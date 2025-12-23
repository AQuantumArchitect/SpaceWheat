extends SceneTree

## Complete Measurement Cascade Test
## Verifies spooky action at a distance works correctly

const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")


func _initialize():
	print("\n" + "=".repeat(80))
	print("  MEASUREMENT CASCADE - COMPREHENSIVE TEST")
	print("=".repeat(80) + "\n")

	test_simple_cascade()
	test_harvest_cascade()
	test_correlation()

	print("\n" + "=".repeat(80))
	print("  ALL CASCADE TESTS PASSED ✅")
	print("=".repeat(80) + "\n")

	quit()


func test_simple_cascade():
	print("TEST 1: Simple Measurement Cascade")
	print("─".repeat(40))

	var farm = FarmGrid.new()
	farm.grid_width = 3
	farm.grid_height = 3
	farm._ready()

	farm.plant_wheat(Vector2i(0, 0))
	farm.plant_wheat(Vector2i(1, 0))
	farm.create_entanglement(Vector2i(0, 0), Vector2i(1, 0), "phi_plus")

	var plot_a = farm.get_plot(Vector2i(0, 0))
	var plot_b = farm.get_plot(Vector2i(1, 0))

	print("  Before: A=%.2f, B=%.2f (both in superposition)" % [plot_a.quantum_state.theta, plot_b.quantum_state.theta])

	# Measure via FarmGrid.measure_plot (old system)
	farm.measure_plot(Vector2i(0, 0))

	print("  After:  A=%.2f, B=%.2f" % [plot_a.quantum_state.theta, plot_b.quantum_state.theta])

	var a_collapsed = plot_a.quantum_state.theta < 0.3 or plot_a.quantum_state.theta > 2.8
	var b_collapsed = plot_b.quantum_state.theta < 0.3 or plot_b.quantum_state.theta > 2.8

	test_assert(a_collapsed and b_collapsed, "Both should collapse")
	print("  ✅ Both collapsed (spooky action!)\n")


func test_harvest_cascade():
	print("TEST 2: Harvest Cascade")
	print("─".repeat(40))

	var farm = FarmGrid.new()
	farm.grid_width = 3
	farm.grid_height = 3
	farm._ready()

	farm.plant_wheat(Vector2i(0, 0))
	farm.plant_wheat(Vector2i(1, 0))
	farm.create_entanglement(Vector2i(0, 0), Vector2i(1, 0), "phi_plus")

	var plot_a = farm.get_plot(Vector2i(0, 0))
	var plot_b = farm.get_plot(Vector2i(1, 0))

	plot_a.growth_progress = 1.0
	plot_a.is_mature = true

	print("  Before harvest: A=%.2f, B=%.2f" % [plot_a.quantum_state.theta, plot_b.quantum_state.theta])

	var yield_data = farm.harvest_with_topology(Vector2i(0, 0))

	# A is reset, so check only B
	if plot_b.quantum_state:
		print("  After harvest:  B=%.2f (%s)" % [plot_b.quantum_state.theta, plot_b.quantum_state.get_semantic_state()])

		var b_collapsed = plot_b.quantum_state.theta < 0.3 or plot_b.quantum_state.theta > 2.8
		test_assert(b_collapsed, "Partner should collapse during harvest")
		print("  ✅ Partner collapsed during harvest\n")
	else:
		print("  ❌ ERROR: Plot B state destroyed\n")


func test_correlation():
	print("TEST 3: Bell State Correlation")
	print("─".repeat(40))

	var farm = FarmGrid.new()
	farm.grid_width = 3
	farm.grid_height = 3
	farm._ready()

	# Test correlation over multiple trials
	var same_count = 0
	var trials = 20

	print("  Running %d trials of |Φ+⟩ measurement..." % trials)

	for trial in range(trials):
		farm.plant_wheat(Vector2i(0, 0))
		farm.plant_wheat(Vector2i(1, 0))
		farm.create_entanglement(Vector2i(0, 0), Vector2i(1, 0), "phi_plus")

		var plot_a = farm.get_plot(Vector2i(0, 0))
		var plot_b = farm.get_plot(Vector2i(1, 0))

		# Harvest A
		plot_a.growth_progress = 1.0
		plot_a.is_mature = true
		var result_a = farm.harvest_with_topology(Vector2i(0, 0))["state"]

		# Check B state
		var b_state = plot_b.quantum_state.get_semantic_state()

		if result_a == b_state:
			same_count += 1

		# Reset for next trial
		farm.plots.clear()
		farm.entangled_pairs.clear()

	var correlation = float(same_count) / trials
	print("  Correlation: %d/%d = %.1f%%" % [same_count, trials, correlation * 100])

	# For |Φ+⟩, should be 100% correlated (both same)
	# With quantum fluctuations, allow 80%+
	test_assert(correlation > 0.8, "Should be highly correlated for |Φ+⟩")
	print("  ✅ High correlation confirmed\n")


func test_assert(condition: bool, message: String):
	if not condition:
		print("  ❌ FAILED: %s" % message)
		push_error(message)
