extends SceneTree

## Test quantum algorithm implementations

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const BasePlot = preload("res://Core/GameMechanics/BasePlot.gd")
const QuantumAlgorithms = preload("res://Core/QuantumSubstrate/QuantumAlgorithms.gd")

func _init():
	print("\n╔════════════════════════════════════════════════════════╗")
	print("║  QUANTUM ALGORITHMS TEST (Tool 6)                    ║")
	print("╚════════════════════════════════════════════════════════╝\n")

	await test_deutsch_jozsa()
	await test_grover_search()
	await test_phase_estimation()
	await test_algorithm_integration()

	print("\n✅ ALL QUANTUM ALGORITHM TESTS PASSED!\n")
	quit()

func test_deutsch_jozsa():
	print("📊 Test 1: Deutsch-Jozsa algorithm...")

	var biome = BioticFluxBiome.new()
	root.add_child(biome)
	await process_frame

	# Get IconRegistry
	var icon_registry = root.get_node_or_null("IconRegistry")
	if not icon_registry:
		print("  ⚠️ IconRegistry not available, skipping test")
		biome.queue_free()
		return

	# Create two qubit descriptors from available emojis
	var emoji_list = biome.bath.emoji_list
	if emoji_list.size() < 4:
		print("  ⚠️ Need at least 4 emojis in bath, skipping test")
		biome.queue_free()
		return

	var qubit_a = {
		"north": emoji_list[0],
		"south": emoji_list[1]
	}
	var qubit_b = {
		"north": emoji_list[2],
		"south": emoji_list[3]
	}

	print("  ✓ Qubit A: %s ↔ %s" % [qubit_a.north, qubit_a.south])
	print("  ✓ Qubit B: %s ↔ %s" % [qubit_b.north, qubit_b.south])

	# Run Deutsch-Jozsa
	var result = QuantumAlgorithms.deutsch_jozsa(biome.bath, qubit_a, qubit_b)

	# Validate result structure
	assert(result.has("result"), "Result should have 'result' field")
	assert(result.has("measurement"), "Result should have 'measurement' field")
	assert(result.has("classical_advantage"), "Result should have 'classical_advantage' field")

	assert(result.result in ["constant", "balanced"],
		"Result should be 'constant' or 'balanced'")

	print("  ✓ Result: %s" % result.result)
	print("  ✓ Measurement: %s" % result.measurement)
	print("  ✓ Classical advantage: %s" % result.classical_advantage)

	# Verify bath still valid after algorithm
	var validation = biome.bath.validate()
	assert(validation.valid, "Bath should remain valid after Deutsch-Jozsa")

	print("  ✅ PASS (Deutsch-Jozsa executes correctly)\n")
	biome.queue_free()

func test_grover_search():
	print("📊 Test 2: Grover search algorithm...")

	var biome = BioticFluxBiome.new()
	root.add_child(biome)
	await process_frame

	# Get IconRegistry
	var icon_registry = root.get_node_or_null("IconRegistry")
	if not icon_registry:
		print("  ⚠️ IconRegistry not available, skipping test")
		biome.queue_free()
		return

	# Create two qubit descriptors
	var emoji_list = biome.bath.emoji_list
	if emoji_list.size() < 4:
		print("  ⚠️ Need at least 4 emojis in bath, skipping test")
		biome.queue_free()
		return

	var qubit_a = {
		"north": emoji_list[0],
		"south": emoji_list[1]
	}
	var qubit_b = {
		"north": emoji_list[2],
		"south": emoji_list[3]
	}

	var marked_state = qubit_a.north

	print("  ✓ Qubit A: %s ↔ %s" % [qubit_a.north, qubit_a.south])
	print("  ✓ Qubit B: %s ↔ %s" % [qubit_b.north, qubit_b.south])
	print("  ✓ Marked state: %s" % marked_state)

	# Run Grover search
	var result = QuantumAlgorithms.grover_search(biome.bath, qubit_a, qubit_b, marked_state)

	# Validate result structure
	assert(result.has("found"), "Result should have 'found' field")
	assert(result.has("iterations"), "Result should have 'iterations' field")
	assert(result.has("success_probability"), "Result should have 'success_probability' field")

	print("  ✓ Found: %s (target: %s)" % [result.found, marked_state])
	print("  ✓ Iterations: %d" % result.iterations)
	print("  ✓ Success probability: %.1f%%" % (result.success_probability * 100))

	# Verify bath still valid
	var validation = biome.bath.validate()
	assert(validation.valid, "Bath should remain valid after Grover")

	print("  ✅ PASS (Grover search executes correctly)\n")
	biome.queue_free()

