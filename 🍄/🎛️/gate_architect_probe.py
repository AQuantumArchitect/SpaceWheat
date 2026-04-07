#!/usr/bin/env python3
"""
gate_architect_probe.py — StarterForest Hamiltonian inspector

Loads Core/Config/Hamiltonians/starterforest.jsonl, builds the 32×32 Hamiltonian
in Python/numpy, and reports:

  1. Eigenspectrum — energy levels, gaps, degeneracies
  2. Rabi map     — effective coupling and period for every emoji pair
  3. Gate effect  — what each gate does to each qubit starting from |uniform⟩
  4. Resonance    — when the driven ☀ axis crosses resonance with 🌙 (Landau-Zener)
  5. Reachability — which basis states are most reachable from uniform superposition

Usage:
  python3 gate_architect_probe.py [--json] [--biome starterforest]

Output:
  Human-readable report to stdout, or JSON if --json flag passed.

Role in asymmetric play:
  This is the Gate Architect's tool. Runners never need it.
  Biome Crafters use it to verify their JSONL changes produce interesting physics.
"""

import sys
import json
import math
import argparse
from pathlib import Path

try:
    import numpy as np
    from scipy.linalg import expm
    HAS_SCIPY = True
except ImportError:
    HAS_SCIPY = False
    try:
        import numpy as np
    except ImportError:
        print("ERROR: numpy required. pip install numpy", file=sys.stderr)
        sys.exit(1)

# ── Repository root (two levels up from 🍄/🎛️/) ──────────────────────────
REPO_ROOT = Path(__file__).resolve().parent.parent.parent


# ══════════════════════════════════════════════════════════════════════════════
# JSONL loader
# ══════════════════════════════════════════════════════════════════════════════

def load_hamiltonian_jsonl(biome_name: str) -> dict:
    """Load and parse a biome Hamiltonian JSONL profile."""
    path = REPO_ROOT / "Core" / "Config" / "Hamiltonians" / f"{biome_name.lower()}.jsonl"
    if not path.exists():
        raise FileNotFoundError(f"No Hamiltonian profile found: {path}")

    data = {"self_energies": {}, "couplings": {}, "drivers": {}}

    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        try:
            row = json.loads(stripped)
        except json.JSONDecodeError:
            continue
        if row.get("op") != "set":
            continue
        path_str = row.get("path", "")
        value = row.get("value")
        if path_str and value is not None:
            _set_nested(data, path_str, value)

    return data


def _set_nested(d: dict, path_str: str, value):
    parts = path_str.split(".")
    node = d
    for part in parts[:-1]:
        node = node.setdefault(part, {})
    node[parts[-1]] = value


# ══════════════════════════════════════════════════════════════════════════════
# Hamiltonian builder (mirrors HamiltonianBuilder.gd logic)
# ══════════════════════════════════════════════════════════════════════════════

# StarterForest register: (qubit_index, pole: 0=north 1=south)
AXES = [
    ("☀", "🌙"),   # Q0 celestial
    ("🐺", "🐇"),  # Q1 predator-prey
    ("🦅", "🦌"),  # Q2 apex-grazer
    ("🌲", "🍂"),  # Q3 growth-decay
    ("🌱", "🌿"),  # Q4 ground-growth
]

NUM_QUBITS = len(AXES)
DIM = 2 ** NUM_QUBITS  # 32

EMOJI_MAP: dict[str, tuple[int, int]] = {}  # emoji → (qubit, pole)
for _q, (_n, _s) in enumerate(AXES):
    EMOJI_MAP[_n] = (_q, 0)
    EMOJI_MAP[_s] = (_q, 1)

EMOJI_NAMES = {
    "☀": "Sun", "🌙": "Moon",
    "🐺": "Wolf", "🐇": "Rabbit",
    "🦅": "Eagle", "🦌": "Deer",
    "🌲": "Tree", "🍂": "Leaves",
    "🌱": "Sprout", "🌿": "Herb",
}


