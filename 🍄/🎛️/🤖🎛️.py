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
import os

PROJECT_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_PLAN = PROJECT_ROOT / "🍄" / "🎛️" / "🧭📜.json"
RIG_LOG_DIR = PROJECT_ROOT / "🍄" / "🎛️" / "🧾"
RIG_TOKEN_DIR = RIG_LOG_DIR / "🔖"


def load_plan(path: Path):
    if not path.exists():
        raise FileNotFoundError(f"Turn plan not found: {path}")
    with path.open() as f:
        plan = json.load(f)
    if not isinstance(plan, list):
        raise ValueError("Turn plan must be a list of turns.")
    return plan


def docmd(step, log_dir: Path, timeout_s: int):
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

    before_tokens = {p.name for p in RIG_TOKEN_DIR.glob("*.tok")}

    cmd = ["bash", str(script_path)]
    start = time.time()
    env = os.environ.copy()
    env["PROJECT_ROOT"] = str(PROJECT_ROOT)
    env["QII_TOKEN_DIR"] = str(RIG_TOKEN_DIR)
    try:
        proc = subprocess.run(
            cmd,
            cwd=PROJECT_ROOT,
            capture_output=True,
            text=True,
            env=env,
            timeout=timeout_s,
        )
        duration = time.time() - start
        stdout = proc.stdout
        stderr = proc.stderr
        returncode = proc.returncode
    except subprocess.TimeoutExpired as exc:
        duration = time.time() - start
        stdout = exc.stdout or ""
        stderr = exc.stderr or ""
        returncode = 124

    with output_log.open("w", encoding="utf-8") as outf:
        outf.write(stdout)
        outf.write("\n--- STDERR ---\n")
        outf.write(stderr)

    after_tokens = {p.name for p in RIG_TOKEN_DIR.glob("*.tok")}
    new_tokens = sorted(list(after_tokens - before_tokens))

    summary = {
        "name": name,
        "description": step.get("description", ""),
        "command": " ".join(cmd),
        "returncode": returncode,
        "start": datetime.utcfromtimestamp(start).isoformat(),
        "duration_seconds": round(duration, 3),
        "token_logs": new_tokens,
        "output_log": str(output_log.relative_to(PROJECT_ROOT)),
    }

    with summary_log.open("w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)

    return summary, returncode


def ensure_dirs(log_dir: Path):
    log_dir.mkdir(parents=True, exist_ok=True)
    RIG_TOKEN_DIR.mkdir(parents=True, exist_ok=True)


def main():
    parser = argparse.ArgumentParser(description="Codex-mini rig orchestrator.")
    parser.add_argument(
        "--plan",
        type=Path,
        default=DEFAULT_PLAN,
        help="JSON file describing each turn (default 🍄/🎛️/🧭📜.json)",
    )
    parser.add_argument(
        "--log-dir",
        type=Path,
        default=RIG_LOG_DIR,
        help="Directory to store orchestrator logs",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=300,
        help="Timeout per turn in seconds (default 300)",
    )
    parser.add_argument("--dry-run", action="store_true", help="Only print the plan")
    parser.add_argument(
        "--no-interactive",
        action="store_true",
        help="Run through the plan once without prompts",
    )
    args = parser.parse_args()

    plan = load_plan(args.plan)
    ensure_dirs(args.log_dir)

    if args.dry_run:
        for idx, turn in enumerate(plan, start=1):
            print(f"Turn {idx}: {turn.get('name')} -> {turn.get('script')}")
        return

    print("Rig mode: QA playtesters. Please look for bugs or performance issues.")

    def prompt_continue(message: str, default_yes: bool = True) -> bool:
        if args.no_interactive:
            return True
        suffix = "[Y/n]" if default_yes else "[y/N]"
        raw = input(f"{message} {suffix} ").strip().lower()
        if raw == "":
            return default_yes
        return raw in ("y", "yes")

    while True:
        for idx, turn in enumerate(plan, start=1):
            print(f"--> Turn {idx}/{len(plan)}: {turn.get('name', 'unnamed')}")
            summary, rc = docmd(turn, args.log_dir, args.timeout)
            print(f"    cmd: {summary['command']}")
            print(f"    duration: {summary['duration_seconds']}s returncode={rc}")
            if summary["token_logs"]:
                print(f"    tokens: {summary['token_logs']}")
            if rc != 0:
                print(f"    !!!! Turn {turn.get('name')} failed (rc={rc})")
                sys.exit(rc)

            if not prompt_continue("Continue to next turn?"):
                return

        if args.no_interactive:
            return
        if not prompt_continue("Run another pass through the turn plan?", default_yes=False):
            return


if __name__ == "__main__":
    main()
