#!/usr/bin/env python3
"""Drive the village arc by KEYBOARD: forest_listener → village_stirs → learn Mill.

Phase A: incorporate StarterForest registers (Druid-excite → Icon-track → ripen →
         incorporate) until forest_listener fires (StarterForest berry >= 3).
Phase B: switch to Village, incorporate its registers until village_stirs fires;
         accept the apprentice arc_quest (C→I→R), keep incorporating to berry>=3,
         claim it (C→U→R) → learn the Mill icon (💨/🔨).

Read-only instruments: flag_progress, berry_state, known_icons. All DRIVING is
through press_key (the real input stack). No physics pokes, no forced flags.
"""
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))  # 🍄/🎛️
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
    proc = c.start_listener(
        scenario_id=SCEN, display_mode="headless",
        extra_env={"RIG_DISABLE_LOOKAHEAD": os.environ.get("RIG_DISABLE_LOOKAHEAD", "0")},
    )

    def go(action, **kw):
        to = kw.pop("timeout_s", 60)
        return c.run_turn(t(), action, timeout_s=to, **kw)

    def press(seq, settle=4):
        if isinstance(seq, str):
            seq = [seq]
        for k in seq:
            go("press_key", key=k, settle_frames=settle, timeout_s=25)

    def fprog(fid):
        fp = go("flag_progress", id=fid)
        if fp.get("error"):
            return f"{fid}: {fp['error']}"
        parts = [f"{ps['score']:.2f}" for ps in fp.get("predicates", [])]
        return f"{fid} fired={fp.get('fired')} combined={fp.get('combined'):.2f} [{','.join(parts)}]"

    def berry(biome):
        bs = go("berry_state", biome=biome)
        return bs.get("consumed_count", "?"), round(bs.get("consumed_phase", 0.0), 2)

    def known():
        return go("known_icons").get("icons", [])

    def incorporate(biome_key, ripen=900):
        """One incorporation sweep on the active biome (biome_key already pressed)."""
        # Druid-excite off the ground eigenstate so qubits precess.
        press("0")
        for pk in PLOT_KEYS:
            press(pk, settle=2)
            press("E", settle=3)          # Druid E = Hadamard
        # Icon-track every register.
        press("5")
        for pk in PLOT_KEYS:
            press(pk, settle=2)
            press("F", settle=3)          # toggle Berry track + resume play
        go("time_skip", phrames=ripen, timeout_s=200)
        # Incorporate (still on Icon hat — do NOT re-press 5).
        for pk in PLOT_KEYS:
            press(pk, settle=2)
            press("R", settle=4)          # ripe → incorporate

    try:
        c.wait_for_ready(proc, timeout_s=180)
        print("READY")
        print("  ", fprog("forest_listener"))
        print("  ", fprog("village_stirs"))
        print("   forest berry:", berry("StarterForest"), " village berry:", berry("Village"))

        # ---- PHASE A: forest_listener (StarterForest berry >= 3) ----
        print("\n== PHASE A: forest incorporation ==")
        press("T")  # biome slot 0 = StarterForest
        for rnd in range(1, 7):
            incorporate("T")
            fc, fp = berry("StarterForest")
            print(f"  [A{rnd}] forest berry={fc} phase={fp} | {fprog('forest_listener')}")
            flags = go("story_flags").get("flags_fired", {})
            if "forest_listener" in flags:
                print("  ✓ forest_listener FIRED")
                break

        # ---- PHASE B: village_stirs + learn Mill ----
        print("\n== PHASE B: village incorporation + arc quest ==")
        press("Y")  # biome slot 1 = Village
        arc_accepted = False
        for rnd in range(1, 9):
            incorporate("Y")
            vc, vp = berry("Village")
            flags = go("story_flags").get("flags_fired", {})
            print(f"  [B{rnd}] village berry={vc} phase={vp} | {fprog('village_stirs')} | icons={len(known())}")

            # Once village_stirs fires, accept its arc quest via QuestBoard (C→I→select→R).
            if "village_stirs" in flags and not arc_accepted:
                so = go("story_offers").get("story_offers", [])
                print("     village_stirs FIRED. story_offers:", [(o.get('id'), o.get('faction')) for o in so])
                press("C")              # open QuestBoard
                press("I", settle=3)    # Arc frame
                press("G", settle=3)    # select first arc row
                press("R", settle=4)    # accept arc quest
                press("ESCAPE", settle=3)
                aq = go("active_quests").get("quests", [])
                print("     after accept, active_quests:", [(q.get('faction'), q.get('status')) for q in aq])
                arc_accepted = True

            # Try to claim the arc quest once accepted + predicates met (Commitments U→R).
            if arc_accepted:
                press("C")
                press("U", settle=3)    # Commitments frame
                press("G", settle=3)    # select first commitment
                press("R", settle=4)    # complete/claim
                press("ESCAPE", settle=3)
                ic = known()
                has_mill = any(i.get("north") == "💨" or i.get("south") == "🔨" for i in ic)
                if has_mill:
                    print(f"  ✓ MILL LEARNED — icons={ic}")
                    break

        print("\n== FINAL ==")
        print("  ", fprog("forest_listener"))
        print("  ", fprog("village_stirs"))
        print("  ", fprog("mill_wakes"))
        print("   known_icons:", known())
        print("   forest berry:", berry("StarterForest"), " village berry:", berry("Village"))
    finally:
        go("stop", timeout_s=10)
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
