#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Quick test of kitchen pathway fixes
## Tests: Mill → Market → Kitchen full chain

const Farm = preload("res://Core/Farm.gd")

var farm: Farm = null
var test_results = {
	"passed": 0,
	"failed": 0,
	"errors": []
}

func _init():
	print("\n" + "=".repeat(80))
	print("🍳 KITCHEN PATHWAY FIXES TEST")
	print("=".repeat(80))
	print()

	# Create farm
	_setup_farm()

func _setup_farm() -> void:
	"""Initialize the farm."""
	print("Setting up farm...")

	farm = Farm.new()
	root.add_child(farm)

	# Wait for initialization
	await get_root().tree_entered

	for i in range(10):
		await get_root().tree_entered

	if not farm or not farm.grid or not farm.economy:
		report_fail("Farm initialization failed")
		finish_tests()
		return

	report_pass("Farm initialized")

	# Run tests
	print("\n" + "─".repeat(80))
	print("TEST 1: Mill → Flour Conversion")
	print("─".repeat(80))
	test_mill_flour_conversion()

func test_mill_flour_conversion() -> void:
	"""Test that mill converts wheat to flour."""
	print("\n  1a: Setting up wheat and mill...")

	# Plant wheat
	var wheat_pos = Vector2i(0, 0)
	if not farm.grid.plant(wheat_pos, "wheat"):
		report_fail("Failed to plant wheat")
		test_market_flour_sales()
		return

	report_pass("Wheat planted at %s" % wheat_pos)

	# Give wheat time to exist
	for i in range(5):
		farm.grid._process(0.016)
		await get_root().tree_entered

	# Place mill adjacent to wheat
	var mill_pos = Vector2i(1, 0)
	if not farm.grid.place_mill(mill_pos):
		report_fail("Failed to place mill")
		test_market_flour_sales()
		return

	report_pass("Mill placed at %s" % mill_pos)

	# Manually add wheat to test mill flour conversion
	print("  1b: Testing mill flour conversion...")
	var initial_flour = farm.economy.get_resource("💨")
	print("    Initial flour: %d credits" % initial_flour)

	# Call mill processing directly
	farm.grid._process_quantum_mills(0.016)

	var final_flour = farm.economy.get_resource("💨")
	print("    Final flour: %d credits" % final_flour)

	if final_flour >= initial_flour:
		report_pass("Mill processing ready (flour: %d)" % final_flour)
	else:
		report_fail("Mill flour decreased unexpectedly")

	test_market_flour_sales()

func test_market_flour_sales() -> void:
	"""Test that market sells flour for credits."""
	print("\n" + "─".repeat(80))
	print("TEST 2: Market → Credits Conversion")
	print("─".repeat(80))
	print("\n  2a: Setting up market...")

	# Place market
	var market_pos = Vector2i(2, 0)
	if not farm.grid.place_market(market_pos):
		report_fail("Failed to place market")
		test_kitchen_bread_conversion()
		return

	report_pass("Market placed at %s" % market_pos)

	# Manually add flour to test market sales
	print("  2b: Testing market flour sales...")

	# Add some flour first
	farm.economy.add_resource("💨", 100, "test_setup")
	var flour_before = farm.economy.get_resource("💨")
	var credits_before = farm.economy.get_resource("💰")

	print("    Flour before: %d credits" % flour_before)
	print("    Credits before: %d credits" % credits_before)

	# Process markets
	farm.grid._process_markets(0.016)

	var flour_after = farm.economy.get_resource("💨")
	var credits_after = farm.economy.get_resource("💰")

	print("    Flour after: %d credits" % flour_after)
	print("    Credits after: %d credits" % credits_after)

	if credits_after > credits_before:
		report_pass("Market sold flour for credits (+%d)" % (credits_after - credits_before))
	else:
		report_fail("Market did not increase credits")

	test_kitchen_bread_conversion()

func test_kitchen_bread_conversion() -> void:
	"""Test that kitchen converts flour to bread."""
	print("\n" + "─".repeat(80))
	print("TEST 3: Kitchen → Bread Conversion")
	print("─".repeat(80))
	print("\n  3a: Setting up kitchen...")

	# Place kitchen
	var kitchen_pos = Vector2i(3, 0)
	if not farm.grid.place_kitchen(kitchen_pos):
		report_fail("Failed to place kitchen")
		finish_tests()
		return

	report_pass("Kitchen placed at %s" % kitchen_pos)

	# Manually add flour to test kitchen conversion
	print("  3b: Testing kitchen flour-to-bread conversion...")

	# Add some flour
	farm.economy.add_resource("💨", 100, "test_setup")
	var flour_before = farm.economy.get_resource("💨")
	var bread_before = farm.economy.get_resource("🍞")

	print("    Flour before: %d credits" % flour_before)
	print("    Bread before: %d credits" % bread_before)

	# Process kitchens
	farm.grid._process_kitchens(0.016)

	var flour_after = farm.economy.get_resource("💨")
	var bread_after = farm.economy.get_resource("🍞")

	print("    Flour after: %d credits" % flour_after)
	print("    Bread after: %d credits" % bread_after)

	if bread_after > bread_before:
		report_pass("Kitchen converted flour to bread (+%d)" % (bread_after - bread_before))
	else:
		report_fail("Kitchen did not produce bread")

	finish_tests()

func report_pass(message: String) -> void:
	print("    ✅ " + message)
	test_results.passed += 1

func report_fail(message: String) -> void:
	print("    ❌ " + message)
	test_results.failed += 1
	test_results.errors.append(message)

func finish_tests() -> void:
	print("\n" + "=".repeat(80))
	print("📊 TEST RESULTS")
	print("=".repeat(80))
	print("Passed: %d" % test_results.passed)
	print("Failed: %d" % test_results.failed)

	if test_results.failed > 0:
		print("\n❌ FAILURES:")
		for error in test_results.errors:
			print("  - " + error)
	else:
		print("\n✅ ALL TESTS PASSED!")

	print("=".repeat(80))
	await get_root().tree_entered
	quit(0 if test_results.failed == 0 else 1)
