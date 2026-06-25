class_name IconPairing
extends RefCounted


## Icon Pairing System (South-First Design) — pairs CLOUD atoms into an icon
##
## NEW ORDER: South pole is calculated FIRST, then North pole.
##
## 1. SOUTH pole: Rolled first, biased heavily by player's resource quantities.
##    This is the "cost" side - players spend what they have.
##
## 2. NORTH pole: Rolled second, based on connections to the South emoji.
##    This is the "discovery" side - players learn something new.
##    North cannot be an emoji already in the player's cloud.
##
## The pair forms a qubit axis that can be planted in biomes.


## Roll SOUTH pole - biased heavily by player resource quantities
static func _roll_south_pole(atom_registry) -> Dictionary:
	var economy = _get_economy()
	if not economy:
		return {"error": "no_economy", "message": "Economy not available"}

	# Get all emojis player has resources for
	var candidates = {}
	var all_resources = {}
	if economy.has_method("get_all_resources"):
		all_resources = economy.get_all_resources()
	elif "emoji_credits" in economy:
		all_resources = economy.emoji_credits

	# Build weighted candidates from player's resources
	for emoji in all_resources:
		var amount = all_resources[emoji]
		if amount <= 0:
			continue

		# Check if this emoji has connections (can be paired)
		var connections = get_connection_weights(emoji, atom_registry)
		if connections.is_empty():
			continue

		# Weight = power-law resource bias (preserves Fibonacci ratios)
		var weight = pow(amount + 1.0, 0.65)
		candidates[emoji] = {"weight": weight, "amount": amount, "connections": connections}

	if candidates.is_empty():
		return {"error": "no_resources", "message": "No resources available for pairing"}

	# Weighted random selection
	var total_weight = 0.0
	for emoji in candidates:
		total_weight += candidates[emoji].weight

	var roll = randf() * total_weight
	var cumulative = 0.0

	for emoji in candidates:
		cumulative += candidates[emoji].weight
		if roll <= cumulative:
			return {
				"south": emoji,
				"weight": candidates[emoji].weight,
				"amount": candidates[emoji].amount,
				"connections": candidates[emoji].connections
			}

	# Fallback
	var first = candidates.keys()[0]
	return {
		"south": first,
		"weight": candidates[first].weight,
		"amount": candidates[first].amount,
		"connections": candidates[first].connections
	}


## Roll SOUTH pole from faction signature (weighted by player inventory)
## biome_emojis: optional Array of emojis native to the active biome.
## When provided, faction signature emojis that also appear in the biome
## get a soft weight boost (BIOME_AFFINITY_BOOST), making quests in a
## biome preferentially spend that biome's resources.
const BIOME_AFFINITY_BOOST_DEFAULT := 1.5

static func _roll_south_pole_from_cloud(atom_registry, faction_cloud: Array, biome_emojis: Array = [], biome_affinity_boost: float = BIOME_AFFINITY_BOOST_DEFAULT) -> Dictionary:
	# Roll south pole from faction signature, weighted by player inventory

	# South pole can be known OR unknown to player.
	# Weights use power-law formula: weight = (amount + 1)^0.65
	# Biome-native emojis in the faction signature get a soft boost.

	# Args:
	# atom_registry: IconRegistry for connection data
	# faction_cloud: the faction's cloud (its atoms/emojis)
	# biome_emojis: Emojis native to the active biome (soft boost)

	# Returns:
	# {south, weight, amount, connections} or {error, message}
	var economy = _get_economy()
	if not economy:
		return {"error": "no_economy", "message": "Economy not available"}

	# Get all resources
	var all_resources = {}
	if economy.has_method("get_all_resources"):
		all_resources = economy.get_all_resources()
	elif "emoji_credits" in economy:
		all_resources = economy.emoji_credits

	# Build weighted candidates from faction signature
	var candidates = {}
	for emoji in faction_cloud:
		# Get player's inventory amount for this emoji (0 if none)
		var amount = all_resources.get(emoji, 0)

		# Get IconRegistry connections if available (used for north pole selection)
		var connections = get_connection_weights(emoji, atom_registry)
		# Don't skip emojis without IconRegistry connections — north pole selection
		# falls back to faction co-membership when connections are empty.

		# Weight = power-law inventory bias (preserves Fibonacci ratios)
		var weight = pow(amount + 1.0, 0.65)

		# Biome affinity: boost emojis native to the active biome
		if not biome_emojis.is_empty() and emoji in biome_emojis:
			weight *= biome_affinity_boost

		candidates[emoji] = {"weight": weight, "amount": amount, "connections": connections}

	if candidates.is_empty():
		return {"error": "no_candidates", "message": "No pairable emojis in faction signature"}

	# Weighted random selection
	var total_weight = 0.0
	for emoji in candidates:
		total_weight += candidates[emoji].weight

	var roll = randf() * total_weight
	var cumulative = 0.0

	for emoji in candidates:
		cumulative += candidates[emoji].weight
		if roll <= cumulative:
			return {
				"south": emoji,
				"weight": candidates[emoji].weight,
				"amount": candidates[emoji].amount,
				"connections": candidates[emoji].connections
			}

	# Fallback
	var first = candidates.keys()[0]
	return {
		"south": first,
		"weight": candidates[first].weight,
		"amount": candidates[first].amount,
		"connections": candidates[first].connections
	}


