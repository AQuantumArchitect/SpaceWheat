#!/usr/bin/env python3
"""Character Derby — two LLM lanes design Graph Tissue™ characters for milk_hunt.

Each lane (sonnet-low, codex-mini) generates 5 "characters":
  - A world_state profile (resources, biomes, known_pairs)
  - A set of QuantumGraphPolicy weight overrides (the Graph Tissue™ knobs)

Characters are written to config/world_state/derby_{lane}_{n}.json
and policy overrides to config/policy_weights/derby_{lane}_{n}.json.

Then milk_hunt_matrix runs all 10 characters head-to-head.
Results are scored and the winning tissue is extracted for learning.

Graph Tissue™ is a trademark of Luke Spooner.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict, List

HERE = Path(__file__).resolve().parent
CONFIG_WS = HERE / "config" / "world_state"
CONFIG_PW = HERE / "config" / "policy_weights"

# ── Default Graph Tissue™ weight ranges (for prompting) ──────────────
WEIGHT_RANGES: Dict[str, Dict[str, Any]] = {
    "offer_pair":                {"default": 1.0,  "range": [0.3, 3.0]},
    "offer_novelty":             {"default": 1.0,  "range": [0.3, 4.0]},
    "offer_reward":              {"default": 0.04, "range": [0.01, 0.15]},
    "offer_deficit":             {"default": 0.9,  "range": [0.3, 2.0]},
    "offer_delivery_cost":       {"default": -0.06,"range": [-0.15, -0.01]},
    "offer_milk_direct":         {"default": 900.0,"range": [500.0, 2000.0]},
    "offer_critical_any":        {"default": 2.0,  "range": [0.5, 10.0]},
    "offer_critical_unknown":    {"default": 7.0,  "range": [2.0, 40.0]},
    "offer_critical_pair":       {"default": 16.0, "range": [4.0, 100.0]},
    "probe_frontier":            {"default": 1.0,  "range": [0.3, 3.0]},
    "probe_hits":                {"default": 0.8,  "range": [0.2, 2.0]},
    "probe_novelty":             {"default": 0.4,  "range": [0.1, 1.5]},
    "probe_critical_hits":       {"default": 1.2,  "range": [0.3, 3.0]},
    "probe_village_pressure":    {"default": 0.8,  "range": [0.2, 3.0]},
    "probe_village_known_critical":{"default":0.25,"range": [0.05, 1.5]},
    "loop_probe_base":           {"default": 1.0,  "range": [0.0, 3.0]},
    "loop_probe_pair_scale":     {"default": 0.10, "range": [0.0, 0.5]},
    "loop_probe_floor_pressure": {"default": 1.0,  "range": [0.0, 2.0]},
    "loop_probe_critical_pressure":{"default":1.0, "range": [0.0, 2.0]},
    "loop_probe_strict_bonus":   {"default": 1.0,  "range": [0.0, 2.0]},
    "loop_probe_max":            {"default": 4.0,  "range": [1.0, 8.0]},
    "vocab_probe_base":          {"default": 1.0,  "range": [0.0, 3.0]},
    "vocab_probe_per_pair":      {"default": 1.0,  "range": [0.0, 3.0]},
    "vocab_probe_max":           {"default": 6.0,  "range": [1.0, 10.0]},
    "lindblad_hits":             {"default": 1.1,  "range": [0.3, 2.5]},
    "lindblad_critical_hits":    {"default": 1.6,  "range": [0.5, 3.5]},
    "lindblad_floor_hits":       {"default": 1.8,  "range": [0.5, 4.0]},
    "lindblad_frontier":         {"default": 0.35, "range": [0.1, 1.5]},
    "lindblad_novelty":          {"default": 0.45, "range": [0.1, 1.5]},
    "lindblad_village_pressure": {"default": 0.8,  "range": [0.2, 2.5]},
}

# Biomes the game knows about
KNOWN_BIOMES = [
    "StarterForest", "Village", "WildHill", "FungalNetworks",
    "SolarPlains", "VolcanicRidge", "ArcticShelf", "CoralReef",
]

# Resources and their roles
RESOURCE_INFO = {
    "👥": "labor (critical, floor=80)",
    "🌾": "wheat (growth)",
    "🍞": "bread (critical, floor=120)",
    "❄️": "cold (critical, floor=60)",
    "🌱": "seed (renewal)",
    "⚙":  "gear (infrastructure)",
    "🔥": "fire (energy)",
}

# Existing profiles for reference
REFERENCE_PROFILES = [
    "balanced_survival (300/300/160/160/120/120/120, strict)",
    "granary_scout (8/4/32/16/2/1/0, non-strict, bread-first)",
    "scarcity_stress (40/40/20/20/10/5/5, strict, ultra-hard)",
    "probe_heavy (200/200/200/200/150/100/100, strict, extra biomes)",
]

CHARACTER_PROMPT = """\
You are designing 5 "characters" for the SpaceWheat milk_hunt game.

