#!/usr/bin/env python3
"""Isolate the apprentice-arc Mill-learning mechanic with full quest-state visibility.

Boot → Village → incorporate to berry>=3 (fires village_stirs, offers the apprentice
arc quest) → step accept (ARC tab) → ready (time_skip with Village current_biome) →
claim (COMMITMENTS tab) → check known_icons for Mill (💨/🔨). Dumps story_offers +
active_quests (with status) at every step so the exact break point is visible.
"""
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

os.environ.setdefault("RIG_DISABLE_LOOKAHEAD", "0")
PLOT = ["G", "H", "J", "K", "L", "SEMICOLON"]
_turn = [10]


def t():
    _turn[0] += 1
    return _turn[0]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})

    def go(a, **k):
        k.pop("timeout_s", None)
        return c.run_turn(t(), a, timeout_s=90, **k)

    def press(seq, s=4):
        if isinstance(seq, str):
            seq = [seq]
        for k in seq:
            c.run_turn(t(), "press_key", key=k, settle_frames=s, timeout_s=25)

    def flags():
        return go("story_flags").get("flags_fired", {}) or {}

    def known():
        return go("known_icons").get("icons", []) or []

    def has_mill():
        return any(i.get("north") == "💨" and i.get("south") == "🔨" for i in known())

    def berry(b):
        return go("berry_state", biome=b).get("consumed_count", "?")

    def qstate(bn):
        return go("berry_state", biome=bn).get("qubits", [])

    def active_biome():
        return go("biome_slots").get("active", "")

    def biome_key(name):
        for s in go("biome_slots").get("slots", []):
            if s.get("biome") == name:
                return s.get("key")
        return None

    def ensure_hat(h):
        other = "7" if h != "7" else "8"
        press(other, 2); press(h, 2)

    def offers():
        so = go("story_offers").get("story_offers", []) or []
        return [f"id{o.get('id')}:{o.get('category','?')}:{o.get('reward_icon_north','')}/{o.get('reward_icon_south','')}" for o in so]

    def actives():
        aq = go("active_quests").get("quests", []) or []
        return [f"id{q.get('id')}:status={q.get('status','?')}:{q.get('reward_icon_north','')}/{q.get('reward_icon_south','')}" for q in aq]

    def dump(tag):
        print(f"  [{tag}] berry={berry('Village')} active_biome={active_biome()} mill={has_mill()}")
        print(f"        offers={offers()}")
        print(f"        actives={actives()}")

    def incorporate(bn="Village", ripen=900):
        qs = qstate(bn)
        plots = PLOT[:len(qs)] if qs else PLOT
        ensure_hat("0")
        for pk in plots:
            press(pk, 3); press("E", 3)
        ensure_hat("5")
        trk = [bool(q.get("tracked")) for q in qstate(bn)]
        for i, pk in enumerate(plots):
            if i < len(trk) and not trk[i]:
                press(pk, 3); press("F", 3)
        go("time_skip", phrames=ripen)
        for pk in plots:
            press(pk, 3); press("R", 4)

    try:
        c.wait_for_ready(proc, timeout_s=180)
        # village_stirs requires forest_listener (StarterForest berry>=3) as a prereq.
        print("=== ACT1: StarterForest → forest_listener ===")
        fk = biome_key("StarterForest") or "T"
        press(fk)
        for rnd in range(1, 7):
            incorporate("StarterForest")
            fl = flags()
            print(f"  [forest {rnd}] berry={berry('StarterForest')} listener={'forest_listener' in fl}")
            if "forest_listener" in fl:
                break
        vk = biome_key("Village") or "Y"
        press(vk)
        # The apprentice arc's state_predicate is berry_consumed_count_gte(Village, 3),
        # but soft_gate(3,3,1.5)=0.5 < 0.85 completion threshold — it only flips "ready"
        # around berry>=6. Incorporation grows berry; time_skip does NOT. So push to >=6.
        print("=== incorporate Village to berry>=6 + village_stirs ===")
        for rnd in range(1, 8):
            incorporate("Village")
            fl = flags()
            b = berry("Village")
            print(f"  [inc {rnd}] berry={b} village_stirs={'village_stirs' in fl}")
            if "village_stirs" in fl and isinstance(b, int) and b >= 6:
                break
        dump("post-stirs")

        # --- ACCEPT: ARC tab (I). Accepting row 0 REMOVES it, so every remaining
        # arc_quest shifts down to index 0 — re-select index 0 and accept repeatedly
        # (order-independent; once index 0 is a flag-timeline row, R no-ops). ---
        print("\n=== ACCEPT (C → I arc tab → G,R × N, re-selecting index 0) ===")
        press(vk)  # ensure Village is current_biome
        press("C"); press("I", 4)
        for _ in range(4):
            press("G", 3)      # always re-select index 0
            press("R", 4)      # _accept_selected_arc
        press("ESCAPE", 3)
        dump("post-accept")

        # --- READY: let physics_process flip it (needs current_biome=Village) ---
        print("\n=== READY (press Village, time_skip) ===")
        press(vk)
        go("time_skip", phrames=120)
        dump("post-ready-skip")

        # --- CLAIM: COMMITMENTS tab (U). Same re-select-index-0 loop. ---
        print("\n=== CLAIM (C → U commitments → G,R × N, re-selecting index 0) ===")
        press("C"); press("U", 4)
        for _ in range(4):
            press("G", 3)
            press("R", 4)
        press("ESCAPE", 3)
        dump("post-claim")

        print("\n=== RESULT mill learned:", has_mill(), "===")
        print("known:", [f"{i.get('north')}/{i.get('south')}" for i in known()])
    finally:
        go("stop")
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
