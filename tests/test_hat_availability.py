"""Locked hats are hidden and their keys do nothing; keyboard and tabs share one
availability (ToolConfig.is_frame_available -> UIProgression.is_hat_active)."""
import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = ROOT / "Core" / "Quests" / "data" / "campaign_runtime.json"
TOOLS = ROOT / "Core" / "GameState" / "ToolConfig.gd"


def test_only_ace_is_ungated():
    hats = json.loads(RUNTIME.read_text(encoding="utf-8"))["unlocks"]["hats"]
    for h in ("spark", "icon", "merchant", "captain", "operator", "druid"):
        assert h in hats, f"{h} hat must be gated by a beat"
    assert "ace" not in hats


def test_keyboard_availability_reads_the_progression_table():
    src = TOOLS.read_text(encoding="utf-8")
    assert "is_hat_active" in src
    assert "every hat is always selectable" not in src


def test_battery():
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    r = subprocess.run(
        ["godot", "--headless", "--script", "tests/hat_availability_smoke.gd"],
        cwd=ROOT, capture_output=True, text=True, timeout=300,
    )
    tail = (r.stdout + r.stderr)[-3000:]
    assert r.returncode == 0, tail
    assert " 0 failed" in r.stdout, tail
