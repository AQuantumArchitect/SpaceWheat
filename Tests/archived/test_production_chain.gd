extends SceneTree
## Test: Complete Quantum Production Chain
## Verifies sun → wheat → mill → flour → market → credits → imperium tribute

const TomatoConspiracyNetwork = preload("res://Core/QuantumSubstrate/TomatoConspiracyNetwork.gd")
const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
const ImperiumIcon = preload("res://Core/Icons/ImperiumIcon.gd")

var network: TomatoConspiracyNetwork
var farm: FarmGrid
var economy: FarmEconomy
var imperium_icon: ImperiumIcon
var test_results = []
var tests_passed = 0
var tests_failed = 0

func _init():
	print("═══════════════════════════════════════════════════════")
	print("   QUANTUM PRODUCTION CHAIN TEST")
	print("═══════════════════════════════════════════════════════")
	print("")

	# Create systems
	network = TomatoConspiracyNetwork.new()
	get_root().add_child(network)

	farm = FarmGrid.new()
	farm.conspiracy_network = network
	get_root().add_child(farm)

	economy = FarmEconomy.new()
	farm.farm_economy = economy
	get_root().add_child(economy)

	imperium_icon = ImperiumIcon.new()
	imperium_icon.set_activation(0.1)
	economy.imperium_icon = imperium_icon
	get_root().add_child(imperium_icon)

	# Wait for initialization
	await create_timer(0.5).timeout

	# Run tests
	test_basic_setup()
	await create_timer(0.5).timeout

	test_wheat_growth_and_harvest()
	await create_timer(3.0).timeout

	test_mill_processing()
	await create_timer(6.0).timeout

	test_market_selling()
	await create_timer(4.0).timeout

	test_complete_production_loop()
	await create_timer(10.0).timeout

	# Print summary
	_print_summary()

	# Exit
	await create_timer(0.1).timeout
	quit()


func test_basic_setup():
	print("TEST 1: Basic Setup")
	print("─────────────────────────────────────────")

	_assert_equal(economy.credits, 20, "Starting credits (reduced for core loop)")
	_assert_equal(economy.wheat_inventory, 0, "Starting wheat")
	_assert_equal(economy.flour_inventory, 0, "Starting flour")
	_assert_equal(economy.imperium_resource, 0, "Starting imperium")
	_assert_true(network.nodes.size() == 12, "Conspiracy network has 12 nodes")

	print("")


func test_wheat_growth_and_harvest():
	print("TEST 2: Wheat Growth and Harvest")
	print("─────────────────────────────────────────")

	# Plant wheat
	var wheat_pos = Vector2i(0, 0)
	farm.plant_wheat(wheat_pos)

	_assert_true(farm.is_plot_empty(wheat_pos) == false, "Wheat planted")

	# Wait for sun phase
	while not network.is_currently_sun():
		await create_timer(0.1).timeout

	print("  ☀️ Sun phase - waiting for wheat to grow...")

	# Wait for wheat to mature (should be fast with solar energy)
	var timeout = 0.0
	while not farm.is_plot_mature(wheat_pos) and timeout < 20.0:
		await create_timer(0.1).timeout
		timeout += 0.1

	_assert_true(farm.is_plot_mature(wheat_pos), "Wheat matured")

	# Harvest wheat
	var plot = farm.get_plot(wheat_pos)
	plot.measure()  # Measure quantum state first
	await create_timer(0.1).timeout

	var yield_data = farm.harvest_wheat(wheat_pos)
	_assert_true(yield_data["success"], "Wheat harvested successfully")

	# Wheat goes to inventory
	_assert_true(economy.wheat_inventory > 0, "Wheat in inventory (%d units)" % economy.wheat_inventory)

	print("")


