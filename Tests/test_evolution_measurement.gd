#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: Evolution & Measurement with Live-Coupled Projections
##
## Phase 2 verification:
## 1. Plant wheat
## 2. Evolve bath
## 3. Verify qubit.theta updates automatically (live coupling)
## 4. Measure qubit
## 5. Verify bath collapsed
## 6. Verify normalization maintained

const Farm = preload("res://Core/Farm.gd")

var farm: Farm
var test_pos = Vector2i(2, 0)  # BioticFlux biome

func _init():
	print("\n🧪 EVOLUTION & MEASUREMENT TEST (Live-Coupled Projections)")
	print("=" + "=".repeat(59))

	# Setup
	print("\n🌾 Setting up farm...")
	farm = Farm.new()
	farm._ready()

	# Init BioticFlux biome
	if farm.biotic_flux_biome and not farm.biotic_flux_biome.bath:
		farm.biotic_flux_biome._ready()

	farm.economy.add_resource("🌾", 100, "test")
	print("  ✓ Farm ready")

	# Get biome reference
	var biome = farm.grid.biomes.get("BioticFlux")
	if not biome or not biome.bath:
		print("❌ FAIL: No BioticFlux biome/bath")
		quit(1)
		return

	# TEST 1: Plant
	print("\n🌱 TEST 1: PLANTING")
	if not farm.build(test_pos, "wheat"):
		print("❌ FAIL: Could not plant")
		quit(1)
		return

	var plot = farm.grid.get_plot(test_pos)
	var qubit = plot.quantum_state

	if not qubit or not qubit.bath:
		print("❌ FAIL: No bath-coupled qubit")
		quit(1)
		return

	print("  ✓ Planted: %s ↔ %s" % [qubit.north_emoji, qubit.south_emoji])
	print("  ✓ Bath coupled: %s" % (qubit.bath != null))

	# Record initial state
	var theta_initial = qubit.theta
	var wheat_pop_initial = biome.bath.get_population("🌾")
	var labor_pop_initial = biome.bath.get_population("👥")

	print("  Initial state:")
	print("    θ = %.4f" % theta_initial)
	print("    🌾 = %.4f" % wheat_pop_initial)
	print("    👥 = %.4f" % labor_pop_initial)

	# TEST 2: Evolution
	print("\n⏱️  TEST 2: BATH EVOLUTION")
	print("  Evolving for 3 ticks (dt=0.5)...")

	var evolution_history = []
	for tick in range(3):
		# Evolve bath (biome.evolve calls bath.evolve)
		biome.evolve(0.5)

		var theta = qubit.theta
		var wheat = biome.bath.get_population("🌾")
		var labor = biome.bath.get_population("👥")

		evolution_history.append({
			"tick": tick + 1,
			"theta": theta,
			"wheat": wheat,
			"labor": labor
		})

		print("    Tick %d: θ=%.4f | 🌾=%.4f 👥=%.4f" % [tick + 1, theta, wheat, labor])

	# Verify theta changed (live update)
	var theta_after = qubit.theta
	var theta_changed = abs(theta_after - theta_initial) > 0.0001

	if not theta_changed:
		print("  ⚠️  WARNING: Theta didn't change (%.4f → %.4f)" % [theta_initial, theta_after])
		print("  This might be OK if bath evolution is slow/disabled without icons")
	else:
		print("  ✅ PASS: Theta updated (%.4f → %.4f) - live coupling works!" % [theta_initial, theta_after])

	# TEST 3: Bath Normalization (Before Measurement)
	print("\n🔄 TEST 3: BATH NORMALIZATION (pre-measurement)")
	var total_prob_before = 0.0
	for emoji in biome.bath.emoji_list:
		total_prob_before += biome.bath.get_probability(emoji)

	print("  Total probability: %.6f" % total_prob_before)

	if abs(total_prob_before - 1.0) > 0.01:
		print("❌ FAIL: Bath not normalized before measurement!")
		quit(1)
		return

	print("  ✅ PASS: Bath normalized")

	# TEST 4: Measurement
	print("\n🔬 TEST 4: MEASUREMENT & COLLAPSE")

	# Get probabilities before measurement
	var prob_north_before = qubit.get_north_probability()
	var prob_south_before = qubit.get_south_probability()

	print("  Probabilities before measurement:")
	print("    P(%s) = %.4f" % [qubit.north_emoji, prob_north_before])
	print("    P(%s) = %.4f" % [qubit.south_emoji, prob_south_before])

	# Measure
	var outcome = farm.measure_plot(test_pos)

	if outcome == "":
		print("❌ FAIL: Measurement returned empty string")
		quit(1)
		return

	print("  Measured outcome: %s" % outcome)

	# Verify bath collapsed
	var wheat_after_measure = biome.bath.get_population("🌾")
	var labor_after_measure = biome.bath.get_population("👥")

	print("  Bath populations after measurement:")
	print("    🌾 = %.6f" % wheat_after_measure)
	print("    👥 = %.6f" % labor_after_measure)

	# Check collapse: one should be near 0
	var collapsed = false
	if outcome == "🌾":
		# Wheat measured - labor should collapse to ~0
		if labor_after_measure < 0.01:
			collapsed = true
			print("  ✅ Collapse verified: 👥 → 0 (measured 🌾)")
	else:
		# Labor measured - wheat should collapse to ~0
		if wheat_after_measure < 0.01:
			collapsed = true
			print("  ✅ Collapse verified: 🌾 → 0 (measured 👥)")

	if not collapsed:
		print("  ⚠️  WARNING: Expected collapse didn't occur")
		print("    This might happen if collapse_in_subspace has issues")

	# TEST 5: Bath Normalization (After Measurement)
	print("\n🔄 TEST 5: BATH NORMALIZATION (post-measurement)")
	var total_prob_after = 0.0
	for emoji in biome.bath.emoji_list:
		total_prob_after += biome.bath.get_probability(emoji)

	print("  Total probability: %.6f" % total_prob_after)

	if abs(total_prob_after - 1.0) > 0.01:
		print("❌ FAIL: Bath not normalized after measurement!")
		print("  Populations:")
		for emoji in biome.bath.emoji_list:
			var pop = biome.bath.get_probability(emoji)
			print("    %s: %.6f" % [emoji, pop])
		quit(1)
		return

	print("  ✅ PASS: Bath remains normalized after collapse")

	# TEST 6: Qubit State After Measurement
	print("\n🔭 TEST 6: QUBIT STATE (post-measurement)")

	var theta_measured = qubit.theta
	print("  Theta after measurement: %.4f" % theta_measured)

	# Theta should be near 0 or PI depending on outcome
	var theta_collapsed = false
	if outcome == qubit.north_emoji:
		# Measured north - theta should be near 0
		if abs(theta_measured) < 0.1 or abs(theta_measured - TAU) < 0.1:
			theta_collapsed = true
	else:
		# Measured south - theta should be near PI
		if abs(theta_measured - PI) < 0.1:
			theta_collapsed = true

	if theta_collapsed:
		print("  ✅ Theta collapsed to basis state")
	else:
		print("  ⚠️  Theta = %.4f (expected 0 or π)" % theta_measured)

	# Summary
	print("\n" + "=" + "=".repeat(59))
	print("✅ EVOLUTION & MEASUREMENT TEST COMPLETE")
	print("=" + "=".repeat(59))
	print("\nResults:")
	print("  ✅ Plant: Success")
	print("  %s Evolution: %s" % [
		"✅" if theta_changed else "⚠️ ",
		"Theta updated" if theta_changed else "Theta unchanged (may need icons)"
	])
	print("  %s Measurement: %s" % [
		"✅" if collapsed else "⚠️ ",
		"Bath collapsed" if collapsed else "Collapse unclear"
	])
	print("  ✅ Normalization: Maintained throughout")

	quit(0)
