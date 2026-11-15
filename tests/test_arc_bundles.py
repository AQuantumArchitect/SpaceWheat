"""Arcs bundle 1-6 Charges (#94, phase 1): docs/design/ARC_CHARGE_STRUCTURE.md.

Fast half (spec only): the compiler folds each arc's requires into its
charges, the validator refuses a malformed arc, Act 0-1 of the Demos is
regrouped into arcs in lesson order, and the arc loop reaches every ending.

Slow half (headless Godot, keys only): a fresh run at the first arc. The Arc
shows ONE row for The Wheel Is Yours with its charges; R signs them all; the
Charge tab lists them under the arc with its progress, and E there spells the
steps; claiming the last charge completes the arc and the Arc offers the next.
"""
import copy
import json
import os
import sys
import time
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "campaign"))
import build  # noqa: E402
import spec as S  # noqa: E402
import validate  # noqa: E402

LONG = pytest.mark.skipif(os.environ.get("SW_SKIP_LONG") == "1",
                          reason="SW_SKIP_LONG=1 — headless arc drive skipped")
KEYS = "ghjkl;"


def _runtime():
    return json.loads((ROOT / "Core/Quests/data/campaign_runtime.json").read_text(encoding="utf-8"))


def _flags():
    return {f["id"]: f for f in json.loads((ROOT / "Core/Quests/data/story_flags.json").read_text(encoding="utf-8"))}


def _reqs(flag):
    return {p["id"] for p in flag["predicates"] if p.get("type") == "story_flag_set"}


# --------------------------------------------------------------- fast (spec only)

def test_act_one_is_regrouped_into_arcs_in_lesson_order():
    arcs = {a["id"]: a for a in _runtime()["arcs"]}
    order = [a["id"] for a in _runtime()["arcs"] if a["campaign"] == "demos" and a["act"] == 1]
    assert order == ["the_wheel", "breath", "voices", "the_milk"]
    assert arcs["the_wheel"]["charges"] == ["arc_handover", "village_stirs"]
    assert arcs["breath"]["charges"] == ["first_breath"]
    assert arcs["voices"]["charges"] == ["spiral_breaks", "new_voices"]
    assert arcs["the_milk"]["charges"] == ["find_the_milk"]
    # one-charge arcs are the big moments only
    for a in arcs.values():
        assert len(a["charges"]) > 1 or a["large_event"], a["id"]
    assert arcs["the_wheel"]["next"] == ["breath"]
    assert set(arcs["breath"]["next"]) == {"voices", "the_milk"}, "an arc may open more than one next arc"


def test_every_offered_act_0_1_beat_is_a_charge():
    spec = S.load()
    demos = spec["campaigns"][0]
    for act in demos["acts"]:
        if act["act"] > 1:
            continue
        for ch in act["chapters"]:
            for b in ch.get("beats", []):
                if b.get("offer"):
                    assert b.get("arc"), "%s (Act %d) is in no arc" % (b["id"], act["act"])


def test_charges_inherit_the_arc_requires():
    f = _flags()
    assert _reqs(f["arc_handover"]) == _reqs(f["village_stirs"]) == {"first_harvest", "loom_opens"}
    # an arc waits on the WHOLE previous arc: requiring an arc id is all its charges
    assert _reqs(f["first_breath"]) == {"arc_handover", "village_stirs"}
    assert _reqs(f["spiral_breaks"]) == _reqs(f["new_voices"]) == {"first_breath"}
    assert _reqs(f["woodlot_door"]) == _reqs(f["spring_door"]) == {"spiral_breaks", "new_voices"}
    for cid in ("arc_handover", "village_stirs", "first_breath"):
        assert f[cid]["arc_quest"]["arc"] == f[cid]["arc"]


def test_apply_arcs_is_idempotent():
    once = S.load()
    twice = S.apply_arcs(copy.deepcopy(once))
    assert build.compile_all(copy.deepcopy(once)) == build.compile_all(twice)


