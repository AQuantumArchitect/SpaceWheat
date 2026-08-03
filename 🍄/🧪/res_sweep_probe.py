#!/usr/bin/env python3
"""Resolution sweep — find where the action-bar / hat-row layout explodes.

At 1280x720 the UI is clean (no Ace-over-action-bar overlap). The playtest report
is likely resolution-dependent. Resize the headed window across common sizes and
screenshot each, so we can SEE which resolutions break the responsive layout.
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

RESOLUTIONS = [
    (1920, 1080),  # common fullscreen 16:9
    (2560, 1440),  # 1440p
    (1366, 768),   # common laptop
    (1600, 900),   # 16:9 mid
    (3440, 1440),  # ultrawide 21:9
    (1024, 768),   # 4:3
    (1280, 1024),  # 5:4
    (960, 600),    # small window
]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headed",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})
    go = _driver.make_go(c, timeout_s=GO_TIMEOUT_S)
    press = _driver.make_press(c, settle_frames=PRESS_SETTLE_FRAMES, timeout_s=PRESS_TIMEOUT_S)
    try:
        c.wait_for_ready(proc, timeout_s=300)
        print("READY (headed)")
        press("8", 4)  # Ace hat — the reported-overlap state
        for (w, h) in RESOLUTIONS:
            rs = go("set_window_size", w=w, h=h)
            got = rs.get("window_size", {})
            name = "res_%dx%d" % (w, h)
            sh = go("screenshot", path="user://rig/%s.png" % name).get("screenshot", {})
            print("SHOT %-12s req=%dx%d got=%sx%s saved=%s -> %s" % (
                name, w, h, got.get("w"), got.get("h"), sh.get("saved"), sh.get("abs")))
    finally:
        go("stop"); c.terminate_listener(proc)


if __name__ == "__main__":
    main()
