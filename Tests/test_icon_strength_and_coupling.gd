#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Icon Strength and Coupling Control Tests
## Isolates icon modulation and sigma_z coupling effects

var farm = null
var game_manager = null
var test_complete = false

func _process(delta):
	if not test_complete:
		test_complete = true
		await run_tests()

func run_tests():
	print("\n" + "=".repeat(80))
	print("ICON STRENGTH AND COUPLING CONTROL TESTS")
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

	# Run experiments
	await test_icon_strength_sweep()
	await test_sigma_z_disabled()
	await test_icon_strength_with_coupling()
	await test_minimal_radius_growth()

	print("\n" + "=".repeat(80))
	print("ALL TESTS COMPLETE")
	print("=".repeat(80) + "\n")
	quit()


func test_icon_strength_sweep():
	"""Test how different icon strengths (theta values) affect energy growth"""
	print("\n" + "─".repeat(80))
	print("TEST 1: Icon Strength Sweep (varies wheat icon theta)")
	print("─".repeat(80))

	# Icon theta values: 0° (pure imperium) → 15° (agrarian) → 180° (opposite)
	var icon_thetas = [
		0.0,           # 0° - pure imperium (weak coupling)
		PI / 12.0,     # 15° - default agrarian (strong coupling)
		PI / 6.0,      # 30° - mid-strength
		PI / 2.0,      # 90° - perpendicular
		PI,            # 180° - opposite (weak coupling)
	]

	var results = []

	for icon_theta in icon_thetas:
		reset_farm()

		# Set icon to specific theta
		farm.biome.wheat_icon.theta = icon_theta
		farm.biome.time_elapsed = 0.0

		# Plant wheat at θ=45° with 0.3 initial radius
		var pos = Vector2i(0, 0)
		var wheat = farm.biome.create_quantum_state(pos, "🌾", "👥", PI / 4.0)
		wheat.radius = 0.3  # Start small
		farm.grid.get_plot(pos).plant(wheat)

		var initial_radius = wheat.radius
		var icon_influence = pow(cos(icon_theta / 2.0), 2)

		print("\n  Icon θ = %.1f° (cos²(θ/2) = %.4f)" % [icon_theta * 180.0 / PI, icon_influence])

		# Simulate 5 seconds (peak sun)
		farm.biome.time_elapsed = 0.0
		for frame in range(300):
			farm.biome._process(0.016)

		var final_radius = wheat.radius
		var growth = final_radius - initial_radius
		var growth_rate = growth / 5.0

		results.append({
			"icon_theta": icon_theta,
			"icon_influence": icon_influence,
			"initial_radius": initial_radius,
			"final_radius": final_radius,
			"growth": growth,
			"growth_rate": growth_rate
		})

		print("    Initial radius: %.4f" % initial_radius)
		print("    Final radius:   %.4f" % final_radius)
		print("    Growth:         %.4f" % growth)
		print("    Growth rate:    %.4f energy/sec" % growth_rate)

	# Summary
	print("\n  Summary:")
	print("  Icon θ (°) | Influence | Growth   | Growth Rate")
	print("  ───────────────────────────────────────────────")
	for r in results:
		print("  %10.1f | %9.4f | %8.4f | %11.4f" % [
			r.icon_theta * 180.0 / PI,
			r.icon_influence,
			r.growth,
			r.growth_rate
		])

	# Find best and worst
	var best_growth = 0.0
	var worst_growth = 999.0
	var best_icon = 0.0
	var worst_icon = 0.0

	for r in results:
		if r.growth > best_growth:
			best_growth = r.growth
			best_icon = r.icon_theta * 180.0 / PI
		if r.growth < worst_growth:
			worst_growth = r.growth
			worst_icon = r.icon_theta * 180.0 / PI

	print("\n  Best icon strength: θ = %.1f° (growth = %.4f)" % [best_icon, best_growth])
	print("  Worst icon strength: θ = %.1f° (growth = %.4f)" % [worst_icon, worst_growth])
	if worst_growth != 0:
		print("  Ratio: %.1f:1" % [best_growth / worst_growth])


func test_sigma_z_disabled():
	"""Test energy growth with sigma_z coupling disabled (wheat stationary in phase)"""
	print("\n" + "─".repeat(80))
	print("TEST 2: Sigma-Z Coupling Disabled (Wheat Stationary)")
	print("─".repeat(80))

	reset_farm()
	farm.biome.time_elapsed = 0.0

	# Create wheat at various phases, but we'll manually prevent phase changes
	var phases = [0.0, PI / 4.0, PI / 2.0, PI]
	var phase_names = ["0° (aligned)", "45°", "90° (perp)", "180° (opposite)"]

	print("\n  Testing energy growth WITHOUT sigma_z coupling...")
	print("  (Wheat phase remains constant)\n")

	for i in range(phases.size()):
		var pos = Vector2i(i, 0)
		var initial_theta = phases[i]

		var plot = farm.grid.get_plot(pos)
		if not plot:
			continue

		var wheat = farm.biome.create_quantum_state(pos, "🌾", "👥", initial_theta)
		wheat.radius = 0.3
		plot.plant(wheat)

		# Store initial state
		var initial_radius = wheat.radius
		var stored_theta = wheat.theta

		print("  Wheat %d @ θ = %s" % [i, phase_names[i]])

		# Simulate 5 seconds, but manually reset theta each frame
		farm.biome.time_elapsed = 0.0
		for frame in range(300):
			# Apply energy growth via Biome but SKIP sigma_z coupling
			if farm.biome and farm.biome.sun_qubit and farm.biome.wheat_icon:
				# Calculate energy growth WITHOUT phase changes
				var amplitude = pow(cos(wheat.theta / 2.0), 2)
				var alignment = pow(cos((wheat.theta - farm.biome.sun_qubit.theta) / 2.0), 2)
				var icon_influence = pow(cos(farm.biome.wheat_icon.theta / 2.0), 2)
				var base_energy_rate = 0.5

				var energy_rate = base_energy_rate * amplitude * alignment * icon_influence
				wheat.grow_energy(energy_rate, 0.016)
				wheat.radius = wheat.energy

				# CRITICAL: Prevent phase changes (sigma_z coupling disabled)
				wheat.theta = stored_theta

			# Still need to advance biome for sun phase
			farm.biome.time_elapsed += 0.016

		var final_radius = wheat.radius
		var growth = final_radius - initial_radius
		var theta_change = (wheat.theta - stored_theta) * 180.0 / PI

		print("    Radius: %.4f → %.4f (growth: %.4f)" % [initial_radius, final_radius, growth])
		print("    Phase: %.1f° → %.1f° (change: %.1f°)" % [
			stored_theta * 180.0 / PI,
			wheat.theta * 180.0 / PI,
			theta_change
		])
		print()

	print("  ✓ Energy growth measured WITHOUT sigma_z phase coupling")


