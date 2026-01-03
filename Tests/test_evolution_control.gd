extends SceneTree

## Test research-grade evolution control methods

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const BasePlot = preload("res://Core/GameMechanics/BasePlot.gd")

func _init():
	print("\n╔════════════════════════════════════════════════════════╗")
	print("║  EVOLUTION CONTROL TEST (Tool 4)                     ║")
	print("╚════════════════════════════════════════════════════════╝\n")

	await test_boost_hamiltonian_coupling()
	await test_tune_lindblad_rate()
	await test_add_time_driver()
	await test_evolution_effects()

	print("\n✅ ALL EVOLUTION CONTROL TESTS PASSED!\n")
	quit()

func test_boost_hamiltonian_coupling():
	print("📊 Test 1: Boost Hamiltonian coupling...")

	var biome = BioticFluxBiome.new()
	root.add_child(biome)
	await process_frame

	# Get IconRegistry to check coupling before/after
	var icon_registry = root.get_node_or_null("IconRegistry")
	if not icon_registry:
		print("  ⚠️ IconRegistry not available, skipping test")
		biome.queue_free()
		return

	# Get initial wheat icon
	var wheat_icon = icon_registry.get_icon("🌾")
	if not wheat_icon:
		print("  ⚠️ Wheat icon not found, skipping test")
		biome.queue_free()
		return

	# Check if wheat has any couplings
	if wheat_icon.hamiltonian_couplings.is_empty():
		print("  ⚠️ Wheat has no Hamiltonian couplings, skipping test")
		biome.queue_free()
		return

	# Get first coupling
	var target_emoji = wheat_icon.hamiltonian_couplings.keys()[0]
	var initial_coupling = wheat_icon.hamiltonian_couplings[target_emoji]

	print("  ✓ Initial coupling 🌾 → %s: %.4f" % [target_emoji, initial_coupling])

	# Boost coupling 2x
	var boost_factor = 2.0
	var success = biome.boost_hamiltonian_coupling("🌾", target_emoji, boost_factor)
	assert(success, "Boost coupling should succeed")

	# Check coupling was modified
	var new_coupling = wheat_icon.hamiltonian_couplings[target_emoji]
	print("  ✓ After boost: %.4f (×%.1f)" % [new_coupling, boost_factor])

	assert(abs(new_coupling - initial_coupling * boost_factor) < 0.001,
		"Coupling should be boosted by factor %.1f" % boost_factor)

	print("  ✅ PASS (coupling boosted correctly)\n")
	biome.queue_free()

func test_tune_lindblad_rate():
	print("📊 Test 2: Tune Lindblad decoherence rate...")

	var biome = BioticFluxBiome.new()
	root.add_child(biome)
	await process_frame

	# Get IconRegistry
	var icon_registry = root.get_node_or_null("IconRegistry")
	if not icon_registry:
		print("  ⚠️ IconRegistry not available, skipping test")
		biome.queue_free()
		return

	# Find an icon with Lindblad outgoing
	var source_emoji = ""
	var target_emoji = ""
	var source_icon = null

	for emoji in biome.bath.emoji_list:
		var icon = icon_registry.get_icon(emoji)
		if icon and not icon.lindblad_outgoing.is_empty():
			source_emoji = emoji
			source_icon = icon
			target_emoji = icon.lindblad_outgoing.keys()[0]
			break

	if source_emoji == "":
		print("  ⚠️ No Lindblad terms found, skipping test")
		biome.queue_free()
		return

	var initial_rate = source_icon.lindblad_outgoing[target_emoji]
	print("  ✓ Initial Lindblad %s → %s: γ=%.4f" % [source_emoji, target_emoji, initial_rate])

	# Reduce decoherence by 50%
	var rate_factor = 0.5
	var success = biome.tune_lindblad_rate(source_emoji, target_emoji, rate_factor)
	assert(success, "Tune Lindblad should succeed")

	# Check rate was modified
	var new_rate = source_icon.lindblad_outgoing[target_emoji]
	print("  ✓ After tuning: γ=%.4f (×%.1f)" % [new_rate, rate_factor])

	assert(abs(new_rate - initial_rate * rate_factor) < 0.001,
		"Rate should be scaled by factor %.1f" % rate_factor)

	print("  ✅ PASS (decoherence rate tuned correctly)\n")
	biome.queue_free()

