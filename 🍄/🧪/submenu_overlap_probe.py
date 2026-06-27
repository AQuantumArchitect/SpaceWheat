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
    def press(seq, s=4):
        if isinstance(seq, str): seq = [seq]
        for k in seq: c.run_turn(t(), "press_key", key=k, settle_frames=s, timeout_s=30)
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
