#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Hybrid Shielding Test: 🌾🍄 with probability-weighted protection
## Demonstrates wheat component shielding mushroom from sun damage

var farm = null
var game_manager = null
var test_complete = false

func _process(delta):
	if not test_complete:
		test_complete = true
		await run_experiment()

func run_experiment():
	print("\n" + "═".repeat(100))
	print("HYBRID SHIELDING TEST: 🌾🍄 with probability-weighted sun protection")
	print("═".repeat(100) + "\n")

	const MemoryManager = preload("res://Core/GameState/MemoryManager.gd")
	game_manager = MemoryManager.new()
	root.add_child(game_manager)
	game_manager.new_game("default")

	const Farm = preload("res://Core/Farm.gd")
	farm = Farm.new()
	root.add_child(farm)
	await root.get_tree().process_frame

	# Setup: specialist wheat, specialist mushroom, shielded hybrid
	print("SETUP: Planting specialists + shielded 🌾🍄 hybrid\n")

	# Plot 1: Specialist wheat (reference day)
	var wheat_pos = Vector2i(0, 0)
	var wheat_plot = farm.grid.get_plot(wheat_pos)
	var wheat = farm.biome.create_quantum_state(wheat_pos, "🌾", "⚪", 0.0)
	wheat.radius = 0.3
	wheat_plot.plant(wheat)
	print("  Plot 1: 🌾 WHEAT specialist at day (θ=0°)")

	# Plot 2: Specialist mushroom (reference night - gets sun damage at dawn/dusk)
	var mushroom_pos = Vector2i(1, 0)
	var mushroom_plot = farm.grid.get_plot(mushroom_pos)
	var mushroom = farm.biome.create_quantum_state(mushroom_pos, "🍄", "🌙", PI)
	mushroom.radius = 0.3
	mushroom_plot.plant(mushroom)
	print("  Plot 2: 🍄 MUSHROOM specialist at night (θ=π)")

	# Plot 3: HYBRID - starts at equator, will evolve freely
	# Spring attractions: wheat to π/4, mushroom to π
	# At day (θ≈0): wheat shields, mushroom probability ≈ 0
	# At night (θ≈π): wheat probability ≈ 0, but sun_strength ≈ 0 anyway
	var hybrid_pos = Vector2i(2, 0)
	var hybrid_plot = farm.grid.get_plot(hybrid_pos)
	var hybrid = farm.biome.create_quantum_state(hybrid_pos, "🌾", "🍄", PI/2.0)
	hybrid.radius = 0.3
	hybrid_plot.plant(hybrid)
	print("  Plot 3: 🌾🍄 HYBRID shielded at equator (θ=π/2)")

	print("\n" + "─".repeat(100))
	print("EXPERIMENT: 60-second simulation showing sun damage protection")
	print("Key: Hybrid damage = 0.01 × sun_strength × sin²(θ/2)")
	print("     Specialist damage = 0.01 × sun_strength × 1.0")
	print("─".repeat(100) + "\n")

	farm.biome.time_elapsed = 0.0

	print("Time (s) | Sun θ | Wheat θ | Mushroom θ | Hybrid θ | W.Rad | M.Rad | H.Rad | Explanation")
	print("─".repeat(100))

	for frame_num in range(3601):
		if frame_num > 0:
			farm.biome._process(0.016)

		# Capture every 5 seconds (300 frames)
		if frame_num % 300 == 0:
			var time_s = frame_num * 0.016
			var sun_theta_deg = farm.biome.sun_qubit.theta * 180.0 / PI
			var wheat_theta_deg = wheat.theta * 180.0 / PI
			var mushroom_theta_deg = mushroom.theta * 180.0 / PI
			var hybrid_theta_deg = hybrid.theta * 180.0 / PI

			# Calculate what's happening
			var sun_strength = pow(cos(farm.biome.sun_qubit.theta / 2.0), 2)
			var hybrid_mushroom_prob = pow(sin(hybrid.theta / 2.0), 2)
			var specialist_damage_per_frame = 0.01 * sun_strength * 0.016
			var hybrid_damage_per_frame = 0.01 * sun_strength * hybrid_mushroom_prob * 0.016

			var explanation = ""
			if sun_theta_deg < 45.0:
				explanation = "Day: Wheat shields mushroom"
			elif sun_theta_deg > 315.0:
				explanation = "Night: Sun weak, no damage"
			else:
				explanation = "Dawn/Dusk: Balanced exposure"

			print("  %6.1f | %5.1f | %7.1f | %10.1f | %8.1f | %5.4f | %5.4f | %5.4f | %s" % [
				time_s,
				sun_theta_deg,
				wheat_theta_deg,
				mushroom_theta_deg,
				hybrid_theta_deg,
				wheat.radius,
				mushroom.radius,
				hybrid.radius,
				explanation
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

	print("🌾 Wheat specialist         | %10.2f | %10.4f | %10.4f" % [wheat_theta_final, 0.3, wheat.radius])
	print("🍄 Mushroom specialist      | %10.2f | %10.4f | %10.4f" % [mushroom_theta_final, 0.3, mushroom.radius])
	print("🌾🍄 Hybrid (shielded)      | %10.2f | %10.4f | %10.4f" % [hybrid_theta_final, 0.3, hybrid.radius])

	print("\n" + "─".repeat(100))
	print("GROWTH ANALYSIS")
	print("─".repeat(100) + "\n")

	print("Growth Rates (Δ radius):")
	print("  Wheat specialist:     %.4f" % wheat_growth)
	print("  Mushroom specialist:  %.4f" % mushroom_growth)
	print("  Hybrid (shielded):    %.4f" % hybrid_growth)
	print()

	print("Protection Mechanism (Probability-Weighted):")
	print("  At θ=0° (wheat):         mushroom exposure = sin²(0) = 0.000  → no sun damage to hybrid")
	print("  At θ=π/2 (equator):      mushroom exposure = sin²(π/4) = 0.500  → 50%% damage to hybrid")
	print("  At θ=π (mushroom):       mushroom exposure = sin²(π/2) = 1.000  → full damage, but sun weak")
	print()

	var hybrid_vs_specialist = ""
	if hybrid_growth > mushroom_growth:
		hybrid_vs_specialist = "PROTECTED - Hybrid beats specialist mushroom!"
	else:
		hybrid_vs_specialist = "Specialist mushroom still wins, but hybrid is shielded"

	print("Shielding Effectiveness:")
	print("  Hybrid vs Mushroom specialist: %s" % hybrid_vs_specialist)
	print("  Hybrid benefits from wheat shield when θ < π/2")
	print()

	print("Final Equilibrium Position:")
	print("  Hybrid θ = %.2f° (between wheat stable π/4=45° and mushroom stable π=180°)" % hybrid_theta_final)

	print("\n" + "═".repeat(100))
	print("HYBRID SHIELDING TEST COMPLETE")
	print("═".repeat(100) + "\n")

	quit()