static func _get_economy():
	var active_farm = InstrumentLocator.resolve_active_farm_main_loop()
	if active_farm:
		return active_farm.get("economy")
	return null


## Calculate cloud connectivity: sum of connection weights to player's known emojis
## Used for weighting North pole candidates by how well-connected they are to player's icon
static func calculate_cloud_connectivity(emoji: String, player_cloud: Array, atom_registry) -> float:
	# Calculate sum of connection weights from emoji to player's known signature

	# Returns sum of (|H| + L_in + L_out) for all connections to player_cloud emojis.

	# Example:
	# emoji 🔥 connected to:
	# 🌾 (weight 0.5), 👥 (weight 0.8), ⚡ (weight 0.3)
	# player_cloud = [🌾, 👥, 💰]
	# Returns: 0.5 + 0.8 = 1.3 (sum of weights to known emojis)

	# Args:
	# emoji: The emoji to check connectivity for
	# player_cloud: Player's known emojis
	# atom_registry: IconRegistry for connection data

	# Returns:
	# Sum of connection weights to player_cloud (0.0 if no connections)
	var connections = get_connection_weights(emoji, atom_registry)

	var total_connectivity = 0.0
	for target in connections:
		if target in player_cloud:
			total_connectivity += connections[target]["weight"]

	return total_connectivity


## Get all connection weights for an emoji
## Uses: |H| + L_in + L_out (absolute values, merged)
static func get_connection_weights(emoji: String, atom_registry) -> Dictionary:
	if not atom_registry:
		push_warning("IconPairing.get_connection_weights: atom_registry is null")
		return {}

	var icon = atom_registry.get_atom(emoji)
	if not icon:
		return {}

	var connections = {}  # target -> {h, weight}

	# Hamiltonian couplings (icons own H only; L lives on biome.atom_components)
	for target in icon.hamiltonian_couplings:
		var val = icon.hamiltonian_couplings[target]
		if val is float or val is int:
			if not connections.has(target):
				connections[target] = {"h": 0.0, "weight": 0.0}
			connections[target]["h"] = abs(val)

	for target in connections:
		var c = connections[target]
		c["weight"] = c["h"]

	# Remove zero-weight connections
	var to_remove = []
	for target in connections:
		if connections[target]["weight"] <= 0:
			to_remove.append(target)
	for target in to_remove:
		connections.erase(target)

	return connections


## Get sorted connection list for display/debugging
static func get_sorted_connections(emoji: String, atom_registry) -> Array:
	var connections = get_connection_weights(emoji, atom_registry)

	var total_weight = 0.0
	for target in connections:
		total_weight += connections[target]["weight"]

	var sorted_list = []
	for target in connections:
		sorted_list.append({
			"emoji": target,
			"weight": connections[target]["weight"],
			"probability": connections[target]["weight"] / total_weight if total_weight > 0 else 0,
			"h": connections[target]["h"],
		})

	sorted_list.sort_custom(func(a, b): return a.weight > b.weight)
	return sorted_list

## Format pair for display
static func format_pair(north: String, south: String) -> String:
	return "%s/%s" % [north, south]


## Check if an emoji has any connections (can be paired)
static func can_be_paired(emoji: String) -> bool:
	var atom_registry = (Engine.get_main_loop().root.get_node_or_null("/root/IconRegistry") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if not atom_registry:
		return false

	var connections = get_connection_weights(emoji, atom_registry)
	return not connections.is_empty()