def build_hamiltonian(profile: dict, time: float = 0.0) -> np.ndarray:
    """Build 32×32 complex Hermitian Hamiltonian from profile dict."""
    H = np.zeros((DIM, DIM), dtype=complex)
    se = profile.get("self_energies", {})
    co = profile.get("couplings", {})
    dr = profile.get("drivers", {})

    # Self-energies (diagonal) — apply drivers if present
    for emoji, base_e in se.items():
        if emoji not in EMOJI_MAP:
            continue
        q, p = EMOJI_MAP[emoji]
        shift = NUM_QUBITS - 1 - q

        # Time-dependent driver
        energy = float(base_e)
        if emoji in dr:
            d = dr[emoji]
            dtype = d.get("type", "")
            freq = float(d.get("frequency", 0.0))
            phase = float(d.get("phase", 0.0))
            amp = float(d.get("amplitude", 1.0))
            if dtype == "cosine":
                energy = energy * amp * math.cos(2 * math.pi * freq * time + phase)
            elif dtype == "sine":
                energy = energy * amp * math.sin(2 * math.pi * freq * time + phase)

        for i in range(DIM):
            if ((i >> shift) & 1) == p:
                H[i, i] += energy

    # Couplings (off-diagonal)
    for src_emoji, targets in co.items():
        if src_emoji not in EMOJI_MAP:
            continue
        if not isinstance(targets, dict):
            continue
        q_src, p_src = EMOJI_MAP[src_emoji]
        shift_src = NUM_QUBITS - 1 - q_src

        for tgt_emoji, strength in targets.items():
            if tgt_emoji not in EMOJI_MAP:
                continue
            q_tgt, p_tgt = EMOJI_MAP[tgt_emoji]
            shift_tgt = NUM_QUBITS - 1 - q_tgt
            s = float(strength)

            if q_src == q_tgt:
                # Same qubit σ_x: flip between north and south
                if p_src != p_tgt:
                    for i in range(DIM):
                        if ((i >> shift_src) & 1) == p_src:
                            j = i ^ (1 << shift_src)
                            H[i, j] += s
            else:
                # Different qubits: correlated 2-qubit flip
                for i in range(DIM):
                    b_src = (i >> shift_src) & 1
                    b_tgt = (i >> shift_tgt) & 1
                    if b_src == p_src and b_tgt == p_tgt:
                        j = i ^ (1 << shift_src) ^ (1 << shift_tgt)
                        H[i, j] += s

    # Hermitianize: H = (H + H†) / 2
    H = (H + H.conj().T) / 2
    return H


def basis_label(idx: int) -> str:
    """Human-readable label for a basis state index."""
    emojis = []
    for q in range(NUM_QUBITS):
        shift = NUM_QUBITS - 1 - q
        pole = (idx >> shift) & 1
        emojis.append(AXES[q][pole])
    return "".join(emojis)


def gate_matrix_1q(name: str) -> np.ndarray:
    """Return 2×2 gate matrix for a named 1-qubit gate."""
    s2 = 1.0 / math.sqrt(2)
    gates = {
        "X":   np.array([[0, 1], [1, 0]], dtype=complex),
        "Y":   np.array([[0, -1j], [1j, 0]], dtype=complex),
        "Z":   np.array([[1, 0], [0, -1]], dtype=complex),
        "H":   np.array([[s2, s2], [s2, -s2]], dtype=complex),
        "S":   np.array([[1, 0], [0, 1j]], dtype=complex),
        "Sdg": np.array([[1, 0], [0, -1j]], dtype=complex),
        "T":   np.array([[1, 0], [0, complex(s2, s2)]], dtype=complex),
        "Tdg": np.array([[1, 0], [0, complex(s2, -s2)]], dtype=complex),
        "Rx":  np.array([[math.cos(math.pi/8), -1j*math.sin(math.pi/8)],
                          [-1j*math.sin(math.pi/8), math.cos(math.pi/8)]], dtype=complex),
        "Ry":  np.array([[math.cos(math.pi/8), -math.sin(math.pi/8)],
                          [math.sin(math.pi/8), math.cos(math.pi/8)]], dtype=complex),
        "Rz":  np.array([[complex(math.cos(math.pi/8), -math.sin(math.pi/8)), 0],
                          [0, complex(math.cos(math.pi/8), math.sin(math.pi/8))]], dtype=complex),
    }
    return gates[name]


