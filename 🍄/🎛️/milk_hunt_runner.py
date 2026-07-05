#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys
from collections import deque
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

from milk_hunt_console import (
    Console,
    default_listener_stdout,
    default_rig_log_profile,
    default_wait_progress_seconds,
    resolve_console_profile,
)
from milk_hunt_paths import project_root
from milk_hunt_io import write_json
from policy_graph_runtime import (
    action_limits_for_action,
    action_limits_for_action_from_graph,
    profile_graph_path as runtime_policy_graph_path,
)
from profiles import get_profile_name_for_save, get_save_path, resolve_save_spec
from milk_hunt_summary import (
    add_milk_pair_index,
    apply_profile_metrics,
    build_common_summary_fields,
    policy_action_breakdown,
    market_projection_summary,
    vocab_milestone_fields,
)
from milk_hunt_runtime_config import get_cfg_bool, get_cfg_float, get_cfg_int, get_cfg_str, load_json_config
from milk_hunt_strategy import Strategy, load_strategy
from rig_client import RigClient


MILK = "\U0001F37C"
PROJECT_ROOT = project_root()
_RIG = RigClient(root_from_file=Path(__file__))
FACTIONS_PATH = PROJECT_ROOT / "Core" / "Factions" / "data" / "factions.json"
_CONSOLE = Console("quiet")
_TURN_PROGRESS_INTERVAL_S = 30.0


class TurnTimeoutError(TimeoutError):
    def __init__(self, turn_id: int, action: str, timeout_s: float) -> None:
        super().__init__(f"turn={turn_id} action={action} timeout_waiting_for_result timeout_s={timeout_s:.1f}")
        self.turn_id = int(turn_id)
        self.action = str(action)
        self.timeout_s = float(timeout_s)


def _set_console_profile(profile: str) -> None:
    global _CONSOLE
    _CONSOLE = Console(profile)


def _set_turn_progress_interval(seconds: float) -> None:
    global _TURN_PROGRESS_INTERVAL_S
    _TURN_PROGRESS_INTERVAL_S = max(0.0, float(seconds))


def _safe_print(msg: str, channel: str = "info") -> None:
    _CONSOLE.log(msg, channel)


def _json_load_lines(path: Path) -> List[Dict[str, Any]]:
    return RigClient.json_load_lines(path)


def _clear_rig_files() -> None:
    _RIG.clear_rig_files()


def _find_listener_pids() -> List[int]:
    return RigClient.find_listener_pids(xdg=_RIG.xdg_root)


def _kill_existing_listeners() -> None:
    RigClient.kill_existing_listeners(xdg=_RIG.xdg_root)


def _start_listener(
    load_slot: Optional[int] = None,
    scenario_id: str = "default",
    display_mode: str = "headless",
    allow_resource_injection: Optional[bool] = None,
    listener_stdout: str = "null",
    listener_log_path: Optional[Path] = None,
    rig_log_profile: Optional[str] = None,
    rig_log_category_levels: Optional[str] = None,
    extra_env: Optional[Dict[str, str]] = None,
) -> Any:
    return _RIG.start_listener(
        load_slot=load_slot,
        scenario_id=scenario_id,
        display_mode=display_mode,
        allow_resource_injection=allow_resource_injection,
        listener_stdout=listener_stdout,
        listener_log_path=listener_log_path,
        rig_log_profile=rig_log_profile,
        rig_log_category_levels=rig_log_category_levels,
        extra_env=extra_env,
    )


def _wait_for_ready(proc: Any, timeout_s: float = 60.0) -> List[str]:
    return RigClient.wait_for_ready(proc, timeout_s=timeout_s)


def _queue_turn(payload: Dict[str, Any]) -> None:
    _RIG.queue_turn(payload)


def _wait_for_turn(turn_id: int, timeout_s: float = 10.0) -> Optional[Dict[str, Any]]:
    return _RIG.wait_for_turn(turn_id, timeout_s=timeout_s)


def _run_turn(turn_id: int, action: str, **kwargs: Any) -> Dict[str, Any]:
    timeout_s = kwargs.pop("timeout_s", None)
    progress_interval_s = kwargs.pop("progress_interval_s", _TURN_PROGRESS_INTERVAL_S)
    if timeout_s is None:
        if action in {"complete_quest", "complete_or_claim", "claim_quest"}:
            timeout_s = 120.0
        elif action in {"active_quests"}:
            timeout_s = 45.0
        elif action in {"quest_cycle_step"}:
            timeout_s = 300.0
        elif action in {"policy_snapshot"}:
            timeout_s = 20.0
        elif action in {"offer_quests", "accept_offer", "known_icons", "resource_snapshot"}:
            timeout_s = 20.0
        elif action in {"grid_snapshot"}:
            timeout_s = 20.0
        elif action in {"probe_cycle", "discover_biome"}:
            timeout_s = 20.0
        elif action in {"time_skip"}:
            timeout_s = 45.0
        elif action == "victory_lap":
            timeout_s = 180.0
        elif action in {"load_game", "load_game_path", "save_game", "save_game_path"}:
            timeout_s = 30.0
        else:
            timeout_s = 10.0
    row = _RIG.run_turn(
        turn_id,
        action,
        timeout_s=float(timeout_s),
        progress_interval_s=float(progress_interval_s),
        **kwargs,
    )
    if isinstance(row, dict) and row.get("error") == "timeout_waiting_for_result":
        raise TurnTimeoutError(turn_id=turn_id, action=action, timeout_s=float(timeout_s))
    return row


def _extract_policy_icons(rows: List[Dict[str, Any]]) -> List[Dict[str, str]]:
    icons: List[Dict[str, str]] = []
    for row in rows:
        if row.get("action") == "known_icons":
            val = row.get("pairs", [])
            if isinstance(val, list):
                icons = val
        elif row.get("action") == "policy_snapshot":
            policy_snapshot = row.get("policy_snapshot", {})
            if isinstance(policy_snapshot, dict):
                val = policy_snapshot.get("known_icons", [])
                if isinstance(val, list):
                    icons = val
    return icons


def _contains_milk_icon(icons: List[Dict[str, str]]) -> bool:
    for p in icons:
        if p.get("north") == MILK or p.get("south") == MILK:
            return True
    return False


def _extract_biomes(rows: List[Dict[str, Any]]) -> List[str]:
    biomes: List[str] = []
    for row in rows:
        action = row.get("action")
        if action == "grid_snapshot":
            grid = row.get("grid", {})
            if not isinstance(grid, dict):
                continue
            val = grid.get("biomes", [])
            if not isinstance(val, list):
                continue
            biomes = [str(b) for b in val if isinstance(b, str) and b]
        elif action == "policy_snapshot":
            policy_snapshot = row.get("policy_snapshot", {})
            if not isinstance(policy_snapshot, dict):
                continue
            val = policy_snapshot.get("biomes", [])
            if not isinstance(val, list):
                continue
            biomes = [str(b) for b in val if isinstance(b, str) and b]
    return biomes


def _extract_policy_snapshot(row: Dict[str, Any]) -> Dict[str, Any]:
    if not isinstance(row, dict):
        return {}
    payload = row.get("policy_snapshot", {})
    return payload if isinstance(payload, dict) else {}


def _extract_policy_icon_payload(row: Dict[str, Any]) -> List[Dict[str, Any]]:
    payload = _extract_policy_snapshot(row)
    icons = payload.get("known_icons", [])
    return icons if isinstance(icons, list) else []


def _extract_policy_biomes(row: Dict[str, Any]) -> List[str]:
    payload = _extract_policy_snapshot(row)
    raw = payload.get("biomes", [])
    if not isinstance(raw, list):
        return []
    return [str(b) for b in raw if isinstance(b, str) and b]


def _extract_policy_active_quests(row: Dict[str, Any]) -> List[Dict[str, Any]]:
    payload = _extract_policy_snapshot(row)
    quests = payload.get("active_quests", [])
    return quests if isinstance(quests, list) else []


def _run_policy_snapshot(
    turn: int,
    history: List[Dict[str, Any]],
    include_grid: bool = False,
    include_offers: bool = False,
) -> tuple[int, Dict[str, Any]]:
    row = _run_turn(turn, "policy_snapshot", include_offers=include_offers, include_grid=include_grid)
    history.append(row)
    return turn + 1, row


def _tail_lines(path: Path, max_lines: int = 6) -> List[str]:
    if not path.exists():
        return []
    try:
        data = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return []
    if max_lines <= 0:
        return []
    return data[-max_lines:]


def _tail_json_rows(path: Path, max_rows: int = 6) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    for line in _tail_lines(path, max_lines=max_rows):
        raw = line.strip()
        if not raw:
            continue
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            payload = {"raw": raw}
        if isinstance(payload, dict):
            rows.append(payload)
    return rows


def _file_size(path: Optional[Path]) -> int:
    if path is None:
        return 0
    try:
        return int(path.stat().st_size)
    except OSError:
        return 0


def _read_new_lines(path: Optional[Path], start_offset: int = 0, max_lines: int = 4000) -> List[str]:
    if path is None or not path.exists():
        return []
    try:
        with path.open("r", encoding="utf-8", errors="replace") as handle:
            if start_offset > 0:
                handle.seek(start_offset)
            data = handle.read().splitlines()
    except OSError:
        return []
    if max_lines > 0 and len(data) > max_lines:
        return data[-max_lines:]
    return data


def _extract_boot_script_errors(lines: List[str]) -> List[str]:
    patterns = (
        "SCRIPT ERROR:",
        "Parse Error:",
        "Compile Error:",
        "Failed to load script",
        "Could not preload resource script",
        "Could not resolve script",
    )
    out: List[str] = []
    for ln in lines:
        text = str(ln or "")
        if any(token in text for token in patterns):
            out.append(text)
    return out


def _git_metadata(max_dirty_files: int = 32) -> Dict[str, Any]:
    branch = ""
    commit = ""
    dirty_files: List[str] = []
    try:
        branch_proc = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=str(PROJECT_ROOT),
            capture_output=True,
            text=True,
            check=False,
        )
        branch = branch_proc.stdout.strip()
    except Exception:
        branch = ""
    try:
        commit_proc = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=str(PROJECT_ROOT),
            capture_output=True,
            text=True,
            check=False,
        )
        commit = commit_proc.stdout.strip()
    except Exception:
        commit = ""
    try:
        dirty_proc = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=str(PROJECT_ROOT),
            capture_output=True,
            text=True,
            check=False,
        )
        lines = [ln.rstrip() for ln in dirty_proc.stdout.splitlines() if ln.strip()]
        dirty_files = lines[: max(0, int(max_dirty_files))]
        dirty_count = len(lines)
    except Exception:
        dirty_count = -1
    return {
        "git_branch": branch,
        "git_commit": commit,
        "git_dirty_count": dirty_count,
        "git_dirty_files": dirty_files,
    }


def _compact_diag_row(row: Dict[str, Any]) -> Dict[str, Any]:
    out: Dict[str, Any] = {}
    for key in ("turn", "action", "ok", "duration_ms", "error"):
        if key in row:
            out[key] = row.get(key)
    if "quest_id" in row:
        out["quest_id"] = row.get("quest_id")
    if "accepted" in row:
        out["accepted"] = row.get("accepted")
    if "completed" in row:
        out["completed"] = row.get("completed")
    if "completed_or_claimed" in row:
        out["completed_or_claimed"] = row.get("completed_or_claimed")
    if "claimed" in row:
        out["claimed"] = row.get("claimed")
    if "offers" in row and isinstance(row.get("offers"), list):
        out["offers_count"] = len(row["offers"])
    if "quests" in row and isinstance(row.get("quests"), list):
        out["quests_count"] = len(row["quests"])
    return out


def _compact_batcher_metrics(metrics: Dict[str, Any]) -> Dict[str, Any]:
    out: Dict[str, Any] = {}
    for key in (
        "physics_fps",
        "phrame_cap_hz",
        "buffer_depth",
        "packets_pending",
        "threads_running",
        "watchdog_stall_warnings",
        "avg_batch_time_ms",
        "last_batch_time_ms",
    ):
        if key in metrics:
            out[key] = metrics.get(key)
    return out


def _runtime_profile_env_overrides(profile_name: str) -> Dict[str, str]:
    profile = str(profile_name or "default").strip().lower()
    if profile == "quantum_fiber_nodes":
        # Keep C++ lookahead active, cap phrame rate, and lower queue polling churn.
        return {
            "SW_MAX_PHRAME_HZ": "10",
            "SW_STRIDE_SCALES_RESOLUTION": "1",
            "RIG_QUEUE_POLL_MS": "100",
            "RIG_DISABLE_MI": "1",
            "RIG_DISABLE_FORCE": "1",
        }
    if profile == "io_min":
        return {
            "RIG_QUEUE_POLL_MS": "16",
            "RIG_LOG_PROFILE": "quiet",
        }
    return {}


