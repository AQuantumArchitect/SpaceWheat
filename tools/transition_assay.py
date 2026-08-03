#!/usr/bin/env python3
"""transition_assay.py — Scan SpaceWheat biomes for bistable phase transitions.

═══════════════════════════════════════════════════════════════════════════
  WHAT IS A DISSIPATIVE PHASE TRANSITION?
═══════════════════════════════════════════════════════════════════════════

In a closed quantum system, the state evolves reversibly: you can tell
where you came from. In an open system — where the environment measures
the system continuously via Lindblad decays, pumps, and drains — the
system usually FORGETS its initial condition and settles into a unique
STEADY STATE.  One sky, one answer.

But if the Lindbladian is NONLINEAR, two (or more) steady states can
COEXIST for the same external parameters. The answer depends on where
you started. This is a DISSIPATIVE PHASE TRANSITION, and the set of
coexisting steady states is the PHASE DIAGRAM.

The cleanest example uses AUTOCATALYSIS: a transition rate that is
itself proportional to the population of some site. A "self-kindling"
Lindblad.  Once a site has enough population on it, it pumps itself
further.  Once it doesn't, it can't.  Two stable fixed points.

In SpaceWheat, this is represented by the GATED LINDBLAD:

    gated_lindblad_source: [
        { target: X,   gate: X,   rate: r,   power: 2 }
    ]

This reads "a transition ending at X whose effective rate is r · ρ_X^p".
When p ≥ 2 the feedback is super-linear and bistability can emerge.

═══════════════════════════════════════════════════════════════════════════
  WHY THIS MATTERS FOR GAMEPLAY
═══════════════════════════════════════════════════════════════════════════

A biome with a dissipative phase transition has a MEMORY written in its
steady state. A quest can ask "is the tide currently bright or dim?" —
and the answer is not determined by the biome's static parameters, but
by its HISTORY.  A push is required to flip it. That push is a quest
or player interaction.

Bistable biomes are the first genuine non-trivial state machines in the
game world: they can be in a persistent configuration that carries
information across encounters.

═══════════════════════════════════════════════════════════════════════════
  METHOD
═══════════════════════════════════════════════════════════════════════════

For each biome we:

    1.  Build H on the biome emojis (faction contributions).
    2.  Build the Lindbladian jump set, including any gated jumps
        (rate_eff = base_rate · ρ_gate^power at each time step).
    3.  Time-evolve to steady state from TWO different initial states:
          (a) the vacuum ρ = 0       ("waking up empty")
          (b) a saturated guess       ("waking up full")
    4.  Compare the two steady states.  Define a BISTABILITY SCORE as
           S = max_e | ρ_ee^(full) − ρ_ee^(empty) |
        A value of S close to 0 means the biome has a unique steady
        state (as a linear Lindblad system must).  A value of S close
        to 1 means two wildly different steady states coexist: a
        bistable phase transition.

═══════════════════════════════════════════════════════════════════════════

Usage:
    python3 tools/transition_assay.py
    python3 tools/transition_assay.py --top 10
    python3 tools/transition_assay.py --biome TwofacedTide
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from biome_audit import (  # noqa: E402
    compute_frobenius_norms,
    compute_faction_baselines,
)
from assay_cli import run_assay  # noqa: E402


# ── H builder (same as in gain_assay) ───────────────────────────────────────

def build_H(emojis: list[str], se: dict, cre: dict, cim: dict) -> np.ndarray:
    N = len(emojis)
    H = np.zeros((N, N), dtype=complex)
    for i, e in enumerate(emojis):
        H[i, i] = se.get(e, 0.0)
    for i in range(N):
        for j in range(i + 1, N):
            a, b = emojis[i], emojis[j]
            key = tuple(sorted([a, b]))
            re = 0.5 * cre.get(key, 0.0)
            im = 0.5 * cim.get(key, 0.0)
            g = complex(re, im) if (a, b) == key else complex(re, -im)
            H[i, j] = g
            H[j, i] = np.conj(g)
    return H


# ── Jump list with gated support ────────────────────────────────────────────

def build_jumps(biome: dict, emojis: list[str]) -> list[dict]:
    """Return a list of jump dicts. Each jump has:
        kind: 'linear' or 'gated'
        src, tgt: indices (None = outside)
        rate: base rate
        gate, power: only for gated jumps
    """
    idx = {e: i for i, e in enumerate(emojis)}
    jumps = []
    for emoji, comp in (biome.get('atom_components') or {}).items():
        if not isinstance(comp, dict) or emoji not in idx:
            continue
        i = idx[emoji]
        for tgt, rate in (comp.get('lindblad_outgoing') or {}).items():
            jumps.append({'kind': 'linear', 'src': i, 'tgt': idx.get(tgt),
                          'rate': float(rate)})
        for src, rate in (comp.get('lindblad_incoming') or {}).items():
            jumps.append({'kind': 'linear', 'src': idx.get(src), 'tgt': i,
                          'rate': float(rate)})
        decay = comp.get('decay') or {}
        if float(decay.get('rate', 0)) > 0:
            jumps.append({'kind': 'linear', 'src': i, 'tgt': idx.get(decay['target']),
                          'rate': float(decay['rate'])})
        for g in (comp.get('gated_lindblad_source') or []):
            if not isinstance(g, dict):
                continue
            jumps.append({
                'kind': 'gated',
                'src': i,
                'tgt': idx.get(g.get('target', '')),
                'gate': idx.get(g.get('gate', '')),
                'rate': float(g.get('rate', 0)),
                'power': float(g.get('power', 1)),
                'inverse': bool(g.get('inverse', False)),
            })
    return jumps


# ── Master-equation RHS with gated jumps ────────────────────────────────────

def rhs(rho: np.ndarray, H: np.ndarray, jumps: list[dict]) -> np.ndarray:
    d = -1j * (H @ rho - rho @ H)
    trace = float(np.real(np.trace(rho)))
    saturation = max(0.0, 1.0 - trace)

    for j in jumps:
        s, t = j['src'], j['tgt']
        base_rate = j['rate']
        if j['kind'] == 'gated':
            g = j['gate']
            if g is None:
                continue
            pop = float(np.real(rho[g, g]))
            gate_val = pop ** j['power'] if pop > 0 else 0.0
            if j['inverse']:
                gate_val = max(0.0, 1.0 - gate_val)
            rate = base_rate * gate_val
        else:
            rate = base_rate

        if rate <= 0:
            continue

        if s is not None:
            d[s, :] -= 0.5 * rate * rho[s, :]
            d[:, s] -= 0.5 * rate * rho[:, s]
            if t is not None:
                d[t, t] += rate * rho[s, s].real
        else:
            # Pump from outside; saturable.
            if t is not None:
                d[t, t] += rate * saturation
    return d


def evolve(rho0: np.ndarray, H: np.ndarray, jumps: list[dict],
           t_max: float = 80.0, dt: float = 0.1) -> np.ndarray:
    rho = rho0.copy()
    steps = int(t_max / dt)
    for _ in range(steps):
        k1 = rhs(rho, H, jumps)
        k2 = rhs(rho + 0.5 * dt * k1, H, jumps)
        k3 = rhs(rho + 0.5 * dt * k2, H, jumps)
        k4 = rhs(rho + dt * k3, H, jumps)
        rho = rho + (dt / 6.0) * (k1 + 2 * k2 + 2 * k3 + k4)
    return rho


# ── Per-biome analysis ─────────────────────────────────────────────────────

def assay_biome(biome: dict, factions: list[dict]) -> dict:
    emojis = biome['emojis']
    if len(emojis) < 1:
        return {'name': biome['name'], 'score': 0.0, 'note': 'too-small'}

    norms = compute_frobenius_norms(factions, emojis)
    se, cre, cim, _ = compute_faction_baselines(factions, emojis, norms)
    H = build_H(emojis, se, cre, cim)
    jumps = build_jumps(biome, emojis)
    if not jumps:
        return {'name': biome['name'], 'score': 0.0, 'note': 'no-lindblads'}

    N = len(emojis)

    # Initial state A: vacuum ρ = 0
    rho_empty = np.zeros((N, N), dtype=complex)
    # Initial state B: saturated — equal populations on all diagonal summing to 1
    rho_full = np.eye(N, dtype=complex) / N

    rho_a = evolve(rho_empty, H, jumps)
    rho_b = evolve(rho_full, H, jumps)

    pops_a = np.real(np.diag(rho_a))
    pops_b = np.real(np.diag(rho_b))

    # Both steady states must be genuine attractors — if "from empty" stays at
    # zero trace, the biome has no pumps and is merely *pump-starved*, not
    # bistable. True bistability has two coexisting populated steady states.
    trace_a = float(np.sum(pops_a))
    trace_b = float(np.sum(pops_b))
    if trace_a < 0.05 or trace_b < 0.05:
        return {'name': biome['name'], 'score': 0.0,
                'note': f'pump-starved (Tr_∅={trace_a:.2f}, Tr_full={trace_b:.2f})'}

    diffs = np.abs(pops_a - pops_b)
    score = float(np.max(diffs))
    dominant_idx = int(np.argmax(diffs))

    return {
        'name': biome['name'],
        'score': score,
        'dominant': emojis[dominant_idx],
        'pops_empty': {e: float(p) for e, p in zip(emojis, pops_a)},
        'pops_full': {e: float(p) for e, p in zip(emojis, pops_b)},
        'note': '',
    }


def print_detail(r: dict) -> None:
    print(f"\n── {r['name']} ──")
    if r.get('note'):
        print(f"  (skipped: {r['note']})")
        return
    print(f"  Steady states from two initial conditions:")
    print(f"    {'emoji':^6}  {'from ∅':>9}     {'from full':>9}     diff")
    for e in r['pops_empty']:
        pa = r['pops_empty'][e]
        pb = r['pops_full'][e]
        mark = ' ← bistable' if abs(pa - pb) > 0.05 else ''
        print(f"    {e:^6}  {pa:>9.3f}     {pb:>9.3f}     {abs(pa - pb):>6.3f}{mark}")
    print(f"  bistability score = max |Δρ| = {r['score']:.3f}   "
          f"(0 = unique steady state; → 1 = fully bistable)")
    print(f"  dominant site:   {r['dominant']}")


def print_summary(ok: list[dict], results: list[dict], args) -> None:
    print('─' * 82)
    print(' BISTABILITY ASSAY — steady-state dependence on initial conditions')
    print('─' * 82)
    print(f"{'rank':>4}  {'score':>6}  dominant  biome")
    for i, r in enumerate(ok[:args.top], 1):
        print(f"  {i:>2}  {r['score']:>6.3f}    {r['dominant']:^6}  {r['name']}")
    n = sum(1 for r in ok if r['score'] >= args.threshold)
    print(f"\n  {n} biome(s) clear the bistability threshold ({args.threshold}).")


def main() -> int:
    return run_assay(
        description=__doc__.split('\n')[0],
        assay_fn=assay_biome,
        print_detail=print_detail,
        sort_key='score',
        default_threshold=0.1,
        skip_orphan_biomes=True,  # transition_assay has always excluded _orphan_lindblads
        print_summary=print_summary,
    )


if __name__ == '__main__':
    sys.exit(main())
