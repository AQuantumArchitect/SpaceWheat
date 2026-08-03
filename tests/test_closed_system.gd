extends "res://tests/smoke_test_base.gd"

## Closed-System Gate Verification Test
##
## Verifies the single-switch discipline documented in docs/CLOSED_SYSTEM.md:
##   1. Closed (default): LindbladBuilder builds ZERO operators; the biome's
##      quantum computer carries none.
##   2. Open (dissipative_dynamics=true): the SAME atom_components data
##      rebuilds real Lindblad operators — dormant content, not deleted content.
##   3. Closed evolution is purity-exact: r = Tr(ρ²) = 1 holds under the exact
##      unitary kernel (no Euler drift, no renormalize-as-crutch).
##   4. Measurement is the only irreversible act — and it maps pure → pure.
##
## Run: godot --headless --script tests/test_closed_system.gd

var biome = null

const DIVIDER = "============================================================"
const EPSILON = 1e-6


func _init():
	print("\n" + DIVIDER)
	print("CLOSED-SYSTEM GATE VERIFICATION TEST")
	print("Testing: dissipative switch, purity conservation, projective collapse")
	print(DIVIDER)

	await self.process_frame

	if await setup_test_environment():
		test_closed_builds_no_lindblad_operators()
		test_open_rebuilds_operators_from_same_data()
		test_closed_evolution_conserves_purity()
		test_measurement_maps_pure_to_pure()
	else:
		print("\n[ERROR] Failed to setup test environment")
		failed += 1

	_finish("RESULTS")


func setup_test_environment() -> bool:
	print("\n[Setup: Real Biome + Quantum Computer, closed defaults]")

	# Make sure no stale override leaks in from another context.
	BalanceConfig.clear_physics_override()
	if not BalanceConfig.is_closed_system():
		print("  ✗ Expected closed system by DEFAULT (coherent on, dissipative off)")
		return false
	print("  ✓ Default physics mode is closed (coherent on, dissipative off)")

	var BiomeBuilderScript = load("res://Core/Biomes/BiomeBuilder.gd")
	var result = BiomeBuilderScript.build_from_registry("StarterForest", root, {"skip_tree_add": true})
	if not result.success:
		print("  ✗ Failed to build biome: %s" % result.error)
		return false
	biome = result.biome_node
	biome.name = "ClosedSystemTestBiome"
	root.add_child(biome)

	await self.process_frame

	if not biome.quantum_computer or not biome.quantum_computer.density_matrix:
		print("  ✗ Failed to create quantum computer")
		return false

	print("  ✓ Quantum computer ready: %d qubits" % biome.quantum_computer.register_map.num_qubits)
	return true


func test_closed_builds_no_lindblad_operators():
	# CLOSED_SYSTEM.md: "closed → 0 operators". The gate is LindbladBuilder.build_from_atoms.
	print("\n[Closed mode: zero Lindblad operators]")

	var qc = biome.quantum_computer
	assert_true(qc.lindblad_operators.is_empty(),
		"quantum_computer.lindblad_operators is empty in closed mode")

	var atom_components := _get_atom_components("StarterForest")
	assert_true(not atom_components.is_empty(),
		"StarterForest atom_components exist in data (dormant, not deleted)")

	var LindbladBuilderScript = load("res://Core/QuantumSubstrate/LindbladBuilder.gd")
	var built = LindbladBuilderScript.build_from_atoms(atom_components, qc.register_map)
	var ops: Array = built.get("operators", [])
	assert_true(ops.is_empty(),
		"LindbladBuilder returns 0 operators while dissipative_dynamics is off (got %d)" % ops.size())


