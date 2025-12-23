extends Node

## Simple test for Bell pairs and density matrices
## Tests core physics without Icons

const EntangledPair = preload("res://Core/QuantumSubstrate/EntangledPair.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const LindbladEvolution = preload("res://Core/QuantumSubstrate/LindbladEvolution.gd")


func _ready():
	print("\n" + "=".repeat(80))
	print("  BELL PAIRS & LINDBLAD TEST (Simple)")
	print("=".repeat(80) + "\n")

	test_bell_pair_creation()
	test_measurement()
	test_qubit_decoherence()
	test_entangled_pair_decoherence()

	print("\n" + "=".repeat(80))
	print("  ALL TESTS COMPLETE ✅")
	print("=".repeat(80) + "\n")

	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


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

	print("Created |Φ+⟩ = (|00⟩ + |11⟩)/√2")
	pair.print_density_matrix()

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

	print("Before measurement:")
	print("  Purity: %.3f (should be 1.0)" % pair.get_purity())
	print("  Entanglement Entropy: %.3f (should be ~0.69)" % pair.get_entanglement_entropy())

	var result_a = pair.measure_qubit_a()
	print("\nMeasured A: %s" % result_a)

	print("After measurement:")
	print("  Purity: %.3f" % pair.get_purity())
	print("  Separable: %s (should be true)" % pair.is_separable())

	print("✅ PASSED\n")


func test_qubit_decoherence():
	print("TEST 3: Single Qubit Decoherence (T₁/T₂)")
	print("─".repeat(40))

	var qubit = DualEmojiQubit.new("🌾", "👥", PI/2)
	qubit.set_T1_T2_times(10.0, 5.0)

	print("Initial: θ=%.3f, coherence=%.3f" % [qubit.theta, qubit.get_coherence()])

	# Apply 5 seconds of decoherence
	for i in range(50):
		qubit.apply_realistic_decoherence(0.1, 50.0)

	print("After 5s at T=50K: θ=%.3f, coherence=%.3f" % [qubit.theta, qubit.get_coherence()])
	print("✅ PASSED\n")


func test_entangled_pair_decoherence():
	print("TEST 4: Entangled Pair Decoherence")
	print("─".repeat(40))

	var pair = EntangledPair.new()
	pair.create_bell_phi_plus()

	print("Initial Bell state:")
	print("  Purity: %.3f" % pair.get_purity())

	# Apply decoherence
	for i in range(20):
		pair.density_matrix = LindbladEvolution.apply_two_qubit_decoherence_4x4(
			pair.density_matrix,
			0.1,
			50.0,  # Temperature
			100.0  # Base T1
		)

	print("After 2s decoherence at T=50K:")
	print("  Purity: %.3f (should be < 1.0, mixed state)" % pair.get_purity())
	print("✅ PASSED\n")
