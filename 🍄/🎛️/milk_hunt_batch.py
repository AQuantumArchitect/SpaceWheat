#!/usr/bin/env python3
import argparse
import json
import math
import random
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


def _compact_run_summary(summary: Dict[str, Any]) -> Dict[str, Any]:
    compact: Dict[str, Any] = {
        "run_name": str(summary.get("run_name", "")),
        "exit_code": int(summary.get("exit_code", -1) or -1),
        "found_milk_pair": bool(summary.get("found_milk_pair", False)),
        "steps": int(summary.get("steps", summary.get("turns_executed", 0) or 0) or 0),
        "loops_completed": int(summary.get("loops_completed", 0) or 0),
        "strict_biome_economy": bool(summary.get("strict_biome_economy", False)),
        "hunter_policy_mode": str(summary.get("hunter_policy_mode", "")),
        "quest_offers_seen": int(summary.get("quest_offers_seen", 0) or 0),
        "quest_offers_accepted": int(summary.get("quest_offers_accepted", 0) or 0),
        "quest_completions": int(summary.get("quest_completions", 0) or 0),
        "quest_claims": int(summary.get("quest_claims", 0) or 0),
        "vocab_pairs_final": int(summary.get("vocab_pairs_final", 0) or 0),
        "vocab_pairs_learned": int(summary.get("vocab_pairs_learned", 0) or 0),
        "lindblad_drain_actions": int(summary.get("lindblad_drain_actions", 0) or 0),
        "lindblad_drains_established": int(summary.get("lindblad_drains_established", 0) or 0),
        "time_skip_actions": int(summary.get("time_skip_actions", 0) or 0),
        "time_skip_total_phrames": int(summary.get("time_skip_total_phrames", 0) or 0),
        "time_skip_total_evolved_steps": int(summary.get("time_skip_total_evolved_steps", 0) or 0),
        "policy_action_counts": summary.get("policy_action_counts", {}),
        "policy_action_entropy_bits": float(summary.get("policy_action_entropy_bits", 0.0) or 0.0),
        "biome_discovery_order": list(summary.get("biome_discovery_order", []) or []),
        "vocab_milestone_count": len(summary.get("vocab_milestones", []) or []),
        "timeout_action": summary.get("timeout_action"),
        "run_error": summary.get("run_error"),
    }
    if "policy_mutation" in summary:
        compact["policy_mutation"] = summary.get("policy_mutation", {})
    if "batcher_metrics_samples" in summary:
        compact["batcher_metrics_samples"] = len(summary.get("batcher_metrics_samples", []) or [])
    return compact


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
    parser.add_argument(
        "--policy-restrictions",
        dest="policy_restrictions",
        action="store_true",
        help="Enable runner-side policy action restrictions",
    )
    parser.add_argument(
        "--no-policy-restrictions",
        dest="policy_restrictions",
        action="store_false",
        help="Disable runner-side policy action restrictions (full action space)",
    )
    parser.add_argument(
        "--topology-gto",
        dest="topology_gto",
        action="store_true",
        help="Mutate policy parameters per run and export topology report",
    )
    parser.add_argument(
        "--no-topology-gto",
        dest="topology_gto",
        action="store_false",
        help="Disable policy mutation topology sweep",
    )
    parser.add_argument("--base-policy-epsilon", type=float, default=0.18, help="Baseline policy epsilon")
    parser.add_argument("--base-policy-ucb-scale", type=float, default=1.10, help="Baseline policy UCB scale")
    parser.add_argument("--epsilon-jitter", type=float, default=0.12, help="Absolute epsilon mutation radius")
    parser.add_argument("--ucb-octave-jitter", type=float, default=0.45, help="Log2 mutation radius for UCB scale")
    parser.add_argument("--mutation-seed", type=int, default=1337, help="RNG seed for topology mutations")
    parser.set_defaults(strict_biome_economy=True, reuse_listener=True)
    parser.set_defaults(include_offer_reward_resources=False)
    parser.set_defaults(include_offer_market_projection=False)
    parser.set_defaults(policy_restrictions=False, topology_gto=False)
    return parser


def _avg(nums: List[int]) -> float:
    if not nums:
        return 0.0
    return float(statistics.mean(nums))


