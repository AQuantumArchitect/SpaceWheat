"""Hat row relocation laws (2026-08-24: hats + their sub-modes move to the bottom).

Owner ask: move the hat selection row off the top strip, down next to the QERF
actions ("close to the actions... between the circular center [field] and the
action bar"). The sub-mode chips (Spark's shift/bridge, Merchant's thermal/
dephase/damp, Druid's X/Y/Z) move with them rather than orphaning at the top —
"use the existing hat system as the basis for the new bottom row."

Two facts made this a one-band move, not a two-band one:

  1. Same-alignment rows collide (ClockSpeedRow's own comment: two
     right-aligned clusters on one row collide on a narrow window) — so hats
     (centered) and mode (a fixed right-hand dock) share ONE new bottom band
     rather than each claiming a band of their own.
  2. ActionBarManager.get_free_band() decides how tall the field renders. If
     hats/mode stayed in its TOP-row list while now living at the bottom, the
     field's play area would silently collapse (their new bottom-anchored rect
     would wrongly count as a top exclusion). They must move to the BOTTOM
     side of that calculation instead.
"""

from conftest import read_source


def test_hats_and_mode_use_the_bottom_index_positioner() -> None:
    src = read_source("UI/Managers/ActionBarManager.gd")
    tool_block = src.split("func _position_tool_row", 1)[1].split("\nfunc ", 1)[0]
    mode_block = src.split("func _position_mode_row", 1)[1].split("\nfunc ", 1)[0]
    assert "_position_row_at_index(tool_selection_row, 1)" in tool_block
    assert "_position_row_at_index(mode_selection_row, 1)" in mode_block
    # Neither goes through the TOP-strip positioner anymore.
    assert "_position_top_row(tool_selection_row" not in src
    assert "_position_top_row(mode_selection_row" not in src


def test_hats_center_and_mode_gets_a_fixed_dock() -> None:
    src = read_source("UI/Managers/ActionBarManager.gd")
    assert "BoxContainer.ALIGNMENT_CENTER" in src
    assert "MODE_DOCK_WIDTH" in src
    tool_block = src.split("func _position_tool_row", 1)[1].split("\nfunc ", 1)[0]
    assert "ALIGNMENT_CENTER" in tool_block


def test_free_band_excludes_hats_and_mode_from_the_top_rows() -> None:
    src = read_source("UI/Managers/ActionBarManager.gd")
    free_band = src.split("func get_free_band", 1)[1]
    top_loop = free_band.split("for row in", 2)[1]
    bottom_loop = free_band.split("for row in", 2)[2]
    assert "tool_selection_row" not in top_loop, (
        "the hat row now lives at the BOTTOM -- counting its rect as a top-row "
        "exclusion would wrongly shrink the field's play area from the top "
        "instead of the bottom"
    )
    assert "mode_selection_row" not in top_loop
    assert "tool_selection_row" in bottom_loop
    assert "mode_selection_row" in bottom_loop
    assert "action_preview_row" in bottom_loop