GAME CONTEXT:
- Players navigate a quantum farming game to discover the milk vocabulary pair (🍼)
- Each turn: accept quest offers, probe biomes for resources, discover vocab pairs
- Win condition: find the milk pair. Fewer steps = better.
- Resources: {resources}
- Critical resources (must stay above floors): 👥(80), 🍞(120), ❄️(60)
- Available biomes: {biomes}
- Quest offers are scored by Graph Tissue™ weights (see below)

REFERENCE PROFILES (existing characters for calibration):
{reference}

GRAPH TISSUE™ WEIGHTS (the learned decision tissue):
These weights control how the QuantumGraphPolicy scores decisions.
Each weight has a [min, max] range. You MUST stay within range.
{weights}

YOUR TASK:
Design 5 DIVERSE characters. Each needs:
1. A world_state profile (starting resources, biomes, known_pairs, strict_biome_economy)
2. A Graph Tissue™ weight override set (only override weights you want to change from defaults)
3. A name and 1-line strategy description

Characters should explore DIFFERENT strategies:
- One aggressive explorer (low resources, wide biomes, high novelty weights)
- One defensive hoarder (high resources, conservative weights)
- One specialist (extreme in one dimension)
- Two creative hybrids

Return ONLY valid JSON array, no markdown fences:
[
  {{
    "name": "derby_{lane}_1",
    "description": "strategy description",
    "scenario_id": "default",
    "resource_mode": "set",
    "resources": {{"👥": N, "🌾": N, "🍞": N, "❄️": N, "🌱": N, "⚙": N, "🔥": N}},
    "unlocked_biomes": ["StarterForest", "Village"],
    "active_biome": "Village",
    "known_pairs": [{{"north": "🌾", "south": "👥"}}],
    "strict_biome_economy": true,
    "policy_weights": {{
      "offer_novelty": 2.5,
      "probe_frontier": 2.0
    }}
  }},
  ... (5 total)
]

