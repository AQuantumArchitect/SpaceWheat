#!/usr/bin/env python3
"""Headed screenshot capture — verify the UI actually LOOKS right.

Boots the rig in headed mode (opengl3 on WSL) and captures PNGs at key states:
  1. boot       — default farm view (look for the "Ace over the action bar" overlap)
  2. icon_hat   — Icon frame selected (the "Add Icon" cost chip should show 🌱5)
  3. ace_hat    — Ace frame selected (the reported overlap)
  4. b_inspect  — B microscope open on a selected plot (new "How this biome behaves" card)

Prints the absolute PNG paths for the caller to read.
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
        r = go("screenshot", path="user://rig/shot_%s.png" % name)
        s = r.get("screenshot", {})
        print("SHOT %-10s saved=%s %sx%s -> %s" % (name, s.get("saved"), s.get("w"), s.get("h"), s.get("abs")))
        return s.get("abs")

    try:
        c.wait_for_ready(proc, timeout_s=300)
        print("READY (headed)")
        paths = {}
        paths["boot"] = shot("boot")
        press("5", 5)                 # Icon hat
        paths["icon_hat"] = shot("icon_hat")
        press("G", 4)                 # select a plot (so Add Icon chip resolves in context)
        paths["icon_plot"] = shot("icon_plot")
        press("8", 5)                 # Ace hat (the reported overlap)
        paths["ace_hat"] = shot("ace_hat")
        press("B", 6)                 # B microscope (plot still selected)
        paths["b_inspect"] = shot("b_inspect")
        print("\nPATHS:")
        for k, v in paths.items():
            print("  %s = %s" % (k, v))
    finally:
        go("stop"); c.terminate_listener(proc)


if __name__ == "__main__":
    main()
