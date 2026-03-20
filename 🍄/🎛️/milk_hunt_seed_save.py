#!/usr/bin/env python3
import argparse
import json
import sys
from typing import Any, Dict, List, Optional

from milk_hunt_characters import get_character, resolve_character_seed
from milk_hunt_profiles import get_profile, list_profiles
from policy_graph_runtime import profile_graph_path
from milk_hunt_world_state import load_world_state
from rig_client import RigClient


def _parse_resource_pairs(values: List[str]) -> Dict[str, int]:
    out: Dict[str, int] = {}
    for raw in values:
        if ":" not in raw:
            raise ValueError(f"invalid resource format '{raw}', expected EMOJI:AMOUNT")
        emoji, amount_raw = raw.split(":", 1)
        emoji = emoji.strip()
        amount = int(amount_raw.strip())
        if not emoji:
            raise ValueError(f"invalid resource emoji in '{raw}'")
        out[emoji] = out.get(emoji, 0) + amount
    return out


def _parse_known_pairs(values: List[str]) -> List[Dict[str, str]]:
    out: List[Dict[str, str]] = []
    for raw in values:
        if ":" not in raw:
            raise ValueError(f"invalid known pair '{raw}', expected NORTH:SOUTH")
        north, south = raw.split(":", 1)
        north = north.strip()
        south = south.strip()
        if not north or not south or north == south:
            raise ValueError(f"invalid known pair '{raw}'")
        out.append({"north": north, "south": south})
    return out


def _merge_known_pairs(base: List[Dict[str, str]], extra: List[Dict[str, str]]) -> List[Dict[str, str]]:
    merged: List[Dict[str, str]] = []
    seen: set[str] = set()
    for pair in base + extra:
        north = str(pair.get("north", ""))
        south = str(pair.get("south", ""))
        if not north or not south or north == south:
            continue
        key = f"{north}|{south}"
        if key in seen:
            continue
        seen.add(key)
        merged.append({"north": north, "south": south})
    return merged


def _select_resource_mode(args_resource_mode: Optional[str], profile: Optional[Dict[str, Any]]) -> str:
    if args_resource_mode in {"add", "set"}:
        return args_resource_mode
    if profile:
        return str(profile.get("resource_mode", "set"))
    return "add"


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Create a starter save slot for milk-hunt testing")
    parser.add_argument("--slot", type=int, required=True, help="Save slot index (0-2)")
    parser.add_argument("--character", type=str, default=None, help="Higher-order character name/path")
    parser.add_argument("--profile", type=str, default=None, help="Starter profile name")
    parser.add_argument("--world-state", type=str, default=None, help="World state JSON path (alternative to --profile)")
    parser.add_argument(
        "--policy-mode",
        choices=["engine_policy", "quantum_register"],
        default="engine_policy",
        help="Policy mode used when resolving a character's policy graph",
    )
    parser.add_argument(
        "--policy-graph-path",
        type=str,
        default=None,
        help="Explicit policy graph path to store in the seeded save",
    )
    parser.add_argument(
        "--policy-graph-line",
        action="append",
        default=[],
        help="Extra JSONL policy graph patch line (repeatable)",
    )
    parser.add_argument(
        "--display-mode",
        choices=["headless", "headed"],
        default="headless",
        help="Launch the seeding rig headless or with a visible window",
    )
    parser.add_argument(
        "--ready-timeout",
        type=float,
        default=None,
        help="Seconds to wait for the rig bridge to become ready",
    )
    parser.add_argument("--list-profiles", action="store_true", help="List available profiles and exit")
    parser.add_argument("--load-slot", type=int, default=None, help="Optional existing slot to load before seeding")
    parser.add_argument("--scenario-id", type=str, default=None, help="Scenario id when not loading a slot")
    parser.add_argument(
        "--resource-mode",
        choices=["add", "set"],
        default=None,
        help="How to apply --resource amounts: add to current or set exact value",
    )
    parser.add_argument(
        "--resource",
        action="append",
        default=[],
        help="Starter resource grant in EMOJI:AMOUNT format (repeatable)",
    )
    parser.add_argument(
        "--unlock-biome",
        action="append",
        default=[],
        help="Biome to unlock in seeded save (repeatable)",
    )
    parser.add_argument(
        "--unexplored-biome",
        action="append",
        default=[],
        help="Explicit unexplored biome pool entry (repeatable)",
    )
    parser.add_argument("--active-biome", type=str, default=None, help="Active biome to select before saving")
    parser.add_argument(
        "--save-path",
        type=str,
        default=None,
        help="Optional explicit save path (e.g. user://saves/profiles/granary_scout.tres)",
    )
    parser.add_argument(
        "--known-pair",
        action="append",
        default=[],
        help="Known vocabulary pair in NORTH:SOUTH format (repeatable)",
    )
    parser.add_argument("--reuse-listener", action="store_true",
        help="Reuse an existing listener (phrame bridge or headless) instead of starting a new one")
    return parser


