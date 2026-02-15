class_name QuestRewards
extends RefCounted

## Quest Reward System
## Handles reward generation and vocabulary teaching for completed quests

const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")
const VocabularyPairing = preload("res://Core/Quests/VocabularyPairing.gd")
const FactionRegistry = preload("res://Core/Factions/FactionRegistry.gd")

static var _faction_registry_cache = null
static var _faction_dynamic_cache: Dictionary = {}

const RESOURCE_REWARD_MIN_TOTAL: int = 8
const RESOURCE_REWARD_MAX_TOTAL: int = 240
const RESOURCE_REWARD_MIN_PER_EMOJI: int = 4
const RESOURCE_REWARD_BASE_RATIO: float = 0.4

## Icon Modification: How quest rewards can modify icon physics
class IconModification:
	enum Type {
		ADD_COUPLING,       # Add new hamiltonian coupling
		MODIFY_COUPLING,    # Change existing coupling strength
		REDUCE_DECAY,       # Lower decay rate
		ADD_LINDBLAD,       # Add transfer channel
		UNLOCK_BELL_FEATURE,# Enable bell-activated feature
		ADD_DRIVER,         # Add time-dependent forcing
		BOOST_SELF_ENERGY,  # Increase self-energy (stability)
	}

	var type: Type
	var icon_emoji: String = ""
	var parameters: Dictionary = {}  # Type-specific params

	func _init():
		type = Type.MODIFY_COUPLING

	func _to_string() -> String:
		return "IconMod<%s>[%s]" % [Type.keys()[type], icon_emoji]


class QuestReward:
	"""Rewards for completing a quest"""
	var money_amount: int = 0  # 💰-credits reward (no universal currency!)
	var resource_rewards: Dictionary = {}  # {emoji: credits} primary payout
	var learned_vocabulary: Array[String] = []  # Emojis player learned (both north and south)
	var learned_pairs: Array = []  # Array of {north, south, weight, probability} - paired vocabulary
	var reputation_gain: int = 0  # Future: faction reputation
	var bonus_multiplier: float = 1.0  # From alignment
	var icon_modifications: Array = []  # Array[IconModification] - physics changes


static func generate_reward(quest: Dictionary, bath, player_vocab: Array) -> QuestReward:
	"""Generate rewards for quest completion

	Uses PRE-ROLLED vocabulary pair from quest creation time (not rolled now).
	This ensures player sees the same pair in preview and actual reward.

	Args:
		quest: Completed quest data (with reward_vocab_north/south)
		bath: Current biome quantum bath
		player_vocab: Player's known emojis

	Returns:
		QuestReward with vocabulary (no universal 💰 currency!)
	"""
	var reward = QuestReward.new()

	# NO UNIVERSAL MONEY! Money is just another emoji resource
	# Remove: reward.money_amount = ...
	reward.money_amount = 0  # No universal currency
	reward.bonus_multiplier = quest.get("reward_multiplier", 1.0)

	# Primary payout: faction-shaped resource rewards
	var faction_name = quest.get("faction", "")
	var faction_dict = _get_faction_by_name(faction_name)
	var pre_rolled_resources = quest.get("reward_resources", {})
	if pre_rolled_resources is Dictionary and not pre_rolled_resources.is_empty():
		reward.resource_rewards = _sanitize_resource_rewards(pre_rolled_resources)
	else:
		reward.resource_rewards = _build_resource_reward_plan(quest, faction_dict, false)

	# Use PRE-ROLLED vocabulary pair from quest creation
	var north = quest.get("reward_vocab_north", "")
	var south = quest.get("reward_vocab_south", "")

	if north != "":
		reward.learned_vocabulary.append(north)

		if south != "":
			# Full pair (both north and south)
			reward.learned_vocabulary.append(south)
			reward.learned_pairs.append({
				"north": north,
				"south": south,
				"weight": quest.get("reward_vocab_weight", 0.0),
				"probability": quest.get("reward_vocab_probability", 0.0)
			})
		else:
			# Single emoji (no connections found at creation time)
			push_warning("QuestRewards: Quest has north=%s but no south" % north)

	# Icon modification reward (for higher-tier quests)
	if faction_dict and should_grant_icon_modification(quest):
		var mod = generate_icon_modification(faction_dict, quest)
		reward.icon_modifications.append(mod)

	return reward


