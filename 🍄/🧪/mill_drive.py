#!/usr/bin/env python3
"""Drive the village arc by KEYBOARD all the way to the Mill plant, measuring the wall.

A) forest incorporation → forest_listener
B) village incorporation → village_stirs; accept ALL arc offers (C→I→accept each),
   time-tick, claim all commitments (C→U→claim each) → learn Mill (💨/🔨).
   SAVE state to user://rig save slot after Mill is learned.
C) MEASURE the plant economy: plant cost is 13 🔨 + 5 🌱. Harvest (Ace Q-extract)
   for sprouts, run market DELIVER contracts for 🔨, and report throughput so we
   can judge whether the 13🔨 cost is reachable by play or needs a balance tune.

Read-only instruments: flag_progress / berry_state / known_icons / resource_snapshot /
action_cost. DRIVING via press_key only.
"""
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402
from turn_driver import TurnDriver  # noqa: E402

SCEN = os.environ.get("PT_SCENARIO", "demos_normal")
os.environ.setdefault("RIG_DISABLE_LOOKAHEAD", "0")
PLOT_KEYS = ["G", "H", "J", "K", "L", "SEMICOLON"]
SAVE_PATH = "user://rig/mill_learned.save"
# Historical per-script driver timeouts — deliberately NOT unified (SLOP_PATROL knot #8).
GO_TIMEOUT_S = 60
PRESS_TIMEOUT_S = 25
PRESS_SETTLE_FRAMES = 4

_driver = TurnDriver(start=10)


t = _driver.t


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(
        scenario_id=SCEN, display_mode="headless",
        extra_env={"RIG_DISABLE_LOOKAHEAD": os.environ.get("RIG_DISABLE_LOOKAHEAD", "0")},
    )

    go = _driver.make_go(c, timeout_s=GO_TIMEOUT_S, caller_override=True)

    press = _driver.make_press(c, settle_frames=PRESS_SETTLE_FRAMES, timeout_s=PRESS_TIMEOUT_S)

    def flags():
        return go("story_flags").get("flags_fired", {}) or {}

    def known():
        return go("known_icons").get("icons", [])

    def res():
        r = go("resource_snapshot").get("resources") or {}
        if isinstance(r, dict) and isinstance(r.get("resources"), dict):
            r = r["resources"]
        return r

    def berry(b):
        bs = go("berry_state", biome=b)
        return bs.get("consumed_count", "?")

    def has_mill():
        return any(i.get("north") == "💨" and i.get("south") == "🔨" for i in known())

    def incorporate(ripen=900):
        press("0")
        for pk in PLOT_KEYS:
            press(pk, settle=2); press("E", settle=3)
        press("5")
        for pk in PLOT_KEYS:
            press(pk, settle=2); press("F", settle=3)
        go("time_skip", phrames=ripen, timeout_s=200)
        for pk in PLOT_KEYS:
            press(pk, settle=2); press("R", settle=4)

    try:
        c.wait_for_ready(proc, timeout_s=180)
        print("READY  res=", res())

        # ---- PHASE A ----
        print("\n== A: forest ==")
        press("T")
        for rnd in range(1, 7):
            incorporate()
            if "forest_listener" in flags():
                print(f"  forest_listener FIRED (forest berry={berry('StarterForest')})"); break

        # ---- PHASE B ----
        print("\n== B: village + learn Mill ==")
        press("Y")
        for rnd in range(1, 8):
            incorporate()
            fl = flags()
            print(f"  [B{rnd}] village berry={berry('Village')} village_stirs={'village_stirs' in fl} icons={len(known())}")
            if "village_stirs" in fl:
                so = go("story_offers").get("story_offers", [])
                print("     story_offers:", [(o.get('id'), o.get('faction'), o.get('category')) for o in so])
                # accept ALL arc offers (the Millwright apprentice is among them)
                press("C"); press("I", settle=3)
                for pk in PLOT_KEYS:
                    press(pk, settle=2); press("R", settle=3)
                press("ESCAPE", settle=3)
                go("time_skip", phrames=60, timeout_s=60)  # let ready-check tick
                aq = go("active_quests").get("quests", [])
                print("     active:", [(q.get('faction'), q.get('status')) for q in aq])
                # claim ALL ready commitments
                press("C"); press("U", settle=3)
                for pk in PLOT_KEYS:
                    press(pk, settle=2); press("R", settle=4)
                press("ESCAPE", settle=3)
                print("     after claim, icons=", known())
            if has_mill():
                print("  ✓ MILL LEARNED"); break

        if has_mill():
            sv = go("save_game_path", path=SAVE_PATH)
            print(f"\n  saved mill-learned state → {SAVE_PATH}  ok={sv.get('saved')}")
        else:
            print("\n  ✗ Mill NOT learned — stopping before economy measure")
            return

        # ---- PHASE C: measure the plant economy ----
        print("\n== C: plant economy (need 13 🔨 + 5 🌱) ==")
        ac = go("action_cost", name="inject_icon", context={"south_emoji": "🔨"})
        print("  inject_icon(🔨) cost =", ac.get("cost"))
        print("  res before grind:", res())

        # Harvest sweep (Ace Q-extract) for sprouts/resources on both biomes.
        for bkey in ("T", "Y"):
            press(bkey); press("8")  # biome, Ace hat
            for pk in PLOT_KEYS:
                press(pk, settle=2)
                press("R", settle=5)   # strike (collapse)
                press("Q", settle=3)   # extract (Ace Q is immediate/safe now)
            go("time_skip", phrames=60, timeout_s=60)
        print("  res after harvest:", res())

        # Market: drive a few DELIVER contracts by keyboard, measure 🔨 gained.
        before = res().get("🔨", 0)
        for mrnd in range(1, 7):
            press("C"); press("Y", settle=3)         # Market frame
            press("E", settle=3)                      # refresh pool
            for pk in PLOT_KEYS:                       # accept every visible offer
                press(pk, settle=2); press("R", settle=3)
            press("ESCAPE", settle=3)
            go("time_skip", phrames=40, timeout_s=60)
            press("C"); press("U", settle=3)          # Commitments
            for pk in PLOT_KEYS:                       # complete everything deliverable
                press(pk, settle=2); press("R", settle=4)
            press("ESCAPE", settle=3)
            cur = res()
            print(f"  [mkt{mrnd}] 🔨={cur.get('🔨',0)} 🌱={cur.get('🌱',0)}  res={ {k:v for k,v in cur.items()} }")
            if cur.get("🔨", 0) >= 13 and cur.get("🌱", 0) >= 5:
                print("  ✓ can afford the Mill plant"); break
        after = res()
        print(f"\n  🔨 gained over market grind: {after.get('🔨',0) - before}  (need 13)")
        print("  FINAL res:", after)
    finally:
        go("stop", timeout_s=10)
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
