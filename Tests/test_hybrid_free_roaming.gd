#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Free-Roaming Hybrid Crop Test: 🌾🍄 evolves freely under spring attraction
## Compare: specialist wheat (day), specialist mushroom (night), free hybrid

var farm = null
var game_manager = null
var test_complete = false

func _process(delta):
	if not test_complete:
		test_complete = true
		await run_experiment()

func run_experiment():
	print("\n" + "═".repeat(100))
	print("FREE-ROAMING HYBRID TEST: 🌾🍄 with dual spring attraction")
	print("═".repeat(100) + "\n")

	const MemoryManager = preload("res://Core/GameState/MemoryManager.gd")
	game_manager = MemoryManager.new()
	root.add_child(game_manager)
	game_manager.new_game("default")

	const Farm = preload("res://Core/Farm.gd")
	farm = Farm.new()
	root.add_child(farm)
	await root.get_tree().process_frame

	# Setup: specialist wheat, specialist mushroom, free-roaming hybrid
	print("SETUP: Planting specialist crops + free-roaming hybrid\n")

	# Plot 1: Specialist wheat at day (θ=0, naturally stable here)
	var wheat_pos = Vector2i(0, 0)
	var wheat_plot = farm.grid.get_plot(wheat_pos)
	var wheat = farm.biome.create_quantum_state(wheat_pos, "🌾", "⚪", 0.0)
	wheat.radius = 0.3
	wheat_plot.plant(wheat)
	print("  Plot 1: 🌾 WHEAT specialist at day (θ=0°)")

	# Plot 2: Specialist mushroom at night (θ=π, naturally stable here)
	var mushroom_pos = Vector2i(1, 0)
	var mushroom_plot = farm.grid.get_plot(mushroom_pos)
	var mushroom = farm.biome.create_quantum_state(mushroom_pos, "🍄", "🌙", PI)
	mushroom.radius = 0.3
	mushroom_plot.plant(mushroom)
	print("  Plot 2: 🍄 MUSHROOM specialist at night (θ=π)")

	# Plot 3: FREE-ROAMING HYBRID - no phase constraint, starts at equator
	var hybrid_pos = Vector2i(2, 0)
	var hybrid_plot = farm.grid.get_plot(hybrid_pos)
	var hybrid = farm.biome.create_quantum_state(hybrid_pos, "🌾", "🍄", PI/2.0)
	hybrid.radius = 0.3
	hybrid_plot.plant(hybrid)
	print("  Plot 3: 🌾🍄 HYBRID free-roaming at equator (θ=π/2) - NO constraint")

	print("\n" + "─".repeat(100))
	print("EXPERIMENT: 60-second simulation with dual spring attraction")
	print("─".repeat(100) + "\n")

	farm.biome.time_elapsed = 0.0

	print("Time (s) | Wheat θ(°) | Mushroom θ(°) | Hybrid θ(°) | W.Radius | M.Radius | H.Radius")
	print("─".repeat(100))

	for frame_num in range(3601):
		if frame_num > 0:
			farm.biome._process(0.016)

		# Capture every 5 seconds (300 frames)
		if frame_num % 300 == 0:
			var time_s = frame_num * 0.016
			var wheat_theta_deg = wheat.theta * 180.0 / PI
			var mushroom_theta_deg = mushroom.theta * 180.0 / PI
			var hybrid_theta_deg = hybrid.theta * 180.0 / PI

			print("  %6.1f | %10.2f | %13.2f | %11.2f | %8.4f | %8.4f | %8.4f" % [
				time_s,
				wheat_theta_deg,
				mushroom_theta_deg,
				hybrid_theta_deg,
				wheat.radius,
				mushroom.radius,
				hybrid.radius
			])

	print("\n" + "─".repeat(100))
	print("RESULTS")
	print("─".repeat(100) + "\n")

	var wheat_growth = wheat.radius - 0.3
	var mushroom_growth = mushroom.radius - 0.3
	var hybrid_growth = hybrid.radius - 0.3

	var wheat_theta_final = wheat.theta * 180.0 / PI
	var mushroom_theta_final = mushroom.theta * 180.0 / PI
	var hybrid_theta_final = hybrid.theta * 180.0 / PI

	print("%-35s | %10s | %10s | %10s" % ["Crop", "Final θ(°)", "Initial R", "Final R"])
	print("%-35s | %10s | %10s | %10s" % ["─".repeat(35), "─".repeat(10), "─".repeat(10), "─".repeat(10)])

	print("🌾 Wheat specialist (day)    | %10.2f | %10.4f | %10.4f" % [wheat_theta_final, 0.3, wheat.radius])
	print("🍄 Mushroom specialist (night)| %10.2f | %10.4f | %10.4f" % [mushroom_theta_final, 0.3, mushroom.radius])
	print("🌾🍄 Hybrid (free-roaming)   | %10.2f | %10.4f | %10.4f" % [hybrid_theta_final, 0.3, hybrid.radius])

	print("\n" + "─".repeat(100))
	print("GROWTH ANALYSIS")
	print("─".repeat(100) + "\n")

	print("Growth Rates (Δ radius):")
	print("  Wheat specialist:     %.4f" % wheat_growth)
	print("  Mushroom specialist:  %.4f" % mushroom_growth)
	print("  Hybrid (free-roaming): %.4f" % hybrid_growth)
	print()

	print("Final Position on Bloch Sphere:")
	print("  Wheat: θ=%6.2f° (native day phase)" % wheat_theta_final)
	print("  Mushroom: θ=%6.2f° (native night phase)" % mushroom_theta_final)
	print("  Hybrid: θ=%6.2f° (evolved from equator toward %s)" % [
		hybrid_theta_final,
		"day" if abs(hybrid_theta_final) < 90 else "night" if abs(hybrid_theta_final - 180) < 90 else "equator"
	])
	print()

	var better_wheat_mushroom = "Wheat" if wheat_growth > mushroom_growth else "Mushroom"
	var hybrid_comparison = ""
	if hybrid_growth > maxf(wheat_growth, mushroom_growth):
		hybrid_comparison = "HYBRID WINS - generalist strategy beats both specialists!"
	elif hybrid_growth > minf(wheat_growth, mushroom_growth):
		hybrid_comparison = "Hybrid beats worst specialist but not best"
	else:
		hybrid_comparison = "Specialists beat hybrid (specialization advantage)"

	print("Strategy Assessment:")
	print("  Best specialist: %s (%.4f > %.4f)" % [better_wheat_mushroom, maxf(wheat_growth, mushroom_growth), minf(wheat_growth, mushroom_growth)])
	print("  Hybrid performance: %s" % hybrid_comparison)
	print()

	# Check if hybrid evolved toward a stable point
	var wheat_stable = 45.0  # π/4 in degrees
	var mushroom_stable = 180.0  # π in degrees
	var dist_to_wheat = fmod(abs(hybrid_theta_final - wheat_stable) + 180.0, 360.0) - 180.0
	var dist_to_mushroom = fmod(abs(hybrid_theta_final - mushroom_stable) + 180.0, 360.0) - 180.0
	dist_to_wheat = abs(dist_to_wheat)
	dist_to_mushroom = abs(dist_to_mushroom)

	print("Spring Attraction Dynamics:")
	print("  Wheat stable point: θ=45° (π/4), distance: %.2f°" % dist_to_wheat)
	print("  Mushroom stable point: θ=180° (π), distance: %.2f°" % dist_to_mushroom)

	if dist_to_wheat < dist_to_mushroom:
		print("  → Hybrid drifted toward WHEAT stable point (π/4)")
	else:
		print("  → Hybrid drifted toward MUSHROOM stable point (π)")

	print("\n" + "═".repeat(100))
	print("FREE-ROAMING HYBRID TEST COMPLETE")
	print("═".repeat(100) + "\n")

	quit()
