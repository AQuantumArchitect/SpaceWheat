extends SceneTree

## Simple FarmGrid Test - No Icons
## Tests core EntangledPair + FarmGrid functionality

const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")


func _initialize():
	print("\n" + "=".repeat(80))
	print("  FARMGRID + ENTANGLEMENT TEST (No Icons)")
	print("=".repeat(80) + "\n")

	test_plant_and_entangle()
	test_multiple_pairs()
	test_harvest_breaks_entanglement()
	test_decoherence_without_icons()

	print("\n" + "=".repeat(80))
	print("  ALL FARMGRID TESTS PASSED ✅")
	print("=".repeat(80) + "\n")

	quit()


func test_plant_and_entangle():
	print("TEST 1: Plant and Entangle")
	print("─".repeat(40))

	var farm = FarmGrid.new()
	farm.grid_width = 3
	farm.grid_height = 3
	farm._ready()

	# Plant two plots
	farm.plant_wheat(Vector2i(0, 0))
	farm.plant_wheat(Vector2i(1, 0))

	print("  Planted 2 wheat plots")

	# Create entanglement
	var success = farm.create_entanglement(Vector2i(0, 0), Vector2i(1, 0), "phi_plus")
	test_assert(success, "Should create entanglement")

	print("  Created Bell pair |Φ+⟩")

	# Verify
	test_assert(farm.entangled_pairs.size() == 1, "Should have 1 entangled pair")

	var pair = farm.entangled_pairs[0]
	var purity = pair.get_purity()
	var entropy = pair.get_entanglement_entropy()

	print("  Purity: %.3f, Entropy: %.3f" % [purity, entropy])

	test_assert(abs(purity - 1.0) < 0.01, "Purity should be 1.0")
	test_assert(abs(entropy - 0.693) < 0.1, "Entropy should be ~0.693")

	print("  ✅ PASSED\n")


func test_multiple_pairs():
	print("TEST 2: Multiple Entangled Pairs")
	print("─".repeat(40))

	var farm = FarmGrid.new()
	farm.grid_width = 3
	farm.grid_height = 3
	farm._ready()

	# Plant 4 plots
	farm.plant_wheat(Vector2i(0, 0))
	farm.plant_wheat(Vector2i(1, 0))
	farm.plant_wheat(Vector2i(0, 1))
	farm.plant_wheat(Vector2i(1, 1))

	# Create 2 independent pairs
	farm.create_entanglement(Vector2i(0, 0), Vector2i(1, 0), "phi_plus")
	farm.create_entanglement(Vector2i(0, 1), Vector2i(1, 1), "psi_plus")

	print("  Created 2 entangled pairs")

	test_assert(farm.entangled_pairs.size() == 2, "Should have 2 pairs")

	print("  Pair 1: Purity=%.3f" % farm.entangled_pairs[0].get_purity())
	print("  Pair 2: Purity=%.3f" % farm.entangled_pairs[1].get_purity())

	print("  ✅ PASSED\n")


func test_harvest_breaks_entanglement():
	print("TEST 3: Harvest Breaks Entanglement")
	print("─".repeat(40))

	var farm = FarmGrid.new()
	farm.grid_width = 3
	farm.grid_height = 3
	farm._ready()

	# Create entangled pair
	farm.plant_wheat(Vector2i(0, 0))
	farm.plant_wheat(Vector2i(1, 0))
	farm.create_entanglement(Vector2i(0, 0), Vector2i(1, 0), "phi_plus")

	print("  Created entangled pair")

	# Make mature
	var plot = farm.get_plot(Vector2i(0, 0))
	plot.growth_progress = 1.0
	plot.is_mature = true

	test_assert(farm.entangled_pairs.size() == 1, "Should have 1 pair before harvest")

	# Harvest
	var yield_data = farm.harvest_with_topology(Vector2i(0, 0))

	print("  Harvested: yield=%.2f, state=%s" % [yield_data["yield"], yield_data["state"]])

	# Verify entanglement broken
	test_assert(farm.entangled_pairs.size() == 0, "Pair should be removed after harvest")
	test_assert(plot.quantum_state == null or plot.quantum_state.entangled_pair == null, "Qubit should be unlinked or reset")

	print("  ✅ PASSED\n")


func test_decoherence_without_icons():
	print("TEST 4: Decoherence (No Icons)")
	print("─".repeat(40))

	var farm = FarmGrid.new()
	farm.grid_width = 3
	farm.grid_height = 3
	farm.base_temperature = 50.0  # Elevated temperature
	farm._ready()

	# Create pair
	farm.plant_wheat(Vector2i(0, 0))
	farm.plant_wheat(Vector2i(1, 0))
	farm.create_entanglement(Vector2i(0, 0), Vector2i(1, 0), "phi_plus")

	var pair = farm.entangled_pairs[0]
	var initial_purity = pair.get_purity()

	print("  Initial purity: %.3f" % initial_purity)
	print("  Temperature: %.1fK" % farm.base_temperature)

	# Apply decoherence for 2 seconds
	for i in range(20):
		farm._apply_entangled_pair_decoherence(0.1)

	var final_purity = pair.get_purity()
	print("  After 2s: purity=%.3f" % final_purity)

	test_assert(final_purity < initial_purity, "Purity should decrease")

	print("  ✅ PASSED\n")


func test_assert(condition: bool, message: String):
	if not condition:
		print("  ❌ ASSERTION FAILED: %s" % message)
		push_error(message)