def _sample_policy_mutation(
    run_idx: int,
    rng: random.Random,
    base_epsilon: float,
    base_ucb_scale: float,
    epsilon_jitter: float,
    ucb_octave_jitter: float,
    enabled: bool,
) -> Dict[str, Any]:
    if not enabled:
        return {
            "id": "baseline",
            "policy_epsilon": max(0.0, min(1.0, float(base_epsilon))),
            "policy_ucb_scale": max(0.0, float(base_ucb_scale)),
            "delta_epsilon": 0.0,
            "delta_ucb_scale": 0.0,
            "octave_shift": 0.0,
        }
    phase = float(run_idx) * 1.61803398875
    epsilon_delta = rng.uniform(-epsilon_jitter, epsilon_jitter) + 0.035 * math.sin(phase)
    epsilon = max(0.0, min(1.0, float(base_epsilon) + epsilon_delta))
    octave_shift = rng.uniform(-ucb_octave_jitter, ucb_octave_jitter)
    ucb_scale = max(0.0, float(base_ucb_scale) * (2.0 ** octave_shift))
    return {
        "id": f"mut_{run_idx:03d}",
        "policy_epsilon": epsilon,
        "policy_ucb_scale": ucb_scale,
        "delta_epsilon": epsilon - float(base_epsilon),
        "delta_ucb_scale": ucb_scale - float(base_ucb_scale),
        "octave_shift": octave_shift,
    }


