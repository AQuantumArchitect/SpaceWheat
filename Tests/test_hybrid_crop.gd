#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Hybrid Crop Test: Wheat-Mushroom dual emoji qubit
## Plant in day, night, and equator phases to see hybrid performance

var farm = null
var game_manager = null
var test_complete = false

func _process(delta):
	if not test_complete:
		test_complete = true
		await run_experiment()

func run_experiment():
	print("\n" + "═".repeat(100))
	print("HYBRID CROP TEST: 🌾🍄 Dual emoji qubit in three zones")
	print("═".repeat(100) + "\n")

	const MemoryManager = preload("res://Core/GameState/MemoryManager.gd")
	game_manager = MemoryManager.new()
	root.add_child(game_manager)
	game_manager.new_game("default")

	const Farm = preload("res://Core/Farm.gd")
	farm = Farm.new()
	root.add_child(farm)
	await root.get_tree().process_frame

	const PhaseConstraint = preload("res://Core/GameMechanics/PhaseConstraint.gd")

	# Setup 3 hybrid crops in different phases
	print("SETUP: Planting 3 hybrid 🌾🍄 crops in different zones\n")

	# Plot 1: Hybrid at DAY (θ=0, wheat native phase)
	var hybrid_day_pos = Vector2i(0, 0)
	var hybrid_day_plot = farm.grid.get_plot(hybrid_day_pos)
	var hybrid_day = farm.biome.create_quantum_state(hybrid_day_pos, "🌾", "🍄", 0.0)
	hybrid_day.radius = 0.3
	hybrid_day_plot.plant(hybrid_day)
	hybrid_day_plot.phase_constraint = PhaseConstraint.new(
		PhaseConstraint.ConstraintType.FROZEN, 0.0, 0.0
	)
	print("  Plot 1: 🌾🍄 HYBRID at DAY (θ=0°) - Wheat zone")

	# Plot 2: Hybrid at NIGHT (θ=π, mushroom native phase)
	var hybrid_night_pos = Vector2i(1, 0)
	var hybrid_night_plot = farm.grid.get_plot(hybrid_night_pos)
	var hybrid_night = farm.biome.create_quantum_state(hybrid_night_pos, "🌾", "🍄", PI)
	hybrid_night.radius = 0.3
	hybrid_night_plot.plant(hybrid_night)
	hybrid_night_plot.phase_constraint = PhaseConstraint.new(
		PhaseConstraint.ConstraintType.FROZEN, PI, 0.0
	)
	print("  Plot 2: 🌾🍄 HYBRID at NIGHT (θ=π) - Mushroom zone")

	# Plot 3: Hybrid at EQUATOR (θ=π/2, balanced)
	var hybrid_mid_pos = Vector2i(2, 0)
	var hybrid_mid_plot = farm.grid.get_plot(hybrid_mid_pos)
	var hybrid_mid = farm.biome.create_quantum_state(hybrid_mid_pos, "🌾", "🍄", PI/2.0)
	hybrid_mid.radius = 0.3
	hybrid_mid_plot.plant(hybrid_mid)
	hybrid_mid_plot.phase_constraint = PhaseConstraint.new(
		PhaseConstraint.ConstraintType.FROZEN, PI/2.0, 0.0
	)
	print("  Plot 3: 🌾🍄 HYBRID at EQUATOR (θ=π/2) - Balanced zone")

	print("\n" + "─".repeat(100))
	print("EXPERIMENT: 60-second simulation (3 full day-night cycles)")
	print("─".repeat(100) + "\n")

	farm.biome.time_elapsed = 0.0

	print("Time (s) | Day Zone   | Night Zone | Equator")
	print("─".repeat(100))

	for frame_num in range(3601):
		if frame_num > 0:
			farm.biome._process(0.016)

		# Capture every 5 seconds (300 frames)
		if frame_num % 300 == 0:
			var time_s = frame_num * 0.016
			print("  %6.1f | %10.4f | %10.4f | %10.4f" % [
				time_s,
				hybrid_day.radius,
				hybrid_night.radius,
				hybrid_mid.radius
			])

	print("\n" + "─".repeat(100))
	print("RESULTS CHART")
	print("─".repeat(100) + "\n")

	var day_growth = hybrid_day.radius - 0.3
	var night_growth = hybrid_night.radius - 0.3
	var mid_growth = hybrid_mid.radius - 0.3

	print("%-30s | %10s | %10s | %10s" % ["Zone", "Initial", "Final", "Growth"])
	print("%-30s | %10s | %10s | %10s" % ["─".repeat(30), "─".repeat(10), "─".repeat(10), "─".repeat(10)])

	print("🌾🍄 Hybrid at Day        | %10.4f | %10.4f | %10.4f" % [0.3, hybrid_day.radius, day_growth])
	print("🌾🍄 Hybrid at Night      | %10.4f | %10.4f | %10.4f" % [0.3, hybrid_night.radius, night_growth])
	print("🌾🍄 Hybrid at Equator    | %10.4f | %10.4f | %10.4f" % [0.3, hybrid_mid.radius, mid_growth])

	print("\n" + "─".repeat(100))
	print("ANALYSIS")
	print("─".repeat(100) + "\n")

	print("Hybrid Crop Performance by Zone:")
	print("  Day Zone:     %.4f growth (wheat icon advantage)" % day_growth)
	print("  Night Zone:   %.4f growth (mushroom icon advantage)" % night_growth)
	print("  Equator Zone: %.4f growth (balanced, both icons)" % mid_growth)
	print()

	var better_day_night = "Day" if day_growth > night_growth else "Night"
	var better_equator = "YES - Equator wins!" if (mid_growth > maxf(day_growth, night_growth)) else "No - zone-specific better"

	print("Zone Preference:")
	print("  Best zone: %s (%.4f > %.4f)" % [better_day_night, maxf(day_growth, night_growth), minf(day_growth, night_growth)])
	print("  Does equator beat zone-specific? %s" % better_equator)
	print()

	print("Hybrid Strategy Assessment:")
	if mid_growth > day_growth and mid_growth > night_growth:
		print("  ✓ GENERALIST: Equator positioning gives overall best growth (hedging bets)")
	elif (day_growth + night_growth) / 2.0 > mid_growth:
		print("  ✓ SPECIALIST: Zone-specific positioning beats equator (specialization wins)")
	else:
		print("  ~ BALANCED: Equator is compromise between zone-specific strategies")

	print("\n" + "═".repeat(100))
	print("HYBRID CROP TEST COMPLETE")
	print("═".repeat(100) + "\n")

	quit()
