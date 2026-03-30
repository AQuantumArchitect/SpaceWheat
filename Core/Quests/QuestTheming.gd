class_name QuestTheming
extends RefCounted

## GAME-SPECIFIC THEMING (SpaceWheat)
## Maps abstract QuestParameters -> concrete quest data
## THIS is where emojis and game content live!
##
## Abstract inputs: alignment, intensity, complexity, urgency, variety
## SpaceWheat outputs: resource emoji, quantity, time_limit, reward_multiplier

const FactionStateMatcher = preload("res://Core/QuantumSubstrate/FactionStateMatcher.gd")
const QuestTypes = preload("res://Core/Quests/QuestTypes.gd")
const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")
const VocabularyPairing = preload("res://Core/Quests/VocabularyPairing.gd")
const QuestRewards = preload("res://Core/Quests/QuestRewards.gd")
const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")
const VerboseHelper = preload("res://Core/Config/VerboseHelper.gd")

# Light bias toward simulated vocab when selecting north pole.
const NORTH_BIAS_WEIGHT: float = 1.3

static func _log(level: String, category: String, emoji: String, message: String) -> void:
	VerboseHelper.log(level, category, emoji, message)


static func apply_theming(params: FactionStateMatcher.QuestParameters, bath, economy = null, icon_map = null) -> Dictionary:
	"""Map abstract parameters to SpaceWheat quest

	Chooses quest type based on complexity and generates appropriate quest
	"""

	# Choose quest type based on abstract parameters
	var quest_type = _select_quest_type(params)

	# Generate quest based on type
	var quest: Dictionary

	match quest_type:
		QuestTypes.Type.DELIVERY:
			quest = _generate_delivery_quest(params, bath, economy, icon_map)
		QuestTypes.Type.SHAPE_ACHIEVE:
			quest = _generate_shape_achieve_quest(params)
		QuestTypes.Type.SHAPE_MAINTAIN:
			quest = _generate_shape_maintain_quest(params)
		QuestTypes.Type.EVOLUTION:
			quest = _generate_evolution_quest(params)
		QuestTypes.Type.ENTANGLEMENT:
			quest = _generate_entanglement_quest(params)
		_:
			quest = _generate_delivery_quest(params, bath, economy, icon_map)  # Fallback

	# Add quest type
	quest["type"] = quest_type

	return quest


static func _select_quest_type(params: FactionStateMatcher.QuestParameters) -> int:
	"""Choose quest type based on abstract parameters

	High complexity → shape/evolution quests (teach quantum manipulation)
	Medium complexity → mix
	Low complexity → mostly delivery (familiar gameplay)
	"""

	# High complexity: Advanced quantum quests
	if params.complexity > 0.7:
		if randf() < 0.5:
			return QuestTypes.Type.SHAPE_MAINTAIN
		else:
			return QuestTypes.Type.EVOLUTION

	# Medium complexity: Mix of types
	elif params.complexity > 0.4:
		var roll = randf()
		if roll < 0.5:
			return QuestTypes.Type.DELIVERY
		elif roll < 0.75:
			return QuestTypes.Type.SHAPE_ACHIEVE
		else:
			return QuestTypes.Type.ENTANGLEMENT

	# Low complexity: Mostly delivery (80%)
	else:
		return QuestTypes.Type.DELIVERY if randf() < 0.8 else QuestTypes.Type.SHAPE_ACHIEVE


