"""Issue #145: one-finger drag-select on the 2D plot rack.

Source pins always run; the headless Godot smoke
(tests/touch_drag_select_smoke.gd) synthesizes InputEventScreenTouch /
InputEventScreenDrag and skips when godot is not on PATH.
"""
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
GRID = (ROOT / "UI" / "PlotGridDisplay.gd").read_text(encoding="utf-8")
SMOKE = ROOT / "tests" / "touch_drag_select_smoke.gd"


def test_touch_path_is_wired_behind_the_visible_gate():
    inp = GRID.split("func _input(")[1].split("\nfunc _touch_drag_button")[0]
    assert inp.index("if not visible") < inp.index("InputEventScreenTouch")
    assert "InputEventScreenDrag" in inp
    assert "TODO: Implement Godot 4 touch drag" not in GRID


def test_tap_threshold_matches_touch_manager():
    tim = (ROOT / "UI" / "Input" / "TouchInputManager.gd").read_text(encoding="utf-8")
    assert "const TAP_MAX_MOVEMENT: float = 30.0" in tim
    assert "const TOUCH_DRAG_MIN_MOVEMENT: float = 30.0" in GRID


def test_headless_touch_drag_smoke():
    if shutil.which("godot") is None:
        pytest.skip("godot not on PATH")
    proc = subprocess.run(
        ["godot", "--headless", "--path", str(ROOT), "--script", str(SMOKE)],
        capture_output=True, text=True, timeout=120,
    )
    assert proc.returncode == 0, proc.stdout[-2000:] + proc.stderr[-2000:]
