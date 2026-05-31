#!/usr/bin/env python3
import argparse
import json
import os
import sys
from pathlib import Path

from rig_client import RigClient


def main() -> int:
    parser = argparse.ArgumentParser(description="Smoke-test the Windows rig listener from WSL.")
    parser.add_argument("--display-mode", default="headless", choices=["headless", "headed"])
    parser.add_argument("--godot-windows-path", default="")
    parser.add_argument("--scenario", default="default")
    parser.add_argument("--ready-timeout", type=float, default=90.0)
    parser.add_argument("--turn-timeout", type=float, default=30.0)
    args = parser.parse_args()

    env = {"RIG_RUNTIME_TARGET": "windows"}
    if args.godot_windows_path:
        env["GODOT_WINDOWS_PATH"] = args.godot_windows_path

    client = RigClient(root_from_file=Path(__file__))
    client.clear_rig_files(preserve_live_sentinel=False)
    proc = None
    try:
        proc = client.start_listener(
            scenario_id=str(args.scenario),
            display_mode=str(args.display_mode),
            listener_stdout="pipe",
            extra_env=env,
        )
        ready_lines = client.wait_for_ready(proc, timeout_s=float(args.ready_timeout), xdg=client.xdg_root)
        print("READY_LINES:")
        for line in ready_lines[-20:]:
            print(line)
        if not RigClient.ready_seen(ready_lines) and not os.environ.get("RIG_TRUST_SENTINEL"):
            print("listener did not reach ready state", file=sys.stderr)
            return 1

        row = client.run_turn(
            1,
            "policy_snapshot",
            timeout_s=float(args.turn_timeout),
            include_grid=False,
            include_offers=False,
        )
        print("RESULT_JSON:")
        print(json.dumps(row, ensure_ascii=False, indent=2))
        return 0 if bool(row.get("ok", False)) else 2
    finally:
        RigClient.terminate_listener(proc)


if __name__ == "__main__":
    raise SystemExit(main())
