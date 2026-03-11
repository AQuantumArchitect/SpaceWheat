#!/usr/bin/env python3
"""FibonacciAdversary — Python mirror of Core/AI/FibonacciAdversary.gd.

Adversarial graph tissue that mutates economy costs using Fibonacci-constrained
values, targeting a golden-ratio (φ-cascade) action distribution.

Usage:
    # After a milk hunt, read the summary and mutate:
    python3 fibonacci_adversary.py --summary path/to/batch_summary.json

    # Or pipe a summary JSON on stdin:
    cat summary.json | python3 fibonacci_adversary.py --stdin

    # Inspect current state:
    python3 fibonacci_adversary.py --show

    # Reset to defaults:
    python3 fibonacci_adversary.py --reset
"""
import hashlib
import json
import math
import os
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

# ── Constants ─────────────────────────────────────────────────────────

FIB = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233]
FIB_COUNT = 13
MAX_FIB_INDEX = 12
PHI = 1.6180339887498949

POLICY_ACTIONS = [
    "quest_cycle", "probe_cycle", "lindblad_drain", "time_skip",
    "discover_biome", "victory_lap_partial", "lock_offer", "channel_drain",
]

# ── Paths ─────────────────────────────────────────────────────────────

def _project_root(from_file: Optional[Path] = None) -> Path:
    f = from_file or Path(__file__)
    return f.resolve().parent.parent.parent


def default_ledger_path(from_file: Optional[Path] = None) -> Path:
    return _project_root(from_file) / "Core" / "Config" / "FarmVariableGraph" / "berry_ledger.jsonl"


def default_state_path(from_file: Optional[Path] = None) -> Path:
    return _project_root(from_file) / "Core" / "Config" / "FarmVariableGraph" / "adversary_state.json"


def default_patch_path(from_file: Optional[Path] = None) -> Path:
    return _project_root(from_file) / "Core" / "Config" / "FarmVariableGraph" / "adversary_patch.jsonl"


# ── Golden target ─────────────────────────────────────────────────────

def compute_golden_target(n: int) -> List[float]:
    """φ-cascade: rank k gets share ∝ 1/φ^(k+1), normalized to sum=1."""
    raw = [1.0 / PHI ** (k + 1) for k in range(n)]
    total = sum(raw)
    return [r / total for r in raw] if total > 0 else raw


GOLDEN_TARGET = compute_golden_target(len(POLICY_ACTIONS))


# ── Fibonacci helpers ─────────────────────────────────────────────────

def fib_value(index: int) -> int:
    return FIB[max(0, min(index, MAX_FIB_INDEX))]


def nearest_fib_index(value: int) -> int:
    best_idx = 0
    best_dist = abs(FIB[0] - value)
    for i in range(1, FIB_COUNT):
        dist = abs(FIB[i] - value)
        if dist < best_dist:
            best_dist = dist
            best_idx = i
    return best_idx


# ── Knob registry ────────────────────────────────────────────────────