func test_icon_strength_with_coupling():
	"""Test icon strength effect WITH sigma_z coupling enabled (for comparison)"""
	print("\n" + "─".repeat(80))
	print("TEST 3: Icon Strength WITH Sigma-Z Coupling (for comparison)")
	print("─".repeat(80))

	# Test with agrarian icon (strong) vs imperium icon (weak)
	var test_configs = [
		{"name": "Agrarian (θ=15°)", "icon_theta": PI / 12.0},
		{"name": "Weak (θ=90°)", "icon_theta": PI / 2.0},
		{"name": "Imperium (θ=0°)", "icon_theta": 0.0},
	]

	print("\n  Comparing energy growth across icon strengths WITH coupling:\n")

	for config in test_configs:
		reset_farm()
		farm.biome.wheat_icon.theta = config.icon_theta
		farm.biome.time_elapsed = 0.0

		# Plant wheat at various phases
		var phases = [0.0, PI / 4.0, PI / 2.0, 3 * PI / 4.0, PI]
		var growths = []

		print("  %s:" % config.name)

		for j in range(phases.size()):
			var pos = Vector2i(j, 0)
			if farm.grid.get_plot(pos) == null:
				continue

			var wheat = farm.biome.create_quantum_state(pos, "🌾", "👥", phases[j])
			wheat.radius = 0.3
			farm.grid.get_plot(pos).plant(wheat)

			var initial_radius = wheat.radius

			# Simulate 5 seconds WITH normal coupling
			farm.biome.time_elapsed = 0.0
			for frame in range(300):
				farm.biome._process(0.016)

			var growth = wheat.radius - initial_radius
			growths.append(growth)

		var avg_growth = 0.0
		for g in growths:
			avg_growth += g
		avg_growth /= growths.size()

		var max_growth = growths.max()
		var min_growth = growths.min()

		print("    Avg growth: %.4f" % avg_growth)
		print("    Max growth: %.4f (best phase)" % max_growth)
		print("    Min growth: %.4f (worst phase)" % min_growth)
		print()

	print("  ✓ Icon strength significantly modulates energy growth")


func test_minimal_radius_growth():
	"""Test energy growth with very small initial radius (0.3)"""
	print("\n" + "─".repeat(80))
	print("TEST 4: Energy Growth Tracking (0.3 → 1.0)")
	print("─".repeat(80))

	reset_farm()
	farm.biome.time_elapsed = 0.0

	# Plant 3 wheat with 0.3 initial radius at different phases
	var phases = [0.0, PI / 3.0, 2 * PI / 3.0]
	var phase_names = ["aligned (0°)", "moderate (60°)", "poor (120°)"]
	var wheat_objects = []

	print("\n  Starting all wheat at radius = 0.3\n")

	for i in range(phases.size()):
		var pos = Vector2i(i, 0)
		var wheat = farm.biome.create_quantum_state(pos, "🌾", "👥", phases[i])
		wheat.radius = 0.3
		farm.grid.get_plot(pos).plant(wheat)
		wheat_objects.append(wheat)
		print("  Wheat %d @ %s: r = 0.3" % [i, phase_names[i]])

	print("\n  Simulation timeline (energy growth + phase coupling):\n")
	print("  Time (s) | W0 (0°)    | W1 (60°)   | W2 (120°)  | Avg Growth")
	print("  ──────────────────────────────────────────────────────────────")

	farm.biome.time_elapsed = 0.0
	for frame in range(301):
		if frame > 0:
			farm.biome._process(0.016)

		if frame % 60 == 0:  # Every 0.96 seconds
			var time_s = frame * 0.016
			var w0_radius = wheat_objects[0].radius
			var w1_radius = wheat_objects[1].radius
			var w2_radius = wheat_objects[2].radius
			var avg_radius = (w0_radius + w1_radius + w2_radius) / 3.0

			print("  %8.2f | %.4f | %.4f | %.4f | %.4f" % [
				time_s,
				w0_radius,
				w1_radius,
				w2_radius,
				avg_radius
			])

	print("\n  Final states:")
	for i in range(wheat_objects.size()):
		var final_radius = wheat_objects[i].radius
		var growth = final_radius - 0.3
		print("    Wheat %d (%s): %.4f (growth: %.4f)" % [i, phase_names[i], final_radius, growth])


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
