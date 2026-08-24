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
