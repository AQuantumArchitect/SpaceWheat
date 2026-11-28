extends SceneTree
## Vocabulary boot probe (tests/test_vocab_physics.py, tools/vocab/).
##
## For every biome in biomes.json: build its boot loadout exactly as
## BiomeBuilder does (Biome.get_neighborhood_icons -> allocate_axis ->
## build_operators_from_icons -> initialize_ground_state), and print one
## VOCAB_BOOT JSON line per biome with:
##   loadout   [name, north, south] per qubit
##   eigs      the lowest eigenvalues of H (up to 6)
##   gap       QuantumComputer.get_hamiltonian_spectral_gap() (the ending's measure)
##   hnorm     Frobenius norm of H
##   p_south   boot-state P(south) per qubit (ground state + dawn kick)
##   dh        Frobenius norm of H minus H built with the pairs in
##             SW_VOCAB_ZERO (comma list of "north|south") stripped of physics:
##             the size of the change those words' physics make here.
## Optional env SW_VOCAB_AXES: JSON {biome: [[north, south], ...]} replaces a
## biome's loadout (to measure an inverted or planted seat).
## Biomes with more than SW_VOCAB_MAXQ qubits (default 10) report loadout only.

const _IR = preload("res://Core/Factions/IconRegistry.gd")

var _done := false
var _lex = null


func _reg():
	if _lex == null:
		_lex = root.get_node_or_null("/root/IconRegistry")
	if _lex == null:
		_lex = _IR.new()
	return _lex


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_run()
	return true


func _frob(h: ComplexMatrix) -> float:
	var p: PackedFloat64Array = h._to_packed()
	var s := 0.0
	for v in p:
		s += v * v
	return sqrt(s)


func _build(bname: String, axes: Array, zero: Dictionary) -> QuantumComputer:
	var qc = QuantumComputer.new(bname)
	for i in range(axes.size()):
		qc.allocate_axis(i, str(axes[i][0]), str(axes[i][1]))
	var icons: Array = BiomeQuantumSystemBuilder.icons_from_axes(_axes_dicts(axes))
	if not zero.is_empty():
		for ic in icons:
			if zero.has("%s|%s" % [_IR.norm_emoji(ic.pole_0), _IR.norm_emoji(ic.pole_1)]):
				ic.self_energy_0 = 0.0
				ic.self_energy_1 = 0.0
				ic.self_energy = 0.0
				ic.rabi_coupling = 0.0
				ic.hamiltonian_couplings = {}
				ic.cross_couplings = {}
	var sb = BiomeQuantumSystemBuilder.new()
	sb.quantum_computer = qc
	sb.build_operators_from_icons(bname, icons, {})
	return qc


func _axes_dicts(axes: Array) -> Array:
	var out: Array = []
	for a in axes:
		out.append({"north": str(a[0]), "south": str(a[1])})
	return out


func _run() -> void:
	var maxq := int(OS.get_environment("SW_VOCAB_MAXQ")) if OS.get_environment("SW_VOCAB_MAXQ") != "" else 10
	var zero := {}
	for k in OS.get_environment("SW_VOCAB_ZERO").split(",", false):
		zero[_IR.norm_emoji(k)] = true
	var override := {}
	if OS.get_environment("SW_VOCAB_AXES") != "":
		override = JSON.parse_string(OS.get_environment("SW_VOCAB_AXES"))
	var only := OS.get_environment("SW_VOCAB_ONLY")
	var engine = QuantumEvolutionEngine.new()
	var BR = load("res://Core/Biomes/BiomeRegistry.gd").get_shared()
	for b in BR.get_all():
		var bname := str(b.name)
		if only != "" and not (bname in only.split(",")):
			continue
		var axes: Array = []
		var loadout: Array = []
		if override.has(bname):
			axes = override[bname]
			for a in axes:
				var rec: Dictionary = _reg().find_icon_by_pair(str(a[0]), str(a[1]))
				loadout.append([str(rec.get("name", "")), str(a[0]), str(a[1])])
		else:
			for ic in b.get_neighborhood_icons():
				axes.append([ic.pole_0, ic.pole_1])
				loadout.append([str(ic.name), ic.pole_0, ic.pole_1])
		var row := {"biome": bname, "loadout": loadout}
		if axes.size() >= 1 and axes.size() <= maxq:
			var qc := _build(bname, axes, {})
			var dim: int = qc.register_map.dim()
			row["gap"] = qc.get_hamiltonian_spectral_gap()
			row["hnorm"] = _frob(qc.hamiltonian)
			if engine.get_dimension() != dim:
				engine.set_dimension(dim)
			var res: Dictionary = engine.compute_eigenstates(qc.hamiltonian.scale_real(-1.0)._to_packed())
			var eigs: Array = []
			for v in res.get("eigenvalues", PackedFloat64Array()):
				eigs.append(-float(v))
			eigs.sort()
			row["eigs"] = eigs.slice(0, 6)
			qc.initialize_ground_state()
			var ps: Array = []
			for q in range(qc.register_map.num_qubits):
				var shift: int = qc.register_map.num_qubits - 1 - q
				var p1 := 0.0
				for i in range(dim):
					if (i >> shift) & 1 == 1:
						p1 += qc.density_matrix.get_element(i, i).re
				ps.append(snappedf(p1, 0.0001))
			row["p_south"] = ps
			if not zero.is_empty():
				var qz := _build(bname, axes, zero)
				row["dh"] = _frob(qc.hamiltonian.add(qz.hamiltonian.scale_real(-1.0)))
				row["gap_zeroed"] = qz.get_hamiltonian_spectral_gap()
		print("VOCAB_BOOT " + JSON.stringify(row))
	quit(0)
