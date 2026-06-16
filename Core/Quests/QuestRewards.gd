class_name QuestRewards
extends RefCounted

## Quest Reward System
## Handles reward generation and icon teaching for completed quests


const RESOURCE_REWARD_MIN_TOTAL: int = 1
const RESOURCE_REWARD_MAX_TOTAL: int = 55
const RESOURCE_REWARD_MIN_PER_EMOJI: int = 1
const RESOURCE_REWARD_BASE_RATIO: float = 0.25
const QUEST_REWARD_TUNING_DEFAULTS: Dictionary = {
	"resource_reward_min_total": RESOURCE_REWARD_MIN_TOTAL,
	"resource_reward_max_total": RESOURCE_REWARD_MAX_TOTAL,
	"resource_reward_min_per_emoji": RESOURCE_REWARD_MIN_PER_EMOJI,
	"resource_reward_base_ratio": RESOURCE_REWARD_BASE_RATIO
	,
	"biome_novelty_multiplier": 1.10,
	"icon_novelty_multiplier": 1.10,
	"novelty_multiplier_cap": 1.20,
	# Representative kT for quest-reward SIZING (rarer goal → bigger bounty). Live market
	# pricing uses the biome's own kT; this is the offer-sizing anchor. Canonical value in
	# default.jsonl (quest_rewards.reward_kT).
	"reward_kT": 10.0
}

static var _quest_reward_tuning_overrides: Dictionary = {}

## Icon Modification: How quest rewards can modify icon physics
class IconModification:
	enum Type {
		ADD_COUPLING,       # Add new coupling
		MODIFY_COUPLING,    # Change existing coupling strength
		REDUCE_DECAY,       # Lower decay rate
		ADD_LINDBLAD,       # Add transfer channel
		UNLOCK_BELL_FEATURE,# Enable bell-activated feature
		ADD_DRIVER,         # Add time-dependent forcing
		BOOST_SELF_ENERGY,  # Increase self-energy (stability)
	}

	var quest_type: Type
	var icon_emoji: String = ""
	var parameters: Dictionary = {}  # Type-specific params

	func _init():
		quest_type = Type.MODIFY_COUPLING

	func _to_string() -> String:
		return "IconMod<%s>[%s]" % [Type.keys()[quest_type], icon_emoji]


class QuestReward:
	# Rewards for completing a quest
	var money_amount: int = 0  # 💰-credits reward (no universal currency!)
	var resource_rewards: Dictionary = {}  # {emoji: credits} primary payout
	var learned_emojis: Array[String] = []  # Emojis player learned (both north and south)
	var learned_pairs: Array = []  # Array of {north, south, weight, probability} - paired icon
	var reputation_gain: int = 0  # Scalar kept for save files; see standing_deltas
	var bonus_multiplier: float = 1.0  # From alignment
	var icon_modifications: Array = []  # Array[IconModification] - physics changes
	var faction_name: String = ""  # Which faction owns this reward (for standing application)
	var standing_deltas: Dictionary = {}  # Per-channel deltas to apply on grant. Keys: trust/debt/attention/access/legitimacy/entanglement


static func generate_reward(quest: Dictionary, _bath, player_vocab: Array) -> QuestReward:
	# Generate rewards for quest completion

	# Uses PRE-ROLLED icon from quest creation time (not rolled now).
	# This ensures player sees the same pair in preview and actual reward.

	# Args:
	# quest: Completed quest data (with reward_north/south)
	# bath: Current biome quantum bath
	# player_vocab: Player's known emojis

	# Returns:
	# QuestReward with signature (no universal 💰 currency!)
	var reward = QuestReward.new()

	# NO UNIVERSAL MONEY! Money is just another emoji resource
	# Remove: reward.money_amount = ...
	reward.money_amount = 0  # No universal currency
	reward.bonus_multiplier = quest.get("reward_multiplier", 1.0)

	# Use PRE-ROLLED icon from quest creation.
	# Quests give EITHER icon OR resources — not both.
	var north = quest.get("reward_north", "")
	var south = quest.get("reward_south", "")
	var faction_name = quest.get("faction", "")
	var faction_dict = _get_faction_by_name(faction_name)

	# Primary payout: faction-shaped resource rewards (only for non-icon quests)
	if north == "":
		var pre_rolled_resources = quest.get("reward_resources", {})
		if pre_rolled_resources is Dictionary and not pre_rolled_resources.is_empty():
			reward.resource_rewards = _sanitize_resource_rewards(pre_rolled_resources)
		else:
			var reward_icon_map := _build_uniform_icon_map(player_vocab)
			if reward_icon_map.is_empty():
				reward_icon_map = _build_uniform_icon_map(_quest_reward_emojis(quest, faction_dict))
			reward.resource_rewards = _build_resource_reward_plan(quest, faction_dict, false, reward_icon_map)

	if north != "":
		reward.learned_emojis.append(north)

		if south != "":
			# Full pair (both north and south)
			reward.learned_emojis.append(south)
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

	# Faction standing wiring (Phase 2 rep channels)
	reward.faction_name = faction_name
	reward.standing_deltas = _standing_deltas_for_quest(quest, true)

	return reward


