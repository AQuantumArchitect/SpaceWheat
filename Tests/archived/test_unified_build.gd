## test_unified_build.gd - Test unified build() system
## Verifies all build types work correctly with multi-resource costs
extends SceneTree

const GameController = preload("res://Core/GameController.gd")
const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
const Biome = preload("res://Core/Environment/Biome.gd")

var game_controller: GameController
var farm_grid: FarmGrid
var economy: FarmEconomy
var biome: Biome

var passed: int = 0
var failed: int = 0

func _initialize():
	print("\n========================================")
	print("UNIFIED BUILD() SYSTEM TESTS")
	print("========================================")

	# Setup mocks
	_setup_systems()

	# Run tests
	test_build_configs_complete()
	test_build_wheat_success()
	test_build_wheat_insufficient_funds()
	test_build_mushroom_with_labor_cost()
	test_build_mill_success()
	test_build_market_success()
	test_money_not_charged_on_failure()
	test_invalid_build_type()

	print("\n========================================")
	var result = "RESULTS: " + str(passed) + " PASSED, " + str(failed) + " FAILED"
	print(result)
	print("========================================\n")

	if failed == 0:
		print("✅ ALL UNIFIED BUILD TESTS PASSED!")
	else:
		print("❌ SOME TESTS FAILED")

	quit()


func _setup_systems():
	# Create game systems
	game_controller = GameController.new()
	farm_grid = FarmGrid.new()
	farm_grid.grid_width = 5
	farm_grid.grid_height = 5
	farm_grid.topology_analyzer = preload("res://Core/QuantumSubstrate/TopologyAnalyzer.gd").new()
	farm_grid.biome = BioticFluxBiome.new()

	economy = FarmEconomy.new()

	# Wire up game controller
	game_controller.farm_grid = farm_grid
	game_controller.economy = economy
	game_controller.quantum_graph = null
	game_controller.conspiracy_network = null

	# Setup economy with starting credits
	economy.credits = 100  # Start with 100 credits
	economy.labor_inventory = 5  # Start with 5 labor
	economy.wheat_inventory = 10  # Start with 10 wheat
	economy.flour_inventory = 5  # Start with 5 flour

	print("\n✓ Systems initialized: economy has 100💰, 5👥 labor, 10🌾 wheat, 5💨 flour")


func test_build_configs_complete():
	print("\n[TEST 1] BUILD_CONFIGS Complete")

	var required_types = ["wheat", "tomato", "mushroom", "mill", "market"]
	for build_type in required_types:
		if not GameController.BUILD_CONFIGS.has(build_type):
			failed += 1
			print("    FAIL Missing build type: %s" % build_type)
			return

		var config = GameController.BUILD_CONFIGS[build_type]
		assert_true(config.has("cost"), "Config for %s has cost" % build_type)
		assert_true(config.has("farm_method"), "Config for %s has farm_method" % build_type)
		assert_true(config.has("visual_color"), "Config for %s has visual_color" % build_type)

	print("  ✓ All 5 build types configured correctly")


func test_build_wheat_success():
	print("\n[TEST 2] Build Wheat (Success)")

	# Reset economy
	economy.credits = 100

	# Track feedback signal
	var feedback_received = false
	game_controller.action_feedback.connect(func(msg: String, success: bool):
		if success and "wheat" in msg.to_lower():
			feedback_received = true
	)

	# Attempt to plant wheat
	var initial_credits = economy.credits
	var result = game_controller.build(Vector2i(0, 0), "wheat")

	assert_true(result, "build() returned true for wheat")
	assert_equal(economy.credits, initial_credits - 5, "Wheat cost 5 credits")
	assert_true(feedback_received, "Success feedback received")

	print("  ✓ Wheat planting works, charged 5 credits")


func test_build_wheat_insufficient_funds():
	print("\n[TEST 3] Build Wheat (Insufficient Funds)")

	# Set low credits
	economy.credits = 2

	# Attempt to plant wheat with insufficient funds
	var result = game_controller.build(Vector2i(1, 0), "wheat")

	assert_true(not result, "build() returned false for insufficient funds")
	assert_equal(economy.credits, 2, "Credits unchanged when unable to afford")

	print("  ✓ Insufficient funds check works correctly")


func test_build_mushroom_with_labor_cost():
	print("\n[TEST 4] Build Mushroom (Labor Cost)")

	# Reset economy
	economy.credits = 100
	economy.labor_inventory = 5

	# Track feedback
	var feedback_received = false
	game_controller.action_feedback.connect(func(msg: String, success: bool):
		if success and "mushroom" in msg.to_lower():
			feedback_received = true
	)

	# Attempt to plant mushroom
	var initial_labor = economy.labor_inventory
	var initial_credits = economy.credits
	var result = game_controller.build(Vector2i(2, 0), "mushroom")

	assert_true(result, "build() returned true for mushroom")
	assert_equal(economy.labor_inventory, initial_labor - 1, "Mushroom cost 1 labor")
	assert_equal(economy.credits, initial_credits, "Mushroom didn't cost credits")

	print("  ✓ Mushroom costs 1 labor (not credits), credits unchanged")


func test_build_mill_success():
	print("\n[TEST 5] Build Mill (Success)")

	# Reset economy
	economy.credits = 100

	var initial_credits = economy.credits
	var result = game_controller.build(Vector2i(3, 0), "mill")

	assert_true(result, "build() returned true for mill")
	assert_equal(economy.credits, initial_credits - 10, "Mill cost 10 credits")

	print("  ✓ Mill placement works, charged 10 credits")


func test_build_market_success():
	print("\n[TEST 6] Build Market (Success)")

	# Reset economy
	economy.credits = 100

	var initial_credits = economy.credits
	var result = game_controller.build(Vector2i(4, 0), "market")

	assert_true(result, "build() returned true for market")
	assert_equal(economy.credits, initial_credits - 10, "Market cost 10 credits")

	print("  ✓ Market placement works, charged 10 credits")


func test_money_not_charged_on_failure():
	print("\n[TEST 7] Money Not Charged on Failure")

	# Reset economy
	economy.credits = 100

	# Plant wheat at (0,0)
	game_controller.build(Vector2i(0, 1), "wheat")
	var credits_after_first = economy.credits

	# Try to plant at same occupied plot - should fail
	var result = game_controller.build(Vector2i(0, 1), "wheat")

	assert_true(not result, "build() returned false for occupied plot")
	assert_equal(economy.credits, credits_after_first, "Credits unchanged after failed build on occupied plot")

	print("  ✓ Money not charged when build fails on occupied plot")


func test_invalid_build_type():
	print("\n[TEST 8] Invalid Build Type")

	# Reset economy
	economy.credits = 100

	var initial_credits = economy.credits
	var result = game_controller.build(Vector2i(0, 2), "invalid_type")

	assert_true(not result, "build() returned false for invalid type")
	assert_equal(economy.credits, initial_credits, "Credits unchanged for invalid type")

	print("  ✓ Invalid build type rejected correctly")


func assert_true(condition: bool, message: String):
	if condition:
		passed += 1
		print("    PASS " + message)
	else:
		failed += 1
		print("    FAIL " + message)


func assert_equal(actual, expected, message: String):
	if actual == expected:
		passed += 1
		print("    PASS " + message)
	else:
		failed += 1
		var msg = "FAIL " + message + " (got " + str(actual) + ", expected " + str(expected) + ")"
		print("    " + msg)
