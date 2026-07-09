#!/usr/bin/env python3
"""Store-page kit capture: stage a lively farm, screenshot the money moments.

Output → releases/store_kit/: farm beauty shots, microscope, quest board,
ceremony, plus a frame burst (frames/*.png) for GIF assembly. Not a test —
a photographer. Run headed on :0.
"""
import sys
import shutil
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

ROOT = HERE.parent.parent
KIT = ROOT / "releases" / "store_kit"
FRAMES = KIT / "frames"

_t = [0]


def turn():
    _t[0] += 1
    return _t[0]


def main():
    KIT.mkdir(parents=True, exist_ok=True)
    FRAMES.mkdir(parents=True, exist_ok=True)
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headed",
                            listener_log_path=ROOT / "logs" / "store_kit.log",
                            rig_log_profile="quiet")
    try:
        print("ready:", c.wait_for_ready(proc, timeout_s=200))

        def t(action, **kw):
            return c.run_turn(turn(), action, timeout_s=30, **kw)

        def press(k, settle=6):
            return t("press_key", key=k, settle_frames=settle)

        def shot(name, settle=6, dest=None):
            r = t("screenshot", path="user://rig/%s.png" % name, settle_frames=settle)
            a = r.get("screenshot", {}).get("abs", "")
            if a and Path(a).exists():
                shutil.copy(a, (dest or KIT) / ("%s.png" % name))
                print("shot", name)
            return r

        # Stage: superposition everywhere, wake all six plots, measure a few.
        t("gate_inject", gate="hadamard", biome="StarterForest", positions=[])
        for k in ["g", "h", "j", "k", "l", ";"]:
            press(k, settle=4)
        time.sleep(1.0)
        shot("01_living_farm", settle=10)

        # Measure two plots (cyan terminals) for the mixed live/locked look.
        press("g", settle=4)
        press("r", settle=10)
        press("j", settle=4)
        press("r", settle=10)
        shot("02_measured_mix", settle=10)

        # GIF burst: tap-pop moment. Frames every ~0.12s around a pop.
        bs = t("bubble_state")
        target = None
        for b in bs.get("bubbles", []):
            if b.get("measured"):
                target = b["pos"]
                break
        for i in range(6):
            shot("f%02d" % i, settle=3, dest=FRAMES)
        if target:
            t("tap", pos=target, settle_frames=2)  # pop → burst + flier
        for i in range(6, 22):
            shot("f%02d" % i, settle=3, dest=FRAMES)

        # Village: the tristable heart of the campaign.
        press("y", settle=10)
        t("gate_inject", gate="hadamard", biome="Village", positions=[])
        for k in ["g", "h", "j"]:
            press(k, settle=4)
        time.sleep(1.5)
        shot("03_village", settle=10)

        # Microscope (B): the physics, legible.
        press("b", settle=12)
        shot("04_microscope", settle=8)
        press("escape", settle=8)

        # Quest board (C): contracts.
        press("c", settle=12)
        shot("05_contracts", settle=8)
        press("escape", settle=8)

        # The ceremony door (the ending beat, also a great store shot).
        t("fire_flag", id="island_free", settle_frames=20)
        time.sleep(1.6)
        shot("06_ceremony_title", settle=6)
        for _ in range(3):
            t("tap", screen=[640, 400], settle_frames=8)
            time.sleep(0.7)
        shot("07_ceremony_door", settle=6)

    finally:
        c.terminate_listener(proc)
    print("kit at", KIT)
    return 0


if __name__ == "__main__":
    sys.exit(main())
