class_name PolicyStateProjector
extends RefCounted

const MILK_EMOJI := "🍼"


static func build_candidates(state: Dictionary, graph: Dictionary, supported_actions: Array = []) -> Array:
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
	var forecast = state.get("discovery_forecast", {})
	if not (forecast is Dictionary):
		forecast = {}
	var locked_offers = _as_dict_array(state.get("locked_offers", []))
	var forbid_actions = _as_forbid_map(state.get("forbid_actions", []))
	var graph_actions = graph.get("action_priors", {})
	if not (graph_actions is Dictionary):
		graph_actions = {}
	var supported_map = _to_supported_map(supported_actions)

	if _action_enabled("victory_lap_partial", graph_actions, supported_map) and contains_milk_pair(known_pairs):
		var victory_params = _action_params(graph, "victory_lap_partial")
		candidates.append({
			"action": "victory_lap_partial",
			"params": {
				"max_registers": int(victory_params.get("max_registers", 8)),
				"milk_spend": int(victory_params.get("milk_spend", 0)),
				"phase_window": int(victory_params.get("phase_window", 1)),
			},
			"prior": _prior_value(graph_actions, "victory_lap_partial", "base", 8.5),
			"tags": ["milk_known"],
		})

	if _action_enabled("quest_cycle", graph_actions, supported_map):
		var quest_prior = quest_pressure(resources, offers, active_quests, known_pairs, graph, int(state.get("quest_no_vocab_streak", 0)))
		candidates.append({
			"action": "quest_cycle",
			"params": {},
			"prior": quest_prior,
			"tags": ["economy", "vocab"],
		})

	if _action_enabled("probe_cycle", graph_actions, supported_map):
		var probe_biome = choose_probe_biome(biomes, lindblad, resources, floors, graph)
		if probe_biome != "":
			candidates.append({
				"action": "probe_cycle",
				"params": {"biome": probe_biome},
				"prior": probe_cycle_prior(resources, floors, graph),
				"tags": ["projection", probe_biome],
			})

	if _action_enabled("lindblad_drain", graph_actions, supported_map):
		var drain_biome = choose_drain_biome(biomes, lindblad, resources, floors, graph)
		if drain_biome != "":
			var active_drain = float(active_drain_count(lindblad))
			candidates.append({
				"action": "lindblad_drain",
				"params": {"biome": drain_biome},
				"prior": lindblad_drain_prior(graph, active_drain),
				"tags": ["passive_gain", drain_biome],
			})

	if _action_enabled("lock_offer", graph_actions, supported_map):
		var lock_result = best_lockable_offer(offers, locked_offers, active_quests, known_pairs)
		if lock_result.has("offer_index"):
			candidates.append({
				"action": "lock_offer",
				"params": {"offer_index": lock_result.get("offer_index", 0)},
				"prior": lock_offer_prior(graph, lock_result),
				"tags": ["planning", "lock"],
			})

	if _action_enabled("discover_biome", graph_actions, supported_map):
		var eagle_stock = float(resources.get("🦅", 0.0))
		var min_eagles = _prior_value(graph_actions, "discover_biome", "min_eagles", 8.0)
		var max_biomes = int(_prior_value(graph_actions, "discover_biome", "max_biomes", 6.0))
		if eagle_stock >= min_eagles and biomes.size() < max_biomes:
			var forecast_bonus = discovery_forecast_bonus(forecast) * _prior_value(graph_actions, "discover_biome", "forecast_scale", 1.0)
			var divisor = max(1.0, _prior_value(graph_actions, "discover_biome", "eagle_divisor", 16.0))
			var eagle_cap = _prior_value(graph_actions, "discover_biome", "eagle_cap", 2.0)
			candidates.append({
				"action": "discover_biome",
				"params": {},
				"prior": _prior_value(graph_actions, "discover_biome", "base", 0.7) + min(eagle_cap, eagle_stock / divisor) + forecast_bonus,
				"tags": ["expansion"],
			})

	if _action_enabled("time_skip", graph_actions, supported_map):
		candidates.append({
			"action": "time_skip",
			"params": {"phrames": suggest_wait_phrames(lindblad, graph)},
			"prior": _prior_value(graph_actions, "time_skip", "base", 0.4) + float(active_drain_count(lindblad)) * _prior_value(graph_actions, "time_skip", "active_drain_scale", 0.35),
			"tags": ["accumulate"],
		})

	if _action_enabled("channel_drain", graph_actions, supported_map):
		var channel_target = choose_channel_drain_target(biomes, lindblad, graph)
		if not channel_target.is_empty():
			var active_drains = float(active_drain_count(lindblad))
			candidates.append({
				"action": "channel_drain",
				"params": channel_target,
				"prior": _prior_value(graph_actions, "channel_drain", "base", 0.6) + active_drains * _prior_value(graph_actions, "channel_drain", "active_drain_scale", 0.2),
				"tags": ["strategic_drain"],
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
	return filtered if not filtered.is_empty() else candidates


static func compute_reward_components(pre_state: Dictionary, post_state: Dictionary, execution: Dictionary, graph: Dictionary) -> Dictionary:
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
	var pre_locked = _as_dict_array(pre_state.get("locked_offers", []))
	var post_locked = _as_dict_array(post_state.get("locked_offers", []))
	var reward_terms = graph.get("reward_terms", {})
	if not (reward_terms is Dictionary):
		reward_terms = {}

	var delta_resources = sum_resources(post_resources) - sum_resources(pre_resources)
	var delta_pairs = float(post_pairs.size() - pre_pairs.size())
	var delta_active = float(pre_active.size() - post_active.size())
	var delta_biomes = float(post_biomes.size() - pre_biomes.size())
	var delta_drains = float(active_drain_count(post_lind) - active_drain_count(pre_lind))
	var delta_locked = float(post_locked.size() - pre_locked.size())
	var milk_bonus = 0.0
	if not contains_milk_pair(pre_pairs) and contains_milk_pair(post_pairs):
		milk_bonus = _reward_value(reward_terms, "milk_bonus", 120.0)

	var resource_term = delta_resources * _reward_value(reward_terms, "resource", 0.08)
	var pair_term = delta_pairs * _reward_value(reward_terms, "pair", 42.0)
	var active_quest_term = delta_active * _reward_value(reward_terms, "active_quest", 5.0)
	var biome_term = delta_biomes * _reward_value(reward_terms, "biome", 8.0)
	var drain_term = delta_drains * _reward_value(reward_terms, "drain", 2.5)
	var lock_term = delta_locked * _reward_value(reward_terms, "lock", 3.0)
	var reward = resource_term + pair_term + active_quest_term + biome_term + drain_term + lock_term + milk_bonus
	var execution_penalty = 0.0
	if execution is Dictionary and not bool(execution.get("ok", false)):
		execution_penalty = _reward_value(reward_terms, "execution_penalty", -4.0)
		reward += execution_penalty
	var clamped = clamp(
		reward,
		_reward_value(reward_terms, "reward_min", -120.0),
		_reward_value(reward_terms, "reward_max", 220.0)
	)
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


static func quest_pressure(resources: Dictionary, offers: Array, active_quests: Array, known_pairs: Array, graph: Dictionary, quest_no_vocab_streak: int) -> float:
	var affordable = 0
	for offer in offers:
		if not (offer is Dictionary):
			continue
		var resource = str(offer.get("resource", ""))
		var quantity = float(offer.get("quantity", 0.0))
		if resource != "" and quantity > 0.0 and float(resources.get(resource, 0.0)) >= quantity:
			affordable += 1
	var unknown_vocab_reward = 0
	var known = known_emoji_map(known_pairs)
	for offer in offers:
		if not (offer is Dictionary):
			continue
		var north = str(offer.get("reward_vocab_north", ""))
		var south = str(offer.get("reward_vocab_south", ""))
		if north != "" and not known.has(north):
			unknown_vocab_reward += 1
		if south != "" and not known.has(south):
			unknown_vocab_reward += 1
	var quest_cfg = _action_config(graph, "quest_cycle")
	var stagnation_cap = float(quest_cfg.get("stagnation_cap", 6.0))
	var stagnation_scale = float(quest_cfg.get("stagnation_scale", 0.45))
	var stagnation_bias = min(stagnation_cap, float(quest_no_vocab_streak) * stagnation_scale)
	return (
		float(quest_cfg.get("base", 0.7))
		+ float(active_quests.size()) * float(quest_cfg.get("active_quest", 0.3))
		+ float(affordable) * float(quest_cfg.get("affordable", 0.25))
		+ float(unknown_vocab_reward) * float(quest_cfg.get("unknown_vocab", 1.25))
		+ float(quest_cfg.get("bonus", 0.0))
		- stagnation_bias
	)


static func probe_cycle_prior(resources: Dictionary, floors: Dictionary, graph: Dictionary) -> float:
	var cfg = _action_config(graph, "probe_cycle")
	return float(cfg.get("base", 1.0)) + resource_pressure(resources, floors) * float(cfg.get("resource_pressure", 0.8))


static func lindblad_drain_prior(graph: Dictionary, active_drain_count_value: float) -> float:
	var cfg = _action_config(graph, "lindblad_drain")
	var prior = float(cfg.get("base", 0.9)) + active_drain_count_value * float(cfg.get("active_scale", 0.0))
	if active_drain_count_value <= 0.0:
		prior += float(cfg.get("inactive_bonus", 0.0))
	return prior


static func lock_offer_prior(graph: Dictionary, lock_result: Dictionary) -> float:
	var cfg = _action_config(graph, "lock_offer")
	return (
		float(cfg.get("base", 0.5))
		+ float(lock_result.get("discovery_value", 0.0)) * float(cfg.get("discovery_affinity", 6.0))
		+ float(lock_result.get("novelty", 0.0)) * float(cfg.get("novelty", 1.5))
	)


static func resource_pressure(resources: Dictionary, floors: Dictionary) -> float:
	if floors.is_empty():
		return 0.0
	var pressure = 0.0
	for emoji in floors.keys():
		var floor = float(floors.get(emoji, 0.0))
		if floor <= 0.0:
			continue
		var have = float(resources.get(emoji, 0.0))
		if have < floor:
			pressure += (floor - have) / max(1.0, floor)
	return pressure


static func choose_probe_biome(biomes: Array, lindblad: Dictionary, resources: Dictionary, floors: Dictionary, graph: Dictionary) -> String:
	if biomes.is_empty():
		return ""
	var cfg = _action_config(graph, "probe_cycle")
	var best_biome = str(biomes[0])
	var best_score = -1e18
	var biome_data = lindblad.get("biomes", {})
	if not (biome_data is Dictionary):
		biome_data = {}
	var pressure = resource_pressure(resources, floors)
	for biome in biomes:
		var bname = str(biome)
		var score = float(cfg.get("base", 1.0))
		var sink = biome_sink_flux(biome_data, bname)
		for emoji in sink.keys():
			var flux = float(sink.get(emoji, 0.0))
			var floor = float(floors.get(emoji, 0.0))
			if floor > 0.0 and float(resources.get(emoji, 0.0)) < floor:
				score += flux * float(cfg.get("deficit_flux", 4.0))
			else:
				score += flux * float(cfg.get("surplus_flux", 0.5))
		score += pressure * float(cfg.get("biome_pressure", 0.25))
		if score > best_score:
			best_score = score
			best_biome = bname
	return best_biome


static func choose_drain_biome(biomes: Array, lindblad: Dictionary, resources: Dictionary, floors: Dictionary, graph: Dictionary) -> String:
	if biomes.is_empty():
		return ""
	var cfg = _action_config(graph, "lindblad_drain")
	var best_biome = str(biomes[0])
	var best_score = -1e18
	var biome_data = lindblad.get("biomes", {})
	if not (biome_data is Dictionary):
		biome_data = {}
	for biome in biomes:
		var bname = str(biome)
		var sink = biome_sink_flux(biome_data, bname)
		var score = 0.0
		for emoji in sink.keys():
			var flux = float(sink.get(emoji, 0.0))
			var floor = float(floors.get(emoji, 0.0))
			if floor > 0.0 and float(resources.get(emoji, 0.0)) < floor:
				score += flux * float(cfg.get("deficit_flux", 5.0))
			else:
				score += flux * float(cfg.get("surplus_flux", 1.0))
		if score > best_score:
			best_score = score
			best_biome = bname
	return best_biome


static func choose_channel_drain_target(biomes: Array, lindblad: Dictionary, graph: Dictionary) -> Dictionary:
	var cfg = _action_config(graph, "channel_drain")
	if not bool(cfg.get("enabled", false)):
		return {}
	var biome_data = lindblad.get("biomes", {})
	if not (biome_data is Dictionary):
		return {}
	var best_gradient = 0.0
	var best_result: Dictionary = {}
	for biome in biomes:
		var bname = str(biome)
		var entry = biome_data.get(bname, {})
		if not (entry is Dictionary):
			continue
		var populations = entry.get("populations", {})
		if not (populations is Dictionary) or populations.size() < 2:
			var sink = entry.get("sink_fluxes", {})
			if sink is Dictionary and sink.size() >= 2:
				populations = sink
			else:
				continue
		var emojis = populations.keys()
		for i in range(emojis.size()):
			for j in range(i + 1, emojis.size()):
				var left = str(emojis[i])
				var right = str(emojis[j])
				var left_val = float(populations.get(left, 0.0))
				var right_val = float(populations.get(right, 0.0))
				var gradient = abs(left_val - right_val)
				if gradient > best_gradient:
					best_gradient = gradient
					best_result = {
						"biome": bname,
						"source_emoji": left if left_val > right_val else right,
						"target_emoji": right if left_val > right_val else left,
					}
	var min_gradient = float(cfg.get("min_gradient", 0.05))
	return {} if best_gradient < min_gradient else best_result


static func biome_sink_flux(biome_data: Dictionary, biome_name: String) -> Dictionary:
	var entry = biome_data.get(biome_name, {})
	if not (entry is Dictionary):
		return {}
	var sink = entry.get("sink_fluxes", {})
	return sink if sink is Dictionary else {}


static func active_drain_count(lindblad: Dictionary) -> int:
	return int(lindblad.get("active_plot_count", 0))


static func suggest_wait_phrames(lindblad: Dictionary, graph: Dictionary) -> int:
	var active_drains = active_drain_count(lindblad)
	var cfg = _action_params(graph, "time_skip")
	if active_drains <= 0:
		return int(cfg.get("phrames_no_drain", 4))
	var mid_threshold = int(cfg.get("mid_drain_threshold", 4))
	if active_drains <= mid_threshold:
		return int(cfg.get("phrames_mid_drain", 10))
	return int(cfg.get("phrames_high_drain", 16))


static func contains_milk_pair(pairs: Array) -> bool:
	for pair in pairs:
		if not (pair is Dictionary):
			continue
		if str(pair.get("north", "")) == MILK_EMOJI or str(pair.get("south", "")) == MILK_EMOJI:
			return true
	return false


static func known_emoji_map(pairs: Array) -> Dictionary:
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


static func best_lockable_offer(offers: Array, locked_offers: Array, active_quests: Array, known_pairs: Array) -> Dictionary:
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
	var known = known_emoji_map(known_pairs)
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


static func discovery_forecast_bonus(forecast: Dictionary) -> float:
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
	return clamp((max_prob - mean_prob) * 25.0, 0.0, 1.5)


static func sum_resources(resources: Dictionary) -> float:
	var total = 0.0
	for emoji in resources.keys():
		total += max(0.0, float(resources.get(emoji, 0.0)))
	return total


static func _action_enabled(action_name: String, graph_actions: Dictionary, supported_map: Dictionary) -> bool:
	if not supported_map.is_empty() and not supported_map.has(action_name):
		return false
	var cfg = graph_actions.get(action_name, {})
	if cfg is Dictionary and cfg.has("enabled"):
		return bool(cfg.get("enabled", true))
	return true


static func _to_supported_map(supported_actions: Array) -> Dictionary:
	var out: Dictionary = {}
	for action_name in supported_actions:
		var key = str(action_name)
		if key != "":
			out[key] = true
	return out


static func _as_forbid_map(raw) -> Dictionary:
	var out: Dictionary = {}
	if not (raw is Array):
		return out
	for action_name in raw:
		var key = str(action_name)
		if key != "":
			out[key] = true
	return out


static func _action_config(graph: Dictionary, action_name: String) -> Dictionary:
	var actions = graph.get("action_priors", {})
	if not (actions is Dictionary):
		return {}
	var cfg = actions.get(action_name, {})
	return cfg if cfg is Dictionary else {}


static func _action_params(graph: Dictionary, action_name: String) -> Dictionary:
	var params = graph.get("action_params", {})
	if not (params is Dictionary):
		return {}
	var cfg = params.get(action_name, {})
	return cfg if cfg is Dictionary else {}


static func _prior_value(actions: Dictionary, action_name: String, key: String, default_value: float) -> float:
	var cfg = actions.get(action_name, {})
	if not (cfg is Dictionary):
		return default_value
	return float(cfg.get(key, default_value))


static func _reward_value(reward_terms: Dictionary, key: String, default_value: float) -> float:
	return float(reward_terms.get(key, default_value))


static func _as_pairs(raw) -> Array:
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


static func _as_dict_array(raw) -> Array:
	var out: Array = []
	if not (raw is Array):
		return out
	for row in raw:
		if row is Dictionary:
			out.append(row)
	return out


static func _as_string_array(raw) -> Array:
	var out: Array = []
	if not (raw is Array):
		return out
	for item in raw:
		var s = str(item)
		if s != "":
			out.append(s)
	return out


static func _as_resource_map(raw) -> Dictionary:
	var out: Dictionary = {}
	if not (raw is Dictionary):
		return out
	for emoji in raw.keys():
		var key = str(emoji)
		if key != "":
			out[key] = float(raw.get(emoji, 0.0))
	return out
