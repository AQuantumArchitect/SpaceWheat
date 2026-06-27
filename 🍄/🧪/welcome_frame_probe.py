#!/usr/bin/env python3
"""Reproduce the reported bug: after dismissing the welcome splash, frame (hat)
selection is blocked / actions don't work. Boots headed WITH the welcome (like the
real `godot` boot), dismisses it, then tries to change frames, screenshotting each
step + reading instrument/overlay state to find why input is stuck."""
import os, sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

os.environ.setdefault("RIG_DISABLE_LOOKAHEAD", "0")
_turn = [0]
def t(): _turn[0] += 1; return _turn[0]

def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headed",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0", "RIG_SKIP_WELCOME": "0"})
    def go(a, **k):
        k.pop("timeout_s", None); return c.run_turn(t(), a, timeout_s=120, **k)
    def press(seq, s=5):
        if isinstance(seq, str): seq = [seq]
        for k in seq: c.run_turn(t(), "press_key", key=k, settle_frames=s, timeout_s=30)
    def shot(name):
        sh = go("screenshot", path="user://rig/wf_%s.png" % name).get("screenshot", {})
        print("SHOT %-18s -> %s" % (name, sh.get("abs")))
    def istate(tag):
        s = go("instrument_state")
        print("STATE %-14s cursor_layer=%s plot=%s biome=%s in_submenu=%s confirm=%s" % (
            tag, s.get("cursor_layer"), s.get("current_plot_idx"), s.get("current_biome"),
            s.get("in_submenu"), s.get("confirm_pending") if "confirm_pending" in s else s.get("_confirm_pending")))
    try:
        c.wait_for_ready(proc, timeout_s=300)
        print("READY (headed, welcome ON)")
        shot("01_welcome_up"); istate("welcome_up")
        # FIX CHECK: a NON-F key (the user pressed frame keys, got stuck) must dismiss the
        # welcome. Press 5 — welcome should clear (any-key dismiss, consumed).
        press("5", 6)
        istate("after_5_dismiss"); shot("02_after_5_dismiss")
        # Now the player plays normally: 5 → Icon frame, R → Add Icon, frames cycle freely.
        for key, name in [("5","03_icon"), ("7","04_captain"), ("8","05_ace")]:
            press(key, 5); shot(name); istate("after_%s" % name)
        press("G", 4); press("R", 4); istate("after_G_R_action"); shot("06_plot_action")
    finally:
        go("stop"); c.terminate_listener(proc)

if __name__ == "__main__":
    main()
