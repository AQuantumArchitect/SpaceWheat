extends SceneTree

## Biotic Flux Icon Tests
## Verify coherence enhancement, cooling, and balance with Cosmic Chaos

# Load base classes first to ensure proper inheritance chain
const IconHamiltonian = preload("res://Core/Icons/IconHamiltonian.gd")
const LindbladIcon = preload("res://Core/Icons/LindbladIcon.gd")
const BioticFluxIcon = preload("res://Core/Icons/BioticFluxIcon.gd")
const CosmicChaosIcon = preload("res://Core/Icons/CosmicChaosIcon.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

func _initialize():
	print("\n" + "=".repeat(80))
	print("  BIOTIC FLUX ICON TESTS")
	print("=".repeat(80) + "\n")

	test_activation()
	test_temperature_cooling()
	test_coherence_restoration()
	test_growth_modifier()
	test_chaos_vs_biotic_balance()

	print("\n" + "=".repeat(80))
	print("  ALL BIOTIC FLUX TESTS PASSED ✅")
	print("=".repeat(80) + "\n")

	quit()


func test_activation():
	print("TEST 1: Activation from Wheat Cultivation")
	print("─".repeat(40))

	var biotic = BioticFluxIcon.new()
	biotic._ready()

	# No wheat → 0% activation
	biotic.calculate_activation_from_wheat(0, 25)
	print("  No wheat: %.0f%% activation" % (biotic.active_strength * 100))
	test_assert(biotic.active_strength == 0.0, "Should have 0% activation with no wheat")

	# 25% wheat → ~25% activation
	biotic.calculate_activation_from_wheat(6, 25)
	print("  6/25 wheat: %.0f%% activation" % (biotic.active_strength * 100))
	test_assert(biotic.active_strength >= 0.2 and biotic.active_strength <= 0.3, "Should have ~25% activation")

	# 100% wheat → 100% activation
	biotic.calculate_activation_from_wheat(25, 25)
	print("  25/25 wheat: %.0f%% activation" % (biotic.active_strength * 100))
	test_assert(biotic.active_strength >= 0.9, "Should have ~100% activation with full wheat")

	print("  ✅ Activation scaling correct\n")


func test_temperature_cooling():
	print("TEST 2: Temperature Cooling Effect")
	print("─".repeat(40))

	var biotic = BioticFluxIcon.new()
	biotic._ready()

	# 0% activation → baseline temperature
	biotic.active_strength = 0.0
	var temp_0 = biotic.get_effective_temperature()
	print("  0%% activation: T = %.1f K" % temp_0)
	test_assert(abs(temp_0 - 20.0) < 0.1, "Should be at baseline temperature")

	# 50% activation → moderate cooling
	biotic.active_strength = 0.5
	var temp_50 = biotic.get_effective_temperature()
	print("  50%% activation: T = %.1f K (%.1f K cooling)" % [temp_50, 20.0 - temp_50])
	test_assert(temp_50 < 10.0 and temp_50 > 1.0, "Should have moderate cooling")

	# 100% activation → maximum cooling
	biotic.active_strength = 1.0
	var temp_100 = biotic.get_effective_temperature()
	print("  100%% activation: T = %.1f K (%.1f K cooling)" % [temp_100, 20.0 - temp_100])
	test_assert(temp_100 <= 2.0, "Should approach absolute zero")

	print("  ✅ Temperature cooling working\n")


func test_coherence_restoration():
	print("TEST 3: Coherence Restoration")
	print("─".repeat(40))

	# Create qubit starting at north pole (fully collapsed)
	var qubit = DualEmojiQubit.new("🌾", "👥", 0.1)  # Near north pole

	print("  Initial state: θ = %.3f (coherence: %.2f)" % [qubit.theta, qubit.get_coherence()])

	# Apply Biotic Flux to restore coherence
	var biotic = BioticFluxIcon.new()
	biotic._ready()
	biotic.active_strength = 1.0  # Full activation

	# Apply over 10 seconds (100 steps of 0.1s)
	for i in range(100):
		biotic.apply_to_qubit(qubit, 0.1)

	print("  After 10s Biotic Flux: θ = %.3f (coherence: %.2f)" % [qubit.theta, qubit.get_coherence()])

	# Should have moved toward equator (θ = π/2)
	var target = PI / 2.0
	test_assert(abs(qubit.theta - target) < abs(0.1 - target), "Should move toward superposition")
	test_assert(qubit.get_coherence() > 0.8, "Should restore coherence")

	print("  ✅ Coherence restoration working\n")


func test_growth_modifier():
	print("TEST 4: Growth Modifier")
	print("─".repeat(40))

	var biotic = BioticFluxIcon.new()
	biotic._ready()

	# 0% activation → 1.0x growth
	biotic.active_strength = 0.0
	var growth_0 = biotic.get_growth_modifier()
	print("  0%% activation: %.2fx growth" % growth_0)
	test_assert(abs(growth_0 - 1.0) < 0.01, "Should have no growth boost")

	# 50% activation → 1.5x growth
	biotic.active_strength = 0.5
	var growth_50 = biotic.get_growth_modifier()
	print("  50%% activation: %.2fx growth" % growth_50)
	test_assert(abs(growth_50 - 1.5) < 0.01, "Should have 1.5x growth")

	# 100% activation → 2.0x growth
	biotic.active_strength = 1.0
	var growth_100 = biotic.get_growth_modifier()
	print("  100%% activation: %.2fx growth" % growth_100)
	test_assert(abs(growth_100 - 2.0) < 0.01, "Should have 2.0x growth")

	print("  ✅ Growth modifier correct\n")


func test_chaos_vs_biotic_balance():
	print("TEST 5: Cosmic Chaos vs Biotic Flux Balance")
	print("─".repeat(40))

	# Create qubit in perfect superposition
	var qubit = DualEmojiQubit.new("🌾", "👥", PI/2)

	# Create both Icons
	var chaos = CosmicChaosIcon.new()
	chaos._ready()
	chaos.active_strength = 0.8  # 80% chaos

	var biotic = BioticFluxIcon.new()
	biotic._ready()
	biotic.active_strength = 0.8  # 80% biotic

	print("  Initial coherence: %.2f" % qubit.get_coherence())
	print("  Chaos temperature: %.1f K" % chaos.get_effective_temperature())
	print("  Biotic temperature: %.1f K" % biotic.get_effective_temperature())

	# Apply both for 5 seconds
	for i in range(50):
		# First apply chaos (tries to decohere)
		chaos.apply_to_qubit(qubit, 0.1)
		# Then apply biotic (tries to restore)
		biotic.apply_to_qubit(qubit, 0.1)

	var final_coherence = qubit.get_coherence()
	print("  After 5s with both: coherence = %.2f" % final_coherence)

	# With both active, should maintain some coherence (balance point)
	test_assert(final_coherence > 0.4, "Should maintain moderate coherence with both active")

	# Now test: only Chaos (should decohere heavily)
	var qubit_chaos = DualEmojiQubit.new("🌾", "👥", PI/2)
	for i in range(50):
		chaos.apply_to_qubit(qubit_chaos, 0.1)

	print("  Chaos only: coherence = %.2f" % qubit_chaos.get_coherence())

	# Now test: only Biotic (should preserve well)
	var qubit_biotic = DualEmojiQubit.new("🌾", "👥", PI/2)
	for i in range(50):
		biotic.apply_to_qubit(qubit_biotic, 0.1)

	print("  Biotic only: coherence = %.2f" % qubit_biotic.get_coherence())

	# Biotic should preserve better than Chaos destroys
	test_assert(qubit_biotic.get_coherence() > qubit_chaos.get_coherence(),
				"Biotic should preserve better than Chaos destroys")

	print("  ✅ Balance mechanics working\n")


func test_assert(condition: bool, message: String):
	if not condition:
		print("  ❌ FAILED: %s" % message)
		push_error(message)
		quit(1)
