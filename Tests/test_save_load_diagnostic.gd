#!/usr/bin/env -S godot --headless --exit-on-finish -s
extends SceneTree

# Diagnostic test for save/load functionality
# Run with: godot --headless -s res://test_save_load_diagnostic.gd

const GameStateManager = preload("res://Core/GameState/GameStateManager.gd")
const GameState = preload("res://Core/GameState/GameState.gd")

var tests_passed = 0
var tests_failed = 0
var manager: Node = null

func _initialize():
	print("\n" + "=".repeat(60))
	print("🧪 SAVE/LOAD DIAGNOSTIC TEST")
	print("=".repeat(60) + "\n")

	# Create a GameStateManager instance
	manager = GameStateManager.new()
	root.add_child(manager)

	test_1_gamestate_creation()
	test_2_gamestate_serialization()
	test_3_save_directory_setup()
	test_4_resource_save_load()
	test_5_state_integrity()

	print("\n" + "=".repeat(60))
	print("📊 TEST SUMMARY")
	print("=".repeat(60))
	print("✅ Passed: " + str(tests_passed))
	print("❌ Failed: " + str(tests_failed))
	print()

	if tests_failed == 0:
		print("🎉 ALL TESTS PASSED - Save/Load system is healthy!")
		quit(0)
	else:
		print("⚠️  SOME TESTS FAILED - Issues found:")
		quit(1)

func test_1_gamestate_creation():
	print("\n" + "-".repeat(60))
	print("TEST 1: GameState Creation and Defaults")
	print("-".repeat(60))

	var state = GameState.new()
	if state == null:
		print("❌ GameState creation: FAILED - null returned")
		tests_failed += 1
		return

	if state.plots.size() != 25:
		print("❌ GameState creation: FAILED - Expected 25 plots, got " + str(state.plots.size()))
		tests_failed += 1
		return

	if state.credits != 20:
		print("❌ GameState creation: FAILED - Expected 20 default credits, got " + str(state.credits))
		tests_failed += 1
		return

	# Check plot structure
	for i in range(25):
		var plot = state.plots[i]
		if not plot.has("position"):
			print("❌ GameState creation: FAILED - Plot " + str(i) + " missing position")
			tests_failed += 1
			return
		if not plot.has("type"):
			print("❌ GameState creation: FAILED - Plot " + str(i) + " missing type")
			tests_failed += 1
			return
		if not plot.has("is_planted"):
			print("❌ GameState creation: FAILED - Plot " + str(i) + " missing is_planted")
			tests_failed += 1
			return

	print("✅ GameState creation: OK")
	print("   - 25 plots initialized")
	print("   - Default credits: " + str(state.credits))
	print("   - Timestamp: " + str(state.save_timestamp))
	tests_passed += 1

func test_2_gamestate_serialization():
	print("\n" + "-".repeat(60))
	print("TEST 2: GameState Property Export")
	print("-".repeat(60))

	var state = GameState.new()
	state.credits = 100
	state.scenario_id = "test_scenario"
	state.wheat_inventory = 50

	# Check all exportable properties exist
	var required_props = [
		"scenario_id", "save_timestamp", "game_time",
		"credits", "wheat_inventory", "labor_inventory", "flour_inventory", "flower_inventory",
		"tributes_paid", "tributes_failed",
		"plots", "current_goal_index", "completed_goals",
		"biotic_activation", "chaos_activation", "imperium_activation",
		"sun_moon_phase"
	]

	for prop in required_props:
		var val = state.get(prop)
		if val == null and val != 0:
			print("❌ GameState serialization: FAILED - Property " + prop + " not found")
			tests_failed += 1
			return

	print("✅ GameState serialization: OK")
	print("   - " + str(required_props.size()) + " exportable properties verified")
	tests_passed += 1

func test_3_save_directory_setup():
	print("\n" + "-".repeat(60))
	print("TEST 3: Save Directory Setup")
	print("-".repeat(60))

	var save_dir = "user://saves/"
	var dir = DirAccess.open("user://")

	if dir == null:
		print("❌ Save directory: FAILED - Could not open user directory")
		tests_failed += 1
		return

	if not dir.dir_exists("saves"):
		dir.make_dir("saves")

	if not DirAccess.dir_exists_absolute(save_dir):
		print("❌ Save directory: FAILED - Save directory not created: " + save_dir)
		tests_failed += 1
		return

	print("✅ Save directory: OK")
	print("   - Directory: " + save_dir)
	tests_passed += 1

