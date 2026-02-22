#!/usr/bin/env python3
import argparse
import json
import statistics
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

from milk_hunt_profiles import get_profile

SCRIPT_DIR = Path(__file__).resolve().parent
RUNNER = SCRIPT_DIR / "milk_hunt_runner.py"
SEEDER = SCRIPT_DIR / "milk_hunt_seed_save.py"


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Batch runner for milk hunt trials")
    parser.add_argument("--runs", type=int, default=5, help="How many independent trials to run")
    parser.add_argument("--max-loops", type=int, default=220, help="Max offer cycles per trial")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("/tmp/milk_hunt_batches"),
        help="Directory for logs and summaries",
    )
    parser.add_argument("--load-slot", type=int, default=None, help="Boot each trial from this save slot")
    parser.add_argument("--load-alias", type=str, default=None, help="Load each trial from emoji alias save filename/path")
    parser.add_argument("--profile", type=str, default=None, help="Profile name for starter seeding")
    parser.add_argument("--world-state", type=str, default=None, help="World state JSON path (alternative to --profile)")
    parser.add_argument("--hunter-profile", type=str, default=None, help="Policy profile passed to runner")
    parser.add_argument(
        "--hunter-policy",
        choices=["auto", "classic", "quantum_graph"],
        default=None,
        help="Policy mode passed to runner",
    )
    parser.add_argument("--strategy", type=str, default=None, help="Strategy JSON path passed to runner")
    parser.add_argument("--seed-slot", type=int, default=2, help="Save slot to write profile seed into")
    parser.add_argument("--seed-from-slot", type=int, default=None, help="Optional slot to load before profile seeding")
    parser.add_argument("--scenario-id", type=str, default=None, help="Scenario id used for profile seeding")
    parser.add_argument(
        "--resource-mode",
        choices=["add", "set"],
        default=None,
        help="Resource application mode for profile seeding",
    )
    parser.add_argument(
        "--strict-biome-economy",
        dest="strict_biome_economy",
        action="store_true",
        help="Disable all rig-side resource injection in each trial",
    )
    parser.add_argument(
        "--no-strict-biome-economy",
        dest="strict_biome_economy",
        action="store_false",
        help="Force-enable rig-side resource injection in each trial",
    )
    parser.add_argument(
        "--reuse-listener",
        action="store_true",
        help="Reuse a single rig listener for all trials in this batch",
    )
    parser.set_defaults(strict_biome_economy=None)
    return parser


def _avg(nums: List[int]) -> float:
    if not nums:
        return 0.0
    return float(statistics.mean(nums))


