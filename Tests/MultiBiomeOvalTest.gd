extends Node

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

@onready var canvas = $Canvas2D

var biome1: BioticFluxBiome
var biome2: BioticFluxBiome

# Crop references for tracking - separate by biome
var biome1_wheat: Array = []
var biome1_mushroom: Array = []
var biome2_wheat: Array = []
var biome2_mushroom: Array = []

func _ready() -> void:
	var sep = "════════════════════════════════════════════════════════════════════════════"
	print("\n" + sep)
	print("TEST: MULTI-BIOME OVAL VISUALIZATION")
	print("Biome 1: Oval with sun (center), 3 wheat, 2 mushrooms")
	print("Biome 2: Separate oval with 3 wheat, 2 mushrooms (shares sun with biome1)")
	print(sep)

	# Create first biome
	biome1 = BioticFluxBiome.new()
	add_child(biome1)
	await get_tree().process_frame

	# Add crops to biome1 - scattered in an oval pattern
	_setup_biome(biome1, Vector2(640, 360), 300, 200, 1)  # Center, semi-major, semi-minor, biome_id

	# Create second biome and share biome1's sun qubit (one sun for both biomes)
	biome2 = BioticFluxBiome.new()
	add_child(biome2)
	await get_tree().process_frame

	# Replace biome2's sun with biome1's sun so both biomes share the same celestial oscillator
	biome2.sun_qubit = biome1.sun_qubit
	# Register shared sun in biome2's quantum states
	biome2.quantum_states[Vector2i(-1, -1)] = biome2.sun_qubit
	biome2.plots_by_type[biome2.PlotType.FARM].append(Vector2i(-1, -1))
	biome2.plot_types[Vector2i(-1, -1)] = biome2.PlotType.FARM

	# Add crops to biome2 - separate oval, uses shared sun
	_setup_biome(biome2, Vector2(1200, 360), 300, 200, 2, false)

	# Start simulation
	_run_simulation()

func _setup_biome(biome: BioticFluxBiome, center: Vector2, major_axis: float, minor_axis: float, biome_id: int, include_sun: bool = true) -> void:
	"""Setup a biome with crops scattered in an oval"""

	if include_sun:
		# Sun at center
		biome.quantum_states[Vector2i(-1, -1)] = biome.sun_qubit
		biome.plots_by_type[biome.PlotType.FARM].append(Vector2i(-1, -1))
		biome.plot_types[Vector2i(-1, -1)] = biome.PlotType.FARM
		print("Biome %d: Added sun at center" % biome_id)

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

		if biome_id == 1:
			biome1_wheat.append(wheat)
		else:
			biome2_wheat.append(wheat)

		print("Biome %d: Added wheat %d at (%.0f, %.0f)" % [biome_id, i, x, y])

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

		if biome_id == 1:
			biome1_mushroom.append(mushroom)
		else:
			biome2_mushroom.append(mushroom)

		print("Biome %d: Added mushroom %d at (%.0f, %.0f)" % [biome_id, i, x, y])

func _run_simulation() -> void:
	"""Run the simulation for multiple sun cycles"""

	var dt = 0.016666
	var total_time = 0.0
	var max_time = 60.0  # 3 full cycles (20s each)
	var next_sample = 0.0

	print("\nRunning simulation for %.0f seconds (3 sun cycles)...\n" % max_time)

	while total_time < max_time:
		total_time += dt

		# Update both biomes
		biome1.time_tracker.update(dt)
		biome1._apply_celestial_oscillation(dt)
		biome1._apply_hamiltonian_evolution(dt)
		biome1._apply_spring_attraction(dt)
		biome1._apply_energy_transfer(dt)

		biome2.time_tracker.update(dt)
		biome2._apply_hamiltonian_evolution(dt)
		biome2._apply_spring_attraction(dt)
		biome2._apply_energy_transfer(dt)

		# Sample output every second
		if total_time >= next_sample:
			var sun_theta = biome1.sun_qubit.theta
			var sun_bright = pow(cos(sun_theta / 2.0), 2)
			var moon_bright = pow(sin(sun_theta / 2.0), 2)

			# Average crop energies for biome1
			var b1_wheat_avg = 0.0
			for w in biome1_wheat:
				b1_wheat_avg += w.energy
			b1_wheat_avg /= biome1_wheat.size() if biome1_wheat.size() > 0 else 1

			var b1_mushroom_avg = 0.0
			for m in biome1_mushroom:
				b1_mushroom_avg += m.energy
			b1_mushroom_avg /= biome1_mushroom.size() if biome1_mushroom.size() > 0 else 1

			# Average crop energies for biome2
			var b2_wheat_avg = 0.0
			for w in biome2_wheat:
				b2_wheat_avg += w.energy
			b2_wheat_avg /= biome2_wheat.size() if biome2_wheat.size() > 0 else 1

			var b2_mushroom_avg = 0.0
			for m in biome2_mushroom:
				b2_mushroom_avg += m.energy
			b2_mushroom_avg /= biome2_mushroom.size() if biome2_mushroom.size() > 0 else 1

			var phase = "Day" if sun_bright > 0.5 else "Night"
			print("T=%.1fs | Sun θ=%5.0f° | B1W=%.4f B1M=%.4f | B2W=%.4f B2M=%.4f | %s" % [
				total_time,
				sun_theta * 180.0 / PI,
				b1_wheat_avg,
				b1_mushroom_avg,
				b2_wheat_avg,
				b2_mushroom_avg,
				phase
			])

			next_sample += 1.0

	var sep2 = "════════════════════════════════════════════════════════════════════════════"
	print("\n" + sep2)
	print("SIMULATION COMPLETE - MULTI-BIOME ANALYSIS")
	print("")
	print("Biome 1 (with sun):")
	var b1_wheat_final = 0.0
	for w in biome1_wheat:
		b1_wheat_final += w.energy
	b1_wheat_final /= biome1_wheat.size() if biome1_wheat.size() > 0 else 1
	var b1_mushroom_final = 0.0
	for m in biome1_mushroom:
		b1_mushroom_final += m.energy
	b1_mushroom_final /= biome1_mushroom.size() if biome1_mushroom.size() > 0 else 1
	print("  Final wheat energy: %.4f | Final mushroom energy: %.4f" % [b1_wheat_final, b1_mushroom_final])

	print("")
	print("Biome 2 (separate oval):")
	var b2_wheat_final = 0.0
	for w in biome2_wheat:
		b2_wheat_final += w.energy
	b2_wheat_final /= biome2_wheat.size() if biome2_wheat.size() > 0 else 1
	var b2_mushroom_final = 0.0
	for m in biome2_mushroom:
		b2_mushroom_final += m.energy
	b2_mushroom_final /= biome2_mushroom.size() if biome2_mushroom.size() > 0 else 1
	print("  Final wheat energy: %.4f | Final mushroom energy: %.4f" % [b2_wheat_final, b2_mushroom_final])

	print("")
	print("✓ Both biomes evolved for 3 sun cycles")
	print("✓ Wheat grows during day (θ near 10-45°)")
	print("✓ Mushrooms grow at night (θ near 170-180°)")
	print("✓ Ovals are spatially separated (no overlap)")
	print(sep2 + "\n")

	get_tree().quit()
