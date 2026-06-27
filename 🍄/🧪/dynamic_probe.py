#!/usr/bin/env python3
"""Dynamic-state screenshots — verify the states tied to the playtest complaints.

  1. inject_submenu — Icon hat, plot selected, R pressed: the per-icon injection
     submenu where vocab costs live ("can't see the resource costs" complaint).
  2. v_overlay      — V (Qubit Atlas) open: does the z=60 action bar bury overlays?
  3. quests_overlay — C/quest board open: same overlap check + general legibility.
  4. toast_state    — after a destructive action arms a toast: toast vs action bar.
"""
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
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})
    def go(a, **k):
        k.pop("timeout_s", None); return c.run_turn(t(), a, timeout_s=120, **k)
    def press(seq, s=5):
        if isinstance(seq, str): seq = [seq]
        for k in seq: c.run_turn(t(), "press_key", key=k, settle_frames=s, timeout_s=30)
    def shot(name):
        sh = go("screenshot", path="user://rig/dyn_%s.png" % name).get("screenshot", {})
        print("SHOT %-16s saved=%s -> %s" % (name, sh.get("saved"), sh.get("abs")))
    try:
        c.wait_for_ready(proc, timeout_s=300)
        go("set_window_size", w=1600, h=900)
        print("READY (headed 1600x900)")
        # 1. Injection submenu (per-icon costs)
        press("5", 4)            # Icon hat
        press("G", 4)            # select a plot
        press("R", 5)            # open Add-Icon submenu
        sm = go("submenu_state")
        print("in_submenu:", sm.get("in_submenu"), "slots:", list((sm.get("slots") or {}).keys()))
        shot("inject_submenu")
        press("ESCAPE", 3)
        # 2. V overlay
        press("V", 5)
        shot("v_overlay")
        press("V", 3)            # close
        # 3. Quest board (C)
        press("C", 5)
        shot("quests_overlay")
        press("C", 3)
    finally:
        go("stop"); c.terminate_listener(proc)


if __name__ == "__main__":
    main()
