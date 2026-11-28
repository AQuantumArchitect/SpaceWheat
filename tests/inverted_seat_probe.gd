extends SceneTree
## Inverted seats and the discover rule (tests/test_inverted_seats.py).
##
## SEAT   for each word the game seats the other way round (the four inverted
##        campaign teachings and the starter 🌾/👥): the physics the registry
##        hands an inverted seat, next to the word's own.
## VILLAGE  Village's boot loadout plus one word, seated in the word's own
##        orientation and inverted: is H_inverted == X_q H_own X_q (the same
##        word, its atoms relabelled), and the spectral gap of each.
## LEARN  Farm.discover_icon on a bare Farm: both words of a pair, a word whose
##        north is already a pole of a known word, and a reversed spelling of a
##        word already known.

const IR = preload("res://Core/Factions/IconRegistry.gd")

const INVERTED := [["🏭", "⚙"], ["🪵", "🪓"], ["🩸", "🦅"], ["📜", "🏰"], ["🌾", "👥"]]
const VILLAGE_BOOT := [["👥", "🍞"], ["🔥", "❄"], ["💰", "⚙"]]

var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_run()
	return true


func _h(axes: Array) -> QuantumComputer:
	var qc = QuantumComputer.new("Village")
	var dicts: Array = []
	for i in range(axes.size()):
		qc.allocate_axis(i, str(axes[i][0]), str(axes[i][1]))
		dicts.append({"north": str(axes[i][0]), "south": str(axes[i][1])})
	var sb = BiomeQuantumSystemBuilder.new()
	sb.quantum_computer = qc
	sb.build_operators_from_icons("Village", BiomeQuantumSystemBuilder.icons_from_axes(dicts), {})
	return qc


func _planted(boot: Array, seat: Array) -> QuantumComputer:
	var qc := _h(boot)
	qc.initialize_ground_state()
	var sb = BiomeQuantumSystemBuilder.new()
	sb.quantum_computer = qc
	sb.expand_quantum_system(str(seat[0]), str(seat[1]))
	return qc


func _run() -> void:
	var R = root.get_node_or_null("/root/IconRegistry")
	if R == null:
		R = IR.new()
	var seats: Array = []
	for p in INVERTED:
		var own: Dictionary = R.get_icon_physics_by_pair(p[1], p[0])
		var inv: Dictionary = R.get_icon_physics_by_pair(p[0], p[1])
		seats.append({"seat": "%s/%s" % [p[0], p[1]],
			"word": str(R.find_icon_by_pair(p[0], p[1]).get("name", "")),
			"own_se0": own.get("self_energy_0", 0.0), "own_se1": own.get("self_energy_1", 0.0),
			"inv_se0": inv.get("self_energy_0", 0.0), "inv_se1": inv.get("self_energy_1", 0.0),
			"own_flag": own.get("seated_inverted", false), "inv_flag": inv.get("seated_inverted", false),
			"rabi_same": is_equal_approx(float(own.get("rabi_coupling", 0.0)), float(inv.get("rabi_coupling", 0.0))),
			"couplings_same": JSON.stringify(own.get("hamiltonian_couplings", {})) == JSON.stringify(inv.get("hamiltonian_couplings", {}))})
	print("SEAT " + JSON.stringify(seats))

	var village: Array = []
	for p in INVERTED:
		var own_axes: Array = VILLAGE_BOOT.duplicate()
		own_axes.append([p[1], p[0]])
		var inv_axes: Array = VILLAGE_BOOT.duplicate()
		inv_axes.append([p[0], p[1]])
		var qo := _h(own_axes)
		var qi := _h(inv_axes)
		var n: int = qo.register_map.num_qubits
		var dim: int = qo.register_map.dim()
		var flip: int = 1  # the added word is the last qubit (lowest bit)
		var max_rel := 0.0
		var max_raw := 0.0
		for i in range(dim):
			for j in range(dim):
				var a = qi.hamiltonian.get_element(i, j)
				var b = qo.hamiltonian.get_element(i ^ flip, j ^ flip)
				var c = qo.hamiltonian.get_element(i, j)
				max_rel = maxf(max_rel, absf(a.re - b.re) + absf(a.im - b.im))
				max_raw = maxf(max_raw, absf(a.re - c.re) + absf(a.im - c.im))
		# PLANT both ways into a booted Village (ground state + dawn kick) through
		# the real expand lane: the inverted seat's ρ must be X_q ρ_own X_q, so
		# (with H_inv = X H_own X) it runs the own seat's trajectory relabelled.
		var rho_err := 0.0
		var ro := _planted(VILLAGE_BOOT, [p[1], p[0]])
		var ri := _planted(VILLAGE_BOOT, [p[0], p[1]])
		for i in range(dim):
			for j in range(dim):
				var x = ri.density_matrix.get_element(i, j)
				var y = ro.density_matrix.get_element(i ^ flip, j ^ flip)
				rho_err = maxf(rho_err, absf(x.re - y.re) + absf(x.im - y.im))
		village.append({"seat": "%s/%s" % [p[0], p[1]], "n": n,
			"gap_own": qo.get_hamiltonian_spectral_gap(), "gap_inv": qi.get_hamiltonian_spectral_gap(),
			"relabel_err": max_rel, "raw_diff": max_raw, "rho_relabel_err": rho_err,
			"kick_own": BiomeQuantumSystemBuilder.seat_kick_angle(p[1], p[0], 0.35, R),
			"kick_inv": BiomeQuantumSystemBuilder.seat_kick_angle(p[0], p[1], 0.35, R)})
	print("VILLAGE " + JSON.stringify(village))

	var Farm = load("res://Core/Farm.gd")
	var farm = Farm.new()
	farm.icon_atlas = R  # a bare Farm is outside the tree: hand it the registry
	farm.known_icons = [{"north": "🌾", "south": "👥"}, {"north": "🦅", "south": "🐇"}, {"north": "👥", "south": "🍞"}]
	var learn := {
		"predation_after_raptor": farm.discover_icon("🦅", "🩸"),   # north 🦅 is Raptor's pole
		"bread_after_labor": farm.discover_icon("🍞", "👥"),         # the other word of the pair
		"labor_again": farm.discover_icon("👥", "🍞"),
		"factory_inverted": farm.discover_icon("🏭", "⚙"),
		"factory_own_after_inverted": farm.discover_icon("⚙", "🏭"),  # same word, other spelling
		"subsistence_own_after_starter": farm.discover_icon("👥", "🌾"),
		"same_poles": farm.discover_icon("🌾", "🌾"),
	}
	learn["size"] = farm.known_icons.size()
	print("LEARN " + JSON.stringify(learn))
	farm.free()
	quit(0)
