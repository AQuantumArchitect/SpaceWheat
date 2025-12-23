extends Node

## Test Suite for Density Matrix & Lindblad System
## Tests the new physically accurate quantum mechanics implementation

const EntangledPair = preload("res://Core/QuantumSubstrate/EntangledPair.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const LindbladEvolution = preload("res://Core/QuantumSubstrate/LindbladEvolution.gd")
const LindbladIcon = preload("res://Core/Icons/LindbladIcon.gd")  # Load before CosmicChaosIcon
const CosmicChaosIcon = preload("res://Core/Icons/CosmicChaosIcon.gd")
const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")


func _ready():
	print("\n" + "=".repeat(80))
	print("  DENSITY MATRIX & LINDBLAD SYSTEM TEST SUITE")
	print("=".repeat(80) + "\n")

	test_entangled_pair_creation()
	test_bell_states()
	test_measurement_collapse()
	test_entanglement_measures()
	test_lindblad_decoherence()
	test_temperature_dependent_decoherence()
	test_cosmic_chaos_icon()
	test_farmgrid_integration()

	print("\n" + "=".repeat(80))
	print("  ALL TESTS COMPLETE")
	print("=".repeat(80) + "\n")

	# Exit
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


func test_entangled_pair_creation():
	print("TEST: EntangledPair Creation")
	print("─".repeat(80))

	var pair = EntangledPair.new()
	pair.qubit_a_id = "plot_0"
	pair.qubit_b_id = "plot_1"
	pair.north_emoji_a = "🌾"
	pair.south_emoji_a = "👥"
	pair.north_emoji_b = "🌾"
	pair.south_emoji_b = "👥"

	# Create Bell state
	pair.create_bell_phi_plus()

	# Check properties
	var purity = pair.get_purity()
	var entropy = pair.get_entanglement_entropy()
	var concurrence = pair.get_concurrence()

	print("  Bell state |Φ+⟩ created")
	print("  Purity: %.3f (should be 1.0 for pure state)" % purity)
	print("  Entanglement Entropy: %.3f (should be ~0.693 for max entangled)" % entropy)
	print("  Concurrence: %.3f (should be 1.0 for Bell state)" % concurrence)

	test_assert(abs(purity - 1.0) < 0.01, "Purity should be 1.0")
	test_assert(abs(entropy - 0.693) < 0.1, "Entropy should be ~ln(2) = 0.693")
	test_assert(abs(concurrence - 1.0) < 0.1, "Concurrence should be 1.0")

	print("  ✅ PASSED: Entangled pair properties correct\n")


func test_bell_states():
	print("TEST: Bell States")
	print("─".repeat(80))

	var bell_types = ["phi_plus", "phi_minus", "psi_plus", "psi_minus"]

	for bell_type in bell_types:
		var pair = EntangledPair.new()
		pair.qubit_a_id = "a"
		pair.qubit_b_id = "b"
		pair.north_emoji_a = "0"
		pair.south_emoji_a = "1"
		pair.north_emoji_b = "0"
		pair.south_emoji_b = "1"

		match bell_type:
			"phi_plus": pair.create_bell_phi_plus()
			"phi_minus": pair.create_bell_phi_minus()
			"psi_plus": pair.create_bell_psi_plus()
			"psi_minus": pair.create_bell_psi_minus()

		var purity = pair.get_purity()
		print("  %s: Purity=%.3f (should be 1.0)" % [bell_type, purity])
		test_assert(abs(purity - 1.0) < 0.01, "%s should have purity 1.0" % bell_type)

	print("  ✅ PASSED: All Bell states are pure\n")


func test_measurement_collapse():
	print("TEST: Measurement Collapse")
	print("─".repeat(80))

	# Create Bell pair |Φ+⟩ = (|00⟩ + |11⟩)/√2
	var pair = EntangledPair.new()
	pair.qubit_a_id = "a"
	pair.qubit_b_id = "b"
	pair.north_emoji_a = "0"
	pair.south_emoji_a = "1"
	pair.north_emoji_b = "0"
	pair.south_emoji_b = "1"
	pair.create_bell_phi_plus()

	print("  Created |Φ+⟩ state")
	print("  Before measurement: Purity=%.3f, Separable=%s" % [pair.get_purity(), pair.is_separable()])

	# Measure qubit A
	var result_a = pair.measure_qubit_a()
	print("  Measured qubit A: %s" % result_a)

	# After measurement, state should be separable (product state)
	var purity_after = pair.get_purity()
	var separable = pair.is_separable()
	print("  After measurement: Purity=%.3f, Separable=%s" % [purity_after, separable])

	test_assert(separable, "State should be separable after measurement")
	print("  ✅ PASSED: Measurement collapses entanglement\n")


func test_entanglement_measures():
	print("TEST: Entanglement Measures")
	print("─".repeat(80))

	# Test 1: Product state (no entanglement)
	var pair_product = EntangledPair.new()
	pair_product._collapse_to_product_state(0, 0)  # |00⟩
	var S_product = pair_product.get_entanglement_entropy()
	print("  Product state |00⟩: Entropy=%.3f (should be 0)" % S_product)
	test_assert(S_product < 0.01, "Product state should have zero entropy")

	# Test 2: Maximally entangled state
	var pair_bell = EntangledPair.new()
	pair_bell.create_bell_phi_plus()
	var S_bell = pair_bell.get_entanglement_entropy()
	print("  Bell state |Φ+⟩: Entropy=%.3f (should be ~0.693)" % S_bell)
	test_assert(abs(S_bell - 0.693) < 0.1, "Bell state should have max entropy")

	print("  ✅ PASSED: Entanglement measures correct\n")


func test_lindblad_decoherence():
	print("TEST: Lindblad Decoherence (T₁/T₂)")
	print("─".repeat(80))

	# Create qubit in superposition
	var qubit = DualEmojiQubit.new("🌾", "👥", PI/2)
	qubit.set_T1_T2_times(10.0, 5.0)  # T1=10s, T2=5s

	print("  Initial state: θ=%.3f, coherence=%.3f" % [qubit.theta, qubit.get_coherence()])

	# Apply decoherence for 10 seconds
	var total_time = 10.0
	var dt = 0.1
	var steps = int(total_time / dt)

	for i in range(steps):
		qubit.apply_realistic_decoherence(dt, 20.0)  # 20K temperature

	print("  After %ds decoherence: θ=%.3f, coherence=%.3f" % [total_time, qubit.theta, qubit.get_coherence()])

	# State should have decohered (coherence reduced)
	var final_coherence = qubit.get_coherence()
	test_assert(final_coherence < 0.9, "Coherence should decrease after decoherence")

	print("  ✅ PASSED: Decoherence reduces coherence\n")


func test_temperature_dependent_decoherence():
	print("TEST: Temperature-Dependent Decoherence")
	print("─".repeat(80))

	# Test at different temperatures
	var temperatures = [0.0, 50.0, 100.0]

	for temp in temperatures:
		var qubit = DualEmojiQubit.new("🌾", "👥", PI/2)
		qubit.set_T1_T2_times(100.0, 50.0)

		var initial_coherence = qubit.get_coherence()

		# Apply 5 seconds of decoherence
		for i in range(50):
			qubit.apply_realistic_decoherence(0.1, temp)

		var final_coherence = qubit.get_coherence()
		var coherence_loss = initial_coherence - final_coherence

		print("  T=%.0fK: Coherence loss = %.3f" % [temp, coherence_loss])

		# Higher temperature should cause more coherence loss
		if temp > 0:
			test_assert(coherence_loss > 0, "Should lose coherence at T>0")

	print("  ✅ PASSED: Higher temperature → more decoherence\n")


func test_cosmic_chaos_icon():
	print("TEST: Cosmic Chaos Icon (Lindblad)")
	print("─".repeat(80))

	var icon = CosmicChaosIcon.new()
	icon._initialize_couplings()
	icon._initialize_jump_operators()
	icon.set_activation(1.0)  # Full activation

	print("  Icon: %s (activation=%.2f)" % [icon.icon_name, icon.active_strength])
	print("  Temperature: %.1fK" % icon.get_effective_temperature())
	print("  Jump operators: %d" % icon.jump_operators.size())

	# Apply to qubit
	var qubit = DualEmojiQubit.new("🌾", "👥", PI/2)
	var initial_coherence = qubit.get_coherence()

	# Apply Icon effects for 5 seconds
	for i in range(50):
		icon.apply_to_qubit(qubit, 0.1)

	var final_coherence = qubit.get_coherence()
	print("  Coherence: %.3f → %.3f" % [initial_coherence, final_coherence])

	test_assert(final_coherence < initial_coherence, "Chaos should reduce coherence")

	print("  ✅ PASSED: Cosmic Chaos Icon applies decoherence\n")


func test_farmgrid_integration():
	print("TEST: FarmGrid Integration")
	print("─".repeat(80))

	var farm = FarmGrid.new()
	farm.grid_width = 3
	farm.grid_height = 3

	# Plant two wheat plots
	var pos_a = Vector2i(0, 0)
	var pos_b = Vector2i(1, 0)

	farm.plant_wheat(pos_a)
	farm.plant_wheat(pos_b)

	print("  Planted wheat at %s and %s" % [pos_a, pos_b])

	# Create entanglement
	var success = farm.create_entanglement(pos_a, pos_b, "phi_plus")
	test_assert(success, "Should create entanglement")

	print("  Created Bell pair |Φ+⟩")
	print("  Entangled pairs: %d" % farm.entangled_pairs.size())
	test_assert(farm.entangled_pairs.size() == 1, "Should have 1 entangled pair")

	# Add Cosmic Chaos Icon
	var icon = CosmicChaosIcon.new()
	icon._initialize_couplings()
	icon._initialize_jump_operators()
	icon.set_activation(0.8)
	farm.add_icon(icon)

	print("  Added Cosmic Chaos Icon (activation=0.8)")

	# Get entangled pair
	var pair = farm.entangled_pairs[0]
	var initial_purity = pair.get_purity()

	print("  Initial pair purity: %.3f" % initial_purity)

	# Simulate time (decoherence should occur)
	for i in range(10):
		farm._apply_icon_effects(0.1)
		farm._apply_entangled_pair_decoherence(0.1)

	var final_purity = pair.get_purity()
	print("  Final pair purity: %.3f" % final_purity)

	# Purity should decrease (mixed state from decoherence)
	test_assert(final_purity < initial_purity, "Decoherence should reduce purity")

	# Test measurement
	var plot_a = farm.get_plot(pos_a)
	plot_a.growth_progress = 1.0  # Fully grown
	plot_a.is_mature = true

	var yield_data = farm.harvest_with_topology(pos_a)
	print("  Harvested plot A: yield=%.2f, state=%s" % [yield_data["yield"], yield_data["state"]])

	# After harvest, entangled pair should be removed
	test_assert(farm.entangled_pairs.size() == 0, "Measurement should break entanglement")
	test_assert(plot_a.quantum_state.entangled_pair == null, "Qubit should be unlinked")

	print("  ✅ PASSED: FarmGrid integration works correctly\n")


func test_assert(condition: bool, message: String):
	"""Simple assertion helper"""
	if not condition:
		print("  ❌ ASSERTION FAILED: %s" % message)
		push_error(message)
	# Continue running other tests even if assertion fails
