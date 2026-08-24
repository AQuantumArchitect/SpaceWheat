"""Top-strip geometry laws (re-band 2026-08-24: hats level with menus).

The strip is two bands now — band 0 = hats (left) + menus (right), band 1 =
mode chips (under the hats) + clock (right corner) — and three drifts that
made it read as mucky are pinned shut here:

  1. ONE SCALE: only the menu row used to receive the layout manager, so menu
     chips rendered 1.5x the hats' size at 720p. Every row gets it now.
  2. ONE HEIGHT AUTHORITY: get_resource_bar_height used to say h(50) (~9.3%)
     while FarmUI drew the strip at 6% — a ~23px band of dead air between the
     strip and the first chips. The getter speaks TOP_BAR_HEIGHT_PERCENT now.
  3. NO MAGIC CORNERS: ActFilament/ContractChip tops were hand-tuned 140/202,
     going stale on every re-band. They derive from the layout manager now.
"""

from conftest import read_source


def test_every_row_receives_the_layout_manager() -> None:
    src = read_source("UI/Managers/ActionBarManager.gd")
    create = src.split("func create_action_bars", 1)[1].split("\nfunc ", 1)[0]
    # tool, mode, clock, menu, action_preview -- five rows, five handoffs,
    # each BEFORE add_child (the scale is copied once in _ready).
    assert create.count(".set_layout_manager(layout_manager)") == 5, (
        "a row built without the layout manager renders at scale 1.0 while its "
        "band-mates render at the snapped viewport scale -- the mismatched-chip "
        "muck this wave removed"
    )


def test_resource_bar_height_has_one_authority() -> None:
    lm = read_source("UI/Managers/UILayoutManager.gd")
    getter = lm.split("func get_resource_bar_height", 1)[1].split("\nfunc ", 1)[0]
    assert "TOP_BAR_HEIGHT_PERCENT" in getter, (
        "the band math must start where the drawn strip actually ends (FarmUI "
        "draws viewport_h * TOP_BAR_HEIGHT_PERCENT) -- two authorities here is "
        "the dead-air gap coming back"
    )
    assert "RESOURCE_BAR_BASE_HEIGHT" not in lm


def test_contract_corner_derives_from_the_layout_manager() -> None:
    rm = read_source("Core/Boot/RuntimeMount.gd")
    assert "offset_top = 140.0" not in rm
    assert "offset_top = 202.0" not in rm
    assert "get_resource_bar_height" in rm and "get_action_row_height" in rm
    assert "corner_top + ACT_BANNER_BLOCK" in rm
