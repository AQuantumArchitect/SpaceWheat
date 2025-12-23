#!/usr/bin/env -S godot --headless --exit-on-finish -s
extends SceneTree

## Comprehensive test for DebugEnvironment and save/load integration
## Tests all pre-built scenarios and custom state creation

const GameState = preload("res://Core/GameState/GameState.gd")
const DebugEnvironment = preload("res://Core/GameState/DebugEnvironment.gd")
const GameStateManager = preload("res://Core/GameState/GameStateManager.gd")

var tests_passed = 0
var tests_failed = 0
var manager: Node = null

func _initialize():
	print("\n" + "=".repeat(70))
	print("🧪 COMPREHENSIVE DEBUG ENVIRONMENT TEST")
	print("=".repeat(70) + "\n")

	# Create GameStateManager
	manager = GameStateManager.new()
	root.add_child(manager)

	test_minimal_farm()
	test_wealthy_farm()
	test_fully_planted_farm()
	test_fully_measured_farm()
	test_fully_entangled_farm()
	test_mixed_quantum_farm()
	test_icons_active_farm()
	test_mid_game_farm()
	test_custom_state_builder()
	test_state_persistence()
	test_state_inspection()
	test_json_export()

	print("\n" + "=".repeat(70))
	print("📊 OVERALL RESULTS")
	print("=".repeat(70))
	print("✅ Passed: " + str(tests_passed))
	print("❌ Failed: " + str(tests_failed))
	print()

	if tests_failed == 0:
		print("🎉 ALL DEBUG ENVIRONMENT TESTS PASSED!")
		quit(0)
	else:
		print("⚠️  SOME TESTS FAILED")
		quit(1)

func test_minimal_farm():
	print("\n" + "-".repeat(70))
	print("TEST 1: Minimal Farm")
	print("-".repeat(70))

	var env = DebugEnvironment.minimal_farm()

	if env == null:
		print("❌ FAILED - null returned")
		tests_failed += 1
		return

	if env.credits != 20:
		print("❌ FAILED - Expected 20 credits, got " + str(env.credits))
		tests_failed += 1
		return

	if env.wheat_inventory != 0:
		print("❌ FAILED - Expected 0 wheat, got " + str(env.wheat_inventory))
		tests_failed += 1
		return

	if env.scenario_id != "debug_minimal":
		print("❌ FAILED - Scenario not set correctly")
		tests_failed += 1
		return

	print("✅ Minimal farm: OK")
	print("   - Scenario: " + env.scenario_id)
	print("   - Credits: " + str(env.credits))
	tests_passed += 1

func test_wealthy_farm():
	print("\n" + "-".repeat(70))
	print("TEST 2: Wealthy Farm")
	print("-".repeat(70))

	var env = DebugEnvironment.wealthy_farm()

	if env.credits != 5000:
		print("❌ FAILED - Expected 5000 credits, got " + str(env.credits))
		tests_failed += 1
		return

	if env.wheat_inventory != 500:
		print("❌ FAILED - Expected 500 wheat, got " + str(env.wheat_inventory))
		tests_failed += 1
		return

	if env.flour_inventory != 200:
		print("❌ FAILED - Expected 200 flour, got " + str(env.flour_inventory))
		tests_failed += 1
		return

	print("✅ Wealthy farm: OK")
	print("   - Credits: " + str(env.credits))
	print("   - Resources: Wheat=" + str(env.wheat_inventory) + " Flour=" + str(env.flour_inventory) + " Flowers=" + str(env.flower_inventory))
	tests_passed += 1

func test_fully_planted_farm():
	print("\n" + "-".repeat(70))
	print("TEST 3: Fully Planted Farm")
	print("-".repeat(70))

	var env = DebugEnvironment.fully_planted_farm()

	var planted_count = 0
	for plot in env.plots:
		if plot["is_planted"]:
			planted_count += 1

	if planted_count != 25:
		print("❌ FAILED - Expected 25 planted, got " + str(planted_count))
		tests_failed += 1
		return

	print("✅ Fully planted farm: OK")
	print("   - Planted: " + str(planted_count) + "/25")
	tests_passed += 1

