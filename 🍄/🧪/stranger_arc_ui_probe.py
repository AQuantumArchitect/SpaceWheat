#!/usr/bin/env python3
"""The Act-0 tutorial, played as a first-night STRANGER through REAL UI ONLY.

Why this exists: tutorial_stranger_probe.py drives the chain with the rig's
accept_quest / complete_or_claim DATA shortcuts — it steps around the exact
key-presses (X→Arc R to accept, C→Commitments R to claim) that trap a human,
which is WHY the opening dead-end survived every test. This probe NEVER touches
those seams. It reads state for orientation (story_offers / active_quests /
resource_snapshot / overlay_text — introspection, not action) and performs every
accept / claim / mechanic with injected KEY PRESSES, exactly what a player types.

It also runs at PLAYER PARITY — RIG_UNLOCK_ALL=0, progressive-disclosure
enforcement ON — so a hat the tutorial names but the spine has not yet unlocked
(the Operator hat at the entanglement step) is a hard stall this probe will catch.
That is the second break: the tutorial must hand the spine forward (fire
loom_opens) so the Operator hat is live before step 4 asks for it. The same
parity also gates the capstone: Shift+F (reap) stays funnel-locked until the
reap_season step itself is live.

Design contract exercised here (2026-08-17 capstone order):
  · steps 0, 2-5 are predicate-driven — they AUTO-accept and AUTO-claim (the
    progress bar is the teacher). The probe just does the mechanic and watches
    the step advance; it presses NO accept/claim key for them.
  · step 1 (contracts) stays MANUAL: accept it on the X→Arc tab (real R), gather
    2× 🌾, deliver it on the C→Commitments tab (real R) — the market-contract
    grammar every player must learn.

Asserts all 6 steps advance with no silent stall. This is Track 2's pass/fail gate.
No resource injection: the boot wallet must carry the whole chain.
"""
import json
import re
import sys
from pathlib import Path

# Resolve the rig relative to THIS file so the probe drives the tree it lives in
# (worktree or main checkout), never a hard-coded checkout. `root_from_file` below
# then pins RigClient.project_root to that same tree.
_RUNNER_ROOT = Path(__file__).resolve().parents[1] / "\U0001F39B️"  # 🍄/🎛️
sys.path.insert(0, str(_RUNNER_ROOT))
from rig_client import RigClient  # noqa: E402

_t = [0]


def turn():
    _t[0] += 1
    return _t[0]


# Arc-tab / Commitments-tab row selection keys (ControlsOverlay.ITEM_KEYS /
# QuestBoard ITEM_KEYS), lower-cased for injection.
SEL_KEYS = ["g", "h", "j", "k", "l", ";"]

# The Act-0 chain, in unlock order (tutorial_arc.json). The chain is strictly linear
# (each step's claim unlocks the next), so a LATER step being live proves an earlier one
# completed — even when it auto-claimed the instant its condition was already met.
# 2026-08-17 reorder: berry/vocabulary left Act 0 for the act-3 chapter; the
# contracts ceremony moved up; wayfinding makes the crossing its own beat.
# 2026-08-17 capstone order: reap moved LAST (once-affordable early, funnel-
# locked until its step; the entanglement claim grants the 🍼 that pays it).
EXPECTED = ["core_loop", "contracts", "wayfinding",
            "superposition", "entanglement", "reap_season"]