func test_open_rebuilds_operators_from_same_data():
	# Flip the one switch: the SAME data must rebuild real operators.
	print("\n[Open mode: operators rebuild from the same atom_components]")

	var qc = biome.quantum_computer
	var atom_components := _get_atom_components("StarterForest")

	BalanceConfig.set_physics_override({"dissipative_dynamics": true})
	assert_true(not BalanceConfig.is_closed_system(), "override flips is_closed_system() to false")

	var LindbladBuilderScript = load("res://Core/QuantumSubstrate/LindbladBuilder.gd")
	var built = LindbladBuilderScript.build_from_atoms(atom_components, qc.register_map)
	var ops: Array = built.get("operators", [])
	assert_true(ops.size() > 0,
		"LindbladBuilder builds operators when dissipative_dynamics is on (got %d)" % ops.size())

	# Every built operator must match the register dimension (shape sanity).
	var dim: int = qc.register_map.dim()
	var shapes_ok := true
	for L in ops:
		if L == null or int(L.n) != dim:
			shapes_ok = false
			break
	assert_true(shapes_ok, "all built operators are %d×%d" % [dim, dim])

	BalanceConfig.clear_physics_override()
	assert_true(BalanceConfig.is_closed_system(), "override cleared — back to closed")


func test_closed_evolution_conserves_purity():
	# The exact unitary kernel: ρ → UρU†, U = exp(−iH·dt). Purity is conserved
	# by theorem — this test checks the implementation didn't betray the theorem.
	print("\n[Closed evolution: Tr(ρ²) = 1 held under the exact kernel]")

	var qc = biome.quantum_computer
	var p0: float = qc.get_purity()
	assert_approx(p0, 1.0, "initial purity = 1 (pure ground-state init)")

	if qc.hamiltonian == null:
		print("  ✗ No Hamiltonian on the test biome — cannot exercise the unitary kernel")
		failed += 1
		return

	# Several macro-steps through the public evolve() path (the closed fast path).
	for i in range(10):
		qc.evolve(0.1, 0.02)

	var p1: float = qc.get_purity()
	assert_approx(p1, 1.0, "purity after 10 × evolve(0.1) = 1 (no integrator drift)")

	var trace: float = qc.get_trace()
	assert_approx(trace, 1.0, "Tr(ρ) after evolution = 1")


func test_measurement_maps_pure_to_pure():
	# Projective collapse of a pure state is pure: P|ψ⟩⟨ψ|P / p is rank-1.
	print("\n[Measurement: projective collapse keeps r = 1]")

	var qc = biome.quantum_computer
	var pair: Dictionary = qc.get_emoji_pair_for_qubit(0)
	var north := str(pair.get("north", ""))
	var south := str(pair.get("south", ""))
	if north == "" or south == "":
		print("  ✗ Qubit 0 has no emoji axis — cannot measure")
		failed += 1
		return

	var outcome: String = qc.measure_axis(north, south)
	assert_true(outcome == north or outcome == south,
		"measure_axis(%s/%s) returned an outcome (%s)" % [north, south, outcome])

	assert_approx(qc.get_purity(), 1.0, "purity after projective collapse = 1")
	assert_approx(qc.get_trace(), 1.0, "trace after projective collapse = 1")

	# The collapsed qubit is pinned at the measured pole.
	var measured_pole := 0 if outcome == north else 1
	var p_outcome: float = qc.get_marginal(0, measured_pole)
	assert_approx(p_outcome, 1.0, "measured pole population = 1 after collapse")


# =============================================================================
# HELPERS
# =============================================================================

func _get_atom_components(biome_name: String) -> Dictionary:
	# Prefer the live biome node; fall back to the registry definition.
	if biome != null and ("atom_components" in biome):
		var ac = biome.atom_components
		if ac is Dictionary and not ac.is_empty():
			return ac
	var breg = load("res://Core/Biomes/BiomeRegistry.gd").get_shared()
	var bdef = breg.get_by_name(biome_name)
	if bdef != null and ("atom_components" in bdef):
		return bdef.atom_components
	return {}


func assert_true(condition: bool, message: String) -> void:
	if condition:
		print("  ✓ %s" % message)
		passed += 1
	else:
		print("  ✗ %s" % message)
		failed += 1


func assert_approx(actual: float, expected: float, message: String) -> void:
	if abs(actual - expected) < EPSILON:
		print("  ✓ %s (%.9f)" % [message, actual])
		passed += 1
	else:
		print("  ✗ %s — expected %.9f, got %.9f" % [message, expected, actual])
		failed += 1