def embed_1q_gate(gate_2x2: np.ndarray, qubit: int) -> np.ndarray:
    """Embed 2×2 gate into DIM×DIM space for the given qubit index (MSB convention)."""
    # Build full unitary via tensor product: I⊗...⊗G⊗...⊗I
    ops = [np.eye(2, dtype=complex)] * NUM_QUBITS
    ops[qubit] = gate_2x2
    result = ops[0]
    for op in ops[1:]:
        result = np.kron(result, op)
    return result


def apply_gate_to_rho(U: np.ndarray, rho: np.ndarray) -> np.ndarray:
    return U @ rho @ U.conj().T


def evolve_rho(H: np.ndarray, rho: np.ndarray, dt: float) -> np.ndarray:
    """Evolve density matrix under Hamiltonian for time dt."""
    if HAS_SCIPY:
        U = expm(-1j * H * dt)
    else:
        # Fall back to first-order Cayley
        n = H.shape[0]
        A = np.eye(n, dtype=complex) - 1j * H * dt / 2
        B = np.eye(n, dtype=complex) + 1j * H * dt / 2
        U = np.linalg.solve(A, B)
    return U @ rho @ U.conj().T


def populations(rho: np.ndarray) -> dict[str, float]:
    """Return emoji populations (probability of each emoji being 'active')."""
    pops = {}
    for emoji, (q, p) in EMOJI_MAP.items():
        shift = NUM_QUBITS - 1 - q
        total = 0.0
        for i in range(DIM):
            if ((i >> shift) & 1) == p:
                total += rho[i, i].real
        pops[emoji] = total
    return pops


# ══════════════════════════════════════════════════════════════════════════════
# Analysis functions
# ══════════════════════════════════════════════════════════════════════════════

def analyse_spectrum(H: np.ndarray) -> dict:
    eigenvalues = np.linalg.eigvalsh(H)
    eigenvalues = np.sort(eigenvalues)
    gaps = np.diff(eigenvalues)
    return {
        "min": float(eigenvalues[0]),
        "max": float(eigenvalues[-1]),
        "spread": float(eigenvalues[-1] - eigenvalues[0]),
        "mean_gap": float(np.mean(gaps)),
        "min_gap": float(np.min(gaps)),
        "nonzero_eigenvalues": int(np.sum(np.abs(eigenvalues) > 1e-8)),
        "eigenvalues": [round(float(e), 4) for e in eigenvalues[:16]],  # first 16
    }


def build_rabi_map(profile: dict) -> list[dict]:
    """For every emoji pair in the profile, compute effective Rabi parameters."""
    H = build_hamiltonian(profile, time=0.0)
    co = profile.get("couplings", {})
    se = profile.get("self_energies", {})
    results = []

    # Intra-axis: same-qubit pairs
    for q, (north, south) in enumerate(AXES):
        coupling = 0.0
        targets = co.get(north, {})
        if isinstance(targets, dict):
            coupling = float(targets.get(south, 0.0))
        e_n = float(se.get(north, 0.0))
        e_s = float(se.get(south, 0.0))
        detuning = abs(e_n - e_s)
        rabi = math.sqrt(coupling**2 + (detuning / 2) ** 2)
        period = 2 * math.pi / rabi if rabi > 1e-10 else float("inf")
        results.append({
            "pair": f"{north}/{south}",
            "type": "intra-axis",
            "qubit": q,
            "coupling": round(coupling, 4),
            "detuning": round(detuning, 4),
            "rabi_freq": round(rabi, 4),
            "period_s": round(period, 2),
        })

    # Cross-axis: different-qubit pairs
    for src_emoji, targets in co.items():
        if not isinstance(targets, dict) or src_emoji not in EMOJI_MAP:
            continue
        q_src = EMOJI_MAP[src_emoji][0]
        for tgt_emoji, strength in targets.items():
            if tgt_emoji not in EMOJI_MAP:
                continue
            q_tgt = EMOJI_MAP[tgt_emoji][0]
            if q_src == q_tgt:
                continue  # Already handled above
            results.append({
                "pair": f"{src_emoji}→{tgt_emoji}",
                "type": "cross-axis",
                "qubits": f"Q{q_src}↔Q{q_tgt}",
                "coupling": round(float(strength), 4),
            })

    return results


