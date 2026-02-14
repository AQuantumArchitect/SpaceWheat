#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys
import time
from collections import deque
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

SCRIPT_DIR = Path(__file__).resolve().parent
PARENT_DIR = SCRIPT_DIR.parent
if str(PARENT_DIR) not in sys.path:
    sys.path.insert(0, str(PARENT_DIR))

from milk_hunt_paths import project_root
from rig_client import RigClient


MILK = "\U0001F37C"
PROJECT_ROOT = project_root()
_RIG = RigClient(root_from_file=Path(__file__))
FACTIONS_PATH = PROJECT_ROOT / "Core" / "Factions" / "data" / "factions_merged.json"
STRATEGIC_RESOURCE_TARGETS: Dict[str, float] = {
    "👥": 220.0,
    "🌾": 220.0,
    "🍞": 260.0,
    "❄️": 120.0,
    "🌱": 120.0,
}
TURN_DELAY_S: float = 0.0
PROBE_DELAY_S: float = 0.0


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


def _start_listener(load_slot: Optional[int] = None, scenario_id: str = "default") -> subprocess.Popen:
    return _RIG.start_listener(load_slot=load_slot, scenario_id=scenario_id)


def _wait_for_ready(proc: subprocess.Popen, timeout_s: float = 60.0) -> List[str]:
    return RigClient.wait_for_ready(proc, timeout_s=timeout_s)


def _queue_turn(payload: Dict[str, Any]) -> None:
    _RIG.queue_turn(payload)


def _wait_for_turn(turn_id: int, timeout_s: float = 10.0) -> Optional[Dict[str, Any]]:
    return _RIG.wait_for_turn(turn_id, timeout_s=timeout_s)


def _run_turn(turn_id: int, action: str, **kwargs: Any) -> Dict[str, Any]:
    result = _RIG.run_turn(turn_id, action, **kwargs)
    delay_s = PROBE_DELAY_S if action == "probe_cycle" else TURN_DELAY_S
    if result.get("error") != "timeout_waiting_for_result" and delay_s > 0.0:
        time.sleep(delay_s)
    return result


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


def _target_distance_score(emoji: str, distances: Dict[str, int]) -> int:
    if emoji == MILK:
        return 1000
    d = distances.get(emoji)
    if d == 1:
        return 260
    if d == 2:
        return 180
    if d == 3:
        return 80
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
) -> int:
    rewards = _offer_reward_resources(offer)
    if not rewards:
        return 0

    after = _simulate_post_completion_resources(current_resources, offer)
    score = 0.0

    # Reward plans that increase immediately affordable delivery options.
    afford_before = _count_affordable_delivery_offers(offers, current_resources)
    afford_after = _count_affordable_delivery_offers(offers, after)
    score += float(afford_after - afford_before) * 120.0

    # Push inventory toward hunt-critical resource levels.
    for emoji, target in STRATEGIC_RESOURCE_TARGETS.items():
        before_deficit = max(0.0, target - current_resources.get(emoji, 0.0))
        after_deficit = max(0.0, target - after.get(emoji, 0.0))
        progress = before_deficit - after_deficit
        if progress > 0:
            score += progress * 0.8

    # Injecting newly learned vocab needs 100 of the south-pole resource.
    south = str(offer.get("reward_vocab_south", "") or "")
    if south:
        before_need = max(0.0, 100.0 - current_resources.get(south, 0.0))
        after_need = max(0.0, 100.0 - after.get(south, 0.0))
        score += (before_need - after_need) * 1.2

    # Modest value for net growth.
    all_keys = set(current_resources.keys()) | set(after.keys())
    net_delta = sum(after.get(k, 0.0) - current_resources.get(k, 0.0) for k in all_keys)
    score += net_delta * (0.18 if strict_biome_economy else 0.08)
    score += sum(rewards.values()) * 0.04

    return int(round(score))


