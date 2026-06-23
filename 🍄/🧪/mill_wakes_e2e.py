#!/usr/bin/env python3
"""Final E2E: drive the village arc by keyboard all the way to mill_wakes.

A) forest + village incorporation → learn Mill (genuine keyboard arc).
B) ~3 keyboard market cycles to show 🔨 accumulating in PLAY (proves the fix).
C) bridge the rest of the 🔨/🌱 plant economy via add_resource (the market-supply
   of 🔨 is independently verified; this just shortcuts the long grind so we can
   verify the PLANT physics). Plant the Mill into Village by KEYBOARD (Icon hat →
   empty plot → R → inject submenu, slot found via submenu_state).
D) excite 💨 (Druid Hadamard + evolve) → check mill_wakes fires.
"""
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

SCEN = os.environ.get("PT_SCENARIO", "demos_normal")
os.environ.setdefault("RIG_DISABLE_LOOKAHEAD", "0")
PLOT_KEYS = ["G", "H", "J", "K", "L", "SEMICOLON"]
_turn = [10]


def t():
    _turn[0] += 1
    return _turn[0]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id=SCEN, display_mode="headless",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})

    def go(action, **kw):
        kw.pop("timeout_s", None)
        return c.run_turn(t(), action, timeout_s=90, **kw)

    def press(seq, settle=4):
        if isinstance(seq, str):
            seq = [seq]
        for k in seq:
            c.run_turn(t(), "press_key", key=k, settle_frames=settle, timeout_s=25)

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
        return go("berry_state", biome=b).get("consumed_count", "?")

    def has_mill():
        return any(i.get("north") == "💨" and i.get("south") == "🔨" for i in known())

    def mwprog():
        fp = go("flag_progress", id="mill_wakes")
        parts = [f"{ps['score']:.2f}" for ps in fp.get("predicates", [])]
        return f"fired={fp.get('fired')} combined={fp.get('combined'):.2f} [{','.join(parts)}]"

    def incorporate(ripen=900):
        press("0")
        for pk in PLOT_KEYS:
            press(pk, settle=2); press("E", settle=3)
        press("5")
        for pk in PLOT_KEYS:
            press(pk, settle=2); press("F", settle=3)
        go("time_skip", phrames=ripen)
        for pk in PLOT_KEYS:
            press(pk, settle=2); press("R", settle=4)

    try:
        c.wait_for_ready(proc, timeout_s=180)
        print("READY")

        # ---- A: arc → learn Mill ----
        press("T")
        for _ in range(6):
            incorporate()
            if "forest_listener" in flags():
                break
        print("forest_listener:", "forest_listener" in flags())
        press("Y")
        for _ in range(7):
            incorporate()
            fl = flags()
            if "village_stirs" in fl:
                press("C"); press("I", settle=3)
                for pk in PLOT_KEYS:
                    press(pk, settle=2); press("R", settle=3)
                press("ESCAPE", settle=3)
                go("time_skip", phrames=60)
                press("C"); press("U", settle=3)
                for pk in PLOT_KEYS:
                    press(pk, settle=2); press("R", settle=4)
                press("ESCAPE", settle=3)
            if has_mill():
                break
        print("MILL learned:", has_mill(), " village berry:", berry("Village"))
        if not has_mill():
            print("✗ stop: Mill not learned"); return

        # ---- B: a few KEYBOARD market cycles (prove 🔨 accrues in play) ----
        print("\n-- keyboard market cycles (🔨 in play) --  start 🔨=%d 🍞=%d" % (res().get("🔨", 0), res().get("🍞", 0)))
        for mr in range(1, 4):
            press("C"); press("Y", settle=3); press("E", settle=3)
            for pk in PLOT_KEYS:
                press(pk, settle=2); press("R", settle=3)
            press("ESCAPE", settle=3)
            go("time_skip", phrames=40)
            press("C"); press("U", settle=3)
            for pk in PLOT_KEYS:
                press(pk, settle=2); press("R", settle=4)
            press("ESCAPE", settle=3)
            print("   [mkt%d] 🔨=%d 🍞=%d" % (mr, res().get("🔨", 0), res().get("🍞", 0)))

        # ---- C: bridge economy + PLANT by keyboard ----
        need_h = max(0, 13 - res().get("🔨", 0))
        need_s = max(0, 5 - res().get("🌱", 0))
        if need_h:
            go("add_resource", emoji="🔨", amount=need_h)
        if need_s:
            go("add_resource", emoji="🌱", amount=need_s)
        print("\n-- bridged economy: 🔨=%d 🌱=%d (granted +%d🔨 +%d🌱) --" % (res().get("🔨", 0), res().get("🌱", 0), need_h, need_s))

        print("  mill_wakes before plant:", mwprog())
        press("Y")          # Village active
        press("5")          # Icon hat
        planted = False
        for pk in PLOT_KEYS:                      # find a plot that opens the inject submenu
            press(pk, settle=2)
            press("R", settle=4)                  # open inject submenu
            sm = go("submenu_state")
            if not sm.get("in_submenu"):
                continue
            for page in range(6):
                slots = go("submenu_state").get("slots", {})
                slot_for_mill = None
                for k, v in slots.items():
                    if v.get("north") == "💨" and v.get("south") == "🔨":
                        slot_for_mill = k
                        break
                if slot_for_mill:
                    print(f"  Mill in submenu slot {slot_for_mill} (plot {pk}, page {page}); slots={slots}")
                    press(slot_for_mill, settle=4)
                    planted = True
                    break
                press("F", settle=2)  # page/next (or close); re-check
                if not go("submenu_state").get("in_submenu"):
                    break
            if planted:
                break
        print("  planted:", planted, " 🔨 after:", res().get("🔨", 0))
        print("  mill_wakes after plant:", mwprog())

        # ---- D: excite 💨 → mill_wakes ----
        for rnd in range(1, 6):
            press("0")  # Druid
            for pk in PLOT_KEYS:
                press(pk, settle=2); press("E", settle=3)   # Hadamard each register
            go("time_skip", phrames=300)
            print(f"  [excite{rnd}] mill_wakes: {mwprog()}")
            if "mill_wakes" in flags():
                print("  ✓✓ MILL_WAKES FIRED"); break
        print("\nFINAL flags:", sorted(flags().keys()))
    finally:
        go("stop")
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
