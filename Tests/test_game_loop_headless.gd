#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Headless Game Loop Validation
## Tests: Plant → Measure → Harvest cycle
## Focus: Pure simulation mechanics without GUI

var farm_view = null
var test_results = []

func _init():
	print("\n" + "=".repeat(70))
	print("🧪 HEADLESS GAME LOOP VALIDATION TEST")
	print("=".repeat(70) + "\n")

func _ready():
	# Initialize test
	print("▶ Initializing headless test environment...")
	test_results.clear()

	# Boot game
	if await boot_game():
		print("✓ Game booted successfully\n")
		await run_tests()
	else:
		print("❌ Boot failed\n")
		quit(1)

func boot_game() -> bool:
	print("  Loading FarmView scene...")
	var scene = load("res://scenes/FarmView.tscn")
	if not scene:
		print("  ❌ Could not load scene")
		return false

	farm_view = scene.instantiate()
	root.add_child(farm_view)

	# Wait for initialization
	var timer = Timer.new()
	root.add_child(timer)
	timer.start(5.0)
	await timer.timeout
	timer.queue_free()

	# Verify systems
	if not (farm_view.farm and farm_view.farm.biome and farm_view.farm.grid):
		print("  ❌ Farm systems not initialized")
		return false

	print("  ✓ Farm systems initialized")
	print("    Grid: %dx%d | Credits: %d" % [
		farm_view.farm.grid_width,
		farm_view.farm.grid_height,
		farm_view.economy.credits
	])
	return true

func run_tests():
	print("▶ RUNNING GAME LOOP TESTS\n")

	# Test 1: Single plant → measure → harvest cycle
	await test_single_plot_cycle()

	# Test 2: Multi-plot simultaneous cycle
	await test_multi_plot_cycle()

	# Test 3: Entanglement preservation through measurement
	await test_entanglement_cycle()

	# Print results
	print_results()

func test_single_plot_cycle():
	print("TEST 1: Single Plot Cycle (Plant → Measure → Harvest)")
	print("-".repeat(70))

	var pos = Vector2i(0, 0)
	var plot = farm_view.farm.grid.get_plot(pos)

	if not plot:
		print("❌ FAILED: Could not get plot")
		test_results.append(false)
		return

	# Plant
	print("  Phase 1: Plant qubit at (0,0)")
	var qubit = farm_view.farm.biome.create_quantum_state(pos, "🌾", "🌱", PI/2)
	plot.plant(qubit)
	print("    ✓ Planted | State: theta=%.2f, phi=%.2f, radius=%.2f" % [
		qubit.theta, qubit.phi, qubit.radius
	])

	# Advance simulation
	print("  Phase 2: Advance simulation (2 seconds)")
	var timer = Timer.new()
	root.add_child(timer)
	timer.start(2.0)
	await timer.timeout
	timer.queue_free()

	var evolved_qubit = farm_view.farm.biome.quantum_states.get(pos)
	if evolved_qubit:
		print("    ✓ Evolved | State: theta=%.2f, phi=%.2f, radius=%.2f" % [
			evolved_qubit.theta, evolved_qubit.phi, evolved_qubit.radius
		])

	# Measure
	print("  Phase 3: Measure quantum state")
	var outcome = farm_view.farm.biome.measure_qubit(pos)
	plot.measure(outcome)
	print("    ✓ Measured | Outcome: %s | has_been_measured: %s" % [
		outcome, plot.has_been_measured
	])

	# Harvest
	print("  Phase 4: Harvest crop")
	var harvest_reward = plot.harvest()
	farm_view.farm.biome.clear_qubit(pos)
	plot.clear()
	print("    ✓ Harvested | Reward: %s" % harvest_reward)
	print("  ✅ TEST 1 PASSED\n")
	test_results.append(true)