# Each knob: (path, initial_value, affinity, tier, min_idx, max_idx)
DEFAULT_KNOBS: List[Tuple[str, int, str, int, int, int]] = [
    # Tier 1: action costs
    ("action_costs.explore.🍞",              1, "probe_cycle",         1, 0, MAX_FIB_INDEX),
    ("action_costs.measure.❄️",              1, "probe_cycle",         1, 0, MAX_FIB_INDEX),
    ("action_costs.pop.👥",                  1, "",                    1, 0, MAX_FIB_INDEX),
    ("action_costs.reap.🍼",                 1, "victory_lap_partial", 1, 0, MAX_FIB_INDEX),
    ("action_costs.quest_reroll.🐇",         1, "quest_cycle",         1, 0, MAX_FIB_INDEX),
    ("action_costs.quest_lock.🌲",           1, "lock_offer",          1, 0, MAX_FIB_INDEX),
    ("action_costs.explore_biome.🦅",        5, "discover_biome",      1, 0, MAX_FIB_INDEX),
    ("action_costs.remove_vocabulary.🐺",   21, "",                    1, 0, MAX_FIB_INDEX),
    ("action_costs.lindblad_pump.🌱",        8, "lindblad_drain",      1, 0, MAX_FIB_INDEX),
    ("action_costs.lindblad_drain.⚙",       2, "lindblad_drain",      1, 0, MAX_FIB_INDEX),
    # Tier 1: dynamic costs
    ("dynamic.lindblad_drain_gear_cost",      2, "lindblad_drain",      1, 0, MAX_FIB_INDEX),
    ("dynamic.lindblad_drain_south_cost",     8, "lindblad_drain",      1, 0, MAX_FIB_INDEX),
    ("dynamic.lindblad_pump_sprout_cost",     8, "lindblad_drain",      1, 0, MAX_FIB_INDEX),
    ("dynamic.lindblad_pump_north_cost",     34, "lindblad_drain",      1, 0, MAX_FIB_INDEX),
    ("dynamic.vocab_injection_south_cost",    5, "quest_cycle",         1, 0, MAX_FIB_INDEX),
    ("dynamic.vocab_injection_sprout_cost",   8, "quest_cycle",         1, 0, MAX_FIB_INDEX),
    # Tier 2: gate costs
    ("gate_costs.pauli_x.☀",   1, "", 2, 0, MAX_FIB_INDEX),
    ("gate_costs.pauli_y.🌙",  1, "", 2, 0, MAX_FIB_INDEX),
    ("gate_costs.pauli_z.🍂",  1, "", 2, 0, MAX_FIB_INDEX),
    ("gate_costs.hadamard.🔥", 1, "", 2, 0, MAX_FIB_INDEX),
    ("gate_costs.s_gate.🌱",   1, "", 2, 0, MAX_FIB_INDEX),
    ("gate_costs.t_gate.🌿",   1, "", 2, 0, MAX_FIB_INDEX),
    ("gate_costs.cnot.🍄",     1, "", 2, 0, MAX_FIB_INDEX),
    ("gate_costs.cz.🦌",       1, "", 2, 0, MAX_FIB_INDEX),
    ("gate_costs.swap.🐺",     1, "", 2, 0, MAX_FIB_INDEX),
    # Tier 3: quest rewards
    ("quest_rewards.resource_reward_min_total",      8, "quest_cycle",         3, 0, MAX_FIB_INDEX),
    ("quest_rewards.resource_reward_max_total",    233, "quest_cycle",         3, 0, MAX_FIB_INDEX),
    ("quest_rewards.resource_reward_min_per_emoji",   5, "quest_cycle",         3, 0, MAX_FIB_INDEX),
    # Tier 3: economy / tuning
    ("economy_variables.max_biome_qubits",  13, "discover_biome",      3, 0, MAX_FIB_INDEX),
    ("tuning.reap_evolution_cycles",        13, "victory_lap_partial",  3, 0, MAX_FIB_INDEX),
    ("tuning.reap_starting_tokens",          5, "victory_lap_partial",  3, 0, MAX_FIB_INDEX),
]


