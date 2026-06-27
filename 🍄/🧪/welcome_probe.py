#!/usr/bin/env python3
"""Welcome splash verification (headed). Confirms:
  - the splash AUTO-SHOWS on first run (RIG_SKIP_WELCOME=0),
  - tutorial_seen is NOT set while it's up (flags fire from action, not boot),
  - dismissing with F fires tutorial_seen (the human action) and closes the splash.
Also screenshots the splash for a visual check.
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
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0", "RIG_SKIP_WELCOME": "0"})
    def go(a, **k):
        k.pop("timeout_s", None); return c.run_turn(t(), a, timeout_s=120, **k)
    def press(seq, s=5):
        if isinstance(seq, str): seq = [seq]
        for k in seq: c.run_turn(t(), "press_key", key=k, settle_frames=s, timeout_s=30)
    def shot(name):
        sh = go("screenshot", path="user://rig/wel_%s.png" % name).get("screenshot", {})
        print("SHOT %-10s saved=%s -> %s" % (name, sh.get("saved"), sh.get("abs")))
    def flags():
        return sorted((go("story_flags").get("flags_fired") or {}).keys())
    try:
        c.wait_for_ready(proc, timeout_s=300)
        print("READY")
        shot("shown")                      # splash should be visible on first run
        before = flags()
        print("flags BEFORE dismiss:", before, "| tutorial_seen present:", "tutorial_seen" in before)
        press("F", 5)                      # F = Begin → dismiss
        after = flags()
        print("flags AFTER dismiss: ", after, "| tutorial_seen present:", "tutorial_seen" in after)
        shot("dismissed")                  # splash gone, farm view
        ok = ("tutorial_seen" not in before) and ("tutorial_seen" in after)
        print("RESULT tutorial_seen fires on dismiss (action, not boot):", "OK" if ok else "CHECK")
    finally:
        go("stop"); c.terminate_listener(proc)


if __name__ == "__main__":
    main()