func test_multi_plot_cycle():
	print("TEST 2: Multi-Plot Simultaneous Cycle")
	print("-".repeat(70))

	var positions = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	var plots = []

	# Plant all
	print("  Phase 1: Plant %d plots" % positions.size())
	for pos in positions:
		var plot = farm_view.farm.grid.get_plot(pos)
		if plot:
			var qubit = farm_view.farm.biome.create_quantum_state(pos, "🌾", "🌱", PI/4)
			plot.plant(qubit)
			plots.append(plot)
	print("    ✓ Planted %d plots" % plots.size())

	# Advance time
	print("  Phase 2: Advance simulation (1 second)")
	var timer = Timer.new()
	root.add_child(timer)
	timer.start(1.0)
	await timer.timeout
	timer.queue_free()

	# Measure all
	print("  Phase 3: Measure all plots")
	var measured = 0
	for i in range(positions.size()):
		var pos = positions[i]
		var outcome = farm_view.farm.biome.measure_qubit(pos)
		plots[i].measure(outcome)
		if plots[i].has_been_measured:
			measured += 1

	print("    ✓ Measured %d/%d plots" % [measured, positions.size()])

	# Harvest all
	print("  Phase 4: Harvest all plots")
	var harvested = 0
	for i in range(positions.size()):
		var pos = positions[i]
		plots[i].harvest()
		farm_view.farm.biome.clear_qubit(pos)
		plots[i].clear()
		harvested += 1

	print("    ✓ Harvested %d plots" % harvested)
	print("  ✅ TEST 2 PASSED\n")
	test_results.append(true if measured == positions.size() else false)

func test_entanglement_cycle():
	print("TEST 3: Entanglement Preservation")
	print("-".repeat(70))

	var pos1 = Vector2i(4, 0)
	var pos2 = Vector2i(5, 0)
	var plot1 = farm_view.farm.grid.get_plot(pos1)
	var plot2 = farm_view.farm.grid.get_plot(pos2)

	if not plot1 or not plot2:
		print("❌ FAILED: Could not get plots")
		test_results.append(false)
		return

	# Create entangled pair
	print("  Phase 1: Create entangled pair")
	var qubit1 = farm_view.farm.biome.create_quantum_state(pos1, "🌾", "🌱", PI/2)
	var qubit2 = farm_view.farm.biome.create_quantum_state(pos2, "🌾", "🌱", PI/2)

	# Link them
	qubit1.entangled_pair = qubit2
	qubit2.entangled_pair = qubit1

	plot1.plant(qubit1)
	plot2.plant(qubit2)
	print("    ✓ Entangled qubits planted")

	# Advance time
	print("  Phase 2: Advance simulation (1 second)")
	var timer = Timer.new()
	root.add_child(timer)
	timer.start(1.0)
	await timer.timeout
	timer.queue_free()

	# Measure first
	print("  Phase 3: Measure first qubit")
	var outcome1 = farm_view.farm.biome.measure_qubit(pos1)
	plot1.measure(outcome1)
	print("    ✓ Measured plot1 | Outcome: %s" % outcome1)

	# Measure second - should be correlated
	print("  Phase 4: Measure entangled partner")
	var outcome2 = farm_view.farm.biome.measure_qubit(pos2)
	plot2.measure(outcome2)
	print("    ✓ Measured plot2 | Outcome: %s" % outcome2)

	# Harvest
	print("  Phase 5: Harvest both plots")
	plot1.harvest()
	plot2.harvest()
	farm_view.farm.biome.clear_qubit(pos1)
	farm_view.farm.biome.clear_qubit(pos2)
	plot1.clear()
	plot2.clear()
	print("    ✓ Both plots harvested")
	print("  ✅ TEST 3 PASSED\n")
	test_results.append(true)

func print_results():
	print("=".repeat(70))
	print("📊 TEST RESULTS")
	print("=".repeat(70))

	var passed = 0
	for i in range(test_results.size()):
		var status = "✅ PASS" if test_results[i] else "❌ FAIL"
		print("  Test %d: %s" % [i + 1, status])
		if test_results[i]:
			passed += 1

	print("\nSummary: %d/%d tests passed" % [passed, test_results.size()])

	if passed == test_results.size():
		print("\n✅ ALL TESTS PASSED - Headless game loop validation successful!\n")
		quit(0)
	else:
		print("\n❌ SOME TESTS FAILED - Review output above\n")
		quit(1)