def _build_topology_report(run_summaries: List[Dict[str, Any]], mode: str) -> Dict[str, Any]:
    action_universe: set[str] = set()
    run_rows: List[Dict[str, Any]] = []
    action_reward_rows: Dict[str, List[float]] = {}

    for summary in run_summaries:
        counts_raw = summary.get("policy_action_counts", {})
        counts: Dict[str, int] = {}
        if isinstance(counts_raw, dict):
            for key, raw_count in counts_raw.items():
                if not isinstance(key, str):
                    continue
                try:
                    counts[key] = max(0, int(raw_count))
                except (TypeError, ValueError):
                    continue
        total = int(sum(counts.values()))
        shares: Dict[str, float] = {}
        if total > 0:
            shares = {k: float(v) / float(total) for k, v in counts.items() if v > 0}
            action_universe.update(shares.keys())
        dominant_action = ""
        dominant_share = 0.0
        if shares:
            dominant_action, dominant_share = max(shares.items(), key=lambda kv: kv[1])
        run_rows.append(
            {
                "run_name": str(summary.get("run_name", "")),
                "success": bool(summary.get("found_milk_pair", False)),
                "steps": int(summary.get("steps", summary.get("turns_executed", 0) or 0) or 0),
                "loops_completed": int(summary.get("loops_completed", 0) or 0),
                "action_counts": counts,
                "action_shares": shares,
                "dominant_action": dominant_action,
                "dominant_share": dominant_share,
                "action_entropy_bits": float(summary.get("policy_action_entropy_bits", 0.0) or 0.0),
                "policy_epsilon": float(summary.get("policy_epsilon", 0.0) or 0.0),
                "policy_ucb_scale": float(summary.get("policy_ucb_scale", 0.0) or 0.0),
                "policy_mutation": summary.get("policy_mutation", {}),
            }
        )
        decisions = summary.get("policy_decisions", [])
        if isinstance(decisions, list):
            for row in decisions:
                if not isinstance(row, dict):
                    continue
                action = str(row.get("executed_action", "") or "")
                reward_raw = row.get("reward", None)
                if not action or not isinstance(reward_raw, (int, float)):
                    continue
                action_reward_rows.setdefault(action, []).append(float(reward_raw))

    def _mean(vals: List[float]) -> float:
        return float(statistics.mean(vals)) if vals else 0.0

    success_rows = [r for r in run_rows if bool(r.get("success", False))]
    failure_rows = [r for r in run_rows if not bool(r.get("success", False))]
    action_stats: Dict[str, Dict[str, Any]] = {}
    for action in sorted(action_universe):
        shares_all = [float(r.get("action_shares", {}).get(action, 0.0)) for r in run_rows]
        shares_success = [float(r.get("action_shares", {}).get(action, 0.0)) for r in success_rows]
        shares_failure = [float(r.get("action_shares", {}).get(action, 0.0)) for r in failure_rows]
        counts_all = [float(int(r.get("action_counts", {}).get(action, 0) or 0)) for r in run_rows]
        success_lift = 0.0
        if success_rows and failure_rows:
            success_lift = _mean(shares_success) - _mean(shares_failure)
        action_stats[action] = {
            "mean_share_all": _mean(shares_all),
            "mean_share_success": _mean(shares_success),
            "mean_share_failure": _mean(shares_failure),
            "share_success_lift": success_lift,
            "share_success_lift_defined": bool(success_rows and failure_rows),
            "mean_count_all": _mean(counts_all),
            "mean_reward_per_execution": _mean(action_reward_rows.get(action, [])),
        }

    return {
        "mode": mode,
        "runs": len(run_rows),
        "success_count": len(success_rows),
        "failure_count": len(failure_rows),
        "action_space": sorted(action_universe),
        "action_stats": action_stats,
        "dominance": {
            "avg_top_action_share_all": _mean([float(r.get("dominant_share", 0.0)) for r in run_rows]),
            "avg_action_entropy_bits_all": _mean([float(r.get("action_entropy_bits", 0.0)) for r in run_rows]),
        },
        "run_rows": run_rows,
    }


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
    policy_restrictions: bool = False,
    policy_epsilon: float | None = None,
    policy_ucb_scale: float | None = None,
) -> Dict[str, Any]:
    run_name = f"run_{run_idx:03d}"
    run_dir = batch_dir / run_name
    run_dir.mkdir(parents=True, exist_ok=True)
    log_path = run_dir / "stdout.log"
    summary_path = run_dir / "run_summary.json"

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
    if policy_epsilon is not None:
        cmd.extend(["--policy-epsilon", str(float(policy_epsilon))])
    if policy_ucb_scale is not None:
        cmd.extend(["--policy-ucb-scale", str(float(policy_ucb_scale))])
    if policy_restrictions:
        cmd.append("--policy-restrictions")
    else:
        cmd.append("--no-policy-restrictions")
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

    summary: Dict[str, Any] = {}
    if proc.stdout:
        last_line = proc.stdout.rstrip().rsplit("\n", 1)[-1].strip()
        try:
            summary = json.loads(last_line)
        except json.JSONDecodeError:
            summary = {"parse_error": "invalid_json_in_stdout"}
    summary["exit_code"] = proc.returncode
    summary["run_name"] = run_name
    compact_summary = _compact_run_summary(summary)
    write_json(summary_path, compact_summary)
    summary["summary_path"] = str(summary_path)
    summary["log_path"] = str(log_path)
    should_write_log = proc.returncode not in {0, 2} or bool(summary.get("parse_error"))
    if not should_write_log and console_profile not in {None, "quiet"}:
        should_write_log = True
    if should_write_log:
        log_path.write_text((proc.stdout or "") + (proc.stderr or ""), encoding="utf-8")
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
    rng = random.Random(int(args.mutation_seed))
    for i in range(1, args.runs + 1):
        reuse = bool(reuse_enabled and i > 1)
        no_stop = bool(reuse_enabled and i < args.runs)
        mutation = _sample_policy_mutation(
            run_idx=i,
            rng=rng,
            base_epsilon=float(args.base_policy_epsilon),
            base_ucb_scale=float(args.base_policy_ucb_scale),
            epsilon_jitter=max(0.0, float(args.epsilon_jitter)),
            ucb_octave_jitter=max(0.0, float(args.ucb_octave_jitter)),
            enabled=bool(args.topology_gto),
        )
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
            policy_restrictions=bool(args.policy_restrictions),
            policy_epsilon=float(mutation.get("policy_epsilon", args.base_policy_epsilon)),
            policy_ucb_scale=float(mutation.get("policy_ucb_scale", args.base_policy_ucb_scale)),
        )
        summary["policy_mutation"] = mutation
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
        "policy_restrictions": bool(args.policy_restrictions),
        "topology_gto": bool(args.topology_gto),
        "base_policy_epsilon": float(args.base_policy_epsilon),
        "base_policy_ucb_scale": float(args.base_policy_ucb_scale),
        "epsilon_jitter": float(args.epsilon_jitter),
        "ucb_octave_jitter": float(args.ucb_octave_jitter),
        "mutation_seed": int(args.mutation_seed),
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
        "run_summaries": [_compact_run_summary(s) for s in run_summaries],
    }

    topology_report = _build_topology_report(
        run_summaries,
        mode="gto_mutation" if bool(args.topology_gto) else "baseline",
    )
    topology_path = batch_dir / "topology_report.json"
    write_json(topology_path, topology_report)
    aggregate["topology_report_path"] = str(topology_path)
    aggregate["topology_highlights"] = {
        "action_space_size": len(topology_report.get("action_space", [])),
        "avg_top_action_share_all": float((topology_report.get("dominance", {}) or {}).get("avg_top_action_share_all", 0.0) or 0.0),
        "avg_action_entropy_bits_all": float((topology_report.get("dominance", {}) or {}).get("avg_action_entropy_bits_all", 0.0) or 0.0),
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
