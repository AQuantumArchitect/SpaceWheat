"""Hats, menus, and the E chip name themselves.

Wave 6: Ace E said Pause next to a Superpose banner (dual-[E]).
Wave 7: Superpose is followable once the hat is named; icon-only chips
still hid which hat/menu was which. Captions and Superpose-on-E are
the same mill-chip class as [C] opens the board.
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


def test_ace_e_renames_to_superpose_on_the_live_door() -> None:
    ace = _read("Core/UI/AceChipResolvers.gd")
    assert "func resolve_e" in ace
    assert "superposition" in ace
    assert '"label": "Superpose"' in ace
    assert '"disabled": false' in ace
    registry = _read("Core/UI/ChipResolverRegistry.gd")
    assert "ace.e_superpose" in registry
    cfg = _read("Core/GameState/ToolConfig.gd")
    assert "ace.e_superpose" in cfg
    # Ace still pauses the rest of the time.
    assert '"label": "Pause"' in cfg


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