static func _generate_delivery_quest(params: FactionStateMatcher.QuestParameters, bath, economy = null, icon_map = null) -> Dictionary:
	"""Generate traditional delivery quest (current system)"""

	# intensity → quantity in CREDITS (fallback when IconMap missing)
	var base_units = 1 + int(params.intensity * 4)  # 1-5 base
	var q2c = EconomyConstants.get_quantum_to_credits(economy)
	var quantity = base_units * q2c

	# Sample resource from ALLOWED emojis only (vocabulary constraint!)
	var allowed_emojis = params.available_emojis if params.available_emojis.size() > 0 else []
	var resource = _sample_from_allowed_emojis(bath, allowed_emojis, params, economy, icon_map)

	# If IconMap is available, map quantum mass → credits (1:1 direct mapping)
	if icon_map == null:
		icon_map = _get_icon_map_payload(bath)
	if icon_map and icon_map.has("by_emoji") and resource != "":
		var weight = icon_map["by_emoji"].get(resource, 0.0)
		if weight > 0.0:
			quantity = int(round(weight * q2c))
			quantity = max(quantity, 1)

	# Scale quantity with inventory using golden ratio exponent.
	# demand = inv^(1/φ) where φ = golden ratio ≈ 1.618
	# Strong feedback: small stockpile changes produce visible demand shifts.
	#   inv  2→1.5,  5→2.9,  8→4.0, 13→5.7, 21→8.1
	if economy != null and economy.has_method("get_resource") and resource != "":
		var inv = float(economy.get_resource(resource))
		if inv > 0.0:
			const INV_PHI = 0.6180339887  # 1/φ = (√5 - 1) / 2
			var fib_qty = int(round(pow(inv, INV_PHI)))
			fib_qty = max(fib_qty, 1)
			# Only scale UP from base quantity, never down
			quantity = max(quantity, fib_qty)

	# urgency → time limit
	var time_limit = _urgency_to_time(params.urgency)

	# alignment → reward multiplier
	var reward_mult = lerp(1.5, 5.0, params.alignment)

	return {
		"resource": resource,
		"quantity": quantity,
		"time_limit": time_limit,
		"reward_multiplier": reward_mult,
		"_alignment": params.alignment,
		"_intensity": params.intensity,
		"_complexity": params.complexity,
		"_urgency": params.urgency,
		"_variety": params.variety,
	}


static func _generate_shape_achieve_quest(params: FactionStateMatcher.QuestParameters) -> Dictionary:
	"""Generate 'achieve purity > X' style quest"""

	# Pick observable based on variety
	var observable = _pick_observable_from_variety(params.variety)
	var target_value = _calculate_target_value(params, observable)

	# Entropy quests want LOW values (entropy < X), others want HIGH (observable > X)
	var comparison = "<" if observable == "entropy" else ">"

	return {
		"observable": observable,  # "purity", "entropy", or "coherence"
		"target": target_value,
		"comparison": comparison,  # "<" for entropy, ">" for purity/coherence
		"reward_multiplier": lerp(2.0, 4.0, params.alignment),
		"time_limit": -1,  # No time limit for achievement
		"_alignment": params.alignment,
		"_intensity": params.intensity,
		"_complexity": params.complexity,
		"_urgency": params.urgency,
	}


static func _generate_shape_maintain_quest(params: FactionStateMatcher.QuestParameters) -> Dictionary:
	"""Generate 'maintain entropy < X for 30s' style quest"""

	var quest = _generate_shape_achieve_quest(params)
	quest["duration"] = 30.0  # Maintain for 30 seconds
	quest["reward_multiplier"] *= 1.5  # Higher reward for maintenance
	quest["elapsed"] = 0.0  # Track how long maintained

	return quest


static func _generate_evolution_quest(params: FactionStateMatcher.QuestParameters) -> Dictionary:
	"""Generate 'increase coherence by 0.3' style quest"""

	var observable = _pick_observable_from_variety(params.variety)
	var delta = lerp(0.1, 0.5, params.intensity)
	var direction = "increase" if randf() < 0.5 else "decrease"

	return {
		"observable": observable,
		"delta": delta,
		"direction": direction,
		"reward_multiplier": lerp(2.5, 5.0, params.alignment),
		"time_limit": lerp(120.0, 300.0, 1.0 - params.urgency) if params.urgency > 0.2 else -1,
		"initial_value": null,  # Will be set when quest starts
		"_alignment": params.alignment,
		"_intensity": params.intensity,
		"_complexity": params.complexity,
		"_urgency": params.urgency,
	}


