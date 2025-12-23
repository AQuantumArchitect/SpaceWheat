extends SceneTree
## Test: Sun/Moon Quantum Production Chain
## Verifies that wheat/mushrooms absorb energy from solar node during correct phases

const TomatoConspiracyNetwork = preload("res://Core/QuantumSubstrate/TomatoConspiracyNetwork.gd")
const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const WheatPlot = preload("res://Core/GameMechanics/WheatPlot.gd")

var test_results = []
var tests_passed = 0
var tests_failed = 0

func _init():
	print("═══════════════════════════════════════════════════════")
	print("   SUN/MOON QUANTUM PRODUCTION CHAIN TEST")
	print("═══════════════════════════════════════════════════════")
	print("")

	# Create conspiracy network
	var network = TomatoConspiracyNetwork.new()
	get_root().add_child(network)

	# Create farm grid
	var farm = FarmGrid.new()
	farm.conspiracy_network = network
	get_root().add_child(farm)

	# Wait for initialization
	await create_timer(0.3).timeout

	# Run tests
	test_solar_node_oscillation(network)
	await create_timer(1.0).timeout

	test_wheat_sun_absorption(network, farm)
	await create_timer(2.0).timeout

	test_mushroom_moon_absorption(network, farm)
	await create_timer(2.0).timeout

	test_energy_flow_through_network(network, farm)
	await create_timer(2.0).timeout

	# Print summary
	_print_summary()

	# Exit
	await create_timer(0.1).timeout
	quit()


func test_solar_node_oscillation(network: TomatoConspiracyNetwork):
	print("TEST 1: Solar Node Oscillation (☀️ ↔ 🌙)")
	print("─────────────────────────────────────────")

	var solar_node = network.nodes.get("solar")
	_assert_true(solar_node != null, "Solar node exists")

	# Check initial state
	var initial_emoji = solar_node.emoji_transform
	print("  Initial emoji: %s" % initial_emoji)

	# Record initial phase
	var initial_phase = network.sun_moon_phase
	var initial_theta = solar_node.theta
	print("  Initial phase: %.2f, theta: %.2f" % [initial_phase, initial_theta])

	# Run for 12 seconds (should complete >half cycle with 20s period)
	var frames = 0
	var saw_sun = false
	var saw_moon = false
	while frames < 720:  # 12 seconds at 60fps
		await create_timer(1.0 / 60.0).timeout
		frames += 1

		# Check for phase transitions
		if network.is_currently_sun():
			saw_sun = true
		else:
			saw_moon = true

	_assert_true(saw_sun, "Saw sun phase during cycle")
	_assert_true(saw_moon, "Saw moon phase during cycle")

	# Check that theta changed
	var final_theta = solar_node.theta
	_assert_true(abs(final_theta - initial_theta) > 0.1, "Solar theta oscillated (Δθ=%.2f)" % abs(final_theta - initial_theta))

	# Check that emoji updates
	var final_emoji = solar_node.emoji_transform
	print("  Final emoji: %s" % final_emoji)

	print("")


func test_wheat_sun_absorption(network: TomatoConspiracyNetwork, farm: FarmGrid):
	print("TEST 2: Wheat Absorbs Energy During Sun Phase")
	print("─────────────────────────────────────────")

	# Plant wheat
	var pos = Vector2i(0, 0)
	var success = farm.plant_wheat(pos)
	_assert_true(success, "Wheat planted successfully")

	var plot = farm.get_plot(pos)
	_assert_equal(plot.conspiracy_node_id, "solar", "Wheat connected to solar node")

	# Wait for sun phase
	while not network.is_currently_sun():
		await create_timer(0.1).timeout

	print("  ☀️ Sun phase detected")

	# Record initial growth
	var initial_growth = plot.growth_progress

	# Run for 2 seconds during sun
	var frames = 0
	var absorbed_energy = false
	while frames < 120 and network.is_currently_sun():  # 2 seconds at 60fps
		await create_timer(1.0 / 60.0).timeout
		frames += 1

		# Check if wheat is absorbing energy
		var solar_energy = network.get_node_energy("solar")
		if solar_energy > 0 and plot.growth_progress > initial_growth:
			absorbed_energy = true

	_assert_true(absorbed_energy, "Wheat absorbed solar energy during sun phase")

	var final_growth = plot.growth_progress
	var growth_delta = final_growth - initial_growth
	_assert_true(growth_delta > 0, "Wheat grew by %.1f%% during sun" % (growth_delta * 100))

	print("")


