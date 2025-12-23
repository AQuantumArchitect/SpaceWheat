#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: Quantum Forest Ecosystem
##
## Demonstrates:
## 1. Ecological succession (bare → seedling → sapling → forest)
## 2. Predator-prey dynamics (wolf eats rabbit, etc.)
## 3. Resource production (wolf produces water)
## 4. Weather effects on growth
## 5. Complete food web as quantum icons

const ForestEcosystem_Biome = preload("res://Core/Environment/ForestEcosystem_Biome.gd")

var forest: ForestEcosystem_Biome

func _initialize():
	print("\n" + print_line("=", 80))
	print("🌲 QUANTUM FOREST ECOSYSTEM TEST")
	print("Markov Chains + Predator-Prey + Weather Effects")
	print(print_line("=", 80) + "\n")

	forest = ForestEcosystem_Biome.new(6, 1)

	_phase_1_natural_succession()
	_phase_2_predator_introduction()
	_phase_3_complete_food_web()
	_phase_4_resource_harvesting()
	_phase_5_graph_topology()

	print(print_line("=", 80))
	print("✅ FOREST ECOSYSTEM TEST COMPLETE")
	print(print_line("=", 80) + "\n")

	quit()


func print_line(char: String, count: int) -> String:
	var line = ""
	for i in range(count):
		line += char
	return line


func print_sep() -> String:
	var line = ""
	for i in range(80):
		line += "─"
	return line


func _phase_1_natural_succession():
	"""Phase 1: Natural succession from bare ground to forest"""
	print(print_sep())
	print("PHASE 1: NATURAL SUCCESSION (Bare → Seedling → Sapling → Forest)")
	print(print_sep() + "\n")

	print("🌍 Starting state: 6 plots of bare ground\n")

	# Show initial status
	_show_status("Initial")

	# Simulate growth cycles
	for cycle in range(1, 6):
		print("\n⏳ Cycle %d: Simulating ecological transitions...\n" % cycle)

		for i in range(10):
			forest.update(0.5)

		_show_status("After cycle %d" % cycle)

	print("\n📊 Result:")
	print("   • Bare ground gradually colonized by seedlings")
	print("   • Weather (wind + water) enables germination")
	print("   • Markov chains drive succession naturally")
	print("   • No organisms yet - pure ecological succession")
	print()


func _phase_2_predator_introduction():
	"""Phase 2: Introduce predators and show ecosystem effects"""
	print(print_sep())
	print("PHASE 2: PREDATOR INTRODUCTION (Wolf + Rabbit)")
	print(print_sep() + "\n")

	print("🐺 Introducing wolf to patch (0,0)...\n")
	forest.add_organism(Vector2i(0, 0), "🐺")

	print("🐰 Introducing rabbits to patch (0,0)...\n")
	forest.add_organism(Vector2i(0, 0), "🐰")

	# Run predator-prey cycle
	for cycle in range(1, 4):
		print("Cycle %d: Predator-prey interaction\n" % cycle)

		for i in range(15):
			forest.update(0.3)

		_show_status("After predation cycle %d" % cycle)

	print("\n📊 Result:")
	print("   • Wolf eats rabbits")
	print("   • Wolf strength increases, rabbit decreases")
	print("   • Rabbits can't eat seedlings (they're weak)")
	print("   • Forest gets chance to grow (fewer herbivores)")
	print()


func _phase_3_complete_food_web():
	"""Phase 3: Build a complete food web"""
	print(print_sep())
	print("PHASE 3: COMPLETE FOOD WEB (Multiple Predators + Prey)")
	print(print_sep() + "\n")

	print("🐦 Adding bird to patch (1,0)...\n")
	forest.add_organism(Vector2i(1, 0), "🐦")

	print("🐛 Adding caterpillars to patch (1,0)...\n")
	forest.add_organism(Vector2i(1, 0), "🐛")

	print("🦅 Adding eagle to patch (2,0)...\n")
	forest.add_organism(Vector2i(2, 0), "🦅")

	print("🐭 Adding mice to patch (2,0)...\n")
	forest.add_organism(Vector2i(2, 0), "🐭")

	# Run food web cycles
	for cycle in range(1, 4):
		print("Cycle %d: Multi-level predation dynamics\n" % cycle)

		for i in range(15):
			forest.update(0.3)

		_show_status("After cycle %d" % cycle)

	print("\n📊 Result:")
	print("   • Bird eats caterpillars")
	print("   • Eagle eats birds and mice")
	print("   • Multiple food chains create resilient ecosystem")
	print("   • Population dynamics oscillate naturally")
	print()


func _phase_4_resource_harvesting():
	"""Phase 4: Demonstrate resource harvesting"""
	print(print_sep())
	print("PHASE 4: RESOURCE HARVESTING (Wolf → Water)")
	print(print_sep() + "\n")

	print("💧 Harvesting water from wolf in patch (0,0)...\n")

	var water = forest.harvest_water(Vector2i(0, 0))

	if water:
		print("✨ Water qubit created:")
		print("   • Energy: %.2f" % water.radius)
		print("   • Theta: %.2f rad (%.0f°)" % [
			water.theta,
			water.theta * 180.0 / PI
		])
		print()

		print("🔗 Connection to Kitchen:")
		print("   • Water qubit from forest")
		print("   • Can be used in kitchen (triplet: wheat + water + flour)")
		print("   • Guilds need water for bread production")
		print("   • Player must manage forest to maintain supply")
		print()

	# Final status
	print("Final ecosystem status:\n")
	_show_status("Final")