func test_fully_measured_farm():
	print("\n" + "-".repeat(70))
	print("TEST 4: Fully Measured Farm")
	print("-".repeat(70))

	var env = DebugEnvironment.fully_measured_farm()

	var measured_count = 0
	for plot in env.plots:
		if plot["has_been_measured"]:
			measured_count += 1

	if measured_count != 25:
		print("❌ FAILED - Expected 25 measured, got " + str(measured_count))
		tests_failed += 1
		return

	print("✅ Fully measured farm: OK")
	print("   - Measured: " + str(measured_count) + "/25")
	tests_passed += 1

func test_fully_entangled_farm():
	print("\n" + "-".repeat(70))
	print("TEST 5: Fully Entangled Farm")
	print("-".repeat(70))

	var env = DebugEnvironment.fully_entangled_farm()

	var entangled_count = 0
	for plot in env.plots:
		if plot["entangled_with"].size() > 0:
			entangled_count += 1

	if entangled_count < 24:  # Chain has 24 entangled (first and last have 1 each, middle have 2)
		print("❌ FAILED - Expected many entangled plots, got " + str(entangled_count))
		tests_failed += 1
		return

	print("✅ Fully entangled farm: OK")
	print("   - Entangled plots: " + str(entangled_count) + "/25")
	tests_passed += 1

func test_mixed_quantum_farm():
	print("\n" + "-".repeat(70))
	print("TEST 6: Mixed Quantum Farm")
	print("-".repeat(70))

	var env = DebugEnvironment.mixed_quantum_farm()

	# Check that we have both measured and unmeasured plots
	var measured = 0
	var unmeasured = 0
	var entangled = 0

	for plot in env.plots:
		if plot["has_been_measured"]:
			measured += 1
		else:
			unmeasured += 1
		if plot["entangled_with"].size() > 0:
			entangled += 1

	if measured == 0:
		print("❌ FAILED - No measured plots")
		tests_failed += 1
		return

	if unmeasured == 0:
		print("❌ FAILED - No unmeasured plots")
		tests_failed += 1
		return

	if entangled == 0:
		print("❌ FAILED - No entangled plots")
		tests_failed += 1
		return

	print("✅ Mixed quantum farm: OK")
	print("   - Measured: " + str(measured) + " | Unmeasured: " + str(unmeasured) + " | Entangled: " + str(entangled))
	tests_passed += 1

func test_icons_active_farm():
	print("\n" + "-".repeat(70))
	print("TEST 7: Icons Active Farm")
	print("-".repeat(70))

	var env = DebugEnvironment.icons_active_farm()

	if env.biotic_activation != 0.75:
		print("❌ FAILED - Biotic activation incorrect: " + str(env.biotic_activation))
		tests_failed += 1
		return

	if env.chaos_activation != 0.5:
		print("❌ FAILED - Chaos activation incorrect: " + str(env.chaos_activation))
		tests_failed += 1
		return

	if env.imperium_activation != 0.25:
		print("❌ FAILED - Imperium activation incorrect: " + str(env.imperium_activation))
		tests_failed += 1
		return

	print("✅ Icons active farm: OK")
	print("   - Biotic: " + str("%.2f" % env.biotic_activation))
	print("   - Chaos: " + str("%.2f" % env.chaos_activation))
	print("   - Imperium: " + str("%.2f" % env.imperium_activation))
	tests_passed += 1

func test_mid_game_farm():
	print("\n" + "-".repeat(70))
	print("TEST 8: Mid-Game Farm")
	print("-".repeat(70))

	var env = DebugEnvironment.mid_game_farm()

	var planted_count = 0
	for plot in env.plots:
		if plot["is_planted"]:
			planted_count += 1

	if planted_count != 12:
		print("❌ FAILED - Expected 12 planted, got " + str(planted_count))
		tests_failed += 1
		return

	if env.tributes_paid != 2:
		print("❌ FAILED - Expected 2 tributes paid, got " + str(env.tributes_paid))
		tests_failed += 1
		return

	if env.completed_goals.size() != 1:
		print("❌ FAILED - Expected 1 completed goal, got " + str(env.completed_goals.size()))
		tests_failed += 1
		return

	print("✅ Mid-game farm: OK")
	print("   - Credits: " + str(env.credits))
	print("   - Planted: " + str(planted_count) + "/25")
	print("   - Tributes: " + str(env.tributes_paid) + " paid")
	print("   - Goals: " + str(env.completed_goals.size()) + " completed")
	tests_passed += 1

