"""Display mode toggle (#150): persisted in the shared settings file, applied on boot."""
import json
import os
import shutil
import subprocess

import pytest

from conftest import ROOT, read_source

PROBE = "tests/display_settings_probe.gd"


@pytest.fixture(scope="module")
def checks(tmp_path_factory):
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    tmp = tmp_path_factory.mktemp("display_probe")
    env = dict(os.environ, APPDATA=str(tmp), XDG_DATA_HOME=str(tmp), SW_PROBE_USER_DIR_PREFIX=str(tmp))
    result = subprocess.run(
        ["godot", "--headless", "--audio-driver", "Dummy", "--script", PROBE],
        cwd=ROOT, capture_output=True, text=True, encoding="utf-8", timeout=120, env=env)
    out = result.stdout + result.stderr
    assert result.returncode == 0, out[-3000:]
    assert "SCRIPT ERROR" not in out and "Parse Error" not in out, out[-3000:]
    rows = {}
    for line in result.stdout.splitlines():
        if line.startswith("DISP "):
            row = json.loads(line[len("DISP "):])
            rows[row["check"]] = row
    return rows


def test_default_is_windowed(checks):
    assert checks["default"] == {"check": "default", "mode": "windowed", "fullscreen": False}


def test_set_applies_and_toggle_round_trips(checks):
    assert checks["set"]["applied"] == ["fullscreen"] and checks["set"]["live"] == "fullscreen"
    assert checks["toggle"]["applied"] == ["fullscreen", "windowed", "fullscreen"]


def test_saved_mode_is_restored_and_audio_key_survives(checks):
    r = checks["reload"]
    assert r["stored"] == "fullscreen"
    assert r["applied"] == ["fullscreen"]
    assert r["music"] == pytest.approx(0.7)


def test_unknown_stored_value_falls_back_to_windowed(checks):
    assert checks["garbage"]["mode"] == "windowed"


def test_wiring():
    assert "DisplaySettings=" in read_source("project.godot")
    menu = read_source("UI/Overlays/EscapeMenu.gd")
    assert "display_mode" in menu and "set_fullscreen" in menu
    assert "KEY_F11" in read_source("Core/Settings/DisplaySettings.gd")