func test_4_resource_save_load():
	print("\n" + "-".repeat(60))
	print("TEST 4: Resource Save/Load Cycle")
	print("-".repeat(60))

	# Create test state
	var original_state = GameState.new()
	original_state.credits = 777
	original_state.scenario_id = "diagnostic_test"
	original_state.wheat_inventory = 42
	# Set typed array properly (Godot 4 requirement)
	original_state.completed_goals.clear()
	original_state.completed_goals.append_array(["goal_1", "goal_2"])

	# Modify plots
	if original_state.plots.size() > 0:
		original_state.plots[0]["type"] = 1
		original_state.plots[0]["is_planted"] = true

	# Save to disk
	var test_path = "user://saves/test_diagnostic.tres"
	var result = ResourceSaver.save(original_state, test_path)
	if result != OK:
		print("❌ Resource save/load: FAILED - ResourceSaver returned " + str(result))
		tests_failed += 1
		return

	if not FileAccess.file_exists(test_path):
		print("❌ Resource save/load: FAILED - Save file not created")
		tests_failed += 1
		return

	# Load from disk
	var loaded_state = ResourceLoader.load(test_path)
	if loaded_state == null:
		print("❌ Resource save/load: FAILED - Could not load state from disk")
		tests_failed += 1
		return

	# Verify data integrity
	if loaded_state.credits != 777:
		print("❌ Resource save/load: FAILED - Credits mismatch: " + str(loaded_state.credits))
		tests_failed += 1
		return

	if loaded_state.scenario_id != "diagnostic_test":
		print("❌ Resource save/load: FAILED - Scenario mismatch: " + loaded_state.scenario_id)
		tests_failed += 1
		return

	if loaded_state.wheat_inventory != 42:
		print("❌ Resource save/load: FAILED - Wheat mismatch: " + str(loaded_state.wheat_inventory))
		tests_failed += 1
		return

	if loaded_state.plots.size() != 25:
		print("❌ Resource save/load: FAILED - Plots mismatch: " + str(loaded_state.plots.size()))
		tests_failed += 1
		return

	# Check completed goals
	if loaded_state.completed_goals.size() != 2:
		print("❌ Resource save/load: FAILED - Goals count mismatch: " + str(loaded_state.completed_goals.size()))
		tests_failed += 1
		return

	if not loaded_state.completed_goals.has("goal_1"):
		print("❌ Resource save/load: FAILED - Goal 1 not found")
		tests_failed += 1
		return

	if not loaded_state.completed_goals.has("goal_2"):
		print("❌ Resource save/load: FAILED - Goal 2 not found")
		tests_failed += 1
		return

	# Check modified plot
	if loaded_state.plots.size() > 0:
		if loaded_state.plots[0]["type"] != 1:
			print("❌ Resource save/load: FAILED - Plot type not saved")
			tests_failed += 1
			return

		if loaded_state.plots[0]["is_planted"] != true:
			print("❌ Resource save/load: FAILED - Plot planted status not saved")
			tests_failed += 1
			return

	# Clean up
	DirAccess.remove_absolute(test_path)

	print("✅ Resource save/load: OK")
	print("   - Saved: " + str(original_state.credits) + " credits, " + original_state.scenario_id + " scenario")
	print("   - Loaded: " + str(loaded_state.credits) + " credits, " + loaded_state.scenario_id + " scenario")
	print("   - Data integrity verified")
	tests_passed += 1

func test_5_state_integrity():
	print("\n" + "-".repeat(60))
	print("TEST 5: Complex State Integrity (Arrays & Entanglement)")
	print("-".repeat(60))

	var state = GameState.new()

	# Test plot entanglement
	var entangled_positions = [Vector2i(1, 1), Vector2i(2, 2)]
	state.plots[0]["entangled_with"] = entangled_positions

	# Test array types - use proper typed array methods
	state.completed_goals.clear()
	state.completed_goals.append_array(["goal_a", "goal_b", "goal_c"])

	# Save and load
	var test_path = "user://saves/test_integrity.tres"
	ResourceSaver.save(state, test_path)
	var loaded = ResourceLoader.load(test_path)

	if loaded == null:
		print("❌ State integrity: FAILED - Could not load state")
		tests_failed += 1
		return

	# Verify entanglement array
	var entangled_with = loaded.plots[0]["entangled_with"]
	if entangled_with.size() != 2:
		print("❌ State integrity: FAILED - Entanglement array size mismatch: " + str(entangled_with.size()))
		tests_failed += 1
		return

	if entangled_with[0] != Vector2i(1, 1):
		print("❌ State integrity: FAILED - Entanglement position 0 mismatch: " + str(entangled_with[0]))
		tests_failed += 1
		return

	if entangled_with[1] != Vector2i(2, 2):
		print("❌ State integrity: FAILED - Entanglement position 1 mismatch: " + str(entangled_with[1]))
		tests_failed += 1
		return

	# Verify goal array
	if loaded.completed_goals.size() != 3:
		print("❌ State integrity: FAILED - Goals array size mismatch: " + str(loaded.completed_goals.size()))
		tests_failed += 1
		return

	if loaded.completed_goals[0] != "goal_a":
		print("❌ State integrity: FAILED - Goal 0 mismatch: " + loaded.completed_goals[0])
		tests_failed += 1
		return

	# Clean up
	DirAccess.remove_absolute(test_path)

	print("✅ State integrity: OK")
	print("   - Entanglement arrays preserved")
	print("   - Completed goals arrays preserved")
	tests_passed += 1
