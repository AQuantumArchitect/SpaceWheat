"""A strike after the Bell weave collapses the pair, and the bubbles show it (#90).

The Charge lesson weaves two Starter Forest plots into a Bell pair (Operator),
then the player strikes one as Ace. In Luke's playtest (2026-11-14) the strike
"did nothing" in the forest, though it had collapsed fine in the Demos.

ρ did collapse. The strike is a write to ρ outside the evolution tick, and
unlike a gate it never re-projected ρ into the viz cache the bubbles draw from.
While the clock runs, the next tick repaints them; while the world is paused
(E, the banner's "[E] more", Ace Pause) no tick comes, so the bubbles kept
showing the Bell state, both at the centre of the sphere, however many times
the player struck. ProbeActions.action_measure now projects after the collapse,
and before its Born sample, so it samples the live state.

tests/strike_after_bell_probe.gd drives it by keys in the real game, paused.
"""
import json
import os
import shutil
import subprocess

import pytest

from conftest import ROOT

PROBE = "tests/strike_after_bell_probe.gd"
TOL = 1e-6


@pytest.fixture(scope="module")
def run(tmp_path_factory):
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    tmp = tmp_path_factory.mktemp("bell_strike")
    env = dict(os.environ)
    env["APPDATA"] = str(tmp)               # Windows: user:// lives under %APPDATA%
    env["XDG_DATA_HOME"] = str(tmp)         # Linux / macOS
    env["SW_PROBE_USER_DIR_PREFIX"] = str(tmp)
    env["RIG_UNLOCK_ALL"] = "1"             # Operator is locked until the lesson opens it
    result = subprocess.run(["godot", "--headless", "--script", PROBE], cwd=ROOT,
                            capture_output=True, text=True, encoding="utf-8",
                            timeout=300, env=env)
    out = result.stdout + result.stderr
    assert result.returncode == 0, f"{PROBE} failed:\n{out[-3000:]}"
    assert "SCRIPT ERROR" not in out and "Parse Error" not in out, out[-3000:]
    rows = [json.loads(l[len("BELL_STRIKE "):]) for l in result.stdout.splitlines()
            if l.startswith("BELL_STRIKE {")]
    assert len(rows) == 1, out[-3000:]
    return rows[0]


def test_the_weave_is_a_bell_pair(run):
    bell = run["bell"]
    assert abs(bell["p00"] - 0.5) < TOL and abs(bell["p11"] - 0.5) < TOL, bell
    for q in ("a", "b"):
        assert abs(bell[q]["live_z"]) < TOL, bell   # reduced state: the centre


def test_the_strike_writes_rho_and_collapses_the_struck_qubit(run):
    assert run["paused"], "the probe strikes with the world paused"
    s = run["strike"]
    assert s["register_id"] == run["registers"][0] and s["projective_collapse"], s
    assert s["rho_written"], "the strike did not write ρ"
    assert abs(s["probability"] - 0.5) < 1e-3, "Born sample must read the live Bell state"
    p = run["after"]["a"]["p_north"]
    assert min(p, 1.0 - p) < TOL, f"struck qubit not at a pole: P(north)={p}"


def test_the_partner_answers_at_the_same_pole(run):
    after = run["after"]
    pa, pb = after["a"]["p_north"], after["b"]["p_north"]
    assert min(pb, 1.0 - pb) < TOL, f"partner not at a pole: P(north)={pb}"
    assert abs(pa - pb) < TOL, f"Φ+ answers in kind: {pa} vs {pb}"
    assert abs(after["p00"] + after["p11"] - 1.0) < TOL, after


def test_the_bubbles_show_the_collapse_while_paused(run):
    # frames: [frame, cache_z(a), live_z(a), cache_z(b), live_z(b)]
    for f, cza, lza, czb, lzb in run["frames"]:
        assert abs(cza - lza) < 1e-6 and abs(czb - lzb) < 1e-6, \
            f"frame {f}: the bubbles show z=({cza}, {czb}), ρ holds ({lza}, {lzb})"
        assert abs(abs(cza) - 1.0) < 1e-6, f"frame {f}: struck bubble not at its pole"