static func plan_resource_rewards(quest: Dictionary, faction: Dictionary = {}, icon_map: Dictionary = {}) -> Dictionary:
	"""Pre-roll resource rewards at quest creation time for deterministic UI/claim.

	CRITICAL: Ensures south pole emoji resources are granted (needed for vocab injection).
	Vocab injection costs 4 [south_emoji] + 10 🌱, so we must grant ≥4 of south emoji.
	"""
	var rewards = _build_resource_reward_plan(quest, faction, false, icon_map)

	# CRITICAL FIX: Always grant south pole resources for vocab injection
	var south = quest.get("reward_vocab_south", "")
	if south != "":
		# Ensure at least 4 south resources (needed for injection - scaled for 1:1 quantum mass economy)
		if not rewards.has(south):
			rewards[south] = 4
		else:
			rewards[south] = max(int(rewards[south]), 4)

	# Also grant some north pole resources (bonus)
	var north = quest.get("reward_vocab_north", "")
	if north != "" and north != south:
		# Ensure at least 10 north resources (bonus to help complete the pair - scaled for 1:1 economy)
		if not rewards.has(north):
			rewards[north] = 10
		else:
			rewards[north] = max(int(rewards[north]), 10)

	return rewards


static func estimate_resource_rewards(quest: Dictionary, faction: Dictionary = {}, icon_map: Dictionary = {}) -> Dictionary:
	"""Deterministic estimate for preview paths when quest has no pre-rolled bundle."""
	return _build_resource_reward_plan(quest, faction, true, icon_map)


static func _build_resource_reward_plan(quest: Dictionary, faction: Dictionary, deterministic: bool, icon_map: Dictionary = {}) -> Dictionary:
	var faction_name = quest.get("faction", faction.get("name", ""))
	var signature = quest.get("faction_signature", faction.get("sig", faction.get("signature", [])))
	var faction_dynamic = _get_faction_dynamic_data(faction_name, signature)

	var profile: Dictionary
	var total_budget: int

	# IconMap-projected rewards (north pole from quantum state)
	if not icon_map.is_empty() and icon_map.has("by_emoji"):
		profile = _compute_iconmap_reward_profile(faction_dynamic, icon_map)
		var iconmap_total = float(icon_map.get("total", 0.0))
		total_budget = int(clamp(round(iconmap_total), RESOURCE_REWARD_MIN_TOTAL, RESOURCE_REWARD_MAX_TOTAL))
	else:
		# Fallback: Hamiltonian eigenvalue rewards (old behavior)
		profile = _compute_hamiltonian_reward_profile(faction_dynamic)
		total_budget = _compute_total_resource_budget(quest, profile.get("dominant_eigenvalue", 0.0))

	if profile.get("weights", {}).is_empty():
		return {}

	if total_budget <= 0:
		return {}

	var weights: Dictionary = profile["weights"]
	var reward_count = 1
	if total_budget >= 70 and weights.size() >= 2:
		reward_count = 2
	if total_budget >= 140 and weights.size() >= 3:
		reward_count = 3
	if not deterministic and reward_count < weights.size() and randf() < 0.2:
		reward_count += 1

	var selected = _pick_reward_emojis(weights, reward_count, deterministic)
	if selected.is_empty():
		return {}

	var selected_weight_total = 0.0
	for emoji in selected:
		selected_weight_total += float(weights.get(emoji, 0.0))
	if selected_weight_total <= 0.0:
		return {}

	var rewards: Dictionary = {}
	var remaining = total_budget
	for i in range(selected.size()):
		var emoji = selected[i]
		var amount = RESOURCE_REWARD_MIN_PER_EMOJI
		if i == selected.size() - 1:
			amount = max(RESOURCE_REWARD_MIN_PER_EMOJI, remaining)
		else:
			var ratio = float(weights.get(emoji, 0.0)) / selected_weight_total
			amount = max(RESOURCE_REWARD_MIN_PER_EMOJI, int(round(total_budget * ratio)))
			amount = min(amount, remaining - (selected.size() - i - 1) * RESOURCE_REWARD_MIN_PER_EMOJI)
		rewards[emoji] = amount
		remaining -= amount

	return rewards


