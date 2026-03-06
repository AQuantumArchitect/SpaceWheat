#!/usr/bin/env python3
import argparse
import json
import statistics
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

import milk_hunt_args
from milk_hunt_console import Console, resolve_console_profile
from milk_hunt_io import write_json
from milk_hunt_profiles import get_profile
from profile_save_registry import get_profile_name_for_save, get_profile_save, resolve_profile_save_spec

SCRIPT_DIR = Path(__file__).resolve().parent
RUNNER = SCRIPT_DIR / "milk_hunt_runner.py"
SEEDER = SCRIPT_DIR / "milk_hunt_seed_save.py"


def _build_parser() -> argparse.ArgumentParser:
    parser = milk_hunt_args.make_base_parser("Batch runner for milk hunt trials")
    parser.add_argument("--runs", type=int, default=5, help="How many independent trials to run")
    parser.add_argument("--max-loops", type=int, default=220, help="Max offer cycles per trial")
    parser.add_argument(
        "--metrics-every",
        type=int,
        default=0,
        help="Sample batcher metrics every N loops in each run (0 disables)",
    )
    parser.add_argument(
        "--runtime-profile",
        choices=["default", "quantum_fiber_nodes", "io_min"],
        default=None,
        help="Runtime env profile to apply when launching rig listener",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("/tmp/milk_hunt_batches"),
        help="Directory for logs and summaries",
    )
    parser.add_argument("--profile", type=str, default=None, help="Profile name for starter seeding")
    parser.add_argument("--world-state", type=str, default=None, help="World state JSON path (alternative to --profile)")
    parser.add_argument("--seed-slot", type=int, default=2, help="Save slot to write profile seed into")
    parser.add_argument("--seed-from-slot", type=int, default=None, help="Optional slot to load before profile seeding")
    parser.add_argument(
        "--resource-mode",
        choices=["add", "set"],
        default=None,
        help="Resource application mode for profile seeding",
    )
    parser.add_argument(
        "--include-offer-reward-resources",
        dest="include_offer_reward_resources",
        action="store_true",
        help="Include reward_resources payload in offer_quests responses",
    )
    parser.add_argument(
        "--no-include-offer-reward-resources",
        dest="include_offer_reward_resources",
        action="store_false",
        help="Exclude reward_resources payload from offer_quests responses",
    )
    parser.add_argument(
        "--include-offer-market-projection",
        dest="include_offer_market_projection",
        action="store_true",
        help="Include market_projection payload in offer_quests responses",
    )
    parser.add_argument(
        "--no-include-offer-market-projection",
        dest="include_offer_market_projection",
        action="store_false",
        help="Exclude market_projection payload from offer_quests responses",
    )
    parser.set_defaults(strict_biome_economy=True, reuse_listener=True)
    parser.set_defaults(include_offer_reward_resources=False)
    parser.set_defaults(include_offer_market_projection=False)
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
    profile_save: str | None,
    profile_save_index: str | None,
    strict_biome_economy: Optional[bool],
    reuse_listener: bool,
    turn_start: int,
    no_stop: bool,
    strategy_path: str | None = None,
    hunter_profile: str | None = None,
    hunter_policy: str | None = None,
    console_profile: str | None = None,
    metrics_every: int = 0,
    runtime_profile: str | None = None,
    include_offer_reward_resources: bool = False,
    include_offer_market_projection: bool = False,
) -> Dict[str, Any]:
    run_name = f"run_{run_idx:03d}"
    run_dir = batch_dir / run_name
    run_dir.mkdir(parents=True, exist_ok=True)
    log_path = run_dir / "stdout.log"

    cmd = [
        "python3",
        str(RUNNER),
        "--max-loops",
        str(max_loops),
        "--json-only",
        "--turn-start",
        str(turn_start),
    ]
    if strategy_path is not None:
        cmd.extend(["--strategy", strategy_path])
    if hunter_profile is not None:
        cmd.extend(["--hunter-profile", hunter_profile])
    if hunter_policy is not None:
        cmd.extend(["--hunter-policy", hunter_policy])
    if console_profile is not None:
        cmd.extend(["--console-profile", console_profile])
    if metrics_every > 0:
        cmd.extend(["--metrics-every", str(int(metrics_every))])
    if runtime_profile:
        cmd.extend(["--runtime-profile", str(runtime_profile)])
    if load_slot is not None:
        cmd.extend(["--load-slot", str(load_slot)])
    if profile_save is not None:
        cmd.extend(["--profile-save", str(profile_save)])
        if profile_save_index:
            cmd.extend(["--profile-save-index", str(profile_save_index)])
    elif load_alias is not None:
        cmd.extend(["--load-alias", str(load_alias)])
    if strict_biome_economy is True:
        cmd.append("--strict-biome-economy")
    elif strict_biome_economy is False:
        cmd.append("--no-strict-biome-economy")
    if include_offer_reward_resources:
        cmd.append("--include-offer-reward-resources")
    else:
        cmd.append("--no-include-offer-reward-resources")
    if include_offer_market_projection:
        cmd.append("--include-offer-market-projection")
    else:
        cmd.append("--no-include-offer-market-projection")
    if reuse_listener:
        cmd.append("--reuse-listener")
        cmd.append("--no-clear-rig")
    if no_stop:
        cmd.append("--no-stop")
    proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    log_path.write_text((proc.stdout or "") + (proc.stderr or ""), encoding="utf-8")

    summary: Dict[str, Any] = {}
    if proc.stdout:
        last_line = proc.stdout.rstrip().rsplit("\n", 1)[-1].strip()
        try:
            summary = json.loads(last_line)
        except json.JSONDecodeError:
            summary = {"parse_error": "invalid_json_in_stdout"}
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
    console = Console(resolve_console_profile(args.console_profile))
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    batch_dir = args.output_dir / f"batch_{ts}"
    batch_dir.mkdir(parents=True, exist_ok=True)

    profile: Optional[Dict[str, Any]] = None
    load_slot = args.load_slot
    load_alias = args.load_alias
    seed_result: Optional[Dict[str, Any]] = None
    resolved_profile_save: Optional[str] = None
    if args.profile_save and (args.profile or args.world_state):
        console.log("[batch] cannot combine --profile-save with --profile/--world-state", "error")
        return 2

    if args.profile_save:
        resolved_profile_save = resolve_profile_save_spec(args.profile_save, args.profile_save_index)
    elif args.profile and not args.world_state:
        mapped = get_profile_save(args.profile, args.profile_save_index)
        if mapped:
            resolved_profile_save = mapped
            console.log(
                f"[batch] profile '{args.profile}' resolved to profile-save '{resolved_profile_save}'",
                "detail",
            )
    if resolved_profile_save:
        load_alias = resolved_profile_save
        load_slot = None
        console.log(f"[batch] using profile-save '{resolved_profile_save}'", "info")

    seed_source = args.world_state or args.profile
    if seed_source and not resolved_profile_save:
        if args.profile and not args.world_state:
            try:
                profile = get_profile(args.profile)
            except ValueError as exc:
                console.log(f"[batch] {exc}", "error")
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
            console.log("[batch] profile seeding failed", "error")
            console.log(json.dumps(seed_result, ensure_ascii=False, indent=2), "warn")
            return 3
        load_slot = seed_slot
        load_alias = None
        console.log(f"[batch] '{seed_source}' seeded into slot {seed_slot}", "info")

    strict_biome_economy = args.strict_biome_economy
    if strict_biome_economy is None:
        strict_biome_economy = True
    hunter_profile = args.hunter_profile or args.profile
    if hunter_profile is None and args.profile_save:
        mapped = get_profile_save(args.profile_save, args.profile_save_index)
        if mapped:
            hunter_profile = args.profile_save
        else:
            lookup = resolved_profile_save if resolved_profile_save else args.profile_save
            hunter_profile = get_profile_name_for_save(lookup, args.profile_save_index)
    if hunter_profile is None and resolved_profile_save:
        hunter_profile = get_profile_name_for_save(resolved_profile_save, args.profile_save_index)
    hunter_policy = args.hunter_policy
    reuse_enabled = bool(args.reuse_listener)
    metrics_every = max(0, int(args.metrics_every))

    run_summaries: List[Dict[str, Any]] = []
    turn_cursor = 1
    for i in range(1, args.runs + 1):
        reuse = bool(reuse_enabled and i > 1)
        no_stop = bool(reuse_enabled and i < args.runs)
        summary = _run_trial(
            batch_dir,
            i,
            args.max_loops,
            load_slot,
            load_alias,
            resolved_profile_save,
            args.profile_save_index,
            strict_biome_economy,
            reuse_listener=reuse,
            turn_start=turn_cursor,
            no_stop=no_stop,
            strategy_path=args.strategy,
            hunter_profile=hunter_profile,
            hunter_policy=hunter_policy,
            console_profile=console.profile,
            metrics_every=metrics_every,
            runtime_profile=args.runtime_profile,
            include_offer_reward_resources=bool(args.include_offer_reward_resources),
            include_offer_market_projection=bool(args.include_offer_market_projection),
        )
        run_summaries.append(summary)
        found = bool(summary.get("found_milk_pair", False))
        steps = int(summary.get("steps", summary.get("turns_executed", 0) or 0) or 0)
        console.log(f"[batch] {summary.get('run_name')} found_milk={found} steps={steps}", "info")
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
    quest_offers_seen_per_run = [int(s.get("quest_offers_seen", 0) or 0) for s in run_summaries]
    quest_completions_per_run = [int(s.get("quest_completions", 0) or 0) for s in run_summaries]
    quest_claims_per_run = [int(s.get("quest_claims", 0) or 0) for s in run_summaries]
    vocab_pairs_learned_per_run = [int(s.get("vocab_pairs_learned", 0) or 0) for s in run_summaries]
    drains_established_per_run = [int(s.get("lindblad_drains_established", 0) or 0) for s in run_summaries]
    drain_actions_per_run = [int(s.get("lindblad_drain_actions", 0) or 0) for s in run_summaries]
    time_skip_actions_per_run = [int(s.get("time_skip_actions", 0) or 0) for s in run_summaries]
    time_skip_phrames_per_run = [int(s.get("time_skip_total_phrames", 0) or 0) for s in run_summaries]
    time_skip_evolved_steps_per_run = [int(s.get("time_skip_total_evolved_steps", 0) or 0) for s in run_summaries]

    def _sample_metric(field: str) -> List[float]:
        values: List[float] = []
        for summary in run_summaries:
            samples = summary.get("batcher_metrics_samples", [])
            if not isinstance(samples, list):
                continue
            for sample in samples:
                if not isinstance(sample, dict):
                    continue
                metrics = sample.get("metrics", {})
                if not isinstance(metrics, dict):
                    continue
                raw = metrics.get(field)
                if isinstance(raw, (int, float)):
                    values.append(float(raw))
        return values

    sampled_threads_running = _sample_metric("threads_running")
    sampled_packets_pending = _sample_metric("packets_pending")
    sampled_physics_fps = _sample_metric("physics_fps")
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
        "profile_save": resolved_profile_save,
        "profile_save_index": args.profile_save_index,
        "console_profile": console.profile,
        "reuse_listener": reuse_enabled,
        "metrics_every": metrics_every,
        "runtime_profile": args.runtime_profile or "default",
        "include_offer_reward_resources": bool(args.include_offer_reward_resources),
        "include_offer_market_projection": bool(args.include_offer_market_projection),
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
        "avg_quest_offers_seen_per_run": _avg(quest_offers_seen_per_run),
        "avg_quest_completions_per_run": _avg(quest_completions_per_run),
        "avg_quest_claims_per_run": _avg(quest_claims_per_run),
        "avg_vocab_pairs_learned_per_run": _avg(vocab_pairs_learned_per_run),
        "avg_lindblad_drain_actions_per_run": _avg(drain_actions_per_run),
        "avg_lindblad_drains_established_per_run": _avg(drains_established_per_run),
        "avg_time_skip_actions_per_run": _avg(time_skip_actions_per_run),
        "avg_time_skip_phrames_per_run": _avg(time_skip_phrames_per_run),
        "avg_time_skip_evolved_steps_per_run": _avg(time_skip_evolved_steps_per_run),
        "avg_sampled_threads_running": float(statistics.mean(sampled_threads_running)) if sampled_threads_running else 0.0,
        "max_sampled_threads_running": int(max(sampled_threads_running)) if sampled_threads_running else 0,
        "avg_sampled_packets_pending": float(statistics.mean(sampled_packets_pending)) if sampled_packets_pending else 0.0,
        "max_sampled_packets_pending": int(max(sampled_packets_pending)) if sampled_packets_pending else 0,
        "avg_sampled_physics_fps": float(statistics.mean(sampled_physics_fps)) if sampled_physics_fps else 0.0,
        "discovered_biomes_union": all_discovered,
        "first_discovery_counts": first_discovery_counts,
        "batch_dir": str(batch_dir),
        "run_summaries": run_summaries,
    }

    agg_path = batch_dir / "batch_summary.json"
    write_json(agg_path, aggregate)
    profile_report = {
        "profile": aggregate.get("profile", ""),
        "runs": [
            {
                "run_name": s.get("run_name", ""),
                "found_milk_pair": bool(s.get("found_milk_pair", False)),
                "steps": int(s.get("steps", s.get("turns_executed", 0) or 0) or 0),
                "loops_completed": int(s.get("loops_completed", 0) or 0),
                "quest_offer_cycles": int(s.get("quest_offer_cycles", 0) or 0),
                "quest_offers_seen": int(s.get("quest_offers_seen", 0) or 0),
                "quest_offers_accepted": int(s.get("quest_offers_accepted", 0) or 0),
                "quest_completions": int(s.get("quest_completions", 0) or 0),
                "quest_claims": int(s.get("quest_claims", 0) or 0),
                "vocab_pairs_learned": int(s.get("vocab_pairs_learned", 0) or 0),
                "lindblad_drain_actions": int(s.get("lindblad_drain_actions", 0) or 0),
                "lindblad_drains_established": int(s.get("lindblad_drains_established", 0) or 0),
                "time_skip_actions": int(s.get("time_skip_actions", 0) or 0),
                "time_skip_total_phrames": int(s.get("time_skip_total_phrames", 0) or 0),
                "time_skip_total_evolved_steps": int(s.get("time_skip_total_evolved_steps", 0) or 0),
                "batcher_metrics_samples": len(s.get("batcher_metrics_samples", []) or []),
                "exit_code": int(s.get("exit_code", -1) or -1),
                "run_error": s.get("run_error"),
                "timeout_action": s.get("timeout_action"),
            }
            for s in run_summaries
        ],
        "averages": {
            "steps": aggregate.get("avg_steps_all", 0.0),
            "loops_completed": aggregate.get("avg_loops_completed_all", 0.0),
            "quest_offers_seen": aggregate.get("avg_quest_offers_seen_per_run", 0.0),
            "quest_completions": aggregate.get("avg_quest_completions_per_run", 0.0),
            "quest_claims": aggregate.get("avg_quest_claims_per_run", 0.0),
            "vocab_pairs_learned": aggregate.get("avg_vocab_pairs_learned_per_run", 0.0),
            "lindblad_drain_actions": aggregate.get("avg_lindblad_drain_actions_per_run", 0.0),
            "lindblad_drains_established": aggregate.get("avg_lindblad_drains_established_per_run", 0.0),
            "time_skip_actions": aggregate.get("avg_time_skip_actions_per_run", 0.0),
            "time_skip_phrames": aggregate.get("avg_time_skip_phrames_per_run", 0.0),
            "time_skip_evolved_steps": aggregate.get("avg_time_skip_evolved_steps_per_run", 0.0),
        },
    }
    write_json(batch_dir / "profile_report.json", profile_report)
    if console.allows("trace"):
        console.log("[batch] summary", "info")
        console.log(json.dumps(aggregate, ensure_ascii=False, indent=2), "detail")
    else:
        console.log(
            "[batch] summary success=%d/%d avg_steps=%.1f -> %s"
            % (
                int(aggregate["success_count"]),
                int(aggregate["runs"]),
                float(aggregate["avg_steps_all"]),
                str(agg_path),
            ),
            "info",
        )
    return 0 if len(successes) > 0 else 2


if __name__ == "__main__":
    sys.exit(main())
