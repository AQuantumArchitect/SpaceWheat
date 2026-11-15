"""Pins #117: gold highlight keyed off the objective target, Q/E/R retire after 3 uses.

Source-level pins (no Godot needed); the behaviour lives in
UI/Core/ObjectiveTargets.gd and UI/Widgets/ObjectiveSpotlight.gd.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def src(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def test_gold_matches_toast_gold():
    assert "Color(1.0, 0.82, 0.2" in src("UI/Core/ObjectiveTargets.gd")
    assert "Color(1.0, 0.82, 0.2" in src("UI/Widgets/ActFilament.gd")


def test_spotlight_uses_registry_and_retirement():
    s = src("UI/Widgets/ObjectiveSpotlight.gd")
    assert "ObjectiveTargets.resolve(" in s
    assert "ObjectiveTargets.is_retired(" in s
    assert "GOLD_MODULATE" in s
    assert "reticle" not in s.lower().replace("never a reticle", "")


def test_surface_tabs_register_on_both_surfaces():
    assert "ObjectiveTargets.register(" in src("UI/Overlays/ControlsOverlay.gd")
    assert "ObjectiveTargets.register(" in src("UI/Overlays/QuestBoard.gd")


def test_use_counts_persist():
    for rel in ("Core/GameState/GameState.gd", "Core/Farm.gd"):
        assert "highlight_uses" in src(rel)
    ser = src("Core/GameState/GameStateSerializer.gd")
    assert ser.count("highlight_uses") >= 4  # capture + restore, both directions
    assert "ObjectiveTargets.note_use(" in src("UI/Core/QuantumInstrumentInput.gd")


def test_rows_chips_and_arc_register_specific_targets():
    assert "func row_id(" in src("UI/Core/ObjectiveTargets.gd")
    board = src("UI/Overlays/QuestBoard.gd")
    assert board.count("ObjectiveTargets.row_id(") >= 2   # offer rows + commitment rows
    assert "ObjectiveTargets.register(key, cell)" in board  # R accept/deliver, F flatten chips
    ctl = src("UI/Overlays/ControlsOverlay.gd")
    assert ctl.count("ObjectiveTargets.row_id(") >= 2     # arc + charge rows
    assert "ObjectiveTargets.row_id(row)" in src("UI/Core/UIProgression.gd")


def test_dummy_control_is_tinted_gold_by_the_spotlight():
    import shutil
    import subprocess

    import pytest
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    r = subprocess.run(["godot", "--headless", "--script", "tests/objective_highlight_smoke.gd"],
                       cwd=ROOT, capture_output=True, text=True, timeout=180)
    assert "Objective highlight smoke:" in r.stdout and r.returncode == 0, (r.stdout + r.stderr)[-1500:]