def _best_offer_index(
    offers: List[Dict[str, Any]],
    known_symbols: set,
    faction_sigs: Dict[str, Set[str]],
    distances: Dict[str, int],
    current_resources: Dict[str, float],
    strict_biome_economy: bool,
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
            score += 25
        if s and s not in known_symbols:
            score += 25
        score += _target_distance_score(n, distances)
        score += _target_distance_score(s, distances)
        score += _quest_reward_score(offer, offers, current_resources, strict_biome_economy)
        sig = faction_sigs.get(faction, set())
        if sig:
            best_sig_dist = min((distances.get(e, 9999) for e in sig), default=9999)
            if best_sig_dist == 1:
                score += 140
            elif best_sig_dist == 2:
                score += 90
            elif best_sig_dist == 3:
                score += 35
        completion_action = str(offer.get("completion_action", "") or "")
        if completion_action not in {"complete_quest", "complete_or_claim"}:
            score -= 30
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


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Single-run milk hunt rig player")
    parser.add_argument("--max-loops", type=int, default=None, help="Maximum offer cycles")
    parser.add_argument("--summary-path", type=Path, default=None, help="Optional JSON summary output path")
    parser.add_argument("--json-only", action="store_true", help="Print only the summary JSON")
    parser.add_argument("--load-slot", type=int, default=None, help="Boot the rig from a save slot")
    parser.add_argument("--load-alias", type=str, default=None, help="Load from emoji alias save filename/path")
    parser.add_argument("--scenario-id", type=str, default="default", help="Scenario id when not loading a slot")
    parser.add_argument(
        "--strict-biome-economy",
        action="store_true",
        help="Disable all rig-side resource injection; rely only on in-biome resources",
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
        "--turn-delay-s",
        type=float,
        default=float(os.environ.get("MILK_HUNT_TURN_DELAY_S", "0.10")),
        help="Sleep after each non-probe turn (visual pacing)",
    )
    parser.add_argument(
        "--probe-delay-s",
        type=float,
        default=float(os.environ.get("MILK_HUNT_PROBE_DELAY_S", "0.25")),
        help="Sleep after probe_cycle turns (gives rendering time)",
    )
    parser.add_argument(
        "--probe-each-loop",
        dest="probe_each_loop",
        action="store_true",
        default=True,
        help="Drive quantum instrument every loop via probe_cycle",
    )
    parser.add_argument(
        "--no-probe-each-loop",
        dest="probe_each_loop",
        action="store_false",
        help="Disable per-loop probe_cycle driving",
    )
    parser.add_argument(
        "--grid-refresh-every",
        type=int,
        default=5,
        help="Refresh grid_snapshot every N loops while probing",
    )
    return parser


def main() -> int:
    args = _build_parser().parse_args()
    global TURN_DELAY_S, PROBE_DELAY_S
    TURN_DELAY_S = max(0.0, float(args.turn_delay_s))
    PROBE_DELAY_S = max(0.0, float(args.probe_delay_s))
    load_slot = args.load_slot
    load_alias = args.load_alias
    if load_slot is None and os.environ.get("MILK_HUNT_LOAD_SLOT", "") != "":
        load_slot = int(os.environ["MILK_HUNT_LOAD_SLOT"])
    if not load_alias and os.environ.get("MILK_HUNT_LOAD_ALIAS", "") != "":
        load_alias = os.environ["MILK_HUNT_LOAD_ALIAS"]
    if load_alias:
        load_slot = None
    proc: Optional[subprocess.Popen] = None
    boot_lines: List[str] = []
    if not args.reuse_listener:
        _safe_print("milk-hunt: resetting rig cache and starting listener")
        _kill_existing_listeners()
        if not args.no_clear_rig:
            _clear_rig_files()
        proc = _start_listener(load_slot=load_slot, scenario_id=args.scenario_id)
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
            proc = _start_listener(load_slot=load_slot, scenario_id=args.scenario_id)
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
    faction_sigs, milk_distances = _load_faction_data()

    try:
        if load_alias is not None:
            history.append(_run_turn(turn, "load_game_alias", alias=load_alias))
            turn += 1
        elif args.reuse_listener and load_slot is not None:
            history.append(_run_turn(turn, "load_game", slot=load_slot))
            turn += 1
        history.append(_run_turn(turn, "open_overlay", name="quests"))
        turn += 1
        snap = _run_turn(turn, "resource_snapshot")
        history.append(snap)
        turn += 1

        resources = snap.get("resources", {}).get("resources", {})
        if isinstance(resources, dict) and not args.strict_biome_economy:
            for emoji in ["👥", "🌾", "🍞", "❄️", "🌱", "⚙", "🔥"]:
                history.append(_run_turn(turn, "add_resource", emoji=emoji, amount=500))
                turn += 1

        history.append(_run_turn(turn, "grid_snapshot"))
        turn += 1
        history.append(_run_turn(turn, "known_vocab_pairs"))
        turn += 1

        max_loops = args.max_loops if args.max_loops is not None else int(os.environ.get("MILK_HUNT_MAX_LOOPS", "140"))
        found_milk = False
        found_offer = False
        last_milk_offer: Optional[Dict[str, Any]] = None
        prev_pairs_count = len(_extract_pairs(history))
        discovered_biomes: List[str] = []
        biome_explore_counts: Dict[str, int] = {}
        biome_probe_events: List[Dict[str, Any]] = []
        current_resources: Dict[str, float] = _extract_resource_map(snap)

        for loop_idx in range(max_loops):
            if args.probe_each_loop:
                if loop_idx % max(1, int(args.grid_refresh_every)) == 0:
                    history.append(_run_turn(turn, "grid_snapshot"))
                    turn += 1
                loop_biomes = _extract_biomes(history)
                if loop_biomes:
                    loop_biome = min(loop_biomes, key=lambda b: (biome_explore_counts.get(b, 0), b))
                    if loop_biome not in discovered_biomes:
                        discovered_biomes.append(loop_biome)
                    biome_explore_counts[loop_biome] = biome_explore_counts.get(loop_biome, 0) + 1
                    loop_probe_row = _run_turn(turn, "probe_cycle", biome=loop_biome)
                    history.append(loop_probe_row)
                    turn += 1
                    loop_probe = loop_probe_row.get("probe", {}) if isinstance(loop_probe_row, dict) else {}
                    loop_probe_ok = bool(isinstance(loop_probe, dict) and loop_probe.get("success", False))
                    biome_probe_events.append(
                        {
                            "source": "loop_probe",
                            "loop": loop_idx + 1,
                            "biome": loop_biome,
                            "ok": loop_probe_ok,
                            "probe": loop_probe if isinstance(loop_probe, dict) else {},
                        }
                    )

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
            eligible_delivery = _eligible_delivery_offer_indices(offers, args.strict_biome_economy, current_resources)
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
                        args.strict_biome_economy,
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
                    args.strict_biome_economy,
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
                        if res and qty > 0 and not args.strict_biome_economy:
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

        final_pairs = _extract_pairs(history)
        summary = {
            "found_milk_pair": found_milk,
            "found_milk_offer": found_offer,
            "milk_offer": last_milk_offer,
            "known_pairs_count": len(final_pairs),
            "known_pairs": final_pairs,
            "turns_executed": len(history),
            "errors_seen_during_boot": error_lines,
            "max_loops": max_loops,
            "strict_biome_economy": args.strict_biome_economy,
            "load_slot": load_slot,
            "load_alias": load_alias,
            "biome_discovery_order": discovered_biomes,
            "biome_explore_counts": biome_explore_counts,
            "biome_probe_events": biome_probe_events,
            "turn_delay_s": TURN_DELAY_S,
            "probe_delay_s": PROBE_DELAY_S,
            "probe_each_loop": bool(args.probe_each_loop),
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
