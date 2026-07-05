#!/usr/bin/env python3
"""channel_assay.py — Verify the runtime dissipative channels, headlessly.

═══════════════════════════════════════════════════════════════════════════
  WHAT THIS COVERS
═══════════════════════════════════════════════════════════════════════════

Four runtime mechanisms shipped with the Spark/Merchant revisit and the
basin awakening, each ported from its GDScript implementation and checked
against the physics it claims:

  1. PURE DEPHASING (QuantumComputer.apply_dephase + LindbladBuilder's
     dephasing field). Claim: coherences between the qubit's poles decay
     exactly as e^(−γt), populations never move, the map is CPTP, and the
     builder's L_z amplitude convention √(rate/2) reproduces the authored
     rate through the GKSL dissipator.

  2. THERMAL PAIR (Merchant thermal mode, Farm._process_lindblad_effects).
     Claim: a decay at γ paired with a back-drive at γ/2 has the mixed
     fixed point p = 1/3 against the flow — warm, never pinned. (And the
     mirrored import pair fixes at 2/3.)

  3. CROSS-QUBIT JUMP KRAUS (QuantumComputer.apply_jump_channel). Claim:
     the generalized amplitude-damping construction over the builder's
     partial-isometry jumps is exactly CPTP for arbitrary dt.

  4. GATED SELF-KINDLING (Farm._process_gated_channels). Claim: the
     mean-field per-tick map with rate_eff = r·p_gate^power reproduces the
     bistability the authored `gated_lindblad_source` circuits were
     written for — two initial conditions, two distinct steady states
     above threshold; a unique steady state below it. This is the
     transition_assay's phenomenon, re-verified through the *runtime's*
     exact-Kraus map rather than the site-basis RK4 model.

Usage:
    python3 tools/channel_assay.py
"""

from __future__ import annotations

import sys

import numpy as np


def vn_entropy(rho: np.ndarray) -> float:
    ev = np.linalg.eigvalsh(rho)
    ev = ev[ev > 1e-12]
    return float(-(ev * np.log(ev)).sum())


# ── 1. Pure dephasing ───────────────────────────────────────────────────────

def check_dephasing() -> list[tuple[str, float, float]]:
    out = []
    gamma, t = 0.35, 1.7
    rho = np.array([[0.3, 0.2 + 0.1j], [0.2 - 0.1j, 0.7]])

    # apply_dephase port: off-diagonals scale by e^(−γ·dt) per call.
    s = np.exp(-gamma * t)
    rho_d = rho.copy()
    rho_d[0, 1] *= s
    rho_d[1, 0] *= s

    out.append(("dephase: populations untouched",
                abs(rho_d[0, 0] - rho[0, 0]) + abs(rho_d[1, 1] - rho[1, 1]), 1e-15))
    out.append(("dephase: trace preserved", abs(np.trace(rho_d).real - 1.0), 1e-12))
    out.append(("dephase: positivity (min eig ≥ 0)",
                max(0.0, -np.linalg.eigvalsh(rho_d).min()), 1e-12))
    out.append(("dephase: entropy rises",
                max(0.0, vn_entropy(rho) - vn_entropy(rho_d)), 1e-12))

    # Builder convention: L = √(rate/2)·σ_z through the GKSL dissipator must
    # give d/dt ρ01 = −rate·ρ01. Integrate the exact dissipator and compare.
    rate = 0.35
    amp = np.sqrt(rate / 2)
    L = amp * np.array([[1, 0], [0, -1]], complex)
    dt, steps = 1e-4, int(t / 1e-4)
    r = rho.copy()
    for _ in range(steps):
        r = r + dt * (L @ r @ L.conj().T
                      - 0.5 * (L.conj().T @ L @ r + r @ L.conj().T @ L))
    out.append(("builder L_z convention (rate through GKSL)",
                abs(r[0, 1] - rho[0, 1] * np.exp(-rate * t)), 1e-4))
    return out


# ── 2. Thermal pair fixed point ─────────────────────────────────────────────

def kraus_flip(p_up: float, direction_up: bool, p_north: float) -> float:
    """1-qubit amplitude damping on the population, exact per tick."""
    if direction_up:  # south → north with prob p_up
        return p_north + (1 - p_north) * p_up
    return p_north * (1 - p_up)


def check_thermal() -> list[tuple[str, float, float]]:
    out = []
    g_down, ratio, dt = 1.0, 0.5, 0.01
    # export pair: decay γ then back-drive γ/2 (Farm tick order)
    p = 0.9
    for _ in range(6000):
        p = kraus_flip(1 - np.exp(-g_down * dt), False, p)
        p = kraus_flip(1 - np.exp(-g_down * ratio * dt), True, p)
    out.append(("thermal export fixed point (→ 1/3)", abs(p - 1 / 3), 2e-3))
    # import pair: drive γ then back-decay γ/2
    p = 0.1
    for _ in range(6000):
        p = kraus_flip(1 - np.exp(-g_down * dt), True, p)
        p = kraus_flip(1 - np.exp(-g_down * ratio * dt), False, p)
    out.append(("thermal import fixed point (→ 2/3)", abs(p - 2 / 3), 2e-3))
    return out


