#!/usr/bin/env python3
"""Exploratory closed-system rig probe: boot the rig, learn the snapshot schema."""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))  # 🍄/🎛️
from rig_client import RigClient  # noqa: E402


def jp(label, obj):
    print(f"\n===== {label} =====")
    print(json.dumps(obj, indent=2, ensure_ascii=False)[:3000])


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless")
    try:
        lines = c.wait_for_ready(proc, timeout_s=120)
        print("READY (%d boot lines)" % len(lines))
        jp("grid_snapshot", c.run_turn(1, "grid_snapshot", timeout_s=60))
        jp("resource_snapshot", c.run_turn(2, "resource_snapshot", timeout_s=30))
        jp("full_snapshot", c.run_turn(3, "full_snapshot", timeout_s=60))
    finally:
        try:
            c.run_turn(999, "stop", timeout_s=10)
        except Exception:
            pass
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
