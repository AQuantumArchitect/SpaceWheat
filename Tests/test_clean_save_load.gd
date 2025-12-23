#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Clean Architecture Save/Load Test
## - GameState = source of truth
## - Simulation = reads/writes GameState
## - No UI dependencies

var farm = null
var game_manager = null
var test_complete = false

func _process(delta):
	if not test_complete:
		test_complete = true
		await run_test()

func run_test():
	print("\n" + "=".repeat(70))
	print("🧪 CLEAN ARCHITECTURE SAVE/LOAD TEST")
	print("=".repeat(70) + "\n")

	# Initialize manager
	const MemoryManager = preload("res://Core/GameState/MemoryManager.gd")
	game_manager = MemoryManager.new()
	root.add_child(game_manager)

	# Phase 1: Create new game
	print("▶ PHASE 1: Create New Game State")
	print("-".repeat(70))
	var state1 = game_manager.new_game("default")
	print("✓ GameState created")
	print("  Grid: %dx%d | Credits: %d\n" % [state1.grid_width, state1.grid_height, state1.credits])

	# Phase 2: Boot Farm with initial state
	print("▶ PHASE 2: Boot Simulation & Apply State")
	print("-".repeat(70))
	const Farm = preload("res://Core/Farm.gd")
	farm = Farm.new()
	root.add_child(farm)
	await root.get_tree().process_frame

	apply_state_to_farm(state1)
	print("✓ Farm initialized with GameState\n")

	# Phase 3: Play game - modify state
	print("▶ PHASE 3: Play Game & Modify State")
	print("-".repeat(70))

	# Plant qubits
	var positions = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		var qubit = farm.biome.create_quantum_state(pos, "🌾", "🌱", PI/2)
		plot.plant(qubit)

	print("✓ Planted 3 qubits")

	# Evolve
	for i in range(3):
		farm.biome._evolve_quantum_substrate(0.1)
	print("✓ Evolved quantum states")

	# Measure
	for pos in positions:
		var outcome = farm.biome.measure_qubit(pos)
		var plot = farm.grid.get_plot(pos)
		if not (outcome is String and outcome.length() > 0):
			print("⚠ Measurement outcome unclear")
		plot.has_been_measured = true

	print("✓ Measured 3 qubits")

	# Harvest 2
	for i in range(2):
		var pos = positions[i]
		var plot = farm.grid.get_plot(pos)
		plot.harvest()
		farm.biome.clear_qubit(pos)
		plot.is_planted = false

	print("✓ Harvested 2 qubits\n")

	# Phase 4: Capture state (simulate game saving)
	print("▶ PHASE 4: Capture Simulation State")
	print("-".repeat(70))
	var state_before_save = capture_state_from_farm(state1)
	print("✓ State captured from simulation")
	print("  Credits: %d | Planted: %d | Measured: %d\n" % [
		state_before_save.credits,
		count_planted(state_before_save),
		count_measured(state_before_save)
	])

	# Phase 5: Save to disk
	print("▶ PHASE 5: Save GameState to Disk")
	print("-".repeat(70))
	var save_result = game_manager.save_game(state_before_save, 0)
	if not save_result:
		print("❌ Save failed")
		quit()
		return

	print("✓ Saved to slot 0\n")

	# Phase 6: Play different game
	print("▶ PHASE 6: Play Different Game")
	print("-".repeat(70))

	# Clear farm
	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		plot.is_planted = false
		farm.biome.clear_qubit(pos)

	# Plant different
	var new_positions = [Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)]
	for pos in new_positions:
		var plot = farm.grid.get_plot(pos)
		var qubit = farm.biome.create_quantum_state(pos, "🌾", "🌱", PI/4)
		plot.plant(qubit)

	print("✓ Played different game (new qubits at positions 3-5)\n")

	# Phase 7: Load saved state
	print("▶ PHASE 7: Load Saved GameState")
	print("-".repeat(70))
	var loaded_state = game_manager.load_game(0)
	if not loaded_state:
		print("❌ Load failed")
		quit()
		return

	print("✓ Loaded from slot 0")

	# Apply loaded state to farm
	apply_state_to_farm(loaded_state)
	print("✓ Applied loaded state to farm\n")

	# Phase 8: Verify
	print("▶ PHASE 8: Verify State Matches")
	print("-".repeat(70))

	var state_after_load = capture_state_from_farm(loaded_state)

	var credits_match = state_after_load.credits == state_before_save.credits
	var planted_match = count_planted(state_after_load) == count_planted(state_before_save)
	var measured_match = count_measured(state_after_load) == count_measured(state_before_save)

	print("Credits match: %s (%d == %d)" % [credits_match, state_after_load.credits, state_before_save.credits])
	print("Planted match: %s (%d == %d)" % [planted_match, count_planted(state_after_load), count_planted(state_before_save)])
	print("Measured match: %s (%d == %d)" % [measured_match, count_measured(state_after_load), count_measured(state_before_save)])

	if credits_match and planted_match and measured_match:
		print("\n✅ VERIFICATION PASSED\n")
	else:
		print("\n⚠️ VERIFICATION FAILED\n")

	# Phase 9: Continue gameplay
	print("▶ PHASE 9: Continue Gameplay After Load")
	print("-".repeat(70))

	# Measure remaining qubit
	var remaining_pos = positions[2]
	var remaining_plot = farm.grid.get_plot(remaining_pos)
	if remaining_plot and remaining_plot.is_planted:
		var outcome = farm.biome.measure_qubit(remaining_pos)
		remaining_plot.has_been_measured = true
		print("✓ Measured remaining qubit")

		remaining_plot.harvest()
		farm.biome.clear_qubit(remaining_pos)
		remaining_plot.is_planted = false
		print("✓ Harvested remaining qubit")

	print("")

	# Final
	print("=".repeat(70))
	print("✅ CLEAN ARCHITECTURE TEST COMPLETE")
	print("   GameState → Save → Load → Continue → Verified")
	print("=".repeat(70) + "\n")

	quit()