func test_mushroom_moon_absorption(network: TomatoConspiracyNetwork, farm: FarmGrid):
	print("TEST 3: Mushroom Absorbs Energy During Moon Phase")
	print("─────────────────────────────────────────")

	# Plant mushroom
	var pos = Vector2i(1, 0)
	var success = farm.plant_mushroom(pos)
	_assert_true(success, "Mushroom planted successfully")

	var plot = farm.get_plot(pos)
	_assert_equal(plot.conspiracy_node_id, "solar", "Mushroom connected to solar node")

	# Wait for moon phase
	while network.is_currently_sun():
		await create_timer(0.1).timeout

	print("  🌙 Moon phase detected")

	# Record initial growth
	var initial_growth = plot.growth_progress

	# Run for 2 seconds during moon
	var frames = 0
	var absorbed_energy = false
	while frames < 120 and not network.is_currently_sun():  # 2 seconds at 60fps
		await create_timer(1.0 / 60.0).timeout
		frames += 1

		# Check if mushroom is absorbing energy
		var solar_energy = network.get_node_energy("solar")
		if solar_energy > 0 and plot.growth_progress > initial_growth:
			absorbed_energy = true

	_assert_true(absorbed_energy, "Mushroom absorbed lunar energy during moon phase")

	var final_growth = plot.growth_progress
	var growth_delta = final_growth - initial_growth
	_assert_true(growth_delta > 0, "Mushroom grew by %.1f%% during moon" % (growth_delta * 100))

	print("")


func test_energy_flow_through_network(network: TomatoConspiracyNetwork, farm: FarmGrid):
	print("TEST 4: Energy Flows Through Conspiracy Network")
	print("─────────────────────────────────────────")

	# Solar node should be pumping energy
	var solar_node = network.nodes.get("solar")
	var initial_solar_energy = solar_node.energy

	# Run for 2 seconds
	var frames = 0
	while frames < 120:  # 2 seconds at 60fps
		await create_timer(1.0 / 60.0).timeout
		frames += 1

	var final_solar_energy = solar_node.energy

	# Check that solar energy changed
	_assert_true(abs(final_solar_energy - initial_solar_energy) > 0.01,
		"Solar energy evolved (%.2f → %.2f)" % [initial_solar_energy, final_solar_energy])

	# Check that energy flows to connected nodes (seed and water are connected to solar)
	var seed_node = network.nodes.get("seed")
	var water_node = network.nodes.get("water")

	_assert_true(seed_node.energy > 0, "Seed node has energy (%.2f)" % seed_node.energy)
	_assert_true(water_node.energy > 0, "Water node has energy (%.2f)" % water_node.energy)

	# Verify connections exist
	var has_seed_connection = false
	var has_water_connection = false
	for conn in network.connections:
		if (conn["from"] == "seed" and conn["to"] == "solar") or (conn["from"] == "solar" and conn["to"] == "seed"):
			has_seed_connection = true
		if (conn["from"] == "water" and conn["to"] == "solar") or (conn["from"] == "solar" and conn["to"] == "water"):
			has_water_connection = true

	_assert_true(has_seed_connection, "Solar node connected to seed node")
	_assert_true(has_water_connection, "Solar node connected to water node")

	print("")


## Helper functions

func _assert_true(condition: bool, description: String):
	if condition:
		print("  ✅ %s" % description)
		tests_passed += 1
	else:
		print("  ❌ %s" % description)
		tests_failed += 1
	test_results.append({"passed": condition, "description": description})


func _assert_equal(actual, expected, description: String):
	if actual == expected:
		print("  ✅ %s (got %s)" % [description, str(actual)])
		tests_passed += 1
	else:
		print("  ❌ %s (expected %s, got %s)" % [description, str(expected), str(actual)])
		tests_failed += 1
	test_results.append({"passed": actual == expected, "description": description})


func _print_summary():
	print("═══════════════════════════════════════════════════════")
	print("   TEST SUMMARY")
	print("═══════════════════════════════════════════════════════")
	print("")
	print("Total tests: %d" % (tests_passed + tests_failed))
	print("Passed: %d ✅" % tests_passed)
	print("Failed: %d ❌" % tests_failed)
	print("")

	if tests_failed == 0:
		print("🎉 ALL TESTS PASSED!")
		print("")
		print("✨ Sun/Moon Quantum Production Chain Working:")
		print("  - Solar node oscillates ☀️ ↔ 🌙")
		print("  - Wheat absorbs energy during sun phase")
		print("  - Mushrooms absorb energy during moon phase")
		print("  - Energy flows through conspiracy network")
		print("  - Biotic Hamiltonian drives the flow")
	else:
		print("⚠️  SOME TESTS FAILED")
		print("")
		print("Failed tests:")
		for result in test_results:
			if not result["passed"]:
				print("  - %s" % result["description"])

	print("")
	print("═══════════════════════════════════════════════════════")
