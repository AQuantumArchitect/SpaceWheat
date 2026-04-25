class_name VocabPairUtils
extends RefCounted

## VocabPairUtils - shared helpers for vocabulary pair discovery/injection filtering.


static func collect_known_pairs(farm_ref) -> Array:
	var pairs: Array = []
	if farm_ref and farm_ref.has_method("get_known_pairs"):
		pairs.append_array(farm_ref.get_known_pairs())
	if farm_ref and "vocabulary_evolution" in farm_ref and farm_ref.vocabulary_evolution:
		var vocab = farm_ref.vocabulary_evolution
		if vocab and vocab.has_method("get_discovered_vocabulary"):
			var discovered = vocab.get_discovered_vocabulary()
			if discovered is Array:
				pairs.append_array(discovered)
	return pairs


static func collect_injectable_pairs(farm_ref, biome = null) -> Array:
	var pairs = collect_known_pairs(farm_ref)
	var filtered: Array = []
	var seen: Dictionary = {}
	for pair in pairs:
		if not (pair is Dictionary):
			continue
		var north = str(pair.get("north", ""))
		var south = str(pair.get("south", ""))
		if north == "" or south == "" or north == south:
			continue
		if biome and (biome_has_emoji(biome, north) or biome_has_emoji(biome, south)):
			continue
		var key = "%s|%s" % [north, south]
		if seen.has(key):
			continue
		seen[key] = true
		filtered.append({"north": north, "south": south})
	return filtered


static func biome_has_emoji(biome, emoji: String) -> bool:
	if not biome or emoji == "":
		return false
	if biome.viz_cache and biome.viz_cache.has_metadata():
		return biome.viz_cache.get_qubit(emoji) >= 0
	return false


## Build the "discovered pair-key set" from a farm/game-state ref. Pass the
## result to IconLexicon.is_pair_discovered / filter_discovered_records. Empty
## set if no vocabulary system is wired up yet (e.g. during boot).
static func discovered_pair_set(farm_ref) -> Dictionary:
	var pairs = collect_known_pairs(farm_ref)
	var IconLexiconScript = load("res://Core/Factions/IconLexicon.gd")
	return IconLexiconScript.discovered_set_from_vocabulary(pairs)