def test_validator_refuses_malformed_arcs():
    base = S.load()

    def errors(mutate):
        sp = copy.deepcopy(base)
        arcs = {a["id"]: a for _c, _a, _ch, a in S.iter_arcs(sp)}
        beats = {b["id"]: b for _c, _a, _ch, b in S.iter_beats(sp, resolved=False)}
        mutate(arcs, beats)
        return validate.validate(sp).errors

    assert not errors(lambda a, b: None)
    # a one-charge arc that is not a large event
    assert any("large event" in e for e in errors(lambda a, b: a["breath"].pop("large_event")))
    # seven charges
    assert any("1-6" in e for e in errors(lambda a, b: a["the_wheel"].__setitem__("charges", ["arc_handover"] * 7)))
    # a milestone is not a charge
    assert errors(lambda a, b: a["the_wheel"]["charges"].append("first_harvest"))
    # an offered beat left out of its chapter's arcs
    assert any("none of its arcs" in e for e in errors(lambda a, b: a["voices"]["charges"].remove("new_voices")))
    # a charge authoring its own, different requires
    assert any("takes the arc's requires" in e
               for e in errors(lambda a, b: (b["village_stirs"].pop("arc", None),
                                             b["village_stirs"].__setitem__("requires", ["first_harvest"]))))
    # an arc that waits on itself never opens: the arc loop catches it
    assert errors(lambda a, b: a["voices"].__setitem__("requires", ["voices"]))


def test_arc_loop_reaches_every_ending():
    rep = validate.validate(S.load())
    assert not [e for e in rep.errors if "arc loop" in e], rep.errors


# --------------------------------------------------------------- slow (headless, keys only)

def _row_of(lines, label):
    cur = None
    for s in lines:
        s = s.strip()
        if len(s) == 3 and s[0] == "[" and s[2] == "]":
            cur = s[1].lower()
            continue
        if cur and label in s:
            return cur
    return None


@LONG
def test_fresh_run_first_arc_bundles_its_charges(rig_boot):
    rig, _proc = rig_boot(prefix="sw_arc_bundle_", scenario_id="demos_normal",
                          display_mode="headless", allow_resource_injection=True,
                          listener_stdout="null", rig_log_profile="quiet",
                          extra_env={"RIG_UNLOCK_ALL": "0", "RIG_QUEUE_POLL_MS": "60"},
                          sentinel_timeout_s=240.0)
    n = [0]

    def t(action, timeout_s=60, **kw):
        n[0] += 1
        return rig.run_turn(n[0], action, timeout_s=timeout_s, **kw)

    def press(k, settle=10):
        return t("press_key", key=k, settle_frames=settle)

    def lines():
        return [str(x.get("text", "")) for x in t("overlay_text").get("lines", [])]

    r = t("start_at_beat", id="arc_handover", wait_frames=300, timeout_s=240)
    assert r.get("ok") and r.get("fired"), r
    offers = {o.get("source_flag") for o in t("story_offers").get("story_offers", [])}
    assert {"arc_handover", "village_stirs"} <= offers, "the first arc's charges open together: %s" % offers

    press("x")
    press("y")
    arc_lines = lines()
    row = _row_of(arc_lines, "The Wheel Is Yours")
    assert row, "\n".join(arc_lines[:60])
    text = "\n".join(arc_lines)
    assert "2 charges" in text and "Apprentice to the Mill" in text, text
    press(row)
    press("r", 20)

    held = {q.get("source_flag") for q in t("active_quests").get("quests", [])}
    offers = {o.get("source_flag") for o in t("story_offers").get("story_offers", [])}
    assert "village_stirs" in held and "village_stirs" not in offers, (held, offers)
    assert "arc_handover" not in offers

    press("u", 20)
    text = "\n".join(lines())
    assert "The Wheel Is Yours  ·  1/2 done" in text, text  # the handshake claimed itself on accept
    row = _row_of(lines(), "Apprentice to the Mill")
    assert row, text
    press(row)
    press("e", 12)
    text = "\n".join(lines())
    assert "What to do" in text and "Market [Y]" in text and "Millwright's Union" in text, text

    # Finish the last charge: the Union's access (test-only grant), then claim it here.
    t("grant_standing", faction="Millwright's Union", deltas={"access": 0.2})
    deadline = time.time() + 60
    while time.time() < deadline:
        q = [q for q in t("active_quests").get("quests", []) if q.get("source_flag") == "village_stirs"]
        if q and q[0].get("status") == "ready":
            break
        time.sleep(0.5)
    press("u", 12)
    row = _row_of(lines(), "Apprentice to the Mill")
    press(row)
    press("r", 30)

    deadline = time.time() + 60
    offers = set()
    while time.time() < deadline:
        offers = {o.get("source_flag") for o in t("story_offers").get("story_offers", [])}
        if "first_breath" in offers:
            break
        time.sleep(0.5)
    assert "first_breath" in offers, "completing The Wheel did not offer the next arc: %s" % offers
    press("y", 12)
    text = "\n".join(lines())
    assert "First Breath" in text, text
