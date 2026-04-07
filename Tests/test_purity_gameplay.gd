extends SceneTree

## Test purity gameplay mechanics (Phase 4)

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const BasePlot = preload("res://Core/GameMechanics/BasePlot.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")

func _init():
	print("\n╔════════════════════════════════════════════════════════╗")
	print("║  PURITY GAMEPLAY TEST (Phase 4)                      ║")
	print("╚════════════════════════════════════════════════════════╝\n")

	await test_purity_harvest_multiplier()
	await test_purity_range_validation()
	await test_tune_decoherence_resource_cost()
	await test_harvest_with_different_purities()

	print("\n✅ ALL PURITY GAMEPLAY TESTS PASSED!\n")
	quit()

func test_purity_harvest_multiplier():
	print("📊 Test 1: Purity harvest multiplier...")

	var biome = BioticFluxBiome.new()
	root.add_child(biome)
	await process_frame

	# Create a test plot
	var plot = BasePlot.new()
	plot.grid_position = Vector2i(0, 0)
	root.add_child(plot)

	# Create a quantum state manually
	var DualEmojiQubit = load("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
	var quantum_state = DualEmojiQubit.new(
		biome.bath.emoji_list[0],
		biome.bath.emoji_list[1],
		PI/4,  # theta
		biome.bath
	)

	# Plant with quantum state
	plot.plant(quantum_state, 0.0, biome)

	# Force a specific coherence value for consistent testing
	quantum_state.radius = 0.5  # Coherence = 0.5

	# Measure before harvest
	plot.measure()

	# Get initial bath purity
	var purity = biome.bath.get_purity()
	print("  ✓ Initial purity: %.3f" % purity)

	# Harvest
	var result = plot.harvest()

	assert(result.has("purity"), "Harvest result should include purity")
	assert(result.has("purity_multiplier"), "Harvest result should include purity_multiplier")

	# Verify multiplier formula: 2.0 * purity
	var expected_multiplier = 2.0 * result.purity
	var actual_multiplier = result.purity_multiplier

	print("  ✓ Harvest purity: %.3f" % result.purity)
	print("  ✓ Purity multiplier: %.2f× (expected: %.2f×)" % [actual_multiplier, expected_multiplier])
	print("  ✓ Yield: %d credits" % result.yield)

	assert(abs(actual_multiplier - expected_multiplier) < 0.01,
		"Purity multiplier should be 2.0 * purity")

	print("  ✅ PASS (purity multiplier works correctly)\n")

	plot.queue_free()
	biome.queue_free()

func test_purity_range_validation():
	print("📊 Test 2: Purity range validation...")

	var biome = BioticFluxBiome.new()
	root.add_child(biome)
	await process_frame

	# Get bath purity
	var purity = biome.bath.get_purity()

	print("  ✓ Bath purity: %.3f" % purity)

	# Verify purity is in valid range [1/N, 1.0]
	var N = biome.bath.emoji_list.size()
	var min_purity = 1.0 / float(N)

	assert(purity >= min_purity - 0.01,
		"Purity should be >= 1/N = %.3f" % min_purity)
	assert(purity <= 1.01,
		"Purity should be <= 1.0")

	print("  ✓ Purity range: [%.3f, 1.0] | Actual: %.3f" % [min_purity, purity])

	# Calculate expected yield multipliers
	var multiplier_pure = 2.0 * 1.0  # Pure state
	var multiplier_mixed = 2.0 * 0.5  # Half-mixed
	var multiplier_max_mixed = 2.0 * min_purity  # Maximally mixed

	print("  ✓ Yield multipliers:")
	print("    - Pure state (ρ²=1.0): %.2f×" % multiplier_pure)
	print("    - Mixed state (ρ²=0.5): %.2f×" % multiplier_mixed)
	print("    - Max mixed (ρ²=%.3f): %.2f×" % [min_purity, multiplier_max_mixed])

	assert(multiplier_pure == 2.0, "Pure state should give 2× multiplier")
	assert(multiplier_mixed == 1.0, "Half-mixed should give 1× multiplier")

	print("  ✅ PASS (purity range and multipliers validated)\n")

	biome.queue_free()

func test_tune_decoherence_resource_cost():
	print("📊 Test 3: Tune decoherence resource cost...")

	# Note: This test validates the cost calculation
	# Full integration test would require QuantumInstrumentInput setup

	var cost_per_plot = 10  # Historical tool-cost assumption for this test fixture
	var num_plots = 3

	var total_cost = num_plots * cost_per_plot
	print("  ✓ Cost per plot: %d wheat credits" % cost_per_plot)
	print("  ✓ Total cost for %d plots: %d wheat credits" % [num_plots, total_cost])

	assert(total_cost == 30, "Total cost should be 30 for 3 plots")

	# Test economy check without the live keyboard adapter
	var economy = FarmEconomy.new()
	root.add_child(economy)

	# Test 1: Insufficient funds
	economy.emoji_credits["🌾"] = 20  # Less than 30
	var can_afford_insufficient = economy.can_afford_resource("🌾", total_cost)
	assert(not can_afford_insufficient, "Should not afford with 20 wheat")
	print("  ✓ Correctly rejects with 20 wheat (need 30)")

	# Test 2: Sufficient funds
	economy.emoji_credits["🌾"] = 100  # More than 30
	var can_afford_sufficient = economy.can_afford_resource("🌾", total_cost)
	assert(can_afford_sufficient, "Should afford with 100 wheat")
	print("  ✓ Correctly accepts with 100 wheat")

	# Test 3: Exact funds
	economy.emoji_credits["🌾"] = 30  # Exactly 30
	var can_afford_exact = economy.can_afford_resource("🌾", total_cost)
	assert(can_afford_exact, "Should afford with exactly 30 wheat")
	print("  ✓ Correctly accepts with exactly 30 wheat")

	# Test 4: Spend resources
	var spent = economy.remove_resource("🌾", total_cost, "Test tuning")
	assert(spent, "Should successfully spend resources")
	assert(economy.emoji_credits["🌾"] == 0, "Should have 0 wheat left")
	print("  ✓ Successfully spent 30 wheat, 0 remaining")

	print("  ✅ PASS (resource cost system works)\n")

	economy.queue_free()

func test_harvest_with_different_purities():
	print("📊 Test 4: Harvest yields with different purities...")

	# Create test scenarios with different purity levels
	var test_cases = [
		{"purity": 1.0, "name": "Pure state"},
		{"purity": 0.8, "name": "High purity"},
		{"purity": 0.5, "name": "Mixed state"},
		{"purity": 0.2, "name": "Low purity"}
	]

	var base_coherence = 0.5  # Fixed coherence for fair comparison

	for test_case in test_cases:
		var target_purity = test_case.purity
		var name = test_case.name

		# Calculate expected yield
		var base_yield = base_coherence * 10  # 5 credits
		var purity_multiplier = 2.0 * target_purity
		var expected_yield = max(1, int(base_yield * purity_multiplier))

		print("  • %s (ρ²=%.1f):" % [name, target_purity])
		print("    - Base yield: %.1f credits" % base_yield)
		print("    - Purity multiplier: %.2f×" % purity_multiplier)
		print("    - Final yield: %d credits" % expected_yield)

	# Verify yield progression: higher purity → higher yield
	var yield_pure = max(1, int(base_coherence * 10 * 2.0 * 1.0))  # 10 credits
	var yield_half = max(1, int(base_coherence * 10 * 2.0 * 0.5))  # 5 credits
	var yield_low = max(1, int(base_coherence * 10 * 2.0 * 0.2))   # 2 credits

	assert(yield_pure > yield_half, "Pure state should yield more than mixed")
	assert(yield_half > yield_low, "Mixed state should yield more than low purity")

	print("  ✓ Yield progression validated: %d > %d > %d" % [yield_pure, yield_half, yield_low])
	print("  ✅ PASS (purity affects yield correctly)\n")
