"""Tap = click: ClickWire accepts a left-mouse OR finger release (#154).

No Godot on the test box, so these pin the source contract: the one shared
helper exists, covers both event types, and the chrome handlers route through it.
"""
from conftest import read_source

HANDLERS = [
    "UI/Widgets/ActionPreviewRow.gd", "UI/Widgets/SelectionButtonRow.gd",
    "UI/Widgets/ReapButton.gd", "UI/Widgets/ContractChip.gd",
    "UI/Widgets/HintToast.gd", "UI/Overlays/EscapeMenu.gd",
    "UI/Overlays/QuestBoard.gd",
]


def test_clickwire_accepts_mouse_and_touch_release() -> None:
    src = read_source("UI/Core/ClickWire.gd")
    assert "InputEventMouseButton" in src and "InputEventScreenTouch" in src
    assert "MOUSE_BUTTON_LEFT" in src
    assert "static func is_release" in src and "static func is_press" in src
    attach = src.split("static func attach(")[1]
    assert "is_release(event)" in attach


def test_emulated_pair_is_deduped() -> None:
    src = read_source("UI/Core/ClickWire.gd")
    assert "get_process_frames" in src, "emulated mouse + raw touch must fire once"


def test_chrome_handlers_use_the_shared_helper() -> None:
    for path in HANDLERS:
        src = read_source(path)
        assert "ClickWire.is_" in src, path


def test_project_sets_touch_emulation_explicitly() -> None:
    src = read_source("project.godot")
    assert "[input_devices]" in src
    assert "pointing/emulate_mouse_from_touch=true" in src
    assert "emulate_touch_from_mouse=true" not in src
