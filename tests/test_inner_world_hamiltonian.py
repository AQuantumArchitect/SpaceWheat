"""Inner (recursive / fractal) worlds carry a Hamiltonian built from their icons.

Luke's playtest (2026-11-14, #112): the recursive world opened from 🦅/🐇 was
generated well but showed no Hamiltonian. Inner worlds are closed and pure
(no Lindblad terms) and must still evolve under H assembled from the Icon
library, exactly as an outer biome gets H from its icons.

tests/inner_world_hamiltonian_probe.gd boots the real game, opens the 🦅/🐇
inner world through FractalWorldService and reports:

- INNER_H: H is non-zero and Hermitian, L is empty, the regime is closed, and
  the viz cache carries the icons' H couplings (what the field draws).
- INNER_EVO: ρ moves over 120 frames in the batcher, purity stays ≈ 1.
- OUTER_EVO: the outer biome still evolves (no regression).
- PAIR_ATOMS: a pair whose library record has no physics still gets an H,
  assembled from its atoms' physics.
- INNER_LOAD: save → drop the world → load rebuilds it from its seed with the
  identical H and the saved ρ, back in the batcher.
"""
import json
import os
import shutil
import subprocess

import pytest

from conftest import ROOT, read_source

PROBE = "tests/inner_world_hamiltonian_probe.gd"


def _godot_env(tmp):
    env = dict(os.environ)
    env["APPDATA"] = str(tmp)
    env["XDG_DATA_HOME"] = str(tmp)
    env["SW_PROBE_USER_DIR_PREFIX"] = str(tmp)
    return env


@pytest.fixture(scope="module")
def probe(tmp_path_factory):
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    tmp = tmp_path_factory.mktemp("inner_world")
    result = subprocess.run(
        ["godot", "--headless", "--audio-driver", "Dummy", "--script", PROBE],
        cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
        timeout=480, env=_godot_env(tmp))
    out = result.stdout + result.stderr
    lines = {}
    for line in out.splitlines():
        tag, _, payload = line.partition(" ")
        if tag in ("INNER_H", "INNER_EVO", "OUTER_EVO", "PAIR_ATOMS", "INNER_LOAD"):
            lines[tag] = json.loads(payload)
    assert "SCRIPT ERROR" not in out, out[-4000:]
    assert result.returncode == 0, out[-4000:]
    return lines


def test_inner_world_has_nonzero_hermitian_closed_h(probe):
    h = probe["INNER_H"]
    assert h["active"], h
    assert h["n"] == h["dim"] and h["n"] > 1, h
    assert h["max_abs"] > 1e-3, h
    assert h["herm_err"] < 1e-9, h
    assert h["lindblad"] == 0 and h["open"] is False, h


def test_inner_world_viz_cache_carries_h(probe):
    assert probe["INNER_H"]["viz_h_terms"] > 0, probe["INNER_H"]


def test_inner_world_evolves_and_stays_pure(probe):
    evo = probe["INNER_EVO"]
    assert evo["steps"] > 0, evo
    assert evo["drift"] > 1e-3, evo
    assert evo["min_purity"] > 0.999, evo
    assert evo["purity"] > 0.999, evo


def test_outer_biome_still_evolves(probe):
    evo = probe["OUTER_EVO"]
    assert evo["drift"] > 1e-3, evo


def test_physics_less_pair_gets_h_from_its_atoms(probe):
    pa = probe["PAIR_ATOMS"]
    if not pa.get("pair"):
        pytest.skip("icon library has no physics-less pair with atoms")
    assert pa["max_abs"] > 1e-3, pa
    assert pa["herm_err"] < 1e-9, pa
    assert pa["lindblad"] == 0, pa
    assert pa["purity"] > 0.999, pa


def test_inner_world_survives_save_load_with_same_h(probe):
    ld = probe["INNER_LOAD"]
    assert ld["dropped"], ld
    assert ld["rebuilt"], ld
    assert ld["same_signature"], ld
    assert ld["h_diff"] == 0.0, ld
    assert ld["rho_diff"] < 1e-9, ld
    assert ld["lindblad"] == 0, ld
    assert ld["in_batcher"], ld


def test_serializer_saves_the_seed():
    src = read_source("Core/GameState/GameStateSerializer.gd")
    assert 'state_dict["fractal_seed"]' in src
    assert "_rematerialize_fractal_worlds(farm, state.biome_states)" in src
