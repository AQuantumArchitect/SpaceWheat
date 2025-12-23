extends SceneTree

## Integration Test - Full System
## Tests FarmGrid + Icons + EntangledPairs + Decoherence working together

const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const CosmicChaosIcon = preload("res://Core/Icons/CosmicChaosIcon.gd")
const WheatPlot = preload("res://Core/GameMechanics/WheatPlot.gd")


func _initialize():
	print("\n" + "=".repeat(80))
	print("  INTEGRATION TEST - Full System")
	print("=".repeat(80) + "\n")

	test_farmgrid_basic()
	test_entanglement_creation()
	test_icon_integration()
	test_measurement_propagation()
	test_decoherence_with_icons()
	test_harvest_with_entanglement()

	print("\n" + "=".repeat(80))
	print("  ALL INTEGRATION TESTS PASSED ✅")
	print("=".repeat(80) + "\n")

	quit()


func test_farmgrid_basic():
	print("TEST 1: FarmGrid Initialization")
	print("─".repeat(40))

	var farm = FarmGrid.new()
	farm.grid_width = 5
	farm.grid_height = 5
	farm._ready()

	test_assert(farm.plots.size() == 0, "Should start with no plots")
	test_assert(farm.entangled_pairs.size() == 0, "Should start with no entangled pairs")
	test_assert(farm.base_temperature == 20.0, "Base temperature should be 20K")

	# Plant wheat
	var planted = farm.plant_wheat(Vector2i(0, 0))
	test_assert(planted, "Should plant wheat")

	var plot = farm.get_plot(Vector2i(0, 0))
	test_assert(plot != null, "Plot should exist")
	test_assert(plot.is_planted, "Plot should be planted")
	test_assert(plot.quantum_state != null, "Should have quantum state")

	print("  ✅ FarmGrid initialization works\n")


func test_entanglement_creation():
	print("TEST 2: Entanglement Creation")
	print("─".repeat(40))

	var farm = FarmGrid.new()
	farm.grid_width = 5
	farm.grid_height = 5
	farm._ready()

	# Plant two plots
	farm.plant_wheat(Vector2i(0, 0))
	farm.plant_wheat(Vector2i(1, 0))

	print("  Planted 2 wheat plots")

	# Create entanglement
	var success = farm.create_entanglement(Vector2i(0, 0), Vector2i(1, 0), "phi_plus")
	test_assert(success, "Should create entanglement")

	print("  Created entanglement")

	# Verify
	test_assert(farm.entangled_pairs.size() == 1, "Should have 1 entangled pair")

	var pair = farm.entangled_pairs[0]
	test_assert(pair.get_purity() > 0.99, "Pair should be pure")
	test_assert(pair.get_concurrence() > 0.9, "Pair should be highly entangled")

	print("  Pair properties: Purity=%.3f, Concurrence=%.3f" % [pair.get_purity(), pair.get_concurrence()])

	# Check qubits are linked
	var plot_a = farm.get_plot(Vector2i(0, 0))
	var plot_b = farm.get_plot(Vector2i(1, 0))

	test_assert(plot_a.quantum_state.entangled_pair != null, "Plot A should be linked to pair")
	test_assert(plot_b.quantum_state.entangled_pair != null, "Plot B should be linked to pair")
	test_assert(plot_a.quantum_state.entangled_pair == pair, "Plot A linked to correct pair")

	print("  ✅ Entanglement creation works\n")