static func _get_faction_dynamic_data(faction_name: String, fallback_signature: Array) -> Dictionary:
	if faction_name == "":
		return {
			"sig": fallback_signature.duplicate(),
			"hamiltonian": {},
			"self_energies": {},
			"lindblad_outgoing": {}
		}

	if _faction_dynamic_cache.has(faction_name):
		return _faction_dynamic_cache[faction_name].duplicate(true)

	var registry = _get_faction_registry()
	if registry:
		var faction_obj = registry.get_by_name(faction_name)
		if faction_obj:
			var data = {
				"sig": faction_obj.signature.duplicate(),
				"hamiltonian": faction_obj.hamiltonian.duplicate(true),
				"self_energies": faction_obj.self_energies.duplicate(true),
				"lindblad_outgoing": faction_obj.lindblad_outgoing.duplicate(true)
			}
			_faction_dynamic_cache[faction_name] = data.duplicate(true)
			return data

	var fallback = _get_faction_by_name(faction_name)
	var fallback_data = {
		"sig": fallback.get("sig", fallback_signature).duplicate(),
		"hamiltonian": fallback.get("hamiltonian", {}).duplicate(true),
		"self_energies": fallback.get("self_energies", {}).duplicate(true),
		"lindblad_outgoing": fallback.get("lindblad_outgoing", {}).duplicate(true)
	}
	_faction_dynamic_cache[faction_name] = fallback_data.duplicate(true)
	return fallback_data


static func _get_faction_registry():
	if _faction_registry_cache == null:
		_faction_registry_cache = FactionRegistry.new()
	return _faction_registry_cache


static func _compute_hamiltonian_reward_profile(faction_data: Dictionary) -> Dictionary:
	var signature = faction_data.get("sig", [])
	if signature.is_empty():
		return {"weights": {}, "dominant_eigenvalue": 0.0}

	var index_by_emoji: Dictionary = {}
	for i in range(signature.size()):
		index_by_emoji[signature[i]] = i

	var n = signature.size()
	var matrix: Array = []
	for i in range(n):
		var row: Array = []
		row.resize(n)
		for j in range(n):
			row[j] = 0.0
		matrix.append(row)

	var hamiltonian = faction_data.get("hamiltonian", {})
	for source in hamiltonian.keys():
		if not index_by_emoji.has(source):
			continue
		var src_i = int(index_by_emoji[source])
		var edges = hamiltonian[source]
		if not (edges is Dictionary):
			continue
		for target in edges.keys():
			if not index_by_emoji.has(target):
				continue
			var tgt_i = int(index_by_emoji[target])
			if src_i == tgt_i:
				continue
			matrix[src_i][tgt_i] += _hamiltonian_magnitude(edges[target])

	var self_energies = faction_data.get("self_energies", {})
	var lindblad_outgoing = faction_data.get("lindblad_outgoing", {})
	var production_bias: Dictionary = {}
	for emoji in signature:
		var out_strength = 0.0
		var outgoing_map = lindblad_outgoing.get(emoji, {})
		if outgoing_map is Dictionary:
			for target in outgoing_map.keys():
				out_strength += abs(float(outgoing_map[target]))
		production_bias[emoji] = 1.0 + min(out_strength * 2.5, 1.25)

	var vector: Array = []
	for _i in range(n):
		vector.append(1.0 / float(n))

	for _iter in range(12):
		var next_vec: Array = []
		var total = 0.0
		for i in range(n):
			var accum = 0.0
			for j in range(n):
				accum += float(matrix[i][j]) * float(vector[j])
			var emoji = signature[i]
			var self_energy = max(0.0, float(self_energies.get(emoji, 0.0)))
			accum += self_energy * 0.3 * float(vector[i])
			accum *= float(production_bias.get(emoji, 1.0))
			next_vec.append(accum)
			total += accum
		if total <= 0.00001:
			next_vec.clear()
			for _k in range(n):
				next_vec.append(1.0 / float(n))
		else:
			for i in range(n):
				next_vec[i] = float(next_vec[i]) / total
		vector = next_vec

	var eigen_num = 0.0
	var eigen_den = 0.0
	for i in range(n):
		var row_dot = 0.0
		for j in range(n):
			row_dot += float(matrix[i][j]) * float(vector[j])
		eigen_num += float(vector[i]) * row_dot
		eigen_den += float(vector[i]) * float(vector[i])
	var dominant_eigenvalue = eigen_num / max(eigen_den, 0.00001)

	var weights: Dictionary = {}
	var weight_total = 0.0
	for i in range(n):
		var emoji = signature[i]
		var base = max(0.0001, float(vector[i]))
		var self_term = max(0.0, float(self_energies.get(emoji, 0.0))) * 0.15
		var prod_term = (float(production_bias.get(emoji, 1.0)) - 1.0) * 0.5
		var weight = base + self_term + prod_term
		weights[emoji] = max(0.0001, weight)
		weight_total += float(weights[emoji])

	if weight_total > 0.0:
		for emoji in weights.keys():
			weights[emoji] = float(weights[emoji]) / weight_total

	return {
		"weights": weights,
		"dominant_eigenvalue": dominant_eigenvalue
	}