func test_custom_state_builder():
	print("\n" + "-".repeat(70))
	print("TEST 9: Custom State Builder")
	print("-".repeat(70))

	var activation = {"biotic": 0.6, "chaos": 0.4}
	var env = DebugEnvironment.custom_state(1000, 300, 0, 0, 0, 10, 5, 2, activation)

	if env.credits != 1000:
		print("❌ FAILED - Credits: " + str(env.credits))
		tests_failed += 1
		return

	if env.wheat_inventory != 300:
		print("❌ FAILED - Wheat: " + str(env.wheat_inventory))
		tests_failed += 1
		return

	var planted_count = 0
	for plot in env.plots:
		if plot["is_planted"]:
			planted_count += 1

	if planted_count != 10:
		print("❌ FAILED - Planted count: " + str(planted_count))
		tests_failed += 1
		return

	if env.biotic_activation != 0.6:
		print("❌ FAILED - Biotic activation: " + str(env.biotic_activation))
		tests_failed += 1
		return

	print("✅ Custom state builder: OK")
	print("   - Credits: " + str(env.credits))
	print("   - Wheat: " + str(env.wheat_inventory))
	print("   - Planted: " + str(planted_count))
	print("   - Icon activation: Biotic=" + str("%.2f" % env.biotic_activation))
	tests_passed += 1

func test_state_persistence():
	print("\n" + "-".repeat(70))
	print("TEST 10: State Persistence (Save/Load)")
	print("-".repeat(70))

	var original = DebugEnvironment.wealthy_farm()
	original.scenario_id = "test_persist"

	# Save directly to disk
	var test_path = "user://saves/test_debug_persist.tres"
	var result = ResourceSaver.save(original, test_path)
	if result != OK:
		print("❌ FAILED - Could not save state")
		tests_failed += 1
		return

	# Load from disk
	var loaded = ResourceLoader.load(test_path)
	if loaded == null:
		print("❌ FAILED - Could not load state")
		tests_failed += 1
		return

	# Verify persistence
	if loaded.scenario_id != "test_persist":
		print("❌ FAILED - Scenario not persisted")
		tests_failed += 1
		return

	if loaded.credits != 5000:
		print("❌ FAILED - Credits not persisted")
		tests_failed += 1
		return

	# Clean up
	DirAccess.remove_absolute(test_path)

	print("✅ State persistence: OK")
	print("   - Saved state to disk")
	print("   - Loaded from disk")
	print("   - Data verified")
	tests_passed += 1

func test_state_inspection():
	print("\n" + "-".repeat(70))
	print("TEST 11: State Inspection")
	print("-".repeat(70))

	var env = DebugEnvironment.mixed_quantum_farm()

	# Test print_state (should not crash)
	DebugEnvironment.print_state(env)

	print("✅ State inspection: OK")
	print("   - print_state() executed successfully")
	tests_passed += 1

func test_json_export():
	print("\n" + "-".repeat(70))
	print("TEST 12: JSON Export")
	print("-".repeat(70))

	var env = DebugEnvironment.wealthy_farm()
	var json = DebugEnvironment.export_as_json(env)

	if json == null:
		print("❌ FAILED - export_as_json returned null")
		tests_failed += 1
		return

	if not json.has("scenario"):
		print("❌ FAILED - Missing scenario in JSON")
		tests_failed += 1
		return

	if not json.has("economy"):
		print("❌ FAILED - Missing economy in JSON")
		tests_failed += 1
		return

	if not json.has("plots"):
		print("❌ FAILED - Missing plots in JSON")
		tests_failed += 1
		return

	if json["economy"]["credits"] != 5000:
		print("❌ FAILED - Economy data not correct")
		tests_failed += 1
		return

	print("✅ JSON export: OK")
	print("   - Scenario: " + json["scenario"])
	print("   - Credits: " + str(json["economy"]["credits"]))
	print("   - Plots: " + str(json["plots"].size()))
	tests_passed += 1
