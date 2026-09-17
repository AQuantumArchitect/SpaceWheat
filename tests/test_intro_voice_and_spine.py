"""Source-shape pins for the first-minute spine.

The live Godot smoke (intro_flow_smoke.gd) instantiates the overlays.
This file is the compiler for the *laws* so a later edit cannot silently
put formula back on the Arc face, resurrect 'tap here to accept' on an
auto-accepted tutorial step, reprint a lesson on the welcome splash, or
let welcome / toast / Arc name three different first verbs.
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


def test_arc_now_row_does_not_ask_accept():
    """Auto-accepted NOW doors inspect then shunt; OPEN (optional) doors pulse R."""
    row = _make_arc_row_body()
    assert "[R] Accept" in row
    assert 'kind == "arc_quest"' in row
    assert '_make_muted_label("tap to inspect  ·  R accepts"' in row
    assert '_make_muted_label("tap to inspect  ·  tap again for the work"' in row


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
    assert "IntroVoice.welcome_footer()" in w
    # Identity splash — the how lives on Guide; the 1D lane auto-accepts
    # onto the banner. Optional offers wait on Arc.
    footer = src(INTRO).split("static func welcome_footer")[1].split("static func ")[0]
    assert "Tap anywhere" in footer
    assert "Arc" not in footer
    assert "IntroVoice.welcome_verbs()" not in w
    assert "Wake a sleeping plot" not in w
    assert "PanelSizeMode.MEDIUM" in w
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
    auto_fn = intro.split("func toast_for_offer")[1].split("func flag_postcard")[0]
    # Lane steps are silent. Unsigned offers wait on the Arc. Never reprint accept.
    assert "Tap here to read & accept" not in intro
    assert "return {}" in auto_fn
    assert "[X] then Arc [I]" in auto_fn
    assert "New offer from" in auto_fn
    assert "The Demos sleeps" in intro
    assert "IntroVoice.toast_for_offer" in src(BRIDGE)
    flag_fn = intro.split("func toast_for_flag")[1].split("func recap")[0]
    assert "arc_quest" in flag_fn
    assert "return {}" in flag_fn
    assert 'flag_data.has("predicates")' in flag_fn
    bridge = src(BRIDGE)
    assert "_announced_offer_ids" in bridge
    offered = bridge.split("func _on_quest_offered")[1].split("func _on_quest_failed")[0]
    assert "_announced_offer_ids.has(qid)" in offered
    fired = bridge.split("func _on_story_flag_fired")[1].split("func _on_quest_completed")[0]
    assert "toast.is_empty()" in fired


def test_toast_is_tracker_plus_link():
    t = src(TOAST)
    assert "ClickLadder" in t
    show = t.split("func show_text")[1].split("\nfunc ")[0]
    assert "has_detail = false" in show
    assert '_detail = ""' in show
    gui = t.split("func _on_gui_input")[1].split("func _on_mouse_entered")[0]
    body = gui.split("if on_close:")[1]
    assert '"home"' in body and '"scoot"' in body
    ladder = src(ROOT / "UI" / "Core" / "ClickLadder.gd")
    assert "tap to open %s" in ladder
    assert "[%s] opens %s" in ladder
    assert "tap again to go there" in ladder
    assert "[F] opens" in t
    assert "func follow(" in t


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


def test_arc_inspects_in_the_menu_not_a_toast():
    """X→I→G E unfolds in the Arc row. Tap inspects; next tap shunts; R accepts."""
    arc = src(ARC)
    get_fn = arc.split("func get_inspect_text")[1].split("func _story_inspect_text")[0]
    assert 'Tab.ARC:' in get_fn
    assert 'return ""' in get_fn
    assert "_append_arc_inspect" in arc
    select = arc.split("func _select_arc_row")[1].split("\nfunc ")[0]
    assert "_on_action_r()" not in select
    assert "accept_quest" not in select
    assert "_arc_inspect_open" in select
    assert "_tunnel_from_arc" in select
    assert 'r_lbl.text = "[R] Accept"' in arc
    assert "COLOR_ACCENT_GOLD" in arc.split("func _make_arc_row")[1].split("func _make_arc_chapter_header")[0]


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
