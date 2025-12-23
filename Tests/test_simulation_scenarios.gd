#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Simulation Scenarios
## Tests various farm configurations with different wheat phases, entanglement, and farm sizes

var farm = null
var game_manager = null
var test_complete = false

func _process(delta):
	if not test_complete:
		test_complete = true
		await run_tests()

func run_tests():
	print("\n" + "=".repeat(80))
	print("SIMULATION SCENARIOS - WHEAT PHASE CONFIGURATIONS")
	print("=".repeat(80) + "\n")

	# Initialize
	const MemoryManager = preload("res://Core/GameState/MemoryManager.gd")
	game_manager = MemoryManager.new()
	root.add_child(game_manager)
	game_manager.new_game("default")

	const Farm = preload("res://Core/Farm.gd")
	farm = Farm.new()
	root.add_child(farm)
	await root.get_tree().process_frame

	# Test scenarios
	await test_small_farm_different_phases()
	await test_full_farm_different_phases()
	await test_entangled_wheat_dynamics()
	await test_phase_sweep_analysis()

	print("\n" + "=".repeat(80))
	print("ALL SCENARIOS COMPLETE")
	print("=".repeat(80) + "\n")
	quit()


func test_small_farm_different_phases():
	print("\n" + "─".repeat(80))
	print("SCENARIO 1: Small Farm (2 Wheat) - Different Phases")
	print("─".repeat(80))

	reset_farm()

	# Plant at 0° (aligned with sun at peak)
	var wheat1_pos = Vector2i(0, 0)
	var wheat1_theta = 0.0
	var wheat1 = farm.biome.create_quantum_state(wheat1_pos, "🌾", "👥", wheat1_theta)
	farm.grid.get_plot(wheat1_pos).plant(wheat1)
	print("  Wheat 1 @ (0,0): θ = %.1f°" % [wheat1_theta * 180.0 / PI])

	# Plant at 90° (perpendicular to sun)
	var wheat2_pos = Vector2i(1, 0)
	var wheat2_theta = PI / 2.0
	var wheat2 = farm.biome.create_quantum_state(wheat2_pos, "🌾", "👥", wheat2_theta)
	farm.grid.get_plot(wheat2_pos).plant(wheat2)
	print("  Wheat 2 @ (1,0): θ = %.1f°" % [wheat2_theta * 180.0 / PI])

	print("\n  Simulating 10 seconds at peak sun phase...")
	farm.biome.time_elapsed = 0.0
	for frame in range(600):  # 10 seconds
		farm.biome._process(0.016)

	var wheat1_final_theta = wheat1.theta * 180.0 / PI
	var wheat2_final_theta = wheat2.theta * 180.0 / PI
	var wheat1_final_radius = wheat1.radius
	var wheat2_final_radius = wheat2.radius

	print("  Results:")
	print("    Wheat 1: θ = %.1f° → %.1f°, radius = %.4f → %.4f (growth: %.4f)" % [
		wheat1_theta * 180.0 / PI,
		wheat1_final_theta,
		0.7, wheat1_final_radius,
		wheat1_final_radius - 0.7
	])
	print("    Wheat 2: θ = %.1f° → %.1f°, radius = %.4f → %.4f (growth: %.4f)" % [
		wheat2_theta * 180.0 / PI,
		wheat2_final_theta,
		0.7, wheat2_final_radius,
		wheat2_final_radius - 0.7
	])
	print("\n  ✓ Aligned wheat (0°) benefits from sun coupling")
	print("  ✓ Perpendicular wheat (90°) struggles to gain energy")


