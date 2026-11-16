extends SceneTree
## Old-save probe for the 2026-11-16 renames (tests/test_vocab_names_and_physics.py).
##
## Saves store ordered pairs ({north, south}), never icon names. This writes a
## GameState .tres in the shape every save before the renames wrote, holding
## renamed words and once physics-less words in known_icons, incorporated_icons
## and a biome's register axes, loads it back, and reports what the registry
## and the operator builder now make of those pairs. One OLD_SAVE JSON line.

const IR = preload("res://Core/Factions/IconRegistry.gd")

var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_run()
	return true


func _run() -> void:
	var GS = load("res://Core/GameState/GameState.gd")
	var st = GS.new()
	# 🧺/💰 was "Commerce" in factions.json; 📜/⚖ was "Edict" in icons.json;
	# 👥/🪓 was a physics-less "Labor"; 🪣/🌾 a physics-less "Harvest".
	st.known_icons = [{"north": "🌾", "south": "👥"}, {"north": "🧺", "south": "💰"},
		{"north": "📜", "south": "⚖"}, {"north": "👥", "south": "🪓"}]
	st.incorporated_icons = [{"north": "🧺", "south": "💰"}, {"north": "🪣", "south": "🌾"}]
	st.biome_states = {"Harbor": {"register_axes": [
		{"north": "🛶", "south": "💧"}, {"north": "🪣", "south": "🌾"}, {"north": "⚓", "south": "🪝"}]}}
	var path := "user://vocab_old_save.tres"
	var err := ResourceSaver.save(st, path)
	var loaded = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var R = root.get_node_or_null("/root/IconRegistry")
	if R == null:
		R = IR.new()
	var out := {"save_err": err, "loaded": loaded != null, "known": [], "incorporated": [], "harbor": []}
	if loaded != null:
		for k in ["known", "incorporated"]:
			var arr: Array = loaded.known_icons if k == "known" else loaded.incorporated_icons
			for e in arr:
				var n := str(e.get("north", ""))
				var s := str(e.get("south", ""))
				var ph: Dictionary = R.get_icon_physics_by_pair(n, s)
				out[k].append({"pair": "%s/%s" % [n, s], "name": str(R.find_icon_by_pair(n, s).get("name", "")),
					"rabi": float(ph.get("rabi_coupling", 0.0)),
					"couplings": (ph.get("hamiltonian_couplings", {}) as Dictionary).size()})
		var axes: Array = loaded.biome_states.get("Harbor", {}).get("register_axes", [])
		for ic in BiomeQuantumSystemBuilder.icons_from_axes(axes, R):
			out["harbor"].append({"name": ic.name, "pair": "%s/%s" % [ic.pole_0, ic.pole_1],
				"se0": ic.self_energy_0, "se1": ic.self_energy_1, "rabi": ic.rabi_coupling})
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("OLD_SAVE " + JSON.stringify(out))
	quit(0)