def analyse_resonance_windows(profile: dict) -> list[dict]:
    """Find times when the driven ☀ axis crosses resonance with 🌙."""
    dr = profile.get("drivers", {})
    se = profile.get("self_energies", {})
    co = profile.get("couplings", {})
    windows = []

    for emoji, drv in dr.items():
        if not isinstance(drv, dict):
            continue
        dtype = drv.get("type", "")
        if dtype not in ("cosine", "sine"):
            continue

        # Find opposite-pole partner
        q, p = EMOJI_MAP[emoji]
        partner = AXES[q][1 - p]
        freq = float(drv.get("frequency", 0.0))
        amp = float(drv.get("amplitude", 1.0))
        phase = float(drv.get("phase", 0.0))
        base_e = float(se.get(emoji, 0.0))
        partner_e = float(se.get(partner, 0.0))
        coupling = float(co.get(emoji, {}).get(partner, 0.0))

        period = 1.0 / freq if freq > 1e-10 else float("inf")

        # Resonance when driven energy == partner energy
        # E_driven(t) = base * amp * cos(2π*freq*t + phase) = partner_e
        # cos(x) = partner_e / (base * amp)
        if abs(base_e * amp) < 1e-10:
            continue
        ratio = partner_e / (base_e * amp)
        if abs(ratio) > 1.0:
            resonance_times = []
        else:
            x0 = math.acos(ratio)
            x1 = -x0
            two_pi_f = 2 * math.pi * freq
            t0 = (x0 - phase) / two_pi_f % period
            t1 = (x1 - phase) / two_pi_f % period
            resonance_times = sorted(set([round(t0, 2), round(t1, 2)]))

        # Rabi freq AT resonance (min detuning = 0 → Ω = coupling)
        rabi_at_res = coupling
        lz_period_at_res = 2 * math.pi / rabi_at_res if rabi_at_res > 1e-10 else float("inf")

        windows.append({
            "driven": emoji,
            "partner": partner,
            "driver_type": dtype,
            "driver_freq_hz": freq,
            "day_period_s": round(period, 2),
            "resonance_times_s": resonance_times,
            "rabi_at_resonance": round(rabi_at_res, 4),
            "full_flip_period_at_res_s": round(lz_period_at_res, 2),
            "note": "Full population inversion possible only at resonance crossing",
        })

    return windows


def ground_state_rho(H: np.ndarray) -> np.ndarray:
    """Return density matrix for the ground state (lowest eigenvalue eigenstate)."""
    eigenvalues, eigenvectors = np.linalg.eigh(H)
    gs = eigenvectors[:, 0]  # lowest eigenvalue column
    return np.outer(gs, gs.conj())


def north_pole_rho() -> np.ndarray:
    """Pure state |00000⟩ — all qubits in north pole. Good for gate effect testing."""
    psi = np.zeros(DIM, dtype=complex)
    psi[0] = 1.0  # |00000⟩
    return np.outer(psi, psi.conj())


