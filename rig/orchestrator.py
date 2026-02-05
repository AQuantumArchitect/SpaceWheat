#!/usr/bin/env python3
"""
Rig orchestrator - sequentially run turns for Codex-mini play sessions.

Each turn is defined in turn_plan.json. The orchestrator launches the referenced
script (usually one of the emoji bash runners), waits for completion, records
which token logs were produced, and writes a per-turn summary into the rig logs.
"""

import argparse
import json
import shutil
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
TOKEN_DIR = PROJECT_ROOT / "🍄" / "logs" / "tokens"
DEFAULT_PLAN = PROJECT_ROOT / "rig" / "turn_plan.json"


def load_plan(path: Path):
    if not path.exists():
        raise FileNotFoundError(f"Turn plan not found: {path}")
    with path.open() as f:
        plan = json.load(f)
    if not isinstance(plan, list):
        raise ValueError("Turn plan must be a list of turns.")
    return plan


def docmd(step, log_dir: Path):
    script = step.get("script")
    if not script:
        raise ValueError("Turn is missing 'script'.")
    script_path = (PROJECT_ROOT / script).resolve()
    if not script_path.exists():
        raise FileNotFoundError(f"Script {script_path} does not exist.")

    name = step.get("name", script_path.stem)
    ts = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    output_log = log_dir / f"{name}_{ts}.log"
    summary_log = log_dir / f"{name}_{ts}.json"

    before_tokens = {p.name for p in TOKEN_DIR.glob("*.tok")}

    cmd = ["bash", str(script_path)]
    start = time.time()
    proc = subprocess.run(
        cmd,
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        env=dict(**dict(PROJECT_ROOT=PROJECT_ROOT)),
    )
    duration = time.time() - start

    with output_log.open("w", encoding="utf-8") as outf:
        outf.write(proc.stdout)
        outf.write("\n--- STDERR ---\n")
        outf.write(proc.stderr)

    after_tokens = {p.name for p in TOKEN_DIR.glob("*.tok")}
    new_tokens = sorted(list(after_tokens - before_tokens))

    summary = {
        "name": name,
        "description": step.get("description", ""),
        "command": " ".join(cmd),
        "returncode": proc.returncode,
        "start": datetime.utcfromtimestamp(start).isoformat(),
        "duration_seconds": round(duration, 3),
        "token_logs": new_tokens,
        "output_log": str(output_log.relative_to(PROJECT_ROOT)),
    }

    with summary_log.open("w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)

    return summary, proc.returncode


def ensure_dirs(log_dir: Path):
    log_dir.mkdir(parents=True, exist_ok=True)
    TOKEN_DIR.mkdir(parents=True, exist_ok=True)


def main():
    parser = argparse.ArgumentParser(description="Codex-mini rig orchestrator.")
    parser.add_argument(
        "--plan",
        type=Path,
        default=DEFAULT_PLAN,
        help="JSON file describing each turn (default rig/turn_plan.json)",
    )
    parser.add_argument(
        "--log-dir",
        type=Path,
        default=PROJECT_ROOT / "rig" / "logs",
        help="Directory to store orchestrator logs",
    )
    parser.add_argument("--dry-run", action="store_true", help="Only print the plan")
    args = parser.parse_args()

    plan = load_plan(args.plan)
    ensure_dirs(args.log_dir)

    if args.dry_run:
        for idx, turn in enumerate(plan, start=1):
            print(f"Turn {idx}: {turn.get('name')} -> {turn.get('script')}")
        return

    for idx, turn in enumerate(plan, start=1):
        print(f"--> Turn {idx}/{len(plan)}: {turn.get('name', 'unnamed')}")
        summary, rc = docmd(turn, args.log_dir)
        print(f"    cmd: {summary['command']}")
        print(f"    duration: {summary['duration_seconds']}s returncode={rc}")
        if summary["token_logs"]:
            print(f"    tokens: {summary['token_logs']}")
        if rc != 0:
            print(f"    !!!! Turn {turn.get('name')} failed (rc={rc})")
            sys.exit(rc)


if __name__ == "__main__":
    main()
