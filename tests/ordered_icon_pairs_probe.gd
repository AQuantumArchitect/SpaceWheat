extends SceneTree
## Ordered icon pairs probe (tests/test_ordered_icon_pairs.py).
##
## Seven pole pairs carry two words, one per orientation (south pole provides).
## Prints one PAIRS_TRACE JSON line:
##   words:   every orientation of the seven -> registry name, owners, physics
##   same:    IconRegistry.same_word / has_inverse_word answers
##   ledger:  vocabulary tiers from an OLD-FORMAT save's ledger, loaded back
##            from a .tres GameState written with the pre-change shape
##   boot:    the boot loadout row of every biome that seats one of the seven
## No game boot: the registries are built directly (the autoloads still load).

const PAIRS := [["⚖", "💰"], ["⛓", "👥"], ["🪢", "🪡"], ["👥", "🍞"],
		["🌾", "🌱"], ["🌱", "🌿"], ["🍂", "🌿"]]


class FakeFarm:
	extends RefCounted
	var grid = null
	var incorporated_icons: Array = []


var _done := false


# Run on the first frame, inside the live tree, so Biome reaches the
# IconRegistry autoload instead of building its own fallback.
func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_run()
	return true


func _run() -> void:
	var R = load("res://Core/Factions/IconRegistry.gd").new()
	var out := {"words": [], "same": {}, "ledger": {}, "boot": {}}

	for p in PAIRS:
		for o in [[p[0], p[1]], [p[1], p[0]]]:
			var rec: Dictionary = R.find_icon_by_pair(o[0], o[1])
			var ph: Dictionary = R.get_icon_physics_by_pair(o[0], o[1])
			out["words"].append({
				"pole_0": o[0], "pole_1": o[1],
				"name": str(rec.get("name", "")),
				"rec_pole_0": str(rec.get("pole_0", "")), "rec_pole_1": str(rec.get("pole_1", "")),
				"owners": R.get_factions_for_pair(o[0], o[1]),
				"inverse": R.has_inverse_word(o[0], o[1]),
				"se0": float(ph.get("self_energy_0", 0.0)), "se1": float(ph.get("self_energy_1", 0.0)),
				"rabi": float(ph.get("rabi_coupling", 0.0)),
				"hc": (ph.get("hamiltonian_couplings", {}) as Dictionary).keys(),
			})

	var IR = load("res://Core/Factions/IconRegistry.gd")
	out["same"] = {
		"labor_vs_bread": IR.same_word("👥", "🍞", "🍞", "👥"),
		"labor_vs_labor": IR.same_word("👥", "🍞", "👥", "🍞"),
		# Factory ⚙/🏭 has no inverse word: 🏭/⚙ (how the campaign teaches it)
		# is the same word read the other way round.
		"factory_inverted": IR.same_word("⚙", "🏭", "🏭", "⚙"),
		"factory_has_inverse": IR.has_inverse_word("⚙", "🏭"),
		"probe_same_word": ProbeActions.same_word({"north": "🍞", "south": "👥"}, "👥", "🍞"),
		"discovered_labor_has_bread": IR.discovered_set_from_icons(
				[{"north": "👥", "south": "🍞"}]).has("🍞|👥"),
		"discovered_factory_inverted": R.is_icon_discovered("⚙", "🏭",
				IR.discovered_set_from_icons([{"north": "🏭", "south": "⚙"}])),
	}

	# An old-format save: the ledgers are arrays of {north, south}, exactly the
	# shape every save before this change wrote. Write it, load it, then read
	# the vocabulary back through the one rule.
	var GS = load("res://Core/GameState/GameState.gd")
	var st = GS.new()
	st.known_icons = [{"north": "🌾", "south": "👥"}, {"north": "🏭", "south": "⚙"}]
	st.incorporated_icons = [{"north": "👥", "south": "🍞"}, {"north": "🏭", "south": "⚙"}]
	var path := "user://ordered_pairs_old_save.tres"
	var err := ResourceSaver.save(st, path)
	var loaded = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var farm := FakeFarm.new()
	if loaded != null:
		farm.incorporated_icons = loaded.incorporated_icons
	out["ledger"] = {
		"save_err": err,
		"loaded": loaded != null,
		"ledger_size": farm.incorporated_icons.size(),
		"labor": ProbeActions.vocabulary_tier(farm, "👥", "🍞").get("tier", ""),
		"bread": ProbeActions.vocabulary_tier(farm, "🍞", "👥").get("tier", ""),
		"factory": ProbeActions.vocabulary_tier(farm, "⚙", "🏭").get("tier", ""),
		"factory_inverted": ProbeActions.vocabulary_tier(farm, "🏭", "⚙").get("tier", ""),
	}
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	var seven := {}
	for p in PAIRS:
		seven["%s|%s" % [p[0], p[1]]] = true
		seven["%s|%s" % [p[1], p[0]]] = true
	var BR = load("res://Core/Biomes/BiomeRegistry.gd").get_shared()
	for b in BR.get_all():
		var rows := []
		for ic in b.get_neighborhood_icons():
			if seven.has("%s|%s" % [ic.pole_0, ic.pole_1]):
				var ph2: Dictionary = R.get_icon_physics_by_pair(ic.pole_0, ic.pole_1)
				rows.append({"name": str(ic.name), "pole_0": ic.pole_0, "pole_1": ic.pole_1,
					"se0": float(ph2.get("self_energy_0", 0.0)), "se1": float(ph2.get("self_energy_1", 0.0)),
					"rabi": float(ph2.get("rabi_coupling", 0.0))})
		if not rows.is_empty():
			out["boot"][str(b.name)] = rows

	print("PAIRS_TRACE " + JSON.stringify(out))
	R.free()
	quit(0)
