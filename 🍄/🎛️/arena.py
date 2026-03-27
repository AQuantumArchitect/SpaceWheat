#!/usr/bin/env python3
"""Arena: unified competition entry point for SpaceWheat.

Replaces 4 separate derby scripts with one CLI:

    python3 arena.py race   --profile balanced_survival --runners 5
    python3 arena.py duel   --lanes sonnet codex --runners-per-lane 5
    python3 arena.py matrix --profiles "derby_*" --runs 5
    python3 arena.py design --lanes sonnet codex

Modes:
  race   - 🏁 Round-robin: N runners race on 1 profile, fibonacci rounds
  duel   - 🏆 Head-to-head: 2+ lanes in parallel, each with N runners
  matrix - 📊 Batch comparison: multiple profiles, N runs each
  design - 🧬 LLM character generation + matrix evaluation

All modes use the same scoring, the same RunnerResult type, and the
same JSON output envelope.  Tissue learning is automatic.

Graph Tissue™ is a trademark of Luke Spooner.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import time
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path
from typing import Any, Dict, List, Optional

from constants import (
    MAX_LOOPS, SECS_PER_CYCLE, SEED_TIMEOUT_S, MATCH_TIMEOUT_S, TIMEOUT_FLOOR,
    run_timeout,
    POLICY_ENGINE, POLICY_QUANTUM, POLICY_MODES,
    DEFAULT_LANES, DEFAULT_RUNNERS, DEFAULT_RUNS_PER_PROFILE,
    TRAIN_MAX_CYCLES_START, TRAIN_CYCLES_STEP, TRAIN_TARGET_WIN_RATE,
)
from emoji import (
    DERBY, RACE, LANE, RUNNER, BATCH, TISSUE, LICHEN, CHARACTER, SCORE,
    LAYER_RACE, LAYER_DUEL, LAYER_MATRIX, LAYER_DESIGN,
    header, tag,
)
from schema import (
    RunnerResult, score_lane, make_envelope,
    format_scoreboard, format_lane_scores,
)
from tissue_ledger import (
    WEIGHT_RANGES, _EMA_ALPHA,
    append_ledger_entry,
    evolve_defaults,
    format_evolved_diff,
    format_policy_projection,
    format_resource_projection,
    jitter_weights,
    lichen_scoring_weights,
    load_evolved_defaults,
    project_jittered_to_policy,
    project_to_policy,
    project_to_resources,
    reverse_policy_to_weights,
    score_with_weights,
)
from profiles import (
    list_derby_names,
    list_derby_lanes,
    list_names,
    exists as profile_exists,
    load as load_profile,
    load_policy_weights,
    load_character,
    list_character_names,
    character_exists,
    resolve_character_seed,
    WORLD_STATE_DIR,
    POLICY_WEIGHTS_DIR,
)
from milk_hunt_io import write_json
from leaderboard import record_results as _record_leaderboard

HERE = Path(__file__).resolve().parent
LOG_DIR = HERE / "logs" / "derby"
BATCH_LOG_DIR = HERE / "logs" / "milk_batches"
BATCH_SCRIPT = HERE / "milk_hunt_batch.py"
SEED_SCRIPT = HERE / "milk_hunt_seed_save.py"
RUNNER_SCRIPT = HERE / "milk_hunt_runner.py"

# Claura lichen bridge
_WS_ROOT = HERE.parent.parent.parent
CLAURA_ROOT = Path(os.environ.get("CLAURA_ROOT", str(_WS_ROOT / "Claura")))
_PROBE_PYTHON = CLAURA_ROOT / "venv" / "bin" / "python3"
LICHEN_STATE = CLAURA_ROOT / "fungi_rig_state.json"


# ═══════════════════════════════════════════════════════════════════
# Lichen probe (shared across modes)
# ═══════════════════════════════════════════════════════════════════

_PROBE_DEFAULTS: Dict[str, Any] = {
    "recommended_params": {
        "base_policy_epsilon":   0.18,
        "base_policy_ucb_scale": 1.10,
        "epsilon_jitter":        0.12,
        "ucb_octave_jitter":     0.45,
    },
    "jsonl_overlay":          [],
    "character_prompt_context": "",
    "lane_projection":        {"cost_sensitivity": 0.5, "exploration_pressure": 0.5},
}


def _probe_lichen() -> Dict[str, Any]:
    """Call quantum_lichen.derby_probe and return its JSON output."""
    if not _PROBE_PYTHON.exists():
        print(f"  [{LICHEN}] Claura venv not found — using defaults", flush=True)
        return _PROBE_DEFAULTS.copy()
    try:
        proc = subprocess.run(
            [str(_PROBE_PYTHON), "-m", "quantum_lichen.derby_probe",
             "--rig-state", str(LICHEN_STATE)],
            capture_output=True, text=True, timeout=30,
            cwd=str(CLAURA_ROOT),
        )
        if proc.returncode == 0 and proc.stdout.strip():
            data = json.loads(proc.stdout)
            rp = data.get("recommended_params", {})
            print(f"  [{LICHEN}] probe ok — "
                  f"epsilon={rp.get('base_policy_epsilon', '?'):.3f}  "
                  f"ucb={rp.get('base_policy_ucb_scale', '?'):.3f}", flush=True)
            return data
    except Exception as exc:
        print(f"  [{LICHEN}] probe failed ({exc}) — using defaults", flush=True)
    return _PROBE_DEFAULTS.copy()


def _observe_lichen_derby(summary_path: Path) -> None:
    """Post derby results to lichen pheromone system.

    Uses --observe-result for v2 envelopes (arena.py output),
    falls back to --observe-derby for legacy format.
    """
    if not _PROBE_PYTHON.exists():
        return
    try:
        data = json.loads(summary_path.read_text())
        flag = "--observe-result" if data.get("schema") == "v2" else "--observe-derby"
    except Exception:
        flag = "--observe-derby"
    try:
        proc = subprocess.run(
            [str(_PROBE_PYTHON), "-m", "quantum_lichen.derby_probe",
             flag, str(summary_path),
             "--rig-state", str(LICHEN_STATE), "--save"],
            capture_output=True, text=True, timeout=30,
            cwd=str(CLAURA_ROOT),
        )
        if proc.returncode == 0:
            result = json.loads(proc.stdout) if proc.stdout.strip() else {}
            print(f"  [{LICHEN}] derby observed — "
                  f"saved={result.get('saved', False)}", flush=True)
    except Exception as exc:
        print(f"  [{LICHEN}] observe-derby failed: {exc}", flush=True)


def _write_overlay_jsonl(ops: List[Dict[str, Any]], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(json.dumps(op) for op in ops) + "\n")


# ═══════════════════════════════════════════════════════════════════
# Tissue setup (shared across modes)
# ═══════════════════════════════════════════════════════════════════

def _setup_tissue(
    no_lichen: bool = False,
) -> Dict[str, Any]:
    """Probe lichen + load evolved tissue defaults.

    Returns a context dict with everything modes need for scoring + policy.
    """
    ctx: Dict[str, Any] = {}

    # Lichen probe
    if no_lichen:
        ctx["lichen_probe"] = _PROBE_DEFAULTS.copy()
    else:
        print(f"\n[{LICHEN}] Probing quantum organism state...")
        ctx["lichen_probe"] = _probe_lichen()

    # Evolved tissue defaults
    evolved_ranges, ledger = load_evolved_defaults()
    ctx["evolved_ranges"] = evolved_ranges
    ctx["ledger"] = ledger
    ctx["n_ledger"] = len(ledger)

    diffs = format_evolved_diff(evolved_ranges)
    if diffs:
        print(f"\n[{TISSUE}] Evolved defaults ({len(ledger)} entries):")
        for line in diffs[:8]:
            print(f"  {line}")

    # Adaptive scoring weights
    cal_proj = ctx["lichen_probe"].get("cal_projection")
    ctx["scoring_weights"] = lichen_scoring_weights(cal_proj)

    # Policy projection
    ctx["tissue_policy_ops"] = project_to_policy(evolved_ranges)
    ctx["tissue_resources"] = project_to_resources(evolved_ranges)

    # Lichen overlay ops (tissue base + Claura quantum overlay)
    lichen_overlay = ctx["lichen_probe"].get("jsonl_overlay", [])
    ctx["combined_overlay_ops"] = ctx["tissue_policy_ops"] + lichen_overlay

    # Proposed character from Claura (v2+)
    ctx["proposed_character"] = ctx["lichen_probe"].get("proposed_character")

    # Write proposed character to disk so it's available as a character file
    proposed = ctx.get("proposed_character")
    if proposed and isinstance(proposed, dict) and proposed.get("name"):
        char_path = HERE / "config" / "characters" / f"{proposed['name']}.json"
        char_path.parent.mkdir(parents=True, exist_ok=True)
        char_path.write_text(json.dumps(proposed, indent=2, ensure_ascii=False) + "\n")
        ctx["proposed_character_path"] = str(char_path)
        print(f"  [{LICHEN}] Proposed character: {proposed['name']}  "
              f"biomes={len(proposed.get('unlocked_biomes', []))}  "
              f"policy_ops={len(proposed.get('policies', {}).get('quantum_register', {}).get('graph_jsonl', []))}",
              flush=True)

    # Lichen params for subprocess env injection
    rp = ctx["lichen_probe"].get("recommended_params", {})
    ctx["lichen_params"] = {
        "epsilon":          rp.get("base_policy_epsilon",   0.18),
        "ucb_scale":        rp.get("base_policy_ucb_scale", 1.10),
        "gto_epsilon":      rp.get("base_policy_epsilon",   0.18),
        "gto_ucb_scale":    rp.get("base_policy_ucb_scale", 1.10),
        "epsilon_jitter":   rp.get("epsilon_jitter",        0.12),
        "ucb_octave_jitter": rp.get("ucb_octave_jitter",    0.45),
    }

    return ctx


# ═══════════════════════════════════════════════════════════════════
# Extract learnings (shared across modes)
# ═══════════════════════════════════════════════════════════════════

def _extract_learnings(
    runners: List[RunnerResult],
    evolved_ranges: Dict[str, Any],
    scoring_weights: Optional[Dict[str, float]] = None,
) -> Dict[str, Any]:
    """Extract Graph Tissue learnings: which weights + resources correlated with success."""
    # Prefer milk finders as "winners" for tissue signal — milk is the actual goal.
    # Fall back to top composite when nobody found milk (learning from relative performance).
    milk_runners = [r for r in runners if r.found_milk]
    if milk_runners:
        scored = sorted(runners, key=lambda r: r.composite(scoring_weights), reverse=True)
        winners = milk_runners  # all milk finders are winners
        losers = [r for r in scored if not r.found_milk]
    else:
        scored = sorted(runners, key=lambda r: r.composite(scoring_weights), reverse=True)
        winners = scored[:max(1, len(scored) // 2)]  # top half by composite
        losers = scored[len(winners):]

    learnings: Dict[str, Any] = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "trademark": "Graph Tissue™ is a trademark of Luke Spooner",
        "top_runners": [],
        "tissue_signal": {},
        "resource_signal": {},
    }

    for r in winners:
        learnings["top_runners"].append({
            "profile": r.profile, "lane": r.lane,
            "composite": r.composite(scoring_weights),
            "found_milk": r.found_milk,
        })

    # Tissue signal — two sources:
    # 1. Policy weights file (profiles with config/policy_weights/{name}.json)
    # 2. Runtime outcome signal derived from batch_summary stats:
    #    winners vs losers in probe count, vocab breadth, step efficiency
    tissue_deltas: Dict[str, List[float]] = {}

    # Source 1: policy weight files / character JSONL
    for r in winners:
        pw = load_policy_weights(r.profile)
        if not pw and character_exists(r.profile):
            try:
                char = load_character(r.profile)
                from milk_hunt_characters import resolve_character_policy
                policy_cfg = resolve_character_policy(char, POLICY_ENGINE)
                jsonl_lines = policy_cfg.get("graph_jsonl", [])
                if jsonl_lines:
                    pw = reverse_policy_to_weights(jsonl_lines)
            except Exception:
                pass
        for k, v in pw.items():
            if k in evolved_ranges:
                delta = float(v) - float(evolved_ranges[k]["default"])
                tissue_deltas.setdefault(k, []).append(delta)

    # Source 2: runtime outcome signal (works even when policy files are absent)
    # Compare winner vs loser batch_summary stats to infer weight adjustments.
    # Only fires when we have both winners and losers with batch data.
    if losers:
        def _bstat(runner: "RunnerResult", key: str, default: float = 0.0) -> float:
            return float(runner.batch_summary.get(key, default) or default)

        w_probes = [_bstat(r, "avg_probe_events_per_run") for r in winners
                    if r.batch_summary]
        l_probes = [_bstat(r, "avg_probe_events_per_run") for r in losers
                    if r.batch_summary]
        w_vocab  = [_bstat(r, "avg_vocab_milestones_per_run") for r in winners
                    if r.batch_summary]
        l_vocab  = [_bstat(r, "avg_vocab_milestones_per_run") for r in losers
                    if r.batch_summary]

        w_drains = [_bstat(r, "avg_lindblad_drain_actions_per_run") for r in winners
                    if r.batch_summary]
        l_drains = [_bstat(r, "avg_lindblad_drain_actions_per_run") for r in losers
                    if r.batch_summary]
        w_skips  = [_bstat(r, "avg_time_skip_actions_per_run") for r in winners
                    if r.batch_summary]
        l_skips  = [_bstat(r, "avg_time_skip_actions_per_run") for r in losers
                    if r.batch_summary]

        # Scale factor: keep nudges small (±20% of default per signal)
        _NUDGE = 0.20

        if w_probes and l_probes:
            w_avg_probes = sum(w_probes) / len(w_probes)
            l_avg_probes = sum(l_probes) / len(l_probes)
            probe_default = float(evolved_ranges.get("probe_frontier", {}).get("default", 1.0))
            # Normalize: diff / (w+l average) clamped to [-1, 1], scaled by nudge
            norm = max(w_avg_probes + l_avg_probes, 0.1) / 2.0
            probe_delta = ((w_avg_probes - l_avg_probes) / norm) * _NUDGE * probe_default
            probe_delta = max(-probe_default * _NUDGE, min(probe_default * _NUDGE, probe_delta))
            if abs(probe_delta) > 0.02:
                tissue_deltas.setdefault("probe_frontier", []).append(probe_delta)
                tissue_deltas.setdefault("probe_hits", []).append(probe_delta * 0.8)

        if w_vocab and l_vocab:
            w_avg_vocab = sum(w_vocab) / len(w_vocab)
            l_avg_vocab = sum(l_vocab) / len(l_vocab)
            vocab_default = float(evolved_ranges.get("vocab_probe_base", {}).get("default", 0.4))
            norm = max(w_avg_vocab + l_avg_vocab, 0.1) / 2.0
            vocab_delta = ((w_avg_vocab - l_avg_vocab) / norm) * _NUDGE * vocab_default
            vocab_delta = max(-vocab_default * _NUDGE, min(vocab_default * _NUDGE, vocab_delta))
            if abs(vocab_delta) > 0.005:
                tissue_deltas.setdefault("vocab_probe_base", []).append(vocab_delta)

        # Lindblad drain: winners with fewer drains → reduce lindblad_hits
        if w_drains and l_drains:
            w_avg = sum(w_drains) / len(w_drains)
            l_avg = sum(l_drains) / len(l_drains)
            drain_default = float(evolved_ranges.get("lindblad_hits", {}).get("default", 1.1))
            norm = max(w_avg + l_avg, 0.1) / 2.0
            drain_delta = ((w_avg - l_avg) / norm) * _NUDGE * drain_default
            drain_delta = max(-drain_default * _NUDGE, min(drain_default * _NUDGE, drain_delta))
            if abs(drain_delta) > 0.02:
                tissue_deltas.setdefault("lindblad_hits", []).append(drain_delta)
                tissue_deltas.setdefault("lindblad_frontier", []).append(drain_delta * 0.5)

        # Time skip: winners with fewer skips → increase loop_probe_floor_pressure
        # (inverse mode: higher floor_pressure → lower time_skip.base)
        if w_skips and l_skips:
            w_avg = sum(w_skips) / len(w_skips)
            l_avg = sum(l_skips) / len(l_skips)
            skip_default = float(evolved_ranges.get("loop_probe_floor_pressure", {}).get("default", 1.0))
            norm = max(w_avg + l_avg, 0.1) / 2.0
            # Winners skip less → push floor_pressure UP (inverse mode reduces time_skip)
            skip_delta = ((l_avg - w_avg) / norm) * _NUDGE * skip_default
            skip_delta = max(-skip_default * _NUDGE, min(skip_default * _NUDGE, skip_delta))
            if abs(skip_delta) > 0.02:
                tissue_deltas.setdefault("loop_probe_floor_pressure", []).append(skip_delta)

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
        if profile_exists(r.profile):
            res = load_profile(r.profile).get("resources", {})
            for emoji, val in res.items():
                winner_res.setdefault(emoji, []).append(float(val))
    for r in losers:
        if profile_exists(r.profile):
            res = load_profile(r.profile).get("resources", {})
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


def _finish_tissue(
    runners: List[RunnerResult],
    ctx: Dict[str, Any],
    summary_path: Path,
    no_lichen: bool = False,
) -> Dict[str, Any]:
    """Extract learnings, append to ledger, observe lichen.  Returns learnings dict."""
    learnings = _extract_learnings(
        runners, ctx["evolved_ranges"], ctx["scoring_weights"])

    # Print learnings
    if learnings["tissue_signal"]:
        print(f"\n  [{TISSUE}] LEARNINGS:")
        for k, sig in learnings["tissue_signal"].items():
            print(f"    {sig['direction']} {k}: {sig['mean_delta']:+.4f}  (n={sig['n_winners']})")
    if learnings["resource_signal"]:
        print(f"\n  [{TISSUE}] RESOURCE SIGNAL:")
        for emoji, sig in learnings["resource_signal"].items():
            print(f"    {emoji}: winners={sig['winner_avg']:.0f} "
                  f"losers={sig['loser_avg']:.0f} "
                  f"(delta={sig['delta']:+.0f})")

    # Append to ledger
    n_winners = sum(1 for r in runners if r.found_milk)
    append_ledger_entry(
        tissue_signal=learnings.get("tissue_signal", {}),
        resource_signal=learnings.get("resource_signal", {}),
        scoring_weights=ctx["scoring_weights"],
        n_hunters=len(runners),
        n_winners=n_winners,
    )
    print(f"\n  [{TISSUE}] Ledger entry #{ctx['n_ledger'] + 1} appended")

    # Lichen observe
    if not no_lichen:
        print(f"\n[{LICHEN}] Observing derby result...")
        _observe_lichen_derby(summary_path)

    return learnings


# ═══════════════════════════════════════════════════════════════════
# MODE: race  (was derby_round_robin.py)
# ═══════════════════════════════════════════════════════════════════

def _fib_steps(max_cycles: int) -> List[int]:
    """Fibonacci delta step sizes: 13, 8, 13, 21, 34, 55, 89, ..."""
    fibs = [13, 21]
    while fibs[-1] < max_cycles:
        fibs.append(fibs[-1] + fibs[-2])
    steps = [fibs[0]]
    for i in range(1, len(fibs)):
        steps.append(fibs[i] - fibs[i - 1])
    return steps


def _slot_for(profile: str, runner_index: int) -> int:
    """Deterministic collision-free slot from profile+index."""
    key = f"derby:{profile}:runner:{runner_index}"
    h = int(hashlib.sha256(key.encode()).hexdigest()[:8], 16)
    return 1000 + (h % 9000)


def _seed_runner(
    profile: str,
    slot: int,
    overlay_lines: Optional[List[str]] = None,
    resource_overrides: Optional[Dict[str, int]] = None,
) -> bool:
    """Seed a save slot from a profile, optionally with tissue overlay ops and resource tuning."""
    cmd = [
        sys.executable, str(SEED_SCRIPT),
        "--profile", profile,
        "--slot", str(slot),
    ]
    for line in (overlay_lines or []):
        line = line.strip()
        if line:
            cmd.extend(["--policy-graph-line", line])
    if resource_overrides:
        cmd.extend(["--resource-mode", "set"])
        for emoji, amount in resource_overrides.items():
            cmd.extend(["--resource", f"{emoji}:{amount}"])
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=SEED_TIMEOUT_S)
    return proc.returncode in (0, 3)


def _seed_character(
    character_name: str,
    slot: int,
    policy_mode: str = POLICY_ENGINE,
    overlay_lines: Optional[List[str]] = None,
    resource_overrides: Optional[Dict[str, int]] = None,
) -> bool:
    """Seed a save slot from a character spec, optionally with tissue overlay ops and resource tuning."""
    cmd = [
        sys.executable, str(SEED_SCRIPT),
        "--character", character_name,
        "--slot", str(slot),
        "--policy-mode", policy_mode,
    ]
    for line in (overlay_lines or []):
        line = line.strip()
        if line:
            cmd.extend(["--policy-graph-line", line])
    if resource_overrides:
        cmd.extend(["--resource-mode", "set"])
        for emoji, amount in resource_overrides.items():
            cmd.extend(["--resource", f"{emoji}:{amount}"])
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=SEED_TIMEOUT_S)
    return proc.returncode in (0, 3)


def _run_chunk(
    runner: RunnerResult,
    max_cycles: int,
    console_profile: str,
    strict: Optional[bool] = None,
    hunter_policy: str = POLICY_ENGINE,
) -> Dict[str, Any]:
    """Run a chunk of cycles for one runner."""
    cmd = [
        sys.executable, str(RUNNER_SCRIPT),
        "--load-slot", str(runner.slot),
        "--save-slot-at-end", str(runner.slot),
        "--max-loops", str(max_cycles),
        "--turn-start", str(runner.steps),
        "--hunter-profile", runner.profile,
        "--hunter-policy", hunter_policy,
        "--json-only",
        "--reuse-listener",
        "--console-profile", console_profile,
    ]
    if strict is not None:
        cmd.append("--strict-biome-economy" if strict else "--no-strict-biome-economy")

    t0 = time.time()
    proc = subprocess.run(
        cmd, capture_output=True, text=True,
        timeout=run_timeout(max_cycles, floor=TIMEOUT_FLOOR["race"]),
    )
    elapsed = time.time() - t0

    summary = {}
    stdout = (proc.stdout or "").strip()
    if stdout:
        for line in reversed(stdout.split("\n")):
            line = line.strip()
            if line.startswith("{"):
                try:
                    summary = json.loads(line)
                    break
                except json.JSONDecodeError:
                    pass

    summary["_chunk_elapsed_s"] = round(elapsed, 2)
    summary["_chunk_max_loops"] = max_cycles
    summary["_exit_code"] = proc.returncode
    return summary


def cmd_race(args: argparse.Namespace) -> None:
    """🏁 Race mode: N runners, 1 profile/character, fibonacci interleaved rounds."""
    n_runners = max(2, min(5, args.runners))
    max_cycles = args.max_cycles
    win_threshold = min(args.win_threshold, n_runners)

    # Resolve profile or character
    use_character = bool(getattr(args, "character", None))
    profile_name = args.character if use_character else args.profile
    if not profile_name:
        print("Must specify --profile or --character")
        sys.exit(1)
    policy_mode = getattr(args, "hunter_policy", POLICY_ENGINE) or POLICY_ENGINE

    slots = [_slot_for(profile_name, i) for i in range(n_runners)]
    step_sizes = _fib_steps(max_cycles)

    cumulatives = []
    c = 0
    for s in step_sizes:
        c += s
        cumulatives.append(c)

    mode_tag = f"{CHARACTER} {profile_name}" if use_character else profile_name
    print(header(RACE, f"RACE: {mode_tag}"))
    print(f"  {n_runners} runners x {max_cycles} max cycles")
    if use_character:
        print(f"  Character mode, policy={policy_mode}")
    print(f"  Stop after {win_threshold} complete")
    print(f"  Fibonacci milestones: {cumulatives}")
    print(f"  Slots: {slots}")

    # Seed all runners
    print(f"\n  [{RUNNER}] Seeding {n_runners} save slots...")
    runners: List[RunnerResult] = []
    for i, slot in enumerate(slots):
        if use_character:
            ok = _seed_character(profile_name, slot, policy_mode)
        else:
            ok = _seed_runner(profile_name, slot)
        if not ok:
            print(f"  FAILED to seed slot {slot}!")
            sys.exit(1)
        r = RunnerResult(profile=profile_name, slot=slot, active=True)
        runners.append(r)
        print(f"  Runner {i+1} -> slot {slot}")

    # Round-robin
    t_start = time.time()

    for round_idx, step_size in enumerate(step_sizes):
        completed = sum(1 for r in runners if not r.active)
        if completed >= win_threshold:
            print(f"\n  {completed}/{n_runners} done — threshold met. Stopping.")
            break

        active = [r for r in runners if r.active]
        if not active:
            break

        for r in active:
            remaining = max_cycles - r.cycles
            if remaining <= 0:
                r.active = False
                r.exit_code = 1
                continue

            chunk_cycles = min(step_size, remaining)
            summary = _run_chunk(r, chunk_cycles, args.console_profile, args.strict,
                                 hunter_policy=policy_mode)

            loops_done = summary.get("loops_completed", 0)
            steps = summary.get("steps", 0)
            r.cycles += loops_done
            r.steps += steps
            r.elapsed_s += summary.get("_chunk_elapsed_s", 0)
            r.rounds += 1

            if summary.get("found_milk_pair", False):
                r.found_milk = True
                r.active = False
                print(f"  {RUNNER} Runner {runners.index(r)+1} found MILK "
                      f"at cycle {r.cycles}, step {r.steps}!")
            elif r.cycles >= max_cycles:
                r.active = False
                r.exit_code = 1
            elif summary.get("_exit_code", 0) != 0 and loops_done == 0:
                r.active = False
                r.exit_code = summary.get("_exit_code", 1)
                print(f"  {RUNNER} Runner {runners.index(r)+1} crashed "
                      f"(exit={r.exit_code})")

        print(format_scoreboard(runners, round_idx=round_idx, step_size=step_size))

    # Mark remaining active as failed
    for r in runners:
        if r.active:
            r.active = False
            r.exit_code = 1

    total_elapsed = time.time() - t_start

    # Results
    print(header(RACE, f"RESULTS: {profile_name}"))
    print(f"  Total time: {total_elapsed:.1f}s")

    milk_count = sum(1 for r in runners if r.found_milk)
    success_rate = milk_count / n_runners
    print(f"\n  Success: {milk_count}/{n_runners} ({success_rate:.0%})")

    milk_steps = [r.steps for r in runners if r.found_milk]
    if milk_steps:
        print(f"  Steps (winners): min={min(milk_steps)} "
              f"avg={sum(milk_steps)/len(milk_steps):.0f} max={max(milk_steps)}")

    print(format_scoreboard(runners, title="FINAL STANDINGS"))

    # Save report
    out_dir = BATCH_LOG_DIR
    out_dir.mkdir(parents=True, exist_ok=True)
    ts = time.strftime("%Y%m%d_%H%M%S")
    out_path = out_dir / f"race_{profile_name}_{ts}.json"
    report = make_envelope(
        LAYER_RACE,
        profile=profile_name,
        runners=[r.to_dict() for r in runners],
        scores={"success_rate": success_rate, "milk_count": milk_count},
        extra={
            "n_runners": n_runners,
            "max_cycles": max_cycles,
            "win_threshold": win_threshold,
            "total_elapsed_s": round(total_elapsed, 2),
        },
    )
    write_json(out_path, report)
    print(f"\n  Report: {out_path}")

    # Record to persistent leaderboard
    _record_leaderboard(runners, layer=LAYER_RACE,
                        default_lane=profile_name)
    print(f"  {SCORE} Leaderboard updated (+{len(runners)} entries)")


# ═══════════════════════════════════════════════════════════════════
# MODE: duel  (was derby.py)
# ═══════════════════════════════════════════════════════════════════

def _run_lane(
    lane: str,
    lane_profiles: List[str],
    max_cycles: int,
    console_profile: str,
    hunter_policy: str,
    derby_dir: Path,
    lichen_params: Optional[Dict[str, Any]] = None,
    use_topology_gto: bool = False,
) -> List[RunnerResult]:
    """Run all runners for one lane sequentially on one isolated rig."""
    env = os.environ.copy()
    env["XDG_ROOT"] = f"/tmp/sw_derby_{lane}"

    overlay_path = ""
    if lichen_params:
        env["MILK_HUNT_POLICY_EPSILON"] = str(lichen_params.get("epsilon", 0.18))
        env["MILK_HUNT_POLICY_UCB_SCALE"] = str(lichen_params.get("ucb_scale", 1.10))
        overlay_path = lichen_params.get("overlay_path", "")
        if overlay_path and Path(overlay_path).exists():
            env["MILK_HUNT_POLICY_EXTRA_JSONL"] = overlay_path

    results: List[RunnerResult] = []

    for profile in lane_profiles:
        batch_output = derby_dir / lane / profile
        batch_output.mkdir(parents=True, exist_ok=True)

        cmd = [
            sys.executable, str(BATCH_SCRIPT),
            "--profile", profile,
            "--runs", "1",
            "--max-loops", str(max_cycles),
            "--hunter-policy", hunter_policy,
            "--console-profile", console_profile,
            "--output-dir", str(batch_output),
        ]

        # Pass tissue overlay to batch for policy graph injection during seeding
        if overlay_path and Path(overlay_path).exists():
            cmd.extend(["--policy-overlay-path", overlay_path])

        if use_topology_gto and lichen_params:
            cmd.extend([
                "--topology-gto",
                "--base-policy-epsilon",   str(lichen_params.get("gto_epsilon", 0.18)),
                "--base-policy-ucb-scale", str(lichen_params.get("gto_ucb_scale", 1.10)),
                "--epsilon-jitter",        str(lichen_params.get("epsilon_jitter", 0.12)),
                "--ucb-octave-jitter",     str(lichen_params.get("ucb_octave_jitter", 0.45)),
            ])

        t0 = time.time()
        try:
            proc = subprocess.run(
                cmd, capture_output=True, text=True,
                timeout=run_timeout(max_cycles, floor=TIMEOUT_FLOOR["duel"]), env=env,
            )
        except subprocess.TimeoutExpired:
            elapsed = time.time() - t0
            results.append(RunnerResult(
                profile=profile, lane=lane, elapsed_s=elapsed, exit_code=-1))
            print(f"  [{LANE} {lane}] {profile}: TIMEOUT ({elapsed:.0f}s)", flush=True)
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

        result = RunnerResult.from_batch_summary(
            profile=profile,
            batch_summary=batch_summary,
            lane=lane,
            elapsed_s=round(elapsed, 2),
            exit_code=proc.returncode,
        )
        results.append(result)

        milk_tag = "MILK!" if result.found_milk else f"exit={result.exit_code}"
        print(f"  [{LANE} {lane}] {profile}: {milk_tag}  "
              f"cycles={result.cycles}  steps={result.steps}  "
              f"{result.elapsed_s:.0f}s", flush=True)

    return results


def _run_character_lane(
    lane: str,
    character_names: List[str],
    policy_mode: str,
    max_cycles: int,
    console_profile: str,
    derby_dir: Path,
    lichen_params: Optional[Dict[str, Any]] = None,
    use_topology_gto: bool = False,
    tissue_resources: Optional[Dict[str, int]] = None,
    per_runner_jitter_ops: Optional[Dict[str, List[str]]] = None,
) -> List[RunnerResult]:
    """Run all characters for one policy-lane using character seeding."""
    env = os.environ.copy()
    env["XDG_ROOT"] = f"/tmp/sw_derby_{lane}"

    overlay_path = ""
    overlay_lines: List[str] = []
    if lichen_params:
        env["MILK_HUNT_POLICY_EPSILON"] = str(lichen_params.get("epsilon", 0.18))
        env["MILK_HUNT_POLICY_UCB_SCALE"] = str(lichen_params.get("ucb_scale", 1.10))
        overlay_path = lichen_params.get("overlay_path", "")
        if overlay_path and Path(overlay_path).exists():
            env["MILK_HUNT_POLICY_EXTRA_JSONL"] = overlay_path
            overlay_lines = [
                l.strip() for l in Path(overlay_path).read_text().splitlines()
                if l.strip()
            ]

    results: List[RunnerResult] = []

    for char_name in character_names:
        batch_output = derby_dir / lane / char_name
        batch_output.mkdir(parents=True, exist_ok=True)

        cmd = [
            sys.executable, str(BATCH_SCRIPT),
            "--runs", "1",
            "--max-loops", str(max_cycles),
            "--hunter-profile", char_name,
            "--hunter-policy", policy_mode,
            "--console-profile", console_profile,
            "--output-dir", str(batch_output),
        ]

        if use_topology_gto and lichen_params:
            cmd.extend([
                "--topology-gto",
                "--base-policy-epsilon",   str(lichen_params.get("gto_epsilon", 0.18)),
                "--base-policy-ucb-scale", str(lichen_params.get("gto_ucb_scale", 1.10)),
                "--epsilon-jitter",        str(lichen_params.get("epsilon_jitter", 0.12)),
                "--ucb-octave-jitter",     str(lichen_params.get("ucb_octave_jitter", 0.45)),
            ])

        # Seed using character spec + tissue overlay ops + per-runner jitter.
        # Do NOT pass tissue_resources to character seeds — characters have their
        # own carefully-tuned starting resources; overriding them breaks gameplay.
        slot = _slot_for(f"{char_name}_{lane}", 0)
        seed_overlay = list(overlay_lines)
        if per_runner_jitter_ops and char_name in per_runner_jitter_ops:
            seed_overlay.extend(per_runner_jitter_ops[char_name])
        if not _seed_character(char_name, slot, policy_mode,
                               overlay_lines=seed_overlay,
                               resource_overrides=None):
            results.append(RunnerResult(
                profile=char_name, lane=lane, exit_code=-2))
            print(f"  [{CHARACTER} {lane}] {char_name}: SEED FAILED", flush=True)
            continue

        # Load from pre-seeded slot (skip batch re-seeding since no --profile given)
        cmd.extend(["--load-slot", str(slot)])

        t0 = time.time()
        try:
            proc = subprocess.run(
                cmd, capture_output=True, text=True,
                timeout=run_timeout(max_cycles, floor=TIMEOUT_FLOOR["duel"]), env=env,
            )
        except subprocess.TimeoutExpired:
            elapsed = time.time() - t0
            results.append(RunnerResult(
                profile=char_name, lane=lane, elapsed_s=elapsed, exit_code=-1))
            print(f"  [{CHARACTER} {lane}] {char_name}: TIMEOUT ({elapsed:.0f}s)", flush=True)
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

        result = RunnerResult.from_batch_summary(
            profile=char_name,
            batch_summary=batch_summary,
            lane=lane,
            elapsed_s=round(elapsed, 2),
            exit_code=proc.returncode,
        )
        results.append(result)

        milk_tag = "MILK!" if result.found_milk else f"exit={result.exit_code}"
        print(f"  [{CHARACTER} {lane}] {char_name}: {milk_tag}  "
              f"cycles={result.cycles}  steps={result.steps}  "
              f"{result.elapsed_s:.0f}s", flush=True)

    return results


def cmd_duel(args: argparse.Namespace) -> None:
    """🏆 Duel mode: 2+ lanes compete in parallel, each with N runners.

    Two modes:
      --lanes (default): lanes are LLM identities, runners are derby profiles
      --characters:      lanes are policy modes, runners are character specs
    """
    ctx = _setup_tissue(no_lichen=args.no_lichen)
    use_characters = bool(getattr(args, "characters", None))

    if use_characters:
        # Character mode: lanes = policy modes, runners = characters
        char_names = args.characters
        policies = args.policies or POLICY_MODES

        # Validate characters exist
        for name in char_names:
            if not character_exists(name):
                print(f"Unknown character: {name}")
                print(f"  Available: {', '.join(list_character_names())}")
                sys.exit(1)

        lane_profiles: Dict[str, List[str]] = {}
        for policy in policies:
            lane_profiles[policy] = list(char_names)

        n_runners = sum(len(p) for p in lane_profiles.values())

        print(header(DERBY, "DUEL: " + " vs ".join(
            f"{p.upper()} ({len(char_names)})" for p in policies)))
        print(f"  {CHARACTER} Character mode: {len(char_names)} characters x {len(policies)} policies")
        print(f"  {n_runners} runners total, {args.max_cycles} max cycles")
    else:
        # Profile mode: lanes = LLM identities, runners = derby profiles
        lane_profiles = {}
        for lane in args.lanes:
            profiles = list_derby_names(lane, args.runners_per_lane)
            if profiles:
                lane_profiles[lane] = profiles

        if not lane_profiles:
            print("No derby profiles found! Create config/world_state/derby_{lane}_{N}.json first.")
            sys.exit(1)

        n_runners = sum(len(p) for p in lane_profiles.values())

        print(header(DERBY, "DUEL: " + " vs ".join(
            f"{lane.upper()} ({len(ps)})" for lane, ps in lane_profiles.items())))
        print(f"  {len(lane_profiles)} lanes in parallel (1 rig each)")
        print(f"  {n_runners} runners total, {args.max_cycles} max cycles")
        print(f"  policy={args.hunter_policy}")

    ts = time.strftime("%Y%m%d_%H%M%S")
    derby_dir = LOG_DIR / f"derby_{ts}"
    derby_dir.mkdir(parents=True, exist_ok=True)

    # Write overlay files
    if ctx["combined_overlay_ops"]:
        for lane in lane_profiles:
            overlay_path = derby_dir / f"tissue_overlay_{lane}.jsonl"
            _write_overlay_jsonl(ctx["combined_overlay_ops"], overlay_path)
            ctx["lichen_params"]["overlay_path"] = str(overlay_path)

    t_total = time.time()

    # Launch lanes in parallel
    all_runners: List[RunnerResult] = []
    lane_results: Dict[str, List[RunnerResult]] = {}

    with ProcessPoolExecutor(max_workers=len(lane_profiles)) as pool:
        futures = {}
        for lane, runners_list in lane_profiles.items():
            lp = dict(ctx["lichen_params"])
            overlay_path = derby_dir / f"tissue_overlay_{lane}.jsonl"
            if overlay_path.exists():
                lp["overlay_path"] = str(overlay_path)

            if use_characters:
                # Character mode: use character seeding, lane = policy mode
                fut = pool.submit(
                    _run_character_lane,
                    lane=lane, character_names=runners_list,
                    policy_mode=lane,  # lane IS the policy mode
                    max_cycles=args.max_cycles,
                    console_profile=args.console_profile,
                    derby_dir=derby_dir,
                    lichen_params=lp,
                    use_topology_gto=args.use_topology_gto,
                    tissue_resources=ctx.get("tissue_resources"),
                )
            else:
                # Profile mode: standard lane execution
                fut = pool.submit(
                    _run_lane,
                    lane=lane, lane_profiles=runners_list,
                    max_cycles=args.max_cycles,
                    console_profile=args.console_profile,
                    hunter_policy=args.hunter_policy,
                    derby_dir=derby_dir,
                    lichen_params=lp,
                    use_topology_gto=args.use_topology_gto,
                )
            futures[fut] = lane

        for fut in as_completed(futures):
            lane = futures[fut]
            try:
                results = fut.result()
            except Exception as exc:
                results = []
                print(f"  [{LANE} {lane}] FAILED: {exc}", flush=True)
            lane_results[lane] = results
            all_runners.extend(results)
            milk = sum(1 for r in results if r.found_milk)
            print(f"\n  [{LANE} {lane}] DONE: {milk}/{len(results)} found milk",
                  flush=True)

    total_elapsed = time.time() - t_total

    # Score lanes
    scoring_weights = ctx["scoring_weights"]
    ls: Dict[str, Dict[str, Any]] = {}
    for lane, results in lane_results.items():
        ls[lane] = score_lane(results, scoring_weights)

    # Determine winner
    winner = None
    if len(ls) == 2:
        lanes = sorted(ls.keys())
        a, b = lanes
        sa, sb = ls[a]["composite"], ls[b]["composite"]
        if sa > sb:
            winner = a.upper()
        elif sb > sa:
            winner = b.upper()
        else:
            winner = "TIE"

    # Print results
    all_runners.sort(key=lambda r: (not r.found_milk, r.steps))
    print(header(DERBY, f"RESULTS ({total_elapsed:.0f}s)"))
    print(format_scoreboard(all_runners, title="ALL RUNNERS", show_scores=True,
                            weights=scoring_weights))
    print(format_lane_scores(ls, winner))

    # Tissue learning
    learnings = _finish_tissue(all_runners, ctx, derby_dir / "derby_summary.json",
                               no_lichen=args.no_lichen)

    # Save summary
    summary = make_envelope(
        LAYER_DUEL,
        runners=[r.to_dict() for r in all_runners],
        lane_scores=ls,
        winner=winner,
        learnings=learnings,
        extra={
            "total_elapsed_s": round(total_elapsed, 1),
            "max_cycles": args.max_cycles,
            "hunter_policy": args.hunter_policy,
            "tissue_ledger_size": ctx["n_ledger"] + 1,
        },
    )
    summary_path = derby_dir / "derby_summary.json"
    write_json(summary_path, summary)
    print(f"\n  Report: {summary_path}")

    # Record to persistent leaderboard
    _record_leaderboard(all_runners, layer=LAYER_DUEL,
                        weights=scoring_weights)
    print(f"  {SCORE} Leaderboard updated (+{len(all_runners)} entries)")
    print("=" * 64)


# ═══════════════════════════════════════════════════════════════════
# MODE: matrix  (was milk_hunt_matrix.py + derby_rr_matrix.py)
# ═══════════════════════════════════════════════════════════════════

def cmd_matrix(args: argparse.Namespace) -> None:
    """📊 Matrix mode: batch comparison across multiple profiles."""
    # Resolve profile list
    if args.profiles.strip() == "derby_*":
        profile_names = []
        for lane in list_derby_lanes():
            profile_names.extend(list_derby_names(lane))
    elif "*" in args.profiles:
        import fnmatch
        pattern = args.profiles.strip()
        profile_names = [n for n in list_names() if fnmatch.fnmatch(n, pattern)]
    else:
        profile_names = [p.strip() for p in args.profiles.split(",") if p.strip()]

    if not profile_names:
        print("No profiles matched!")
        sys.exit(1)

    print(header(BATCH, f"MATRIX: {len(profile_names)} profiles x {args.runs} runs"))
    for name in profile_names:
        print(f"  {RUNNER} {name}")

    ts = time.strftime("%Y%m%d_%H%M%S")
    matrix_dir = BATCH_LOG_DIR / f"matrix_{ts}"
    matrix_dir.mkdir(parents=True, exist_ok=True)

    t_total = time.time()
    results: List[Dict[str, Any]] = []
    all_runners: List[RunnerResult] = []

    for profile in profile_names:
        batch_output = matrix_dir / profile
        batch_output.mkdir(parents=True, exist_ok=True)

        cmd = [
            sys.executable, str(BATCH_SCRIPT),
            "--profile", profile,
            "--runs", str(args.runs),
            "--max-loops", str(args.max_cycles),
            "--console-profile", args.console_profile,
            "--output-dir", str(batch_output),
        ]

        print(f"\n  [{BATCH}] Running {profile} ({args.runs} runs)...")
        t0 = time.time()
        proc = subprocess.run(cmd, capture_output=True, text=True,
                              timeout=run_timeout(args.max_cycles, floor=TIMEOUT_FLOOR["matrix"], runs=args.runs))
        elapsed = time.time() - t0

        # Find batch summary
        batch_summary: Dict[str, Any] = {}
        for sf in sorted(batch_output.rglob("batch_summary.json")):
            try:
                batch_summary = json.loads(sf.read_text())
                break
            except (json.JSONDecodeError, OSError):
                pass

        runner = RunnerResult.from_batch_summary(
            profile=profile,
            batch_summary=batch_summary,
            elapsed_s=round(elapsed, 2),
            exit_code=proc.returncode,
        )
        all_runners.append(runner)
        scores = runner.scores_dict()
        results.append({
            "profile": profile,
            "elapsed_s": round(elapsed, 2),
            "scores": scores,
        })
        print(f"  [{BATCH}] {profile}: SR={scores['success_rate']:.0%}  "
              f"composite={scores['composite']:.4f}  ({elapsed:.0f}s)")

    total_elapsed = time.time() - t_total

    # Leaderboard
    results.sort(key=lambda r: r["scores"]["composite"], reverse=True)
    print(header(BATCH, f"LEADERBOARD ({total_elapsed:.0f}s)"))
    print(f"  {'#':<3} {'Profile':<28} {'SR':>5} {'Speed':>6} {'Biome':>6} "
          f"{'Vocab':>6} {'Score':>7}")
    print("  " + "-" * 62)
    for i, r in enumerate(results):
        s = r["scores"]
        print(f"  {i+1:<3} {r['profile']:<28} {s['success_rate']:.0%} "
              f"{s['speed_score']:>6.2f} {s['biome_score']:>6.2f} "
              f"{s['vocab_score']:>6.2f} {s['composite']:>7.4f}")

    # Save summary
    summary = make_envelope(
        LAYER_MATRIX,
        extra={
            "total_elapsed_s": round(total_elapsed, 1),
            "n_profiles": len(profile_names),
            "runs_per_profile": args.runs,
            "max_cycles": args.max_cycles,
            "results": results,
        },
    )
    summary_path = matrix_dir / "matrix_summary.json"
    write_json(summary_path, summary)
    print(f"\n  Report: {summary_path}")

    # Record to persistent leaderboard
    _record_leaderboard(all_runners, layer=LAYER_MATRIX)
    print(f"  {SCORE} Leaderboard updated (+{len(all_runners)} entries)")
    print("=" * 64)


# ═══════════════════════════════════════════════════════════════════
# MODE: train  (continuous learning loop)
# ═══════════════════════════════════════════════════════════════════

LAYER_TRAIN = "train"


def _run_duel_epoch(
    characters: List[str],
    policies: List[str],
    max_cycles: int,
    console_profile: str,
    use_topology_gto: bool,
    no_lichen: bool,
    epoch_dir: Path,
    epoch_idx: int = 0,
) -> tuple:
    """Run one duel epoch. Returns (all_runners, lane_results, ctx)."""
    ctx = _setup_tissue(no_lichen=no_lichen)

    lane_profiles: Dict[str, List[str]] = {}
    for policy in policies:
        lane_profiles[policy] = list(characters)

    # Write overlay files
    if ctx["combined_overlay_ops"]:
        for lane in lane_profiles:
            overlay_path = epoch_dir / f"tissue_overlay_{lane}.jsonl"
            _write_overlay_jsonl(ctx["combined_overlay_ops"], overlay_path)
            ctx["lichen_params"]["overlay_path"] = str(overlay_path)

    # Generate per-runner tissue weight jitter (when GTO enabled)
    per_runner_jitter: Optional[Dict[str, List[str]]] = None
    if use_topology_gto:
        per_runner_jitter = {}
        for i, char_name in enumerate(characters):
            jitter_seed = epoch_idx * 1000 + i * 37 + hash(char_name) % 997
            jittered = jitter_weights(
                ctx["evolved_ranges"],
                n_jitters=min(5, len(WEIGHT_RANGES)),
                jitter_fraction=0.15,
                seed=jitter_seed,
            )
            if jittered:
                jitter_ops = project_jittered_to_policy(jittered, ctx["evolved_ranges"])
                per_runner_jitter[char_name] = [
                    json.dumps(op, ensure_ascii=False) for op in jitter_ops
                ]
        if per_runner_jitter:
            n_jittered = sum(1 for v in per_runner_jitter.values() if v)
            print(f"  [{TISSUE}] GTO: {n_jittered} runners with tissue jitter "
                  f"(5 weights x ±15%)", flush=True)

    all_runners: List[RunnerResult] = []
    lane_results: Dict[str, List[RunnerResult]] = {}

    with ProcessPoolExecutor(max_workers=len(lane_profiles)) as pool:
        futures = {}
        for lane, runners_list in lane_profiles.items():
            lp = dict(ctx["lichen_params"])
            overlay_path = epoch_dir / f"tissue_overlay_{lane}.jsonl"
            if overlay_path.exists():
                lp["overlay_path"] = str(overlay_path)

            fut = pool.submit(
                _run_character_lane,
                lane=lane, character_names=runners_list,
                policy_mode=lane,
                max_cycles=max_cycles,
                console_profile=console_profile,
                derby_dir=epoch_dir,
                lichen_params=lp,
                use_topology_gto=use_topology_gto,
                tissue_resources=ctx.get("tissue_resources"),
                per_runner_jitter_ops=per_runner_jitter,
            )
            futures[fut] = lane

        for fut in as_completed(futures):
            lane = futures[fut]
            try:
                results = fut.result()
            except Exception as exc:
                results = []
                print(f"  [{LANE} {lane}] FAILED: {exc}", flush=True)
            lane_results[lane] = results
            all_runners.extend(results)

    return all_runners, lane_results, ctx


def cmd_train(args: argparse.Namespace) -> None:
    """Continuous adversarial training loop with tissue evolution between epochs."""
    characters = args.characters or list_character_names()
    policies = args.policies or POLICY_MODES
    epochs = args.epochs
    max_cycles = args.max_cycles
    target_win_rate = getattr(args, "target_win_rate", TRAIN_TARGET_WIN_RATE)
    cycles_step = getattr(args, "cycles_step", TRAIN_CYCLES_STEP)
    _MAX_CYCLES_CAP = MAX_LOOPS

    if not characters:
        print("No characters found!")
        sys.exit(1)

    print(header(DERBY, "TRAIN: Adversarial Learning Loop"))
    print(f"  {CHARACTER} Characters: {', '.join(characters)}")
    print(f"  Policies: {', '.join(policies)}")
    print(f"  Epochs: {epochs}  |  Max cycles: {max_cycles}  |  Target win rate: {target_win_rate:.0%}")
    print(f"  Tissue evolution: alpha={_EMA_ALPHA}, {len(WEIGHT_RANGES)} weights")

    ts = time.strftime("%Y%m%d_%H%M%S")
    train_dir = LOG_DIR / f"train_{ts}"
    train_dir.mkdir(parents=True, exist_ok=True)

    t_total = time.time()
    epoch_summaries: List[Dict[str, Any]] = []

    for epoch in range(epochs):
        t_epoch = time.time()
        epoch_dir = train_dir / f"epoch_{epoch:03d}"
        epoch_dir.mkdir(parents=True, exist_ok=True)

        print(f"\n{'=' * 64}")
        print(f"  EPOCH {epoch + 1}/{epochs}")
        print(f"{'=' * 64}")

        all_runners, lane_results, ctx = _run_duel_epoch(
            characters=characters,
            policies=policies,
            max_cycles=max_cycles,
            console_profile=args.console_profile,
            use_topology_gto=args.use_topology_gto,
            no_lichen=args.no_lichen,
            epoch_dir=epoch_dir,
            epoch_idx=epoch,
        )

        if not all_runners:
            print(f"  No results for epoch {epoch + 1} — skipping learning")
            continue

        # Score lanes
        scoring_weights = ctx["scoring_weights"]
        ls: Dict[str, Dict[str, Any]] = {}
        for lane, results in lane_results.items():
            ls[lane] = score_lane(results, scoring_weights)

        # Determine winner
        winner = None
        if len(ls) >= 2:
            ranked = sorted(ls.items(), key=lambda kv: kv[1].get("composite", 0), reverse=True)
            winner = ranked[0][0].upper()

        # Print epoch results
        all_runners.sort(key=lambda r: (not r.found_milk, r.steps))
        milk_count = sum(1 for r in all_runners if r.found_milk)
        avg_composite = sum(r.composite(scoring_weights) for r in all_runners) / max(1, len(all_runners))
        print(f"\n  Epoch {epoch + 1}: {milk_count}/{len(all_runners)} milk  "
              f"avg_composite={avg_composite:.4f}  winner={winner or 'n/a'}")
        print(format_lane_scores(ls, winner))

        # Tissue learning
        summary_path = epoch_dir / "epoch_summary.json"
        learnings = _finish_tissue(all_runners, ctx, summary_path,
                                    no_lichen=args.no_lichen)

        # Save epoch summary
        epoch_elapsed = time.time() - t_epoch
        epoch_summary = {
            "epoch": epoch,
            "milk_count": milk_count,
            "n_runners": len(all_runners),
            "avg_composite": round(avg_composite, 4),
            "winner": winner,
            "lane_scores": ls,
            "elapsed_s": round(epoch_elapsed, 1),
            "tissue_signal_count": len(learnings.get("tissue_signal", {})),
            "resource_signal_count": len(learnings.get("resource_signal", {})),
        }
        epoch_summaries.append(epoch_summary)

        # Auto-scale max_cycles toward target win rate
        total_milk_so_far = sum(s["milk_count"] for s in epoch_summaries)
        total_runners_so_far = sum(s["n_runners"] for s in epoch_summaries)
        running_win_rate = total_milk_so_far / max(1, total_runners_so_far)
        epoch_summary["running_win_rate"] = round(running_win_rate, 4)
        epoch_summary["max_cycles"] = max_cycles
        if running_win_rate < target_win_rate and max_cycles < _MAX_CYCLES_CAP:
            new_cycles = min(max_cycles + cycles_step, _MAX_CYCLES_CAP)
            print(f"\n  [{TISSUE}] Win rate {running_win_rate:.1%} < target {target_win_rate:.0%} "
                  f"→ increasing max_cycles {max_cycles} → {new_cycles}")
            max_cycles = new_cycles
        else:
            print(f"\n  [{TISSUE}] Win rate {running_win_rate:.1%}  max_cycles={max_cycles}")

        summary = make_envelope(
            LAYER_TRAIN,
            runners=[r.to_dict() for r in all_runners],
            lane_scores=ls,
            winner=winner,
            learnings=learnings,
            extra={
                "epoch": epoch,
                "elapsed_s": round(epoch_elapsed, 1),
                "tissue_ledger_size": ctx["n_ledger"] + 1,
            },
        )
        write_json(summary_path, summary)

        # Record to leaderboard
        _record_leaderboard(all_runners, layer=LAYER_TRAIN,
                            weights=scoring_weights)

        # Show evolved defaults drift
        evolved_ranges, _ = load_evolved_defaults()
        diffs = format_evolved_diff(evolved_ranges)
        if diffs:
            print(f"\n  [{TISSUE}] Weight drift after epoch {epoch + 1}:")
            for line in diffs[:5]:
                print(f"    {line}")

    total_elapsed = time.time() - t_total

    # Final summary
    print(f"\n{'=' * 64}")
    print(header(DERBY, f"TRAINING COMPLETE ({total_elapsed:.0f}s)"))
    print(f"  {epochs} epochs, {sum(s['n_runners'] for s in epoch_summaries)} total runners")

    if epoch_summaries:
        print(f"\n  {'Epoch':<7} {'Milk':>5} {'Runners':>8} {'WinRate':>8} {'MaxCyc':>7} {'AvgComp':>8} {'Winner':<12} {'Time':>6}")
        print("  " + "-" * 68)
        for s in epoch_summaries:
            wr = s.get("running_win_rate", 0.0)
            mc = s.get("max_cycles", max_cycles)
            print(f"  {s['epoch']+1:<7} {s['milk_count']:>5} {s['n_runners']:>8} "
                  f"{wr:>8.1%} {mc:>7} "
                  f"{s['avg_composite']:>8.4f} {(s['winner'] or 'n/a'):<12} "
                  f"{s['elapsed_s']:>5.0f}s")

        # Show composite trend
        composites = [s["avg_composite"] for s in epoch_summaries]
        if len(composites) >= 2:
            delta = composites[-1] - composites[0]
            direction = "improved" if delta > 0 else "declined"
            print(f"\n  Composite trend: {composites[0]:.4f} -> {composites[-1]:.4f} "
                  f"({direction} by {abs(delta):.4f})")

    # Save training report
    report = make_envelope(
        LAYER_TRAIN,
        extra={
            "total_elapsed_s": round(total_elapsed, 1),
            "epochs": epochs,
            "characters": characters,
            "policies": policies,
            "max_cycles_initial": args.max_cycles,
            "max_cycles_final": max_cycles,
            "target_win_rate": target_win_rate,
            "epoch_summaries": epoch_summaries,
        },
    )
    report_path = train_dir / "training_summary.json"
    write_json(report_path, report)
    print(f"\n  Report: {report_path}")
    print("=" * 64)


# ═══════════════════════════════════════════════════════════════════
# MODE: design  (Claura-proposed character vs baselines)
# ═══════════════════════════════════════════════════════════════════

def cmd_design(args: argparse.Namespace) -> None:
    """🧬 Design mode: evaluate a Claura-proposed character against baselines.

    Called autonomously by SpaceWheatPort on Berry-cycle maintain directives.
    Skips lichen probe (character already generated upstream) but always
    calls _observe_lichen_derby so results feed back to Claura.
    """
    char_name = args.character
    if not character_exists(char_name):
        print(f"Character not found: {char_name}")
        print(f"  Available: {', '.join(list_character_names())}")
        sys.exit(1)

    # Baselines: explicit list, or all characters except the proposed one.
    if args.baselines:
        baselines = [n for n in args.baselines if character_exists(n) and n != char_name]
    else:
        baselines = [n for n in list_character_names() if n != char_name]

    all_characters = [char_name] + baselines

    print(header(DERBY, f"DESIGN: {char_name} vs {len(baselines)} baseline(s)"))
    print(f"  {CHARACTER} Proposed : {char_name}")
    print(f"  {CHARACTER} Baselines: {', '.join(baselines) or 'none'}")
    print(f"  Max cycles: {args.max_cycles}  Policy: engine_policy")

    ts = time.strftime("%Y%m%d_%H%M%S")
    derby_dir = LOG_DIR / f"design_{ts}"
    derby_dir.mkdir(parents=True, exist_ok=True)

    t_total = time.time()

    # Run one duel epoch — no_lichen=True skips the inner probe since the
    # proposed character was already generated by the caller.
    all_runners, lane_results, ctx = _run_duel_epoch(
        characters=all_characters,
        policies=[POLICY_ENGINE],
        max_cycles=args.max_cycles,
        console_profile=args.console_profile,
        use_topology_gto=False,
        no_lichen=True,
        epoch_dir=derby_dir,
    )

    total_elapsed = time.time() - t_total

    scoring_weights = ctx["scoring_weights"]
    ls: Dict[str, Dict[str, Any]] = {}
    for lane, results in lane_results.items():
        ls[lane] = score_lane(results, scoring_weights)

    all_runners.sort(key=lambda r: (not r.found_milk, r.steps))
    print(header(DERBY, f"DESIGN RESULTS ({total_elapsed:.0f}s)"))
    print(format_scoreboard(all_runners, title="ALL RUNNERS", show_scores=True,
                            weights=scoring_weights))

    # Save v2 envelope before tissue/observe so the path is ready.
    summary_path = derby_dir / "design_summary.json"
    summary = make_envelope(
        LAYER_DESIGN,
        runners=[r.to_dict() for r in all_runners],
        lane_scores=ls,
        extra={
            "proposed_character": char_name,
            "baselines": baselines,
            "total_elapsed_s": round(total_elapsed, 1),
            "max_cycles": args.max_cycles,
        },
    )
    write_json(summary_path, summary)
    print(f"\n  Report: {summary_path}")

    # Tissue learning — always, design mode exists to learn.
    _finish_tissue(all_runners, ctx, summary_path, no_lichen=False)

    _record_leaderboard(all_runners, layer=LAYER_DESIGN, weights=scoring_weights)
    print(f"  {SCORE} Leaderboard updated (+{len(all_runners)} entries)")
    print("=" * 64)


# ═══════════════════════════════════════════════════════════════════
# CLI entry point
# ═══════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(
        description="Arena: unified SpaceWheat competition runner",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""modes:
  race    Race N runners on 1 profile with fibonacci scheduling
  duel    Head-to-head: 2+ lanes compete in parallel
  matrix  Batch comparison across multiple profiles
  train   Continuous adversarial learning loop (tissue evolution)

Graph Tissue™ is a trademark of Luke Spooner.""",
    )
    sub = parser.add_subparsers(dest="mode", required=True)

    # ── race ────────────────────────────────────────────────────────
    p_race = sub.add_parser("race", help="Round-robin race on one profile/character")
    p_race_source = p_race.add_mutually_exclusive_group(required=True)
    p_race_source.add_argument("--profile", help="Profile name")
    p_race_source.add_argument("--character", help="Character spec name")
    p_race.add_argument("--runners", type=int, default=DEFAULT_RUNNERS, help="Number of runners (2-5)")
    p_race.add_argument("--max-cycles", type=int, default=MAX_LOOPS,
                        help=f"Max cycles per runner (default: {MAX_LOOPS})")
    p_race.add_argument("--win-threshold", type=int, default=4,
                        help="Stop after N runners complete (default: 4)")
    p_race.add_argument("--hunter-policy", default=POLICY_ENGINE,
                        choices=POLICY_MODES,
                        help="Policy mode (for character mode)")
    p_race.add_argument("--console-profile", default="quiet",
                        choices=["quiet", "normal", "debug", "trace", "test"])
    p_race.add_argument("--strict", type=bool, default=None)

    # ── duel ────────────────────────────────────────────────────────
    p_duel = sub.add_parser("duel", help="Head-to-head lane competition")
    p_duel.add_argument("--lanes", nargs="+", default=DEFAULT_LANES,
                        help="Lane names for profile mode (default: sonnet codex)")
    p_duel.add_argument("--characters", nargs="+", default=None,
                        help="Character specs (enables character mode: lanes=policies)")
    p_duel.add_argument("--policies", nargs="+", default=None,
                        help=f"Policy modes for character mode (default: {' '.join(POLICY_MODES)})")
    p_duel.add_argument("--runners-per-lane", type=int, default=DEFAULT_RUNNERS)
    p_duel.add_argument("--max-cycles", type=int, default=MAX_LOOPS)
    p_duel.add_argument("--hunter-policy", default=POLICY_ENGINE,
                        choices=["auto", "classic", "quantum_graph"] + POLICY_MODES)
    p_duel.add_argument("--console-profile", default="quiet",
                        choices=["quiet", "normal", "debug", "trace", "test"])
    p_duel.add_argument("--use-topology-gto", action="store_true")
    p_duel.add_argument("--no-lichen", action="store_true")

    # ── matrix ──────────────────────────────────────────────────────
    p_matrix = sub.add_parser("matrix", help="Batch comparison across profiles")
    p_matrix.add_argument("--profiles", required=True,
                          help="Comma-separated or glob pattern (e.g. 'derby_*')")
    p_matrix.add_argument("--runs", type=int, default=DEFAULT_RUNS_PER_PROFILE)
    p_matrix.add_argument("--max-cycles", type=int, default=MAX_LOOPS)
    p_matrix.add_argument("--console-profile", default="quiet",
                          choices=["quiet", "normal", "debug", "trace", "test"])

    # ── design ───────────────────────────────────────────────────────
    p_design = sub.add_parser("design", help="Evaluate Claura-proposed character vs baselines")
    p_design.add_argument("--character", required=True,
                          help="Proposed character name (written by Claura probe)")
    p_design.add_argument("--baselines", nargs="*", default=None,
                          help="Baseline character names (default: all other characters)")
    p_design.add_argument("--max-cycles", type=int, default=TRAIN_MAX_CYCLES_START,
                          help=f"Max cycles per runner (default: {TRAIN_MAX_CYCLES_START}, short for fast eval)")
    p_design.add_argument("--console-profile", default="quiet",
                          choices=["quiet", "normal", "debug", "trace", "test"])

    # ── train ────────────────────────────────────────────────────────
    p_train = sub.add_parser("train", help="Continuous adversarial learning loop")
    p_train.add_argument("--characters", nargs="+", default=None,
                         help="Character specs (default: all available)")
    p_train.add_argument("--policies", nargs="+", default=None,
                         help="Policy modes (default: engine_policy quantum_register)")
    p_train.add_argument("--epochs", type=int, default=10,
                         help="Number of training epochs (default: 10)")
    p_train.add_argument("--max-cycles", type=int, default=TRAIN_MAX_CYCLES_START,
                         help=f"Starting max cycles per runner (default: {TRAIN_MAX_CYCLES_START}, auto-scales toward target win rate)")
    p_train.add_argument("--target-win-rate", type=float, default=TRAIN_TARGET_WIN_RATE,
                         help=f"Auto-scale max_cycles upward until this win rate is achieved (default: {TRAIN_TARGET_WIN_RATE})")
    p_train.add_argument("--cycles-step", type=int, default=TRAIN_CYCLES_STEP,
                         help=f"Cycles increment per epoch when win rate is below target (default: {TRAIN_CYCLES_STEP})")
    p_train.add_argument("--console-profile", default="quiet",
                         choices=["quiet", "normal", "debug", "trace", "test"])
    p_train.add_argument("--use-topology-gto", action="store_true")
    p_train.add_argument("--no-lichen", action="store_true")

    args = parser.parse_args()

    if args.mode == "race":
        cmd_race(args)
    elif args.mode == "duel":
        cmd_duel(args)
    elif args.mode == "matrix":
        cmd_matrix(args)
    elif args.mode == "design":
        cmd_design(args)
    elif args.mode == "train":
        cmd_train(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
