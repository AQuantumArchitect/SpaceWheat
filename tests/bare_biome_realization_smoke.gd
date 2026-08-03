extends "res://tests/smoke_test_base.gd"

## Smoke test for the bare-biome / neighborhood split.
## Run: godot --headless --script tests/bare_biome_realization_smoke.gd

const BiomeRegistryCls = preload("res://Core/Biomes/BiomeRegistry.gd")
const BiomeBuilderCls = preload("res://Core/Biomes/BiomeBuilder.gd")

var _ran := false


func _process(_delta: float) -> bool:
	# Run on the first frame, not _init(): the live biome's quantum_computer/
	# register_map resolution touches /root/* autoload paths (IconRegistry/
	# FactionDensityMatrix), which only work once the scene tree is active —
	# see tests/story_icon_cutover_smoke.gd for the precedent.
	if _ran:
		return false
	_ran = true
	_run_test()
	return false


func _run_test() -> void:
	print("\n=== Bare biome neighborhood smoke ===")
	BiomeRegistryCls.reset_shared()
	var reg = BiomeRegistryCls.get_shared()

	var biome = _pick_bare_biome(reg)
	_check(biome != null, "found a bare biome with a neighborhood loadout")
	if biome == null:
		_finish()
		return

	_check(biome.get_neighborhood_icons().size() > 0, "%s preserves a neighborhood loadout" % biome.name)
	_check(biome.validate(), "%s validates as a bare biome" % biome.name)

	var result = BiomeBuilderCls.build_from_spec(biome, null, {"skip_tree_add": true})
	_check(bool(result.get("success", false)), "%s can become a live biome" % biome.name)
	if bool(result.get("success", false)):
		var live = result.get("biome_node", null)
		_check(live != null, "live biome node returned")
		if live != null:
			var qc = live.quantum_computer
			_check(qc != null, "live neighborhood has a quantum computer")
			_check(qc != null and qc.register_map != null and qc.register_map.num_qubits > 0, "live neighborhood has registers")
			var _def = live.get_meta("biome_def", null)
			_check(_def != null and _def.get_neighborhood_icons().size() > 0, "live neighborhood has faction-derived icons")

	_finish()


func _pick_bare_biome(reg) -> Object:
	for biome in reg.get_all():
		if biome == null:
			continue
		if "neighborhood" in biome.tags:
			continue
		if biome.get_neighborhood_icons().is_empty():
			continue
		return biome
	return null