class FibonacciAdversary:
    def __init__(self) -> None:
        self.knobs: Dict[str, Dict[str, Any]] = {}
        self.cycle: int = 0
        self.last_block_id: str = ""
        self._register_defaults()

    def _register_defaults(self) -> None:
        for path, init_val, affinity, tier, min_idx, max_idx in DEFAULT_KNOBS:
            self.knobs[path] = {
                "path": path,
                "fib_index": nearest_fib_index(init_val),
                "min_idx": min_idx,
                "max_idx": max_idx,
                "tier": tier,
                "affinity": affinity,
            }

    # ── KL divergence ─────────────────────────────────────────────────

    @staticmethod
    def compute_kl_divergence(observed_sorted: List[float], target: Optional[List[float]] = None) -> float:
        tgt = target or GOLDEN_TARGET
        n = min(len(observed_sorted), len(tgt))
        if n == 0:
            return 0.0
        kl = 0.0
        for i in range(n):
            p = max(1e-10, observed_sorted[i])
            q = max(1e-10, tgt[i])
            kl += p * math.log(p / q)
        return kl

    @staticmethod
    def sort_distribution_descending(action_dist: Dict[str, float]) -> List[float]:
        freqs = [float(action_dist.get(a, 0.0)) for a in POLICY_ACTIONS]
        freqs.sort(reverse=True)
        return freqs

    # ── Mutation engine ───────────────────────────────────────────────

    def mutate(self, observed_action_pct: Dict[str, float], max_mutations: int = 5) -> List[Dict[str, Any]]:
        """Compute ±1 fib_index mutations to push observed distribution toward φ-cascade."""
        # 1. Rank actions by observed frequency (descending)
        ranked = sorted(
            [(a, float(observed_action_pct.get(a, 0.0))) for a in POLICY_ACTIONS],
            key=lambda x: x[1],
            reverse=True,
        )

        mutations: List[Dict[str, Any]] = []

        for rank_idx, (action_name, observed_share) in enumerate(ranked):
            if len(mutations) >= max_mutations:
                break

            target_share = GOLDEN_TARGET[rank_idx] if rank_idx < len(GOLDEN_TARGET) else 0.0
            excess = observed_share - target_share

            # Dead zone
            if abs(excess) < 0.05:
                continue

            # Find affiliated knobs
            affiliated = [k for k in self.knobs.values() if k["affinity"] == action_name]
            if not affiliated:
                continue

            direction = 1 if excess > 0 else -1

            # Sort by tier (mutate lowest tier first)
            affiliated.sort(key=lambda k: k["tier"])

            for knob in affiliated:
                if len(mutations) >= max_mutations:
                    break
                old_idx = knob["fib_index"]
                new_idx = max(knob["min_idx"], min(knob["max_idx"], old_idx + direction))
                if new_idx == old_idx:
                    continue

                old_val = fib_value(old_idx)
                new_val = fib_value(new_idx)
                knob["fib_index"] = new_idx

                mutations.append({
                    "knob": knob["path"],
                    "from_idx": old_idx,
                    "to_idx": new_idx,
                    "from_val": old_val,
                    "to_val": new_val,
                    "action": action_name,
                    "rank": rank_idx,
                    "excess": round(excess, 3),
                })
                break  # one mutation per action per cycle

        self.cycle += 1
        return mutations

    # ── Berry block bookkeeping ───────────────────────────────────────

    def write_berry_block(
        self,
        observed_action_pct: Dict[str, float],
        mutations: List[Dict[str, Any]],
        extra_observed: Optional[Dict[str, Any]] = None,
        ledger_path: Optional[Path] = None,
    ) -> Dict[str, Any]:
        block_id = f"bb_{self.cycle:04d}"
        parent_id = self.last_block_id or "genesis"

        sorted_obs = self.sort_distribution_descending(observed_action_pct)
        kl = self.compute_kl_divergence(sorted_obs)

        knob_snapshot = {p: k["fib_index"] for p, k in self.knobs.items()}

        observed_payload: Dict[str, Any] = {"action_distribution": dict(observed_action_pct)}
        if extra_observed:
            observed_payload.update(extra_observed)

        check_input = parent_id + json.dumps(mutations, ensure_ascii=False)
        checksum = hashlib.sha256(check_input.encode()).hexdigest()

        block: Dict[str, Any] = {
            "block_id": block_id,
            "parent_id": parent_id,
            "author": "python",
            "timestamp_unix": time.time(),
            "cycle": self.cycle,
            "observed": observed_payload,
            "divergence": {
                "kl_from_golden": round(kl, 4),
                "sorted_observed": [round(v, 4) for v in sorted_obs],
                "sorted_target": [round(v, 4) for v in GOLDEN_TARGET],
            },
            "mutations": mutations,
            "state": {"knob_indices": knob_snapshot},
            "checksum": checksum,
        }

        self.last_block_id = block_id

        if ledger_path is not None:
            ledger_path.parent.mkdir(parents=True, exist_ok=True)
            with open(ledger_path, "a", encoding="utf-8") as fh:
                fh.write(json.dumps(block, ensure_ascii=False))
                fh.write("\n")

        return block

    # ── FarmVariableGraph export ──────────────────────────────────────

    def to_graph_lines(self) -> List[str]:
        lines = []
        for path, knob in self.knobs.items():
            val = fib_value(knob["fib_index"])
            lines.append(json.dumps({"op": "set", "path": path, "value": val}, ensure_ascii=False))
        return lines

    def write_patch_file(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "w", encoding="utf-8") as fh:
            for line in self.to_graph_lines():
                fh.write(line)
                fh.write("\n")

    # ── State persistence ─────────────────────────────────────────────

    def export_state(self) -> Dict[str, Any]:
        return {
            "version": 1,
            "type": "fibonacci_adversary",
            "cycle": self.cycle,
            "last_block_id": self.last_block_id,
            "knob_indices": {p: k["fib_index"] for p, k in self.knobs.items()},
        }

    def save_state(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(self.export_state(), fh, ensure_ascii=False, indent=2)
            fh.write("\n")

    def load_state(self, data: Dict[str, Any]) -> None:
        if not isinstance(data, dict) or data.get("type") != "fibonacci_adversary":
            return
        self.cycle = int(data.get("cycle", 0))
        self.last_block_id = str(data.get("last_block_id", ""))
        indices = data.get("knob_indices", {})
        if isinstance(indices, dict):
            for path, idx in indices.items():
                if path in self.knobs:
                    self.knobs[path]["fib_index"] = max(0, min(MAX_FIB_INDEX, int(idx)))

    def load_state_file(self, path: Path) -> bool:
        if not path.exists():
            return False
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            self.load_state(data)
            return True
        except (json.JSONDecodeError, OSError):
            return False

    def load_from_ledger(self, ledger_path: Path) -> bool:
        """Restore state from the last berry block in a ledger file."""
        if not ledger_path.exists():
            return False
        last_block: Optional[Dict[str, Any]] = None
        for raw in ledger_path.read_text(encoding="utf-8").splitlines():
            raw = raw.strip()
            if not raw:
                continue
            try:
                last_block = json.loads(raw)
            except json.JSONDecodeError:
                continue
        if not last_block or not isinstance(last_block, dict):
            return False
        self.cycle = int(last_block.get("cycle", 0))
        self.last_block_id = str(last_block.get("block_id", ""))
        state = last_block.get("state", {})
        if isinstance(state, dict):
            indices = state.get("knob_indices", {})
            if isinstance(indices, dict):
                for path, idx in indices.items():
                    if path in self.knobs:
                        self.knobs[path]["fib_index"] = max(0, min(MAX_FIB_INDEX, int(idx)))
        return True

    # ── Debug / inspection ────────────────────────────────────────────

    def format_summary(self) -> str:
        lines = [f"FibonacciAdversary  cycle={self.cycle}  knobs={len(self.knobs)}  last_block={self.last_block_id}"]
        lines.append("")
        lines.append("φ-cascade target (sorted descending):")
        for i, t in enumerate(GOLDEN_TARGET):
            lines.append(f"  rank {i}: {t:.4f}")
        lines.append("")
        lines.append("Knobs by tier:")
        by_tier: Dict[int, List[Dict[str, Any]]] = {}
        for k in self.knobs.values():
            by_tier.setdefault(k["tier"], []).append(k)
        for tier in sorted(by_tier):
            lines.append(f"  Tier {tier}:")
            for k in sorted(by_tier[tier], key=lambda x: x["path"]):
                val = fib_value(k["fib_index"])
                aff = k["affinity"] or "(none)"
                lines.append(f"    {k['path']:50s}  fib[{k['fib_index']:2d}]={val:4d}  → {aff}")
        return "\n".join(lines)


# ── CLI ───────────────────────────────────────────────────────────────

def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(description="Fibonacci adversary: mutate economy costs toward φ-cascade")
    parser.add_argument("--summary", type=Path, help="Path to milk hunt batch_summary.json")
    parser.add_argument("--stdin", action="store_true", help="Read summary JSON from stdin")
    parser.add_argument("--show", action="store_true", help="Show current adversary state")
    parser.add_argument("--reset", action="store_true", help="Reset to default knob values")
    parser.add_argument("--max-mutations", type=int, default=5, help="Max knob mutations per cycle")
    parser.add_argument("--ledger", type=Path, default=None, help="Berry ledger path")
    parser.add_argument("--state", type=Path, default=None, help="Adversary state file path")
    parser.add_argument("--patch-out", type=Path, default=None, help="Output FarmVariableGraph patch path")
    parser.add_argument("--json-only", action="store_true", help="Output only JSON result")
    args = parser.parse_args()

    ledger = args.ledger or default_ledger_path()
    state_path = args.state or default_state_path()
    patch_out = args.patch_out or default_patch_path()

    adversary = FibonacciAdversary()

    # Load state from file or ledger
    if not adversary.load_state_file(state_path):
        adversary.load_from_ledger(ledger)

    if args.reset:
        adversary = FibonacciAdversary()
        adversary.save_state(state_path)
        print("Reset to defaults.")
        return

    if args.show:
        print(adversary.format_summary())
        return

    # Load summary
    summary: Optional[Dict[str, Any]] = None
    if args.stdin:
        summary = json.load(sys.stdin)
    elif args.summary:
        summary = json.loads(args.summary.read_text(encoding="utf-8"))

    if summary is None:
        parser.print_help()
        return

    # Extract action distribution
    action_pct = summary.get("policy_action_pct", {})
    if not action_pct:
        action_counts = summary.get("policy_action_counts", {})
        total = sum(action_counts.values()) if action_counts else 0
        if total > 0:
            action_pct = {k: v / total for k, v in action_counts.items()}

    if not action_pct:
        print("No action distribution found in summary", file=sys.stderr)
        sys.exit(1)

    # Run mutation
    mutations = adversary.mutate(action_pct, max_mutations=args.max_mutations)

    # Write berry block
    extra = {
        "found_milk": summary.get("found_milk"),
        "loops_completed": summary.get("loops_completed"),
        "known_pairs_count": summary.get("known_pairs_count"),
    }
    block = adversary.write_berry_block(action_pct, mutations, extra_observed=extra, ledger_path=ledger)

    # Save state
    adversary.save_state(state_path)

    # Write patch
    adversary.write_patch_file(patch_out)

    # Output
    if args.json_only:
        print(json.dumps(block, ensure_ascii=False))
    else:
        sorted_obs = adversary.sort_distribution_descending(action_pct)
        kl = adversary.compute_kl_divergence(sorted_obs)
        print(f"Cycle {adversary.cycle}  KL={kl:.4f}  mutations={len(mutations)}")
        if mutations:
            for m in mutations:
                arrow = "↑" if m["to_idx"] > m["from_idx"] else "↓"
                print(f"  {arrow} {m['knob']:45s}  {m['from_val']:4d} → {m['to_val']:4d}  "
                      f"(action={m['action']}, excess={m['excess']:+.3f})")
        else:
            print("  (no mutations — distribution within dead zone)")
        print(f"Patch written: {patch_out}")
        print(f"Ledger: {ledger}")


if __name__ == "__main__":
    main()
