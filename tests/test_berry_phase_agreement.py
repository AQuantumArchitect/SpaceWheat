"""Three implementations of the same physics must agree — nobody refereed them.

Geometric phase is computed THREE independent times across these repos, by three
different formulas, and until this file nothing tied any two of them together:

  1. SpaceWheat  Core/QuantumSubstrate/BerryPhaseRegister.gd:71 `integrate_step`
     signed solid angle Ω of the spherical triangle (ẑ, prev_b̂, cur_b̂) per slice,
     L'Huilier form. This is the one the game's physics actually runs on — story
     flags gate on it and the save file persists it.
  2. umwelt      substrate/params.py:154 `BlochGeometricPhase.update`
     dγ = −½(1 − cos θ)·dφ·|r|, accumulated incrementally. Live.
  3. umwelt      substrate/continuous_geometry.py:57 `berry_holonomy`
     Γ = +½∮(1 − cos ϑ)dφ. Note the sign: OPPOSITE to (2). Zero callers.

For a pure state (|r| = 1) the standard spin-½ relation ties all three:

        γ  =  −Ω / 2  =  −Γ

Both umwelt docstrings imply it — (2) says "one equatorial loop (Δφ = 2π) gives
−π", and (1)'s BERRY_DEFAULT_RIPE_THRESHOLD = TAU is commented "2π solid angle ≈
one hemisphere" — and neither states it as a testable claim. Two functions in the
SAME package compute this quantity with opposite signs, and no test anywhere pins
either one. That is exactly the condition under which a rendering channel can show
you a number with the wrong sign for months and every unit test stays green.

THE DISCRIMINATOR (`retrace`): a path that walks out along a meridian and back the
same way has substantial ARC LENGTH and encloses ZERO AREA. A genuine geometric
phase returns 0; anything path-length-driven (a dissipative accumulator wearing a
geometry costume) does not. This is the test that says the quantity is real.

Ω comes from running the REAL GDScript register headless (tests/berry_solid_angle_probe.gd)
— it is never reimplemented here. The Bloch paths below are the test's own INPUT;
generating an input is not duplicating an implementation.
"""
from __future__ import annotations

import json
import math
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
PROBE = PROJECT_ROOT / "tests" / "berry_solid_angle_probe.gd"
SAMPLES_PER_TURN = 240          # must match berry_solid_angle_probe.gd:N

# Cross-implementation agreement tolerance. (2) is a first-order accumulator and
# (1) is an exact spherical-triangle sum, so they differ at O(dφ²); at 240
# samples/turn that is ~1e-4. Measured, not guessed — the test prints the residual.
IDENTITY_TOL = 2e-4
ZERO_TOL = 1e-9                 # the retrace case: machine zero, not "small"


def _umwelt_src() -> Path | None:
    p = Path(os.environ.get("UMWELT_SRC") or (Path.home() / "ws" / "umwelt" / "src"))
    return p if (p / "umwelt").is_dir() else None


def _cap_path(theta: float, turns: float) -> list[tuple[float, float, float]]:
    """Circle at constant polar angle, wound `turns` times — mirrors probe `_cap`."""
    steps = int(round(SAMPLES_PER_TURN * turns))
    out = []
    for i in range(steps + 1):
        phi = 2.0 * math.pi * turns * i / steps
        out.append((math.sin(theta) * math.cos(phi),
                    math.sin(theta) * math.sin(phi),
                    math.cos(theta)))
    return out


def _retrace_path(theta: float) -> list[tuple[float, float, float]]:
    """Out along a meridian arc and back the same way — mirrors probe `_retrace`."""
    fwd = [(math.sin(theta) * math.cos(math.pi * i / SAMPLES_PER_TURN),
            math.sin(theta) * math.sin(math.pi * i / SAMPLES_PER_TURN),
            math.cos(theta))
           for i in range(SAMPLES_PER_TURN + 1)]
    return fwd + fwd[::-1]


CASES = {
    "equator_1turn": _cap_path(math.pi / 2.0, 1.0),
    "equator_2turn": _cap_path(math.pi / 2.0, 2.0),
    "cap_60deg": _cap_path(math.pi / 3.0, 1.0),
    "cap_30deg": _cap_path(math.pi / 6.0, 1.0),
    "retrace_60deg": _retrace_path(math.pi / 3.0),
}


