extends SceneTree

## Test gate integration with biome and plots

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const BasePlot = preload("res://Core/GameMechanics/BasePlot.gd")

func _init():
	print("\n╔════════════════════════════════════════════════════════╗")
	print("║  GATE INTEGRATION TEST                               ║")
	print("╚════════════════════════════════════════════════════════╝\n")

	await test_single_qubit_gates_on_plot()
	await test_gate_preserves_physics()

	print("\n✅ ALL GATE INTEGRATION TESTS PASSED!\n")
	quit()

func test_single_qubit_gates_on_plot():
	print("📊 Test 1: Single-qubit gates on planted plot...")

	var biome = BioticFluxBiome.new()
	root.add_child(biome)
	await process_frame

	# Create and plant a plot
	var plot = BasePlot.new()
	plot.grid_position = Vector2i(0, 0)
	plot.plant(null, 0.0, biome)

	await process_frame

	assert(plot.is_planted, "Plot should be planted")
	assert(plot.quantum_state != null, "Plot should have quantum state")
	assert(plot.quantum_state.bath != null, "Quantum state should have bath reference")

	print("  ✓ Plot planted with quantum state")
	print("    North: %s, South: %s" % [plot.quantum_state.north_emoji, plot.quantum_state.south_emoji])

	# Get initial state
	var bath = plot.quantum_state.bath
	var north = plot.quantum_state.north_emoji
	var south = plot.quantum_state.south_emoji
	var initial_trace = bath.get_total_probability()
	var initial_purity = bath.get_purity()

	print("  ✓ Initial state:")
	print("    P(%s) = %.4f, P(%s) = %.4f" % [north, bath.get_probability(north), south, bath.get_probability(south)])
	print("    Purity = %.4f, Trace = %.6f" % [initial_purity, initial_trace])

	# Test Pauli-X gate
	var X = bath.get_standard_gate("X")
	assert(X != null, "X gate should exist")
	bath.apply_unitary_1q(north, south, X)

	print("  ✓ Applied Pauli-X gate")
	print("    P(%s) = %.4f, P(%s) = %.4f" % [north, bath.get_probability(north), south, bath.get_probability(south)])

	# Test Hadamard gate
	var H = bath.get_standard_gate("H")
	assert(H != null, "H gate should exist")
	bath.apply_unitary_1q(north, south, H)

	print("  ✓ Applied Hadamard gate")
	print("    P(%s) = %.4f, P(%s) = %.4f" % [north, bath.get_probability(north), south, bath.get_probability(south)])

	# Verify trace preserved
	var final_trace = bath.get_total_probability()
	assert(abs(final_trace - 1.0) < 0.01, "Trace should be preserved")
	print("    Trace = %.6f (preserved ✓)" % final_trace)

	print("  ✅ PASS\n")
	biome.queue_free()

func test_gate_preserves_physics():
	print("📊 Test 2: Gates preserve quantum physics...")

	var biome = BioticFluxBiome.new()
	root.add_child(biome)
	await process_frame

	# Plant two plots in the same biome
	var plot_a = BasePlot.new()
	plot_a.grid_position = Vector2i(0, 0)
	plot_a.plant(null, 0.0, biome)

	var plot_b = BasePlot.new()
	plot_b.grid_position = Vector2i(1, 0)
	plot_b.plant(null, 0.0, biome)

	await process_frame

	# Verify both share same bath
	assert(plot_a.quantum_state.bath == plot_b.quantum_state.bath,
		"Plots in same biome should share bath")

	var bath = plot_a.quantum_state.bath
	print("  ✓ Two plots planted in same biome (shared bath)")

	# Test 2-qubit gate (CNOT)
	var CNOT = bath.get_standard_gate("CNOT")
	assert(CNOT != null, "CNOT gate should exist")

	var n1 = plot_a.quantum_state.north_emoji
	var s1 = plot_a.quantum_state.south_emoji
	var n2 = plot_b.quantum_state.north_emoji
	var s2 = plot_b.quantum_state.south_emoji

	var initial_trace = bath.get_total_probability()
	var initial_purity = bath.get_purity()

	# Apply CNOT
	bath.apply_unitary_2q(n1, s1, n2, s2, CNOT)
	print("  ✓ Applied CNOT gate: (%s,%s) ⊗ (%s,%s)" % [n1, s1, n2, s2])

	# Verify physics preserved
	var final_trace = bath.get_total_probability()
	var final_purity = bath.get_purity()

	print("  ✓ Physics check:")
	print("    Trace: %.6f → %.6f (preserved)" % [initial_trace, final_trace])
	print("    Purity: %.4f → %.4f" % [initial_purity, final_purity])

	assert(abs(final_trace - 1.0) < 0.01, "Trace must be 1")

	# Test validation
	var validation = bath.validate()
	assert(validation.valid, "Bath should remain valid after gates")
	print("  ✓ Bath validation: PASS")
	print("    Hermitian: %s" % validation.hermitian)
	print("    Positive semidefinite: %s" % validation.positive_semidefinite)
	print("    Unit trace: %s" % validation.unit_trace)

	print("  ✅ PASS\n")
	biome.queue_free()
