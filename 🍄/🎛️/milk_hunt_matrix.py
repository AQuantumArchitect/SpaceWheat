#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List

from milk_hunt_paths import resolve_batch_summary

SCRIPT_DIR = Path(__file__).resolve().parent
RUNNER = SCRIPT_DIR / "milk_hunt_batch.py"


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run milk hunt batches across multiple profiles")
    parser.add_argument(
        "--profiles",
        type=str,
        required=True,
        help="Comma-separated profile names",
    )
    parser.add_argument("--runs", type=int, default=3, help="Runs per profile")
    parser.add_argument("--max-loops", type=int, default=220, help="Max offer cycles per run")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("/home/tehcr33d/ws/SpaceWheat/🍄/🎛️/logs/milk_batches"),
        help="Directory for logs and summaries",
    )
    return parser


def _run_profile(profile: str, runs: int, max_loops: int, output_dir: Path) -> Dict[str, Any]:
    cmd = [
        "python3",
        str(RUNNER),
        "--profile",
        profile,
        "--runs",
        str(runs),
        "--max-loops",
        str(max_loops),
        "--output-dir",
        str(output_dir),
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    summary: Dict[str, Any] = {
        "profile": profile,
        "exit_code": proc.returncode,
        "stdout_tail": (proc.stdout or "")[-4000:],
        "stderr_tail": (proc.stderr or "")[-4000:],
    }

    candidate = resolve_batch_summary(output_dir)
    if candidate is not None and candidate.exists():
        try:
            summary["batch_summary"] = json.loads(candidate.read_text(encoding="utf-8"))
            summary["batch_dir"] = str(candidate.parent)
        except json.JSONDecodeError:
            summary["batch_summary"] = {"parse_error": "invalid_summary_json"}
    return summary


def main() -> int:
    args = _build_parser().parse_args()
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
        summary = _run_profile(profile, args.runs, args.max_loops, args.output_dir)
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
    out_path.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("[matrix] summary written", out_path, flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
