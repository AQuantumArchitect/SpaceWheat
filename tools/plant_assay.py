#!/usr/bin/env python3
"""plant_assay.py — Verify the Plant verb's coherent Rabi preparation.

═══════════════════════════════════════════════════════════════════════════
  WHAT PLANT CLAIMS
═══════════════════════════════════════════════════════════════════════════

Ace R ("Plant") is a steepest-ascent Rabi pulse: read the plot's reduced
Bloch vector r, rotate it fully onto the pole axis n̂ with

    U = exp(−i·α·u·σ/2),   u = (r × n̂)/|r × n̂|,   α = angle(r, n̂)

(`GateActionHandler.apply_plant`). Three claims ride on this:

    1. U is exactly unitary (the pulse is coherent control, not a channel).
    2. After the pulse the Bloch vector is r_len·n̂ — full alignment, no
       residual transverse component.
    3. Purity is untouched, so p_north caps at (1+|r|)/2 — the theorem the
       game teaches as "a fog cannot be planted". Only dissipation
       (measurement, the Spark) manufactures purity.

This assay ports the exact GDScript matrix construction (including the
element signs and the anti-parallel edge case) and checks all three claims
over a large ensemble of random mixed states, plus the guard edges.

Usage:
    python3 tools/plant_assay.py
    python3 tools/plant_assay.py --cases 50000
"""

from __future__ import annotations

import argparse
import sys

import numpy as np

SX = np.array([[0, 1], [1, 0]], complex)
SY = np.array([[0, -1j], [1j, 0]], complex)
SZ = np.array([[1, 0], [0, -1]], complex)

# Same guards as GateActionHandler
PLANT_MIN_BLOCH_R = 0.05
PLANT_ALIGNED_COS = 0.999


def plant_unitary(rx: float, ry: float, rz: float, tz: float) -> np.ndarray:
    """Port of the GDScript matrix in apply_plant, element for element."""
    r_len = np.sqrt(rx * rx + ry * ry + rz * rz)
    cos_a = np.clip((rz * tz) / r_len, -1.0, 1.0)
    alpha = np.arccos(cos_a)
    ux, uy = ry * tz, -rx * tz
    ul = np.hypot(ux, uy)
    if ul < 1e-12:
        ux, uy, ul = 1.0, 0.0, 1.0
    ux, uy = ux / ul, uy / ul
    c, s = np.cos(alpha / 2), np.sin(alpha / 2)
    return np.array([[c + 0j, -s * uy - 1j * s * ux],
                     [s * uy - 1j * s * ux, c + 0j]])


def random_rho(rng: np.random.Generator) -> np.ndarray:
    a = rng.normal(size=(2, 2)) + 1j * rng.normal(size=(2, 2))
    rho = a @ a.conj().T
    return rho / np.trace(rho).real


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--cases', type=int, default=20000)
    args = ap.parse_args()

    rng = np.random.default_rng(7)
    worst_unitary = worst_align = worst_purity = 0.0
    tested = 0
    for _ in range(args.cases):
        rho = random_rho(rng)
        rx = np.trace(rho @ SX).real
        ry = np.trace(rho @ SY).real
        rz = np.trace(rho @ SZ).real
        r_len = np.sqrt(rx * rx + ry * ry + rz * rz)
        if r_len < PLANT_MIN_BLOCH_R:
            continue  # the fog guard: apply_plant refuses these
        tz = rng.choice([1.0, -1.0])
        if np.clip(rz * tz / r_len, -1, 1) > PLANT_ALIGNED_COS:
            continue  # already planted
        tested += 1
        u = plant_unitary(rx, ry, rz, tz)
        worst_unitary = max(worst_unitary,
                            np.abs(u @ u.conj().T - np.eye(2)).max())
        rho2 = u @ rho @ u.conj().T
        worst_align = max(
            worst_align,
            abs(np.trace(rho2 @ SZ).real - tz * r_len),
            abs(np.trace(rho2 @ SX).real),
            abs(np.trace(rho2 @ SY).real))
        worst_purity = max(worst_purity,
                           abs(np.trace(rho2 @ rho2).real
                               - np.trace(rho @ rho).real))

    # Edge: pure south planted to north must land exactly on north.
    rho_s = np.diag([0.0, 1.0]).astype(complex)
    u = plant_unitary(0.0, 0.0, -1.0, 1.0)
    edge = abs((u @ rho_s @ u.conj().T)[0, 0].real - 1.0)

    # The fog-cap theorem: p_north after = (1 + r_len)/2 exactly.
    rho_m = np.array([[0.3, 0.2 + 0.1j], [0.2 - 0.1j, 0.7]])
    rx = np.trace(rho_m @ SX).real
    ry = np.trace(rho_m @ SY).real
    rz = np.trace(rho_m @ SZ).real
    r_len = np.sqrt(rx * rx + ry * ry + rz * rz)
    u = plant_unitary(rx, ry, rz, 1.0)
    cap = abs((u @ rho_m @ u.conj().T)[0, 0].real - (1 + r_len) / 2)

    tol = 1e-12
    checks = [
        ("unitarity  (‖UU†−I‖∞ over ensemble)", worst_unitary, tol),
        ("alignment  (Bloch after vs r_len·n̂)", worst_align, 1e-9),
        ("purity     (Tr ρ² drift)", worst_purity, 1e-9),
        ("anti-parallel edge (south → north)", edge, 1e-12),
        ("fog cap    (p_north = (1+|r|)/2)", cap, 1e-12),
    ]
    print(f"plant_assay — {tested} random mixed states\n")
    failed = 0
    for name, dev, bound in checks:
        ok = dev <= bound
        failed += 0 if ok else 1
        print(f"  {'PASS' if ok else 'FAIL'}  {name:<42} dev={dev:.2e}")
    print(f"\n  {'ALL CLAIMS HOLD' if failed == 0 else str(failed) + ' CLAIM(S) FAILED'}")
    return 0 if failed == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
