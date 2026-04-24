#!/usr/bin/env python3
"""ssh_assay.py — Scan SpaceWheat biomes for topological edge modes.

═══════════════════════════════════════════════════════════════════════════
  WHAT IS AN EDGE MODE?
═══════════════════════════════════════════════════════════════════════════

Consider a chain of sites with only nearest-neighbor couplings:

    ● ── t₁ ── ● ── t₂ ── ● ── t₁ ── ● ── t₂ ── ●
    0          1          2          3          4

If the hops alternate (t₁ weak, t₂ strong, t₁ weak, t₂ strong, …), the
chain has a sublattice symmetry: even sites only couple to odd sites and
vice-versa. We say it is BIPARTITE. Such a Hamiltonian has a hidden
structural property called CHIRAL SYMMETRY — for every eigenstate at
energy +E there is a partner at energy −E.

Now count: 5 sites, 3 of one sublattice (0, 2, 4) and 2 of the other
(1, 3). The chiral symmetry forces there to exist AT LEAST ONE eigenstate
at exactly zero energy, and that eigenstate has amplitude ONLY on the
larger sublattice.

Even more specifically, if the chain STARTS with a WEAK bond, that zero
mode is exponentially localized at the starting end:

    |ψ₀⟩ ∝  |0⟩  −  (t₁/t₂)|2⟩  +  (t₁/t₂)²|4⟩

The edge is a prison. Any population that sits in |ψ₀⟩ cannot decay
through couplings — it has to go to one of the ± partners, and the
partners are at finite energy. The state is TOPOLOGICALLY PROTECTED:
the protection is not about any specific number but about the integer
"how many weak-strong domain walls does the chain have from this end."

This is the SSH (Su-Schrieffer-Heeger) model — the simplest topological
insulator. Real graphene nanoribbons, polyacetylene molecules, and
photonic lattices all implement it.

═══════════════════════════════════════════════════════════════════════════
  WHAT DOES A TOPOLOGICAL BIOME LOOK LIKE?
═══════════════════════════════════════════════════════════════════════════

A biome hosts an edge mode when:

    1. its coupling graph has a *chain-like* backbone (some nodes of
       degree 1, a path through the middle),
    2. the couplings along that path alternate (ideally weak-strong-
       weak-strong),
    3. self-energies are small and roughly uniform (so the chiral
       symmetry is preserved).

When those hold, diagonalizing the biome's Hamiltonian produces at least
one eigenstate that is (a) near zero energy and (b) sharply localized
on a single site at the boundary.

═══════════════════════════════════════════════════════════════════════════
  THE METRIC
═══════════════════════════════════════════════════════════════════════════

We define the INVERSE PARTICIPATION RATIO (IPR) of an eigenstate |ψ⟩:

    IPR(ψ) = Σᵢ |ψᵢ|⁴

A state uniformly delocalized over N sites has IPR = 1/N. A state
concentrated on one site has IPR = 1. So IPR is the reciprocal of the
effective number of sites the state touches.

For each biome we:

    1.  Build its full Hamiltonian (from faction contributions only).
    2.  Diagonalize.
    3.  For every eigenstate, compute IPR and the energy E.
    4.  Pick the eigenstate with the highest IPR  — most localized.
    5.  Also note its dominant site and the degree of that site in the
        coupling graph.

Edge-mode score:

    edge_score = IPR · |degree_dominant ≤ 1|  · exp(−5·|E|)

A high score means "a state localized on a degree-1 boundary node, with
energy close to zero." That's a topological edge mode.

═══════════════════════════════════════════════════════════════════════════

Usage:
    python3 tools/ssh_assay.py                    # rank biomes
    python3 tools/ssh_assay.py --top 10
    python3 tools/ssh_assay.py --biome Lanternfall
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from biome_audit import (  # noqa: E402
    load_factions,
    load_biomes,
    compute_frobenius_norms,
    compute_faction_baselines,
)


def build_biome_hamiltonian(
    emojis: list[str], se: dict, cre: dict, cim: dict,
) -> np.ndarray:
    """Build the full N×N Hermitian Hamiltonian on the biome's emoji basis."""
    N = len(emojis)
    H = np.zeros((N, N), dtype=complex)
    for i, e in enumerate(emojis):
        H[i, i] = se.get(e, 0.0)
    for i in range(N):
        for j in range(i + 1, N):
            a, b = emojis[i], emojis[j]
            key = tuple(sorted([a, b]))
            re = cre.get(key, 0.0)
            im = cim.get(key, 0.0)
            g = complex(re, im) if (a, b) == key else complex(re, -im)
            H[i, j] = g
            H[j, i] = np.conj(g)
    return H


