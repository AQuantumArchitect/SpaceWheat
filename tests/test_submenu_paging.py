"""Submenu paging regression (sensor leg L2b, 2026-07-15).

The plant picker (Icon-hat R on an empty slot) paginates 3 options per page,
but the pager was dead end-to-end: F closed the submenu instead of cycling,
and QuantumInstrument.cycle_submenu_page reset the page to 0 before
regenerating. With >3 known icons every option past the first three was
unreachable — a freshly taught 🪵/🪓 could never be planted, so the taught
word LOOKED planted (🌱 spent on whatever the top-affinity page offered) while
the story beat never fired.

The GDScript battery (tests/test_submenu_integration.gd) asserts:
  - every known icon is reachable on SOME page (union of pages == vocabulary)
  - multi-page submenus advertise the F pager chip; single-page ones do not
  - QuantumInstrument.cycle_submenu_page actually advances and wraps
"""
import shutil
import subprocess
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def test_submenu_battery() -> None:
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    result = subprocess.run(
        ["godot", "--headless", "--script", "tests/test_submenu_integration.gd"],
        cwd=PROJECT_ROOT, capture_output=True, text=True, timeout=180,
    )
    tail = (result.stdout + result.stderr)[-2000:]
    assert result.returncode == 0, f"submenu battery failed:\n{tail}"
    assert "0 failed" in result.stdout, f"submenu battery reported failures:\n{tail}"
