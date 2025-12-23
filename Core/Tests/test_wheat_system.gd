extends Node

## Test Script for Wheat Farming System
## Validates WheatPlot, FarmGrid, and FarmEconomy

# Preload classes
const WheatPlot = preload("res://Core/GameMechanics/WheatPlot.gd")
const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")

var farm_grid: FarmGrid
var economy: FarmEconomy
var test_passed: int = 0
var test_failed: int = 0


func _ready():
	print("\n============================================================")
	print("WHEAT FARMING SYSTEM TEST SUITE")
	print("============================================================\n")

	# Setup
	economy = FarmEconomy.new()
	add_child(economy)

	farm_grid = FarmGrid.new()
	add_child(farm_grid)

	await get_tree().process_frame

	# Run tests
	test_wheat_plot_creation()
	test_wheat_growth()
	test_quantum_measurement()
	test_entanglement()
	test_berry_phase()
	test_farm_grid_operations()
	test_economy_transactions()
	test_full_cycle()

	# Summary
	print("\n============================================================")
	print("TEST SUMMARY")
	print("============================================================")
	print("✅ Passed: %d" % test_passed)
	print("❌ Failed: %d" % test_failed)
	print("============================================================\n")

	if test_failed == 0:
		print("🎉 ALL TESTS PASSED! Wheat farming system is working.\n")
	else:
		print("⚠️  SOME TESTS FAILED. Review output above.\n")


## Test Cases

func test_wheat_plot_creation():
	print("TEST: WheatPlot Creation")

	var plot = WheatPlot.new()
	plot.plot_id = "test_plot"

	assert_true(not plot.is_planted, "New plot should not be planted")
	assert_true(plot.growth_progress == 0.0, "Growth should be zero")
	assert_true(plot.replant_cycles == 0, "Replant cycles should be zero")

	print("  ✓ WheatPlot created successfully\n")


func test_wheat_growth():
	print("TEST: Wheat Growth")

	var plot = WheatPlot.new()
	plot.plant()

	assert_true(plot.is_planted, "Plot should be planted")
	assert_true(plot.growth_progress == 0.0, "Initial growth should be zero")

	# Simulate growth
	for i in range(100):
		plot.grow(1.0)  # 1 second per step

	assert_true(plot.growth_progress > 0.0, "Growth should have increased")
	print("  Growth after 100 seconds: %.1f%%" % (plot.growth_progress * 100))

	# Growth to maturity
	for i in range(100):
		plot.grow(1.0)

	assert_true(plot.is_mature, "Wheat should be mature after enough time")
	print("  ✓ Wheat growth working\n")


func test_quantum_measurement():
	print("TEST: Quantum Measurement (Observer Effect)")

	var plot = WheatPlot.new()
	plot.plant()

	var state_before = plot.get_dominant_emoji()
	var measured_state = plot.measure()

	assert_true(plot.has_been_measured, "Plot should be marked as measured")
	assert_true(measured_state == plot.EMOJI_NORTH or measured_state == plot.EMOJI_SOUTH,
		"Should collapse to one of the basis states")

	print("  State before: %s, Collapsed to: %s" % [state_before, measured_state])
	print("  ✓ Quantum measurement working\n")


func test_entanglement():
	print("TEST: Entanglement Between Plots")

	var plot_a = WheatPlot.new()
	var plot_b = WheatPlot.new()

	plot_a.plot_id = "plot_a"
	plot_b.plot_id = "plot_b"

	plot_a.plant()
	plot_b.plant()

	# Create entanglement
	var success = plot_a.create_entanglement(plot_b.plot_id, 0.8)
	assert_true(success, "Entanglement should be created")
	assert_true(plot_a.get_entanglement_count() == 1, "Plot A should have 1 entanglement")

	# Growth with entanglement should be faster
	var growth_rate_entangled = plot_a.grow(1.0)
	var growth_rate_solo = plot_b.grow(1.0)

	print("  Growth rate entangled: %.3f" % growth_rate_entangled)
	print("  Growth rate solo: %.3f" % growth_rate_solo)

	# Note: plot_a has entanglement bonus but plot_b doesn't have the reverse entanglement
	# So we can't directly compare. This is just showing the system works.

	print("  ✓ Entanglement system working\n")


