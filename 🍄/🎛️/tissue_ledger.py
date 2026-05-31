#!/usr/bin/env python3
"""Graph Tissue™ learning ledger — trainable weight defaults + adaptive scoring.

Canonical home of WEIGHT_RANGES (the 29 Graph Tissue™ knobs), shared by
derby.py, derby_character_derby.py, and the Claura lichen bridge.

Three capabilities:
  1. Tissue ledger: each derby appends a tissue_signal entry.  Over many
     derbies, EMA-smoothed deltas shift the defaults toward configurations
     that consistently correlate with success.
  2. Evolved defaults: load_evolved_defaults() reads the ledger and returns
     WEIGHT_RANGES with shifted defaults, guarded by ±50% of range width.
  3. Adaptive scoring: lichen_scoring_weights() maps CalibrationGraph axiom
     projections to per-dimension fitness weights, so the organism's quantum
     state shapes *what success means* in the derby.

Graph Tissue™ is a trademark of Luke Spooner.
"""
from __future__ import annotations

import json
import math
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

HERE = Path(__file__).resolve().parent
LEDGER_PATH = HERE / "config" / "tissue_ledger.jsonl"

# ── Canonical Graph Tissue™ weight ranges ─────────────────────────────
# Single source of truth.  derby.py + derby_character_derby.py import this.

WEIGHT_RANGES: Dict[str, Dict[str, Any]] = {
    "offer_pair":                    {"default": 1.0,   "range": [0.3,   3.0]},
    "offer_novelty":                 {"default": 1.0,   "range": [0.3,   4.0]},
    "offer_reward":                  {"default": 0.04,  "range": [0.01,  0.15]},
    "offer_deficit":                 {"default": 0.9,   "range": [0.3,   2.0]},
    "offer_delivery_cost":           {"default": -0.06, "range": [-0.15, -0.01]},
    "offer_milk_direct":             {"default": 900.0, "range": [500.0, 2000.0]},
    "offer_critical_any":            {"default": 2.0,   "range": [0.5,   10.0]},
    "offer_critical_unknown":        {"default": 7.0,   "range": [2.0,   40.0]},
    "offer_critical_pair":           {"default": 16.0,  "range": [4.0,   100.0]},
    "probe_frontier":                {"default": 1.0,   "range": [0.3,   3.0]},
    "probe_hits":                    {"default": 0.8,   "range": [0.2,   2.0]},
    "probe_novelty":                 {"default": 0.4,   "range": [0.1,   1.5]},
    "probe_critical_hits":           {"default": 1.2,   "range": [0.3,   3.0]},
    "probe_village_pressure":        {"default": 0.8,   "range": [0.2,   3.0]},
    "probe_village_known_critical":  {"default": 0.25,  "range": [0.05,  1.5]},
    "loop_probe_base":               {"default": 1.0,   "range": [0.0,   3.0]},
    "loop_probe_pair_scale":         {"default": 0.10,  "range": [0.0,   0.5]},
    "loop_probe_floor_pressure":     {"default": 1.0,   "range": [0.0,   2.0]},
    "loop_probe_critical_pressure":  {"default": 1.0,   "range": [0.0,   2.0]},
    "loop_probe_strict_bonus":       {"default": 1.0,   "range": [0.0,   2.0]},
    "loop_probe_max":                {"default": 4.0,   "range": [1.0,   8.0]},
    "vocab_probe_base":              {"default": 1.0,   "range": [0.0,   3.0]},
    "vocab_probe_per_pair":          {"default": 1.0,   "range": [0.0,   3.0]},
    "vocab_probe_max":               {"default": 6.0,   "range": [1.0,   10.0]},
    "lindblad_hits":                 {"default": 1.1,   "range": [0.3,   2.5]},
    "lindblad_critical_hits":        {"default": 1.6,   "range": [0.5,   3.5]},
    "lindblad_floor_hits":           {"default": 1.8,   "range": [0.5,   4.0]},
    "lindblad_frontier":             {"default": 0.35,  "range": [0.1,   1.5]},
    "lindblad_novelty":              {"default": 0.45,  "range": [0.1,   1.5]},
    "lindblad_village_pressure":     {"default": 0.8,   "range": [0.2,   2.5]},
}

