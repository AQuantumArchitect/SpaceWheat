#!/usr/bin/env python3
"""Headed: does the live explore→bind→bubble path actually produce a bubble?

Boots demos_normal headed (viz mounts, is_headless=false), dismisses welcome,
selects plot 0 (G), Strikes (R = measure → strike-time bind → terminal_bound →
bubble), settles, screenshots. Prints instrument_state before/after so we can see
whether a terminal got bound. Then copy user://rig/shot.png out for inspection.
"""
import os
import sys
import shutil
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

_t = [0]


def turn():
    _t[0] += 1
    return _t[0]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    log_path = HERE.parent.parent / "logs" / "strike_listener.log"
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headed",
                            listener_log_path=log_path, rig_log_profile="debug",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0", "RIG_SKIP_WELCOME": "0"})
    try:
        ready = c.wait_for_ready(proc, timeout_s=200)
        print("ready:", ready)

        def t(action, **kw):
            return c.run_turn(turn(), action, timeout_s=25, **kw)

        def press(k, shift=False):
            return t("press_key", key=k, shift=shift)

        def istate():
            r = t("instrument_state")
            return r

        # Dismiss welcome splash, settle into live view
        press("f")
        press("f")
        t("press_key", key="f", settle_frames=8)
        print("instrument BEFORE:", istate())

        # Put register in superposition so a strike is meaningful, then select+strike
        hg = t("gate_inject", gate="hadamard", biome="StarterForest", positions=[])
        print("hadamard ok:", hg.get("ok"))

        print("select G:", press("g").get("ok"))
        t("press_key", key="g", settle_frames=4)
        print("strike R:", press("r").get("ok"))
        t("press_key", key="r", settle_frames=12)

        print("instrument AFTER:", istate())

        shot = t("screenshot")
        print("screenshot resp:", shot.get("screenshot", shot.get("ok")))
    finally:
        c.terminate_listener(proc)

    # Copy the shot out (best-effort) for inspection
    for base in [os.environ.get("GODOT_USER_DIR", ""), ]:
        if base:
            p = Path(base) / "rig" / "shot.png"
            if p.exists():
                shutil.copy(p, HERE.parent.parent / "logs" / "strike_shot.png")
                print("copied shot to logs/strike_shot.png")
                return
    # Fallback: search
    import glob
    hits = sorted(glob.glob("/tmp/sw_godot_*/**/rig/shot.png", recursive=True), key=os.path.getmtime)
    if hits:
        shutil.copy(hits[-1], HERE.parent.parent / "logs" / "strike_shot.png")
        print("copied shot to logs/strike_shot.png (from", hits[-1], ")")
    else:
        print("no shot.png found")


if __name__ == "__main__":
    main()
