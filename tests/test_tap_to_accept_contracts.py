"""Contracts accept on a confirm tap, not only on R.

Playtest 2026-10-29: "double click or confirm click on the market contracts
to accept them; right now you have to press R". Board (QuestBoard): first tap
selects + arms, a second tap on the armed row runs R — it now fires on PRESS
so the 1 s heartbeat re-render can't swallow the release. Arc
(ControlsOverlay): the confirm tap on an unsigned offer accepts through the
same _accept_selected_arc as R.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
QB = ROOT / "UI" / "Overlays" / "QuestBoard.gd"
CO = ROOT / "UI" / "Overlays" / "ControlsOverlay.gd"


def _fn(p: Path, name: str) -> str:
    return p.read_text(encoding="utf-8").split("func %s(" % name)[1].split("\nfunc ")[0]


def test_board_row_tap_fires_on_press_and_confirms_with_r():
    body = _fn(QB, "_on_row_gui_input")
    assert "and event.pressed)" in body and "not event.pressed" not in body
    assert body.index("_row_confirm_armed") < body.index("_on_action_r()")
    assert "_select(idx)" in body


def test_arc_confirm_tap_accepts_offers_via_the_r_path():
    tunnel = _fn(CO, "_tunnel_from_arc")
    assert 'kind", "")) == "arc_quest"' in tunnel
    assert "_accept_selected_arc()" in tunnel
    select = _fn(CO, "_select_arc_row")
    first = select.split("if _arc_selected_idx != idx:")[1].split("return")[0]
    assert "_accept_selected_arc" not in first, "the selecting tap must never accept"
