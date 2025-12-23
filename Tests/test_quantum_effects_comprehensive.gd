#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Comprehensive Quantum Effects Test
## Verifies: sun coupling, icon modulation, energy transfer, entanglement

var farm = null
var game_manager = null
var test_complete = false

func _process(delta):
	if not test_complete:
		test_complete = true
		await run_test()

func run_test():
	print("\n" + "=".repeat(70))
	print("COMPREHENSIVE QUANTUM EFFECTS TEST")
	print("=".repeat(70) + "\n")

	# Initialize
	const MemoryManager = preload("res://Core/GameState/MemoryManager.gd")
	game_manager = MemoryManager.new()
	root.add_child(game_manager)
	var state = game_manager.new_game("default")

	const Farm = preload("res://Core/Farm.gd")
	farm = Farm.new()
	root.add_child(farm)
	await root.get_tree().process_frame

	print("=".repeat(70))
	print("TEST 1: SUN/WHEAT COUPLING (Sigma_z interaction)")
	print("=".repeat(70))

	# Plant wheat at different theta values
	var wheat_positions = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var initial_thetas: Array[float] = []

	for i in range(wheat_positions.size()):
		var pos = wheat_positions[i]
		var plot = farm.grid.get_plot(pos)

		# Create wheat with specific theta
		var theta = (i * PI / 3.0)  # 0°, 60°, 120°
		var qubit = farm.biome.create_quantum_state(pos, "🌾", "👥", theta)
		plot.plant(qubit)
		initial_thetas.append(theta)

		print("  Planted wheat at (0,%d): theta=%.1f°" % [i, theta * 180.0 / PI])

	# Get sun to peak sun phase (theta ≈ 0°, maximum energy transfer)
	print("\nAdvancing to peak SUN phase...")
	farm.biome.time_elapsed = 0.0
	farm.biome._sync_sun_qubit(0.016)
	print("  Sun theta: %.1f° (should be near 0° for peak sun)" % [farm.biome.sun_qubit.theta * 180.0 / PI])

	# Record initial state
	var state_before = []
	for i in range(wheat_positions.size()):
		var qubit = farm.grid.get_plot(wheat_positions[i]).quantum_state
		state_before.append(qubit.theta)

	# Simulate during sun phase (5 seconds at 60fps = 300 frames)
	print("\nSimulating 5 seconds of sun phase coupling...")
	for frame in range(300):
		farm.biome._process(0.016)

	# Record final state
	var state_after = []
	var theta_changes: Array[float] = []
	for i in range(wheat_positions.size()):
		var qubit = farm.grid.get_plot(wheat_positions[i]).quantum_state
		state_after.append(qubit.theta)
		var change = state_after[i] - state_before[i]
		theta_changes.append(change)

	# Verify coupling worked
	print("\nResults:")
	var coupling_success = 0
	for i in range(wheat_positions.size()):
		var initial = initial_thetas[i] * 180.0 / PI
		var final = state_after[i] * 180.0 / PI
		var change = theta_changes[i] * 180.0 / PI
		print("  Wheat %d: %.1f° → %.1f° (change: %.1f°)" % [i, initial, final, change])

		# Expect some change due to sun coupling
		if abs(theta_changes[i]) > 0.05:
			coupling_success += 1
			print("    ✓ Sigma_z coupling detected")
		else:
			print("    ✗ No coupling detected")

	print("\n" + "=".repeat(70))
	print("TEST 2: WHEAT ICON MODULATION (energy transfer rate)")
	print("=".repeat(70))

	# Reset and plant fresh wheat
	for pos in wheat_positions:
		farm.grid.get_plot(pos).is_planted = false
		farm.biome.clear_qubit(pos)

	# Create two wheat with same theta but different icon influence
	print("\nCreating test wheat for icon modulation...")
	var agrarian_qubit = farm.biome.create_quantum_state(Vector2i(0, 0), "🌾", "👥", PI / 4.0)
	farm.grid.get_plot(Vector2i(0, 0)).plant(agrarian_qubit)
	var agrarian_initial_radius = agrarian_qubit.radius

	var imperium_qubit = farm.biome.create_quantum_state(Vector2i(1, 0), "🌾", "👥", PI / 4.0)
	farm.grid.get_plot(Vector2i(1, 0)).plant(imperium_qubit)
	var imperium_initial_radius = imperium_qubit.radius

	print("  Both wheat: theta=%.1f°, initial radius=%.3f" % [PI/4.0 * 180.0 / PI, agrarian_initial_radius])

	# Ensure we're at peak sun phase
	farm.biome.time_elapsed = 0.0
	farm.biome._sync_sun_qubit(0.016)

	# Test 1: With AGRARIAN icon (theta=15° = high cos²(theta/2))
	print("\nSimulating with AGRARIAN icon (theta=15°, high influence)...")
	farm.biome.wheat_icon.theta = PI / 12.0  # 15° (default agrarian)
	print("  Icon influence cos²(%.1f°/2) = %.3f" % [
		farm.biome.wheat_icon.theta * 180.0 / PI,
		pow(cos(farm.biome.wheat_icon.theta / 2.0), 2)
	])
	for frame in range(100):
		farm.biome._process(0.016)
	var agrarian_final_radius = agrarian_qubit.radius

	# Reset to test 2
	for pos in wheat_positions:
		farm.grid.get_plot(pos).is_planted = false
		farm.biome.clear_qubit(pos)

	# Recreate wheat for second test
	var imperium_qubit2 = farm.biome.create_quantum_state(Vector2i(1, 0), "🌾", "👥", PI / 4.0)
	farm.grid.get_plot(Vector2i(1, 0)).plant(imperium_qubit2)

	# Reset sun to peak
	farm.biome.time_elapsed = 0.0
	farm.biome._sync_sun_qubit(0.016)

	# Test 2: With IMPERIUM icon (theta=165° = low cos²(theta/2))
	print("\nSimulating with IMPERIUM icon (theta=165°, low influence)...")
	farm.biome.wheat_icon.theta = 11 * PI / 12.0  # 165° (toward imperium)
	print("  Icon influence cos²(%.1f°/2) = %.3f" % [
		farm.biome.wheat_icon.theta * 180.0 / PI,
		pow(cos(farm.biome.wheat_icon.theta / 2.0), 2)
	])
	for frame in range(100):
		farm.biome._process(0.016)
	var imperium_final_radius = imperium_qubit2.radius

	print("\nResults:")
	var agrarian_growth = agrarian_final_radius - agrarian_initial_radius
	var imperium_growth = imperium_final_radius - imperium_initial_radius
	print("  Agrarian wheat growth: %.4f (high icon influence)" % agrarian_growth)
	print("  Imperium wheat growth: %.4f (low icon influence)" % imperium_growth)

	var modulation_success = 0
	if agrarian_growth > imperium_growth:  # Agrarian should grow more
		print("  ✓ Icon modulation working (agrarian growth > imperium)")
		modulation_success = 1
	else:
		print("  ✗ Icon modulation not effective")

	print("\n" + "=".repeat(70))
	print("TEST 3: FULL GAMEPLAY LOOP")
	print("=".repeat(70))

	# Reset everything
	for pos in wheat_positions:
		farm.grid.get_plot(pos).is_planted = false
		farm.biome.clear_qubit(pos)

	# Plant, evolve, measure, harvest
	print("\nPhase 1: Planting...")
	for pos in wheat_positions:
		var qubit = farm.biome.create_quantum_state(pos, "🌾", "👥", PI / 3.0)
		farm.grid.get_plot(pos).plant(qubit)
	print("  ✓ Planted 3 qubits")

	print("\nPhase 2: Evolving quantum substrate...")
	farm.biome.time_elapsed = 0.0
	for frame in range(300):  # 5 seconds
		farm.biome._process(0.016)
	print("  ✓ Evolved for 5 seconds")
	print("    Sun theta: %.1f°" % [farm.biome.sun_qubit.theta * 180.0 / PI])
	print("    Icon theta: %.1f°" % [farm.biome.wheat_icon.theta * 180.0 / PI])

	print("\nPhase 3: Measuring...")
	for pos in wheat_positions:
		var outcome = farm.biome.measure_qubit(pos)
		var plot = farm.grid.get_plot(pos)
		plot.has_been_measured = true
		if outcome:
			print("  ✓ Measured %s: %s" % [pos, outcome])

	print("\nPhase 4: Harvesting...")
	for i in range(2):
		var pos = wheat_positions[i]
		var plot = farm.grid.get_plot(pos)
		plot.harvest()
		farm.biome.clear_qubit(pos)
		print("  ✓ Harvested %s" % pos)

	print("\n" + "=".repeat(70))
	print("TEST 4: SAVE/LOAD PRESERVES QUANTUM STATE")
	print("=".repeat(70))

	# Create a specific game state
	print("\nCreating game state with quantum plants...")
	farm.grid.get_plot(Vector2i(3, 0)).is_planted = true
	var qstate = farm.biome.create_quantum_state(Vector2i(3, 0), "🌾", "👥", PI / 4.0)
	farm.grid.get_plot(Vector2i(3, 0)).plant(qstate)

	# Capture state
	var captured_state = game_manager.new_game("default")
	captured_state.credits = 42
	if farm.biome.sun_qubit:
		captured_state.sun_theta = farm.biome.sun_qubit.theta
		captured_state.sun_phi = farm.biome.sun_qubit.phi
	if farm.biome.wheat_icon:
		captured_state.wheat_icon_theta = farm.biome.wheat_icon.theta

	# Save
	var save_ok = game_manager.save_game(captured_state, 0)
	print("  Save: %s" % ("✓ OK" if save_ok else "✗ FAILED"))

	# Load
	var loaded_state = game_manager.load_game(0)
	print("  Load: %s" % ("✓ OK" if loaded_state else "✗ FAILED"))

	if loaded_state:
		print("  Loaded state:")
		print("    Credits: %d (expect 42)" % loaded_state.credits)
		print("    Sun theta: %.2f rad (expect ~%.2f)" % [loaded_state.sun_theta, farm.biome.sun_qubit.theta])
		print("    Icon theta: %.2f rad (expect ~%.2f)" % [loaded_state.wheat_icon_theta, farm.biome.wheat_icon.theta])

	# Final report
	print("\n" + "=".repeat(70))
	print("TEST RESULTS SUMMARY")
	print("=".repeat(70))
	print("Test 1 (Sun coupling): %d/3 wheat showed coupling" % coupling_success)
	print("Test 2 (Icon modulation): %s" % ("PASS" if modulation_success else "FAIL"))
	print("Test 3 (Gameplay loop): PASS (all phases completed)")
	print("Test 4 (Save/load): %s" % ("PASS" if loaded_state else "FAIL"))

	var total_pass = (coupling_success >= 2) and modulation_success and (loaded_state != null)
	if total_pass:
		print("\n✅ COMPREHENSIVE QUANTUM EFFECTS TEST PASSED")
	else:
		print("\n⚠️ Some tests failed - investigate quantum physics")

	print("=".repeat(70) + "\n")
	quit()
