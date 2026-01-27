class_name VocabInjectionSubmenu
extends RefCounted

## Vocabulary Injection Submenu
## Dynamic submenu for Tool 4Q action showing vocab options sorted by biome affinity
## Supports F-cycling through multiple sets of options

const BiomeAffinityCalculator = preload("res://Core/Quantum/BiomeAffinityCalculator.gd")

const OPTIONS_PER_PAGE = 3  # Show 3 options per page (Q/E/R)

static func generate_submenu(biome, farm, page: int = 0) -> Dictionary:
	"""Generate dynamic submenu for vocab injection.

	Args:
		biome: Current biome
		farm: Farm instance (vocab owner)
		page: Page number for F-cycling (0 = first 3, 1 = next 3, etc.)

	Returns submenu with structure:
	{
		"name": "vocab_injection",
		"title": "Inject Vocabulary",
		"dynamic": true,
		"page": int,
		"max_pages": int,
		"actions": {
			"Q": {vocab_pair, affinity, label, hint},
			"E": {vocab_pair, affinity, label, hint},
			"R": {vocab_pair, affinity, label, hint}
		}
	}
	"""
	var candidate_pairs = _collect_injectable_pairs(farm, biome)
	var sorted_pairs = _sort_by_biome_affinity(candidate_pairs, biome, farm)

	# Calculate pagination
	var total_pairs = sorted_pairs.size()
	var max_pages = ceili(float(total_pairs) / OPTIONS_PER_PAGE)
	var current_page = page % max_pages if max_pages > 0 else 0

	# Get pairs for current page
	var start_idx = current_page * OPTIONS_PER_PAGE
	var end_idx = min(start_idx + OPTIONS_PER_PAGE, total_pairs)
	var page_pairs = sorted_pairs.slice(start_idx, end_idx)

	# Build actions for Q/E/R
	var actions = {}
	var keys = ["Q", "E", "R"]
	for i in range(page_pairs.size()):
		var pair = page_pairs[i]
		var north = pair.get("north", "")
		var south = pair.get("south", "")
		var affinity = pair.get("affinity", 0.0)
		actions[keys[i]] = {
			"vocab_pair": {"north": north, "south": south},
			"affinity": affinity,
			"label": "%s/%s" % [north, south],
			"hint": "Affinity: %.2f" % affinity,
			"enabled": true,
			"action": "inject_vocabulary"
		}

	return {
		"name": "vocab_injection",
		"title": "🌱 Inject Vocabulary",
		"dynamic": true,
		"page": current_page,
		"max_pages": max_pages,
		"total_options": total_pairs,
		"actions": actions
	}


static func _collect_injectable_pairs(farm, biome) -> Array:
	"""Collect vocab pairs that can be injected into biome.

	A pair is injectable if:
	- Player has learned it (in known_pairs)
	- NOT already in biome's quantum computer
	"""
	var injectable = []

	if not farm:
		return injectable

	var pairs: Array = []
	if farm.has_method("get_known_pairs"):
		pairs.append_array(farm.get_known_pairs())
	if "vocabulary_evolution" in farm and farm.vocabulary_evolution and farm.vocabulary_evolution.has_method("get_discovered_vocabulary"):
		var discovered = farm.vocabulary_evolution.get_discovered_vocabulary()
		if discovered is Array:
			pairs.append_array(discovered)

	var biome_emojis = _get_biome_emojis(biome)
	var seen: Dictionary = {}

	for pair in pairs:
		if not (pair is Dictionary):
			continue
		var north = pair.get("north", "")
		var south = pair.get("south", "")
		if north == "" or south == "" or north == south:
			continue

		# Check if already in biome
		if north in biome_emojis or south in biome_emojis:
			continue  # Already present

		var key = "%s|%s" % [north, south]
		if seen.has(key):
			continue
		seen[key] = true
		injectable.append({"north": north, "south": south})

	return injectable


static func _sort_by_biome_affinity(pairs: Array, biome, farm) -> Array:
	"""Sort vocab pairs by descending affinity to biome.

	Uses BiomeAffinityCalculator to calculate connection strength.
	"""
	var scored_pairs = []

	# Get player vocabulary QC if available
	var player_vocab_qc = _get_player_vocab_qc()

	for pair in pairs:
		var affinity = BiomeAffinityCalculator.calculate_affinity(pair, biome, player_vocab_qc)
		scored_pairs.append({
			"north": pair.get("north", ""),
			"south": pair.get("south", ""),
			"affinity": affinity
		})

	# Sort by descending affinity
	scored_pairs.sort_custom(func(a, b): return a.affinity > b.affinity)
	return scored_pairs


static func _get_biome_emojis(biome) -> Array[String]:
	"""Get all emojis in biome's quantum computer."""
	if not biome or not biome.quantum_computer:
		return []

	var emojis: Array[String] = []
	var coordinates = biome.quantum_computer.register_map.coordinates

	for emoji in coordinates.keys():
		emojis.append(emoji)

	return emojis


static func _get_player_vocab_qc() -> QuantumComputer:
	"""Get player vocabulary quantum computer from autoload."""
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		var player_vocab = tree.root.get_node_or_null("PlayerVocabulary")
		if player_vocab and player_vocab.vocab_qc:
			return player_vocab.vocab_qc

	return null