static func _standing_deltas_for_quest(quest: Dictionary, success: bool) -> Dictionary:
	# Per-channel reputation deltas based on quest type and outcome.
	# Modest defaults; expected to be tuned. Channels:
	# trust 🤝 / debt 🩸 / attention 🧿 / access 🗝 / legitimacy ⚖ / entanglement 🕸
	var qtype: int = int(quest.get("type", 0))
	if success:
		match qtype:
			0:  # DELIVERY — bread-and-butter; build trust + small access
				return {"trust": 0.05, "access": 0.02, "attention": 0.01}
			1, 2, 3:  # SHAPE_*, EVOLUTION — competence, signals legitimacy
				return {"trust": 0.04, "legitimacy": 0.03, "attention": 0.02}
			4:  # ENTANGLEMENT — spooky cooperation; raises entanglement edge
				return {"trust": 0.03, "entanglement": 0.05, "attention": 0.03}
			5, 6:  # ACHIEVE_EIGENSTATE, MAINTAIN_COHERENCE — quantum mastery
				return {"trust": 0.04, "legitimacy": 0.06, "access": 0.03}
			7:  # INDUCE_BELL_STATE — high entanglement payoff
				return {"trust": 0.04, "entanglement": 0.08, "legitimacy": 0.03}
			8, 9:  # PREVENT_DECOHERENCE, COLLAPSE_DELIBERATELY — careful work
				return {"trust": 0.05, "legitimacy": 0.04}
			_:
				return {"trust": 0.03, "attention": 0.01}
	else:
		# Failure: debt + attention. Larger penalties for high-trust quests.
		match qtype:
			0:
				return {"debt": 0.06, "attention": 0.03, "trust": -0.02}
			4, 7:  # entanglement-flavored failures leave residue
				return {"debt": 0.05, "attention": 0.04, "entanglement": 0.03}
			_:
				return {"debt": 0.04, "attention": 0.04, "trust": -0.01}


static func plan_resource_rewards(quest: Dictionary, faction: Dictionary = {}, icon_map: Dictionary = {}) -> Dictionary:
	# Pre-roll resource rewards at quest creation time for deterministic UI/claim.

	# Icon-teaching quests give no resource rewards — icon OR resources, not both.
	# Icon-teaching quests give no resource rewards
	if quest.get("reward_north", "") != "":
		return {}
	return _build_resource_reward_plan(quest, faction, false, icon_map)


static func estimate_resource_rewards(quest: Dictionary, faction: Dictionary = {}, icon_map: Dictionary = {}) -> Dictionary:
	# Deterministic estimate for preview paths when quest has no pre-rolled bundle.
	if quest.get("reward_north", "") != "":
		return {}
	return _build_resource_reward_plan(quest, faction, true, icon_map)


