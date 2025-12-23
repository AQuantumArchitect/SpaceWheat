extends Node

## Headless UI Test - Simulates Player Actions
## Tests every button, every interaction, validates core gameplay loop

var test_passed: int = 0
var test_failed: int = 0
var farm_view: Node = null


func _ready():
	print("\n============================================================")
	print("UI SYSTEM HEADLESS TEST SUITE")
	print("Testing core gameplay loop by simulating player actions")
	print("============================================================\n")

	# Load and instantiate FarmView
	var farm_scene = load("res://scenes/FarmView.tscn")
	farm_view = farm_scene.instantiate()
	add_child(farm_view)

	# Wait for initialization
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout

	# Run test suite
	test_initial_state()
	await test_plant_wheat()
	await test_growth_and_harvest()
	await test_sell_wheat()
	await test_entanglement()
	await test_measurement()
	await test_goal_progression()
	await test_full_game_loop()

	# Summary
	print("\n============================================================")
	print("TEST SUMMARY")
	print("============================================================")
	print("✅ Passed: %d" % test_passed)
	print("❌ Failed: %d" % test_failed)
	print("============================================================\n")

	if test_failed == 0:
		print("🎉 ALL UI TESTS PASSED! Game is ready to play.\n")
		get_tree().quit(0)  # Exit success
	else:
		print("⚠️  SOME TESTS FAILED. Review output above.\n")
		get_tree().quit(1)  # Exit with error


## Assertion Helpers

func assert_true(condition: bool, message: String):
	if condition:
		test_passed += 1
		print("  ✓ " + message)
	else:
		test_failed += 1
		print("  ✗ FAILED: " + message)


func assert_equals(actual, expected, message: String):
	if actual == expected:
		test_passed += 1
		print("  ✓ " + message)
	else:
		test_failed += 1
		print("  ✗ FAILED: %s (expected %s, got %s)" % [message, str(expected), str(actual)])


## Test Cases

func test_initial_state():
	print("TEST: Initial Game State")

	# Check economy
	assert_equals(farm_view.economy.credits, 100, "Starting credits should be 100")
	assert_equals(farm_view.economy.wheat_inventory, 0, "Starting wheat should be 0")

	# Check grid
	assert_equals(farm_view.farm_grid.grid_width, 5, "Grid width should be 5")
	assert_equals(farm_view.farm_grid.grid_height, 5, "Grid height should be 5")

	# Check goals
	assert_true(farm_view.goals != null, "Goals system should exist")

	# Check buttons exist
	assert_true(farm_view.plant_button != null, "Plant button should exist")
	assert_true(farm_view.harvest_button != null, "Harvest button should exist")
	assert_true(farm_view.sell_wheat_button != null, "Sell wheat button should exist")
	assert_true(farm_view.entangle_button != null, "Entangle button should exist")

	print("")


func test_plant_wheat():
	print("TEST: Plant Wheat")

	# Select a plot
	var test_pos = Vector2i(1, 1)
	farm_view._select_plot(test_pos)

	assert_equals(farm_view.selected_position, test_pos, "Plot should be selected")

	# Plant button should be enabled
	assert_true(not farm_view.plant_button.disabled, "Plant button should be enabled")

	# Plant wheat
	var credits_before = farm_view.economy.credits
	farm_view._on_plant_pressed()

	await get_tree().process_frame

	# Check results
	var plot = farm_view.farm_grid.get_plot(test_pos)
	assert_true(plot.is_planted, "Plot should be planted")
	assert_equals(farm_view.economy.credits, credits_before - 5, "Credits should decrease by 5")
	assert_true(plot.quantum_state != null, "Quantum state should be created")

	print("")


func test_growth_and_harvest():
	print("TEST: Growth and Harvest")

	var test_pos = Vector2i(1, 1)
	var plot = farm_view.farm_grid.get_plot(test_pos)

	# Simulate growth to maturity (10% per second = ~10 seconds)
	print("  Simulating growth to maturity...")
	await get_tree().create_timer(12.0).timeout  # 12 seconds for safety

	assert_true(plot.is_mature, "Plot should be mature")

	# Measure plot (required before harvest)
	farm_view._select_plot(test_pos)
	farm_view._on_measure_pressed()
	await get_tree().process_frame

	assert_true(plot.has_been_measured, "Plot should be measured before harvest")
	assert_true(not farm_view.harvest_button.disabled, "Harvest button should be enabled after measurement")

	# Harvest
	var wheat_before = farm_view.economy.wheat_inventory
	farm_view._on_harvest_pressed()

	await get_tree().process_frame

	assert_true(farm_view.economy.wheat_inventory > wheat_before, "Wheat inventory should increase")
	assert_true(not plot.is_planted, "Plot should be empty after harvest")

	print("")


