#!/usr/bin/env python3
"""mill_wakes E2E v2 — fixes the hat-toggle + empty-plot bugs from v1.

Arc → learn Mill (keyboard). Bridge 🔨/🌱 (market-supply verified). Plant Mill into
an EMPTY Village plot by keyboard (Icon hat guaranteed ON via prior different-hat press;
empty plot, not a register, so R opens the inject submenu). Then let the ⚙→💨 coupling
(1.1) populate wind under evolution → mill_wakes.
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

    def has_mill():
        return any(i.get("north") == "💨" and i.get("south") == "🔨" for i in known())

    def village_qubits():
        return len(go("berry_state", biome="Village").get("qubits", []))

    def mwprog():
        fp = go("flag_progress", id="mill_wakes")
        parts = [f"{ps['score']:.2f}" for ps in fp.get("predicates", [])]
        return f"fired={fp.get('fired')} [{','.join(parts)}]  (💨,⚙pop,berry,⚙attr in slots 2-5)"

    def ensure_hat(hat):
        # Guarantee `hat` is the active frame: press a DIFFERENT hat first so pressing
        # `hat` always turns it ON (re-pressing the active hat toggles it OFF).
        other = "7" if hat != "7" else "8"
        press(other, settle=2)
        press(hat, settle=2)

    def incorporate(ripen=900):
        ensure_hat("0")  # Druid
        for pk in PLOT_KEYS:
            press(pk, settle=2); press("E", settle=3)
        ensure_hat("5")  # Icon
        for pk in PLOT_KEYS:
            press(pk, settle=2); press("F", settle=3)
        go("time_skip", phrames=ripen)
        for pk in PLOT_KEYS:
            press(pk, settle=2); press("R", settle=4)

    try:
        c.wait_for_ready(proc, timeout_s=180)
        print("READY")
        press("T")
        for _ in range(6):
            incorporate()
            if "forest_listener" in flags():
                break
        press("Y")
        for _ in range(7):
            incorporate()
            if "village_stirs" in flags():
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
        nq = village_qubits()
        print(f"MILL learned: {has_mill()}  village qubits: {nq}")
        if not has_mill():
            print("✗ stop: Mill not learned"); return

        # bridge economy (🔨 market-supply independently verified)
        r = res()
        if r.get("🔨", 0) < 13:
            go("add_resource", emoji="🔨", amount=13 - r.get("🔨", 0))
        if r.get("🌱", 0) < 5:
            go("add_resource", emoji="🌱", amount=5 - r.get("🌱", 0))
        print("bridged: 🔨=%d 🌱=%d" % (res().get("🔨", 0), res().get("🌱", 0)))
        print("before plant:", mwprog())

        # PLANT into an empty Village plot. Empty plots are at indices >= qubit count.
        press("Y")            # Village
        ensure_hat("5")       # Icon hat guaranteed ON
        planted = False
        empty_plot_keys = PLOT_KEYS[nq:] + PLOT_KEYS  # try empties first, then all
        for pk in empty_plot_keys:
            press(pk, settle=2)
            press("R", settle=4)
            sm = go("submenu_state")
            if not sm.get("in_submenu"):
                continue
            for page in range(6):
                slots = go("submenu_state").get("slots", {})
                mill_slot = None
                for k, v in slots.items():
                    if v.get("north") == "💨" and v.get("south") == "🔨":
                        mill_slot = k; break
                if mill_slot:
                    print(f"  Mill at submenu slot {mill_slot} (plot {pk}, page {page})")
                    press(mill_slot, settle=4)
                    planted = True; break
                press("F", settle=2)
                if not go("submenu_state").get("in_submenu"):
                    break
            if planted:
                break
        print(f"  planted: {planted}  village qubits now: {village_qubits()}  🔨={res().get('🔨',0)}")
        print("  after plant:", mwprog())

        # Let the ⚙→💨 coupling populate wind. One gentle Hadamard kick, then evolve.
        for rnd in range(1, 7):
            ensure_hat("0")
            for pk in PLOT_KEYS:
                press(pk, settle=2); press("E", settle=2)
            go("time_skip", phrames=250)
            print(f"  [evolve{rnd}] {mwprog()}")
            if "mill_wakes" in flags():
                print("  ✓✓ MILL_WAKES FIRED"); break
        print("\nFINAL flags:", sorted(flags().keys()))
    finally:
        go("stop")
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