def analyse_gate_effects(profile: dict) -> list[dict]:
    """For each 1-qubit gate × each qubit, report population changes.

    Starts from the Hamiltonian ground state (not uniform superposition, which
    is invariant under all unitaries and would show no change).
    Also tests from |00000⟩ (all north poles) for a second perspective.
    """
    H = build_hamiltonian(profile, time=0.0)
    one_q_gates = ["X", "Y", "Z", "H", "S", "T", "Rx", "Ry", "Rz"]
    results = []

    # Starting states: ground state (interesting) and |00000⟩ (pedagogical)
    rho_ground = ground_state_rho(H)
    rho_north = north_pole_rho()

    # Quarter of the celestial Rabi period (to see trajectory mid-oscillation)
    se = profile.get("self_energies", {})
    co = profile.get("couplings", {})
    sun_moon_coupling = float(co.get("☀", {}).get("🌙", 0.8))
    e_sun = float(se.get("☀", 0.8))
    e_moon = float(se.get("🌙", -0.8))
    rabi_0 = math.sqrt(sun_moon_coupling**2 + ((e_sun - e_moon) / 2) ** 2)
    quarter_period = math.pi / (2 * rabi_0) if rabi_0 > 0 else 1.0

    for start_name, rho_start in [("ground", rho_ground), ("north_pole", rho_north)]:
        pops_before = populations(rho_start)
        purity_before = float(np.trace(rho_start @ rho_start).real)

        for gate_name in one_q_gates:
            G_2x2 = gate_matrix_1q(gate_name)
            for q in range(NUM_QUBITS):
                north_emoji, south_emoji = AXES[q]
                G_full = embed_1q_gate(G_2x2, q)

                rho_after_gate = apply_gate_to_rho(G_full, rho_start)
                rho_evolved = evolve_rho(H, rho_after_gate, quarter_period)

                pops_after = populations(rho_after_gate)
                pops_evolved = populations(rho_evolved)

                delta_north = pops_after[north_emoji] - pops_before[north_emoji]
                delta_south = pops_after[south_emoji] - pops_before[south_emoji]
                purity_after = float(np.trace(rho_after_gate @ rho_after_gate).real)
                total_shift = abs(delta_north) + abs(delta_south)

                results.append({
                    "start": start_name,
                    "gate": gate_name,
                    "qubit": q,
                    "axis": f"{north_emoji}/{south_emoji}",
                    "delta_north": round(delta_north, 5),
                    "delta_south": round(delta_south, 5),
                    "purity_before": round(purity_before, 6),
                    "purity_after": round(purity_after, 6),
                    "purity_delta": round(purity_after - purity_before, 6),
                    "interest_score": round(total_shift, 5),
                })

    return sorted(results, key=lambda r: -r["interest_score"])


def analyse_reachability(profile: dict) -> list[dict]:
    """
    Starting from uniform superposition, evolve under H for increasing times.
    Report which basis states become significantly populated.
    """
    H = build_hamiltonian(profile, time=0.0)
    rho = np.eye(DIM, dtype=complex) / DIM

    # Sample populations at t = 0, 5, 10, 15, 20s
    times = [0, 5, 10, 15, 20]
    snapshots = []
    for t in times:
        rho_t = evolve_rho(H, rho, float(t))
        diag = [rho_t[i, i].real for i in range(DIM)]
        top_states = sorted(enumerate(diag), key=lambda x: -x[1])[:6]
        snapshots.append({
            "time_s": t,
            "top_states": [
                {"state": basis_label(idx), "prob": round(p, 5)}
                for idx, p in top_states
            ],
            "max_prob": round(max(diag), 5),
            "purity": round(float(np.trace(rho_t @ rho_t).real), 6),
        })

    return snapshots


# ══════════════════════════════════════════════════════════════════════════════
# Report formatting
# ══════════════════════════════════════════════════════════════════════════════

