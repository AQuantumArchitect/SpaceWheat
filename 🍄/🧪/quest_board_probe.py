#!/usr/bin/env python3
"""Quest board tab screenshots — verify the board populates and the Arc tab shows
the reworked rigid-empire / plural-island narrative (the Demos spine)."""
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
        sh = go("screenshot", path="user://rig/qb_%s.png" % name).get("screenshot", {})
        print("SHOT %-10s saved=%s -> %s" % (name, sh.get("saved"), sh.get("abs")))
    try:
        c.wait_for_ready(proc, timeout_s=300)
        print("READY")
        press("C", 5)            # open quest board
        press("I", 4); shot("arc")       # Arc tab (the Demos spine)
        press("Y", 4); shot("market")    # Market tab
        press("T", 4); shot("manifold")  # Manifold tab
        # Story-flags readout to cross-check what the Arc tab should list.
        sf = go("story_flags")
        print("flags_fired:", sorted((sf.get("flags_fired") or {}).keys()))
    finally:
        go("stop"); c.terminate_listener(proc)


if __name__ == "__main__":
    main()
