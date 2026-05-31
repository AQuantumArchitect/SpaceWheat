from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
ACTION_PREVIEW = PROJECT_ROOT / "UI" / "Widgets" / "ActionPreviewRow.gd"
QUEST_BOARD = PROJECT_ROOT / "UI" / "Overlays" / "QuestBoard.gd"
ICON_SUBMENU = PROJECT_ROOT / "UI" / "Core" / "Submenus" / "IconInjectionSubmenu.gd"


def test_action_preview_uses_runtime_economy_surface() -> None:
    src = ACTION_PREVIEW.read_text(encoding="utf-8")
    assert "EconomyConstants" not in src
    assert "ActionCostRuntime" not in src


def test_quest_board_uses_runtime_economy_surface() -> None:
    src = QUEST_BOARD.read_text(encoding="utf-8")
    assert "EconomyConstants" not in src
    assert "ActionCostRuntime" not in src


def test_icon_submenu_uses_runtime_injection_cost_surface() -> None:
    src = ICON_SUBMENU.read_text(encoding="utf-8")
    assert '_get_injection_cost(farm, south)' in src
    assert 'return {"energy": 1}' not in src
    assert "ActionCostRuntime.get_action_cost(" in src
