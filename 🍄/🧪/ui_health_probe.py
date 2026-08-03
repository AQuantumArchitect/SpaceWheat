#!/usr/bin/env python3
"""Broad UI-health screenshot sweep — every hat action bar + every surface overlay.

One headed run captures all states so we can triage rendering bugs across the whole UI:
  hats 4-0 (Spark/Icon/Merchant/Captain/Ace/Operator/Druid) — action bar + costs
  surfaces Z X C V B N M [ — each top-level overlay renders
"""
import os, sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402
from turn_driver import TurnDriver  # noqa: E402

os.environ.setdefault("RIG_DISABLE_LOOKAHEAD", "0")
# Historical per-script driver timeouts — deliberately NOT unified (SLOP_PATROL knot #8).
GO_TIMEOUT_S = 120
PRESS_TIMEOUT_S = 30
PRESS_SETTLE_FRAMES = 4

_driver = TurnDriver(start=0)
t = _driver.t


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headed",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})
    go = _driver.make_go(c, timeout_s=GO_TIMEOUT_S)
    press = _driver.make_press(c, settle_frames=PRESS_SETTLE_FRAMES, timeout_s=PRESS_TIMEOUT_S)
    def shot(name):
        sh = go("screenshot", path="user://rig/ui_%s.png" % name).get("screenshot", {})
        print("SHOT %-14s saved=%s -> %s" % (name, sh.get("saved"), sh.get("abs")))
    try:
        c.wait_for_ready(proc, timeout_s=300)
        print("READY")
        go("time_skip", phrames=120)
        press("G", 3)  # select a plot so action availability resolves
        # --- Hats (action bar) ---
        for key, name in [("4","hat_spark"),("5","hat_icon"),("6","hat_merchant"),
                          ("7","hat_captain"),("8","hat_ace"),("9","hat_operator"),("0","hat_druid")]:
            press(key, 4); shot(name)
        # back to a neutral hat
        press("8", 3)
        # --- Surfaces (overlays) ---
        for key, name in [("Z","surf_z"),("X","surf_x"),("C","surf_c"),("V","surf_v"),
                          ("B","surf_b"),("N","surf_n"),("M","surf_m"),("BRACKETLEFT","surf_bracket")]:
            press(key, 5); shot(name); press(key, 3)  # open, shot, toggle-close
    finally:
        go("stop"); c.terminate_listener(proc)


if __name__ == "__main__":
    main()