func test_sell_wheat():
	print("TEST: Sell Wheat")

	var wheat_count = farm_view.economy.wheat_inventory
	var credits_before = farm_view.economy.credits

	# Sell wheat
	assert_true(not farm_view.sell_wheat_button.disabled, "Sell button should be enabled")
	farm_view._on_sell_wheat_pressed()

	await get_tree().process_frame

	assert_equals(farm_view.economy.wheat_inventory, 0, "Wheat should be sold")
	assert_true(farm_view.economy.credits > credits_before, "Credits should increase")
	assert_equals(farm_view.economy.credits, credits_before + wheat_count * 2, "Correct sell price")

	print("")


func test_entanglement():
	print("TEST: Entanglement System")

	# Plant two adjacent plots
	var pos_a = Vector2i(2, 2)
	var pos_b = Vector2i(2, 3)

	farm_view._select_plot(pos_a)
	farm_view._on_plant_pressed()
	await get_tree().process_frame

	farm_view._select_plot(pos_b)
	farm_view._on_plant_pressed()
	await get_tree().process_frame

	# Create entanglement
	farm_view._select_plot(pos_a)
	assert_true(not farm_view.entangle_button.disabled, "Entangle button should be enabled")

	farm_view._on_entangle_pressed()
	await get_tree().process_frame

	assert_true(farm_view.entangle_mode, "Should enter entangle mode")

	# Click second plot
	farm_view._on_tile_clicked(pos_b)
	await get_tree().process_frame

	# Check entanglement created
	var plot_a = farm_view.farm_grid.get_plot(pos_a)
	var plot_b = farm_view.farm_grid.get_plot(pos_b)

	assert_true(plot_a.get_entanglement_count() > 0, "Plot A should be entangled")
	assert_true(plot_b.get_entanglement_count() > 0, "Plot B should be entangled")

	print("")


func test_measurement():
	print("TEST: Quantum Measurement")

	# Use an already planted plot
	var pos = Vector2i(2, 2)
	var plot = farm_view.farm_grid.get_plot(pos)

	if not plot.is_planted:
		farm_view._select_plot(pos)
		farm_view._on_plant_pressed()
		await get_tree().process_frame

	# Measure
	farm_view._select_plot(pos)
	assert_true(not farm_view.measure_button.disabled, "Measure button should be enabled")

	farm_view._on_measure_pressed()
	await get_tree().process_frame

	assert_true(plot.has_been_measured, "Plot should be measured")

	print("")


func test_goal_progression():
	print("TEST: Goal Progression")

	var goals = farm_view.goals

	# Check first goal (should be first harvest - already completed in earlier tests)
	var first_goal = goals.goals[0]
	print("  First goal: " + first_goal["title"])
	print("  Progress: " + goals.get_goal_progress_text(first_goal, farm_view.economy.credits))

	# Goals should be tracking
	assert_true(goals.progress["harvest_count"] > 0, "Harvest count should be tracked")

	print("")


func test_full_game_loop():
	print("TEST: Complete Game Loop")

	var starting_credits = farm_view.economy.credits

	# Plant multiple plots
	var plots_to_plant = [Vector2i(3, 3), Vector2i(3, 4), Vector2i(4, 3)]

	for pos in plots_to_plant:
		if farm_view.economy.can_afford(5):
			farm_view._select_plot(pos)
			farm_view._on_plant_pressed()
			await get_tree().process_frame

	# Wait for growth
	print("  Simulating multiple plot growth...")
	await get_tree().create_timer(12.0).timeout  # 12 seconds for safety

	# Measure and harvest all
	var total_harvested = 0
	for pos in plots_to_plant:
		var plot = farm_view.farm_grid.get_plot(pos)
		if plot.is_mature:
			# Measure first (required for harvest)
			farm_view._select_plot(pos)
			farm_view._on_measure_pressed()
			await get_tree().process_frame

			# Then harvest
			farm_view._on_harvest_pressed()
			total_harvested += 1
			await get_tree().process_frame

	assert_true(total_harvested > 0, "Should harvest at least one plot")

	# Sell all wheat
	if farm_view.economy.wheat_inventory > 0:
		farm_view._on_sell_wheat_pressed()
		await get_tree().process_frame

	# Check profitability
	var final_credits = farm_view.economy.credits
	assert_true(final_credits >= starting_credits, "Should be profitable (or break even)")

	print("  Starting credits: %d" % starting_credits)
	print("  Final credits: %d" % final_credits)
	print("  Net profit: %d" % (final_credits - starting_credits))

	print("")
