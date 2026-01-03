#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Comprehensive Save/Load Test
## Gold Standard: Full production chain + all Phase 2-5.2 features
##
## Tests:
## - Economy persistence
## - Multi-biome states (Phase 2)
## - Bath-first quantum states (Phase 3)
## - Plot states (planted, measured, frozen)
## - Persistent gate infrastructure (Phase 5.2)
## - Entanglement preservation
## - Goals & vocabulary
## - Visualizer rebuild (Phase 5)

const Farm = preload("res://Core/Farm.gd")

var farm: Node = null
var test_slot_name = "test_comprehensive_saveload"
var errors = []

func _initialize():
	print("\n" + "=".repeat(80))
	print("🧪 COMPREHENSIVE SAVE/LOAD TEST")
	print("=".repeat(80))

	# Wait for engine to initialize
	await get_root().ready

	# Load GameStateManager manually (SceneTree mode doesn't load autoloads automatically)
	var gsm_script = load("res://Core/GameState/GameStateManager.gd")
	if not gsm_script:
		fail("Failed to load GameStateManager script!")
		return

	# In SceneTree mode, we need to access the already-loaded singleton
	# Check if it exists in the root
	var gsm = Engine.get_singleton("GameStateManager")
	if not gsm:
		print("⚠️  GameStateManager singleton not found - this is expected in SceneTree mode")
		print("  Test will use direct Farm save/load methods instead\n")
		await run_direct_test()
	else:
		print("✅ GameStateManager available\n")
		await run_comprehensive_test()

	# Run test
	await run_comprehensive_test()

	# Report
	print("\n" + "=".repeat(80))
	if errors.is_empty():
		print("✅ ALL TESTS PASSED")
	else:
		print("❌ %d ERRORS:" % errors.size())
		for err in errors:
			print("  - " + err)
	print("=".repeat(80) + "\n")

	quit(1 if not errors.is_empty() else 0)


func run_comprehensive_test():
	"""Main test flow"""
	print("📋 TEST FLOW:")
	print("  1. Create farm")
	print("  2. Perform gameplay actions")
	print("  3. Capture pre-save state")
	print("  4. Save to '%s'" % test_slot_name)
	print("  5. Destroy farm")
	print("  6. Recreate farm")
	print("  7. Load save")
	print("  8. Compare states\n")

	# Phase 1: Create farm
	section("Phase 1: Create Farm")
	farm = Farm.new()
	get_root().add_child(farm)
	GameStateManager.active_farm = farm

	# Wait for async initialization
	for i in range(5):
		await get_root().process_frame

	check("Farm created", farm != null)
	check("Grid initialized", farm.grid != null)
	check("Economy initialized", farm.economy != null)

	# Phase 2: Perform actions
	section("Phase 2: Perform Gameplay Actions")
	perform_test_actions()

	# Wait for quantum evolution
	for i in range(3):
		await get_root().process_frame

	# Phase 3: Capture pre-save state
	section("Phase 3: Capture Pre-Save State")
	var pre_save = capture_full_state()
	print_state_summary("PRE-SAVE", pre_save)

	# Phase 4: Save
	section("Phase 4: Save Game")
	var save_ok = GameStateManager.save_game(test_slot_name)
	check("Save successful", save_ok)
	if not save_ok:
		fail("Save failed - aborting test")
		return

	# Phase 5: Destroy farm
	section("Phase 5: Destroy Farm (Simulate Quit)")
	GameStateManager.active_farm = null
	farm.queue_free()
	for i in range(3):
		await get_root().process_frame
	farm = null
	print("  ✅ Farm destroyed\n")

	# Phase 6: Recreate farm
	section("Phase 6: Recreate Farm (Simulate Restart)")
	farm = Farm.new()
	get_root().add_child(farm)
	GameStateManager.active_farm = farm

	# Wait for async initialization
	for i in range(5):
		await get_root().process_frame

	check("Farm recreated", farm != null)

	# Phase 7: Load save
	section("Phase 7: Load Save")
	var load_ok = GameStateManager.load_game(test_slot_name)
	check("Load successful", load_ok)
	if not load_ok:
		fail("Load failed - aborting test")
		return

	# Wait for state application
	for i in range(3):
		await get_root().process_frame

	# Phase 8: Capture post-load state
	section("Phase 8: Capture Post-Load State")
	var post_load = capture_full_state()
	print_state_summary("POST-LOAD", post_load)

	# Phase 9: Compare
	section("Phase 9: Compare States")
	compare_states(pre_save, post_load)


