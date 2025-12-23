extends SceneTree

## Test harness for density matrix system
## Extends SceneTree to run as standalone script

const EntangledPair = preload("res://Core/QuantumSubstrate/EntangledPair.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const LindbladEvolution = preload("res://Core/QuantumSubstrate/LindbladEvolution.gd")


func _initialize():
	print("\n" + "=".repeat(80))
	print("  DENSITY MATRIX & LINDBLAD SYSTEM TESTS")
	print("=".repeat(80) + "\n")

	test_bell_pair_creation()
	test_measurement()
	test_qubit_decoherence()
	test_entangled_pair_decoherence()
	test_density_matrix_conversion()

	print("\n" + "=".repeat(80))
	print("  ALL TESTS PASSED ✅")
	print("=".repeat(80) + "\n")

	quit()


func test_bell_pair_creation():
	print("TEST 1: Bell Pair Creation")
	print("─".repeat(40))

	var pair = EntangledPair.new()
	pair.qubit_a_id = "A"
	pair.qubit_b_id = "B"
	pair.north_emoji_a = "0"
	pair.south_emoji_a = "1"
	pair.north_emoji_b = "0"
	pair.south_emoji_b = "1"

	pair.create_bell_phi_plus()

	var purity = pair.get_purity()
	var entropy = pair.get_entanglement_entropy()
	var concurrence = pair.get_concurrence()

	print("Created |Φ+⟩ = (|00⟩ + |11⟩)/√2")
	print("  Purity: %.3f (expected: 1.000)" % purity)
	print("  Entropy: %.3f (expected: ~0.693)" % entropy)
	print("  Concurrence: %.3f (expected: 1.000)" % concurrence)

	assert(abs(purity - 1.0) < 0.01, "Purity check failed")
	assert(abs(entropy - 0.693) < 0.1, "Entropy check failed")

	print("✅ PASSED\n")


func test_measurement():
	print("TEST 2: Measurement Collapse")
	print("─".repeat(40))

	var pair = EntangledPair.new()
	pair.qubit_a_id = "A"
	pair.qubit_b_id = "B"
	pair.north_emoji_a = "0"
	pair.south_emoji_a = "1"
	pair.north_emoji_b = "0"
	pair.south_emoji_b = "1"

	pair.create_bell_phi_plus()

	print("Before measurement: Purity=%.3f" % pair.get_purity())

	var result_a = pair.measure_qubit_a()
	print("Measured A: %s" % result_a)

	var separable = pair.is_separable()
	print("After measurement: Separable=%s" % separable)

	assert(separable, "State should be separable after measurement")

	print("✅ PASSED\n")


func test_qubit_decoherence():
	print("TEST 3: Single Qubit Decoherence (T₁/T₂)")
	print("─".repeat(40))

	var qubit = DualEmojiQubit.new("🌾", "👥", PI/2)
	qubit.set_T1_T2_times(10.0, 5.0)

	var initial_coherence = qubit.get_coherence()
	print("Initial coherence: %.3f" % initial_coherence)

	# Apply 5 seconds of decoherence
	for i in range(50):
		qubit.apply_realistic_decoherence(0.1, 50.0)

	var final_coherence = qubit.get_coherence()
	print("After 5s at T=50K: coherence=%.3f" % final_coherence)

	assert(final_coherence < initial_coherence, "Coherence should decrease")

	print("✅ PASSED\n")


func test_entangled_pair_decoherence():
	print("TEST 4: Entangled Pair Decoherence")
	print("─".repeat(40))

	var pair = EntangledPair.new()
	pair.create_bell_phi_plus()

	var initial_purity = pair.get_purity()
	print("Initial purity: %.3f" % initial_purity)

	# Apply 2 seconds of decoherence
	for i in range(20):
		pair.density_matrix = LindbladEvolution.apply_two_qubit_decoherence_4x4(
			pair.density_matrix,
			0.1,
			50.0,
			100.0
		)

	var final_purity = pair.get_purity()
	print("After 2s at T=50K: purity=%.3f" % final_purity)

	assert(final_purity < initial_purity, "Purity should decrease (mixed state)")

	print("✅ PASSED\n")


func test_density_matrix_conversion():
	print("TEST 5: Bloch Sphere ↔ Density Matrix Conversion")
	print("─".repeat(40))

	var qubit = DualEmojiQubit.new("🌾", "👥", PI/2)
	qubit.phi = PI/4

	print("Original: θ=%.3f, φ=%.3f" % [qubit.theta, qubit.phi])

	# Convert to density matrix and back
	var rho = qubit.to_density_matrix()
	qubit.from_density_matrix(rho)

	print("After roundtrip: θ=%.3f, φ=%.3f" % [qubit.theta, qubit.phi])

	assert(abs(qubit.theta - PI/2) < 0.01, "Theta should be preserved")
	assert(abs(qubit.phi - PI/4) < 0.01, "Phi should be preserved")

	print("✅ PASSED\n")
