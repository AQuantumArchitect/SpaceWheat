#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys
from collections import deque
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

from milk_hunt_paths import project_root
from milk_hunt_runtime_config import get_cfg_bool, get_cfg_int, get_cfg_str, load_json_config
from milk_hunt_strategy import Strategy, load_strategy
from rig_client import RigClient


MILK = "\U0001F37C"
PROJECT_ROOT = project_root()
_RIG = RigClient(root_from_file=Path(__file__))
FACTIONS_PATH = PROJECT_ROOT / "Core" / "Factions" / "data" / "factions_merged.json"


def _safe_print(msg: str) -> None:
    RigClient.safe_print(msg)


def _json_load_lines(path: Path) -> List[Dict[str, Any]]:
    return RigClient.json_load_lines(path)


def _clear_rig_files() -> None:
    _RIG.clear_rig_files()


def _find_listener_pids() -> List[int]:
    return RigClient.find_listener_pids()


def _kill_existing_listeners() -> None:
    RigClient.kill_existing_listeners()


def _start_listener(
    load_slot: Optional[int] = None,
    scenario_id: str = "default",
    allow_resource_injection: Optional[bool] = None,
) -> Any:
    return _RIG.start_listener(
        load_slot=load_slot,
        scenario_id=scenario_id,
        allow_resource_injection=allow_resource_injection,
    )


def _wait_for_ready(proc: Any, timeout_s: float = 60.0) -> List[str]:
    return RigClient.wait_for_ready(proc, timeout_s=timeout_s)


def _queue_turn(payload: Dict[str, Any]) -> None:
    _RIG.queue_turn(payload)


def _wait_for_turn(turn_id: int, timeout_s: float = 10.0) -> Optional[Dict[str, Any]]:
    return _RIG.wait_for_turn(turn_id, timeout_s=timeout_s)


def _run_turn(turn_id: int, action: str, **kwargs: Any) -> Dict[str, Any]:
    return _RIG.run_turn(turn_id, action, **kwargs)


def _extract_pairs(rows: List[Dict[str, Any]]) -> List[Dict[str, str]]:
    pairs: List[Dict[str, str]] = []
    for row in rows:
        if row.get("action") == "known_vocab_pairs":
            val = row.get("pairs", [])
            if isinstance(val, list):
                pairs = val
    return pairs


def _contains_milk_pair(pairs: List[Dict[str, str]]) -> bool:
    for p in pairs:
        if p.get("north") == MILK or p.get("south") == MILK:
            return True
    return False


def _extract_biomes(rows: List[Dict[str, Any]]) -> List[str]:
    biomes: List[str] = []
    for row in rows:
        if row.get("action") != "grid_snapshot":
            continue
        grid = row.get("grid", {})
        if not isinstance(grid, dict):
            continue
        val = grid.get("biomes", [])
        if not isinstance(val, list):
            continue
        biomes = [str(b) for b in val if isinstance(b, str) and b]
    return biomes


