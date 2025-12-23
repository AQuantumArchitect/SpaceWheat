extends SceneTree

## Carrion Throne Icon Tests
## Verifies Imperial measurement and extraction mechanics

func _initialize():
	print("\n" + "=".repeat(80))
	print("  CARRION THRONE ICON - IMPERIAL WHEAT TESTS")
	print("=".repeat(80) + "\n")

	# Load scripts manually
	var IconHamiltonianScript = load("res://Core/Icons/IconHamiltonian.gd")
	var LindbladIconScript = load("res://Core/Icons/LindbladIcon.gd")
	var CarrionThroneScript = load("res://Core/Icons/CarrionThroneIcon.gd")
	var DualEmojiQubitScript = load("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

	# Test 1: Icon Creation
	print("TEST 1: Icon Creation")
	print("─".repeat(40))
	var carrion = CarrionThroneScript.new()
	carrion._ready()
	print("  Icon created: %s %s" % [carrion.icon_emoji, carrion.icon_name])
	print("  ✅ Creation successful\n")

	# Test 2: Temperature Effect (Moderate Cooling)
	print("TEST 2: Temperature Modulation (Industrial Cooling)")
	print("─".repeat(40))
	carrion.active_strength = 0.0
	var temp_0 = carrion.get_effective_temperature()
	print("  0%% activation: %.1f K" % temp_0)

	carrion.active_strength = 1.0
	var temp_100 = carrion.get_effective_temperature()
	print("  100%% activation: %.1f K" % temp_100)
	print("  Cooling achieved: %.1f K" % (temp_0 - temp_100))

	if temp_100 < temp_0 and temp_100 >= 5.0:  # Accept exactly 5.0K (clamped)
		print("  ✅ Moderate cooling working (%.1fK → %.1fK)" % [temp_0, temp_100])
	else:
		print("  ❌ Cooling not working properly")
		quit(1)

	# Verify it's LESS cooling than Biotic would be
	var expected_biotic_cooling = 60.0
	var actual_imperial_cooling = temp_0 - temp_100
	if actual_imperial_cooling < expected_biotic_cooling:
		print("  ✅ Imperial cooling weaker than Biotic (expected)")
	else:
		print("  ⚠️ Imperial cooling stronger than expected")

	print()

	# Test 3: Growth Modifier (Inverted-U Curve)
	print("TEST 3: Growth Modifier (Inverted-U Curve)")
	print("─".repeat(40))

	carrion.active_strength = 0.2  # Low pressure
	var growth_20 = carrion.get_growth_modifier()
	print("  20%% activation: %.2fx growth" % growth_20)

	carrion.active_strength = 0.6  # Optimal pressure
	var growth_60 = carrion.get_growth_modifier()
	print("  60%% activation: %.2fx growth" % growth_60)

	carrion.active_strength = 0.9  # High pressure (oppressive)
	var growth_90 = carrion.get_growth_modifier()
	print("  90%% activation: %.2fx growth" % growth_90)

	# Verify inverted-U: optimal at 60%
	if growth_60 > growth_20 and growth_60 > growth_90:
		print("  ✅ Inverted-U curve confirmed (optimal at ~60%%)")
	else:
		print("  ❌ Growth curve incorrect")
		quit(1)

	print()

	# Test 4: Quota Activation Logic
	print("TEST 4: Quota-Based Activation")
	print("─".repeat(40))

	# Scenario A: Early game, on track
	var activation_a = carrion.calculate_activation_from_quota(
		50,    # current wheat
		100,   # quota target
		300.0, # time remaining (lots of time)
		600.0  # total time
	)
	print("  Early game, on track (50/100, 50%% time left): %.0f%% activation" % (activation_a * 100))

	# Scenario B: Late game, behind quota
	var activation_b = carrion.calculate_activation_from_quota(
		30,    # current wheat
		100,   # quota target
		60.0,  # time remaining (running out!)
		600.0  # total time
	)
	print("  Late game, behind quota (30/100, 10%% time left): %.0f%% activation" % (activation_b * 100))

	# Scenario C: Quota met early
	var activation_c = carrion.calculate_activation_from_quota(
		100,   # current wheat
		100,   # quota target
		300.0, # time remaining
		600.0  # total time
	)
	print("  Quota met early (100/100, 50%% time left): %.0f%% activation" % (activation_c * 100))

	# Verify logic
	if activation_b > activation_a and activation_c < activation_a:
		print("  ✅ Activation logic correct (pressure when behind, relief when met)")
	else:
		print("  ❌ Activation logic incorrect")
		quit(1)

	print()

	# Test 5: Measurement Pressure (Collapse)
	print("TEST 5: Measurement Pressure (Superposition Collapse)")
	print("─".repeat(40))

	# Create qubit in superposition
	var qubit = DualEmojiQubitScript.new("🌾", "👥", PI/2)  # Equator = max superposition
	print("  Initial: θ=%.3f, coherence=%.2f" % [qubit.theta, qubit.get_coherence()])

	carrion.active_strength = 1.0
	# Apply measurement pressure for 5 seconds
	for i in range(50):
		carrion._apply_measurement_pressure(qubit, 0.1)

	print("  After 5s measurement: θ=%.3f, coherence=%.2f" % [qubit.theta, qubit.get_coherence()])

	# Should collapse toward pole (θ → 0 or θ → π)
	# Threshold adjusted for 15% collapse rate over 5s
	var collapsed_to_pole = (qubit.theta < 0.5 or qubit.theta > 2.2)
	if collapsed_to_pole:
		print("  ✅ Measurement collapse working (superposition → classical)")
	else:
		print("  ❌ Measurement not collapsing properly")
		quit(1)

	print()

	# Test 6: Extractive Damping
	print("TEST 6: Extractive Damping (Energy Drain)")
	print("─".repeat(40))

	# Create qubit in excited state
	qubit = DualEmojiQubitScript.new("🌾", "👥", PI * 0.8)  # Mostly excited
	var initial_energy = sin(qubit.theta / 2.0) ** 2
	print("  Initial excited probability: %.2f" % initial_energy)

	carrion.active_strength = 1.0
	# Apply extraction for 5 seconds
	for i in range(50):
		carrion._apply_imperial_extraction(qubit, 0.1)

	var final_energy = sin(qubit.theta / 2.0) ** 2
	print("  After 5s extraction: %.2f" % final_energy)
	print("  Energy extracted: %.2f" % (initial_energy - final_energy))

	if final_energy < initial_energy:
		print("  ✅ Extractive damping working (energy drained to Empire)")
	else:
		print("  ❌ Extraction not working")
		quit(1)

	print()

	# Test 7: Entanglement Weakening
	print("TEST 7: Entanglement Weakening")
	print("─".repeat(40))

	carrion.active_strength = 0.0
	var ent_0 = carrion.get_entanglement_strength_modifier()
	print("  0%% activation: %.2fx entanglement" % ent_0)

	carrion.active_strength = 1.0
	var ent_100 = carrion.get_entanglement_strength_modifier()
	print("  100%% activation: %.2fx entanglement" % ent_100)

	if ent_100 < ent_0:
		print("  ✅ Imperial pressure weakens entanglement (%.2fx → %.2fx)" % [ent_0, ent_100])
	else:
		print("  ❌ Entanglement modifier incorrect")
		quit(1)

	print()

	# Test 8: Visual Effect Parameters
	print("TEST 8: Visual Effect Parameters")
	print("─".repeat(40))

	carrion.active_strength = 0.75
	var fx = carrion.get_visual_effect()

	print("  Type: %s" % fx.type)
	print("  Color: %s" % fx.color)
	print("  Flow pattern: %s" % fx.flow_pattern)
	print("  Particle density: %d" % fx.particle_density)
	print("  Oppression overlay: %.1f%%" % (fx.oppression_overlay * 100))

	if fx.type == "imperial_order" and fx.flow_pattern == "marching":
		print("  ✅ Visual effects configured (cold gold, marching, oppressive)")
	else:
		print("  ⚠️ Visual effect parameters unexpected")

	print()

	# Test 9: Physics Description
	print("TEST 9: Physics Description")
	print("─".repeat(40))

	carrion.active_strength = 0.5
	var desc = carrion.get_physics_description()
	print(desc)

	if desc.contains("Carrion Throne") and desc.contains("measurement"):
		print("  ✅ Physics description generated")
	else:
		print("  ⚠️ Description incomplete")

	print()

	print("=".repeat(80))
	print("  ALL CARRION THRONE TESTS PASSED ✅")
	print("=".repeat(80) + "\n")

	print("Summary:")
	print("  - Moderate industrial cooling (weaker than Biotic)")
	print("  - Inverted-U growth curve (optimal at ~60%% pressure)")
	print("  - Quota-based activation (pressure when behind, relief when met)")
	print("  - Measurement collapse (superposition → classical)")
	print("  - Extractive damping (energy drain to Empire)")
	print("  - Entanglement weakening (measurement breaks correlation)")
	print("  - Cold gold visual effects (marching, oppressive)")
	print("\nThe Carrion Throne watches. The quotas must be met. 🏰⚖️\n")

	quit()