CONSTRAINTS:
- Resources: each between 1 and 500
- At least 1 known_pair per character
- 2-4 unlocked_biomes per character
- active_biome must be in unlocked_biomes
- policy_weights: only include overrides, stay within ranges
- Names MUST be derby_{lane}_1 through derby_{lane}_5
"""


def build_prompt(lane: str) -> str:
    weight_lines = []
    for k, v in WEIGHT_RANGES.items():
        weight_lines.append(f"  {k}: default={v['default']}, range={v['range']}")
    return CHARACTER_PROMPT.format(
        lane=lane,
        resources=json.dumps(RESOURCE_INFO, ensure_ascii=False),
        biomes=json.dumps(KNOWN_BIOMES),
        reference="\n".join(f"  - {p}" for p in REFERENCE_PROFILES),
        weights="\n".join(weight_lines),
    )


def parse_characters(raw: str, lane: str) -> List[Dict[str, Any]]:
    """Parse JSON array from LLM output, stripping markdown fences."""
    text = raw.strip()
    if text.startswith("```"):
        lines = text.split("\n")
        text = "\n".join(lines[1:])
        if text.rstrip().endswith("```"):
            text = text.rstrip()[:-3]
    # Find the JSON array
    start = text.find("[")
    end = text.rfind("]")
    if start == -1 or end == -1:
        raise ValueError(f"No JSON array found in {lane} output")
    chars = json.loads(text[start : end + 1])
    if not isinstance(chars, list) or len(chars) != 5:
        raise ValueError(f"Expected 5 characters, got {len(chars)} from {lane}")
    # Validate and normalize
    for i, c in enumerate(chars):
        expected_name = f"derby_{lane}_{i + 1}"
        c["name"] = expected_name
        if "policy_weights" not in c:
            c["policy_weights"] = {}
        # Clamp weights to ranges
        pw = c["policy_weights"]
        for k, v in list(pw.items()):
            if k in WEIGHT_RANGES:
                lo, hi = WEIGHT_RANGES[k]["range"]
                pw[k] = max(lo, min(hi, float(v)))
            else:
                del pw[k]  # Unknown weight, discard
        # Ensure biomes are valid
        c.setdefault("unlocked_biomes", ["StarterForest", "Village"])
        c["unlocked_biomes"] = [b for b in c["unlocked_biomes"] if b in KNOWN_BIOMES]
        if not c["unlocked_biomes"]:
            c["unlocked_biomes"] = ["StarterForest", "Village"]
        if c.get("active_biome") not in c["unlocked_biomes"]:
            c["active_biome"] = c["unlocked_biomes"][-1]
        c.setdefault("scenario_id", "default")
        c.setdefault("resource_mode", "set")
        c.setdefault("strict_biome_economy", True)
        c.setdefault("known_pairs", [{"north": "🌾", "south": "👥"}])
        # Clamp resources
        res = c.get("resources", {})
        for emoji in RESOURCE_INFO:
            res[emoji] = max(1, min(500, int(res.get(emoji, 100))))
        c["resources"] = res
    return chars


def write_characters(chars: List[Dict[str, Any]]) -> List[str]:
    """Write profile JSONs and policy weight JSONs. Returns profile names."""
    CONFIG_PW.mkdir(parents=True, exist_ok=True)
    names = []
    for c in chars:
        name = c["name"]
        names.append(name)
        # Separate policy_weights from profile
        pw = c.pop("policy_weights", {})
        # Write world_state profile
        profile_path = CONFIG_WS / f"{name}.json"
        profile_path.write_text(json.dumps(c, indent=2, ensure_ascii=False) + "\n")
        # Write policy weights
        pw_path = CONFIG_PW / f"{name}.json"
        pw_path.write_text(json.dumps(pw, indent=2, ensure_ascii=False) + "\n")
    return names


def score_batch_summary(summary: Dict[str, Any]) -> Dict[str, float]:
    """Multi-objective scoring from a batch_summary."""
    sr = float(summary.get("success_rate", 0))
    avg_steps = float(summary.get("avg_steps_success_only", 999))
    biomes = len(summary.get("discovered_biomes_union", []))
    vocab = float(summary.get("avg_vocab_milestones_per_run", 0))

    # Composite: 50% success rate, 25% speed (inverse steps), 15% biome coverage, 10% vocab
    speed = max(0, 1.0 - avg_steps / 300.0) if avg_steps < 999 else 0.0
    biome_score = min(1.0, biomes / 6.0)
    vocab_score = min(1.0, vocab / 5.0)
    composite = 0.50 * sr + 0.25 * speed + 0.15 * biome_score + 0.10 * vocab_score
    return {
        "success_rate": sr,
        "speed_score": round(speed, 4),
        "biome_score": round(biome_score, 4),
        "vocab_score": round(vocab_score, 4),
        "composite": round(composite, 4),
    }


def extract_learnings(results: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Extract Graph Tissue™ learnings from derby results.

    Local chunks at relevant scales:
    - Character scale: which weight configs won
    - Resource scale: which starting allocations survived
    - Tissue scale: weight deltas from defaults that correlated with success
    """
    winners = sorted(results, key=lambda r: r.get("scores", {}).get("composite", 0), reverse=True)
    learnings: Dict[str, Any] = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "trademark": "Graph Tissue™ is a trademark of Luke Spooner",
        "top_characters": [],
        "tissue_signal": {},
        "resource_signal": {},
    }

    # Character scale
    for r in winners[:3]:
        learnings["top_characters"].append({
            "name": r["name"],
            "lane": r["lane"],
            "composite": r["scores"]["composite"],
            "success_rate": r["scores"]["success_rate"],
        })

    # Tissue scale: average winning weights vs defaults
    tissue_deltas: Dict[str, List[float]] = {}
    for r in winners[:3]:
        pw = r.get("policy_weights", {})
        for k, v in pw.items():
            if k in WEIGHT_RANGES:
                delta = v - WEIGHT_RANGES[k]["default"]
                tissue_deltas.setdefault(k, []).append(delta)
    for k, deltas in tissue_deltas.items():
        mean_delta = sum(deltas) / len(deltas)
        if abs(mean_delta) > 0.01:
            learnings["tissue_signal"][k] = {
                "mean_delta": round(mean_delta, 4),
                "direction": "+" if mean_delta > 0 else "-",
                "n_winners": len(deltas),
            }

    # Resource scale: average starting resources of winners vs losers
    winner_res = {}
    loser_res = {}
    for r in winners[:3]:
        for emoji, val in r.get("resources", {}).items():
            winner_res.setdefault(emoji, []).append(val)
    for r in winners[3:]:
        for emoji, val in r.get("resources", {}).items():
            loser_res.setdefault(emoji, []).append(val)
    for emoji in RESOURCE_INFO:
        w_avg = sum(winner_res.get(emoji, [0])) / max(1, len(winner_res.get(emoji, [1])))
        l_avg = sum(loser_res.get(emoji, [0])) / max(1, len(loser_res.get(emoji, [1])))
        if abs(w_avg - l_avg) > 10:
            learnings["resource_signal"][emoji] = {
                "winner_avg": round(w_avg, 1),
                "loser_avg": round(l_avg, 1),
                "delta": round(w_avg - l_avg, 1),
            }

    return learnings