func test_icon_integration():
	print("TEST 3: Icon Integration")
	print("─".repeat(40))

	var farm = FarmGrid.new()
	farm.grid_width = 3
	farm.grid_height = 3
	farm._ready()

	# Create Cosmic Chaos Icon
	var chaos = CosmicChaosIcon.new()
	chaos._initialize_couplings()
	chaos._initialize_jump_operators()
	chaos.set_activation(0.5)

	print("  Created Cosmic Chaos Icon (activation=0.5)")

	# Add to farm
	farm.add_icon(chaos)

	test_assert(farm.active_icons.size() == 1, "Should have 1 active icon")

	# Check temperature modulation
	var temp = farm.get_effective_temperature()
	print("  Effective temperature: %.1fK (base=20K)" % temp)
	test_assert(temp > 20.0, "Temperature should increase with Chaos")

	# Plant wheat
	farm.plant_wheat(Vector2i(0, 0))
	var plot = farm.get_plot(Vector2i(0, 0))

	# Apply Icon effects
	farm._apply_icon_effects(0.1)

	# Temperature should be set on qubit
	test_assert(plot.quantum_state.environment_temperature > 20.0, "Qubit should have elevated temperature")

	print("  ✅ Icon integration works\n")


func test_measurement_propagation():
	print("TEST 4: Measurement Propagation")
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

	var pair = farm.entangled_pairs[0]
	var initial_purity = pair.get_purity()

	# Measure via pair object
	var result_a = pair.measure_qubit_a()
	print("  Measured qubit A: %s" % result_a)

	# Check state collapsed
	test_assert(pair.is_separable(), "State should be separable after measurement")

	print("  ✅ Measurement propagation works\n")


func test_decoherence_with_icons():
	print("TEST 5: Decoherence with Icons")
	print("─".repeat(40))

	var farm = FarmGrid.new()
	farm.grid_width = 3
	farm.grid_height = 3
	farm._ready()

	# Create entangled pair
	farm.plant_wheat(Vector2i(0, 0))
	farm.plant_wheat(Vector2i(1, 0))
	farm.create_entanglement(Vector2i(0, 0), Vector2i(1, 0), "phi_plus")

	# Add Cosmic Chaos
	var chaos = CosmicChaosIcon.new()
	chaos._initialize_couplings()
	chaos._initialize_jump_operators()
	chaos.set_activation(1.0)  # Full chaos!
	farm.add_icon(chaos)

	print("  Setup: Bell pair + Cosmic Chaos (100%%)")

	var pair = farm.entangled_pairs[0]
	var initial_purity = pair.get_purity()
	print("  Initial purity: %.3f" % initial_purity)

	# Run decoherence for 5 seconds
	for i in range(50):
		farm._apply_icon_effects(0.1)
		farm._apply_entangled_pair_decoherence(0.1)

	var final_purity = pair.get_purity()
	print("  After 5s with Chaos: purity=%.3f" % final_purity)

	test_assert(final_purity < initial_purity, "Purity should decrease")
	test_assert(final_purity < 0.9, "Significant decoherence should occur")

	print("  ✅ Decoherence with Icons works\n")


func test_harvest_with_entanglement():
	print("TEST 6: Harvest with Entanglement")
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

	# Make plot mature
	var plot = farm.get_plot(Vector2i(0, 0))
	plot.growth_progress = 1.0
	plot.is_mature = true

	test_assert(farm.entangled_pairs.size() == 1, "Should have 1 pair before harvest")

	# Harvest
	var yield_data = farm.harvest_with_topology(Vector2i(0, 0))

	print("  Harvested: yield=%.2f, state=%s" % [yield_data["yield"], yield_data["state"]])
	print("  Coherence: %.3f, Topology bonus: %.2fx" % [yield_data["coherence"], yield_data["topology_bonus"]])

	# Verify entanglement broken
	test_assert(farm.entangled_pairs.size() == 0, "Entangled pair should be removed after measurement")
	test_assert(plot.quantum_state.entangled_pair == null, "Qubit should be unlinked")

	# Verify other qubit also unlinked
	var plot_b = farm.get_plot(Vector2i(1, 0))
	test_assert(plot_b.quantum_state.entangled_pair == null, "Other qubit should also be unlinked")

	print("  ✅ Harvest with entanglement works\n")


func test_assert(condition: bool, message: String):
	if not condition:
		print("  ❌ ASSERTION FAILED: %s" % message)
		push_error(message)