static func _compute_iconmap_reward_profile(faction_data: Dictionary, icon_map: Dictionary) -> Dictionary:
	"""Project IconMap weights onto faction signature for reward distribution."""
	var signature = faction_data.get("sig", [])
	if signature.is_empty():
		return {"weights": {}}

	var by_emoji: Dictionary = icon_map.get("by_emoji", {})
	if by_emoji.is_empty():
		return {"weights": {}}

	var weights: Dictionary = {}
	var total = 0.0

	for emoji in signature:
		if by_emoji.has(emoji):
			var w = max(0.0, float(by_emoji[emoji]))
			if w > 0.0:
				weights[emoji] = w
				total += w

	# Normalize weights
	if total > 0.0:
		for emoji in weights.keys():
			weights[emoji] = float(weights[emoji]) / total

	return {"weights": weights}


static func _compute_total_resource_budget(quest: Dictionary, dominant_eigenvalue: float) -> int:
	var quantity = max(0.0, float(quest.get("quantity", 0.0)))
	var multiplier = clamp(float(quest.get("reward_multiplier", 1.0)), 1.0, 6.0)
	var quest_type = int(quest.get("type", 0))

	var base = max(10.0, quantity * 0.85 + 8.0)
	var eigen_boost = clamp(1.0 + dominant_eigenvalue * 0.6, 1.0, 2.5)
	var type_scale = 1.0 if quest_type == 0 else 0.75

	var raw_total = base * multiplier * eigen_boost * RESOURCE_REWARD_BASE_RATIO * type_scale
	return int(clamp(round(raw_total), RESOURCE_REWARD_MIN_TOTAL, RESOURCE_REWARD_MAX_TOTAL))


static func _pick_reward_emojis(weights: Dictionary, count: int, deterministic: bool) -> Array:
	var chosen: Array = []
	if weights.is_empty() or count <= 0:
		return chosen

	if deterministic:
		var ordered = []
		for emoji in weights.keys():
			ordered.append({"emoji": emoji, "weight": float(weights[emoji])})
		ordered.sort_custom(func(a, b): return float(a["weight"]) > float(b["weight"]))
		for i in range(min(count, ordered.size())):
			chosen.append(ordered[i]["emoji"])
		return chosen

	var remaining = weights.duplicate()
	while chosen.size() < count and not remaining.is_empty():
		var total = 0.0
		for emoji in remaining.keys():
			total += max(0.0, float(remaining[emoji]))
		if total <= 0.0:
			break
		var roll = randf() * total
		var cumulative = 0.0
		for emoji in remaining.keys():
			cumulative += max(0.0, float(remaining[emoji]))
			if roll <= cumulative:
				chosen.append(emoji)
				remaining.erase(emoji)
				break

	return chosen


