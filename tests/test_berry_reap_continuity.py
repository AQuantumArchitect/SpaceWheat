"""Collapse must cut every tracked Berry walk — pinned at the single authority.

Reap (Ace Shift+F) projectively collapses every qubit of every biome. Until the
2026-08-04 fable push it did so WITHOUT reseeding tracked Berry walks (unlike
Ace Strike, which reseeded caller-side), so the next integrate_step drew a
spherical triangle across the discontinuous Bloch jump — manufacturing solid
angle, i.e. fake ripeness, on every tracked register in the game, per Reap.

The fix moved the reseed into QuantumComputer._project_qubit itself, covering
all projective paths (Strike, Reap, MarketLattice contract exercise,
measure_axis) at one seam. The probe drives the REAL seam headless:

  with_reseed_delta — phase change across a real project_qubit + a jumped
    post-collapse packet. Must be ~0 (the packet becomes a seed, not a triangle).
  control_delta — identical walk + jump on a bare register with no reseed.
    Must be visibly nonzero, proving the test can see the failure it guards.
"""
from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
PROBE = PROJECT_ROOT / "tests" / "berry_reap_continuity_probe.gd"


@pytest.fixture(scope="module")
def probe_result() -> dict:
    if shutil.which("godot") is None:
        pytest.skip("godot not on PATH — cannot run the real QuantumComputer")
    proc = subprocess.run(["godot", "--headless", "--script", str(PROBE)],
                          cwd=PROJECT_ROOT, capture_output=True, text=True,
                          timeout=300)
    line = next((l for l in proc.stdout.splitlines()
                 if l.strip().startswith('{') and "berry-reap-continuity" in l), None)
    assert line, f"probe emitted no JSON.\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
    return json.loads(line)


def test_projection_succeeded_and_walk_was_real(probe_result):
    assert probe_result["projected"] is True
    # The arc must have accumulated real phase before the collapse, or the
    # continuity claim below would be vacuous.
    assert abs(probe_result["phase_before"]) > 0.5


def test_collapse_does_not_manufacture_solid_angle(probe_result):
    assert probe_result["with_reseed_delta"] < 1e-9, (
        "phase changed across a projective collapse — the reseed in "
        "QuantumComputer._project_qubit is not cutting the walk")


def test_control_shows_the_spurious_triangle(probe_result):
    assert probe_result["control_delta"] > 1e-3, (
        "control (no reseed) shows no spurious triangle — the probe geometry "
        "can no longer detect the failure this test guards against")
