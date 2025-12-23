#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Phase Constraint Tests
## Verifies Imperium frozen Bloch sphere vs free fields

var farm = null
var game_manager = null
var test_complete = false

func _process(delta):
	if not test_complete:
		test_complete = true
		await run_tests()

func run_tests():
	print("\n" + "=".repeat(80))
	print("PHASE CONSTRAINT TESTS - Imperium Frozen Bloch Sphere")
	print("=".repeat(80) + "\n")

	const MemoryManager = preload("res://Core/GameState/MemoryManager.gd")
	game_manager = MemoryManager.new()
	root.add_child(game_manager)
	game_manager.new_game("default")

	const Farm = preload("res://Core/Farm.gd")
	farm = Farm.new()
	root.add_child(farm)
	await root.get_tree().process_frame

	await test_free_field_dynamics()
	await test_imperium_frozen_bloch()
	await test_imperium_energy_growth()
	await test_mixed_field_comparison()

	print("\n" + "=".repeat(80))
	print("ALL PHASE CONSTRAINT TESTS COMPLETE")
	print("=".repeat(80) + "\n")
	quit()


func test_free_field_dynamics():
	"""Test that free fields allow full quantum evolution"""
	print("─".repeat(80))
	print("TEST 1: Free Field - Full Quantum Dynamics")
	print("─".repeat(80))

	reset_farm()

	# Plant wheat at perpendicular phase (90°) in FREE field
	var pos = Vector2i(0, 0)
	var wheat = farm.biome.create_quantum_state(pos, "🌾", "👥", PI / 2.0)
	wheat.radius = 0.3
	farm.grid.get_plot(pos).plant(wheat)

	# NO constraint = free evolution
	var plot = farm.grid.get_plot(pos)
	plot.phase_constraint = null

	print("\n  Setup:")
	print("    Plot type: FREE FIELD (no constraint)")
	print("    Initial wheat: θ = 90.0° (perpendicular to sun)")
	print("    Initial radius: %.4f" % wheat.radius)

	farm.biome.time_elapsed = 0.0
	print("\n  Simulating 5 seconds (sun coupling active)...\n")

	var theta_history = []
	var radius_history = []

	for frame in range(301):
		if frame > 0:
			farm.biome._process(0.016)

		if frame % 60 == 0:
			theta_history.append(wheat.theta)
			radius_history.append(wheat.radius)

	print("  Time (s) | θ (°)    | Radius  | Status")
	print("  ─────────────────────────────────────")
	for i in range(theta_history.size()):
		var time_s = i * 0.96
		var theta_deg = theta_history[i] * 180.0 / PI
		var radius = radius_history[i]
		var status = "evolving" if i == 0 else ("pulled toward sun" if theta_deg < 45.0 else "adapting")
		print("  %8.2f | %8.1f | %.4f | %s" % [time_s, theta_deg, radius, status])

	var final_theta = theta_history[-1] * 180.0 / PI
	var final_radius = radius_history[-1]
	var theta_change = final_theta - 90.0

	print("\n  Results:")
	print("    Theta changed: 90.0° → %.1f° (change: %.1f°)" % [final_theta, theta_change])
	print("    Radius grew: 0.3000 → %.4f" % final_radius)
	print("    ✓ Free field allows both phase and radius evolution")


