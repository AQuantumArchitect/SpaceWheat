#!/usr/bin/env python3
import argparse
import json
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List

from constants import MAX_LOOPS, DEFAULT_RUNS_PER_PROFILE
from milk_hunt_io import write_json
from run_executor import ensure_lane, run_batch

def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run milk hunt batches across multiple profiles")
    parser.add_argument(
        "--profiles",
        type=str,
        required=True,
        help="Comma-separated profile names",
    )
    parser.add_argument("--runs", type=int, default=DEFAULT_RUNS_PER_PROFILE, help="Runs per profile")
    parser.add_argument("--max-loops", type=int, default=MAX_LOOPS, help="Max offer cycles per run")
    parser.add_argument(
        "--console-profile",
        choices=["quiet", "normal", "debug", "trace", "test"],
        default=None,
        help="Batch + runner console verbosity profile",
    )
    parser.add_argument(
        "--profile-save-index",
        type=str,
        default=None,
        help="Optional profile-save registry index path passed to batch runs",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parent / "logs/milk_batches",
        help="Directory for logs and summaries",
    )
    return parser


def _run_profile(
    profile: str,
    runs: int,
    max_loops: int,
    output_dir: Path,
    lane,
    profile_save_index: str | None = None,
    console_profile: str | None = None,
) -> Dict[str, Any]:
    extra_args: List[str] = ["--profile", profile]
    if profile_save_index:
        extra_args.extend(["--profile-save-index", profile_save_index])
    batch = run_batch(
        lane=lane,
        timeout_s=400,
        runs=runs,
        max_loops=max_loops,
        hunter_profile=profile,
        hunter_policy="engine_policy",
        runtime_profile="io_min",
        console_profile=console_profile or "quiet",
        display_mode="headless",
        policy_execution_backend="direct",
        output_dir=output_dir,
        strict_biome_economy=True,
        reuse_listener=False,
        extra_args=extra_args,
    )
    summary: Dict[str, Any] = {
        "profile": profile,
        "exit_code": int(batch.get("exit_code", 1)),
        "stdout_tail": str(batch.get("stdout", ""))[-4000:],
        "stderr_tail": str(batch.get("stderr", ""))[-4000:],
        "batch_summary": batch.get("batch_summary", {}),
    }
    batch_summary = summary.get("batch_summary", {})
    if isinstance(batch_summary, dict) and batch_summary:
        batch_dir = batch_summary.get("batch_dir")
        if batch_dir:
            summary["batch_dir"] = str(batch_dir)
    return summary


def main() -> int:
    args = _build_parser().parse_args()
    lane = ensure_lane()
    profiles = [p.strip() for p in args.profiles.split(",") if p.strip()]
    if not profiles:
        print("[matrix] no profiles provided", flush=True)
        return 2

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    matrix_dir = args.output_dir / f"matrix_{ts}"
    matrix_dir.mkdir(parents=True, exist_ok=True)

    results: List[Dict[str, Any]] = []
    for profile in profiles:
        print(f"[matrix] running profile={profile}", flush=True)
        summary = _run_profile(
            profile,
            args.runs,
            args.max_loops,
            args.output_dir,
            lane,
            args.profile_save_index,
            args.console_profile,
        )
        results.append(summary)
        print(f"[matrix] done profile={profile} exit={summary['exit_code']}", flush=True)

    output = {
        "profiles": profiles,
        "runs_per_profile": args.runs,
        "max_loops": args.max_loops,
        "output_dir": str(args.output_dir),
        "results": results,
    }
    out_path = matrix_dir / "matrix_summary.json"
    write_json(out_path, output)
    print("[matrix] summary written", out_path, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
