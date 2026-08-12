#!/usr/bin/env python3
"""Store-kit capture — the screenshots that go on the itch.io page.

Run this, not a hand-cropped screen grab, so the kit can be re-cut for every
release from a known state instead of whatever happened to be on screen.

Two things it gets right that an ad-hoc capture did not:

  1. **SW_DEBUG_READOUT=0.** The rig drives a DEBUG binary, so headed captures
     carry the FPS/PhHz profiler strip that `OS.is_debug_build()` keeps out of
     every shipped build. One kit shipped that way (`01_living_farm`, flagged in
     ITCH_PAGE.md's own note). A store shot must look like the release it
     advertises.
  2. **A played save, not a fresh boot.** Act 0 is three dim spheres on an empty
     field — honest, and a terrible advertisement. Loading a mid-campaign
     checkpoint shows what the game actually looks like once it is alive: a full
     cloud, metro lines, a real wallet.

Usage:
  python3 🍄/🧪/store_kit_shots.py [checkpoint] [outdir]
Defaults: checkpoint=act4_hub, outdir=releases/store_kit
"""
import os
import shutil
import sys
import time
from pathlib import Path

ROOT = Path("/home/primearchitect/ws/SpaceWheat")
sys.path.insert(0, str(ROOT / "\U0001F344" / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402
from turn_driver import TurnDriver  # noqa: E402

CHECKPOINTS = ROOT / "\U0001F344" / "\U0001F9EA" / "checkpoints"

# (keys pressed BEFORE the shot, shot name, what it is for the page).
#
# Overlay keys TOGGLE. An earlier version pressed B then B, C then C and got the
# same field frame three times — the second press closed what the first opened.
# So each beat states the full sequence that reaches its state, and closes the
# previous overlay explicitly rather than assuming a press advances.
BEATS = [
    ([], "01_living_field", "the cloud alive — orbs, couplings, wallet"),
    (["B"], "02_microscope", "the honest numbers behind a field"),
    (["B", "C"], "03_contracts", "the contracts board"),
    (["C", "X"], "04_story", "the arc/story tab"),
    (["X", "U"], "05_forest", "a second biome — different cloud, different physics"),
    (["T"], "06_demos", "TheDemos — where the campaign starts"),
]


def main() -> int:
    checkpoint = sys.argv[1] if len(sys.argv) > 1 else "act4_hub"
    outdir = Path(sys.argv[2]) if len(sys.argv) > 2 else (ROOT / "releases" / "store_kit")
    ckpt = CHECKPOINTS / ("%s.tres" % checkpoint)
    if not ckpt.exists():
        print("no such checkpoint: %s" % ckpt)
        return 2
    outdir.mkdir(parents=True, exist_ok=True)

    driver = TurnDriver(start=0)
    c = RigClient()
    c.kill_existing_listeners()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(
        scenario_id="demos_normal",
        display_mode="headed",
        allow_resource_injection=False,
        extra_env={
            "DISPLAY": os.environ.get("DISPLAY", ":0"),
            "RIG_SKIP_WELCOME": "1",
            # The whole point: shoot the release's chrome, not the rig's.
            "SW_DEBUG_READOUT": "0",
        },
    )
    go = driver.make_go(c, timeout_s=120)
    press = driver.make_press(c, settle_frames=5, timeout_s=30)
    saved = []
    try:
        c.wait_for_ready(proc, timeout_s=300)
        print("READY (headed)")
        r = go("load_game_path", path=str(ckpt))
        if not r.get("loaded", r.get("ok", False)):
            print("checkpoint load FAILED: %s" % str(r)[:300])
            return 3
        print("loaded %s" % checkpoint)
        # Let the field settle: the cloud is force-directed and looks its best
        # once the layout has relaxed rather than caught mid-spring. A headed
        # session runs in real time, so sleeping really is the settle — there is
        # no frame-stepping verb to fake it with.
        time.sleep(6.0)

        for keys, name, why in BEATS:
            for key in keys:
                press(key, 8)
                time.sleep(0.8)
            res = go("screenshot", path="user://rig/%s.png" % name)
            shot = res.get("screenshot", {})
            src = shot.get("abs")
            if not shot.get("saved") or not src:
                print("SHOT %-18s FAILED (%s)" % (name, str(shot)[:120]))
                continue
            dst = outdir / ("%s.png" % name)
            shutil.copyfile(src, dst)
            saved.append(dst)
            print("SHOT %-18s %sx%s -> %s   (%s)" % (
                name, shot.get("w"), shot.get("h"), dst, why))
    finally:
        go("stop")
        c.terminate_listener(proc)

    print("\n%d shots in %s" % (len(saved), outdir))
    return 0 if saved else 1


if __name__ == "__main__":
    raise SystemExit(main())
