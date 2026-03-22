#!/usr/bin/env python3
"""Finish-line harness: retry only failed profiles and continue state across attempts.

Design goals:
- Only rerun profiles that have no recorded milk victory.
- Increase max-loops only after a failed attempt.
- Continue from last attempt state via save/load slot (no fresh restart per retry).
"""

from __future__ import annotations

import argparse
import json
import subprocess
import time
from pathlib import Path
from typing import Any, Dict, List

from run_executor import ensure_lane, run_cli


PROFILES: List[str] = [
    "granary_scout",
    "arc_coldpath_explorer",
    "solar_gatekeeper",
    "village_diplomat",
    "biotic_bubble_runner",
]


def _parse_loop_schedule(raw: str) -> List[int]:
    out: List[int] = []
    for part in (raw or "").split(","):
        part = part.strip()
        if not part:
            continue
        out.append(int(part))
    if not out:
        raise ValueError("loop schedule must include at least one integer")
    return out


def _collect_batch_status(batch_root: Path) -> Dict[str, Dict[str, Any]]:
    status: Dict[str, Dict[str, Any]] = {p: {"runs": 0, "successes": 0} for p in PROFILES}
    for summary_path in sorted(batch_root.glob("batch_*/batch_summary.json")):
        try:
            data = json.loads(summary_path.read_text(encoding="utf-8"))
        except Exception:
            continue
        profile = str(data.get("profile") or "")
        if profile not in status:
            continue
        runs = data.get("run_summaries", []) or []
        status[profile]["runs"] += len(runs)
        status[profile]["successes"] += sum(1 for run in runs if bool(run.get("found_milk_pair", False)))
    return status


def _run_cmd(cmd: List[str], timeout_s: int, lane=None) -> subprocess.CompletedProcess[str]:
    return run_cli(cmd, lane=lane, capture_output=True, timeout_s=timeout_s)


def _cleanup_stale_processes() -> None:
    subprocess.run(
        [
            "/bin/bash",
            "-lc",
            (
                "pids=$(pgrep -f \"milk_hunt_runner.py|Tests/rig_listener.gd|milk_hunt_batch.py --profile\" || true); "
                "if [ -n \"$pids\" ]; then kill $pids || true; fi"
            ),
        ],
        capture_output=True,
        text=True,
        check=False,
    )


