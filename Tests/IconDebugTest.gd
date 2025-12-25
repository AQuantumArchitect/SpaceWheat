extends Node

## ICON DEBUG TEST - Check if blending is actually happening

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

var biome: BioticFluxBiome
var wheat: DualEmojiQubit
var mushroom: DualEmojiQubit
var measurement_count = 0

func _ready() -> void:
	var sep = "════════════════════════════════════════════════════════════════════════════════════════════════════"
	print("\n" + sep)
	print("ICON DEBUG TEST")
	print("Check if stable_theta/stable_phi blending is actually being applied")
	print(sep)

	# Create biome
	biome = BioticFluxBiome.new()
	add_child(biome)
	await get_tree().process_frame

	# Create one wheat and one mushroom
	wheat = DualEmojiQubit.new()
	wheat.north_emoji = "🌾"
	wheat.south_emoji = "🏰"
	wheat.theta = PI / 3.0
	wheat.phi = 0.0
	wheat.radius = 0.5
	wheat.energy = 0.5

	mushroom = DualEmojiQubit.new()
	mushroom.north_emoji = "🍂"
	mushroom.south_emoji = "🍄"
	mushroom.theta = 2.0 * PI / 3.0
	mushroom.phi = PI
	mushroom.radius = 0.5
	mushroom.energy = 0.5

	# Register in biome
	biome.quantum_states[Vector2i(0, 0)] = wheat
	biome.plots_by_type[biome.PlotType.FARM] = [Vector2i(0, 0)]
	biome.plot_types[Vector2i(0, 0)] = biome.PlotType.FARM

	biome.quantum_states[Vector2i(1, 0)] = mushroom
	biome.plots_by_type[biome.PlotType.FARM].append(Vector2i(1, 0))
	biome.plot_types[Vector2i(1, 0)] = biome.PlotType.FARM

	print("\n🎯 ICON PREFERRED REST LOCATIONS:")
	print("   Wheat Icon:    preferred θ = %.1f° (π/4), preferred φ = %.1f° (3π/2)" % [
		biome.wheat_icon["preferred_theta"] * 180 / PI,
		biome.wheat_icon["preferred_phi"] * 180 / PI
	])
	print("   Mushroom Icon: preferred θ = %.1f° (π), preferred φ = %.1f° (0)" % [
		biome.mushroom_icon["preferred_theta"] * 180 / PI,
		biome.mushroom_icon["preferred_phi"] * 180 / PI
	])

	print("\n📊 STABLE THETA/PHI VALUES OVER TIME:")
	print("Time | Sun θ  | Sun φ  | Wheat stable_θ | Wheat stable_φ | Mushroom stable_θ | Mushroom stable_φ")
	print("─────────────────────────────────────────────────────────────────────────────────────────────────────")

	# Run for 10 seconds, sampling every 0.5 seconds
	var total_time = 0.0
	var dt = 0.016666
	var next_sample = 0.5

	while total_time < 10.0:
		total_time += dt
		biome.time_tracker.update(dt)
		biome._apply_celestial_oscillation(dt)
		biome._apply_hamiltonian_evolution(dt)
		biome._apply_spring_attraction(dt)
		biome._apply_energy_transfer(dt)

		if total_time >= next_sample:
			_print_icon_status(total_time)
			next_sample += 0.5

	print("\n════════════════════════════════════════════════════════════════════════════════════════════════════")
	print("ANALYSIS:")
	print("════════════════════════════════════════════════════════════════════════════════════════════════════")
	print("\nIf blending is working (50% rest + 50% sun/moon):")
	print("  - Wheat stable_φ should be: 50% * 270° + 50% * sun_φ")
	print("  - Should trend toward 270° but mostly follow sun")
	print("  - Mushroom stable_φ should be: 50% * 0° + 50% * moon_φ")
	print("  - Should blend but mostly follow moon")
	print("\nIf blending is NOT working:")
	print("  - Icons will ONLY follow sun/moon with no drift toward preferred rests")
	print("\n════════════════════════════════════════════════════════════════════════════════════════════════════\n")
	get_tree().quit()


func _print_icon_status(time: float) -> void:
	measurement_count += 1
	var wheat_st = biome.wheat_icon["stable_theta"]
	var wheat_sp = biome.wheat_icon["stable_phi"]
	var mushroom_st = biome.mushroom_icon["stable_theta"]
	var mushroom_sp = biome.mushroom_icon["stable_phi"]

	print("%.1fs | %5.0f° | %5.0f° | %13.1f° | %14.1f° | %17.1f° | %16.1f°" % [
		time,
		biome.sun_qubit.theta * 180 / PI,
		biome.sun_qubit.phi * 180 / PI,
		wheat_st * 180 / PI,
		wheat_sp * 180 / PI,
		mushroom_st * 180 / PI,
		mushroom_sp * 180 / PI,
	])
