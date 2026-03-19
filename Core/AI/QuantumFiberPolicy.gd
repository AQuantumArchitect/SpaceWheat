class_name QuantumFiberPolicy
extends RefCounted

## QuantumFiberPolicy
## -----------------
## Lightweight in-engine controller for milk-hunt style automation.
## - Chooses high-level actions from live simulation state projections.
## - Learns online from reward deltas (resources, vocab, quests, discovery).
## - Keeps Python runner thin (queueing + logging) while policy lives in Godot.

const MILK_EMOJI := "🍼"
const PolicyGraph = preload("res://Core/AI/PolicyGraph.gd")
const PolicyStateProjector = preload("res://Core/AI/PolicyStateProjector.gd")
const ACTIONS: Array[String] = [
	"quest_cycle",
	"probe_cycle",
	"lindblad_drain",
	"time_skip",
	"discover_biome",
	"victory_lap_partial",
	"lock_offer",
]

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _profile: String = "default"
var _epsilon: float = 0.18
var _ucb_scale: float = 1.10
var _max_history: int = 160
var _step_count: int = 0
var _action_stats: Dictionary = {}
var _last_reward: float = 0.0
var _last_reward_components: Dictionary = {}
var _quest_no_vocab_streak: int = 0
var _last_decision: Dictionary = {}
var _history: Array = []
var _policy_graph: Dictionary = {}


func _init() -> void:
	_rng.randomize()
	reset({})


func reset(config: Dictionary = {}) -> Dictionary:
	_profile = str(config.get("profile", "default") or "default")
	_epsilon = clamp(float(config.get("epsilon", 0.18)), 0.0, 1.0)
	_ucb_scale = max(0.0, float(config.get("ucb_scale", 1.10)))
	_max_history = max(16, int(config.get("max_history", 160)))
	_step_count = 0
	_last_reward = 0.0
	_last_reward_components = {}
	_quest_no_vocab_streak = 0
	_last_decision = {}
	_history.clear()
	_action_stats.clear()
	var graph_lines = config.get("policy_graph_jsonl", [])
	_policy_graph = PolicyGraph.load_resolved_graph("ucb", _profile, graph_lines)
	if config.get("policy_graph", null) is Dictionary:
		_policy_graph = PolicyGraph.apply_patch(_policy_graph, config.get("policy_graph", {}))
	for action_name in ACTIONS:
		_action_stats[action_name] = {
			"count": 0,
			"value": 0.0,
			"last_score": 0.0,
			"last_reward": 0.0,
		}
	return get_snapshot()


func get_snapshot() -> Dictionary:
	return {
		"policy_type": "ucb",
		"profile": _profile,
		"epsilon": _epsilon,
		"ucb_scale": _ucb_scale,
		"step_count": _step_count,
		"last_reward": _last_reward,
		"last_reward_components": _last_reward_components.duplicate(true),
		"quest_no_vocab_streak": _quest_no_vocab_streak,
		"last_decision": _last_decision.duplicate(true),
		"action_stats": _action_stats.duplicate(true),
		"history_tail": _history.duplicate(true),
		"policy_graph": _policy_graph.duplicate(true),
		"policy_graph_jsonl": PolicyGraph.snapshot_to_graph_lines(_policy_graph),
	}


func export_state() -> Dictionary:
	return {
		"version": 1,
		"policy_type": "ucb",
		"profile": _profile,
		"epsilon": _epsilon,
		"ucb_scale": _ucb_scale,
		"step_count": _step_count,
		"last_reward": _last_reward,
		"last_reward_components": _last_reward_components.duplicate(true),
		"quest_no_vocab_streak": _quest_no_vocab_streak,
		"last_decision": _last_decision.duplicate(true),
		"action_stats": _action_stats.duplicate(true),
		"history_tail": _history.duplicate(true),
		"policy_graph": _policy_graph.duplicate(true),
		"policy_graph_jsonl": PolicyGraph.snapshot_to_graph_lines(_policy_graph),
	}


