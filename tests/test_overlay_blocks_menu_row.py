"""Source-shape pin (#98): an open overlay must block clicks to the menu row.

Godot GUI picking is tree order, not z_index, and the ActionBarLayer sits after
the OverlayLayer. So the pointer bleed guard must switch off the menu row's
chips (the ZXCVBNM ring) along with the hat/mode rows when a real menu is up.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UCC = ROOT / "UI" / "Managers" / "UIContextController.gd"


def test_pointer_guard_covers_the_menu_row():
    text = UCC.read_text(encoding="utf-8")
    body = text.split("func _apply_pointer_bleed_guard", 1)[1].split("\nfunc ", 1)[0]
    rows = re.search(r"for row in \[(.*?)\]:", body, re.S).group(1)
    assert "get_menu_row()" in rows
    assert "get_tool_row()" in rows and "get_mode_row()" in rows
    assert "set_pointer_enabled(not menu_open)" in body
