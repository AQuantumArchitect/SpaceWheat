#!/usr/bin/env python3
"""biome_audit.py — Faction-baseline analysis for any SpaceWheat biome.

Usage:
    python3 tools/biome_audit.py StarterForest
    python3 tools/biome_audit.py Village
    python3 tools/biome_audit.py --all          # summary of every biome
    python3 tools/biome_audit.py --list          # just list biome names + emoji counts

Loads factions_merged.json, applies Frobenius normalization, reads the .jsonl
Hamiltonian profile (if any), and prints a per-axis breakdown:
    faction baseline | profile correction | effective | Rabi | period | max population
"""

from __future__ import annotations

import json
import math
import os
import re
import sys
from pathlib import Path

# ── Paths (relative to repo root) ────────────────────────────────────────────

ROOT = Path(__file__).resolve().parent.parent
FACTIONS_PATH = ROOT / "Core" / "Factions" / "data" / "factions.json"
BIOMES_PATH = ROOT / "Core" / "Biomes" / "data" / "biomes.json"
HAMILTONIANS_DIR = ROOT / "Core" / "Config" / "Hamiltonians"

# ── Emoji normalization ──────────────────────────────────────────────────────

def strip_fe0f(s: str) -> str:
    """Strip U+FE0F variation selectors (matches EmojiUtil.normalize in GDScript)."""
    return s.replace("\ufe0f", "")


# ── Data loading ─────────────────────────────────────────────────────────────

def load_factions() -> list[dict]:
    with open(FACTIONS_PATH, encoding="utf-8") as f:
        factions = json.load(f)
    # Normalize emoji keys
    for fac in factions:
        fac["sig"] = [strip_fe0f(e) for e in fac.get("sig", [])]
        fac["self_energies"] = {strip_fe0f(k): v for k, v in fac.get("self_energies", {}).items()}
        fac["hamiltonian"] = {
            strip_fe0f(src): {strip_fe0f(tgt): v for tgt, v in targets.items()}
            for src, targets in fac.get("hamiltonian", {}).items()
        }
        fac["drivers"] = {
            strip_fe0f(k): v for k, v in fac.get("drivers", {}).items()
        }
    return factions


def load_biomes() -> list[dict]:
    with open(BIOMES_PATH, encoding="utf-8") as f:
        biomes = json.load(f)
    for b in biomes:
        b["emojis"] = [strip_fe0f(e) for e in b.get("emojis", [])]
    return biomes


def load_profile(biome_name: str) -> dict:
    """Load .jsonl Hamiltonian profile. Returns {self_energies, couplings, drivers}."""
    path = HAMILTONIANS_DIR / f"{biome_name.lower()}.jsonl"
    result = {"self_energies": {}, "couplings": {}, "drivers": {}}
    if not path.exists():
        return result
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            op = row.get("op", "")
            path_str = row.get("path", "")
            value = row.get("value")
            if op == "set" and path_str and value is not None:
                _set_nested(result, path_str, value)
    return result


def _set_nested(data: dict, path_str: str, value):
    parts = path_str.split(".")
    node = data
    for part in parts[:-1]:
        if part not in node or not isinstance(node[part], dict):
            node[part] = {}
        node = node[part]
    node[parts[-1]] = value


# ── Frobenius normalization ──────────────────────────────────────────────────

def faction_speaks(faction: dict, emoji: str) -> bool:
    return emoji in faction["sig"]


def compute_frobenius_norms(factions: list[dict], emojis: list[str]) -> dict[str, float]:
    """Compute ||H_f||_F for each faction relative to the given emoji set."""
    norms = {}
    for fac in factions:
        norm_sq = 0.0
        for emoji in emojis:
            if not faction_speaks(fac, emoji):
                continue
            se = fac["self_energies"].get(emoji, 0.0)
            norm_sq += se * se
            ham = fac["hamiltonian"].get(emoji, {})
            for val in ham.values():
                if isinstance(val, list):
                    # Complex coupling [re, im]
                    norm_sq += sum(v * v for v in val)
                else:
                    norm_sq += val * val
        if norm_sq > 0.0:
            norms[fac["name"]] = math.sqrt(norm_sq)
    return norms