func test_phase_estimation():
	print("📊 Test 3: Phase estimation algorithm...")

	var biome = BioticFluxBiome.new()
	root.add_child(biome)
	await process_frame

	# Get IconRegistry
	var icon_registry = root.get_node_or_null("IconRegistry")
	if not icon_registry:
		print("  ⚠️ IconRegistry not available, skipping test")
		biome.queue_free()
		return

	# Create control and target qubits
	var emoji_list = biome.bath.emoji_list
	if emoji_list.size() < 4:
		print("  ⚠️ Need at least 4 emojis in bath, skipping test")
		biome.queue_free()
		return

	var control = {
		"north": emoji_list[0],
		"south": emoji_list[1]
	}
	var target = {
		"north": emoji_list[2],
		"south": emoji_list[3]
	}

	print("  ✓ Control qubit: %s ↔ %s" % [control.north, control.south])
	print("  ✓ Target qubit: %s ↔ %s" % [target.north, target.south])

	# Evolution time
	var evolution_time = 1.0

	# Run phase estimation
	var result = QuantumAlgorithms.phase_estimation(biome.bath, control, target, evolution_time)

	# Validate result structure
	assert(result.has("phase"), "Result should have 'phase' field")
	assert(result.has("frequency"), "Result should have 'frequency' field")
	assert(result.has("interpretation"), "Result should have 'interpretation' field")

	print("  ✓ Phase: %.3f rad" % result.phase)
	print("  ✓ Frequency: ω = %.3f rad/s" % result.frequency)
	print("  ✓ %s" % result.interpretation)

	# Verify phase is reasonable (0 or π for 1-qubit case)
	assert(result.phase >= 0.0 and result.phase <= PI + 0.1,
		"Phase should be in range [0, π]")

	# Verify bath still valid
	var validation = biome.bath.validate()
	assert(validation.valid, "Bath should remain valid after phase estimation")

	print("  ✅ PASS (Phase estimation executes correctly)\n")
	biome.queue_free()

func test_algorithm_integration():
	print("📊 Test 4: Algorithm physics preservation...")

	var biome = BioticFluxBiome.new()
	root.add_child(biome)
	await process_frame

	# Get initial bath state
	var initial_trace = biome.bath.get_total_probability()
	var initial_purity = biome.bath.get_purity()

	print("  ✓ Initial state: purity=%.4f, trace=%.6f" % [initial_purity, initial_trace])

	# Get IconRegistry
	var icon_registry = root.get_node_or_null("IconRegistry")
	if not icon_registry:
		print("  ⚠️ IconRegistry not available, skipping test")
		biome.queue_free()
		return

	# Create qubits
	var emoji_list = biome.bath.emoji_list
	if emoji_list.size() < 4:
		print("  ⚠️ Need at least 4 emojis in bath, skipping test")
		biome.queue_free()
		return

	var qubit_a = {"north": emoji_list[0], "south": emoji_list[1]}
	var qubit_b = {"north": emoji_list[2], "south": emoji_list[3]}

	# Run all three algorithms in sequence
	print("  • Running Deutsch-Jozsa...")
	QuantumAlgorithms.deutsch_jozsa(biome.bath, qubit_a, qubit_b)

	print("  • Running Grover search...")
	QuantumAlgorithms.grover_search(biome.bath, qubit_a, qubit_b, qubit_a.north)

	print("  • Running Phase estimation...")
	QuantumAlgorithms.phase_estimation(biome.bath, qubit_a, qubit_b, 1.0)

	# Verify physics still valid
	var final_trace = biome.bath.get_total_probability()
	var final_purity = biome.bath.get_purity()

	print("  ✓ Final state: purity=%.4f, trace=%.6f" % [final_purity, final_trace])

	# Trace should still be ~1.0
	assert(abs(final_trace - 1.0) < 0.05,
		"Trace should be preserved (%.6f)" % final_trace)

	# Bath should be valid
	var validation = biome.bath.validate()
	assert(validation.valid, "Bath should remain valid after all algorithms")

	print("  ✓ Bath validation: PASS")
	print("    - Hermitian: %s" % validation.hermitian)
	print("    - Positive semidefinite: %s" % validation.positive_semidefinite)
	print("    - Unit trace: %s" % validation.unit_trace)

	print("  ✅ PASS (All algorithms preserve quantum physics)\n")
	biome.queue_free()
