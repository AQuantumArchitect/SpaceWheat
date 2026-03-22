#!/usr/bin/env python3
"""Opinionated derby-of-1 wrapper.

Runs three fib-scale characters against both current engine policies.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from run_executor import ensure_lane, run_cli


HERE = Path(__file__).resolve().parent
DERBY = HERE / "derby.py"
DEFAULT_CHARACTERS = [
    "granary_scout_fib",
    "solar_gatekeeper_fib",
    "village_diplomat_fib",
]


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run the default 3-character derby-of-1")
    parser.add_argument("--runs", type=int, default=1)
    parser.add_argument("--max-loops", type=int, default=13)
    parser.add_argument(
        "--runtime-profile",
        choices=["default", "quantum_fiber_nodes", "io_min"],
        default="io_min",
    )
    parser.add_argument(
        "--console-profile",
        choices=["quiet", "normal", "debug", "trace", "test"],
        default="quiet",
    )
    parser.add_argument(
        "--display-mode",
        choices=["headless", "headed"],
        default="headless",
    )
    parser.add_argument(
        "--policy-execution-backend",
        choices=["auto", "direct", "player_input"],
        default="auto",
    )
    parser.add_argument("--reuse-listener", dest="reuse_listener", action="store_true")
    parser.add_argument("--no-reuse-listener", dest="reuse_listener", action="store_false")
    parser.set_defaults(reuse_listener=True)
    return parser


def main() -> int:
    args = _build_parser().parse_args()
    lane = ensure_lane()
    cmd = [
        sys.executable,
        str(DERBY),
        "--characters",
        *DEFAULT_CHARACTERS,
        "--policies",
        "engine_policy",
        "quantum_register",
        "--runs",
        str(args.runs),
        "--max-loops",
        str(args.max_loops),
        "--runtime-profile",
        str(args.runtime_profile),
        "--console-profile",
        str(args.console_profile),
        "--display-mode",
        str(args.display_mode),
        "--policy-execution-backend",
        str(args.policy_execution_backend),
    ]
    cmd.append("--reuse-listener" if args.reuse_listener else "--no-reuse-listener")
    proc = run_cli(cmd, lane=lane, timeout_s=1800, capture_output=False)
    return int(proc.returncode)


if __name__ == "__main__":
    raise SystemExit(main())
