#!/usr/bin/env python3
"""Persistent cross-run leaderboard for SpaceWheat.

Append-only JSONL ledger tracking every runner result across all
arena modes and session autoplay runs.  Provides aggregation views
by lane (LLM identity), character, policy, and cross-dimensional.

Usage (library):

    from leaderboard import record_result, record_results, show

    # After a race/duel finishes
    record_results(runners, layer="duel", default_lane="sonnet")

    # Print the leaderboard
    show()

Usage (CLI):

    python3 leaderboard.py                   # overall leaderboard
    python3 leaderboard.py lanes             # per-lane (LLM) rankings
    python3 leaderboard.py characters        # per-character rankings
    python3 leaderboard.py policies          # policy comparison
    python3 leaderboard.py history           # recent entries
    python3 leaderboard.py best              # all-time best runs
    python3 leaderboard.py head-to-head      # lane x character matrix
    python3 leaderboard.py clear             # wipe the ledger

Graph Tissue(TM) is a trademark of Luke Spooner.
"""
from __future__ import annotations

import json
import time
from collections import defaultdict
from pathlib import Path
from typing import Any, Dict, List, Optional

from emoji import (
    DERBY, RACE, LANE, RUNNER, CHARACTER, SCORE,
    header,
)

HERE = Path(__file__).resolve().parent
LEADERBOARD_PATH = HERE / "config" / "leaderboard.jsonl"


# ═══════════════════════════════════════════════════════════════════
# Ledger I/O (append-only JSONL, same pattern as tissue_ledger)
# ═══════════════════════════════════════════════════════════════════

def load_all(path: Optional[Path] = None) -> List[Dict[str, Any]]:
    """Read all leaderboard entries (oldest first)."""
    p = path or LEADERBOARD_PATH
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


def _append(entry: Dict[str, Any], path: Optional[Path] = None) -> None:
    p = path or LEADERBOARD_PATH
    p.parent.mkdir(parents=True, exist_ok=True)
    with open(p, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


def record_result(
    *,
    character: str = "",
    profile: str = "",
    lane: str = "",
    policy: str = "",
    layer: str = "",
    found_milk: bool = False,
    cycles: int = 0,
    steps: int = 0,
    biomes_found: int = 0,
    vocab: int = 0,
    elapsed_s: float = 0.0,
    composite: float = 0.0,
    success_rate: float = 0.0,
    speed_score: float = 0.0,
    biome_score: float = 0.0,
    vocab_score: float = 0.0,
    extra: Optional[Dict[str, Any]] = None,
    path: Optional[Path] = None,
) -> Dict[str, Any]:
    """Record one runner result to the leaderboard ledger."""
    entry: Dict[str, Any] = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "layer": layer,
        "lane": lane,
        "character": character or profile,
        "policy": policy,
        "found_milk": found_milk,
        "cycles": cycles,
        "steps": steps,
        "biomes_found": biomes_found,
        "vocab": vocab,
        "elapsed_s": round(elapsed_s, 2),
        "composite": round(composite, 4),
        "success_rate": round(success_rate, 4),
        "speed_score": round(speed_score, 4),
        "biome_score": round(biome_score, 4),
        "vocab_score": round(vocab_score, 4),
    }
    if extra:
        entry["extra"] = extra
    _append(entry, path)
    return entry


def record_from_runner_result(
    runner: Any,
    *,
    layer: str = "",
    default_lane: str = "",
    weights: Optional[Dict[str, float]] = None,
    path: Optional[Path] = None,
) -> Dict[str, Any]:
    """Record a RunnerResult object to the leaderboard."""
    return record_result(
        character=runner.profile,
        lane=runner.lane or default_lane,
        policy="",
        layer=layer,
        found_milk=runner.found_milk,
        cycles=runner.cycles,
        steps=runner.steps,
        biomes_found=runner.biomes_found or len(runner.biomes),
        vocab=runner.vocab,
        elapsed_s=runner.elapsed_s,
        composite=runner.composite(weights),
        success_rate=runner.success_rate,
        speed_score=runner.speed_score,
        biome_score=runner.biome_score,
        vocab_score=runner.vocab_score,
        path=path,
    )


def record_results(
    runners: List[Any],
    *,
    layer: str = "",
    default_lane: str = "",
    weights: Optional[Dict[str, float]] = None,
    path: Optional[Path] = None,
) -> int:
    """Record multiple RunnerResult objects. Returns count recorded."""
    for r in runners:
        record_from_runner_result(
            r, layer=layer, default_lane=default_lane,
            weights=weights, path=path)
    return len(runners)


def clear(path: Optional[Path] = None) -> None:
    """Wipe the leaderboard ledger."""
    p = path or LEADERBOARD_PATH
    if p.exists():
        p.unlink()


# ═══════════════════════════════════════════════════════════════════
# Aggregation views
# ═══════════════════════════════════════════════════════════════════

