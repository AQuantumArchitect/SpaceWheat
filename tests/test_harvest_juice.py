"""Harvest loop juice (#60): Gather is the payoff, planting and ripening whisper.

Gather (pop) gets an orb squash-and-stretch, the Pop-Harvest badge, a spark
burst, the "+N" flier to the resource counter and a layered sound (thump,
sparkle, rare bell) whose pitch climbs on quick chains. Size is the payout's
surprisal, so rarer harvests land bigger. Planting and a fresh ripening get a
quiet ring and a soft cue. Every knob lives in Core/Audio/FeedbackTuning.gd,
with the player's intensity and reduced-motion settings, persisted.

tests/harvest_juice_probe.gd boots the real game headless; see its header.
"""
import json
import os
import re
import shutil
import subprocess

import pytest

from conftest import ROOT

PROBE = "tests/harvest_juice_probe.gd"
TUNING = ROOT / "Core" / "Audio" / "FeedbackTuning.gd"
SFX = ROOT / "Core" / "Audio" / "SFXRegistry.gd"
LAYER = ROOT / "UI" / "Widgets" / "FloatingRewardLayer.gd"
SFX_DIR = ROOT / "Assets" / "Audio" / "SFX"
NEW_SOUNDS = ["harvest_sparkle", "harvest_rare", "plant_soft", "ripe_ready"]


def _src(p):
    return p.read_text(encoding="utf-8")


# ── static: one home for the feel knobs ─────────────────────────────────────

def test_new_sounds_are_generated_and_registered():
    gen = _src(SFX_DIR / "generate_sfx.py")
    sfx = _src(SFX)
    for sid in NEW_SOUNDS:
        assert (SFX_DIR / f"{sid}.wav").is_file(), sid
        assert f'"{sid}": gen_{sid}' in gen, sid
        assert f'"{sid}"' in sfx, sid


def test_feel_knobs_live_in_feedback_tuning():
    # The combo ladder and the big-pop threshold moved out of their old homes.
    sfx, layer = _src(SFX), _src(LAYER)
    for old in ["_POP_CHAIN_WINDOW_MS", "_PENTATONIC_SEMITONES"]:
        assert old not in sfx, old
    for old in ["const BIG_POP_REL", "const HITSTOP_S", "const MUSIC_DUCK_DB",
                "const FRACTAL_FLASH_PEAK"]:
        assert old not in layer, old
    tuning = _src(TUNING)
    for knob in ["COMBO_WINDOW_MS", "COMBO_SEMITONES", "BIG_POP_REL", "HITSTOP_S",
                 "PARTICLES_BASE", "PUNCH_BASE", "RIPE_PULSE_PERIOD_S", "BADGE_PATH"]:
        assert re.search(r"^const %s\b" % knob, tuning, re.M), knob


def test_gather_size_reads_the_payout_not_a_missing_key():
    # Gather's result has `banked` and `amount`, never `credits`.
    sfx, layer = _src(SFX), _src(LAYER)
    assert 'result.get("credits", 0)' not in sfx
    assert "FeedbackTuning.harvest_size(result)" in sfx
    assert "FeedbackTuning.harvest_size(result)" in layer


def test_both_renderers_take_a_punch():
    for rel in ["Core/Visualization/QuantumField3D.gd", "Core/Visualization/QuantumForceGraph.gd"]:
        assert "func punch_register(" in _src(ROOT / rel), rel


def test_settings_rows_in_the_escape_menu():
    menu = _src(ROOT / "UI" / "Overlays" / "EscapeMenu.gd")
    assert '"kind": "feedback_pct"' in menu
    assert '"kind": "toggle_motion"' in menu
    assert "FeedbackTuning.set_intensity(" in menu
    assert "FeedbackTuning.set_reduced_motion(" in menu


# ── live: the real game, headless ───────────────────────────────────────────

@pytest.fixture(scope="module")
def phases(tmp_path_factory):
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    tmp = tmp_path_factory.mktemp("harvest_juice_probe")
    env = dict(os.environ)
    env.update({"APPDATA": str(tmp), "XDG_DATA_HOME": str(tmp),
                "SW_PROBE_USER_DIR_PREFIX": str(tmp), "RIG_UNLOCK_ALL": "1"})
    result = subprocess.run(["godot", "--headless", "--script", PROBE], cwd=ROOT,
                            capture_output=True, text=True, encoding="utf-8",
                            timeout=400, env=env)
    out = result.stdout + result.stderr
    assert result.returncode == 0, f"{PROBE} failed:\n{out[-3000:]}"
    assert "SCRIPT ERROR" not in out and "Parse Error" not in out, out[-3000:]
    rows = [json.loads(l[len("JUICE_TRACE "):]) for l in result.stdout.splitlines()
            if l.startswith("JUICE_TRACE ")]
    return {r["phase"]: r for r in rows}


def test_settings_persist_beside_the_audio_volume(phases):
    s = phases["settings"]
    assert s["intensity"] == 0.5 and s["file_intensity"] == 0.5, s
    assert s["reduced_motion"] and s["file_reduced"], s
    assert s["motion"] == 0.0, s
    assert s["file_sfx_volume"] == pytest.approx(0.4), s  # the audio key survived


def test_quick_gathers_climb_and_a_pause_resets(phases):
    # Gaps of half a window climb; a gap of three windows drops back to the root.
    assert phases["ladder"]["steps"] == [0, 1, 2, 3, 0, 1], phases["ladder"]


def test_rare_harvests_feel_bigger(phases):
    sc = phases["scale"]
    assert sc["routine"]["badges"] == 1 and sc["rare"]["badges"] == 1, sc
    assert sc["rare"]["sparks"] > sc["routine"]["sparks"], sc
    assert sc["rare_time_scale"] < 1.0, sc          # the rare hitstop
    assert sc["restored_time_scale"] == 1.0, sc     # and it lets go


def test_reduced_motion_and_off_are_still(phases):
    sc = phases["scale"]
    for key in ["reduced", "off"]:
        assert sc[key] == {"badges": 0, "bursts": 0, "sparks": 0}, (key, sc)
    assert sc["reduced_time_scale"] == 1.0, sc


def test_a_real_gather_celebrates_and_thumps(phases):
    lp = phases["loop"]
    assert lp["popped"], lp
    assert lp["size"] > 0, lp
    assert lp["juice"]["badges"] == 1 and lp["juice"]["sparks"] > 0, lp
    assert "pop_success.wav" in lp["streams"], lp


def test_ripening_chimes_once_and_arrival_is_silent(phases):
    r = phases["ripe"]
    assert r["has_register"], r
    assert r["rows"]["primed_streams"] == [], r
    assert r["rows"]["fresh_streams"] == ["ripe_ready.wav"], r
    assert r["rows"]["watching"] == 2, r
