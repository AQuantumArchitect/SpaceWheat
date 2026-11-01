"""SpineRecipe: walks compile from quest fields, not from hint prose."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HIVE = ROOT / "🍄" / "🧪" / "hive"
sys.path.insert(0, str(HIVE))
import spine_recipe as sr  # noqa: E402


def _flags():
    return {f["id"]: f for f in sr.load_flags()}


def _tutorial():
    return {s["tutorial_teaches"]: s for s in sr.load_tutorial()}


def test_targets_parse_matches_gloss_kinds():
    gloss = (ROOT / "Core" / "Quests" / "PredicateGloss.gd").read_text(encoding="utf-8")
    for t, spec in sr.TARGETS.items():
        assert '"%s"' % t in gloss
        assert spec.get("kind") in ("hat", "menu", "gate", "biome")
    assert "lesson_receipt" in sr.TARGETS
    assert "biome_state_gte" in sr.TARGETS
    assert sr.GATE_FRAMES.get("batch_explore") == "ace"
    assert sr.GATE_FRAMES.get("bell_collapse") == "ace"


def test_tutorial_clocks_are_authored():
    steps = _tutorial()
    loop = sr.compile_quest({**steps["core_loop"], "category": "TUTORIAL"})
    assert loop["auto_accept"] is True and loop["auto_claim"] is True
    assert loop["kind"] == "gate"
    assert "F" in loop["keys"] and "Q" in loop["keys"] and "R" in loop["keys"]
    mill = sr.compile_quest({**steps["contracts"], "category": "TUTORIAL"})
    assert mill["auto_accept"] is False and mill["auto_claim"] is False
    assert mill["kind"] == "delivery"
    assert "C" in mill["keys"] and "U" in mill["keys"]
    assert "X" not in mill["keys"]
    way = sr.compile_quest({**steps["wayfinding"], "category": "TUTORIAL"})
    assert way["kind"] == "travel"
    superpose = sr.compile_quest({**steps["superposition"], "category": "TUTORIAL"})
    assert "0" in superpose["keys"] and "E" in superpose["keys"]
    assert "Q" in superpose["keys"]  # warmth receipt is Gather


def test_village_to_mill_kinds():
    flags = _flags()
    wheel = sr.compile_flag(flags["arc_handover"])
    assert wheel["kind"] == "handshake"
    assert wheel["auto_claim"] is True
    assert set(wheel["keys"]) >= {"X", "Y", "R"}
    stirs = sr.compile_flag(flags["village_stirs"])
    assert stirs["kind"] == "standing"
    assert "C" in stirs["keys"] and "💨" in stirs["teaches"]
    voices = sr.compile_flag(flags["new_voices"])
    assert voices["kind"] == "plant"
    assert "5" in voices["keys"] and "R" in voices["keys"]
    door = sr.compile_flag(flags["woodlot_door"])
    assert door["kind"] == "discover"
    assert "7" in door["keys"] and "R" in door["keys"]
    mill = sr.compile_flag(flags["mill_wakes"])
    assert mill["kind"] == "steer"
    assert mill["teaches"] == ["🧺", "💰"]
    assert "5" not in mill["keys"], "Hold Commerce does not mill Icon for an untaught glyph"
    assert "X" in mill["keys"] and "R" in mill["keys"]


def test_hint_keys_subset_of_recipe():
    flags = _flags()
    for fid in ("village_stirs", "new_voices", "woodlot_door", "mill_wakes", "arc_handover"):
        aq = flags[fid]["arc_quest"]
        stray = sr.hint_off_recipe(aq, aq.get("hint") or "")
        assert stray == [], "%s hint names %s outside the compiled keys" % (fid, stray)
    steps = _tutorial()
    for name, step in steps.items():
        q = {**step, "category": "TUTORIAL"}
        stray = sr.hint_off_recipe(q, step.get("tutorial_hint") or "")
        assert stray == [], "%s tutorial_hint names %s outside the compiled keys" % (name, stray)


def test_every_arc_quest_compiles_keys():
    missing = []
    for flag in sr.load_flags():
        aq = flag.get("arc_quest")
        if not isinstance(aq, dict) or not aq:
            continue
        rec = sr.compile_flag(flag)
        if not rec["keys"]:
            missing.append(flag["id"])
    assert missing == [], "arc_quest compiled empty keys: %s" % missing


def test_live_recipe_pair_missing_outranks_children():
    rec = sr.live_recipe(["village_stirs", "new_voices"], known_icons=[])
    assert rec is not None
    assert rec["id"] == "village_stirs"
    assert rec["clock"] == "unsigned_or_language"
    known = [{"north": "💨", "south": "🔨"}]
    rec2 = sr.live_recipe(["village_stirs", "new_voices"], known_icons=known)
    assert rec2 is not None
    assert rec2["id"] == "new_voices"
    planted = sr.live_recipe(
        ["village_stirs", "new_voices"],
        known_icons=known,
        village_axes=["💰⚙", "💨🔨"],
    )
    assert planted is not None
    assert planted["id"] == "woodlot_door"


def test_gold_off_spine_catches_icon_on_granary():
    rec = sr.live_recipe(["loop_remembers", "mill_wakes"], known_icons=[])
    assert rec is not None
    assert rec["id"] == "mill_wakes"
    assert sr.gold_off_spine(rec, ["5"]) is True
    assert sr.gold_off_spine(rec, ["X"]) is False
    assert sr.gold_off_spine(rec, ["R"]) is False
    gear = sr.compile_flag(_flags()["timber_rhythm"])
    assert "5" not in gear["keys"]
    assert "L" in gear["keys"]
    assert sr.gold_off_spine({**gear, "id": "timber_rhythm"}, ["5"]) is True
    assert sr.gold_off_spine({**gear, "id": "timber_rhythm"}, ["L"]) is False
    assert sr.gold_off_spine({**gear, "id": "timber_rhythm"}, ["C"]) is False


def test_mermaid_names_the_village_band():
    text = sr.to_mermaid()
    assert "village_stirs --> new_voices" in text
    assert "new_voices --> woodlot_door" in text
    assert "T6 --> arc_handover" in text


def test_quest_schema_and_manager_read_authored_clocks():
    quest = (ROOT / "Core" / "Quests" / "Quest.gd").read_text(encoding="utf-8")
    assert '"auto_accept": null' in quest
    assert '"auto_claim": null' in quest
    qm = (ROOT / "Core" / "Quests" / "QuestManager.gd").read_text(encoding="utf-8")
    accepts = qm.split("func _tutorial_auto_accepts")[1].split("\nfunc ")[0]
    assert 'quest.get("auto_accept") is bool' in accepts
    claims = qm.split("func _tutorial_auto_advances")[1].split("\nfunc ")[0]
    assert 'quest.get("auto_claim") is bool' in claims
    hand = qm.split("func _handshake_auto_claims")[1].split("\nfunc ")[0]
    assert 'quest.get("auto_claim") is bool' in hand
    gd = (ROOT / "Core" / "Quests" / "SpineRecipe.gd").read_text(encoding="utf-8")
    assert "static func kind(" in gd
    assert "static func allowed_keys(" in gd