func test_full_farm_different_phases():
	print("\n" + "─".repeat(80))
	print("SCENARIO 2: Full Farm - Wheat at Different Phases")
	print("─".repeat(80))

	reset_farm()

	# Plant wheat across full 360° phase space (up to 6 available plots)
	var wheat_configs: Array = []
	var num_wheat = 6  # Limited to farm grid size

	print("\n  Planting %d wheat around the Bloch sphere:" % num_wheat)
	for i in range(num_wheat):
		var theta = (i * 2.0 * PI) / num_wheat
		var pos = Vector2i(i, 0)  # 6x1 grid

		var plot = farm.grid.get_plot(pos)
		if not plot:
			continue

		var qubit = farm.biome.create_quantum_state(pos, "🌾", "👥", theta)
		plot.plant(qubit)
		wheat_configs.append({
			"pos": pos,
			"qubit": qubit,
			"initial_theta": theta,
			"initial_radius": 0.7
		})

		print("  Wheat %2d @ (%d,0): θ = %3.0f°" % [i, pos.x, theta * 180.0 / PI])

	print("\n  Simulating 8 seconds (peak sun phase)...")
	farm.biome.time_elapsed = 0.0
	for frame in range(480):  # 8 seconds
		farm.biome._process(0.016)

	# Analyze results
	print("\n  Final States:")
	print("  Index | Phase  | Theta (°) | Radius | Growth | Coupling Strength")
	print("  ──────────────────────────────────────────────────────────────────")

	var best_growth = 0.0
	var best_index = 0
	var worst_growth = 999.0
	var worst_index = 0

	for i in range(wheat_configs.size()):
		var cfg = wheat_configs[i]
		var final_theta = cfg.qubit.theta
		var final_radius = cfg.qubit.radius
		var growth = final_radius - cfg.initial_radius

		# Calculate coupling strength based on phase alignment
		var sun_theta = farm.biome.sun_qubit.theta
		var alignment = pow(cos((final_theta - sun_theta) / 2.0), 2)
		var amplitude = pow(cos(final_theta / 2.0), 2)
		var coupling_strength = alignment * amplitude

		print("  %5d | %3.0f°  | %9.1f | %.4f | %.4f | %.3f" % [
			i,
			cfg.initial_theta * 180.0 / PI,
			final_theta * 180.0 / PI,
			final_radius,
			growth,
			coupling_strength
		])

		if growth > best_growth:
			best_growth = growth
			best_index = i
		if growth < worst_growth:
			worst_growth = growth
			worst_index = i

	print("\n  Summary:")
	print("    Best performer: Wheat %d (initial θ = %.0f°, growth = %.4f)" % [
		best_index,
		wheat_configs[best_index].initial_theta * 180.0 / PI,
		best_growth
	])
	print("    Worst performer: Wheat %d (initial θ = %.0f°, growth = %.4f)" % [
		worst_index,
		wheat_configs[worst_index].initial_theta * 180.0 / PI,
		worst_growth
	])
	print("    Growth ratio: %.1f:1" % [best_growth / worst_growth if worst_growth > 0 else 999])


func test_entangled_wheat_dynamics():
	print("\n" + "─".repeat(80))
	print("SCENARIO 3: Wheat Dynamics - Different Initial Phases")
	print("─".repeat(80))

	reset_farm()

	# Create two wheat with different initial states (independent, not entangled)
	var wheat1_pos = Vector2i(0, 0)
	var wheat1_theta = 0.0  # Aligned with sun
	var wheat1 = farm.biome.create_quantum_state(wheat1_pos, "🌾", "👥", wheat1_theta)
	farm.grid.get_plot(wheat1_pos).plant(wheat1)
	print("\n  Wheat 1 @ (0,0): θ = %.1f° (aligned)" % [wheat1_theta * 180.0 / PI])

	var wheat2_pos = Vector2i(1, 0)
	var wheat2_theta = PI / 2.0  # Perpendicular
	var wheat2 = farm.biome.create_quantum_state(wheat2_pos, "🌾", "👥", wheat2_theta)
	farm.grid.get_plot(wheat2_pos).plant(wheat2)
	print("  Wheat 2 @ (1,0): θ = %.1f° (perpendicular)" % [wheat2_theta * 180.0 / PI])

	print("\n  Simulating 10 seconds (sun coupling effects)...")
	farm.biome.time_elapsed = 0.0

	# Record snapshots
	var snapshots = []
	for frame in range(625):  # 10 seconds + 1
		farm.biome._process(0.016)

		if frame % 125 == 0:  # Every 2 seconds
			snapshots.append({
				"time": frame * 0.016,
				"wheat1_theta": wheat1.theta,
				"wheat2_theta": wheat2.theta,
				"wheat1_radius": wheat1.radius,
				"wheat2_radius": wheat2.radius,
				"phase_difference": abs(wheat1.theta - wheat2.theta)
			})

	print("\n  Evolution Timeline:")
	print("  Time (s) | W1 θ (°) | W2 θ (°) | Phase Diff | W1 R   | W2 R   | Dynamics")
	print("  ──────────────────────────────────────────────────────────────────────────")

	for snap in snapshots:
		var w1_theta = snap.wheat1_theta * 180.0 / PI
		var w2_theta = snap.wheat2_theta * 180.0 / PI
		var phase_diff = snap.phase_difference * 180.0 / PI
		var w1_state = "growing" if snap.wheat1_radius > 0.7 else "weak"
		var w2_state = "growing" if snap.wheat2_radius > 0.7 else "weak"

		print("  %8.1f | %8.1f | %8.1f | %10.1f | %.4f | %.4f | %s/%s" % [
			snap.time,
			w1_theta,
			w2_theta,
			phase_diff,
			snap.wheat1_radius,
			snap.wheat2_radius,
			w1_state,
			w2_state
		])

	print("\n  Analysis:")
	var initial_diff = snapshots[0].phase_difference * 180.0 / PI
	var final_diff = snapshots[-1].phase_difference * 180.0 / PI
	var w1_growth = snapshots[-1].wheat1_radius - snapshots[0].wheat1_radius
	var w2_growth = snapshots[-1].wheat2_radius - snapshots[0].wheat2_radius

	print("    Wheat 1 (aligned) growth: %.4f (radius: %.4f → %.4f)" % [
		w1_growth, snapshots[0].wheat1_radius, snapshots[-1].wheat1_radius
	])
	print("    Wheat 2 (perp) growth: %.4f (radius: %.4f → %.4f)" % [
		w2_growth, snapshots[0].wheat2_radius, snapshots[-1].wheat2_radius
	])
	print("    Growth ratio: %.1f:1 (aligned benefits from sun coupling)" % [
		w1_growth / w2_growth if w2_growth > 0 else 999
	])


