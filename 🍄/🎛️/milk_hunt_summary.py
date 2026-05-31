from __future__ import annotations

import math
from typing import Any, Dict, List, Optional


def policy_action_counts(policy_decisions: List[Dict[str, Any]]) -> Dict[str, int]:
    counts: Dict[str, int] = {}
    for ev in policy_decisions:
        if not isinstance(ev, dict):
            continue
        action = ev.get("executed_action", ev.get("selected_action", ""))
        if not isinstance(action, str) or not action:
            continue
        counts[action] = counts.get(action, 0) + 1
    return counts


def policy_action_entropy(policy_decisions: List[Dict[str, Any]]) -> float:
    counts = policy_action_counts(policy_decisions)
    total = float(sum(counts.values()))
    if total <= 0.0:
        return 0.0
    h = 0.0
    for count in counts.values():
        p = float(count) / total
        if p > 0.0:
            h -= p * math.log(p, 2)
    return h


def policy_action_breakdown(policy_decisions: List[Dict[str, Any]]) -> Dict[str, Any]:
    counts = policy_action_counts(policy_decisions)
    total = int(sum(counts.values()))
    pct = {
        action: (float(count) / float(total))
        for action, count in counts.items()
        if total > 0
    }
    return {
        "policy_action_counts": counts,
        "policy_action_pct": pct,
        "policy_action_entropy_bits": policy_action_entropy(policy_decisions),
    }