def main():
    print("=" * 64)
    print("  CHARACTER DERBY: Graph Tissue™ Milk Hunt")
    print("  Sonnet-low  vs  Codex-mini  •  5 characters each")
    print("  Graph Tissue™ is a trademark of Luke Spooner")
    print("=" * 64)
    print()

    # Phase 1: Generate characters
    # (Characters are generated by external agents and written to disk)
    # Check if derby characters already exist (for re-running scoring only)
    sonnet_names = [f"derby_sonnet_{i}" for i in range(1, 6)]
    codex_names = [f"derby_codex_{i}" for i in range(1, 6)]
    all_names = sonnet_names + codex_names

    have_all = all((CONFIG_WS / f"{n}.json").exists() for n in all_names)

    if not have_all:
        print("[!] Character profiles not yet generated.")
        print("    Run the lane agents first to create profiles.")
        print(f"    Expected: {CONFIG_WS}/derby_sonnet_1.json .. derby_codex_5.json")
        sys.exit(1)

    print("[1/4] Loading 10 derby characters...")
    for name in all_names:
        p = CONFIG_WS / f"{name}.json"
        pw = CONFIG_PW / f"{name}.json"
        profile = json.loads(p.read_text())
        weights = json.loads(pw.read_text()) if pw.exists() else {}
        lane = "sonnet" if "sonnet" in name else "codex"
        res_sum = sum(profile.get("resources", {}).values())
        n_biomes = len(profile.get("unlocked_biomes", []))
        n_weights = len(weights)
        print(f"  {name:24s}  lane={lane}  res={res_sum:4.0f}  biomes={n_biomes}  tissue_overrides={n_weights}")
    print()

    # Phase 2: Run matrix (all 10 profiles)
    print("[2/4] Running milk_hunt_matrix (5 runs per character, 220 loops)...")
    profiles_csv = ",".join(all_names)
    log_dir = HERE / "logs" / "milk_batches"
    log_dir.mkdir(parents=True, exist_ok=True)
    matrix_cmd = [
        sys.executable, str(HERE / "milk_hunt_matrix.py"),
        "--profiles", profiles_csv,
        "--runs", "5",
        "--max-loops", "220",
        "--console-profile", "quiet",
        "--output-dir", str(log_dir),
    ]
    print(f"  cmd: {' '.join(matrix_cmd[:6])} ...")
    print()

    t0 = time.time()
    proc = subprocess.run(matrix_cmd, capture_output=True, text=True, timeout=3600)
    elapsed = time.time() - t0
    print(f"  Matrix completed in {elapsed:.0f}s (exit={proc.returncode})")
    if proc.returncode != 0:
        print(f"  STDERR: {(proc.stderr or '')[-500:]}")

    # Phase 3: Score
    print()
    print("[3/4] Scoring...")

    # Find the latest matrix output
    matrix_dirs = sorted(log_dir.glob("matrix_*"), key=lambda p: p.name, reverse=True)
    if not matrix_dirs:
        print("  No matrix output found!")
        sys.exit(1)
    matrix_dir = matrix_dirs[0]
    print(f"  Matrix dir: {matrix_dir.name}")

    matrix_summary_path = matrix_dir / "matrix_summary.json"
    if not matrix_summary_path.exists():
        print("  No matrix_summary.json!")
        sys.exit(1)

    matrix_summary = json.loads(matrix_summary_path.read_text())
    results = []
    for entry in matrix_summary.get("results", []):
        bs = entry.get("batch_summary", {})
        if not bs:
            continue
        profile_name = bs.get("profile", entry.get("profile", "?"))
        lane = "sonnet" if "sonnet" in profile_name else "codex"
        scores = score_batch_summary(bs)

        # Load the character's resources and policy weights for learning
        profile_path = CONFIG_WS / f"{profile_name}.json"
        pw_path = CONFIG_PW / f"{profile_name}.json"
        resources = {}
        policy_weights = {}
        if profile_path.exists():
            resources = json.loads(profile_path.read_text()).get("resources", {})
        if pw_path.exists():
            policy_weights = json.loads(pw_path.read_text())

        results.append({
            "name": profile_name,
            "lane": lane,
            "scores": scores,
            "resources": resources,
            "policy_weights": policy_weights,
        })

    results.sort(key=lambda r: r["scores"]["composite"], reverse=True)

    print()
    print(f"  {'Rank':<5} {'Character':<26} {'Lane':<8} {'SR':>5} {'Speed':>6} {'Biome':>6} {'Total':>7}")
    print("  " + "-" * 64)
    for i, r in enumerate(results):
        s = r["scores"]
        print(f"  {i+1:<5} {r['name']:<26} {r['lane']:<8} {s['success_rate']:5.0%} {s['speed_score']:6.2f} {s['biome_score']:6.2f} {s['composite']:7.4f}")

    # Lane totals
    sonnet_total = sum(r["scores"]["composite"] for r in results if r["lane"] == "sonnet")
    codex_total = sum(r["scores"]["composite"] for r in results if r["lane"] == "codex")
    print()
    print(f"  SONNET TOTAL: {sonnet_total:.4f}")
    print(f"  CODEX  TOTAL: {codex_total:.4f}")
    winner_lane = "SONNET" if sonnet_total > codex_total else "CODEX"
    print(f"  LANE WINNER: {winner_lane} (+{abs(sonnet_total - codex_total):.4f})")

    # Phase 4: Extract learnings
    print()
    print("[4/4] Extracting Graph Tissue™ learnings...")
    learnings = extract_learnings(results)

    learnings_path = matrix_dir / "tissue_learnings.json"
    learnings_path.write_text(json.dumps(learnings, indent=2, ensure_ascii=False) + "\n")
    print(f"  Saved: {learnings_path}")

    if learnings["tissue_signal"]:
        print()
        print("  Graph Tissue™ signals (winning weight deltas from defaults):")
        for k, sig in learnings["tissue_signal"].items():
            print(f"    {sig['direction']} {k}: {sig['mean_delta']:+.3f}  (n={sig['n_winners']})")

    if learnings["resource_signal"]:
        print()
        print("  Resource signals (winner vs loser averages):")
        for emoji, sig in learnings["resource_signal"].items():
            print(f"    {emoji}: winners={sig['winner_avg']:.0f} losers={sig['loser_avg']:.0f} (delta={sig['delta']:+.0f})")

    # Save full derby report
    report = {
        "derby": "character_derby_v1",
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "lanes": {"sonnet_total": sonnet_total, "codex_total": codex_total, "winner": winner_lane},
        "results": results,
        "learnings": learnings,
    }
    report_path = matrix_dir / "derby_report.json"
    report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False, default=str) + "\n")
    print(f"\n  Full report: {report_path}")
    print("=" * 64)


if __name__ == "__main__":
    main()
