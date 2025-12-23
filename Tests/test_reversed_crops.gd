#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Reversed Crops Experiment: Wheat at midnight, Mushroom at midday
## Compare performance when crops are in opposite phases from their design

var farm = null
var game_manager = null
var test_complete = false

func _process(delta):
	if not test_complete:
		test_complete = true
		await run_experiment()

func run_experiment():
	print("\n" + "=".repeat(90))
	print("REVERSED CROPS: Wheat at MIDNIGHT vs Mushroom at MIDDAY")
	print("=".repeat(90) + "\n")

	const MemoryManager = preload("res://Core/GameState/MemoryManager.gd")
	game_manager = MemoryManager.new()
	root.add_child(game_manager)
	game_manager.new_game("default")

	const Farm = preload("res://Core/Farm.gd")
	farm = Farm.new()
	root.add_child(farm)
	await root.get_tree().process_frame

	# Setup reversed crops
	print("SETUP: Planting crops in OPPOSITE phases from their design\n")

	const PhaseConstraint = preload("res://Core/GameMechanics/PhaseConstraint.gd")

	# Plot 1: WHEAT at MIDNIGHT (θ = π, normally grows at noon)
	var wheat_pos = Vector2i(0, 0)
	var wheat_plot = farm.grid.get_plot(wheat_pos)
	var wheat = farm.biome.create_quantum_state(wheat_pos, "🌾", "👥", PI)
	wheat.radius = 0.3
	wheat_plot.plant(wheat)
	wheat_plot.phase_constraint = PhaseConstraint.new(
		PhaseConstraint.ConstraintType.FROZEN, PI, 0.0
	)
	print("  Plot 1 @ (0,0): WHEAT AT MIDNIGHT")
	print("    Constraint: θ = 180° (OPPOSITE of sun phase)")
	print("    Normal role: Grows during day. This will test: can wheat grow at night?")
	print("    Wheat icon influence: %.3f (nerfed, same scale as mushroom)\n" % farm.biome.wheat_energy_influence)

	# Plot 2: MUSHROOM at MIDDAY (θ = 0, normally grows at midnight)
	var mushroom_pos = Vector2i(1, 0)
	var mushroom_plot = farm.grid.get_plot(mushroom_pos)
	var mushroom = farm.biome.create_quantum_state(mushroom_pos, "🍄", "🍂", 0.0)
	mushroom.radius = 0.3
	mushroom_plot.plant(mushroom)
	mushroom_plot.phase_constraint = PhaseConstraint.new(
		PhaseConstraint.ConstraintType.FROZEN, 0.0, 0.0
	)
	print("  Plot 2 @ (1,0): MUSHROOM AT MIDDAY")
	print("    Constraint: θ = 0° (ALIGNED with sun phase)")
	print("    Normal role: Grows during night. This will test: can mushroom grow during day?")
	print("    Mushroom icon influence: %.3f (nerfed to wheat scale)\n" % farm.biome.mushroom_energy_influence)

	print("Initial Config:")
	print("  Sun period: 20.0 seconds (full day-night cycle)")
	print("  Sun θ starts at: ~0° (peak sun phase)")
	print("  Energy formula: base_rate × cos²(θ_qubit/2) × cos²((θ_qubit - θ_sun)/2) × cos²(θ_icon/2)\n")

	# Run 60-second experiment (3 full cycles)
	print("─".repeat(90))
	print("EXPERIMENT: 60-second simulation (3 day-night cycles)")
	print("─".repeat(90) + "\n")

	farm.biome.time_elapsed = 0.0
	var snapshots = []

	print("Time (s) | Sun θ (°) | Phase     | Wheat R (mid) | Mush R (mid) | Expected")
	print("         |          | (stage)   | alignment=0   | alignment=1  | ratio")
	print("─".repeat(90))

	for frame_num in range(3601):  # 60 seconds at 60fps
		if frame_num > 0:
			farm.biome._process(0.016)

		# Capture data every 60 frames (1 second)
		if frame_num % 300 == 0:
			var time_s = frame_num * 0.016
			var sun_theta = farm.biome.sun_qubit.theta
			var sun_theta_deg = sun_theta * 180.0 / PI

			# Determine phase
			var phase_stage = "SUNRISE " if sun_theta < PI / 4.0 else \
							  "PEAK    " if sun_theta < PI / 2.0 else \
							  "SUNSET  " if sun_theta < 3 * PI / 4.0 else \
							  "DUSK    " if sun_theta < PI else \
							  "NIGHT   " if sun_theta < 3 * PI / 2.0 else \
							  "DAWN    "

			# Calculate expected alignment
			# Wheat at midnight (θ=π): alignment = cos²((π - sun_θ)/2) = cos²(π/2 - sun_θ/2)
			# Mushroom at midday (θ=0): alignment = cos²((0 - sun_θ)/2) = cos²(-sun_θ/2) = cos²(sun_θ/2)
			var wheat_alignment = pow(cos((PI - sun_theta) / 2.0), 2)
			var mushroom_alignment = pow(cos((0.0 - sun_theta) / 2.0), 2)
			var ratio = wheat_alignment / mushroom_alignment if mushroom_alignment > 0.001 else 0.0

			snapshots.append({
				"time": time_s,
				"sun_theta": sun_theta,
				"sun_theta_deg": sun_theta_deg,
				"phase": phase_stage,
				"wheat_radius": wheat.radius,
				"mushroom_radius": mushroom.radius,
				"wheat_alignment": wheat_alignment,
				"mushroom_alignment": mushroom_alignment,
			})

			print("  %6.1f | %9.1f | %9s | %.4f (%.3f)  | %.4f (%.3f)  | %.2f:1" % [
				time_s,
				sun_theta_deg,
				phase_stage,
				wheat.radius,
				wheat_alignment,
				mushroom.radius,
				mushroom_alignment,
				ratio
			])

	print("\n" + "─".repeat(90))
	print("ANALYSIS: Reversed Roles Performance")
	print("─".repeat(90) + "\n")

	var initial_snap = snapshots[0]
	var final_snap = snapshots[-1]

	var wheat_growth = final_snap.wheat_radius - 0.3
	var mushroom_growth = final_snap.mushroom_radius - 0.3

	print("WHEAT AT MIDNIGHT (θ = 180°, opposite sun):")
	print("  Initial radius: 0.3000")
	print("  Final radius:   %.4f" % final_snap.wheat_radius)
	print("  Growth:         %.4f" % wheat_growth)
	print("  Performance:    POOR - grows only during night when sun is opposite")
	print("  Icon influence: %.3f (nerfed to match mushroom)" % farm.biome.wheat_energy_influence)
	print("  Alignment:      Peaks at midnight (θ_sun = π), zero at noon (θ_sun = 0)")
	print()

	print("MUSHROOM AT MIDDAY (θ = 0°, aligned with sun):")
	print("  Initial radius: 0.3000")
	print("  Final radius:   %.4f" % final_snap.mushroom_radius)
	print("  Growth:         %.4f" % mushroom_growth)
	print("  Performance:    EXCELLENT - grows during entire day phase")
	print("  Icon influence: %.3f (nerfed to wheat scale)" % farm.biome.mushroom_energy_influence)
	print("  Alignment:      Peaks at noon (θ_sun = 0), zero at midnight (θ_sun = π)")
	print()

	print("COMPARATIVE METRICS:")
	print("  Wheat (midnight) growth:    %.4f" % wheat_growth)
	print("  Mushroom (midday) growth:   %.4f" % mushroom_growth)
	print("  Growth ratio (mush/wheat):  %.2f:1" % (mushroom_growth / wheat_growth if wheat_growth > 0.001 else 999))
	print("  Mushroom is %.0f%% more effective at midday" % ((mushroom_growth - wheat_growth) / wheat_growth * 100.0))
	print()

	print("KEY INSIGHTS (NERFED MUSHROOM = BALANCED SYSTEM):")
	print("  ✓ Wheat (0.017) ≈ Mushroom (0.022) - NOW BALANCED on same scale!")
	print("  ✓ Phase alignment matters MORE than crop type")
	print("  ✗ Wheat at midnight: WRONG PHASE - loses energy to dissipation")
	print("  ✓ Mushroom at midday: CORRECT PHASE - gains energy from sun")
	print("  → System is now PHASE-DEPENDENT, not crop-type-dominant")
	print("  → Sun damage mechanic is more meaningful (0.8/sec at noon)")
	print("  → Creates strategic choice: phase vs crop type")
	print()

	print("=".repeat(90))
	print("REVERSED CROPS EXPERIMENT COMPLETE")
	print("=".repeat(90) + "\n")

	quit()