def _read_summary(path: Path) -> Dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser(description="Retry failed milk-hunt profiles with save-slot continuation")
    parser.add_argument(
        "--batch-output-root",
        type=Path,
        default=Path("/tmp/milk_hunt_allprofiles_strict_fast"),
        help="Directory containing prior milk_hunt_batch batch_*/batch_summary.json runs",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("/tmp/milk_hunt_finish_line"),
        help="Directory for continuation summaries/logs",
    )
    parser.add_argument("--slot", type=int, default=2, help="Save slot used for continuation attempts")
    parser.add_argument(
        "--loop-schedule",
        type=str,
        default="34,55,89,144",
        help="Comma-separated max-loop escalation schedule",
    )
    parser.add_argument("--retries-per-level", type=int, default=4, help="Retries per loop level")
    parser.add_argument("--timeout-seconds", type=int, default=420, help="Per-attempt timeout")
    parser.add_argument(
        "--failures-only",
        action="store_true",
        default=True,
        help="Only run profiles that have no prior milk victory in batch-output-root",
    )
    parser.add_argument(
        "--all-profiles",
        action="store_true",
        help="Ignore prior status and run all profiles through continuation flow",
    )
    args = parser.parse_args()
    lane = ensure_lane()

    root = Path(__file__).resolve().parent
    runner = root / "milk_hunt_runner.py"
    seeder = root / "milk_hunt_seed_save.py"
    args.output_dir.mkdir(parents=True, exist_ok=True)

    loop_schedule = _parse_loop_schedule(args.loop_schedule)
    prior = _collect_batch_status(args.batch_output_root)

    if args.all_profiles:
        targets = list(PROFILES)
    else:
        targets = [p for p in PROFILES if int(prior[p]["successes"]) <= 0]

    print("finish-line: targets=%s" % targets, flush=True)
    report: Dict[str, Any] = {
        "generated_at_epoch": time.time(),
        "slot": int(args.slot),
        "loop_schedule": loop_schedule,
        "retries_per_level": int(args.retries_per_level),
        "timeout_seconds": int(args.timeout_seconds),
        "prior_status": prior,
        "profiles": {},
    }

    for profile in targets:
        print("== %s ==" % profile, flush=True)
        # Seed once, then continuation attempts load/save the same slot.
        seed_log = args.output_dir / f"{profile}_seed.log"
        seed_cmd = [
            "python3",
            str(seeder),
            "--profile",
            profile,
            "--slot",
            str(args.slot),
        ]
        seed_proc = _run_cmd(seed_cmd, timeout_s=max(90, args.timeout_seconds), lane=lane)
        seed_log.write_text((seed_proc.stdout or "") + (seed_proc.stderr or ""), encoding="utf-8")

        profile_entry: Dict[str, Any] = {
            "seed_ok": (seed_proc.returncode == 0),
            "attempts": [],
            "victory": False,
            "final_summary_path": "",
        }
        if seed_proc.returncode != 0:
            report["profiles"][profile] = profile_entry
            continue

        attempt_idx = 0
        for loops in loop_schedule:
            for retry in range(1, int(args.retries_per_level) + 1):
                attempt_idx += 1
                summary_path = args.output_dir / f"{profile}_attempt_{attempt_idx}.json"
                log_path = args.output_dir / f"{profile}_attempt_{attempt_idx}.log"
                cmd = [
                    "python3",
                    str(runner),
                    "--load-slot",
                    str(args.slot),
                    "--save-slot-at-end",
                    str(args.slot),
                    "--hunter-profile",
                    profile,
                    "--hunter-policy",
                    "engine_policy",
                    "--strict-biome-economy",
                    "--runtime-profile",
                    "io_min",
                    "--console-profile",
                    "quiet",
                    "--max-loops",
                    str(loops),
                    "--summary-path",
                    str(summary_path),
                ]
                if attempt_idx > 1:
                    cmd.append("--no-policy-reset-on-start")

                timeout_hit = False
                try:
                    proc = _run_cmd(cmd, timeout_s=int(args.timeout_seconds), lane=lane)
                except subprocess.TimeoutExpired:
                    timeout_hit = True
                    _cleanup_stale_processes()
                    proc = subprocess.CompletedProcess(cmd, 124, "", "timeout")

                log_path.write_text((proc.stdout or "") + (proc.stderr or ""), encoding="utf-8")
                if not summary_path.exists():
                    profile_entry["attempts"].append(
                        {
                            "attempt": attempt_idx,
                            "max_loops": int(loops),
                            "retry": int(retry),
                            "timeout": timeout_hit,
                            "summary_missing": True,
                            "exit_code": int(proc.returncode),
                        }
                    )
                    print(
                        "  attempt=%d loops=%d retry=%d summary=missing timeout=%s"
                        % (attempt_idx, loops, retry, str(timeout_hit).lower()),
                        flush=True,
                    )
                    continue

                summary = _read_summary(summary_path)
                success = bool(summary.get("found_milk_pair", False))
                steps = int(summary.get("steps") or summary.get("turns_executed") or 0)
                loops_completed = int(summary.get("loops_completed") or 0)
                run_error = str(summary.get("run_error") or "")
                profile_entry["attempts"].append(
                    {
                        "attempt": attempt_idx,
                        "max_loops": int(loops),
                        "retry": int(retry),
                        "timeout": timeout_hit,
                        "summary_missing": False,
                        "exit_code": int(proc.returncode),
                        "success": success,
                        "steps": steps,
                        "loops_completed": loops_completed,
                        "run_error": run_error,
                        "summary_path": str(summary_path),
                    }
                )
                print(
                    "  attempt=%d loops=%d retry=%d success=%s steps=%d loops_completed=%d err=%s"
                    % (
                        attempt_idx,
                        loops,
                        retry,
                        str(success).lower(),
                        steps,
                        loops_completed,
                        run_error or "none",
                    ),
                    flush=True,
                )
                if success:
                    profile_entry["victory"] = True
                    profile_entry["final_summary_path"] = str(summary_path)
                    break
            if profile_entry["victory"]:
                break

        report["profiles"][profile] = profile_entry

    # Merge prior + current profile status for final all-profiles check.
    merged_success: Dict[str, bool] = {}
    for p in PROFILES:
        prior_ok = int(prior.get(p, {}).get("successes", 0)) > 0
        now_ok = bool(report.get("profiles", {}).get(p, {}).get("victory", False))
        merged_success[p] = bool(prior_ok or now_ok)

    report["merged_success"] = merged_success
    report["all_profiles_victory"] = all(merged_success.values())

    report_path = args.output_dir / ("finish_line_report_%d.json" % int(time.time()))
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print("REPORT_PATH=%s" % report_path, flush=True)
    print("ALL_PROFILES_VICTORY=%s" % str(report["all_profiles_victory"]), flush=True)
    return 0 if report["all_profiles_victory"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
