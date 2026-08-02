class_name ProceduralIconBiome
extends RefCounted
## ProceduralIconBiome — lazy seed + materialize for icon→world fractal.

const ATOM_CAP := 12
const SIGNATURE_ICON_CAP := 6


static func build_seed(
	icon_name: String,
	pole_0: String,
	pole_1: String,
	family_atoms: Array = [],
	coupling_atoms = null
) -> Dictionary:
	var atoms: Array = []
	for a in [pole_0, pole_1]:
		if a != "" and a not in atoms:
			atoms.append(a)
	for a in family_atoms:
		var s: String = str(a)
		if s != "" and s not in atoms:
			atoms.append(s)
		if atoms.size() >= ATOM_CAP:
			break
	if coupling_atoms is Dictionary:
		for k in coupling_atoms.keys():
			var s2: String = str(k)
			if s2 != "" and s2 not in atoms:
				atoms.append(s2)
			if atoms.size() >= ATOM_CAP:
				break
	elif coupling_atoms is Array:
		for a2 in coupling_atoms:
			var s3: String = str(a2)
			if s3 != "" and s3 not in atoms:
				atoms.append(s3)
			if atoms.size() >= ATOM_CAP:
				break
	return {
		"from_icon": icon_name,
		"pole_0": pole_0,
		"pole_1": pole_1,
		"atoms": atoms,
		"closed": true,
		"signature_icons": [icon_name],
		"signature_icon_cap": SIGNATURE_ICON_CAP,
	}


static func materialize(seed: Dictionary, biome_name: String, parent_node: Node) -> Dictionary:
	if seed.is_empty():
		return {"success": false, "error": "empty_seed", "message": "No seed for procedural world"}
	var pole_0: String = str(seed.get("pole_0", ""))
	var pole_1: String = str(seed.get("pole_1", ""))
	if pole_0 == "" or pole_1 == "" or pole_0 == pole_1:
		return {"success": false, "error": "invalid_poles", "message": "Poles required"}
	if biome_name == "":
		return {"success": false, "error": "no_biome_name", "message": "Synthetic biome name required"}

	var IconCls = load("res://Core/QuantumSubstrate/Icon.gd")
	var BiomeBuilderCls = load("res://Core/Biomes/BiomeBuilder.gd")
	var DynamicBiomeCls = load("res://Core/Environment/DynamicBiome.gd")
	var QuantumVizCacheCls = load("res://Core/Visualization/QuantumVizCache.gd")
	if IconCls == null or BiomeBuilderCls == null or DynamicBiomeCls == null:
		return {"success": false, "error": "load_failed", "message": "Could not load biome build classes"}

	var lexicon = null
	if Engine.get_main_loop() and Engine.get_main_loop().root:
		lexicon = Engine.get_main_loop().root.get_node_or_null("/root/IconRegistry")
	if lexicon == null:
		var IconRegistryCls = load("res://Core/Factions/IconRegistry.gd")
		if IconRegistryCls:
			lexicon = IconRegistryCls.new()

	var icon_name: String = str(seed.get("from_icon", pole_0))
	var physics: Dictionary = {}
	if lexicon != null and lexicon.has_method("get_icon_physics_by_pair"):
		physics = lexicon.get_icon_physics_by_pair(pole_0, pole_1)
	var icon = IconCls.from_pair_physics(icon_name, pole_0, pole_1, physics, 1.0)
	var neighborhood_icons: Array = [icon]

	if lexicon != null and lexicon.has_method("get_all"):
		var seen: Dictionary = {}
		seen[pole_0 + "|" + pole_1] = true
		seen[pole_1 + "|" + pole_0] = true
		var all_icons = lexicon.get_all()
		if all_icons is Array:
			for raw in all_icons:
				if neighborhood_icons.size() >= SIGNATURE_ICON_CAP:
					break
				if not (raw is Dictionary):
					continue
				var p0: String = str(raw.get("pole_0", ""))
				var p1: String = str(raw.get("pole_1", ""))
				var iname: String = str(raw.get("name", p0))
				if p0 == "" or p1 == "":
					continue
				if p0 != pole_0 and p0 != pole_1 and p1 != pole_0 and p1 != pole_1:
					continue
				var key: String = p0 + "|" + p1
				if seen.has(key):
					continue
				seen[key] = true
				var ph2: Dictionary = {}
				if lexicon.has_method("get_icon_physics_by_pair"):
					ph2 = lexicon.get_icon_physics_by_pair(p0, p1)
				neighborhood_icons.append(IconCls.from_pair_physics(iname, p0, p1, ph2, 1.0))

	var atom_components: Dictionary = {}
	var atoms = seed.get("atoms", [pole_0, pole_1])
	if atoms is Array:
		for a in atoms:
			atom_components[str(a)] = {}

	var qres: Dictionary = BiomeBuilderCls.build_biome_quantum_system(
		biome_name,
		[],
		{},
		atom_components,
		{"neighborhood_icons": neighborhood_icons, "regime": "closed"}
	)
	if not bool(qres.get("success", false)):
		return {
			"success": false,
			"error": "qc_build_failed",
			"message": str(qres.get("error", "build_biome_quantum_system failed")),
		}

	var qc = qres.get("quantum_computer")
	if qc == null:
		return {"success": false, "error": "no_qc", "message": "No quantum computer built"}

	var biome = DynamicBiomeCls.new()
	biome.set_biome_type(biome_name)
	biome.name = biome_name
	biome.quantum_computer = qc
	biome.set_meta("fractal_world", true)
	biome.set_meta("fractal_seed", seed.duplicate(true))
	biome.set_meta("biome_def", {
		"name": biome_name,
		"emojis": atoms if atoms is Array else [pole_0, pole_1],
		"atom_components": atom_components,
		"regime": "closed",
		"tags": ["fractal", "procedural_icon_world"],
	})

	BiomeBuilderCls._initialize_biome_components(biome, qc)

	var emoji_pairs: Array = []
	for ic in neighborhood_icons:
		emoji_pairs.append({"north": ic.pole_0, "south": ic.pole_1})
	var viz_metadata: Dictionary = BiomeBuilderCls._build_viz_metadata(emoji_pairs, null)
	if QuantumVizCacheCls:
		biome.viz_cache = QuantumVizCacheCls.new()
		biome.viz_cache.update_metadata_from_payload(viz_metadata)

	if parent_node != null and biome.get_parent() == null:
		parent_node.add_child(biome)

	return {
		"success": true,
		"stub": false,
		"biome_name": biome_name,
		"biome": biome,
		"quantum_computer": qc,
		"seed": seed,
		"icon_n": neighborhood_icons.size(),
	}
