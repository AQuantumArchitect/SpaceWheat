#!/usr/bin/env python3
"""Lichen Player: Claude Code sub-agent plays SpaceWheat via RunSession API.

The simplest possible LLM-in-the-loop SpaceWheat player.
No training, no tissue, no pheromones — just an LLM reading
game state and picking actions. The quantum learning is a
bonus that accumulates over time, not a prerequisite.

Uses `claude -p` (Claude Code CLI) as the LLM interface — same
pattern as HaikuRunner/SonnetRunner. No API key required.

Follows the universal observe→project→deposit loop:
  OBSERVE: read game state (resources, vocab, offers, biomes)
  PROJECT: LLM picks action from state (or heuristic fallback)
  DEPOSIT: execute action, record to leaderboard, fold back to Claura

Usage:
    python3 lichen_player.py --profile balanced_survival --max-cycles 40
    python3 lichen_player.py --character granary_scout_fib --max-cycles 60
    python3 lichen_player.py --character granary_scout_fib --model haiku

Graph Tissue(TM) is a trademark of Luke Spooner.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

from session import RunSession
from leaderboard import record_result

HERE = Path(__file__).resolve().parent
CLAURA_ROOT = HERE.parent.parent.parent / "Claura"
CLAURA_RIG_STATE = CLAURA_ROOT / "fungi_rig_state.json"

# Habitat paths
_CLAURA_HABITAT_PATH = CLAURA_ROOT / "🍄" / "🧠" / "🌾" / "context.yaml"
_CONTROL_HABITAT_PATH = HERE / "context.yaml"

# ---------------------------------------------------------------------------
# LLM decision-making (claude -p, same as HaikuRunner/SonnetRunner)
# ---------------------------------------------------------------------------

SYSTEM_PROMPT = """\
You are playing SpaceWheat, a resource-management game. Your goal is to find \
the milk emoji pair (🍼). You do this by completing quests to learn vocabulary \
pairs, discovering biomes to expand your search space, and probing for patterns.

Each turn you must choose ONE action. Reply with ONLY a JSON object:
{"action": "<name>", "reason": "<one sentence>"}

Available actions:
- quest_cycle: accept and complete the best available quest (earns resources AND vocab pairs)
- discover: unlock a new biome (more biomes = more vocab sources)
- probe: probe the current biome for quantum grid patterns
- time_skip: wait 60 physics frames (refreshes offers, advances economy)