static func _generate_entanglement_quest(params: FactionStateMatcher.QuestParameters) -> Dictionary:
	"""Generate 'create coherence > 0.6' quest"""

	return {
		"target_coherence": lerp(0.4, 0.8, params.intensity),
		"reward_multiplier": lerp(3.0, 6.0, params.alignment),
		"time_limit": -1,
		"_alignment": params.alignment,
		"_intensity": params.intensity,
		"_complexity": params.complexity,
	}


static func _pick_observable_from_variety(variety: float) -> String:
	"""Choose which observable based on variety parameter"""
	var roll = randf()

	if roll < 0.4:
		return "purity"
	elif roll < 0.7:
		return "entropy"
	else:
		return "coherence"


static func _calculate_target_value(params: FactionStateMatcher.QuestParameters, observable: String) -> float:
	"""Calculate target value based on intensity and observable type"""

	match observable:
		"purity":
			# High purity = ordered state
			return lerp(0.6, 0.95, params.intensity)
		"entropy":
			# High entropy = chaotic state
			return lerp(0.5, 0.9, params.intensity)
		"coherence":
			# High coherence = quantum entanglement
			return lerp(0.3, 0.7, params.intensity)

	return 0.7  # Fallback


static func _index_to_emoji(bath, index: int) -> String:
	"""Map basis index to emoji from bath's emoji list"""
	if bath == null:
		return _fallback_emoji(index)

	var density_matrix = bath.get("_density_matrix")
	if density_matrix == null:
		return _fallback_emoji(index)

	var emoji_list = density_matrix.emoji_list
	if index >= 0 and index < emoji_list.size():
		return emoji_list[index]

	return emoji_list[0] if emoji_list.size() > 0 else _fallback_emoji(index)


static func _fallback_emoji(index: int) -> String:
	"""Fallback when bath is unavailable - SpaceWheat defaults"""
	var fallbacks = ["🌾", "🍄", "💨", "🍂", "💰", "👥", "🌻"]
	return fallbacks[index % fallbacks.size()]


