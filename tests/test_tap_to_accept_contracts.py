"""Only R accepts (issue #76).

Luke's playtest 2026-11-14: G pressed three times accepted the first quest.
Row keys (G H J K L ;), row clicks and E only ever give more information;
R (or the Accept label, which sends R) is the one verb that accepts/delivers.
Supersedes the 2026-10-29 "confirm tap accepts" rule.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
QB = ROOT / "UI" / "Overlays" / "QuestBoard.gd"
CO = ROOT / "UI" / "Overlays" / "ControlsOverlay.gd"


def _fn(p: Path, name: str) -> str:
    return p.read_text(encoding="utf-8").split("func %s(" % name)[1].split("\nfunc ")[0]


def test_board_row_press_only_selects():
    body = _fn(QB, "_on_row_gui_input")
    assert "_select(idx)" in body
    assert "_on_action_r" not in body and "_accept" not in body


def test_board_row_keys_only_select():
    src = QB.read_text(encoding="utf-8")
    keys = src.split("func _on_unhandled_key(")[1].split("\n## Send the cursor back")[0]
    assert "_select(_item_page * MAX_VISIBLE_ITEMS + item_idx)" in keys
    for verb in ("_on_action_r", "_accept_selected", "_complete_selected"):
        assert verb not in keys
    assert "_row_confirm_armed" not in src, "no arm-then-commit state may exist"
    assert "_accept_selected" not in _fn(QB, "_select")


def test_board_e_never_accepts_and_is_labelled_info():
    e = _fn(QB, "_on_action_e")
    for verb in ("_accept_selected", "_complete_selected", "_on_action_r", "_toggle_lock"):
        assert verb not in e
    market = QB.read_text(encoding="utf-8").split("func _current_verb_labels")[1].split("FRAME_COMMITMENTS:")[0]
    assert '"E": "Info"' in market and '"E": "Refresh", "R": "Accept"' not in market


def test_board_r_accepts_the_selected_offer_once():
    r = _fn(QB, "_on_action_r")
    assert r.count("_accept_selected()") == 1
    assert "_complete_selected()" in r


def test_arc_taps_and_keys_never_accept():
    select = _fn(CO, "_select_arc_row")
    assert "_accept_selected_arc" not in select
    tunnel = _fn(CO, "_tunnel_from_arc")
    assert "_accept_selected_arc" not in tunnel
    # E toggles info only.
    e = _fn(CO, "_on_action_e")
    assert "_accept" not in e
    # The one accept entry point from a verb is R.
    assert "_accept_selected_arc()" in _fn(CO, "_on_action_r")


def test_hint_copy_names_details_then_r():
    assert "for details, [R] Accept" in QB.read_text(encoding="utf-8")
    assert "again to accept" not in CO.read_text(encoding="utf-8")
