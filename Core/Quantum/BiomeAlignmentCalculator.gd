class_name BiomeAlignmentCalculator
extends RefCounted

## Biome Affinity Calculator
## Calculates quantum affinity between icons and biomes
## Uses graph-based connection weights from IconPairing

static func calculate_affinity(icon: Dictionary, biome) -> float:
	# Calculate quantum affinity between icon and biome.

	# Uses: Graph-based connection strength (|H| + L_in + L_out)
	# between icon emojis and biome emojis

	# Args:
	# icon: {north: String, south: String}
	# biome: Biome with quantum_computer

	# Returns:
	# float: Weighted connection strength (higher = better match)

	# Algorithm:
	# 1. Get emojis from icon
	# 2. Get all emojis from biome QC
	# 3. For each (icon_emoji, biome_emoji) pair:
	# - Look up connection weight: |H| + L_in + L_out (IconPairing)
	# - Accumulate total weight
	# 4. Normalize by number of connections
	var icon_emojis = [icon.get("north", ""), icon.get("south", "")]
	var biome_emojis = _get_biome_emojis(biome)

	# Filter out empty emojis
	var filtered_emojis = []
	for emoji in icon_emojis:
		if not emoji.is_empty():
			filtered_emojis.append(emoji)
	icon_emojis = filtered_emojis

	if icon_emojis.is_empty() or biome_emojis.is_empty():
		return 0.0

	var total_weight = 0.0
	var connection_count = 0
	var atom_registry = _get_atom_registry()

	# Calculate connection strengths between all icon-biome emoji pairs
	for icon_emoji in icon_emojis:
		var connections = IconPairing.get_connection_weights(icon_emoji, atom_registry)

		for biome_emoji in biome_emojis:
			if connections.has(biome_emoji):
				var conn_data = connections[biome_emoji]
				var weight = conn_data.get("weight", 0.0) if conn_data is Dictionary else 0.0
				total_weight += weight
				connection_count += 1

	return total_weight / connection_count if connection_count > 0 else 0.0

static func calculate_affinity_with_populations(icon: Dictionary, biome) -> float:
	# Calculate affinity weighted by biome quantum state populations.

	# This variant multiplies connection weights by current quantum populations,
	# making affinity dynamic and state-dependent.

	# Args:
	# icon: {north: String, south: String}
	# biome: Biome with quantum_computer

	# Returns:
	# float: Population-weighted connection strength
	var icon_emojis = [icon.get("north", ""), icon.get("south", "")]
	var biome_emojis = _get_biome_emojis(biome)

	# Filter out empty emojis
	var filtered_emojis = []
	for emoji in icon_emojis:
		if not emoji.is_empty():
			filtered_emojis.append(emoji)
	icon_emojis = filtered_emojis

	if icon_emojis.is_empty() or biome_emojis.is_empty():
		return 0.0

	# Get current quantum populations (viz_cache-backed)
	var populations: Dictionary = {}
	for emoji in biome_emojis:
		populations[emoji] = biome.get_emoji_probability(emoji)

	var total_weight = 0.0
	var connection_count = 0
	var atom_registry = _get_atom_registry()

	# Calculate connection strengths weighted by populations
	for icon_emoji in icon_emojis:
		var connections = IconPairing.get_connection_weights(icon_emoji, atom_registry)

		for biome_emoji in biome_emojis:
			if connections.has(biome_emoji):
				var conn_data = connections[biome_emoji]
				var connection_weight = conn_data.get("weight", 0.0) if conn_data is Dictionary else 0.0
				var population = populations.get(biome_emoji, 0.0)

				# Weight by population (higher population = more relevant)
				total_weight += connection_weight * (1.0 + population)
				connection_count += 1

	return total_weight / connection_count if connection_count > 0 else 0.0

static func calculate_affinity_by_name(icon: Dictionary, biome_name: String) -> float:
	# Calculate affinity for an unloaded biome using BiomeRegistry (JSON-backed).

	# Used for discovery weighting — biome doesn't need to be loaded/instantiated.

	# Args:
	# icon: {north: String, south: String}
	# biome_name: Name of a biome in BiomeRegistry

	# Returns:
	# float: Connection weight (same scale as calculate_affinity)
	var biome_registry = load("res://Core/Biomes/BiomeRegistry.gd").get_shared()
	if not biome_registry:
		return 0.0
	var biome_data = biome_registry.get_by_name(biome_name)
	if not biome_data:
		return 0.0
	var biome_emojis: Array[String] = []
	for e in biome_data.emojis:
		biome_emojis.append(e)
	return _calculate_affinity_from_emojis(icon, biome_emojis)


static func _calculate_affinity_from_emojis(icon: Dictionary, biome_emojis: Array[String]) -> float:
	# Core affinity: connection weight between icon emojis and biome emojis.
	var icon_emojis = [icon.get("north", ""), icon.get("south", "")]
	icon_emojis = icon_emojis.filter(func(e): return not e.is_empty())
	if icon_emojis.is_empty() or biome_emojis.is_empty():
		return 0.0
	var total_weight = 0.0
	var connection_count = 0
	var atom_registry = _get_atom_registry()
	for icon_emoji in icon_emojis:
		var connections = IconPairing.get_connection_weights(icon_emoji, atom_registry)
		for biome_emoji in biome_emojis:
			if connections.has(biome_emoji):
				var conn_data = connections[biome_emoji]
				var weight = conn_data.get("weight", 0.0) if conn_data is Dictionary else 0.0
				total_weight += weight
				connection_count += 1
	return total_weight / connection_count if connection_count > 0 else 0.0


static func _get_biome_emojis(biome) -> Array[String]:
	# Get all emojis registered in biome's quantum computer.
	var result: Array[String] = []
	if not biome:
		return result

	if biome.viz_cache:
		var emojis = biome.viz_cache.get_emojis()
		for e in emojis:
			result.append(e)
	return result

static func _get_atom_registry():
	var icon_reg = (Engine.get_main_loop().root.get_node_or_null("/root/IconRegistry") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if icon_reg == null:
		push_error("BiomeAlignmentCalculator: Could not find IconRegistry")
	return icon_reg
