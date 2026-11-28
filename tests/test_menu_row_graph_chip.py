"""The Neighborhood Graph ([) chip is on the surface button row (#149).

Behaviour is pinned in tests/menu_row_progression_smoke.gd; the source pin
keeps "[" in the row's key order.
"""
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
ROW = ROOT / "UI" / "Widgets" / "MenuSelectionRow.gd"


def test_row_key_order_includes_bracket():
    assert '"M", "["]' in ROW.read_text(encoding="utf-8")


def test_graph_chip_battery():
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    r = subprocess.run(
        ["godot", "--headless", "--script", "tests/menu_row_progression_smoke.gd"],
        cwd=ROOT, capture_output=True, text=True, timeout=300,
    )
    out = r.stdout + r.stderr
    assert r.returncode == 0, out[-3000:]
    assert "SCRIPT ERROR" not in out, out[-3000:]