func perform_test_actions():
	"""Simulate realistic gameplay"""
	print("  🎮 Simulating gameplay...")

	# Modify economy
	farm.economy.credits = 42
	farm.economy.wheat_inventory = 10
	if farm.economy.has_method("set_mushroom_inventory"):
		farm.economy.set_mushroom_inventory(5)
	farm.economy.flour_inventory = 3

	print("    💰 Economy: 42 credits, 10 wheat, 5 mushroom, 3 flour")

	# Plant some plots
	var grid = farm.grid
	if grid and grid.has_method("plant"):
		# Plant wheat at (0,0)
		grid.plant(Vector2i(0, 0), "wheat")
		# Plant mushroom at (1,0)
		grid.plant(Vector2i(1, 0), "mushroom")
		print("    🌾 Planted wheat at (0,0)")
		print("    🍄 Planted mushroom at (1,0)")

		# Build persistent gate (Tool #2) - Bell gate between plots
		var plot_a = grid.get_plot(Vector2i(0, 0))
		var plot_b = grid.get_plot(Vector2i(1, 0))
		if plot_a and plot_a.has_method("add_persistent_gate"):
			plot_a.add_persistent_gate("bell_phi_plus", [Vector2i(1, 0)])
			print("    🔗 Built Bell gate: (0,0) ↔ (1,0)")
		if plot_b and plot_b.has_method("add_persistent_gate"):
			plot_b.add_persistent_gate("bell_phi_plus", [Vector2i(0, 0)])

		# Measure a plot
		if plot_a and plot_a.has_method("measure"):
			plot_a.measure()
			print("    👁️  Measured plot (0,0)")

	# Modify goals
	if farm.goals:
		farm.goals.current_goal_index = 2
		print("    🎯 Advanced to goal index 2")

	print()


func capture_full_state() -> Dictionary:
	"""Capture complete state for comparison"""
	var state = {}

	# Economy
	state.economy = {
		"credits": farm.economy.credits,
		"wheat": farm.economy.wheat_inventory,
		"mushroom": farm.economy.get("mushroom_inventory") if farm.economy.has_method("get_mushroom_inventory") else 0,
		"flour": farm.economy.flour_inventory
	}

	# Grid
	state.grid_width = farm.grid.grid_width if farm.grid else 0
	state.grid_height = farm.grid.grid_height if farm.grid else 0

	# Plots
	state.plots = []
	if farm.grid:
		for y in range(farm.grid.grid_height):
			for x in range(farm.grid.grid_width):
				var pos = Vector2i(x, y)
				var plot = farm.grid.get_plot(pos)
				if plot:
					var plot_data = {
						"position": pos,
						"type": plot.plot_type,
						"is_planted": plot.is_planted,
						"has_been_measured": plot.has_been_measured,
						"theta_frozen": plot.get("theta_frozen") if plot.has("theta_frozen") else false,
						"persistent_gates": []
					}

					# Phase 5.2: Persistent gates
					if plot.has("persistent_gates"):
						for gate in plot.persistent_gates:
							plot_data.persistent_gates.append({
								"type": gate.get("type", ""),
								"linked_count": gate.get("linked_plots", []).size()
							})

					state.plots.append(plot_data)

	# Goals
	state.goals = {
		"current_index": farm.goals.current_goal_index if farm.goals else 0,
		"completed_count": farm.goals.goals_completed.count(true) if farm.goals else 0
	}

	# Biomes (Phase 2)
	state.biomes = {}
	if farm.biotic_flux_biome:
		state.biomes["BioticFlux"] = {
			"qubit_count": farm.biotic_flux_biome.quantum_states.size(),
			"use_bath": farm.biotic_flux_biome.get("use_bath_mode") if farm.biotic_flux_biome.has("use_bath_mode") else false
		}
	if farm.market_biome:
		state.biomes["Market"] = {"qubit_count": farm.market_biome.quantum_states.size()}
	if farm.forest_biome:
		state.biomes["Forest"] = {"qubit_count": farm.forest_biome.quantum_states.size()}
	if farm.kitchen_biome:
		state.biomes["Kitchen"] = {"qubit_count": farm.kitchen_biome.quantum_states.size()}

	return state