def _compute_profile_metrics(history: List[Dict[str, Any]], initial_pairs: int, final_pairs: int) -> Dict[str, Any]:
    metrics: Dict[str, Any] = {
        "quest_offer_cycles": 0,
        "quest_offers_seen": 0,
        "quest_offers_accepted": 0,
        "quest_completions": 0,
        "quest_complete_or_claim": 0,
        "quest_claims": 0,
        "active_quest_reads": 0,
        "probe_cycles_total": 0,
        "probe_cycles_success": 0,
        "time_skip_actions": 0,
        "time_skip_total_phrames": 0,
        "time_skip_total_evolved_steps": 0,
        "lindblad_drain_actions": 0,
        "lindblad_drains_established": 0,
        "lindblad_drain_charged_total": 0,
        "lindblad_drain_persistent_total": 0,
        "lindblad_drain_already_active_total": 0,
        "resource_snapshot_calls": 0,
        "policy_snapshot_calls": 0,
        "known_icon_reads": 0,
        "vocab_pairs_initial": max(0, int(initial_pairs)),
        "vocab_pairs_final": max(0, int(final_pairs)),
        "vocab_pairs_learned": max(0, int(final_pairs) - int(initial_pairs)),
    }

    for row in history:
        if not isinstance(row, dict):
            continue
        action = str(row.get("action", "") or "")
        if action == "offer_quests":
            metrics["quest_offer_cycles"] += 1
            offers = row.get("offers", [])
            if isinstance(offers, list):
                metrics["quest_offers_seen"] += len(offers)
        elif action == "accept_offer":
            if bool(row.get("accepted", False)):
                metrics["quest_offers_accepted"] += 1
        elif action == "complete_quest":
            if bool(row.get("completed", False)):
                metrics["quest_completions"] += 1
        elif action == "complete_or_claim":
            if bool(row.get("completed_or_claimed", False)):
                metrics["quest_complete_or_claim"] += 1
        elif action == "claim_quest":
            if bool(row.get("claimed", False)):
                metrics["quest_claims"] += 1
        elif action == "active_quests":
            metrics["active_quest_reads"] += 1
        elif action == "probe_cycle":
            metrics["probe_cycles_total"] += 1
            probe = row.get("probe", {})
            if isinstance(probe, dict) and bool(probe.get("success", False)):
                metrics["probe_cycles_success"] += 1
        elif action == "time_skip":
            metrics["time_skip_actions"] += 1
            payload = row.get("time_skip", {})
            if isinstance(payload, dict):
                try:
                    metrics["time_skip_total_phrames"] += int(payload.get("phrames", 0) or 0)
                except (TypeError, ValueError):
                    pass
                try:
                    metrics["time_skip_total_evolved_steps"] += int(payload.get("evolved_steps", 0) or 0)
                except (TypeError, ValueError):
                    pass
        elif action == "lindblad_drain":
            metrics["lindblad_drain_actions"] += 1
            payload = row.get("drain_result", {})
            if not isinstance(payload, dict):
                continue
            try:
                charged = int(payload.get("charged_count", 0) or 0)
            except (TypeError, ValueError):
                charged = 0
            try:
                persistent = int(payload.get("persistent_enabled", 0) or 0)
            except (TypeError, ValueError):
                persistent = 0
            try:
                already = int(payload.get("already_active", 0) or 0)
            except (TypeError, ValueError):
                already = 0
            metrics["lindblad_drain_charged_total"] += max(0, charged)
            metrics["lindblad_drain_persistent_total"] += max(0, persistent)
            metrics["lindblad_drain_already_active_total"] += max(0, already)
            if bool(payload.get("success", False)) or charged > 0 or persistent > 0 or already > 0:
                metrics["lindblad_drains_established"] += 1
        elif action == "resource_snapshot":
            metrics["resource_snapshot_calls"] += 1
        elif action == "policy_snapshot":
            metrics["policy_snapshot_calls"] += 1
        elif action == "known_icons":
            metrics["known_icon_reads"] += 1
        elif action == "quest_cycle_step":
            payload = row.get("quest_cycle_step", {})
            if not isinstance(payload, dict):
                continue
            execution = payload.get("execution", {})
            if not isinstance(execution, dict):
                continue
            executed_action = str(execution.get("action", "") or "")
            if executed_action == "probe_cycle":
                metrics["probe_cycles_total"] += 1
                probe = execution.get("probe", {})
                if isinstance(probe, dict) and bool(probe.get("success", False)):
                    metrics["probe_cycles_success"] += 1
            elif executed_action == "time_skip":
                metrics["time_skip_actions"] += 1
                skip_payload = execution.get("time_skip", {})
                if isinstance(skip_payload, dict):
                    try:
                        metrics["time_skip_total_phrames"] += int(skip_payload.get("phrames", 0) or 0)
                    except (TypeError, ValueError):
                        pass
                    try:
                        metrics["time_skip_total_evolved_steps"] += int(skip_payload.get("evolved_steps", 0) or 0)
                    except (TypeError, ValueError):
                        pass
            elif executed_action == "lindblad_drain":
                metrics["lindblad_drain_actions"] += 1
                drain = execution.get("drain_result", {})
                if isinstance(drain, dict):
                    try:
                        charged = int(drain.get("charged_count", 0) or 0)
                    except (TypeError, ValueError):
                        charged = 0
                    try:
                        persistent = int(drain.get("persistent_enabled", 0) or 0)
                    except (TypeError, ValueError):
                        persistent = 0
                    try:
                        already = int(drain.get("already_active", 0) or 0)
                    except (TypeError, ValueError):
                        already = 0
                    metrics["lindblad_drain_charged_total"] += max(0, charged)
                    metrics["lindblad_drain_persistent_total"] += max(0, persistent)
                    metrics["lindblad_drain_already_active_total"] += max(0, already)
                    if bool(drain.get("success", False)) or charged > 0 or persistent > 0 or already > 0:
                        metrics["lindblad_drains_established"] += 1
            elif executed_action == "quest_cycle":
                metrics["quest_offer_cycles"] += 1
                if bool(execution.get("accepted", False)):
                    metrics["quest_offers_accepted"] += 1
                if bool(execution.get("completed_after_accept", False)):
                    metrics["quest_complete_or_claim"] += 1
                completed_ids = execution.get("completed_ids", [])
                if isinstance(completed_ids, list):
                    metrics["quest_complete_or_claim"] += len(completed_ids)
                try:
                    metrics["quest_offers_seen"] += int(execution.get("offers_seen", 0) or 0)
                except (TypeError, ValueError):
                    pass

    return metrics


def _rig_timeout_diagnostics(turn_id: int, action: str) -> Dict[str, Any]:
    queue_path = _RIG.queue_file
    results_path = _RIG.results_file
    queue_tail = _tail_json_rows(queue_path, max_rows=8)
    results_tail = _tail_json_rows(results_path, max_rows=8)
    queue_tail_compact = [_compact_diag_row(row) for row in queue_tail]
    results_tail_compact = [_compact_diag_row(row) for row in results_tail]
    queue_last = queue_tail_compact[-1] if queue_tail_compact else {}
    results_last = results_tail_compact[-1] if results_tail_compact else {}
    try:
        queue_size = queue_path.stat().st_size if queue_path.exists() else 0
    except OSError:
        queue_size = -1
    try:
        results_size = results_path.stat().st_size if results_path.exists() else 0
    except OSError:
        results_size = -1

    return {
        "expected_turn": int(turn_id),
        "expected_action": str(action),
        "queue_path": str(queue_path),
        "results_path": str(results_path),
        "queue_size_bytes": queue_size,
        "results_size_bytes": results_size,
        "queue_tail_count": len(queue_tail),
        "results_tail_count": len(results_tail),
        "queue_last": queue_last,
        "results_last": results_last,
        "queue_tail": queue_tail_compact,
        "results_tail": results_tail_compact,
    }


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
    if d is not None and d >= 1:
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
    south = str(offer.get("reward_icon_south", "") or "")
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


def _heuristic_best_offer_index(
    offers: List[Dict[str, Any]],
    known_symbols: set,
    faction_sigs: Dict[str, Set[str]],
    distances: Dict[str, int],
    current_resources: Dict[str, float],
    strict_biome_economy: bool,
    strategy: Strategy,
    candidate_indices: Optional[List[int]] = None,
) -> int:
    """Heuristic offer scorer used when the engine policy does not choose."""
    indices = candidate_indices if candidate_indices else list(range(len(offers)))
    if not indices:
        return 0
    best_idx = 0
    best_score = -10**9
    for i in indices:
        offer = offers[i]
        n = str(offer.get("reward_icon_north", "") or "")
        s = str(offer.get("reward_icon_south", "") or "")
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
            if best_sig_dist >= 1:
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
    policy_snapshot = row.get("policy_snapshot", {})
    if isinstance(policy_snapshot, dict):
        policy_resources = policy_snapshot.get("resources", {})
        if isinstance(policy_resources, dict):
            out_policy: Dict[str, float] = {}
            for emoji, amount in policy_resources.items():
                if not isinstance(emoji, str) or not emoji:
                    continue
                try:
                    out_policy[emoji] = float(amount)
                except (TypeError, ValueError):
                    continue
            if out_policy:
                return out_policy
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


def _parse_biome_list(raw: Optional[str]) -> List[str]:
    if not raw:
        return []
    out: List[str] = []
    seen: Set[str] = set()
    for token in str(raw).split(","):
        name = token.strip()
        if not name or name in seen:
            continue
        out.append(name)
        seen.add(name)
    return out


def _parse_emoji_list(values: List[str]) -> List[str]:
    out: List[str] = []
    seen: Set[str] = set()
    for raw in values:
        for token in str(raw).split(","):
            emoji = token.strip()
            if not emoji or emoji in seen:
                continue
            seen.add(emoji)
            out.append(emoji)
    return out


def _parse_token_list(values: List[str]) -> List[str]:
    out: List[str] = []
    seen: Set[str] = set()
    for raw in values:
        for token in str(raw).split(","):
            val = token.strip()
            if not val or val in seen:
                continue
            seen.add(val)
            out.append(val)
    return out


def _critical_floor_pressure(resources: Dict[str, float], floors: Dict[str, float]) -> float:
    pressure = 0.0
    for emoji in ("🍞", "❄️", "👥"):
        floor = float(floors.get(emoji, 0.0))
        if floor <= 0.0:
            continue
        have = float(resources.get(emoji, 0.0))
        if have < floor:
            pressure += (floor - have) / max(1.0, floor)
    return pressure


def _evaluate_action_gate(
    action_name: str,
    limits: Dict[str, Any],
    *,
    loop_number: int,
    loop_action_count: int,
    total_action_count: int,
    pair_count: int,
    known_biomes_count: int,
    current_resources: Dict[str, float],
    resource_floors: Dict[str, float],
    cooldown_until_loop: int,
) -> Tuple[bool, List[str], float]:
    reasons: List[str] = []
    pressure = _critical_floor_pressure(current_resources, resource_floors)
    if not bool(limits.get("enabled", True)):
        reasons.append("disabled")
    min_loop = int(limits.get("min_loop", 1) or 1)
    loop_mod = int(limits.get("loop_mod", 1) or 1)
    max_per_loop = int(limits.get("max_per_loop", 999999) or 999999)
    max_total_actions = int(
        limits.get("max_total_actions", limits.get("max_total_locks", 999999)) or 999999
    )
    pairs_soft_cap = int(limits.get("pairs_soft_cap", 999999) or 999999)
    min_known_biomes = int(limits.get("min_known_biomes", 0) or 0)
    critical_pressure_cap = float(limits.get("critical_pressure_cap", 999999.0) or 999999.0)
    if loop_number < min_loop:
        reasons.append("before_min_loop")
    if loop_mod > 1 and loop_number >= min_loop and ((loop_number - min_loop) % loop_mod != 0):
        reasons.append("loop_mod_skip")
    if loop_action_count >= max_per_loop:
        reasons.append("per_loop_cap")
    if total_action_count >= max_total_actions:
        reasons.append("total_action_cap")
    if pair_count > pairs_soft_cap:
        reasons.append("pairs_soft_cap")
    if known_biomes_count < min_known_biomes:
        reasons.append("known_biomes_gate")
    if pressure > critical_pressure_cap:
        reasons.append("critical_pressure")
    if loop_number <= cooldown_until_loop:
        reasons.append("cooldown")
    return (not reasons), reasons, pressure


def _encode_positions_for_rig(raw_positions: Any, limit: int = 0, offset: int = 0) -> List[List[int]]:
    out: List[List[int]] = []
    if not isinstance(raw_positions, list) or not raw_positions:
        return out
    normalized: List[List[int]] = []
    for entry in raw_positions:
        x_val: Any = None
        y_val: Any = None
        if isinstance(entry, (list, tuple)) and len(entry) >= 2:
            x_val, y_val = entry[0], entry[1]
        elif isinstance(entry, dict):
            x_val = entry.get("x")
            y_val = entry.get("y")
        elif isinstance(entry, str):
            txt = entry.strip()
            txt = txt.replace("(", "").replace(")", "").replace("[", "").replace("]", "")
            parts = [p.strip() for p in txt.split(",")]
            if len(parts) >= 2:
                x_val = parts[0]
                y_val = parts[1]
        if x_val is None or y_val is None:
            continue
        try:
            x = int(x_val)
            y = int(y_val)
        except (TypeError, ValueError):
            continue
        normalized.append([x, y])
    if not normalized:
        return out
    if limit <= 0 or limit >= len(normalized):
        return normalized
    start = offset % len(normalized) if offset > 0 else 0
    idx = start
    while len(out) < limit:
        out.append(normalized[idx])
        idx = (idx + 1) % len(normalized)
        if idx == start:
            break
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
        turn, snap_row = _run_policy_snapshot(turn, history, include_grid=False, include_offers=False)
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


def _resource_threshold_met(resources: Dict[str, float], threshold: Dict[str, float]) -> bool:
    if not threshold:
        return False
    for emoji, target in threshold.items():
        if float(resources.get(emoji, 0.0)) < float(target):
            return False
    return True