def _group_by(entries: List[Dict[str, Any]], key: str) -> Dict[str, List[Dict[str, Any]]]:
    groups: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
    for e in entries:
        val = str(e.get(key, "") or "unknown")
        groups[val].append(e)
    return dict(groups)


def _agg(entries: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Aggregate a list of entries into summary stats."""
    n = len(entries)
    if n == 0:
        return {"runs": 0}
    milk = sum(1 for e in entries if e.get("found_milk"))
    composites = [float(e.get("composite", 0)) for e in entries]
    steps_winners = [int(e.get("steps", 0)) for e in entries if e.get("found_milk")]
    return {
        "runs": n,
        "milk_count": milk,
        "win_rate": round(milk / n, 4) if n else 0,
        "avg_composite": round(sum(composites) / n, 4),
        "best_composite": round(max(composites), 4),
        "avg_steps_winners": round(sum(steps_winners) / len(steps_winners), 1) if steps_winners else None,
        "avg_cycles": round(sum(int(e.get("cycles", 0)) for e in entries) / n, 1),
    }


def by_lane(entries: Optional[List[Dict[str, Any]]] = None) -> Dict[str, Dict[str, Any]]:
    """Aggregate by lane (LLM identity)."""
    all_entries = entries if entries is not None else load_all()
    groups = _group_by(all_entries, "lane")
    return {k: _agg(v) for k, v in sorted(groups.items())}


def by_character(entries: Optional[List[Dict[str, Any]]] = None) -> Dict[str, Dict[str, Any]]:
    """Aggregate by character/profile."""
    all_entries = entries if entries is not None else load_all()
    groups = _group_by(all_entries, "character")
    return {k: _agg(v) for k, v in sorted(groups.items())}


def by_policy(entries: Optional[List[Dict[str, Any]]] = None) -> Dict[str, Dict[str, Any]]:
    """Aggregate by policy mode."""
    all_entries = entries if entries is not None else load_all()
    groups = _group_by(all_entries, "policy")
    return {k: _agg(v) for k, v in sorted(groups.items())}


def head_to_head(entries: Optional[List[Dict[str, Any]]] = None) -> Dict[str, Dict[str, Any]]:
    """Lane x character matrix."""
    all_entries = entries if entries is not None else load_all()
    matrix: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
    for e in all_entries:
        lane = str(e.get("lane", "") or "?")
        char = str(e.get("character", "") or "?")
        key = f"{lane} / {char}"
        matrix[key].append(e)
    return {k: _agg(v) for k, v in sorted(matrix.items())}


def best_runs(entries: Optional[List[Dict[str, Any]]] = None, n: int = 10) -> List[Dict[str, Any]]:
    """Top N runs by composite score."""
    all_entries = entries if entries is not None else load_all()
    return sorted(all_entries, key=lambda e: float(e.get("composite", 0)), reverse=True)[:n]


# ═══════════════════════════════════════════════════════════════════
# Formatting
# ═══════════════════════════════════════════════════════════════════

def _fmt_table(title: str, data: Dict[str, Dict[str, Any]], sort_key: str = "avg_composite") -> str:
    lines = [header(SCORE, title)]
    if not data:
        lines.append("  (no data)")
        return "\n".join(lines)

    ranked = sorted(data.items(), key=lambda kv: kv[1].get(sort_key, 0), reverse=True)
    lines.append(f"  {'#':<3} {'Name':<28} {'Runs':>5} {'Win%':>6} "
                 f"{'AvgComp':>8} {'BestComp':>9} {'AvgSteps':>9}")
    lines.append("  " + "-" * 72)
    for i, (name, stats) in enumerate(ranked):
        avg_steps = stats.get("avg_steps_winners")
        steps_str = f"{avg_steps:>9.1f}" if avg_steps is not None else "      n/a"
        lines.append(
            f"  {i+1:<3} {name:<28} {stats['runs']:>5} "
            f"{stats['win_rate']:>5.0%} "
            f"{stats['avg_composite']:>8.4f} {stats['best_composite']:>9.4f} "
            f"{steps_str}")
    return "\n".join(lines)


def format_overall(entries: Optional[List[Dict[str, Any]]] = None) -> str:
    """Overall leaderboard: all unique character/profile names ranked."""
    return _fmt_table("LEADERBOARD", by_character(entries))


def format_lanes(entries: Optional[List[Dict[str, Any]]] = None) -> str:
    """Per-lane (LLM) rankings."""
    return _fmt_table("LANE RANKINGS (LLM Identity)", by_lane(entries))


def format_characters(entries: Optional[List[Dict[str, Any]]] = None) -> str:
    """Per-character rankings."""
    return _fmt_table("CHARACTER RANKINGS", by_character(entries))


def format_policies(entries: Optional[List[Dict[str, Any]]] = None) -> str:
    """Policy comparison."""
    return _fmt_table("POLICY COMPARISON", by_policy(entries))


def format_history(entries: Optional[List[Dict[str, Any]]] = None, n: int = 20) -> str:
    """Recent entries."""
    all_entries = entries if entries is not None else load_all()
    recent = all_entries[-n:]
    lines = [header(SCORE, f"RECENT HISTORY (last {len(recent)})")]
    if not recent:
        lines.append("  (no entries)")
        return "\n".join(lines)
    lines.append(f"  {'Time':<20} {'Lane':<10} {'Character':<24} {'Milk':>5} "
                 f"{'Cycles':>6} {'Steps':>6} {'Score':>7}")
    lines.append("  " + "-" * 80)
    for e in reversed(recent):
        ts = str(e.get("timestamp", "?"))[-19:]
        milk = "YES" if e.get("found_milk") else "no"
        lines.append(
            f"  {ts:<20} {str(e.get('lane', '')):<10} "
            f"{str(e.get('character', '')):<24} {milk:>5} "
            f"{int(e.get('cycles', 0)):>6} {int(e.get('steps', 0)):>6} "
            f"{float(e.get('composite', 0)):>7.4f}")
    return "\n".join(lines)


def format_best(entries: Optional[List[Dict[str, Any]]] = None, n: int = 10) -> str:
    """All-time best runs."""
    top = best_runs(entries, n)
    lines = [header(SCORE, f"ALL-TIME BEST (top {len(top)})")]
    if not top:
        lines.append("  (no entries)")
        return "\n".join(lines)
    lines.append(f"  {'#':<3} {'Lane':<10} {'Character':<24} {'Milk':>5} "
                 f"{'Steps':>6} {'Score':>7} {'Time'}")
    lines.append("  " + "-" * 80)
    for i, e in enumerate(top):
        milk = "YES" if e.get("found_milk") else "no"
        lines.append(
            f"  {i+1:<3} {str(e.get('lane', '')):<10} "
            f"{str(e.get('character', '')):<24} {milk:>5} "
            f"{int(e.get('steps', 0)):>6} {float(e.get('composite', 0)):>7.4f} "
            f"{str(e.get('timestamp', ''))}")
    return "\n".join(lines)


def format_head_to_head(entries: Optional[List[Dict[str, Any]]] = None) -> str:
    """Lane x character matrix."""
    return _fmt_table("HEAD-TO-HEAD (Lane x Character)", head_to_head(entries))


def show(entries: Optional[List[Dict[str, Any]]] = None) -> None:
    """Print the full leaderboard dashboard."""
    all_entries = entries if entries is not None else load_all()
    n = len(all_entries)
    milk = sum(1 for e in all_entries if e.get("found_milk"))
    print(f"\n  {SCORE} SpaceWheat Leaderboard — {n} runs recorded, {milk} milk found")
    print()
    print(format_lanes(all_entries))
    print()
    print(format_characters(all_entries))
    print()
    print(format_best(all_entries, 5))


# ═══════════════════════════════════════════════════════════════════
# CLI entry point
# ═══════════════════════════════════════════════════════════════════

def main() -> int:
    import argparse
    parser = argparse.ArgumentParser(
        description="SpaceWheat leaderboard — persistent cross-run rankings",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""views:
  (default)      Full dashboard (lanes + characters + best)
  lanes          Per-lane (LLM identity) rankings
  characters     Per-character rankings
  policies       Policy mode comparison
  history        Recent N entries
  best           All-time best runs
  head-to-head   Lane x character matrix
  clear          Wipe the leaderboard""",
    )
    parser.add_argument("view", nargs="?", default="show",
                        choices=["show", "lanes", "characters", "policies",
                                 "history", "best", "head-to-head", "clear"])
    parser.add_argument("-n", type=int, default=20, help="Number of entries for history/best")
    args = parser.parse_args()

    if args.view == "clear":
        entries = load_all()
        if not entries:
            print("  Leaderboard is already empty.")
        else:
            print(f"  Clearing {len(entries)} entries from leaderboard...")
            clear()
            print("  Done.")
        return 0

    entries = load_all()
    if not entries:
        print(f"  {SCORE} No leaderboard entries yet.")
        print(f"  Run a competition first:")
        print(f"    python3 arena.py race --character granary_scout_fib")
        print(f"    python3 session.py --character granary_scout_fib --autoplay")
        return 0

    if args.view == "show":
        show(entries)
    elif args.view == "lanes":
        print(format_lanes(entries))
    elif args.view == "characters":
        print(format_characters(entries))
    elif args.view == "policies":
        print(format_policies(entries))
    elif args.view == "history":
        print(format_history(entries, args.n))
    elif args.view == "best":
        print(format_best(entries, args.n))
    elif args.view == "head-to-head":
        print(format_head_to_head(entries))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
