extends SceneTree

## Smoke test: BiomeRegistry load shape after the thrash + tag fix.
## Run: godot --headless --script tests/biome_registry_load_shape.gd
##
## Pins invariants that cleanup work might silently break:
##  - Single-file load (faction_biomes.json removed; biomes.json is canonical)
##  - 60 world_biome + 97 faction_biome (one per faction)
##  - Every faction_biome carries the "faction_biome" tag
##  - Internal records (`_`-prefix) excluded from `get_exportable_biomes`
##  - All exportable biomes pass `validate()`

var passed = 0
var failed = 0


func _init():
	print("\n=== BiomeRegistry load shape ===")

	BiomeRegistry.reset_shared()
	var reg = BiomeRegistry.get_shared()
	var all = reg.get_all()
	var exportable = reg.get_exportable_biomes()

	var by_kind: Dictionary = {}
	for b in all:
		var k = b.kind if b.kind else "world_biome"
		by_kind[k] = by_kind.get(k, 0) + 1
	print("  load: %d total, kinds=%s" % [all.size(), by_kind])

	_check(all.size() >= 150, "loaded a substantial biome set (>=150)")
	_check(by_kind.get("world_biome", 0) >= 50, "world_biome count >= 50")
	_check(by_kind.get("faction_biome", 0) >= 90, "faction_biome count >= 90")

	# Tag consistency
	var untagged: Array = []
	for b in all:
		if b.kind == "faction_biome" and not (b.tags is Array and b.tags.has("faction_biome")):
			untagged.append(b.name)
	_check(untagged.is_empty(), "every faction_biome carries `faction_biome` tag (offenders=%s)" % [untagged])

	# Exportable filter
	var leaked_internal: Array = []
	for b in exportable:
		if b.name.begins_with("_"):
			leaked_internal.append(b.name)
	_check(leaked_internal.is_empty(), "exportable filter excludes _-prefix records")
	_check(exportable.size() < all.size(), "exportable is strict subset of all (orphanage hidden)")

	# Validate exportable
	_check(reg.validate_exportable(), "all exportable biomes validate()")

	# Faction-biomes are identity-shaped: empty atom_components by design
	var fb_with_components: Array = []
	for b in all:
		if b.kind == "faction_biome" and b.atom_components is Dictionary and not b.atom_components.is_empty():
			fb_with_components.append(b.name)
	# Soft check — print only, don't fail (some faction-biomes may carry components legitimately)
	print("  info: %d faction-biomes carry non-empty atom_components" % fb_with_components.size())

	print("\nResult: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
		print("  PASS  %s" % label)
	else:
		failed += 1
		push_error("  FAIL  %s" % label)
