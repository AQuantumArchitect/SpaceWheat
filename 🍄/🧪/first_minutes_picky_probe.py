#!/usr/bin/env python3
"""Three-round first-minutes playtest: welcome → loom → reap → Arc catalog.

Player-parity (RIG_UNLOCK_ALL=0, welcome ON). Extremely picky about:
  - one live ask on screen
  - no Woodlot / Village / Mill peek during the loom
  - mash F on Operator after the Bell weave still reaps
  - Arc after reap is the Wheel, not timber country

Run: python3 🍄/🧪/first_minutes_picky_probe.py
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

_t = [0]
FORBIDDEN_EARLY = (
    "timber country", "woodlot", "the mill runs", "find the woodlot",
    "lumber",
)


def turn():
    _t[0] += 1
    return _t[0]


def main() -> int:
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(
        scenario_id="demos_normal",
        display_mode="headless",
        extra_env={
            "RIG_DISABLE_LOOKAHEAD": "0",
            "RIG_UNLOCK_ALL": "0",
            "RIG_SKIP_WELCOME": "0",
        },
    )
    findings = []
    completed = []
    notes = []
    try:
        print("ready:", c.wait_for_ready(proc, timeout_s=200))

        def t(action, **kw):
            return c.run_turn(turn(), action, timeout_s=60, **kw)

        def press(k, settle=8, shift=False):
            return t("press_key", key=k, shift=shift, settle_frames=settle)

        def flags():
            return sorted((t("story_flags").get("flags_fired") or {}).keys())

        def offers():
            return t("story_offers").get("story_offers", []) or []

        def actives():
            aq = t("active_quests", full=True)
            return aq.get("quests", []) or []

        def screen():
            lines = []
            for x in t("overlay_text").get("lines", []) or []:
                tx = str(x.get("text", "") if isinstance(x, dict) else x).strip()
                if tx:
                    lines.append(tx)
            return lines

        def screen_blob():
            return " ".join(screen()).lower()

        def hat():
            return str(t("confirm_state").get("current_frame", "") or "")

        def note(s):
            print("FINDING:", s)
            findings.append(s)

        def observe(label):
            blob = screen_blob()
            fired = flags()
            offer_names = [str(o.get("tutorial_teaches") or o.get("body") or o.get("source_flag") or "")[:48]
                           for o in offers()]
            active_names = [str(a.get("tutorial_teaches") or a.get("body") or "")[:48] for a in actives()]
            print(f"\n-- {label} --")
            print("  hat:", hat(), "flags:", fired)
            print("  active:", active_names)
            print("  offers:", offer_names)
            print("  screen[:400]:", " | ".join(screen())[:400])
            notes.append(label)
            if any(bad in blob for bad in FORBIDDEN_EARLY):
                if "reap_season" not in " ".join(active_names) and "arc_handover" not in fired:
                    note("%s: early catalog leak on screen: %s" % (label, blob[:240]))
            if "woodlot_door" in fired and "new_voices" not in fired:
                note("%s: woodlot_door fired before new_voices" % label)
            if "village_stirs" in fired and "arc_handover" not in fired:
                note("%s: village_stirs fired before Wheel" % label)
            return blob

        def find_step(teach):
            for q in offers():
                if str(q.get("tutorial_teaches", "")) == teach:
                    return "offer", q
            for q in actives():
                if str(q.get("tutorial_teaches", "")) == teach:
                    return "active", q
            return "", {}

        def biome_key(name):
            for s in t("biome_slots").get("slots", []):
                if s.get("biome") == name:
                    return str(s.get("key")).lower()
            return ""

        def wallet():
            r = t("resource_snapshot").get("resources", {})
            return (r.get("resources", r) or {})

        _ORDER = ["core_loop", "contracts", "wayfinding",
                  "superposition", "entanglement", "reap_season"]

        def chain_past(teach):
            i = _ORDER.index(teach)
            live = {str(x.get("tutorial_teaches", "")) for x in offers() + actives()}
            return any(later in live for later in _ORDER[i + 1:])

        def run_step(teach, drive, rounds=10):
            where, q = find_step(teach)
            if where == "":
                if teach == "reap_season" and "first_harvest" in flags():
                    print("  ✓ step 'reap_season' already paid (first_harvest)")
                    completed.append(teach)
                    return True
                if teach == "superposition" and chain_past(teach):
                    note("superposition auto-completed without a Hadamard — forest weather stole the lesson")
                    return False
                if chain_past(teach):
                    print("  ✓ step '%s' auto-completed" % teach)
                    completed.append(teach)
                    return True
                note("step '%s' never offered" % teach)
                return False
            if where == "offer":
                acc = t("accept_quest", quest_id=int(q.get("id", -1)))
                if not acc.get("ok", acc.get("success", False)):
                    note("step '%s' would not accept: %s" % (teach, acc))
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

        # WELCOME
        observe("boot_welcome")
        press("f", settle=10)
        observe("after_welcome")
        if "tutorial_seen" not in flags():
            note("tutorial_seen did not fire on welcome dismiss")

        dk = biome_key("TheDemos")
        fk = biome_key("StarterForest")
        print("biome keys demos=%s forest=%s wallet=%s" % (dk, fk, json.dumps(wallet(), ensure_ascii=False)))

        def drive0(_rnd):
            press(dk or "t", settle=6)
            press("8", settle=4)
            press("g", settle=6)
            press("f", settle=10)
            press("r", settle=12)
            press("q", settle=10)
        run_step("core_loop", drive0)
        observe("after_strike")

        def drive_mill(_rnd):
            if float(wallet().get("🌾", 0) or 0) < 2:
                press(dk or "t", settle=6)
                press("8", settle=4)
                press("g", settle=4)
                press("f", settle=8)
                press("r", settle=10)
                press("q", settle=8)
            press("c", settle=8)
            press("y", settle=6)
            press("r", settle=8)
            press("u", settle=6)
            press("r", settle=8)
            press("escape", settle=6)
        run_step("contracts", drive_mill, rounds=8)
        observe("after_mill")

        def drive_forest(_rnd):
            press(fk or "y", settle=10)
        run_step("wayfinding", drive_forest)
        observe("in_forest")

        def drive_super(rnd):
            press(fk or "y", settle=8)
            press("0", settle=4)
            press("ghjkl;"[rnd % 6], settle=4)
            press("e", settle=8)
        run_step("superposition", drive_super)
        observe("after_superpose")
        if "loom_opens" not in flags():
            note("loom_opens did not fire after superposition")

        def drive_bell(_rnd):
            press(fk or "y", settle=8)
            press("9", settle=4)
            if t("instrument_state").get("checked_plots"):
                t("press_key", keycode=39, settle_frames=6)
            press("g", settle=6, shift=True)
            press("h", settle=6, shift=True)
            press("r", settle=10)
            press("q", settle=12)
            t("time_skip", phrames=300)
        run_step("entanglement", drive_bell, rounds=8)
        observe("after_loom")

        # THE PLAYER MISTAKE: stay on Operator, mash F, do not go home first.
        print("\n== masher path: Operator F after loom ==")
        print("  wearing:", hat())
        press("f", settle=12)           # should explore or switch to Ace
        press("f", settle=12)           # should reap
        press("f", settle=12, shift=True)
        observe("after_operator_f_mash")
        if "first_harvest" not in flags() and "reap_season" in {str(x.get("tutorial_teaches", "")) for x in actives() + offers()}:
            # still on the capstone — try home + mash without Ace on purpose
            press(dk or "t", settle=8)
            press("g", settle=6)
            press("f", settle=10)
            press("f", settle=12)
            observe("after_home_mash_still_maybe_operator")

        def drive_reap(rnd):
            press(dk or "t", settle=8)
            # Deliberately do NOT press 8 — capstone must survive Operator.
            press("ghjkl;"[rnd % 6], settle=4)
            press("f", settle=8)
            press("f", settle=12)
        run_step("reap_season", drive_reap)
        observe("after_reap")
        if "first_harvest" not in flags():
            note("first_harvest did not fire — player still has not reaped")

        # Arc catalog: X then I
        press("x", settle=8)
        press("i", settle=8)
        blob = observe("arc_after_reap")
        for bad in ("timber country", "woodlot", "the mill runs", "find the woodlot"):
            if bad in blob:
                note("Arc after reap still shows %r" % bad)
        if "the wheel is yours" not in blob:
            note("Arc after reap is missing the Wheel handshake")
        if "tap to open story" in blob and "first harvest" in blob:
            note("First Harvest gold-toasts to Story, stacking the Wheel")
        # Accept the Wheel — the next door must be mill teaching, not timber.
        press("g", settle=6)
        press("r", settle=10)
        press("escape", settle=6)
        press("x", settle=8)
        press("i", settle=8)
        blob = observe("arc_after_wheel")
        for bad in ("timber country", "woodlot", "find the woodlot", "the mill runs"):
            if bad in blob:
                note("Arc after Wheel still shows %r" % bad)
        if "the village stirs" in blob and "open" not in blob:
            note("Arc after Wheel peeks Village Stirs as an unfired row, not an offer")
        if "no story flags loaded" in blob or "the next door hasn't opened" in blob:
            note("Arc after Wheel is empty — mill teaching did not open")
        mill_face = ("apprentice" in blob) or ("windmill" in blob) or (
            "the village stirs" in blob and "open" in blob)
        if not mill_face:
            note("Arc after Wheel is missing mill teaching: %s" % blob[:240])
        if "surprisal" in blob or "kT" in blob:
            note("Arc/chip still dumping physics on the face: %s" % blob[:160])
        press("escape", settle=6)

        print("\ncompleted steps:", completed)
        print("final flags:", flags())
        print("final hat:", hat())
        print("final wallet:", json.dumps(wallet(), ensure_ascii=False))
    finally:
        try:
            t = lambda action, **kw: c.run_turn(turn(), action, timeout_s=20, **kw)  # noqa
            t("stop")
        except Exception:
            pass
        c.terminate_listener(proc)

    print("\n== FINDINGS (%d) ==" % len(findings))
    for f in findings:
        print(" -", f)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
