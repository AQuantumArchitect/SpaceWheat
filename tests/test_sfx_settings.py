"""Escape → Balance SFX volume (#143): one default, one settings file, a UI row."""
import json
import os
import shutil
import subprocess

import pytest

from conftest import ROOT, read_source


@pytest.fixture(scope="module")
def probe(tmp_path_factory):
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    tmp = tmp_path_factory.mktemp("sfx_probe")
    env = dict(os.environ, APPDATA=str(tmp), XDG_DATA_HOME=str(tmp))
    r = subprocess.run(["godot", "--headless", "--audio-driver", "Dummy", "--script",
                        "tests/sfx_settings_probe.gd"], cwd=ROOT, capture_output=True,
                       text=True, encoding="utf-8", timeout=300, env=env)
    out = r.stdout + r.stderr
    assert r.returncode == 0, out[-2000:]
    line = [l for l in out.splitlines() if l.startswith("SFXPROBE ")]
    assert line, out[-2000:]
    return json.loads(line[0][len("SFXPROBE "):])


def test_default_is_one_number_in_source():
    src = read_source("Core/Audio/SFXRegistry.gd")
    assert "var _sfx_volume: float = DEFAULT_SFX_VOLUME" in src
    assert "DEFAULT_SFX_VOLUME)" in src and "0.7)" not in src.replace("DEFAULT_SFX_VOLUME := 0.7", "")


def test_music_and_sfx_share_one_file():
    assert 'CONFIG_PATH = "user://settings.cfg"' in read_source("Core/Audio/SFXRegistry.gd")
    assert 'user://settings.cfg' in read_source("Core/Audio/MusicManager.gd")


def test_balance_lists_an_sfx_row():
    src = read_source("UI/Overlays/EscapeMenu.gd")
    assert '"kind": "sfx_pct"' in src
    assert "_SFX_ROW.duplicate(true)" in src


def test_default_consistent_at_runtime(probe):
    assert probe["default_const"] == probe["initial"] == probe["first_run"] == 0.7


def test_roundtrip_through_shared_file(probe):
    assert probe["same_file"]
    assert abs(probe["roundtrip"] - 0.4) < 1e-6
    assert abs(probe["music_kept"] - 0.2) < 1e-6


def test_legacy_file_honored_once(probe):
    assert abs(probe["migrated"] - 0.15) < 1e-6
    assert abs(probe["migrated_saved"] - 0.15) < 1e-6
    assert probe["legacy_gone"]
