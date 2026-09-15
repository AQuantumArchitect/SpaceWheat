"""Source-shape pins for the one-strand information pathway.

Playtest 2026-09-09: quests + reputation were a spreadsheet in 9px type,
the banner wore three chrome lines under the ask, and harvest left double
metro threads. Face copy lives on IntroVoice; inspect may be dense.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INTRO = ROOT / "Core" / "Story" / "IntroVoice.gd"
BANNER = ROOT / "UI" / "Widgets" / "ActFilament.gd"
BOARD = ROOT / "UI" / "Overlays" / "QuestBoard.gd"
BRIDGE = ROOT / "Core" / "Story" / "PlayerEventBridge.gd"
FIELD = ROOT / "Core" / "Visualization" / "QuantumField3D.gd"
SEED = ROOT / "Core" / "Story" / "StorySeedLoader.gd"
ROOT_GD = ROOT / "scenes" / "GameRoot.gd"
ARC = ROOT / "UI" / "Overlays" / "ControlsOverlay.gd"


def src(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def test_spine_owns_the_live_door():
    text = src(INTRO)
    assert "static func live_door" in text
    assert "static func doors_ahead" in text
    assert "static func memoir" in text
    assert "static func felt_standing" in text
    assert "static func recap" in text
    banner = src(BANNER)
    assert "font_size\", 14" in banner or "font_size', 14" in banner.replace(" ", "")
    assert "ActLabel" not in banner
    assert "NextLabel" not in banner
    recap = src(ROOT_GD)
    assert "IntroVoice.recap" in recap
    assert 'Act %d' not in recap.split("func _show_boot_recap")[1].split("func ")[0]


def test_banner_stays_dark_until_the_door_is_taken():
    prog = src(ROOT / "UI" / "Core" / "UIProgression.gd")
    text_fn = prog.split("static func objective_text")[1].split("static func objective_target_key")[0]
    assert "Quest.STATUS_STORY" in text_fn
    assert "return _decorate_objective(best)" in text_fn
    assert "OFFER_LINE" not in text_fn
    target_fn = prog.split("static func objective_target()")[1].split("static func _hat_key_for_frame")[0]
    assert "Quest.STATUS_STORY" in target_fn
    assert '{"key": "X"' not in target_fn


def test_offer_toast_is_title_only():
    intro = src(INTRO)
    offer = intro.split("func toast_for_offer")[1].split("func flag_postcard")[0]
    assert "return {}" in offer
    assert offer.count('"detail": ""') >= 2
    assert "waiting on the Arc" in offer
    assert "New offer from" in offer
    assert "Tap here to read & accept" not in intro


def test_commitments_and_standing_are_rooms_not_plots():
    board = src(BOARD)
    assert "math:" not in board.split("func _make_commitment_row")[1].split("func ")[0]
    assert "tutorial_hint" in board.split("func _commitments_inspect_text_for")[1].split("func ")[0]
    bridge = src(BRIDGE)
    standing = bridge.split("func _on_standing_changed")[1].split("func ")[0]
    assert "felt_standing" in standing
    assert "%+.2f" not in standing


def test_arc_and_story_consume_the_spine():
    arc = src(ARC)
    assert "IntroVoice.doors_ahead" in arc
    assert "IntroVoice.memoir" in arc
    assert "IntroVoice.chapter_line" in arc
    assert "leaning toward" in arc
    face_story = arc.split("func _fill_story_live_top")[1].split("func _fill_story_static_mid")[0]
    assert "activity" not in face_story.lower() or "toast ring" in face_story.lower()


def test_metro_is_one_coupling_at_orb_centre():
    field = src(FIELD)
    metro = field.split("func _recompute_metro_segs")[1].split("func ")[0]
    assert "q_src" in metro and "q_tgt" in metro
    assert "_emoji_pole_pos" not in metro
    assert "first_harvest" not in src(SEED).split("func _pick_seed")[1] or \
        'nid != "first_harvest"' in src(SEED) or '== "first_harvest"' in src(SEED)
