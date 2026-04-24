#!/usr/bin/env python3
"""clock_assay.py — Scan SpaceWheat biomes for persistent currents (chiral clocks).

═══════════════════════════════════════════════════════════════════════════
  WHAT IS A PERSISTENT CURRENT?
═══════════════════════════════════════════════════════════════════════════

Consider three sites A, B, C on a loop. Each edge carries a complex
Hamiltonian amplitude:

    H_AB = |H_AB| · e^{iα}
    H_BC = |H_BC| · e^{iβ}
    H_CA = |H_CA| · e^{iγ}

The LOOP PHASE is Φ = α + β + γ — the total phase you accumulate going
once around the cycle. This number is the discrete analogue of the
magnetic flux through the ring. Crucially:

    Φ = 0  or  π   →  time-reversal symmetric, no current, achiral
    Φ = π/2        →  time-reversal BROKEN, maximum persistent current

When Φ ≠ 0, π, the GROUND STATE of H is no longer real-valued. Amplitude
flows preferentially in one direction around the ring — and keeps flowing
forever, even though no drive and no energy is put in. This is a
PERSISTENT CURRENT. Every real atom in a ring-shaped magnetic field
does this. Every superconducting ring threaded by flux does this.

In the game, a biome containing a chiral triangle HAS A BUILT-IN CLOCK:
population circulates around the triangle at a rate set by the coupling
magnitudes, in a direction set by the sign of Im(H). Other circuits can
read off this clock by coupling to one of its sites.

═══════════════════════════════════════════════════════════════════════════
  THE METRIC
═══════════════════════════════════════════════════════════════════════════

For each triangle (A, B, C) with non-trivial couplings on all three
edges we compute:

    1.  Loop phase   Φ = arg(H_AB) + arg(H_BC) + arg(H_CA)
        (computed in the oriented cycle A→B→C→A).

    2.  Ground state |ψ_0⟩ of the 3×3 Hermitian H restricted to the
        triangle.

    3.  Persistent current around the loop.
        For a pure state the edge-current from j to i is
            J_ij = 2 Im(H_ij · ψ_j* · ψ_i)
        and the loop current is the sum around the cycle.

A biome is a CLOCK when max_triangle |J_loop| is large.

Normalization: for a ring with all |H_ij| = M and loop phase π/2, the
exact ground-state current is M · √3/2 · normalization. We report both
the raw current and a normalized "chirality" = |J_loop| / M_avg.

═══════════════════════════════════════════════════════════════════════════

Usage:
    python3 tools/clock_assay.py
    python3 tools/clock_assay.py --top 10
    python3 tools/clock_assay.py --biome WheelOfHours
"""

from __future__ import annotations

import argparse
import math
import sys
from itertools import combinations
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from biome_audit import (  # noqa: E402
    load_factions,
    load_biomes,
    compute_frobenius_norms,
    compute_faction_baselines,
)


# ── Edge-amplitude lookup ───────────────────────────────────────────────────

def edge_amplitude(a: str, b: str, cre: dict, cim: dict) -> complex:
    """Return H_ab (Hilbert-space matrix element), halving biome_audit's
    double-counted sum-over-both-directions convention."""
    key = tuple(sorted([a, b]))
    re = cre.get(key, 0.0) * 0.5
    im = cim.get(key, 0.0) * 0.5
    # Sign of imag depends on orientation
    if (a, b) == key:
        return complex(re, im)
    else:
        return complex(re, -im)


# ── Triangle analysis ───────────────────────────────────────────────────────

def analyze_triangle(A: str, B: str, C: str,
                     se: dict, cre: dict, cim: dict) -> dict | None:
    """Build 3×3 H on the triangle, compute loop phase and ground-state
    persistent current. Returns None if any edge is too weak."""
    # Edges in the cyclic direction A→B→C→A
    g_ab = edge_amplitude(A, B, cre, cim)
    g_bc = edge_amplitude(B, C, cre, cim)
    g_ca = edge_amplitude(C, A, cre, cim)

    mags = [abs(g_ab), abs(g_bc), abs(g_ca)]
    if min(mags) < 0.05:
        return None

    # Build 3×3 Hermitian H on ordered basis [A, B, C]
    H = np.zeros((3, 3), dtype=complex)
    for i, e in enumerate([A, B, C]):
        H[i, i] = se.get(e, 0.0)
    H[0, 1] = g_ab; H[1, 0] = np.conj(g_ab)
    H[1, 2] = g_bc; H[2, 1] = np.conj(g_bc)
    H[2, 0] = g_ca; H[0, 2] = np.conj(g_ca)

    # Loop phase
    phi = math.atan2(g_ab.imag, g_ab.real) \
        + math.atan2(g_bc.imag, g_bc.real) \
        + math.atan2(g_ca.imag, g_ca.real)
    # Fold into (-π, π]
    phi = ((phi + math.pi) % (2 * math.pi)) - math.pi

    # Ground state
    w, V = np.linalg.eigh(H)
    psi0 = V[:, 0]
    # Edge current J_ji = 2 Im( H_ji · ψ_j* · ψ_i ).  We want the current
    # flowing AROUND A→B→C→A. Current across (A→B) is
    #   J_A→B = 2 Im( H_BA · ψ_A · conj(ψ_B) ) = 2 Im( conj(g_ab) · ψ_A · conj(ψ_B) )
    def edge_current(g: complex, a_amp: complex, b_amp: complex) -> float:
        return 2.0 * (np.conj(g) * a_amp * np.conj(b_amp)).imag

    j_ab = edge_current(g_ab, psi0[0], psi0[1])
    j_bc = edge_current(g_bc, psi0[1], psi0[2])
    j_ca = edge_current(g_ca, psi0[2], psi0[0])
    # In steady state they should all be equal; use the average as "loop current"
    j_loop = (j_ab + j_bc + j_ca) / 3.0

    m_avg = sum(mags) / 3.0
    chirality = abs(j_loop) / m_avg if m_avg > 1e-9 else 0.0

    return {
        'triangle': (A, B, C),
        'loop_phase_over_pi': phi / math.pi,
        'edge_mag_avg': m_avg,
        'j_loop': j_loop,
        'chirality': chirality,
        'ground_energy': float(w[0]),
    }


