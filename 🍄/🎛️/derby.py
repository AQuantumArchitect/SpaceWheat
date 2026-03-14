#!/usr/bin/env python3
"""Derby: N agents compete, each running hunters via milk_hunt_batch.

Each agent (lane) gets one Godot rig (isolated XDG_ROOT). Its hunters
run sequentially via milk_hunt_batch.py on that rig. Agents run in
parallel — one rig per agent.

Architecture:
  Derby (N agents in parallel, 1 rig per agent)
  ├── Agent: sonnet  (1 rig @ /tmp/sw_derby_sonnet)
  │   ├── milk_hunt_batch --profile derby_sonnet_1 --runs 1
  │   ├── milk_hunt_batch --profile derby_sonnet_2 --runs 1
  │   ├── ...
  │   └── milk_hunt_batch --profile derby_sonnet_5 --runs 1
  └── Agent: codex   (1 rig @ /tmp/sw_derby_codex)
      ├── milk_hunt_batch --profile derby_codex_1 --runs 1
      └── ...

Graph Tissue™ is a trademark of Luke Spooner.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from concurrent.futures import ProcessPoolExecutor, as_completed
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional

HERE = Path(__file__).resolve().parent
CONFIG_WS = HERE / "config" / "world_state"
CONFIG_PW = HERE / "config" / "policy_weights"
LOG_DIR = HERE / "logs" / "derby"
BATCH_SCRIPT = HERE / "milk_hunt_batch.py"

# Graph Tissue™ weight ranges — for learning extraction
WEIGHT_RANGES: Dict[str, Any] = {
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


@dataclass
class HunterResult:
    profile: str
    lane: str
    found_milk: bool
    loops_completed: int
    steps: int
    elapsed_s: float
    exit_code: int
    batch_summary: Dict[str, Any]


@dataclass
class AgentResult:
    lane: str
    hunters: List[HunterResult] = field(default_factory=list)
    total_elapsed_s: float = 0.0


def _xdg_for_agent(lane: str) -> str:
    """One XDG_ROOT per agent — isolates from other agents and QA."""
    return f"/tmp/sw_derby_{lane}"


def run_agent(
    lane: str,
    profiles: List[str],
    max_loops: int,
    console_profile: str,
    hunter_policy: str,
    derby_dir: Path,
) -> AgentResult:
    """Run all hunters for one agent, sequentially on one rig.

    Called in a worker process — agents run in parallel.
    """
    env = os.environ.copy()
    env["XDG_ROOT"] = _xdg_for_agent(lane)

    agent = AgentResult(lane=lane)
    t_agent = time.time()

    for i, profile in enumerate(profiles):
        batch_output = derby_dir / lane / profile
        batch_output.mkdir(parents=True, exist_ok=True)

        cmd = [
            sys.executable, str(BATCH_SCRIPT),
            "--profile", profile,
            "--runs", "1",
            "--max-loops", str(max_loops),
            "--hunter-policy", hunter_policy,
            "--console-profile", console_profile,
            "--output-dir", str(batch_output),
        ]

        t0 = time.time()
        try:
            proc = subprocess.run(
                cmd, capture_output=True, text=True,
                timeout=max(300, max_loops * 30), env=env,
            )
        except subprocess.TimeoutExpired:
            elapsed = time.time() - t0
            agent.hunters.append(HunterResult(
                profile=profile, lane=lane, found_milk=False,
                loops_completed=0, steps=0, elapsed_s=elapsed,
                exit_code=-1, batch_summary={"error": "timeout"},
            ))
            print(f"  [{lane}] {profile}: TIMEOUT ({elapsed:.0f}s)", flush=True)
            continue
        elapsed = time.time() - t0

        # Find batch_summary.json
        batch_summary: Dict[str, Any] = {}
        for summary_file in sorted(batch_output.rglob("batch_summary.json")):
            try:
                batch_summary = json.loads(summary_file.read_text())
                break
            except (json.JSONDecodeError, OSError):
                pass

        # Extract result from first (only) run
        run_summaries = batch_summary.get("run_summaries", [])
        run = run_summaries[0] if run_summaries else {}

        result = HunterResult(
            profile=profile, lane=lane,
            found_milk=bool(run.get("found_milk_pair", False)),
            loops_completed=int(run.get("loops_completed", 0)),
            steps=int(run.get("steps", run.get("turns_executed", 0) or 0) or 0),
            elapsed_s=round(elapsed, 2),
            exit_code=proc.returncode,
            batch_summary=batch_summary,
        )
        agent.hunters.append(result)

        tag = "MILK!" if result.found_milk else f"exit={result.exit_code}"
        print(f"  [{lane}] {profile}: {tag}  "
              f"loops={result.loops_completed}  steps={result.steps}  "
              f"{result.elapsed_s:.0f}s", flush=True)

    agent.total_elapsed_s = round(time.time() - t_agent, 2)
    return agent


def score_hunter(result: HunterResult) -> Dict[str, float]:
    """Score one hunter from its batch_summary."""
    bs = result.batch_summary
    sr = float(bs.get("success_rate", 1.0 if result.found_milk else 0.0))
    avg_steps = float(bs.get("avg_steps_success_only", result.steps if result.found_milk else 999))
    biomes = len(bs.get("discovered_biomes_union", []))
    vocab = float(bs.get("avg_vocab_milestones_per_run", 0))

    speed = max(0.0, 1.0 - avg_steps / 300.0) if avg_steps < 999 else 0.0
    biome_score = min(1.0, biomes / 6.0)
    vocab_score = min(1.0, vocab / 5.0)
    composite = 0.50 * sr + 0.25 * speed + 0.15 * biome_score + 0.10 * vocab_score
    return {
        "success_rate": round(sr, 4),
        "speed_score": round(speed, 4),
        "biome_score": round(biome_score, 4),
        "vocab_score": round(vocab_score, 4),
        "composite": round(composite, 4),
        "avg_steps_winners": round(avg_steps, 1),
    }


def score_lane(results: List[HunterResult]) -> Dict[str, float]:
    scores = [score_hunter(r) for r in results]
    n = len(scores) or 1
    composite = sum(s["composite"] for s in scores) / n
    sr = sum(s["success_rate"] for s in scores) / n
    speed = sum(s["speed_score"] for s in scores) / n
    biome = sum(s["biome_score"] for s in scores) / n
    vocab = sum(s["vocab_score"] for s in scores) / n
    return {
        "hunters": n,
        "milk_count": sum(1 for r in results if r.found_milk),
        "success_rate": round(sr, 4),
        "speed_score": round(speed, 4),
        "biome_score": round(biome, 4),
        "vocab_score": round(vocab, 4),
        "composite": round(composite, 4),
    }


def extract_learnings(
    all_hunters: List[HunterResult],
    weight_ranges: Dict[str, Any],
) -> Dict[str, Any]:
    """Extract Graph Tissue™ learnings: which weights + resources correlated with success."""
    scored = sorted(all_hunters, key=lambda r: score_hunter(r)["composite"], reverse=True)
    winners = scored[:3]
    losers = scored[3:]

    learnings: Dict[str, Any] = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "trademark": "Graph Tissue™ is a trademark of Luke Spooner",
        "top_hunters": [],
        "tissue_signal": {},
        "resource_signal": {},
    }

    for r in winners:
        learnings["top_hunters"].append({
            "name": r.profile, "lane": r.lane,
            "composite": score_hunter(r)["composite"],
            "found_milk": r.found_milk,
        })

    # Tissue signal: winning weight deltas from defaults
    tissue_deltas: Dict[str, List[float]] = {}
    for r in winners:
        pw_path = CONFIG_PW / f"{r.profile}.json"
        if pw_path.exists():
            pw = json.loads(pw_path.read_text())
            for k, v in pw.items():
                if k in weight_ranges:
                    delta = float(v) - float(weight_ranges[k]["default"])
                    tissue_deltas.setdefault(k, []).append(delta)
    for k, deltas in tissue_deltas.items():
        mean_delta = sum(deltas) / len(deltas)
        if abs(mean_delta) > 0.01:
            learnings["tissue_signal"][k] = {
                "mean_delta": round(mean_delta, 4),
                "direction": "+" if mean_delta > 0 else "-",
                "n_winners": len(deltas),
            }

    # Resource signal: winner vs loser starting resources
    winner_res: Dict[str, List[float]] = {}
    loser_res: Dict[str, List[float]] = {}
    for r in winners:
        prof_path = CONFIG_WS / f"{r.profile}.json"
        if prof_path.exists():
            res = json.loads(prof_path.read_text()).get("resources", {})
            for emoji, val in res.items():
                winner_res.setdefault(emoji, []).append(float(val))
    for r in losers:
        prof_path = CONFIG_WS / f"{r.profile}.json"
        if prof_path.exists():
            res = json.loads(prof_path.read_text()).get("resources", {})
            for emoji, val in res.items():
                loser_res.setdefault(emoji, []).append(float(val))
    all_emojis = set(winner_res) | set(loser_res)
    for emoji in all_emojis:
        w_vals = winner_res.get(emoji, [0])
        l_vals = loser_res.get(emoji, [0])
        w_avg = sum(w_vals) / len(w_vals)
        l_avg = sum(l_vals) / len(l_vals)
        if abs(w_avg - l_avg) > 10:
            learnings["resource_signal"][emoji] = {
                "winner_avg": round(w_avg, 1),
                "loser_avg": round(l_avg, 1),
                "delta": round(w_avg - l_avg, 1),
            }

    return learnings


def main():
    parser = argparse.ArgumentParser(
        description="Derby: N agents compete, each running hunters on 1 rig")
    parser.add_argument("--max-loops", type=int, default=220,
                        help="Max loops per hunter (default: 220)")
    parser.add_argument("--console-profile", default="quiet",
                        choices=["quiet", "normal", "debug", "trace", "test"])
    parser.add_argument("--hunter-policy", default="quantum_graph",
                        choices=["auto", "classic", "quantum_graph",
                                 "engine_policy", "quantum_register"])
    parser.add_argument("--lanes", nargs="+", default=["sonnet", "codex"],
                        help="Agent lanes to compete (default: sonnet codex)")
    parser.add_argument("--hunters-per-lane", type=int, default=5,
                        help="Hunters per agent (default: 5)")
    args = parser.parse_args()

    # Discover profiles per lane
    lane_profiles: Dict[str, List[str]] = {}
    for lane in args.lanes:
        profiles = []
        for i in range(1, args.hunters_per_lane + 1):
            name = f"derby_{lane}_{i}"
            if (CONFIG_WS / f"{name}.json").exists():
                profiles.append(name)
        if profiles:
            lane_profiles[lane] = profiles

    if not lane_profiles:
        print("No derby profiles found! Run lane agents first.")
        sys.exit(1)

    n_agents = len(lane_profiles)
    n_hunters = sum(len(p) for p in lane_profiles.values())

    print("=" * 64)
    print("  DERBY: " + " vs ".join(
        f"{lane.upper()} ({len(ps)} hunters)"
        for lane, ps in lane_profiles.items()))
    print(f"  {n_agents} agents in parallel (1 rig each)")
    print(f"  {n_hunters} hunters total, {args.max_loops} max loops")
    print(f"  policy={args.hunter_policy}")
    print("  Graph Tissue™ is a trademark of Luke Spooner")
    print("=" * 64)

    ts = time.strftime("%Y%m%d_%H%M%S")
    derby_dir = LOG_DIR / f"derby_{ts}"
    derby_dir.mkdir(parents=True, exist_ok=True)

    t_total = time.time()

    # Launch one worker per agent — agents run in parallel
    agent_results: List[AgentResult] = []
    with ProcessPoolExecutor(max_workers=n_agents) as pool:
        futures = {}
        for lane, profiles in lane_profiles.items():
            fut = pool.submit(
                run_agent,
                lane=lane, profiles=profiles,
                max_loops=args.max_loops,
                console_profile=args.console_profile,
                hunter_policy=args.hunter_policy,
                derby_dir=derby_dir,
            )
            futures[fut] = lane

        for fut in as_completed(futures):
            lane = futures[fut]
            try:
                agent = fut.result()
            except Exception as exc:
                agent = AgentResult(lane=lane)
                print(f"  [{lane}] AGENT FAILED: {exc}", flush=True)
            agent_results.append(agent)
            milk = sum(1 for h in agent.hunters if h.found_milk)
            print(f"\n  [{lane}] DONE: {milk}/{len(agent.hunters)} found milk "
                  f"({agent.total_elapsed_s:.0f}s)", flush=True)

    total_elapsed = time.time() - t_total

    # Collect all results
    all_hunters: List[HunterResult] = []
    for agent in agent_results:
        all_hunters.extend(agent.hunters)

    lane_scores: Dict[str, Dict[str, float]] = {}
    for agent in agent_results:
        lane_scores[agent.lane] = score_lane(agent.hunters)

    # Print results
    print(f"\n{'=' * 64}")
    print(f"  RESULTS ({total_elapsed:.0f}s)")
    print(f"{'=' * 64}")

    all_hunters.sort(key=lambda r: (not r.found_milk, r.steps))
    print(f"\n  {'#':<3} {'Hunter':<24} {'Lane':<8} {'Milk':>5} "
          f"{'Loops':>6} {'Steps':>6} {'Time':>7}")
    print("  " + "-" * 60)
    for i, r in enumerate(all_hunters):
        milk = "YES" if r.found_milk else "no"
        print(f"  {i+1:<3} {r.profile:<24} {r.lane:<8} {milk:>5} "
              f"{r.loops_completed:>6} {r.steps:>6} {r.elapsed_s:>6.0f}s")

    print(f"\n  LANE SCORES:")
    for lane, s in sorted(lane_scores.items(),
                          key=lambda x: x[1]["composite"], reverse=True):
        print(f"    {lane.upper():<8} SR={s['success_rate']:.0%}  "
              f"speed={s['speed_score']:.2f}  biome={s['biome_score']:.2f}  "
              f"vocab={s['vocab_score']:.2f}  composite={s['composite']:.4f}")

    winner = None
    if len(lane_scores) == 2:
        lanes = sorted(lane_scores.keys())
        a, b = lanes
        sa, sb = lane_scores[a]["composite"], lane_scores[b]["composite"]
        if sa > sb:
            winner = a.upper()
        elif sb > sa:
            winner = b.upper()
        else:
            winner = "TIE"
        print(f"\n  WINNER: {winner} (+{abs(sa - sb):.4f})")

    # Phase 3: Extract learnings
    print(f"\n  GRAPH TISSUE™ LEARNINGS:")
    learnings = extract_learnings(all_hunters, WEIGHT_RANGES)
    if learnings["tissue_signal"]:
        for k, sig in learnings["tissue_signal"].items():
            print(f"    {sig['direction']} {k}: {sig['mean_delta']:+.4f}  (n={sig['n_winners']})")
    else:
        print("    (no tissue signal — need more winners)")
    if learnings["resource_signal"]:
        print(f"\n  RESOURCE SIGNAL:")
        for emoji, sig in learnings["resource_signal"].items():
            print(f"    {emoji}: winners={sig['winner_avg']:.0f} losers={sig['loser_avg']:.0f} (Δ{sig['delta']:+.0f})")

    # Save summary
    summary = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "total_elapsed_s": round(total_elapsed, 1),
        "max_loops": args.max_loops,
        "hunter_policy": args.hunter_policy,
        "agents": [
            {"lane": a.lane, "elapsed_s": a.total_elapsed_s,
             "hunters": len(a.hunters),
             "xdg_root": _xdg_for_agent(a.lane),
             "milk_found": sum(1 for h in a.hunters if h.found_milk)}
            for a in agent_results
        ],
        "hunters": [
            {"profile": r.profile, "lane": r.lane,
             "found_milk": r.found_milk,
             "loops_completed": r.loops_completed,
             "steps": r.steps, "elapsed_s": r.elapsed_s,
             "exit_code": r.exit_code}
            for r in all_hunters
        ],
        "lane_scores": lane_scores,
        "winner": winner,
        "learnings": learnings,
    }
    summary_path = derby_dir / "derby_summary.json"
    summary_path.write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n")
    print(f"\n  Report: {summary_path}")
    print("=" * 64)


if __name__ == "__main__":
    main()