static func compute_market_projection(quest: Dictionary, icon_map: Dictionary = {}, _tuning: Dictionary = {}) -> Dictionary:
	# Compute read-only market projection (no dynamic cost multiplier by default).
	if quest.is_empty():
		return {}
	if int(quest.get("type", -1)) != 0:
		return {}
	var resource = str(quest.get("resource", ""))
	var base_cost = float(quest.get("quantity", 0))
	if resource == "" or base_cost <= 0.0:
		return {}

	var faction_name = quest.get("faction", "")
	var signature = quest.get("faction_signature", [])
	var faction_dynamic = _get_faction_dynamic_data(faction_name, signature)
	var resolved_icon_map := _resolve_reward_icon_map(quest, faction_dynamic, icon_map if icon_map is Dictionary else {})
	if resolved_icon_map.is_empty():
		return {}
	var profile = _compute_interference_reward_profile(faction_dynamic, resolved_icon_map)
	var weights = profile.get("weights", {})
	var by_emoji: Dictionary = resolved_icon_map.get("by_emoji", {})
	var total = max(0.0, float(resolved_icon_map.get("total", 0.0)))
	var availability = max(0.0, float(by_emoji.get(resource, 0.0))) if by_emoji is Dictionary else 0.0
	var normalized_availability = availability / max(1.0, total)
	var scarcity = 1.0 / max(0.05, normalized_availability)
	var pressure = float(weights.get(resource, 0.0)) if weights is Dictionary else 0.0

	return {
		"resource": resource,
		"base_cost": int(base_cost),
		"effective_cost": int(base_cost),
		"multiplier": 1.0,
		"availability": availability,
		"normalized_availability": normalized_availability,
		"scarcity": scarcity,
		"pressure": pressure,
		"interference_strength": float(profile.get("interference_strength", 0.0))
	}


static func _build_resource_reward_plan(quest: Dictionary, faction: Dictionary, deterministic: bool, icon_map: Dictionary = {}) -> Dictionary:
	var faction_name = quest.get("faction", faction.get("name", ""))
	var signature = quest.get("faction_signature", faction.get("sig", faction.get("signature", [])))
	var faction_dynamic = _get_faction_dynamic_data(faction_name, signature)

	var resolved_icon_map := _resolve_reward_icon_map(quest, faction_dynamic, icon_map)
	if resolved_icon_map.is_empty():
		return {}
	var profile := _compute_interference_reward_profile(faction_dynamic, resolved_icon_map)
	var total_budget := _compute_surprisal_reward_budget(quest, profile, deterministic)

	if profile.get("weights", {}).is_empty():
		return {}

	if total_budget <= 0:
		return {}

	var weights: Dictionary = profile["weights"]
	var quantity = max(0.0, float(quest.get("quantity", 0.0)))
	var reward_count = 1
	if quantity >= 5.0 and weights.size() >= 2:
		reward_count = 2
	if quantity >= 13.0 and weights.size() >= 3:
		reward_count = 3
	if not deterministic and reward_count < weights.size() and quantity >= 8.0 and randf() < 0.15:
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
	var min_per_emoji = _reward_min_per_emoji_for_quantity(quantity)
	for i in range(selected.size()):
		var emoji = selected[i]
		var amount = min_per_emoji
		if i == selected.size() - 1:
			amount = max(min_per_emoji, remaining)
		else:
			var ratio = float(weights.get(emoji, 0.0)) / selected_weight_total
			amount = max(min_per_emoji, int(round(total_budget * ratio)))
			amount = min(amount, remaining - (selected.size() - i - 1) * min_per_emoji)
		rewards[emoji] = amount
		remaining -= amount

	return _apply_reward_tuning(rewards, quest)


static func _apply_reward_tuning(rewards: Dictionary, quest: Dictionary) -> Dictionary:
	if rewards.is_empty():
		return rewards
	var tuning = get_reward_tuning()
	# Additive novelty bonuses, capped to prevent runaway generosity.
	var multiplier = 1.0
	if bool(quest.get("biome_new", false)):
		multiplier += float(tuning.get("biome_novelty_multiplier", 1.10)) - 1.0
	if bool(quest.get("contains_new_vocab", false)):
		multiplier += float(tuning.get("icon_novelty_multiplier", 1.10)) - 1.0
	var cap = float(tuning.get("novelty_multiplier_cap", 1.20))
	multiplier = min(multiplier, cap)
	if multiplier <= 1.0:
		return rewards
	for emoji in rewards.keys():
		var base = float(rewards[emoji])
		var scaled = max(1.0, round(base * multiplier))
		rewards[emoji] = int(scaled)
	return rewards


