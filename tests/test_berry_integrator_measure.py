"""Issue #124: fast continuous fire/ice loops never ripen. Measure the solid-angle
integrator before blaming it.

Both halves drive the REAL GDScript register headless; nothing here reimplements
BerryPhaseRegister.integrate_step.

Synthetic half (tests/berry_integrator_measure_probe.gd): Ω vs the closed form
for a great circle through both poles, constant-latitude circles at 60/120/170°,
and Luke's loop shape, each at several step sizes.

Live half (tests/berry_fire_ice_live_probe.gd): Village's 🔥/❄ qubit stepped
through the Ace-F time_skip seam on the native engine.

What the measurement says, suspect by suspect:
  (a) REAL, now fixed. A step whose arc runs through −ẑ (the apex's antipode)
      was signed by the sign of a float zero. A great circle through both poles
      (a resonant 🔥↔❄ hop) read 0, ±2π or 4π for 1–3 turns depending only on
      the sample count. It now reads exactly 2π per turn.
  (b) Real only for coarse slices: Ω degrades from ~0.5 rad per slice and
      reverses past π. Live, the 🔥 qubit turns ~0.004 rad per slice, three
      orders of magnitude short.
  (c) Not real. A dip under BERRY_EPSILON freezes the walk; it does not reset Ω.
Luke's loop is a small circle (~0.33 rad radius about −x̂). It is integrated
exactly; it encloses ~0.34 sr per turn, so 2π takes ~18 turns. Live, one Ace-F
press (900 phrames) adds |Ω| ≈ 0.77 and five reach ≈ 2.73 — short of 2π.
"""
from __future__ import annotations

import json
import math
import shutil
import subprocess
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
PROBE = PROJECT_ROOT / "tests" / "berry_integrator_measure_probe.gd"
LIVE_PROBE = PROJECT_ROOT / "tests" / "berry_fire_ice_live_probe.gd"
EXACT = 1e-9


def _run(script: Path, tag: str, extra: list[str]) -> dict:
    """Run a probe; parse the first stdout line starting with `tag` (a bare JSON
    line when tag is '{' — Godot sorts keys, so it opens with "cases")."""
    if shutil.which("godot") is None:
        pytest.skip("godot not on PATH — cannot run the real BerryPhaseRegister")
    proc = subprocess.run(["godot", "--headless", *extra, "--script", str(script)],
                          cwd=PROJECT_ROOT, capture_output=True, text=True, timeout=300)
    line = next((l for l in proc.stdout.splitlines() if l.startswith(tag)), None)
    assert line, f"probe emitted no JSON.\nstdout:\n{proc.stdout[-4000:]}\nstderr:\n{proc.stderr[-4000:]}"
    return json.loads(line if tag == "{" else line[len(tag):])


@pytest.fixture(scope="module")
def cases() -> dict:
    return _run(PROBE, "{", [])["cases"]


N_STEPS = [240, 24, 8, 4]


@pytest.mark.parametrize("n", N_STEPS)
def test_pole_crossing_great_circle_is_a_hemisphere(cases, n):
    """Suspect (a). A resonant 🔥↔❄ hop traces a great circle through both poles.
    It encloses a hemisphere at every step size; before #124 it read 0 at n=240."""
    fwd = cases[f"pole_circle_n{n}"]["omega"]
    rev = cases[f"pole_circle_rev_n{n}"]["omega"]
    three = cases[f"pole_circle_3turn_n{n}"]["omega"]
    assert abs(abs(fwd) - 2 * math.pi) < EXACT, f"n={n}: one pole-crossing turn read {fwd}"
    assert abs(fwd + rev) < EXACT, f"n={n}: reversing the loop must negate Ω ({fwd} vs {rev})"
    assert abs(three - 3 * fwd) < EXACT, f"n={n}: three windings read {three}, one read {fwd}"


def test_pole_retrace_still_cancels(cases):
    """Down a meridian through the south pole and back the same way: zero area.
    The −ẑ tie-break must flip with the step, or retraces would manufacture 4π."""
    assert abs(cases["pole_retrace"]["omega"]) < EXACT


def test_ground_state_seed_then_hop_ripens_in_one_turn(cases):
    """Seeded exactly on −ẑ (a ground state) then hopped: leaving the string counts
    0, and the return pass over it is signed, so one turn is a hemisphere."""
    assert abs(abs(cases["pole_circle_south_seed"]["omega"]) - 2 * math.pi) < EXACT


@pytest.mark.parametrize("deg", [60, 120, 170])
def test_latitude_circle_converges_to_closed_form(cases, deg):
    """Away from the string the formula is untouched. The geodesic polygon
    approaches 2π(1 − cos θ) as the steps shrink, monotonically."""
    analytic = cases[f"latitude_{deg}_n240"]["analytic_abs"]
    errs = [abs(cases[f"latitude_{deg}_n{n}"]["omega"] - analytic) for n in N_STEPS]
    assert errs[0] < 2e-3, f"{deg}°: fine-sampled Ω off by {errs[0]}"
    assert errs == sorted(errs), f"{deg}°: error does not shrink with step size: {errs}"


def test_lukes_loop_at_live_speed_is_exact(cases):
    """Luke's loop at the measured live turn rate integrates to the closed form.
    The integrator is not why it never ripened: 3 turns are worth only ~1.0 sr."""
    c = cases["luke_loop_dpsi0.011"]
    assert abs(c["omega"] - c["analytic_abs"]) < 1e-3, c
    assert c["analytic_abs"] < math.pi, "three turns of this loop are far below ripe"


def test_aliasing_needs_slices_hundreds_of_times_coarser_than_live(cases):
    """Suspect (b), measured. Ω holds within 5% at 0.5 rad per slice, loses most
    of itself by 3 rad, and reverses sign past π. The live qubit's 0.004 rad per
    slice (test_live_fire_ice_walk) is far below any of that."""
    loops = {k: v for k, v in cases.items() if k.startswith("luke_loop_")}
    ref = cases["luke_loop_dpsi0.011"]["analytic_abs"]
    assert abs(cases["luke_loop_dpsi0.500"]["omega"] - ref) / ref < 0.05
    assert cases["luke_loop_dpsi3.000"]["omega"] < 0.5 * ref
    assert cases["luke_loop_dpsi4.500"]["omega"] < 0.0, "past π per slice the loop reads reversed"
    assert len(loops) == 6


def test_decoherence_dip_freezes_but_does_not_reset(cases):
    """Suspect (c). |r| under BERRY_EPSILON for ten slices mid-loop: the walk
    holds its prev and one triangle bridges the gap. Ω is not lost."""
    c = cases["equator_with_decoherence_dip"]
    assert abs(c["omega"] - c["analytic_abs"]) < 1e-6, c


@pytest.fixture(scope="module")
def live() -> dict:
    return _run(LIVE_PROBE, "FIRE_ICE ", ["--audio-driver", "Dummy", "--path", "."])


def test_live_fire_ice_walk(live):
    """The real 🔥/❄ qubit in Village on the native engine, through Ace F's
    time_skip seam. None of the three suspects' preconditions hold: it turns
    ~0.004 rad per slice, stays nearly pure and never goes near a pole. It does
    accumulate: measured Ω ≈ −2.73 after 4500 phrames, ~0.6 per 1000."""
    assert live["max_turn"] < 0.05, live          # (b) needs ~0.5+ rad per slice
    assert live["min_r"] > 0.5, live              # (c) needs |r| < 0.05
    assert live["min_pole_dist"] > 0.5, live      # (a) needs a pass through −ẑ
    assert abs(live["omega"]) > 1.0, live         # the walk does accumulate
