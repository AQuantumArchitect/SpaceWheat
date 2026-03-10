class_name QuantumFiberPolicy
extends RefCounted

## QuantumFiberPolicy
## -----------------
## Lightweight in-engine controller for milk-hunt style automation.
## - Chooses high-level actions from live simulation state projections.
## - Learns online from reward deltas (resources, vocab, quests, discovery).
## - Keeps Python runner thin (queueing + logging) while policy lives in Godot.

const MILK_EMOJI := "🍼"
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
	}


func export_state() -> Dictionary:
	return {
		"version": 1,
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
			stagnation_penalty = -min(24.0, float(_quest_no_vocab_streak) * 1.5)
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
	var candidates: Array = []
	var resources = _as_resource_map(state.get("resources", {}))
	var known_pairs = _as_pairs(state.get("known_pairs", []))
	var active_quests = _as_dict_array(state.get("active_quests", []))
	var offers = _as_dict_array(state.get("offers", []))
	var biomes = _as_string_array(state.get("biomes", []))
	var floors = _as_resource_map(state.get("resource_floors", {}))
	var lindblad = state.get("lindblad", {})
	if not (lindblad is Dictionary):
		lindblad = {}
	var forbid_actions: Dictionary = {}
	var forbid_raw = state.get("forbid_actions", [])
	if forbid_raw is Array:
		for action_name in forbid_raw:
			var key = str(action_name)
			if key != "":
				forbid_actions[key] = true

	if _contains_milk_pair(known_pairs):
		candidates.append({
			"action": "victory_lap_partial",
			"params": {"max_registers": 8, "milk_spend": 0, "phase_window": 1},
			"prior": 8.5,
			"tags": ["milk_known"],
		})

	var quest_pressure = _quest_pressure(resources, offers, active_quests, known_pairs)
	candidates.append({
		"action": "quest_cycle",
		"params": {},
		"prior": quest_pressure,
		"tags": ["economy", "vocab"],
	})

	var probe_biome = _choose_probe_biome(biomes, lindblad, resources, floors)
	if probe_biome != "":
		candidates.append({
			"action": "probe_cycle",
			"params": {"biome": probe_biome},
			"prior": 1.0 + _resource_pressure(resources, floors) * 0.8,
			"tags": ["projection", probe_biome],
		})

	var drain_biome = _choose_drain_biome(biomes, lindblad, resources, floors)
	if drain_biome != "":
		var active_drain = int(_active_drain_count(lindblad))
		candidates.append({
			"action": "lindblad_drain",
			"params": {"biome": drain_biome},
			"prior": 0.9 + (1.0 if active_drain <= 0 else 0.0),
			"tags": ["passive_gain", drain_biome],
		})

	var forecast = state.get("discovery_forecast", {})
	if not (forecast is Dictionary):
		forecast = {}
	var locked_offers = _as_dict_array(state.get("locked_offers", []))

	var lock_result = _best_lockable_offer(offers, locked_offers, active_quests, known_pairs)
	if lock_result.has("offer_index"):
		candidates.append({
			"action": "lock_offer",
			"params": {"offer_index": lock_result.get("offer_index", 0)},
			"prior": 0.5 + float(lock_result.get("discovery_value", 0.0)) * 6.0 + float(lock_result.get("novelty", 0.0)) * 1.5,
			"tags": ["planning", "lock"],
		})

	var eagle_stock = float(resources.get("🦅", 0.0))
	if eagle_stock >= 8.0 and biomes.size() < 6:
		var forecast_bonus = _discovery_forecast_bonus(forecast)
		candidates.append({
			"action": "discover_biome",
			"params": {},
			"prior": 0.7 + min(2.0, eagle_stock / 16.0) + forecast_bonus,
			"tags": ["expansion"],
		})

	candidates.append({
		"action": "time_skip",
		"params": {"phrames": _suggest_wait_phrames(lindblad)},
		"prior": 0.4 + float(_active_drain_count(lindblad)) * 0.35,
		"tags": ["accumulate"],
	})

	if forbid_actions.is_empty():
		return candidates
	var filtered: Array = []
	for row in candidates:
		if not (row is Dictionary):
			continue
		var action_name = str(row.get("action", ""))
		if action_name != "" and forbid_actions.has(action_name):
			continue
		filtered.append(row)
	if filtered.is_empty():
		return candidates
	return filtered


func _quest_pressure(resources: Dictionary, offers: Array, active_quests: Array, known_pairs: Array) -> float:
	var affordable = 0
	for offer in offers:
		if not (offer is Dictionary):
			continue
		var resource = str(offer.get("resource", ""))
		var quantity = float(offer.get("quantity", 0.0))
		if resource != "" and quantity > 0.0 and float(resources.get(resource, 0.0)) >= quantity:
			affordable += 1
	var unknown_vocab_reward = 0
	var known = _known_emoji_map(known_pairs)
	for offer in offers:
		if not (offer is Dictionary):
			continue
		var n = str(offer.get("reward_vocab_north", ""))
		var s = str(offer.get("reward_vocab_south", ""))
		if n != "" and not known.has(n):
			unknown_vocab_reward += 1
		if s != "" and not known.has(s):
			unknown_vocab_reward += 1
	var stagnation_bias = min(6.0, float(_quest_no_vocab_streak) * 0.45)
	return 0.7 + float(active_quests.size()) * 0.3 + float(affordable) * 0.25 + float(unknown_vocab_reward) * 1.25 - stagnation_bias


func _resource_pressure(resources: Dictionary, floors: Dictionary) -> float:
	if floors.is_empty():
		return 0.0
	var p = 0.0
	for emoji in floors.keys():
		var floor = float(floors.get(emoji, 0.0))
		if floor <= 0.0:
			continue
		var have = float(resources.get(emoji, 0.0))
		if have < floor:
			p += (floor - have) / max(1.0, floor)
	return p


func _choose_probe_biome(biomes: Array, lindblad: Dictionary, resources: Dictionary, floors: Dictionary) -> String:
	if biomes.is_empty():
		return ""
	var best_biome = str(biomes[0])
	var best_score = -1e18
	var biome_data = lindblad.get("biomes", {})
	if not (biome_data is Dictionary):
		biome_data = {}
	var pressure = _resource_pressure(resources, floors)
	for biome in biomes:
		var bname = str(biome)
		var score = 1.0
		var sink = _biome_sink_flux(biome_data, bname)
		for emoji in sink.keys():
			var flux = float(sink.get(emoji, 0.0))
			var floor = float(floors.get(emoji, 0.0))
			if floor > 0.0 and float(resources.get(emoji, 0.0)) < floor:
				score += flux * 4.0
			else:
				score += flux * 0.5
		score += pressure * 0.25
		if score > best_score:
			best_score = score
			best_biome = bname
	return best_biome


func _choose_drain_biome(biomes: Array, lindblad: Dictionary, resources: Dictionary, floors: Dictionary) -> String:
	if biomes.is_empty():
		return ""
	var best_biome = str(biomes[0])
	var best_score = -1e18
	var biome_data = lindblad.get("biomes", {})
	if not (biome_data is Dictionary):
		biome_data = {}
	for biome in biomes:
		var bname = str(biome)
		var sink = _biome_sink_flux(biome_data, bname)
		var score = 0.0
		for emoji in sink.keys():
			var flux = float(sink.get(emoji, 0.0))
			var floor = float(floors.get(emoji, 0.0))
			if floor > 0.0 and float(resources.get(emoji, 0.0)) < floor:
				score += flux * 5.0
			else:
				score += flux
		if score > best_score:
			best_score = score
			best_biome = bname
	return best_biome


func _biome_sink_flux(biome_data: Dictionary, biome_name: String) -> Dictionary:
	var entry = biome_data.get(biome_name, {})
	if not (entry is Dictionary):
		return {}
	var sink = entry.get("sink_fluxes", {})
	return sink if sink is Dictionary else {}


func _active_drain_count(lindblad: Dictionary) -> int:
	return int(lindblad.get("active_plot_count", 0))


func _suggest_wait_phrames(lindblad: Dictionary) -> int:
	var active_drains = _active_drain_count(lindblad)
	if active_drains <= 0:
		return 4
	if active_drains <= 4:
		return 10
	return 16


func _compute_reward(pre_state: Dictionary, post_state: Dictionary, execution: Dictionary) -> float:
	var parts = _compute_reward_components(pre_state, post_state, execution)
	return float(parts.get("reward", 0.0))


func _compute_reward_components(pre_state: Dictionary, post_state: Dictionary, execution: Dictionary) -> Dictionary:
	var pre_resources = _as_resource_map(pre_state.get("resources", {}))
	var post_resources = _as_resource_map(post_state.get("resources", {}))
	var pre_pairs = _as_pairs(pre_state.get("known_pairs", []))
	var post_pairs = _as_pairs(post_state.get("known_pairs", []))
	var pre_active = _as_dict_array(pre_state.get("active_quests", []))
	var post_active = _as_dict_array(post_state.get("active_quests", []))
	var pre_biomes = _as_string_array(pre_state.get("biomes", []))
	var post_biomes = _as_string_array(post_state.get("biomes", []))

	var pre_lind = pre_state.get("lindblad", {})
	var post_lind = post_state.get("lindblad", {})
	if not (pre_lind is Dictionary):
		pre_lind = {}
	if not (post_lind is Dictionary):
		post_lind = {}

	var delta_resources = _sum_resources(post_resources) - _sum_resources(pre_resources)
	var delta_pairs = float(post_pairs.size() - pre_pairs.size())
	var delta_active = float(pre_active.size() - post_active.size())
	var delta_biomes = float(post_biomes.size() - pre_biomes.size())
	var delta_drains = float(_active_drain_count(post_lind) - _active_drain_count(pre_lind))
	var milk_bonus = 0.0
	if (not _contains_milk_pair(pre_pairs)) and _contains_milk_pair(post_pairs):
		milk_bonus = 120.0

	var pre_locked = _as_dict_array(pre_state.get("locked_offers", []))
	var post_locked = _as_dict_array(post_state.get("locked_offers", []))
	var delta_locked = float(post_locked.size() - pre_locked.size())
	var lock_term = delta_locked * 3.0

	var resource_term = delta_resources * 0.08
	var pair_term = delta_pairs * 42.0
	var active_quest_term = delta_active * 5.0
	var biome_term = delta_biomes * 8.0
	var drain_term = delta_drains * 2.5
	var reward = resource_term + pair_term + active_quest_term + biome_term + drain_term + lock_term + milk_bonus
	var execution_penalty = 0.0

	if execution is Dictionary and not bool(execution.get("ok", false)):
		execution_penalty = -4.0
		reward += execution_penalty
	var clamped = clamp(reward, -120.0, 220.0)
	return {
		"delta_resources": delta_resources,
		"delta_pairs": delta_pairs,
		"delta_active_quests": delta_active,
		"delta_biomes": delta_biomes,
		"delta_drains": delta_drains,
		"delta_locked": delta_locked,
		"resource_term": resource_term,
		"pair_term": pair_term,
		"active_quest_term": active_quest_term,
		"biome_term": biome_term,
		"drain_term": drain_term,
		"lock_term": lock_term,
		"milk_bonus": milk_bonus,
		"execution_penalty": execution_penalty,
		"reward_raw": reward,
		"reward": clamped,
	}


func _sum_resources(resources: Dictionary) -> float:
	var total = 0.0
	for emoji in resources.keys():
		total += max(0.0, float(resources.get(emoji, 0.0)))
	return total


func _contains_milk_pair(pairs: Array) -> bool:
	for pair in pairs:
		if not (pair is Dictionary):
			continue
		if str(pair.get("north", "")) == MILK_EMOJI or str(pair.get("south", "")) == MILK_EMOJI:
			return true
	return false


func _known_emoji_map(pairs: Array) -> Dictionary:
	var out: Dictionary = {}
	for pair in pairs:
		if not (pair is Dictionary):
			continue
		var north = str(pair.get("north", ""))
		var south = str(pair.get("south", ""))
		if north != "":
			out[north] = true
		if south != "":
			out[south] = true
	return out


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
	if locked_offers.size() >= 3:
		return {}
	var locked_ids: Dictionary = {}
	for locked in locked_offers:
		if locked is Dictionary:
			var lid = str(locked.get("id", ""))
			if lid != "":
				locked_ids[lid] = true
	var active_ids: Dictionary = {}
	for quest in active_quests:
		if quest is Dictionary:
			var aid = str(quest.get("id", ""))
			if aid != "":
				active_ids[aid] = true
	var known = _known_emoji_map(known_pairs)
	var best: Dictionary = {}
	var best_score = -1.0
	for i in range(offers.size()):
		var offer = offers[i]
		if not (offer is Dictionary):
			continue
		var oid = str(offer.get("id", ""))
		if oid != "" and (locked_ids.has(oid) or active_ids.has(oid)):
			continue
		var north = str(offer.get("reward_vocab_north", ""))
		var south = str(offer.get("reward_vocab_south", ""))
		var novelty = 0.0
		if north != "" and not known.has(north):
			novelty += 1.0
		if south != "" and not known.has(south):
			novelty += 1.0
		if novelty <= 0.0:
			continue
		var discovery_aff = float(offer.get("discovery_affinity", 0.0))
		var score = discovery_aff + novelty * 0.5
		if score > best_score:
			best_score = score
			best = {
				"offer_index": i,
				"discovery_value": discovery_aff,
				"novelty": novelty,
			}
	return best


func _discovery_forecast_bonus(forecast: Dictionary) -> float:
	if forecast.is_empty():
		return 0.0
	var max_prob = 0.0
	var sum_prob = 0.0
	var count = 0
	for biome_name in forecast.keys():
		var entry = forecast.get(biome_name, {})
		if not (entry is Dictionary):
			continue
		var prob = float(entry.get("probability", 0.0))
		sum_prob += prob
		count += 1
		if prob > max_prob:
			max_prob = prob
	if count <= 0:
		return 0.0
	var mean_prob = sum_prob / float(count)
	var spread = max_prob - mean_prob
	return clamp(spread * 25.0, 0.0, 1.5)
