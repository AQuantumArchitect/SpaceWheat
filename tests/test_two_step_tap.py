"""Taps are two-step: the first tap on a plot SELECTS it, the next tap on the
selected plot runs the recommended verb.

The old behavior fired Explore/Strike/Gather the moment a pointer landed, which
a touch player cannot take back and a mouse player cannot aim around. These are
source-contract pins (the repo's convention for QII input rules, see
test_confirm_chord_mouse_parity.py): they fail if a refactor lets a first tap
act, forgets to disarm on other focus moves, or arms from the wrong place.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
QII = ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd"


def _src() -> str:
    return QII.read_text(encoding="utf-8")


def _func_body(src: str, name: str) -> str:
    m = re.search(r"^func %s\(.*?\n(.*?)(?=^func |\Z)" % re.escape(name), src, re.DOTALL | re.MULTILINE)
    assert m, "%s not found" % name
    return m.group(1)


def test_tap_armed_state_exists_and_starts_unarmed():
    src = _src()
    assert re.search(r"^var _tap_armed_pos: Vector2i = GridSentinel\.INVALID_POSITION", src, re.MULTILINE), (
        "the two-step tap needs _tap_armed_pos, starting INVALID (nothing armed)"
    )


def test_every_focus_move_disarms():
    body = _func_body(_src(), "_focus_plot")
    assert "_tap_armed_pos = GridSentinel.INVALID_POSITION" in body, (
        "_focus_plot must disarm: keyboard picks and biome switches go through it, "
        "and a stale arm would let a later first tap act"
    )


def test_first_tap_selects_and_does_not_dispatch():
    body = _func_body(_src(), "handle_bubble_tap")
    sel = body.index("if not already_selected:")
    verb_dispatch = body.index("match verb:")
    assert sel < verb_dispatch, "the select-only branch must come before any verb dispatch"
    branch = body[sel:body.index("var verb := predict_tap_verb(grid_pos)", sel)]
    assert '"action": "select"' in branch, "the select-only tap must report action=select"
    assert "return " in branch, "the select-only branch must return before dispatching a verb"
    assert "_run_action" not in branch, "a selecting tap must never run an action"


def test_already_selected_needs_armed_and_live_cursor():
    # Cursor-alone is wrong: current_plot_idx starts at 0, so the very first tap
    # of a run on plot 0 would act. Both must hold.
    body = _func_body(_src(), "handle_bubble_tap")
    m = re.search(r"var already_selected: bool = \((.*?)\n\t\)", body, re.DOTALL)
    assert m, "already_selected definition not found"
    expr = m.group(1)
    assert "_tap_armed_pos == grid_pos" in expr
    assert "_instrument.current_plot_idx == grid_pos.x" in expr
    assert "_instrument.current_biome == biome_name" in expr


def test_arming_happens_after_the_focus_move_and_only_in_the_tap_path():
    src = _src()
    body = _func_body(src, "handle_bubble_tap")
    # select branch: focus first, arm second (arming first would be wiped by _focus_plot)
    sel = body[body.index("if not already_selected:"):]
    assert sel.index("_focus_plot(grid_pos.x, biome_name)") < sel.index("_tap_armed_pos = grid_pos")
    # biome-switch tap arms too, again after its _focus_plot
    sw = body[body.index("focus_biome") - 400:body.index("focus_biome")]
    assert sw.index("_focus_plot(grid_pos.x, biome_name)") < sw.index("_tap_armed_pos = grid_pos")
    # nothing outside handle_bubble_tap may arm
    arms = [m.start() for m in re.finditer(r"_tap_armed_pos = grid_pos", src)]
    start = src.index("func handle_bubble_tap(")
    end = src.index("\nfunc ", start + 1)
    assert arms and all(start <= a <= end for a in arms), "only the tap path may arm"


def test_shift_and_multi_select_taps_bypass_the_two_step():
    body = _func_body(_src(), "handle_bubble_tap")
    assert body.index("toggle_check(grid_pos)") < body.index("if not already_selected:"), (
        "Shift-tap / MULTI-mode toggles the checkbox and must stay one-tap"
    )


def test_select_hint_is_bounded():
    src = _src()
    assert re.search(r"^var _tap_select_hints_left: int = \d+", src, re.MULTILINE)
    body = _func_body(src, "_note_tap_selected")
    assert "_tap_select_hints_left <= 0" in body and "_tap_select_hints_left -= 1" in body, (
        "the select toast teaches the rule a few times, then stays quiet"
    )
