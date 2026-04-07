#!/usr/bin/env python3
"""
gate_architect_batch.py — Multi-run gate sweep orchestrator

Runs gate_architect_runner.py multiple times across different save slots,
biomes, or with different evolution-rate settings.  Aggregates coverage
reports and identifies which gates are consistently effective.

Usage:
    python3 gate_architect_batch.py [options]

    --runs N            Number of independent runs (default: 3)
    --load-slot N       Save slot to use for all runs (default: 0)
    --biome NAME        Biome to sweep (default: StarterForest)
    --evolve-phrames N  Physics frames per gate evolution step (default: 45)
    --output-dir PATH   Base directory for results (default: /tmp/gate_architect_batches)
    --skip-2q           Skip 2-qubit gates in all runs
    --skip-entangled    Skip entangled state prep in all runs

Report at end:
  - Which gate types succeeded across all runs
  - Which qubits are most affected by each gate family
  - Variance in purity changes across runs
  - Coverage percentage for 1Q, 2Q, entangled gate types
"""

import argparse
import datetime
import json
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

from run_executor import ensure_lane, run_cli

SCRIPT_DIR = Path(__file__).resolve().parent
RUNNER = SCRIPT_DIR / "gate_architect_runner.py"


# ── Run a single gate_architect_runner subprocess ────────────────────────────

def _run_once(
    run_idx: int,
    lane: str,
    run_dir: Path,
    load_slot: int,
    biome: str,
    evolve_phrames: int,
    skip_2q: bool,
    skip_entangled: bool,
) -> dict[str, Any]:
    """Invoke gate_architect_runner.py in a subprocess. Return its summary dict."""
    run_dir.mkdir(parents=True, exist_ok=True)

    cmd = [
        sys.executable, str(RUNNER),
        "--load-slot", str(load_slot),
        "--biome", biome,
        "--evolve-phrames", str(evolve_phrames),
        "--output-dir", str(run_dir),
    ]
    if skip_2q:
        cmd.append("--skip-2q")
    if skip_entangled:
        cmd.append("--skip-entangled")

    print(f"[batch] run {run_idx:03d} start — {biome} slot={load_slot}", flush=True)
    t0 = time.time()
    proc = run_cli(cmd, lane=lane, capture_output=True, timeout_s=600)
    elapsed = time.time() - t0

    stdout = proc.stdout or ""
    stderr = proc.stderr or ""

    # Last non-empty line of stdout is the JSON summary
    summary = {"ok": False, "error": "no_stdout"}
    for line in reversed(stdout.splitlines()):
        line = line.strip()
        if line.startswith("{"):
            try:
                summary = json.loads(line)
                break
            except json.JSONDecodeError:
                continue

    summary["run_idx"] = run_idx
    summary["elapsed_s"] = round(elapsed, 2)
    summary["exit_code"] = proc.returncode

    # Save raw output for debugging
    (run_dir / "stdout.log").write_text(stdout, encoding="utf-8")
    if stderr:
        (run_dir / "stderr.log").write_text(stderr, encoding="utf-8")

    status = "✓" if summary.get("ok") else "✗"
    covered = summary.get("gates_ok", "?")
    total = summary.get("total_gate_ops", "?")
    print(f"[batch] run {run_idx:03d} {status} — {covered}/{total} gates ok "
          f"in {elapsed:.1f}s", flush=True)

    return summary


# ── Aggregate analysis ────────────────────────────────────────────────────────