static func _sample_from_allowed_emojis(bath, allowed_emojis: Array, params, economy = null, icon_map = null) -> String:
	"""Sample emoji from bath's probability distribution, constrained to allowed vocabulary

	Strategy:
	1. Get bath's probability distribution
	2. Filter to only allowed emojis
	3. Renormalize probabilities
	4. Sample from filtered distribution

	If no bath or no probabilities, picks randomly from allowed emojis.
	"""

	if allowed_emojis.is_empty():
		_log("warn", "quest", "⚠️", "Empty allowed_emojis - fallback to 🌾")
		return "🌾"  # Ultimate fallback

	# Economy-weighted demand: sample proportional to player's resource quantities
	if economy != null and economy.has_method("get_resource"):
		var econ_emojis: Array = []
		var econ_weights: Array = []
		var econ_total = 0.0

		for emoji in allowed_emojis:
			var amount = economy.get_resource(emoji)
			if amount > 0:
				var weight = pow(amount + 1.0, 0.65)
				econ_emojis.append(emoji)
				econ_weights.append(weight)
				econ_total += weight

		if not econ_emojis.is_empty() and econ_total > 0.0:
			var roll = randf() * econ_total
			var cumulative = 0.0
			for i in range(econ_weights.size()):
				cumulative += econ_weights[i]
				if roll <= cumulative:
					var chosen = econ_emojis[i]
					_log("debug", "quest", "💰", "Sampled %s from economy (w=%.3f, roll=%.3f)" % [
						chosen, econ_weights[i], roll
					])
					return chosen
			return econ_emojis[0]

	if icon_map == null:
		icon_map = _get_icon_map_payload(bath)
	if icon_map and icon_map.has("by_emoji"):
		var by_emoji: Dictionary = icon_map["by_emoji"]
		var filtered_emojis: Array = []
		var filtered_weights: Array = []
		var total = 0.0

		for emoji in allowed_emojis:
			if by_emoji.has(emoji):
				var weight = float(by_emoji[emoji])
				if weight > 0.0:
					filtered_emojis.append(emoji)
					filtered_weights.append(weight)
					total += weight

		if filtered_emojis.is_empty() or total <= 0.0:
			# Faction emojis not in biome icon_map (e.g. outer-ring factions with
			# abstract/mystic emojis).  Use the biome's top-mass resource instead
			# so the delivery quest is completable with farm resources.
			var top_emoji = ""
			var top_weight = 0.0
			for emoji in by_emoji.keys():
				var w = float(by_emoji.get(emoji, 0.0))
				if w > top_weight:
					top_weight = w
					top_emoji = emoji
			if top_emoji != "":
				_log("debug", "quest", "🌾", "No IconMap overlap for faction emojis - using biome top: %s" % top_emoji)
				return top_emoji
			_log("debug", "quest", "🎲", "No IconMap overlap - random from allowed: %s" % allowed_emojis[0])
			return allowed_emojis[randi() % allowed_emojis.size()]

		# Sample from cumulative weights
		var roll = randf() * total
		var cumulative = 0.0
		for i in range(filtered_weights.size()):
			cumulative += filtered_weights[i]
			if roll <= cumulative:
				var chosen = filtered_emojis[i]
				_log("debug", "quest", "🎯", "Sampled %s from IconMap (w=%.3f, roll=%.3f)" % [
					chosen, filtered_weights[i], roll
				])
				return chosen

		return filtered_emojis[0]

	# No IconMap? Fall back to density matrix sampling
	if bath == null:
		var chosen = allowed_emojis[randi() % allowed_emojis.size()]
		_log("debug", "quest", "🎲", "No bath - random from allowed: %s" % chosen)
		return chosen

	var density_matrix = bath.get("_density_matrix")
	if density_matrix == null:
		var chosen = allowed_emojis[randi() % allowed_emojis.size()]
		_log("debug", "quest", "🎲", "No density matrix - random from allowed: %s" % chosen)
		return chosen

	# Get bath emoji list
	var bath_emojis = density_matrix.emoji_list

	# Find indices of allowed emojis in bath
	var allowed_indices = []
	var allowed_probs = []

	for i in range(bath_emojis.size()):
		if bath_emojis[i] in allowed_emojis:
			allowed_indices.append(i)
			allowed_probs.append(density_matrix.get_probability_by_index(i))

	# If no allowed emojis in bath, pick from allowed randomly
	if allowed_indices.is_empty():
		var chosen = allowed_emojis[randi() % allowed_emojis.size()]
		_log("debug", "quest", "🎲", "No overlap with bath - random from allowed: %s" % chosen)
		return chosen

	# Renormalize probabilities
	var total = 0.0
	for p in allowed_probs:
		total += p

	if total < 0.001:
		# No probability mass in allowed emojis, pick random
		return allowed_emojis[randi() % allowed_emojis.size()]

	for i in range(allowed_probs.size()):
		allowed_probs[i] /= total

	# Sample from renormalized distribution
	var roll = randf()
	var cumulative = 0.0
	for i in range(allowed_probs.size()):
		cumulative += allowed_probs[i]
		if roll <= cumulative:
			var chosen = bath_emojis[allowed_indices[i]]
			_log("debug", "quest", "🎯", "Sampled %s (p=%.3f, roll=%.3f) from bath" % [chosen, allowed_probs[i], roll])
			return chosen

	# Fallback
	var fallback = bath_emojis[allowed_indices[0]]
	_log("debug", "quest", "🎲", "Fallback to first allowed: %s" % fallback)
	return fallback


static func _get_icon_map_payload(bath) -> Dictionary:
	if bath == null:
		return _get_global_icon_map()
	if bath.has_method("get_icon_map"):
		return bath.get_icon_map()
	if "viz_cache" in bath and bath.viz_cache:
		return bath.viz_cache.get_icon_map()
	if bath.has_method("get_viz_cache"):
		var cache = bath.get_viz_cache()
		if cache and cache.has_method("get_icon_map"):
			return cache.get_icon_map()
	var global_map = _get_global_icon_map()
	return global_map if not global_map.is_empty() else {}