@pytest.fixture(scope="module")
def omega() -> dict[str, float]:
    """Solid angle per case, from the REAL GDScript register run headless."""
    if shutil.which("godot") is None:
        pytest.skip("godot not on PATH — cannot run the real BerryPhaseRegister")
    proc = subprocess.run(["godot", "--headless", "--script", str(PROBE)],
                          cwd=PROJECT_ROOT, capture_output=True, text=True, timeout=300)
    line = next((l for l in proc.stdout.splitlines()
                 if l.strip().startswith('{"cases"')), None)
    assert line, f"probe emitted no JSON.\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
    data = json.loads(line)
    assert data["samples_per_turn"] == SAMPLES_PER_TURN, (
        "probe and test disagree on discretization — the comparison would be "
        "apples-to-oranges")
    return {k: float(v["omega"]) for k, v in data["cases"].items()}


@pytest.fixture(scope="module")
def umwelt_phases() -> dict[str, tuple[float, float]]:
    """(gamma, Gamma) per case from umwelt's two independent implementations."""
    src = _umwelt_src()
    if src is None:
        pytest.skip("umwelt not found — set UMWELT_SRC to run the cross-repo check")
    sys.path.insert(0, str(src))
    from umwelt.substrate.continuous_geometry import berry_holonomy
    from umwelt.substrate.params import BlochGeometricPhase

    out: dict[str, tuple[float, float]] = {}
    for name, path in CASES.items():
        bgp = BlochGeometricPhase()
        for xyz in path:
            bgp.update("q", xyz)
        # berry_holonomy wants the azimuth series and the polar series
        phis = [math.atan2(y, x) for x, y, _ in path]
        phis = _unwrap(phis)
        pols = [math.acos(max(-1.0, min(1.0, z))) for _, _, z in path]
        out[name] = (bgp.total, berry_holonomy(phis, pols))
    return out


def _unwrap(seq: list[float]) -> list[float]:
    """Continuous azimuth: berry_holonomy differences raw samples, so a 2π
    wrap would inject a spurious −2π step. BlochGeometricPhase does its own
    shortest-arc step internally (params.py:198); this gives Γ the same courtesy."""
    out = [seq[0]]
    for prev, cur in zip(seq, seq[1:]):
        d = math.atan2(math.sin(cur - prev), math.cos(cur - prev))
        out.append(out[-1] + d)
    return out


# ── the claims ────────────────────────────────────────────────────────────────

@pytest.mark.parametrize("case", list(CASES))
def test_gamma_equals_minus_half_omega(case, omega, umwelt_phases):
    """THE CROSS-REPO IDENTITY: umwelt's live Berry phase is −½ the game's solid
    angle. If this ever fails, one of the two is rendering the wrong sign or
    magnitude and every downstream instrument inherits the error."""
    gamma, _ = umwelt_phases[case]
    expected = -omega[case] / 2.0
    residual = abs(gamma - expected)
    assert residual < IDENTITY_TOL, (
        f"{case}: gamma={gamma:+.9f} but -omega/2={expected:+.9f} "
        f"(omega={omega[case]:+.9f}, residual={residual:.2e})")


@pytest.mark.parametrize("case", list(CASES))
def test_the_two_umwelt_implementations_are_exact_negatives(case, umwelt_phases):
    """substrate/params.py and substrate/continuous_geometry.py compute the same
    physical quantity with OPPOSITE sign conventions. That is legal, and it is a
    trap: berry_holonomy has zero callers today, so the day someone wires it in
    believing it agrees with the live one, the sign silently flips. Pin it."""
    gamma, big_gamma = umwelt_phases[case]
    residual = abs(gamma + big_gamma)
    assert residual < IDENTITY_TOL, (
        f"{case}: gamma={gamma:+.9f}, Gamma={big_gamma:+.9f} — expected exact "
        f"negatives, residual={residual:.2e}")


def test_equatorial_loop_is_minus_pi(umwelt_phases, omega):
    """The canonical anchor both docstrings name: one equatorial winding is a
    hemisphere (Ω = 2π) and gives γ = −π, so a spinor needs 4π to come home."""
    gamma, _ = umwelt_phases["equator_1turn"]
    assert abs(omega["equator_1turn"] - 2.0 * math.pi) < 1e-9
    assert abs(gamma + math.pi) < IDENTITY_TOL