def _seconds_to_phrames(seconds: float, phrame_hz: float = 6.0) -> int:
    if seconds <= 0.0:
        return 0
    return max(1, int(round(float(seconds) * float(phrame_hz))))


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
    parser.add_argument(
        "--console-profile",
        choices=["quiet", "normal", "debug", "trace", "test"],
        default=None,
        help="Runner console verbosity profile",
    )
    parser.add_argument(
        "--wait-progress-seconds",
        type=float,
        default=None,
        help="Emit wait heartbeat every N seconds while turn is pending (0 disables)",
    )
    parser.add_argument("--load-slot", type=int, default=None, help="Boot the rig from a save slot")
    parser.add_argument(
        "--profile-save",
        type=str,
        default=None,
        help="Canonical profile save path or profile id from registry",
    )
    parser.add_argument(
        "--profile-save-index",
        type=str,
        default=None,
        help="Optional registry JSON path for profile-id resolution",
    )
    parser.add_argument("--scenario-id", type=str, default=None, help="Scenario id when not loading a slot")
    parser.add_argument(
        "--hunter-profile",
        type=str,
        default=None,
        help="Profile identity for policy tuning (e.g. granary_scout)",
    )
    parser.add_argument(
        "--hunter-policy",
        type=str,
        choices=["auto", "engine_policy", "quantum_register"],
        default=None,
        help="Decision policy mode (default: auto => engine_policy)",
    )
    parser.add_argument(
        "--policy-actions-per-loop",
        type=int,
        default=None,
        help="When engine_policy is active, number of quest_cycle_step actions per loop",
    )
    parser.add_argument(
        "--policy-epsilon",
        type=float,
        default=None,
        help="Engine policy exploration rate (0..1)",
    )
    parser.add_argument(
        "--policy-ucb-scale",
        type=float,
        default=None,
        help="Engine policy UCB exploration bonus scale",
    )
    parser.add_argument(
        "--policy-max-quest-actions-per-loop",
        type=int,
        default=None,
        help="When engine_policy is active, cap quest_cycle actions per loop to prevent degenerate quest spam",
    )
    parser.add_argument(
        "--policy-restrictions",
        dest="policy_restrictions",
        action="store_true",
        help="Enable runner-side policy action restrictions (quest caps / lock gating / forbid lists)",
    )
    parser.add_argument(
        "--no-policy-restrictions",
        dest="policy_restrictions",
        action="store_false",
        help="Disable runner-side policy action restrictions; keep full policy action space",
    )
    parser.add_argument(
        "--policy-forbid-action",
        action="append",
        default=[],
        help="Forbid policy actions globally (repeat or pass comma-separated values), e.g. --policy-forbid-action quest_cycle",
    )
    parser.add_argument(
        "--lock-offer-gate",
        dest="quest_cycle_gate",
        action="store_true",
        help="Override policy-graph lock gating on",
    )
    parser.add_argument(
        "--no-lock-offer-gate",
        dest="quest_cycle_gate",
        action="store_false",
        help="Override policy-graph lock gating off",
    )
    parser.add_argument(
        "--policy-reset-on-start",
        dest="policy_reset_on_start",
        action="store_true",
        help="Reset engine policy memory at run start instead of loading from save state",
    )
    parser.add_argument(
        "--no-policy-reset-on-start",
        dest="policy_reset_on_start",
        action="store_false",
        help="Keep engine policy memory from loaded save state",
    )
    parser.add_argument(
        "--policy-trace-limit",
        type=int,
        default=300,
        help="Maximum number of policy decision events to keep in summary",
    )
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
    parser.add_argument("--save-path-at-end", type=str, default=None, help="Save the run state to this path/alias before exit")
    parser.add_argument(
        "--reuse-listener",
        dest="reuse_listener",
        action="store_true",
        help="Reuse an existing rig listener instead of starting a new one",
    )
    parser.add_argument(
        "--no-reuse-listener",
        dest="reuse_listener",
        action="store_false",
        help="Do not reuse an existing rig listener",
    )
    parser.add_argument("--turn-start", type=int, default=1, help="Turn id to start at")
    parser.add_argument("--no-stop", action="store_true", help="Skip sending stop on exit")
    parser.add_argument("--no-clear-rig", action="store_true", help="Skip clearing rig queue/results files")
    parser.add_argument(
        "--target-turn-hz",
        type=float,
        default=0.0,
        help="Deprecated/no-op in phrame-driven mode (runner no longer uses wall-clock pacing)",
    )
    parser.add_argument(
        "--metrics-every",
        type=int,
        default=0,
        help="Sample batcher metrics every N loops (0 disables periodic sampling)",
    )
    parser.add_argument(
        "--runtime-profile",
        choices=["default", "quantum_fiber_nodes", "io_min"],
        default=None,
        help="Runtime env profile for listener startup and batcher path",
    )
    parser.add_argument(
        "--display-mode",
        choices=["headless", "headed"],
        default=None,
        help="Launch the rig headless or with a visible window",
    )
    parser.add_argument(
        "--policy-execution-backend",
        choices=["auto", "direct", "player_input"],
        default=None,
        help="Execute policy steps directly or through the player input path",
    )
    parser.add_argument(
        "--include-offer-reward-resources",
        dest="include_offer_reward_resources",
        action="store_true",
        help="Include reward_resources payload in offer_quests responses",
    )
    parser.add_argument(
        "--no-include-offer-reward-resources",
        dest="include_offer_reward_resources",
        action="store_false",
        help="Exclude reward_resources from offer_quests payload to reduce IO",
    )
    parser.add_argument(
        "--include-offer-market-projection",
        dest="include_offer_market_projection",
        action="store_true",
        help="Include market_projection payload in offer_quests responses",
    )
    parser.add_argument(
        "--no-include-offer-market-projection",
        dest="include_offer_market_projection",
        action="store_false",
        help="Exclude market_projection payload from offer_quests responses to reduce IO",
    )
    parser.add_argument(
        "--rig-listener-stdout",
        choices=["file", "pipe", "null"],
        default=None,
        help="Listener stdout mode (defaults from console profile)",
    )
    parser.add_argument(
        "--rig-listener-log",
        type=Path,
        default=None,
        help="Optional log file path when --rig-listener-stdout=file",
    )
    parser.add_argument(
        "--rig-log-profile",
        choices=["quiet", "normal", "debug", "trace", "test"],
        default=None,
        help="Rig listener VerboseConfig profile (defaults from console profile)",
    )
    parser.add_argument(
        "--rig-log-categories",
        type=str,
        default="",
        help="Optional category overrides, e.g. quest:debug,boot:warn",
    )
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
        "--require-clean-worktree",
        action="store_true",
        help="Fail fast when git working tree is dirty (reproducibility gate)",
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
        help="Maximum number of discover_biome (new biome unlock) attempts per run",
    )
    parser.add_argument(
        "--min-eagles-for-expansion",
        type=float,
        default=None,
        help="Minimum eagle stock before discover_biome is attempted",
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
    parser.add_argument(
        "--lindblad-drain-focus",
        dest="lindblad_drain_focus",
        action="store_true",
        help="Enable Lindblad-drain-first behavior before quest offer/accept loops",
    )
    parser.add_argument(
        "--no-lindblad-drain-focus",
        dest="lindblad_drain_focus",
        action="store_false",
        help="Disable Lindblad-drain-first behavior",
    )
    parser.add_argument(
        "--lindblad-drain-every",
        type=int,
        default=None,
        help="Run drain branch every N loops (default: 1 when enabled)",
    )
    parser.add_argument(
        "--lindblad-drain-max-biomes-per-loop",
        type=int,
        default=None,
        help="Maximum biomes to attempt for drain each drain loop",
    )
    parser.add_argument(
        "--lindblad-drain-max-plots",
        type=int,
        default=None,
        help="Maximum plot positions per drain action (0 means full biome selection)",
    )
    parser.add_argument(
        "--lindblad-drain-biomes",
        type=str,
        default=None,
        help="Comma-separated biome override order for drain branch",
    )
    parser.add_argument(
        "--lindblad-drain-slices",
        type=int,
        default=None,
        help="Micro-slices per selected biome each drain loop (weak time-scale control)",
    )
    parser.add_argument(
        "--lindblad-wait-seconds",
        type=float,
        default=None,
        help="Legacy wall-clock wait after drain branch (prefer --lindblad-wait-phrames)",
    )
    parser.add_argument(
        "--lindblad-wait-phrames",
        type=int,
        default=None,
        help="Deterministic phrames to time-skip after drain branch so passive channels accumulate",
    )
    parser.add_argument(
        "--lindblad-wait-for-resource",
        action="append",
        default=[],
        help="Wait target as EMOJI:AMOUNT (repeatable), e.g. --lindblad-wait-for-resource 🍞:140",
    )
    parser.add_argument(
        "--lindblad-wait-max-seconds",
        type=float,
        default=None,
        help="Legacy max wall-clock wait for threshold mode (converted to phrames when needed)",
    )
    parser.add_argument(
        "--lindblad-wait-poll-seconds",
        type=float,
        default=None,
        help="Legacy poll wall-clock interval for threshold mode (converted to phrames when needed)",
    )
    parser.add_argument(
        "--lindblad-wait-max-phrames",
        type=int,
        default=None,
        help="Maximum phrames to advance while waiting for threshold resources",
    )
    parser.add_argument(
        "--lindblad-wait-poll-phrames",
        type=int,
        default=None,
        help="Phrases per threshold-wait poll tick",
    )
    parser.add_argument(
        "--stride",
        type=int,
        default=None,
        help="Set observation stride on all biomes at start (0=locked, 1=normal, 2+=fast forward)",
    )
    parser.add_argument(
        "--resolution",
        type=float,
        default=None,
        help="Set evolution resolution dt on all biomes at start (seconds, e.g. 0.02)",
    )
    parser.add_argument(
        "--advanced-mode",
        dest="advanced_mode",
        action="store_true",
        help="Enable advanced timescale-objective rig path (shared with user workbench semantics)",
    )
    parser.add_argument(
        "--no-advanced-mode",
        dest="advanced_mode",
        action="store_false",
        help="Disable advanced timescale-objective rig path",
    )
    parser.add_argument(
        "--timescale-focus-emoji",
        action="append",
        default=[],
        help="Objective focus emoji (repeatable or comma-separated), e.g. --timescale-focus-emoji 🍞,👥",
    )
    parser.add_argument(
        "--timescale-top-k",
        type=int,
        default=None,
        help="Top-K emoji rankings to request from the objective projection",
    )
    parser.add_argument(
        "--timescale-target-gain",
        type=float,
        default=None,
        help="Objective target_gain_per_wait value",
    )
    parser.add_argument(
        "--timescale-horizon-min-phrames",
        type=int,
        default=None,
        help="Objective minimum wait horizon in phrames",
    )
    parser.add_argument(
        "--timescale-horizon-max-phrames",
        type=int,
        default=None,
        help="Objective maximum wait horizon in phrames",
    )
    parser.add_argument(
        "--timescale-floor",
        action="append",
        default=[],
        help="Objective resource floor override as EMOJI:AMOUNT (repeatable)",
    )
    parser.set_defaults(enforce_primary_resource_floors=True, allow_rig_resource_injection=True, reuse_listener=False)
    parser.set_defaults(victory_lap=True)
    parser.set_defaults(strict_biome_economy=True)
    parser.set_defaults(include_offer_reward_resources=False)
    parser.set_defaults(include_offer_market_projection=False)
    parser.set_defaults(lindblad_drain_focus=None)
    parser.set_defaults(advanced_mode=None)
    parser.set_defaults(policy_reset_on_start=None)
    parser.set_defaults(quest_cycle_gate=None)
    parser.set_defaults(policy_restrictions=None)
    return parser


def main() -> int:
    args = _build_parser().parse_args()
    cfg = load_json_config(args.config)
    console_profile = resolve_console_profile(args.console_profile, cfg)
    _set_console_profile(console_profile)
    strategy = load_strategy(args.strategy)
    load_slot = args.load_slot
    profile_save = args.profile_save
    profile_save_index = args.profile_save_index
    scenario_id = args.scenario_id
    hunter_profile = args.hunter_profile
    hunter_policy_mode = args.hunter_policy
    strict_biome_economy = args.strict_biome_economy
    max_loops = args.max_loops
    wait_progress_seconds = args.wait_progress_seconds
    display_mode = args.display_mode
    policy_execution_backend = args.policy_execution_backend

    if wait_progress_seconds is None:
        wait_progress_seconds = get_cfg_float(cfg, "wait_progress_seconds")
    if wait_progress_seconds is None and os.environ.get("MILK_HUNT_WAIT_PROGRESS_SECONDS", "") != "":
        wait_progress_seconds = float(os.environ["MILK_HUNT_WAIT_PROGRESS_SECONDS"])
    if wait_progress_seconds is None:
        wait_progress_seconds = default_wait_progress_seconds(console_profile)
    _set_turn_progress_interval(float(wait_progress_seconds))

    rig_listener_stdout = args.rig_listener_stdout
    if not rig_listener_stdout:
        rig_listener_stdout = get_cfg_str(cfg, "rig_listener_stdout")
    if not rig_listener_stdout and os.environ.get("MILK_HUNT_RIG_LISTENER_STDOUT", "") != "":
        rig_listener_stdout = os.environ["MILK_HUNT_RIG_LISTENER_STDOUT"]
    if not rig_listener_stdout:
        rig_listener_stdout = default_listener_stdout(console_profile)
    listener_log_path = args.rig_listener_log
    if rig_listener_stdout == "file" and listener_log_path is None:
        listener_log_path = Path(__file__).resolve().parent / "logs" / "rig_listener.log"
    if args.fail_on_boot_script_errors and rig_listener_stdout == "null":
        rig_listener_stdout = "file"
        if listener_log_path is None:
            listener_log_path = Path(__file__).resolve().parent / "logs" / "rig_listener.log"
        _safe_print("milk-hunt: fail-on-boot-script-errors forcing listener stdout mode to file", "detail")

    rig_log_profile = args.rig_log_profile
    if not rig_log_profile:
        rig_log_profile = get_cfg_str(cfg, "rig_log_profile")
    if not rig_log_profile and os.environ.get("RIG_LOG_PROFILE", "") != "":
        rig_log_profile = os.environ["RIG_LOG_PROFILE"]
    if not rig_log_profile:
        rig_log_profile = default_rig_log_profile(console_profile)

    rig_log_categories = args.rig_log_categories
    if not rig_log_categories:
        rig_log_categories = get_cfg_str(cfg, "rig_log_categories")
    if not rig_log_categories and os.environ.get("RIG_LOG_CATEGORY_LEVELS", "") != "":
        rig_log_categories = os.environ["RIG_LOG_CATEGORY_LEVELS"]

    if max_loops is None:
        max_loops = get_cfg_int(cfg, "max_loops")
    if max_loops is None and os.environ.get("MILK_HUNT_MAX_LOOPS", "") != "":
        max_loops = int(os.environ["MILK_HUNT_MAX_LOOPS"])
    if max_loops is None:
        max_loops = 140

    if not display_mode:
        display_mode = get_cfg_str(cfg, "display_mode")
    if not display_mode and os.environ.get("MILK_HUNT_DISPLAY_MODE", "") != "":
        display_mode = os.environ["MILK_HUNT_DISPLAY_MODE"]
    if not display_mode:
        display_mode = "headless"

    if not policy_execution_backend:
        policy_execution_backend = get_cfg_str(cfg, "policy_execution_backend")
    if not policy_execution_backend and os.environ.get("MILK_HUNT_POLICY_EXECUTION_BACKEND", "") != "":
        policy_execution_backend = os.environ["MILK_HUNT_POLICY_EXECUTION_BACKEND"]
    if not policy_execution_backend or policy_execution_backend == "auto":
        # player_input works in headless via synthetic InputEventKey routing — same surfaces as human.
        # Use RIG_POLICY_EXECUTION_BACKEND=direct or --policy-execution-backend=direct to opt out.
        policy_execution_backend = "player_input"
    elif display_mode == "headed":
        policy_execution_backend = "player_input"

    if load_slot is None:
        load_slot = get_cfg_int(cfg, "load_slot")
    if load_slot is None and os.environ.get("MILK_HUNT_LOAD_SLOT", "") != "":
        load_slot = int(os.environ["MILK_HUNT_LOAD_SLOT"])

    if not profile_save:
        profile_save = get_cfg_str(cfg, "profile_save")
    if not profile_save and os.environ.get("MILK_HUNT_PROFILE_SAVE", "") != "":
        profile_save = os.environ["MILK_HUNT_PROFILE_SAVE"]
    if not profile_save_index:
        profile_save_index = get_cfg_str(cfg, "profile_save_index")
    if not profile_save_index and os.environ.get("MILK_HUNT_PROFILE_SAVE_INDEX", "") != "":
        profile_save_index = os.environ["MILK_HUNT_PROFILE_SAVE_INDEX"]

    if scenario_id is None:
        scenario_id = get_cfg_str(cfg, "scenario_id")
    if not scenario_id:
        scenario_id = "default"

    if not hunter_profile:
        hunter_profile = get_cfg_str(cfg, "hunter_profile")
    if not hunter_profile and os.environ.get("MILK_HUNT_PROFILE", "") != "":
        hunter_profile = os.environ["MILK_HUNT_PROFILE"]
    if not hunter_profile:
        hunter_profile = "default"

    resolved_profile_save: Optional[str] = None
    if profile_save:
        resolved_profile_save = resolve_save_spec(profile_save, profile_save_index)
        load_slot = None
        _safe_print(f"milk-hunt: using profile-save '{resolved_profile_save}'", "detail")
        if not args.hunter_profile:
            mapped = get_save_path(profile_save, profile_save_index)
            if mapped:
                hunter_profile = profile_save
            else:
                mapped_name = get_profile_name_for_save(resolved_profile_save, profile_save_index)
                if mapped_name:
                    hunter_profile = mapped_name
    elif load_slot is None and hunter_profile:
        mapped_profile_save = get_save_path(hunter_profile, profile_save_index)
        if mapped_profile_save:
            resolved_profile_save = mapped_profile_save
            _safe_print(
                f"milk-hunt: hunter-profile '{hunter_profile}' resolved to profile-save '{mapped_profile_save}'",
                "detail",
            )

    if hunter_policy_mode is None:
        hunter_policy_mode = get_cfg_str(cfg, "hunter_policy")
    if not hunter_policy_mode and os.environ.get("MILK_HUNT_POLICY", "") != "":
        hunter_policy_mode = os.environ["MILK_HUNT_POLICY"]
    if hunter_policy_mode not in {"auto", "engine_policy", "quantum_register"}:
        hunter_policy_mode = "auto"
    # Default migration target: decision authority in-engine.
    if hunter_policy_mode == "auto":
        hunter_policy_mode = "engine_policy"

    policy_actions_per_loop = args.policy_actions_per_loop
    if policy_actions_per_loop is None:
        policy_actions_per_loop = get_cfg_int(cfg, "policy_actions_per_loop")
    if policy_actions_per_loop is None and os.environ.get("MILK_HUNT_POLICY_ACTIONS_PER_LOOP", "") != "":
        policy_actions_per_loop = int(os.environ["MILK_HUNT_POLICY_ACTIONS_PER_LOOP"])
    if policy_actions_per_loop is None:
        policy_actions_per_loop = 6
    policy_actions_per_loop = max(1, int(policy_actions_per_loop))

    policy_epsilon = args.policy_epsilon
    if policy_epsilon is None:
        policy_epsilon = get_cfg_float(cfg, "policy_epsilon")
    if policy_epsilon is None and os.environ.get("MILK_HUNT_POLICY_EPSILON", "") != "":
        policy_epsilon = float(os.environ["MILK_HUNT_POLICY_EPSILON"])
    if policy_epsilon is None:
        policy_epsilon = 0.18
    policy_epsilon = max(0.0, min(1.0, float(policy_epsilon)))

    policy_ucb_scale = args.policy_ucb_scale
    if policy_ucb_scale is None:
        policy_ucb_scale = get_cfg_float(cfg, "policy_ucb_scale")
    if policy_ucb_scale is None and os.environ.get("MILK_HUNT_POLICY_UCB_SCALE", "") != "":
        policy_ucb_scale = float(os.environ["MILK_HUNT_POLICY_UCB_SCALE"])
    if policy_ucb_scale is None:
        policy_ucb_scale = 1.10
    policy_ucb_scale = max(0.0, float(policy_ucb_scale))

    policy_reset_on_start = args.policy_reset_on_start
    if policy_reset_on_start is None:
        policy_reset_on_start = get_cfg_bool(cfg, "policy_reset_on_start")
    if policy_reset_on_start is None and os.environ.get("MILK_HUNT_POLICY_RESET_ON_START", "") != "":
        policy_reset_on_start = os.environ["MILK_HUNT_POLICY_RESET_ON_START"].strip().lower() in {
            "1",
            "true",
            "yes",
            "on",
        }
    if policy_reset_on_start is None:
        policy_reset_on_start = False

    policy_max_quest_actions_per_loop = args.policy_max_quest_actions_per_loop
    if policy_max_quest_actions_per_loop is None:
        policy_max_quest_actions_per_loop = get_cfg_int(cfg, "policy_max_quest_actions_per_loop")
    if policy_max_quest_actions_per_loop is None and os.environ.get("MILK_HUNT_POLICY_MAX_QUEST_PER_LOOP", "") != "":
        policy_max_quest_actions_per_loop = int(os.environ["MILK_HUNT_POLICY_MAX_QUEST_PER_LOOP"])
    if policy_max_quest_actions_per_loop is None:
        policy_max_quest_actions_per_loop = 0
    policy_max_quest_actions_per_loop = max(0, int(policy_max_quest_actions_per_loop))
    policy_forbid_actions = _parse_token_list(list(args.policy_forbid_action or []))
    policy_restrictions = args.policy_restrictions
    if policy_restrictions is None:
        policy_restrictions = get_cfg_bool(cfg, "policy_restrictions")
    if policy_restrictions is None and os.environ.get("MILK_HUNT_POLICY_RESTRICTIONS", "") != "":
        policy_restrictions = os.environ["MILK_HUNT_POLICY_RESTRICTIONS"].strip().lower() in {
            "1",
            "true",
            "yes",
            "on",
        }
    if policy_restrictions is None:
        policy_restrictions = False
    quest_cycle_gate_override = args.quest_cycle_gate
    if not bool(policy_restrictions):
        policy_max_quest_actions_per_loop = 0
        policy_forbid_actions = []
    effective_policy_graph_path = str(runtime_policy_graph_path(hunter_profile, "ucb"))

    # MILK_HUNT_POLICY_EXTRA_JSONL: lichen overlay lines (set by derby.py per-lane).
    # Extends profile action_limits/action_priors on the Python gate side.
    _lichen_extra_lines = None
    _lichen_overlay_env = os.environ.get("MILK_HUNT_POLICY_EXTRA_JSONL", "")
    if _lichen_overlay_env:
        try:
            _overlay_p = Path(_lichen_overlay_env)
            if _overlay_p.exists():
                _lichen_extra_lines = _overlay_p.read_text().splitlines()
        except OSError:
            pass

    action_gate_policies: Dict[str, Dict[str, Any]] = {
        "quest_cycle": action_limits_for_action(
            hunter_profile, "ucb", "quest_cycle",
            extra_lines=_lichen_extra_lines,
        ),
    }
    if not bool(policy_restrictions):
        action_gate_policies["quest_cycle"]["enabled"] = False
    elif quest_cycle_gate_override is not None:
        action_gate_policies["quest_cycle"]["enabled"] = bool(quest_cycle_gate_override)

    if strict_biome_economy is None:
        val = strategy.strict_biome_economy
        if val is not None:
            strict_biome_economy = val
        else:
            strict_biome_economy = get_cfg_bool(cfg, "strict_biome_economy")
    if strict_biome_economy is None:
        strict_biome_economy = True
    allow_rig_resource_injection = bool(args.allow_rig_resource_injection) and (not strict_biome_economy)
    if strict_biome_economy and bool(args.allow_rig_resource_injection):
        _safe_print(
            "milk-hunt: strict economy enabled; disabling rig-side resource injection",
            "detail",
        )
    # Runner pacing is phrame-driven in-game via `time_skip`; no wall-clock throttling.
    metrics_every = max(0, int(args.metrics_every))
    runtime_profile = args.runtime_profile
    if not runtime_profile:
        runtime_profile = get_cfg_str(cfg, "runtime_profile")
    if not runtime_profile and os.environ.get("MILK_HUNT_RUNTIME_PROFILE", "") != "":
        runtime_profile = os.environ["MILK_HUNT_RUNTIME_PROFILE"]
    if runtime_profile not in {"default", "quantum_fiber_nodes", "io_min"}:
        runtime_profile = "default"
    runtime_env_overrides = _runtime_profile_env_overrides(runtime_profile)
    if hunter_policy_mode == "quantum_register":
        runtime_env_overrides["RIG_POLICY_TYPE"] = "quantum_register"
    runtime_env_overrides["RIG_POLICY_EXECUTION_BACKEND"] = str(policy_execution_backend)
    include_offer_reward_resources = bool(args.include_offer_reward_resources)
    include_offer_market_projection = bool(args.include_offer_market_projection)

    # Eagle / expansion defaults: CLI > strategy > hardcoded
    eagle_emoji = args.eagle_emoji if args.eagle_emoji is not None else strategy.eagle_emoji
    eagle_target_stock = args.eagle_target_stock if args.eagle_target_stock is not None else strategy.eagle_target_stock
    eagle_probe_burst = args.eagle_probe_burst if args.eagle_probe_burst is not None else strategy.eagle_probe_burst
    expand_check_every = args.expand_check_every if args.expand_check_every is not None else strategy.eagle_check_every
    max_biome_expansions = args.max_biome_expansions if args.max_biome_expansions is not None else strategy.eagle_max_expansions
    min_eagles_for_expansion = args.min_eagles_for_expansion if args.min_eagles_for_expansion is not None else strategy.eagle_min_for_expansion

    primary_resource_floors = dict(strategy.resource_floors)
    primary_resource_floors.update(_parse_resource_floor_overrides(args.resource_floor))
    lindblad_drain_focus = args.lindblad_drain_focus
    if lindblad_drain_focus is None:
        lindblad_drain_focus = get_cfg_bool(cfg, "lindblad_drain_focus")
    if lindblad_drain_focus is None and os.environ.get("MILK_HUNT_LINDBLAD_DRAIN_FOCUS", "") != "":
        lindblad_drain_focus = os.environ["MILK_HUNT_LINDBLAD_DRAIN_FOCUS"].strip().lower() in {
            "1",
            "true",
            "yes",
            "on",
        }
    if lindblad_drain_focus is None:
        lindblad_drain_focus = False
    lindblad_drain_every = args.lindblad_drain_every
    if lindblad_drain_every is None:
        lindblad_drain_every = get_cfg_int(cfg, "lindblad_drain_every")
    if lindblad_drain_every is None and os.environ.get("MILK_HUNT_LINDBLAD_DRAIN_EVERY", "") != "":
        lindblad_drain_every = int(os.environ["MILK_HUNT_LINDBLAD_DRAIN_EVERY"])
    if lindblad_drain_every is None:
        lindblad_drain_every = 1
    lindblad_drain_max_biomes_per_loop = args.lindblad_drain_max_biomes_per_loop
    if lindblad_drain_max_biomes_per_loop is None:
        lindblad_drain_max_biomes_per_loop = get_cfg_int(cfg, "lindblad_drain_max_biomes_per_loop")
    if lindblad_drain_max_biomes_per_loop is None and os.environ.get("MILK_HUNT_LINDBLAD_DRAIN_MAX_BIOMES", "") != "":
        lindblad_drain_max_biomes_per_loop = int(os.environ["MILK_HUNT_LINDBLAD_DRAIN_MAX_BIOMES"])
    if lindblad_drain_max_biomes_per_loop is None:
        lindblad_drain_max_biomes_per_loop = 1
    lindblad_drain_max_plots = args.lindblad_drain_max_plots
    if lindblad_drain_max_plots is None:
        lindblad_drain_max_plots = get_cfg_int(cfg, "lindblad_drain_max_plots")
    if lindblad_drain_max_plots is None and os.environ.get("MILK_HUNT_LINDBLAD_DRAIN_MAX_PLOTS", "") != "":
        lindblad_drain_max_plots = int(os.environ["MILK_HUNT_LINDBLAD_DRAIN_MAX_PLOTS"])
    if lindblad_drain_max_plots is None:
        lindblad_drain_max_plots = 2
    lindblad_drain_biomes_raw = args.lindblad_drain_biomes
    if lindblad_drain_biomes_raw is None:
        lindblad_drain_biomes_raw = get_cfg_str(cfg, "lindblad_drain_biomes")
    if lindblad_drain_biomes_raw is None and os.environ.get("MILK_HUNT_LINDBLAD_DRAIN_BIOMES", "") != "":
        lindblad_drain_biomes_raw = os.environ["MILK_HUNT_LINDBLAD_DRAIN_BIOMES"]
    configured_lindblad_biomes = _parse_biome_list(lindblad_drain_biomes_raw)
    lindblad_drain_slices = args.lindblad_drain_slices
    if lindblad_drain_slices is None:
        lindblad_drain_slices = get_cfg_int(cfg, "lindblad_drain_slices")
    if lindblad_drain_slices is None and os.environ.get("MILK_HUNT_LINDBLAD_DRAIN_SLICES", "") != "":
        lindblad_drain_slices = int(os.environ["MILK_HUNT_LINDBLAD_DRAIN_SLICES"])
    if lindblad_drain_slices is None:
        lindblad_drain_slices = 1
    lindblad_wait_phrames = args.lindblad_wait_phrames
    if lindblad_wait_phrames is None:
        lindblad_wait_phrames = get_cfg_int(cfg, "lindblad_wait_phrames")
    if lindblad_wait_phrames is None and os.environ.get("MILK_HUNT_LINDBLAD_WAIT_PHRAMES", "") != "":
        lindblad_wait_phrames = int(os.environ["MILK_HUNT_LINDBLAD_WAIT_PHRAMES"])
    lindblad_wait_seconds = args.lindblad_wait_seconds
    if lindblad_wait_seconds is None:
        lindblad_wait_seconds = float(get_cfg_float(cfg, "lindblad_wait_seconds") or 0.0)
    if lindblad_wait_phrames is None and lindblad_wait_seconds > 0.0:
        lindblad_wait_phrames = _seconds_to_phrames(float(lindblad_wait_seconds))
    if lindblad_wait_phrames is None:
        lindblad_wait_phrames = 0
    lindblad_wait_threshold = _parse_resource_floor_overrides(args.lindblad_wait_for_resource)
    lindblad_wait_max_phrames = args.lindblad_wait_max_phrames
    if lindblad_wait_max_phrames is None:
        lindblad_wait_max_phrames = get_cfg_int(cfg, "lindblad_wait_max_phrames")
    if lindblad_wait_max_phrames is None and os.environ.get("MILK_HUNT_LINDBLAD_WAIT_MAX_PHRAMES", "") != "":
        lindblad_wait_max_phrames = int(os.environ["MILK_HUNT_LINDBLAD_WAIT_MAX_PHRAMES"])
    lindblad_wait_max_seconds = args.lindblad_wait_max_seconds
    if lindblad_wait_max_seconds is None:
        lindblad_wait_max_seconds = float(get_cfg_float(cfg, "lindblad_wait_max_seconds") or 8.0)
    if lindblad_wait_max_phrames is None:
        lindblad_wait_max_phrames = _seconds_to_phrames(float(lindblad_wait_max_seconds))
    lindblad_wait_poll_phrames = args.lindblad_wait_poll_phrames
    if lindblad_wait_poll_phrames is None:
        lindblad_wait_poll_phrames = get_cfg_int(cfg, "lindblad_wait_poll_phrames")
    if lindblad_wait_poll_phrames is None and os.environ.get("MILK_HUNT_LINDBLAD_WAIT_POLL_PHRAMES", "") != "":
        lindblad_wait_poll_phrames = int(os.environ["MILK_HUNT_LINDBLAD_WAIT_POLL_PHRAMES"])
    lindblad_wait_poll_seconds = args.lindblad_wait_poll_seconds
    if lindblad_wait_poll_seconds is None:
        lindblad_wait_poll_seconds = float(get_cfg_float(cfg, "lindblad_wait_poll_seconds") or 0.5)
    if lindblad_wait_poll_phrames is None:
        lindblad_wait_poll_phrames = _seconds_to_phrames(float(lindblad_wait_poll_seconds))
    lindblad_wait_max_phrames = max(0, int(lindblad_wait_max_phrames))
    lindblad_wait_poll_phrames = max(1, int(lindblad_wait_poll_phrames))

    advanced_mode = args.advanced_mode
    if advanced_mode is None:
        advanced_mode = get_cfg_bool(cfg, "advanced_mode")
    if advanced_mode is None and os.environ.get("MILK_HUNT_ADVANCED_MODE", "") != "":
        advanced_mode = os.environ["MILK_HUNT_ADVANCED_MODE"].strip().lower() in {"1", "true", "yes", "on"}
    if advanced_mode is None:
        advanced_mode = False

    timescale_focus_emojis = _parse_emoji_list(args.timescale_focus_emoji)
    if not timescale_focus_emojis:
        cfg_focus = get_cfg_str(cfg, "timescale_focus_emojis")
        if cfg_focus:
            timescale_focus_emojis = _parse_emoji_list([cfg_focus])
    if not timescale_focus_emojis and os.environ.get("MILK_HUNT_TIMESCALE_FOCUS", "") != "":
        timescale_focus_emojis = _parse_emoji_list([os.environ["MILK_HUNT_TIMESCALE_FOCUS"]])

    timescale_floor_overrides = _parse_resource_floor_overrides(args.timescale_floor)
    timescale_objective_floors = dict(primary_resource_floors)
    timescale_objective_floors.update(timescale_floor_overrides)

    timescale_top_k = args.timescale_top_k
    if timescale_top_k is None:
        timescale_top_k = get_cfg_int(cfg, "timescale_top_k")
    if timescale_top_k is None and os.environ.get("MILK_HUNT_TIMESCALE_TOP_K", "") != "":
        timescale_top_k = int(os.environ["MILK_HUNT_TIMESCALE_TOP_K"])
    if timescale_top_k is None:
        timescale_top_k = 8
    timescale_top_k = max(1, int(timescale_top_k))

    timescale_target_gain = args.timescale_target_gain
    if timescale_target_gain is None:
        timescale_target_gain = get_cfg_float(cfg, "timescale_target_gain")
    if timescale_target_gain is None and os.environ.get("MILK_HUNT_TIMESCALE_TARGET_GAIN", "") != "":
        timescale_target_gain = float(os.environ["MILK_HUNT_TIMESCALE_TARGET_GAIN"])
    if timescale_target_gain is None:
        timescale_target_gain = 1.0

    timescale_horizon_min_phrames = args.timescale_horizon_min_phrames
    if timescale_horizon_min_phrames is None:
        timescale_horizon_min_phrames = get_cfg_int(cfg, "timescale_horizon_min_phrames")
    if timescale_horizon_min_phrames is None and os.environ.get("MILK_HUNT_TIMESCALE_HORIZON_MIN", "") != "":
        timescale_horizon_min_phrames = int(os.environ["MILK_HUNT_TIMESCALE_HORIZON_MIN"])
    if timescale_horizon_min_phrames is None:
        timescale_horizon_min_phrames = 6

    timescale_horizon_max_phrames = args.timescale_horizon_max_phrames
    if timescale_horizon_max_phrames is None:
        timescale_horizon_max_phrames = get_cfg_int(cfg, "timescale_horizon_max_phrames")
    if timescale_horizon_max_phrames is None and os.environ.get("MILK_HUNT_TIMESCALE_HORIZON_MAX", "") != "":
        timescale_horizon_max_phrames = int(os.environ["MILK_HUNT_TIMESCALE_HORIZON_MAX"])
    if timescale_horizon_max_phrames is None:
        timescale_horizon_max_phrames = 72
    timescale_horizon_min_phrames = max(1, int(timescale_horizon_min_phrames))
    timescale_horizon_max_phrames = max(timescale_horizon_min_phrames, int(timescale_horizon_max_phrames))

    timescale_objective_payload = {
        "focus_emojis": timescale_focus_emojis,
        "resource_floors": timescale_objective_floors,
        "top_k": timescale_top_k,
        "target_gain_per_wait": float(timescale_target_gain),
        "horizon_min_phrames": timescale_horizon_min_phrames,
        "horizon_max_phrames": timescale_horizon_max_phrames,
    }
    git_meta = _git_metadata()
    git_dirty_count = int(git_meta.get("git_dirty_count", 0))
    if git_dirty_count > 0:
        _safe_print(
            "milk-hunt: warning - git worktree dirty (%d files), verification reproducibility reduced"
            % git_dirty_count,
            "warn",
        )
    if args.require_clean_worktree and git_dirty_count > 0:
        _safe_print("milk-hunt: failing due to dirty worktree (--require-clean-worktree)", "error")
        return 5

    proc: Optional[subprocess.Popen] = None
    boot_lines: List[str] = []
    listener_log_boot_offset = _file_size(listener_log_path) if rig_listener_stdout == "file" else 0
    if not args.reuse_listener:
        _safe_print("milk-hunt: resetting rig cache and starting listener", "detail")
        _kill_existing_listeners()
        if not args.no_clear_rig:
            _clear_rig_files()
        proc = _start_listener(
            load_slot=load_slot,
            scenario_id=scenario_id,
            display_mode=display_mode,
            allow_resource_injection=allow_rig_resource_injection,
            listener_stdout=rig_listener_stdout,
            listener_log_path=listener_log_path,
            rig_log_profile=rig_log_profile,
            rig_log_category_levels=rig_log_categories,
            extra_env=runtime_env_overrides,
        )
        boot_lines = _wait_for_ready(proc, timeout_s=70.0)
        if proc.poll() is not None:
            _safe_print("milk-hunt: listener exited during boot", "error")
            for line in boot_lines[-20:]:
                _safe_print(line, "error")
            return 1
        if not RigClient.ready_seen(boot_lines):
            _safe_print("milk-hunt: listener did not reach ready state", "error")
            for line in boot_lines[-20:]:
                _safe_print(line, "warn")
            proc.terminate()
            return 1
    else:
        if not _find_listener_pids():
            _safe_print("milk-hunt: reuse requested but no listener found; starting a new one", "detail")
            if not args.no_clear_rig:
                _clear_rig_files()
            proc = _start_listener(
                load_slot=load_slot,
                scenario_id=scenario_id,
                display_mode=display_mode,
                allow_resource_injection=allow_rig_resource_injection,
                listener_stdout=rig_listener_stdout,
                listener_log_path=listener_log_path,
                rig_log_profile=rig_log_profile,
                rig_log_category_levels=rig_log_categories,
                extra_env=runtime_env_overrides,
            )
            boot_lines = _wait_for_ready(proc, timeout_s=70.0)
            if proc.poll() is not None:
                _safe_print("milk-hunt: listener exited during boot", "error")
                for line in boot_lines[-20:]:
                    _safe_print(line, "error")
                return 1
            if not RigClient.ready_seen(boot_lines):
                _safe_print("milk-hunt: listener did not reach ready state", "error")
                for line in boot_lines[-20:]:
                    _safe_print(line, "warn")
                proc.terminate()
                return 1
        else:
            if RigClient._bridge_sentinel_path().exists():
                _safe_print("milk-hunt: phrame bridge detected — visual mode", "detail")
            else:
                _safe_print("milk-hunt: reusing existing headless listener", "detail")
            if not args.no_clear_rig:
                _clear_rig_files()

    turn = max(1, int(args.turn_start))
    history: List[Dict[str, Any]] = []
    initial_known_icons_count = 0
    boot_log_lines = _read_new_lines(listener_log_path, start_offset=listener_log_boot_offset, max_lines=4000)
    error_lines = _extract_boot_script_errors(boot_lines + boot_log_lines)
    if args.fail_on_boot_script_errors and error_lines:
        _safe_print("milk-hunt: failing due to boot script errors", "error")
        for line in error_lines[-20:]:
            _safe_print(line, "warn")
        RigClient.terminate_listener(proc, timeout_s=5.0)
        return 4
    faction_sigs, milk_distances = _load_faction_data()
    use_engine_policy = hunter_policy_mode in ("engine_policy", "quantum_register")

    try:
        # Health check: verify the rig listener is responsive before sending
        # real commands. Catches dead/stale Godot processes early (5s timeout).
        ping_row = _run_turn(turn, "ping", timeout_s=5.0)
        if not ping_row.get("ok", False):
            _safe_print("milk-hunt: listener failed health check (ping): %s" % str(ping_row.get("error", "?")), "error")
            RigClient.terminate_listener(proc, timeout_s=5.0)
            return 1
        turn += 1

        if resolved_profile_save is not None:
            history.append(_run_turn(turn, "load_game_path", path=resolved_profile_save))
            turn += 1
        elif args.reuse_listener and load_slot is not None:
            history.append(_run_turn(turn, "load_game", slot=load_slot))
            turn += 1
        if args.open_quests_overlay:
            history.append(_run_turn(turn, "open_overlay", name="quests"))
            turn += 1
        snap = _run_turn(turn, "policy_snapshot")
        history.append(snap)
        turn += 1

        policy_boot = snap.get("policy_snapshot", {}) if isinstance(snap, dict) else {}
        resources = policy_boot.get("resources", {}) if isinstance(policy_boot, dict) else {}
        if isinstance(resources, dict) and not strict_biome_economy and strategy.initial_injection_enabled:
            inj_amount = strategy.initial_injection_amount
            for emoji in strategy.initial_injection_resources:
                history.append(_run_turn(turn, "add_resource", emoji=emoji, amount=inj_amount))
                turn += 1

        initial_biomes: List[str] = []
        boot_biomes = policy_boot.get("biomes", []) if isinstance(policy_boot, dict) else []
        if isinstance(boot_biomes, list):
            initial_biomes = [str(b) for b in boot_biomes if isinstance(b, str) and b]

        # Apply stride/resolution overrides to all discovered biomes
        if args.stride is not None:
            for biome_name in initial_biomes:
                history.append(_run_turn(turn, "set_stride", biome=biome_name, stride=args.stride))
                turn += 1
            _safe_print(f"milk-hunt: set observation stride={args.stride} on {len(initial_biomes)} biomes", "detail")
        if args.resolution is not None:
            for biome_name in initial_biomes:
                history.append(_run_turn(turn, "set_resolution", biome=biome_name, dt=args.resolution))
                turn += 1
            _safe_print(f"milk-hunt: set resolution dt={args.resolution} on {len(initial_biomes)} biomes", "detail")
        if advanced_mode:
            history.append(_run_turn(turn, "set_timescale_objective", objective=timescale_objective_payload))
            turn += 1
            _safe_print(
                "milk-hunt: advanced timescale objective enabled "
                + json.dumps(timescale_objective_payload, ensure_ascii=False),
                "detail",
            )
        boot_pairs = policy_boot.get("known_icons", []) if isinstance(policy_boot, dict) else []
        initial_known_icons_count = len(boot_pairs) if isinstance(boot_pairs, list) else 0
        current_resources: Dict[str, float] = _extract_resource_map(snap)
        _safe_print("RESOURCE_SNAPSHOT " + json.dumps(current_resources, ensure_ascii=False), "trace")

        found_milk = False
        found_offer = False
        last_milk_offer: Optional[Dict[str, Any]] = None
        victory_lap_result: Dict[str, Any] = {}
        victory_lap_executed = False
        prev_icons_count = initial_known_icons_count
        # Track true biome discovery (newly unlocked biomes beyond initial access).
        known_biomes: Set[str] = set(initial_biomes)
        newly_discovered_biomes: List[str] = []
        # Track probe/selection visitation separately (used by policy heuristics).
        discovered_biomes: List[str] = []
        biome_explore_counts: Dict[str, int] = {}
        biome_resource_hits: Dict[str, Dict[str, int]] = {}
        biome_probe_events: List[Dict[str, Any]] = []
        vocab_milestones: List[Dict[str, Any]] = []
        policy_decisions: List[Dict[str, Any]] = []
        lindblad_biome_attempts: Dict[str, int] = {}
        lindblad_biomes_activated: Set[str] = set()
        lindblad_drain_events: List[Dict[str, Any]] = []
        lindblad_wait_events: List[Dict[str, Any]] = []
        action_gate_quest_cycle_actions = 0
        action_gate_quest_cycle_success = 0
        action_gate_quest_cycle_failed = 0
        action_gate_quest_cycle_cap_hits = 0
        action_gate_quest_cycle_cooldown_hits = 0
        action_gate_quest_cycle_fail_streak = 0
        action_gate_quest_cycle_cooldown_until_loop = 0
        timescale_events: List[Dict[str, Any]] = []
        biome_timescale_cache: Dict[str, Dict[str, float]] = {}
        policy_trace_limit = max(0, int(args.policy_trace_limit))

        def _append_policy_decision(event: Dict[str, Any]) -> None:
            if policy_trace_limit <= 0:
                return
            if len(policy_decisions) < policy_trace_limit:
                policy_decisions.append(event)
                return
            if len(policy_decisions) == policy_trace_limit:
                policy_decisions.append({"kind": "trace_truncated", "limit": policy_trace_limit})

        def _run_loop_tail_wait(loop_number: int, loop_wait_enabled: bool, wait_override_phrames: int = 0) -> None:
            nonlocal turn, current_resources
            if not loop_wait_enabled or not (lindblad_wait_phrames > 0 or lindblad_wait_threshold or wait_override_phrames > 0):
                return
            wait_payload: Dict[str, Any] = {}
            wait_mode = "fixed_time_skip"
            effective_wait = int(max(1, lindblad_wait_phrames))
            if wait_override_phrames > 0 and not lindblad_wait_threshold:
                effective_wait = int(max(1, wait_override_phrames))
                wait_mode = "adaptive_time_skip"
            timeout_hint = int(max(1, effective_wait))
            if lindblad_wait_threshold:
                wait_mode = "threshold_time_skip"
                wait_payload["wait_for_resource"] = lindblad_wait_threshold
                wait_payload["max_phrames"] = int(max(1, lindblad_wait_max_phrames))
                wait_payload["poll_phrames"] = int(max(1, lindblad_wait_poll_phrames))
                wait_payload["phrames"] = int(max(1, lindblad_wait_poll_phrames))
                timeout_hint = int(max(1, lindblad_wait_max_phrames))
            else:
                wait_payload["phrames"] = effective_wait
                timeout_hint = int(max(1, effective_wait))

            wait_row = _run_turn(
                turn,
                "time_skip",
                timeout_s=max(20.0, float(timeout_hint) / 3.0),
                **wait_payload,
            )
            history.append(wait_row)
            turn += 1
            skip_payload = wait_row.get("time_skip", {}) if isinstance(wait_row, dict) else {}
            if isinstance(skip_payload, dict):
                resources_after_wait = skip_payload.get("resources", {})
                if isinstance(resources_after_wait, dict):
                    converted: Dict[str, float] = {}
                    for k, v in resources_after_wait.items():
                        if not isinstance(k, str):
                            continue
                        try:
                            converted[k] = float(v)
                        except (TypeError, ValueError):
                            continue
                    if converted:
                        current_resources = converted
            lindblad_wait_events.append(
                {
                    "loop": loop_number,
                    "mode": wait_mode,
                    "payload": wait_payload,
                    "result": skip_payload if isinstance(skip_payload, dict) else {},
                    "met": bool(isinstance(skip_payload, dict) and skip_payload.get("met", False)),
                }
            )

        biome_expansion_events: List[Dict[str, Any]] = []
        primary_resource_floor_events: List[Dict[str, Any]] = []
        batcher_metrics_samples: List[Dict[str, Any]] = []
        expansions_attempted = 0
        expansions_succeeded = 0
        loops_completed = 0
        policy_quest_cap_hits = 0
        if use_engine_policy:
            if policy_reset_on_start:
                policy_row = _run_turn(
                    turn,
                    "policy_reset",
                    config={
                        "profile": hunter_profile,
                        "epsilon": policy_epsilon,
                        "ucb_scale": policy_ucb_scale,
                    },
                )
            else:
                policy_row = _run_turn(turn, "policy_snapshot")
            history.append(policy_row)
            turn += 1
            graph_row = _run_turn(turn, "policy_graph")
            history.append(graph_row)
            turn += 1
            graph_payload = graph_row.get("policy_graph", {}) if isinstance(graph_row, dict) else {}

            # Apply Claura's overlay to Godot's policy engine via policy_graph_patch.
            # This reaches the Godot-side scoring (milk_distance_gain, base, etc.)
            # which policy_graph_patch supports; the Python-side gate is handled
            # separately by action_limits_for_action(extra_lines=...) below.
            if _lichen_extra_lines:
                apply_row = _run_turn(turn, "policy_graph_patch", lines=_lichen_extra_lines)
                history.append(apply_row)
                turn += 1
                if isinstance(apply_row, dict) and apply_row.get("ok"):
                    apply_payload = apply_row.get("policy_graph", {})
                    if isinstance(apply_payload, dict) and apply_payload:
                        graph_payload = apply_payload

            if isinstance(graph_payload, dict) and graph_payload:
                action_gate_policies["quest_cycle"] = action_limits_for_action_from_graph(graph_payload, "quest_cycle")
                if not bool(policy_restrictions):
                    action_gate_policies["quest_cycle"]["enabled"] = False
                elif quest_cycle_gate_override is not None:
                    action_gate_policies["quest_cycle"]["enabled"] = bool(quest_cycle_gate_override)

        if args.enforce_primary_resource_floors and allow_rig_resource_injection:
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
            loop_should_wait = False
            loop_dynamic_wait_phrames = 0
            if args.enforce_primary_resource_floors and allow_rig_resource_injection:
                turn, current_resources, floor_events = _enforce_primary_resource_floors(
                    turn,
                    history,
                    current_resources,
                    primary_resource_floors,
                )
                if floor_events:
                    primary_resource_floor_events.append({"loop": loop_idx + 1, "events": floor_events})

            if use_engine_policy:
                loop_quest_actions = 0
                loop_lock_actions = 0
                for quest_cycle_step_idx in range(policy_actions_per_loop):
                    forbid_actions: List[str] = list(policy_forbid_actions)
                    if policy_max_quest_actions_per_loop > 0 and loop_quest_actions >= policy_max_quest_actions_per_loop:
                        if "quest_cycle" not in forbid_actions:
                            forbid_actions.append("quest_cycle")
                        policy_quest_cap_hits += 1
                    lock_gate_reasons: List[str] = []
                    lock_gate_pressure: Optional[float] = None
                    lock_gate_allowed = True
                    lock_policy = action_gate_policies.get("quest_cycle", {})
                    lock_gate_enabled = bool(lock_policy.get("enabled", True))
                    if lock_gate_enabled:
                        loop_number = loop_idx + 1
                        lock_gate_allowed, lock_gate_reasons, lock_gate_pressure = _evaluate_action_gate(
                            "quest_cycle",
                            lock_policy,
                            loop_number=loop_number,
                            loop_action_count=loop_lock_actions,
                            total_action_count=action_gate_quest_cycle_actions,
                            pair_count=prev_icons_count,
                            known_biomes_count=len(known_biomes),
                            current_resources=current_resources,
                            resource_floors=primary_resource_floors,
                            cooldown_until_loop=action_gate_quest_cycle_cooldown_until_loop,
                        )
                        if "per_loop_cap" in lock_gate_reasons:
                            action_gate_quest_cycle_cap_hits += 1
                        if "total_action_cap" in lock_gate_reasons:
                            action_gate_quest_cycle_cap_hits += 1
                        if "cooldown" in lock_gate_reasons:
                            action_gate_quest_cycle_cooldown_hits += 1
                        if lock_gate_reasons and "quest_cycle" not in forbid_actions:
                            forbid_actions.append("quest_cycle")
                    policy_row = _run_turn(
                        turn,
                        "quest_cycle_step",
                        execute=True,
                        compact=True,
                        execution_backend=policy_execution_backend,
                        resource_floors=primary_resource_floors,
                        forbid_actions=forbid_actions,
                    )
                    history.append(policy_row)
                    turn += 1

                    policy_payload = policy_row.get("quest_cycle_step", {})
                    decision = policy_payload.get("decision", {}) if isinstance(policy_payload, dict) else {}
                    execution = policy_payload.get("execution", {}) if isinstance(policy_payload, dict) else {}
                    learning = policy_payload.get("learning", {}) if isinstance(policy_payload, dict) else {}
                    selected_action = str(decision.get("action", "")) if isinstance(decision, dict) else ""
                    selected_score = float(decision.get("score", 0.0)) if isinstance(decision, dict) else 0.0
                    reward = float(learning.get("reward", 0.0)) if isinstance(learning, dict) else 0.0
                    reward_components = learning.get("reward_components", {}) if isinstance(learning, dict) else {}
                    executed_action = str(execution.get("action", selected_action)) if isinstance(execution, dict) else selected_action
                    if executed_action == "quest_cycle":
                        loop_quest_actions += 1
                    if executed_action == "quest_cycle":
                        loop_lock_actions += 1
                        action_gate_quest_cycle_actions += 1
                        lock_ok = bool(isinstance(execution, dict) and execution.get("ok", False))
                        if lock_ok:
                            action_gate_quest_cycle_success += 1
                            action_gate_quest_cycle_fail_streak = 0
                        else:
                            action_gate_quest_cycle_failed += 1
                            action_gate_quest_cycle_fail_streak += 1
                            fail_streak_trigger = int(lock_policy.get("fail_streak_trigger", 0) or 0)
                            cooldown_loops = int(lock_policy.get("cooldown_loops", 0) or 0)
                            if (
                                lock_gate_enabled
                                and fail_streak_trigger > 0
                                and action_gate_quest_cycle_fail_streak >= fail_streak_trigger
                                and cooldown_loops > 0
                            ):
                                action_gate_quest_cycle_cooldown_until_loop = max(
                                    action_gate_quest_cycle_cooldown_until_loop,
                                    (loop_idx + 1) + cooldown_loops,
                                )
                                action_gate_quest_cycle_fail_streak = 0
                    event: Dict[str, Any] = {
                        "kind": "engine_quest_cycle_step",
                        "loop": loop_idx + 1,
                        "step_in_loop": quest_cycle_step_idx + 1,
                        "selected_action": selected_action,
                        "executed_action": executed_action,
                        "score": selected_score,
                        "reward": reward,
                        "reward_components": reward_components if isinstance(reward_components, dict) else {},
                        "forbid_actions": forbid_actions,
                        "ok": bool(execution.get("ok", False)) if isinstance(execution, dict) else False,
                    }
                    if lock_gate_enabled:
                        event["lock_gate"] = {
                            "enabled": True,
                            "allowed": lock_gate_allowed,
                            "reasons": lock_gate_reasons,
                            "critical_pressure": lock_gate_pressure,
                            "loop_lock_actions": loop_lock_actions,
                            "cooldown_until_loop": action_gate_quest_cycle_cooldown_until_loop,
                        }
                    if isinstance(execution, dict) and executed_action == "quest_cycle":
                        event["accepted"] = bool(execution.get("accepted", False))
                        event["completed_after_accept"] = bool(execution.get("completed_after_accept", False))
                        event["accepted_offer_reward_icon_north"] = str(
                            execution.get("accepted_offer_reward_icon_north", "") or ""
                        )
                        event["accepted_offer_reward_icon_south"] = str(
                            execution.get("accepted_offer_reward_icon_south", "") or ""
                        )
                    _append_policy_decision(event)

                    if isinstance(policy_payload, dict):
                        post_resources = policy_payload.get("post_resources", {})
                        if isinstance(post_resources, dict):
                            converted: Dict[str, float] = {}
                            for k, v in post_resources.items():
                                if not isinstance(k, str):
                                    continue
                                try:
                                    converted[k] = float(v)
                                except (TypeError, ValueError):
                                    continue
                            if converted:
                                current_resources = converted
                        post_pair_count = int(policy_payload.get("post_known_icons_count", prev_icons_count) or prev_icons_count)
                        if post_pair_count > prev_icons_count:
                            turn, pairs_row = _run_policy_snapshot(turn, history, include_grid=False, include_offers=False)
                            pairs = _extract_policy_icon_payload(pairs_row)
                            actual_pair_count = len(pairs) if isinstance(pairs, list) else post_pair_count
                            new_pairs: List[Dict[str, str]] = []
                            if isinstance(pairs, list):
                                for pair in pairs[prev_icons_count:actual_pair_count]:
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
                                    "pair_count": actual_pair_count,
                                    "pair_gain": actual_pair_count - prev_icons_count,
                                    "new_pairs": new_pairs,
                                    "contains_milk_pair": _contains_milk_icon(new_pairs),
                                }
                            )
                            prev_icons_count = actual_pair_count
                            if (isinstance(pairs, list) and _contains_milk_icon(pairs)) or bool(
                                policy_payload.get("contains_milk_pair", False)
                            ):
                                found_milk = True
                                break

                    if isinstance(execution, dict) and executed_action == "probe_cycle":
                        biome_name = str(execution.get("biome", "") or "")
                        if biome_name:
                            if biome_name not in discovered_biomes:
                                discovered_biomes.append(biome_name)
                            biome_explore_counts[biome_name] = biome_explore_counts.get(biome_name, 0) + 1
                        harvested = str(execution.get("harvested_resource", "") or "")
                        if biome_name and harvested:
                            biome_resource_hits.setdefault(biome_name, {})
                            hits = biome_resource_hits[biome_name]
                            hits[harvested] = hits.get(harvested, 0) + 1
                        probe = execution.get("probe", {})
                        probe_ok = bool(isinstance(probe, dict) and probe.get("success", False))
                        biome_probe_events.append(
                            {
                                "vocab_count": int(policy_payload.get("post_known_icons_count", 0))
                                if isinstance(policy_payload, dict)
                                else 0,
                                "biome": biome_name if biome_name else None,
                                "ok": probe_ok,
                                "reason": "engine_policy",
                                "probe": probe if isinstance(probe, dict) else {},
                            }
                        )

                    if isinstance(execution, dict) and executed_action == "discover_biome":
                        discover = execution.get("discover_biome", {})
                        success = bool(isinstance(discover, dict) and discover.get("success", False))
                        if success:
                            expansions_succeeded += 1
                            turn, grid_after_expand = _run_policy_snapshot(
                                turn, history, include_grid=True, include_offers=False
                            )
                            expanded_biomes = _extract_biomes(history)
                            for biome_name in expanded_biomes:
                                if biome_name not in known_biomes:
                                    known_biomes.add(biome_name)
                                    newly_discovered_biomes.append(biome_name)
                        expansions_attempted += 1
                        policy_expansion_event: Dict[str, Any] = {
                                "loop": loop_idx + 1,
                                "attempt": expansions_attempted,
                                "success": success,
                                "eagle_stock": float(current_resources.get(eagle_emoji, 0.0)),
                                "result": discover if isinstance(discover, dict) else {},
                        }
                        if isinstance(execution, dict) and "discovery_forecast" in execution:
                            policy_expansion_event["discovery_forecast"] = execution["discovery_forecast"]
                        biome_expansion_events.append(policy_expansion_event)

                    if isinstance(execution, dict) and executed_action == "lindblad_drain":
                        drain_result = execution.get("drain_result", {})
                        biome_name = str(execution.get("biome", "") or "")
                        if biome_name:
                            lindblad_biome_attempts[biome_name] = lindblad_biome_attempts.get(biome_name, 0) + 1
                        if isinstance(drain_result, dict):
                            established = bool(drain_result.get("success", False))
                            established = established or int(drain_result.get("charged_count", 0) or 0) > 0
                            established = established or int(drain_result.get("persistent_enabled", 0) or 0) > 0
                            established = established or int(drain_result.get("already_active", 0) or 0) > 0
                            if established and biome_name:
                                lindblad_biomes_activated.add(biome_name)
                            lindblad_drain_events.append(
                                {
                                    "loop": loop_idx + 1,
                                    "biome": biome_name,
                                    "result": drain_result,
                                }
                            )

                    if isinstance(execution, dict) and executed_action == "quest_cycle":
                        if str(execution.get("accepted_offer_reward_icon_north", "")) == MILK or str(
                            execution.get("accepted_offer_reward_icon_south", "")
                        ) == MILK:
                            found_offer = True

                    if isinstance(policy_payload, dict) and bool(policy_payload.get("contains_milk_pair", False)):
                        found_milk = True
                        break

                if metrics_every > 0 and ((loop_idx + 1) % metrics_every == 0):
                    metrics_row = _run_turn(turn, "batcher_metrics", timeout_s=20.0)
                    history.append(metrics_row)
                    turn += 1
                    metrics_payload = metrics_row.get("metrics", {})
                    if isinstance(metrics_payload, dict):
                        batcher_metrics_samples.append(
                            {
                                "loop": loop_idx + 1,
                                "metrics": _compact_batcher_metrics(metrics_payload),
                            }
                        )
                if found_milk:
                    break

            if args.expand_biomes and expansions_attempted < max(0, int(max_biome_expansions)):
                if loop_idx % max(1, int(expand_check_every)) == 0:
                    eagle_stock = float(current_resources.get(eagle_emoji, 0.0))
                    if eagle_stock >= float(min_eagles_for_expansion):
                        expand_row = _run_turn(turn, "discover_biome")
                        history.append(expand_row)
                        turn += 1
                        expansions_attempted += 1
                        expand_result = {}
                        if isinstance(expand_row, dict):
                            expand_result = expand_row.get("discover_biome", {})
                        success = bool(isinstance(expand_result, dict) and expand_result.get("success", False))
                        if success:
                            expansions_succeeded += 1
                            turn, grid_after_expand = _run_policy_snapshot(
                                turn, history, include_grid=True, include_offers=False
                            )
                            expanded_biomes = _extract_biomes(history)
                            for biome_name in expanded_biomes:
                                if biome_name not in known_biomes:
                                    known_biomes.add(biome_name)
                                    newly_discovered_biomes.append(biome_name)
                        expansion_event: Dict[str, Any] = {
                                "loop": loop_idx + 1,
                                "attempt": expansions_attempted,
                                "success": success,
                                "eagle_stock": eagle_stock,
                                "result": expand_result if isinstance(expand_result, dict) else {},
                        }
                        # Capture vocab-weighted discovery forecast if present
                        if isinstance(expand_row, dict) and "discovery_forecast" in expand_row:
                            expansion_event["discovery_forecast"] = expand_row["discovery_forecast"]
                        biome_expansion_events.append(expansion_event)

            if args.eagle_focus and float(current_resources.get(eagle_emoji, 0.0)) < float(eagle_target_stock):
                burst_count = max(1, int(eagle_probe_burst))
                for _focus_idx in range(burst_count):
                    turn, focus_grid = _run_policy_snapshot(turn, history, include_grid=True, include_offers=False)
                    focus_biomes = _extract_policy_biomes(focus_grid)
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
                    turn, focus_snapshot = _run_policy_snapshot(turn, history, include_grid=False, include_offers=False)
                    current_resources = _extract_resource_map(focus_snapshot)
                    if float(current_resources.get(eagle_emoji, 0.0)) >= float(eagle_target_stock):
                        break

            loop_biomes = _extract_biomes(history)
            if lindblad_drain_focus and (loop_idx % max(1, int(lindblad_drain_every)) == 0):
                candidate_biomes = configured_lindblad_biomes if configured_lindblad_biomes else list(loop_biomes)
                if not candidate_biomes:
                    turn, grid_for_drain = _run_policy_snapshot(turn, history, include_grid=True, include_offers=False)
                    loop_biomes = _extract_policy_biomes(grid_for_drain)
                    candidate_biomes = configured_lindblad_biomes if configured_lindblad_biomes else list(loop_biomes)

                unique_biomes: List[str] = []
                seen_biomes: Set[str] = set()
                for biome_name in candidate_biomes:
                    if not biome_name or biome_name in seen_biomes:
                        continue
                    unique_biomes.append(biome_name)
                    seen_biomes.add(biome_name)
                ranked_biomes = sorted(
                    unique_biomes,
                    key=lambda b: (
                        1 if b in lindblad_biomes_activated else 0,
                        lindblad_biome_attempts.get(b, 0),
                        b,
                    ),
                )
                selected_biomes = ranked_biomes[: max(1, int(lindblad_drain_max_biomes_per_loop))]
                lindblad_rankings = [{"biome": name, "score": idx} for idx, name in enumerate(selected_biomes)]
                _append_policy_decision(
                    {
                        "kind": "lindblad_drain",
                        "loop": loop_idx + 1,
                        "selected_biomes": selected_biomes,
                        "rankings": lindblad_rankings,
                        "slices": int(max(1, lindblad_drain_slices)),
                    }
                )
                did_drain = False
                for biome_name in selected_biomes:
                    if advanced_mode:
                        auto_row = _run_turn(
                            turn,
                            "auto_timescale",
                            biome=biome_name,
                            top_k=timescale_top_k,
                        )
                        history.append(auto_row)
                        turn += 1
                        auto_payload = auto_row.get("auto_timescale", {})
                        if isinstance(auto_payload, dict) and bool(auto_payload.get("ok", False)):
                            rec_stride = int(auto_payload.get("recommended_stride", 1))
                            rec_dt = float(auto_payload.get("recommended_dt", 0.02))
                            rec_wait = int(auto_payload.get("recommended_wait_phrames", 0))
                            recommendation = auto_payload.get("recommendation", {})
                            loop_dynamic_wait_phrames = max(loop_dynamic_wait_phrames, rec_wait)
                            biome_timescale_cache[biome_name] = {"stride": float(rec_stride), "dt": rec_dt}
                            timescale_event = {
                                "loop": loop_idx + 1,
                                "biome": biome_name,
                                "applied": bool(auto_payload.get("applied", False)),
                                "recommended_stride": rec_stride,
                                "recommended_dt": rec_dt,
                                "recommended_wait_phrames": rec_wait,
                                "top_emoji": recommendation.get("top_emoji", ""),
                                "top_probability": recommendation.get("top_probability", 0.0),
                                "emoji_rankings": recommendation.get("emoji_rankings", []),
                            }
                            timescale_events.append(timescale_event)
                            _append_policy_decision(
                                {
                                    "kind": "auto_timescale",
                                    "loop": loop_idx + 1,
                                    "biome": biome_name,
                                    "policy_source": "heuristic",
                                    "recommended_stride": rec_stride,
                                    "recommended_dt": rec_dt,
                                    "recommended_wait_phrames": rec_wait,
                                    "top_emoji": timescale_event.get("top_emoji", ""),
                                    "top_probability": timescale_event.get("top_probability", 0.0),
                                    "emoji_rankings": timescale_event.get("emoji_rankings", []),
                                }
                            )
                    raw_positions: Any = []
                    if int(lindblad_drain_max_plots) > 0:
                        positions_row = _run_turn(turn, "biome_positions", biome=biome_name)
                        history.append(positions_row)
                        turn += 1
                        raw_positions = positions_row.get("positions", [])
                    for slice_idx in range(max(1, int(lindblad_drain_slices))):
                        payload: Dict[str, Any] = {"biome": biome_name}
                        selected_positions: List[List[int]] = []
                        if int(lindblad_drain_max_plots) > 0:
                            offset = (loop_idx * max(1, int(lindblad_drain_slices)) + slice_idx) * max(
                                1, int(lindblad_drain_max_plots)
                            )
                            selected_positions = _encode_positions_for_rig(
                                raw_positions,
                                limit=int(lindblad_drain_max_plots),
                                offset=offset,
                            )
                            if selected_positions:
                                payload["positions"] = selected_positions
                        drain_row = _run_turn(turn, "lindblad_drain", **payload)
                        history.append(drain_row)
                        turn += 1
                        did_drain = True
                        lindblad_biome_attempts[biome_name] = lindblad_biome_attempts.get(biome_name, 0) + 1
                        drain_payload = drain_row.get("drain_result", {})
                        success = bool(isinstance(drain_payload, dict) and drain_payload.get("success", False))
                        charged_count = 0
                        persistent_enabled = 0
                        already_active = 0
                        if isinstance(drain_payload, dict):
                            try:
                                charged_count = int(drain_payload.get("charged_count", 0) or 0)
                            except (TypeError, ValueError):
                                charged_count = 0
                            try:
                                persistent_enabled = int(drain_payload.get("persistent_enabled", 0) or 0)
                            except (TypeError, ValueError):
                                persistent_enabled = 0
                            try:
                                already_active = int(drain_payload.get("already_active", 0) or 0)
                            except (TypeError, ValueError):
                                already_active = 0
                        if success or charged_count > 0 or persistent_enabled > 0 or already_active > 0:
                            lindblad_biomes_activated.add(biome_name)
                        lindblad_drain_events.append(
                            {
                                "loop": loop_idx + 1,
                                "slice": slice_idx + 1,
                                "slices": int(max(1, lindblad_drain_slices)),
                                "biome": biome_name,
                                "positions_selected": selected_positions,
                                "success": success,
                                "charged_count": charged_count,
                                "persistent_enabled": persistent_enabled,
                                "already_active": already_active,
                                "drain_result": drain_payload if isinstance(drain_payload, dict) else {},
                            }
                        )
                if did_drain:
                    turn, post_drain_snapshot = _run_policy_snapshot(
                        turn, history, include_grid=False, include_offers=False
                    )
                    current_resources = _extract_resource_map(post_drain_snapshot)
                    loop_should_wait = True

            turn, loop_snapshot = _run_policy_snapshot(turn, history, include_grid=False, include_offers=False)
            current_resources = _extract_resource_map(loop_snapshot)
            if metrics_every > 0 and ((loop_idx + 1) % metrics_every == 0):
                metrics_row = _run_turn(turn, "batcher_metrics", timeout_s=20.0)
                history.append(metrics_row)
                turn += 1
                metrics_payload = metrics_row.get("metrics", {})
                if isinstance(metrics_payload, dict):
                    batcher_metrics_samples.append({
                        "loop": loop_idx + 1,
                        "metrics": _compact_batcher_metrics(metrics_payload),
                    })
            offer_row = _run_turn(
                turn,
                "offer_quests",
                include_reward_resources=include_offer_reward_resources,
                include_market_projection=include_offer_market_projection,
            )
            history.append(offer_row)
            turn += 1
            offers = offer_row.get("offers", [])
            if not isinstance(offers, list) or not offers:
                adaptive_wait = loop_dynamic_wait_phrames if lindblad_wait_phrames > 0 else 0
                _run_loop_tail_wait(loop_idx + 1, loop_should_wait, adaptive_wait)
                continue
            eligible_delivery = _eligible_delivery_offer_indices(offers, strict_biome_economy, current_resources)
            if not eligible_delivery:
                adaptive_wait = loop_dynamic_wait_phrames if lindblad_wait_phrames > 0 else 0
                _run_loop_tail_wait(loop_idx + 1, loop_should_wait, adaptive_wait)
                continue

            known_icons = _extract_policy_icons(history)
            known_symbols = set()
            for p in known_icons:
                if p.get("north"):
                    known_symbols.add(p["north"])
                if p.get("south"):
                    known_symbols.add(p["south"])

            milk_index = None
            for i, offer in enumerate(offers):
                n = str(offer.get("reward_icon_north", "") or "")
                s = str(offer.get("reward_icon_south", "") or "")
                if n == MILK or s == MILK:
                    milk_index = i
                    last_milk_offer = offer
                    break

            if milk_index is not None:
                found_offer = True
                if milk_index in eligible_delivery:
                    selected_idx = milk_index
                    _append_policy_decision(
                        {
                            "kind": "offer",
                            "loop": loop_idx + 1,
                            "selected_offer_index": selected_idx,
                            "reason": "direct_milk_offer",
                        }
                    )
                    accept = _run_turn(turn, "accept_offer", offer_index=selected_idx)
                    history.append(accept)
                    turn += 1
                else:
                    selected_idx = _heuristic_best_offer_index(
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
                selected_idx = _heuristic_best_offer_index(
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
                if not strict_biome_economy:
                    turn, active_row = _run_policy_snapshot(turn, history, include_grid=False, include_offers=False)
                    quests = _extract_policy_active_quests(active_row)
                    if isinstance(quests, list):
                        for q in quests:
                            if int(q.get("id", -1)) != quest_id:
                                continue
                            res = str(q.get("resource", "") or "")
                            qty = int(float(q.get("quantity", 0) or 0))
                            if res and qty > 0:
                                history.append(_run_turn(turn, "add_resource", emoji=res, amount=max(qty + 50, 100)))
                                turn += 1
                completion_action = str(selected_offer.get("completion_action", "") or "")
                if completion_action not in {"complete_quest", "complete_or_claim"}:
                    completion_action = "complete_quest" if int(selected_offer.get("type", -1)) == 0 else "complete_or_claim"
                history.append(_run_turn(turn, completion_action, quest_id=quest_id))
                turn += 1
                turn, post_complete_snapshot = _run_policy_snapshot(turn, history, include_grid=True, include_offers=False)
                current_resources = _extract_resource_map(post_complete_snapshot)
                pairs = _extract_policy_icon_payload(post_complete_snapshot)
                pair_count = len(pairs) if isinstance(pairs, list) else prev_icons_count
                if pair_count > prev_icons_count:
                    new_pairs: List[Dict[str, str]] = []
                    if isinstance(pairs, list):
                        for pair in pairs[prev_icons_count:pair_count]:
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
                            "pair_gain": pair_count - prev_icons_count,
                            "new_pairs": new_pairs,
                            "contains_milk_pair": _contains_milk_icon(new_pairs),
                        }
                    )
                    pair_gain = pair_count - prev_icons_count
                    vocab_probe_cycles = pair_gain
                    for vocab_probe_idx in range(vocab_probe_cycles):
                        turn, grid_row = _run_policy_snapshot(turn, history, include_grid=True, include_offers=False)
                        biomes = _extract_policy_biomes(grid_row)
                        if not biomes:
                            biome_probe_events.append(
                                {
                                    "vocab_count": pair_count,
                                    "biome": None,
                                    "ok": False,
                                    "error": "no_biomes_available",
                                }
                            )
                            continue

                        next_biome: Optional[str] = None
                        if not next_biome:
                            next_biome = next((b for b in biomes if b not in discovered_biomes), None)
                            if next_biome is None:
                                next_biome = min(biomes, key=lambda b: (biome_explore_counts.get(b, 0), b))
                            _append_policy_decision(
                                {
                                    "kind": "vocab_probe",
                                    "loop": loop_idx + 1,
                                    "cycle": vocab_probe_idx + 1,
                                    "pair_gain": pair_gain,
                                    "selected_biome": next_biome,
                                    "rankings": [],
                                    "policy_source": "heuristic",
                                }
                            )

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
                                "vocab_count": pair_count,
                                "biome": next_biome,
                                "ok": probe_ok,
                                "reason": "vocab_gain",
                                "probe": probe if isinstance(probe, dict) else {},
                            }
                        )
                        turn, probe_snapshot = _run_policy_snapshot(
                            turn, history, include_grid=False, include_offers=False
                        )
                        current_resources = _extract_resource_map(probe_snapshot)
                    prev_icons_count = pair_count
                if isinstance(pairs, list) and _contains_milk_icon(pairs):
                    found_milk = True
                    break

            adaptive_wait = loop_dynamic_wait_phrames if lindblad_wait_phrames > 0 else 0
            _run_loop_tail_wait(loop_idx + 1, loop_should_wait, adaptive_wait)

        if found_milk and args.victory_lap:
            victory_row = _run_turn(turn, "victory_lap")
            history.append(victory_row)
            turn += 1
            victory_lap_executed = True
            if isinstance(victory_row, dict):
                raw_victory = victory_row.get("victory_lap", {})
                if isinstance(raw_victory, dict):
                    victory_lap_result = raw_victory
            turn, post_victory_snapshot = _run_policy_snapshot(turn, history, include_grid=False, include_offers=False)
            current_resources = _extract_resource_map(post_victory_snapshot)

        final_pairs = _extract_policy_icons(history)
        profile_metrics = _compute_profile_metrics(history, initial_known_icons_count, len(final_pairs))
        policy_breakdown = policy_action_breakdown(policy_decisions)
        market_view = market_projection_summary(policy_decisions)
        vocab_fields = vocab_milestone_fields(vocab_milestones)
        steps = len(history)
        summary = {
            "found_milk": found_milk,
            "found_milk_pair": found_milk,
            "found_milk_offer": found_offer,
            "milk_offer": last_milk_offer,
            "known_icons_count": len(final_pairs),
            "known_icons": final_pairs,
            "steps": steps,
            "turns_executed": steps,
            "loops_completed": loops_completed,
            "errors_seen_during_boot": error_lines,
            "boot_log_lines_scanned": len(boot_log_lines),
            "policy_trace_limit": policy_trace_limit,
            "biome_discovery_order": newly_discovered_biomes,
            "biome_visit_order": discovered_biomes,
            "initial_unlocked_biomes": initial_biomes,
            "biome_projection_counts": biome_explore_counts,
            "biome_resource_hits": biome_resource_hits,
            "biome_probe_events": biome_probe_events,
            "batcher_metrics_samples": batcher_metrics_samples,
            "policy_decisions": policy_decisions,
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
            "enforce_primary_resource_floors_active": bool(args.enforce_primary_resource_floors and allow_rig_resource_injection),
            "primary_resource_floors": primary_resource_floors,
            "primary_resource_floor_events": primary_resource_floor_events,
            "victory_lap_enabled": args.victory_lap,
            "victory_lap_executed": victory_lap_executed,
            "victory_lap_result": victory_lap_result,
            "lindblad_drain_focus": lindblad_drain_focus,
            "lindblad_drain_every": lindblad_drain_every,
            "lindblad_drain_max_biomes_per_loop": lindblad_drain_max_biomes_per_loop,
            "lindblad_drain_max_plots": lindblad_drain_max_plots,
            "lindblad_drain_slices": lindblad_drain_slices,
            "lindblad_wait_phrames": lindblad_wait_phrames,
            "lindblad_wait_seconds": lindblad_wait_seconds,
            "lindblad_wait_threshold": lindblad_wait_threshold,
            "lindblad_wait_max_phrames": lindblad_wait_max_phrames,
            "lindblad_wait_max_seconds": lindblad_wait_max_seconds,
            "lindblad_wait_poll_phrames": lindblad_wait_poll_phrames,
            "lindblad_wait_poll_seconds": lindblad_wait_poll_seconds,
            "lindblad_drain_configured_biomes": configured_lindblad_biomes,
            "lindblad_drain_biome_attempts": lindblad_biome_attempts,
            "lindblad_drain_biomes_activated": sorted(lindblad_biomes_activated),
            "lindblad_drain_events": lindblad_drain_events,
            "lindblad_wait_events": lindblad_wait_events,
        }
        summary.update(
            build_common_summary_fields(
                max_loops=max_loops,
                strict_biome_economy=strict_biome_economy,
                allow_rig_resource_injection=allow_rig_resource_injection,
                load_slot=load_slot,
                profile_save=profile_save,
                profile_save_index=profile_save_index,
                resolved_profile_save=resolved_profile_save,
                effective_policy_graph_path=effective_policy_graph_path,
                scenario_id=scenario_id,
                console_profile=console_profile,
                wait_progress_seconds=wait_progress_seconds,
                display_mode=display_mode,
                policy_execution_backend=policy_execution_backend,
                rig_listener_stdout=rig_listener_stdout,
                listener_log_path=listener_log_path,
                rig_log_profile=rig_log_profile,
                rig_log_categories=rig_log_categories,
                hunter_profile=hunter_profile,
                hunter_policy_mode=hunter_policy_mode,
                use_engine_policy=use_engine_policy,
                policy_actions_per_loop=policy_actions_per_loop,
                policy_restrictions=bool(policy_restrictions),
                policy_epsilon=policy_epsilon,
                policy_ucb_scale=policy_ucb_scale,
                policy_reset_on_start=bool(policy_reset_on_start),
                policy_max_quest_actions_per_loop=policy_max_quest_actions_per_loop,
                policy_forbid_actions=policy_forbid_actions,
                policy_quest_cap_hits=policy_quest_cap_hits,
                action_gate_policies=action_gate_policies,
                quest_cycle_gate_override=quest_cycle_gate_override,
                action_gate_quest_cycle_actions=action_gate_quest_cycle_actions,
                action_gate_quest_cycle_success=action_gate_quest_cycle_success,
                action_gate_quest_cycle_failed=action_gate_quest_cycle_failed,
                action_gate_quest_cycle_cap_hits=action_gate_quest_cycle_cap_hits,
                action_gate_quest_cycle_cooldown_hits=action_gate_quest_cycle_cooldown_hits,
                action_gate_quest_cycle_cooldown_until_loop=action_gate_quest_cycle_cooldown_until_loop,
                action_gate_quest_cycle_fail_streak=action_gate_quest_cycle_fail_streak,
                target_turn_hz=args.target_turn_hz,
                metrics_every=metrics_every,
                runtime_profile=runtime_profile,
                runtime_env_overrides=runtime_env_overrides,
                reuse_listener=bool(args.reuse_listener),
                include_offer_reward_resources=include_offer_reward_resources,
                include_offer_market_projection=include_offer_market_projection,
                lindblad_drain_focus=lindblad_drain_focus,
                lindblad_drain_every=lindblad_drain_every,
                lindblad_drain_max_biomes_per_loop=lindblad_drain_max_biomes_per_loop,
                lindblad_drain_max_plots=lindblad_drain_max_plots,
                lindblad_drain_slices=lindblad_drain_slices,
                lindblad_wait_phrames=lindblad_wait_phrames,
                lindblad_wait_seconds=lindblad_wait_seconds,
                lindblad_wait_threshold=lindblad_wait_threshold,
                lindblad_wait_max_phrames=lindblad_wait_max_phrames,
                lindblad_wait_max_seconds=lindblad_wait_max_seconds,
                lindblad_wait_poll_phrames=lindblad_wait_poll_phrames,
                lindblad_wait_poll_seconds=lindblad_wait_poll_seconds,
                configured_lindblad_biomes=configured_lindblad_biomes,
                advanced_mode=advanced_mode,
                timescale_top_k=timescale_top_k,
                timescale_objective_payload=timescale_objective_payload,
                timescale_events=timescale_events,
                git_meta=git_meta,
            )
        )
        summary.update(policy_breakdown)
        summary["market_projection"] = market_view
        summary.update(vocab_fields)
        apply_profile_metrics(summary, profile_metrics, len(final_pairs))
        story_flags_row = {}
        try:
            story_flags_row = _run_turn(turn, "story_flags")
            history.append(story_flags_row)
            turn += 1
        except Exception as exc:
            story_flags_row = {
                "ok": False,
                "error": "story_flags_capture_failed",
                "detail": str(exc),
                "flags_fired": {},
                "story_log": [],
            }
        story_flags_fired = story_flags_row.get("flags_fired", {})
        story_log = story_flags_row.get("story_log", [])
        summary["story_flags_fired"] = story_flags_fired if isinstance(story_flags_fired, dict) else {}
        summary["story_log"] = story_log if isinstance(story_log, list) else []
        summary["story_flags_fired_count"] = len(summary["story_flags_fired"])
        summary["story_log_count"] = len(summary["story_log"])
        if args.save_slot_at_end is not None:
            save_row = _run_turn(turn, "save_game", slot=args.save_slot_at_end)
            history.append(save_row)
            turn += 1
            summary["saved_slot"] = args.save_slot_at_end
            summary["save_result"] = save_row
        if args.save_path_at_end is not None:
            save_row = _run_turn(turn, "save_game_path", path=args.save_path_at_end)
            history.append(save_row)
            turn += 1
            summary["saved_path"] = args.save_path_at_end
            summary["save_path_result"] = save_row
        add_milk_pair_index(summary, final_pairs, MILK)
        if args.summary_path is not None:
            args.summary_path.parent.mkdir(parents=True, exist_ok=True)
            write_json(args.summary_path, summary)
        if args.json_only:
            _safe_print(json.dumps(summary, ensure_ascii=False), "info")
        elif _CONSOLE.allows("trace"):
            _safe_print("milk-hunt: summary", "info")
            _safe_print(json.dumps(summary, ensure_ascii=False, indent=2), "detail")
        else:
            _safe_print(
                "milk-hunt: result found_milk=%s loops=%d steps=%d profile=%s"
                % (
                    str(found_milk).lower(),
                    int(summary.get("loops_completed", 0)),
                    int(summary.get("steps", 0)),
                    str(summary.get("hunter_profile", "")),
                ),
                "info",
            )
        return 0 if found_milk else 2
    except TurnTimeoutError as exc:
        timeout_diag = _rig_timeout_diagnostics(exc.turn_id, exc.action)
        timeout_pairs = _extract_policy_icons(history)
        timeout_profile_metrics = _compute_profile_metrics(
            history,
            initial_known_icons_count,
            len(timeout_pairs),
        )
        timeout_summary = {
            "found_milk": False,
            "found_milk_pair": False,
            "found_milk_offer": False,
            "known_icons_count": len(timeout_pairs),
            "steps": len(history),
            "turns_executed": len(history),
            "loops_completed": locals().get("loops_completed", 0),
            "run_error": "turn_timeout",
            "run_error_detail": str(exc),
            "timeout_turn": exc.turn_id,
            "timeout_action": exc.action,
            "timeout_seconds": exc.timeout_s,
            "timeout_diagnostics": timeout_diag,
            "batcher_metrics_samples": locals().get("batcher_metrics_samples", []),
        }
        timeout_summary.update(
            build_common_summary_fields(
                max_loops=max_loops,
                strict_biome_economy=strict_biome_economy,
                allow_rig_resource_injection=allow_rig_resource_injection,
                load_slot=load_slot,
                profile_save=profile_save,
                profile_save_index=profile_save_index,
                resolved_profile_save=resolved_profile_save,
                effective_policy_graph_path=effective_policy_graph_path,
                scenario_id=scenario_id,
                console_profile=console_profile,
                wait_progress_seconds=wait_progress_seconds,
                display_mode=display_mode,
                policy_execution_backend=policy_execution_backend,
                rig_listener_stdout=rig_listener_stdout,
                listener_log_path=listener_log_path,
                rig_log_profile=rig_log_profile,
                rig_log_categories=rig_log_categories,
                hunter_profile=hunter_profile,
                hunter_policy_mode=hunter_policy_mode,
                use_engine_policy=use_engine_policy,
                policy_actions_per_loop=policy_actions_per_loop,
                policy_restrictions=bool(policy_restrictions),
                policy_epsilon=policy_epsilon,
                policy_ucb_scale=policy_ucb_scale,
                policy_reset_on_start=bool(policy_reset_on_start),
                policy_max_quest_actions_per_loop=policy_max_quest_actions_per_loop,
                policy_forbid_actions=policy_forbid_actions,
                policy_quest_cap_hits=locals().get("policy_quest_cap_hits", 0),
                action_gate_policies=action_gate_policies,
                quest_cycle_gate_override=quest_cycle_gate_override,
                action_gate_quest_cycle_actions=locals().get("action_gate_quest_cycle_actions", 0),
                action_gate_quest_cycle_success=locals().get("action_gate_quest_cycle_success", 0),
                action_gate_quest_cycle_failed=locals().get("action_gate_quest_cycle_failed", 0),
                action_gate_quest_cycle_cap_hits=locals().get("action_gate_quest_cycle_cap_hits", 0),
                action_gate_quest_cycle_cooldown_hits=locals().get("action_gate_quest_cycle_cooldown_hits", 0),
                action_gate_quest_cycle_cooldown_until_loop=locals().get(
                    "action_gate_quest_cycle_cooldown_until_loop", 0
                ),
                action_gate_quest_cycle_fail_streak=locals().get("action_gate_quest_cycle_fail_streak", 0),
                target_turn_hz=args.target_turn_hz,
                metrics_every=metrics_every,
                runtime_profile=runtime_profile,
                runtime_env_overrides=runtime_env_overrides,
                reuse_listener=bool(args.reuse_listener),
                include_offer_reward_resources=include_offer_reward_resources,
                include_offer_market_projection=include_offer_market_projection,
                lindblad_drain_focus=lindblad_drain_focus,
                lindblad_drain_every=lindblad_drain_every,
                lindblad_drain_max_biomes_per_loop=lindblad_drain_max_biomes_per_loop,
                lindblad_drain_max_plots=lindblad_drain_max_plots,
                lindblad_drain_slices=lindblad_drain_slices,
                lindblad_wait_phrames=lindblad_wait_phrames,
                lindblad_wait_seconds=lindblad_wait_seconds,
                lindblad_wait_threshold=lindblad_wait_threshold,
                lindblad_wait_max_phrames=lindblad_wait_max_phrames,
                lindblad_wait_max_seconds=lindblad_wait_max_seconds,
                lindblad_wait_poll_phrames=lindblad_wait_poll_phrames,
                lindblad_wait_poll_seconds=lindblad_wait_poll_seconds,
                configured_lindblad_biomes=configured_lindblad_biomes,
                advanced_mode=advanced_mode,
                timescale_top_k=timescale_top_k,
                timescale_objective_payload=timescale_objective_payload,
                timescale_events=locals().get("timescale_events", []),
                git_meta=git_meta,
            )
        )
        timeout_decisions = locals().get("policy_decisions", [])
        timeout_summary.update(policy_action_breakdown(timeout_decisions))
        timeout_summary["market_projection"] = market_projection_summary(timeout_decisions)
        timeout_summary.update(vocab_milestone_fields(locals().get("vocab_milestones", [])))
        apply_profile_metrics(timeout_summary, timeout_profile_metrics, len(timeout_pairs))
        if args.summary_path is not None:
            args.summary_path.parent.mkdir(parents=True, exist_ok=True)
            write_json(args.summary_path, timeout_summary)
        if args.json_only:
            _safe_print(json.dumps(timeout_summary, ensure_ascii=False), "info")
        elif _CONSOLE.allows("trace"):
            _safe_print("milk-hunt: timeout summary", "warn")
            _safe_print(json.dumps(timeout_summary, ensure_ascii=False, indent=2), "detail")
        else:
            _safe_print(
                "milk-hunt: timeout turn=%d action=%s timeout_s=%.1f"
                % (
                    int(timeout_summary.get("timeout_turn", -1)),
                    str(timeout_summary.get("timeout_action", "")),
                    float(timeout_summary.get("timeout_seconds", 0.0)),
                ),
                "warn",
            )
        return 3
    finally:
        if not args.no_stop:
            try:
                _run_turn(turn, "stop")
            except Exception:
                pass
        RigClient.terminate_listener(proc, timeout_s=5.0)


if __name__ == "__main__":
    sys.exit(main())
