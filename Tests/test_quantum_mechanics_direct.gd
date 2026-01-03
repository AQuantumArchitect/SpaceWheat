extends SceneTree

## Direct test of quantum mechanics (no UI dependencies)

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const BasePlot = preload("res://Core/GameMechanics/BasePlot.gd")

func _init():
	print("\n╔════════════════════════════════════════════════════════╗")
	print("║  QUANTUM MECHANICS - Direct Test                     ║")
	print("╚════════════════════════════════════════════════════════╝\n")

	test_bath_initialization()
	test_quantum_evolution()
	test_plot_mechanics()

	print("\n✅ ALL DIRECT QUANTUM TESTS PASSED!\n")
	quit()

func test_bath_initialization():
	print("📊 Test 1: Bath initialization with density matrix...")

	var biome = BioticFluxBiome.new()
	root.add_child(biome)  # Add to tree to trigger _ready()

	await process_frame  # Let _ready() complete

	var bath = biome.quantum_bath
	assert(bath != null, "Quantum bath should exist")

	# Check density matrix methods
	assert(bath.has_method("get_purity"), "Bath should have get_purity()")
	assert(bath.has_method("get_entropy"), "Bath should have get_entropy()")

	var purity = bath.get_purity()
	var entropy = bath.get_entropy()

	print("  ✓ Bath created successfully")
	print("  ✓ Purity = %.4f (1.0 = pure, <1.0 = mixed)" % purity)
	print("  ✓ Entropy = %.4f (0.0 = pure, >0 = mixed)" % entropy)

	# Pure state should have purity ≈ 1.0
	assert(purity > 0.95, "Initial state should be nearly pure (purity=%.4f)" % purity)
	print("  ✅ PASS\n")

	biome.queue_free()

func test_quantum_evolution():
	print("📊 Test 2: Quantum evolution preserves physics...")

	var biome = BioticFluxBiome.new()
	root.add_child(biome)
	await self.process_frame

	var bath = biome.quantum_bath

	# Get initial state
	var initial_trace = bath.get_total_probability()
	var initial_purity = bath.get_purity()

	print("  ✓ Initial trace = %.6f (should be 1.0)" % initial_trace)
	print("  ✓ Initial purity = %.6f" % initial_purity)

	# Evolve for several frames
	for i in range(20):
		biome._process(0.016)  # 60 FPS

	var final_trace = bath.get_total_probability()
	var final_purity = bath.get_purity()

	print("  ✓ After 20 frames:")
	print("    Trace = %.6f (error = %.8f)" % [final_trace, abs(final_trace - 1.0)])
	print("    Purity = %.6f (change = %.6f)" % [final_purity, final_purity - initial_purity])

	# Trace must be preserved
	var trace_error = abs(final_trace - 1.0)
	assert(trace_error < 0.01, "Trace preservation failed (error=%.8f)" % trace_error)

	# Purity should decrease (Lindblad dissipation) or stay same
	assert(final_purity <= initial_purity + 0.01, "Purity increased unexpectedly")

	print("  ✅ PASS\n")

	biome.queue_free()

func test_plot_mechanics():
	print("📊 Test 3: Plot quantum state mechanics...")

	var biome = BioticFluxBiome.new()
	root.add_child(biome)
	await self.process_frame

	var plot = BasePlot.new()
	plot.grid_position = Vector2i(0, 0)
	biome.add_child(plot)

	# Plant
	plot.plant(null, 0.0, biome)
	assert(plot.is_planted, "Plot should be planted")
	assert(plot.quantum_state != null, "Plot should have quantum state")
	print("  ✓ Plot planted successfully")

	# Check quantum state structure
	var qs = plot.quantum_state
	print("  ✓ Quantum state type: %s" % qs.get_class())
	print("  ✓ North emoji: %s" % qs.north_emoji)
	print("  ✓ South emoji: %s" % qs.south_emoji)

	# Check if we can get projections
	if qs.has_method("get_theta"):
		var theta = qs.get_theta()
		print("  ✓ θ = %.2f rad" % theta)

	# Evolve the biome (and thus the plot's quantum state)
	for i in range(10):
		biome._process(0.016)

	print("  ✓ Quantum state evolved for 10 frames")

	# Measure
	var outcome = plot.measure()
	assert(outcome != "", "Measurement should return an emoji")
	assert(plot.has_been_measured, "Plot should be marked as measured")
	print("  ✓ Measured outcome: %s" % outcome)

	# Harvest
	var result = plot.harvest()
	assert(result.success, "Harvest should succeed")
	assert(result.outcome == outcome, "Harvest should match measurement")
	assert(result.yield > 0, "Should get positive yield")
	assert(not plot.is_planted, "Plot should be empty after harvest")

	print("  ✓ Harvested: %d credits from %s" % [result.yield, result.outcome])
	print("  ✅ PASS\n")

	biome.queue_free()