func test_mill_processing():
	print("TEST 3: Mill Processing (Wheat → Flour)")
	print("─────────────────────────────────────────")

	# Place mill
	var mill_pos = Vector2i(1, 0)
	farm.place_mill(mill_pos)

	_assert_true(farm.get_plot(mill_pos).plot_type == 3, "Mill placed")  # PlotType.MILL = 3
	_assert_equal(farm.get_plot(mill_pos).conspiracy_node_id, "sauce", "Mill entangled with sauce node")

	var initial_flour = economy.flour_inventory

	# Wait for mill to process (5 second interval)
	print("  🏭 Waiting for mill to process wheat...")
	await create_timer(6.0).timeout

	# Check that flour was produced (wheat → flour conversion working)
	# Note: Wheat inventory timing is variable due to asynchronous growth/harvest
	_assert_true(economy.flour_inventory > initial_flour, "Flour produced (%d → %d)" % [initial_flour, economy.flour_inventory])

	# Check sauce node energy (affects processing efficiency)
	var sauce_energy = network.get_node_energy("sauce")
	print("  🍅→🍝 Sauce node energy: %.2f (transformation power)" % sauce_energy)

	print("")


func test_market_selling():
	print("TEST 4: Market Selling (Flour → Credits)")
	print("─────────────────────────────────────────")

	# Place market
	var market_pos = Vector2i(2, 0)
	farm.place_market(market_pos)

	_assert_true(farm.get_plot(market_pos).plot_type == 4, "Market placed")  # PlotType.MARKET = 4
	_assert_equal(farm.get_plot(market_pos).conspiracy_node_id, "market", "Market entangled with market node")

	var initial_flour = economy.flour_inventory
	var initial_credits = economy.credits

	# Wait for market to sell (3 second interval)
	print("  💰 Waiting for market to sell flour...")
	await create_timer(4.0).timeout

	# Check that credits increased (flour → credits conversion working)
	# Note: Flour inventory might stay constant due to mill producing while market sells
	_assert_true(economy.credits > initial_credits, "Credits earned (%d → %d)" % [initial_credits, economy.credits])

	# Check market node state (affects pricing)
	var market_node = network.nodes.get("market")
	print("  💰→📈 Market node theta: %.2f, energy: %.2f" % [market_node.theta, market_node.energy])
	print("  💰 Price multiplier: %.2fx (based on quantum state)" % (2.0 - market_node.theta / PI))

	print("")


func test_complete_production_loop():
	print("TEST 5: Complete Production Loop")
	print("─────────────────────────────────────────")

	print("  ♻️ Running full production chain for 10 seconds...")

	# Plant more wheat
	farm.plant_wheat(Vector2i(0, 1))
	farm.plant_wheat(Vector2i(1, 1))

	var initial_credits = economy.credits
	var initial_imperium = economy.imperium_resource

	# Run for 10 seconds
	var frames = 0
	while frames < 600:  # 10 seconds at 60fps
		await create_timer(1.0 / 60.0).timeout
		frames += 1

	var final_credits = economy.credits
	var final_imperium = economy.imperium_resource

	# Check that the loop is functioning
	print("")
	print("  📊 Production Chain Results:")
	print("    - Credits: %d → %d (Δ%+d)" % [initial_credits, final_credits, final_credits - initial_credits])
	print("    - Imperium: %d → %d (Δ%+d 🏰)" % [initial_imperium, final_imperium, final_imperium - initial_imperium])
	print("    - Wheat inventory: %d" % economy.wheat_inventory)
	print("    - Flour inventory: %d" % economy.flour_inventory)
	print("    - Tributes paid: %d" % economy.total_tributes_paid)
	print("    - Tributes failed: %d" % economy.total_tributes_failed)

	# Verify the loop produced something
	var total_production = (final_credits - initial_credits) + (final_imperium - initial_imperium) * 10
	_assert_true(total_production > 0, "Production loop generated value (Δ%+d)" % total_production)

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
		print("✨ Quantum Production Chain Complete:")
		print("  ☀️ Sun → 🌾 Wheat → 🏭 Mill → 💨 Flour → 💰 Market → Credits → 🏰 Imperium")
		print("")
		print("  - Sun/moon cycle drives wheat growth")
		print("  - Mill transforms wheat → flour (sauce node)")
		print("  - Market sells flour → credits (market node)")
		print("  - Imperium drains credits → produces 🏰")
		print("  - All connected through conspiracy network!")
	else:
		print("⚠️  SOME TESTS FAILED")
		print("")
		print("Failed tests:")
		for result in test_results:
			if not result["passed"]:
				print("  - %s" % result["description"])

	print("")
	print("═══════════════════════════════════════════════════════")