func load_state(state: Dictionary) -> Dictionary:
	if not (state is Dictionary) or state.is_empty():
		return get_snapshot()

	if state.has("profile"):
		_profile = str(state.get("profile", _profile))
	if state.has("epsilon"):
		_epsilon = clamp(float(state.get("epsilon", _epsilon)), 0.0, 1.0)
	if state.has("ucb_scale"):
		_ucb_scale = max(0.0, float(state.get("ucb_scale", _ucb_scale)))
	if state.has("step_count"):
		_step_count = max(0, int(state.get("step_count", _step_count)))
	if state.has("last_reward"):
		_last_reward = float(state.get("last_reward", _last_reward))
	var reward_components = state.get("last_reward_components", {})
	_last_reward_components = reward_components.duplicate(true) if reward_components is Dictionary else {}
	if state.has("quest_no_vocab_streak"):
		_quest_no_vocab_streak = max(0, int(state.get("quest_no_vocab_streak", 0)))

	var decision = state.get("last_decision", {})
	_last_decision = decision.duplicate(true) if decision is Dictionary else {}

	_history.clear()
	var raw_history = state.get("history_tail", [])
	if raw_history is Array:
		for row in raw_history:
			if row is Dictionary:
				_history.append(row.duplicate(true))
	if _history.size() > _max_history:
		_history = _history.slice(_history.size() - _max_history, _history.size())

	var defaults: Dictionary = {}
	for action_name in ACTIONS:
		defaults[action_name] = {
			"count": 0,
			"value": 0.0,
			"last_score": 0.0,
			"last_reward": 0.0,
		}
	var raw_stats = state.get("action_stats", {})
	_action_stats = defaults
	if raw_stats is Dictionary:
		for action_name in ACTIONS:
			var raw = raw_stats.get(action_name, {})
			if not (raw is Dictionary):
				continue
			_action_stats[action_name] = {
				"count": max(0, int(raw.get("count", 0))),
				"value": float(raw.get("value", 0.0)),
				"last_score": float(raw.get("last_score", 0.0)),
				"last_reward": float(raw.get("last_reward", 0.0)),
			}
	var graph_lines = state.get("policy_graph_jsonl", [])
	_policy_graph = PolicyGraph.load_resolved_graph("ucb", _profile, graph_lines)
	var state_graph = state.get("policy_graph", {})
	if state_graph is Dictionary and not state_graph.is_empty():
		_policy_graph = PolicyGraph.apply_patch(_policy_graph, state_graph)

	return get_snapshot()


