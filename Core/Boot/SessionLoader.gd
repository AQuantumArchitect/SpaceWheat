class_name SessionLoader
extends RefCounted

## Resolves boot requests against the GameState/scenario layer.
##
## Owns:
## - Boot request normalization (slot/scenario/headless argument shapes)
## - Initial biome name resolution from GameState.unlocked_biomes
## - Biome loadability checks against the BiomeRegistry
##
## Pure-data; no Node side effects. BootManager constructs one and delegates.


var _biome_registry  # BiomeRegistry — shared with WorldBuilder


func _init(biome_registry = null) -> void:
	if biome_registry:
		_biome_registry = biome_registry
	else:
		_biome_registry = BiomeRegistry.new()


func normalize_boot_request(load_slot, scenario_id, headless: bool) -> Dictionary:
	# Accepts (dict) or (slot_int, scenario_id, headless). Defers shape
	# normalization to SaveStore.normalize_boot_request — single source of truth.
	if load_slot is Dictionary:
		var raw: Dictionary = (load_slot as Dictionary).duplicate()
		raw["headless"] = raw.get("headless", headless)
		return SaveStore.normalize_boot_request(raw)
	return SaveStore.normalize_boot_request({
		"slot": load_slot,
		"scenario_id": scenario_id,
		"headless": headless,
	})


func resolve_initial_biome_names(state = null) -> Dictionary:
	var names: Array[String] = []
	if state and "unlocked_biomes" in state:
		for raw_name in state.unlocked_biomes:
			var biome_name := str(raw_name)
			if biome_name != "" and biome_name not in names:
				names.append(biome_name)

	if names.is_empty():
		return {"success": false, "error": "no_biomes", "message": "GameState.unlocked_biomes is empty"}

	for biome_name in names:
		if not is_loadable_biome(biome_name):
			return {
				"success": false,
				"error": "unknown_biome",
				"message": "Unknown initial biome '%s'" % biome_name
			}
	return {"success": true, "biomes": names}


func is_loadable_biome(biome_name: String) -> bool:
	if not _biome_registry:
		_biome_registry = BiomeRegistry.new()
	return _biome_registry.get_by_name(biome_name) != null