def compute_faction_baselines(factions: list[dict], emojis: list[str], norms: dict[str, float]):
    """Compute faction-normalized baselines for self_energies and couplings.

    Returns:
        se_baselines: {emoji: float}
        coupling_baselines: {(src,tgt): float}  — REAL part of Hamiltonian coupling
        coupling_imag: {(src,tgt): float}       — IMAGINARY part (chirality)
        driver_baselines: {emoji: dict}
    """
    se = {e: 0.0 for e in emojis}
    couplings = {}       # real parts
    couplings_imag = {}  # imaginary parts (chirality)
    drivers = {}

    for fac in factions:
        if fac["name"] not in norms:
            continue
        w = 1.0 / norms[fac["name"]]

        for emoji in emojis:
            if not faction_speaks(fac, emoji):
                continue
            se[emoji] += fac["self_energies"].get(emoji, 0.0) * w

            ham = fac["hamiltonian"].get(emoji, {})
            for tgt, val in ham.items():
                if tgt not in emojis:
                    continue
                if isinstance(val, list):
                    re_v, im_v = val[0], val[1]
                else:
                    re_v, im_v = val, 0.0
                key = tuple(sorted([emoji, tgt]))
                # For imaginary: sign depends on orientation of the edge.
                # H[a][b] = [re, im] and H[b][a] = [re, -im]. When summing across
                # factions we accumulate the imag part as seen from the smaller
                # key; tracks the handedness consistently.
                im_signed = im_v if (emoji, tgt) == key else -im_v
                couplings.setdefault(key, 0.0)
                couplings[key] += re_v * w
                couplings_imag.setdefault(key, 0.0)
                couplings_imag[key] += im_signed * w

            drv = fac["drivers"].get(emoji)
            if drv:
                drivers[emoji] = drv

    return se, couplings, couplings_imag, drivers


# ── Archetype classification ────────────────────────────────────────────────

def extract_biome_lindblad(biome: dict) -> dict:
    """Read biome Lindblad spec from icon_components.

    Returns: {
        'pumps': [(source, target, rate)],
        'drains': [(source, target, rate)],
        'decays': [(source, target, rate)],
        'gated': [(source, target, gate, rate, power, inverse)],
    }
    """
    out = {'pumps': [], 'drains': [], 'decays': [], 'gated': []}
    ic = biome.get('icon_components', {}) or {}
    for emoji, comp in ic.items():
        if not isinstance(comp, dict):
            continue
        for src, rate in (comp.get('lindblad_outgoing') or {}).items():
            out['drains'].append((emoji, src, float(rate)))
        for src, rate in (comp.get('lindblad_incoming') or {}).items():
            out['pumps'].append((src, emoji, float(rate)))
        decay = comp.get('decay') or {}
        if decay.get('target') and float(decay.get('rate', 0)) > 0:
            out['decays'].append((emoji, decay['target'], float(decay['rate'])))
        for g in (comp.get('gated_lindblad_source') or []):
            if isinstance(g, dict):
                out['gated'].append((emoji, g.get('target', ''), g.get('gate', ''),
                                     float(g.get('rate', 0)), float(g.get('power', 1)),
                                     bool(g.get('inverse', False))))
    return out


def graph_components(emojis: list[str], couplings: dict) -> list[set[str]]:
    """Union-find over the coupling graph. Returns list of connected components."""
    parent = {e: e for e in emojis}
    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]; x = parent[x]
        return x
    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[ra] = rb
    for (a, b), v in couplings.items():
        if abs(v) > 0.01 and a in parent and b in parent:
            union(a, b)
    comps = {}
    for e in emojis:
        comps.setdefault(find(e), set()).add(e)
    return list(comps.values())