# Hardcoded originals (never modified — needed to compute max drift)
_SEED_DEFAULTS: Dict[str, float] = {k: v["default"] for k, v in WEIGHT_RANGES.items()}


# ── Scoring weight base + axiom mapping ───────────────────────────────

_SCORING_BASE: Dict[str, float] = {
    "success_rate": 0.50,
    "speed_score":  0.25,
    "biome_score":  0.15,
    "vocab_score":  0.10,
}

# CalGraph axiom → scoring dimension + influence direction
# τ(rate) → speed:        fast tempo = value rapid convergence
# J(strength) → success:  strong coupling = value reliable outcomes
# θ(sensitivity) → biome: env sensitivity = value biome coverage
# σ(breadth) → vocab:     wide scope = value vocabulary breadth
_AXIOM_TO_SCORING: Dict[str, str] = {
    "rate":        "speed_score",
    "strength":    "success_rate",
    "sensitivity": "biome_score",
    "breadth":     "vocab_score",
}

_MAX_SHIFT = 0.15   # max weight shift per axiom
_WEIGHT_FLOOR = 0.05  # no dimension drops below 5%


def lichen_scoring_weights(
    cal_projection: Optional[Dict[str, float]] = None,
) -> Dict[str, float]:
    """Map CalibrationGraph axiom projections to fitness scoring weights.

    Each axiom ∈ [0,1] shifts its associated scoring dimension by up to
    ±0.15.  Weights are clamped to ≥0.05 and renormalized to sum=1.

    Returns {"success_rate": w, "speed_score": w, "biome_score": w, "vocab_score": w}.
    """
    w = dict(_SCORING_BASE)
    if not cal_projection:
        return w

    for axiom_name, scoring_dim in _AXIOM_TO_SCORING.items():
        axiom_val = float(cal_projection.get(axiom_name, 0.5))
        # deviation from midpoint → shift magnitude
        shift = (axiom_val - 0.5) * 2.0 * _MAX_SHIFT  # ∈ [-0.15, +0.15]
        w[scoring_dim] += shift

    # Clamp and renormalize
    for k in w:
        w[k] = max(_WEIGHT_FLOOR, w[k])
    total = sum(w.values())
    return {k: round(v / total, 4) for k, v in w.items()}


def score_with_weights(
    sr: float,
    speed: float,
    biome: float,
    vocab: float,
    weights: Optional[Dict[str, float]] = None,
) -> float:
    """Compute composite score using (optionally adaptive) weights."""
    w = weights or _SCORING_BASE
    return (
        w.get("success_rate", 0.50) * sr
        + w.get("speed_score", 0.25) * speed
        + w.get("biome_score", 0.15) * biome
        + w.get("vocab_score", 0.10) * vocab
    )


# ── Tissue ledger I/O ─────────────────────────────────────────────────

def load_ledger(path: Optional[Path] = None) -> List[Dict[str, Any]]:
    """Load tissue ledger entries (oldest first)."""
    p = path or LEDGER_PATH
    if not p.exists():
        return []
    entries: List[Dict[str, Any]] = []
    for line in p.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        try:
            entries.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return entries


