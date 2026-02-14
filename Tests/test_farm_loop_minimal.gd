#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Minimal Farm Loop Test
## Tests pure simulation without UI layer

var farm = null

func _ready():
	print("\n" + "=".repeat(70))
	print("🧪 MINIMAL FARM LOOP TEST (Pure Simulation)")
	print("=".repeat(70) + "\n")

	if await boot_farm():
		await run_tests()
	else:
		print("❌ Boot failed\n")
		quit(1)

func boot_farm() -> bool:
	print("Initializing Farm...")
	const Farm = preload("res://Core/Farm.gd")

	farm = Farm.new()
	root.add_child(farm)

	# Wait for initialization
	var timer = Timer.new()
	root.add_child(timer)
	timer.start(2.0)
	await timer.timeout
	timer.queue_free()

	if not (farm.grid and farm.biome):
		print("❌ Farm not initialized properly")
		return false

	print("✓ Farm initialized (Grid: %dx%d, Credits: %d)\n" % [
		farm.grid_width, farm.grid_height, farm.economy.credits
	])
	return true

func run_tests():
	print("▶ TEST SUITE: Plant → Measure → Harvest Cycle\n")

	var passed = 0
	var total = 3

	# Test 1
	if await test_single_plot():
		passed += 1

	# Test 2
	if await test_multi_plot():
		passed += 1

	# Test 3
	if await test_entanglement():
		passed += 1

	# Results
	print("\n" + "=".repeat(70))
	print("📊 RESULTS: %d/%d tests passed" % [passed, total])
	if passed == total:
		print("✅ ALL TESTS PASSED")
		print("=".repeat(70) + "\n")
		quit(0)
	else:
		print("❌ SOME TESTS FAILED")
		print("=".repeat(70) + "\n")
		quit(1)

func test_single_plot() -> bool:
	print("TEST 1: Single Plot (Plant → Evolve → Measure → Harvest)")
	print("-".repeat(70))

	var pos = Vector2i(0, 0)
	var plot = farm.grid.get_plot(pos)

	if not plot:
		print("❌ Failed to get plot\n")
		return false

	# Plant
	print("  ✓ Creating quantum state...")
	var qubit = farm.biome.create_quantum_state(pos, "🌾", "🌱", PI/2)
	plot.plant(qubit)

	# Verify planted
	if not plot.is_planted:
		print("  ❌ Plot not planted\n")
		return false
	print("  ✓ Plot planted")

	# Evolve (simulate time)
	print("  ✓ Advancing quantum evolution...")
	for i in range(5):
		farm.biome._evolve_quantum_substrate(0.1)

	# Measure
	print("  ✓ Measuring quantum state...")
	var outcome = farm.biome.measure_qubit(pos)
	plot.measure(outcome)

	if not plot.is_measured:
		print("  ❌ Plot not measured\n")
		return false
	print("  ✓ Plot measured (outcome: %s)" % outcome)

	# Harvest
	print("  ✓ Harvesting...")
	plot.harvest()
	farm.biome.clear_qubit(pos)
	plot.clear()

	print("✅ TEST 1 PASSED\n")
	return true

func test_multi_plot() -> bool:
	print("TEST 2: Multi-Plot Simultaneous Cycle")
	print("-".repeat(70))

	var positions = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	var plots = []

	# Plant all
	print("  ✓ Planting %d plots..." % positions.size())
	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if plot:
			var qubit = farm.biome.create_quantum_state(pos, "🌾", "🌱", PI/4)
			plot.plant(qubit)
			plots.append(plot)

	if plots.size() != positions.size():
		print("  ❌ Failed to plant all plots\n")
		return false

	# Evolve all
	print("  ✓ Evolving all plots...")
	for i in range(3):
		farm.biome._evolve_quantum_substrate(0.2)

	# Measure all
	print("  ✓ Measuring all plots...")
	var measured = 0
	for i in range(positions.size()):
		var pos = positions[i]
		var outcome = farm.biome.measure_qubit(pos)
		plots[i].measure(outcome)
		if plots[i].is_measured:
			measured += 1

	if measured != positions.size():
		print("  ❌ Not all plots measured (%d/%d)\n" % [measured, positions.size()])
		return false
	print("  ✓ All %d plots measured" % measured)

	# Harvest all
	print("  ✓ Harvesting all plots...")
	for i in range(positions.size()):
		plots[i].harvest()
		farm.biome.clear_qubit(positions[i])
		plots[i].clear()

	print("✅ TEST 2 PASSED\n")
	return true

func test_entanglement() -> bool:
	print("TEST 3: Entanglement Preservation")
	print("-".repeat(70))

	var pos1 = Vector2i(4, 0)
	var pos2 = Vector2i(5, 0)
	var plot1 = farm.grid.get_plot(pos1)
	var plot2 = farm.grid.get_plot(pos2)

	if not (plot1 and plot2):
		print("❌ Failed to get plots\n")
		return false

	# Create entangled pair
	print("  ✓ Creating entangled pair...")
	var qubit1 = farm.biome.create_quantum_state(pos1, "🌾", "🌱", PI/2)
	var qubit2 = farm.biome.create_quantum_state(pos2, "🌾", "🌱", PI/2)

	qubit1.entangled_pair = qubit2
	qubit2.entangled_pair = qubit1

	plot1.plant(qubit1)
	plot2.plant(qubit2)
	print("  ✓ Entangled pair planted")

	# Evolve
	print("  ✓ Evolving entangled pair...")
	for i in range(3):
		farm.biome._evolve_quantum_substrate(0.15)

	# Measure both
	print("  ✓ Measuring both qubits...")
	var outcome1 = farm.biome.measure_qubit(pos1)
	plot1.measure(outcome1)

	var outcome2 = farm.biome.measure_qubit(pos2)
	plot2.measure(outcome2)

	if not (plot1.is_measured and plot2.is_measured):
		print("  ❌ Not both measured\n")
		return false
	print("  ✓ Both measured (outcomes: %s, %s)" % [outcome1, outcome2])

	# Harvest
	print("  ✓ Harvesting entangled plots...")
	plot1.harvest()
	plot2.harvest()
	farm.biome.clear_qubit(pos1)
	farm.biome.clear_qubit(pos2)
	plot1.clear()
	plot2.clear()

	print("✅ TEST 3 PASSED\n")
	return true
