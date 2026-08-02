#!/usr/bin/env python3
"""Single source of truth for shared numeric and string constants.

Import from here instead of hardcoding values in arena.py, derby.py,
session.py, milk_hunt_batch.py, etc.

Graph Tissue™ is a trademark of Luke Spooner.
"""
from __future__ import annotations

# ── Cycle / loop limits ──────────────────────────────────────────────
MAX_LOOPS = 220          # Hard cap on cycles per run — mirrors MAX_LOOPS_DEFAULT in
                         # config/milk_hunt_batch.conf.  Change both if you change either.

# ── Timeouts ────────────────────────────────────────────────────────
SECS_PER_CYCLE   = 30   # Budget per cycle when computing subprocess timeouts
SEED_TIMEOUT_S   = 180  # Per-character save-seed timeout
MATCH_TIMEOUT_S  = 200  # Per-character batch-match timeout (derby.py)

# Per-mode minimum timeout floor (seconds).  run_timeout() uses these.
TIMEOUT_FLOOR: dict = {
    "race":    120,
    "duel":    300,
    "design":  300,
    "train":   300,
    "session": 300,
    "matrix":  600,
}


def run_timeout(max_cycles: int, floor: int = 300, runs: int = 1) -> int:
    """Compute subprocess timeout: max(floor, max_cycles * SECS_PER_CYCLE * runs)."""
    return max(floor, max_cycles * SECS_PER_CYCLE * runs)


# ── Policy modes ─────────────────────────────────────────────────────
POLICY_ENGINE  = "engine_policy"
POLICY_QUANTUM = "quantum_register"
POLICY_MODES   = [POLICY_ENGINE, POLICY_QUANTUM]
POLICY_AUTO    = "auto"

# ── Default lane names (profile-mode duel) ───────────────────────────
DEFAULT_LANES = ["sonnet", "codex"]

# ── Train mode defaults ──────────────────────────────────────────────
TRAIN_MAX_CYCLES_START = 55    # Starting max_cycles for arena train
TRAIN_CYCLES_STEP      = 13    # Increment per epoch when below target win rate
TRAIN_TARGET_WIN_RATE  = 0.80  # Auto-scale target

# ── Runner / run counts ──────────────────────────────────────────────
DEFAULT_RUNNERS         = 5   # Runners per race or per lane in duel
DEFAULT_RUNS_PER_PROFILE = 3  # Runs per profile in matrix mode
DEFAULT_RUNS_BATCH      = 5   # Runs in milk_hunt_batch