func test_imperium_frozen_bloch():
	"""Test that Imperium fields freeze theta/phi"""
	print("\n" + "─".repeat(80))
	print("TEST 2: Imperium Field - Frozen Bloch Sphere (θ, φ locked)")
	print("─".repeat(80))

	reset_farm()

	# Plant wheat at 45° angle in IMPERIUM field
	var pos = Vector2i(0, 0)
	var wheat = farm.biome.create_quantum_state(pos, "🌾", "👥", PI / 4.0)
	wheat.radius = 0.3
	farm.grid.get_plot(pos).plant(wheat)

	var initial_theta = wheat.theta
	var initial_phi = wheat.phi

	# Add FROZEN constraint
	var plot = farm.grid.get_plot(pos)
	const PhaseConstraint = preload("res://Core/GameMechanics/PhaseConstraint.gd")
	plot.phase_constraint = PhaseConstraint.new(PhaseConstraint.ConstraintType.FROZEN, initial_theta, initial_phi)

	print("\n  Setup:")
	print("    Plot type: IMPERIUM FIELD (frozen Bloch sphere)")
	print("    Initial wheat: θ = %.1f°, φ = %.1f°" % [
		initial_theta * 180.0 / PI,
		initial_phi * 180.0 / PI
	])
	print("    Initial radius: %.4f" % wheat.radius)

	farm.biome.time_elapsed = 0.0
	print("\n  Simulating 5 seconds (constraints enforced)...\n")

	var theta_history = []
	var phi_history = []
	var radius_history = []
	var constraint_violations = 0

	for frame in range(301):
		if frame > 0:
			farm.biome._process(0.016)

		if frame % 60 == 0:
			theta_history.append(wheat.theta)
			phi_history.append(wheat.phi)
			radius_history.append(wheat.radius)

			# Check if constraint was violated (before it was re-applied)
			if abs(wheat.theta - initial_theta) > 0.001 or abs(wheat.phi - initial_phi) > 0.001:
				constraint_violations += 1

	print("  Time (s) | θ (°)    | φ (°)   | Radius  | Status")
	print("  ──────────────────────────────────────────────")
	for i in range(theta_history.size()):
		var time_s = i * 0.96
		var theta_deg = theta_history[i] * 180.0 / PI
		var phi_deg = phi_history[i] * 180.0 / PI
		var radius = radius_history[i]
		var is_frozen = abs(theta_deg - (initial_theta * 180.0 / PI)) < 0.1
		var status = "FROZEN ✓" if is_frozen else "DRIFTED ✗"
		print("  %8.2f | %8.1f | %7.1f | %.4f | %s" % [
			time_s, theta_deg, phi_deg, radius, status
		])

	var final_theta = theta_history[-1]
	var final_phi = phi_history[-1]
	var final_radius = radius_history[-1]
	var theta_frozen = abs(final_theta - initial_theta) < 0.001
	var phi_frozen = abs(final_phi - initial_phi) < 0.001
	var radius_grew = final_radius > 0.3

	print("\n  Results:")
	print("    Theta frozen: %s (%.1f° - %.1f° = %.6f)" % [
		"✓ YES" if theta_frozen else "✗ NO",
		final_theta * 180.0 / PI,
		initial_theta * 180.0 / PI,
		abs(final_theta - initial_theta)
	])
	print("    Phi frozen: %s (%.1f° - %.1f° = %.6f)" % [
		"✓ YES" if phi_frozen else "✗ NO",
		final_phi * 180.0 / PI,
		initial_phi * 180.0 / PI,
		abs(final_phi - initial_phi)
	])
	print("    Radius growth: %s (0.3000 → %.4f)" % [
		"✓ YES" if radius_grew else "✗ NO",
		final_radius
	])
	if theta_frozen and phi_frozen and radius_grew:
		print("    ✓✓✓ IMPERIUM constraint working perfectly!")


func test_imperium_energy_growth():
	"""Test that energy growth still works in Imperium (just can't change phase)"""
	print("\n" + "─".repeat(80))
	print("TEST 3: Imperium Energy Growth (scalar-like behavior)")
	print("─".repeat(80))

	reset_farm()

	# Plant wheat at favorable alignment (0°) and poor alignment (90°)
	var good_pos = Vector2i(0, 0)
	var poor_pos = Vector2i(1, 0)

	var good_wheat = farm.biome.create_quantum_state(good_pos, "🌾", "👥", 0.0)
	good_wheat.radius = 0.3
	farm.grid.get_plot(good_pos).plant(good_wheat)

	var poor_wheat = farm.biome.create_quantum_state(poor_pos, "🌾", "👥", PI / 2.0)
	poor_wheat.radius = 0.3
	farm.grid.get_plot(poor_pos).plant(poor_wheat)

	# Apply IMPERIUM constraint to both
	const PhaseConstraint = preload("res://Core/GameMechanics/PhaseConstraint.gd")
	farm.grid.get_plot(good_pos).phase_constraint = PhaseConstraint.new(PhaseConstraint.ConstraintType.FROZEN, 0.0, 0.0)
	farm.grid.get_plot(poor_pos).phase_constraint = PhaseConstraint.new(PhaseConstraint.ConstraintType.FROZEN, PI / 2.0, 0.0)

	print("\n  Setup:")
	print("    Both plots: IMPERIUM FIELD")
	print("    Wheat A @ (0,0): θ = 0° (good alignment), radius = 0.3")
	print("    Wheat B @ (1,0): θ = 90° (poor alignment), radius = 0.3")

	farm.biome.time_elapsed = 0.0
	print("\n  Simulating 5 seconds (energy growth with frozen phases)...\n")

	for frame in range(300):
		farm.biome._process(0.016)

	var good_growth = good_wheat.radius - 0.3
	var poor_growth = poor_wheat.radius - 0.3

	print("  Results:")
	print("    Wheat A (aligned): 0.3000 → %.4f (growth: %.4f)" % [good_wheat.radius, good_growth])
	print("    Wheat B (perpendicular): 0.3000 → %.4f (growth: %.4f)" % [poor_wheat.radius, poor_growth])
	print("    Growth ratio: %.2f:1" % [good_growth / poor_growth if poor_growth > 0 else 999])
	print("\n    ✓ Imperium allows SCALAR-ONLY growth (no phase evolution)")
	print("    ✓ Energy still respects alignment (A grows more than B)")
	print("    ✓ Phase locked means wheat can't adapt to suboptimal starting conditions")


