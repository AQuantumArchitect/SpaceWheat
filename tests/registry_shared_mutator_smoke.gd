extends SceneTree

## Smoke test: shared BiomeRegistry + canonical mutator path.
## Run: godot --headless --script tests/registry_shared_mutator_smoke.gd
##
## Verifies:
##  1. `BiomeRegistry.get_shared()` returns the same instance on repeat calls.
##  2. `reset_shared()` clears it (next call yields a fresh instance).
##  3. `add_atom_pair_to_biome` mutates the shared instance and the mutation
##     is visible via subsequent `get_shared()` queries (the multi-instance
##     bug the shared registry exists to prevent).
##  4. The mutator rejects duplicate atoms and missing biomes.

var passed = 0
var failed = 0


func _init():
	print("\n=== BiomeRegistry shared + mutator smoke ===")

	_test_shared_identity()
	_test_reset_clears()
	_test_mutator_propagates()
	_test_mutator_guards()

	print("\nResult: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
		print("  PASS  %s" % label)
	else:
		failed += 1
		push_error("  FAIL  %s" % label)


func _pick_biome_name() -> String:
	var reg = BiomeRegistry.get_shared()
	for b in reg.get_exportable_biomes():
		if b == null:
			continue
		# Skip faction-biomes (identity-shaped, atom_components empty by design)
		if b.kind == "faction_biome":
			continue
		return b.name
	return ""


func _test_shared_identity() -> void:
	BiomeRegistry.reset_shared()
	var a = BiomeRegistry.get_shared()
	var b = BiomeRegistry.get_shared()
	_check(a != null, "shared instance is non-null")
	_check(a == b, "repeat get_shared returns same instance")


func _test_reset_clears() -> void:
	var a = BiomeRegistry.get_shared()
	BiomeRegistry.reset_shared()
	var b = BiomeRegistry.get_shared()
	_check(a != b, "reset_shared yields a fresh instance")


func _test_mutator_propagates() -> void:
	BiomeRegistry.reset_shared()
	var name = _pick_biome_name()
	if name == "":
		_check(false, "found a world biome to mutate")
		return

	var north := "🧪"  # unlikely to collide; will skip if already in basis
	var south := "⚗️"
	var reg = BiomeRegistry.get_shared()
	var biome = reg.get_by_name(name)
	if biome == null:
		_check(false, "biome %s resolvable" % name)
		return

	# Skip if either atom already in basis (mutator would reject; not the bug
	# under test). Walk a few biomes if needed.
	if north in biome.emojis or south in biome.emojis:
		print("  SKIP  mutator propagation: %s already has %s/%s" % [name, north, south])
		return

	var ok = reg.add_atom_pair_to_biome(name, north, south, "SmokePair")
	_check(ok, "add_atom_pair_to_biome returned true")

	# Same shared instance: mutation visible
	var reg2 = BiomeRegistry.get_shared()
	var biome2 = reg2.get_by_name(name)
	_check(north in biome2.emojis, "north atom present after mutation")
	_check(south in biome2.emojis, "south atom present after mutation")
	_check(reg2.get_biomes_for_emoji(north).has(biome2), "emoji index updated for north")

	# A separately-instantiated registry should NOT see the mutation (it
	# re-parses from disk). This documents the bug shared instance fixes.
	var fresh := BiomeRegistry.new()
	var bf = fresh.get_by_name(name)
	_check(not (north in bf.emojis), "fresh .new() registry isolated from mutation")


func _test_mutator_guards() -> void:
	BiomeRegistry.reset_shared()
	var reg = BiomeRegistry.get_shared()

	# Missing biome
	_check(not reg.add_atom_pair_to_biome("__no_such_biome__", "🔮", "💠"),
		"mutator rejects missing biome")

	# Duplicate atom (use any emoji already in some biome)
	var name = _pick_biome_name()
	if name == "":
		return
	var biome = reg.get_by_name(name)
	if biome.emojis.size() < 1:
		return
	var existing := str(biome.emojis[0])
	_check(not reg.add_atom_pair_to_biome(name, existing, "💠"),
		"mutator rejects duplicate atom")

	# Same atom for both poles
	_check(not reg.add_atom_pair_to_biome(name, "🟢", "🟢"),
		"mutator rejects identical poles")
