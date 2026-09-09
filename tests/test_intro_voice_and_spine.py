"""Source-shape pins for the first-minute spine.

The live Godot smoke (intro_flow_smoke.gd) instantiates the overlays.
This file is the compiler for the *laws* so a later edit cannot silently
put formula back on the Arc face, resurrect 'tap here to accept' on an
auto-accepted tutorial step, or let welcome / toast / Arc name three
different first verbs.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

INTRO = ROOT / "Core" / "Story" / "IntroVoice.gd"
WELCOME = ROOT / "UI" / "Overlays" / "WelcomeOverlay.gd"
ARC = ROOT / "UI" / "Overlays" / "ControlsOverlay.gd"
BRIDGE = ROOT / "Core" / "Story" / "PlayerEventBridge.gd"
TOAST = ROOT / "UI" / "Widgets" / "HintToast.gd"
GLOSS = ROOT / "Core" / "Quests" / "PredicateGloss.gd"
TUTORIAL = ROOT / "Core" / "Quests" / "data" / "tutorial_arc.json"
FLAGS = ROOT / "Core" / "Quests" / "data" / "story_flags.json"


def src(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def _make_arc_row_body() -> str:
    text = src(ARC)
    start = text.find("func _make_arc_row(")
    assert start != -1, "_make_arc_row vanished"
    nxt = text.find("\nfunc ", start + 1)
    return text[start:nxt]


def test_welcome_composes_from_intro_voice():
    w = src(WELCOME)
    assert "IntroVoice.welcome_title()" in w
    assert "IntroVoice.welcome_fiction()" in w
    assert "IntroVoice.welcome_verbs()" in w
    assert "IntroVoice.welcome_footer()" in w
    assert "PanelSizeMode.LARGE" in w
    assert "0.45" in w, "welcome dimmer must be glass (field visible), not a blackout"


def test_welcome_has_three_verb_cards_not_a_keymap_wall():
    intro = src(INTRO)
    assert "Wake a sleeping plot" in intro
    assert "Lock an answer in" in intro
    assert "Take what collapse leaves" in intro
    # The old "THE FIRST MINUTE" jammed F/R/Q into one line — gone.
    assert "THE FIRST MINUTE" not in src(WELCOME)
    assert "THE FIRST MINUTE" not in intro


def test_first_toast_is_the_lesson_not_an_accept_door():
    intro = src(INTRO)
    assert "func toast_for_offer" in intro
    assert "is_auto_tutorial" in intro
    # Auto-accepted steps must not tell the player to accept.
    auto_fn = intro.split("func toast_for_offer")[1].split("func flag_postcard")[0]
    # The auto branch returns before the accept-door copy.
    assert "Tap here to read & accept" in intro  # still used for the contracts step
    assert "The Demos sleeps" in intro
    assert "IntroVoice.toast_for_offer" in src(BRIDGE)


def test_toast_expands_on_first_tap():
    t = src(TOAST)
    assert "func expand()" in t
    assert "tap for more" in t
    assert "tap again to open the Arc" in t
    # First tap with detail must NOT flatten.
    gui = t.split("func _on_gui_input")[1].split("func _on_mouse_entered")[0]
    assert "_detail != " in gui and "expand()" in gui
    # ✕ still flattens first; the body path must expand before it travels.
    body = gui.split("if on_close:")[1]
    assert body.find("expand()") < body.find("_on_tap.call()")
    assert "expand()" in body.split("_on_tap.call()")[0]


def test_arc_face_is_a_postcard_not_a_ledger():
    row = _make_arc_row_body()
    assert "IntroVoice.quest_postcard" in row
    assert "IntroVoice.flag_postcard" in row
    assert "soft_gate" not in row
    assert 'PredicateGloss.formula' not in row, "formula leaked onto the Arc face"
    assert '"act %d"' not in row and "act %d ·" not in row, "internal act numbers on the face"
    assert "0.00 / 0.85" not in row and "%.2f / 0.85" not in row
    assert '"NOW"' in row, "live tutorial must wear a NOW badge"
    assert "live_tutorial" in src(ARC)


def test_arc_inspect_keeps_the_formula_for_the_literalist():
    """E is 'tell me more'. Physics belongs there, not on the face."""
    inspect = src(ARC).split("func _arc_inspect_text")[1].split("\nfunc _accept_selected")[0]
    assert "PredicateGloss.formula" in inspect
    assert 'flag.get("arc_beat"' in src(INTRO)


def test_reap_formula_is_a_structural_count_not_a_soft_gate_at_zero():
    gloss = src(GLOSS)
    form = gloss.split("static func formula")[1].split("static func _num")[0]
    assert 't == "gate_sequence_contains"' in form
    assert "structural count" in form
    assert "fires at" in form
    # The screenshot bug: value defaulted to 0 and printed ≥ 0 · soft_gate.
    summary = gloss.split('"gate_sequence_contains":')[2] if gloss.count('"gate_sequence_contains":') >= 2 \
        else gloss.split("match gname:")[1].split("var gframe")[0]
    assert "Reap the season" in gloss
    assert "Strike ×" in gloss


def test_tutorial_step0_and_first_harvest_are_different_doors():
    steps = json.loads(TUTORIAL.read_text(encoding="utf-8"))["steps"]
    assert steps[0]["tutorial_teaches"] == "core_loop"
    assert steps[0]["state_predicates"][0]["gate"] == "measure"
    assert steps[-1]["tutorial_teaches"] == "reap_season"
    flags = json.loads(FLAGS.read_text(encoding="utf-8"))
    if isinstance(flags, dict):
        for v in flags.values():
            if isinstance(v, list) and v and isinstance(v[0], dict) and "id" in v[0]:
                flags = v
                break
    harvest = next(f for f in flags if f.get("id") == "first_harvest")
    assert harvest["predicates"][0]["gate"] == "reap"
    assert "The Demos sleeps" in steps[0]["body"]
    assert "explore, strike, gather, reap" in harvest["arc_beat"]


def test_live_ask_token_step0_is_strike():
    intro = src(INTRO)
    fn = intro.split("func live_ask_token")[1]
    assert re.search(r'"core_loop":\s*\n\s*return "strike"', fn)
    assert re.search(r'"reap_season":\s*\n\s*return "reap"', fn)
