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


def test_keyboard_f_flattens_before_overlay_routing():
    body = _body(SHELL, "func _input(")
    assert body.index("_flatten_surface()") < body.index("overlay_stack.route_input")


def test_touch_f_flattens():
    assert "_flatten_surface()" in _body(SHELL, "func _route_action_key")


def test_flatten_pops_one_level_only_off_the_farm():
    body = _body(SHELL, "func _flatten_surface")
    assert "_any_menu_open()" in body and "close_overlay()" in body
    assert "close_all" not in body


def test_label_flips_to_farm_on_top_surface():
    assert "stack_changed.connect(_refresh_flatten_label)" in SHELL
    assert '"Farm" if flatten_mode == 1' in ROW