def _run_trial(
    batch_dir: Path,
    run_idx: int,
    max_loops: int,
    load_slot: int | None,
    load_alias: str | None,
    strict_biome_economy: Optional[bool],
    reuse_listener: bool,
    turn_start: int,
    no_stop: bool,
    strategy_path: str | None = None,
    hunter_profile: str | None = None,
    hunter_policy: str | None = None,
) -> Dict[str, Any]:
    run_name = f"run_{run_idx:03d}"
    run_dir = batch_dir / run_name
    run_dir.mkdir(parents=True, exist_ok=True)
    log_path = run_dir / "stdout.log"
    summary_path = run_dir / "summary.json"

    cmd = [
        "python3",
        str(RUNNER),
        "--max-loops",
        str(max_loops),
        "--summary-path",
        str(summary_path),
        "--turn-start",
        str(turn_start),
    ]
    if strategy_path is not None:
        cmd.extend(["--strategy", strategy_path])
    if hunter_profile is not None:
        cmd.extend(["--hunter-profile", hunter_profile])
    if hunter_policy is not None:
        cmd.extend(["--hunter-policy", hunter_policy])
    if load_slot is not None:
        cmd.extend(["--load-slot", str(load_slot)])
    if load_alias is not None:
        cmd.extend(["--load-alias", str(load_alias)])
    if strict_biome_economy is True:
        cmd.append("--strict-biome-economy")
    elif strict_biome_economy is False:
        cmd.append("--no-strict-biome-economy")
    if reuse_listener:
        cmd.append("--reuse-listener")
        cmd.append("--no-clear-rig")
    if no_stop:
        cmd.append("--no-stop")
    proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    log_path.write_text((proc.stdout or "") + (proc.stderr or ""), encoding="utf-8")

    summary: Dict[str, Any] = {}
    if summary_path.exists():
        try:
            summary = json.loads(summary_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            summary = {"parse_error": "invalid_summary_json"}
    summary["exit_code"] = proc.returncode
    summary["run_name"] = run_name
    summary["log_path"] = str(log_path)
    return summary


def _seed_profile(
    batch_dir: Path,
    profile_name: str,
    seed_slot: int,
    seed_from_slot: Optional[int],
    scenario_id: Optional[str],
    resource_mode: Optional[str],
    world_state_path: Optional[str] = None,
) -> Dict[str, Any]:
    log_path = batch_dir / "seed_stdout.log"
    cmd = [
        "python3",
        str(SEEDER),
        "--slot",
        str(seed_slot),
    ]
    if world_state_path:
        cmd.extend(["--world-state", world_state_path])
    else:
        cmd.extend(["--profile", profile_name])
    if seed_from_slot is not None:
        cmd.extend(["--load-slot", str(seed_from_slot)])
    if scenario_id:
        cmd.extend(["--scenario-id", scenario_id])
    if resource_mode:
        cmd.extend(["--resource-mode", resource_mode])
    proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    log_path.write_text((proc.stdout or "") + (proc.stderr or ""), encoding="utf-8")
    return {"ok": proc.returncode == 0, "exit_code": proc.returncode, "log_path": str(log_path), "cmd": cmd}


def main() -> int:
    args = _build_parser().parse_args()
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    batch_dir = args.output_dir / f"batch_{ts}"
    batch_dir.mkdir(parents=True, exist_ok=True)

    profile: Optional[Dict[str, Any]] = None
    load_slot = args.load_slot
    load_alias = args.load_alias
    seed_result: Optional[Dict[str, Any]] = None
    seed_source = args.world_state or args.profile
    if seed_source:
        if args.profile and not args.world_state:
            try:
                profile = get_profile(args.profile)
            except ValueError as exc:
                print(f"[batch] {exc}", flush=True)
                return 2
        seed_slot = load_slot if load_slot is not None else args.seed_slot
        seed_result = _seed_profile(
            batch_dir=batch_dir,
            profile_name=args.profile or "",
            seed_slot=seed_slot,
            seed_from_slot=args.seed_from_slot,
            scenario_id=args.scenario_id,
            resource_mode=args.resource_mode,
            world_state_path=args.world_state,
        )
        if not seed_result["ok"]:
            print("[batch] profile seeding failed", flush=True)
            print(json.dumps(seed_result, ensure_ascii=False, indent=2), flush=True)
            return 3
        load_slot = seed_slot
        load_alias = None
        print(f"[batch] '{seed_source}' seeded into slot {seed_slot}", flush=True)

    strict_biome_economy = args.strict_biome_economy
    if strict_biome_economy is None and profile and "strict_biome_economy" in profile:
        strict_biome_economy = bool(profile.get("strict_biome_economy"))
    hunter_profile = args.hunter_profile or args.profile
    hunter_policy = args.hunter_policy

    run_summaries: List[Dict[str, Any]] = []
    turn_cursor = 1
    for i in range(1, args.runs + 1):
        reuse = bool(args.reuse_listener and i > 1)
        no_stop = bool(args.reuse_listener and i < args.runs)
        summary = _run_trial(
            batch_dir,
            i,
            args.max_loops,
            load_slot,
            load_alias,
            strict_biome_economy,
            reuse_listener=reuse,
            turn_start=turn_cursor,
            no_stop=no_stop,
            strategy_path=args.strategy,
            hunter_profile=hunter_profile,
            hunter_policy=hunter_policy,
        )
        run_summaries.append(summary)
        found = bool(summary.get("found_milk_pair", False))
        steps = int(summary.get("steps", summary.get("turns_executed", 0) or 0) or 0)
        print(f"[batch] {summary.get('run_name')} found_milk={found} steps={steps}", flush=True)
        turn_cursor += steps + 5

    successes = [s for s in run_summaries if s.get("found_milk_pair") is True]
    steps_all = [
        int(s.get("steps", s.get("turns_executed", 0) or 0) or 0)
        for s in run_summaries
    ]
    steps_success = [
        int(s.get("steps", s.get("turns_executed", 0) or 0) or 0)
        for s in successes
    ]
    loops_all = [int(s.get("loops_completed", 0) or 0) for s in run_summaries]
    loops_success = [int(s.get("loops_completed", 0) or 0) for s in successes]
    steps_per_loop_all = [
        (float(steps) / float(loops))
        for steps, loops in zip(steps_all, loops_all)
        if loops > 0
    ]
    steps_per_loop_success = [
        (float(steps) / float(loops))
        for steps, loops in zip(steps_success, loops_success)
        if loops > 0
    ]
    vocab_milestone_counts = [len(s.get("vocab_milestones", []) or []) for s in run_summaries]
    vocab_first_milestone_steps = [
        int(((s.get("vocab_milestones", []) or [])[0]).get("step", 0) or 0)
        for s in run_summaries
        if isinstance(s.get("vocab_milestones", []), list) and len(s.get("vocab_milestones", [])) > 0
    ]
    vocab_milk_milestone_steps = [
        int(ms.get("step", 0) or 0)
        for s in run_summaries
        for ms in (s.get("vocab_milestones", []) or [])
        if isinstance(ms, dict) and bool(ms.get("contains_milk_pair", False))
    ]
    milk_pair_steps = [int(s.get("milk_pair_index", 0) or 0) for s in successes if s.get("milk_pair_index") is not None]
    discovered_per_run = [len(s.get("biome_discovery_order", []) or []) for s in run_summaries]
    probe_events_per_run = [len(s.get("biome_probe_events", []) or []) for s in run_summaries]
    all_discovered = sorted(
        {
            biome
            for s in run_summaries
            for biome in (s.get("biome_discovery_order", []) or [])
            if isinstance(biome, str) and biome
        }
    )
    first_discovery_counts: Dict[str, int] = {}
    for s in run_summaries:
        order = s.get("biome_discovery_order", []) or []
        if isinstance(order, list) and order:
            first = order[0]
            if isinstance(first, str) and first:
                first_discovery_counts[first] = first_discovery_counts.get(first, 0) + 1

    effective_strict_biome_economy = strict_biome_economy
    if effective_strict_biome_economy is None and run_summaries:
        effective_strict_biome_economy = bool(run_summaries[0].get("strict_biome_economy", False))

    aggregate = {
        "runs": args.runs,
        "max_loops": args.max_loops,
        "load_slot": load_slot,
        "load_alias": load_alias,
        "strict_biome_economy": effective_strict_biome_economy,
        "profile": profile["name"] if profile else args.profile,
        "profile_description": profile.get("description", "") if profile else "",
        "world_state": args.world_state,
        "strategy": args.strategy,
        "seed_result": seed_result,
        "success_count": len(successes),
        "failure_count": args.runs - len(successes),
        "success_rate": (len(successes) / args.runs) if args.runs else 0.0,
        "avg_turns_all": _avg(steps_all),
        "avg_turns_success_only": _avg(steps_success),
        "min_turns_success_only": min(steps_success) if steps_success else None,
        "max_turns_success_only": max(steps_success) if steps_success else None,
        "avg_steps_all": _avg(steps_all),
        "avg_steps_success_only": _avg(steps_success),
        "min_steps_success_only": min(steps_success) if steps_success else None,
        "max_steps_success_only": max(steps_success) if steps_success else None,
        "avg_loops_completed_all": _avg(loops_all),
        "avg_loops_completed_success_only": _avg(loops_success),
        "avg_steps_per_loop_all": _avg(steps_per_loop_all),
        "avg_steps_per_loop_success_only": _avg(steps_per_loop_success),
        "avg_vocab_milestones_per_run": _avg(vocab_milestone_counts),
        "max_vocab_milestones_per_run": max(vocab_milestone_counts) if vocab_milestone_counts else None,
        "avg_first_vocab_milestone_step": _avg(vocab_first_milestone_steps),
        "avg_milk_vocab_milestone_step": _avg(vocab_milk_milestone_steps),
        "avg_vocab_steps_to_milk": _avg(milk_pair_steps),
        "min_vocab_steps_to_milk": min(milk_pair_steps) if milk_pair_steps else None,
        "max_vocab_steps_to_milk": max(milk_pair_steps) if milk_pair_steps else None,
        "avg_biomes_discovered_per_run": _avg(discovered_per_run),
        "avg_probe_events_per_run": _avg(probe_events_per_run),
        "discovered_biomes_union": all_discovered,
        "first_discovery_counts": first_discovery_counts,
        "batch_dir": str(batch_dir),
        "run_summaries": run_summaries,
    }

    agg_path = batch_dir / "batch_summary.json"
    agg_path.write_text(json.dumps(aggregate, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("[batch] summary", flush=True)
    print(json.dumps(aggregate, ensure_ascii=False, indent=2), flush=True)
    return 0 if len(successes) > 0 else 2


if __name__ == "__main__":
    sys.exit(main())
