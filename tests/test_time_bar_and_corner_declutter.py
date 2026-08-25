"""Corner-declutter + TimeBar placeholder laws (2026-08-25).

Owner sent a screenshot: a resource emoji clipped by the ChromeFrame molding,
and a top-right corner crowded with the objective banner (ActFilament), the
offer chip (ContractChip), toasts, and the resource strip's tail all fighting
for the same patch of screen. Fixes, pinned here:

  1. ActFilament ("next objective") moves to bottom-left, close to the
     actions -- ContractChip alone stays top-right, a much lighter corner.
  2. HintToastStack moves to bottom-left too, stacking UPWARD from just
     above the banner ("the toasts are above it," the owner's own words).
  3. A new inert TimeBar placeholder reserves a full-width strip between the
     resource bar and the first top chip band, for a future history-scrubber
     -- UI only, no mechanics, so every top-row offset that used to derive
     from get_resource_bar_height() alone must now also add
     get_time_bar_height() or the new strip silently gets painted under.
"""

from conftest import read_source


def test_time_bar_is_inert_chrome() -> None:
    # Same contract as ChromeFrame: pure _draw(), no children, can never eat
    # a click. When the real scrubber lands, flipping mouse_filter to STOP
    # and wiring gui_input is a deliberate later step, not something to fake
    # now.
    src = read_source("UI/Widgets/TimeBar.gd")
    assert "mouse_filter = Control.MOUSE_FILTER_IGNORE" in src
    assert "gui_input" not in src
    assert "MOUSE_FILTER_STOP" not in src
    assert "add_child(" not in src


def test_time_bar_height_is_a_layout_authority() -> None:
    lm = read_source("UI/Managers/UILayoutManager.gd")
    assert "func get_time_bar_height() -> float:" in lm


def test_top_rows_clear_the_time_bar() -> None:
    abm = read_source("UI/Managers/ActionBarManager.gd")
    top_row_block = abm.split("func _position_top_row", 1)[1].split("\nfunc ", 1)[0]
    assert "get_time_bar_height()" in top_row_block, (
        "a top row positioned from get_resource_bar_height() alone renders "
        "UNDER the new TimeBar placeholder instead of below it"
    )

    rm = read_source("Core/Boot/RuntimeMount.gd")
    assert "get_time_bar_height()" in rm, (
        "ContractChip's corner_top must also clear the TimeBar placeholder"
    )


def test_objective_banner_moved_bottom_left() -> None:
    rm = read_source("Core/Boot/RuntimeMount.gd")
    act_filament_block = rm.split('act_filament.name = "ActFilament"', 1)[1].split("act_filament.setup", 1)[0]
    assert "PRESET_BOTTOM_LEFT" in act_filament_block
    assert "PRESET_TOP_RIGHT" not in act_filament_block

    contract_chip_block = rm.split('contract_chip.name = "ContractChip"', 1)[1].split("contract_chip.setup", 1)[0]
    assert "PRESET_TOP_RIGHT" in contract_chip_block, (
        "ContractChip stays top-right by design -- only the banner moved"
    )


def test_toasts_stack_above_the_relocated_banner() -> None:
    shell = read_source("UI/PlayerShell.gd")
    toast_block = shell.split('_hint_toast_stack.name = "HintToastStack"', 1)[1] \
        .split("overlay_layer.add_child(_hint_toast_stack)", 1)[0]
    assert "PRESET_BOTTOM_LEFT" in toast_block
    assert "PRESET_BOTTOM_RIGHT" not in toast_block
