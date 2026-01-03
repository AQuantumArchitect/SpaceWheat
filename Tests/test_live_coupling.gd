#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: Live-Coupled 2D Projections
##
## Verifies:
## 1. Qubits compute theta/phi/radius from bath (live coupling)
## 2. Bath changes propagate to qubits automatically
## 3. Measurement on one qubit affects others (entanglement)
## 4. Multiple projections onto same emojis are consistent

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

func _init():
	print("🧪 LIVE-COUPLED 2D PROJECTION TEST\n")

	# Create biome with bath
	var biome = BioticFluxBiome.new()
	biome._ready()

	if not biome.bath:
		print("❌ FAIL: Biome has no bath!")
		quit(1)
		return

	print("✓ Biome initialized with bath")
	print("  Bath has %d emojis: %s\n" % [biome.bath.emoji_list.size(), str(biome.bath.emoji_list)])

	# TEST 1: Live coupling - theta computes from bath
	print("🔼 TEST 1: LIVE COUPLING (theta from bath)")

	# Create projection
	var qubit1 = biome.create_projection(Vector2i(0, 0), "🌾", "🍄")

	if not qubit1:
		print("❌ FAIL: Could not create projection!")
		quit(1)
		return

	if not qubit1.bath:
		print("❌ FAIL: Qubit has no bath reference!")
		quit(1)
		return

	var theta_initial = qubit1.theta
	print("  Initial theta (from bath): %.4f" % theta_initial)

	# Modify bath directly
	var wheat_before = biome.bath.get_population("🌾")
	biome.bath.boost_amplitude("🌾", 0.15)
	var wheat_after = biome.bath.get_population("🌾")

	print("  🌾 population: %.4f → %.4f" % [wheat_before, wheat_after])

	# Qubit should automatically update!
	var theta_after_boost = qubit1.theta
	print("  Theta after boost: %.4f" % theta_after_boost)

	if abs(theta_after_boost - theta_initial) < 0.001:
		print("  ❌ FAIL: Theta did not change (not live-coupled!)")
		quit(1)
		return
	else:
		print("  ✅ PASS: Theta updated automatically (live coupling works!)")

	# TEST 2: Multiple projections are consistent
	print("\n🔀 TEST 2: MULTIPLE PROJECTIONS (same emojis)")

	# Create another projection with same emojis
	var qubit2 = biome.create_projection(Vector2i(1, 0), "🌾", "🍄")

	var theta1 = qubit1.theta
	var theta2 = qubit2.theta

	print("  Qubit1 theta: %.4f" % theta1)
	print("  Qubit2 theta: %.4f" % theta2)

	if abs(theta1 - theta2) > 0.001:
		print("  ❌ FAIL: Qubits have different theta (should be identical!)")
		quit(1)
		return
	else:
		print("  ✅ PASS: Both qubits see same bath state")

	# TEST 3: Measurement entanglement
	print("\n🔬 TEST 3: MEASUREMENT ENTANGLEMENT")

	# Create overlapping projections
	var qubit_wheat_mushroom = biome.create_projection(Vector2i(0, 1), "🌾", "🍄")
	var qubit_mushroom_labor = biome.create_projection(Vector2i(1, 1), "🍄", "👥")

	var mushroom_pop_before = biome.bath.get_population("🍄")
	var theta_ml_before = qubit_mushroom_labor.theta

	print("  🍄 population before: %.4f" % mushroom_pop_before)
	print("  🍄↔👥 theta before: %.4f" % theta_ml_before)

	# Measure wheat-mushroom (should affect mushroom population)
	var outcome = qubit_wheat_mushroom.measure()

	print("  Measured 🌾↔🍄 → %s" % outcome)

	var mushroom_pop_after = biome.bath.get_population("🍄")
	var theta_ml_after = qubit_mushroom_labor.theta

	print("  🍄 population after: %.4f" % mushroom_pop_after)
	print("  🍄↔👥 theta after: %.4f" % theta_ml_after)

	# Theta should change (entanglement via shared 🍄)
	if abs(theta_ml_after - theta_ml_before) < 0.001:
		print("  ❌ FAIL: Second qubit didn't update (no entanglement!)")
		quit(1)
		return
	else:
		print("  ✅ PASS: Measurement on first qubit affected second (entanglement!)")

	# TEST 4: Verify bath normalization
	print("\n🔄 TEST 4: BATH NORMALIZATION")

	var total_prob = 0.0
	for emoji in biome.bath.emoji_list:
		total_prob += biome.bath.get_probability(emoji)

	print("  Total probability: %.6f" % total_prob)

	if abs(total_prob - 1.0) > 0.001:
		print("  ❌ FAIL: Bath not normalized!")
		quit(1)
		return
	else:
		print("  ✅ PASS: Bath remains normalized")

	# TEST 5: Radius computation
	print("\n📐 TEST 5: RADIUS (coherence in subspace)")

	var qubit_test = biome.create_projection(Vector2i(2, 2), "🌾", "🍄")
	var radius = qubit_test.radius

	print("  Radius (🌾+🍄 subspace): %.4f" % radius)

	# Radius should be sqrt(P(🌾) + P(🍄))
	var p_wheat = biome.bath.get_probability("🌾")
	var p_mushroom = biome.bath.get_probability("🍄")
	var expected_radius = sqrt(p_wheat + p_mushroom)

	print("  Expected: %.4f" % expected_radius)

	if abs(radius - expected_radius) > 0.01:
		print("  ❌ FAIL: Radius mismatch!")
		quit(1)
		return
	else:
		print("  ✅ PASS: Radius correctly computed from bath")

	print("\n" + "=".repeat(50))
	print("✅ ALL TESTS PASSED - LIVE COUPLING WORKS!")
	print("=".repeat(50))
	quit(0)
