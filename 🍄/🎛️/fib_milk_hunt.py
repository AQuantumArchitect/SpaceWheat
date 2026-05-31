#!/usr/bin/env python3
"""Fibonacci-escalating milk hunt — single-process orchestrator.

Boots ONE Godot instance and runs all characters through it via save/load IPC.
No subprocess spawning per character. One boot, many runs.

Schedule: [8, 13, 21, 34, 55] loops per round.
Each character gets a persistent save file (absolute path).
Stops when 4/5 characters find milk.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))

from milk_hunt_characters import get_character, resolve_character_world_state, resolve_character_policy
from rig_client import RigClient
from milk_hunt_paths import xdg_root

OUTPUT_ROOT = Path("/tmp/fib_milk_hunt")
SAVE_DIR = OUTPUT_ROOT / "saves"
# PPG priors persist in the repo (survives /tmp wipes from reboots)
PPG_PRIOR_DIR = Path(__file__).resolve().parent / "ppg_priors"

CHARACTERS = [
    "pioneer_fib",
    "cold_front_fib",
    "solar_engine_fib",
    "market_broker_fib",
    "spore_drifter_fib",
    "debt_rebel_fib",
]

FIB_SCHEDULE = [8, 13, 21, 34, 55]
MILK_TARGET = 4
POLICY = "quantum_register"

EXTRA_ENV = {
    "RIG_QUEUE_POLL_MS": "16",
    "RIG_LOG_PROFILE": "quiet",
    "RIG_POLICY_TYPE": "quantum_register",
    "RIG_POLICY_EXECUTION_BACKEND": "direct",
}


def _safe_print(msg: str) -> None:
    print(msg, flush=True)


# ── PPG Persistence ────────────────────────────────────────────────
# After each run, extract PPG density matrix + rates from the character's
# save (via policy_debug_snapshot IPC) and store as JSON.  On next seed,
# inject the stored prior so ρ starts where the last run left off.

def _ppg_prior_path(name: str) -> Path:
    PPG_PRIOR_DIR.mkdir(parents=True, exist_ok=True)
    return PPG_PRIOR_DIR / f"{name}.json"


def save_ppg_prior(client: RigClient, turn: int, name: str) -> int:
    """Extract PPG state from currently loaded character and persist it."""
    result = client.run_turn(turn, "export_policy_state", timeout_s=10.0)
    turn += 1
    if not result.get("ok", False):
        return turn  # no PPG or error

    ppg = result.get("ppg_state", {})
    if not ppg or ppg.get("step_count", 0) == 0:
        return turn  # nothing learned yet

    prior_path = _ppg_prior_path(name)
    prior_path.write_text(
        json.dumps(ppg, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    _safe_print(f"  [ppg] saved prior for {name} (steps={ppg.get('step_count', 0)})")
    return turn


def load_ppg_prior(name: str) -> Optional[Dict]:
    """Load persisted PPG prior if it exists."""
    prior_path = _ppg_prior_path(name)
    if not prior_path.exists():
        return None
    try:
        data = json.loads(prior_path.read_text(encoding="utf-8"))
        if isinstance(data, dict) and data.get("step_count", 0) > 0:
            return data
    except (json.JSONDecodeError, OSError):
        pass
    return None


def inject_ppg_prior(client: RigClient, turn: int, name: str) -> int:
    """If a PPG prior exists, inject it into the currently loaded game state."""
    prior = load_ppg_prior(name)
    if prior is None:
        return turn

    step_count = prior.get("step_count", 0)
    _safe_print(f"  [ppg] loading prior for {name} (steps={step_count})")

    # Use policy_debug_snapshot to verify policy is loaded, then
    # inject PPG state via set_policy_state IPC action
    result = client.run_turn(
        turn, "set_policy_state", timeout_s=10.0,
        ppg_state=prior,
    )
    turn += 1
    if result.get("ok", False):
        _safe_print(f"  [ppg] prior injected OK")
    else:
        _safe_print(f"  [ppg] prior injection failed: {result.get('error', '?')}")
    return turn


def _save_path(name: str) -> str:
    SAVE_DIR.mkdir(parents=True, exist_ok=True)
    return str(SAVE_DIR / f"{name}.tres")


def _boot_godot(client: RigClient, xdg: Path) -> Optional[Any]:
    """Boot a fresh Godot instance. Returns proc or None on failure."""
    client.clear_rig_files(preserve_live_sentinel=False)
    proc = client.start_listener(
        display_mode="headless",
        listener_stdout="null",
        rig_log_profile="quiet",
        extra_env=EXTRA_ENV,
    )
    boot_lines = RigClient.wait_for_ready(proc, timeout_s=60.0, xdg=xdg)
    if proc.poll() is not None:
        _safe_print("  [boot] Godot died during boot")
        return None
    if not RigClient.ready_seen(boot_lines):
        _safe_print("  [boot] Godot did not reach ready state")
        proc.terminate()
        return None
    return proc


def _ensure_godot(
    client: RigClient, proc: Any, xdg: Path, turn: int
) -> tuple[Any, int]:
    """Return (proc, turn) with a guaranteed-alive Godot. Restarts if hung/dead."""
    if proc.poll() is None:
        ping = client.run_turn(turn, "ping", timeout_s=4.0)
        turn += 1
        if ping.get("pong"):
            return proc, turn
        _safe_print("  [godot] ping failed — restarting...")
        RigClient.terminate_listener(proc)
    else:
        _safe_print("  [godot] process dead — restarting...")

    new_proc = _boot_godot(client, xdg)
    if new_proc is None:
        raise RuntimeError("Godot restart failed")
    ping = client.run_turn(turn, "ping", timeout_s=5.0)
    turn += 1
    if not ping.get("pong"):
        raise RuntimeError("Godot post-restart ping failed")
    _safe_print(f"  [godot] restarted OK (turn={turn})")
    return new_proc, turn


def seed_character(client: RigClient, turn: int, name: str) -> int:
    """Seed a character via IPC: configure_seed_state + save_game_path."""
    character = get_character(name)
    world = resolve_character_world_state(character)
    policy_cfg = resolve_character_policy(character, POLICY)

    # Build seed payload
    seed_payload: Dict[str, Any] = {
        "known_icons": world.get("known_icons", []),
        "unlocked_biomes": world.get("unlocked_biomes", ["StarterForest", "Village"]),
        "unexplored_biomes": world.get("unexplored_biomes", []),
        "active_biome": world.get("active_biome", "Village"),
        "resources": world.get("resources", {}),
        "strict_biome_economy": world.get("strict_biome_economy", True),
    }
    if policy_cfg.get("policy_graph_path"):
        seed_payload["policy_graph_path"] = policy_cfg["policy_graph_path"]
    if policy_cfg.get("policy_graph_jsonl"):
        seed_payload["policy_graph_jsonl"] = policy_cfg["policy_graph_jsonl"]

    result = client.run_turn(turn, "configure_seed_state", timeout_s=30.0, **seed_payload)
    turn += 1
    if not result.get("ok", False):
        _safe_print(f"  [seed] {name}: configure_seed_state FAILED: {result.get('error', '?')}")
        return turn

    # Set starting resources (configure_seed_state doesn't handle resources)
    resources = world.get("resources", {})
    for emoji, amount in resources.items():
        client.run_turn(turn, "set_resource", timeout_s=5.0, emoji=emoji, amount=int(amount))
        turn += 1

    # Inject PPG prior from previous runs (if any)
    turn = inject_ppg_prior(client, turn, name)

    # Save to absolute path
    save = _save_path(name)
    result = client.run_turn(turn, "save_game_path", timeout_s=30.0, path=save)
    turn += 1
    ok = result.get("ok", False) and result.get("saved", False)
    _safe_print(f"  [seed] {name} → {save} ({'OK' if ok else 'FAILED'})")
    return turn


def run_character_round(
    client: RigClient,
    turn: int,
    name: str,
    max_loops: int,
    policy_actions_per_loop: int = 6,
) -> tuple[int, Dict[str, Any]]:
    """Load character save, run quest_cycle_step loops, save back."""
    save = _save_path(name)

    # Load from save
    result = client.run_turn(turn, "load_game_path", timeout_s=30.0, path=save)
    turn += 1
    if not result.get("loaded", False):
        _safe_print(f"  [{name}] load FAILED: {result.get('error', '?')}")
        return turn, {"ok": False, "error": "load_failed", "loops": 0, "icons": 0}

    # Apply policy graph
    character = get_character(name)
    policy_cfg = resolve_character_policy(character, POLICY)
    if policy_cfg.get("policy_graph_path"):
        client.run_turn(turn, "policy_graph_read", timeout_s=10.0, path=policy_cfg["policy_graph_path"])
        turn += 1
    if policy_cfg.get("policy_graph_jsonl"):
        client.run_turn(turn, "policy_graph_patch", timeout_s=10.0, lines=policy_cfg["policy_graph_jsonl"])
        turn += 1

    # Take initial snapshot
    snap = client.run_turn(turn, "policy_snapshot", timeout_s=10.0)
    turn += 1
    snap_data = snap.get("policy_snapshot", snap)
    initial_icons = len(snap_data.get("known_icons", []))

    # Run policy loops
    found_milk = False
    loops_completed = 0
    steps = 0
    world = resolve_character_world_state(character)
    strict = world.get("strict_biome_economy", True)

    resource_floors = {}
    if strict:
        resources = world.get("resources", {})
        # Use top-3 resources as floors (Fibonacci starting resources)
        sorted_res = sorted(resources.items(), key=lambda x: -x[1])[:3]
        resource_floors = {e: a for e, a in sorted_res}

    for loop_idx in range(max_loops):
        for step_idx in range(policy_actions_per_loop):
            result = client.run_turn(
                turn, "quest_cycle_step",
                timeout_s=300.0,
                execute=True,
                include_state=True,
                resource_floors=resource_floors,
                execution_backend="direct",
            )
            turn += 1
            steps += 1

            if not result.get("ok", False):
                continue

            # Check for milk via quest_cycle_step's pre-computed contains_milk_pair flag.
            # post_state is nested under result["quest_cycle_step"], NOT at top level.
            quest_cycle_step_data = result.get("quest_cycle_step", {})
            if quest_cycle_step_data.get("contains_milk_pair"):
                found_milk = True

            if found_milk:
                break
        loops_completed += 1
        if found_milk:
            break

    # Final snapshot for icon count
    final_snap = client.run_turn(turn, "policy_snapshot", timeout_s=10.0)
    turn += 1
    final_snap_data = final_snap.get("policy_snapshot", final_snap)
    final_icons = len(final_snap_data.get("known_icons", []))

    # Extract and persist PPG state before saving
    turn = save_ppg_prior(client, turn, name)

    # Save state back
    result = client.run_turn(turn, "save_game_path", timeout_s=30.0, path=save)
    turn += 1

    return turn, {
        "ok": True,
        "found_milk": found_milk,
        "loops": loops_completed,
        "icons": final_icons,
        "icons_learned": final_icons - initial_icons,
        "steps": steps,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Fibonacci milk hunt (single-process)")
    parser.add_argument("--skip-characters", nargs="*", default=[], help="Characters that already found milk")
    parser.add_argument("--start-round", type=int, default=1, help="1-indexed round to start from")
    args = parser.parse_args()

    ts = time.strftime("%Y%m%d_%H%M%S")
    output_dir = OUTPUT_ROOT / f"run_{ts}"
    output_dir.mkdir(parents=True, exist_ok=True)
    SAVE_DIR.mkdir(parents=True, exist_ok=True)

    _safe_print("=" * 72)
    _safe_print("  FIBONACCI MILK HUNT (single-process orchestrator)")
    _safe_print(f"  characters: {', '.join(CHARACTERS)}")
    _safe_print(f"  schedule: {FIB_SCHEDULE}")
    _safe_print(f"  policy: {POLICY}")
    _safe_print(f"  target: {MILK_TARGET}/{len(CHARACTERS)} milk")
    _safe_print(f"  saves: {SAVE_DIR}")
    _safe_print("=" * 72)

    # Boot one Godot instance
    _safe_print("\n--- BOOTING GODOT ---")
    xdg = xdg_root()
    client = RigClient(xdg=xdg)
    proc = _boot_godot(client, xdg)
    if proc is None:
        _safe_print("FATAL: Godot boot failed")
        return 1
    _safe_print("  Godot booted OK")

    turn = 1

    # Ping
    ping = client.run_turn(turn, "ping", timeout_s=5.0)
    turn += 1
    if not ping.get("pong"):
        _safe_print("FATAL: ping failed")
        RigClient.terminate_listener(proc)
        return 1
    _safe_print(f"  ping OK (uptime={ping.get('uptime_ms', '?')}ms)")

    # Seed all characters (if saves don't exist)
    needs_seed = [n for n in CHARACTERS if not Path(_save_path(n)).exists()]
    if needs_seed:
        _safe_print(f"\n--- SEEDING {len(needs_seed)} CHARACTERS ---")
        for name in needs_seed:
            turn = seed_character(client, turn, name)
    else:
        _safe_print(f"\n--- ALL SAVES EXIST (skipping seed) ---")

    # Fibonacci escalation
    milk_found: Dict[str, bool] = {name: False for name in CHARACTERS}
    for skip in (args.skip_characters or []):
        if skip in milk_found:
            milk_found[skip] = True
    cumulative_loops: Dict[str, int] = {name: 0 for name in CHARACTERS}
    cumulative_icons: Dict[str, int] = {name: 0 for name in CHARACTERS}
    cumulative_time: Dict[str, float] = {name: 0.0 for name in CHARACTERS}
    start_round_idx = max(0, args.start_round - 1)

    total_start = time.time()

    for round_idx, fib_loops in enumerate(FIB_SCHEDULE):
        if round_idx < start_round_idx:
            continue

        milk_count = sum(1 for v in milk_found.values() if v)
        if milk_count >= MILK_TARGET:
            break

        remaining = [name for name in CHARACTERS if not milk_found[name]]
        _safe_print(f"\n{'=' * 72}")
        _safe_print(f"  ROUND {round_idx + 1}: {fib_loops} loops")
        _safe_print(f"  milk so far: {milk_count}/{len(CHARACTERS)}")
        _safe_print(f"  running: {', '.join(remaining)}")
        _safe_print("=" * 72)

        for name in remaining:
            t0 = time.time()
            _safe_print(f"\n  [{name}] running {fib_loops} loops...")

            # Ensure Godot is alive (restart if needed)
            try:
                proc, turn = _ensure_godot(client, proc, xdg, turn)
            except RuntimeError as e:
                _safe_print(f"  [{name}] FATAL: {e}")
                RigClient.terminate_listener(proc)
                return 1

            turn, result = run_character_round(client, turn, name, fib_loops)
            elapsed = time.time() - t0

            cumulative_loops[name] += result.get("loops", 0)
            cumulative_icons[name] = max(cumulative_icons[name], result.get("icons", 0))
            cumulative_time[name] += elapsed

            if result.get("found_milk"):
                milk_found[name] = True
                _safe_print(
                    f"  [{name}] MILK! loops={result['loops']} icons={result['icons']} "
                    f"time={elapsed:.0f}s (cumulative: {cumulative_loops[name]} loops)"
                )
            elif not result.get("ok"):
                _safe_print(
                    f"  [{name}] ERROR: {result.get('error', '?')} "
                    f"loops={result.get('loops', 0)} time={elapsed:.0f}s"
                )
            else:
                _safe_print(
                    f"  [{name}] no milk  loops={result['loops']} icons={result['icons']} "
                    f"(+{result.get('icons_learned', 0)}) time={elapsed:.0f}s"
                )

    # Cleanup
    RigClient.terminate_listener(proc)
    total_elapsed = time.time() - total_start
    milk_count = sum(1 for v in milk_found.values() if v)

    _safe_print(f"\n{'=' * 72}")
    _safe_print("  FIBONACCI MILK HUNT — FINAL SCORECARD")
    _safe_print("=" * 72)
    _safe_print(f"\n {'Name':<30} {'Milk':<5} {'Loops':>6} {'Icons':>6} {'Time':>8}")
    _safe_print("  " + "-" * 58)
    for name in CHARACTERS:
        milk_str = "YES" if milk_found[name] else "no"
        _safe_print(
            f"  {name:<30} {milk_str:<5} {cumulative_loops[name]:>6} "
            f"{cumulative_icons[name]:>6} {cumulative_time[name]:>7.0f}s"
        )
    _safe_print("  " + "-" * 58)
    _safe_print(f"  Result: {milk_count}/{len(CHARACTERS)} milk in {total_elapsed:.0f}s total")
    _safe_print(f"  Target: {MILK_TARGET}/{len(CHARACTERS)} — {'ACHIEVED' if milk_count >= MILK_TARGET else 'NOT REACHED'}")

    # Save report
    report = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "policy": POLICY,
        "fib_schedule": FIB_SCHEDULE,
        "milk_target": MILK_TARGET,
        "milk_count": milk_count,
        "target_achieved": milk_count >= MILK_TARGET,
        "total_elapsed_s": round(total_elapsed, 1),
        "characters": {
            name: {
                "found_milk": milk_found[name],
                "cumulative_loops": cumulative_loops[name],
                "cumulative_icons": cumulative_icons[name],
                "cumulative_time_s": round(cumulative_time[name], 1),
            }
            for name in CHARACTERS
        },
    }
    report_path = output_dir / "fib_hunt_report.json"
    report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    _safe_print(f"\n  Report: {report_path}")

    return 0 if milk_count >= MILK_TARGET else 1


if __name__ == "__main__":
    raise SystemExit(main())
