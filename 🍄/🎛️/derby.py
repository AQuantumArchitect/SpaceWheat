#!/usr/bin/env python3
"""Character-policy derby for milk hunt.

This is the higher-order 🍄 layer over:
- world_state / save seeding
- canonical engine policy graphs

Each match is:
  character seed × hunter policy × milk_hunt_batch
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List

from milk_hunt_characters import (
    get_character,
    list_character_names,
    resolve_character_policy,
    resolve_character_world_state,
)


HERE = Path(__file__).resolve().parent
SEED_SAVE = HERE / "milk_hunt_seed_save.py"
BATCH = HERE / "milk_hunt_batch.py"
LOG_ROOT = HERE / "logs" / "derby"


@dataclass
class DerbyResult:
    character: str
    policy: str
    save_uri: str
    strict_biome_economy: bool
    policy_graph_path: str
    policy_graph_jsonl: List[str]
    found_milk: bool
    loops_completed: int
    steps: int
    elapsed_s: float
    exit_code: int
    batch_summary: Dict[str, Any]


def _save_uri(character_name: str, policy: str) -> str:
    return f"user://saves/characters/{character_name}__{policy}.tres"


def _score(result: DerbyResult) -> Dict[str, float]:
    summary = result.batch_summary
    success_rate = float(summary.get("success_rate", 1.0 if result.found_milk else 0.0))
    avg_steps = float(summary.get("avg_steps_success_only", result.steps if result.found_milk else 999.0))
    speed = 0.0
    if success_rate > 0.0 and avg_steps < 999.0:
        speed = max(0.0, 1.0 - avg_steps / 300.0)
    vocab = float(summary.get("avg_vocab_milestones_per_run", 0.0))
    vocab_score = min(1.0, vocab / 40.0)
    biome_score = min(1.0, float(summary.get("avg_biomes_discovered_per_run", 0.0)) / 4.0)
    drain_score = min(1.0, float(summary.get("avg_lindblad_drains_established_per_run", 0.0)) / 2.0)
    composite = (
        0.60 * success_rate
        + 0.15 * speed
        + 0.15 * vocab_score
        + 0.05 * biome_score
        + 0.05 * drain_score
    )
    return {
        "success_rate": round(success_rate, 4),
        "speed_score": round(speed, 4),
        "vocab_score": round(vocab_score, 4),
        "biome_score": round(biome_score, 4),
        "drain_score": round(drain_score, 4),
        "composite": round(composite, 4),
        "avg_steps_winners": round(avg_steps, 1),
    }


def _latest_batch_summary(match_dir: Path) -> Dict[str, Any]:
    summaries = sorted(match_dir.rglob("batch_summary.json"))
    for path in reversed(summaries):
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
    return {}


def _seed_character(
    character_name: str,
    policy: str,
    reuse_listener: bool,
    display_mode: str,
    timeout_s: int = 180,
) -> Dict[str, Any]:
    save_uri = _save_uri(character_name, policy)
    cmd = [
        sys.executable,
        str(SEED_SAVE),
        "--slot",
        "2",
        "--character",
        character_name,
        "--policy-mode",
        policy,
        "--display-mode",
        display_mode,
        "--save-path",
        save_uri,
    ]
    if reuse_listener:
        cmd.append("--reuse-listener")
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=max(1, int(timeout_s)))
    if proc.returncode not in (0, 3):
        raise RuntimeError(
            "seed failed for %s/%s\n%s%s"
            % (character_name, policy, proc.stdout or "", proc.stderr or "")
        )
    return {"save_uri": save_uri, "stdout": proc.stdout, "stderr": proc.stderr}


def _run_match(
    character_name: str,
    policy: str,
    runs: int,
    max_loops: int,
    runtime_profile: str,
    console_profile: str,
    display_mode: str,
    policy_execution_backend: str,
    output_dir: Path,
    reuse_listener: bool,
    seed_timeout_s: int = 180,
    match_timeout_s: int = 200,
) -> DerbyResult:
    character = get_character(character_name)
    world_state = resolve_character_world_state(character)
    policy_cfg = resolve_character_policy(character, policy)
    strict = bool(world_state.get("strict_biome_economy", True))

    seed_result = _seed_character(
        character_name,
        policy,
        reuse_listener=reuse_listener,
        display_mode=display_mode,
        timeout_s=int(seed_timeout_s),
    )
    save_uri = str(seed_result["save_uri"])

    match_dir = output_dir / f"{character_name}__{policy}"
    match_dir.mkdir(parents=True, exist_ok=True)

    cmd = [
        sys.executable,
        str(BATCH),
        "--runs",
        str(runs),
        "--max-loops",
        str(max_loops),
        "--profile-save",
        save_uri,
        "--hunter-profile",
        character_name,
        "--hunter-policy",
        policy,
        "--runtime-profile",
        runtime_profile,
        "--console-profile",
        console_profile,
        "--display-mode",
        display_mode,
        "--policy-execution-backend",
        policy_execution_backend,
        "--output-dir",
        str(match_dir),
    ]
    cmd.append("--strict-biome-economy" if strict else "--no-strict-biome-economy")
    cmd.append("--reuse-listener" if reuse_listener else "--no-reuse-listener")

    t0 = time.time()
    proc = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=max(1, int(match_timeout_s)),
    )
    elapsed = round(time.time() - t0, 2)
    batch_summary = _latest_batch_summary(match_dir)

    run_rows = batch_summary.get("run_summaries", [])
    first = run_rows[0] if run_rows else {}
    return DerbyResult(
        character=character_name,
        policy=policy,
        save_uri=save_uri,
        strict_biome_economy=strict,
        policy_graph_path=str(policy_cfg.get("policy_graph_path", "")),
        policy_graph_jsonl=[str(x) for x in policy_cfg.get("policy_graph_jsonl", [])],
        found_milk=bool(first.get("found_milk_pair", False)),
        loops_completed=int(first.get("loops_completed", 0) or 0),
        steps=int(first.get("steps", first.get("turns_executed", 0) or 0) or 0),
        elapsed_s=elapsed,
        exit_code=int(proc.returncode),
        batch_summary=batch_summary,
    )


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run a character-policy derby matrix")
    parser.add_argument(
        "--characters",
        nargs="+",
        default=None,
        help="Character names/paths (default: all character specs)",
    )
    parser.add_argument(
        "--policies",
        nargs="+",
        default=["engine_policy", "quantum_register"],
        choices=["engine_policy", "quantum_register"],
        help="Hunter policies to compare",
    )
    parser.add_argument("--runs", type=int, default=1, help="Runs per character/policy match")
    parser.add_argument("--max-loops", type=int, default=13, help="Max loops per run")
    parser.add_argument(
        "--runtime-profile",
        choices=["default", "quantum_fiber_nodes", "io_min"],
        default="io_min",
    )
    parser.add_argument(
        "--console-profile",
        choices=["quiet", "normal", "debug", "trace", "test"],
        default="quiet",
    )
    parser.add_argument(
        "--display-mode",
        choices=["headless", "headed"],
        default="headless",
        help="Launch derby matches headless or visible",
    )
    parser.add_argument(
        "--policy-execution-backend",
        choices=["auto", "direct", "player_input"],
        default="auto",
        help="How policy steps execute inside the rig",
    )
    parser.add_argument("--reuse-listener", dest="reuse_listener", action="store_true")
    parser.add_argument("--no-reuse-listener", dest="reuse_listener", action="store_false")
    parser.set_defaults(reuse_listener=True)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=LOG_ROOT,
        help="Directory for derby reports",
    )
    parser.add_argument("--seed-timeout", type=int, default=180, help="Per-character seed timeout in seconds")
    parser.add_argument("--match-timeout", type=int, default=200, help="Per-character match timeout in seconds")
    return parser


def main() -> int:
    args = _build_parser().parse_args()
    characters = args.characters or list_character_names()
    if not characters:
        print("no character specs found", file=sys.stderr)
        return 2

    ts = time.strftime("%Y%m%d_%H%M%S")
    derby_dir = args.output_dir / f"derby_{ts}"
    derby_dir.mkdir(parents=True, exist_ok=True)

    print("=" * 72, flush=True)
    print("  CHARACTER POLICY DERBY", flush=True)
    print("  higher-order 🍄 layer: character seed × policy graph × milk hunt", flush=True)
    print(f"  characters={','.join(characters)}", flush=True)
    print(f"  policies={','.join(args.policies)} runs={args.runs} max_loops={args.max_loops}", flush=True)
    print("=" * 72, flush=True)

    results: List[DerbyResult] = []
    started = time.time()
    for character_name in characters:
        for policy in args.policies:
            print(f"\n[{character_name} :: {policy}]", flush=True)
            try:
                result = _run_match(
                    character_name=character_name,
                    policy=policy,
                    runs=int(args.runs),
                    max_loops=int(args.max_loops),
                    runtime_profile=str(args.runtime_profile),
                    console_profile=str(args.console_profile),
                    display_mode=str(args.display_mode),
                    policy_execution_backend=str(args.policy_execution_backend),
                    output_dir=derby_dir,
                    reuse_listener=bool(args.reuse_listener),
                    seed_timeout_s=int(args.seed_timeout),
                    match_timeout_s=int(args.match_timeout),
                )
            except Exception as exc:
                print(f"  failed: {exc}", flush=True)
                continue
            results.append(result)
            print(
                "  milk=%s loops=%d steps=%d exit=%d elapsed=%.1fs"
                % (
                    "yes" if result.found_milk else "no",
                    result.loops_completed,
                    result.steps,
                    result.exit_code,
                    result.elapsed_s,
                )
            , flush=True)

    elapsed = round(time.time() - started, 2)
    scored = []
    for result in results:
        scored.append(
            {
                "character": result.character,
                "policy": result.policy,
                "save_uri": result.save_uri,
                "strict_biome_economy": result.strict_biome_economy,
                "policy_graph_path": result.policy_graph_path,
                "policy_graph_jsonl": result.policy_graph_jsonl,
                "found_milk": result.found_milk,
                "loops_completed": result.loops_completed,
                "steps": result.steps,
                "elapsed_s": result.elapsed_s,
                "exit_code": result.exit_code,
                "scores": _score(result),
                "resources": resolve_character_world_state(get_character(result.character)).get("resources", {}),
            }
        )
    scored.sort(key=lambda row: row["scores"]["composite"], reverse=True)

    print(f"\n{'#':<3} {'Character':<24} {'Policy':<17} {'Milk':<5} {'Loops':>5} {'Steps':>6} {'Score':>7}", flush=True)
    print("  " + "-" * 74, flush=True)
    for idx, row in enumerate(scored, start=1):
        print(
            f"  {idx:<3} {row['character']:<24} {row['policy']:<17} "
            f"{('yes' if row['found_milk'] else 'no'):<5} {row['loops_completed']:>5} {row['steps']:>6} "
            f"{row['scores']['composite']:>7.4f}"
        , flush=True)

    by_policy: Dict[str, List[float]] = {}
    for row in scored:
        by_policy.setdefault(str(row["policy"]), []).append(float(row["scores"]["composite"]))
    policy_totals = {
        key: round(sum(vals) / max(1, len(vals)), 4)
        for key, vals in by_policy.items()
    }

    report = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "elapsed_s": elapsed,
        "characters": characters,
        "policies": args.policies,
        "runs": int(args.runs),
        "max_loops": int(args.max_loops),
        "results": scored,
        "policy_totals": policy_totals,
    }
    report_path = derby_dir / "derby_summary.json"
    report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"\nreport: {report_path}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