def _load_faction_data() -> Tuple[Dict[str, Set[str]], Dict[str, int]]:
    by_name: Dict[str, Set[str]] = {}
    adjacency: Dict[str, Set[str]] = {}
    if not FACTIONS_PATH.exists():
        return by_name, {}
    try:
        rows = json.loads(FACTIONS_PATH.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return by_name, {}
    for row in rows:
        name = str(row.get("name", ""))
        sig = row.get("sig", [])
        if not name or not isinstance(sig, list):
            continue
        ems = {str(e) for e in sig if isinstance(e, str) and e}
        if not ems:
            continue
        by_name[name] = ems
        for e in ems:
            adjacency.setdefault(e, set()).update(ems - {e})
    distances: Dict[str, int] = {}
    if MILK not in adjacency:
        return by_name, distances
    q: deque[str] = deque([MILK])
    distances[MILK] = 0
    while q:
        cur = q.popleft()
        for nxt in adjacency.get(cur, set()):
            if nxt in distances:
                continue
            distances[nxt] = distances[cur] + 1
            q.append(nxt)
    return by_name, distances


def _target_distance_score(emoji: str, distances: Dict[str, int], strategy: Strategy) -> int:
    if emoji == MILK:
        return strategy.distance_score(0)
    d = distances.get(emoji)
    if d is not None and 1 <= d <= 3:
        return strategy.distance_score(d)
    return 0


def _offer_reward_resources(offer: Dict[str, Any]) -> Dict[str, float]:
    raw = offer.get("reward_resources", {})
    if not isinstance(raw, dict):
        return {}
    out: Dict[str, float] = {}
    for emoji, amount in raw.items():
        if not isinstance(emoji, str) or not emoji:
            continue
        try:
            val = float(amount)
        except (TypeError, ValueError):
            continue
        if val > 0:
            out[emoji] = val
    return out


def _delivery_cost(offer: Dict[str, Any]) -> Tuple[str, float]:
    resource = str(offer.get("resource", "") or "")
    try:
        quantity = float(offer.get("quantity", 0) or 0)
    except (TypeError, ValueError):
        quantity = 0.0
    if not resource or quantity <= 0:
        return "", 0.0
    return resource, quantity


def _simulate_post_completion_resources(resources: Dict[str, float], offer: Dict[str, Any]) -> Dict[str, float]:
    out = dict(resources)
    cost_emoji, cost_qty = _delivery_cost(offer)
    if cost_emoji and cost_qty > 0:
        out[cost_emoji] = out.get(cost_emoji, 0.0) - cost_qty
    for emoji, amount in _offer_reward_resources(offer).items():
        out[emoji] = out.get(emoji, 0.0) + amount
    return out


def _count_affordable_delivery_offers(offers: List[Dict[str, Any]], resources: Dict[str, float]) -> int:
    count = 0
    for offer in offers:
        if int(offer.get("type", -1)) != 0:
            continue
        cost_emoji, cost_qty = _delivery_cost(offer)
        if not cost_emoji or cost_qty <= 0:
            continue
        if resources.get(cost_emoji, 0.0) >= cost_qty:
            count += 1
    return count


def _quest_reward_score(
    offer: Dict[str, Any],
    offers: List[Dict[str, Any]],
    current_resources: Dict[str, float],
    strict_biome_economy: bool,
    strategy: Strategy,
) -> int:
    rewards = _offer_reward_resources(offer)
    if not rewards:
        return 0

    after = _simulate_post_completion_resources(current_resources, offer)
    score = 0.0

    # Reward plans that increase immediately affordable delivery options.
    afford_before = _count_affordable_delivery_offers(offers, current_resources)
    afford_after = _count_affordable_delivery_offers(offers, after)
    score += float(afford_after - afford_before) * strategy.afford_delta

    # Push inventory toward hunt-critical resource levels.
    for emoji, target in strategy.strategic_targets.items():
        before_deficit = max(0.0, target - current_resources.get(emoji, 0.0))
        after_deficit = max(0.0, target - after.get(emoji, 0.0))
        progress = before_deficit - after_deficit
        if progress > 0:
            score += progress * strategy.deficit_progress

    # Injecting newly learned vocab needs 100 of the south-pole resource.
    south = str(offer.get("reward_vocab_south", "") or "")
    if south:
        before_need = max(0.0, 100.0 - current_resources.get(south, 0.0))
        after_need = max(0.0, 100.0 - after.get(south, 0.0))
        score += (before_need - after_need) * strategy.vocab_injection_need

    # Modest value for net growth.
    all_keys = set(current_resources.keys()) | set(after.keys())
    net_delta = sum(after.get(k, 0.0) - current_resources.get(k, 0.0) for k in all_keys)
    score += net_delta * (strategy.net_growth_strict if strict_biome_economy else strategy.net_growth_normal)
    score += sum(rewards.values()) * strategy.reward_sum

    return int(round(score))


def _best_offer_index(
    offers: List[Dict[str, Any]],
    known_symbols: set,
    faction_sigs: Dict[str, Set[str]],
    distances: Dict[str, int],
    current_resources: Dict[str, float],
    strict_biome_economy: bool,
    strategy: Strategy,
    candidate_indices: Optional[List[int]] = None,
) -> int:
    indices = candidate_indices if candidate_indices else list(range(len(offers)))
    if not indices:
        return 0
    best_idx = 0
    best_score = -10**9
    for i in indices:
        offer = offers[i]
        n = str(offer.get("reward_vocab_north", "") or "")
        s = str(offer.get("reward_vocab_south", "") or "")
        faction = str(offer.get("faction", "") or "")
        score = 0
        if n and n not in known_symbols:
            score += strategy.vocab_discovery
        if s and s not in known_symbols:
            score += strategy.vocab_discovery
        score += _target_distance_score(n, distances, strategy)
        score += _target_distance_score(s, distances, strategy)
        score += _quest_reward_score(offer, offers, current_resources, strict_biome_economy, strategy)
        sig = faction_sigs.get(faction, set())
        if sig:
            best_sig_dist = min((distances.get(e, 9999) for e in sig), default=9999)
            if 1 <= best_sig_dist <= 3:
                score += strategy.faction_sig_score(best_sig_dist)
        completion_action = str(offer.get("completion_action", "") or "")
        if completion_action not in {"complete_quest", "complete_or_claim"}:
            score += strategy.completion_penalty
        if score > best_score:
            best_score = score
            best_idx = i
    return best_idx


def _extract_resource_map(row: Dict[str, Any]) -> Dict[str, float]:
    if not isinstance(row, dict):
        return {}
    resources = row.get("resources", {})
    if not isinstance(resources, dict):
        return {}
    values = resources.get("resources", {})
    if not isinstance(values, dict):
        return {}
    out: Dict[str, float] = {}
    for emoji, amount in values.items():
        if not isinstance(emoji, str) or not emoji:
            continue
        try:
            out[emoji] = float(amount)
        except (TypeError, ValueError):
            continue
    return out


def _eligible_delivery_offer_indices(
    offers: List[Dict[str, Any]],
    strict_biome_economy: bool,
    resources: Dict[str, float],
) -> List[int]:
    eligible: List[int] = []
    for i, offer in enumerate(offers):
        quest_type = int(offer.get("type", -1))
        if quest_type != 0:
            continue
        resource = str(offer.get("resource", "") or "")
        quantity = int(float(offer.get("quantity", 0) or 0))
        if not resource or quantity <= 0:
            continue
        if strict_biome_economy and resources.get(resource, 0.0) < float(quantity):
            continue
        eligible.append(i)
    return eligible


def _parse_resource_floor_overrides(values: List[str]) -> Dict[str, float]:
    out: Dict[str, float] = {}
    for raw in values:
        if ":" not in raw:
            continue
        emoji, amount_raw = raw.split(":", 1)
        emoji = emoji.strip()
        if not emoji:
            continue
        try:
            amount = float(amount_raw.strip())
        except ValueError:
            continue
        out[emoji] = max(0.0, amount)
    return out


def _enforce_primary_resource_floors(
    turn: int,
    history: List[Dict[str, Any]],
    current_resources: Dict[str, float],
    floors: Dict[str, float],
) -> tuple[int, Dict[str, float], List[Dict[str, Any]]]:
    events: List[Dict[str, Any]] = []
    changed = False
    for emoji, floor in floors.items():
        have = float(current_resources.get(emoji, 0.0))
        if have >= floor:
            continue
        need = int(max(1.0, floor - have))
        add_row = _run_turn(turn, "add_resource", emoji=emoji, amount=need)
        history.append(add_row)
        turn += 1
        changed = True
        events.append({"emoji": emoji, "before": have, "floor": floor, "added": need, "ok": bool(add_row.get("added", False))})
    if changed:
        snap_row = _run_turn(turn, "resource_snapshot")
        history.append(snap_row)
        turn += 1
        current_resources = _extract_resource_map(snap_row)
    return turn, current_resources, events


def _extract_probe_pop_resource(probe_row: Dict[str, Any]) -> str:
    if not isinstance(probe_row, dict):
        return ""
    probe = probe_row.get("probe", {})
    if not isinstance(probe, dict):
        return ""
    pop = probe.get("pop", {})
    if not isinstance(pop, dict):
        return ""
    resource = pop.get("resource", "")
    return str(resource) if isinstance(resource, str) else ""


def _select_focus_biome(
    biomes: List[str],
    biome_explore_counts: Dict[str, int],
    biome_resource_hits: Dict[str, Dict[str, int]],
    target_emoji: str,
) -> Optional[str]:
    if not biomes:
        return None
    ranked = sorted(
        biomes,
        key=lambda b: (
            -(biome_resource_hits.get(b, {}).get(target_emoji, 0)),
            biome_explore_counts.get(b, 0),
            b,
        ),
    )
    return ranked[0] if ranked else None


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Single-run milk hunt rig player")
    parser.add_argument(
        "--config",
        type=Path,
        default=Path(__file__).resolve().parent / "config" / "milk_hunt_runner.json",
        help="Runner config JSON path",
    )
    parser.add_argument(
        "--strategy",
        type=Path,
        default=None,
        help="Strategy JSON path (overrides hardcoded scoring/targeting constants)",
    )
    parser.add_argument("--max-loops", type=int, default=None, help="Maximum offer cycles")
    parser.add_argument("--summary-path", type=Path, default=None, help="Optional JSON summary output path")
    parser.add_argument("--json-only", action="store_true", help="Print only the summary JSON")
    parser.add_argument("--load-slot", type=int, default=None, help="Boot the rig from a save slot")
    parser.add_argument("--load-alias", type=str, default=None, help="Load from emoji alias save filename/path")
    parser.add_argument("--scenario-id", type=str, default=None, help="Scenario id when not loading a slot")
    parser.add_argument(
        "--strict-biome-economy",
        dest="strict_biome_economy",
        action="store_true",
        help="Disable all rig-side resource injection; rely only on in-biome resources",
    )
    parser.add_argument(
        "--no-strict-biome-economy",
        dest="strict_biome_economy",
        action="store_false",
        help="Force-enable rig-side resource injection",
    )
    parser.add_argument("--save-slot-at-end", type=int, default=None, help="Save the run state to this slot before exit")
    parser.add_argument(
        "--reuse-listener",
        action="store_true",
        help="Reuse an existing rig listener instead of starting a new one",
    )
    parser.add_argument("--turn-start", type=int, default=1, help="Turn id to start at")
    parser.add_argument("--no-stop", action="store_true", help="Skip sending stop on exit")
    parser.add_argument("--no-clear-rig", action="store_true", help="Skip clearing rig queue/results files")
    parser.add_argument(
        "--allow-rig-resource-injection",
        dest="allow_rig_resource_injection",
        action="store_true",
        help="Allow rig add/set resource actions (default on)",
    )
    parser.add_argument(
        "--no-allow-rig-resource-injection",
        dest="allow_rig_resource_injection",
        action="store_false",
        help="Disallow rig add/set resource actions (strict economy mode)",
    )
    parser.add_argument(
        "--fail-on-boot-script-errors",
        action="store_true",
        help="Fail run if boot logs include SCRIPT ERROR / compile failures",
    )
    parser.add_argument(
        "--open-quests-overlay",
        action="store_true",
        help="Open quests overlay at run start (disabled by default to keep world visible)",
    )
    parser.add_argument("--eagle-focus", action="store_true", help="Prioritize cultivating eagle stock via probe cycles")
    parser.add_argument("--eagle-emoji", type=str, default=None, help="Resource emoji used for expansion gating")
    parser.add_argument(
        "--eagle-target-stock",
        type=float,
        default=None,
        help="When eagle-focus is enabled, run extra probe cycles until this stock is reached",
    )
    parser.add_argument(
        "--eagle-probe-burst",
        type=int,
        default=None,
        help="Extra probe_cycle actions per loop while eagle stock is below target",
    )
    parser.add_argument("--expand-biomes", action="store_true", help="Attempt biome expansion during milk runs")
    parser.add_argument(
        "--expand-check-every",
        type=int,
        default=None,
        help="Check biome expansion every N loops",
    )
    parser.add_argument(
        "--max-biome-expansions",
        type=int,
        default=None,
        help="Maximum number of explore_biome attempts per run",
    )
    parser.add_argument(
        "--min-eagles-for-expansion",
        type=float,
        default=None,
        help="Minimum eagle stock before explore_biome is attempted",
    )
    parser.add_argument(
        "--enforce-primary-resource-floors",
        dest="enforce_primary_resource_floors",
        action="store_true",
        help="Keep bread/cold/labor above floor thresholds to avoid starvation traps",
    )
    parser.add_argument(
        "--no-enforce-primary-resource-floors",
        dest="enforce_primary_resource_floors",
        action="store_false",
        help="Disable automatic primary-resource floor enforcement",
    )
    parser.add_argument(
        "--resource-floor",
        action="append",
        default=[],
        help="Override floor as EMOJI:AMOUNT (repeatable), e.g. --resource-floor 🍞:140",
    )
    parser.add_argument(
        "--victory-lap",
        dest="victory_lap",
        action="store_true",
        help="After learning 🍼 vocab, run full-farm explore→measure→harvest victory lap",
    )
    parser.add_argument(
        "--no-victory-lap",
        dest="victory_lap",
        action="store_false",
        help="Skip post-milk victory lap",
    )
    parser.set_defaults(enforce_primary_resource_floors=True, allow_rig_resource_injection=True)
    parser.set_defaults(victory_lap=True)
    parser.set_defaults(strict_biome_economy=True)
    return parser


def main() -> int:
    args = _build_parser().parse_args()
    cfg = load_json_config(args.config)
    strategy = load_strategy(args.strategy)
    load_slot = args.load_slot
    load_alias = args.load_alias
    scenario_id = args.scenario_id
    strict_biome_economy = args.strict_biome_economy
    max_loops = args.max_loops

    if max_loops is None:
        max_loops = get_cfg_int(cfg, "max_loops")
    if max_loops is None and os.environ.get("MILK_HUNT_MAX_LOOPS", "") != "":
        max_loops = int(os.environ["MILK_HUNT_MAX_LOOPS"])
    if max_loops is None:
        max_loops = 140

    if load_slot is None:
        load_slot = get_cfg_int(cfg, "load_slot")
    if load_slot is None and os.environ.get("MILK_HUNT_LOAD_SLOT", "") != "":
        load_slot = int(os.environ["MILK_HUNT_LOAD_SLOT"])

    if not load_alias:
        load_alias = get_cfg_str(cfg, "load_alias")
    if not load_alias and os.environ.get("MILK_HUNT_LOAD_ALIAS", "") != "":
        load_alias = os.environ["MILK_HUNT_LOAD_ALIAS"]

    if scenario_id is None:
        scenario_id = get_cfg_str(cfg, "scenario_id")
    if not scenario_id:
        scenario_id = "default"

    if strict_biome_economy is None:
        val = strategy.strict_biome_economy
        if val is not None:
            strict_biome_economy = val
        else:
            strict_biome_economy = get_cfg_bool(cfg, "strict_biome_economy")
    if strict_biome_economy is None:
        strict_biome_economy = True

    # Eagle / expansion defaults: CLI > strategy > hardcoded
    eagle_emoji = args.eagle_emoji if args.eagle_emoji is not None else strategy.eagle_emoji
    eagle_target_stock = args.eagle_target_stock if args.eagle_target_stock is not None else strategy.eagle_target_stock
    eagle_probe_burst = args.eagle_probe_burst if args.eagle_probe_burst is not None else strategy.eagle_probe_burst
    expand_check_every = args.expand_check_every if args.expand_check_every is not None else strategy.eagle_check_every
    max_biome_expansions = args.max_biome_expansions if args.max_biome_expansions is not None else strategy.eagle_max_expansions
    min_eagles_for_expansion = args.min_eagles_for_expansion if args.min_eagles_for_expansion is not None else strategy.eagle_min_for_expansion

    primary_resource_floors = dict(strategy.resource_floors)
    primary_resource_floors.update(_parse_resource_floor_overrides(args.resource_floor))

    if load_alias:
        load_slot = None
    proc: Optional[subprocess.Popen] = None
    boot_lines: List[str] = []
    if not args.reuse_listener:
        _safe_print("milk-hunt: resetting rig cache and starting listener")
        _kill_existing_listeners()
        if not args.no_clear_rig:
            _clear_rig_files()
        proc = _start_listener(
            load_slot=load_slot,
            scenario_id=scenario_id,
            allow_resource_injection=args.allow_rig_resource_injection,
        )
        boot_lines = _wait_for_ready(proc, timeout_s=70.0)
        if proc.poll() is not None:
            _safe_print("milk-hunt: listener exited during boot")
            for line in boot_lines[-20:]:
                _safe_print(line)
            return 1
        if not any("Rig ready. Waiting for turns in:" in ln for ln in boot_lines):
            _safe_print("milk-hunt: listener did not reach ready state")
            for line in boot_lines[-20:]:
                _safe_print(line)
            proc.terminate()
            return 1
    else:
        if not _find_listener_pids():
            _safe_print("milk-hunt: reuse requested but no listener found; starting a new one")
            if not args.no_clear_rig:
                _clear_rig_files()
            proc = _start_listener(
                load_slot=load_slot,
                scenario_id=scenario_id,
                allow_resource_injection=args.allow_rig_resource_injection,
            )
            boot_lines = _wait_for_ready(proc, timeout_s=70.0)
            if proc.poll() is not None:
                _safe_print("milk-hunt: listener exited during boot")
                for line in boot_lines[-20:]:
                    _safe_print(line)
                return 1
            if not any("Rig ready. Waiting for turns in:" in ln for ln in boot_lines):
                _safe_print("milk-hunt: listener did not reach ready state")
                for line in boot_lines[-20:]:
                    _safe_print(line)
                proc.terminate()
                return 1
        else:
            if not args.no_clear_rig:
                _clear_rig_files()

    turn = max(1, int(args.turn_start))
    history: List[Dict[str, Any]] = []
    error_lines = [ln for ln in boot_lines if "ERROR:" in ln or "SCRIPT ERROR:" in ln]
    if args.fail_on_boot_script_errors and error_lines:
        _safe_print("milk-hunt: failing due to boot script errors")
        for line in error_lines[-20:]:
            _safe_print(line)
        RigClient.terminate_listener(proc, timeout_s=5.0)
        return 4
    faction_sigs, milk_distances = _load_faction_data()

    try:
        if load_alias is not None:
            history.append(_run_turn(turn, "load_game_alias", alias=load_alias))
            turn += 1
        elif args.reuse_listener and load_slot is not None:
            history.append(_run_turn(turn, "load_game", slot=load_slot))
            turn += 1
        if args.open_quests_overlay:
            history.append(_run_turn(turn, "open_overlay", name="quests"))
            turn += 1
        snap = _run_turn(turn, "resource_snapshot")
        history.append(snap)
        turn += 1

        resources = snap.get("resources", {}).get("resources", {})
        if isinstance(resources, dict) and not strict_biome_economy and strategy.initial_injection_enabled:
            inj_amount = strategy.initial_injection_amount
            for emoji in strategy.initial_injection_resources:
                history.append(_run_turn(turn, "add_resource", emoji=emoji, amount=inj_amount))
                turn += 1

        history.append(_run_turn(turn, "grid_snapshot"))
        turn += 1
        history.append(_run_turn(turn, "known_vocab_pairs"))
        turn += 1
        resources = _run_turn(turn, "resource_snapshot")
        history.append(resources)
        turn += 1
        print("RESOURCE_SNAPSHOT", json.dumps(resources.get("resources", {}), ensure_ascii=False))

        found_milk = False
        found_offer = False
        last_milk_offer: Optional[Dict[str, Any]] = None
        victory_lap_result: Dict[str, Any] = {}
        victory_lap_executed = False
        prev_pairs_count = len(_extract_pairs(history))
        discovered_biomes: List[str] = []
        biome_explore_counts: Dict[str, int] = {}
        biome_resource_hits: Dict[str, Dict[str, int]] = {}
        biome_probe_events: List[Dict[str, Any]] = []
        vocab_milestones: List[Dict[str, Any]] = []
        biome_expansion_events: List[Dict[str, Any]] = []
        primary_resource_floor_events: List[Dict[str, Any]] = []
        expansions_attempted = 0
        expansions_succeeded = 0
        loops_completed = 0
        current_resources: Dict[str, float] = _extract_resource_map(snap)

        if args.enforce_primary_resource_floors:
            turn, current_resources, floor_events = _enforce_primary_resource_floors(
                turn,
                history,
                current_resources,
                primary_resource_floors,
            )
            if floor_events:
                primary_resource_floor_events.append({"loop": 0, "events": floor_events})

        for loop_idx in range(max_loops):
            loops_completed = loop_idx + 1
            if args.enforce_primary_resource_floors:
                turn, current_resources, floor_events = _enforce_primary_resource_floors(
                    turn,
                    history,
                    current_resources,
                    primary_resource_floors,
                )
                if floor_events:
                    primary_resource_floor_events.append({"loop": loop_idx + 1, "events": floor_events})

            if args.expand_biomes and expansions_attempted < max(0, int(max_biome_expansions)):
                if loop_idx % max(1, int(expand_check_every)) == 0:
                    eagle_stock = float(current_resources.get(eagle_emoji, 0.0))
                    if eagle_stock >= float(min_eagles_for_expansion):
                        expand_row = _run_turn(turn, "explore_biome")
                        history.append(expand_row)
                        turn += 1
                        expansions_attempted += 1
                        expand_result = expand_row.get("explore_biome", {}) if isinstance(expand_row, dict) else {}
                        success = bool(isinstance(expand_result, dict) and expand_result.get("success", False))
                        if success:
                            expansions_succeeded += 1
                            grid_after_expand = _run_turn(turn, "grid_snapshot")
                            history.append(grid_after_expand)
                            turn += 1
                        biome_expansion_events.append(
                            {
                                "loop": loop_idx + 1,
                                "attempt": expansions_attempted,
                                "success": success,
                                "eagle_stock": eagle_stock,
                                "result": expand_result if isinstance(expand_result, dict) else {},
                            }
                        )

            if args.eagle_focus and float(current_resources.get(eagle_emoji, 0.0)) < float(eagle_target_stock):
                burst_count = max(1, int(eagle_probe_burst))
                for _focus_idx in range(burst_count):
                    focus_grid = _run_turn(turn, "grid_snapshot")
                    history.append(focus_grid)
                    turn += 1
                    focus_biomes = _extract_biomes(history)
                    focus_biome = _select_focus_biome(
                        focus_biomes,
                        biome_explore_counts,
                        biome_resource_hits,
                        eagle_emoji,
                    )
                    if not focus_biome:
                        break
                    if focus_biome not in discovered_biomes:
                        discovered_biomes.append(focus_biome)
                    biome_explore_counts[focus_biome] = biome_explore_counts.get(focus_biome, 0) + 1
                    focus_probe_row = _run_turn(turn, "probe_cycle", biome=focus_biome)
                    history.append(focus_probe_row)
                    turn += 1
                    harvested = _extract_probe_pop_resource(focus_probe_row)
                    if harvested:
                        biome_resource_hits.setdefault(focus_biome, {})
                        hits = biome_resource_hits[focus_biome]
                        hits[harvested] = hits.get(harvested, 0) + 1
                    focus_snapshot = _run_turn(turn, "resource_snapshot")
                    history.append(focus_snapshot)
                    turn += 1
                    current_resources = _extract_resource_map(focus_snapshot)
                    if float(current_resources.get(eagle_emoji, 0.0)) >= float(eagle_target_stock):
                        break

            loop_snapshot = _run_turn(turn, "resource_snapshot")
            history.append(loop_snapshot)
            turn += 1
            current_resources = _extract_resource_map(loop_snapshot)
            offer_row = _run_turn(turn, "offer_quests")
            history.append(offer_row)
            turn += 1
            offers = offer_row.get("offers", [])
            if not isinstance(offers, list) or not offers:
                continue
            eligible_delivery = _eligible_delivery_offer_indices(offers, strict_biome_economy, current_resources)
            if not eligible_delivery:
                continue

            known_pairs = _extract_pairs(history)
            known_symbols = set()
            for p in known_pairs:
                if p.get("north"):
                    known_symbols.add(p["north"])
                if p.get("south"):
                    known_symbols.add(p["south"])

            milk_index = None
            for i, offer in enumerate(offers):
                n = str(offer.get("reward_vocab_north", "") or "")
                s = str(offer.get("reward_vocab_south", "") or "")
                if n == MILK or s == MILK:
                    milk_index = i
                    last_milk_offer = offer
                    break

            if milk_index is not None:
                found_offer = True
                if milk_index in eligible_delivery:
                    selected_idx = milk_index
                    accept = _run_turn(turn, "accept_offer", offer_index=selected_idx)
                    history.append(accept)
                    turn += 1
                else:
                    selected_idx = _best_offer_index(
                        offers,
                        known_symbols,
                        faction_sigs,
                        milk_distances,
                        current_resources,
                        strict_biome_economy,
                        strategy,
                        eligible_delivery,
                    )
                    accept = _run_turn(turn, "accept_offer", offer_index=selected_idx)
                    history.append(accept)
                    turn += 1
            else:
                selected_idx = _best_offer_index(
                    offers,
                    known_symbols,
                    faction_sigs,
                    milk_distances,
                    current_resources,
                    strict_biome_economy,
                    strategy,
                    eligible_delivery,
                )
                accept = _run_turn(turn, "accept_offer", offer_index=selected_idx)
                history.append(accept)
                turn += 1

            quest_id = int(accept.get("quest_id", -1))
            if quest_id >= 0:
                selected_offer: Dict[str, Any] = {}
                if 0 <= selected_idx < len(offers):
                    maybe_offer = offers[selected_idx]
                    if isinstance(maybe_offer, dict):
                        selected_offer = maybe_offer
                active_row = _run_turn(turn, "active_quests")
                history.append(active_row)
                turn += 1
                quests = active_row.get("quests", [])
                if isinstance(quests, list):
                    for q in quests:
                        if int(q.get("id", -1)) != quest_id:
                            continue
                        res = str(q.get("resource", "") or "")
                        qty = int(float(q.get("quantity", 0) or 0))
                        if res and qty > 0 and not strict_biome_economy:
                            history.append(_run_turn(turn, "add_resource", emoji=res, amount=max(qty + 50, 100)))
                            turn += 1
                completion_action = str(selected_offer.get("completion_action", "") or "")
                if completion_action not in {"complete_quest", "complete_or_claim"}:
                    completion_action = "complete_quest" if int(selected_offer.get("type", -1)) == 0 else "complete_or_claim"
                history.append(_run_turn(turn, completion_action, quest_id=quest_id))
                turn += 1
                post_complete_snapshot = _run_turn(turn, "resource_snapshot")
                history.append(post_complete_snapshot)
                turn += 1
                current_resources = _extract_resource_map(post_complete_snapshot)
                pairs_row = _run_turn(turn, "known_vocab_pairs")
                history.append(pairs_row)
                turn += 1
                pairs = pairs_row.get("pairs", [])
                pair_count = len(pairs) if isinstance(pairs, list) else prev_pairs_count
                if pair_count > prev_pairs_count:
                    new_pairs: List[Dict[str, str]] = []
                    if isinstance(pairs, list):
                        for pair in pairs[prev_pairs_count:pair_count]:
                            if not isinstance(pair, dict):
                                continue
                            north = str(pair.get("north", "") or "")
                            south = str(pair.get("south", "") or "")
                            if north or south:
                                new_pairs.append({"north": north, "south": south})
                    vocab_milestones.append(
                        {
                            "loop": loop_idx + 1,
                            "step": len(history),
                            "pair_count": pair_count,
                            "pair_gain": pair_count - prev_pairs_count,
                            "new_pairs": new_pairs,
                            "contains_milk_pair": _contains_milk_pair(new_pairs),
                        }
                    )
                    for _vocab_step in range(prev_pairs_count, pair_count):
                        grid_row = _run_turn(turn, "grid_snapshot")
                        history.append(grid_row)
                        turn += 1
                        biomes = _extract_biomes(history)
                        if not biomes:
                            biome_probe_events.append(
                                {
                                    "vocab_count": _vocab_step + 1,
                                    "biome": None,
                                    "ok": False,
                                    "error": "no_biomes_available",
                                }
                            )
                            continue

                        next_biome = next((b for b in biomes if b not in discovered_biomes), None)
                        if next_biome is None:
                            next_biome = min(biomes, key=lambda b: (biome_explore_counts.get(b, 0), b))

                        if next_biome not in discovered_biomes:
                            discovered_biomes.append(next_biome)
                        biome_explore_counts[next_biome] = biome_explore_counts.get(next_biome, 0) + 1

                        probe_row = _run_turn(turn, "probe_cycle", biome=next_biome)
                        history.append(probe_row)
                        turn += 1
                        harvested = _extract_probe_pop_resource(probe_row)
                        if harvested:
                            biome_resource_hits.setdefault(next_biome, {})
                            hits = biome_resource_hits[next_biome]
                            hits[harvested] = hits.get(harvested, 0) + 1
                        probe = probe_row.get("probe", {}) if isinstance(probe_row, dict) else {}
                        probe_ok = bool(isinstance(probe, dict) and probe.get("success", False))
                        biome_probe_events.append(
                            {
                                "vocab_count": _vocab_step + 1,
                                "biome": next_biome,
                                "ok": probe_ok,
                                "probe": probe if isinstance(probe, dict) else {},
                            }
                        )
                    prev_pairs_count = pair_count
                if isinstance(pairs, list) and _contains_milk_pair(pairs):
                    found_milk = True
                    break

        if found_milk and args.victory_lap:
            victory_row = _run_turn(turn, "victory_lap")
            history.append(victory_row)
            turn += 1
            victory_lap_executed = True
            if isinstance(victory_row, dict):
                raw_victory = victory_row.get("victory_lap", {})
                if isinstance(raw_victory, dict):
                    victory_lap_result = raw_victory
            post_victory_snapshot = _run_turn(turn, "resource_snapshot")
            history.append(post_victory_snapshot)
            turn += 1
            current_resources = _extract_resource_map(post_victory_snapshot)

        final_pairs = _extract_pairs(history)
        steps = len(history)
        summary = {
            "found_milk_pair": found_milk,
            "found_milk_offer": found_offer,
            "milk_offer": last_milk_offer,
            "known_pairs_count": len(final_pairs),
            "known_pairs": final_pairs,
            "steps": steps,
            "turns_executed": steps,
            "loops_completed": loops_completed,
            "errors_seen_during_boot": error_lines,
            "max_loops": max_loops,
            "strict_biome_economy": strict_biome_economy,
            "load_slot": load_slot,
            "load_alias": load_alias,
            "scenario_id": scenario_id,
            "biome_discovery_order": discovered_biomes,
            "biome_explore_counts": biome_explore_counts,
            "biome_resource_hits": biome_resource_hits,
            "biome_probe_events": biome_probe_events,
            "vocab_milestones": vocab_milestones,
            "strategy_name": strategy.name,
            "strategy_path": strategy.path,
            "eagle_focus": args.eagle_focus,
            "eagle_emoji": eagle_emoji,
            "eagle_target_stock": eagle_target_stock,
            "eagle_stock_final": current_resources.get(eagle_emoji, 0.0),
            "expand_biomes": args.expand_biomes,
            "max_biome_expansions": max_biome_expansions,
            "expansions_attempted": expansions_attempted,
            "expansions_succeeded": expansions_succeeded,
            "biome_expansion_events": biome_expansion_events,
            "enforce_primary_resource_floors": args.enforce_primary_resource_floors,
            "primary_resource_floors": primary_resource_floors,
            "primary_resource_floor_events": primary_resource_floor_events,
            "victory_lap_enabled": args.victory_lap,
            "victory_lap_executed": victory_lap_executed,
            "victory_lap_result": victory_lap_result,
        }
        if args.save_slot_at_end is not None:
            save_row = _run_turn(turn, "save_game", slot=args.save_slot_at_end)
            history.append(save_row)
            turn += 1
            summary["saved_slot"] = args.save_slot_at_end
            summary["save_result"] = save_row
        for idx, pair in enumerate(final_pairs):
            if pair.get("north") == MILK or pair.get("south") == MILK:
                summary["milk_pair_index"] = idx + 1
                break
        if "milk_pair_index" not in summary:
            summary["milk_pair_index"] = None
        if args.summary_path is not None:
            args.summary_path.parent.mkdir(parents=True, exist_ok=True)
            args.summary_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        if args.json_only:
            _safe_print(json.dumps(summary, ensure_ascii=False))
        else:
            _safe_print("milk-hunt: summary")
            _safe_print(json.dumps(summary, ensure_ascii=False, indent=2))
        return 0 if found_milk else 2
    finally:
        if not args.no_stop:
            try:
                _run_turn(turn, "stop")
            except Exception:
                pass
        RigClient.terminate_listener(proc, timeout_s=5.0)


if __name__ == "__main__":
    sys.exit(main())
