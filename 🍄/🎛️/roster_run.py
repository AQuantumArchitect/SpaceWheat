#!/usr/bin/env python3
"""Roster batch runner: run 5 characters from a roster JSON and produce a scorecard.

A roster defines 5 characters with world_state, policy_overrides, and tuning.
The runner executes each sequentially, scores them, and writes results to a
leaderboard JSONL for cross-roster comparison.

Usage:
    python3 roster_run.py --roster config/rosters/baseline_v1.json
    python3 roster_run.py --roster config/rosters/baseline_v1.json --max-loops 55 --timeout 300
"""
import argparse
import json
import math
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

from run_executor import cleanup_process_patterns, ensure_lane, parse_last_json, run_cli, run_seed

_RUNNER_DIR = Path(__file__).resolve().parent


def _project_root() -> Path:
    return _RUNNER_DIR.parent.parent


def _cleanup_stale() -> None:
    cleanup_process_patterns(["milk_hunt_runner.py", "Rig/rig_listener.gd"])


def seed_character(
    *,
    world_state: str,
    lane,
    slot: int = 2,
    timeout: int = 90,
) -> bool:
    """Seed a save slot from a world state profile or JSON path."""
    ws_path = Path(world_state)
    result = run_seed(
        lane=lane,
        timeout_s=timeout,
        slot=slot,
        world_state=str(ws_path) if ws_path.exists() else None,
        profile=None if ws_path.exists() else world_state,
        reuse_listener=False,
    )
    return int(result.get("exit_code", 1)) == 0


def run_character(
    *,
    name: str,
    world_state: str,
    lane,
    policy_mode: str = "quantum_register",
    policy_profile: str = "",
    policy_overrides_path: Optional[str] = None,
    max_loops: int = 89,
    slot: int = 2,
    timeout: int = 420,
) -> Optional[Dict[str, Any]]:
    """Run a single character's milk hunt and return summary JSON."""
    runner = _RUNNER_DIR / "milk_hunt_runner.py"
    cmd = [
        sys.executable, str(runner),
        "--hunter-policy", policy_mode,
        "--hunter-profile", policy_profile or name,
        "--load-slot", str(slot),
        "--max-loops", str(max_loops),
        "--console-profile", "quiet",
        "--json-only",
    ]

    try:
        proc = run_cli(
            cmd,
            lane=lane,
            timeout_s=timeout,
            cwd=_project_root(),
            extra_env={
                "RIG_DISABLE_LOOKAHEAD": "1",
                "PYTHONUNBUFFERED": "1",
            },
        )
    except subprocess.TimeoutExpired:
        _cleanup_stale()
        return None

    payload = parse_last_json(proc.stdout or "", proc.stderr or "")
    return payload or None


def write_policy_overrides(overrides: List[Dict[str, Any]], name: str) -> Optional[str]:
    """Write policy overrides to a temp JSONL file, return path. Returns None if empty."""
    if not overrides:
        return None
    path = Path(tempfile.gettempdir()) / f"roster_policy_{name}.jsonl"
    with open(path, "w", encoding="utf-8") as f:
        for entry in overrides:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    return str(path)


def write_inline_world_state(world_state: Dict[str, Any], name: str) -> str:
    """Write inline world state dict to a temp JSON, return path."""
    path = Path(tempfile.gettempdir()) / f"roster_ws_{name}.json"
    with open(path, "w", encoding="utf-8") as f:
        json.dump(world_state, f, ensure_ascii=False, indent=2)
    return str(path)


def score_character(summary: Dict[str, Any], max_loops: int) -> Dict[str, Any]:
    """Compute composite score for a character run."""
    found_milk = bool(summary.get("found_milk", False))
    loops = int(summary.get("loops_completed", 0) or 0)
    icons = int(summary.get("known_icons_count", 0) or 0)
    biomes = len(summary.get("biome_discovery_order", []) or [])
    action_counts = summary.get("policy_action_counts", {}) or {}
    total_actions = sum(action_counts.values()) or 1

    # Action entropy (bits)
    entropy = 0.0
    for count in action_counts.values():
        if count > 0:
            p = count / total_actions
            entropy -= p * math.log2(p)

    # Primary: milk found
    milk_score = 1.0 if found_milk else 0.0

    # Speed: fewer loops = better (only counts if milk found)
    speed_score = max(0.0, 1.0 - loops / (max_loops * 2.0)) if found_milk else 0.0

    # Vocabulary breadth
    vocab_score = min(1.0, icons / 15.0)

    # Action diversity
    diversity_score = min(1.0, entropy / 2.5)

    composite = (
        0.50 * milk_score +
        0.25 * speed_score +
        0.15 * vocab_score +
        0.10 * diversity_score
    )

    return {
        "milk": milk_score,
        "speed": round(speed_score, 4),
        "vocab": round(vocab_score, 4),
        "diversity": round(diversity_score, 4),
        "composite": round(composite, 4),
    }


