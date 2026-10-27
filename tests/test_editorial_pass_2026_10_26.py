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


def test_offered_beats_do_not_claim_the_deed_before_it_is_done():
    """`beat` is read at open; a payoff belongs in `done` (read on claim)."""
    b = _beats()
    for bid in ("first_breath", "spiral_breaks", "forest_listener", "forest_communion", "mill_wakes",
                "mill_master", "village_identity", "island_stops_asking", "ledger_opens", "island_free"):
        assert str(b[bid].get("done", "")).strip(), bid
    flags = {f["id"]: f for f in json.loads(src("Core/Quests/data/story_flags.json"))}
    assert "The Demos are free" in flags["island_free"]["arc_quest"]["done_beat"]
    assert "The Demos are free" not in flags["island_free"]["arc_beat"]
    eng = src("Core/Story/StoryEngine.gd")
    assert "done_beat_read" in eng and '"done_beat"' in eng
    assert "_on_done_beat_read" in src("Core/Story/PlayerEventBridge.gd")


def test_berry_counts_in_prose_match_the_gates():
    b = _beats()
    assert "Four" in b["forest_listener"]["done"] and "four" in b["forest_listener"]["offer"]["body"]
    assert "once more" in b["forest_evolving"]["offer"]["body"]


def test_gather_decides_fees_before_the_trip():
    """Act-5 loop: Forest said 'buy 🧺 in the Village', the Village said 'go to the
    Forest' because the fee was only checked on arrival."""
    g = src("Core/Campaign/Guide.gd").split("static func _gather(")[1].split("\nstatic func ")[0]
    fees = g.index('for fee in ["🧺", "👥"]')
    assert fees < g.index("var t := _travel(where, q)")


def test_coast_fast_fwd_rules_apply_only_on_the_coast():
    """Fourth pass: with lantern_door on the banner (biome_evolving Lanternfall),
    Ace F in the Starter Forest kept Fast-Fwd, so "gather 🦅, Explore [F]" never
    explored. The coast's keep-Fast-Fwd rules are scoped to the active biome."""
    prog = (ROOT / "UI" / "Core" / "UIProgression.gd").read_text(encoding="utf-8")
    keep = prog.split("static func ace_f_keeps_fast_fwd")[1].split("static func ")[0]
    assert 'here == "Lanternfall"' in keep
    assert 'here == "ShrineOfAshes"' in keep
    assert keep.count('here == "Lanternfall"') >= 2


def test_hint_first_sentence_cap_is_enforced():
    """validate.py errors on a main-campaign hint whose first sentence is over 70."""
    import importlib, sys
    sys.path.insert(0, str(ROOT / "tools" / "campaign"))
    V = importlib.import_module("validate")
    S = importlib.import_module("spec")
    spec = S.load()
    R = V.Report()
    V.check_hints(spec, R)
    assert not R.errors, R.errors
    V.HINT_FIRST_SENTENCE_MAX, cap = 10, V.HINT_FIRST_SENTENCE_MAX
    try:
        R2 = V.Report()
        V.check_hints(spec, R2)
        assert R2.errors
    finally:
        V.HINT_FIRST_SENTENCE_MAX = cap


def test_legacy_plant_banner_skips_keys_the_wallet_cannot_pay():
    """Fourth pass: after lantern_teaching the unsigned Village-paths banner asked
    "[Q] plant 🦅" with no 🩸 for its south pole, forever. The legacy picker now
    skips a key the player cannot afford."""
    prog = (ROOT / "UI" / "Core" / "UIProgression.gd").read_text(encoding="utf-8")
    live = prog.split("static func _live_atom_plant_line")[1].split("\nstatic func ")[0]
    assert "_plant_affordable(farm, biome, atom)" in live
    assert "static func _plant_affordable" in prog
    aff = prog.split("static func _plant_affordable")[1].split("\nstatic func ")[0]
    assert "_get_injection_cost" in aff and "_wallet" in aff
