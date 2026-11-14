"""Right click on a plot = Q (gather); left click stays the auto F/R tap.

Source-contract pins (same convention as test_two_step_tap.py).
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
QII = (ROOT / "UI/Core/QuantumInstrumentInput.gd").read_text(encoding="utf-8")
GRID = (ROOT / "UI/PlotGridDisplay.gd").read_text(encoding="utf-8")
FARM = (ROOT / "UI/FarmView.gd").read_text(encoding="utf-8")
CONTROLS = (ROOT / "UI/Overlays/ControlsOverlay.gd").read_text(encoding="utf-8")


def _body(src, name):
    m = re.search(r"^func %s\(.*?\n(.*?)(?=^func |\Z)" % re.escape(name), src, re.DOTALL | re.MULTILINE)
    assert m, name
    return m.group(1)


def test_gather_only_fires_pop_and_never_selects_first():
    b = _body(QII, "handle_bubble_gather")
    assert '_run_action("pop"' in b
    assert "explore" not in b and "measure" not in b
    assert "_tap_armed_pos" not in b, "gather has no two-step select"


def test_gather_is_silent_noop_unless_pop_and_respects_overlays():
    b = _body(QII, "handle_bubble_gather")
    assert "_tap_blocked_by_overlay()" in b
    assert 'predict_tap_verb(grid_pos) != "pop"' in b
    # the no-op check precedes any focus move or dispatch
    assert b.index('predict_tap_verb(grid_pos) != "pop"') < b.index("_focus_plot")
    assert "_toast" not in b


def test_2d_right_click_routes_and_consumes():
    m = re.search(r"MOUSE_BUTTON_RIGHT:(.*?)elif event\.button_index == MOUSE_BUTTON_LEFT", GRID, re.DOTALL)
    assert m
    assert "handle_bubble_gather" in m.group(1)
    assert "set_input_as_handled" in m.group(1)


def test_3d_right_click_gathers_not_taps():
    b = _body(FARM, "_on_quantum_node_clicked")
    assert b.index("MOUSE_BUTTON_RIGHT") < b.index("handle_bubble_tap(")
    assert "handle_bubble_gather" in b


def test_left_click_path_unchanged_and_copy_mentions_right_click():
    assert "handle_bubble_tap(plot_pos)" in GRID
    assert "right click = Q" in CONTROLS