def market_projection_summary(policy_decisions: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Telemetry view of what the market lattice served the hunter.

    Reads every `offer_quests` event from the policy decision trace, collects
    every offer's `market_projection` payload, and aggregates:

      - offers_with_projection / offers_total     (how many offers carried the payload)
      - factions_distinct                          (how many distinct factions bid)
      - resources_distinct                         (how many distinct emojis bid on)
      - market_score: mean / min / max
      - scarcity:     mean / min / max
      - alignment:    mean / min / max

    All read-only. Empty when no offer_quests events fired or projection
    flag was off (no payload to read).
    """
    factions: set[str] = set()
    resources: set[str] = set()
    scores: List[float] = []
    scarcities: List[float] = []
    alignments: List[float] = []
    offers_total = 0
    offers_with_projection = 0

    for ev in policy_decisions:
        if not isinstance(ev, dict):
            continue
        if str(ev.get("action", "")) != "offer_quests":
            continue
        offers = ev.get("offers", [])
        if not isinstance(offers, list):
            continue
        for offer in offers:
            if not isinstance(offer, dict):
                continue
            offers_total += 1
            proj = offer.get("market_projection")
            if not isinstance(proj, dict):
                continue
            offers_with_projection += 1
            faction = offer.get("faction")
            resource = offer.get("resource")
            if isinstance(faction, str) and faction:
                factions.add(faction)
            if isinstance(resource, str) and resource:
                resources.add(resource)
            for key, sink in (("market_score", scores), ("scarcity", scarcities), ("alignment", alignments)):
                v = proj.get(key)
                if isinstance(v, (int, float)):
                    sink.append(float(v))

    def _mmm(xs: List[float]) -> Dict[str, float]:
        if not xs:
            return {"mean": 0.0, "min": 0.0, "max": 0.0}
        return {
            "mean": sum(xs) / len(xs),
            "min": min(xs),
            "max": max(xs),
        }

    return {
        "offers_total": offers_total,
        "offers_with_projection": offers_with_projection,
        "factions_distinct": len(factions),
        "resources_distinct": len(resources),
        "market_score": _mmm(scores),
        "scarcity": _mmm(scarcities),
        "alignment": _mmm(alignments),
    }


def quest_cycle_gate_summary_fields(
    action_gate_policies: Dict[str, Dict[str, Any]],
    quest_cycle_gate_override: Optional[bool],
    *,
    actions: int,
    success: int,
    failed: int,
    cap_hits: int,
    cooldown_hits: int,
    cooldown_until_loop: int,
    fail_streak_final: int,
) -> Dict[str, Any]:
    quest_cycle_policy = action_gate_policies.get("quest_cycle", {})
    quest_cycle_enabled = bool(quest_cycle_policy.get("enabled", True))
    return {
        "action_gate_overrides": {"quest_cycle": quest_cycle_gate_override},
        "action_gate_quest_cycle_enabled": quest_cycle_enabled,
        "action_gate_quest_cycle_policy": quest_cycle_policy if quest_cycle_enabled else {},
        "action_gate_policies": action_gate_policies,
        "action_gate_quest_cycle_actions": actions,
        "action_gate_quest_cycle_success": success,
        "action_gate_quest_cycle_failed": failed,
        "action_gate_quest_cycle_cap_hits": cap_hits,
        "action_gate_quest_cycle_cooldown_hits": cooldown_hits,
        "action_gate_quest_cycle_cooldown_until_loop": cooldown_until_loop,
        "action_gate_quest_cycle_fail_streak_final": fail_streak_final,
    }


def vocab_milestone_fields(vocab_milestones: List[Dict[str, Any]]) -> Dict[str, Any]:
    first_step = (
        int(vocab_milestones[0].get("step", 0))
        if isinstance(vocab_milestones, list) and len(vocab_milestones) > 0
        else None
    )
    first_loop = (
        int(vocab_milestones[0].get("loop", 0))
        if isinstance(vocab_milestones, list) and len(vocab_milestones) > 0
        else None
    )
    gain_loops = sorted(
        {
            int(ms.get("loop", 0))
            for ms in vocab_milestones
            if isinstance(ms, dict) and int(ms.get("loop", 0)) > 0
        }
    )
    return {
        "first_vocab_milestone_step": first_step,
        "first_vocab_milestone_loop": first_loop,
        "vocab_gain_loops": gain_loops,
        "vocab_progress_gate_pass": first_loop is not None and int(first_loop) <= 6,
    }


def build_common_summary_fields(
    *,
    max_loops: int,
    strict_biome_economy: bool,
    allow_rig_resource_injection: bool,
    load_slot: Optional[int],
    profile_save: Optional[str],
    profile_save_index: Optional[str],
    resolved_profile_save: str,
    effective_policy_graph_path: str,
    scenario_id: str,
    console_profile: str,
    wait_progress_seconds: float,
    display_mode: str,
    policy_execution_backend: str,
    rig_listener_stdout: str,
    listener_log_path: Any,
    rig_log_profile: str,
    rig_log_categories: str,
    hunter_profile: str,
    hunter_policy_mode: str,
    use_engine_policy: bool,
    policy_actions_per_loop: int,
    policy_restrictions: bool,
    policy_epsilon: float,
    policy_ucb_scale: float,
    policy_reset_on_start: bool,
    policy_max_quest_actions_per_loop: int,
    policy_forbid_actions: List[str],
    policy_quest_cap_hits: int,
    action_gate_policies: Dict[str, Dict[str, Any]],
    quest_cycle_gate_override: Optional[bool],
    action_gate_quest_cycle_actions: int,
    action_gate_quest_cycle_success: int,
    action_gate_quest_cycle_failed: int,
    action_gate_quest_cycle_cap_hits: int,
    action_gate_quest_cycle_cooldown_hits: int,
    action_gate_quest_cycle_cooldown_until_loop: int,
    action_gate_quest_cycle_fail_streak: int,
    target_turn_hz: float,
    metrics_every: int,
    runtime_profile: str,
    runtime_env_overrides: Dict[str, str],
    reuse_listener: bool,
    include_offer_reward_resources: bool,
    include_offer_market_projection: bool,
    lindblad_drain_focus: bool,
    lindblad_drain_every: int,
    lindblad_drain_max_biomes_per_loop: int,
    lindblad_drain_max_plots: int,
    lindblad_drain_slices: int,
    lindblad_wait_phrames: int,
    lindblad_wait_seconds: float,
    lindblad_wait_threshold: float,
    lindblad_wait_max_phrames: int,
    lindblad_wait_max_seconds: float,
    lindblad_wait_poll_phrames: int,
    lindblad_wait_poll_seconds: float,
    configured_lindblad_biomes: List[str],
    advanced_mode: bool,
    timescale_top_k: int,
    timescale_objective_payload: Dict[str, Any],
    timescale_events: List[Dict[str, Any]],
    git_meta: Dict[str, Any],
) -> Dict[str, Any]:
    return {
        "max_loops": max_loops,
        "strict_biome_economy": strict_biome_economy,
        "allow_rig_resource_injection": allow_rig_resource_injection,
        "load_slot": load_slot,
        "profile_save": profile_save,
        "profile_save_index": profile_save_index,
        "resolved_profile_save": resolved_profile_save,
        "effective_policy_graph_path": effective_policy_graph_path,
        "scenario_id": scenario_id,
        "console_profile": console_profile,
        "wait_progress_seconds": float(wait_progress_seconds),
        "display_mode": display_mode,
        "policy_execution_backend": policy_execution_backend,
        "rig_listener_stdout": rig_listener_stdout,
        "rig_listener_log": str(listener_log_path) if listener_log_path is not None else "",
        "rig_log_profile": rig_log_profile,
        "rig_log_categories": rig_log_categories,
        "hunter_profile": hunter_profile,
        "hunter_policy_mode": hunter_policy_mode,
        "hunter_policy_active": use_engine_policy,
        "engine_policy_active": use_engine_policy,
        "policy_actions_per_loop": policy_actions_per_loop,
        "policy_restrictions_enabled": bool(policy_restrictions),
        "policy_epsilon": policy_epsilon,
        "policy_ucb_scale": policy_ucb_scale,
        "policy_reset_on_start": bool(policy_reset_on_start),
        "policy_max_quest_actions_per_loop": policy_max_quest_actions_per_loop,
        "policy_forbid_actions": policy_forbid_actions,
        "policy_quest_cap_hits": policy_quest_cap_hits,
        **quest_cycle_gate_summary_fields(
            action_gate_policies,
            quest_cycle_gate_override,
            actions=action_gate_quest_cycle_actions,
            success=action_gate_quest_cycle_success,
            failed=action_gate_quest_cycle_failed,
            cap_hits=action_gate_quest_cycle_cap_hits,
            cooldown_hits=action_gate_quest_cycle_cooldown_hits,
            cooldown_until_loop=action_gate_quest_cycle_cooldown_until_loop,
            fail_streak_final=action_gate_quest_cycle_fail_streak,
        ),
        "target_turn_hz": target_turn_hz,
        "metrics_every": metrics_every,
        "runtime_profile": runtime_profile,
        "runtime_env_overrides": runtime_env_overrides,
        "reuse_listener": bool(reuse_listener),
        "include_offer_reward_resources": include_offer_reward_resources,
        "include_offer_market_projection": include_offer_market_projection,
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
        "advanced_mode": advanced_mode,
        "timescale_top_k": timescale_top_k,
        "timescale_objective": timescale_objective_payload if advanced_mode else {},
        "timescale_events": timescale_events,
        "git_branch": git_meta.get("git_branch", ""),
        "git_commit": git_meta.get("git_commit", ""),
        "git_dirty_count": git_meta.get("git_dirty_count", 0),
        "git_dirty_files": git_meta.get("git_dirty_files", []),
    }


def apply_profile_metrics(summary: Dict[str, Any], profile_metrics: Dict[str, Any], pairs_final: int) -> Dict[str, Any]:
    summary["profile_metrics"] = profile_metrics
    summary["quest_offer_cycles"] = profile_metrics.get("quest_offer_cycles", 0)
    summary["quest_offers_seen"] = profile_metrics.get("quest_offers_seen", 0)
    summary["quest_offers_accepted"] = profile_metrics.get("quest_offers_accepted", 0)
    summary["quest_completions"] = profile_metrics.get("quest_completions", 0)
    summary["quest_complete_or_claim"] = profile_metrics.get("quest_complete_or_claim", 0)
    summary["quest_claims"] = profile_metrics.get("quest_claims", 0)
    summary["vocab_pairs_initial"] = profile_metrics.get("vocab_pairs_initial", 0)
    summary["vocab_pairs_final"] = profile_metrics.get("vocab_pairs_final", pairs_final)
    summary["vocab_pairs_learned"] = profile_metrics.get("vocab_pairs_learned", 0)
    summary["lindblad_drain_actions"] = profile_metrics.get("lindblad_drain_actions", 0)
    summary["lindblad_drains_established"] = profile_metrics.get("lindblad_drains_established", 0)
    summary["time_skip_actions"] = profile_metrics.get("time_skip_actions", 0)
    summary["time_skip_total_phrames"] = profile_metrics.get("time_skip_total_phrames", 0)
    summary["time_skip_total_evolved_steps"] = profile_metrics.get("time_skip_total_evolved_steps", 0)
    return summary


def add_milk_pair_index(summary: Dict[str, Any], final_pairs: List[Dict[str, Any]], milk_emoji: str) -> Dict[str, Any]:
    summary["milk_pair_index"] = None
    for idx, pair in enumerate(final_pairs):
        if pair.get("north") == milk_emoji or pair.get("south") == milk_emoji:
            summary["milk_pair_index"] = idx + 1
            break
    return summary
