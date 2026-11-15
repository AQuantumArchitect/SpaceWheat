"""Source-shape pin (#120): F flattens out of any open surface, one layer per press.

Keyboard F and the touch F chip share PlayerShell._flatten_surface(); the chip
reads "🌾 Farm" when the next F lands on the farm.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHELL = (ROOT / "UI" / "PlayerShell.gd").read_text(encoding="utf-8")
ROW = (ROOT / "UI" / "Widgets" / "ActionPreviewRow.gd").read_text(encoding="utf-8")


def _body(text, sig):
    return text.split(sig, 1)[1].split("\nfunc ", 1)[0]


def test_overlay_f_verb_runs_before_flatten():
    # Overlays route first; F flattens only if the overlay did not consume it,
    # and always ahead of the bleed-through guard that would swallow it.
    body = _body(SHELL, "func _input(")
    assert body.index("overlay_stack.route_input") < body.index("_flatten_surface()")
    assert body.index("_flatten_surface()") < body.index("Bleed-through guard")


def test_flatten_yields_to_overlays_that_claim_f():
    # QuestBoard/Market lock, EscapeMenu confirm, ControlsOverlay Play all label F.
    assert "_top_overlay_owns_f()" in _body(SHELL, "func _flatten_surface")
    owns = _body(SHELL, "func _top_overlay_owns_f")
    assert 'get_action_labels().get("F"' in owns and '"—"' in owns
    for src in ("QuestBoard", "EscapeMenu", "ControlsOverlay"):
        text = (ROOT / "UI" / "Overlays" / (src + ".gd")).read_text(encoding="utf-8")
        assert "_on_action_f" in text, src


def test_flatten_mode_depth_math():
    # FarmView is stack index 0: one open surface is size() == 2.
    body = _body(SHELL, "func _flatten_mode")
    assert "_any_menu_open()" in body and "_top_overlay_owns_f()" in body
    assert "overlay_stack.size() - 1 == 1" in body


def test_touch_f_flattens():
    assert "_flatten_surface()" in _body(SHELL, "func _route_action_key")


def test_flatten_pops_one_level_only_off_the_farm():
    body = _body(SHELL, "func _flatten_surface")
    assert "_any_menu_open()" in body and "close_overlay()" in body
    assert "close_all" not in body


def test_label_flips_to_farm_on_top_surface():
    assert "stack_changed.connect(_refresh_flatten_label)" in SHELL
    assert '"Farm" if flatten_mode == 1' in ROW


def test_escape_menu_confirm_and_market_lock_keep_f():
    esc = (ROOT / "UI" / "Overlays" / "EscapeMenu.gd").read_text(encoding="utf-8")
    assert '"F": "quit without saving"' in esc and '"F": "confirm reset"' in esc
    qb = (ROOT / "UI" / "Overlays" / "QuestBoard.gd").read_text(encoding="utf-8")
    assert '"F": f_label' in qb  # Market price lock rides the F label
