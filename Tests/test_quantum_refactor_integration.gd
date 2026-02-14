extends SceneTree

## Quick integration test for refactored quantum system

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const BasePlot = preload("res://Core/GameMechanics/BasePlot.gd")

func _init():
	print("\n╔════════════════════════════════════════════════════════╗")
	print("║  QUANTUM REFACTOR - Integration Test                 ║")
	print("╚════════════════════════════════════════════════════════╝\n")

	test_biome_creation()
	test_plot_plant_measure_harvest()
	test_bath_evolution()

	print("\n✅ ALL INTEGRATION TESTS PASSED!\n")
	quit()

func test_biome_creation():
	print("📊 Test 1: Create BioticFlux biome with density matrix...")
	var biome = BioticFluxBiome.new()
	biome._ready()  # Manual initialization

	var bath = biome.quantum_bath
	assert(bath != null, "Quantum bath should exist")
	assert(bath.has_method("get_purity"), "Bath should have density matrix methods")

	var purity = bath.get_purity()
	print("  ✓ Biome created, bath purity = %.4f" % purity)
	assert(purity > 0.0 and purity <= 1.0, "Purity should be in (0,1]")
	print("  ✅ PASS\n")

func test_plot_plant_measure_harvest():
	print("📊 Test 2: Plant → Measure → Harvest cycle...")

	var biome = BioticFluxBiome.new()
	biome._ready()  # Manual initialization

	var plot = BasePlot.new()
	plot.grid_position = Vector2i(0, 0)

	# Plant
	plot.plant(null, 0.0, biome)
	assert(plot.is_planted, "Plot should be planted")
	assert(plot.quantum_state != null, "Plot should have quantum state")
	print("  ✓ Plot planted")

	# Check quantum state properties
	var theta = plot.quantum_state.theta
	var radius = plot.quantum_state.radius
	print("  ✓ Quantum state: θ=%.2f, r=%.3f" % [theta, radius])

	# Measure
	var outcome = plot.measure()
	assert(outcome != "", "Measurement should return an emoji")
	assert(plot.is_measured, "Plot should be marked as measured")
	print("  ✓ Measured: %s" % outcome)

	# Harvest
	var result = plot.harvest()
	assert(result.success, "Harvest should succeed")
	assert(result.outcome == outcome, "Harvest outcome should match measurement")
	assert(result.yield > 0, "Should get some yield")
	assert(not plot.is_planted, "Plot should be empty after harvest")
	print("  ✓ Harvested: %d credits from %s" % [result.yield, result.outcome])
	print("  ✅ PASS\n")

func test_bath_evolution():
	print("📊 Test 3: Bath evolution preserves trace...")

	var biome = BioticFluxBiome.new()
	biome._ready()  # Manual initialization

	var bath = biome.quantum_bath
	var initial_trace = bath.get_total_probability()
	print("  ✓ Initial trace = %.6f" % initial_trace)

	# Evolve for a few frames
	for i in range(10):
		bath.evolve(0.016)  # 60 FPS

	var final_trace = bath.get_total_probability()
	print("  ✓ After 10 frames: trace = %.6f" % final_trace)

	var trace_error = abs(final_trace - 1.0)
	assert(trace_error < 0.01, "Trace should be preserved (error = %.6f)" % trace_error)

	print("  ✅ PASS\n")