def test_winding_is_linear(omega):
    """Two windings enclose twice the solid angle. A quantity that saturates or
    drifts here is an accumulator, not a geometric phase."""
    assert abs(omega["equator_2turn"] - 2.0 * omega["equator_1turn"]) < 1e-9


@pytest.mark.parametrize("case,theta", [("cap_60deg", math.pi / 3.0),
                                        ("cap_30deg", math.pi / 6.0)])
def test_cap_matches_closed_form(case, theta, omega):
    """Ω = 2π(1 − cos ϑ) for a polar cap — the closed form, independent of both
    codebases. This is the one leg of the triangle that needs no implementation
    to be trusted."""
    expected = 2.0 * math.pi * (1.0 - math.cos(theta))
    assert abs(omega[case] - expected) < 1e-3, (
        f"{case}: omega={omega[case]:.9f} vs closed form {expected:.9f}")


def test_zero_area_path_yields_zero_phase(omega, umwelt_phases):
    """THE DISCRIMINATOR. Out along a meridian and back the same way: long arc,
    zero enclosed area. Both implementations must return ZERO — not "small".
    A path-length-driven accumulator wearing a geometry costume fails here, and
    this is the only test in either repo that could have caught that."""
    gamma, big_gamma = umwelt_phases["retrace_60deg"]
    assert abs(omega["retrace_60deg"]) < ZERO_TOL, (
        f"game register accumulated {omega['retrace_60deg']:.3e} over a path "
        f"enclosing no area — it is tracking path length, not geometry")
    assert abs(gamma) < ZERO_TOL, f"umwelt gamma={gamma:.3e} on a zero-area path"
    assert abs(big_gamma) < ZERO_TOL, f"umwelt Gamma={big_gamma:.3e} on a zero-area path"


# THE NAME COLLISION LAW (2026-08-02). Before this file existed, three OTHER things in
# this repo were also named "berry_phase": QuantumNode.berry_phase (= coh_magnitude*TAU,
# an overwrite mislabeled "accumulated" with zero readers), DualEmojiQubit.berry_phase
# (a real += accumulator, clamped 0..10, also zero callers — a dissipative accumulator
# wearing the geometric-phase name for real, not just in a docstring), and a stale
# QuantumForceGraph.gd doc comment claiming a glow/pulse channel neither ever fed. All
# three were deleted 2026-08-02 SPECIFICALLY BECAUSE the name collision is dangerous: a
# reader (or an instrument) grepping "berry_phase" cannot tell a real geometric quantity
# from a same-named impostor without reading the formula. This test is the tripwire so a
# fourth impostor can't quietly grow back next to the real one.
_LIVE_BERRY_PHASE_HOMES = {
    PROJECT_ROOT / "Core" / "QuantumSubstrate" / "BerryPhaseRegister.gd",  # the real one
}
# Declarations only (var/func), so prose mentions (GameState.gd's persistence-schema
# comment, this very doc comment on QuantumForceGraph.gd) don't trip it — and the exact
# identifier `berry_phase`, so FarmPlot.berry_phase_bonus (a real, unrelated, flat yield
# constant) doesn't either. What it DOES catch: a new field or getter that revives the name.
_DECL_RE = re.compile(r"\b(?:var|func)\s+\w*berry_phase\b")


def test_no_impostor_berry_phase_fields_regrow():
    """Every GDScript declaration of `berry_phase` (as a var or in a func name) must live
    in a known real-physics home. A new one anywhere else means someone reinvented the
    2026-08-02 collision: three same-named impostors (an overwrite mislabeled
    "accumulated", a real += accumulator with zero callers, a stale doc comment) sharing a
    grep result with the one quantity this repo actually trusts."""
    hits = []
    for path in (PROJECT_ROOT / "Core").rglob("*.gd"):
        if path in _LIVE_BERRY_PHASE_HOMES:
            continue
        if _DECL_RE.search(path.read_text(encoding="utf-8")):
            hits.append(str(path.relative_to(PROJECT_ROOT)))
    assert not hits, (
        f"berry_phase declared outside its known home: {hits} — either it's a real "
        f"geometric-phase computation (add it to test_berry_phase_agreement.py's cross-"
        f"check and _LIVE_BERRY_PHASE_HOMES) or it's an impostor (rename it before it "
        f"confuses the next reader)")
