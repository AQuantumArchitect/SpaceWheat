#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Icon Formula Debugging
## Trace the actual formula values frame-by-frame

var farm = null
var game_manager = null
var test_complete = false

func _process(delta):
	if not test_complete:
		test_complete = true
		await run_tests()

func run_tests():
	print("\n" + "=".repeat(80))
	print("ICON FORMULA DEBUG - TRACE ACTUAL CALCULATIONS")
	print("=".repeat(80) + "\n")

	const MemoryManager = preload("res://Core/GameState/MemoryManager.gd")
	game_manager = MemoryManager.new()
	root.add_child(game_manager)
	game_manager.new_game("default")

	const Farm = preload("res://Core/Farm.gd")
	farm = Farm.new()
	root.add_child(farm)
	await root.get_tree().process_frame

	await test_icon_formula_trace()
	await test_different_icons_isolated()

	print("\n" + "=".repeat(80))
	print("DEBUG COMPLETE")
	print("=".repeat(80) + "\n")
	quit()


func test_icon_formula_trace():
	"""Trace formula values over time with fixed wheat theta"""
	print("─".repeat(80))
	print("TEST: Icon Formula Trace (Wheat Locked at θ=45°)")
	print("─".repeat(80))

	# Reset
	for x in range(farm.grid.grid_width):
		for y in range(farm.grid.grid_height):
			var pos = Vector2i(x, y)
			var plot = farm.grid.get_plot(pos)
			if plot and plot.is_planted:
				plot.is_planted = false
				farm.biome.clear_qubit(pos)

	farm.biome.time_elapsed = 0.0

	# Plant wheat at fixed 45°
	var pos = Vector2i(0, 0)
	var wheat = farm.biome.create_quantum_state(pos, "🌾", "👥", PI / 4.0)
	wheat.radius = 0.3
	farm.grid.get_plot(pos).plant(wheat)

	var original_theta = wheat.theta

	# Test with agrarian icon
	farm.biome.wheat_icon.theta = PI / 12.0
	var agrarian_influence = pow(cos(farm.biome.wheat_icon.theta / 2.0), 2)

	print("\n  Config:")
	print("    Wheat θ: %.1f° (locked)" % (original_theta * 180.0 / PI))
	print("    Icon θ: %.1f° (agrarian, influence=%.4f)" % [
		farm.biome.wheat_icon.theta * 180.0 / PI,
		agrarian_influence
	])

	print("\n  Frame-by-frame formula trace:\n")
	print("  Frame | Time(s) | Sun θ (°) | Align Factor | Amplitude | Icon Inf | Energy Rate | R Growth")
	print("  ──────────────────────────────────────────────────────────────────────────────────────")

	farm.biome.time_elapsed = 0.0

	var energy_rates = []
	var radii = []

	for frame in range(0, 301, 60):  # Every 1 second
		farm.biome._process(0.016)

		if frame % 60 == 0:
			var sun_theta = farm.biome.sun_qubit.theta
			var amplitude = pow(cos(wheat.theta / 2.0), 2)
			var alignment = pow(cos((wheat.theta - sun_theta) / 2.0), 2)
			var icon_influence = pow(cos(farm.biome.wheat_icon.theta / 2.0), 2)
			var energy_rate = 0.5 * amplitude * alignment * icon_influence

			radii.append(wheat.radius)
			energy_rates.append(energy_rate)

			if farm.biome.sun_qubit.theta > PI:
				print("  %5d | %7.2f | (moon)     | --         | %.4f | %.4f | %.6f       | %.4f (no sun)" % [
					frame, frame * 0.016, amplitude, icon_influence, energy_rate, wheat.radius
				])
			else:
				print("  %5d | %7.2f | %9.1f | %.4f      | %.4f | %.4f | %.6f       | %.4f" % [
					frame, frame * 0.016, sun_theta * 180.0 / PI, alignment, amplitude,
					icon_influence, energy_rate, wheat.radius
				])

	# Manually apply remaining frames to get to 5 seconds
	while farm.biome.time_elapsed < 5.0:
		farm.biome._process(0.016)

	var final_radius = wheat.radius
	var total_growth = final_radius - 0.3

	print("\n  Summary:")
	print("    Initial radius: 0.3000")
	print("    Final radius:   %.4f" % final_radius)
	print("    Total growth:   %.4f" % total_growth)
	print("    Avg energy rate: %.6f" % (energy_rates.reduce(func(acc, x): return acc + x, 0.0) / energy_rates.size()))


func test_different_icons_isolated():
	"""Test with icon frozen and wheat at key phase"""
	print("\n" + "─".repeat(80))
	print("TEST: Different Icons (with Fixed Sun Phase)")
	print("─".repeat(80))

	var icons_to_test = [
		{"theta": 0.0, "name": "Imperium (0°)"},
		{"theta": PI / 12.0, "name": "Agrarian (15°)"},
		{"theta": PI / 2.0, "name": "Perpendicular (90°)"},
		{"theta": PI, "name": "Opposition (180°)"},
	]

	print("\n  Comparing icons with wheat at θ=45°, sun frozen at θ=0°:\n")
	print("  Icon Type          | Influence | Formula Value | Actual Growth")
	print("  ────────────────────────────────────────────────────────────")

	for icon_config in icons_to_test:
		# Reset
		for x in range(farm.grid.grid_width):
			for y in range(farm.grid.grid_height):
				var pos = Vector2i(x, y)
				var plot = farm.grid.get_plot(pos)
				if plot and plot.is_planted:
					plot.is_planted = false
					farm.biome.clear_qubit(pos)

		farm.biome.time_elapsed = 0.0

		# Set icon
		farm.biome.wheat_icon.theta = icon_config.theta

		# Plant wheat
		var pos = Vector2i(0, 0)
		var wheat = farm.biome.create_quantum_state(pos, "🌾", "👥", PI / 4.0)
		wheat.radius = 0.3
		farm.grid.get_plot(pos).plant(wheat)

		# Calculate expected formula value
		var amplitude = pow(cos(wheat.theta / 2.0), 2)  # cos²(22.5°) ≈ 0.854
		var alignment = pow(cos((wheat.theta - 0.0) / 2.0), 2)  # cos²(22.5°) ≈ 0.854
		var icon_influence = pow(cos(icon_config.theta / 2.0), 2)
		var expected_rate = 0.5 * amplitude * alignment * icon_influence

		# Simulate 5 seconds
		farm.biome.time_elapsed = 0.0
		for frame in range(300):
			farm.biome._process(0.016)

		var actual_growth = wheat.radius - 0.3

		print("  %18s | %.4f | %.6f | %.4f" % [
			icon_config.name,
			icon_influence,
			expected_rate,
			actual_growth
		])
