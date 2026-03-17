#!/usr/bin/env python3
"""Unified emoji vocabulary for SpaceWheat orchestration layers.

This module is the single source of truth for all emoji tags used across
the derby/batch/run system.  Import from here — never hardcode emoji
meanings elsewhere.

Two kinds of emoji live here:

  1. **Resource emojis** — in-game resources (👥 labor, 🌾 wheat, etc.)
     These come from config/emoji_registry.json and are re-exported here
     for convenience.

  2. **Layer/concept emojis** — orchestration vocabulary (🏆 derby,
     🎽 runner, 📦 batch, etc.)  These standardize the terminology across
     arena.py, batch.py, run.py, and session.py.

Graph Tissue™ is a trademark of Luke Spooner.
"""
from __future__ import annotations

# ── Layer / concept tags ────────────────────────────────────────────
# One emoji per concept.  Used in JSON output, CLI output, docstrings.

DERBY   = "🏆"   # Multi-lane competition event
RACE    = "🏁"   # Round-robin interleaved race
LANE    = "🧬"   # LLM competitor identity (sonnet, codex, ...)
RUNNER  = "🎽"   # One profile instance in competition
PROFILE = "🎯"   # Starter world-state config
BATCH   = "📦"   # N independent runs of the same profile
RUN     = "🧪"   # One complete trial (seed -> play -> result)
CYCLE   = "🔁"   # One offer->accept->complete quest loop
STEP    = "👣"   # One action/decision
POLICY  = "🧠"   # Decision-making function
TISSUE  = "📊"   # Graph Tissue(TM) weight system
LICHEN  = "🍄"   # Quantum lichen organism (Claura bridge)
SEED    = "🌱"   # Save slot initialization
SLOT    = "🎰"   # Save slot number
SCORE   = "⭐"   # Composite score
PIN     = "📌"   # Schema version tag

# ── Resource emojis ─────────────────────────────────────────────────
# Canonical names for the 7 starter resources + goal.

LABOR   = "👥"
WHEAT   = "🌾"
BREAD   = "🍞"
COLD    = "❄️"
SPROUT  = "🌱"
GEAR    = "⚙"
FIRE    = "🔥"
ENERGY  = "⚡"
EAGLE   = "🦅"
MILK    = "🍼"
MUSHROOM = "🍄"

STARTER_RESOURCES = [LABOR, WHEAT, BREAD, COLD, SPROUT, GEAR, FIRE]

# ── Scoring dimension emojis ────────────────────────────────────────

MILK_RATE   = "🍼"    # Success rate (found milk?)
SPEED       = "⚡"    # Speed score (steps to milk)
BIOME       = "🗺️"   # Biome coverage score
VOCAB       = "📖"    # Vocabulary breadth score
COMPOSITE   = "🏆"    # Weighted composite

# ── Vernacular mapping ──────────────────────────────────────────────
# Maps old inconsistent terms to unified names.  Used by schema.py
# for backwards-compatible JSON output.

TERM_MAP = {
    # old term            -> (unified term, emoji)
    "hunter":               ("runner",  RUNNER),
    "character":            ("runner",  RUNNER),
    "trial":                ("run",     RUN),
    "loop":                 ("cycle",   CYCLE),
    "offer_cycle":          ("cycle",   CYCLE),
    "turn":                 ("step",    STEP),
    "agent":                ("lane",    LANE),
    "world_state":          ("profile", PROFILE),
    "hunter_profile":       ("profile", PROFILE),
    "found_milk_pair":      ("found_milk", MILK),
    "loops_completed":      ("cycles",  CYCLE),
    "steps":                ("steps",   STEP),
    "turns_executed":       ("steps",   STEP),
}

# ── Console formatting helpers ──────────────────────────────────────

def tag(emoji: str, text: str) -> str:
    """Format an emoji-tagged label for console output."""
    return f"{emoji} {text}"

def header(emoji: str, title: str, width: int = 64) -> str:
    """Format a section header with emoji."""
    line = f"  {emoji} {title}"
    return f"{'=' * width}\n{line}\n{'=' * width}"

def scored(label: str, value: float, width: int = 6) -> str:
    """Format a score value."""
    return f"{label}={value:.{width}f}" if isinstance(value, float) else f"{label}={value}"


# ── Layer names (for JSON output) ───────────────────────────────────

LAYER_RUN    = "run"
LAYER_BATCH  = "batch"
LAYER_RACE   = "race"
LAYER_DUEL   = "duel"
LAYER_MATRIX = "matrix"
LAYER_DESIGN = "design"

SCHEMA_VERSION = "v2"
