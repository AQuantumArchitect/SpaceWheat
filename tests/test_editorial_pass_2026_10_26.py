"""Editorial pass 2026-10-26: what the player reads is written for the player.

  * lessons have titles; the banner names a lesson by its title, not its body
  * math_note (designer notes) is not rendered on the Arc card or inspect
  * the travel line and Demos prose use spaced biome names
  * offers describe the gate they are checked by (no stale numbers)
  * spiral_breaks requires the strike it preaches (strike_known gate)
  * Mass Explore ignores marks left in another country
  * the Guide's focus test is false before any plot was picked
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def src(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def _demos():
    return json.loads(src("Core/Campaign/campaign.json"))["campaigns"][0]


def _beats():
    out = {}
    for a in _demos()["acts"]:
        for ch in a["chapters"]:
            for b in ch.get("beats", []):
                out[b["id"]] = b
    return out


def test_lessons_have_titles_and_the_banner_uses_them():
    steps = json.loads(src("Core/Quests/data/tutorial_arc.json"))["steps"]
    for s in steps:
        assert str(s.get("display_name", "")).strip(), s["tutorial_teaches"]
        assert len(s["display_name"]) <= 24
    titles = [s["display_name"] for s in steps]
    assert "First Harvest" not in titles, "collides with the Act-0 beat"
    guide = src("Core/Campaign/Guide.gd").split("static func _title(")[1].split("\nstatic func ")[0]
    assert "IntroVoice.quest_title(q)" in guide
    assert 'split(" — ")' not in guide


def test_designer_notes_are_not_player_text():
    intro = src("Core/Story/IntroVoice.gd")
    assert '"physics": str(quest.get("math_note"' not in intro
    board = src("UI/Overlays/QuestBoard.gd").split("func _commitments_inspect_text_for(")[1].split("\nfunc ")[0]
    assert "math_note" not in board


def test_no_code_names_in_demos_prose_or_travel_line():
    code = re.compile(r"StarterForest|FreshwaterSpring|BloodLedger|TheDemos")
    for b in _beats().values():
        assert not code.search(b.get("beat", "")), b["id"]
        o = b.get("offer") or {}
        assert not code.search(o.get("body", "") + o.get("hint", "")), b["id"]
    guide = src("Core/Campaign/Guide.gd")
    assert "static func biome_label(" in guide
    assert '["to " + biome_label(biome), key]' in guide


def test_offers_do_not_quote_stale_standing_numbers():
    b = _beats()
    for bid in ("woodlot_contact", "spring_contact", "village_stirs"):
        assert not re.search(r"\b0\.\d+", b[bid]["offer"]["body"]), bid
    assert "{$hub.enclave_signature}" in b["edge_of_the_enclave"]["offer"]["body"]
    assert "gap" not in b["pond_depths"]["offer"]["body"]
    assert "8%" not in b["mill_wakes"]["offer"]["body"]
    assert b["mill_master"].get("offer"), "a bar with no ask"


def test_spiral_breaks_requires_the_strike_it_teaches():
    b = _beats()["spiral_breaks"]
    kinds = {(o["type"], o.get("gate")) for o in b["objective"]}
    assert ("gate_sequence_contains", "strike_known") in kinds
    probe = src("Core/Actions/ProbeActions.gd").split("static func action_measure(")[1].split("\nstatic func ")[0]
    assert '"known": known' in probe
    inst = src("Core/Instrumentation/QuantumInstrument.gd")
    assert '_notify_quest_projection("strike_known"' in inst
    guide = src("Core/Campaign/Guide.gd")
    assert 'if gate == "strike_known":' in guide and "static func _strike_known(" in guide


def test_mass_explore_ignores_marks_from_another_country():
    qii = src("UI/Core/QuantumInstrumentInput.gd").split("func _mass_explore(")[1].split("\nfunc ")[0]
    assert "positions.filter(" in qii and "== here" in qii
    guide = src("Core/Campaign/Guide.gd")
    assert "_any_mark_here(inst.checked_plots)" in guide.split("static func _survey(")[1].split("\nstatic func ")[0]


def test_guide_focus_is_false_before_any_pick():
    live = src("Core/Campaign/Guide.gd").split("static func _live_col(")[1].split("\nstatic func ")[0]
    assert "last_selected_position" in live and "current_biome" in live


def test_no_player_text_says_shift_f_reaps():
    for rel in ("Core/Quests/PredicateGloss.gd", "Core/Actions/ProbeActions.gd",
                "UI/Overlays/ControlsOverlay.gd", "docs/HOW_TO_PLAY.md"):
        for line in src(rel).splitlines():
            if line.strip().startswith("#"):
                continue
            if "reap" in line.lower() and "Shift+F" in line and "Ctrl+Shift+F" not in line:
                raise AssertionError("%s: %s" % (rel, line.strip()[:90]))
