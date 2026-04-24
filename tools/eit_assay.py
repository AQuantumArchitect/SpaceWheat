#!/usr/bin/env python3
"""eit_assay.py — Scan SpaceWheat biomes for dark-state (EIT) detectors.

═══════════════════════════════════════════════════════════════════════════
  WHAT IS EIT?  (Electromagnetically Induced Transparency)
═══════════════════════════════════════════════════════════════════════════

A real, measured, Nobel-adjacent quantum-optics effect: a medium that
should absorb a beam of light becomes perfectly *transparent* at a specific
frequency — because two quantum pathways into the absorbing state cancel
by destructive interference.

The minimal setup is a "Λ system" — three levels in a lambda shape:

              |B⟩        ← "excited" state, LOSSY (Lindblad decay Γ)
             /   \\
            /     \\
           /       \\
        |A⟩         |C⟩   ← "ground" states, stable

Two coherent couplings live in the Hamiltonian:

        g_AB  couples  A ↔ B
        g_CB  couples  C ↔ B

KEY FACT. Under these conditions the Hamiltonian has a stationary
eigenstate — the DARK STATE — that lives entirely in the {|A⟩, |C⟩}
subspace and has ZERO amplitude on |B⟩:

        |D⟩ = (g_CB |A⟩  −  g_AB |C⟩) / √(|g_AB|² + |g_CB|²)

Because |D⟩ has no |B⟩ component, the Lindblad decay on B cannot touch
it. So even though the biome is dissipative, any population that flows
into |D⟩ stays forever. The Λ is a coherent *trap* in a lossy medium.

═══════════════════════════════════════════════════════════════════════════
  WHY DO WE CARE IN SPACEWHEAT?
═══════════════════════════════════════════════════════════════════════════

A biome implements an EIT detector when it has a Λ substructure:
    1.  an emoji B with fast Lindblad decay,
    2.  two emojis A, C strongly H-coupled to B by faction contributions,
    3.  no strong direct A↔C coupling (would spoil the interference),
    4.  comparable self-energies on A and C (near-resonant Λ).

That makes the biome a FUNCTIONAL QUANTUM CIRCUIT — not decoration. You
can read out a binary "dark or not" by measuring population at B, and
the reading depends on whether the faction couplings are in the right
phase relationship. In other words: the biome is a physical *instrument*
whose state reports on the algebraic relationship between factions.

═══════════════════════════════════════════════════════════════════════════
  THE METRIC
═══════════════════════════════════════════════════════════════════════════

For each biome we:

    1.  Pick the emoji with the largest outgoing Lindblad rate — call
        this B.  (No decay ⇒ no detector.)
    2.  Pick A, C = the two emojis with strongest |g_XB| coupling to B.
    3.  Build the 3×3 complex Hermitian Hamiltonian on {A, B, C} using
        faction self-energies and couplings (real + imaginary parts).
    4.  Diagonalize.  For each eigenvector |ψᵢ⟩, compute |⟨B|ψᵢ⟩|² —
        the population that eigenstate places on the lossy site.
    5.  darkness = 1 − min_i |⟨B|ψᵢ⟩|²    — how dark the best state is
        (1.0 means a perfect dark state exists).

We also compute:

    purity   = (|g_AB|² + |g_CB|²) / Σ_x |g_Bx|²
               (fraction of B's coupling that actually lives inside the Λ;
               if B is strongly coupled to a fourth emoji the Λ leaks)

    gamma    = total outgoing Lindblad rate on B (must be > 0)

Final score:

    eit_score = darkness × min(gamma / 0.05, 1) × purity

Biomes with eit_score ≳ 0.5 are functioning dark-state detectors.

═══════════════════════════════════════════════════════════════════════════

Usage:
    python3 tools/eit_assay.py                 # rank all biomes
    python3 tools/eit_assay.py --top 15        # show top 15
    python3 tools/eit_assay.py --biome Name    # detailed report on one biome
    python3 tools/eit_assay.py --verbose       # show Λ details for each
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import numpy as np

# We reuse the faction-baseline machinery from biome_audit.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from biome_audit import (  # noqa: E402
    load_factions,
    load_biomes,
    compute_frobenius_norms,
    compute_faction_baselines,
    extract_biome_lindblad,
)


# ── Core physics ────────────────────────────────────────────────────────────

def build_lambda_hamiltonian(
    A: str, B: str, C: str,
    se: dict, couplings_re: dict, couplings_im: dict,
) -> np.ndarray:
    """Build the 3×3 Hermitian Hamiltonian on the ordered basis [A, B, C].

    H is Hermitian by construction: H[i,j] = g*  on one side, g on the other.
    Real + imaginary couplings are combined into complex numbers.
    The `couplings_im` dict stores the signed imaginary part using the
    convention H[a][b] = re + i·im with (a,b) = sorted pair (see
    biome_audit.compute_faction_baselines).
    """
    basis = [A, B, C]
    H = np.zeros((3, 3), dtype=complex)
    for i, e in enumerate(basis):
        H[i, i] = se.get(e, 0.0)
    for i in range(3):
        for j in range(i + 1, 3):
            a, b = basis[i], basis[j]
            key = tuple(sorted([a, b]))
            re = couplings_re.get(key, 0.0)
            im = couplings_im.get(key, 0.0)
            # If (a,b) matches the sorted key order, the imag is +im;
            # otherwise it's the complex conjugate. But since (i,j) with i<j
            # always matches the sorted key in our basis ordering here ONLY
            # if basis[i] < basis[j] in sort order — which need not hold —
            # we must align explicitly.
            if (a, b) == key:
                g = complex(re, im)
            else:
                g = complex(re, -im)
            H[i, j] = g
            H[j, i] = np.conj(g)
    return H


def darkest_eigenstate(H: np.ndarray) -> tuple[float, np.ndarray, float]:
    """Diagonalize H and return the eigenstate with smallest |⟨B|ψ⟩|².

    Returns (b_pop, eigvec, eigvalue). b_pop is the population on index 1
    (which is always B in our convention).
    """
    w, V = np.linalg.eigh(H)
    b_pops = np.abs(V[1, :]) ** 2
    idx = int(np.argmin(b_pops))
    return float(b_pops[idx]), V[:, idx], float(w[idx])


# ── Biome selection ─────────────────────────────────────────────────────────

def pick_lambda(
    emojis: list[str],
    couplings_re: dict,
    couplings_im: dict,
    lind: dict,
) -> tuple[str, str, str, float] | None:
    """Pick the best candidate Λ triple (A, B, C) in a biome.

    B = emoji with largest total Lindblad-out rate.
    A, C = emojis with strongest |g_XB| (real² + imag²) to B.

    Returns (A, B, C, gamma_B) or None if no viable triple.
    """
    if len(emojis) < 3:
        return None

    # Sum outgoing Lindblad per emoji (drains + decays)
    out_rate = {e: 0.0 for e in emojis}
    for src, _, r in lind.get('drains', []):
        if src in out_rate:
            out_rate[src] += r
    for src, _, r in lind.get('decays', []):
        if src in out_rate:
            out_rate[src] += r

    # B = the lossiest emoji
    B = max(emojis, key=lambda e: out_rate[e])
    gamma_B = out_rate[B]
    if gamma_B <= 0.0:
        return None

    # Coupling magnitude from each other emoji to B
    def coupling_mag(x: str) -> float:
        key = tuple(sorted([x, B]))
        re = couplings_re.get(key, 0.0)
        im = couplings_im.get(key, 0.0)
        return math.sqrt(re * re + im * im)

    others = sorted([e for e in emojis if e != B], key=coupling_mag, reverse=True)
    if len(others) < 2:
        return None
    A, C = others[0], others[1]
    if coupling_mag(A) < 0.05 or coupling_mag(C) < 0.05:
        return None
    return A, B, C, gamma_B


def assay_biome(biome: dict, factions: list[dict]) -> dict:
    """Compute EIT metrics for one biome. Returns a flat dict of results."""
    emojis = biome['emojis']
    if len(emojis) < 3:
        return {'name': biome['name'], 'eit_score': 0.0, 'note': 'too-few-emojis'}

    norms = compute_frobenius_norms(factions, emojis)
    se, couplings_re, couplings_im, _ = compute_faction_baselines(factions, emojis, norms)
    lind = extract_biome_lindblad(biome)

    lam = pick_lambda(emojis, couplings_re, couplings_im, lind)
    if lam is None:
        return {'name': biome['name'], 'eit_score': 0.0, 'note': 'no-lambda'}

    A, B, C, gamma_B = lam
    H = build_lambda_hamiltonian(A, B, C, se, couplings_re, couplings_im)
    b_pop_min, psi_dark, _ = darkest_eigenstate(H)
    darkness = 1.0 - b_pop_min

    # Purity: how much of B's coupling is *inside* the Λ?
    inside_mag_sq = 0.0
    for x in (A, C):
        key = tuple(sorted([x, B]))
        inside_mag_sq += couplings_re.get(key, 0.0) ** 2 + couplings_im.get(key, 0.0) ** 2
    total_mag_sq = 0.0
    for x in biome['emojis']:
        if x == B:
            continue
        key = tuple(sorted([x, B]))
        total_mag_sq += couplings_re.get(key, 0.0) ** 2 + couplings_im.get(key, 0.0) ** 2
    purity = (inside_mag_sq / total_mag_sq) if total_mag_sq > 1e-9 else 0.0

    # Cross-coupling A↔C spoils dark state if large
    cross_key = tuple(sorted([A, C]))
    cross_re = couplings_re.get(cross_key, 0.0)
    cross_im = couplings_im.get(cross_key, 0.0)
    cross_mag = math.sqrt(cross_re * cross_re + cross_im * cross_im)

    # Self-energy detuning between A and C (zero is resonant, ideal)
    detuning = abs(se.get(A, 0.0) - se.get(C, 0.0))

    gamma_factor = min(gamma_B / 0.05, 1.0)
    eit_score = darkness * gamma_factor * purity

    # Amplitudes on A and C in the darkest state (the shape of the dark mode)
    amp_A = float(abs(psi_dark[0]))
    amp_C = float(abs(psi_dark[2]))

    return {
        'name': biome['name'],
        'A': A, 'B': B, 'C': C,
        'gamma_B': gamma_B,
        'g_AB_re': couplings_re.get(tuple(sorted([A, B])), 0.0),
        'g_AB_im': couplings_im.get(tuple(sorted([A, B])), 0.0),
        'g_CB_re': couplings_re.get(tuple(sorted([C, B])), 0.0),
        'g_CB_im': couplings_im.get(tuple(sorted([C, B])), 0.0),
        'cross_AC': cross_mag,
        'detuning_AC': detuning,
        'darkness': darkness,
        'b_pop_in_dark': b_pop_min,
        'amp_A': amp_A,
        'amp_C': amp_C,
        'purity': purity,
        'eit_score': eit_score,
        'note': '',
    }


# ── Output ──────────────────────────────────────────────────────────────────

def fmt_complex(re: float, im: float) -> str:
    sign = '+' if im >= 0 else '−'
    return f'{re:+.3f} {sign} {abs(im):.3f}i'


def print_detail(r: dict) -> None:
    print(f"\n── {r['name']} ──")
    if r.get('note'):
        print(f"  (skipped: {r['note']})")
        return
    A, B, C = r['A'], r['B'], r['C']
    print(f"  Λ system:   {A} ─── [{B}] ─── {C}")
    print(f"              A    lossy    C")
    print(f"  decay on B: Γ = {r['gamma_B']:.3f}")
    print(f"  g_AB =      {fmt_complex(r['g_AB_re'], r['g_AB_im'])}")
    print(f"  g_CB =      {fmt_complex(r['g_CB_re'], r['g_CB_im'])}")
    print(f"  cross A↔C:  |g_AC| = {r['cross_AC']:.3f}  (lower = better)")
    print(f"  detuning:   |SE(A) − SE(C)| = {r['detuning_AC']:.3f}  (lower = better)")
    print(f"  ── results ──")
    print(f"  B-pop in darkest state: {r['b_pop_in_dark']:.4f}  (0 = perfect dark)")
    print(f"  dark-state amplitudes:  |A|={r['amp_A']:.3f}  |C|={r['amp_C']:.3f}")
    print(f"  darkness = {r['darkness']:.3f}")
    print(f"  purity   = {r['purity']:.3f}  (fraction of B's coupling inside the Λ)")
    print(f"  EIT score = {r['eit_score']:.3f}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--top', type=int, default=10, help='show top N biomes')
    ap.add_argument('--biome', type=str, default=None, help='detailed report on one biome')
    ap.add_argument('--verbose', action='store_true', help='show Λ for every biome')
    ap.add_argument('--threshold', type=float, default=0.3, help='eit_score threshold for the "detector" list')
    args = ap.parse_args()

    factions = load_factions()
    biomes = load_biomes()

    if args.biome:
        match = [b for b in biomes if b['name'] == args.biome]
        if not match:
            print(f"No such biome: {args.biome}")
            return 1
        r = assay_biome(match[0], factions)
        print_detail(r)
        return 0

    results = [assay_biome(b, factions) for b in biomes]
    scored = [r for r in results if not r.get('note')]
    scored.sort(key=lambda r: r['eit_score'], reverse=True)

    print(f"\n{'─' * 72}")
    print(f" EIT DARK-STATE ASSAY  ({len(scored)}/{len(results)} biomes had a Λ candidate)")
    print(f"{'─' * 72}")
    print(f"{'rank':>4}  {'score':>6}  {'dark':>5}  {'pure':>5}  {'Γ_B':>5}  biome              Λ")
    for i, r in enumerate(scored[:args.top], 1):
        lam_str = f"{r['A']}─[{r['B']}]─{r['C']}"
        print(f"  {i:>2}  {r['eit_score']:>6.3f}  {r['darkness']:>5.3f}  "
              f"{r['purity']:>5.2f}  {r['gamma_B']:>5.3f}  {r['name']:<18} {lam_str}")

    n_detectors = sum(1 for r in scored if r['eit_score'] >= args.threshold)
    print(f"\n  {n_detectors} biome(s) clear the EIT threshold ({args.threshold:.2f}).")

    if args.verbose:
        for r in scored:
            print_detail(r)

    return 0


if __name__ == '__main__':
    sys.exit(main())