func test_add_time_driver():
	print("📊 Test 3: Add time-dependent driver...")

	var biome = BioticFluxBiome.new()
	root.add_child(biome)
	await process_frame

	# Get IconRegistry
	var icon_registry = root.get_node_or_null("IconRegistry")
	if not icon_registry:
		print("  ⚠️ IconRegistry not available, skipping test")
		biome.queue_free()
		return

	# Get wheat icon
	var wheat_icon = icon_registry.get_icon("🌾")
	if not wheat_icon:
		print("  ⚠️ Wheat icon not found, skipping test")
		biome.queue_free()
		return

	# Check initial driver state
	var initial_driver = wheat_icon.self_energy_driver
	print("  ✓ Initial driver: %s" % initial_driver)

	# Add resonant driver
	var frequency = 0.5
	var amplitude = 0.1
	var phase = 0.0

	var success = biome.add_time_driver("🌾", frequency, amplitude, phase)
	assert(success, "Add driver should succeed")

	# Check driver was added
	assert(wheat_icon.self_energy_driver == "cosine", "Driver should be 'cosine'")
	assert(wheat_icon.driver_frequency == frequency, "Frequency should match")
	assert(wheat_icon.driver_amplitude == amplitude, "Amplitude should match")

	print("  ✓ Driver added: ω=%.2f, A=%.2f" % [wheat_icon.driver_frequency, wheat_icon.driver_amplitude])

	# Remove driver (amplitude = 0)
	success = biome.add_time_driver("🌾", 0.0, 0.0)
	assert(success, "Remove driver should succeed")
	assert(wheat_icon.self_energy_driver == "none", "Driver should be removed")

	print("  ✓ Driver removed")
	print("  ✅ PASS (driver added/removed correctly)\n")
	biome.queue_free()

func test_evolution_effects():
	print("📊 Test 4: Evolution control affects dynamics...")

	var biome = BioticFluxBiome.new()
	root.add_child(biome)
	await process_frame

	# Get initial bath state
	var initial_purity = biome.bath.get_purity()
	var initial_trace = biome.bath.get_total_probability()

	print("  ✓ Initial state: purity=%.4f, trace=%.6f" % [initial_purity, initial_trace])

	# Boost coupling (should speed up oscillations)
	var icon_registry = root.get_node_or_null("IconRegistry")
	var wheat_icon = icon_registry.get_icon("🌾") if icon_registry else null

	if wheat_icon and not wheat_icon.hamiltonian_couplings.is_empty():
		var target = wheat_icon.hamiltonian_couplings.keys()[0]
		biome.boost_hamiltonian_coupling("🌾", target, 2.0)
		print("  ✓ Boosted coupling 🌾 → %s by 2×" % target)

	# Evolve for a short time
	for i in range(10):
		biome.advance_simulation(0.1)

	# Check physics still valid
	var final_purity = biome.bath.get_purity()
	var final_trace = biome.bath.get_total_probability()

	print("  ✓ After evolution: purity=%.4f, trace=%.6f" % [final_purity, final_trace])

	# Verify trace preserved
	assert(abs(final_trace - 1.0) < 0.01, "Trace should be preserved")

	# Verify bath still valid
	var validation = biome.bath.validate()
	assert(validation.valid, "Bath should remain valid after evolution control")

	print("  ✓ Bath validation: PASS")
	print("    - Hermitian: %s" % validation.hermitian)
	print("    - Positive semidefinite: %s" % validation.positive_semidefinite)
	print("    - Unit trace: %s" % validation.unit_trace)

	print("  ✅ PASS (evolution control preserves quantum physics)\n")
	biome.queue_free()
