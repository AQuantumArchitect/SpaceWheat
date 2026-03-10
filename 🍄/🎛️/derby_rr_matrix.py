#!/usr/bin/env python3
"""Round-robin derby matrix: run all 10 derby characters via round-robin batches.

Runs derby_round_robin.py for each profile sequentially.
Each profile gets 5 runners interleaved with fibonacci step growth.
Stop each batch after 4 runners complete.

Then score all profiles head-to-head and extract Graph Tissue™ learnings.

Graph Tissue™ is a trademark of Luke Spooner.
"""
from __future__ import annotations

import json
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict, List

HERE = Path(__file__).resolve().parent
CONFIG_WS = HERE / "config" / "world_state"
CONFIG_PW = HERE / "config" / "policy_weights"
LOG_DIR = HERE / "logs" / "milk_batches"


def score_result(report: Dict[str, Any]) -> Dict[str, float]:
    sr = float(report.get("success_rate", 0))
    runners = report.get("runners", [])
    milk_steps = [r["steps_done"] for r in runners if r.get("found_milk")]
    avg_steps = sum(milk_steps) / len(milk_steps) if milk_steps else 999
    speed = max(0, 1.0 - avg_steps / 300.0)
    efficiency = sum(1 for r in runners if r.get("found_milk") and r["loops_done"] < 100) / max(1, len(runners))
    return {
        "success_rate": sr,
        "speed_score": round(speed, 4),
        "efficiency": round(efficiency, 4),
        "composite": round(0.50 * sr + 0.30 * speed + 0.20 * efficiency, 4),
        "avg_steps_winners": round(avg_steps, 1),
    }


def main():
    profiles = []
    for i in range(1, 6):
        for lane in ("sonnet", "codex"):
            name = f"derby_{lane}_{i}"
            if (CONFIG_WS / f"{name}.json").exists():
                profiles.append(name)

    if not profiles:
        print("No derby profiles found! Run lane agents first.")
        sys.exit(1)

    print("=" * 64)
    print("  ROUND-ROBIN DERBY MATRIX")
    print(f"  {len(profiles)} profiles × 5 runners (fibonacci steps)")
    print("  Graph Tissue™ is a trademark of Luke Spooner")
    print("=" * 64)

    LOG_DIR.mkdir(parents=True, exist_ok=True)
    ts = time.strftime("%Y%m%d_%H%M%S")
    matrix_dir = LOG_DIR / f"rr_matrix_{ts}"
    matrix_dir.mkdir(parents=True, exist_ok=True)

    results: List[Dict[str, Any]] = []
    t_total = time.time()

    for pi, profile in enumerate(profiles):
        print(f"\n[{pi+1}/{len(profiles)}] {profile}")
        out_path = matrix_dir / f"{profile}.json"

        cmd = [
            sys.executable, str(HERE / "derby_round_robin.py"),
            "--profile", profile,
            "--runners", "5",
            "--max-loops", "220",
            "--win-threshold", "4",
            "--console-profile", "quiet",
            "--output", str(out_path),
        ]

        t0 = time.time()
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=1800)
        elapsed = time.time() - t0

        if out_path.exists():
            report = json.loads(out_path.read_text())
        else:
            report = {"profile": profile, "success_rate": 0, "runners": [], "error": proc.stderr[-300:] if proc.stderr else "no output"}

        lane = "sonnet" if "sonnet" in profile else "codex"
        scores = score_result(report)
        results.append({
            "profile": profile,
            "lane": lane,
            "elapsed_s": round(elapsed, 1),
            "report": report,
            "scores": scores,
        })
        sr = report.get("success_rate", 0)
        print(f"  → {sr:.0%} success, {scores['composite']:.4f} composite ({elapsed:.0f}s)")

    total_elapsed = time.time() - t_total

    # Leaderboard
    results.sort(key=lambda r: r["scores"]["composite"], reverse=True)
    print(f"\n{'=' * 64}")
    print(f"  LEADERBOARD ({total_elapsed:.0f}s total)")
    print(f"{'=' * 64}")
    print(f"\n  {'#':<3} {'Character':<26} {'Lane':<8} {'SR':>5} {'Speed':>6} {'Score':>7}")
    print("  " + "-" * 56)
    for i, r in enumerate(results):
        s = r["scores"]
        print(f"  {i+1:<3} {r['profile']:<26} {r['lane']:<8} {s['success_rate']:5.0%} {s['speed_score']:6.2f} {s['composite']:7.4f}")

    # Lane totals
    sonnet = sum(r["scores"]["composite"] for r in results if r["lane"] == "sonnet")
    codex = sum(r["scores"]["composite"] for r in results if r["lane"] == "codex")
    print(f"\n  SONNET: {sonnet:.4f}")
    print(f"  CODEX:  {codex:.4f}")
    winner = "SONNET" if sonnet > codex else "CODEX" if codex > sonnet else "TIE"
    print(f"  WINNER: {winner} (+{abs(sonnet - codex):.4f})")

    # Extract tissue learnings
    top3_pw = []
    for r in results[:3]:
        pw_path = CONFIG_PW / f"{r['profile']}.json"
        if pw_path.exists():
            top3_pw.append({"profile": r["profile"], "weights": json.loads(pw_path.read_text())})

    # Save matrix summary
    summary = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "total_elapsed_s": round(total_elapsed, 1),
        "results": [{k: v for k, v in r.items() if k != "report"} for r in results],
        "lane_totals": {"sonnet": round(sonnet, 4), "codex": round(codex, 4), "winner": winner},
        "top3_tissue": top3_pw,
    }
    summary_path = matrix_dir / "matrix_summary.json"
    summary_path.write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n")
    print(f"\n  Report: {summary_path}")
    print("=" * 64)


if __name__ == "__main__":
    main()