static func _get_global_icon_map() -> Dictionary:
	var tree = Engine.get_main_loop()
	if not tree or not tree.root:
		return {}
	var gsm = tree.root.get_node_or_null("/root/GameStateManager")
	if not gsm or not ("active_farm" in gsm):
		return {}
	var farm = gsm.active_farm
	if not farm or not ("biome_evolution_batcher" in farm):
		return {}
	var batcher = farm.biome_evolution_batcher
	if batcher and batcher.has_method("get_global_icon_map"):
		return batcher.get_global_icon_map()
	return {}


static func _urgency_to_time(urgency: float) -> float:
	"""Map urgency [0,1] to SpaceWheat time limits"""
	if urgency < 0.2:
		return -1  # No time limit
	elif urgency < 0.5:
		return 180  # Relaxed (3 minutes)
	elif urgency < 0.8:
		return 120  # Moderate (2 minutes)
	else:
		return 60   # Urgent (1 minute)


static func generate_quest(
	faction: Dictionary,
	bath,
	player_vocab: Array = [],
	bias_emojis: Array = [],
	economy = null,
	cached_obs = null,
	cached_icon_map = null
) -> Dictionary:
	"""Full pipeline: faction x bath -> themed quest

	Args:
		faction: Faction data with bits and signature
		bath: Current biome quantum state
		player_vocab: Emojis the player knows (for vocabulary filtering)
		bias_emojis: Optional emojis to bias toward for north pole selection
		economy: FarmEconomy for demand curve and resource lookups
		cached_obs: Pre-computed BiomeObservables (avoids O(dim²) per call)
		cached_icon_map: Pre-fetched icon map dict (avoids GSM tree walk per call)

	Returns:
		Quest dict, or error if no vocabulary overlap
	"""

	# 1. Get faction's complete vocabulary
	var faction_vocab = FactionDatabase.get_faction_vocabulary(faction)
	var faction_name = faction.get("name", "Unknown")

	_log("debug", "quest", "📚", "Quest gen: %s signature=%s axial=%s" % [
		faction_name,
		"".join(faction_vocab.signature),
		"".join(faction_vocab.axial.slice(0, 3)) + "..."
	])

	# 2. Find overlap with player's known vocabulary
	# Quest resources come from SIGNATURE ONLY (not axial vocabulary)
	var available_emojis = []
	if player_vocab.is_empty():
		available_emojis = faction_vocab.signature
		_log("debug", "quest", "🎲", "No player vocab filter - using full signature")
	else:
		available_emojis = FactionDatabase.get_vocabulary_overlap(faction_vocab.signature, player_vocab)
		_log("debug", "quest", "🔍", "Player knows %s, faction signature %s → available %s" % [
			"".join(player_vocab),
			"".join(faction_vocab.signature),
			"".join(available_emojis)
		])

	# 3. If no overlap, faction is inaccessible!
	if available_emojis.is_empty():
		_log("debug", "quest", "🚫", "%s inaccessible - no signature overlap with player vocab" % faction_name)
		return {
			"error": "no_vocabulary_overlap",
			"message": "Learn more about %s's interests first..." % faction.get("name", "Unknown"),
			"faction": faction.get("name", "Unknown"),
			"required_emojis": faction_vocab.signature.slice(0, 3),
			"faction_vocabulary": faction_vocab.signature
		}

	# 4. Extract abstract observables (use cached if provided — same bath for all factions)
	var obs = cached_obs if cached_obs else FactionStateMatcher.extract_observables(bath)

	# 5. Generate abstract parameters
	var faction_bits = faction.get("bits", [0,0,0,0,0,0,0,0,0,0,0,0])
	var params = FactionStateMatcher.generate_quest_parameters(faction_bits, obs, bath)

	# 6. Apply IconMap constraint (use cached if provided — same bath for all factions)
	var icon_map = cached_icon_map if cached_icon_map != null else _get_icon_map_payload(bath)
	if icon_map and icon_map.has("by_emoji"):
		var icon_emojis = icon_map["by_emoji"].keys()
		var filtered = FactionDatabase.get_vocabulary_overlap(available_emojis, icon_emojis)
		if not filtered.is_empty():
			available_emojis = filtered

	# 7. Add vocabulary constraint to params
	params.available_emojis = available_emojis

	# 8. Apply SpaceWheat theming (pass icon_map through to avoid re-fetching)
	var quest = apply_theming(params, bath, economy, icon_map)

	# 9. Add faction metadata
	quest["faction"] = faction.get("name", "Unknown")
	var signature = faction.get("sig", faction.get("signature", []))
	quest["faction_emoji"] = "".join(signature.slice(0, 3))
	quest["faction_signature"] = signature
	quest["bits"] = faction_bits

	quest["motto"] = faction.get("motto", null)
	quest["domain"] = faction.get("domain", "Unknown")
	quest["ring"] = faction.get("ring", "unknown")
	quest["description"] = faction.get("description", "")

	quest["banner_path"] = FactionDatabase.get_faction_banner_path(faction)

	# 10. Add vocabulary info
	quest["faction_vocabulary"] = faction_vocab.all
	quest["available_emojis"] = available_emojis
	quest["vocabulary_overlap_pct"] = float(available_emojis.size()) / max(faction_vocab.all.size(), 1)

	# 11. Resonance Gate for vocabulary rewards
	var resonance = _compute_vocab_resonance_probability(
		faction, obs,
		icon_map if icon_map else {},
		available_emojis, player_vocab, economy
	)
	var grant_vocab = randf() < resonance.get("p_vocab", 0.0)
	quest["reward_vocab_resonance"] = resonance
	quest["reward_vocab_granted"] = grant_vocab

	if grant_vocab:
		var vocab_pair = _roll_vocabulary_reward_pair(signature, player_vocab, bias_emojis)
		if vocab_pair.get("north", "") != "" and vocab_pair.get("south", "") != "":
			quest["reward_vocab_north"] = vocab_pair.get("north", "")
			quest["reward_vocab_south"] = vocab_pair.get("south", "")
			quest["reward_vocab_probability"] = vocab_pair.get("probability", 0.0)
			quest["reward_vocab_weight"] = vocab_pair.get("weight", 0.0)
		else:
			grant_vocab = false
			quest["reward_vocab_north"] = ""
			quest["reward_vocab_south"] = ""
			quest["reward_vocab_probability"] = 0.0
			quest["reward_vocab_weight"] = 0.0
	else:
		quest["reward_vocab_north"] = ""
		quest["reward_vocab_south"] = ""
		quest["reward_vocab_probability"] = 0.0
		quest["reward_vocab_weight"] = 0.0

	quest["reward_resources"] = QuestRewards.plan_resource_rewards(quest, faction, icon_map if icon_map else {})

	if grant_vocab:
		_log("debug", "quest", "📖", "Resonance gate opened (p=%.2f) -> vocab reward granted" % [
			float(resonance.get("p_vocab", 0.0))
		])
	else:
		_log("debug", "quest", "📖", "Resonance gate closed (p=%.2f) -> resource reward only" % [
			float(resonance.get("p_vocab", 0.0))
		])

	quest["_preferences"] = FactionStateMatcher.describe_preferences(faction_bits)
	quest["_observables"] = FactionStateMatcher.describe_observables(obs)

	return quest