def compute_signature(biome: dict, factions: list[dict]) -> dict:
    """Compute the dynamic-signature metrics for a biome.

    Returns a dict of scalar metrics used by classify_archetype.
    """
    emojis = biome['emojis']
    if not emojis:
        return {}

    norms = compute_frobenius_norms(factions, emojis)
    se, couplings, couplings_imag, _ = compute_faction_baselines(factions, emojis, norms)
    lind = extract_biome_lindblad(biome)

    # Within-pair Rabi: edges where the two poles of the same icon-pair are coupled
    pairs = []
    for i in range(0, len(emojis), 2):
        north = emojis[i]
        south = emojis[i + 1] if i + 1 < len(emojis) else emojis[i]
        pairs.append(tuple(sorted([north, south])))
    rabi_vals = [abs(couplings.get(p, 0.0)) for p in pairs]
    rabi_active = sum(1 for v in rabi_vals if v > 0.1) / max(len(pairs), 1)
    rabi_total = sum(rabi_vals)

    # Chirality
    chirality = sum(abs(v) for v in couplings_imag.values())
    chirality_max = max((abs(v) for v in couplings_imag.values()), default=0.0)

    # Coherent (H) magnitudes
    coherent_mag = sum(abs(v) for v in couplings.values()) + chirality

    # Lindblad rates
    drain_rate = sum(r for _, _, r in lind['drains']) + sum(r for _, _, r in lind['decays'])
    pump_rate = sum(r for _, _, r in lind['pumps'])
    gated_rate = sum(r for _, _, _, r, _, _ in lind['gated'])
    total_l = drain_rate + pump_rate + gated_rate

    # Self-energy distribution
    se_vals = list(se.values())
    if se_vals:
        se_mean = sum(se_vals) / len(se_vals)
        se_var = sum((v - se_mean) ** 2 for v in se_vals) / len(se_vals)
        se_range = max(se_vals) - min(se_vals)
        se_neg_frac = sum(1 for v in se_vals if v < -0.02) / len(se_vals)
    else:
        se_mean = se_var = se_range = se_neg_frac = 0.0

    # Graph structure
    comps = graph_components(emojis, couplings)
    n_components = len(comps)
    # Isolated nodes (not coupled to anything)
    isolated = sum(1 for c in comps if len(c) == 1)

    # Degree / hub detection
    degrees = {e: 0 for e in emojis}
    for (a, b), v in couplings.items():
        if abs(v) > 0.05:
            if a in degrees: degrees[a] += 1
            if b in degrees: degrees[b] += 1
    max_deg = max(degrees.values()) if degrees else 0
    has_hub = max_deg >= 3

    return {
        'emojis': emojis,
        'rabi_active_frac': rabi_active,
        'rabi_total': rabi_total,
        'chirality': chirality,
        'chirality_max': chirality_max,
        'coherent_mag': coherent_mag,
        'drain_rate': drain_rate,
        'pump_rate': pump_rate,
        'gated_rate': gated_rate,
        'total_l': total_l,
        'l_over_h': (total_l / coherent_mag) if coherent_mag > 0.01 else (float('inf') if total_l > 0 else 0.0),
        'se_var': se_var,
        'se_range': se_range,
        'se_neg_frac': se_neg_frac,
        'n_components': n_components,
        'isolated': isolated,
        'max_deg': max_deg,
        'has_hub': has_hub,
        'n_couplings': sum(1 for v in couplings.values() if abs(v) > 0.05),
        'has_cascade': detect_cascade(lind, se, emojis),
        'has_loop_current': detect_loop_current(emojis, couplings_imag, couplings),
    }


def detect_cascade(lind: dict, se: dict, emojis: list[str]) -> bool:
    """Cascade: acyclic directed drain path of length >= 3 through biome emojis
    with an end-to-end SE drop (source SE > sink SE by >= 0.1).
    """
    edges = []
    for s, t, r in lind.get('drains', []):
        if s in emojis and t in emojis and r > 0.02:
            edges.append((s, t))
    for s, t, r in lind.get('decays', []):
        if s in emojis and t in emojis and r > 0.02:
            edges.append((s, t))
    if len(edges) < 3:
        return False
    adj = {}
    for a, b in edges:
        adj.setdefault(a, []).append(b)
    # Find an acyclic path of length >= 3 with SE[start] > SE[end] + 0.1
    def dfs(node, start, visited, depth):
        if depth >= 3 and se.get(start, 0.0) - se.get(node, 0.0) >= 0.1:
            return True
        for nxt in adj.get(node, []):
            if nxt in visited: continue
            if dfs(nxt, start, visited | {nxt}, depth + 1):
                return True
        return False
    for src in adj:
        if dfs(src, src, {src}, 1):
            return True
    return False


