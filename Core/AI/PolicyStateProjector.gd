class_name PolicyStateProjector
extends RefCounted

const MILK_EMOJI := "🍼"

# Milk navigation cache: computed once from the full faction graph.
# Three layers of distance:
#   _milk_distances: emoji → BFS hops through Hamiltonian couplings to 🍼
#   _faction_milk_values: faction_name → best milk distance of any signature emoji
#   _emoji_cascade_values: emoji → "if I learn this, what's the best faction I unlock?"
#     cascade = min(faction_milk_value for factions whose signature contains this emoji)
# These power the full steering loop:
#   stockpile resource → attract faction quests → learn vocab → steer discovery → reach milk
static var _milk_distances: Dictionary = {}
static var _faction_milk_values: Dictionary = {}  # faction_name → int
static var _emoji_cascade_values: Dictionary = {}  # emoji → int
static var _emoji_to_factions: Dictionary = {}  # emoji → Array[faction_name]
static var _faction_signatures: Dictionary = {}  # faction_name → Array[emoji]
static var _milk_graph_ready: bool = false
const _MILK_MAX_DISTANCE := 8


static func milk_distance(emoji: String) -> int:
	"""BFS distance from emoji to 🍼 through Hamiltonian couplings."""
	if not _milk_graph_ready:
		_build_milk_graph()
	return int(_milk_distances.get(emoji, _MILK_MAX_DISTANCE))


static func milk_cascade_value(emoji: String) -> int:
	"""Strategic distance: if I learn this emoji, what's the closest-to-milk faction I unlock?
	Lower = learning this emoji opens a path closer to milk."""
	if not _milk_graph_ready:
		_build_milk_graph()
	return int(_emoji_cascade_values.get(emoji, _MILK_MAX_DISTANCE))


static func faction_milk_value(faction_name: String) -> int:
	"""How close is this faction's signature to milk? min(milk_distance) over signature."""
	if not _milk_graph_ready:
		_build_milk_graph()
	return int(_faction_milk_values.get(faction_name, _MILK_MAX_DISTANCE))


static func get_faction_signatures() -> Dictionary:
	"""Return faction_name → Array[emoji] map for all factions."""
	if not _milk_graph_ready:
		_build_milk_graph()
	return _faction_signatures


static func get_emoji_to_factions() -> Dictionary:
	"""Return emoji → Array[faction_name] map."""
	if not _milk_graph_ready:
		_build_milk_graph()
	return _emoji_to_factions