Strategy:
- quest_cycle is your primary action — it teaches vocabulary pairs over time
- discover early (first 3-5 turns) to expand your biome pool
- probe periodically to advance the quantum grid
- time_skip when offers are stale or resources are low
- The milk pair hides among vocab pairs — maximize your known pairs count
"""


def _format_game_state(
    resources: Dict[str, float],
    known_pairs: List[Dict[str, str]],
    offers: List[Dict[str, Any]],
    biomes: List[str],
    step: int,
    max_cycles: int,
) -> str:
    """Format game state as a concise string for the LLM."""
    lines = [
        f"Turn {step}/{max_cycles}",
        f"Resources: {json.dumps(resources, ensure_ascii=False)}",
        f"Known pairs ({len(known_pairs)}): {json.dumps(known_pairs[:8], ensure_ascii=False)}",
        f"Biomes discovered: {biomes if biomes else 'none yet'}",
    ]
    if offers:
        lines.append("Quest offers:")
        for i, o in enumerate(offers[:4]):
            faction = o.get("faction", "?")
            reward = o.get("reward_resources", o.get("reward", "?"))
            vocab_n = o.get("reward_vocab_north", "")
            vocab_s = o.get("reward_vocab_south", "")
            vocab_info = f" vocab={vocab_n}/{vocab_s}" if (vocab_n or vocab_s) else ""
            lines.append(f"  {i+1}. [{faction}] reward={reward}{vocab_info}")
    else:
        lines.append("No offers available (try time_skip to refresh)")
    return "\n".join(lines)


def _heuristic_decide(
    step: int,
    known_pairs: List[Dict[str, str]],
    offers: List[Dict[str, Any]],
    biomes: List[str],
    resources: Dict[str, float],
) -> str:
    """Simple heuristic policy when LLM is unavailable.

    Strategy: discover biomes early, then mostly quest_cycle (the action
    that actually earns vocab), with periodic probes and time_skips.
    """
    # Early game: discover biomes to expand vocab pool
    if step < 4 and len(biomes) < 3:
        return "discover"

    # More discovers mid-game if we have few biomes
    if step % 10 == 0 and len(biomes) < 6:
        return "discover"

    # Periodically probe
    if step % 8 == 0:
        return "probe"

    # Time skip to refresh offers when stuck
    if not offers and step > 5:
        return "time_skip"

    # Default: quest_cycle (this is how vocab pairs are learned)
    return "quest_cycle"


# Model name → claude CLI model flag
_MODEL_MAP = {
    "haiku": "haiku",
    "sonnet": "sonnet",
    "opus": "opus",
}


def _invoke_claude(prompt: str, model: str = "haiku") -> Optional[str]:
    """Invoke Claude via CLI subprocess (same pattern as HaikuRunner).

    Uses `claude -p` with CLAUDECODE stripped from env to prevent
    nested Claude Code invocations from aborting.
    """
    cli_model = _MODEL_MAP.get(model, model)
    cmd = ["claude", "-p", prompt, "--model", cli_model]

    # Strip CLAUDECODE to avoid nested-agent abort
    clean_env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}

    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30,
            env=clean_env,
        )
        if proc.returncode == 0 and proc.stdout.strip():
            return proc.stdout.strip()
        return None
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError) as e:
        print(f"  claude invoke failed: {e}", file=sys.stderr)
        return None


def _load_spacewheat_habitat() -> str:
    """Write Claura's SpaceWheat habitat packet and return it as a prompt block.

    Calls write_spacewheat_habitat_packet() which:
      1. Runs derby_probe.probe() to read current lichen quantum state
      2. Writes 🍄/🧠/🌾/context.yaml in Claura's habitat tree
      3. Returns rendered prompt text for LLM injection

    Safe to call even if Claura is unavailable — returns "" on any failure.
    """
    if not CLAURA_RIG_STATE.exists():
        return ""
    try:
        sys.path.insert(0, str(CLAURA_ROOT))
        from quantum_lichen.spacewheat_habitat import (
            write_spacewheat_habitat_packet,
            render_spacewheat_habitat_prompt,
        )
        data = write_spacewheat_habitat_packet(
            root=CLAURA_ROOT,
            rig_state_path=CLAURA_RIG_STATE,
        )
        return render_spacewheat_habitat_prompt(data, max_chars=600)
    except Exception:
        return ""


def _write_control_habitat(character: str, model: str, max_cycles: int) -> None:
    """Write a living context.yaml for the SpaceWheat control surface.

    This gives the 🍄/🎛️/ directory a habitat packet so any agent
    descending into the control surface can orient itself. Written
    once per session; updated by foldback after each game.
    """
    try:
        import yaml
    except ImportError:
        return

    packet = {
        "emoji": "🎛️🍄",
        "summary": (
            f"SpaceWheat lichen_player session: character={character} "
            f"model={model} max_cycles={max_cycles}"
        ),
        "kind": "session_context",
        "role": "control_surface_packet",
        "gate": "live",
        "for_agents": True,
        "session": {
            "character": character,
            "model": model,
            "max_cycles": max_cycles,
            "started": time.strftime("%Y-%m-%dT%H:%M:%S"),
        },
        "files": [
            "🍄/🎛️/📐_arena_parameters.yaml",
            "🍄/🎛️/session.py",
            "🍄/🎛️/lichen_player.py",
        ],
        "claura": {
            "habitat": str(_CLAURA_HABITAT_PATH),
            "rig_state": str(CLAURA_RIG_STATE),
            "foldback": "derby_probe --observe-derby",
        },
        "queries": [
            "What character is being played and what does their resource layout suggest?",
            "What is the Claura habitat recommending for this domain?",
            "Which actions have strong pheromone signal right now?",
        ],
    }
    try:
        _CONTROL_HABITAT_PATH.write_text(
            yaml.safe_dump(packet, allow_unicode=True, default_flow_style=False, sort_keys=False),
            encoding="utf-8",
        )
    except Exception:
        pass


def _llm_decide(
    game_state_text: str,
    model: str = "haiku",
    *,
    habitat_context: str = "",
    step: int = 0,
    known_pairs: Optional[List[Dict[str, str]]] = None,
    offers: Optional[List[Dict[str, Any]]] = None,
    biomes: Optional[List[str]] = None,
    resources: Optional[Dict[str, float]] = None,
) -> str:
    """Ask Claude to pick an action via CLI. Falls back to heuristic."""
    habitat_block = f"\n\n--- Claura habitat signal ---\n{habitat_context}\n" if habitat_context else ""
    full_prompt = f"{SYSTEM_PROMPT}{habitat_block}\n\n---\n\n{game_state_text}"
    text = _invoke_claude(full_prompt, model=model)

    if text is None:
        return _heuristic_decide(
            step, known_pairs or [], offers or [], biomes or [],
            resources or {},
        )

    # Parse JSON response (claude -p may wrap in ```json ... ```)
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("```"):
            continue
        if line.startswith("{"):
            try:
                parsed = json.loads(line)
                action = str(parsed.get("action", ""))
                if action in ("quest_cycle", "probe", "discover", "time_skip"):
                    return action
            except json.JSONDecodeError:
                pass

    # Fallback: look for action name in freetext
    lower = text.lower()
    for action in ("quest_cycle", "probe", "discover", "time_skip"):
        if action in lower:
            return action

    return _heuristic_decide(
        step, known_pairs or [], offers or [], biomes or [],
        resources or {},
    )


# ---------------------------------------------------------------------------
# Claura foldback: observe→project→deposit
# ---------------------------------------------------------------------------

def _foldback_to_claura(
    result: Dict[str, Any],
    identity: str,
    model: str,
    verbose: bool = True,
) -> None:
    """Fold game results back into Claura's quantum learning system.

    Uses derby_probe --observe-result to feed through:
      DerbyFiber → ContextTendril.observe_trial() → LaneTendril.observe_derby_result()
      → Lindblad evolution → pheromone foldback → Hamiltonian bias
    """
    if not CLAURA_RIG_STATE.exists():
        if verbose:
            print("  (no Claura rig state — foldback skipped)")
        return

    # Build a summary envelope compatible with derby_probe.observe_derby()
    # lane_scores must be a dict keyed by lane_id
    lane_id = f"lichen_{model}"
    envelope = {
        "source": "lichen_player",
        "character": identity,
        "lane": lane_id,
        "found_milk": result.get("found_milk", False),
        "cycles": result.get("cycles", 0),
        "steps": result.get("steps", 0),
        "biomes_found": len(result.get("biomes", [])),
        "vocab": result.get("vocab", 0),
        "composite": result.get("composite", 0.0),
        "total_elapsed_s": result.get("elapsed_s", 0.0),
        "lane_scores": {
            lane_id: {
                "composite": result.get("composite", 0.0),
                "milk_count": 1 if result.get("found_milk") else 0,
                "hunters": 1,
            },
        },
    }

    # Write temporary summary file
    summary_path = Path("/tmp") / f"lichen_player_{int(time.time())}.json"
    summary_path.write_text(json.dumps(envelope, ensure_ascii=False, indent=2))

    try:
        cmd = [
            sys.executable, "-m", "quantum_lichen.derby_probe",
            "--observe-derby", str(summary_path),
            "--rig-state", str(CLAURA_RIG_STATE),
            "--save",
        ]
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30,
            cwd=str(CLAURA_ROOT),
            env={**os.environ, "PYTHONPATH": str(CLAURA_ROOT)},
        )
        if verbose:
            if proc.returncode == 0:
                print("  🍄 Claura foldback: tendrils updated")
            else:
                print(f"  Claura foldback failed (rc={proc.returncode}): {proc.stderr[:200]}")
    except Exception as e:
        if verbose:
            print(f"  Claura foldback error: {e}")
    finally:
        try:
            summary_path.unlink(missing_ok=True)
        except Exception:
            pass


# ---------------------------------------------------------------------------
# Main game loop (observe → project → deposit)
# ---------------------------------------------------------------------------

def play(
    *,
    profile: str = "",
    character: str = "",
    max_cycles: int = 40,
    model: str = "haiku",
    verbose: bool = True,
) -> Dict[str, Any]:
    """Play SpaceWheat with an LLM making per-turn decisions.

    Each turn follows the universal loop:
      OBSERVE: read game state (resources, vocab, offers, biomes)
      PROJECT: LLM/heuristic picks action from state
      DEPOSIT: execute action on game rig
    """
    identity = character or profile
    if verbose:
        print(f"\n  🍄 Lichen Player: {identity} x {max_cycles} cycles")
        print(f"  Model: {model}")
        print()

    # ── HABITAT: write habitat packets and load Claura signal ──
    # 1. SpaceWheat control surface: 🍄/🎛️/context.yaml
    _write_control_habitat(identity, model, max_cycles)
    # 2. Claura SpaceWheat habitat: 🍄/🧠/🌾/context.yaml + rendered prompt text
    habitat_context = _load_spacewheat_habitat()
    if verbose and habitat_context:
        print(f"  Claura habitat: {len(habitat_context)} chars loaded")

    with RunSession(
        profile=profile,
        character=character,
        slot=3,  # dedicated slot for lichen player
    ) as s:
        biomes_seen: List[str] = []
        probe_count = 0
        discover_count = 0
        prev_pair_count = 0

        for step in range(max_cycles):
            if s.found_milk:
                break

            # ── OBSERVE: read game state ──
            try:
                resources = s.resources()
                known_pairs = s.known_vocab()
                # Track vocab milestones by pair count delta
                if len(known_pairs) > prev_pair_count:
                    s._vocab_milestones += len(known_pairs) - prev_pair_count
                    prev_pair_count = len(known_pairs)
                offers = s.offer()
            except Exception as e:
                if verbose:
                    print(f"  [{step}] State read failed: {e}")
                break

            # ── PROJECT: LLM/heuristic picks action ──
            state_text = _format_game_state(
                resources, known_pairs, offers,
                biomes_seen, step, max_cycles,
            )
            action = _llm_decide(
                state_text, model=model,
                habitat_context=habitat_context,
                step=step, known_pairs=known_pairs, offers=offers,
                biomes=biomes_seen, resources=resources,
            )

            # ── DEPOSIT: execute action on game rig ──
            try:
                if action == "quest_cycle":
                    result = s.play_cycle()
                    if verbose:
                        milk = " 🍼 MILK!" if s.found_milk else ""
                        print(f"  [{step:3d}] quest_cycle{milk}")

                elif action == "probe":
                    result = s.probe()
                    probe_count += 1
                    if verbose:
                        print(f"  [{step:3d}] probe")

                elif action == "discover":
                    # Discover gives random biomes; name doesn't matter
                    result = s.discover("x")
                    actual = result.get("discover_biome", {}).get("biome_name", "")
                    if result.get("ok") and actual:
                        if actual not in biomes_seen:
                            biomes_seen.append(actual)
                        discover_count += 1
                        if verbose:
                            print(f"  [{step:3d}] discover → {actual}")
                    else:
                        if verbose:
                            print(f"  [{step:3d}] discover ✗")
                        result = s.play_cycle()

                elif action == "time_skip":
                    result = s.time_skip(60)
                    if verbose:
                        print(f"  [{step:3d}] time_skip")

                else:
                    result = s.play_cycle()
                    if verbose:
                        print(f"  [{step:3d}] quest_cycle (unknown: {action})")

            except Exception as e:
                if verbose:
                    print(f"  [{step:3d}] action failed: {e}")
                try:
                    s.time_skip(30)
                except Exception:
                    break

        # Final observation
        try:
            final_pairs = s.known_vocab()
            if len(final_pairs) > prev_pair_count:
                s._vocab_milestones += len(final_pairs) - prev_pair_count
        except Exception:
            final_pairs = s._known_pairs

        elapsed = time.time() - s._t_start
        found = s.found_milk

        if verbose:
            print()
            status = "🍼 MILK FOUND!" if found else "No milk"
            print(f"  Result: {status}")
            print(f"  cycles={s._cycles}  steps={s._steps}  "
                  f"biomes={len(biomes_seen)}  vocab={s._vocab_milestones}  "
                  f"pairs={len(final_pairs)}  elapsed={elapsed:.1f}s")
            print(f"  probes={probe_count}  discovers={discover_count}")

        # Record to leaderboard
        from schema import RunnerResult
        rr = RunnerResult(
            profile=identity,
            lane=f"lichen_{model}",
            found_milk=found,
            steps=s._steps,
            cycles=s._cycles,
            biomes_found=len(biomes_seen),
            biomes=biomes_seen,
            vocab=s._vocab_milestones,
            elapsed_s=elapsed,
            slot=s.slot,
        )
        entry = record_result(
            character=identity,
            lane=rr.lane,
            layer="lichen_player",
            found_milk=found,
            cycles=s._cycles,
            steps=s._steps,
            biomes_found=len(biomes_seen),
            vocab=s._vocab_milestones,
            elapsed_s=round(elapsed, 2),
            composite=rr.composite(),
            success_rate=rr.success_rate,
            speed_score=rr.speed_score,
            biome_score=rr.biome_score,
            vocab_score=rr.vocab_score,
            extra={"model": model, "probes": probe_count, "discovers": discover_count},
        )

        game_result = {
            "found_milk": found,
            "steps": s._steps,
            "cycles": s._cycles,
            "biomes": biomes_seen,
            "vocab": s._vocab_milestones,
            "pairs": len(final_pairs),
            "composite": rr.composite(),
            "elapsed_s": round(elapsed, 2),
            "leaderboard_entry": entry,
        }

        if verbose:
            print(f"  composite={rr.composite():.4f}")
            print(f"  ⭐ Leaderboard updated")

        # ── FOLDBACK: feed results into Claura's quantum learning ──
        _foldback_to_claura(game_result, identity, model, verbose=verbose)

        return game_result


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Lichen Player: Claude Code sub-agent plays SpaceWheat",
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--profile", help="World-state profile name")
    group.add_argument("--character", help="Character spec name")
    parser.add_argument("--max-cycles", type=int, default=40)
    parser.add_argument("--model", default="haiku",
                        help="Claude model: haiku, sonnet, opus")
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    result = play(
        profile=args.profile or "",
        character=args.character or "",
        max_cycles=args.max_cycles,
        model=args.model,
        verbose=not args.quiet,
    )
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["found_milk"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
