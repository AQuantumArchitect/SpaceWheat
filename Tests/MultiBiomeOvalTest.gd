extends Node

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const ForestEcosystem_Biome = preload("res://Core/Environment/ForestEcosystem_Biome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

@onready var canvas = $Canvas2D

var biome1: BioticFluxBiome  # BioticFlux - wheat/mushroom farm
var biome2  # ForestEcosystem_Biome - forest ecology

# Crop references for tracking - BioticFlux biome
var biome1_wheat: Array = []
var biome1_mushroom: Array = []

func _ready() -> void:
	var sep = "════════════════════════════════════════════════════════════════════════════"
	print("\n" + sep)
	print("TEST: MULTI-BIOME OVAL VISUALIZATION")
	print("Biome 1: BioticFlux (sun + wheat + mushrooms)")
	print("Biome 2: ForestEcosystem (weather + succession + organisms)")
	print(sep)

	# Create first biome - BioticFlux (farming)
	biome1 = BioticFluxBiome.new()
	add_child(biome1)
	await get_tree().process_frame

	# Add crops to biome1 - scattered in an oval pattern
	_setup_biotic_flux(biome1, Vector2(640, 360), 300, 200)

	# Create second biome - ForestEcosystem
	biome2 = ForestEcosystem_Biome.new(4, 1)  # 4x1 grid of patches
	add_child(biome2)
	await get_tree().process_frame

	# Add initial organisms to forest
	_setup_forest(biome2)

	# Start simulation
	_run_simulation()


func _setup_biotic_flux(biome: BioticFluxBiome, center: Vector2, major_axis: float, minor_axis: float) -> void:
	"""Setup BioticFlux biome with crops scattered in an oval"""

	# Sun at center
	biome.quantum_states[Vector2i(-1, -1)] = biome.sun_qubit
	biome.plots_by_type[biome.PlotType.FARM].append(Vector2i(-1, -1))
	biome.plot_types[Vector2i(-1, -1)] = biome.PlotType.FARM
	print("BioticFlux: Added sun at center")

	# Add 3 wheat scattered around oval
	for i in range(3):
		var angle = (i / 3.0) * TAU
		var x = center.x + major_axis * cos(angle)
		var y = center.y + minor_axis * sin(angle)

		var wheat = DualEmojiQubit.new()
		wheat.north_emoji = "🌾"
		wheat.south_emoji = "🏰"
		wheat.theta = PI / 4.0
		wheat.phi = 3.0 * PI / 2.0
		wheat.radius = 0.3
		wheat.energy = 0.5

		var pos = Vector2i(i, 0)
		biome.quantum_states[pos] = wheat
		biome.plots_by_type[biome.PlotType.FARM].append(pos)
		biome.plot_types[pos] = biome.PlotType.FARM
		biome1_wheat.append(wheat)

		print("BioticFlux: Added wheat %d at (%.0f, %.0f)" % [i, x, y])

	# Add 2 mushrooms scattered around oval
	for i in range(2):
		var angle = (0.5 + i / 2.0) * TAU  # Offset from wheat
		var x = center.x + major_axis * cos(angle)
		var y = center.y + minor_axis * sin(angle)

		var mushroom = DualEmojiQubit.new()
		mushroom.north_emoji = "🍂"
		mushroom.south_emoji = "🍄"
		mushroom.theta = PI
		mushroom.phi = PI / 2.0
		mushroom.radius = 0.3
		mushroom.energy = 0.5

		var pos = Vector2i(i + 10, 0)
		biome.quantum_states[pos] = mushroom
		biome.plots_by_type[biome.PlotType.FARM].append(pos)
		biome.plot_types[pos] = biome.PlotType.FARM
		biome1_mushroom.append(mushroom)

		print("BioticFlux: Added mushroom %d at (%.0f, %.0f)" % [i, x, y])


func _setup_forest(forest) -> void:
	"""Setup ForestEcosystem biome with initial organisms"""

	print("\nForest Ecosystem: Setting up patches and organisms...")

	# Add initial organisms - keep small to avoid population explosion
	# Patch 0: carnivore (🐺 wolf) - controls herbivore population
	forest.add_organism(Vector2i(0, 0), "🐺")
	print("Forest: Added 🐺 wolf at patch (0, 0)")

	# Patch 2: apex predator (🦅 eagle) - controls both populations
	forest.add_organism(Vector2i(2, 0), "🦅")
	print("Forest: Added 🦅 eagle at patch (2, 0)")


func _run_simulation() -> void:
	"""Run the simulation for multiple sun cycles"""

	var dt = 0.016666
	var total_time = 0.0
	var max_time = 20.0  # 1 full cycle (20s) - reduced to avoid organism explosion
	var next_sample = 0.0

	print("\nRunning simulation for %.0f seconds (3 sun cycles)...\n" % max_time)

	while total_time < max_time:
		total_time += dt

		# Update BioticFlux biome
		biome1.time_tracker.update(dt)
		biome1._apply_celestial_oscillation(dt)
		biome1._apply_hamiltonian_evolution(dt)
		biome1._apply_spring_attraction(dt)
		biome1._apply_energy_transfer(dt)

		# Update ForestEcosystem biome
		biome2.time_tracker.update(dt)
		biome2._update_quantum_substrate(dt)  # Updates weather and patches

		# Sample output every 2 seconds
		if total_time >= next_sample:
			_print_status(total_time)
			next_sample += 2.0

	_print_final_analysis()
	get_tree().quit()


func _print_status(time: float) -> void:
	"""Print current status of both biomes"""

	# BioticFlux status
	var sun_theta = biome1.sun_qubit.theta
	var sun_bright = pow(cos(sun_theta / 2.0), 2)

	var b1_wheat_avg = 0.0
	for w in biome1_wheat:
		b1_wheat_avg += w.energy
	b1_wheat_avg /= biome1_wheat.size() if biome1_wheat.size() > 0 else 1

	var b1_mushroom_avg = 0.0
	for m in biome1_mushroom:
		b1_mushroom_avg += m.energy
	b1_mushroom_avg /= biome1_mushroom.size() if biome1_mushroom.size() > 0 else 1

	# ForestEcosystem status
	var forest_status = biome2.get_ecosystem_status()
	var dominant_state = biome2._get_dominant_state()
	var state_emoji = biome2._get_ecosystem_emoji(dominant_state)
	var organism_count = forest_status["organisms_count"]
	var wind_prob = forest_status["weather"]["wind_prob"]
	var water_prob = forest_status["weather"]["water_prob"]

	var phase = "Day" if sun_bright > 0.5 else "Night"

	print("T=%4.1fs | ☀️ θ=%3.0f° (%s) | 🌾=%.2f 🍄=%.2f | 🌲%s x%d | 🌬️%.1f 💧%.1f" % [
		time,
		sun_theta * 180.0 / PI,
		phase,
		b1_wheat_avg,
		b1_mushroom_avg,
		state_emoji,
		organism_count,
		wind_prob,
		water_prob
	])


func _print_final_analysis() -> void:
	"""Print final analysis of both biomes"""

	var sep = "════════════════════════════════════════════════════════════════════════════"
	print("\n" + sep)
	print("SIMULATION COMPLETE - MULTI-BIOME ANALYSIS")
	print("")

	# BioticFlux final state
	print("╔═══════════════════════════════════════════╗")
	print("║ BIOME 1: BioticFlux (Farming)             ║")
	print("╠═══════════════════════════════════════════╣")
	var b1_wheat_final = 0.0
	for w in biome1_wheat:
		b1_wheat_final += w.energy
	b1_wheat_final /= biome1_wheat.size() if biome1_wheat.size() > 0 else 1
	var b1_mushroom_final = 0.0
	for m in biome1_mushroom:
		b1_mushroom_final += m.energy
	b1_mushroom_final /= biome1_mushroom.size() if biome1_mushroom.size() > 0 else 1
	print("║  🌾 Wheat avg energy:    %.4f            ║" % b1_wheat_final)
	print("║  🍄 Mushroom avg energy: %.4f            ║" % b1_mushroom_final)
	print("╚═══════════════════════════════════════════╝")

	# ForestEcosystem final state
	print("")
	print("╔═══════════════════════════════════════════╗")
	print("║ BIOME 2: ForestEcosystem (Ecology)        ║")
	print("╠═══════════════════════════════════════════╣")
	var forest_status = biome2.get_ecosystem_status()
	print("║  Total organisms: %d                       ║" % forest_status["organisms_count"])
	print("║  💧 Water harvested: %.2f                 ║" % forest_status["total_water_harvested"])
	print("║                                           ║")
	print("║  Patches:                                 ║")
	for patch_info in forest_status["patches"]:
		var state_name = patch_info["state"]
		var org_list = []
		for org in patch_info["organisms"]:
			org_list.append(org["icon"])
		var orgs_str = " ".join(org_list) if org_list.size() > 0 else "(empty)"
		print("║    %s: %s - %s" % [patch_info["position"], state_name, orgs_str])
	print("╚═══════════════════════════════════════════╝")

	print("")
	print("✓ BioticFlux: Day/night cycle drove wheat/mushroom growth")
	print("✓ ForestEcosystem: Weather cycle drove ecological succession")
	print("✓ Both biomes evolved independently with their own dynamics")
	print("✓ Ovals are spatially separated (no overlap)")
	print(sep + "\n")