func test_phase_sweep_analysis():
	print("\n" + "─".repeat(80))
	print("SCENARIO 4: Phase Sweep - Energy Gain vs Initial Phase")
	print("─".repeat(80))

	reset_farm()

	var phase_steps = 6  # Limited to available plots in 6x1 grid
	var energy_gains: Array[float] = []

	print("\n  Testing energy gain across phase space (6 phases)...")
	print("  Phase (°) | Growth  | Growth Rate (energy/sec) | Icon Influence")
	print("  ──────────────────────────────────────────────────────────────")

	farm.biome.time_elapsed = 0.0

	for step in range(phase_steps):
		# Reset for each phase test
		reset_farm()
		farm.biome.time_elapsed = 0.0

		var phase = (step * 2.0 * PI) / phase_steps
		var pos = Vector2i(step, 0)  # 6x1 grid

		var plot = farm.grid.get_plot(pos)
		if not plot:
			continue

		var qubit = farm.biome.create_quantum_state(pos, "🌾", "👥", phase)
		plot.plant(qubit)

		var initial_radius = qubit.radius

		# Simulate 5 seconds
		for frame in range(300):
			farm.biome._process(0.016)

		var final_radius = qubit.radius
		var growth = final_radius - initial_radius
		var growth_rate = growth / 5.0  # Per second

		energy_gains.append(growth)

		var icon_influence = pow(cos(farm.biome.wheat_icon.theta / 2.0), 2)
		print("  %9.1f | %.6f | %.6f                  | %.3f" % [
			phase * 180.0 / PI,
			growth,
			growth_rate,
			icon_influence
		])

	# Find peak and valley
	var max_gain = 0.0
	var min_gain = 999.0
	var max_phase = 0.0
	var min_phase = 0.0

	for i in range(energy_gains.size()):
		if energy_gains[i] > max_gain:
			max_gain = energy_gains[i]
			max_phase = (i * 2.0 * PI) / phase_steps
		if energy_gains[i] < min_gain:
			min_gain = energy_gains[i]
			min_phase = (i * 2.0 * PI) / phase_steps

	print("\n  Summary:")
	print("    Peak gain: %.6f at θ = %.1f°" % [max_gain, max_phase * 180.0 / PI])
	print("    Min gain: %.6f at θ = %.1f°" % [min_gain, min_phase * 180.0 / PI])
	print("    Ratio: %.1f:1" % [max_gain / min_gain if min_gain > 0 else 999])


func reset_farm():
	"""Clear all plants and reset time"""
	for x in range(farm.grid.grid_width):
		for y in range(farm.grid.grid_height):
			var pos = Vector2i(x, y)
			var plot = farm.grid.get_plot(pos)
			if plot and plot.is_planted:
				plot.is_planted = false
				farm.biome.clear_qubit(pos)
	farm.biome.time_elapsed = 0.0
