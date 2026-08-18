#!/usr/bin/env python3
"""The Act-0 tutorial chain, played as a STRANGER: each step accepted from the
board's story offers, driven ONLY by the keys its on-screen hint names (F/R/Q
grammar, TheDemos-first order), then claimed. Asserts every step COMPLETES.
This is the first-night player's exact path — a step that can't be finished
from its own hint is a P0.

No resource injection: the boot wallet must carry the whole chain.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

_t = [0]


def turn():
    _t[0] += 1
    return _t[0]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headed")
    findings = []
    completed = []
    try:
        print("ready:", c.wait_for_ready(proc, timeout_s=200))

        def t(action, **kw):
            return c.run_turn(turn(), action, timeout_s=60, **kw)

        def press(k, settle=8, shift=False):
            return t("press_key", key=k, shift=shift, settle_frames=settle)

        def offers():
            return t("story_offers").get("story_offers", []) or []

        def actives():
            aq = t("active_quests", full=True)
            return aq.get("quests", []) or []

        def find_step(teach):
            """Return ('offer'|'active'|'', quest) for the step teaching `teach`."""
            for q in offers():
                if str(q.get("tutorial_teaches", "")) == teach:
                    return "offer", q
            for q in actives():
                if str(q.get("tutorial_teaches", "")) == teach:
                    return "active", q
            return "", {}

        def wallet():
            r = t("resource_snapshot").get("resources", {})
            return (r.get("resources", r) or {})

        def note(s):
            print("FINDING:", s)
            findings.append(s)

        def biome_key(name):
            for s in t("biome_slots").get("slots", []):
                if s.get("biome") == name:
                    return str(s.get("key")).lower()
            return ""

        # 2026-08-17 capstone order: reap moved LAST (once-affordable early,
        # funnel-locked until its step; the entanglement claim pays it).
        _ORDER = ["core_loop", "contracts", "wayfinding",
                  "superposition", "entanglement", "reap_season"]

        def chain_advanced_past(teach):
            # The Act-0 chain is strictly linear (each claim unlocks the next), so a LATER
            # step being live proves `teach` already completed. Since predicate-driven steps
            # now auto-accept AND auto-claim (the progress bar is the teacher), a step whose
            # soft condition is already met when it unlocks — StarterForest coherence ≥ 0.3
            # in the naturally oscillating forest (superposition) — completes before this
            # data-shortcut probe can poll it. That is a pass, not a "never offered".
            i = _ORDER.index(teach)
            live = {str(x.get("tutorial_teaches", "")) for x in offers() + actives()}
            return any(later in live for later in _ORDER[i + 1:])

        def run_step(teach, drive, rounds=10):
            where, q = find_step(teach)
            if where == "":
                if chain_advanced_past(teach):
                    print("  ✓ step '%s' auto-completed (condition already met on unlock)" % teach)
                    completed.append(teach)
                    return True
                note("step '%s' never offered" % teach)
                return False
            if where == "offer":
                acc = t("accept_quest", quest_id=int(q.get("id", -1)))
                if not acc.get("ok", acc.get("success", False)):
                    note("step '%s' offer would not accept: %s" % (teach, acc))
                    return False
            qid = int(q.get("id", -1))
            for rnd in range(rounds):
                drive(rnd)
                t("complete_or_claim", quest_id=qid)
                where2, q2 = find_step(teach)
                if where2 == "":
                    print("  ✓ step '%s' completed (round %d)" % (teach, rnd + 1))
                    completed.append(teach)
                    return True
                print("    [%s r%d] progress=%.2f status=%s" % (
                    teach, rnd, float(q2.get("progress", 0) or 0), q2.get("status")))
            note("step '%s' never completed after %d rounds" % (teach, rounds))
            return False

        print("boot wallet:", json.dumps(wallet(), ensure_ascii=False))
        print("offers at boot:", [str(o.get("tutorial_teaches", o.get("body", "")))[:40] for o in offers()])

        dk = biome_key("TheDemos")
        fk = biome_key("StarterForest")

        # STEP 0 core_loop — hint: G (or tap), F explores, R strikes, Q extracts.
        def drive0(_rnd):
            press(dk, settle=6)
            press("8", settle=4)
            press("g", settle=6)
            press("f", settle=10)
            press("r", settle=12)
            press("q", settle=10)
        run_step("core_loop", drive0)

        # STEP 1 contracts — hint: C board, accept, deliver 2x🌾. (The 2026-08-17
        # reorder moved the ceremony up: it now rides the same Ace verbs step 0
        # taught, and the granary usually holds the grain already.)
        def drive2(_rnd):
            if float(wallet().get("🌾", 0)) < 2:
                press(dk, settle=6)
                press("8", settle=4)
                press("g", settle=4)
                press("f", settle=8)
                press("r", settle=10)
                press("q", settle=8)
        run_step("contracts", drive2, rounds=8)

        # STEP 2 wayfinding — hint: the biome tabs; arrival IS the gate
        # (active_biome_is). The berry ritual that used to wall both personas
        # here is mid-game content now (act-3 first_breath).
        def drive3(_rnd):
            press(fk, settle=10)
        run_step("wayfinding", drive3)

        # STEP 3 superposition — hint: Druid hat (0), E Hadamard, coherence>=0.3.
        def drive4(rnd):
            press(fk, settle=8)
            press("0", settle=4)
            press("ghjkl;"[rnd % 6], settle=4)
            press("e", settle=8)
        run_step("superposition", drive4)

        # STEP 4 entanglement — hint: Operator (9), Shift-check two plots, R, pick Bell (Q).
        def drive5(_rnd):
            press(fk, settle=8)
            press("9", settle=4)
            # Stray checks accumulate from plain re-presses (re-press on the
            # current plot toggles its checkbox) — clear before checking the
            # deliberate pair, exactly like a player tidying the board with '.
            if t("instrument_state").get("checked_plots"):
                # ' = bulk clear; the string "'" is an unknown key to the rig
                # mapper (same as "[") — send the keycode (KEY_APOSTROPHE=39).
                t("press_key", keycode=39, settle_frames=6)
            press("g", settle=6, shift=True)
            press("h", settle=6, shift=True)
            press("r", settle=10)      # opens the gate picker
            press("q", settle=12)      # Bell
            t("time_skip", phrames=300)
        run_step("entanglement", drive5, rounds=8)

        # STEP 5 reap_season — the CAPSTONE: come home, put the field in play
        # (reap only has material when explored plots are still in the season),
        # then Ace hat (8), Shift+F. Locked by the funnel until this step is
        # live; the entanglement claim's 🍼 pays its cost, so a refusal here
        # is a real finding.
        def drive_reap(rnd):
            press(dk, settle=8)
            press("8", settle=4)
            press("ghjkl;"[rnd % 6], settle=4)
            press("f", settle=8)           # explore — puts the plot in play
            press("f", settle=12, shift=True)
        run_step("reap_season", drive_reap)

        print("\ncompleted steps:", completed)
        print("final wallet:", json.dumps(wallet(), ensure_ascii=False))
    finally:
        c.terminate_listener(proc)

    print("\n== FINDINGS (%d) ==" % len(findings))
    for f in findings:
        print(" -", f)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