func decide(state: Dictionary) -> Dictionary:
	var candidates = _build_candidates(state)
	if candidates.is_empty():
		return {
			"ok": true,
			"mode": "fallback",
			"action": "time_skip",
			"params": {"phrames": 6},
			"rankings": [],
		}

	var explore = _rng.randf() < _epsilon
	var total = max(1, _step_count)
	var scored: Array = []
	for idx in range(candidates.size()):
		var candidate = candidates[idx]
		var action_name = str(candidate.get("action", ""))
		var prior = float(candidate.get("prior", 0.0))
		var stats = _action_stats.get(action_name, {})
		var count = int(stats.get("count", 0))
		var mean_value = float(stats.get("value", 0.0))
		var bonus = _ucb_scale * sqrt(log(float(total + 2)) / float(count + 1))
		var score = mean_value + prior + bonus
		scored.append({
			"idx": idx,
			"action": action_name,
			"score": score,
			"prior": prior,
			"value": mean_value,
			"bonus": bonus,
			"params": candidate.get("params", {}),
			"tags": candidate.get("tags", []),
		})

	scored.sort_custom(func(a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	var selected = scored[0]
	if explore and scored.size() > 1:
		var rand_idx = _rng.randi_range(0, scored.size() - 1)
		selected = scored[rand_idx]

	var selected_action = str(selected.get("action", "time_skip"))
	var selected_params = selected.get("params", {})
	if not (selected_params is Dictionary):
		selected_params = {}

	_last_decision = {
		"step": _step_count + 1,
		"mode": "explore" if explore else "exploit",
		"action": selected_action,
		"params": selected_params,
		"score": float(selected.get("score", 0.0)),
		"tags": selected.get("tags", []),
	}

	var top_rankings: Array = []
	for i in range(min(6, scored.size())):
		var row = scored[i]
		top_rankings.append({
			"action": row.get("action", ""),
			"score": float(row.get("score", 0.0)),
			"prior": float(row.get("prior", 0.0)),
			"value": float(row.get("value", 0.0)),
			"bonus": float(row.get("bonus", 0.0)),
			"tags": row.get("tags", []),
		})

	return {
		"ok": true,
		"mode": "explore" if explore else "exploit",
		"action": selected_action,
		"params": selected_params,
		"score": float(selected.get("score", 0.0)),
		"rankings": top_rankings,
	}


func observe(pre_state: Dictionary, decision: Dictionary, post_state: Dictionary, execution: Dictionary) -> Dictionary:
	var action_name = str(decision.get("action", ""))
	var reward_components = _compute_reward_components(pre_state, post_state, execution)
	var reward = float(reward_components.get("reward", 0.0))
	var delta_pairs = float(reward_components.get("delta_pairs", 0.0))
	var stagnation_penalty = 0.0
	if action_name == "quest_cycle":
		if delta_pairs <= 0.0:
			_quest_no_vocab_streak += 1
			var quest_cfg = _policy_graph.get("action_priors", {}).get("quest_cycle", {})
			var stag_scale = float(quest_cfg.get("stagnation_scale", 0.45)) if quest_cfg is Dictionary else 0.45
			var stag_cap = float(quest_cfg.get("stagnation_cap", 6.0)) if quest_cfg is Dictionary else 6.0
			stagnation_penalty = -min(stag_cap, float(_quest_no_vocab_streak) * stag_scale)
		else:
			_quest_no_vocab_streak = 0
	else:
		if delta_pairs > 0.0:
			_quest_no_vocab_streak = 0
	reward += stagnation_penalty
	reward = clamp(reward, -120.0, 220.0)
	reward_components["stagnation_penalty"] = stagnation_penalty
	reward_components["quest_no_vocab_streak"] = _quest_no_vocab_streak
	reward_components["reward_after_stagnation"] = reward
	_last_reward = reward
	_last_reward_components = reward_components.duplicate(true)
	_step_count += 1

	if _action_stats.has(action_name):
		var stats = _action_stats[action_name]
		var count = int(stats.get("count", 0)) + 1
		var prev = float(stats.get("value", 0.0))
		var updated = prev + ((reward - prev) / float(count))
		stats["count"] = count
		stats["value"] = updated
		stats["last_score"] = float(decision.get("score", 0.0))
		stats["last_reward"] = reward
		_action_stats[action_name] = stats

	var row = {
		"step": _step_count,
		"action": action_name,
		"reward": reward,
		"quest_no_vocab_streak": _quest_no_vocab_streak,
		"mode": str(decision.get("mode", "")),
		"exec_ok": bool(execution.get("ok", false)),
	}
	_history.append(row)
	if _history.size() > _max_history:
		_history = _history.slice(_history.size() - _max_history, _history.size())

	var action_stats = _action_stats.get(action_name, {})
	return {
		"ok": true,
		"step": _step_count,
		"action": action_name,
		"reward": reward,
		"reward_components": reward_components,
		"action_count": int(action_stats.get("count", 0)),
		"action_value": float(action_stats.get("value", 0.0)),
	}


func _build_candidates(state: Dictionary) -> Array:
	var projected_state = state.duplicate(true)
	projected_state["quest_no_vocab_streak"] = _quest_no_vocab_streak
	return PolicyStateProjector.build_candidates(projected_state, _policy_graph, ACTIONS)


func _quest_pressure(resources: Dictionary, offers: Array, active_quests: Array, known_pairs: Array) -> float:
	return PolicyStateProjector.quest_pressure(resources, offers, active_quests, known_pairs, _policy_graph, _quest_no_vocab_streak)


func _resource_pressure(resources: Dictionary, floors: Dictionary) -> float:
	return PolicyStateProjector.resource_pressure(resources, floors)


func _choose_probe_biome(biomes: Array, lindblad: Dictionary, resources: Dictionary, floors: Dictionary) -> String:
	return PolicyStateProjector.choose_probe_biome(biomes, lindblad, resources, floors, _policy_graph)


func _choose_drain_biome(biomes: Array, lindblad: Dictionary, resources: Dictionary, floors: Dictionary) -> String:
	return PolicyStateProjector.choose_drain_biome(biomes, lindblad, resources, floors, _policy_graph)


func _biome_sink_flux(biome_data: Dictionary, biome_name: String) -> Dictionary:
	return PolicyStateProjector.biome_sink_flux(biome_data, biome_name)


func _active_drain_count(lindblad: Dictionary) -> int:
	return PolicyStateProjector.active_drain_count(lindblad)


func _suggest_wait_phrames(lindblad: Dictionary) -> int:
	return PolicyStateProjector.suggest_wait_phrames(lindblad, _policy_graph)


func _compute_reward(pre_state: Dictionary, post_state: Dictionary, execution: Dictionary) -> float:
	var parts = _compute_reward_components(pre_state, post_state, execution)
	return float(parts.get("reward", 0.0))


func _compute_reward_components(pre_state: Dictionary, post_state: Dictionary, execution: Dictionary) -> Dictionary:
	return PolicyStateProjector.compute_reward_components(pre_state, post_state, execution, _policy_graph)


func _sum_resources(resources: Dictionary) -> float:
	return PolicyStateProjector.sum_resources(resources)


func _contains_milk_pair(pairs: Array) -> bool:
	return PolicyStateProjector.contains_milk_pair(pairs)


func _known_emoji_map(pairs: Array) -> Dictionary:
	return PolicyStateProjector.known_emoji_map(pairs)


func _as_pairs(raw) -> Array:
	var out: Array = []
	if not (raw is Array):
		return out
	for pair in raw:
		if not (pair is Dictionary):
			continue
		out.append({
			"north": str(pair.get("north", "")),
			"south": str(pair.get("south", "")),
		})
	return out


func _as_dict_array(raw) -> Array:
	var out: Array = []
	if not (raw is Array):
		return out
	for row in raw:
		if row is Dictionary:
			out.append(row)
	return out


func _as_string_array(raw) -> Array:
	var out: Array = []
	if not (raw is Array):
		return out
	for item in raw:
		var s = str(item)
		if s == "":
			continue
		out.append(s)
	return out


func _as_resource_map(raw) -> Dictionary:
	var out: Dictionary = {}
	if not (raw is Dictionary):
		return out
	for emoji in raw.keys():
		var key = str(emoji)
		if key == "":
			continue
		out[key] = float(raw.get(emoji, 0.0))
	return out


func _best_lockable_offer(offers: Array, locked_offers: Array, active_quests: Array, known_pairs: Array) -> Dictionary:
	return PolicyStateProjector.best_lockable_offer(offers, locked_offers, active_quests, known_pairs)


func _discovery_forecast_bonus(forecast: Dictionary) -> float:
	return PolicyStateProjector.discovery_forecast_bonus(forecast)


func get_policy_graph() -> Dictionary:
	return _policy_graph.duplicate(true)


func apply_policy_graph_lines(lines: Array) -> Dictionary:
	var result = PolicyGraph.apply_graph_lines(_policy_graph, lines)
	if bool(result.get("ok", false)):
		_policy_graph = result.get("graph", _policy_graph)
	return {
		"ok": bool(result.get("ok", false)),
		"errors": result.get("errors", []),
		"policy_graph": _policy_graph.duplicate(true),
	}