def detect_loop_current(emojis: list[str], couplings_imag: dict, couplings_re: dict) -> bool:
    """Loop current: a cycle of length >= 3 in the coupling graph where the
    imaginary parts (chirality) have consistent sign around the loop — a
    persistent macroscopic current.
    """
    # Build adjacency from edges with non-trivial imaginary part
    adj = {}
    for (a, b), im in couplings_imag.items():
        if abs(im) < 0.05: continue
        adj.setdefault(a, []).append((b, im))
        adj.setdefault(b, []).append((a, -im))  # reverse edge flips sign
    # DFS from each node looking for cycles of length 3-6 with consistent sign
    def search(start, node, visited, path_signs, depth):
        if depth > 6: return False
        for nxt, im in adj.get(node, []):
            # Closing the cycle: at least 2 edges accumulated, closing edge makes it a 3+ cycle
            if nxt == start and len(path_signs) >= 2:
                closing = path_signs + [im]
                if all(s > 0 for s in closing) or all(s < 0 for s in closing):
                    return True
                continue
            if nxt in visited: continue
            if path_signs and ((path_signs[-1] > 0) != (im > 0)):
                continue
            if search(start, nxt, visited | {nxt}, path_signs + [im], depth + 1):
                return True
        return False
    for start in adj:
        if search(start, start, {start}, [], 0):
            return True
    return False


def classify_archetype(sig: dict) -> str:
    """Return an archetype label from the dynamic signature.

    Priority-ordered; first match wins. Thresholds picked to be calibrated
    on the existing roster — adjust after seeing the census distribution.
    """
    if not sig:
        return 'Empty'
    coherent = sig['coherent_mag']
    chiral = sig['chirality']
    l_over_h = sig['l_over_h']
    total_l = sig['total_l']

    # 1. Orphan / empty biome
    if coherent < 0.05 and total_l < 0.01:
        return 'Empty'

    # 2. Two-room: disconnected H components (ignoring fully-isolated nodes)
    comps_with_edges = sig['n_components'] - sig['isolated']
    if comps_with_edges >= 2:
        return 'Two-room'

    # 3. Loop current: cycle with consistent chirality handedness
    if chiral > 0.25 and sig.get('has_loop_current'):
        return 'Loop current'

    # 4. Cascade: directed Lindblad flow with SE gradient
    if sig.get('has_cascade') and sig['drain_rate'] > sig['pump_rate']:
        return 'Cascade'

    # 5. Dissipation-dominant families
    if total_l > 0.02 and l_over_h > 0.25:
        # net flow direction
        if sig['pump_rate'] > sig['drain_rate'] * 1.3:
            return 'Driven garden'
        if sig['drain_rate'] > sig['pump_rate'] * 1.3:
            return 'Drain void'
        return 'Churn'  # roughly balanced L

    # 6. Chiral-dominant
    if chiral > 0.35:
        if chiral > 0.8 and sig['has_hub']:
            return 'Chiral spiral'
        if chiral > 0.3:
            return 'Chiral soft'

    # 5. Dark: most poles suppressed
    if sig['se_neg_frac'] >= 0.5:
        return 'Dark'

    # 7. Clock: most pairs actively Rabi-oscillating
    if sig['rabi_active_frac'] >= 0.6 and chiral < 0.2:
        return 'Clock'

    # 7. Stone: coherent but near-frozen (low rabi, low chirality)
    if sig['rabi_total'] < 0.1 and chiral < 0.1 and coherent > 0.5:
        return 'Stone'

    # 8. Chaos: dense, no hub, many components-of-one merged
    if sig['n_couplings'] >= len(sig['emojis']) and not sig['has_hub']:
        return 'Chaos'

    return 'Mixed'


# ── Quantum axis analysis ────────────────────────────────────────────────────

def rabi_period(rabi: float, detuning: float, time_scale: float = 0.5) -> float:
    """Real-time Rabi period in seconds. time_scale=0.5 means sim runs at half real-time."""
    omega_r = math.sqrt(rabi**2 + (detuning / 2)**2)
    if omega_r < 1e-9:
        return float("inf")
    t_sim = math.pi / omega_r
    return t_sim / time_scale


def max_minority_population(rabi: float, detuning: float) -> float:
    """Ground-state admixture of the disfavored pole (sin²θ mixing angle).

    For H = (Δ/2)σ_z + g·σ_x, the ground state has probability sin²(θ) of
    being found in the higher-energy diabatic state, where:
        sin²(θ) = (1 − Δ/√(Δ² + 4g²)) / 2
    """
    gap = math.sqrt(detuning**2 + 4 * rabi**2)
    if gap < 1e-12:
        return 0.5  # fully degenerate
    return (1.0 - abs(detuning) / gap) / 2.0


# ── Display ──────────────────────────────────────────────────────────────────

BOLD = "\033[1m"
DIM = "\033[2m"
YELLOW = "\033[33m"
RED = "\033[31m"
GREEN = "\033[32m"
CYAN = "\033[36m"
RESET = "\033[0m"

