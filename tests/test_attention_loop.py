"""Ace's attention loop (#75): explore lights, strike banks and darkens, gather
never disturbs ρ; all dark = dormant (no evolution, no music).

tests/attention_loop_probe.gd boots a new game headless and walks the loop; the
pins below hold the one architectural rule Luke set (2026-11-14): music is
driven only by whether ρ is actually evolving. The pause button, the E peek,
dormancy and menus all halt evolution; MusicManager follows the batcher's one
signal (`evolution_running`) and reads nothing else.
"""
import json
import os
import re
import shutil
import subprocess

import pytest

from conftest import ROOT, read_source

PROBE = "tests/attention_loop_probe.gd"


@pytest.fixture(scope="module")
def checks(tmp_path_factory):
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    tmp = tmp_path_factory.mktemp("attention_probe")
    env = dict(os.environ)
    env["APPDATA"] = str(tmp)
    env["XDG_DATA_HOME"] = str(tmp)
    env["SW_PROBE_USER_DIR_PREFIX"] = str(tmp)
    # --fixed-fps 10 = one 10 Hz physics tick per frame: 600 ticks are 60 s of play.
    result = subprocess.run(
        ["godot", "--headless", "--audio-driver", "Dummy", "--fixed-fps", "10", "--script", PROBE],
        cwd=ROOT, capture_output=True, text=True, encoding="utf-8", timeout=600, env=env)
    out = result.stdout + result.stderr
    assert result.returncode == 0, out[-3000:]
    assert "SCRIPT ERROR" not in out and "Parse Error" not in out, out[-3000:]
    rows = {}
    for line in result.stdout.splitlines():
        if line.startswith("ATTN "):
            row = json.loads(line[len("ATTN "):])
            rows[row["check"]] = row
    return rows


def test_new_game_all_dark_is_dormant_and_silent(checks):
    c = checks["boot"]
    assert c["lit"] == 0 and c["dormant"] is True
    assert c["steps"] == 0 and c["rho_same"] is True, "ρ moved across 60 s with every plot dark"
    assert c["running"] is False and c["music"] is False


def test_explore_lights_and_wakes_evolution_and_music(checks):
    c = checks["explore"]
    assert c["ok"] and c["lit"] == 1
    assert c["steps"] > 0 and c["running"] is True
    assert c["music"] is True


def test_pause_button_stops_evolution_and_music_follows_evolution(checks):
    c = checks["pause"]
    assert c["paused"] is True
    assert c["steps"] == 0 and c["running"] is False
    assert c["heard"] == [False], "the batcher must report the halt itself"
    assert c["music_follows_signal"] is True
    assert c["music"] is False


def test_strike_banks_and_darkens_into_dormancy(checks):
    c = checks["strike"]
    assert c["resumed_music"] is True, "unpausing resumes evolution and with it the music"
    assert c["ok"] and sum(c["banked"].values()) > 0
    assert c["term_lit"] is False and c["lit"] == 0 and c["dormant"] is True
    assert c["steps"] == 0 and c["rho_same"] is True
    assert c["music"] is False


def test_gather_pays_the_bank_and_leaves_rho_bit_identical(checks):
    c = checks["gather"]
    assert c["ok"] and not c["noop"]
    for e, n in c["banked"].items():
        assert c["paid"].get(e, 0) == n
    assert c["rho_same"] is True
    assert c["terminal"] is False, "a dark plot returns to fog once gathered"


def test_gather_on_an_unstruck_plot_changes_nothing(checks):
    c = checks["unstruck"]
    assert c["ok"] and c["noop"]
    assert c["paid"] == {}
    assert c["rho_same"] is True and c["still_lit"] is True


def test_save_while_dormant_loads_dormant_with_the_same_rho(checks):
    c = checks["save"]
    assert c["saved"] and c["loaded"]
    assert c["dormant_before"] is True and c["dormant"] is True and c["lit"] == 0
    assert c["steps"] == 0, "a loaded dormant world must not evolve"
    # Bit-identical up to the save file's JSON float encoding (~1e-17 measured).
    assert c["rho_close"] is True
    assert c["bank_kept"] is True and c["music"] is False


# --- source pins: one cause, one effect ---------------------------------------

def test_music_reads_only_the_evolution_layer():
    src = read_source("Core/Audio/MusicManager.gd")
    code = "\n".join(l.split("#", 1)[0] for l in src.splitlines() if not l.lstrip().startswith("##"))
    assert "evolution_running.connect(" in code
    for forbidden in ("paused_changed", "PlayerShell", "player_shell", ".paused",
                      "get_lit_count", "is_attention_dormant", ".lit",
                      "terminal_bound", "terminal_released", "terminal_measured"):
        assert forbidden not in code, f"MusicManager must not read {forbidden!r}"


def test_pause_reaches_music_only_through_the_batcher():
    for rel in ("UI/PlayerShell.gd", "UI/Widgets/ClockSpeedRow.gd"):
        assert "MusicManager" not in read_source(rel), rel
    farm = read_source("Core/Farm.gd")
    assert "biome_evolution_batcher.hold_evolution()" in farm


def test_gather_never_measures():
    src = read_source("Core/Actions/ProbeActions.gd")
    assert "_auto_measure_for_pop" not in src
    body = src[src.index("static func _prepare_pop_result("):src.index("## Q on a struck plot")]
    for call in ("_project_register(", "_drain_register(", "mark_measured(", "release_register("):
        assert call not in body, call
