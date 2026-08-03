#!/usr/bin/env python3
"""Injection submenu costs + dynamic 'Ace overlaps action bar' hunt.

submenu: StarterForest has 5 qubits / 6 plots, so plot ; (index 5) is EMPTY.
         Icon hat + R there opens the Add-Icon submenu where per-icon costs live.
overlap: open/close overlays in sequence + arm a destructive toast, screenshotting
         the action bar each time to catch any stuck/duplicated 'Ace on top' state.
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
        sh = go("screenshot", path="user://rig/so_%s.png" % name).get("screenshot", {})
        print("SHOT %-14s saved=%s -> %s" % (name, sh.get("saved"), sh.get("abs")))
    try:
        c.wait_for_ready(proc, timeout_s=300)
        print("READY")
        # Bridge resources so inject options render as affordable (varied emojis + sprouts).
        for emo, amt in [("🌱", 80), ("🌾", 40), ("💧", 40), ("🪵", 40), ("🔨", 40), ("❄", 40)]:
            go("add_resource", emoji=emo, amount=amt)
        # --- Injection submenu (per-icon costs) ---
        press("5", 4)                 # Icon hat
        press("SEMICOLON", 4)         # 6th plot (empty in StarterForest)
        press("R", 5)                 # open Add-Icon submenu
        sm = go("submenu_state")
        print("in_submenu:", sm.get("in_submenu"), "slots:", list((sm.get("slots") or {}).keys()))
        shot("inject_submenu")
        press("ESCAPE", 3)
        # --- Overlap hunt: open/close overlay sequence, then check the action bar ---
        press("B", 4); press("B", 3)  # open + close B
        press("V", 4); press("V", 3)  # open + close V
        press("8", 3)                 # back to Ace hat
        shot("after_overlay_cycle")   # action bar should be clean Ace verbs
        # --- Toast state: arm a destructive cull (Captain Q) ---
        press("7", 3)                 # Captain hat
        press("Q", 4)                 # arm Cull Biome (destructive → confirm toast)
        shot("toast_armed")
        press("ESCAPE", 3)
    finally:
        go("stop"); c.terminate_listener(proc)


if __name__ == "__main__":
    main()
