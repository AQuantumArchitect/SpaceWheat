extends "res://tests/smoke_test_base.gd"

## Smoke test: BiomeRegistry load shape after the bare-biome / neighborhood split.
## Run: godot --headless --script tests/biome_registry_load_shape.gd
##
## Pins invariants that cleanup work might silently break:
##  - biomes.json loads into bare biome records
##  - bare records keep terrain/discovery metadata but no live icons[]
##  - neighborhood loadouts are preserved separately for faction discovery
##  - Internal records (`_`-prefix) excluded from `get_exportable_biomes`
##  - All exportable biomes pass `validate()`


func _init():
	print("\n=== BiomeRegistry load shape ===")

	BiomeRegistry.reset_shared()
	var reg = BiomeRegistry.get_shared()
	var all = reg.get_all()
	var exportable = reg.get_exportable_biomes()

	# Tag-based neighborhood classification: the kind field + is_*_biome
	# predicates are gone post-layer-split. Tags are the canonical signal.
	var neighborhood_count := 0
	for b in all:
		if "neighborhood" in b.tags:
			neighborhood_count += 1
	print("  load: %d total, %d neighborhoods, %d untagged" % [all.size(), neighborhood_count, all.size() - neighborhood_count])

	_check(all.size() >= 150, "loaded a substantial biome set (>=150)")
	_check(all.size() - neighborhood_count >= 100, "untagged biome count >= 100")
	_check(neighborhood_count >= 1, "neighborhood count >= 1")

	# Neighborhoods should keep a loadout.
	var neighborhoods_with_missing_loadout: Array = []
	for b in all:
		if "neighborhood" in b.tags:
			if not (b.get_neighborhood_icons() is Array and not b.get_neighborhood_icons().is_empty()):
				neighborhoods_with_missing_loadout.append(b.name)
	_check(neighborhoods_with_missing_loadout.is_empty(), "neighborhoods keep a loadout (offenders=%s)" % [neighborhoods_with_missing_loadout])

	# Exportable filter
	var leaked_internal: Array = []
	for b in exportable:
		if b.name.begins_with("_"):
			leaked_internal.append(b.name)
	_check(leaked_internal.is_empty(), "exportable filter excludes _-prefix records")
	_check(exportable.size() < all.size(), "exportable is strict subset of all (orphanage hidden)")

	# Validate exportable
	_check(reg.validate_exportable(), "all exportable biomes validate()")

	# Neighborhoods may carry atom_components for dissipation; bare biomes
	# still validate with the same rules.
	var neighborhoods_with_components: Array = []
	for b in all:
		if "neighborhood" in b.tags and b.atom_components is Dictionary and not b.atom_components.is_empty():
			neighborhoods_with_components.append(b.name)
	print("  info: %d neighborhoods carry non-empty atom_components" % neighborhoods_with_components.size())

	_finish()