static func _sanitize_resource_rewards(raw_rewards: Dictionary) -> Dictionary:
	var clean: Dictionary = {}
	for emoji in raw_rewards.keys():
		var amount = int(raw_rewards.get(emoji, 0))
		if amount > 0:
			clean[emoji] = amount
	return clean


static func _hamiltonian_magnitude(value) -> float:
	if value is float or value is int:
		return abs(float(value))
	if value is Vector2:
		return sqrt(value.x * value.x + value.y * value.y)
	if value is Array and value.size() >= 2:
		var re = float(value[0])
		var im = float(value[1])
		return sqrt(re * re + im * im)
	return 0.0


static func select_vocabulary_reward(faction: Dictionary, bath, player_vocab: Array) -> String:
	"""Choose which emoji from faction signature to teach

	Strategy:
	1. Get faction signature vocabulary
	2. Filter to emojis player doesn't know
	3. Get bath probabilities for unknown emojis (quantum-weighted!)
	4. Sample weighted by probability
	5. Fallback to random if no probabilities

	Args:
		faction: Faction dictionary with signature
		bath: QuantumBath with probability distribution
		player_vocab: Player's known emojis

	Returns:
		Emoji string to teach, or "" if none available
	"""
	# Faction data uses "sig" key (short for signature)
	var signature = faction.get("sig", faction.get("signature", []))

	# Filter to unknown vocabulary
	var unknown = []
	for emoji in signature:
		if emoji not in player_vocab:
			unknown.append(emoji)

	# Already know everything?
	if unknown.is_empty():
		return ""  # No vocabulary to teach

	# Get bath probabilities for unknown emojis (quantum-informed selection!)
	if bath and bath.get("_density_matrix"):
		var density_matrix = bath._density_matrix
		var emoji_list = density_matrix.emoji_list
		var probs = []
		var indices = []

		for i in range(unknown.size()):
			var emoji = unknown[i]
			var idx = emoji_list.find(emoji)

			if idx >= 0:
				var prob = density_matrix.get_probability_by_index(idx)
				probs.append(prob)
				indices.append(i)

		# Sample weighted by probability
		if probs.size() > 0:
			var total = 0.0
			for p in probs:
				total += p

			if total > 0.001:
				# Renormalize and sample
				var roll = randf() * total
				var cumulative = 0.0
				for i in range(probs.size()):
					cumulative += probs[i]
					if roll <= cumulative:
						return unknown[indices[i]]

	# Fallback: random from unknown
	return unknown[randi() % unknown.size()]


static func _get_faction_by_name(faction_name: String) -> Dictionary:
	"""Find faction dictionary by name"""
	for faction in FactionDatabase.ALL_FACTIONS:
		if faction.get("name", "") == faction_name:
			return faction

	return {}


static func format_reward_text(reward: QuestReward) -> String:
	"""Generate human-readable reward text for UI

	No universal 💰 currency - just vocab pairs!
	"""
	var lines = []

	# Primary payout: faction resources
	if not reward.resource_rewards.is_empty():
		for emoji in reward.resource_rewards.keys():
			lines.append("🎁 +%d %s" % [int(reward.resource_rewards[emoji]), emoji])

	# Vocabulary pairs (primary reward)
	if reward.learned_pairs.size() > 0:
		for pair in reward.learned_pairs:
			var north = pair.get("north", "?")
			var south = pair.get("south", "?")
			lines.append("📖 Learned: %s/%s axis" % [north, south])
	elif reward.learned_vocabulary.size() > 0:
		# Fallback for single emojis (no connections)
		for emoji in reward.learned_vocabulary:
			lines.append("📖 Learned: %s (solo)" % emoji)
	else:
		lines.append("📖 (No new vocabulary)")

	# Icon modifications
	for mod in reward.icon_modifications:
		lines.append("⚛️ %s" % _format_icon_modification(mod))

	return "\n".join(lines)


