class_name PolicySnapshotBuilder
extends RefCounted

## PolicySnapshotBuilder - shared aggregation helper for policy-facing state reads.
##
## Provider must expose:
## - get_resource_snapshot()
## - get_known_vocab_pairs()
## - get_active_quests()
## - get_locked_offers()
## - get_grid_snapshot()
## - get_quest_offers_for_current_biome() (when include_offers=true)

static func build(provider, include_offers: bool = true, include_grid: bool = true) -> Dictionary:
	if not provider:
		return {}

	var resource_snapshot = provider.get_resource_snapshot() if provider.has_method("get_resource_snapshot") else {}
	var resources = resource_snapshot.get("resources", {}) if resource_snapshot is Dictionary else {}
	if not (resources is Dictionary):
		resources = {}

	var known_pairs: Array = provider.get_known_vocab_pairs() if provider.has_method("get_known_vocab_pairs") else []
	var active_quests: Array = provider.get_active_quests() if provider.has_method("get_active_quests") else []
	var locked_offers: Array = provider.get_locked_offers() if provider.has_method("get_locked_offers") else []
	var offers: Array = []
	if include_offers and provider.has_method("get_quest_offers_for_current_biome"):
		offers = provider.get_quest_offers_for_current_biome()

	var grid_snapshot: Dictionary = {}
	if include_grid and provider.has_method("get_grid_snapshot"):
		grid_snapshot = provider.get_grid_snapshot()
		if not (grid_snapshot is Dictionary):
			grid_snapshot = {}

	var biomes: Array = []
	if grid_snapshot is Dictionary:
		var raw_biomes = grid_snapshot.get("biomes", [])
		if raw_biomes is Array:
			for biome_name in raw_biomes:
				var b = str(biome_name)
				if b != "":
					biomes.append(b)

	return {
		"resources": resources,
		"resource_snapshot": resource_snapshot if resource_snapshot is Dictionary else {},
		"known_pairs": known_pairs if known_pairs is Array else [],
		"offers": offers if offers is Array else [],
		"active_quests": active_quests if active_quests is Array else [],
		"locked_offers": locked_offers if locked_offers is Array else [],
		"grid": grid_snapshot,
		"biomes": biomes,
	}
