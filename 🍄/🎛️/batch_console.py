#!/usr/bin/env python3
"""batch_console.py — milk hunt batch runner + display console.

Wraps milk_hunt_batch.py, streams progress, then renders a detailed
formatted readout and records results to the leaderboard.

Usage:
    # Run a fresh batch then display + record:
    python3 batch_console.py --profile balanced_survival --runs 3 --max-loops 220

    # Display + record an existing batch dir (no run):
    python3 batch_console.py --report-only /tmp/milk_hunt_batches/batch_20260310_125624

    # Quick stress run:
    python3 batch_console.py --profile granary_scout --runs 5 --max-loops 150 --lane engine_policy
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

HERE = Path(__file__).resolve().parent
BATCH_RUNNER = HERE / "milk_hunt_batch.py"

# ── Scoring (mirrors schema.py / tissue_ledger.py) ──────────────────────────

def _speed_score(batch: Dict[str, Any]) -> float:
    avg = float(batch.get("avg_steps_success_only") or 999)
    return max(0.0, 1.0 - avg / 300.0) if avg < 999 else 0.0


def _biome_score(batch: Dict[str, Any]) -> float:
    n = len(batch.get("discovered_biomes_union") or [])
    return min(1.0, n / 6.0)


def _vocab_score(batch: Dict[str, Any]) -> float:
    v = float(batch.get("avg_vocab_milestones_per_run") or 0)
    return min(1.0, v / 5.0)


def _composite(batch: Dict[str, Any]) -> float:
    sr = float(batch.get("success_rate") or 0.0)
    sp = _speed_score(batch)
    bs = _biome_score(batch)
    vs = _vocab_score(batch)
    return round(0.50 * sr + 0.30 * sp + 0.10 * bs + 0.10 * vs, 4)


# ── Display helpers ───────────────────────────────────────────────────────────

WIDTH = 78

def _bar(ch: str = "─") -> str:
    return ch * WIDTH


def _header(title: str) -> str:
    pad = max(0, WIDTH - len(title) - 4)
    return f"┌── {title} {'─' * pad}┐"


def _footer() -> str:
    return "└" + "─" * (WIDTH - 1) + "┘"


def _row(text: str) -> str:
    return f"│ {text:<{WIDTH - 3}}│"


def _milk(found: bool) -> str:
    return "🍼 YES" if found else "  no "


def _fmt_run_table(summaries: List[Dict[str, Any]]) -> List[str]:
    lines = []
    lines.append(_row(f"{'#':>3}  {'Milk':6}  {'Steps':>6}  {'Loops':>5}  "
                      f"{'Vocab':>5}  {'Quests':>6}  {'Drains':>6}  {'Error'}"))
    lines.append(_row("─" * (WIDTH - 4)))
    for i, s in enumerate(summaries, 1):
        err = str(s.get("run_error") or s.get("timeout_action") or "")
        if err and len(err) > 14:
            err = err[:12] + ".."
        lines.append(_row(
            f"{i:>3}  "
            f"{_milk(bool(s.get('found_milk_pair'))):6}  "
            f"{int(s.get('steps', 0) or 0):>6}  "
            f"{int(s.get('loops_completed', 0) or 0):>5}  "
            f"{int(s.get('vocab_milestone_count') or s.get('vocab_pairs_learned') or 0):>5}  "
            f"{int(s.get('quest_completions', 0) or 0) + int(s.get('quest_claims', 0) or 0):>6}  "
            f"{int(s.get('lindblad_drain_actions', 0) or 0):>6}  "
            f"{err}"
        ))
    return lines


def _fmt_vocab_journeys(summaries: List[Dict[str, Any]]) -> List[str]:
    lines = []
    for i, s in enumerate(summaries, 1):
        milestones = s.get("vocab_milestones", []) or []
        if not isinstance(milestones, list) or not milestones:
            lines.append(_row(f"  Run {i}: (no milestones recorded)"))
            continue
        found = bool(s.get("found_milk_pair"))
        tag = "🍼" if found else "✗"
        lines.append(_row(f"  Run {i} [{tag}]  {len(milestones)} milestones:"))
        pairs_str = "  "
        for m in milestones:
            if not isinstance(m, dict):
                continue
            new_pairs = m.get("new_pairs", []) or []
            for p in new_pairs:
                north = p.get("north", "?")
                south = p.get("south", "?")
                is_milk = bool(m.get("contains_milk_pair"))
                tag_m = " ←🍼" if is_milk else ""
                step = int(m.get("step", 0) or 0)
                pairs_str += f"L{m.get('loop', '?')}:s{step} {north}↔{south}{tag_m}  "
        # wrap at WIDTH-4
        chunk = WIDTH - 6
        wrapped = [pairs_str[j:j + chunk] for j in range(0, len(pairs_str), chunk)]
        for w in wrapped:
            lines.append(_row(f"    {w}"))
    return lines


def _fmt_action_breakdown(summaries: List[Dict[str, Any]]) -> List[str]:
    combined: Dict[str, int] = {}
    for s in summaries:
        counts = s.get("policy_action_counts") or {}
        if isinstance(counts, dict):
            for k, v in counts.items():
                combined[k] = combined.get(k, 0) + int(v or 0)
    if not combined:
        return [_row("  (no action breakdown available)")]
    total = max(1, sum(combined.values()))
    lines = []
    for action, count in sorted(combined.items(), key=lambda kv: -kv[1]):
        pct = 100.0 * count / total
        bar_len = int(pct / 2)
        lines.append(_row(f"  {action:<28} {count:>6}  {pct:5.1f}%  {'█' * bar_len}"))
    return lines


def display_batch(batch_dir: Path, lane: str = "") -> Dict[str, Any]:
    """Read batch_summary.json and render a formatted report. Returns the summary."""
    agg_path = batch_dir / "batch_summary.json"
    if not agg_path.exists():
        print(f"ERROR: no batch_summary.json in {batch_dir}", file=sys.stderr)
        return {}

    batch = json.loads(agg_path.read_text(encoding="utf-8"))
    runs = batch.get("run_summaries", [])
    profile = batch.get("profile") or batch.get("world_state") or "unknown"
    n = int(batch.get("runs", len(runs)))
    success = int(batch.get("success_count", 0))
    sr = float(batch.get("success_rate", 0.0))
    max_loops = int(batch.get("max_loops", 0))
    avg_steps = float(batch.get("avg_steps_all", 0.0))
    avg_steps_w = float(batch.get("avg_steps_success_only") or 0.0)
    min_steps_w = batch.get("min_steps_success_only")
    max_steps_w = batch.get("max_steps_success_only")
    avg_loops = float(batch.get("avg_loops_completed_all", 0.0))
    avg_vocab = float(batch.get("avg_vocab_milestones_per_run", 0.0))
    avg_quests = float(batch.get("avg_quest_completions_per_run", 0.0))
    discovered = list(batch.get("discovered_biomes_union") or [])
    batch_ts = batch_dir.name.replace("batch_", "")

    sp = _speed_score(batch)
    bs = _biome_score(batch)
    vs = _vocab_score(batch)
    comp = _composite(batch)

    print()
    print(_header(f"🥛 MILK HUNT BATCH — {profile}"))
    print(_row(f"  Batch:  {batch_ts}   Lane: {lane or '(engine)'}"))
    print(_row(f"  Runs:   {n}   Max loops: {max_loops}   "
               f"Strict economy: {batch.get('strict_biome_economy', '?')}"))
    print(_row(f"  Dir:    {batch_dir}"))
    print(_row(""))
    print(_row(f"  RESULT:  {success}/{n} found 🍼   "
               f"Win rate: {sr:.0%}   Avg steps: {avg_steps:.1f}"))
    if success:
        steps_w_str = f"{avg_steps_w:.1f}  (min {min_steps_w} / max {max_steps_w})"
        print(_row(f"           Winners avg steps: {steps_w_str}"))
    print(_row(""))

    print(_row("  SCORES"))
    print(_row(f"    success_rate: {sr:.4f}   speed: {sp:.4f}   "
               f"biome: {bs:.4f}   vocab: {vs:.4f}"))
    print(_row(f"    composite:    {comp:.4f}"))
    print(_row(""))

    print(_row("  AVERAGES per run"))
    print(_row(f"    loops: {avg_loops:.1f}   vocab milestones: {avg_vocab:.1f}   "
               f"quest completions: {avg_quests:.1f}"))
    avg_drain = float(batch.get("avg_lindblad_drain_actions_per_run") or 0.0)
    avg_skip = float(batch.get("avg_time_skip_actions_per_run") or 0.0)
    print(_row(f"    lindblad drains: {avg_drain:.1f}   time skips: {avg_skip:.1f}"))
    if discovered:
        print(_row(f"    biomes discovered (union): {', '.join(discovered)}"))
    print(_row(""))

    print(_row("  PER-RUN TABLE"))
    for ln in _fmt_run_table(runs):
        print(ln)
    print(_row(""))

    print(_row("  VOCAB JOURNEYS"))
    for ln in _fmt_vocab_journeys(runs):
        print(ln)
    print(_row(""))

    print(_row("  ACTION BREAKDOWN (all runs combined)"))
    for ln in _fmt_action_breakdown(runs):
        print(ln)

    print(_footer())
    return batch


RUN_LOG = HERE / "logs" / "run_log.jsonl"


def append_run_log(batch: Dict[str, Any], batch_dir: Path) -> None:
    """Append one line per completed run to the persistent run log."""
    import time as _time
    ts = _time.strftime("%Y-%m-%dT%H:%M:%S")
    profile = batch.get("profile") or batch.get("world_state") or "unknown"
    runs = batch.get("run_summaries", [])
    RUN_LOG.parent.mkdir(parents=True, exist_ok=True)
    with open(RUN_LOG, "a", encoding="utf-8") as f:
        for i, s in enumerate(runs, 1):
            entry = {
                "timestamp": ts,
                "batch": batch_dir.name,
                "profile": profile,
                "run": i,
                "found_milk": bool(s.get("found_milk_pair")),
                "steps": int(s.get("steps", 0) or 0),
                "loops": int(s.get("loops_completed", 0) or 0),
                "vocab": int(s.get("vocab_milestone_count") or s.get("vocab_pairs_learned") or 0),
                "drains": int(s.get("lindblad_drain_actions", 0) or 0),
                "biomes": list(s.get("biome_discovery_order") or []),
                "policy_mode": str(s.get("hunter_policy_mode") or ""),
                "error": s.get("run_error") or s.get("timeout_action"),
            }
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    n = len(runs)
    print(f"  ✓ Appended {n} run{'s' if n != 1 else ''} to {RUN_LOG}")


def record_to_leaderboard(batch: Dict[str, Any], lane: str = "engine_policy") -> None:
    """Record this batch as a single leaderboard entry."""
    try:
        sys.path.insert(0, str(HERE))
        import leaderboard as lb
        profile = batch.get("profile") or batch.get("world_state") or "unknown"
        lb.record_result(
            character=profile,
            lane=lane,
            layer="batch",
            found_milk=bool(batch.get("success_count", 0) > 0),
            cycles=int(batch.get("avg_loops_completed_all") or 0),
            steps=int(batch.get("avg_steps_all") or 0),
            biomes_found=len(batch.get("discovered_biomes_union") or []),
            vocab=int(batch.get("avg_vocab_milestones_per_run") or 0),
            composite=_composite(batch),
            success_rate=float(batch.get("success_rate") or 0.0),
            speed_score=_speed_score(batch),
            biome_score=_biome_score(batch),
            vocab_score=_vocab_score(batch),
            extra={"runs": batch.get("runs"), "max_loops": batch.get("max_loops")},
        )
        print(f"\n  ✓ Recorded to leaderboard (lane={lane}, profile={profile})")
    except Exception as exc:
        print(f"\n  ⚠ Leaderboard record failed: {exc}", file=sys.stderr)


def show_leaderboard() -> None:
    """Print the leaderboard dashboard."""
    try:
        sys.path.insert(0, str(HERE))
        import leaderboard as lb
        print()
        lb.show()
    except Exception as exc:
        print(f"\n  ⚠ Leaderboard display failed: {exc}", file=sys.stderr)


# ── Batch runner ──────────────────────────────────────────────────────────────

def run_batch(
    profile: Optional[str],
    runs: int,
    max_loops: int,
    output_dir: Path,
    lane: str,
    extra_args: List[str],
) -> Optional[Path]:
    """Invoke milk_hunt_batch.py, stream output, return batch_dir."""
    ts_before = time.time()
    cmd = [
        sys.executable,
        str(BATCH_RUNNER),
        "--runs", str(runs),
        "--max-loops", str(max_loops),
        "--output-dir", str(output_dir),
        "--console-profile", "normal",
    ]
    if profile:
        cmd.extend(["--profile", profile])
    cmd.extend(extra_args)

    ts_str = datetime.now().strftime("%Y%m%d_%H%M%S")
    print(f"\n  🚀 Starting batch [{profile or 'no-profile'}]  "
          f"{runs} runs × {max_loops} loops")
    print(f"     Output dir: {output_dir}/batch_{ts_str} (approx)")
    print(f"     Command: {' '.join(cmd[2:])}")
    print(_bar("─"))
    print()

    env = dict(os.environ)

    try:
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            cwd=str(HERE),
            env=env,
        )
        batch_dir_hint: Optional[str] = None
        for line in proc.stdout:  # type: ignore[union-attr]
            line = line.rstrip()
            print(f"  {line}")
            if "batch_" in line and "batch_dir" not in line:
                # Extract batch dir from console output
                for tok in line.split():
                    if "batch_" in tok and output_dir.name in tok:
                        batch_dir_hint = tok
            # Also look for the summary line pattern
            if "-> " in line and str(output_dir) in line:
                batch_dir_hint = line.split("->")[-1].strip()
                # extract just the directory
                import re
                m = re.search(r'(/.+/batch_\d{8}_\d{6})', line)
                if m:
                    batch_dir_hint = m.group(1)
        proc.wait()
    except KeyboardInterrupt:
        proc.terminate()
        print("\n  [batch_console] interrupted — partial results may exist")
        proc.wait()
    except Exception as exc:
        print(f"\n  ERROR: {exc}", file=sys.stderr)
        return None

    elapsed = time.time() - ts_before
    print()
    print(_bar("─"))
    print(f"  Batch finished in {elapsed:.1f}s  (exit={proc.returncode})")

    # Find the newest batch dir
    newest: Optional[Path] = None
    newest_mtime = 0.0
    if output_dir.exists():
        for d in output_dir.iterdir():
            if d.is_dir() and d.name.startswith("batch_"):
                mt = d.stat().st_mtime
                if mt > newest_mtime:
                    newest_mtime = mt
                    newest = d

    if newest and (newest / "batch_summary.json").exists():
        return newest

    # Fallback: try batch_dir_hint
    if batch_dir_hint:
        p = Path(batch_dir_hint)
        if (p / "batch_summary.json").exists():
            return p

    print("  ⚠ Could not locate batch_summary.json", file=sys.stderr)
    return None


# ── CLI ───────────────────────────────────────────────────────────────────────

def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="milk hunt batch runner + display console",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""examples:
  python3 batch_console.py --profile balanced_survival --runs 3 --max-loops 220
  python3 batch_console.py --profile granary_scout --runs 5
  python3 batch_console.py --report-only /tmp/milk_hunt_batches/batch_20260310_125624
  python3 batch_console.py --no-run --batch-dir /tmp/milk_hunt_batches/batch_20260310_125624
""",
    )
    p.add_argument("--profile", default=None,
                   help="Profile name (e.g. balanced_survival, granary_scout)")
    p.add_argument("--runs", type=int, default=3, help="Number of trials (default: 3)")
    p.add_argument("--max-loops", type=int, default=220,
                   help="Max offer cycles per trial (default: 220)")
    p.add_argument("--output-dir", type=Path,
                   default=HERE / "logs" / "milk_batches",
                   help="Parent directory for batch output")
    p.add_argument("--lane", default="engine_policy",
                   help="Leaderboard lane identifier (default: engine_policy)")
    p.add_argument("--no-leaderboard", action="store_true",
                   help="Skip leaderboard recording and display")
    p.add_argument("--report-only", metavar="BATCH_DIR",
                   help="Skip running; just display an existing batch dir")
    p.add_argument("--no-run", action="store_true",
                   help="Same as --report-only but use --batch-dir")
    p.add_argument("--batch-dir", type=Path,
                   help="Existing batch dir to display (used with --no-run)")
    p.add_argument("--no-strict", action="store_true",
                   help="Disable strict biome economy (passes --no-strict-biome-economy)")
    p.add_argument("--topology-gto", action="store_true",
                   help="Enable GTO policy mutation sweep")
    p.add_argument("--no-reuse-listener", action="store_true",
                   help="Fresh Godot process per run (slower startup, avoids state accumulation)")
    return p


def main() -> int:
    args = _build_parser().parse_args()

    batch_dir: Optional[Path] = None

    if args.report_only:
        batch_dir = Path(args.report_only)
    elif args.no_run and args.batch_dir:
        batch_dir = args.batch_dir
    else:
        # Build extra args for batch runner
        extra: List[str] = []
        if args.no_strict:
            extra.append("--no-strict-biome-economy")
        else:
            extra.append("--strict-biome-economy")
        if args.topology_gto:
            extra.append("--topology-gto")
        if args.no_reuse_listener:
            extra.append("--no-reuse-listener")

        batch_dir = run_batch(
            profile=args.profile,
            runs=args.runs,
            max_loops=args.max_loops,
            output_dir=args.output_dir,
            lane=args.lane,
            extra_args=extra,
        )

    if batch_dir is None:
        return 1

    batch = display_batch(batch_dir, lane=args.lane)
    if not batch:
        return 1

    append_run_log(batch, batch_dir)
    if not args.no_leaderboard:
        record_to_leaderboard(batch, lane=args.lane)
        show_leaderboard()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
