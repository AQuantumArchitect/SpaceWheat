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
	var physics: Dictionary = pair_physics(lexicon, pole_0, pole_1)
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
				# A neighbour earns a qubit only if it brings physics: an icon with
				# no self-energy, no rabi and no couplings is a frozen qubit.
				var ph2: Dictionary = pair_physics(lexicon, p0, p1)
				if not has_physics(ph2):
					continue
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
	# Same tail as an outer biome (BiomeBuilder.build_from_spec): the viz cache
	# carries the icons' H (self-energies + couplings) so the field draws it, and
	# the evolution granularity comes from the characteristics sweep.
	if biome.has_method("_seed_viz_couplings"):
		biome._seed_viz_couplings()
	BiomeCharacteristics.apply_to_biome(biome)

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


## The physics an icon brings into an inner world, from the Icon library.
## The pair's own record wins. A pair whose record carries no physics (an
## anonymous or data-only pair) is assembled from its two atoms instead: each
## pole's self-energy and the atoms' Hamiltonian couplings, so the world still
## gets the physics of the emojis it is made of. No rabi term is invented.
static func pair_physics(lexicon, pole_0: String, pole_1: String) -> Dictionary:
	var physics: Dictionary = {}
	if lexicon != null and lexicon.has_method("get_icon_physics_by_pair"):
		physics = lexicon.get_icon_physics_by_pair(pole_0, pole_1)
	if has_physics(physics) or lexicon == null or not lexicon.has_method("get_atom"):
		return physics
	var a0 = lexicon.get_atom(pole_0)
	var a1 = lexicon.get_atom(pole_1)
	var couplings: Dictionary = {}
	for atom in [a0, a1]:
		if atom == null or not ("hamiltonian_couplings" in atom):
			continue
		for target in atom.hamiltonian_couplings:
			if str(target) == pole_0 or str(target) == pole_1:
				continue
			if couplings.has(target):
				continue
			var v = atom.hamiltonian_couplings[target]
			couplings[target] = [v.x, v.y] if v is Vector2 else v
	var out: Dictionary = physics.duplicate(true) if not physics.is_empty() else {}
	out["self_energy_0"] = float(a0.self_energy) if a0 != null and "self_energy" in a0 else 0.0
	out["self_energy_1"] = float(a1.self_energy) if a1 != null and "self_energy" in a1 else 0.0
	out["rabi_coupling"] = float(out.get("rabi_coupling", 0.0))
	out["hamiltonian_couplings"] = couplings
	return out


## True if this physics dict puts any term into H.
static func has_physics(physics: Dictionary) -> bool:
	if physics.is_empty():
		return false
	for k in ["self_energy_0", "self_energy_1", "rabi_coupling"]:
		if absf(float(physics.get(k, 0.0))) > 1e-10:
			return true
	var hc = physics.get("hamiltonian_couplings", {})
	return hc is Dictionary and not (hc as Dictionary).is_empty()
