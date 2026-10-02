"""Hats and menus name themselves. Ace never does Druid things.

Superpose is Druid E. Ace E is Pause, always. The banner names [0] Druid
then [E] Superpose — the player walks that door. No auto-wear, no Ace
chip that advertises Superpose.
"""
import json
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


def test_icon_r_is_plant() -> None:
    """Icon R is Plant on the action bar. Empty plot opens the picker.
    The chip must name the verb the banner already speaks."""
    cfg = _read("Core/GameState/ToolConfig.gd")
    icon = cfg.split("FRAME_ICON: {")[1].split("FRAME_MERCHANT: {")[0]
    inject = icon.split('"inject":')[1].split('"mirror":')[0]
    r_chip = inject.split('"R":')[1].split('"F":')[0]
    assert '"label": "Plant"' in r_chip
    assert '"label": "Add Icon"' not in r_chip
    grammar = _read("UI/Core/KEYBOARD_GRAMMAR.md")
    assert "Plant · Stay Home" in grammar
    resolvers = _read("Core/UI/IconChipResolvers.gd")
    assert 'static "Plant"' in resolvers
    assert "action_cue" in resolvers
    cfg_fn = _read("Core/GameState/ToolConfig.gd")
    assert "func action_cue(" in cfg_fn
    gloss = _read("Core/Quests/PredicateGloss.gd")
    assert "action_cue" in gloss
    assert "get_action_label" in gloss
    overlay = _read("UI/Overlays/ControlsOverlay.gd")
    assert "get_action_label(ToolConfig.FRAME_ICON, \"R\")" in overlay
    intro = _read("Core/Story/IntroVoice.gd")
    assert "get_action_label(ToolConfig.FRAME_ACE" in intro
    flags = json.loads(_read("Core/Quests/data/story_flags.json"))
    voices = next(f for f in flags if f.get("id") == "new_voices")
    assert "[R] Plant" in str(voices.get("arc_quest", {}).get("hint", ""))
    mill = next(f for f in flags if f.get("id") == "village_stirs")
    mill_hint = str(mill.get("arc_quest", {}).get("hint", ""))
    assert "[Y]" in mill_hint and "[U]" in mill_hint
    overlay = _read("UI/Core/OverlayBase.gd")
    assert "func action_cue(" in overlay
    board = _read("UI/Overlays/QuestBoard.gd")
    assert "ToolConfig.cue(" in board
    assert "VERB_ACCEPT" in board
    assert "VERB_DELIVER" in board


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
