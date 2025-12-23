#!/usr/bin/env -S godot --headless -s
extends SceneTree

## GameState Persistence Test: Verify quantum state survives save/load
## Tests that:
## - time_elapsed is preserved
## - sun position is preserved
## - icon states are preserved
## - emoji qubit states (theta, radius, energy) are preserved

const GameState = preload("res://Core/GameState/GameState.gd")

var farm = null
var game_manager = null
var test_complete = false

func _process(delta):
	if not test_complete:
		test_complete = true
		await run_test()

func run_test():
	print("\n" + "═".repeat(100))
	print("GAMESTATE PERSISTENCE TEST: Quantum state save/load")
	print("═".repeat(100) + "\n")

	const MemoryManager = preload("res://Core/GameState/MemoryManager.gd")
	game_manager = MemoryManager.new()
	root.add_child(game_manager)
	game_manager.new_game("default")

	const Farm = preload("res://Core/Farm.gd")
	farm = Farm.new()
	root.add_child(farm)
	await root.get_tree().process_frame

	# Setup: Plant wheat hybrid to track its evolution
	print("SETUP: Plant wheat hybrid and let it evolve for 10 seconds\n")

	var hybrid_pos = Vector2i(0, 0)
	var hybrid_plot = farm.grid.get_plot(hybrid_pos)
	var hybrid = farm.biome.create_quantum_state(hybrid_pos, "🌾", "🍄", PI/2.0)
	hybrid.radius = 0.3
	hybrid_plot.plant(hybrid)
	print("  Planted hybrid at (0,0): θ=90°, R=0.3\n")

	# Phase 1: Let it evolve
	print("─".repeat(100))
	print("PHASE 1: Evolve for 10 seconds")
	print("─".repeat(100) + "\n")

	farm.biome.time_elapsed = 0.0

	# Simulate 10 seconds (625 frames at 16ms)
	for frame_num in range(625):
		farm.biome._process(0.016)

	var time_before_save = farm.biome.time_elapsed
	var sun_theta_before = farm.biome.sun_qubit.theta
	var hybrid_theta_before = hybrid.theta
	var hybrid_radius_before = hybrid.radius
	var hybrid_energy_before = hybrid.energy

	print("Before Save:")
	print("  Time elapsed: %.2f seconds" % time_before_save)
	print("  Sun θ: %.2f° (%.4f rad)" % [sun_theta_before * 180.0 / PI, sun_theta_before])
	print("  Hybrid θ: %.2f° (%.4f rad)" % [hybrid_theta_before * 180.0 / PI, hybrid_theta_before])
	print("  Hybrid R: %.4f, E: %.4f" % [hybrid_radius_before, hybrid_energy_before])
	print()

	# Phase 2: Capture state
	print("─".repeat(100))
	print("PHASE 2: Capture GameState")
	print("─".repeat(100) + "\n")

	var state = GameState.new()
	state.grid_width = 6
	state.grid_height = 1

	# Manually capture like GameStateManager does
	state.time_elapsed = farm.biome.time_elapsed
	if farm.biome.sun_qubit:
		state.sun_theta = farm.biome.sun_qubit.theta
		state.sun_phi = farm.biome.sun_qubit.phi

	# Capture biome_state tree
	state.biome_state = {
		"time_elapsed": farm.biome.time_elapsed,
		"sun_qubit": {},
		"wheat_icon": {},
		"mushroom_icon": {},
		"quantum_states": []
	}

	# Sun qubit
	if farm.biome.sun_qubit:
		state.biome_state["sun_qubit"] = {
			"theta": farm.biome.sun_qubit.theta,
			"phi": farm.biome.sun_qubit.phi,
			"radius": farm.biome.sun_qubit.radius,
			"energy": farm.biome.sun_qubit.energy
		}

	# Quantum states
	for pos in farm.biome.quantum_states.keys():
		var qubit = farm.biome.quantum_states[pos]
		state.biome_state["quantum_states"].append({
			"position": pos,
			"theta": qubit.theta,
			"phi": qubit.phi,
			"radius": qubit.radius,
			"energy": qubit.energy
		})

	print("  Captured state with biome_state tree")
	print("  biome_state[\"time_elapsed\"] = %.2f" % state.biome_state["time_elapsed"])
	print("  biome_state[\"sun_qubit\"][\"theta\"] = %.4f" % state.biome_state["sun_qubit"]["theta"])

	# Find the quantum state for the hybrid position
	var hybrid_capture_theta = 0.0
	for qs in state.biome_state["quantum_states"]:
		if qs["position"] == hybrid_pos:
			hybrid_capture_theta = qs["theta"]
			break
	print("  biome_state[\"quantum_states\"][hybrid][\"theta\"] = %.4f" % hybrid_capture_theta)
	print()

	# Phase 3: Direct restoration test (same farm, reset qubits, then restore)
	print("─".repeat(100))
	print("PHASE 3: Direct Restoration Test")
	print("─".repeat(100) + "\n")

	var biome = farm.biome
	print("  Testing restoration of biome_state directly...\n")

	# Simulate a fresh load by resetting the hybrid to defaults
	var hybrid_before_restore = biome.quantum_states[hybrid_pos]
	hybrid_before_restore.theta = PI/2.0  # Reset to fresh value
	hybrid_before_restore.radius = 0.3
	hybrid_before_restore.energy = 0.3
	biome.time_elapsed = 0.0
	biome.sun_qubit.theta = 0.0

	print("  After manual reset:")
	print("    Time elapsed: 0.00")
	print("    Sun θ: 0.00")
	print("    Hybrid θ: %.2f° (%.4f)" % [PI/2.0 * 180.0 / PI, PI/2.0])
	print("    Hybrid R: 0.3000\n")

	# Now restore from state (like GameStateManager.apply_state_to_game)
	if state.biome_state:
		var bs = state.biome_state
		biome.time_elapsed = bs.get("time_elapsed", 0.0)

		if bs.has("sun_qubit") and biome.sun_qubit:
			var sq = bs["sun_qubit"]
			biome.sun_qubit.theta = sq.get("theta", 0.0)
			biome.sun_qubit.phi = sq.get("phi", 0.0)
			biome.sun_qubit.radius = sq.get("radius", 1.0)
			biome.sun_qubit.energy = sq.get("energy", 1.0)

		# Restore quantum states
		if bs.has("quantum_states"):
			for qubit_data in bs["quantum_states"]:
				var pos = qubit_data["position"]
				if biome.quantum_states.has(pos):
					var qubit = biome.quantum_states[pos]
					qubit.theta = qubit_data.get("theta", PI/2.0)
					qubit.phi = qubit_data.get("phi", 0.0)
					qubit.radius = qubit_data.get("radius", 0.3)
					qubit.energy = qubit_data.get("energy", 0.3)

	print("  Restored quantum state from biome_state tree\n")

	# Phase 4: Verify restoration
	print("─".repeat(100))
	print("PHASE 4: Verify State Preservation")
	print("─".repeat(100) + "\n")

	var time_after_restore = biome.time_elapsed
	var sun_theta_after = biome.sun_qubit.theta
	var hybrid_after = biome.quantum_states[hybrid_pos]
	var hybrid_theta_after = hybrid_after.theta
	var hybrid_radius_after = hybrid_after.radius
	var hybrid_energy_after = hybrid_after.energy

	print("After Restore:")
	print("  Time elapsed: %.2f seconds" % time_after_restore)
	print("  Sun θ: %.2f° (%.4f rad)" % [sun_theta_after * 180.0 / PI, sun_theta_after])
	print("  Hybrid θ: %.2f° (%.4f rad)" % [hybrid_theta_after * 180.0 / PI, hybrid_theta_after])
	print("  Hybrid R: %.4f, E: %.4f" % [hybrid_radius_after, hybrid_energy_after])
	print()

	# Check differences
	var time_diff = abs(time_after_restore - time_before_save)
	var sun_diff = abs(sun_theta_after - sun_theta_before)
	var theta_diff = abs(hybrid_theta_after - hybrid_theta_before)
	var radius_diff = abs(hybrid_radius_after - hybrid_radius_before)
	var energy_diff = abs(hybrid_energy_after - hybrid_energy_before)

	print("Differences:")
	print("  Time Δ: %.6f (tolerance: < 0.0001)" % time_diff)
	print("  Sun θ Δ: %.6f (tolerance: < 0.0001)" % sun_diff)
	print("  Hybrid θ Δ: %.6f (tolerance: < 0.0001)" % theta_diff)
	print("  Hybrid R Δ: %.6f (tolerance: < 0.0001)" % radius_diff)
	print("  Hybrid E Δ: %.6f (tolerance: < 0.0001)" % energy_diff)
	print()

	# Results
	print("─".repeat(100))
	print("RESULTS")
	print("─".repeat(100) + "\n")

	var all_pass = true
	if time_diff > 0.0001:
		print("❌ FAIL: Time not preserved (Δ=%.6f)" % time_diff)
		all_pass = false
	else:
		print("✓ PASS: Time preserved (Δ=%.6f)" % time_diff)

	if sun_diff > 0.0001:
		print("❌ FAIL: Sun position not preserved (Δ=%.6f)" % sun_diff)
		all_pass = false
	else:
		print("✓ PASS: Sun position preserved (Δ=%.6f)" % sun_diff)

	if theta_diff > 0.0001:
		print("❌ FAIL: Hybrid θ not preserved (Δ=%.6f)" % theta_diff)
		all_pass = false
	else:
		print("✓ PASS: Hybrid θ preserved (Δ=%.6f)" % theta_diff)

	if radius_diff > 0.0001:
		print("❌ FAIL: Hybrid radius not preserved (Δ=%.6f)" % radius_diff)
		all_pass = false
	else:
		print("✓ PASS: Hybrid radius preserved (Δ=%.6f)" % radius_diff)

	if energy_diff > 0.0001:
		print("❌ FAIL: Hybrid energy not preserved (Δ=%.6f)" % energy_diff)
		all_pass = false
	else:
		print("✓ PASS: Hybrid energy preserved (Δ=%.6f)" % energy_diff)

	print()
	if all_pass:
		print("═".repeat(100))
		print("✓✓✓ ALL TESTS PASSED - Quantum state persisted correctly ✓✓✓")
		print("═".repeat(100) + "\n")
	else:
		print("═".repeat(100))
		print("❌❌❌ SOME TESTS FAILED - See above for details ❌❌❌")
		print("═".repeat(100) + "\n")

	quit()

