#!/usr/bin/env python3
"""Unified data types and JSON output schemas for SpaceWheat orchestration.

Replaces the patchwork of HunterResult, RunnerState, and ad-hoc dicts
with a single RunnerResult dataclass used at every layer.

All JSON output uses the unified vocabulary from emoji.py.

Graph Tissue™ is a trademark of Luke Spooner.
"""
from __future__ import annotations

import time
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

from emoji import (
    SCHEMA_VERSION,
    LAYER_RUN,
    LAYER_BATCH,
    LAYER_RACE,
    LAYER_DUEL,
    LAYER_MATRIX,
)
from tissue_ledger import score_with_weights


# ── Core result dataclass ───────────────────────────────────────────

@dataclass
class RunnerResult:
    """One runner's outcome — used at every layer.

    This replaces HunterResult (derby.py) and RunnerState
    (derby_round_robin.py) with a single unified type.
    """
    profile: str            # 🎯 profile name
    lane: str = ""          # 🧬 lane (empty for single-lane modes)
    found_milk: bool = False  # 🍼 did this runner find the milk pair?
    steps: int = 0          # 👣 total action/decision count
    cycles: int = 0         # 🔁 offer cycles (loops) completed
    biomes_found: int = 0   # 🗺️ unique biomes discovered
    biomes: List[str] = field(default_factory=list)  # biome names
    vocab: int = 0          # 📖 vocab milestones hit
    elapsed_s: float = 0.0  # ⏱️ wall clock seconds
    slot: int = -1          # 🎰 save slot used
    exit_code: int = 0
    rounds: int = 0         # race mode: how many fibonacci rounds
    active: bool = False    # race mode: still running?
    batch_summary: Dict[str, Any] = field(default_factory=dict)

    # ── Scoring properties ──────────────────────────────────────────

    @property
    def success_rate(self) -> float:
        """From batch_summary if available, else binary from found_milk."""
        return float(self.batch_summary.get(
            "success_rate", 1.0 if self.found_milk else 0.0))

    @property
    def speed_score(self) -> float:
        """1.0 - (avg_steps / 300), clamped to [0, 1]."""
        avg = float(self.batch_summary.get(
            "avg_steps_success_only", self.steps if self.found_milk else 999))
        return max(0.0, 1.0 - avg / 300.0) if avg < 999 else 0.0

    @property
    def biome_score(self) -> float:
        """min(biomes / 6, 1.0)."""
        n = self.biomes_found or len(self.biomes) or len(
            self.batch_summary.get("discovered_biomes_union", []))
        return min(1.0, n / 6.0)

    @property
    def vocab_score(self) -> float:
        """min(vocab / 5, 1.0)."""
        v = self.vocab or float(
            self.batch_summary.get("avg_vocab_milestones_per_run", 0))
        return min(1.0, v / 5.0)

    def composite(self, weights: Optional[Dict[str, float]] = None) -> float:
        """Weighted composite score."""
        return score_with_weights(
            self.success_rate, self.speed_score,
            self.biome_score, self.vocab_score, weights)

    def scores_dict(self, weights: Optional[Dict[str, float]] = None) -> Dict[str, float]:
        """All scoring dimensions as a dict."""
        return {
            "success_rate": round(self.success_rate, 4),
            "speed_score": round(self.speed_score, 4),
            "biome_score": round(self.biome_score, 4),
            "vocab_score": round(self.vocab_score, 4),
            "composite": round(self.composite(weights), 4),
        }

    # ── Conversion helpers ──────────────────────────────────────────

    def to_dict(self) -> Dict[str, Any]:
        """Serializable dict with unified keys."""
        return {
            "profile": self.profile,
            "lane": self.lane,
            "found_milk": self.found_milk,
            "steps": self.steps,
            "cycles": self.cycles,
            "biomes": self.biomes,
            "vocab": self.vocab,
            "elapsed_s": round(self.elapsed_s, 2),
            "slot": self.slot,
            "exit_code": self.exit_code,
        }

    @classmethod
    def from_batch_summary(
        cls,
        profile: str,
        batch_summary: Dict[str, Any],
        *,
        lane: str = "",
        elapsed_s: float = 0.0,
        exit_code: int = 0,
    ) -> "RunnerResult":
        """Build from a milk_hunt_batch batch_summary.json."""
        runs = batch_summary.get("run_summaries", [])
        run = runs[0] if runs else {}
        return cls(
            profile=profile,
            lane=lane,
            found_milk=bool(run.get("found_milk_pair", False)),
            steps=int(run.get("steps", run.get("turns_executed", 0) or 0) or 0),
            cycles=int(run.get("loops_completed", 0)),
            biomes=list(batch_summary.get("discovered_biomes_union", [])),
            biomes_found=len(batch_summary.get("discovered_biomes_union", [])),
            vocab=int(batch_summary.get("avg_vocab_milestones_per_run", 0)),
            elapsed_s=elapsed_s,
            exit_code=exit_code,
            batch_summary=batch_summary,
        )

    @classmethod
    def from_race_state(
        cls,
        profile: str,
        slot: int,
        *,
        loops_done: int = 0,
        steps_done: int = 0,
        found_milk: bool = False,
        failed: bool = False,
        total_elapsed_s: float = 0.0,
        n_rounds: int = 0,
    ) -> "RunnerResult":
        """Build from derby_round_robin RunnerState fields."""
        return cls(
            profile=profile,
            slot=slot,
            found_milk=found_milk,
            steps=steps_done,
            cycles=loops_done,
            elapsed_s=total_elapsed_s,
            rounds=n_rounds,
            exit_code=0 if found_milk else (1 if failed else 0),
        )


