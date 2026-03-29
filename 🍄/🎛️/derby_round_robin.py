#!/usr/bin/env python3
"""Round-robin derby batch: time-division multiplexed milk hunt.

One rig, 5 runners, interleaved turns with growing step sizes.
Each runner gets its own save slot (hashed from profile+index to avoid
collisions when multiple derbies run concurrently).

Step sizes: 13 (warm-up), then fibonacci escalation: 8, 13, 21, 34
As soon as 4+ runners complete (milk found or max loops), we stop.
No extensions after that — the 5th either finished or didn't.

Graph Tissue™ is a trademark of Luke Spooner.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional

from run_executor import ensure_lane, run_runner, run_seed

HERE = Path(__file__).resolve().parent

def _fib_steps(max_loops: int) -> list[int]:
    """Generate round step sizes from fibonacci cumulative targets.

    Fibonacci sequence starting at 13: 13, 21, 34, 55, 89, 144, 233, ...
    Step sizes are the DELTAS:          13,  8, 13, 21, 34,  55,  89, ...
    So each round brings everyone to the next fibonacci milestone.
    """
    # Generate fibonacci targets starting at 13, 21
    fibs = [13, 21]
    while fibs[-1] < max_loops:
        fibs.append(fibs[-1] + fibs[-2])
    # Convert to deltas (step sizes per round)
    steps = [fibs[0]]  # first round = 13
    for i in range(1, len(fibs)):
        steps.append(fibs[i] - fibs[i - 1])
    return steps


def _slot_for(profile: str, runner_index: int) -> int:
    """Deterministic high slot number from profile+index.

    Uses hash to avoid collisions between concurrent derbies.
    Range: 100-999 (well above manual save slots 0-20).
    """
    key = f"derby:{profile}:runner:{runner_index}"
    h = int(hashlib.sha256(key.encode()).hexdigest()[:8], 16)
    return 1000 + (h % 9000)  # 1000-9999


@dataclass
class RunnerState:
    index: int  # 0-4
    slot: int  # save slot
    profile: str
    loops_done: int = 0
    steps_done: int = 0
    found_milk: bool = False
    failed: bool = False  # exhausted max_loops without finding milk
    active: bool = True
    summaries: List[Dict[str, Any]] = field(default_factory=list)
    total_elapsed_s: float = 0.0


def seed_runner(profile: str, slot: int, lane) -> bool:
    """Seed a save slot from a profile.

    Note: milk_hunt_seed_save.py does NOT accept --console-profile.
    """
    result = run_seed(
        lane=lane,
        timeout_s=120,
        profile=profile,
        slot=slot,
        reuse_listener=False,
    )
    # Exit 0 = saved, 3 = seeded (no prior save existed) — both are success
    return int(result.get("exit_code", 1)) in (0, 3)


def run_chunk(
    runner: RunnerState,
    max_loops: int,
    total_max_loops: int,
    args: argparse.Namespace,
    lane,
) -> Dict[str, Any]:
    """Run a chunk of loops for one runner, save state back to its slot."""
    extra_args = [
        "--save-slot-at-end", str(runner.slot),
        "--turn-start", str(runner.steps_done),
        "--json-only",
        "--reuse-listener",
    ]
    if args.strict is not None:
        extra_args.append("--strict-biome-economy" if args.strict else "--no-strict-biome-economy")

    t0 = time.time()
    result = run_runner(
        lane=lane,
        timeout_s=max(120, max_loops * 30),
        max_loops=max_loops,
        load_slot=runner.slot,
        hunter_profile=runner.profile,
        hunter_policy="engine_policy",
        console_profile=args.console_profile or "quiet",
        extra_args=extra_args,
    )
    elapsed = time.time() - t0

    # Parse JSON summary from stdout
    summary = result.get("summary", {}) or {}

    summary["_chunk_elapsed_s"] = round(elapsed, 2)
    summary["_chunk_max_loops"] = max_loops
    summary["_exit_code"] = int(result.get("exit_code", 1))
    return summary


def print_scoreboard(runners: List[RunnerState], round_idx: int, step_size: int):
    """Print current standings."""
    active = sum(1 for r in runners if r.active)
    done = sum(1 for r in runners if not r.active)
    print(f"\n  ── Round {round_idx + 1} (step={step_size}) ── active={active} done={done}")
    print(f"  {'#':<3} {'Slot':<5} {'Loops':>6} {'Steps':>6} {'Status':<10} {'Time':>7}")
    for r in runners:
        if r.found_milk:
            status = "MILK!"
        elif r.failed:
            status = "exhaust"
        elif not r.active:
            status = "stopped"
        else:
            status = "running"
        print(f"  {r.index+1:<3} {r.slot:<5} {r.loops_done:>6} {r.steps_done:>6} {status:<10} {r.total_elapsed_s:>6.1f}s")


def main():
    parser = argparse.ArgumentParser(description="Round-robin derby batch")
    parser.add_argument("--profile", required=True, help="Profile name")
    parser.add_argument("--runners", type=int, default=5, help="Number of runners (2-5)")
    parser.add_argument("--max-loops", type=int, default=220, help="Max total loops per runner")
    parser.add_argument("--win-threshold", type=int, default=4,
                        help="Stop after this many runners complete (default: 4)")
    parser.add_argument("--console-profile", default="quiet",
                        choices=["quiet", "normal", "debug", "trace", "test"])
    parser.add_argument("--strict", type=bool, default=None)
    parser.add_argument("--output", type=str, default=None,
                        help="Output JSON path (default: auto)")
    args = parser.parse_args()
    lane = ensure_lane()

    n_runners = max(2, min(5, args.runners))
    win_threshold = min(args.win_threshold, n_runners)

    # Compute collision-free slots for this profile
    slots = [_slot_for(args.profile, i) for i in range(n_runners)]

    step_sizes = _fib_steps(args.max_loops)

    # Show fibonacci cumulative targets
    cumulatives = []
    c = 0
    for s in step_sizes:
        c += s
        cumulatives.append(c)

    print("=" * 60)
    print(f"  ROUND-ROBIN DERBY: {args.profile}")
    print(f"  {n_runners} runners × {args.max_loops} max loops")
    print(f"  Stop after {win_threshold} complete")
    print(f"  Fibonacci milestones: {cumulatives}")
    print(f"  Step deltas:          {step_sizes}")
    print(f"  Slots: {slots} (hashed, collision-free)")
    print("=" * 60)

    # Phase 1: Seed all runners
    print(f"\n[seed] Seeding {n_runners} save slots...")
    runners: List[RunnerState] = []
    for i, slot in enumerate(slots):
        ok = seed_runner(args.profile, slot, lane)
        if not ok:
            print(f"  FAILED to seed slot {slot}!")
            sys.exit(1)
        runners.append(RunnerState(index=i, slot=slot, profile=args.profile))
        print(f"  Runner {i+1} → slot {slot} ✓")

    # Phase 2: Round-robin
    print(f"\n[race] Starting round-robin...")
    t_race_start = time.time()

    for round_idx, step_size in enumerate(step_sizes):
        # Check completion threshold
        completed = sum(1 for r in runners if not r.active)
        if completed >= win_threshold:
            print(f"\n  {completed}/{n_runners} runners done — threshold {win_threshold} met. Stopping.")
            break

        # Check if all runners are done
        active_runners = [r for r in runners if r.active]
        if not active_runners:
            break

        # Run each active runner for step_size loops
        for r in active_runners:
            remaining = args.max_loops - r.loops_done
            if remaining <= 0:
                r.failed = True
                r.active = False
                continue

            chunk_loops = min(step_size, remaining)
            summary = run_chunk(r, chunk_loops, args.max_loops, args, lane)

            # Update runner state from summary
            loops_completed = summary.get("loops_completed", 0)
            steps = summary.get("steps", 0)
            r.loops_done += loops_completed
            r.steps_done += steps
            r.total_elapsed_s += summary.get("_chunk_elapsed_s", 0)
            r.summaries.append(summary)

            if summary.get("found_milk_pair", False):
                r.found_milk = True
                r.active = False
                print(f"  Runner {r.index+1} found MILK at loop {r.loops_done}, step {r.steps_done}!")
            elif r.loops_done >= args.max_loops:
                r.failed = True
                r.active = False
            elif summary.get("_exit_code", 0) != 0 and loops_completed == 0:
                # Runner crashed without progress — mark failed
                r.failed = True
                r.active = False
                print(f"  Runner {r.index+1} crashed (exit={summary.get('_exit_code')})")

        print_scoreboard(runners, round_idx, step_size)

    # Final check — any remaining active runners get marked
    for r in runners:
        if r.active:
            r.failed = True
            r.active = False

    total_elapsed = time.time() - t_race_start

    # Phase 3: Results
    print(f"\n{'=' * 60}")
    print(f"  RESULTS: {args.profile}")
    print(f"  Total time: {total_elapsed:.1f}s")
    print(f"{'=' * 60}")

    milk_count = sum(1 for r in runners if r.found_milk)
    fail_count = sum(1 for r in runners if r.failed)
    success_rate = milk_count / n_runners

    print(f"\n  Success: {milk_count}/{n_runners} ({success_rate:.0%})")

    milk_steps = [r.steps_done for r in runners if r.found_milk]
    if milk_steps:
        print(f"  Steps (winners): min={min(milk_steps)} avg={sum(milk_steps)/len(milk_steps):.0f} max={max(milk_steps)}")

    for r in runners:
        tag = "MILK!" if r.found_milk else "FAIL"
        print(f"  Runner {r.index+1}: {tag:5s}  loops={r.loops_done:3d}  steps={r.steps_done:3d}  time={r.total_elapsed_s:.1f}s  rounds={len(r.summaries)}")

    # Save report
    report = {
        "profile": args.profile,
        "n_runners": n_runners,
        "max_loops": args.max_loops,
        "win_threshold": win_threshold,
        "success_rate": success_rate,
        "milk_count": milk_count,
        "total_elapsed_s": round(total_elapsed, 2),
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "runners": [
            {
                "index": r.index,
                "slot": r.slot,
                "found_milk": r.found_milk,
                "failed": r.failed,
                "loops_done": r.loops_done,
                "steps_done": r.steps_done,
                "elapsed_s": round(r.total_elapsed_s, 2),
                "n_rounds": len(r.summaries),
            }
            for r in runners
        ],
    }

    out_dir = HERE / "logs" / "milk_batches"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = Path(args.output) if args.output else out_dir / f"rr_{args.profile}_{time.strftime('%Y%m%d_%H%M%S')}.json"
    out_path.write_text(json.dumps(report, indent=2) + "\n")
    print(f"\n  Report: {out_path}")
    print("=" * 60)


if __name__ == "__main__":
    main()