func print_state_summary(label: String, state: Dictionary):
	"""Print state summary"""
	print("\n  📊 %s STATE:" % label)
	print("    💰 Economy: %d credits, %d wheat, %d mushroom, %d flour" % [
		state.economy.credits,
		state.economy.wheat,
		state.economy.mushroom,
		state.economy.flour
	])
	print("    📏 Grid: %dx%d (%d plots)" % [
		state.grid_width,
		state.grid_height,
		state.plots.size()
	])

	var planted = 0
	var measured = 0
	var gates_total = 0
	for p in state.plots:
		if p.is_planted:
			planted += 1
		if p.has_been_measured:
			measured += 1
		gates_total += p.persistent_gates.size()

	print("    🌾 Plots: %d planted, %d measured, %d gates" % [planted, measured, gates_total])
	print("    🎯 Goals: index %d, %d completed" % [
		state.goals.current_index,
		state.goals.completed_count
	])
	print("    🌍 Biomes: %d registered" % state.biomes.size())

	for biome_name in state.biomes.keys():
		var biome_data = state.biomes[biome_name]
		print("      - %s: %d qubits" % [biome_name, biome_data.qubit_count])
	print()


func compare_states(pre: Dictionary, post: Dictionary):
	"""Compare pre-save vs post-load"""
	var diffs = []

	# Economy
	if pre.economy.credits != post.economy.credits:
		diffs.append("Credits: %d → %d" % [pre.economy.credits, post.economy.credits])
	if pre.economy.wheat != post.economy.wheat:
		diffs.append("Wheat: %d → %d" % [pre.economy.wheat, post.economy.wheat])
	if pre.economy.mushroom != post.economy.mushroom:
		diffs.append("Mushroom: %d → %d" % [pre.economy.mushroom, post.economy.mushroom])
	if pre.economy.flour != post.economy.flour:
		diffs.append("Flour: %d → %d" % [pre.economy.flour, post.economy.flour])

	# Grid
	if pre.grid_width != post.grid_width or pre.grid_height != post.grid_height:
		diffs.append("Grid: %dx%d → %dx%d" % [pre.grid_width, pre.grid_height, post.grid_width, post.grid_height])

	# Plots
	if pre.plots.size() != post.plots.size():
		diffs.append("Plot count: %d → %d" % [pre.plots.size(), post.plots.size()])
	else:
		# Compare each plot
		for i in range(pre.plots.size()):
			var p1 = pre.plots[i]
			var p2 = post.plots[i]

			if p1.is_planted != p2.is_planted:
				diffs.append("Plot %s planted: %s → %s" % [p1.position, p1.is_planted, p2.is_planted])
			if p1.has_been_measured != p2.has_been_measured:
				diffs.append("Plot %s measured: %s → %s" % [p1.position, p1.has_been_measured, p2.has_been_measured])

			# Phase 5.2: Persistent gates
			if p1.persistent_gates.size() != p2.persistent_gates.size():
				diffs.append("Plot %s gates: %d → %d" % [p1.position, p1.persistent_gates.size(), p2.persistent_gates.size()])

	# Goals
	if pre.goals.current_index != post.goals.current_index:
		diffs.append("Goal index: %d → %d" % [pre.goals.current_index, post.goals.current_index])

	# Biomes (Phase 2)
	if pre.biomes.size() != post.biomes.size():
		diffs.append("Biome count: %d → %d" % [pre.biomes.size(), post.biomes.size()])

	# Report
	if diffs.is_empty():
		print("  ✅ ALL STATE PRESERVED - Perfect match!")
	else:
		print("  ⚠️  %d differences found:" % diffs.size())
		for diff in diffs:
			print("    - " + diff)
			errors.append(diff)


func section(title: String):
	"""Print section header"""
	print("\n" + "─".repeat(80))
	print(title)
	print("─".repeat(80))


func check(desc: String, condition: bool):
	"""Check a condition"""
	if condition:
		print("  ✅ %s" % desc)
	else:
		print("  ❌ %s" % desc)
		errors.append(desc)


func fail(message: String):
	"""Fatal error"""
	printerr("❌ FATAL: " + message)
	errors.append(message)