# ── Lane scoring ────────────────────────────────────────────────────

def score_lane(
    runners: List[RunnerResult],
    weights: Optional[Dict[str, float]] = None,
) -> Dict[str, Any]:
    """Aggregate scores across all runners in a lane."""
    if not runners:
        return {"runners": 0, "milk_count": 0, "composite": 0.0}
    n = len(runners)
    return {
        "runners": n,
        "milk_count": sum(1 for r in runners if r.found_milk),
        "success_rate": round(sum(r.success_rate for r in runners) / n, 4),
        "speed_score": round(sum(r.speed_score for r in runners) / n, 4),
        "biome_score": round(sum(r.biome_score for r in runners) / n, 4),
        "vocab_score": round(sum(r.vocab_score for r in runners) / n, 4),
        "composite": round(sum(r.composite(weights) for r in runners) / n, 4),
    }


# ── Output envelope ─────────────────────────────────────────────────

def make_envelope(
    layer: str,
    profile: str = "",
    *,
    runners: Optional[List[Dict[str, Any]]] = None,
    scores: Optional[Dict[str, Any]] = None,
    lane_scores: Optional[Dict[str, Dict[str, Any]]] = None,
    winner: Optional[str] = None,
    learnings: Optional[Dict[str, Any]] = None,
    extra: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """Build a unified JSON output envelope.

    All arena.py output goes through this function so the format is
    consistent across modes (run, batch, race, duel, matrix, design).
    """
    out: Dict[str, Any] = {
        "schema": SCHEMA_VERSION,
        "layer": layer,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
    }
    if profile:
        out["profile"] = profile
    if runners is not None:
        out["runners"] = runners
    if scores is not None:
        out["scores"] = scores
    if lane_scores is not None:
        out["lane_scores"] = lane_scores
    if winner is not None:
        out["winner"] = winner
    if learnings is not None:
        out["learnings"] = learnings
    if extra:
        out.update(extra)
    return out


# ── Scoreboard formatting ──────────────────────────────────────────

def format_scoreboard(
    runners: List[RunnerResult],
    *,
    title: str = "SCOREBOARD",
    round_idx: int = -1,
    step_size: int = -1,
    show_scores: bool = False,
    weights: Optional[Dict[str, float]] = None,
) -> str:
    """Format a human-readable scoreboard table.

    Works for both race mode (live per-round updates) and final results.
    """
    lines = []
    active = sum(1 for r in runners if r.active)
    done = len(runners) - active

    if round_idx >= 0:
        lines.append(f"\n  -- Round {round_idx + 1} (step={step_size}) "
                      f"-- active={active} done={done}")
    else:
        lines.append(f"\n  {title}")

    if show_scores:
        hdr = (f"  {'#':<3} {'Profile':<24} {'Lane':<8} {'Milk':>5} "
               f"{'Cycles':>6} {'Steps':>6} {'Time':>7} {'Score':>7}")
    else:
        hdr = (f"  {'#':<3} {'Profile':<24} {'Lane':<8} {'Milk':>5} "
               f"{'Cycles':>6} {'Steps':>6} {'Time':>7}")
    lines.append(hdr)
    lines.append("  " + "-" * (len(hdr) - 2))

    for i, r in enumerate(runners):
        if r.found_milk:
            status = "YES"
        elif r.exit_code != 0 and not r.active:
            status = "FAIL"
        elif not r.active:
            status = "done"
        else:
            status = "..."
        lane_str = r.lane or "-"
        profile_str = r.profile[:24]
        row = (f"  {i+1:<3} {profile_str:<24} {lane_str:<8} {status:>5} "
               f"{r.cycles:>6} {r.steps:>6} {r.elapsed_s:>6.1f}s")
        if show_scores:
            row += f" {r.composite(weights):>7.4f}"
        lines.append(row)

    return "\n".join(lines)


def format_lane_scores(
    lane_scores: Dict[str, Dict[str, Any]],
    winner: Optional[str] = None,
) -> str:
    """Format lane comparison table."""
    lines = ["\n  LANE SCORES:"]
    for lane, s in sorted(lane_scores.items(),
                          key=lambda x: x[1].get("composite", 0), reverse=True):
        lines.append(
            f"    {lane.upper():<8} "
            f"SR={s.get('success_rate', 0):.0%}  "
            f"speed={s.get('speed_score', 0):.2f}  "
            f"biome={s.get('biome_score', 0):.2f}  "
            f"vocab={s.get('vocab_score', 0):.2f}  "
            f"composite={s.get('composite', 0):.4f}")
    if winner:
        lines.append(f"\n  WINNER: {winner}")
    return "\n".join(lines)
