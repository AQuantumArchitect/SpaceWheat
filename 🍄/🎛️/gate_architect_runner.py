#!/usr/bin/env python3
"""
gate_architect_runner.py — Apply every gate type to StarterForest in a live game

Boots a headless Godot instance, discovers biome plot positions, then sweeps
every gate (11 single-qubit + 3 two-qubit + 3 entangled-state) across every
available qubit axis.  Reads probability_map observables before/after each
gate and after a short Hamiltonian evolution step.

Usage:
    python3 gate_architect_runner.py [options]

    --load-slot N       Save slot to load (default: 0)
    --biome NAME        Biome to target (default: StarterForest)
    --skip-warmup       Skip the initial Hamiltonian warmup
    --skip-2q           Skip 2-qubit gates (faster run)
    --skip-entangled    Skip bell/ghz/cluster
    --evolve-phrames N  Physics frames to evolve between gates (default: 45)
    --output-dir PATH   Write detailed JSON per gate here
    --verbose           Print verbose progress

Last stdout line is a JSON summary (machine-readable for gate_architect_batch).
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Any

from rig_client import RigClient
from milk_hunt_paths import project_root

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = project_root()

_RIG = RigClient(root_from_file=Path(__file__))

# ── Gate catalogue ────────────────────────────────────────────────────────────
GATES_1Q = [
    "pauli_x", "pauli_y", "pauli_z",
    "hadamard",
    "s_gate", "sdg",
    "t_gate", "tdg",
    "rx", "ry", "rz",
]
GATES_2Q = ["cnot", "cz", "swap"]
GATES_ENTANGLED = ["bell", "ghz", "cluster"]

# Gate family metadata for report labelling
GATE_FAMILY = {
    "pauli_x": "Pauli", "pauli_y": "Pauli", "pauli_z": "Pauli",
    "hadamard": "Clifford",
    "s_gate": "Phase", "sdg": "Phase",
    "t_gate": "T-gate", "tdg": "T-gate",
    "rx": "Rotation", "ry": "Rotation", "rz": "Rotation",
    "cnot": "Entangling", "cz": "Entangling", "swap": "Swap",
    "bell": "State-prep", "ghz": "State-prep", "cluster": "State-prep",
}

# How many positions each gate needs (minimum)
GATE_MIN_POSITIONS = {g: 1 for g in GATES_1Q}
GATE_MIN_POSITIONS.update({"cnot": 2, "cz": 2, "swap": 2})
GATE_MIN_POSITIONS.update({"bell": 2, "ghz": 3, "cluster": 2})


# ── IPC helpers ───────────────────────────────────────────────────────────────

def _run(turn_id: int, action: str, timeout_s: float = 15.0, **kw) -> dict:
    return _RIG.run_turn(turn_id, action, timeout_s=timeout_s, **kw)


def _snap(turn_id: int, biome: str) -> dict:
    """Read current probability_map for biome."""
    row = _run(turn_id, "probability_map", biome=biome, timeout_s=12.0)
    return row.get("probability_map", {})


def _evolve(turn_id: int, phrames: int) -> dict:
    """Skip forward N physics frames to let Hamiltonian evolve."""
    return _run(turn_id, "time_skip", phrames=phrames, timeout_s=60.0)


def _get_positions(turn_id: int, biome: str) -> list:
    """Return sorted list of plot positions [[x,y],...] for biome."""
    row = _run(turn_id, "biome_positions", biome=biome, timeout_s=15.0)
    raw = row.get("positions", [])
    result = []
    for p in raw:
        if isinstance(p, dict):
            result.append([int(p.get("x", 0)), int(p.get("y", 0))])
        elif isinstance(p, (list, tuple)) and len(p) >= 2:
            result.append([int(p[0]), int(p[1])])
        elif isinstance(p, str):
            # GDScript Vector2i serializes as "(x, y)"
            cleaned = p.strip("() ")
            parts = [s.strip() for s in cleaned.split(",")]
            if len(parts) == 2:
                try:
                    result.append([int(parts[0]), int(parts[1])])
                except ValueError:
                    pass
    return sorted(result)


# ── Population helpers ────────────────────────────────────────────────────────

def _extract_populations(pmap: dict) -> dict:
    """Extract emoji → float population dict from probability_map response.

    The response nests data as: pmap["map"]["by_emoji"] → {emoji: float, ...}
    Falls back to pmap["populations"] for older formats.
    """
    if not isinstance(pmap, dict):
        return {}
    # Primary format: pmap["map"]["by_emoji"]
    m = pmap.get("map")
    if isinstance(m, dict):
        by_emoji = m.get("by_emoji", {})
        if isinstance(by_emoji, dict):
            return {k: float(v) for k, v in by_emoji.items() if isinstance(v, (int, float))}
    return {}


def _pop_delta(before: dict, after: dict) -> dict:
    """Compute per-emoji population delta."""
    delta = {}
    for emoji in set(list(before.keys()) + list(after.keys())):
        b = float(before.get(emoji, 0.0))
        a = float(after.get(emoji, 0.0))
        if abs(a - b) > 1e-6:
            delta[emoji] = round(a - b, 5)
    return delta


def _max_shift(delta: dict) -> float:
    if not delta:
        return 0.0
    return max(abs(v) for v in delta.values())


def _purity(pmap: dict) -> float:
    if not isinstance(pmap, dict):
        return -1.0
    # Try direct purity key
    if "purity" in pmap:
        return float(pmap["purity"])
    # Try nested map.purity
    m = pmap.get("map")
    if isinstance(m, dict) and "purity" in m:
        return float(m["purity"])
    return -1.0


# ── Core sweep ────────────────────────────────────────────────────────────────

def _apply_gate(turn_id: int, gate: str, biome: str, positions: list) -> dict:
    """Send gate_inject action; return result dict."""
    return _run(turn_id, "gate_inject", gate=gate, biome=biome,
                positions=positions, timeout_s=15.0)


def _sweep_1q(turn_id_start: int, biome: str, positions: list,
              evolve_phrames: int, verbose: bool) -> tuple[int, list]:
    """Apply every 1Q gate to every position. Returns (next_turn_id, results)."""
    results = []
    tid = turn_id_start

    for gate in GATES_1Q:
        for i, pos in enumerate(positions):
            if verbose:
                print(f"  [1Q] {gate} @ Q{i} {pos}", flush=True)

            snap_before = _snap(tid, biome); tid += 1
            pops_before = _extract_populations(snap_before)

            gate_result = _apply_gate(tid, gate, biome, [pos]); tid += 1
            snap_after = _snap(tid, biome); tid += 1
            pops_after_gate = _extract_populations(snap_after)

            _evolve(tid, evolve_phrames); tid += 1
            snap_evolved = _snap(tid, biome); tid += 1
            pops_evolved = _extract_populations(snap_evolved)

            gate_ok = bool(gate_result.get("ok", False))
            applied = gate_result.get("gate_result", {}).get("applied_count", 0)

            results.append({
                "gate": gate,
                "family": GATE_FAMILY.get(gate, "other"),
                "arity": 1,
                "qubit_index": i,
                "position": pos,
                "ok": gate_ok,
                "applied_count": applied,
                "delta_gate": _pop_delta(pops_before, pops_after_gate),
                "delta_evolved": _pop_delta(pops_after_gate, pops_evolved),
                "max_shift_gate": _max_shift(_pop_delta(pops_before, pops_after_gate)),
                "max_shift_evolved": _max_shift(_pop_delta(pops_after_gate, pops_evolved)),
                "purity_before": _purity(snap_before),
                "purity_after_gate": _purity(snap_after),
                "purity_after_evolve": _purity(snap_evolved),
            })

    return tid, results


def _sweep_2q(turn_id_start: int, biome: str, positions: list,
              evolve_phrames: int, verbose: bool) -> tuple[int, list]:
    """Apply every 2Q gate to every adjacent position pair."""
    results = []
    tid = turn_id_start

    if len(positions) < 2:
        return tid, results

    # Build pairs: (0,1), (1,2), (2,3), ... and wrap-around (n-1, 0)
    pairs = []
    n = len(positions)
    for i in range(n):
        pairs.append((i, (i + 1) % n))

    for gate in GATES_2Q:
        for i, j in pairs:
            pos_pair = [positions[i], positions[j]]
            if verbose:
                print(f"  [2Q] {gate} @ Q{i}↔Q{j} {pos_pair}", flush=True)

            snap_before = _snap(tid, biome); tid += 1
            pops_before = _extract_populations(snap_before)

            gate_result = _apply_gate(tid, gate, biome, pos_pair); tid += 1
            snap_after = _snap(tid, biome); tid += 1
            pops_after_gate = _extract_populations(snap_after)

            _evolve(tid, evolve_phrames); tid += 1
            snap_evolved = _snap(tid, biome); tid += 1
            pops_evolved = _extract_populations(snap_evolved)

            gate_ok = bool(gate_result.get("ok", False))
            applied = gate_result.get("gate_result", {}).get("applied_count", 0)

            results.append({
                "gate": gate,
                "family": GATE_FAMILY.get(gate, "other"),
                "arity": 2,
                "qubit_pair": [i, j],
                "positions": pos_pair,
                "ok": gate_ok,
                "applied_count": applied,
                "delta_gate": _pop_delta(pops_before, pops_after_gate),
                "delta_evolved": _pop_delta(pops_after_gate, pops_evolved),
                "max_shift_gate": _max_shift(_pop_delta(pops_before, pops_after_gate)),
                "max_shift_evolved": _max_shift(_pop_delta(pops_after_gate, pops_evolved)),
                "purity_before": _purity(snap_before),
                "purity_after_gate": _purity(snap_after),
                "purity_after_evolve": _purity(snap_evolved),
            })

    return tid, results


def _sweep_entangled(turn_id_start: int, biome: str, positions: list,
                     evolve_phrames: int, verbose: bool) -> tuple[int, list]:
    """Apply bell/ghz/cluster state preparation sequences."""
    results = []
    tid = turn_id_start
    n = len(positions)

    gate_position_sets = []
    if n >= 2:
        gate_position_sets.append(("bell", positions[:2]))
    if n >= 3:
        gate_position_sets.append(("ghz", positions[:3]))
    if n >= 2:
        gate_position_sets.append(("cluster", positions[:n]))

    for gate, pos_set in gate_position_sets:
        if verbose:
            print(f"  [ENT] {gate} @ {len(pos_set)} positions", flush=True)

        snap_before = _snap(tid, biome); tid += 1
        pops_before = _extract_populations(snap_before)

        gate_result = _apply_gate(tid, gate, biome, pos_set); tid += 1
        snap_after = _snap(tid, biome); tid += 1
        pops_after_gate = _extract_populations(snap_after)

        _evolve(tid, evolve_phrames); tid += 1
        snap_evolved = _snap(tid, biome); tid += 1
        pops_evolved = _extract_populations(snap_evolved)

        gate_ok = bool(gate_result.get("ok", False))
        applied = gate_result.get("gate_result", {}).get("applied_count", 0)

        results.append({
            "gate": gate,
            "family": "State-prep",
            "arity": len(pos_set),
            "positions": pos_set,
            "ok": gate_ok,
            "applied_count": applied,
            "delta_gate": _pop_delta(pops_before, pops_after_gate),
            "delta_evolved": _pop_delta(pops_after_gate, pops_evolved),
            "max_shift_gate": _max_shift(_pop_delta(pops_before, pops_after_gate)),
            "max_shift_evolved": _max_shift(_pop_delta(pops_after_gate, pops_evolved)),
            "purity_before": _purity(snap_before),
            "purity_after_gate": _purity(snap_after),
            "purity_after_evolve": _purity(snap_evolved),
        })

    return tid, results


# ── Analysis helpers ──────────────────────────────────────────────────────────

def _build_summary(biome: str, positions: list, all_results: list,
                   baseline_pops: dict, final_pops: dict) -> dict:
    """Compute summary statistics across the full gate sweep."""
    gates_ok = [r for r in all_results if r.get("ok")]
    gates_failed = [r for r in all_results if not r.get("ok")]

    # Per-gate-type coverage
    coverage: dict[str, int] = {}
    for r in gates_ok:
        g = r["gate"]
        coverage[g] = coverage.get(g, 0) + 1

    # Gate with biggest single-step population shift
    top_by_shift = sorted(gates_ok, key=lambda r: -r["max_shift_gate"])[:5]
    top_movers = [
        {"gate": r["gate"], "qubit": r.get("qubit_index", r.get("qubit_pair")),
         "max_shift": round(r["max_shift_gate"], 5),
         "biggest_change": max(r["delta_gate"].items(), key=lambda x: abs(x[1]))
         if r["delta_gate"] else None}
        for r in top_by_shift
    ]

    # Purity effects
    purity_changes = [
        r["purity_after_gate"] - r["purity_before"]
        for r in gates_ok
        if r["purity_before"] >= 0 and r["purity_after_gate"] >= 0
    ]
    avg_purity_change = sum(purity_changes) / len(purity_changes) if purity_changes else 0.0

    # Gates that successfully applied
    gate_types_covered = set(r["gate"] for r in gates_ok)
    all_gate_types = set(GATES_1Q + GATES_2Q + GATES_ENTANGLED)

    return {
        "biome": biome,
        "positions_found": len(positions),
        "total_gate_ops": len(all_results),
        "gates_ok": len(gates_ok),
        "gates_failed": len(gates_failed),
        "coverage_by_gate": coverage,
        "gate_types_covered": sorted(gate_types_covered),
        "gate_types_missing": sorted(all_gate_types - gate_types_covered),
        "coverage_pct_1q": round(100 * len(set(r["gate"] for r in gates_ok if r["arity"] == 1)) / len(GATES_1Q)),
        "coverage_pct_2q": round(100 * len(set(r["gate"] for r in gates_ok if r["arity"] == 2)) / len(GATES_2Q)),
        "top_population_movers": top_movers,
        "avg_purity_change_per_gate": round(avg_purity_change, 6),
        "failed_gates": [{"gate": r["gate"], "error": r.get("error")} for r in gates_failed],
    }


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="Gate Architect Runner")
    parser.add_argument("--load-slot", type=int, default=0)
    parser.add_argument("--biome", default="StarterForest")
    parser.add_argument("--skip-warmup", action="store_true")
    parser.add_argument("--skip-2q", action="store_true")
    parser.add_argument("--skip-entangled", action="store_true")
    parser.add_argument("--evolve-phrames", type=int, default=45,
                        help="Physics frames to evolve after each gate (~0.75s at 60fps)")
    parser.add_argument("--output-dir", type=Path, default=None)
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    biome = args.biome
    verbose = args.verbose
    evolve_phrames = args.evolve_phrames
    output_dir = args.output_dir
    if output_dir:
        output_dir.mkdir(parents=True, exist_ok=True)

    def log(msg: str) -> None:
        if verbose:
            print(f"[gate_architect] {msg}", flush=True)

    # ── Start Godot ───────────────────────────────────────────────────────────
    log("Starting Godot listener...")
    proc = _RIG.start_listener(
        load_slot=args.load_slot,
        display_mode="headless",
        allow_resource_injection=True,
        listener_stdout="file",
        rig_log_profile="quiet",
    )

    log("Waiting for bridge ready...")
    if not RigClient.wait_for_bridge_sentinel(timeout_s=120.0, xdg=_RIG.xdg_root):
        print(json.dumps({"ok": False, "error": "godot_start_timeout"}))
        sys.exit(1)
    log("Godot ready.")

    tid = 1
    all_results = []
    try:
        # ── Discover positions ────────────────────────────────────────────────
        positions = _get_positions(tid, biome); tid += 1
        log(f"Found {len(positions)} positions for {biome}: {positions}")
        if not positions:
            print(json.dumps({"ok": False, "biome": biome, "error": "no_positions_found"}))
            return

        # ── Warmup: let Hamiltonian settle from uniform superposition ─────────
        if not args.skip_warmup:
            log("Warmup: evolving 120 phrames (~2s)...")
            _evolve(tid, 120); tid += 1

        # ── Baseline snapshot ─────────────────────────────────────────────────
        log("Taking baseline snapshot...")
        baseline_snap = _snap(tid, biome); tid += 1
        baseline_pops = _extract_populations(baseline_snap)
        log(f"Baseline purity: {_purity(baseline_snap):.4f}")

        # ── 1Q gate sweep ─────────────────────────────────────────────────────
        log(f"Sweeping {len(GATES_1Q)} × {len(positions)} = "
            f"{len(GATES_1Q)*len(positions)} single-qubit gate applications...")
        tid, results_1q = _sweep_1q(tid, biome, positions, evolve_phrames, verbose)
        all_results.extend(results_1q)
        log(f"1Q sweep complete. {len([r for r in results_1q if r['ok']])} succeeded.")

        # ── 2Q gate sweep ─────────────────────────────────────────────────────
        if not args.skip_2q and len(positions) >= 2:
            n_pairs = len(positions)  # wrap-around pairs
            log(f"Sweeping {len(GATES_2Q)} × {n_pairs} two-qubit gate pairs...")
            tid, results_2q = _sweep_2q(tid, biome, positions, evolve_phrames, verbose)
            all_results.extend(results_2q)
            log(f"2Q sweep complete. {len([r for r in results_2q if r['ok']])} succeeded.")

        # ── Entangled state prep ───────────────────────────────────────────────
        if not args.skip_entangled and len(positions) >= 2:
            log("Applying entangled state preparations (bell, ghz, cluster)...")
            tid, results_ent = _sweep_entangled(tid, biome, positions, evolve_phrames, verbose)
            all_results.extend(results_ent)
            log(f"Entangled prep complete. {len([r for r in results_ent if r['ok']])} succeeded.")

        # ── Final snapshot ────────────────────────────────────────────────────
        log("Taking final snapshot...")
        final_snap = _snap(tid, biome); tid += 1
        final_pops = _extract_populations(final_snap)

        # ── Build summary ─────────────────────────────────────────────────────
        summary = _build_summary(biome, positions, all_results, baseline_pops, final_pops)
        summary["ok"] = True
        summary["total_turns"] = tid
        summary["baseline_purity"] = _purity(baseline_snap)
        summary["final_purity"] = _purity(final_snap)

        # Write per-gate detail if requested
        if output_dir:
            detail_path = output_dir / "gate_results.json"
            detail_path.write_text(
                json.dumps({"biome": biome, "gate_results": all_results}, indent=2, ensure_ascii=False),
                encoding="utf-8"
            )
            summary_path = output_dir / "summary.json"
            summary_path.write_text(
                json.dumps(summary, indent=2, ensure_ascii=False),
                encoding="utf-8"
            )
            log(f"Wrote detail to {detail_path}")

    except Exception as exc:
        summary = {"ok": False, "error": str(exc), "biome": biome}

    finally:
        RigClient.terminate_listener(proc, timeout_s=10.0)

    # Last line = machine-readable JSON (for gate_architect_batch)
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