# ── 3. Cross-qubit jump Kraus ───────────────────────────────────────────────

def apply_jump_channel(rho: np.ndarray, nq: int, from_q: int, from_p: int,
                       to_q: int, to_p: int, gamma: float, dt: float) -> np.ndarray:
    """Port of QuantumComputer.apply_jump_channel (cross-qubit branch)."""
    dim = 1 << nq
    sf, st = nq - 1 - from_q, nq - 1 - to_q
    flip = (1 << sf) | (1 << st)
    p = 1 - np.exp(-gamma * dt)
    s1mp = np.sqrt(1 - p)

    def member(i: int) -> bool:
        return ((i >> sf) & 1) == from_p and ((i >> st) & 1) != to_p

    def image(i: int) -> bool:
        return ((i >> sf) & 1) != from_p and ((i >> st) & 1) == to_p

    new = np.zeros_like(rho)
    for i in range(dim):
        for j in range(dim):
            k0 = (s1mp if member(i) else 1.0) * (s1mp if member(j) else 1.0)
            v = rho[i, j] * k0
            if image(i) and image(j):
                v += p * rho[i ^ flip, j ^ flip]
            new[i, j] = v
    return new


def check_jump_kraus() -> list[tuple[str, float, float]]:
    out = []
    rng = np.random.default_rng(3)
    nq, dim = 3, 8
    worst_trace = worst_pos = 0.0
    for _ in range(200):
        a = rng.normal(size=(dim, dim)) + 1j * rng.normal(size=(dim, dim))
        rho = a @ a.conj().T
        rho /= np.trace(rho).real
        r2 = apply_jump_channel(rho, nq, 0, 1, 2, 0,
                                rng.uniform(0.1, 3.0), rng.uniform(0.05, 2.0))
        worst_trace = max(worst_trace, abs(np.trace(r2).real - 1.0))
        worst_pos = max(worst_pos, max(0.0, -np.linalg.eigvalsh(r2).min()))
    out.append(("jump Kraus: trace preserved (200 random ρ)", worst_trace, 1e-10))
    out.append(("jump Kraus: positivity", worst_pos, 1e-10))
    return out


# ── 4. Gated self-kindling bistability ──────────────────────────────────────

def evolve_gated(p0: float, r_gate: float, g_decay: float, power: float,
                 dt: float = 0.05, steps: int = 40000) -> float:
    """Runtime map: per tick, gated pump south→north at r·p^power (mean
    field, exact Kraus), then linear decay north→south at g."""
    p = p0
    for _ in range(steps):
        rate_eff = r_gate * (p ** power if p > 0 else 0.0)
        p = kraus_flip(1 - np.exp(-rate_eff * dt), True, p)
        p = kraus_flip(1 - np.exp(-g_decay * dt), False, p)
    return p


def check_bistability() -> list[tuple[str, float, float]]:
    out = []
    # Above threshold (r > 4γ for power 2): the urn fills itself, or stays
    # empty, depending on where it woke — two distinct steady states.
    hi = evolve_gated(0.85, r_gate=0.40, g_decay=0.02, power=2)
    lo = evolve_gated(0.02, r_gate=0.40, g_decay=0.02, power=2)
    out.append(("self-kindling: bright basin holds (p > 0.6)",
                max(0.0, 0.6 - hi), 0.0 + 1e-9))
    out.append(("self-kindling: dark basin holds (p < 0.1)",
                max(0.0, lo - 0.1), 0.0 + 1e-9))
    # Below threshold: a unique steady state — both inits converge.
    hi2 = evolve_gated(0.85, r_gate=0.05, g_decay=0.02, power=2)
    lo2 = evolve_gated(0.02, r_gate=0.05, g_decay=0.02, power=2)
    out.append(("sub-threshold: unique steady state", abs(hi2 - lo2), 1e-3))
    return out


def main() -> int:
    groups = [
        ("pure dephasing", check_dephasing()),
        ("thermal pair", check_thermal()),
        ("cross-qubit jump Kraus", check_jump_kraus()),
        ("gated self-kindling", check_bistability()),
    ]
    print("channel_assay — runtime dissipative channels\n")
    failed = 0
    for title, checks in groups:
        print(f"  [{title}]")
        for name, dev, bound in checks:
            ok = dev <= bound
            failed += 0 if ok else 1
            print(f"    {'PASS' if ok else 'FAIL'}  {name:<46} dev={dev:.2e}")
    print(f"\n  {'ALL CLAIMS HOLD' if failed == 0 else str(failed) + ' CLAIM(S) FAILED'}")
    return 0 if failed == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