def extract_step_stats(summary: Dict[str, Any]) -> Dict[str, Any]:
    """Extract per-step stats from policy_decisions trace."""
    decisions = summary.get("policy_decisions", [])
    if not decisions:
        return {}

    total_steps = 0
    quest_steps = 0
    quest_accepted = 0
    quest_completed = 0
    rewards: List[float] = []

    for ev in decisions:
        if ev.get("kind") == "trace_truncated":
            continue
        total_steps += 1
        action = str(ev.get("executed_action") or ev.get("selected_action", ""))
        reward = float(ev.get("reward", 0.0))
        rewards.append(reward)

        if action == "quest_cycle":
            quest_steps += 1
            if ev.get("accepted"):
                quest_accepted += 1
            if ev.get("completed_after_accept"):
                quest_completed += 1

    avg_reward = sum(rewards) / len(rewards) if rewards else 0.0
    return {
        "total_steps": total_steps,
        "quest_steps": quest_steps,
        "quest_accepted": quest_accepted,
        "quest_completed": quest_completed,
        "quest_accept_rate": round(quest_accepted / max(1, quest_steps), 2),
        "avg_reward": round(avg_reward, 2),
    }


def load_roster(path: Path) -> Dict[str, Any]:
    """Load and validate a roster JSON."""
    data = json.loads(path.read_text(encoding="utf-8"))
    assert "characters" in data, "Roster must have 'characters' array"
    assert len(data["characters"]) >= 1, "Roster must have at least 1 character"
    return data


