#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Crop Phase Comparison: All 4 combinations
## Wheat (day/night) vs Mushroom (day/night)

var farm = null
var game_manager = null
var test_complete = false

func _process(delta):
	if not test_complete:
		test_complete = true
		await run_experiment()

func run_experiment():
	print("\n" + "=".repeat(100))
	print("CROP PHASE COMPARISON: Wheat & Mushroom in all phase combinations")
	print("=".repeat(100) + "\n")

	const MemoryManager = preload("res://Core/GameState/MemoryManager.gd")
	game_manager = MemoryManager.new()
	root.add_child(game_manager)
	game_manager.new_game("default")

	const Farm = preload("res://Core/Farm.gd")
	farm = Farm.new()
	root.add_child(farm)
	await root.get_tree().process_frame

	const PhaseConstraint = preload("res://Core/GameMechanics/PhaseConstraint.gd")

	# Setup 4 crops in different phase-crop combinations
	print("SETUP: Planting 4 crops\n")

	# Plot 1: WHEAT at DAY (0°, native phase)
	var wheat_day_pos = Vector2i(0, 0)
	var wheat_day_plot = farm.grid.get_plot(wheat_day_pos)
	var wheat_day = farm.biome.create_quantum_state(wheat_day_pos, "🌾", "👥", 0.0)
	wheat_day.radius = 0.3
	wheat_day_plot.plant(wheat_day)
	wheat_day_plot.phase_constraint = PhaseConstraint.new(
		PhaseConstraint.ConstraintType.FROZEN, 0.0, 0.0
	)
	print("  Plot 1: 🌾 WHEAT at DAY (θ=0°) - NATIVE PHASE")

	# Plot 2: MUSHROOM at DAY (0°, wrong phase)
	var mush_day_pos = Vector2i(1, 0)
	var mush_day_plot = farm.grid.get_plot(mush_day_pos)
	var mush_day = farm.biome.create_quantum_state(mush_day_pos, "🍄", "🍂", 0.0)
	mush_day.radius = 0.3
	mush_day_plot.plant(mush_day)
	mush_day_plot.phase_constraint = PhaseConstraint.new(
		PhaseConstraint.ConstraintType.FROZEN, 0.0, 0.0
	)
	print("  Plot 2: 🍄 MUSHROOM at DAY (θ=0°) - WRONG PHASE")

	# Plot 3: WHEAT at NIGHT (π, wrong phase)
	var wheat_night_pos = Vector2i(2, 0)
	var wheat_night_plot = farm.grid.get_plot(wheat_night_pos)
	var wheat_night = farm.biome.create_quantum_state(wheat_night_pos, "🌾", "👥", PI)
	wheat_night.radius = 0.3
	wheat_night_plot.plant(wheat_night)
	wheat_night_plot.phase_constraint = PhaseConstraint.new(
		PhaseConstraint.ConstraintType.FROZEN, PI, 0.0
	)
	print("  Plot 3: 🌾 WHEAT at NIGHT (θ=π) - WRONG PHASE")

	# Plot 4: MUSHROOM at NIGHT (π, native phase)
	var mush_night_pos = Vector2i(3, 0)
	var mush_night_plot = farm.grid.get_plot(mush_night_pos)
	var mush_night = farm.biome.create_quantum_state(mush_night_pos, "🍄", "🍂", PI)
	mush_night.radius = 0.3
	mush_night_plot.plant(mush_night)
	mush_night_plot.phase_constraint = PhaseConstraint.new(
		PhaseConstraint.ConstraintType.FROZEN, PI, 0.0
	)
	print("  Plot 4: 🍄 MUSHROOM at NIGHT (θ=π) - NATIVE PHASE")

	print("\n" + "─".repeat(100))
	print("EXPERIMENT: 60-second simulation (3 full day-night cycles)")
	print("─".repeat(100) + "\n")

	farm.biome.time_elapsed = 0.0

	print("Time (s) | Wheat Day | Mush Day  | Wheat Nt  | Mush Nt")
	print("─".repeat(100))

	for frame_num in range(3601):
		if frame_num > 0:
			farm.biome._process(0.016)

		# Capture every 5 seconds (300 frames)
		if frame_num % 300 == 0:
			var time_s = frame_num * 0.016
			print("  %6.1f | %9.4f | %9.4f | %9.4f | %9.4f" % [
				time_s,
				wheat_day.radius,
				mush_day.radius,
				wheat_night.radius,
				mush_night.radius
			])

	print("\n" + "─".repeat(100))
	print("RESULTS CHART")
	print("─".repeat(100) + "\n")

	var wheat_day_growth = wheat_day.radius - 0.3
	var mush_day_growth = mush_day.radius - 0.3
	var wheat_night_growth = wheat_night.radius - 0.3
	var mush_night_growth = mush_night.radius - 0.3

	print("%-30s | %10s | %10s | %10s" % ["Crop & Phase", "Initial", "Final", "Growth"])
	print("%-30s | %10s | %10s | %10s" % ["-".repeat(30), "─".repeat(10), "─".repeat(10), "─".repeat(10)])

	print("🌾 Wheat at Day (native)    | %10.4f | %10.4f | %10.4f" % [0.3, wheat_day.radius, wheat_day_growth])
	print("🍄 Mushroom at Day (wrong)  | %10.4f | %10.4f | %10.4f" % [0.3, mush_day.radius, mush_day_growth])
	print("🌾 Wheat at Night (wrong)   | %10.4f | %10.4f | %10.4f" % [0.3, wheat_night.radius, wheat_night_growth])
	print("🍄 Mushroom at Night (nat)  | %10.4f | %10.4f | %10.4f" % [0.3, mush_night.radius, mush_night_growth])

	print("\n" + "─".repeat(100))
	print("ANALYSIS")
	print("─".repeat(100) + "\n")

	var max_growth = maxf(maxf(wheat_day_growth, mush_day_growth), maxf(wheat_night_growth, mush_night_growth))
	var min_growth = minf(minf(wheat_day_growth, mush_day_growth), minf(wheat_night_growth, mush_night_growth))

	print("Native Phase Advantage:")
	print("  Wheat native (day):     %.4f growth | %.0f%% advantage over wrong phase" % [
		wheat_day_growth,
		(wheat_day_growth - wheat_night_growth) / wheat_night_growth.abs() * 100
	])
	print("  Mushroom native (night): %.4f growth | %.0f%% advantage over wrong phase" % [
		mush_night_growth,
		(mush_night_growth - mush_day_growth) / mush_day_growth * 100
	])

	print("\nCrop Preference by Phase:")
	print("  Day phase best crop:   %s (%.4f vs %.4f)" % [
		"Wheat" if wheat_day_growth > mush_day_growth else "Mushroom",
		maxf(wheat_day_growth, mush_day_growth),
		minf(wheat_day_growth, mush_day_growth)
	])
	print("  Night phase best crop: %s (%.4f vs %.4f)" % [
		"Wheat" if wheat_night_growth > mush_night_growth else "Mushroom",
		maxf(wheat_night_growth, mush_night_growth),
		minf(wheat_night_growth, mush_night_growth)
	])

	print("\nBalancing Metrics:")
	print("  Native phase growth ratio: %.2f:1 (wheat:mushroom)" % [
		wheat_day_growth / mush_night_growth if mush_night_growth > 0 else 999
	])
	print("  Wrong phase penalty ratio: %.2f:1 (wheat:mushroom)" % [
		wheat_night_growth.abs() / mush_day_growth if mush_day_growth > 0 else 999
	])

	print("\n" + "=".repeat(100))
	print("CROP PHASE COMPARISON COMPLETE")
	print("=".repeat(100) + "\n")

	quit()
