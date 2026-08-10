extends "res://tests/smoke_test_base.gd"

## The fence ledger's wiring smoke: a realized biome carries a GaugeField over
## its coherent coupling graph, seeded from the signed Hamiltonian, rebuilt on
## physics-signature change with player bookkeeping carried by emoji.
## Run: godot --headless --script tests/gauge_wiring_probe.gd

const BiomeRegistryCls = preload("res://Core/Biomes/BiomeRegistry.gd")
const BiomeBuilderCls = preload("res://Core/Biomes/BiomeBuilder.gd")
const NeighborhoodGraphCls = preload("res://Core/QuantumSubstrate/NeighborhoodGraph.gd")

var _ran := false


func _process(_delta: float) -> bool:
	# First-frame guard: biome realization touches /root/* autoloads
	# (IconRegistry), live only once the scene tree is active.
	if _ran:
		return false
	_ran = true
	_run_test()
	return false


func _run_test() -> void:
	print("\n=== Gauge wiring probe ===")
	BiomeRegistryCls.reset_shared()
	var reg = BiomeRegistryCls.get_shared()

	var live = null
	for biome in reg.get_all():
		if biome == null or biome.get_neighborhood_icons().is_empty():
			continue
		var result = BiomeBuilderCls.build_from_spec(biome, null, {"skip_tree_add": true})
		if bool(result.get("success", false)):
			var candidate = result.get("biome_node", null)
			if candidate != null and candidate.quantum_computer != null:
				var qc0 = candidate.quantum_computer
				var g0 = qc0.get_gauge_field()
				# Prefer a biome whose gauge graph actually has edges.
				if g0 != null and g0.edge_count() > 0:
					live = candidate
					break
				if live == null:
					live = candidate
	_check(live != null, "realized a live biome")
	if live == null:
		_finish("gauge wiring probe")
		return

	var qc = live.quantum_computer
	var gf = qc.get_gauge_field()
	_check(gf != null, "quantum computer serves a gauge field")
	if gf == null:
		_finish("gauge wiring probe")
		return

	# --- Shape: nodes mirror registers; edges mirror the coherent graph only --
	_check(gf.node_count() == qc.register_map.num_qubits,
		"gauge nodes == register qubits (%d)" % qc.register_map.num_qubits)
	var ng = NeighborhoodGraphCls.coherent_from_register(qc.register_map)
	var coherent: int = 0
	for e in ng.edges:
		if str(e.get("kind", "")) == "coherent":
			coherent += 1
	_check(gf.edge_count() == coherent,
		"gauge edges == coherent couplings (%d); webway/sink excluded" % coherent)

	# --- Seed honesty: edge phases match arg(J) of the authored couplings ----
	var seeds_match := true
	for e in ng.edges:
		if str(e.get("kind", "")) != "coherent":
			continue
		var want: float = float(e.get("phase", 0.0))
		var got: float = gf.edge_phase(int(e["from_qubit"]), int(e["to_qubit"]))
		if absf(wrapf(got - want, -PI, PI)) > 1e-9:
			seeds_match = false
	_check(seeds_match, "every seed phase == arg(J) of its coupling")

	# --- Same-signature stability; player bookkeeping survives a rebuild -----
	_check(qc.get_gauge_field() == gf, "same signature -> same field instance")
	if gf.edge_count() > 0 and gf.node_count() > 0:
		var first_node = gf.nodes()[0]
		gf.gauge_flip(first_node)
		var frame_before: float = gf.node_frame(first_node)
		var carry: Dictionary = gf.carry_state()
		_check(not carry.get("edges", {}).is_empty(), "carry_state captures edge phases by emoji")
		var rebuilt = null
		var GaugeFieldCls = load("res://Core/QuantumSubstrate/GaugeField.gd")
		rebuilt = GaugeFieldCls.from_neighborhood(ng, carry)
		_check(absf(rebuilt.node_frame(first_node) - frame_before) < 1e-9,
			"node frame survives rebuild via emoji carry")
		var phases_survive := true
		for e in ng.edges:
			if str(e.get("kind", "")) != "coherent":
				continue
			var a: int = int(e["from_qubit"])
			var b: int = int(e["to_qubit"])
			if absf(wrapf(rebuilt.edge_phase(a, b) - gf.edge_phase(a, b), -PI, PI)) > 1e-9:
				phases_survive = false
		_check(phases_survive, "flipped edge phases survive rebuild via emoji carry")

		# --- Signature change triggers a fresh build --------------------------
		qc.physics_signature = qc.physics_signature + "|probe-poke"
		var gf2 = qc.get_gauge_field()
		_check(gf2 != gf, "signature change -> fresh field")
		_check(absf(gf2.node_frame(first_node) - frame_before) < 1e-9,
			"fresh field carries the player's frame forward")

	_finish("gauge wiring probe")