def main() -> None:
    parser = argparse.ArgumentParser(description="Run a roster of characters and produce a scorecard")
    parser.add_argument("--roster", type=Path, required=True, help="Roster JSON file")
    parser.add_argument("--max-loops", type=int, default=None,
                        help="Override max loops for all characters (default: use roster value)")
    parser.add_argument("--timeout", type=int, default=420, help="Per-character timeout in seconds")
    parser.add_argument("--output-dir", type=Path, default=Path("/tmp/roster_results"),
                        help="Output directory for scorecards")
    parser.add_argument("--leaderboard", type=Path, default=None,
                        help="Leaderboard JSONL path (default: output-dir/leaderboard.jsonl)")
    parser.add_argument("--slot", type=int, default=2, help="Save slot to use")
    args = parser.parse_args()
    lane = ensure_lane()

    roster = load_roster(args.roster)
    roster_id = roster.get("roster_id", args.roster.stem)
    author = roster.get("author", "unknown")
    characters = roster["characters"]
    roster_max_loops = args.max_loops or roster.get("max_loops", 89)
    roster_policy_mode = roster.get("policy_mode", "quantum_register")

    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    run_dir = args.output_dir / f"{roster_id}_{timestamp}"
    run_dir.mkdir(parents=True, exist_ok=True)

    leaderboard_path = args.leaderboard or (args.output_dir / "leaderboard.jsonl")

    print(f"[roster] {roster_id} by {author}", flush=True)
    print(f"[roster] {len(characters)} characters, max_loops={roster_max_loops}, policy={roster_policy_mode}", flush=True)
    print(f"[roster] Output: {run_dir}", flush=True)
    print(flush=True)

    results: List[Dict[str, Any]] = []
    total_elapsed = 0.0

    for i, char in enumerate(characters):
        char_name = char["name"]
        char_max_loops = char.get("max_loops", roster_max_loops)
        char_policy = char.get("policy_mode", roster_policy_mode)
        char_ws = char.get("world_state", char_name)
        char_overrides = char.get("policy_overrides", [])

        print(f"{'='*60}", flush=True)
        print(f"[{i+1}/{len(characters)}] {char_name}  biome={char.get('description', '')}", flush=True)

        # Resolve world state
        if isinstance(char_ws, dict):
            ws_ref = write_inline_world_state(char_ws, char_name)
        else:
            ws_ref = str(char_ws)

        # Write policy overrides if any
        overrides_path = write_policy_overrides(char_overrides, char_name)

        # Seed
        seed_ok = seed_character(world_state=ws_ref, lane=lane, slot=args.slot)
        if not seed_ok:
            print(f"[{char_name}] Seed failed, skipping", flush=True)
            results.append({
                "slot": char.get("slot", i+1),
                "name": char_name,
                "status": "seed_failed",
                "score": {"milk": 0, "speed": 0, "vocab": 0, "diversity": 0, "composite": 0},
            })
            continue

        # Run
        t0 = time.time()
        summary = run_character(
            name=char_name,
            world_state=ws_ref,
            lane=lane,
            policy_mode=char_policy,
            policy_profile=char_name,
            policy_overrides_path=overrides_path,
            max_loops=char_max_loops,
            slot=args.slot,
            timeout=args.timeout,
        )
        elapsed = time.time() - t0
        total_elapsed += elapsed

        if summary is None:
            print(f"[{char_name}] TIMEOUT after {elapsed:.0f}s", flush=True)
            results.append({
                "slot": char.get("slot", i+1),
                "name": char_name,
                "status": "timeout",
                "elapsed_s": round(elapsed, 1),
                "score": {"milk": 0, "speed": 0, "vocab": 0, "diversity": 0, "composite": 0},
            })
            continue

        # Score
        found_milk = bool(summary.get("found_milk", False))
        loops = summary.get("loops_completed", "?")
        icons = int(summary.get("known_icons_count", 0) or 0)
        action_pct = summary.get("policy_action_pct", {})
        quest_pct = action_pct.get("quest_cycle", 0) * 100

        score = score_character(summary, char_max_loops)
        step_stats = extract_step_stats(summary)

        milk_str = "MILK!" if found_milk else "no milk"
        print(f"[{char_name}] {milk_str}  loops={loops}  icons={icons}  "
              f"quest={quest_pct:.0f}%  score={score['composite']:.3f}  ({elapsed:.0f}s)", flush=True)

        if step_stats:
            accept = step_stats.get("quest_accept_rate", 0)
            avg_r = step_stats.get("avg_reward", 0)
            print(f"  steps={step_stats['total_steps']}  "
                  f"quest_accepted={step_stats['quest_accepted']}  "
                  f"accept_rate={accept:.0%}  avg_reward={avg_r:+.1f}", flush=True)

        # Save individual summary
        char_summary_path = run_dir / f"{char_name}.json"
        char_summary_path.write_text(
            json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
        )

        results.append({
            "slot": char.get("slot", i+1),
            "name": char_name,
            "status": "ok",
            "found_milk": found_milk,
            "loops": loops,
            "icons": icons,
            "quest_pct": round(quest_pct, 1),
            "elapsed_s": round(elapsed, 1),
            "score": score,
            "step_stats": step_stats,
            "world_state": char_ws if isinstance(char_ws, str) else char_ws.get("name", char_name),
            "policy_overrides": char_overrides,
        })

    # Scorecard
    print(f"\n{'='*60}", flush=True)
    print(f"[roster] SCORECARD: {roster_id}", flush=True)
    print(flush=True)

    completed = [r for r in results if r["status"] == "ok"]
    milk_count = sum(1 for r in completed if r.get("found_milk", False))
    composites = [r["score"]["composite"] for r in results]
    roster_score = sum(composites) / len(composites) if composites else 0.0

    print(f"{'Slot':>5s} {'Name':<25s} {'Milk':>5s} {'Loops':>6s} {'Icons':>6s} "
          f"{'Quest%':>7s} {'Score':>6s} {'Time':>6s}", flush=True)
    print("-" * 72, flush=True)
    for r in results:
        name = r["name"][:24]
        milk_s = "YES" if r.get("found_milk") else ("--" if r["status"] != "ok" else "no")
        loops_s = str(r.get("loops", "--"))
        icons_s = str(r.get("icons", "--"))
        quest_s = f"{r.get('quest_pct', 0):.0f}%" if r["status"] == "ok" else "--"
        score_s = f"{r['score']['composite']:.3f}"
        time_s = f"{r.get('elapsed_s', 0):.0f}s" if "elapsed_s" in r else "--"
        print(f"{r['slot']:>5d} {name:<25s} {milk_s:>5s} {loops_s:>6s} {icons_s:>6s} "
              f"{quest_s:>7s} {score_s:>6s} {time_s:>6s}", flush=True)

    print(f"\nRoster score: {roster_score:.4f}  "
          f"({milk_count}/{len(results)} milk, {total_elapsed:.0f}s total)", flush=True)

    # Write scorecard JSON
    scorecard = {
        "roster_id": roster_id,
        "author": author,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "roster_score": round(roster_score, 4),
        "milk_count": milk_count,
        "total_characters": len(results),
        "total_elapsed_s": round(total_elapsed, 1),
        "policy_mode": roster_policy_mode,
        "max_loops": roster_max_loops,
        "characters": results,
        "roster_path": str(args.roster),
    }
    scorecard_path = run_dir / "scorecard.json"
    scorecard_path.write_text(
        json.dumps(scorecard, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"\nScorecard: {scorecard_path}", flush=True)

    # Append to leaderboard
    leaderboard_entry = {
        "roster_id": roster_id,
        "author": author,
        "timestamp": scorecard["timestamp"],
        "roster_score": scorecard["roster_score"],
        "milk_count": milk_count,
        "characters": [
            {"name": r["name"], "milk": r.get("found_milk", False),
             "loops": r.get("loops", None), "composite": r["score"]["composite"]}
            for r in results
        ],
        "total_elapsed_s": round(total_elapsed, 1),
        "scorecard_path": str(scorecard_path),
    }
    leaderboard_path.parent.mkdir(parents=True, exist_ok=True)
    with open(leaderboard_path, "a", encoding="utf-8") as f:
        f.write(json.dumps(leaderboard_entry, ensure_ascii=False) + "\n")
    print(f"Leaderboard: {leaderboard_path}", flush=True)


if __name__ == "__main__":
    main()