WIDTH = 80


def fmt_sign(v: float, width: int = 7) -> str:
    """Format a float with explicit sign."""
    return f"{v:+{width}.3f}"


def audit_biome(biome: dict, factions: list[dict], verbose: bool = True):
    """Full audit of a single biome. Returns summary dict."""
    name = biome["name"]
    emojis = biome["emojis"]

    if not emojis:
        if verbose:
            print(f"{RED}  {name}: no emojis defined{RESET}")
        return {"name": name, "emojis": 0, "axes": 0, "profiled": False, "issues": ["no emojis"]}

    # Pair emojis into axes
    pairs = []
    for i in range(0, len(emojis), 2):
        north = emojis[i]
        south = emojis[i + 1] if i + 1 < len(emojis) else emojis[i]
        pairs.append((north, south))

    # Compute baselines
    norms = compute_frobenius_norms(factions, emojis)
    se_base, coupling_base, coupling_imag, driver_base = compute_faction_baselines(factions, emojis, norms)

    # Load profile
    profile = load_profile(name)
    has_profile = bool(profile["self_energies"] or profile["couplings"] or profile["drivers"])

    # Compute effective values
    se_eff = {e: se_base[e] + profile["self_energies"].get(e, 0.0) for e in emojis}

    # Coupling effective values (profile adds to baseline)
    coupling_eff = dict(coupling_base)
    for src, targets in profile.get("couplings", {}).items():
        if isinstance(targets, dict):
            for tgt, delta in targets.items():
                key = tuple(sorted([src, tgt]))
                coupling_eff.setdefault(key, 0.0)
                coupling_eff[key] += delta

    issues = []
    if not has_profile:
        issues.append("no .jsonl profile")

    if verbose:
        print()
        print(f"{BOLD}{'═' * WIDTH}{RESET}")
        print(f"{BOLD}  {name} — {len(emojis)} emojis, {len(pairs)} axes{RESET}")
        if has_profile:
            print(f"  {GREEN}Profile: {name.lower()}.jsonl ✓{RESET}")
        else:
            print(f"  {YELLOW}Profile: none (raw faction baseline){RESET}")
        print(f"  {DIM}Factions with overlap: {len(norms)} of {len(factions)}{RESET}")
        print(f"{BOLD}{'═' * WIDTH}{RESET}")

        # Per-axis table
        for qi, (north, south) in enumerate(pairs):
            detuning_base = se_base[north] - se_base[south]
            detuning_eff = se_eff[north] - se_eff[south]
            rabi_key = tuple(sorted([north, south]))
            rabi_base_val = coupling_base.get(rabi_key, 0.0)
            rabi_eff_val = coupling_eff.get(rabi_key, 0.0)
            prof_n = profile["self_energies"].get(north, 0.0)
            prof_s = profile["self_energies"].get(south, 0.0)
            prof_rabi = rabi_eff_val - rabi_base_val

            t_real = rabi_period(abs(rabi_eff_val), abs(detuning_eff))
            max_pop = max_minority_population(abs(rabi_eff_val), abs(detuning_eff))

            # Driven?
            driven_str = ""
            for pole in (north, south):
                drv = profile.get("drivers", {}).get(pole) or driver_base.get(pole)
                if drv:
                    freq = drv.get("frequency") or drv.get("freq", 0)
                    dtype = drv.get("type", "?")
                    if freq > 0:
                        t_drv = 1.0 / freq / 0.5  # real-time
                        driven_str = f"  ⚡{dtype}@{t_drv:.0f}s"

            print()
            print(f"  {CYAN}Q{qi}: {north} / {south}{RESET}{driven_str}")
            print(f"  {'':4s}{'fac_base':>10s}  {'profile':>10s}  {'effective':>10s}")
            print(f"  {north:4s}{fmt_sign(se_base[north]):>10s}  {fmt_sign(prof_n):>10s}  {fmt_sign(se_eff[north]):>10s}")
            print(f"  {south:4s}{fmt_sign(se_base[south]):>10s}  {fmt_sign(prof_s):>10s}  {fmt_sign(se_eff[south]):>10s}")
            print(f"  {'Δ':4s}{fmt_sign(detuning_base):>10s}  {'':>10s}  {fmt_sign(detuning_eff):>10s}")
            print(f"  {'Rabi':4s}{fmt_sign(rabi_base_val):>10s}  {fmt_sign(prof_rabi):>10s}  {fmt_sign(rabi_eff_val):>10s}")

            # Diagnostics
            if abs(rabi_eff_val) < 0.01:
                flag = f"{RED}  ⚠ FROZEN — near-zero Rabi coupling{RESET}"
                issues.append(f"Q{qi} {north}/{south}: frozen (Rabi≈0)")
            elif t_real > 200:
                flag = f"{YELLOW}  ⚠ Very slow oscillation: T={t_real:.0f}s{RESET}"
                issues.append(f"Q{qi} {north}/{south}: very slow (T={t_real:.0f}s)")
            elif abs(detuning_eff) < 0.05 and not driven_str:
                flag = f"{YELLOW}  ⚠ Near-degenerate (Δ≈0) — 50/50 flip{RESET}"
                issues.append(f"Q{qi} {north}/{south}: degenerate")
            else:
                flag = ""

            print(f"  T_real={t_real:>6.1f}s   max_{south}={max_pop:>5.1%}{flag}")

        # Cross-axis couplings
        cross = []
        for (src, tgt), val in sorted(coupling_eff.items()):
            # Skip intra-axis (Rabi) couplings
            is_rabi = False
            for (n, s) in pairs:
                if tuple(sorted([n, s])) == tuple(sorted([src, tgt])):
                    is_rabi = True
                    break
            if not is_rabi and abs(val) > 0.001:
                cross.append((src, tgt, val))

        if cross:
            print(f"\n  {BOLD}Cross-axis couplings (re | im):{RESET}")
            for src, tgt, val in cross:
                origin = "fac" if abs(coupling_base.get((src, tgt), 0.0)) > 0.001 else "prof"
                im = coupling_imag.get(tuple(sorted([src, tgt])), 0.0)
                im_str = f"  chiral {fmt_sign(im)}" if abs(im) > 0.01 else ""
                print(f"    {src}↔{tgt}  {fmt_sign(val)}{im_str}  ({origin})")
        else:
            print(f"\n  {DIM}No cross-axis couplings{RESET}")
            issues.append("no cross-axis couplings")

        # Archetype signature + Lindblad summary
        sig = compute_signature(biome, factions)
        archetype = classify_archetype(sig)
        lind = extract_biome_lindblad(biome)
        print(f"\n  {BOLD}Dynamic signature:{RESET}")
        print(f"    archetype           = {CYAN}{archetype}{RESET}")
        print(f"    chirality           = {sig['chirality']:.2f}  (max edge {sig['chirality_max']:.2f})")
        print(f"    coherent |H|        = {sig['coherent_mag']:.2f}")
        print(f"    Lindblad total      = {sig['total_l']:.3f}  (pump {sig['pump_rate']:.3f} / drain {sig['drain_rate']:.3f} / gated {sig['gated_rate']:.3f})")
        print(f"    L/H ratio           = {sig['l_over_h']:.2f}")
        print(f"    rabi-active frac    = {sig['rabi_active_frac']:.2f}")
        print(f"    components          = {sig['n_components']}  (isolated {sig['isolated']})")
        print(f"    max degree / hub    = {sig['max_deg']}  ({'yes' if sig['has_hub'] else 'no'})")
        print(f"    SE var / range      = {sig['se_var']:.3f} / {sig['se_range']:.2f}  (neg frac {sig['se_neg_frac']:.2f})")
        if lind['drains'] or lind['pumps'] or lind['decays'] or lind['gated']:
            print(f"  {BOLD}Lindblad ops:{RESET}")
            for s, t, r in lind['pumps']:
                print(f"    pump    {s}→{t}  {r:.3f}")
            for s, t, r in lind['drains']:
                print(f"    drain   {s}→{t}  {r:.3f}")
            for s, t, r in lind['decays']:
                print(f"    decay   {s}→{t}  {r:.3f}")
            for s, t, g, r, p, inv in lind['gated']:
                print(f"    gated   {s}→{t} gate={g} rate={r:.3f} pow={p} {'inv' if inv else ''}")

        # Faction coverage summary
        print(f"\n  {BOLD}Faction coverage per emoji:{RESET}")
        for emoji in emojis:
            speakers = [fac["name"] for fac in factions if faction_speaks(fac, emoji) and fac["name"] in norms]
            count = len(speakers)
            bar = "█" * min(count, 30) + f" {count}"
            color = RED if count == 0 else (YELLOW if count <= 2 else "")
            reset = RESET if color else ""
            print(f"    {emoji}  {color}{bar}{reset}")
            if count == 0:
                issues.append(f"{emoji}: orphan (0 factions)")

        if issues:
            print(f"\n  {YELLOW}Issues:{RESET}")
            for issue in issues:
                print(f"    • {issue}")

        print()

    return {
        "name": name,
        "emojis": len(emojis),
        "axes": len(pairs),
        "profiled": has_profile,
        "factions_overlap": len(norms),
        "issues": issues,
    }


