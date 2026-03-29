#!/usr/bin/env python3
"""Arena: unified competition entry point for SpaceWheat.

Replaces 4 separate derby scripts with one CLI:

    python3 arena.py race   --profile balanced_survival --runners 5
    python3 arena.py duel   --lanes sonnet codex --runners-per-lane 5
    python3 arena.py matrix --profiles "derby_*" --runs 5
    python3 arena.py design --lanes sonnet codex

Modes:
  race   - 🏁 Round-robin: N runners race on 1 profile, fibonacci rounds
  duel   - 🏆 Head-to-head: 2+ lanes in parallel, each with N runners
  matrix - 📊 Batch comparison: multiple profiles, N runs each
  design - 🧬 LLM character generation + matrix evaluation

All modes use the same scoring, the same RunnerResult type, and the
same JSON output envelope.  Tissue learning is automatic.

Graph Tissue™ is a trademark of Luke Spooner.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import time
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path
from typing import Any, Dict, List, Optional

from emoji import (
    DERBY, RACE, LANE, RUNNER, BATCH, TISSUE, LICHEN,
    LAYER_RACE, LAYER_DUEL, LAYER_MATRIX,
    header, tag,
)
from schema import (
    RunnerResult, score_lane, make_envelope,
    format_scoreboard, format_lane_scores,
)
from tissue_ledger import (
    WEIGHT_RANGES,
    append_ledger_entry,
    evolve_defaults,
    format_evolved_diff,
    format_policy_projection,
    format_resource_projection,
    lichen_scoring_weights,
    load_evolved_defaults,
    project_to_policy,
    project_to_resources,
    score_with_weights,
)
from profiles import (
    list_derby_names,
    list_derby_lanes,
    list_names,
    exists as profile_exists,
    load as load_profile,
    WORLD_STATE_DIR,
)
from milk_hunt_io import write_json
from run_executor import ensure_lane, run_batch, run_runner, run_seed

HERE = Path(__file__).resolve().parent
LOG_DIR = HERE / "logs" / "derby"
BATCH_LOG_DIR = HERE / "logs" / "milk_batches"
BATCH_SCRIPT = HERE / "milk_hunt_batch.py"
SEED_SCRIPT = HERE / "milk_hunt_seed_save.py"
RUNNER_SCRIPT = HERE / "milk_hunt_runner.py"

# Claura lichen bridge
_WS_ROOT = HERE.parent.parent.parent
CLAURA_ROOT = Path(os.environ.get("CLAURA_ROOT", str(_WS_ROOT / "Claura")))
_PROBE_PYTHON = CLAURA_ROOT / "venv" / "bin" / "python3"
LICHEN_STATE = CLAURA_ROOT / "fungi_rig_state.json"


# ═══════════════════════════════════════════════════════════════════
# Lichen probe (shared across modes)
# ═══════════════════════════════════════════════════════════════════

_PROBE_DEFAULTS: Dict[str, Any] = {
    "recommended_params": {
        "base_policy_epsilon":   0.18,
        "base_policy_ucb_scale": 1.10,
        "epsilon_jitter":        0.12,
        "ucb_octave_jitter":     0.45,
    },
    "jsonl_overlay":          [],
    "character_prompt_context": "",
    "lane_projection":        {"cost_sensitivity": 0.5, "exploration_pressure": 0.5},
}


def _probe_lichen() -> Dict[str, Any]:
    """Call quantum_lichen.derby_probe and return its JSON output."""
    if not _PROBE_PYTHON.exists():
        print(f"  [{LICHEN}] Claura venv not found — using defaults", flush=True)
        return _PROBE_DEFAULTS.copy()
    try:
        proc = subprocess.run(
            [str(_PROBE_PYTHON), "-m", "quantum_lichen.derby_probe",
             "--rig-state", str(LICHEN_STATE)],
            capture_output=True, text=True, timeout=30,
            cwd=str(CLAURA_ROOT),
        )
        if proc.returncode == 0 and proc.stdout.strip():
            data = json.loads(proc.stdout)
            rp = data.get("recommended_params", {})
            print(f"  [{LICHEN}] probe ok — "
                  f"epsilon={rp.get('base_policy_epsilon', '?'):.3f}  "
                  f"ucb={rp.get('base_policy_ucb_scale', '?'):.3f}", flush=True)
            return data
    except Exception as exc:
        print(f"  [{LICHEN}] probe failed ({exc}) — using defaults", flush=True)
    return _PROBE_DEFAULTS.copy()


def _observe_lichen_derby(summary_path: Path) -> None:
    """Post derby results to lichen pheromone system."""
    if not _PROBE_PYTHON.exists():
        return
    try:
        proc = subprocess.run(
            [str(_PROBE_PYTHON), "-m", "quantum_lichen.derby_probe",
             "--observe-derby", str(summary_path),
             "--rig-state", str(LICHEN_STATE), "--save"],
            capture_output=True, text=True, timeout=30,
            cwd=str(CLAURA_ROOT),
        )
        if proc.returncode == 0:
            result = json.loads(proc.stdout) if proc.stdout.strip() else {}
            print(f"  [{LICHEN}] derby observed — "
                  f"saved={result.get('saved', False)}", flush=True)
    except Exception as exc:
        print(f"  [{LICHEN}] observe-derby failed: {exc}", flush=True)


def _write_overlay_jsonl(ops: List[Dict[str, Any]], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(json.dumps(op) for op in ops) + "\n")


# ═══════════════════════════════════════════════════════════════════
# Tissue setup (shared across modes)
# ═══════════════════════════════════════════════════════════════════

def _setup_tissue(
    no_lichen: bool = False,
) -> Dict[str, Any]:
    """Probe lichen + load evolved tissue defaults.

    Returns a context dict with everything modes need for scoring + policy.
    """
    ctx: Dict[str, Any] = {}

    # Lichen probe
    if no_lichen:
        ctx["lichen_probe"] = _PROBE_DEFAULTS.copy()
    else:
        print(f"\n[{LICHEN}] Probing quantum organism state...")
        ctx["lichen_probe"] = _probe_lichen()

    # Evolved tissue defaults
    evolved_ranges, ledger = load_evolved_defaults()
    ctx["evolved_ranges"] = evolved_ranges
    ctx["ledger"] = ledger
    ctx["n_ledger"] = len(ledger)

    diffs = format_evolved_diff(evolved_ranges)
    if diffs:
        print(f"\n[{TISSUE}] Evolved defaults ({len(ledger)} entries):")
        for line in diffs[:8]:
            print(f"  {line}")

    # Adaptive scoring weights
    cal_proj = ctx["lichen_probe"].get("cal_projection")
    ctx["scoring_weights"] = lichen_scoring_weights(cal_proj)

    # Policy projection
    ctx["tissue_policy_ops"] = project_to_policy(evolved_ranges)
    ctx["tissue_resources"] = project_to_resources(evolved_ranges)

    # Lichen overlay ops (tissue base + Claura quantum overlay)
    lichen_overlay = ctx["lichen_probe"].get("jsonl_overlay", [])
    ctx["combined_overlay_ops"] = ctx["tissue_policy_ops"] + lichen_overlay

    # Lichen params for subprocess env injection
    rp = ctx["lichen_probe"].get("recommended_params", {})
    ctx["lichen_params"] = {
        "epsilon":          rp.get("base_policy_epsilon",   0.18),
        "ucb_scale":        rp.get("base_policy_ucb_scale", 1.10),
        "gto_epsilon":      rp.get("base_policy_epsilon",   0.18),
        "gto_ucb_scale":    rp.get("base_policy_ucb_scale", 1.10),
        "epsilon_jitter":   rp.get("epsilon_jitter",        0.12),
        "ucb_octave_jitter": rp.get("ucb_octave_jitter",    0.45),
    }

    return ctx


# ═══════════════════════════════════════════════════════════════════
# Extract learnings (shared across modes)
# ═══════════════════════════════════════════════════════════════════

def _extract_learnings(
    runners: List[RunnerResult],
    evolved_ranges: Dict[str, Any],
    scoring_weights: Optional[Dict[str, float]] = None,
) -> Dict[str, Any]:
    """Extract Graph Tissue learnings: which weights + resources correlated with success."""
    scored = sorted(runners, key=lambda r: r.composite(scoring_weights), reverse=True)
    winners = scored[:3]
    losers = scored[3:]

    learnings: Dict[str, Any] = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "trademark": "Graph Tissue™ is a trademark of Luke Spooner",
        "top_runners": [],
        "tissue_signal": {},
        "resource_signal": {},
    }

    for r in winners:
        learnings["top_runners"].append({
            "profile": r.profile, "lane": r.lane,
            "composite": r.composite(scoring_weights),
            "found_milk": r.found_milk,
        })

    # Resource signal: winner vs loser starting resources
    winner_res: Dict[str, List[float]] = {}
    loser_res: Dict[str, List[float]] = {}
    for r in winners:
        if profile_exists(r.profile):
            res = load_profile(r.profile).get("resources", {})
            for emoji, val in res.items():
                winner_res.setdefault(emoji, []).append(float(val))
    for r in losers:
        if profile_exists(r.profile):
            res = load_profile(r.profile).get("resources", {})
            for emoji, val in res.items():
                loser_res.setdefault(emoji, []).append(float(val))
    all_emojis = set(winner_res) | set(loser_res)
    for emoji in all_emojis:
        w_vals = winner_res.get(emoji, [0])
        l_vals = loser_res.get(emoji, [0])
        w_avg = sum(w_vals) / len(w_vals)
        l_avg = sum(l_vals) / len(l_vals)
        if abs(w_avg - l_avg) > 10:
            learnings["resource_signal"][emoji] = {
                "winner_avg": round(w_avg, 1),
                "loser_avg": round(l_avg, 1),
                "delta": round(w_avg - l_avg, 1),
            }

    return learnings


def _finish_tissue(
    runners: List[RunnerResult],
    ctx: Dict[str, Any],
    summary_path: Path,
    no_lichen: bool = False,
) -> Dict[str, Any]:
    """Extract learnings, append to ledger, observe lichen.  Returns learnings dict."""
    learnings = _extract_learnings(
        runners, ctx["evolved_ranges"], ctx["scoring_weights"])

    # Print learnings
    if learnings["tissue_signal"]:
        print(f"\n  [{TISSUE}] LEARNINGS:")
        for k, sig in learnings["tissue_signal"].items():
            print(f"    {sig['direction']} {k}: {sig['mean_delta']:+.4f}  (n={sig['n_winners']})")
    if learnings["resource_signal"]:
        print(f"\n  [{TISSUE}] RESOURCE SIGNAL:")
        for emoji, sig in learnings["resource_signal"].items():
            print(f"    {emoji}: winners={sig['winner_avg']:.0f} "
                  f"losers={sig['loser_avg']:.0f} "
                  f"(delta={sig['delta']:+.0f})")

    # Append to ledger
    n_winners = sum(1 for r in runners if r.found_milk)
    append_ledger_entry(
        tissue_signal=learnings.get("tissue_signal", {}),
        resource_signal=learnings.get("resource_signal", {}),
        scoring_weights=ctx["scoring_weights"],
        n_hunters=len(runners),
        n_winners=n_winners,
    )
    print(f"\n  [{TISSUE}] Ledger entry #{ctx['n_ledger'] + 1} appended")

    # Lichen observe
    if not no_lichen:
        print(f"\n[{LICHEN}] Observing derby result...")
        _observe_lichen_derby(summary_path)

    return learnings


# ═══════════════════════════════════════════════════════════════════
# MODE: race  (was derby_round_robin.py)
# ═══════════════════════════════════════════════════════════════════

def _fib_steps(max_cycles: int) -> List[int]:
    """Fibonacci delta step sizes: 13, 8, 13, 21, 34, 55, 89, ..."""
    fibs = [13, 21]
    while fibs[-1] < max_cycles:
        fibs.append(fibs[-1] + fibs[-2])
    steps = [fibs[0]]
    for i in range(1, len(fibs)):
        steps.append(fibs[i] - fibs[i - 1])
    return steps


def _slot_for(profile: str, runner_index: int) -> int:
    """Deterministic collision-free slot from profile+index."""
    key = f"derby:{profile}:runner:{runner_index}"
    h = int(hashlib.sha256(key.encode()).hexdigest()[:8], 16)
    return 1000 + (h % 9000)


def _seed_runner(profile: str, slot: int) -> bool:
    """Seed a save slot from a profile."""
    result = run_seed(
        lane=ensure_lane(),
        timeout_s=120,
        profile=profile,
        slot=slot,
        reuse_listener=False,
    )
    return int(result.get("exit_code", 1)) in (0, 3)


def _run_chunk(
    runner: RunnerResult,
    max_cycles: int,
    console_profile: str,
    lane = None,
    strict: Optional[bool] = None,
) -> Dict[str, Any]:
    """Run a chunk of cycles for one runner."""
    extra_args = [
        "--save-slot-at-end", str(runner.slot),
        "--turn-start", str(runner.steps),
        "--json-only",
        "--reuse-listener",
    ]
    if strict is not None:
        extra_args.append("--strict-biome-economy" if strict else "--no-strict-biome-economy")

    proc = run_runner(
        lane=lane,
        timeout_s=max(120, max_cycles * 30),
        load_slot=runner.slot,
        max_loops=max_cycles,
        hunter_profile=runner.profile,
        hunter_policy="engine_policy",
        console_profile=console_profile,
        extra_args=extra_args,
    )
    summary = proc.get("summary", {})
    if not isinstance(summary, dict):
        summary = {}
    summary["_chunk_elapsed_s"] = float(proc.get("elapsed_s", 0.0) or 0.0)
    summary["_chunk_max_loops"] = max_cycles
    summary["_exit_code"] = int(proc.get("exit_code", -1) or -1)
    return summary


def cmd_race(args: argparse.Namespace) -> None:
    """🏁 Race mode: N runners, 1 profile, fibonacci interleaved rounds."""
    lane = ensure_lane()
    n_runners = max(2, min(5, args.runners))
    max_cycles = args.max_cycles
    win_threshold = min(args.win_threshold, n_runners)

    slots = [_slot_for(args.profile, i) for i in range(n_runners)]
    step_sizes = _fib_steps(max_cycles)

    cumulatives = []
    c = 0
    for s in step_sizes:
        c += s
        cumulatives.append(c)

    print(header(RACE, f"RACE: {args.profile}"))
    print(f"  {n_runners} runners x {max_cycles} max cycles")
    print(f"  Stop after {win_threshold} complete")
    print(f"  Fibonacci milestones: {cumulatives}")
    print(f"  Slots: {slots}")

    # Seed all runners
    print(f"\n  [{RUNNER}] Seeding {n_runners} save slots...")
    runners: List[RunnerResult] = []
    for i, slot in enumerate(slots):
        ok = _seed_runner(args.profile, slot)
        if not ok:
            print(f"  FAILED to seed slot {slot}!")
            sys.exit(1)
        r = RunnerResult(profile=args.profile, slot=slot, active=True)
        runners.append(r)
        print(f"  Runner {i+1} -> slot {slot}")

    # Round-robin
    t_start = time.time()

    for round_idx, step_size in enumerate(step_sizes):
        completed = sum(1 for r in runners if not r.active)
        if completed >= win_threshold:
            print(f"\n  {completed}/{n_runners} done — threshold met. Stopping.")
            break

        active = [r for r in runners if r.active]
        if not active:
            break

        for r in active:
            remaining = max_cycles - r.cycles
            if remaining <= 0:
                r.active = False
                r.exit_code = 1
                continue

            chunk_cycles = min(step_size, remaining)
            summary = _run_chunk(r, chunk_cycles, args.console_profile, lane, args.strict)

            loops_done = summary.get("loops_completed", 0)
            steps = summary.get("steps", 0)
            r.cycles += loops_done
            r.steps += steps
            r.elapsed_s += summary.get("_chunk_elapsed_s", 0)
            r.rounds += 1

            if summary.get("found_milk_pair", False):
                r.found_milk = True
                r.active = False
                print(f"  {RUNNER} Runner {runners.index(r)+1} found MILK "
                      f"at cycle {r.cycles}, step {r.steps}!")
            elif r.cycles >= max_cycles:
                r.active = False
                r.exit_code = 1
            elif summary.get("_exit_code", 0) != 0 and loops_done == 0:
                r.active = False
                r.exit_code = summary.get("_exit_code", 1)
                print(f"  {RUNNER} Runner {runners.index(r)+1} crashed "
                      f"(exit={r.exit_code})")

        print(format_scoreboard(runners, round_idx=round_idx, step_size=step_size))

    # Mark remaining active as failed
    for r in runners:
        if r.active:
            r.active = False
            r.exit_code = 1

    total_elapsed = time.time() - t_start

    # Results
    print(header(RACE, f"RESULTS: {args.profile}"))
    print(f"  Total time: {total_elapsed:.1f}s")

    milk_count = sum(1 for r in runners if r.found_milk)
    success_rate = milk_count / n_runners
    print(f"\n  Success: {milk_count}/{n_runners} ({success_rate:.0%})")

    milk_steps = [r.steps for r in runners if r.found_milk]
    if milk_steps:
        print(f"  Steps (winners): min={min(milk_steps)} "
              f"avg={sum(milk_steps)/len(milk_steps):.0f} max={max(milk_steps)}")

    print(format_scoreboard(runners, title="FINAL STANDINGS"))

    # Save report
    out_dir = BATCH_LOG_DIR
    out_dir.mkdir(parents=True, exist_ok=True)
    ts = time.strftime("%Y%m%d_%H%M%S")
    out_path = out_dir / f"race_{args.profile}_{ts}.json"
    report = make_envelope(
        LAYER_RACE,
        profile=args.profile,
        runners=[r.to_dict() for r in runners],
        scores={"success_rate": success_rate, "milk_count": milk_count},
        extra={
            "n_runners": n_runners,
            "max_cycles": max_cycles,
            "win_threshold": win_threshold,
            "total_elapsed_s": round(total_elapsed, 2),
        },
    )
    write_json(out_path, report)
    print(f"\n  Report: {out_path}")


# ═══════════════════════════════════════════════════════════════════
# MODE: duel  (was derby.py)
# ═══════════════════════════════════════════════════════════════════

def _run_lane(
    lane: str,
    lane_profiles: List[str],
    max_cycles: int,
    console_profile: str,
    hunter_policy: str,
    derby_dir: Path,
    lichen_params: Optional[Dict[str, Any]] = None,
    use_topology_gto: bool = False,
) -> List[RunnerResult]:
    """Run all runners for one lane sequentially on one isolated rig."""
    lane_ctx = ensure_lane(Path(f"/tmp/sw_derby_{lane}"))
    extra_env: Dict[str, str] = {}

    if lichen_params:
        extra_env["MILK_HUNT_POLICY_EPSILON"] = str(lichen_params.get("epsilon", 0.18))
        extra_env["MILK_HUNT_POLICY_UCB_SCALE"] = str(lichen_params.get("ucb_scale", 1.10))
        overlay = lichen_params.get("overlay_path", "")
        if overlay and Path(overlay).exists():
            extra_env["MILK_HUNT_POLICY_EXTRA_JSONL"] = overlay

    results: List[RunnerResult] = []

    for profile in lane_profiles:
        batch_output = derby_dir / lane / profile
        batch_output.mkdir(parents=True, exist_ok=True)

        extra_args: List[str] = ["--profile", profile]
        if use_topology_gto and lichen_params:
            extra_args.extend([
                "--topology-gto",
                "--base-policy-epsilon",   str(lichen_params.get("gto_epsilon", 0.18)),
                "--base-policy-ucb-scale", str(lichen_params.get("gto_ucb_scale", 1.10)),
                "--epsilon-jitter",        str(lichen_params.get("epsilon_jitter", 0.12)),
                "--ucb-octave-jitter",     str(lichen_params.get("ucb_octave_jitter", 0.45)),
            ])
        try:
            batch = run_batch(
                lane=lane_ctx,
                timeout_s=max(300, max_cycles * 30),
                runs=1,
                max_loops=max_cycles,
                hunter_profile=profile,
                hunter_policy=hunter_policy,
                runtime_profile="default",
                console_profile=console_profile,
                display_mode="headless",
                policy_execution_backend="auto",
                output_dir=batch_output,
                strict_biome_economy=True,
                reuse_listener=False,
                extra_args=extra_args,
                extra_env=extra_env,
            )
        except subprocess.TimeoutExpired:
            results.append(RunnerResult(
                profile=profile, lane=lane, elapsed_s=float(max_cycles), exit_code=-1))
            print(f"  [{LANE} {lane}] {profile}: TIMEOUT", flush=True)
            continue
        batch_summary: Dict[str, Any] = batch.get("batch_summary", {})

        result = RunnerResult.from_batch_summary(
            profile=profile,
            batch_summary=batch_summary,
            lane=lane,
            elapsed_s=float(batch.get("elapsed_s", 0.0) or 0.0),
            exit_code=int(batch.get("exit_code", -1) or -1),
        )
        results.append(result)

        milk_tag = "MILK!" if result.found_milk else f"exit={result.exit_code}"
        print(f"  [{LANE} {lane}] {profile}: {milk_tag}  "
              f"cycles={result.cycles}  steps={result.steps}  "
              f"{result.elapsed_s:.0f}s", flush=True)

    return results


def cmd_duel(args: argparse.Namespace) -> None:
    """🏆 Duel mode: 2+ lanes compete in parallel, each with N runners."""
    ctx = _setup_tissue(no_lichen=args.no_lichen)

    # Discover profiles per lane
    lane_profiles: Dict[str, List[str]] = {}
    for lane in args.lanes:
        profiles = list_derby_names(lane, args.runners_per_lane)
        if profiles:
            lane_profiles[lane] = profiles

    if not lane_profiles:
        print("No derby profiles found! Create config/world_state/derby_{lane}_{N}.json first.")
        sys.exit(1)

    n_runners = sum(len(p) for p in lane_profiles.values())

    print(header(DERBY, "DUEL: " + " vs ".join(
        f"{lane.upper()} ({len(ps)})" for lane, ps in lane_profiles.items())))
    print(f"  {len(lane_profiles)} lanes in parallel (1 rig each)")
    print(f"  {n_runners} runners total, {args.max_cycles} max cycles")
    print(f"  policy={args.hunter_policy}")

    ts = time.strftime("%Y%m%d_%H%M%S")
    derby_dir = LOG_DIR / f"derby_{ts}"
    derby_dir.mkdir(parents=True, exist_ok=True)

    # Write overlay files
    if ctx["combined_overlay_ops"]:
        for lane in lane_profiles:
            overlay_path = derby_dir / f"tissue_overlay_{lane}.jsonl"
            _write_overlay_jsonl(ctx["combined_overlay_ops"], overlay_path)
            ctx["lichen_params"]["overlay_path"] = str(overlay_path)

    t_total = time.time()

    # Launch lanes in parallel
    all_runners: List[RunnerResult] = []
    lane_results: Dict[str, List[RunnerResult]] = {}

    with ProcessPoolExecutor(max_workers=len(lane_profiles)) as pool:
        futures = {}
        for lane, profiles in lane_profiles.items():
            lp = dict(ctx["lichen_params"])
            overlay_path = derby_dir / f"tissue_overlay_{lane}.jsonl"
            if overlay_path.exists():
                lp["overlay_path"] = str(overlay_path)
            fut = pool.submit(
                _run_lane,
                lane=lane, lane_profiles=profiles,
                max_cycles=args.max_cycles,
                console_profile=args.console_profile,
                hunter_policy=args.hunter_policy,
                derby_dir=derby_dir,
                lichen_params=lp,
                use_topology_gto=args.use_topology_gto,
            )
            futures[fut] = lane

        for fut in as_completed(futures):
            lane = futures[fut]
            try:
                results = fut.result()
            except Exception as exc:
                results = []
                print(f"  [{LANE} {lane}] FAILED: {exc}", flush=True)
            lane_results[lane] = results
            all_runners.extend(results)
            milk = sum(1 for r in results if r.found_milk)
            print(f"\n  [{LANE} {lane}] DONE: {milk}/{len(results)} found milk",
                  flush=True)

    total_elapsed = time.time() - t_total

    # Score lanes
    scoring_weights = ctx["scoring_weights"]
    ls: Dict[str, Dict[str, Any]] = {}
    for lane, results in lane_results.items():
        ls[lane] = score_lane(results, scoring_weights)

    # Determine winner
    winner = None
    if len(ls) == 2:
        lanes = sorted(ls.keys())
        a, b = lanes
        sa, sb = ls[a]["composite"], ls[b]["composite"]
        if sa > sb:
            winner = a.upper()
        elif sb > sa:
            winner = b.upper()
        else:
            winner = "TIE"

    # Print results
    all_runners.sort(key=lambda r: (not r.found_milk, r.steps))
    print(header(DERBY, f"RESULTS ({total_elapsed:.0f}s)"))
    print(format_scoreboard(all_runners, title="ALL RUNNERS", show_scores=True,
                            weights=scoring_weights))
    print(format_lane_scores(ls, winner))

    # Tissue learning
    learnings = _finish_tissue(all_runners, ctx, derby_dir / "derby_summary.json",
                               no_lichen=args.no_lichen)

    # Save summary
    summary = make_envelope(
        LAYER_DUEL,
        runners=[r.to_dict() for r in all_runners],
        lane_scores=ls,
        winner=winner,
        learnings=learnings,
        extra={
            "total_elapsed_s": round(total_elapsed, 1),
            "max_cycles": args.max_cycles,
            "hunter_policy": args.hunter_policy,
            "tissue_ledger_size": ctx["n_ledger"] + 1,
        },
    )
    summary_path = derby_dir / "derby_summary.json"
    write_json(summary_path, summary)
    print(f"\n  Report: {summary_path}")
    print("=" * 64)


# ═══════════════════════════════════════════════════════════════════
# MODE: matrix  (was milk_hunt_matrix.py + derby_rr_matrix.py)
# ═══════════════════════════════════════════════════════════════════

def cmd_matrix(args: argparse.Namespace) -> None:
    """📊 Matrix mode: batch comparison across multiple profiles."""
    lane = ensure_lane()
    # Resolve profile list
    if args.profiles.strip() == "derby_*":
        profile_names = []
        for lane in list_derby_lanes():
            profile_names.extend(list_derby_names(lane))
    elif "*" in args.profiles:
        import fnmatch
        pattern = args.profiles.strip()
        profile_names = [n for n in list_names() if fnmatch.fnmatch(n, pattern)]
    else:
        profile_names = [p.strip() for p in args.profiles.split(",") if p.strip()]

    if not profile_names:
        print("No profiles matched!")
        sys.exit(1)

    print(header(BATCH, f"MATRIX: {len(profile_names)} profiles x {args.runs} runs"))
    for name in profile_names:
        print(f"  {RUNNER} {name}")

    ts = time.strftime("%Y%m%d_%H%M%S")
    matrix_dir = BATCH_LOG_DIR / f"matrix_{ts}"
    matrix_dir.mkdir(parents=True, exist_ok=True)

    t_total = time.time()
    results: List[Dict[str, Any]] = []

    for profile in profile_names:
        batch_output = matrix_dir / profile
        batch_output.mkdir(parents=True, exist_ok=True)

        print(f"\n  [{BATCH}] Running {profile} ({args.runs} runs)...")
        batch = run_batch(
            lane=lane,
            timeout_s=max(600, args.max_cycles * 30 * args.runs),
            runs=args.runs,
            max_loops=args.max_cycles,
            hunter_profile=profile,
            hunter_policy="engine_policy",
            runtime_profile="default",
            console_profile=args.console_profile,
            display_mode="headless",
            policy_execution_backend="auto",
            output_dir=batch_output,
            strict_biome_economy=True,
            reuse_listener=False,
            extra_args=["--profile", profile],
        )
        batch_summary: Dict[str, Any] = batch.get("batch_summary", {})

        runner = RunnerResult.from_batch_summary(
            profile=profile,
            batch_summary=batch_summary,
            elapsed_s=float(batch.get("elapsed_s", 0.0) or 0.0),
            exit_code=int(batch.get("exit_code", -1) or -1),
        )
        scores = runner.scores_dict()
        results.append({
            "profile": profile,
            "elapsed_s": round(elapsed, 2),
            "scores": scores,
        })
        print(f"  [{BATCH}] {profile}: SR={scores['success_rate']:.0%}  "
              f"composite={scores['composite']:.4f}  ({elapsed:.0f}s)")

    total_elapsed = time.time() - t_total

    # Leaderboard
    results.sort(key=lambda r: r["scores"]["composite"], reverse=True)
    print(header(BATCH, f"LEADERBOARD ({total_elapsed:.0f}s)"))
    print(f"  {'#':<3} {'Profile':<28} {'SR':>5} {'Speed':>6} {'Biome':>6} "
          f"{'Vocab':>6} {'Score':>7}")
    print("  " + "-" * 62)
    for i, r in enumerate(results):
        s = r["scores"]
        print(f"  {i+1:<3} {r['profile']:<28} {s['success_rate']:.0%} "
              f"{s['speed_score']:>6.2f} {s['biome_score']:>6.2f} "
              f"{s['vocab_score']:>6.2f} {s['composite']:>7.4f}")

    # Save summary
    summary = make_envelope(
        LAYER_MATRIX,
        extra={
            "total_elapsed_s": round(total_elapsed, 1),
            "n_profiles": len(profile_names),
            "runs_per_profile": args.runs,
            "max_cycles": args.max_cycles,
            "results": results,
        },
    )
    summary_path = matrix_dir / "matrix_summary.json"
    write_json(summary_path, summary)
    print(f"\n  Report: {summary_path}")
    print("=" * 64)


# ═══════════════════════════════════════════════════════════════════
# CLI entry point
# ═══════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(
        description="Arena: unified SpaceWheat competition runner",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""modes:
  race    Race N runners on 1 profile with fibonacci scheduling
  duel    Head-to-head: 2+ lanes compete in parallel
  matrix  Batch comparison across multiple profiles

Graph Tissue™ is a trademark of Luke Spooner.""",
    )
    sub = parser.add_subparsers(dest="mode", required=True)

    # ── race ────────────────────────────────────────────────────────
    p_race = sub.add_parser("race", help="Round-robin race on one profile")
    p_race.add_argument("--profile", required=True, help="Profile name")
    p_race.add_argument("--runners", type=int, default=5, help="Number of runners (2-5)")
    p_race.add_argument("--max-cycles", type=int, default=220,
                        help="Max cycles per runner (default: 220)")
    p_race.add_argument("--win-threshold", type=int, default=4,
                        help="Stop after N runners complete (default: 4)")
    p_race.add_argument("--console-profile", default="quiet",
                        choices=["quiet", "normal", "debug", "trace", "test"])
    p_race.add_argument("--strict", type=bool, default=None)

    # ── duel ────────────────────────────────────────────────────────
    p_duel = sub.add_parser("duel", help="Head-to-head lane competition")
    p_duel.add_argument("--lanes", nargs="+", default=["sonnet", "codex"],
                        help="Lane names (default: sonnet codex)")
    p_duel.add_argument("--runners-per-lane", type=int, default=5)
    p_duel.add_argument("--max-cycles", type=int, default=220)
    p_duel.add_argument("--hunter-policy", default="engine_policy",
                        choices=["auto", "classic", "quantum_graph",
                                 "engine_policy", "quantum_register"])
    p_duel.add_argument("--console-profile", default="quiet",
                        choices=["quiet", "normal", "debug", "trace", "test"])
    p_duel.add_argument("--use-topology-gto", action="store_true")
    p_duel.add_argument("--no-lichen", action="store_true")

    # ── matrix ──────────────────────────────────────────────────────
    p_matrix = sub.add_parser("matrix", help="Batch comparison across profiles")
    p_matrix.add_argument("--profiles", required=True,
                          help="Comma-separated or glob pattern (e.g. 'derby_*')")
    p_matrix.add_argument("--runs", type=int, default=3)
    p_matrix.add_argument("--max-cycles", type=int, default=220)
    p_matrix.add_argument("--console-profile", default="quiet",
                          choices=["quiet", "normal", "debug", "trace", "test"])

    args = parser.parse_args()

    if args.mode == "race":
        cmd_race(args)
    elif args.mode == "duel":
        cmd_duel(args)
    elif args.mode == "matrix":
        cmd_matrix(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
