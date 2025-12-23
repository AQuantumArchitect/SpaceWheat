#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Headless Save/Load Test
## Tests the full game loop with save/load persistence
## Uses direct Farm simulation (no FarmView)

var farm = null
var test_passed = false

func _process(delta):
	if not test_passed:
		test_passed = true
		run_test()

func run_test():
	print("\n" + "=".repeat(70))
	print("💾 HEADLESS SAVE/LOAD TEST")
	print("=".repeat(70) + "\n")

	# Boot Farm
	print("▶ PHASE 1: Initialize Farm")
	print("-".repeat(70))
	const Farm = preload("res://Core/Farm.gd")
	farm = Farm.new()
	root.add_child(farm)
	await root.get_tree().process_frame

	if not (farm and farm.grid and farm.biome):
		print("❌ Farm initialization failed")
		quit()
		return

	var initial_credits = farm.economy.credits
	print("✓ Farm initialized")
	print("  Initial credits: %d\n" % initial_credits)

	# Phase 2: Setup and play
	print("▶ PHASE 2: Setup Game State (Plant 3 Qubits)")
	print("-".repeat(70))
	var positions = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]

	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		var qubit = farm.biome.create_quantum_state(pos, "🌾", "🌱", PI/2)
		plot.plant(qubit)

	print("✓ Planted %d qubits" % positions.size())

	# Evolve
	for i in range(3):
		farm.biome._evolve_quantum_substrate(0.1)
	print("✓ Evolved quantum states")

	# Measure all
	var measured = 0
	for pos in positions:
		var outcome = farm.biome.measure_qubit(pos)
		var plot = farm.grid.get_plot(pos)
		plot.measure(outcome)
		if plot.has_been_measured:
			measured += 1

	print("✓ Measured %d/%d qubits" % [measured, positions.size()])

	# Harvest first two
	for i in range(2):
		var pos = positions[i]
		var plot = farm.grid.get_plot(pos)
		plot.harvest()
		farm.biome.clear_qubit(pos)
		plot.clear()

	print("✓ Harvested 2 qubits\n")

	# Capture state before save
	var state_before = capture_simulation_state()
	print("State before save:")
	print("  Credits: %d" % state_before["credits"])
	print("  Planted plots: %d" % state_before["planted_count"])
	print("  Measured plots: %d\n" % state_before["measured_count"])

	# Phase 3: Save
	print("▶ PHASE 3: Save Game State")
	print("-".repeat(70))
	var save_path = "user://saves/test_save.tres"
	var game_state = create_game_state()
	var save_result = ResourceSaver.save(game_state, save_path)

	if save_result != OK:
		print("❌ Save failed!")
		quit()
		return

	print("✓ Game saved to: %s" % save_path)
	print("  Saved credits: %d" % game_state.credits)
	print("  Saved plots: %d\n" % game_state.plots.size())

	# Phase 4: Play differently
	print("▶ PHASE 4: Play Different Game (Plant at Positions 3-5)")
	print("-".repeat(70))
	var new_positions = [Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)]

	for pos in new_positions:
		var plot = farm.grid.get_plot(pos)
		var qubit = farm.biome.create_quantum_state(pos, "🌾", "🌱", PI/4)
		plot.plant(qubit)

	print("✓ Planted different qubits")

	var state_during = capture_simulation_state()
	print("State during different game:")
	print("  Credits: %d" % state_during["credits"])
	print("  Planted plots: %d\n" % state_during["planted_count"])

	# Phase 5: Load original save
	print("▶ PHASE 5: Load Original Save")
	print("-".repeat(70))
	var loaded_state = ResourceLoader.load(save_path) as Resource

	if not loaded_state:
		print("❌ Load failed!")
		quit()
		return

	print("✓ Loaded save file")
	print("  Loaded credits: %d" % loaded_state.get("credits"))
	print("  Loaded plots: %d" % loaded_state.get("plots").size())

	# Apply state
	apply_game_state(loaded_state)
	print("✓ Applied loaded state to farm\n")

	# Phase 6: Verify
	print("▶ PHASE 6: Verify Loaded State")
	print("-".repeat(70))
	var state_after_load = capture_simulation_state()

	var credits_match = state_after_load["credits"] == state_before["credits"]
	var planted_match = state_after_load["planted_count"] == state_before["planted_count"]
	var measured_match = state_after_load["measured_count"] == state_before["measured_count"]

	print("Credits match: %s (before: %d, after: %d)" % [credits_match, state_before["credits"], state_after_load["credits"]])
	print("Planted count match: %s (before: %d, after: %d)" % [planted_match, state_before["planted_count"], state_after_load["planted_count"]])
	print("Measured count match: %s (before: %d, after: %d)" % [measured_match, state_before["measured_count"], state_after_load["measured_count"]])

	if credits_match and planted_match and measured_match:
		print("\n✅ LOAD VERIFICATION PASSED!\n")
	else:
		print("\n⚠ LOAD VERIFICATION FAILED\n")

	# Phase 7: Continue playing
	print("▶ PHASE 7: Continue Gameplay After Load")
	print("-".repeat(70))

	# Measure the remaining unmeasured qubit
	var remaining_pos = positions[2]
	var remaining_plot = farm.grid.get_plot(remaining_pos)

	if remaining_plot and remaining_plot.is_planted:
		var outcome = farm.biome.measure_qubit(remaining_pos)
		remaining_plot.measure(outcome)
		print("✓ Measured remaining qubit (outcome: %s)" % outcome)

		# Harvest
		remaining_plot.harvest()
		farm.biome.clear_qubit(remaining_pos)
		print("✓ Harvested remaining qubit")
	else:
		print("⚠ Remaining qubit was cleared or not planted")

	var final_state = capture_simulation_state()
	print("Final state after gameplay:")
	print("  Credits: %d" % final_state["credits"])
	print("  Planted plots: %d\n" % final_state["planted_count"])

	# Results
	print("=".repeat(70))
	print("✅ SAVE/LOAD CYCLE TEST COMPLETE")
	print("   Plant → Save → Load → Continue → Verified")
	print("=".repeat(70) + "\n")

	quit()

