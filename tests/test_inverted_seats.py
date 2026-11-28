"""Inverted seats (2026-11-16).

1. A word seated the other way round (B/A when B/A is not a word of its own:
   the campaign teaches 🏭/⚙, 🪵/🪓, 🩸/🦅, 📜/🏰 and starts the player on
   🌾/👥) carries the word's physics on the right atoms: its self-energies
   swap; Rabi and the atom-keyed couplings carry over. Its H is then exactly
   the word's own H with that qubit's poles relabelled (X H X), so the
   spectrum and the spectral gap equal those of the word seated its own way.
   A freshly planted inverted seat starts at the word's north (the register
   south), so it also runs the own seat's trajectory relabelled.
   Before this change the energies sat on the wrong atoms: the same matrix
   under the wrong labels, i.e. the two atoms' populations exchanged.
(The discover rule has its own file: tests/test_discover_rule.py.)

tests/inverted_seat_probe.gd builds everything headless; see its header.
"""
import json
import os
import shutil
import subprocess

import pytest

from conftest import ROOT

PROBE = "tests/inverted_seat_probe.gd"


@pytest.fixture(scope="module")
def trace(tmp_path_factory):
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    tmp = tmp_path_factory.mktemp("inverted_seat_probe")
    env = dict(os.environ, APPDATA=str(tmp), XDG_DATA_HOME=str(tmp))
    r = subprocess.run(["godot", "--headless", "--script", PROBE], cwd=ROOT, capture_output=True,
                       text=True, encoding="utf-8", timeout=300, env=env)
    out = r.stdout + r.stderr
    assert r.returncode == 0, out[-3000:]
    assert "SCRIPT ERROR" not in out, out[-3000:]
    got = {}
    for line in out.splitlines():
        for tag in ("SEAT", "VILLAGE", "LEARN"):
            if line.startswith(tag + " "):
                got[tag] = json.loads(line[len(tag) + 1:])
    assert {"SEAT", "VILLAGE"} <= set(got), out[-3000:]
    return got


def test_inverted_seat_gets_the_words_energies_on_the_right_atoms(trace):
    words = {s["seat"]: s for s in trace["SEAT"]}
    assert {k: v["word"] for k, v in words.items()} == {
        "🏭/⚙": "Factory", "🪵/🪓": "Lumber", "🩸/🦅": "Predation",
        "📜/🏰": "Heritage", "🌾/👥": "Subsistence"}
    for seat, s in words.items():
        assert s["inv_se0"] == pytest.approx(s["own_se1"]), seat
        assert s["inv_se1"] == pytest.approx(s["own_se0"]), seat
        assert s["inv_flag"] and not s["own_flag"], seat
        assert s["rabi_same"] and s["couplings_same"], seat


def test_inverted_village_seat_is_the_word_relabelled(trace):
    for row in trace["VILLAGE"]:
        assert row["relabel_err"] < 1e-12, row
        assert row["gap_inv"] == pytest.approx(row["gap_own"], abs=1e-9), row
        # ...and the matrix really is different in the register basis (the
        # old fallback gave the word's own matrix under the wrong labels).
        assert row["raw_diff"] > 1e-3, row
        # A fresh inverted seat starts at the WORD's north (register south),
        # so planted it is ρ_own relabelled too: with H relabelled, it runs the
        # own seat's trajectory (same ripening, same Berry phase).
        assert row["rho_relabel_err"] < 1e-12, row
        assert row["kick_own"] == pytest.approx(0.35)
        assert row["kick_inv"] == pytest.approx(3.141592653589793 - 0.35)
