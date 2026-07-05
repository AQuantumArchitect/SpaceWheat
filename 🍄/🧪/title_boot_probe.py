#!/usr/bin/env python3
"""Fast validation of RIG_DRIVE_TITLE + start_from_title: boot to the real title screen,
screenshot it, drive F → start → welcome, screenshot, dismiss with a non-F key, screenshot."""
import os, sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

_t = [0]
def t(): _t[0] += 1; return _t[0]

def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headed",
                            extra_env={"RIG_DRIVE_TITLE": "1", "RIG_SKIP_WELCOME": "0",
                                       "RIG_DISABLE_LOOKAHEAD": "0"})
    def go(a, **k): k.pop("timeout_s", None); return c.run_turn(t(), a, timeout_s=120, **k)
    def shot(n):
        s = go("screenshot", path="user://rig/tb_%s.png" % n).get("screenshot", {})
        print("SHOT %-14s saved=%s -> %s" % (n, s.get("saved"), s.get("abs")))
    try:
        c.wait_for_ready(proc, timeout_s=200)
        print("READY (title up)")
        shot("00_title")
        st = go("start_from_title", keys=["F"], settle_frames=10)
        print("start_from_title:", st.get("start_from_title"))
        shot("01_welcome")
        for k in ("press_key",):
            c.run_turn(t(), "press_key", key="5", settle_frames=8, timeout_s=30)
        shot("02_after_dismiss")
        gs = go("grid_snapshot").get("grid", {})
        print("GRID:", gs.get("biomes", gs))
    finally:
        go("stop"); c.terminate_listener(proc)

if __name__ == "__main__":
    main()