static func preview_possible_rewards(quest: Dictionary, player_vocab: Array) -> String:
	"""Preview what rewards will be earned (shows pre-rolled pair)

	No universal 💰 currency - just vocab pairs from quantum physics.
	"""
	var lines = []

	# Resource payouts (primary)
	var resource_rewards = quest.get("reward_resources", {})
	if not (resource_rewards is Dictionary) or resource_rewards.is_empty():
		resource_rewards = estimate_resource_rewards(quest, _get_faction_by_name(quest.get("faction", "")))
	if resource_rewards is Dictionary and not resource_rewards.is_empty():
		for emoji in resource_rewards.keys():
			lines.append("🎁 +%d %s" % [int(resource_rewards[emoji]), emoji])

	# Show PRE-ROLLED vocabulary pair
	var north = quest.get("reward_vocab_north", "")
	var south = quest.get("reward_vocab_south", "")

	if north != "":
		if south != "":
			lines.append("📖 Learn: %s/%s axis" % [north, south])
		else:
			lines.append("📖 Learn: %s (solo)" % north)
	else:
		lines.append("📖 (No new vocabulary)")

	return "\n".join(lines)


## ========================================
## Icon Modification Generation
## ========================================

static func generate_icon_modification(faction: Dictionary, quest: Dictionary) -> IconModification:
	"""Generate a faction-specific icon modification as quest reward

	Args:
		faction: Faction dictionary
		quest: Quest dictionary

	Returns:
		IconModification with faction-appropriate changes
	"""
	var mod = IconModification.new()
	var faction_name = faction.get("name", "Unknown")
	var faction_sig = faction.get("sig", faction.get("signature", []))

	# Pick an emoji from faction signature for modification
	var target_emoji = quest.get("resource", "")
	if target_emoji.is_empty() and faction_sig.size() > 0:
		target_emoji = faction_sig[randi() % faction_sig.size()]

	mod.icon_emoji = target_emoji

	# Faction-specific modification types
	match faction_name:
		"Loom Priests":
			# Fate threads are complex! Add imaginary coupling
			mod.type = IconModification.Type.ADD_COUPLING
			var fate_targets = ["🕯️", "🧵", "🌀", "📿"]
			var fate_target = fate_targets[randi() % fate_targets.size()]
			mod.parameters = {
				"target": fate_target,
				"strength": randf_range(0.05, 0.15),
				"imaginary": randf_range(-0.1, 0.1),  # Complex coupling!
				"description": "Fate threads weave new connections"
			}

		"Yeast Prophets":
			# Enhance fermentation couplings
			mod.type = IconModification.Type.MODIFY_COUPLING
			mod.parameters = {
				"target": "🍞",
				"boost_factor": randf_range(1.1, 1.3),
				"description": "Fermentation accelerates"
			}

		"Sacred Flame Keepers":
			# Reduce fire decay
			mod.type = IconModification.Type.REDUCE_DECAY
			mod.icon_emoji = "🔥"
			mod.parameters = {
				"reduction": randf_range(0.005, 0.02),
				"description": "Sacred flame burns longer"
			}

		"Knot-Shriners":
			# Unlock Bell-activated feature
			mod.type = IconModification.Type.UNLOCK_BELL_FEATURE
			mod.icon_emoji = "🪢"
			mod.parameters = {
				"feature_name": "oath_binding",
				"description": "Oaths now bind when entangled"
			}

		"Verdant Pulse", "Granary Guilds":
			# Boost growth
			mod.type = IconModification.Type.MODIFY_COUPLING
			mod.parameters = {
				"target": "🌾",
				"boost_factor": randf_range(1.05, 1.15),
				"description": "Growth flows strengthened"
			}

		"Kilowatt Collective":
			# Add driver for power oscillation
			mod.type = IconModification.Type.ADD_DRIVER
			mod.icon_emoji = "⚡"
			mod.parameters = {
				"driver_type": "cosine",
				"frequency": randf_range(0.1, 0.3),
				"amplitude": randf_range(0.1, 0.3),
				"description": "Power surges rhythmically"
			}

		"Keepers of Silence":
			# Boost decoherence effect (silence kills coherence)
			mod.type = IconModification.Type.BOOST_SELF_ENERGY
			mod.icon_emoji = "🤫"
			mod.parameters = {
				"boost": randf_range(-0.1, -0.05),  # Negative = more unstable
				"description": "Silence deepens"
			}

		_:
			# Default: small coupling boost to a random emoji
			mod.type = IconModification.Type.MODIFY_COUPLING
			if faction_sig.size() >= 2:
				var other = faction_sig[randi() % faction_sig.size()]
				while other == target_emoji and faction_sig.size() > 1:
					other = faction_sig[randi() % faction_sig.size()]
				mod.parameters = {
					"target": other,
					"boost_factor": randf_range(1.03, 1.1),
					"description": "Bonds strengthen"
				}
			else:
				mod.type = IconModification.Type.BOOST_SELF_ENERGY
				mod.parameters = {
					"boost": randf_range(0.02, 0.08),
					"description": "Essence stabilizes"
				}

	return mod