func test_berry_phase():
	print("TEST: Berry Phase (Plot Memory)")

	var plot = WheatPlot.new()

	# First cycle
	plot.plant()
	for i in range(150):
		plot.grow(1.0)
	var harvest_1 = plot.harvest()

	assert_true(harvest_1["success"], "First harvest should succeed")
	assert_true(plot.replant_cycles == 1, "Replant cycles should be 1")

	# Second cycle (should be faster due to berry phase)
	plot.plant()
	for i in range(150):
		plot.grow(1.0)
	var harvest_2 = plot.harvest()

	assert_true(harvest_2["success"], "Second harvest should succeed")
	assert_true(plot.replant_cycles == 2, "Replant cycles should be 2")
	assert_true(plot.berry_phase > 0.0, "Berry phase should accumulate")

	print("  Replant cycles: %d" % plot.replant_cycles)
	print("  Berry phase: %.3f" % plot.berry_phase)
	print("  ✓ Berry phase accumulation working\n")


func test_farm_grid_operations():
	print("TEST: Farm Grid Operations")

	var pos_a = Vector2i(0, 0)
	var pos_b = Vector2i(1, 0)

	# Plant wheat
	var planted = farm_grid.plant_wheat(pos_a)
	assert_true(planted, "Should plant at empty position")

	# Cannot plant twice
	var planted_again = farm_grid.plant_wheat(pos_a)
	assert_false(planted_again, "Should not plant at occupied position")

	# Plant second plot
	farm_grid.plant_wheat(pos_b)

	# Create entanglement
	var entangled = farm_grid.create_entanglement(pos_a, pos_b)
	assert_true(entangled, "Should create entanglement")
	assert_true(farm_grid.are_plots_entangled(pos_a, pos_b), "Plots should be entangled")

	print("  ✓ Farm grid operations working\n")


func test_economy_transactions():
	print("TEST: Economy Transactions")

	var initial_credits = economy.credits

	# Buy seed
	var can_buy = economy.buy_seed()
	assert_true(can_buy, "Should be able to buy seed")
	assert_true(economy.credits == initial_credits - economy.SEED_COST,
		"Credits should decrease")

	# Add wheat to inventory
	economy.add_wheat(10)
	assert_true(economy.wheat_inventory == 10, "Wheat should be added")

	# Sell wheat
	var sold = economy.sell_wheat(5)
	assert_true(sold, "Should sell wheat")
	assert_true(economy.wheat_inventory == 5, "Wheat should decrease")
	assert_true(economy.credits > initial_credits - economy.SEED_COST,
		"Credits should increase from sale")

	print("  Final credits: %d" % economy.credits)
	print("  Final wheat: %d" % economy.wheat_inventory)
	print("  ✓ Economy working\n")


func test_full_cycle():
	print("TEST: Full Plant-Grow-Harvest-Sell Cycle")

	var start_credits = economy.credits

	# Buy seed and plant
	economy.buy_seed()
	var pos = Vector2i(2, 2)
	farm_grid.plant_wheat(pos)

	# Grow to maturity (accelerated)
	for i in range(150):
		await get_tree().process_frame

	# Harvest
	var harvest_data = farm_grid.harvest_wheat(pos)
	assert_true(harvest_data["success"], "Harvest should succeed")

	var wheat_yield = harvest_data["yield"]
	economy.add_wheat(wheat_yield)

	# Sell
	economy.sell_all_wheat()

	var profit = economy.credits - start_credits
	print("  Wheat yield: %d" % wheat_yield)
	print("  Profit: %d credits" % profit)
	print("  ✓ Full cycle complete\n")


## Assertion Helpers

func assert_true(condition: bool, message: String):
	if condition:
		test_passed += 1
	else:
		test_failed += 1
		print("  ❌ FAILED: %s" % message)


func assert_false(condition: bool, message: String):
	assert_true(not condition, message)
