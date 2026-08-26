"""Corner-declutter + TimeBar laws (2026-08-25, two passes in one day).

PASS ONE. Owner sent a screenshot: a resource emoji clipped by the ChromeFrame
molding, and a top-right corner crowded with the objective banner (ActFilament),
the offer chip (ContractChip), toasts, and the resource strip's tail all
fighting for the same patch of screen. The banner and the toasts moved to
bottom-LEFT and an inert TimeBar strip was scaffolded under the resource bar.

PASS TWO, after the next screenshot. Three things the first pass got wrong or
left half-done, pinned here so they cannot come back:

  1. Bottom-LEFT was the wrong corner. The field's portal rail — the labelled
     biome orbs — runs down the empty LEFT side (QuantumField3D._rebuild_portals
     pins them at x = -4.2), so the banner+toast column landed straight on top
     of it. The whole column is bottom-RIGHT now.
  2. The banner and the toasts looked like two unrelated shapes stacked in one
     column. They share ONE stylebox recipe now
     (UIStyleFactory.create_toast_style) — the owner's "pleasant harmony in
     form … maybe the stable objective hint can be a stable toast looking item?"
     made structural, so the two cannot drift apart again.
  3. The TimeBar was still inert scaffold while the transport chips (⏪ ⏸ ⏩)
     owned a whole top band in the crowded corner. The chips ride the track
     now — "the time controls need to start getting integrated into the
     timebar" — which is also what removed a band from the top strip.
"""

from conftest import read_source


def test_time_bar_cannot_eat_a_click() -> None:
    # The strip is still draw-only: the transport chips that sit ON it are
    # their own Controls, parented elsewhere, with their own hitboxes. A
    # MOUSE_FILTER_IGNORE parent does not block them — and it does keep the
    # bar itself from ever claiming a pick, which is this codebase's worst
    # historical failure class (a decorative Control swallowing clicks).
    src = read_source("UI/Widgets/TimeBar.gd")
    assert "mouse_filter = Control.MOUSE_FILTER_IGNORE" in src
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
        "UNDER the TimeBar strip instead of below it"
    )

    rm = read_source("Core/Boot/RuntimeMount.gd")
    assert "get_time_bar_height()" in rm, (
        "ContractChip's corner_top must also clear the TimeBar strip"
    )


def test_the_transport_rides_the_time_bar_not_a_top_band() -> None:
    abm = read_source("UI/Managers/ActionBarManager.gd")
    clock_block = abm.split("func _position_clock_row", 1)[1].split("\nfunc ", 1)[0]
    # Positioned from the TimeBar's OWN two getters, so the chips and the strip
    # they sit on cannot land in different bands when the viewport re-scales.
    assert "get_resource_bar_height()" in clock_block
    assert "get_time_bar_height()" in clock_block
    assert "_position_top_row(" not in clock_block, (
        "the clock chips are not a top chip band any more — routing them back "
        "through _position_top_row puts them in the corner this pass emptied"
    )
    assert "CONTRACT_CORNER_INSET" not in abm, (
        "the 210px inset existed only to dodge the contract corner the clock "
        "row used to share; it goes stale the moment nothing uses it"
    )


def test_the_transport_carries_pause_and_never_owns_the_bit() -> None:
    row = read_source("UI/Widgets/ClockSpeedRow.gd")
    assert "pause_toggle_requested" in row
    # Same rule the speed chips follow: ask, never own. The row reads the
    # world's pause bit off PlayerShell's signal, so the glyph cannot disagree
    # with E/F or the escape menu.
    assert "paused_changed" in row
    assert "get_tree().paused" not in row
    ctx = read_source("UI/Managers/UIContextController.gd")
    assert "pause_toggle_requested" in ctx and "toggle_paused" in ctx


def test_objective_banner_and_toasts_share_one_corner_and_one_form() -> None:
    rm = read_source("Core/Boot/RuntimeMount.gd")
    act_filament_block = rm.split('act_filament.name = "ActFilament"', 1)[1] \
        .split("act_filament.setup", 1)[0]
    assert "PRESET_BOTTOM_RIGHT" in act_filament_block
    assert "PRESET_BOTTOM_LEFT" not in act_filament_block, (
        "bottom-left is the portal rail's column — the banner sat on top of "
        "the labelled biome orbs there"
    )

    shell = read_source("UI/PlayerShell.gd")
    toast_block = shell.split('_hint_toast_stack.name = "HintToastStack"', 1)[1] \
        .split("overlay_layer.add_child(_hint_toast_stack)", 1)[0]
    assert "PRESET_BOTTOM_RIGHT" in toast_block
    assert "PRESET_BOTTOM_LEFT" not in toast_block
    # The toasts stack directly on top of the banner, so they must be laid out
    # from the banner's OWN constants — a second hardcoded 72.0 here is exactly
    # how the two drifted into overlapping before.
    assert "ActFilament.BANNER_HEIGHT" in toast_block
    assert "ActFilament.BANNER_WIDTH" in toast_block

    # ONE recipe for the card, shared by both, so a tweak moves them together.
    factory = read_source("UI/Core/UIStyleFactory.gd")
    assert "static func create_toast_style(" in factory
    for rel in ("UI/Widgets/HintToast.gd", "UI/Widgets/ActFilament.gd"):
        assert "UIStyleFactory.create_toast_style(" in read_source(rel), rel


def test_contract_chip_keeps_the_top_right_corner_alone() -> None:
    rm = read_source("Core/Boot/RuntimeMount.gd")
    contract_chip_block = rm.split('contract_chip.name = "ContractChip"', 1)[1] \
        .split("contract_chip.setup", 1)[0]
    assert "PRESET_TOP_RIGHT" in contract_chip_block, (
        "ContractChip stays top-right by design — everything else left"
    )


def test_the_debug_readout_never_parks_on_the_resource_strip() -> None:
    # It rendered one ▶ glyph inside a 302px trim box over the strip's right
    # end in a PLAYER's build — the single biggest piece of the top-right
    # clutter, for a control the TimeBar's ⏸ chip now carries properly.
    shell = read_source("UI/PlayerShell.gd")
    assert "fps_display.visible = attached and RuntimeEnv.debug_readout_enabled()" in shell
    fps_block = shell.split("if fps_display:", 2)[2].split("\n\n", 1)[0]
    assert "get_resource_bar_height()" in fps_block, (
        "the readout must derive its top from the strip it used to sit on top of"
    )