def enumerate_triangles(emojis: list[str], cre: dict, cim: dict) -> list[tuple]:
    """All triples (A,B,C) where every pair has an edge above threshold."""
    out = []
    for A, B, C in combinations(emojis, 3):
        mags = [
            math.hypot(cre.get(tuple(sorted([A, B])), 0.0), cim.get(tuple(sorted([A, B])), 0.0)),
            math.hypot(cre.get(tuple(sorted([B, C])), 0.0), cim.get(tuple(sorted([B, C])), 0.0)),
            math.hypot(cre.get(tuple(sorted([C, A])), 0.0), cim.get(tuple(sorted([C, A])), 0.0)),
        ]
        if min(mags) * 0.5 > 0.05:
            out.append((A, B, C))
    return out


# ── Biome assay ─────────────────────────────────────────────────────────────

def assay_biome(biome: dict, factions: list[dict]) -> dict:
    emojis = biome['emojis']
    if len(emojis) < 3:
        return {'name': biome['name'], 'j_loop': 0.0, 'note': 'too-small'}

    norms = compute_frobenius_norms(factions, emojis)
    se, cre, cim, _ = compute_faction_baselines(factions, emojis, norms)

    tris = enumerate_triangles(emojis, cre, cim)
    if not tris:
        return {'name': biome['name'], 'j_loop': 0.0, 'note': 'no-triangles'}

    best = None
    for (A, B, C) in tris:
        # Try both orientations since the cyclic direction matters for J
        for order in [(A, B, C), (A, C, B)]:
            r = analyze_triangle(*order, se=se, cre=cre, cim=cim)
            if r is None:
                continue
            if best is None or abs(r['j_loop']) > abs(best['j_loop']):
                best = r

    if best is None:
        return {'name': biome['name'], 'j_loop': 0.0, 'note': 'no-strong-triangle'}

    return {'name': biome['name'], **best, 'note': ''}


def print_detail(r: dict) -> None:
    print(f"\n── {r['name']} ──")
    if r.get('note'):
        print(f"  (skipped: {r['note']})")
        return
    A, B, C = r['triangle']
    print(f"  triangle:       {A} → {B} → {C} → {A}")
    print(f"  avg edge |H|:   {r['edge_mag_avg']:.3f}")
    print(f"  loop phase:     Φ = {r['loop_phase_over_pi']:+.3f}·π")
    print(f"                    (|Φ| = π/2 → maximum current)")
    print(f"  ground energy:  {r['ground_energy']:+.4f}")
    print(f"  persistent current:")
    print(f"     J_loop = {r['j_loop']:+.4f}   (sign = direction of circulation)")
    print(f"     chirality = |J|/|H| = {r['chirality']:.3f}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--top', type=int, default=10)
    ap.add_argument('--biome', type=str, default=None)
    ap.add_argument('--threshold', type=float, default=0.2)
    args = ap.parse_args()

    factions = load_factions()
    biomes = load_biomes()

    if args.biome:
        m = [b for b in biomes if b['name'] == args.biome]
        if not m:
            print(f'No such biome: {args.biome}')
            return 1
        print_detail(assay_biome(m[0], factions))
        return 0

    results = [assay_biome(b, factions) for b in biomes
               if b.get('name') != '_orphan_lindblads']
    ok = [r for r in results if not r.get('note')]
    ok.sort(key=lambda r: r['chirality'], reverse=True)

    print('─' * 82)
    print(' PERSISTENT-CURRENT ASSAY — ground-state circulation in chiral triangles')
    print('─' * 82)
    print(f"{'rank':>4}  {'chir':>5}  {'|J|':>6}  {'Φ/π':>6}  {'|H|':>5}  biome              triangle")
    for i, r in enumerate(ok[:args.top], 1):
        A, B, C = r['triangle']
        tri = f'{A}→{B}→{C}'
        print(f"  {i:>2}  {r['chirality']:>5.2f}  {abs(r['j_loop']):>6.3f}  "
              f"{r['loop_phase_over_pi']:+6.3f}  {r['edge_mag_avg']:>5.2f}  "
              f"{r['name']:<18} {tri}")
    n = sum(1 for r in ok if r['chirality'] >= args.threshold)
    print(f"\n  {n} biome(s) clear the chirality threshold ({args.threshold}).")
    return 0


if __name__ == '__main__':
    sys.exit(main())