static func _build_milk_graph() -> void:
	"""Build the full milk navigation graph from faction data. Runs once."""
	_milk_graph_ready = true
	var factions_path = "res://Core/Factions/data/factions_merged.json"
	var file = FileAccess.open(factions_path, FileAccess.READ)
	if not file:
		push_warning("PolicyStateProjector: can't open %s for milk graph" % factions_path)
		_milk_distances[MILK_EMOJI] = 0
		return
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	if err != OK or not (json.data is Array):
		push_warning("PolicyStateProjector: failed to parse factions for milk graph")
		_milk_distances[MILK_EMOJI] = 0
		return

	# Pass 1: Build Hamiltonian coupling graph + faction membership maps
	var ham_graph: Dictionary = {}  # emoji → Array[emoji]
	for faction in json.data:
		if not (faction is Dictionary):
			continue
		var fname: String = str(faction.get("name", ""))
		var sig: Array = faction.get("sig", [])
		if fname == "" or sig.is_empty():
			continue
		_faction_signatures[fname] = sig.duplicate()
		for emoji in sig:
			if not _emoji_to_factions.has(emoji):
				_emoji_to_factions[emoji] = []
			if fname not in _emoji_to_factions[emoji]:
				_emoji_to_factions[emoji].append(fname)
		var ham = faction.get("hamiltonian", {})
		if not (ham is Dictionary):
			continue
		for source in ham.keys():
			var targets = ham[source]
			if not (targets is Dictionary):
				continue
			if not ham_graph.has(source):
				ham_graph[source] = []
			for target in targets.keys():
				if not ham_graph.has(target):
					ham_graph[target] = []
				if target not in ham_graph[source]:
					ham_graph[source].append(target)
				if source not in ham_graph[target]:
					ham_graph[target].append(source)

	# Pass 2: BFS from milk through Hamiltonian couplings
	_milk_distances[MILK_EMOJI] = 0
	var queue: Array = [MILK_EMOJI]
	var head := 0
	while head < queue.size():
		var current: String = queue[head]
		head += 1
		var d: int = _milk_distances[current]
		for neighbor in ham_graph.get(current, []):
			if not _milk_distances.has(neighbor):
				_milk_distances[neighbor] = d + 1
				queue.append(neighbor)

	# Pass 3: Faction milk values (min milk_distance over signature)
	for fname in _faction_signatures:
		var best = _MILK_MAX_DISTANCE
		for emoji in _faction_signatures[fname]:
			var d = int(_milk_distances.get(emoji, _MILK_MAX_DISTANCE))
			if d < best:
				best = d
		_faction_milk_values[fname] = best

	# Pass 4: Emoji cascade values
	# "If I learn emoji X, I now overlap with factions containing X.
	#  Those factions can teach me all their signature emojis.
	#  The cascade value = best faction_milk_value among factions containing X."
	for emoji in _emoji_to_factions:
		var best = _MILK_MAX_DISTANCE
		for fname in _emoji_to_factions[emoji]:
			var fmv = int(_faction_milk_values.get(fname, _MILK_MAX_DISTANCE))
			if fmv < best:
				best = fmv
		_emoji_cascade_values[emoji] = best


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
		var victory_prior = _prior_value(graph_actions, "victory_lap_partial", "base", 8.5)
		# Reduce priority if resources are depleted — don't suicide into victory
		var total_res = sum_resources(resources)
		var min_res = _prior_value(graph_actions, "victory_lap_partial", "min_resources", 10.0)
		if total_res < min_res:
			victory_prior *= 0.5  # Halve priority when resources are dangerously low
		candidates.append({
			"action": "victory_lap_partial",
			"params": {
				"max_registers": int(victory_params.get("max_registers", 8)),
				"milk_spend": int(victory_params.get("milk_spend", 0)),
				"phase_window": int(victory_params.get("phase_window", 1)),
			},
			"prior": victory_prior,
			"tags": ["milk_known"],
		})

	if _action_enabled("quest_cycle", graph_actions, supported_map):
		var rank_result = rank_offers(resources, offers, known_pairs, graph)
		var best_idx = int(rank_result.get("best_offer_index", -1))
		var quest_prior = quest_pressure(resources, offers, active_quests, known_pairs, graph, int(state.get("quest_no_vocab_streak", 0)))
		if best_idx >= 0:
			# Sharpen prior with best-offer quality
			var quest_cfg = _action_config(graph, "quest_cycle")
			if float(rank_result.get("novelty", 0.0)) >= 2.0:
				quest_prior += float(quest_cfg.get("frontier_bonus", 1.5))
			if bool(rank_result.get("is_milk", false)):
				quest_prior += float(quest_cfg.get("best_offer_milk", 3.0))
			quest_prior += float(rank_result.get("milk_distance_gain", 0.0)) * float(quest_cfg.get("prior_milk_distance_gain", 0.9))
			quest_prior += float(rank_result.get("milk_cascade_gain", 0.0)) * float(quest_cfg.get("prior_milk_cascade_gain", 0.4))
		else:
			# No affordable offers — still emit quest_cycle at reduced prior
			# (quest_cycle also completes/claims active quests and refreshes offers)
			quest_prior = max(0.1, quest_prior * 0.3)
		candidates.append({
			"action": "quest_cycle",
			"params": ({
				"offer_index": best_idx,
				"cost_ratio": rank_result.get("cost_ratio", 0.0) if best_idx >= 0 else 0.0,
				"novelty": rank_result.get("novelty", 0.0) if best_idx >= 0 else 0.0,
				"is_milk": rank_result.get("is_milk", false) if best_idx >= 0 else false,
			}).merged(rank_result if best_idx >= 0 else {}, true),
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
		var lock_result = best_lockable_offer(offers, locked_offers, active_quests, known_pairs, resources)
		if lock_result.has("offer_index"):
			candidates.append({
				"action": "lock_offer",
				"params": {"offer_index": lock_result.get("offer_index", 0)}.merged(lock_result, true),
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

	# Milk proximity progress: did the player get closer to milk?
	# Computed from the BFS distance of the player's closest known emoji to 🍼.
	# This is the key signal that lets the quantum policy LEARN to seek milk.
	var pre_milk_dist = _closest_milk_distance_from_pairs(pre_pairs)
	var post_milk_dist = _closest_milk_distance_from_pairs(post_pairs)
	var delta_milk_distance = float(pre_milk_dist - post_milk_dist)  # Positive = got closer

	var resource_term = delta_resources * _reward_value(reward_terms, "resource", 0.08)
	var pair_term = delta_pairs * _reward_value(reward_terms, "pair", 42.0)
	var active_quest_term = delta_active * _reward_value(reward_terms, "active_quest", 5.0)
	var biome_term = delta_biomes * _reward_value(reward_terms, "biome", 8.0)
	var drain_term = delta_drains * _reward_value(reward_terms, "drain", 2.5)
	var lock_term = delta_locked * _reward_value(reward_terms, "lock", 3.0)
	var milk_progress_term = delta_milk_distance * _reward_value(reward_terms, "milk_progress", 15.0)
	var reward = resource_term + pair_term + active_quest_term + biome_term + drain_term + lock_term + milk_progress_term + milk_bonus
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
		"delta_milk_distance": delta_milk_distance,
		"pre_milk_distance": pre_milk_dist,
		"post_milk_distance": post_milk_dist,
		"resource_term": resource_term,
		"pair_term": pair_term,
		"active_quest_term": active_quest_term,
		"biome_term": biome_term,
		"drain_term": drain_term,
		"lock_term": lock_term,
		"milk_progress_term": milk_progress_term,
		"milk_bonus": milk_bonus,
		"execution_penalty": execution_penalty,
		"reward_raw": reward,
		"reward": clamped,
	}


static func quest_pressure(resources: Dictionary, offers: Array, active_quests: Array, known_pairs: Array, graph: Dictionary, quest_no_vocab_streak: int) -> float:
	# Cost-relative scoring: weight each affordable offer by surplus fraction
	# surplus = 1 - (quantity/have). Cheap quests score high, expensive ones score low.
	var cost_ratio_sum = 0.0
	var affordable_count = 0
	const INV_PHI = 0.6180339887  # 1/φ
	var demand_awareness = 0.0
	for offer in offers:
		if not (offer is Dictionary):
			continue
		var resource = str(offer.get("resource", ""))
		var quantity = float(offer.get("quantity", 0.0))
		var have = float(resources.get(resource, 0.0))
		if resource != "" and quantity > 0.0 and have >= quantity:
			var surplus = 1.0 - (quantity / max(1.0, have))
			cost_ratio_sum += surplus
			affordable_count += 1
			# Demand curve term: inv^(1/φ - 1) = fraction the curve claims
			# High inventory → small fraction (good deal). Low → large (bad deal).
			if have > 1.0:
				demand_awareness += pow(have, INV_PHI - 1.0)
	if affordable_count > 0:
		demand_awareness = demand_awareness / float(affordable_count)
	# Invert: low demand_awareness (high inventory) → bonus to quest_cycle
	var curve_bonus = (1.0 - demand_awareness) if affordable_count > 0 else 0.0

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
		+ cost_ratio_sum * float(quest_cfg.get("affordable", 0.25))
		+ float(unknown_vocab_reward) * float(quest_cfg.get("unknown_vocab", 1.25))
		+ curve_bonus * float(quest_cfg.get("demand_curve", 0.5))
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
		+ float(lock_result.get("milk_distance_gain", 0.0)) * float(cfg.get("milk_distance_gain", 2.5))
		+ float(lock_result.get("milk_cascade_gain", 0.0)) * float(cfg.get("milk_cascade_gain", 1.2))
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
			# Milk cascade: prefer biomes producing emojis from milk-valuable factions.
			# Stockpiling these emojis attracts quests from factions closer to milk.
			var cv = milk_cascade_value(str(emoji))
			if cv < _MILK_MAX_DISTANCE:
				score += flux * (2.0 / max(1.0, float(cv)))
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


static func _closest_milk_distance_from_pairs(pairs: Array) -> int:
	"""Compute the closest milk distance from all emojis the player knows.
	This is the player's 'progress toward milk' metric."""
	var best = _MILK_MAX_DISTANCE
	for pair in pairs:
		if not (pair is Dictionary):
			continue
		var north = str(pair.get("north", ""))
		var south = str(pair.get("south", ""))
		if north != "":
			var d = milk_distance(north)
			if d < best:
				best = d
		if south != "":
			var d = milk_distance(south)
			if d < best:
				best = d
	return best


static func _closest_milk_cascade_from_pairs(pairs: Array) -> int:
	var best = _MILK_MAX_DISTANCE
	for pair in pairs:
		if not (pair is Dictionary):
			continue
		for emoji in [str(pair.get("north", "")), str(pair.get("south", ""))]:
			if emoji == "":
				continue
			var c = milk_cascade_value(emoji)
			if c < best:
				best = c
	return best


static func _offer_milk_metrics(offer: Dictionary, current_best_dist: int, current_best_cascade: int) -> Dictionary:
	var north = str(offer.get("reward_vocab_north", ""))
	var south = str(offer.get("reward_vocab_south", ""))
	var best_offer_dist = _MILK_MAX_DISTANCE
	var best_offer_cascade = _MILK_MAX_DISTANCE
	var milk_hint = 0.0
	var corridor_emojis: Array = []
	for emoji in [north, south]:
		if emoji == "":
			continue
		var d = milk_distance(emoji)
		var c = milk_cascade_value(emoji)
		if d < best_offer_dist:
			best_offer_dist = d
		if c < best_offer_cascade:
			best_offer_cascade = c
		if d < _MILK_MAX_DISTANCE:
			milk_hint = max(milk_hint, 8.0 / max(1.0, float(d)))
			if d <= max(1, current_best_dist):
				corridor_emojis.append(emoji)
		if c < _MILK_MAX_DISTANCE:
			milk_hint = max(milk_hint, 5.0 / max(1.0, float(c)))
	var milk_distance_gain = max(0, current_best_dist - best_offer_dist) if best_offer_dist < _MILK_MAX_DISTANCE else 0
	var milk_cascade_gain = max(0, current_best_cascade - best_offer_cascade) if best_offer_cascade < _MILK_MAX_DISTANCE else 0
	return {
		"reward_vocab_north": north,
		"reward_vocab_south": south,
		"best_offer_milk_distance": best_offer_dist,
		"best_offer_milk_cascade": best_offer_cascade,
		"current_milk_distance": current_best_dist,
		"current_milk_cascade": current_best_cascade,
		"milk_distance_gain": milk_distance_gain,
		"milk_cascade_gain": milk_cascade_gain,
		"milk_hint": milk_hint,
		"corridor_emojis": corridor_emojis,
		"offer_faction": str(offer.get("faction", "")),
		"offer_id": int(offer.get("id", -1)),
	}


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


static func best_lockable_offer(offers: Array, locked_offers: Array, active_quests: Array, known_pairs: Array, resources: Dictionary = {}) -> Dictionary:
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
	var current_best_dist = _closest_milk_distance_from_pairs(known_pairs)
	var current_best_cascade = _closest_milk_cascade_from_pairs(known_pairs)
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
		# Cost-relative scoring (like rank_offers)
		var surplus = 0.0
		var resource = str(offer.get("resource", ""))
		var qty = float(offer.get("quantity", 0.0))
		if resource != "" and qty > 0.0 and not resources.is_empty():
			var have = float(resources.get(resource, 0.0))
			if have >= qty:
				surplus = 1.0 - (qty / max(1.0, have))
		var milk_metrics = _offer_milk_metrics(offer, current_best_dist, current_best_cascade)
		var score = (
			discovery_aff
			+ novelty * 1.5
			+ surplus * 0.8
			+ float(milk_metrics.get("milk_hint", 0.0))
			+ float(milk_metrics.get("milk_distance_gain", 0.0)) * 6.0
			+ float(milk_metrics.get("milk_cascade_gain", 0.0)) * 3.0
		)
		if score > best_score:
			best_score = score
			best = {
				"offer_index": i,
				"discovery_value": discovery_aff,
				"novelty": novelty,
				"score": score,
			}
			best.merge(milk_metrics, true)
	return best


static func rank_offers(resources: Dictionary, offers: Array, known_pairs: Array, graph: Dictionary) -> Dictionary:
	"""Rank quest offers by value, accounting for cost-to-inventory ratio and vocab novelty.

	Returns: {best_offer_index, best_score, cost_ratio, novelty, is_milk} or empty if none affordable.
	"""
	var known = known_emoji_map(known_pairs)
	var current_best_dist = _closest_milk_distance_from_pairs(known_pairs)
	var current_best_cascade = _closest_milk_cascade_from_pairs(known_pairs)
	var cfg = _action_config(graph, "quest_cycle")
	var best: Dictionary = {}
	var best_score = -1e18
	for i in range(offers.size()):
		var offer = offers[i]
		if not (offer is Dictionary):
			continue
		var resource = str(offer.get("resource", ""))
		var qty = float(offer.get("quantity", 0.0))
		if resource == "" or qty <= 0.0:
			continue
		var have = float(resources.get(resource, 0.0))
		if have < qty:
			continue
		var north = str(offer.get("reward_vocab_north", ""))
		var south = str(offer.get("reward_vocab_south", ""))
		var novelty = 0.0
		if north != "" and not known.has(north):
			novelty += 1.0
		if south != "" and not known.has(south):
			novelty += 1.0
		var is_milk = (north == MILK_EMOJI or south == MILK_EMOJI)
		var surplus = 1.0 - (qty / max(1.0, have))
		var discovery_aff = float(offer.get("discovery_affinity", 0.0))
		var reward_resources = offer.get("reward_resources", {})
		var reward_sum = 0.0
		if reward_resources is Dictionary:
			for emoji in reward_resources.keys():
				reward_sum += max(0.0, float(reward_resources.get(emoji, 0.0)))
		var milk_metrics = _offer_milk_metrics(offer, current_best_dist, current_best_cascade)
		# Score: vocab novelty dominates, surplus rewards cheap quests, milk is king
		var score = (
			novelty * 32.0
			+ surplus * 12.0
			+ reward_sum * 0.22
			+ discovery_aff * 18.0
			+ float(milk_metrics.get("milk_hint", 0.0)) * float(cfg.get("milk_hint_scale", 1.0))
			+ float(milk_metrics.get("milk_distance_gain", 0.0)) * float(cfg.get("milk_distance_gain", 28.0))
			+ float(milk_metrics.get("milk_cascade_gain", 0.0)) * float(cfg.get("milk_cascade_gain", 12.0))
			+ (420.0 if is_milk else 0.0)
			+ (20.0 if novelty >= 2.0 else 0.0)
		)
		if score > best_score:
			best_score = score
			best = {
				"best_offer_index": i,
				"best_score": score,
				"cost_ratio": qty / max(1.0, have),
				"novelty": novelty,
				"is_milk": is_milk,
				"offer_faction": str(offer.get("faction", "")),
				"offer_id": int(offer.get("id", -1)),
			}
			best.merge(milk_metrics, true)
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


static func policy_describe() -> Dictionary:
	"""Return the full policy parameter schema with defaults, ranges, and descriptions.

	Designed for LLM introspection: an LLM can call this to understand what
	parameters are available, what they do, and what values to try.
	"""
	return {
		"action_priors": {
			"quest_cycle": {
				"base": {"default": 0.7, "min": 0.0, "max": 3.0, "description": "Base prior for quest acceptance. Higher = prefer quests over exploration."},
				"active_quest": {"default": 0.3, "min": 0.0, "max": 2.0, "description": "Prior bonus per active quest (completion attempts)."},
				"affordable": {"default": 0.25, "min": 0.0, "max": 2.0, "description": "Weight of cost-relative affordability (surplus fraction sum)."},
				"unknown_vocab": {"default": 1.25, "min": 0.0, "max": 5.0, "description": "Bonus per unknown emoji in current offers. Primary vocab learning driver."},
				"demand_curve": {"default": 0.5, "min": 0.0, "max": 2.0, "description": "Weight of demand curve awareness. High = prefer quests for high-inventory resources."},
				"frontier_bonus": {"default": 1.5, "min": 0.0, "max": 5.0, "description": "Extra prior when best offer teaches 2 new emojis (frontier pair)."},
				"best_offer_milk": {"default": 3.0, "min": 0.0, "max": 10.0, "description": "Extra prior when best offer yields milk vocabulary (win condition)."},
				"milk_hint_scale": {"default": 1.0, "min": 0.0, "max": 5.0, "description": "Tie-break weight for static milk/cascade proximity when ranking quest offers."},
				"milk_distance_gain": {"default": 28.0, "min": 0.0, "max": 100.0, "description": "Quest-offer score bonus per step of direct milk-distance improvement over current known vocab."},
				"milk_cascade_gain": {"default": 12.0, "min": 0.0, "max": 50.0, "description": "Quest-offer score bonus per step of milk-cascade improvement over current known vocab."},
				"prior_milk_distance_gain": {"default": 0.9, "min": 0.0, "max": 5.0, "description": "Extra quest_cycle prior per step of direct milk-distance improvement in the best affordable offer."},
				"prior_milk_cascade_gain": {"default": 0.4, "min": 0.0, "max": 3.0, "description": "Extra quest_cycle prior per step of milk-cascade improvement in the best affordable offer."},
				"bonus": {"default": 0.0, "min": -5.0, "max": 5.0, "description": "Flat bonus/penalty to quest prior. Use for character personality."},
				"stagnation_scale": {"default": 0.45, "min": 0.0, "max": 2.0, "description": "Per-streak penalty when quests fail to teach new vocab."},
				"stagnation_cap": {"default": 6.0, "min": 0.0, "max": 10.0, "description": "Maximum stagnation penalty before capping."},
			},
			"probe_cycle": {
				"base": {"default": 1.0, "min": 0.0, "max": 3.0, "description": "Base prior for quantum measurement/harvest. Higher = farm more."},
				"resource_pressure": {"default": 0.8, "min": 0.0, "max": 3.0, "description": "How much resource deficit boosts probing priority."},
				"deficit_flux": {"default": 4.0, "min": 0.0, "max": 10.0, "description": "Weight for biomes producing deficit resources."},
				"surplus_flux": {"default": 0.5, "min": 0.0, "max": 3.0, "description": "Weight for biomes producing surplus resources."},
			},
			"lindblad_drain": {
				"base": {"default": 0.9, "min": 0.0, "max": 3.0, "description": "Base prior for passive income drain setup."},
				"inactive_bonus": {"default": 0.0, "min": 0.0, "max": 3.0, "description": "Extra bonus when no drains are currently active."},
				"active_scale": {"default": 0.0, "min": -1.0, "max": 2.0, "description": "Per-active-drain adjustment to priority."},
			},
			"discover_biome": {
				"base": {"default": 0.7, "min": 0.0, "max": 3.0, "description": "Base prior for biome discovery/expansion."},
				"min_eagles": {"default": 8.0, "min": 1.0, "max": 50.0, "description": "Minimum eagle resources required to attempt discovery."},
				"max_biomes": {"default": 6, "min": 2, "max": 10, "description": "Maximum unlocked biomes before stopping expansion."},
				"eagle_divisor": {"default": 16.0, "min": 1.0, "max": 50.0, "description": "Eagles/divisor added to prior (higher divisor = less eagle influence)."},
				"eagle_cap": {"default": 2.0, "min": 0.0, "max": 5.0, "description": "Maximum eagle-based prior contribution."},
				"forecast_scale": {"default": 1.0, "min": 0.0, "max": 3.0, "description": "Weight of discovery forecast bonus (favoring concentrated probability)."},
			},
			"lock_offer": {
				"base": {"default": 0.5, "min": 0.0, "max": 3.0, "description": "Base prior for locking a quest offer for later."},
				"discovery_affinity": {"default": 6.0, "min": 0.0, "max": 15.0, "description": "Weight of biome discovery affinity when scoring lockable offers."},
				"novelty": {"default": 1.5, "min": 0.0, "max": 5.0, "description": "Weight of vocab novelty when scoring lockable offers."},
				"milk_distance_gain": {"default": 2.5, "min": 0.0, "max": 15.0, "description": "Extra lock-offer prior per step of direct milk-distance improvement held by the offer."},
				"milk_cascade_gain": {"default": 1.2, "min": 0.0, "max": 10.0, "description": "Extra lock-offer prior per step of milk-cascade improvement held by the offer."},
			},
			"time_skip": {
				"base": {"default": 0.4, "min": 0.0, "max": 2.0, "description": "Base prior for waiting (letting passive income accumulate)."},
				"active_drain_scale": {"default": 0.35, "min": 0.0, "max": 2.0, "description": "Per-active-drain bonus to time_skip priority."},
			},
			"victory_lap_partial": {
				"base": {"default": 8.5, "min": 0.0, "max": 15.0, "description": "Prior when milk is known (triggers victory sequence). Very high = immediate win attempt."},
			},
		},
		"reward_terms": {
			"resource": {"default": 0.08, "min": -1.0, "max": 2.0, "description": "Reward per unit of net resource change."},
			"pair": {"default": 42.0, "min": 0.0, "max": 200.0, "description": "Reward per new vocab pair learned. Primary learning incentive."},
			"active_quest": {"default": 5.0, "min": 0.0, "max": 50.0, "description": "Reward for completing an active quest."},
			"biome": {"default": 8.0, "min": 0.0, "max": 50.0, "description": "Reward for discovering a new biome."},
			"drain": {"default": 2.5, "min": 0.0, "max": 20.0, "description": "Reward for setting up a new passive drain."},
			"lock": {"default": 3.0, "min": 0.0, "max": 20.0, "description": "Reward for locking a quest offer."},
			"milk_progress": {"default": 15.0, "min": 0.0, "max": 50.0, "description": "Reward per step closer to milk in the vocab graph. The key signal that teaches the quantum policy to seek milk."},
			"milk_bonus": {"default": 120.0, "min": 0.0, "max": 500.0, "description": "One-time bonus when milk pair is first discovered."},
			"execution_penalty": {"default": -4.0, "min": -20.0, "max": 0.0, "description": "Penalty when an action fails execution."},
		},
		"action_limits": {
			"min_loop": {"default": 1, "min": 0, "max": 10, "description": "Minimum loop index before action limits engage."},
			"max_per_loop": {"default": 1, "min": 1, "max": 5, "description": "Max actions per loop iteration."},
			"max_total_locks": {"default": 2, "min": 0, "max": 5, "description": "Maximum simultaneous locked offers."},
			"pairs_soft_cap": {"default": 20, "min": 5, "max": 89, "description": "Soft cap on learned pairs before policy adjusts."},
		},
		"dynamics": {
			"apply_stagnation_penalty": {"default": true, "description": "Whether quest stagnation penalty is active."},
		},
	}
