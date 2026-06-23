#!/usr/bin/env python3
"""Diagnose the KEYBOARD market accept→complete path for a 🔨 contract.
Fresh boot, Village. Open market (C→Y), refresh, ACCEPT visible offers, inspect
active_quests (did a Millwright delivery get captured?), then COMPLETE via
Commitments and watch 🔨/🍞/👥. Pinpoints whether the in-play grind actually works."""
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

os.environ.setdefault("RIG_DISABLE_LOOKAHEAD", "0")
PLOT_KEYS = ["G", "H", "J", "K", "L", "SEMICOLON"]
_turn = [10]


def t():
    _turn[0] += 1
    return _turn[0]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    mode = os.environ.get("DISPLAY_MODE", "headless")
    proc = c.start_listener(scenario_id="demos_normal", display_mode=mode,
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0",
                                       "RIG_RENDERING_DRIVER": os.environ.get("RIG_RENDERING_DRIVER", "opengl3")})

    def go(action, **kw):
        kw.pop("timeout_s", None)
        return c.run_turn(t(), action, timeout_s=60, **kw)

    def press(seq, settle=4):
        if isinstance(seq, str):
            seq = [seq]
        for k in seq:
            c.run_turn(t(), "press_key", key=k, settle_frames=settle, timeout_s=25)

    def res():
        r = go("resource_snapshot").get("resources") or {}
        if isinstance(r, dict) and isinstance(r.get("resources"), dict):
            r = r["resources"]
        return r

    def active():
        q = go("active_quests", full=True).get("quests", [])
        return [(x.get("faction"), int(x.get("type", -1)), x.get("status"),
                 x.get("resource"), x.get("quantity"),
                 x.get("reward_resources", x.get("reward_resource_plan"))) for x in q]

    try:
        c.wait_for_ready(proc, timeout_s=180)
        press("Y")
        print("start res:", {k: res().get(k, 0) for k in ("🔨", "🍞", "👥")})
        for rnd in range(1, 5):
            press("C"); press("Y", settle=3); press("E", settle=3)
            print(f"\n-- round {rnd}: board pool --")
            bm = go("board_market", biome="Village")
            for o in bm.get("offers", []):
                print("   pool:", o.get("faction"), o.get("resource"), "x", o.get("quantity"), "->", o.get("reward_resources"))
            for pk in PLOT_KEYS:
                press(pk, settle=2); press("R", settle=3)   # accept visible
            print("   active after accept:", active())
            press("ESCAPE", settle=3)
            go("time_skip", phrames=40)
            press("C"); press("U", settle=3)
            for pk in PLOT_KEYS:
                press(pk, settle=2); press("R", settle=4)   # complete/claim
            press("ESCAPE", settle=3)
            print("   res after complete:", {k: res().get(k, 0) for k in ("🔨", "🍞", "👥")})
    finally:
        go("stop")
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