static func _compute_vocab_resonance_probability(
	faction: Dictionary,
	obs,
	icon_map: Dictionary,
	available_emojis: Array,
	player_vocab: Array,
	economy = null
) -> Dictionary:
	"""Compute Resonance Gate probability for vocab rewards.

	p_vocab rises when:
	- Faction signature has strong mass in the current IconMap.
	- Observable coherence/purity are high.
	- Player has meaningful overlap with faction signature.
	- Player has accumulated inventory in faction signature emojis.
	"""
	var signature = faction.get("sig", faction.get("signature", []))
	var by_emoji: Dictionary = icon_map.get("by_emoji", {}) if icon_map is Dictionary else {}
	var total_mass = max(0.0001, float(icon_map.get("total", 0.0))) if icon_map is Dictionary else 1.0

	var signature_mass = 0.0
	for emoji in signature:
		signature_mass += max(0.0, float(by_emoji.get(emoji, 0.0)))
	var signature_ratio = signature_mass / total_mass

	var overlap_ratio = 0.0
	if signature.size() > 0:
		overlap_ratio = float(available_emojis.size()) / float(signature.size())

	var coherence = float(obs.coherence) if obs else 0.0
	var purity = float(obs.purity) if obs else 0.0

	var unknown_count = 0
	for emoji in signature:
		if emoji not in player_vocab:
			unknown_count += 1
	var unknown_ratio = float(unknown_count) / max(1.0, float(signature.size()))

	# Inventory mass: how much of the faction's signature has the player stockpiled?
	# Uses power-law scaling so accumulation matters.
	var inventory_mass = 0.0
	if economy != null and economy.has_method("get_resource"):
		var sig_inventory = 0.0
		for emoji in signature:
			sig_inventory += float(economy.get_resource(emoji))
		# Normalize: sig_inventory / (signature_size * 21) puts starting Fibonacci top (21) at ~1.0
		inventory_mass = sig_inventory / max(1.0, float(signature.size()) * 21.0)
		inventory_mass = clamp(inventory_mass, 0.0, 3.0)

	# Logistic gate: vocab rewards are the primary quest value in the Fibonacci economy
	# (resource rewards are net-negative trades for diversification).
	# Floor at 0.35 ensures vocab flows even with minimal biome evolution.
	# Factors that BOOST beyond floor: coherence, purity, overlap, unknown emojis.
	var x = (
		(1.5 * signature_ratio)
		+ (1.0 * coherence)
		+ (0.6 * purity)
		+ (1.5 * overlap_ratio)
		+ (1.2 * unknown_ratio)
		+ (1.8 * inventory_mass)
		- 0.5
	)
	var logistic = 1.0 / (1.0 + exp(-x))
	var p_vocab = clamp(0.35 + 0.50 * logistic, 0.35, 0.9)

	# Biome-native faction boost: factions native to the active biome get full
	# resonance; non-native factions get reduced vocab probability.
	# Only applies when the biome HAS native factions (StarterForest/Village have
	# none, so _is_biome_native tag is absent and all factions stay at full resonance).
	if faction.has("_is_biome_native") and not faction.get("_is_biome_native", false):
		p_vocab *= 0.5  # half vocab chance for non-native factions

	return {
		"p_vocab": p_vocab,
		"signature_ratio": signature_ratio,
		"overlap_ratio": overlap_ratio,
		"coherence": coherence,
		"purity": purity,
		"unknown_ratio": unknown_ratio,
		"inventory_mass": inventory_mass
	}