def ipr(psi: np.ndarray) -> float:
    """Inverse participation ratio Σᵢ|ψᵢ|⁴. 1/N = uniform, 1 = delta."""
    p = np.abs(psi) ** 2
    return float(np.sum(p ** 2))


def degrees(emojis: list[str], cre: dict, cim: dict, threshold: float = 0.05) -> dict:
    """Coupling-graph degree per emoji (edges above threshold)."""
    deg = {e: 0 for e in emojis}
    for i in range(len(emojis)):
        for j in range(i + 1, len(emojis)):
            a, b = emojis[i], emojis[j]
            key = tuple(sorted([a, b]))
            mag = math.hypot(cre.get(key, 0.0), cim.get(key, 0.0))
            if mag > threshold:
                deg[a] += 1
                deg[b] += 1
    return deg


def assay_biome(biome: dict, factions: list[dict]) -> dict:
    emojis = biome['emojis']
    if len(emojis) < 3:
        return {'name': biome['name'], 'edge_score': 0.0, 'note': 'too-small'}

    norms = compute_frobenius_norms(factions, emojis)
    se, cre, cim, _ = compute_faction_baselines(factions, emojis, norms)
    H = build_biome_hamiltonian(emojis, se, cre, cim)
    w, V = np.linalg.eigh(H)

    deg = degrees(emojis, cre, cim)

    best = None  # (edge_score, idx, ipr_val, dominant_site)
    for k in range(len(emojis)):
        psi = V[:, k]
        ipr_val = ipr(psi)
        dominant = int(np.argmax(np.abs(psi) ** 2))
        dominant_emoji = emojis[dominant]
        dominant_deg = deg[dominant_emoji]
        # boundary factor: degree-1 is a true edge of a connected chain;
        # degree-0 is a disconnected orphan (trivial zero mode, not interesting).
        boundary = 1.0 if dominant_deg == 1 else 0.0
        E = float(w[k])
        energy_factor = math.exp(-5.0 * abs(E))
        score = ipr_val * boundary * energy_factor
        if best is None or score > best[0]:
            best = (score, k, ipr_val, dominant_emoji, dominant_deg, E, psi)

    (edge_score, k, ipr_val, dom_e, dom_d, E, psi) = best
    amps = np.abs(psi) ** 2
    # Amplitude profile: emoji -> population
    profile = [(emojis[i], float(amps[i])) for i in range(len(emojis))]
    profile.sort(key=lambda t: -t[1])

    return {
        'name': biome['name'],
        'edge_score': edge_score,
        'ipr': ipr_val,
        'energy': E,
        'dominant': dom_e,
        'dominant_deg': dom_d,
        'profile': profile,
        'n_sites': len(emojis),
        'note': '',
    }


def print_detail(r: dict) -> None:
    print(f"\n── {r['name']} ──")
    if r.get('note'):
        print(f"  (skipped: {r['note']})")
        return
    print(f"  sites:             {r['n_sites']}")
    print(f"  most-localized eigenstate:")
    print(f"    energy  E = {r['energy']:+.4f}     (0 = perfect chiral zero mode)")
    print(f"    IPR       = {r['ipr']:.3f}          (1/N={1/r['n_sites']:.3f} uniform … 1 = delta)")
    print(f"    dominant  = {r['dominant']}  (degree {r['dominant_deg']} in coupling graph)")
    print(f"  population profile:")
    for e, p in r['profile']:
        bar = '█' * int(p * 40)
        print(f"    {e}  {p:.3f}  {bar}")
    print(f"  edge_score = {r['edge_score']:.3f}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--top', type=int, default=10)
    ap.add_argument('--biome', type=str, default=None)
    ap.add_argument('--threshold', type=float, default=0.4)
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

    results = [assay_biome(b, factions) for b in biomes]
    ok = [r for r in results if not r.get('note')]
    ok.sort(key=lambda r: r['edge_score'], reverse=True)

    print('─' * 78)
    print(' SSH EDGE-MODE ASSAY')
    print('─' * 78)
    print(f"{'rank':>4}  {'score':>6}  {'IPR':>5}  {'|E|':>6}  {'deg':>3}  biome              dominant")
    for i, r in enumerate(ok[:args.top], 1):
        print(f"  {i:>2}  {r['edge_score']:>6.3f}  {r['ipr']:>5.2f}  {abs(r['energy']):>6.3f}  "
              f"{r['dominant_deg']:>3}  {r['name']:<18} {r['dominant']}")
    n = sum(1 for r in ok if r['edge_score'] >= args.threshold)
    print(f"\n  {n} biome(s) clear the edge-mode threshold ({args.threshold}).")
    return 0


if __name__ == '__main__':
    sys.exit(main())
