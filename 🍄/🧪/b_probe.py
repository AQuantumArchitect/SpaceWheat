#!/usr/bin/env python3
"""B (Biome Microscope) smoke test — confirm it opens with a plot selected and renders.

The prior crash: BiomeInspectorOverlay assigned get_marginal() (a float) to a typed
Dictionary var, so opening B on a real plot threw at runtime. The existing surface smoke
test never caught it (it activated with NO plot selected → early-returns before get_marginal).
This selects a plot first, then opens B, and reads the overlay snapshot.
"""
import os, sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402
from turn_driver import TurnDriver  # noqa: E402

os.environ.setdefault("RIG_DISABLE_LOOKAHEAD", "0")
# Historical per-script driver timeouts — deliberately NOT unified (SLOP_PATROL knot #8).
GO_TIMEOUT_S = 90
PRESS_TIMEOUT_S = 25
PRESS_SETTLE_FRAMES = 4

_driver = TurnDriver(start=0)
t = _driver.t


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})
    go = _driver.make_go(c, timeout_s=GO_TIMEOUT_S)
    press = _driver.make_press(c, settle_frames=PRESS_SETTLE_FRAMES, timeout_s=PRESS_TIMEOUT_S)
    try:
        c.wait_for_ready(proc, timeout_s=180)
        g = go("grid_snapshot").get("grid", {})
        biomes = g.get("biomes", g)
        print("biomes:", biomes)
        # Select a plot on the farm so B has something to inspect, then open B.
        press("G", 3)                 # plot select
        ist = go("instrument_state")
        print("instrument plot_idx:", ist.get("current_plot_idx"), "biome:", ist.get("current_biome"))
        press("B", 5)                 # open the Biome Microscope
        snap = go("overlay_snapshot", overlay="biome_detail")
        print("biome_detail snapshot ok:", snap.get("ok"), "keys:", list((snap.get("snapshot") or {}).keys()))
        vd = snap.get("snapshot", {})
        # The physics section should report the biome's H-gap / Var(H) if surfaced in visible data.
        print("visible_data sample:", {k: vd.get(k) for k in ("scope_mode", "active_plot_idx", "plot_emoji")})
        # Re-read instrument to confirm the listener didn't die when B opened.
        alive = go("instrument_state")
        print("RESULT B opened without killing rig:", "OK" if alive.get("current_biome") is not None else "FAIL")
    finally:
        go("stop"); c.terminate_listener(proc)


if __name__ == "__main__":
    main()
