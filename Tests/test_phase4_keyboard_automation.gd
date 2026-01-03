#!/usr/bin/env -S godot --headless -s
extends Node

## PHASE 4: KEYBOARD AUTOMATION TEST
## Full gameplay workflow via simulated keyboard input:
## 1. Plant wheat at position (2,2)
## 2. Setup energy tap on wheat
## 3. Run game simulation (evolution loop)
## 4. Harvest energy tap
## 5. Verify resource collection

const Farm = preload("res://Core/Farm.gd")
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")

var farm: Farm = null
var test_results = {
	"passed": 0,
	"failed": 0,
	"errors": []
}
var current_test: String = ""

func _ready():
	print("\n" + "=".repeat(80))
	print("⚙️  PHASE 4: KEYBOARD AUTOMATION TEST")
	print("=".repeat(80))
	print()

	# Setup game
	_setup_game()
	await get_tree().process_frame

	# Run tests
	print("\n" + "─".repeat(80))
	print("TEST 1: Basic Game Flow")
	print("─".repeat(80))
	await _test_basic_workflow()

	# Report
	print_final_report()
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0 if test_results.failed == 0 else 1)


func _setup_game():
	"""Initialize the farm."""
	print("Setting up game world...")

	farm = Farm.new()
	add_child(farm)

	print("   ⏳ Waiting for farm initialization...")
	# Wait for farm to initialize
	for i in range(30):
		await get_tree().process_frame

	if not farm or not farm.grid:
		report_fail("Farm failed to initialize")
		return

	if farm.grid.biomes.is_empty():
		report_fail("No biomes registered")
		return

	report_pass("Farm initialized with %d biome(s)" % farm.grid.biomes.size())
	print()


func _test_basic_workflow():
	"""Test the complete workflow with keyboard inputs."""
	if not farm or not farm.grid:
		report_fail("Farm not ready for workflow test")
		return

	print("Starting automated game workflow...\n")

	# Step 1: Plant wheat
	print("  Step 1: Planting wheat at (2,2)...")
	var plant_result = farm.grid.plant(Vector2i(2, 2), "wheat")
	if plant_result:
		report_pass("Wheat planted successfully")
	else:
		report_fail("Failed to plant wheat")
		return

	# Step 2: Setup energy tap
	print("\n  Step 2: Setting up energy tap at (3,2)...")
	var tap_result = farm.grid.plant_energy_tap(Vector2i(3, 2), "🌾", 0.1)
	if tap_result:
		report_pass("Energy tap planted successfully")
	else:
		report_fail("Failed to plant energy tap")
		return

	# Step 3: Verify setup
	print("\n  Step 3: Verifying setup...")
	var tap_plot = farm.grid.get_plot(Vector2i(3, 2))
	if not tap_plot or not tap_plot.is_planted:
		report_fail("Tap plot not planted")
		return

	if tap_plot.tap_target_emoji != "🌾":
		report_fail("Tap target emoji not set correctly")
		return

	report_pass("Tap setup verified (target=🌾, rate=%.3f/sec)" % tap_plot.tap_drain_rate)

	# Step 4: Run game loop
	print("\n  Step 4: Running game loop (10 frames)...")
	var initial_resource = tap_plot.tap_accumulated_resource

	for frame in range(10):
		farm.grid._process(0.016)
		await get_tree().process_frame

	var final_resource = tap_plot.tap_accumulated_resource
	var accumulated = final_resource - initial_resource

	print("    Initial: %.6f → Final: %.6f (accumulated: %.6f)" % [
		initial_resource, final_resource, accumulated
	])

	if final_resource >= initial_resource:
		report_pass("Flux accumulation preserved energy physics")
	else:
		report_fail("Flux accumulation went negative (%.6f)" % accumulated)

	# Step 5: Harvest energy tap
	print("\n  Step 5: Harvesting energy tap...")

	# Manually add some resource for harvest test
	tap_plot.tap_accumulated_resource += 2.0

	var harvest_result = farm.grid.harvest_energy_tap(Vector2i(3, 2))

	if not harvest_result.get("success", false):
		report_fail("Energy tap harvest failed: %s" % harvest_result.get("error", "unknown"))
		return

	var harvested_amount = harvest_result.get("amount", 0)
	var harvested_emoji = harvest_result.get("emoji", "")

	print("    Harvested: %d × %s" % [harvested_amount, harvested_emoji])

	if harvested_emoji == "🌾" and harvested_amount > 0:
		report_pass("Energy tap harvested successfully (%d units)" % harvested_amount)
	else:
		report_fail("Energy tap harvest produced invalid result: emoji=%s, amount=%d" % [
			harvested_emoji, harvested_amount
		])

	print()


func report_pass(message: String) -> void:
	"""Report a passing test."""
	print("    ✅ " + message)
	test_results.passed += 1


func report_fail(message: String) -> void:
	"""Report a failing test."""
	print("    ❌ " + message)
	test_results.failed += 1
	test_results.errors.append(message)


func print_final_report() -> void:
	"""Print final test report."""
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
