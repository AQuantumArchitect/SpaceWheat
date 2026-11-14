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
