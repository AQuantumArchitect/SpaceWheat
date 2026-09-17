"""Hats and menus name themselves. Ace never does Druid things.

Superpose is Druid E. Ace E is Pause, always. The banner names [0] Druid
then [E] Superpose — the player walks that door. No auto-wear, no Ace
chip that advertises Superpose.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def test_druid_e_is_superpose_not_h_gate() -> None:
    src = _read("Core/GameState/ToolConfig.gd")
    assert '"label": "Superpose"' in src
    assert src.count('"label": "H-Gate"') == 0
    assert src.count("hadamard") >= 3


def test_ace_e_is_always_pause_never_superpose() -> None:
    cfg = _read("Core/GameState/ToolConfig.gd")
    ace = _read("Core/UI/AceChipResolvers.gd")
    qii = _read("UI/Core/QuantumInstrumentInput.gd")
    registry = _read("Core/UI/ChipResolverRegistry.gd")
    assert '"label": "Pause"' in cfg
    assert "ace.e_superpose" not in cfg
    assert "ace.e_superpose" not in registry
    assert "func resolve_e" not in ace
    assert "_maybe_wear_live_hat" not in qii
    ctx = _read("UI/Managers/UIContextController.gd")
    assert "AceChipResolvers.resolve_e" not in ctx


def test_operator_r_is_gate_not_weave() -> None:
    """Buttons only do what they advertise. Operator R opens Gate. Bell is
    submenu Q after two plots are marked. Ace never weaves."""
    cfg = _read("Core/GameState/ToolConfig.gd")
    op = cfg.split("FRAME_OPERATOR: {")[1].split("FRAME_DRUID:")[0]
    assert '"label": "Gate"' in op
    assert '"label": "Weave"' not in op
    assert '"submenu": "gate_selection"' in op
    qii = _read("UI/Core/QuantumInstrumentInput.gd")
    assert "_maybe_wear_live_hat" not in qii
    ace = _read("Core/UI/AceChipResolvers.gd")
    assert "weave" not in ace.lower()
    assert "bell" not in ace.lower()


def test_hat_and_menu_chips_carry_a_caption_box() -> None:
    row = _read("UI/Widgets/SelectionButtonRow.gd")
    assert 'spec.get("caption"' in row
    assert 'name = "CaptionBox"' in row
    hats = _read("UI/Widgets/ToolSelectionRow.gd")
    assert '"caption": label_name' in hats
    menus = _read("UI/Widgets/MenuSelectionRow.gd")
    assert '"caption": caption' in menus
    registry = _read("UI/Core/MenuRegistry.gd")
    assert '"caption": "Board"' in registry
    assert '"caption": "Story"' in registry
    assert '"caption": "Farm"' in registry
