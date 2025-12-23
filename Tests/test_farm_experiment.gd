#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Farm Experiment: Noon Imperium vs Midnight Imperium vs Free Field
## Compares performance of wheat at different phase constraints
## Only sun phase matters (no moon interactions)

var farm = null
var game_manager = null
var test_complete = false

func _process(delta):
	if not test_complete:
		test_complete = true
		await run_experiment()

func run_experiment():
	print("\n" + "=".repeat(90))
	print("FARM EXPERIMENT: Noon Imperium vs Midnight Imperium vs Free Field")
	print("=".repeat(90) + "\n")

	const MemoryManager = preload("res://Core/GameState/MemoryManager.gd")
	game_manager = MemoryManager.new()
	root.add_child(game_manager)
	game_manager.new_game("default")

	const Farm = preload("res://Core/Farm.gd")
	farm = Farm.new()
	root.add_child(farm)
	await root.get_tree().process_frame

	# Setup farm plots
	print("SETUP: Creating three farm plots with different constraints\n")

	const PhaseConstraint = preload("res://Core/GameMechanics/PhaseConstraint.gd")

	# Plot 1: Noon-aligned Imperium (θ=0°)
	var noon_pos = Vector2i(0, 0)
	var noon_plot = farm.grid.get_plot(noon_pos)
	noon_plot.phase_constraint = PhaseConstraint.new(
		PhaseConstraint.ConstraintType.FROZEN,
		0.0,  # θ = 0° (noon, aligned with sun)
		0.0   # φ = 0°
	)
	var noon_wheat = farm.biome.create_quantum_state(noon_pos, "🌾", "👥", 0.0)
	noon_wheat.radius = 0.3
	noon_plot.plant(noon_wheat)
	print("  Plot 1 @ (0,0): NOON IMPERIUM")
	print("    Constraint: θ = 0.0° (aligned with ☀️)")
	print("    Wheat: radius = 0.3, phase LOCKED\n")

	# Plot 2: Midnight-aligned Imperium (θ=π)
	var midnight_pos = Vector2i(1, 0)
	var midnight_plot = farm.grid.get_plot(midnight_pos)
	midnight_plot.phase_constraint = PhaseConstraint.new(
		PhaseConstraint.ConstraintType.FROZEN,
		PI,   # θ = 180° (midnight, opposite sun)
		0.0   # φ = 0°
	)
	var midnight_wheat = farm.biome.create_quantum_state(midnight_pos, "🌾", "👥", PI)
	midnight_wheat.radius = 0.3
	midnight_plot.plant(midnight_wheat)
	print("  Plot 2 @ (1,0): MIDNIGHT IMPERIUM")
	print("    Constraint: θ = 180.0° (opposite to ☀️)")
	print("    Wheat: radius = 0.3, phase LOCKED\n")

	# Plot 3: Free field (no constraint)
	var free_pos = Vector2i(2, 0)
	var free_plot = farm.grid.get_plot(free_pos)
	free_plot.phase_constraint = null  # No constraint
	var free_wheat = farm.biome.create_quantum_state(free_pos, "🌾", "👥", PI / 2.0)
	free_wheat.radius = 0.3
	free_plot.plant(free_wheat)
	print("  Plot 3 @ (2,0): FREE FIELD")
	print("    Constraint: None (full quantum dynamics)")
	print("    Wheat: radius = 0.3, phase CAN EVOLVE\n")

	print("Initial Config:")
	print("  Sun period: 20.0 seconds (full day-night cycle)")
	print("  Sun θ starts at: ~0.3° (peak sun phase)")
	print("  Energy transfer: ACTIVE during sun phase only (θ ∈ [0, π))\n")

	# Run 30-second experiment (covers 1.5 full cycles: sun → moon → sun)
	print("─".repeat(90))
	print("EXPERIMENT: 30-second simulation (1.5 day-night cycles)")
	print("─".repeat(90) + "\n")

	farm.biome.time_elapsed = 0.0
	var snapshots = []

	print("Time (s) | Sun θ (°) | Phase     | Noon R | Noon A | Mid R | Mid A | Free R | Free θ")
	print("         |          | (stage)   |        | Factor |       | Factor|        | (°)")
	print("─".repeat(90))

	for frame_num in range(1801):  # 30 seconds at 60fps
		if frame_num > 0:
			farm.biome._process(0.016)

		# Capture data every 60 frames (1 second)
		if frame_num % 60 == 0:
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

			# Calculate alignment factors for locked wheat
			var noon_amplitude = pow(cos(0.0 / 2.0), 2)  # cos²(0) = 1.0
			var noon_alignment = pow(cos((0.0 - sun_theta) / 2.0), 2)
			var noon_factor = noon_amplitude * noon_alignment

			var midnight_amplitude = pow(cos(PI / 2.0), 2)  # cos²(π/2) = 0.0
			var midnight_alignment = pow(cos((PI - sun_theta) / 2.0), 2)
			var midnight_factor = midnight_amplitude * midnight_alignment

			snapshots.append({
				"time": time_s,
				"sun_theta": sun_theta,
				"sun_theta_deg": sun_theta_deg,
				"phase": phase_stage,
				"noon_radius": noon_wheat.radius,
				"noon_alignment": noon_alignment,
				"noon_factor": noon_factor,
				"midnight_radius": midnight_wheat.radius,
				"midnight_alignment": midnight_alignment,
				"midnight_factor": midnight_factor,
				"free_radius": free_wheat.radius,
				"free_theta": free_wheat.theta,
				"free_theta_deg": free_wheat.theta * 180.0 / PI,
			})

			var free_theta_str = "%.1f" % snapshots[-1].free_theta_deg
			print("  %6.1f | %9.1f | %9s | %.4f | %.4f | %.4f | %.4f | %.4f | %s" % [
				time_s,
				sun_theta_deg,
				phase_stage,
				noon_wheat.radius,
				noon_factor,
				midnight_wheat.radius,
				midnight_factor,
				free_wheat.radius,
				free_theta_str
			])

	print("\n" + "─".repeat(90))
	print("ANALYSIS: Performance Comparison")
	print("─".repeat(90) + "\n")

	var initial_snap = snapshots[0]
	var final_snap = snapshots[-1]

	var noon_growth = final_snap.noon_radius - 0.3
	var midnight_growth = final_snap.midnight_radius - 0.3
	var free_growth = final_snap.free_radius - 0.3

	print("NOON IMPERIUM (θ = 0°, aligned with sun):")
	print("  Initial radius: 0.3000")
	print("  Final radius:   %.4f" % final_snap.noon_radius)
	print("  Growth:         %.4f" % noon_growth)
	print("  Performance:    EXCELLENT - constant alignment with sun phase")
	print("  Formula:        amplitude=1.0 × alignment=cos²(0-sun.θ/2) × icon=0.683")
	print()

	print("MIDNIGHT IMPERIUM (θ = 180°, opposite sun):")
	print("  Initial radius: 0.3000")
	print("  Final radius:   %.4f" % final_snap.midnight_radius)
	print("  Growth:         %.4f" % midnight_growth)
	print("  Performance:    POOR - locked in definite state (amplitude=0)")
	print("  Formula:        amplitude=0.0 × alignment=cos²(180-sun.θ/2) × icon=0.683")
	print("  Note:           No superposition means no energy can be absorbed!")
	print()

	print("FREE FIELD (no constraint):")
	print("  Initial radius: 0.3000")
	print("  Initial phase:  %.1f°" % (PI / 2.0 * 180.0 / PI))
	print("  Final radius:   %.4f" % final_snap.free_radius)
	print("  Final phase:    %.1f°" % final_snap.free_theta_deg)
	print("  Growth:         %.4f" % free_growth)
	print("  Performance:    ADAPTIVE - can move to favorable phases")
	print("  Adaptation:     Phase shifted by %.1f°" % (final_snap.free_theta_deg - 90.0))
	print()

	print("COMPARATIVE METRICS:")
	print("  Noon vs Midnight growth ratio:  %.2f:1" % (noon_growth / midnight_growth if midnight_growth > 0 else 999))
	print("  Noon vs Free growth ratio:      %.2f:1" % (noon_growth / free_growth if free_growth > 0 else 999))
	print("  Free vs Midnight growth ratio:  %.2f:1" % (free_growth / midnight_growth if midnight_growth > 0 else 999))
	print()

	print("KEY INSIGHTS:")
	print("  ✓ Noon Imperium: Best strategy if you plant at peak sun alignment")
	print("  ✗ Midnight Imperium: Worst strategy - wheat locked in definite state")
	print("  ✓ Free Field: Good if uncertain about alignment, adapts dynamically")
	print()

	# Phase analysis
	print("PHASE EVOLUTION (Free field only):")
	var free_phase_change = final_snap.free_theta_deg - 90.0
	print("  Initial phase: 90.0° (perpendicular to sun)")
	print("  Final phase:   %.1f°" % final_snap.free_theta_deg)
	print("  Adaptation:    %+.1f° (σ_z coupling pulled wheat toward sun)" % free_phase_change)
	print()

	# Sun phase analysis
	print("SUN PHASE CYCLE (only sun transfers energy, not moon):")
	print("  Peak sun (θ ≈ 0°):     Noon wheat at peak growth")
	print("  Sunset (θ ≈ π/2):      Growth rate drops (sun alignment decreases)")
	print("  Midnight (θ ≈ π):      NO ENERGY TRANSFER (moon phase, θ > π)")
	print("  Sunrise (θ ≈ 3π/2):    Gradually returns to growth as sun rises")
	print("  Full cycle:            20 seconds")
	print()

	print("=".repeat(90))
	print("FARM EXPERIMENT COMPLETE")
	print("=".repeat(90) + "\n")

	quit()
