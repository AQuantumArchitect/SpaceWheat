extends SceneTree

## Simple Biotic Flux Icon Tests
## Manual instantiation to avoid class_name issues

func _initialize():
	print("\n" + "=".repeat(80))
	print("  BIOTIC FLUX ICON - SIMPLE TESTS")
	print("=".repeat(80) + "\n")

	# Load scripts manually
	var IconHamiltonianScript = load("res://Core/Icons/IconHamiltonian.gd")
	var LindbladIconScript = load("res://Core/Icons/LindbladIcon.gd")
	var BioticFluxScript = load("res://Core/Icons/BioticFluxIcon.gd")
	var DualEmojiQubitScript = load("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

	# Test 1: Can we create the icon?
	print("TEST 1: Icon Creation")
	print("─".repeat(40))
	var biotic = BioticFluxScript.new()
	biotic._ready()
	print("  Icon created: %s %s" % [biotic.icon_emoji, biotic.icon_name])
	print("  ✅ Creation successful\n")

	# Test 2: Temperature effect
	print("TEST 2: Temperature Cooling")
	print("─".repeat(40))
	biotic.active_strength = 0.0
	var temp_0 = biotic.get_effective_temperature()
	print("  0%% activation: %.1f K" % temp_0)

	biotic.active_strength = 1.0
	var temp_100 = biotic.get_effective_temperature()
	print("  100%% activation: %.1f K" % temp_100)
	print("  Cooling achieved: %.1f K" % (temp_0 - temp_100))

	if temp_100 < 5.0:
		print("  ✅ Cooling working (near absolute zero!)\n")
	else:
		print("  ❌ Cooling not working properly\n")
		quit(1)

	# Test 3: Growth modifier
	print("TEST 3: Growth Modifier")
	print("─".repeat(40))
	biotic.active_strength = 0.0
	var growth_0 = biotic.get_growth_modifier()
	print("  0%% activation: %.2fx growth" % growth_0)

	biotic.active_strength = 1.0
	var growth_100 = biotic.get_growth_modifier()
	print("  100%% activation: %.2fx growth" % growth_100)

	if abs(growth_100 - 2.0) < 0.01:
		print("  ✅ Growth acceleration working\n")
	else:
		print("  ❌ Growth modifier incorrect\n")
		quit(1)

	# Test 4: Activation logic
	print("TEST 4: Wheat-Based Activation")
	print("─".repeat(40))
	biotic.calculate_activation_from_wheat(0, 25)
	print("  0/25 wheat: %.0f%% activation" % (biotic.active_strength * 100))

	biotic.calculate_activation_from_wheat(25, 25)
	print("  25/25 wheat: %.0f%% activation" % (biotic.active_strength * 100))

	if biotic.active_strength >= 0.9:
		print("  ✅ Activation logic working\n")
	else:
		print("  ❌ Activation logic incorrect\n")
		quit(1)

	# Test 5: Coherence restoration effect
	print("TEST 5: Coherence Restoration")
	print("─".repeat(40))
	var qubit = DualEmojiQubitScript.new("🌾", "👥", 0.1)  # Start near north pole
	print("  Initial: θ=%.3f, coherence=%.2f" % [qubit.theta, qubit.get_coherence()])

	biotic.active_strength = 1.0
	# Apply for 10 seconds (longer duration for visible effect)
	for i in range(100):
		biotic._apply_coherence_restoration(qubit, 0.1)

	print("  After 10s: θ=%.3f, coherence=%.2f" % [qubit.theta, qubit.get_coherence()])

	# Should show improvement (moving toward equator at θ=π/2 ≈ 1.57)
	if qubit.get_coherence() > 0.3 and qubit.theta > 0.3:
		print("  ✅ Coherence restoration working (moving toward superposition)\n")
	else:
		print("  ❌ Coherence not restored\n")
		quit(1)

	print("=".repeat(80))
	print("  ALL SIMPLE TESTS PASSED ✅")
	print("=".repeat(80) + "\n")

	quit()
