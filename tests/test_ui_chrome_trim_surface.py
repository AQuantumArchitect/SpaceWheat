"""Dressing-pass chrome laws (2026-08-24): trim stays quiet, and can't eat clicks.

The dressing pass added decorative chrome — ChromeFrame (viewport hairlines +
vignette), trim trays on the resource strip / QERF dock / chip clusters — into
a codebase whose worst historical failure class is a decorative Control that
silently eats clicks (a STOP panel with no gui_input handler). These ratchets
pin the two laws that keep the dressing safe:

  1. decorative chrome is draw-only and IGNORE — it can never claim a pick;
  2. trim is 1px forever — 2px and 3px are reserved state cues (HintToast
     importance ramp, the would-fire green border), and the accent gold has
     ONE spelling (UIStyleFactory.COLOR_ACCENT_GOLD), so gold at full alpha
     keeps meaning "look here" instead of becoming wallpaper.
"""

from pathlib import Path

from conftest import ROOT, read_source


def test_resource_panel_paints_above_the_frame() -> None:
    # Corner-declutter pass (2026-08-25, owner screenshot): ChromeFrame draws
    # at absolute z 55. ResourcePanel had no z override, so its effective z
    # was whatever its ancestor chain gave it (well under 55) -- the frame's
    # molding/rivet painted OVER resource emojis in the corner. Decorative
    # chrome must never out-rank real HUD content it happens to overlap.
    panel = read_source("UI/Widgets/ResourcePanel.gd")
    assert "z_as_relative = false" in panel
    assert "z_index = 56" in panel


def test_chrome_frame_cannot_eat_clicks() -> None:
    src = read_source("UI/Widgets/ChromeFrame.gd")
    assert "mouse_filter = Control.MOUSE_FILTER_IGNORE" in src
    assert "z_as_relative = false" in src
    # Draw-only by construction: no input handling, no STOP, no child nodes.
    assert "gui_input" not in src
    assert "MOUSE_FILTER_STOP" not in src
    assert "add_child(" not in src


def test_dock_dressing_leaves_the_state_grammar_alone() -> None:
    apr = read_source("UI/Widgets/ActionPreviewRow.gd")
    assert "mouse_filter = MOUSE_FILTER_IGNORE" in apr
    assert "WOULD_FIRE_BORDER_WIDTH" in apr


def test_trim_is_one_pixel_forever() -> None:
    factory = read_source("UI/Core/UIStyleFactory.gd")
    trim = factory.split("static func create_trim_style", 1)[1].split("static func draw_trim", 1)[0]
    assert "set_border_width_all(1)" in trim


def test_the_pointer_tells_the_truth_over_chips() -> None:
    # Feel pass: the hand cursor appeared over every ClickWire'd surface
    # (ClickWire.gd sets it on attach) but went dead over the chip rows --
    # the HUD's most-clicked controls. Both chip factories set it now, and
    # both hand the ARROW back on a disabled chip (a hand over a dead chip
    # promises a click that won't fire -- the anti-gating law's cursor form).
    for rel in ("UI/Widgets/SelectionButtonRow.gd", "UI/Widgets/ActionPreviewRow.gd"):
        src = read_source(rel)
        assert "CURSOR_POINTING_HAND" in src, rel
        assert "CURSOR_ARROW" in src, rel


def test_accent_gold_has_one_spelling_in_ui() -> None:
    offenders = []
    for path in (ROOT / "UI").rglob("*.gd"):
        rel = path.relative_to(ROOT).as_posix()
        if rel == "UI/Core/UIStyleFactory.gd":
            continue
        if "Color(1.0, 0.8, 0.3" in path.read_text(encoding="utf-8"):
            offenders.append(rel)
    assert offenders == [], (
        "accent gold spelled as a raw literal (use UIStyleFactory.COLOR_ACCENT_GOLD "
        "so the accent stays one value): %s" % offenders
    )


def test_frame_is_a_molding_not_a_flat_line() -> None:
    # Border-weight pass (2026-08-24, owner ask: "approaching brass picture
    # frame or clockwork machinery"). The bolder read comes from LAYERING
    # several reserved-1px rings into a bevel (drawn via a loop over
    # MOLD_RING_TONES, not repeated call sites -- the loop IS the dedup this
    # codebase favors), not from widening any single stroke -- collapsing the
    # tone list to 1-2 entries makes the frame a flat line again, leaving the
    # reserved 2px/3px state-cue widths as the only way left to look "bold,"
    # exactly the collision the trim vocabulary was written to prevent.
    frame = read_source("UI/Widgets/ChromeFrame.gd")
    tones_block = frame.split("MOLD_RING_TONES: Array = [", 1)[1].split("]", 1)[0]
    assert tones_block.count('"') >= 6, "need >=3 quoted tones in MOLD_RING_TONES"
    assert "UIStyleFactory.draw_trim(" in frame
    assert "COLOR_BRASS_HIGHLIGHT" in frame
    assert "COLOR_BRASS_SHADOW" in frame


def test_brass_palette_has_one_spelling_in_ui() -> None:
    offenders = []
    for path in (ROOT / "UI").rglob("*.gd"):
        rel = path.relative_to(ROOT).as_posix()
        if rel == "UI/Core/UIStyleFactory.gd":
            continue
        text = path.read_text(encoding="utf-8")
        if "Color(0.95, 0.80, 0.45" in text or "Color(0.72, 0.55, 0.25" in text \
                or "Color(0.28, 0.19, 0.08" in text:
            offenders.append(rel)
    assert offenders == [], (
        "brass molding tone spelled as a raw literal (use "
        "UIStyleFactory.COLOR_BRASS_* so the frame stays one recipe): %s" % offenders
    )
