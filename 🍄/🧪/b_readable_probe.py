#!/usr/bin/env python3
"""Capture the B Biome Microscope at a small window so the centered MEDIUM panel
fills the frame and its "How this biome behaves" card text is legible."""
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
PRESS_SETTLE_FRAMES = 5

_driver = TurnDriver(start=0)
t = _driver.t


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headed",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})
    go = _driver.make_go(c, timeout_s=GO_TIMEOUT_S)
    press = _driver.make_press(c, settle_frames=PRESS_SETTLE_FRAMES, timeout_s=PRESS_TIMEOUT_S)
    try:
        c.wait_for_ready(proc, timeout_s=300)
        go("set_window_size", w=820, h=760)
        print("READY")
        # Evolve a bit so marginals are live, select a plot, open B.
        go("time_skip", phrames=200)
        press("G", 4)
        press("B", 6)
        sh = go("screenshot", path="user://rig/b_readable.png").get("screenshot", {})
        print("SHOT b_readable saved=%s -> %s" % (sh.get("saved"), sh.get("abs")))
        # Also dump the live H-gap / Var(H) for StarterForest to cross-check the card.
        ev = go("energy_variance", biome="StarterForest")
        print("StarterForest  H-gap=%.4f  Var(H)=%.4f" % (ev.get("h_gap", -1), ev.get("var_h", -1)))
    finally:
        go("stop"); c.terminate_listener(proc)


if __name__ == "__main__":
    main()