def append_ledger_entry(
    tissue_signal: Dict[str, Any],
    resource_signal: Dict[str, Any],
    scoring_weights: Dict[str, float],
    n_hunters: int = 0,
    n_winners: int = 0,
    path: Optional[Path] = None,
) -> None:
    """Append a derby result to the tissue ledger."""
    p = path or LEDGER_PATH
    p.parent.mkdir(parents=True, exist_ok=True)
    entry = {
        "timestamp":       time.strftime("%Y-%m-%dT%H:%M:%S"),
        "n_hunters":       n_hunters,
        "n_winners":       n_winners,
        "tissue_signal":   tissue_signal,
        "resource_signal": resource_signal,
        "scoring_weights": scoring_weights,
    }
    with open(p, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


# ── Evolved defaults via EMA ──────────────────────────────────────────

_EMA_ALPHA = 0.30    # Recent signal weight (higher = faster adaptation)
_MAX_DRIFT = 0.50    # Max drift as fraction of range width


def evolve_defaults(
    ledger: Optional[List[Dict[str, Any]]] = None,
    base_ranges: Optional[Dict[str, Dict[str, Any]]] = None,
    alpha: float = _EMA_ALPHA,
    max_drift_frac: float = _MAX_DRIFT,
) -> Dict[str, Dict[str, Any]]:
    """Apply EMA of tissue_signal deltas to weight range defaults.

    Reads the ledger (oldest → newest) and for each weight, computes an
    exponential moving average of the observed delta-from-default signals.
    The accumulated EMA shifts the default, clamped to ±50% of range width
    from the original seed default.

    Returns a new WEIGHT_RANGES dict with evolved defaults.
    """
    if ledger is None:
        ledger = load_ledger()
    ranges = base_ranges or WEIGHT_RANGES

    # Deep copy
    evolved: Dict[str, Dict[str, Any]] = {}
    for k, v in ranges.items():
        evolved[k] = {"default": v["default"], "range": list(v["range"])}

    if not ledger:
        return evolved

    # Accumulate EMA per weight
    ema: Dict[str, float] = {}
    for entry in ledger:
        for weight_name, signal in entry.get("tissue_signal", {}).items():
            delta = float(signal.get("mean_delta", 0.0))
            if weight_name in ema:
                ema[weight_name] = alpha * delta + (1.0 - alpha) * ema[weight_name]
            else:
                ema[weight_name] = delta

    # Apply EMA to defaults with guardrails
    for weight_name, shift in ema.items():
        if weight_name not in evolved:
            continue
        wr = evolved[weight_name]
        lo, hi = wr["range"]
        range_width = hi - lo
        max_abs_drift = range_width * max_drift_frac

        seed_default = _SEED_DEFAULTS.get(weight_name, wr["default"])
        clamped_shift = max(-max_abs_drift, min(max_abs_drift, shift))
        new_default = seed_default + clamped_shift
        new_default = max(lo, min(hi, new_default))
        wr["default"] = round(new_default, 6)

    return evolved


def load_evolved_defaults(
    ledger_path: Optional[Path] = None,
) -> Tuple[Dict[str, Dict[str, Any]], List[Dict[str, Any]]]:
    """Convenience: load ledger + evolve defaults in one call.

    Returns (evolved_ranges, ledger_entries).
    """
    ledger = load_ledger(ledger_path)
    evolved = evolve_defaults(ledger)
    return evolved, ledger


def format_evolved_diff(
    evolved_ranges: Dict[str, Dict[str, Any]],
) -> List[str]:
    """Return human-readable lines for knobs that drifted from seed.

    Only includes knobs where the evolved value differs from the seed default
    by more than 0.5% of the knob range.
    """
    lines: List[str] = []
    for name, spec in WEIGHT_RANGES.items():
        seed = spec["default"]
        lo, hi = spec["range"]
        rng = hi - lo or 1.0
        ev_val = evolved_ranges.get(name, spec).get("default", seed)
        delta = ev_val - seed
        if abs(delta) > 0.005 * rng:
            arrow = "↑" if delta > 0 else "↓"
            lines.append(
                f"  {arrow} {name}: {seed:.4g} → {ev_val:.4g}  (Δ{delta:+.4g})"
            )
    return lines


# ── Tissue → PolicyGraph projection ──────────────────────────────────
# Maps tissue knobs to PolicyGraph paths.  Each entry:
#   (tissue_knob, policy_path, base_policy_value, scale_mode)
#
# scale_mode:
#   "ratio"   — policy = base * (evolved / seed)   [default: proportional]
#   "direct"  — policy = evolved                    [knob IS the value]
#   "inverse" — policy = base * (seed / evolved)    [higher knob → lower policy]

_TISSUE_POLICY_MAP: List[Tuple[str, str, float, str]] = [
    # ── Offer → quest/lock action_priors + reward_terms ──────────────
    ("offer_pair",             "reward_terms.pair",                              42.0,  "ratio"),
    ("offer_novelty",          "action_priors.quest_cycle.unknown_vocab",         1.25, "ratio"),
    ("offer_reward",           "reward_terms.resource",                           0.08, "ratio"),
    ("offer_deficit",          "action_priors.quest_cycle.stagnation_scale",      0.45, "ratio"),
    ("offer_delivery_cost",    "reward_terms.execution_penalty",                 -4.0,  "ratio"),
    ("offer_critical_any",     "action_priors.quest_cycle.discovery_affinity",     5.0,  "ratio"),
    ("offer_critical_unknown", "action_priors.quest_cycle.novelty",               1.5,  "ratio"),

    # ── Probe → probe_cycle action_priors ────────────────────────────
    ("probe_frontier",         "action_priors.probe_cycle.base",                  1.0,  "ratio"),
    ("probe_hits",             "action_priors.probe_cycle.resource_pressure",     0.3,  "ratio"),
    ("probe_novelty",          "action_priors.discover_biome.base",               0.35, "ratio"),
    ("probe_critical_hits",    "action_priors.probe_cycle.biome_pressure",        0.15, "ratio"),

    # ── Loop → limits + priors ───────────────────────────────────────
    ("loop_probe_max",         "action_limits.default.max_per_loop",              1,    "direct"),
    ("vocab_probe_base",       "action_priors.quest_cycle.base",                  0.7,  "ratio"),

    # ── Lindblad → lindblad_drain action_priors ──────────────────────
    ("lindblad_hits",          "action_priors.lindblad_drain.base",               0.9,  "ratio"),
    ("lindblad_frontier",      "action_priors.lindblad_drain.inactive_bonus",     0.5,  "ratio"),

    # ── Time → time_skip ─────────────────────────────────────────────
    ("loop_probe_floor_pressure", "action_priors.time_skip.base",                 0.4,  "inverse"),
]


def project_to_policy(
    evolved_ranges: Optional[Dict[str, Dict[str, Any]]] = None,
) -> List[Dict[str, Any]]:
    """Project evolved tissue defaults to PolicyGraph JSONL overlay ops.

    Generates DELTA ops (using "add") rather than absolute "set" ops, so the
    tissue adjusts relative to each character's natural Godot policy rather
    than overriding it.  At seed defaults the delta is zero → no ops emitted,
    leaving character policies untouched.

    Returns a list of {"op": "add", "path": ..., "value": delta} dicts
    ready for policy_graph_runtime.apply_graph_lines().
    """
    evolved = evolved_ranges or WEIGHT_RANGES
    ops: List[Dict[str, Any]] = []

    for knob_name, policy_path, base_value, mode in _TISSUE_POLICY_MAP:
        knob_spec = evolved.get(knob_name)
        if knob_spec is None:
            continue
        current = float(knob_spec["default"])
        seed = _SEED_DEFAULTS.get(knob_name, current)

        # Compute the seed-default policy value and the evolved policy value,
        # then emit an "add" op for the difference only.
        def _policy_val(weight_val: float) -> float:
            if mode == "direct":
                return weight_val
            elif mode == "inverse":
                if weight_val == 0 or seed == 0:
                    return float(base_value)
                return float(base_value) * (seed / weight_val)
            else:  # "ratio"
                if seed == 0:
                    return float(base_value)
                return float(base_value) * (weight_val / seed)

        seed_policy = _policy_val(seed)
        curr_policy = _policy_val(current)
        delta = curr_policy - seed_policy

        if isinstance(base_value, int):
            delta = int(round(delta))
            if delta == 0:
                continue
        else:
            delta = round(delta, 4)
            if abs(delta) < 1e-6:
                continue

        ops.append({"op": "add", "path": policy_path, "value": delta})

    return ops


def jitter_weights(
    evolved_ranges: Optional[Dict[str, Dict[str, Any]]] = None,
    n_jitters: int = 3,
    jitter_fraction: float = 0.15,
    seed: int = 0,
) -> Dict[str, float]:
    """Apply random jitter to a subset of tissue weights.

    Selects n_jitters random weights and shifts them within their valid
    range by up to ±jitter_fraction of the range width.

    Returns {knob_name: jittered_value} for the selected weights.
    Used by train mode to explore the weight space per-runner.
    """
    import random as _rnd
    rng = _rnd.Random(seed)
    evolved = evolved_ranges or WEIGHT_RANGES

    # Select random subset of weights to jitter
    all_names = list(evolved.keys())
    n = min(n_jitters, len(all_names))
    selected = rng.sample(all_names, n)

    jittered: Dict[str, float] = {}
    for name in selected:
        spec = evolved[name]
        lo, hi = spec["range"]
        current = float(spec["default"])
        range_width = hi - lo
        delta = rng.uniform(-jitter_fraction, jitter_fraction) * range_width
        new_val = max(lo, min(hi, current + delta))
        jittered[name] = round(new_val, 6)

    return jittered


def project_jittered_to_policy(
    jittered_weights: Dict[str, float],
    evolved_ranges: Optional[Dict[str, Dict[str, Any]]] = None,
) -> List[Dict[str, Any]]:
    """Convert jittered tissue weights to PolicyGraph overlay ops.

    Only emits ops for the jittered weights (not all weights).
    These ops are appended ON TOP of the base tissue overlay.
    """
    evolved = evolved_ranges or WEIGHT_RANGES
    ops: List[Dict[str, Any]] = []

    for knob_name, policy_path, base_value, mode in _TISSUE_POLICY_MAP:
        if knob_name not in jittered_weights:
            continue
        current = jittered_weights[knob_name]
        seed = _SEED_DEFAULTS.get(knob_name, float(evolved.get(knob_name, {}).get("default", current)))

        if mode == "direct":
            value = current
        elif mode == "inverse":
            if current == 0 or seed == 0:
                value = base_value
            else:
                value = base_value * (seed / current)
        else:  # "ratio"
            if seed == 0:
                value = base_value
            else:
                value = base_value * (current / seed)

        if isinstance(base_value, int) or (mode == "direct" and current == int(current)):
            value = max(1, int(round(value)))
        else:
            value = round(value, 4)

        ops.append({"op": "set", "path": policy_path, "value": value})

    return ops


def format_policy_projection(ops: List[Dict[str, Any]]) -> List[str]:
    """Human-readable summary of tissue → policy projection."""
    lines = []
    for op in ops:
        lines.append(f"  {op['path']} = {op['value']}")
    return lines


def reverse_policy_to_weights(policy_jsonl_lines: List[str]) -> Dict[str, float]:
    """Reverse-map policy graph JSONL ops to implied tissue weight values.

    Given a character's policy_graph_jsonl lines (which set specific policy
    paths), infer what tissue weight values would produce those policy values.
    This lets tissue learning extract signals from character-based runs.

    Returns {knob_name: implied_weight_value} for any mapped paths found.
    """
    # Build reverse lookup: policy_path → (knob_name, base_value, mode)
    path_to_knob: Dict[str, Tuple[str, float, str]] = {}
    for knob_name, policy_path, base_value, mode in _TISSUE_POLICY_MAP:
        path_to_knob[policy_path] = (knob_name, base_value, mode)

    # Parse JSONL lines
    import json as _json
    policy_values: Dict[str, Any] = {}
    for raw in policy_jsonl_lines:
        raw = raw.strip()
        if not raw:
            continue
        try:
            op = _json.loads(raw)
        except _json.JSONDecodeError:
            continue
        if op.get("op") == "set" and "path" in op and "value" in op:
            policy_values[op["path"]] = op["value"]

    # Reverse-map to tissue weights
    weights: Dict[str, float] = {}
    for policy_path, policy_value in policy_values.items():
        if policy_path not in path_to_knob:
            continue
        knob_name, base_value, mode = path_to_knob[policy_path]
        seed = _SEED_DEFAULTS.get(knob_name, WEIGHT_RANGES[knob_name]["default"])

        if mode == "direct":
            # policy_value IS the knob value
            weights[knob_name] = float(policy_value)
        elif mode == "inverse":
            # policy = base * (seed / knob) → knob = base * seed / policy
            if float(policy_value) != 0:
                weights[knob_name] = base_value * seed / float(policy_value)
            else:
                weights[knob_name] = seed
        else:  # "ratio"
            # policy = base * (knob / seed) → knob = seed * policy / base
            if base_value != 0:
                weights[knob_name] = seed * float(policy_value) / base_value
            else:
                weights[knob_name] = seed

    return weights


# ── Tissue → resource emphasis ───────────────────────────────────────
# Maps tissue knob clusters to resource multipliers.
# Higher cluster emphasis → more starting resources in that category.

_RESOURCE_KNOB_INFLUENCE: Dict[str, List[Tuple[str, float]]] = {
    # emoji → [(tissue_knob, influence_weight)]
    # influence_weight: positive = higher knob → more of this resource
    "👥": [("offer_critical_any", 0.3), ("probe_village_pressure", 0.2)],
    "🌾": [("probe_frontier", 0.3), ("vocab_probe_base", 0.2)],
    "🍞": [("offer_deficit", 0.4), ("offer_critical_pair", 0.15)],
    "❄️": [("lindblad_hits", 0.3), ("lindblad_floor_hits", 0.2)],
    "🌱": [("offer_novelty", 0.3), ("probe_novelty", 0.2)],
    "⚙":  [("lindblad_frontier", 0.25), ("loop_probe_base", 0.2)],
    "🔥": [("probe_critical_hits", 0.25), ("loop_probe_critical_pressure", 0.2)],
}

# Base resource amounts (neutral starting position)
_BASE_RESOURCES: Dict[str, float] = {
    "👥": 120.0,
    "🌾": 140.0,
    "🍞": 180.0,
    "❄️": 80.0,
    "🌱": 60.0,
    "⚙":  70.0,
    "🔥": 55.0,
}


def project_to_resources(
    evolved_ranges: Optional[Dict[str, Dict[str, Any]]] = None,
) -> Dict[str, int]:
    """Project evolved tissue state to starting resource allocation.

    Returns {emoji: amount} dict suitable for world_state profile resources.
    Each resource is biased by tissue knobs that semantically relate to it.
    The bias is gentle: ±20% from base, so critical floors are always met.
    """
    evolved = evolved_ranges or WEIGHT_RANGES
    resources: Dict[str, int] = {}

    for emoji, influences in _RESOURCE_KNOB_INFLUENCE.items():
        base = _BASE_RESOURCES.get(emoji, 100.0)
        multiplier = 1.0

        for knob_name, weight in influences:
            knob_spec = evolved.get(knob_name)
            if knob_spec is None:
                continue
            current = float(knob_spec["default"])
            seed = _SEED_DEFAULTS.get(knob_name, current)
            if seed == 0:
                continue
            # Deviation from seed → resource emphasis shift
            # weight=0.3 and 50% knob increase → 15% resource increase
            ratio = current / seed
            multiplier += weight * (ratio - 1.0)

        # Clamp multiplier to ±20% to keep resources sane
        multiplier = max(0.80, min(1.20, multiplier))
        resources[emoji] = max(1, int(round(base * multiplier)))

    return resources


def format_resource_projection(resources: Dict[str, int]) -> List[str]:
    """Human-readable summary of tissue → resource projection."""
    lines = []
    for emoji in sorted(resources):
        base = int(_BASE_RESOURCES.get(emoji, 100))
        current = resources[emoji]
        delta = current - base
        if delta != 0:
            lines.append(f"  {emoji} {current} ({'+' if delta > 0 else ''}{delta} from base {base})")
        else:
            lines.append(f"  {emoji} {current} (neutral)")
    return lines
