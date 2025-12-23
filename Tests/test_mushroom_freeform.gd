#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Mushroom-Autumn Test: 🍄🍂 free-roaming pair with sprout/collapse cycles
## Test icon_influence=0.04 and sun_damage=0.01 with dual emoji pair

var farm = null
var game_manager = null
var test_complete = false

func _process(delta):
	if not test_complete:
		test_complete = true
		await run_experiment()

func run_experiment():
	print("\n" + "═".repeat(100))
	print("MUSHROOM-AUTUMN TEST: 🍄🍂 free-roaming with sprout/collapse dynamics")
	print("═".repeat(100) + "\n")

	const MemoryManager = preload("res://Core/GameState/MemoryManager.gd")
	game_manager = MemoryManager.new()
	root.add_child(game_manager)
	game_manager.new_game("default")

	const Farm = preload("res://Core/Farm.gd")
	farm = Farm.new()
	root.add_child(farm)
	await root.get_tree().process_frame

	# Setup: specialist mushroom, specialist autumn, free-roaming pair
	print("SETUP: Planting specialist crops + free-roaming 🍄🍂 pair\n")

	# Plot 1: Specialist mushroom at night (θ=π, native)
	var mushroom_pos = Vector2i(0, 0)
	var mushroom_plot = farm.grid.get_plot(mushroom_pos)
	var mushroom = farm.biome.create_quantum_state(mushroom_pos, "🍄", "🌙", PI)
	mushroom.radius = 0.3
	mushroom_plot.plant(mushroom)
	print("  Plot 1: 🍄 MUSHROOM specialist at night (θ=π)")

	# Plot 2: Specialist autumn at day (θ=0, opposite of mushroom)
	var autumn_pos = Vector2i(1, 0)
	var autumn_plot = farm.grid.get_plot(autumn_pos)
	var autumn = farm.biome.create_quantum_state(autumn_pos, "🍂", "☀️", 0.0)
	autumn.radius = 0.3
	autumn_plot.plant(autumn)
	print("  Plot 2: 🍂 AUTUMN specialist at day (θ=0°)")

	# Plot 3: FREE-ROAMING PAIR - starts at equator
	var pair_pos = Vector2i(2, 0)
	var pair_plot = farm.grid.get_plot(pair_pos)
	var pair = farm.biome.create_quantum_state(pair_pos, "🍄", "🍂", PI/2.0)
	pair.radius = 0.3
	pair_plot.plant(pair)
	print("  Plot 3: 🍄🍂 PAIR free-roaming at equator (θ=π/2) - NO constraint")

	print("\n" + "─".repeat(100))
	print("EXPERIMENT: 60-second simulation - watch for sprout/collapse cycles")
	print("Sun damage=0.01/sec (low), Mushroom growth=0.04 influence")
	print("─".repeat(100) + "\n")

	farm.biome.time_elapsed = 0.0

	print("Time (s) | Sun θ(°) | Mushroom θ | Autumn θ | Pair θ | M.Radius | A.Radius | P.Radius")
	print("─".repeat(100))

	var max_pair_radius = 0.3
	var min_pair_radius = 0.3

	for frame_num in range(3601):
		if frame_num > 0:
			farm.biome._process(0.016)

		# Track extremes
		if pair.radius > max_pair_radius:
			max_pair_radius = pair.radius
		if pair.radius < min_pair_radius:
			min_pair_radius = pair.radius

		# Capture every 5 seconds (300 frames)
		if frame_num % 300 == 0:
			var time_s = frame_num * 0.016
			var sun_theta_deg = farm.biome.sun_qubit.theta * 180.0 / PI
			var mushroom_theta_deg = mushroom.theta * 180.0 / PI
			var autumn_theta_deg = autumn.theta * 180.0 / PI
			var pair_theta_deg = pair.theta * 180.0 / PI

			print("  %6.1f | %8.2f | %10.2f | %8.2f | %6.2f | %8.4f | %8.4f | %8.4f" % [
				time_s,
				sun_theta_deg,
				mushroom_theta_deg,
				autumn_theta_deg,
				pair_theta_deg,
				mushroom.radius,
				autumn.radius,
				pair.radius
			])

	print("\n" + "─".repeat(100))
	print("RESULTS")
	print("─".repeat(100) + "\n")

	var mushroom_growth = mushroom.radius - 0.3
	var autumn_growth = autumn.radius - 0.3
	var pair_growth = pair.radius - 0.3

	var mushroom_theta_final = mushroom.theta * 180.0 / PI
	var autumn_theta_final = autumn.theta * 180.0 / PI
	var pair_theta_final = pair.theta * 180.0 / PI

	print("%-35s | %10s | %10s | %10s" % ["Crop", "Final θ(°)", "Initial R", "Final R"])
	print("%-35s | %10s | %10s | %10s" % ["─".repeat(35), "─".repeat(10), "─".repeat(10), "─".repeat(10)])

	print("🍄 Mushroom specialist (night)  | %10.2f | %10.4f | %10.4f" % [mushroom_theta_final, 0.3, mushroom.radius])
	print("🍂 Autumn specialist (day)      | %10.2f | %10.4f | %10.4f" % [autumn_theta_final, 0.3, autumn.radius])
	print("🍄🍂 Pair (free-roaming)        | %10.2f | %10.4f | %10.4f" % [pair_theta_final, 0.3, pair.radius])

	print("\n" + "─".repeat(100))
	print("GROWTH ANALYSIS")
	print("─".repeat(100) + "\n")

	print("Growth Rates (Δ radius):")
	print("  Mushroom specialist:  %.4f" % mushroom_growth)
	print("  Autumn specialist:    %.4f" % autumn_growth)
	print("  Pair (free-roaming):  %.4f" % pair_growth)
	print()

	print("Sprout/Collapse Dynamics (Pair):")
	print("  Max radius reached: %.4f" % max_pair_radius)
	print("  Min radius reached: %.4f" % min_pair_radius)
	print("  Final radius: %.4f" % pair.radius)
	print("  Volatility (max-min): %.4f" % (max_pair_radius - min_pair_radius))
	print()

	print("Final Position on Bloch Sphere:")
	print("  Mushroom: θ=%6.2f° (native night phase)" % mushroom_theta_final)
	print("  Autumn: θ=%6.2f° (native day phase)" % autumn_theta_final)
	print("  Pair: θ=%6.2f°" % pair_theta_final)
	print()

	var better_specialist = "Mushroom" if mushroom_growth > autumn_growth else "Autumn"
	var pair_vs_best = ""
	if pair_growth > maxf(mushroom_growth, autumn_growth):
		pair_vs_best = "PAIR WINS - dual emoji benefits exceed specialists!"
	elif pair_growth > minf(mushroom_growth, autumn_growth):
		pair_vs_best = "Pair beats worst specialist but not best"
	else:
		pair_vs_best = "Specialists beat pair (specialization advantage)"

	print("Strategy Assessment:")
	print("  Best specialist: %s (%.4f > %.4f)" % [better_specialist, maxf(mushroom_growth, autumn_growth), minf(mushroom_growth, autumn_growth)])
	print("  Pair performance: %s" % pair_vs_best)
	print()

	# Check for sprout/collapse cycles
	var is_volatile = (max_pair_radius - min_pair_radius) > 0.15
	if is_volatile:
		print("SPROUT/COLLAPSE PATTERN: ✓ Observed (volatility: %.4f)" % (max_pair_radius - min_pair_radius))
		print("  Sun damage creates day-collapse, night-recovery cycle with 0.01/sec rate")
	else:
		print("SPROUT/COLLAPSE PATTERN: ~ Minimal (volatility: %.4f)" % (max_pair_radius - min_pair_radius))

	print("\n" + "═".repeat(100))
	print("MUSHROOM-AUTUMN TEST COMPLETE")
	print("═".repeat(100) + "\n")

	quit()