def print_human_report(biome_name: str, profile: dict, results: dict):
    H = results["hamiltonian"]
    sep = "─" * 72

    print(f"\n{'═' * 72}")
    print(f"  Gate Architect Probe — {biome_name}")
    print(f"{'═' * 72}")

    # Flatness check
    spec = results["spectrum"]
    print(f"\n{'[ EIGENSPECTRUM ]':─<72}")
    print(f"  Spread:        {spec['spread']:.4f}  (0 = perfectly flat)")
    print(f"  Range:         [{spec['min']:.4f}, {spec['max']:.4f}]")
    print(f"  Mean gap:      {spec['mean_gap']:.4f}")
    print(f"  Min gap:       {spec['min_gap']:.4f}")
    print(f"  Non-zero eigv: {spec['nonzero_eigenvalues']} / {DIM}")
    print(f"  First 16 eigenvalues: {spec['eigenvalues']}")
    if spec["spread"] < 0.01:
        print("  ⚠ WARNING: Hamiltonian is nearly flat — no coherent dynamics!")
    elif spec["spread"] < 0.5:
        print("  ℹ Moderate spread — gentle oscillations")
    else:
        print("  ✓ Rich spectrum — interesting coherent dynamics")

    # Rabi map
    print(f"\n{'[ RABI MAP ]':─<72}")
    intra = [r for r in results["rabi_map"] if r["type"] == "intra-axis"]
    cross = [r for r in results["rabi_map"] if r["type"] == "cross-axis"]
    print("  Intra-axis oscillations:")
    for r in sorted(intra, key=lambda x: x["rabi_freq"], reverse=True):
        print(f"    {r['pair']:<12}  coupling={r['coupling']:.3f}  "
              f"detuning={r['detuning']:.3f}  Rabi={r['rabi_freq']:.3f}  "
              f"period≈{r['period_s']:.1f}s")
    print("  Cross-axis correlations:")
    for r in sorted(cross, key=lambda x: -x["coupling"]):
        print(f"    {r['pair']:<14}  coupling={r['coupling']:.3f}  ({r['qubits']})")

    # Resonance windows
    print(f"\n{'[ RESONANCE WINDOWS ]':─<72}")
    for w in results["resonance_windows"]:
        print(f"  Driver:  {w['driven']} ({w['driver_type']}, "
              f"{w['driver_freq_hz']} Hz → day period={w['day_period_s']}s)")
        print(f"  Partner: {w['partner']}")
        if w["resonance_times_s"]:
            print(f"  Resonance crossings at: {w['resonance_times_s']} s")
            print(f"  Rabi freq at resonance: {w['rabi_at_resonance']:.3f} rad/s "
                  f"→ flip in {w['full_flip_period_at_res_s']:.1f}s")
        else:
            print("  No resonance crossing (partner energy outside driver range)")
        print(f"  Note: {w['note']}")

    # Gate effects (top movers)
    print(f"\n{'[ GATE EFFECTS — TOP 15 BY POPULATION SHIFT ]':─<72}")
    print(f"  {'Gate':<5} {'Q':<3} {'Axis':<12} {'Δnorth':>9} {'Δsouth':>9} "
          f"{'Δpurity':>10} {'interest':>10}")
    for r in results["gate_effects"][:15]:
        print(f"  {r['gate']:<5} Q{r['qubit']:<2} {r['axis']:<12} "
              f"{r['delta_north']:>9.5f} {r['delta_south']:>9.5f} "
              f"{r['purity_delta']:>10.6f} {r['interest_score']:>10.5f}")

    # Reachability
    print(f"\n{'[ STATE REACHABILITY FROM UNIFORM SUPERPOSITION ]':─<72}")
    for snap in results["reachability"]:
        print(f"  t={snap['time_s']}s  purity={snap['purity']:.4f}  "
              f"max_prob={snap['max_prob']:.4f}")
        for st in snap["top_states"]:
            print(f"    {st['state']}  {st['prob']:.5f}")

    print(f"\n{'═' * 72}\n")


# ══════════════════════════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(description="Gate Architect Probe")
    parser.add_argument("--biome", default="starterforest",
                        help="Biome name (default: starterforest)")
    parser.add_argument("--json", action="store_true",
                        help="Output JSON instead of human-readable report")
    args = parser.parse_args()

    profile = load_hamiltonian_jsonl(args.biome)
    H = build_hamiltonian(profile, time=0.0)

    results = {
        "biome": args.biome,
        "dim": DIM,
        "num_qubits": NUM_QUBITS,
        "hamiltonian": H,
        "spectrum": analyse_spectrum(H),
        "rabi_map": build_rabi_map(profile),
        "resonance_windows": analyse_resonance_windows(profile),
        "gate_effects": analyse_gate_effects(profile),
        "reachability": analyse_reachability(profile),
    }

    if args.json:
        # Remove non-serializable numpy array
        out = {k: v for k, v in results.items() if k != "hamiltonian"}
        print(json.dumps(out, indent=2, ensure_ascii=False))
    else:
        print_human_report(args.biome, profile, results)


if __name__ == "__main__":
    main()
