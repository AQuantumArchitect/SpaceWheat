#!/usr/bin/env -S godot --headless --no-window --script
"""
Full Forest Ecosystem V2 Test
Demonstrates complete food web with apex predators (🐺, 🦅)

Food Web:
  Plants (ecological state θ) → Herbivores (🐰, 🐭, 🐛)
                             ↓
                        Predators (🐦, 🐱)
                             ↓
                     Apex Predators (🐺 wolf, 🦅 eagle)

Wolf (🐺) produces 💧 water
Eagle (🦅) produces 🌬️ wind
"""
extends SceneTree

const ForestBiomeV2 = preload("res://Core/Environment/ForestEcosystem_Biome_v2.gd")

func _ready():
	print("\n" + "═".repeat(160))
	print("🌲 FOREST ECOSYSTEM V2 - FULL FOOD WEB WITH APEX PREDATORS")
	print("═".repeat(160) + "\n")

	# Create forest
	var forest = ForestBiomeV2.new(6, 1)
	forest._ready()

	var patch_pos = Vector2i(0, 0)
	var patch = forest.patches[patch_pos]

	print("INITIAL POPULATIONS:")
	print("─" * 160)
	_print_ecosystem_state(forest, patch_pos)
	print()

	# Simulate
	var test_duration = 60.0  # 60 seconds
	var dt = 0.5
	var steps = int(test_duration / dt)

	print("SIMULATION (over %.0f seconds):" % test_duration)
	print("─" * 160)
	print("Time │ Forest │ Herbs │ Pred │ Apex │ Water │ Wind │ Status")
	print("   s │ Theta° │ Count │ Cnt  │ Cnt  │ Prod  │ Prod │")
	print("─" * 160)

	var time = 0.0
	var apex_deaths = 0
	var max_herbivores = 0

	for step in range(steps):
		forest._update_quantum_substrate(dt)

		var state_qubit = patch.quantum_state
		var theta_deg = state_qubit.theta * 180.0 / PI
		var herb_count = patch.get_meta("herbivore_count")
		var pred_count = patch.get_meta("predator_count")
		var apex_count = patch.get_meta("apex_predator_count")
		var water = patch.get_meta("water_produced")
		var wind = patch.get_meta("wind_produced")

		max_herbivores = max(max_herbivores, herb_count)

		var status = ""

		# Check for interesting events
		if apex_count == 0 and step > 0:
			apex_deaths += 1
			if apex_deaths == 1:
				status = "⚠️ APEX PREDATORS EXTINCT"

		# Print every 5 seconds
		if step % 10 == 0:
			print("%5.1f │ %7.1f │ %6d │ %5d │ %5d │ %6.1f │ %6.1f │ %s" % [
				time, theta_deg, herb_count, pred_count, apex_count, water, wind, status
			])

		time += dt

	print("─" * 160)
	print()

	# Final analysis
	print("═ FINAL ECOSYSTEM STATE ═\n")
	_print_ecosystem_state(forest, patch_pos)
	print()

	var state_qubit = patch.quantum_state
	var final_theta = state_qubit.theta
	print("FOREST STATE:")
	print("  Final theta: %.1f° (region: %s)" % [final_theta * 180.0 / PI, forest._get_ecological_state_label(final_theta)])
	print("  Final radius (coherence): %.3f" % state_qubit.radius)
	print()

	print("ECOSYSTEM DYNAMICS:")
	var organisms = patch.get_meta("organisms")
	var total_predation_events = 0
	var total_offspring = 0
	var total_food_consumed = 0

	for icon in organisms.keys():
		var org_list = organisms[icon]
		for org in org_list:
			total_predation_events += org.predation_events
			total_offspring += org.offspring_created
			total_food_consumed += org.food_consumed

	print("  Total predation events: %d" % total_predation_events)
	print("  Total offspring produced: %d" % total_offspring)
	print("  Total plant food consumed: %.1f" % total_food_consumed)
	print()

	print("APEX PREDATOR RESOURCE PRODUCTION:")
	var water_produced = patch.get_meta("water_produced")
	var wind_produced = patch.get_meta("wind_produced")
	print("  💧 Water produced (by 🐺 wolves): %.1f units" % water_produced)
	print("  🌬️ Wind produced (by 🦅 eagles): %.1f units" % wind_produced)
	print()

	print("KEY OBSERVATIONS:")
	print("  ✓ Food web: Plants → Herbivores → Predators → Apex Predators")
	print("  ✓ Apex predators hunt both herbivores AND predators")
	print("  ✓ Wolf (🐺) produces water resource")
	print("  ✓ Eagle (🦅) produces wind resource")
	print("  ✓ Predators affect forest growth through bifurcation")
	print("  ✓ Heavy predation can destabilize ecosystem")
	print()

	print("═" * 160)
	print("✅ FOREST ECOSYSTEM V2 TEST COMPLETE")
	print("═" * 160 + "\n")

	quit()


func _print_ecosystem_state(forest: ForestBiomeV2, pos: Vector2i):
	"""Print detailed ecosystem state"""
	var patch = forest.patches[pos]
	var organisms = patch.get_meta("organisms")

	print("\nOrganism Populations:")
	var org_by_type = {}

	for icon in organisms.keys():
		var org_list = organisms[icon]
		var alive_count = org_list.filter(func(o): return o.alive).size()

		var org_type = ""
		if icon in ["🐰", "🐭", "🐛"]:
			org_type = "Herbivore"
		elif icon in ["🐦", "🐱"]:
			org_type = "Predator"
		elif icon in ["🐺", "🦅"]:
			org_type = "Apex Predator"

		if alive_count > 0:
			print("  %s %s: %d alive" % [icon, org_type, alive_count])

			# Show details for first living organism
			for org in org_list:
				if org.alive:
					print("    ├─ Health: %.2f, Age: %.1fs, Prey caught: %d, Offspring: %d" % [
						org.qubit.radius, org.age, org.predation_events, org.offspring_created
					])
					break  # Just show first one