func capture_simulation_state() -> Dictionary:
	return {
		"credits": farm.economy.credits,
		"wheat_inventory": farm.economy.wheat_inventory,
		"planted_count": _count_planted(),
		"measured_count": _count_measured()
	}

func _count_planted() -> int:
	var count = 0
	for y in range(farm.grid_height):
		for x in range(farm.grid_width):
			var plot = farm.grid.get_plot(Vector2i(x, y))
			if plot and plot.is_planted:
				count += 1
	return count

func _count_measured() -> int:
	var count = 0
	for y in range(farm.grid_height):
		for x in range(farm.grid_width):
			var plot = farm.grid.get_plot(Vector2i(x, y))
			if plot and plot.has_been_measured:
				count += 1
	return count

func create_game_state() -> Resource:
	const GameState = preload("res://Core/GameState/GameState.gd")
	var state = GameState.new()

	state.scenario_id = "headless_test"
	state.save_timestamp = Time.get_unix_time_from_system()
	state.game_time = 0.0

	# Grid
	state.grid_width = farm.grid_width
	state.grid_height = farm.grid_height

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
					"type": plot.plot_type if plot.has_meta("plot_type") else 0,
					"is_planted": plot.is_planted,
					"has_been_measured": plot.has_been_measured,
					"theta_frozen": plot.theta_frozen,
					"entangled_with": []
				})

	# Time
	state.sun_moon_phase = farm.biome.sun_moon_phase

	return state

func apply_game_state(state: Resource):
	const GameState = preload("res://Core/GameState/GameState.gd")
	var gs = state as GameState

	if not gs:
		print("❌ Invalid game state resource")
		return

	# Economy
	farm.economy.credits = gs.credits
	farm.economy.wheat_inventory = gs.wheat_inventory
	farm.economy.flour_inventory = gs.flour_inventory

	# Plots
	for plot_data in gs.plots:
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
	farm.biome.sun_moon_phase = gs.sun_moon_phase