def main():
    c = RigClient(root_from_file=_RUNNER_ROOT / "milk_hunt_runner.py")
    c.clear_rig_files(preserve_live_sentinel=False)
    # RIG_UNLOCK_ALL=0 → player parity: locked hats/menus REDIRECT instead of act,
    # exactly what a real first-night player faces. This is what makes the probe a
    # faithful gate for the Operator-hat handoff (Break #2).
    proc = c.start_listener(
        scenario_id="demos_normal",
        display_mode="headless",
        extra_env={"RIG_UNLOCK_ALL": "0"},
    )
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
            return t("active_quests", full=True).get("quests", []) or []

        def find_step(teach):
            """('offer'|'active'|'', quest) for the step teaching `teach`."""
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

        def flags_fired():
            return t("story_flags").get("flags_fired", {}) or {}

        def note(s):
            print("FINDING:", s)
            findings.append(s)

        def biome_key(name):
            for s in t("biome_slots").get("slots", []):
                if s.get("biome") == name:
                    return str(s.get("key")).lower()
            return ""

        # ── REAL-UI accept (X → Arc tab → select the offer's row → R) ──
        def _arc_row_key_for(snippet):
            """Row key ([G]/[H]/…) whose rendered body contains `snippet`. Rows render
            as a standalone '[K]' chip line followed by the row's text."""
            cur = None
            for l in t("overlay_text").get("lines", []) or []:
                s = str(l.get("text", "")).strip()
                m = re.match(r"^\[([A-Z;])\]$", s)
                if m:
                    cur = m.group(1)
                    continue
                if cur and snippet in s:
                    return cur
            return None

        def accept_via_arc_ui(snippet):
            press("x", settle=6)   # ControlsOverlay
            press("i", settle=6)   # Arc tab
            row = _arc_row_key_for(snippet)
            if row is None:
                note("contracts offer not visible on the Arc tab (overlay_text had no row matching %r)" % snippet)
                press("escape", settle=4)
                return False
            press(row.lower(), settle=6)   # select the row (G–;)
            press("r", settle=12)          # R = accept selected arc/tutorial offer
            press("escape", settle=6)      # back to the game surface
            return True

        # ── REAL-UI deliver (C → Commitments tab → select the row → R) ──
        def deliver_via_commitments_ui(qid):
            idx = -1
            for i, aq in enumerate(actives()):
                if int(aq.get("id", -1)) == qid:
                    idx = i
                    break
            if idx < 0 or idx >= len(SEL_KEYS):
                note("contracts commitment row not selectable (idx=%d)" % idx)
                return
            press("c", settle=6)            # QuestBoard
            press("u", settle=6)            # Commitments tab
            press(SEL_KEYS[idx], settle=6)  # select the contract's row
            press("r", settle=12)           # R = complete the delivery
            press("escape", settle=6)

        print("boot wallet:", json.dumps(wallet(), ensure_ascii=False))
        print("live at boot:", [
            (str(q.get("tutorial_teaches", "")), find_step(str(q.get("tutorial_teaches", "")))[0])
            for q in actives() + offers() if q.get("tutorial_teaches")
        ])

        dk = biome_key("TheDemos")
        fk = biome_key("StarterForest")

        def chain_advanced_past(teach):
            """True if the linear chain has moved beyond `teach` — a later step is live now.
            Because steps unlock strictly in order, that PROVES `teach` completed (the case
            where a step's condition — e.g. StarterForest coherence ≥ 0.3 in the naturally
            oscillating forest — is already met, so it auto-claims before we can poll it)."""
            idx = EXPECTED.index(teach)
            live = {str(q.get("tutorial_teaches", "")) for q in offers() + actives()}
            return any(later in live for later in EXPECTED[idx + 1:])

        # An AUTO step: it is already active (auto-accepted). Do the mechanic; poll
        # until it disappears (auto-claimed). Never press an accept/claim key.
        def run_auto(teach, drive, rounds=12):
            where, q = find_step(teach)
            if where == "":
                # Already gone before we could drive it. Only a PASS if the chain actually
                # advanced past it (a later step is live); otherwise it was never offered.
                if chain_advanced_past(teach):
                    print("  ✓ auto step '%s' auto-completed (condition already met) — chain advanced past it" % teach)
                    completed.append(teach)
                    return True
                note("auto step '%s' is not live and the chain did not advance past it (silent stall)" % teach)
                return False
            if where != "active":
                note("auto step '%s' did not auto-accept — still an offer awaiting R" % teach)
                return False
            for rnd in range(rounds):
                drive(rnd)
                where2, q2 = find_step(teach)
                if where2 == "":
                    print("  ✓ auto step '%s' advanced (round %d) — no accept/claim key pressed" % (teach, rnd + 1))
                    completed.append(teach)
                    return True
                print("    [%s r%d] progress=%.2f status=%s" % (
                    teach, rnd, float(q2.get("progress", 0) or 0), q2.get("status")))
            note("auto step '%s' never advanced after %d rounds (silent stall)" % (teach, rounds))
            return False

        # STEP 0 core_loop — Ace hat (8): explore F, strike R, extract Q.
        def drive0(_rnd):
            press(dk, settle=6)
            press("8", settle=4)
            press("g", settle=6)
            press("f", settle=10)
            press("r", settle=12)
            press("q", settle=10)
        run_auto("core_loop", drive0)

        # STEP 1 contracts — the MANUAL ceremony, real keys only. Moved up in the
        # 2026-08-17 reorder: it rides the same Ace verbs step 0 taught, and the
        # accept→gather→claim grammar is the early game's whole economy now.
        where, q2 = find_step("contracts")
        if where != "offer":
            note("contracts step is not an accept-me offer (where=%s) — it must NOT auto-accept" % where)
        else:
            if accept_via_arc_ui("is buying"):
                where2, q2b = find_step("contracts")
                if where2 != "active":
                    note("contracts step did not go active after the X→Arc R-accept (where=%s)" % where2)
                else:
                    qid = int(q2b.get("id", -1))
                    delivered = False
                    for rnd in range(12):
                        if float(wallet().get("🌾", 0)) < 2:
                            # gather 2× 🌾 — Ace strike+extract on TheDemos
                            press(dk, settle=6)
                            press("8", settle=4)
                            press("g", settle=4)
                            press("f", settle=8)
                            press("r", settle=10)
                            press("q", settle=8)
                        else:
                            deliver_via_commitments_ui(qid)
                        if find_step("contracts")[0] == "":
                            print("  ✓ contracts delivered via C→Commitments UI (round %d)" % (rnd + 1))
                            completed.append("contracts")
                            delivered = True
                            break
                        print("    [contracts r%d] 🌾=%s" % (rnd, wallet().get("🌾", 0)))
                    if not delivered:
                        note("contracts step never delivered through the Commitments UI (silent stall)")

        # STEP 2 wayfinding — the crossing is the whole ask (active_biome_is).
        def drive3(_rnd):
            press(fk, settle=10)
        run_auto("wayfinding", drive3)

        # STEP 3 superposition — Druid hat (0): E Hadamard until coherence ≥ 0.3.
        def drive4(rnd):
            press(fk, settle=8)
            press("0", settle=4)
            press("ghjkl;"[rnd % 6], settle=4)
            press("e", settle=8)
        run_auto("superposition", drive4)

        # BREAK #2 GATE: completing step 3 must have fired loom_opens, or the
        # Operator hat stays locked and step 4 (below) cannot be driven at all.
        # (forest_listener, the old handoff, now fires naturally in the act-3
        # berry chapter — the tutorial no longer force-fires it.)
        ff = flags_fired()
        if "loom_opens" in ff:
            print("  ✓ loom_opens fired from the tutorial — Operator hat unlocked for step 4")
        else:
            note("loom_opens did NOT fire on step-4 completion — Operator hat stays locked "
                 "under player-parity enforcement, dead-ending the entanglement step (Break #2)")

        # STEP 4 entanglement — Operator hat (9): Shift-check a pair, R, Bell (Q).
        def drive5(_rnd):
            press(fk, settle=8)
            press("9", settle=4)
            if t("instrument_state").get("checked_plots"):
                t("press_key", keycode=39, settle_frames=6)  # ' = bulk clear
            press("g", settle=6, shift=True)
            press("h", settle=6, shift=True)
            press("r", settle=10)   # gate picker
            press("q", settle=12)   # Bell
            t("time_skip", phrames=300)
        run_auto("entanglement", drive5, rounds=8)

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
        run_auto("reap_season", drive_reap)

        print("\ncompleted steps:", completed)
        print("final wallet:", json.dumps(wallet(), ensure_ascii=False))
        print("final flags:", sorted(flags_fired().keys()))
    finally:
        c.terminate_listener(proc)

    missing = [s for s in EXPECTED if s not in completed]
    if missing:
        note("steps that never advanced through the real UI: %s" % missing)

    print("\n== FINDINGS (%d) ==" % len(findings))
    for f in findings:
        print(" -", f)
    if not findings:
        print("PASS: all 6 Act-0 steps advanced through real UI at player parity.")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
