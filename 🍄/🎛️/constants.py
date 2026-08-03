#!/usr/bin/env python3
"""Single source of truth for shared numeric and string constants.

Import from here instead of hardcoding values in milk_hunt_batch.py,
milk_hunt_runner.py, milk_hunt_seed_save.py, milk_hunt_args.py,
milk_hunt_characters.py, run_executor.py, etc.

Graph Tissue™ is a trademark of Luke Spooner.
"""
from __future__ import annotations

# ── Cycle / loop limits ──────────────────────────────────────────────
MAX_LOOPS = 220          # Hard cap on cycles per run — mirrors MAX_LOOPS_DEFAULT in
                         # config/milk_hunt_batch.conf.  Change both if you change either.
                         # Used as milk_hunt_batch's --max-loops default.
RUNNER_MAX_LOOPS_FALLBACK = 140  # milk_hunt_runner's fallback when neither CLI,
                                 # config JSON, nor MILK_HUNT_MAX_LOOPS supplies max_loops.

# ── Run counts ──────────────────────────────────────────────────────
DEFAULT_RUNS_BATCH = 5   # milk_hunt_batch's --runs default — mirrors RUNS_DEFAULT in
                         # config/milk_hunt_batch.conf.  Change both if you change either.

# ── Timeouts ────────────────────────────────────────────────────────
# Divergent per-caller timeout formulas live here as NAMED variants — one
# home, deliberately NOT unified (SLOP_PATROL_2026-07-29 knot #26).  Each
# caller imports its own formula; do not merge them into one "canonical"
# timeout without an owner decision.

SEED_TIMEOUT_S = 180     # milk_hunt_batch's seed-save subprocess timeout


def batch_trial_timeout(max_loops: int) -> int:
    """milk_hunt_batch per-trial runner-subprocess timeout.

    Scales with max_loops: 15s per loop + 120s boot margin, minimum 120s.
    """
    return max(120, max_loops * 15 + 120)


# ── Policy modes ─────────────────────────────────────────────────────
POLICY_ENGINE  = "engine_policy"
POLICY_QUANTUM = "quantum_register"
POLICY_MODES   = [POLICY_ENGINE, POLICY_QUANTUM]
POLICY_AUTO    = "auto"