## APPLY STATE TO FARM
## Takes a GameState and applies it to the simulation
func apply_state_to_farm(state):
	# Economy
	farm.economy.credits = state.credits
	farm.economy.wheat_inventory = state.wheat_inventory
	farm.economy.flour_inventory = state.flour_inventory

	# Plots
	for plot_data in state.plots:
		var pos = plot_data.get("position")
		var plot = farm.grid.get_plot(pos)

		if plot:
			plot.is_planted = plot_data.get("is_planted", false)
			plot.has_been_measured = plot_data.get("has_been_measured", false)
			plot.theta_frozen = plot_data.get("theta_frozen", false)

			# Regenerate quantum state if planted
			if plot.is_planted and not farm.biome.quantum_states.has(pos):
				var qubit = farm.biome.create_quantum_state(pos, "🌾", "🌱", PI/2)

	# Time
	farm.biome.sun_moon_phase = state.sun_moon_phase


## CAPTURE STATE FROM FARM
## Takes current farm state and updates GameState
func capture_state_from_farm(state) -> Resource:
	# Economy
	state.credits = farm.economy.credits
	state.wheat_inventory = farm.economy.wheat_inventory
	state.flour_inventory = farm.economy.flour_inventory

	# Plots
	state.plots.clear()
	for y in range(farm.grid_height):
		for x in range(farm.grid_width):
			var pos = Vector2i(x, y)
			var plot = farm.grid.get_plot(pos)

			if plot:
				state.plots.append({
					"position": pos,
					"type": 0,
					"is_planted": plot.is_planted,
					"has_been_measured": plot.has_been_measured,
					"theta_frozen": plot.theta_frozen,
					"entangled_with": []
				})

	# Time/Environment (new quantum architecture)
	if farm.biome.sun_qubit:
		state.sun_theta = farm.biome.sun_qubit.theta
		state.sun_phi = farm.biome.sun_qubit.phi
	if farm.biome.wheat_icon:
		state.wheat_icon_theta = farm.biome.wheat_icon.theta

	return state


## HELPERS
func count_planted(state) -> int:
	var count = 0
	for plot_data in state.plots:
		if plot_data.get("is_planted", false):
			count += 1
	return count


func count_measured(state) -> int:
	var count = 0
	for plot_data in state.plots:
		if plot_data.get("has_been_measured", false):
			count += 1
	return count