def summary_table(biomes: list[dict], factions: list[dict]):
    """Print a compact summary of all biomes."""
    print(f"\n{BOLD}{'Biome':<28s} {'Emojis':>6s} {'Axes':>5s} {'Factions':>8s} {'Profile':>8s} {'Issues':>6s}{RESET}")
    print("─" * 68)
    total_profiled = 0
    total_issues = 0
    for b in sorted(biomes, key=lambda x: x["name"]):
        result = audit_biome(b, factions, verbose=False)
        profiled = "✓" if result["profiled"] else "—"
        if result["profiled"]:
            total_profiled += 1
        n_issues = len(result["issues"])
        total_issues += n_issues
        issue_str = str(n_issues) if n_issues > 0 else ""
        color = GREEN if result["profiled"] else ""
        reset = RESET if color else ""
        print(f"  {color}{result['name']:<26s}{reset} {result['emojis']:>6d} {result['axes']:>5d} {result.get('factions_overlap', 0):>8d} {profiled:>8s} {issue_str:>6s}")
    print("─" * 68)
    print(f"  {BOLD}{len(biomes)} biomes | {total_profiled} profiled | {total_issues} total issues{RESET}")
    print()


# ── CLI ──────────────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    factions = load_factions()
    biomes = load_biomes()
    biome_map = {b["name"].lower(): b for b in biomes}

    arg = sys.argv[1]

    if arg == "--list":
        for b in sorted(biomes, key=lambda x: x["name"]):
            emojis = " ".join(b["emojis"])
            profiled = "✓" if (HAMILTONIANS_DIR / f"{b['name'].lower()}.jsonl").exists() else " "
            print(f"  [{profiled}] {b['name']:<28s} {emojis}")
        return

    if arg == "--all":
        summary_table(biomes, factions)
        return

    if arg == "--census":
        # Classify every biome by archetype, print sorted table + histogram
        from collections import Counter
        rows = []
        for b in biomes:
            if b['name'] == '_orphan_lindblads':
                continue
            sig = compute_signature(b, factions)
            if not sig:
                continue
            arch = classify_archetype(sig)
            rows.append((arch, b['name'], sig))
        rows.sort(key=lambda r: (r[0], r[1]))

        hist = Counter(r[0] for r in rows)
        print(f"\n{BOLD}Archetype census across {len(rows)} biomes{RESET}")
        print("─" * 72)
        print(f"  {'archetype':<15s} {'biome':<22s} {'chiral':>7s} {'|H|':>6s} {'L/H':>6s} {'Rabi%':>6s} {'SE−':>5s} {'comp':>5s}")
        print("─" * 72)
        for arch, name, sig in rows:
            print(f"  {arch:<15s} {name:<22s} {sig['chirality']:>7.2f} {sig['coherent_mag']:>6.2f} "
                  f"{min(sig['l_over_h'], 99.0):>6.2f} {sig['rabi_active_frac']*100:>5.0f}% "
                  f"{sig['se_neg_frac']:>5.2f} {sig['n_components']:>5d}")
        print("─" * 72)
        print(f"\n{BOLD}Histogram:{RESET}")
        for arch, n in sorted(hist.items(), key=lambda x: -x[1]):
            bar = "█" * n
            print(f"  {arch:<16s} {bar} {n}")
        return

    # Single biome audit
    key = arg.lower()
    biome = biome_map.get(key)
    if not biome:
        # Fuzzy match
        matches = [b for name, b in biome_map.items() if key in name]
        if len(matches) == 1:
            biome = matches[0]
        elif len(matches) > 1:
            print(f"Ambiguous: {', '.join(m['name'] for m in matches)}")
            sys.exit(1)
        else:
            print(f"Biome '{arg}' not found. Use --list to see all biomes.")
            sys.exit(1)

    audit_biome(biome, factions)


if __name__ == "__main__":
    main()