def main() -> int:
    rig = RigClient(root_from_file=__file__)
    run_turn = rig.run_turn
    safe_print = rig.safe_print
    args = _build_parser().parse_args()
    if args.list_profiles:
        safe_print("seed-save: available profiles")
        rows = []
        for profile in list_profiles():
            rows.append(
                {
                    "name": profile["name"],
                    "description": profile.get("description", ""),
                    "scenario_id": profile.get("scenario_id", "default"),
                    "active_biome": profile.get("active_biome", ""),
                    "unlocked_biomes": profile.get("unlocked_biomes", []),
                    "resource_mode": profile.get("resource_mode", "set"),
                    "strict_biome_economy": profile.get("strict_biome_economy", False),
                }
            )
        safe_print(json.dumps(rows, ensure_ascii=False, indent=2))
        return 0

    world_state: Optional[Dict[str, Any]] = None
    character: Optional[Dict[str, Any]] = None
    character_policy: Dict[str, Any] = {}
    if args.character:
        try:
            character = get_character(args.character)
        except ValueError as exc:
            safe_print(f"seed-save: {exc}")
            return 2
        world_state, character_policy = resolve_character_seed(character, args.policy_mode)

    if args.world_state:
        world_state = load_world_state(args.world_state)
        if not world_state:
            safe_print(f"seed-save: failed to load world state from '{args.world_state}'")
            return 2

    profile: Optional[Dict[str, Any]] = None
    if world_state:
        profile = world_state
    elif args.profile:
        try:
            profile = get_profile(args.profile)
        except ValueError as exc:
            safe_print(f"seed-save: {exc}")
            return 2

    try:
        extra_resources = _parse_resource_pairs(args.resource)
        extra_pairs = _parse_known_pairs(args.known_pair)
    except ValueError as exc:
        safe_print(f"seed-save: {exc}")
        return 2

    resource_map: Dict[str, int] = {}
    if profile:
        resource_map.update({str(k): int(v) for k, v in profile.get("resources", {}).items()})
    for emoji, amount in extra_resources.items():
        resource_map[emoji] = amount

    known_pairs: List[Dict[str, str]] = []
    if profile:
        known_pairs = _merge_known_pairs(known_pairs, profile.get("known_pairs", []))
    known_pairs = _merge_known_pairs(known_pairs, extra_pairs)

    unlocked_biomes: List[str] = []
    if profile:
        unlocked_biomes = [str(x) for x in profile.get("unlocked_biomes", []) if str(x)]
    if args.unlock_biome:
        unlocked_biomes = [str(x) for x in args.unlock_biome if str(x)]

    unexplored_biomes: List[str] = []
    if profile:
        unexplored_biomes = [str(x) for x in profile.get("unexplored_biomes", []) if str(x)]
    if args.unexplored_biome:
        unexplored_biomes = [str(x) for x in args.unexplored_biome if str(x)]

    active_biome = args.active_biome
    if active_biome is None and profile:
        active_biome = str(profile.get("active_biome", "") or "")

    policy_graph_path_value = ""
    policy_graph_jsonl_value: List[str] = []
    if character_policy:
        policy_graph_path_value = str(character_policy.get("policy_graph_path", "") or "")
        policy_graph_jsonl_value = [str(x) for x in character_policy.get("policy_graph_jsonl", []) if str(x).strip()]
    elif profile:
        profile_name = str(profile.get("name", "") or args.profile or "")
        if profile_name:
            policy_graph_path_value = str(profile_graph_path(profile_name, "ucb"))
    if args.policy_graph_path:
        policy_graph_path_value = str(args.policy_graph_path)
    if args.policy_graph_line:
        policy_graph_jsonl_value.extend(str(x) for x in args.policy_graph_line if str(x).strip())

    scenario_id = args.scenario_id
    if scenario_id is None:
        scenario_id = str(profile.get("scenario_id", "default")) if profile else "default"

    resource_mode = _select_resource_mode(args.resource_mode, profile)

    if args.reuse_listener and RigClient.find_listener_pids():
        safe_print("seed-save: phrame bridge detected — visual mode")
        if RigClient._bridge_sentinel_path().exists():
            safe_print("seed-save: bridge active, sending seed actions directly")
        rig.clear_rig_files()  # sentinel-safe — only clears queue + results
        proc = None
    else:
        safe_print("seed-save: resetting rig cache and starting listener")
        rig.kill_existing_listeners()
        rig.clear_rig_files()
        proc = rig.start_listener(
            load_slot=args.load_slot,
            scenario_id=scenario_id,
            display_mode=str(args.display_mode or "headless"),
        )
        ready_timeout = float(args.ready_timeout) if args.ready_timeout is not None else (180.0 if args.display_mode == "headed" else 70.0)
        boot_lines = rig.wait_for_ready(proc, timeout_s=ready_timeout)
        ready = RigClient.ready_seen(boot_lines)
        if proc.poll() is not None or not ready:
            safe_print("seed-save: listener failed to reach ready state")
            for line in boot_lines[-20:]:
                safe_print(line)
            return 1

    turn = 1
    history: List[dict] = []
    try:
        snapshot = run_turn(turn, "resource_snapshot")
        history.append(snapshot)
        turn += 1
        if unlocked_biomes or unexplored_biomes or known_pairs or active_biome or policy_graph_path_value or policy_graph_jsonl_value:
            payload: Dict[str, Any] = {}
            if unlocked_biomes:
                payload["unlocked_biomes"] = unlocked_biomes
            if unexplored_biomes:
                payload["unexplored_biomes"] = unexplored_biomes
            if known_pairs:
                payload["known_pairs"] = known_pairs
            if active_biome:
                payload["active_biome"] = active_biome
            if policy_graph_path_value:
                payload["policy_graph_path"] = policy_graph_path_value
            if policy_graph_jsonl_value:
                payload["policy_graph_jsonl"] = policy_graph_jsonl_value
            history.append(run_turn(turn, "configure_seed_state", **payload))
            turn += 1

        if resource_mode == "add":
            for emoji, amount in resource_map.items():
                history.append(run_turn(turn, "add_resource", emoji=emoji, amount=amount))
                turn += 1
        else:
            for emoji, amount in resource_map.items():
                history.append(run_turn(turn, "set_resource", emoji=emoji, amount=amount))
                turn += 1

        economy_overrides = {}
        if world_state:
            economy_overrides = world_state.get("economy_overrides", {})
            if not isinstance(economy_overrides, dict):
                economy_overrides = {}
        economy_configure_result = None
        if economy_overrides and any(economy_overrides.get(k) for k in economy_overrides):
            econ_row = run_turn(turn, "configure_economy", overrides=economy_overrides)
            history.append(econ_row)
            turn += 1
            economy_configure_result = econ_row

        if args.save_path:
            history.append(run_turn(turn, "save_game_path", path=args.save_path))
        else:
            history.append(run_turn(turn, "save_game", slot=args.slot))
        turn += 1
        if not args.save_path:
            history.append(run_turn(turn, "save_info", slot=args.slot))
        else:
            history.append({"info": {"path": args.save_path}})
        turn += 1
        summary = {
            "slot": args.slot,
            "save_path": args.save_path,
            "load_slot": args.load_slot,
            "character": args.character,
            "scenario_id": scenario_id,
            "profile": args.profile,
            "world_state": args.world_state,
            "policy_mode": args.policy_mode,
            "policy_graph_path": policy_graph_path_value or None,
            "policy_graph_jsonl": policy_graph_jsonl_value or None,
            "resource_mode": resource_mode,
            "starter_resources": resource_map,
            "known_pairs": known_pairs,
            "unlocked_biomes": unlocked_biomes,
            "unexplored_biomes": unexplored_biomes,
            "active_biome": active_biome,
            "economy_overrides": economy_overrides if economy_overrides else None,
            "economy_configure_result": economy_configure_result,
            "save_result": history[-2] if len(history) >= 2 else {},
            "save_info": history[-1] if history else {},
        }
        safe_print("seed-save: summary")
        safe_print(json.dumps(summary, ensure_ascii=False, indent=2))
        saved = bool(summary["save_result"].get("saved", False))
        return 0 if saved else 3
    finally:
        if proc is not None and not args.reuse_listener:
            try:
                run_turn(turn, "stop")
            except Exception:
                pass
            RigClient.terminate_listener(proc, timeout_s=5.0)


if __name__ == "__main__":
    sys.exit(main())
