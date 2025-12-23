extends SceneTree

## Test Measurement Cascade
## Verify that measuring one qubit collapses its entangled partner

const EntangledPair = preload("res://Core/QuantumSubstrate/EntangledPair.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")


func _initialize():
	print("\n" + "=".repeat(80))
	print("  MEASUREMENT CASCADE TEST")
	print("=".repeat(80) + "\n")

	test_pair_measurement()
	test_farmgrid_cascade()
	test_measurement_network()

	print("\n" + "=".repeat(80))
	print("  MEASUREMENT CASCADE TESTS COMPLETE")
	print("=".repeat(80) + "\n")

	quit()


func test_pair_measurement():
	print("TEST 1: EntangledPair Measurement Collapse")
	print("─".repeat(40))

	var pair = EntangledPair.new()
	pair.qubit_a_id = "A"
	pair.qubit_b_id = "B"
	pair.north_emoji_a = "0"
	pair.south_emoji_a = "1"
	pair.north_emoji_b = "0"
	pair.south_emoji_b = "1"

	pair.create_bell_phi_plus()

	print("  Created |Φ+⟩ = (|00⟩ + |11⟩)/√2")
	print("  Before measurement:")
	print("    Purity: %.3f" % pair.get_purity())
	print("    Separable: %s" % pair.is_separable())

	# Measure qubit A
	var result_a = pair.measure_qubit_a()
	print("\n  Measured A: %s" % result_a)

	print("  After measurement:")
	print("    Purity: %.3f" % pair.get_purity())
	print("    Separable: %s" % pair.is_separable())

	# Now measure B - should be correlated!
	var result_b = pair.measure_qubit_b()
	print("  Measured B: %s" % result_b)

	if result_a == result_b:
		print("  ✅ CORRELATED (both %s) - Expected for |Φ+⟩\n" % result_a)
	else:
		print("  ❌ NOT CORRELATED (%s vs %s) - ERROR!\n" % [result_a, result_b])


func test_farmgrid_cascade():
	print("TEST 2: FarmGrid Measurement Cascade")
	print("─".repeat(40))

	var farm = FarmGrid.new()
	farm.grid_width = 3
	farm.grid_height = 3
	farm._ready()

	# Create entangled pair
	farm.plant_wheat(Vector2i(0, 0))
	farm.plant_wheat(Vector2i(1, 0))
	farm.create_entanglement(Vector2i(0, 0), Vector2i(1, 0), "phi_plus")

	var plot_a = farm.get_plot(Vector2i(0, 0))
	var plot_b = farm.get_plot(Vector2i(1, 0))

	print("  Created entangled pair")
	print("  Plot A state: %s" % plot_a.quantum_state.get_semantic_state())
	print("  Plot B state: %s" % plot_b.quantum_state.get_semantic_state())
	print("  (Both should be in superposition)")

	# Measure plot A via measure_plot
	var result = farm.measure_plot(Vector2i(0, 0))
	print("\n  Measured plot A: %s" % result)

	# Check if plot B state changed
	print("  Plot A state after: %s" % plot_a.quantum_state.get_semantic_state())
	print("  Plot B state after: %s" % plot_b.quantum_state.get_semantic_state())

	# Check if both collapsed
	var a_collapsed = plot_a.quantum_state.theta < 0.3 or plot_a.quantum_state.theta > 2.8
	var b_collapsed = plot_b.quantum_state.theta < 0.3 or plot_b.quantum_state.theta > 2.8

	print("\n  Plot A collapsed: %s (θ=%.2f)" % [a_collapsed, plot_a.quantum_state.theta])
	print("  Plot B collapsed: %s (θ=%.2f)" % [b_collapsed, plot_b.quantum_state.theta])

	if a_collapsed and b_collapsed:
		print("  ✅ BOTH COLLAPSED - Cascade working!\n")
	elif a_collapsed:
		print("  ⚠️ Only A collapsed - Cascade NOT working!\n")
	else:
		print("  ❌ Neither collapsed - ERROR!\n")


func test_measurement_network():
	print("TEST 3: Measurement Network (Chain)")
	print("─".repeat(40))

	var farm = FarmGrid.new()
	farm.grid_width = 5
	farm.grid_height = 1
	farm._ready()

	# Create chain: A-B, B-C (B is entangled with both)
	farm.plant_wheat(Vector2i(0, 0))  # A
	farm.plant_wheat(Vector2i(1, 0))  # B
	farm.plant_wheat(Vector2i(2, 0))  # C

	# Note: Can't create A-B and B-C with current system
	# because B can only be in one EntangledPair at a time
	farm.create_entanglement(Vector2i(0, 0), Vector2i(1, 0), "phi_plus")

	print("  Created A-B entanglement")

	# Try to create B-C
	var success = farm.create_entanglement(Vector2i(1, 0), Vector2i(2, 0), "phi_plus")

	if success:
		print("  Created B-C entanglement")
		print("  ⚠️ Warning: B is now in TWO pairs - this is wrong!")
	else:
		print("  ❌ Cannot create B-C (B already entangled)")
		print("  ℹ️ Current system: each qubit can only be in ONE pair")

	print("\n  Current entangled pairs: %d" % farm.entangled_pairs.size())
	print("  ℹ️ Network entanglement requires different approach\n")


func test_assert(condition: bool, message: String):
	if not condition:
		print("  ❌ ASSERTION FAILED: %s" % message)
		push_error(message)