static func _format_icon_modification(mod: IconModification) -> String:
	"""Format an icon modification for display"""
	var desc = mod.parameters.get("description", "Modified physics")

	match mod.type:
		IconModification.Type.ADD_COUPLING:
			var target = mod.parameters.get("target", "?")
			return "%s → %s: %s" % [mod.icon_emoji, target, desc]

		IconModification.Type.MODIFY_COUPLING:
			var target = mod.parameters.get("target", "?")
			var boost = mod.parameters.get("boost_factor", 1.0)
			return "%s → %s: +%.0f%% (%s)" % [mod.icon_emoji, target, (boost - 1) * 100, desc]

		IconModification.Type.REDUCE_DECAY:
			var red = mod.parameters.get("reduction", 0.0)
			return "%s decay -%.1f%% (%s)" % [mod.icon_emoji, red * 100, desc]

		IconModification.Type.ADD_LINDBLAD:
			var target = mod.parameters.get("target", "?")
			return "%s → %s: new transfer (%s)" % [mod.icon_emoji, target, desc]

		IconModification.Type.UNLOCK_BELL_FEATURE:
			var feature = mod.parameters.get("feature_name", "unknown")
			return "%s: Bell feature [%s] unlocked" % [mod.icon_emoji, feature]

		IconModification.Type.ADD_DRIVER:
			var freq = mod.parameters.get("frequency", 0.0)
			return "%s: oscillation at %.2f Hz (%s)" % [mod.icon_emoji, freq, desc]

		IconModification.Type.BOOST_SELF_ENERGY:
			var boost = mod.parameters.get("boost", 0.0)
			var dir = "stabilized" if boost > 0 else "destabilized"
			return "%s: %s (%s)" % [mod.icon_emoji, dir, desc]

	return "%s: %s" % [mod.icon_emoji, desc]


static func should_grant_icon_modification(quest: Dictionary) -> bool:
	"""Determine if this quest should grant an icon modification reward

	Higher-tier quests (prophecy, coherence, bell state) are more likely
	to grant icon modifications as rewards.
	"""
	var quest_type = quest.get("type", 0)

	# Quantum mechanics quests always grant modifications
	const QuestTypes = preload("res://Core/Quests/QuestTypes.gd")
	if quest_type in [
		QuestTypes.Type.ACHIEVE_EIGENSTATE,
		QuestTypes.Type.MAINTAIN_COHERENCE,
		QuestTypes.Type.INDUCE_BELL_STATE,
	]:
		return true

	# Other quests have a chance based on reward multiplier
	var multiplier = quest.get("reward_multiplier", 1.0)
	var chance = clamp((multiplier - 1.5) * 0.3, 0.0, 0.5)  # 0-50% chance

	return randf() < chance
