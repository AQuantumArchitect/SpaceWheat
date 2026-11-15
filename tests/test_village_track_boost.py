"""Issue #126: tracking a qubit in the Village took ~11 Ace-F presses to ripen.

While a qubit is Berry-tracked and the player is in that biome, the biome's
clock runs at observation_stride × berry_track_boost (biomes.json; Village 8).
Drives tests/berry_village_ripen_probe.gd on the real game and native engine,
through the same time_skip(120)-until-ripe, 900-phrame press Ace F runs.

Measured (press lane, Village 🔥 qubit, new_game_easy):
  boost 1 (before): 11 presses, 10560 phrames, ~0.4 s per press
  boost 8 (after):   2 presses,  1320 phrames, ~0.8 s for the first press
The Ω walk is the same trajectory at every boost (−4.81 at 3600 sim phrames,
−6.61 at 10560): the boost compresses the shared clock, it does not change it.
"""
from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
PROBE = PROJECT_ROOT / "tests" / "berry_village_ripen_probe.gd"


def _press(boost: str) -> dict:
    if shutil.which("godot") is None:
        pytest.skip("godot not on PATH — cannot boot the real game")
    proc = subprocess.run(
        ["godot", "--headless", "--audio-driver", "Dummy", "--path", ".",
         "--script", str(PROBE), "--", "press", boost],
        cwd=PROJECT_ROOT, capture_output=True, text=True, timeout=300)
    tag = "VILLAGE_RIPEN "
    line = next((l for l in proc.stdout.splitlines() if l.startswith(tag)), None)
    assert line, f"probe emitted no JSON.\nstdout:\n{proc.stdout[-4000:]}\nstderr:\n{proc.stderr[-4000:]}"
    return json.loads(line[len(tag):])


@pytest.fixture(scope="module")
def after() -> dict:
    return _press("json")


@pytest.fixture(scope="module")
def before() -> dict:
    return _press("1")


def test_village_ripens_in_a_few_presses(after):
    assert after["json_boost"] == 8
    assert after["ripe"]
    assert 2 <= after["presses_to_ripe"] <= 4, after


def test_without_boost_it_was_slow(before, after):
    assert before["ripe"] and before["presses_to_ripe"] >= 10, before
    # Same loop, same clock: the boost only compresses it.
    assert abs(before["omega"] - after["omega"]) < 1e-6


def test_boost_is_scoped_to_the_tracked_biome_on_screen(after):
    assert after["stride_untracked"] == 1
    assert after["stride_tracked"] == 8
    assert after["stride_tracked_biome_left"] == 1
    assert after["stride_after_untrack"] == 1
    assert set(after["other_strides_tracked"].values()) == {1}


def test_boost_never_reaches_a_save(after):
    # Derived from the register each phrame; observation_stride (what saves
    # and the =/- dial hold) is never written.
    assert after["village_observation_stride_tracked"] == 1
    assert after["saved_stride_tracked"] == 1