static func generate_display_text(quest: Dictionary) -> String:
	"""Generate human-readable quest description"""
	var quest_type = quest.get("type", QuestTypes.Type.DELIVERY)
	var time_limit = quest.get("time_limit", -1)

	match quest_type:
		QuestTypes.Type.DELIVERY:
			var resource = quest.get("resource", "?")
			var quantity = quest.get("quantity", 1)
			var text = "%s x %d" % [resource, quantity]
			if time_limit > 0:
				text += " in %ds" % int(time_limit)
			return text
		QuestTypes.Type.SHAPE_ACHIEVE:
			var observable = quest.get("observable", "purity")
			var comparison = quest.get("comparison", ">")
			var target = quest.get("target", 0.0)
			return "%s %s %.2f" % [observable, comparison, target]
		QuestTypes.Type.SHAPE_MAINTAIN:
			var observable = quest.get("observable", "purity")
			var comparison = quest.get("comparison", ">")
			var target = quest.get("target", 0.0)
			var duration = quest.get("duration", 0.0)
			return "%s %s %.2f for %ds" % [observable, comparison, target, int(duration)]
		QuestTypes.Type.EVOLUTION:
			var observable = quest.get("observable", "coherence")
			var delta = quest.get("delta", 0.0)
			var direction = quest.get("direction", "increase")
			return "%s %s by %.2f" % [direction, observable, delta]
		QuestTypes.Type.ENTANGLEMENT:
			var target_coherence = quest.get("target_coherence", 0.0)
			return "coherence > %.2f" % target_coherence
		_:
			return QuestTypes.get_type_description(quest_type)