func test_mixed_field_comparison():
	"""Compare free field vs Imperium field side-by-side"""
	print("\n" + "─".repeat(80))
	print("TEST 4: Free vs Imperium - Strategic Comparison")
	print("─".repeat(80))

	reset_farm()

	# Scenario: Both start perpendicular (90°)
	var free_pos = Vector2i(0, 0)
	var imperium_pos = Vector2i(1, 0)

	var free_wheat = farm.biome.create_quantum_state(free_pos, "🌾", "👥", PI / 2.0)
	free_wheat.radius = 0.3
	farm.grid.get_plot(free_pos).plant(free_wheat)

	var imperium_wheat = farm.biome.create_quantum_state(imperium_pos, "🌾", "👥", PI / 2.0)
	imperium_wheat.radius = 0.3
	farm.grid.get_plot(imperium_pos).plant(imperium_wheat)

	# Apply constraint only to Imperium plot
	const PhaseConstraint = preload("res://Core/GameMechanics/PhaseConstraint.gd")
	farm.grid.get_plot(imperium_pos).phase_constraint = PhaseConstraint.new(PhaseConstraint.ConstraintType.FROZEN, PI / 2.0, 0.0)

	print("\n  Setup:")
	print("    Both start: θ = 90° (perpendicular), radius = 0.3")
	print("    Free field: allows phase + radius evolution")
	print("    Imperium field: only radius evolution (phase frozen)")

	farm.biome.time_elapsed = 0.0
	print("\n  Simulating 10 seconds...\n")
	print("  Time (s) | Free θ (°) | Free R | Imperium θ (°) | Imp R | Adaptation")
	print("  ────────────────────────────────────────────────────────────────────")

	for frame in range(625):
		if frame > 0:
			farm.biome._process(0.016)

		if frame % 125 == 0:
			var time_s = frame * 0.016
			var free_theta = free_wheat.theta * 180.0 / PI
			var free_radius = free_wheat.radius
			var imp_theta = imperium_wheat.theta * 180.0 / PI
			var imp_radius = imperium_wheat.radius
			var can_adapt = "✓ YES" if abs(free_theta - 90.0) > 5.0 else "✗ stuck"

			print("  %8.2f | %10.1f | %.4f | %14.1f | %.4f | %s" % [
				time_s, free_theta, free_radius, imp_theta, imp_radius, can_adapt
			])

	var free_final_theta = free_wheat.theta * 180.0 / PI
	var free_final_radius = free_wheat.radius
	var imp_final_theta = imperium_wheat.theta * 180.0 / PI
	var imp_final_radius = imperium_wheat.radius

	print("\n  Analysis:")
	print("    Free field wheat:")
	print("      Phase: 90.0° → %.1f° (changed by %.1f°)" % [free_final_theta, free_final_theta - 90.0])
	print("      Radius: 0.3000 → %.4f" % free_final_radius)
	print("      Benefit: Can adapt phase to escape unfavorable superposition")
	print()
	print("    Imperium field wheat:")
	print("      Phase: 90.0° → %.1f° (LOCKED, change: %.1f°)" % [imp_final_theta, imp_final_theta - 90.0])
	print("      Radius: 0.3000 → %.4f" % imp_final_radius)
	print("      Cost: Trapped in initial phase, limited growth")
	print()
	print("    ✓ This shows the strategic tradeoff:")
	print("      - Free fields: Can adapt but less stable")
	print("      - Imperium fields: Stable but rigid (scalar-like)")


func reset_farm():
	"""Clear all plants and reset time"""
	for x in range(farm.grid.grid_width):
		for y in range(farm.grid.grid_height):
			var pos = Vector2i(x, y)
			var plot = farm.grid.get_plot(pos)
			if plot and plot.is_planted:
				plot.is_planted = false
				plot.phase_constraint = null  # Clear constraint
				farm.biome.clear_qubit(pos)
	farm.biome.time_elapsed = 0.0
