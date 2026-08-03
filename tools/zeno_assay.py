#!/usr/bin/env python3
"""zeno_assay.py — Scan SpaceWheat biomes for quantum Zeno latches.

═══════════════════════════════════════════════════════════════════════════
  WHAT IS THE QUANTUM ZENO EFFECT?
═══════════════════════════════════════════════════════════════════════════

Take a simple two-level system: a coin that flips coherently.

    |A⟩   ←── Ω (Rabi coupling in H) ──→   |B⟩

With nothing else, the population oscillates fully between |A⟩ and |B⟩
at frequency 2Ω — perfect coherent flopping. P_A(t) = cos²(Ωt).

Now add a fast Lindblad decay Γ on |B⟩ (continuously "measuring" whether
the coin is on the B-face, or equivalently, draining any population that
ends up there). Intuition says: the decay should eat |B⟩ quickly, so
more decay ⇒ population drains out faster.

REALITY IS OPPOSITE. The master equation says that for Γ ≫ Ω, the
effective rate at which |A⟩ loses population to |B⟩ goes like

    Γ_eff  =  2·Ω² / Γ                     ← the Zeno formula

LOOK AT THE DENOMINATOR. Bigger Γ means SMALLER Γ_eff. More decay makes
the coin LESS LIKELY to flip. The system gets PINNED to |A⟩ by the
measurement-induced dephasing.

This is the "watched pot never boils" theorem, except it's a real
theorem about quantum mechanics and it actually runs in atomic clocks.

═══════════════════════════════════════════════════════════════════════════
  WHAT DOES A ZENO LATCH LOOK LIKE AS A BIOME?
═══════════════════════════════════════════════════════════════════════════

A biome implements a Zeno latch when:

    1.  Two emojis A, B are coupled by a faction Hamiltonian with
        amplitude Ω = |g_AB|,
    2.  The biome puts a strong Lindblad decay Γ on B (drain or decay
        target outside the biome),
    3.  Γ / Ω  ≳  1  (we're in the Zeno regime).

The gameplay effect: starting population on |A⟩ *stays on A* over
timescales much longer than the naive Rabi period 1/Ω. The biome
becomes a LATCH whose state is held in place by the very drain that
should be pulling it apart.

═══════════════════════════════════════════════════════════════════════════
  THE METRIC
═══════════════════════════════════════════════════════════════════════════

For each biome and every eligible (A, B) pair we solve the 2-level
Lindblad master equation exactly with a small RK4 integrator:

    d ρ_AA / dt  =  −i·Ω · (ρ_BA − ρ_AB)
    d ρ_BB / dt  =  −i·Ω · (ρ_AB − ρ_BA)  −  Γ · ρ_BB
    d ρ_AB / dt  =  −i·Δ · ρ_AB  −  i·Ω · (ρ_BB − ρ_AA)  −  (Γ/2)·ρ_AB

Initial state: |A⟩⟨A|. We evolve out to T = 20 / Ω (about 3 Rabi
periods worth of natural time) and record:

    survival_A   = ρ_AA(T)
    leaked_out   = 1 − Tr ρ(T)                (population lost to the sink)
    free_rabi_PA = ⟨cos²(Ωt)⟩_T = 0.5         (pure-Rabi baseline)
    zeno_score   = survival_A − free_rabi_PA  (positive = latched)

Zeno ratio: Γ / Ω  (anything ≳ 1 is Zeno regime).

The analytical Zeno rate Γ_eff = 2Ω²/Γ is reported for comparison.

═══════════════════════════════════════════════════════════════════════════

Usage:
    python3 tools/zeno_assay.py
    python3 tools/zeno_assay.py --top 15
    python3 tools/zeno_assay.py --biome ZenoLatch
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from biome_audit import (  # noqa: E402
    compute_frobenius_norms,
    compute_faction_baselines,
    extract_biome_lindblad,
)
from assay_cli import run_assay  # noqa: E402


# ── 2-level master equation ─────────────────────────────────────────────────

def simulate_zeno(omega: float, delta: float, gamma: float,
                  t_max: float, steps: int = 2000) -> dict:
    """Evolve ρ from |A⟩⟨A| for the two-level + decay-on-B system.

    State vector: (ρ_AA, ρ_BB, Re ρ_AB, Im ρ_AB) — all real-valued.
    RK4 integration. Returns final populations and time-averaged ρ_BB.
    """
    dt = t_max / steps

    def rhs(y):
        rho_aa, rho_bb, re_ab, im_ab = y
        # d ρ_aa /dt = -iΩ(ρ_ba - ρ_ab) = -iΩ·(−2i·Im ρ_ab) = -2Ω·Im ρ_ab
        d_aa = -2.0 * omega * im_ab
        d_bb = +2.0 * omega * im_ab - gamma * rho_bb
        # d ρ_ab /dt = -iΔ·ρ_ab - iΩ·(ρ_bb - ρ_aa) - (Γ/2)·ρ_ab
        # Re part: +Δ·Im ρ_ab - (Γ/2)·Re ρ_ab
        # Im part: -Δ·Re ρ_ab - Ω·(ρ_bb - ρ_aa) - (Γ/2)·Im ρ_ab
        d_re = delta * im_ab - 0.5 * gamma * re_ab
        d_im = -delta * re_ab - omega * (rho_bb - rho_aa) - 0.5 * gamma * im_ab
        return np.array([d_aa, d_bb, d_re, d_im])

    y = np.array([1.0, 0.0, 0.0, 0.0])  # start on |A⟩
    pb_sum = 0.0
    for _ in range(steps):
        k1 = rhs(y)
        k2 = rhs(y + 0.5 * dt * k1)
        k3 = rhs(y + 0.5 * dt * k2)
        k4 = rhs(y + dt * k3)
        y = y + (dt / 6.0) * (k1 + 2*k2 + 2*k3 + k4)
        pb_sum += y[1]

    return {
        'pa_final': float(y[0]),
        'pb_final': float(y[1]),
        'pb_timeavg': float(pb_sum / steps),
        'leaked': float(1.0 - y[0] - y[1]),
    }


# ── Candidate-pair enumeration ──────────────────────────────────────────────

def pick_zeno_pairs(biome: dict, factions: list[dict]) -> list[dict]:
    """Yield (A, B, Ω, Δ, Γ) for every Rabi pair where B has strong decay."""
    emojis = biome['emojis']
    if len(emojis) < 2:
        return []

    norms = compute_frobenius_norms(factions, emojis)
    se, cre, cim, _ = compute_faction_baselines(factions, emojis, norms)
    lind = extract_biome_lindblad(biome)

    # Decay-out rate on each emoji (drains + decays)
    out_rate = {e: 0.0 for e in emojis}
    for src, _, r in lind.get('drains', []):
        if src in out_rate:
            out_rate[src] += r
    for src, _, r in lind.get('decays', []):
        if src in out_rate:
            out_rate[src] += r

    pairs = []
    for i in range(len(emojis)):
        for j in range(len(emojis)):
            if i == j:
                continue
            A, B = emojis[i], emojis[j]
            key = tuple(sorted([A, B]))
            # biome_audit sums BOTH directions of each Hermitian edge (H[a][b]
            # and H[b][a] land in the same dict key). Halve to get the actual
            # Hilbert-space matrix element |⟨A|H|B⟩|.
            re = cre.get(key, 0.0) * 0.5
            im = cim.get(key, 0.0) * 0.5
            omega = math.hypot(re, im)
            gamma = out_rate[B]
            if omega < 0.1 or gamma <= 0.0:
                continue
            delta = se.get(B, 0.0) - se.get(A, 0.0)
            pairs.append({'A': A, 'B': B, 'omega': omega, 'delta': delta, 'gamma': gamma})
    return pairs


# ── Scoring ─────────────────────────────────────────────────────────────────

def assay_biome(biome: dict, factions: list[dict]) -> dict:
    pairs = pick_zeno_pairs(biome, factions)
    if not pairs:
        return {'name': biome['name'], 'zeno_score': 0.0, 'note': 'no-decayed-rabi-pair'}

    best = None
    for p in pairs:
        omega = p['omega']
        # Measure at one Rabi half-period of the resonant system.
        t_max = math.pi / (2.0 * max(omega, 0.01))
        sim = simulate_zeno(omega, p['delta'], p['gamma'], t_max)
        # Pure-Rabi baseline (same Ω and Δ, but Γ = 0). This subtracts off any
        # detuning-induced suppression, so the score isolates the Zeno effect:
        # how much did turning on the decay move P_A *upward*?
        sim_free = simulate_zeno(omega, p['delta'], 0.0, t_max)
        zeno_score = sim['pa_final'] - sim_free['pa_final']
        record = {
            **p,
            'pa_final': sim['pa_final'],
            'pa_free': sim_free['pa_final'],
            'pb_final': sim['pb_final'],
            'pb_timeavg': sim['pb_timeavg'],
            'leaked': sim['leaked'],
            'zeno_ratio': p['gamma'] / p['omega'],
            'gamma_eff': 2.0 * p['omega'] ** 2 / p['gamma'] if p['gamma'] > 1e-9 else float('inf'),
            'zeno_score': zeno_score,
            't_max': t_max,
        }
        if best is None or record['zeno_score'] > best['zeno_score']:
            best = record

    return {'name': biome['name'], **best, 'note': ''}


def print_detail(r: dict) -> None:
    print(f"\n── {r['name']} ──")
    if r.get('note'):
        print(f"  (skipped: {r['note']})")
        return
    print(f"  pair:          |{r['A']}⟩  ──  Ω = {r['omega']:.3f}  ──  |{r['B']}⟩")
    print(f"  detuning:      Δ = {r['delta']:+.3f}")
    print(f"  decay on B:    Γ = {r['gamma']:.3f}")
    print(f"  Zeno ratio:    Γ/Ω = {r['zeno_ratio']:.2f}   "
          f"({'ZENO regime' if r['zeno_ratio'] > 1.0 else 'underdamped'})")
    print(f"  Γ_eff (formula 2Ω²/Γ): {r['gamma_eff']:.4f}  (smaller = stronger latch)")
    print(f"  ── after T = {r['t_max']:.1f} ──")
    print(f"    P(A) with decay      : {r['pa_final']:.3f}")
    print(f"    P(A) no decay (free) : {r['pa_free']:.3f}   ← pure-Rabi baseline")
    print(f"    P(B) instantaneous   : {r['pb_final']:.3f}")
    print(f"    P(B) time-averaged   : {r['pb_timeavg']:.3f}")
    print(f"    leaked to sink       : {r['leaked']:.3f}")
    print(f"  zeno_score = ΔP(A) = P(A|decay) − P(A|no-decay) = {r['zeno_score']:+.3f}")
    print(f"     (positive → decay PROTECTS |A⟩ from transferring; that is Zeno.)")


def print_summary(ok: list[dict], results: list[dict], args) -> None:
    print('─' * 82)
    print(' QUANTUM ZENO ASSAY — latched survival of |A⟩ under continuous measurement of |B⟩')
    print('─' * 82)
    print(f"{'rank':>4}  {'score':>6}  {'P_A':>5}  {'Γ/Ω':>5}  {'Ω':>5}  {'Γ':>5}  biome              pair")
    for i, r in enumerate(ok[:args.top], 1):
        pair = f"{r['A']}──{r['B']}"
        print(f"  {i:>2}  {r['zeno_score']:>+6.3f}  {r['pa_final']:>5.2f}  "
              f"{r['zeno_ratio']:>5.2f}  {r['omega']:>5.2f}  {r['gamma']:>5.2f}  "
              f"{r['name']:<18} {pair}")
    n = sum(1 for r in ok if r['zeno_score'] >= args.threshold)
    print(f"\n  {n} biome(s) clear the Zeno threshold ({args.threshold:+.2f}).")


def main() -> int:
    return run_assay(
        description=__doc__.split('\n')[0],
        assay_fn=assay_biome,
        print_detail=print_detail,
        sort_key='zeno_score',
        default_threshold=0.5,
        skip_orphan_biomes=False,  # zeno_assay has always assayed _orphan_lindblads too
        print_summary=print_summary,
    )


if __name__ == '__main__':
    sys.exit(main())