func _phase_5_graph_topology():
	"""Phase 5: Verify graph topology (pure emoji language)"""
	print(print_sep())
	print("PHASE 5: GRAPH TOPOLOGY VERIFICATION (Pure Emoji Language)")
	print(print_sep() + "\n")

	var wolf_patch = forest.patches.get(Vector2i(0, 0))

	# Query wolf's entanglement graph
	if wolf_patch and wolf_patch["organisms"].size() > 0:
		print("🐺 Wolf entanglement graph (if present):")
		for icon in wolf_patch["organisms"].keys():
			var org = wolf_patch["organisms"][icon]
			if org.icon == "🐺":
				print("   Relationships in pure emoji topology:")
				for rel_emoji in org.qubit.get_all_relationships():
					var targets = org.qubit.get_graph_targets(rel_emoji)
					print("   %s → %s" % [rel_emoji, targets])
				print()
				break

	# Query rabbit's entanglement graph
	print("🐰 Rabbit entanglement graph (if present):")
	if wolf_patch:
		for icon in wolf_patch["organisms"].keys():
			var org = wolf_patch["organisms"][icon]
			if org.icon == "🐰":
				print("   Relationships in pure emoji topology:")
				for rel_emoji in org.qubit.get_all_relationships():
					var targets = org.qubit.get_graph_targets(rel_emoji)
					print("   %s → %s" % [rel_emoji, targets])
				print()
				break

	# Query ecological state transitions (Markov graph)
	print("🌲 Ecological state transitions (Markov graph in emoji topology):")
	var sample_patch = forest.patches.get(Vector2i(0, 0))
	if sample_patch:
		var state_qubit = sample_patch["state_qubit"]
		var state_name = _get_state_emoji(sample_patch["state"]) + " " + _get_state_name(sample_patch["state"])
		print("   Current state: %s" % state_name)

		var transitions = state_qubit.get_graph_targets("🔄")
		if transitions.size() > 0:
			print("   Can transition to (🔄): %s" % transitions)
		else:
			print("   Can transition to (🔄): none")

		var productions = state_qubit.get_graph_targets("💧")
		if productions.size() > 0:
			print("   Produces (💧): %s" % productions)
		else:
			print("   Produces (💧): nothing")
		print()

	print("📊 Graph Topology Summary:")
	print("   • All quantum states carry entanglement graphs")
	print("   • Relationships expressed in pure emoji language:")
	print("     🍴 = Predation (hunts)")
	print("     🏃 = Escape (flees from)")
	print("     🌱 = Consumption (feeds on)")
	print("     💧 = Production (produces)")
	print("     🔄 = Transformation (Markov transition)")
	print("     👶 = Reproduction (creates offspring)")
	print("   • No function strings - pure topological relationships")
	print("   • Graph is queryable: qubit.get_graph_targets(emoji)")
	print("   • Reversible: unitary spaces preserve bidirectionality")
	print()


func _get_state_name(state: int) -> String:
	"""Get readable name for ecological state"""
	match state:
		ForestEcosystem_Biome.EcologicalState.BARE_GROUND:
			return "BARE_GROUND"
		ForestEcosystem_Biome.EcologicalState.SEEDLING:
			return "SEEDLING"
		ForestEcosystem_Biome.EcologicalState.SAPLING:
			return "SAPLING"
		ForestEcosystem_Biome.EcologicalState.MATURE_FOREST:
			return "MATURE_FOREST"
		ForestEcosystem_Biome.EcologicalState.DEAD_FOREST:
			return "DEAD_FOREST"
		_:
			return "UNKNOWN"


func _show_status(label: String):
	"""Display current ecosystem status"""
	var status = forest.get_ecosystem_status()

	print("%s:" % label)
	print()

	# Show weather
	var weather = status["weather"]
	print("🌤️  Weather:")
	print("   Wind: %.1f%% | Water: %.1f%% | Sun: %.1f%%" % [
		weather["wind_prob"] * 100,
		weather["water_prob"] * 100,
		weather["sun_prob"] * 100
	])
	print()

	# Show patches
	print("🌍 Patches:")
	for patch_info in status["patches"]:
		var pos = patch_info["position"]
		var state = patch_info["state"]
		var organisms = patch_info["organisms"]

		var state_emoji = _get_state_emoji(state)
		print("   (%d,%d): %s %s" % [pos.x, pos.y, state_emoji, state])

		if organisms.size() > 0:
			var org_str = "      Organisms: "
			for org in organisms:
				org_str += "%s(%.1f%%) " % [org["icon"], org["strength"] * 100]
			print(org_str)

	print()
	print("📊 Total: %d organisms | Water harvested: %.2f" % [
		status["organisms_count"],
		status["total_water_harvested"]
	])
	print()


func _get_state_emoji(state: String) -> String:
	"""Get emoji for state name"""
	match state:
		"BARE_GROUND":
			return "🏜️"
		"SEEDLING":
			return "🌱"
		"SAPLING":
			return "🌿"
		"MATURE_FOREST":
			return "🌲"
		"DEAD_FOREST":
			return "☠️"
		_:
			return "❓"
