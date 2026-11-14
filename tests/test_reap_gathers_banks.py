"""Behavioral: banks on several plots, Reap's sweep pays all and clears all (#91)."""
import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
PROBE = ROOT / "tests" / "reap_gathers_banks_probe.gd"


def test_banks_on_several_plots_are_paid_and_cleared():
    if shutil.which("godot") is None:
        pytest.skip("godot not on PATH")
    proc = subprocess.run(["godot", "--headless", "--script", str(PROBE)], cwd=ROOT,
                          capture_output=True, text=True, timeout=300)
    line = next((l for l in proc.stdout.splitlines() if "reap-gathers-banks" in l), None)
    assert line, proc.stdout + proc.stderr
    r = json.loads(line)
    assert r["paid"] == {"🌱": 5, "🍄": 5, "🌾": 7}
    assert r["gathered"] == r["paid"]
    assert r["left"] == 0
