extends SceneTree

## Test plot quantum state mechanics with density matrix backend

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const BasePlot = preload("res://Core/GameMechanics/BasePlot.gd")

func _init():
	print("\n╔════════════════════════════════════════════════════════╗")
	print("║  PLOT QUANTUM MECHANICS TEST                         ║")
	print("╚════════════════════════════════════════════════════════╝\n")

	await test_plot_creation()
	await test_plot_measurement()
	await test_multiple_plots()

	print("\n✅ ALL PLOT QUANTUM MECHANICS TESTS PASSED!\n")
	quit()

func test_plot_creation():
	print("📊 Test 1: Plot creation with quantum projection...")

	var biome = BioticFluxBiome.new()
	root.add_child(biome)
	await process_frame

	# Create plot
	var plot = BasePlot.new()
	plot.grid_position = Vector2i(0, 0)

	# Plant (creates quantum projection)
	plot.plant(null, 0.0, biome)

	assert(plot.is_planted, "Plot should be planted")
	assert(plot.quantum_state != null, "Plot should have quantum state")

	print("  ✓ Plot planted at (0,0)")
	print("  ✓ Quantum state created: %s" % plot.quantum_state)

	# Check quantum state properties
	var qs = plot.quantum_state
	print("  ✓ State type: %s" % qs.get_class())

	if qs.has_method("get_north_emoji"):
		print("  ✓ North: %s" % qs.get_north_emoji())
		print("  ✓ South: %s" % qs.get_south_emoji())

	# Verify projection is tracked by biome
	assert(biome.active_projections.has(plot.grid_position),
		"Biome should track active projection")

	print("  ✅ PASS\n")
	biome.queue_free()

func test_plot_measurement():
	print("📊 Test 2: Plot measurement and harvest...")

	var biome = BioticFluxBiome.new()
	root.add_child(biome)
	await process_frame

	var plot = BasePlot.new()
	plot.grid_position = Vector2i(1, 1)

	# Plant
	plot.plant(null, 0.0, biome)
	print("  ✓ Plot planted")

	# Evolve for a bit
	for i in range(30):
		biome._process(1.0 / 60.0)

	print("  ✓ Evolved for 0.5 seconds")

	# Get state before measurement
	var qs = plot.quantum_state
	var pre_measure_state = "unknown"
	if qs.has_method("get_north_emoji"):
		pre_measure_state = "north=%s, south=%s" % [qs.get_north_emoji(), qs.get_south_emoji()]
	print("  ✓ State before measure: %s" % pre_measure_state)

	# Measure
	var outcome = plot.measure()
	assert(outcome != "", "Measurement should return an emoji")
	assert(plot.has_been_measured, "Plot should be marked as measured")
	print("  ✓ Measured outcome: %s" % outcome)

	# Harvest
	var result = plot.harvest()
	assert(result.success, "Harvest should succeed after measurement")
	assert(result.outcome == outcome, "Harvest outcome should match measurement")
	assert(result.yield > 0, "Should get positive yield")
	assert(not plot.is_planted, "Plot should be empty after harvest")

	print("  ✓ Harvested: %d credits from %s" % [result.yield, result.outcome])

	# Verify projection removed from biome
	assert(not biome.active_projections.has(plot.grid_position),
		"Projection should be removed after harvest")

	print("  ✅ PASS\n")
	biome.queue_free()

func test_multiple_plots():
	print("📊 Test 3: Multiple plots sharing quantum bath...")

	var biome = BioticFluxBiome.new()
	root.add_child(biome)
	await process_frame

	# Create multiple plots
	var plots = []
	for i in range(4):
		var plot = BasePlot.new()
		plot.grid_position = Vector2i(i % 2, i / 2)
		plot.plant(null, 0.0, biome)
		plots.append(plot)

	print("  ✓ Created 4 plots")

	# Check all projections are tracked
	assert(biome.active_projections.size() == 4,
		"Biome should track 4 projections")

	# Evolve
	for i in range(60):
		biome._process(1.0 / 60.0)

	print("  ✓ Evolved for 1 second")

	# Check bath state
	var bath = biome.bath
	var bath_purity = bath.get_purity()
	var bath_trace = bath.get_total_probability()
	print("  ✓ Bath purity = %.4f" % bath_purity)
	print("  ✓ Bath trace = %.6f" % bath_trace)

	assert(abs(bath_trace - 1.0) < 0.01, "Bath trace should be preserved")

	# Measure all plots
	var outcomes = []
	for plot in plots:
		var outcome = plot.measure()
		outcomes.append(outcome)

	print("  ✓ Measured outcomes: %s" % [", ".join(outcomes)])

	# Harvest all plots
	var total_yield = 0
	for plot in plots:
		var result = plot.harvest()
		total_yield += result.yield

	print("  ✓ Total yield from 4 plots: %d credits" % total_yield)

	# Verify all projections removed
	assert(biome.active_projections.size() == 0,
		"All projections should be removed after harvest")

	print("  ✅ PASS\n")
	biome.queue_free()