static func describe_alignment_reason(quest: Dictionary) -> String:
	"""Explain why alignment is high/low for UI feedback"""
	var alignment = quest.get("_alignment", 0.5)
	var preferences = quest.get("_preferences", "")
	var observables = quest.get("_observables", "")

	if alignment > 0.7:
		return "Your farm state matches their preferences!"
	elif alignment > 0.4:
		return "Partial match with faction preferences."
	else:
		return "Farm state misaligned with faction preferences."


static func _roll_vocabulary_reward_pair(
	faction_signature: Array,
	player_vocab: Array,
	bias_emojis: Array = []
) -> Dictionary:
	"""Roll vocabulary reward pair at quest creation time (FACTION SIGNATURE)

	NEW STRATEGY (Faction Signature Rolls):
	1. Roll SOUTH pole from faction signature (weighted by player inventory, can be known/unknown)
	2. Roll NORTH pole from faction signature (weighted by connectedness + player vocab, must be unknown)

	Args:
		faction_signature: Faction's signature emojis
		player_vocab: Emojis the player already knows

	Returns:
		{north, south, weight, probability} or {north: "", south: ""} if none available
	"""
	var icon_registry = VocabularyPairing._get_icon_registry()
	if not icon_registry:
		return {"north": "", "south": "", "error": "no_icon_registry"}

	# Step 1: Roll SOUTH pole from faction signature (weighted by player inventory)
	# South can be known OR unknown to player
	# bias_emojis = active biome's emojis — boosts south pole toward biome-native resources
	var south_result = VocabularyPairing._roll_south_pole_from_signature(
		icon_registry,
		faction_signature,
		bias_emojis
	)

	if south_result.get("error"):
		_log("warn", "quest", "⚠️", "South roll failed: %s" % south_result.get("message", "unknown"))
		return {"north": "", "south": "", "error": south_result.get("error")}

	var south = south_result.south
	var south_connections = south_result.get("connections", {})

	# Step 2: Find NORTH candidates from faction signature
	# Must be: in faction signature AND unknown to player
	# Connection check: prefer IconRegistry connections, but faction co-membership
	# is sufficient (all signature emojis are considered reachable from each other).
	var has_icon_connections = not south_connections.is_empty()
	var north_candidates: Array = []
	for emoji in faction_signature:
		# Skip if player already knows this emoji
		if emoji in player_vocab:
			continue
		# Skip if same as south
		if emoji == south:
			continue
		# Skip if not connected to South (when IconRegistry has data)
		if has_icon_connections and not south_connections.has(emoji):
			continue

		# Calculate weight: connectedness to South + player vocab connectivity
		var connection_weight = south_connections[emoji].get("weight", 1.0)
		var vocab_connectivity = VocabularyPairing.calculate_vocab_connectivity(emoji, player_vocab, icon_registry)

		# Combined weight (TODO: clarify weighting formula with user)
		var combined_weight = connection_weight * (1.0 + vocab_connectivity)

		north_candidates.append({
			"emoji": emoji,
			"weight": combined_weight,
			"connection_weight": connection_weight,
			"vocab_connectivity": vocab_connectivity
		})

	if north_candidates.is_empty():
		_log("debug", "quest", "📖", "No unknown north candidates for south=%s in faction signature" % south)
		return {"north": "", "south": south, "no_north_candidates": true}

	# Step 3: Weighted roll for NORTH
	var total_weight = 0.0
	for candidate in north_candidates:
		total_weight += candidate.weight

	var north = north_candidates[0].emoji
	var north_weight = 0.0

	if total_weight > 0:
		var roll = randf() * total_weight
		var cumulative = 0.0
		for candidate in north_candidates:
			cumulative += candidate.weight
			if roll <= cumulative:
				north = candidate.emoji
				north_weight = candidate.weight
				break

	_log("debug", "quest", "📖", "Faction pair: %s → %s (weight=%.2f)" % [south, north, north_weight])

	return {
		"north": north,
		"south": south,
		"weight": north_weight,
		"probability": north_weight / total_weight if total_weight > 0 else 0.0,
		"south_weight": south_result.get("weight", 0.0)
	}