static func _get_faction_dynamic_data(faction_name: String, fallback_signature: Array) -> Dictionary:
	var signature: Array = fallback_signature.duplicate()
	if faction_name != "":
		var registry = FactionRegistry.get_shared()
		if registry:
			var faction_obj = registry.get_by_name(faction_name)
			if faction_obj and faction_obj.cloud is Array and not faction_obj.cloud.is_empty():
				signature = faction_obj.cloud.duplicate()

	if signature.is_empty():
		return {
			"sig": [],
			"hamiltonian": {},
			"self_energies": {},
			"lindblad_outgoing": {}
		}

	var icon_registry = _get_icon_registry()
	if icon_registry != null and icon_registry.has_method("get_signature_physics"):
		var live_physics: Dictionary = icon_registry.get_signature_physics(signature)
		if not live_physics.is_empty():
			live_physics["sig"] = signature.duplicate()
			return live_physics

	return {
		"sig": signature.duplicate(),
		"hamiltonian": {},
		"self_energies": {},
		"lindblad_outgoing": {}
	}


static func _get_icon_registry():
	var local_registry = (Engine.get_main_loop().root.get_node_or_null("/root/IconRegistry") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if local_registry.has_method("rebuild_from_icons"):
		local_registry.rebuild_from_icons()
	return local_registry


static func _compute_interference_reward_profile(faction_data: Dictionary, icon_map: Dictionary) -> Dictionary:
	# Tensor-like interference map between faction icon physics and player IconMap.

	# We collapse an interference tensor T[e,i,j] where:
	# - e: reward emoji candidate (faction signature)
	# - i,j: player "mode" indices on the same signature basis
	# - T[e,i,j] ~ |H_f[e,j]| * p_i * |p_j - p_i|

	# This boosts reward weight where faction couplings and player mass gradients
	# constructively interfere.
	var signature = faction_data.get("sig", [])
	if signature.is_empty():
		return {"weights": {}, "interference_strength": 0.0}
	var by_emoji: Dictionary = icon_map.get("by_emoji", {})
	if by_emoji.is_empty():
		return {"weights": {}, "interference_strength": 0.0}

	var index_by_emoji: Dictionary = {}
	for i in range(signature.size()):
		index_by_emoji[signature[i]] = i

	var n = signature.size()
	var h: Array = []
	for i in range(n):
		var row: Array = []
		row.resize(n)
		for j in range(n):
			row[j] = 0.0
		h.append(row)

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
			h[src_i][tgt_i] += _hamiltonian_magnitude(edges[target])

	var p: Array = []
	var p_total = 0.0
	for emoji in signature:
		var mass = max(0.0, float(by_emoji.get(emoji, 0.0)))
		p.append(mass)
		p_total += mass
	if p_total <= 0.0:
		return {"weights": {}, "interference_strength": 0.0}
	for i in range(n):
		p[i] = float(p[i]) / p_total

	var self_energies = faction_data.get("self_energies", {})
	var weights: Dictionary = {}
	var total = 0.0
	var interference_sum = 0.0

	for e in range(n):
		var emoji = signature[e]
		var tensor_energy = 0.0
		for i in range(n):
			for j in range(n):
				var hij = abs(float(h[e][j]))
				if hij <= 0.0:
					continue
				var pij = abs(float(p[j]) - float(p[i]))
				tensor_energy += hij * float(p[i]) * pij
		var coupling_mass = 0.0
		for j in range(n):
			coupling_mass += abs(float(h[e][j])) * float(p[j])
		var self_term = max(0.0, float(self_energies.get(emoji, 0.0))) * float(p[e]) * 0.5
		var raw = max(0.0001, tensor_energy + coupling_mass + self_term)
		weights[emoji] = raw
		total += raw
		interference_sum += tensor_energy

	if total > 0.0:
		for emoji in weights.keys():
			weights[emoji] = float(weights[emoji]) / total

	return {
		"weights": weights,
		"interference_strength": interference_sum
	}


static func _resolve_reward_icon_map(quest: Dictionary, faction_data: Dictionary, icon_map: Dictionary) -> Dictionary:
	if icon_map is Dictionary and icon_map.has("by_emoji"):
		var by_emoji = icon_map.get("by_emoji", {})
		if by_emoji is Dictionary and not by_emoji.is_empty():
			var signature = faction_data.get("sig", [])
			for emoji in signature:
				if by_emoji.has(str(emoji)):
					return icon_map
	var source: Array = _quest_reward_emojis(quest, faction_data)
	if source.is_empty():
		return {}
	return _build_uniform_icon_map(source)


static func _quest_reward_emojis(quest: Dictionary, faction_data: Dictionary) -> Array:
	var out: Array = []
	var available = quest.get("available_emojis", [])
	if available is Array and not available.is_empty():
		return available.duplicate()
	var signature = quest.get("faction_signature", faction_data.get("sig", faction_data.get("signature", [])))
	if signature is Array and not signature.is_empty():
		return signature.duplicate()
	return out


static func _build_uniform_icon_map(emojis: Array) -> Dictionary:
	var by_emoji: Dictionary = {}
	var total: float = 0.0
	for raw in emojis:
		var emoji := str(raw)
		if emoji == "" or by_emoji.has(emoji):
			continue
		by_emoji[emoji] = 1.0
		total += 1.0
	if by_emoji.is_empty():
		return {}
	return {
		"by_emoji": by_emoji,
		"total": total,
		"steps": 1,
		"source": "uniform"
	}


static func _compute_surprisal_reward_budget(quest: Dictionary, _profile: Dictionary, deterministic: bool) -> int:
	# Bounty = surprisal energy of the quest's target state (QuestEnergy):
	# rarer goal → bigger reward. The same E = −kT·log p law that prices harvest
	# and markets. kT_base is representative (biome-specific kT applies at live
	# market pricing); tune via JSONL tuning.market_temperature. The interference
	# profile no longer sets the budget — it only steers WHICH emojis pay out
	# (see _build_resource_reward_plan).
	var kT := float(get_reward_tuning().get("reward_kT", 10.0))
	var budget := QuestEnergy.target_energy(quest, kT)
	var amount := maxi(1, int(round(budget)))
	if not deterministic:
		# ±15% surprisal jitter (zero-mean) for non-deterministic offers.
		var z := (randf() + randf() + randf() + randf() - 2.0) / 0.57735026919
		amount = maxi(1, int(round(budget + 0.15 * budget * z)))
	return amount


static func _compute_total_resource_budget(quest: Dictionary, dominant_eigenvalue: float) -> int:
	var quantity = max(0.0, float(quest.get("quantity", 0.0)))
	var multiplier = clamp(float(quest.get("reward_multiplier", 1.0)), 1.0, 2.0)
	var quest_type = int(quest.get("type", 0))

	var base = max(10.0, quantity * 0.85 + 8.0)
	var eigen_boost = clamp(1.0 + dominant_eigenvalue * 0.6, 1.0, 2.5)
	var type_scale = 1.0 if quest_type == 0 else 0.75

	var raw_total = base * multiplier * eigen_boost * _reward_base_ratio() * type_scale
	return int(clamp(round(raw_total), _reward_min_total(), _reward_max_total()))


static func set_reward_tuning_overrides(overrides: Dictionary) -> void:
	_quest_reward_tuning_overrides = {}
	if not (overrides is Dictionary):
		return
	for key in QUEST_REWARD_TUNING_DEFAULTS.keys():
		if overrides.has(key):
			_quest_reward_tuning_overrides[key] = overrides[key]


static func get_reward_tuning() -> Dictionary:
	var out = QUEST_REWARD_TUNING_DEFAULTS.duplicate(true)
	for key in _quest_reward_tuning_overrides.keys():
		out[key] = _quest_reward_tuning_overrides[key]
	return out


static func reset_reward_tuning() -> void:
	_quest_reward_tuning_overrides = {}


static func _reward_min_total() -> int:
	var raw = get_reward_tuning().get("resource_reward_min_total", RESOURCE_REWARD_MIN_TOTAL)
	return max(1, int(raw))


static func _reward_max_total() -> int:
	var raw = get_reward_tuning().get("resource_reward_max_total", RESOURCE_REWARD_MAX_TOTAL)
	return max(_reward_min_total(), int(raw))


static func _reward_min_per_emoji() -> int:
	var raw = get_reward_tuning().get("resource_reward_min_per_emoji", RESOURCE_REWARD_MIN_PER_EMOJI)
	return max(1, int(raw))


static func _reward_min_per_emoji_for_quantity(quantity: float) -> int:
	if quantity <= 3.0:
		return 1
	if quantity <= 8.0:
		return 2
	if quantity <= 21.0:
		return 3
	return _reward_min_per_emoji()


static func _reward_base_ratio() -> float:
	var raw = get_reward_tuning().get("resource_reward_base_ratio", RESOURCE_REWARD_BASE_RATIO)
	return max(0.05, float(raw))


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
	# Choose which emoji from faction signature to teach

	# Strategy:
	# 1. Get faction signature signature
	# 2. Filter to emojis player doesn't know
	# 3. Get bath probabilities for unknown emojis (quantum-weighted!)
	# 4. Sample weighted by probability
	# 5. Fallback to random if no probabilities

	# Args:
	# faction: Faction dictionary with signature
	# bath: QuantumBath with probability distribution
	# player_vocab: Player's known emojis

	# Returns:
	# Emoji string to teach, or "" if none available
	# Faction data uses "sig" key (short for signature)
	var signature = faction.get("sig", faction.get("signature", []))

	# Filter to unknown signature
	var unknown = []
	for emoji in signature:
		if emoji not in player_vocab:
			unknown.append(emoji)

	# Already know everything?
	if unknown.is_empty():
		return ""  # No signature to teach

	# Get biome probabilities for unknown emojis (quantum-informed selection!)
	if bath and bath.viz_cache:
		var probs = []
		var indices = []

		for i in range(unknown.size()):
			var emoji = unknown[i]
			var prob = bath.get_emoji_probability(emoji)
			if prob >= 0.0:
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
	# Find faction dictionary by name
	for faction in FactionDatabase.get_all():
		if faction.get("name", "") == faction_name:
			return faction

	return {}


static func format_reward_text(reward: QuestReward) -> String:
	# Generate human-readable reward text for UI

	# No universal 💰 currency - just icons!
	var lines = []

	# Primary payout: faction resources
	if not reward.resource_rewards.is_empty():
		for emoji in reward.resource_rewards.keys():
			lines.append("🎁 +%d %s" % [int(reward.resource_rewards[emoji]), emoji])

	# Signature pairs (primary reward)
	if reward.learned_pairs.size() > 0:
		for pair in reward.learned_pairs:
			var north = pair.get("north", "?")
			var south = pair.get("south", "?")
			lines.append("📖 Learned: %s/%s axis" % [north, south])
	elif reward.learned_emojis.size() > 0:
		# Fallback for single emojis (no connections)
		for emoji in reward.learned_emojis:
			lines.append("📖 Learned: %s (solo)" % emoji)
	else:
		lines.append("📖 (No new signature)")

	# Icon modifications
	for mod in reward.icon_modifications:
		lines.append("⚛️ %s" % _format_icon_modification(mod))

	return "\n".join(lines)


static func preview_possible_rewards(quest: Dictionary, _player_vocab: Array) -> String:
	# Preview what rewards will be earned (shows pre-rolled pair)

	# No universal 💰 currency - just icons from quantum physics.
	var lines = []

	# Resource payouts (primary)
	var resource_rewards = quest.get("reward_resources", {})
	if not (resource_rewards is Dictionary) or resource_rewards.is_empty():
		resource_rewards = estimate_resource_rewards(quest, _get_faction_by_name(quest.get("faction", "")))
	if resource_rewards is Dictionary and not resource_rewards.is_empty():
		for emoji in resource_rewards.keys():
			lines.append("🎁 +%d %s" % [int(resource_rewards[emoji]), emoji])

	# Show PRE-ROLLED icon
	var north = quest.get("reward_north", "")
	var south = quest.get("reward_south", "")

	if north != "":
		if south != "":
			lines.append("📖 Learn: %s/%s axis" % [north, south])
		else:
			lines.append("📖 Learn: %s (solo)" % north)
	else:
		lines.append("📖 (No new signature)")

	return "\n".join(lines)


## ========================================
## Icon Modification Generation
## ========================================

static func generate_icon_modification(faction: Dictionary, quest: Dictionary) -> IconModification:
	# Generate a faction-specific icon modification as quest reward

	# Args:
	# faction: Faction dictionary
	# quest: Quest dictionary

	# Returns:
	# IconModification with faction-appropriate changes
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
	# Format an icon modification for display
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
	# Determine if this quest should grant an icon modification reward

	# Higher-tier quests (prophecy, coherence, bell state) are more likely
	# to grant icon modifications as rewards.
	var quest_type = quest.get("type", 0)

	# Quantum mechanics quests always grant modifications
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