def _aggregate(run_summaries: list[dict]) -> dict:
    """Compute cross-run statistics."""
    ok_runs = [r for r in run_summaries if r.get("ok")]
    if not ok_runs:
        return {"ok": False, "error": "no_successful_runs"}

    # Gate coverage: which gates succeeded in ALL runs
    gate_type_counts: dict[str, int] = {}
    for run in ok_runs:
        for g in run.get("gate_types_covered", []):
            gate_type_counts[g] = gate_type_counts.get(g, 0) + 1

    n = len(ok_runs)
    always_covered = [g for g, cnt in gate_type_counts.items() if cnt == n]
    sometimes_covered = [g for g, cnt in gate_type_counts.items() if cnt < n]

    # Purity change stats
    purity_changes = [r.get("avg_purity_change_per_gate", 0.0) for r in ok_runs]
    mean_purity_change = sum(purity_changes) / len(purity_changes) if purity_changes else 0.0

    # Top movers across all runs
    all_movers: list[dict] = []
    for run in ok_runs:
        all_movers.extend(run.get("top_population_movers", []))

    # Rank gates by mean max_shift
    mover_by_gate: dict[str, list[float]] = {}
    for m in all_movers:
        g = m.get("gate", "?")
        s = float(m.get("max_shift", 0.0))
        mover_by_gate.setdefault(g, []).append(s)
    gate_effectiveness = {
        g: round(sum(vs) / len(vs), 5)
        for g, vs in sorted(mover_by_gate.items(), key=lambda x: -sum(x[1]) / max(len(x[1]), 1))
    }

    # Coverage percentages
    from gate_architect_runner import GATES_1Q, GATES_2Q, GATES_ENTANGLED
    all_gate_types = set(GATES_1Q + GATES_2Q + GATES_ENTANGLED)
    n_gates_always = len(always_covered)
    coverage_pct = round(100 * n_gates_always / len(all_gate_types))

    return {
        "ok": True,
        "runs_attempted": len(run_summaries),
        "runs_ok": n,
        "gate_types_always_covered": sorted(always_covered),
        "gate_types_sometimes_covered": sorted(sometimes_covered),
        "gate_types_never_covered": sorted(all_gate_types - set(gate_type_counts.keys())),
        "coverage_pct_all_runs": coverage_pct,
        "mean_purity_change_per_gate": round(mean_purity_change, 6),
        "gate_effectiveness_rank": gate_effectiveness,
        "runs": [
            {
                "run_idx": r["run_idx"],
                "ok": r.get("ok"),
                "elapsed_s": r.get("elapsed_s"),
                "gates_ok": r.get("gates_ok"),
                "total_gate_ops": r.get("total_gate_ops"),
                "coverage_1q": r.get("coverage_pct_1q"),
                "coverage_2q": r.get("coverage_pct_2q"),
            }
            for r in run_summaries
        ],
    }


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="Gate Architect Batch")
    parser.add_argument("--runs", type=int, default=3)
    parser.add_argument("--load-slot", type=int, default=0)
    parser.add_argument("--biome", default="StarterForest")
    parser.add_argument("--evolve-phrames", type=int, default=45)
    parser.add_argument("--output-dir", type=Path,
                        default=Path("/tmp/gate_architect_batches"))
    parser.add_argument("--skip-2q", action="store_true")
    parser.add_argument("--skip-entangled", action="store_true")
    args = parser.parse_args()

    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    batch_dir = args.output_dir / f"batch_{ts}"
    batch_dir.mkdir(parents=True, exist_ok=True)

    print(f"[batch] Gate Architect Batch — {args.runs} runs", flush=True)
    print(f"[batch] Biome: {args.biome}  Slot: {args.load_slot}", flush=True)
    print(f"[batch] Output: {batch_dir}", flush=True)

    lane = ensure_lane()
    run_summaries = []

    for run_idx in range(args.runs):
        run_dir = batch_dir / f"run_{run_idx:03d}"
        summary = _run_once(
            run_idx=run_idx,
            lane=lane,
            run_dir=run_dir,
            load_slot=args.load_slot,
            biome=args.biome,
            evolve_phrames=args.evolve_phrames,
            skip_2q=args.skip_2q,
            skip_entangled=args.skip_entangled,
        )
        run_summaries.append(summary)
        (run_dir / "run_summary.json").write_text(
            json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8"
        )

    aggregated = _aggregate(run_summaries)
    aggregated["batch_dir"] = str(batch_dir)
    aggregated["biome"] = args.biome
    aggregated["timestamp"] = ts

    batch_summary_path = batch_dir / "batch_summary.json"
    batch_summary_path.write_text(
        json.dumps(aggregated, indent=2, ensure_ascii=False), encoding="utf-8"
    )

    print("\n── Batch Summary ──────────────────────────────────────────────")
    print(f"  Runs OK:         {aggregated['runs_ok']} / {aggregated['runs_attempted']}")
    print(f"  Coverage:        {aggregated['coverage_pct_all_runs']}%")
    print(f"  Always covered:  {aggregated['gate_types_always_covered']}")
    if aggregated.get("gate_types_never_covered"):
        print(f"  Never covered:   {aggregated['gate_types_never_covered']}")
    print(f"  Top gates:       {list(aggregated['gate_effectiveness_rank'].items())[:5]}")
    print(f"  Results:         {batch_summary_path}")
    print("───────────────────────────────────────────────────────────────\n")


if __name__ == "__main__":
    main()
