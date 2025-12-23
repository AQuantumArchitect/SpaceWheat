#!/usr/bin/env -S godot --headless --exit-on-finish -s
extends SceneTree

## Test script to verify DebugEnvironment scenarios load correctly

const DebugEnvironment = preload("res://Core/GameState/DebugEnvironment.gd")

func _initialize():
	print("\n" + "=".repeat(80))
	print("🧪 SCENARIO LOADING TEST")
	print("=".repeat(80) + "\n")

	test_scenario("minimal")
	test_scenario("wealthy")
	test_scenario("planted")
	test_scenario("measured")
	test_scenario("entangled")
	test_scenario("mixed")
	test_scenario("icons")
	test_scenario("midgame")

	print("\n" + "=".repeat(80))
	print("✅ ALL SCENARIOS TESTED")
	print("=".repeat(80) + "\n")
	quit(0)

func test_scenario(name: String) -> void:
	print("\n" + "-".repeat(80))
	print("SCENARIO: %s" % name.to_upper())
	print("-".repeat(80))

	var state = null

	match name:
		"minimal":
			state = DebugEnvironment.minimal_farm()
		"wealthy":
			state = DebugEnvironment.wealthy_farm()
		"planted":
			state = DebugEnvironment.fully_planted_farm()
		"measured":
			state = DebugEnvironment.fully_measured_farm()
		"entangled":
			state = DebugEnvironment.fully_entangled_farm()
		"mixed":
			state = DebugEnvironment.mixed_quantum_farm()
		"icons":
			state = DebugEnvironment.icons_active_farm()
		"midgame":
			state = DebugEnvironment.mid_game_farm()
		_:
			print("❌ Unknown scenario: %s" % name)
			return

	if state == null:
		print("❌ FAILED - State is null!")
		return

	print("✅ State loaded: %s" % state.scenario_id)
	print("\n📊 ECONOMY DATA:")
	print("   Credits: %d" % state.credits)
	print("   Wheat: %d" % state.wheat_inventory)
	print("   Flour: %d" % state.flour_inventory)
	print("   Flowers: %d" % state.flower_inventory)
	print("   Labor: %d" % state.labor_inventory)

	# Count plot states
	var planted_count = 0
	var measured_count = 0
	var entangled_count = 0

	if state.plots.size() > 0:
		print("\n🌾 PLOT DATA:")
		print("   Total plots: %d" % state.plots.size())

		for plot_data in state.plots:
			if plot_data.get("is_planted", false):
				planted_count += 1
			if plot_data.get("has_been_measured", false):
				measured_count += 1
			if plot_data.get("entangled_with", []).size() > 0:
				entangled_count += 1

		print("   Planted: %d" % planted_count)
		print("   Measured: %d" % measured_count)
		print("   Entangled: %d" % entangled_count)
	else:
		print("\n🌾 PLOT DATA:")
		print("   ⚠️ No plots in state!")

	# Check for icon activation
	if state.has_method("get") or state is Resource:
		print("\n⚡ ICON ACTIVATION:")
		if "biotic_activation" in state:
			print("   Biotic: %.2f" % state.biotic_activation)
		if "chaos_activation" in state:
			print("   Chaos: %.2f" % state.chaos_activation)
		if "imperium_activation" in state:
			print("   Imperium: %.2f" % state.imperium_activation)

	# Check for goals/contracts
	if state.has_method("get") or state is Resource:
		print("\n📋 CONTRACTS & GOALS:")
		if "completed_goals" in state and state.completed_goals is Array:
			print("   Completed goals: %d" % state.completed_goals.size())
		if "active_contracts" in state and state.active_contracts is Array:
			print("   Active contracts: %d" % state.active_contracts.size())

	print("\n✅ Scenario '%s' verified successfully" % name)
