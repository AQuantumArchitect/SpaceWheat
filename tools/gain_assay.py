#!/usr/bin/env python3
"""gain_assay.py — Scan SpaceWheat biomes for population inversion (gain media).

═══════════════════════════════════════════════════════════════════════════
  WHAT IS POPULATION INVERSION?
═══════════════════════════════════════════════════════════════════════════

In ordinary matter, colder states are more populated than warmer ones
(Boltzmann's law). If you send a weak signal across a pair of levels,
it gets ABSORBED — population moves from the lower level up to the upper
level, subtracting from your beam.

A GAIN MEDIUM is a system where that's been inverted — the upper level
of some pair has MORE population than the lower level. Now the same
weak signal gets AMPLIFIED: one signal photon stimulates an additional
photon by de-exciting an upper-level atom. You put energy in at one
frequency (the pump), you get amplified output at another frequency.

This is how every laser in the world works.

You cannot do this with a passive, equilibrium system. The second law
will not allow it. You must have continuous ENERGY INFLOW from a pump,
and continuous population DRAINAGE from the lower level, at rates that
hold the system in a non-thermal steady state.

The simplest laser is a THREE-LEVEL system:

            |C⟩                      |C⟩ = pumped from outside at rate P
             |                        Γ_CB · |C⟩  fast decay C→B
             | Γ_CB (fast)
             ↓
            |B⟩                      |B⟩ = upper lasing level (metastable)
             ↕ Ω    ← Rabi coupling (the "lasing transition")
            |A⟩                      |A⟩ = lower lasing level
             |                        Γ_A  fast drain out of |A⟩
             ↓  (fast drain)
           (sink)

STEADY-STATE RATE PICTURE.  With small Ω and dominant Lindblad rates:

    N_C = P / Γ_CB                   (whatever you pump in, decays out)
    N_B ≈ (rate into B) / (rate out of B)   = P / Γ_eff
    N_A ≈ (rate into A) / (rate out of A)   = P / Γ_A

where Γ_eff ≈ 2 Ω²/Γ_dephase is the Zeno-smeared rate at which coherent
coupling transports population from B to A. Inversion (N_B > N_A)
requires  Γ_A > Γ_eff  — the lower level must leak faster than the
lasing transition fills it.

═══════════════════════════════════════════════════════════════════════════
  METHOD
═══════════════════════════════════════════════════════════════════════════

For each biome we:

    1.  Build the full Hermitian Hamiltonian H on its emojis from
        faction contributions.

    2.  Build the full Lindblad jump set from the biome's
        atom_components (pumps, drains, decays).

    3.  Time-evolve the density matrix from ρ = 0 using a 4th-order
        Runge-Kutta Lindblad integrator until it reaches steady state
        (dρ/dt small).

    4.  For every H-coupled pair (A, B) with |H_AB| > 0.1, compute the
        inversion
            ΔN = ρ_BB − ρ_AA            (by convention, B is whichever
                                         has higher steady-state pop)
        and the gain coefficient
            gain = |H_AB| · max(ΔN, 0).

    5.  Report the pair with the largest gain. Positive gain ⇒ the
        biome AMPLIFIES a weak signal on that transition.

═══════════════════════════════════════════════════════════════════════════

Usage:
    python3 tools/gain_assay.py
    python3 tools/gain_assay.py --top 10
    python3 tools/gain_assay.py --biome LaserGlint
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
)
from assay_cli import run_assay  # noqa: E402


# ── Build H on the biome basis ──────────────────────────────────────────────

def build_H(emojis: list[str], se: dict, cre: dict, cim: dict) -> np.ndarray:
    N = len(emojis)
    H = np.zeros((N, N), dtype=complex)
    for i, e in enumerate(emojis):
        H[i, i] = se.get(e, 0.0)
    for i in range(N):
        for j in range(i + 1, N):
            a, b = emojis[i], emojis[j]
            key = tuple(sorted([a, b]))
            # biome_audit double-counts each Hermitian edge; halve.
            re = 0.5 * cre.get(key, 0.0)
            im = 0.5 * cim.get(key, 0.0)
            g = complex(re, im) if (a, b) == key else complex(re, -im)
            H[i, j] = g
            H[j, i] = np.conj(g)
    return H


# ── Build jump list (src_idx, tgt_idx, rate), with None for "outside" ───────

def build_jumps(biome: dict, emojis: list[str]) -> list[tuple]:
    idx = {e: i for i, e in enumerate(emojis)}
    jumps = []
    for emoji, comp in (biome.get('atom_components') or {}).items():
        if not isinstance(comp, dict) or emoji not in idx:
            continue
        i = idx[emoji]
        # outgoing: drain from i to whatever
        for tgt, rate in (comp.get('lindblad_outgoing') or {}).items():
            jumps.append((float(rate), i, idx.get(tgt)))  # src=i, tgt=maybe None
        # incoming: pump from outside/other to i
        for src, rate in (comp.get('lindblad_incoming') or {}).items():
            jumps.append((float(rate), idx.get(src), i))  # src=maybe None, tgt=i
        # decay: emoji → target (target outside the biome is typical)
        decay = comp.get('decay') or {}
        tgt = decay.get('target')
        rate = float(decay.get('rate', 0))
        if rate > 0:
            jumps.append((rate, i, idx.get(tgt)))
    return jumps


# ── Lindblad RHS ────────────────────────────────────────────────────────────

def rhs(rho: np.ndarray, H: np.ndarray, jumps: list[tuple]) -> np.ndarray:
    """Return dρ/dt for the open-system ME. Handles jumps with src/tgt
    possibly outside the biome basis (None). External pumps are saturable
    — multiplied by (1 − Tr ρ) so the reservoir empties as it fills the biome."""
    d = -1j * (H @ rho - rho @ H)
    trace = float(np.real(np.trace(rho)))
    saturation = max(0.0, 1.0 - trace)
    for rate, s, t in jumps:
        if s is not None:
            # Anticommutator −½·r·{|s⟩⟨s|, ρ}   (always applied when src is inside)
            d[s, :] -= 0.5 * rate * rho[s, :]
            d[:, s] -= 0.5 * rate * rho[:, s]
            if t is not None:
                # Population hop  +r · ρ_ss  → (t,t)
                d[t, t] += rate * rho[s, s].real
        else:
            # Pump from outside: saturable source. Only affects tgt if inside.
            if t is not None:
                d[t, t] += rate * saturation
    return d


def evolve_to_steady_state(H: np.ndarray, jumps: list[tuple],
                           t_max: float = 80.0, dt: float = 0.05,
                           tol: float = 1e-4) -> np.ndarray:
    """RK4 integrate. Stop when ||dρ/dt|| drops below tol."""
    N = H.shape[0]
    rho = np.zeros((N, N), dtype=complex)
    steps = int(t_max / dt)
    for k in range(steps):
        k1 = rhs(rho, H, jumps)
        if k % 50 == 49 and np.max(np.abs(k1)) < tol:
            break
        k2 = rhs(rho + 0.5 * dt * k1, H, jumps)
        k3 = rhs(rho + 0.5 * dt * k2, H, jumps)
        k4 = rhs(rho + dt * k3, H, jumps)
        rho = rho + (dt / 6.0) * (k1 + 2*k2 + 2*k3 + k4)
    return rho


# ── Per-biome analysis ─────────────────────────────────────────────────────

def assay_biome(biome: dict, factions: list[dict]) -> dict:
    emojis = biome['emojis']
    if len(emojis) < 2:
        return {'name': biome['name'], 'gain': 0.0, 'note': 'too-small'}

    norms = compute_frobenius_norms(factions, emojis)
    se, cre, cim, _ = compute_faction_baselines(factions, emojis, norms)
    H = build_H(emojis, se, cre, cim)
    jumps = build_jumps(biome, emojis)

    if not jumps:
        return {'name': biome['name'], 'gain': 0.0, 'note': 'no-lindblads'}

    rho = evolve_to_steady_state(H, jumps)
    pops = np.real(np.diag(rho))

    # Find Rabi pair with biggest population inversion weighted by coupling
    best = None
    for i in range(len(emojis)):
        for j in range(i + 1, len(emojis)):
            omega = abs(H[i, j])
            if omega < 0.1:
                continue
            # B = larger-population site, A = smaller
            if pops[i] > pops[j]:
                b_i, a_i = i, j
            else:
                b_i, a_i = j, i
            inversion = pops[b_i] - pops[a_i]
            gain = omega * inversion
            record = {
                'A': emojis[a_i],
                'B': emojis[b_i],
                'N_A': float(pops[a_i]),
                'N_B': float(pops[b_i]),
                'inversion': float(inversion),
                'omega': float(omega),
                'gain': float(gain),
            }
            if best is None or gain > best['gain']:
                best = record

    if best is None:
        return {'name': biome['name'], 'gain': 0.0, 'note': 'no-rabi-pair'}

    all_pops = {e: float(p) for e, p in zip(emojis, pops)}
    return {'name': biome['name'], **best, 'all_pops': all_pops, 'note': ''}


def print_detail(r: dict) -> None:
    print(f"\n── {r['name']} ──")
    if r.get('note'):
        print(f"  (skipped: {r['note']})")
        return
    print(f"  steady-state populations:")
    for e, p in sorted(r['all_pops'].items(), key=lambda kv: -kv[1]):
        bar = '█' * min(int(p * 40), 40)
        print(f"    {e}  {p:6.3f}  {bar}")
    print(f"  lasing transition:  |{r['A']}⟩ ↔ |{r['B']}⟩")
    print(f"    Rabi coupling Ω = {r['omega']:.3f}")
    print(f"    N_B = {r['N_B']:.3f},   N_A = {r['N_A']:.3f}")
    print(f"    inversion  ΔN = {r['inversion']:+.3f}   (> 0 → amplifying)")
    print(f"  gain coefficient  g = Ω · ΔN = {r['gain']:.3f}")


def print_summary(ok: list[dict], results: list[dict], args) -> None:
    print('─' * 82)
    print(' GAIN-MEDIUM ASSAY — steady-state population inversion under drive + drain')
    print('─' * 82)
    print(f"{'rank':>4}  {'gain':>6}  {'ΔN':>6}  {'Ω':>5}  {'N_B':>5}  {'N_A':>5}  biome              pair")
    for i, r in enumerate(ok[:args.top], 1):
        pair = f"{r['A']}↔{r['B']}"
        print(f"  {i:>2}  {r['gain']:>6.3f}  {r['inversion']:>+6.3f}  "
              f"{r['omega']:>5.2f}  {r['N_B']:>5.2f}  {r['N_A']:>5.2f}  "
              f"{r['name']:<18} {pair}")
    n = sum(1 for r in ok if r['gain'] >= args.threshold)
    print(f"\n  {n} biome(s) clear the gain threshold (gain ≥ {args.threshold}).")


def main() -> int:
    return run_assay(
        description=__doc__.split('\n')[0],
        assay_fn=assay_biome,
        print_detail=print_detail,
        sort_key='gain',
        default_threshold=0.05,
        skip_orphan_biomes=True,  # gain_assay has always excluded _orphan_lindblads
        print_summary=print_summary,
    )


if __name__ == '__main__':
    sys.exit(main())
