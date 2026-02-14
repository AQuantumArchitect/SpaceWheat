extends SceneTree

func _init():
	print("\n=== GAMEPLAY TEST: Plant, Evolve, Measure ===\n")

	# Load full game stack
	var FarmGrid = load("res://Core/GameMechanics/FarmGrid.gd")
	var BioticFlux = load("res://Core/Environment/BioticFluxBiome.gd")

	# Create biome
	var biome = BioticFlux.new()
	biome.name = "BioticFlux"
	biome._ready()

	# Create farm grid
	var farm = FarmGrid.new()
	farm.name = "FarmGrid"
	farm.inject_biome(biome)

	print("✓ Farm created with BioticFlux biome")
	print("  Biome quantum_computer: ", biome.quantum_computer != null)
	print("  Grid size: 6x2 = 12 plots")

	# Plant a wheat plot
	var plot_pos = Vector2i(2, 0)
	print("\n🌱 Planting wheat at position ", plot_pos)

	var planted = farm.plant_plot(plot_pos, "wheat")
	if planted:
		print("  ✓ Plot planted successfully")
		var plot = farm.get_plot(plot_pos)
		print("  Plot type: ", plot.plot_type)
		print("  North emoji: ", plot.north_emoji)
		print("  South emoji: ", plot.south_emoji)
		print("  Has been measured: ", plot.is_measured)
	else:
		print("  ❌ Planting failed!")
		quit(1)

	# Check initial quantum state
	print("\n📊 Initial quantum state:")
	var p_wheat_0 = biome.quantum_computer.get_population("🌾")
	var p_mushroom_0 = biome.quantum_computer.get_population("🍄")
	var p_sun_0 = biome.quantum_computer.get_population("☀")
	print("  P(🌾 wheat) = %.3f" % p_wheat_0)
	print("  P(🍄 mushroom) = %.3f" % p_mushroom_0)
	print("  P(☀ sun) = %.3f" % p_sun_0)

	# Evolve biome
	print("\n⏱️ Evolving biome for 2 seconds...")
	for i in range(20):
		biome.advance_simulation(0.1)

	print("📊 After evolution:")
	var p_wheat_1 = biome.quantum_computer.get_population("🌾")
	var p_mushroom_1 = biome.quantum_computer.get_population("🍄")
	print("  P(🌾 wheat) = %.3f (Δ=%.3f)" % [p_wheat_1, p_wheat_1 - p_wheat_0])
	print("  P(🍄 mushroom) = %.3f (Δ=%.3f)" % [p_mushroom_1, p_mushroom_1 - p_mushroom_0])

	# Measure the plot
	print("\n🎲 Measuring plot...")
	var outcome = farm.measure_plot(plot_pos)
	print("  Measurement outcome: ", outcome)

	var plot = farm.get_plot(plot_pos)
	print("  Plot.is_measured: ", plot.is_measured)
	print("  Plot.measured_outcome: ", plot.measured_outcome)

	# Check post-measurement state
	print("\n📊 Post-measurement quantum state:")
	var p_wheat_2 = biome.quantum_computer.get_population("🌾")
	var p_mushroom_2 = biome.quantum_computer.get_population("🍄")
	print("  P(🌾 wheat) = %.3f (collapsed)" % p_wheat_2)
	print("  P(🍄 mushroom) = %.3f (collapsed)" % p_mushroom_2)

	# Verify collapse
	var is_collapsed = (p_wheat_2 > 0.99 and p_mushroom_2 < 0.01) or (p_mushroom_2 > 0.99 and p_wheat_2 < 0.01)
	if is_collapsed:
		print("  ✓ State properly collapsed to ", outcome)
	else:
		print("  ⚠️ State not fully collapsed")

	# Try harvesting
	print("\n🌾 Attempting harvest...")
	var harvest_result = farm.harvest_plot(plot_pos)
	if harvest_result:
		print("  ✓ Harvest successful")
		print("  Harvested emoji: ", harvest_result.get("emoji", "?"))
		print("  Amount: ", harvest_result.get("amount", 0))
	else:
		print("  ⚠️ Harvest returned nothing (expected for Model C)")

	print("\n✅ GAMEPLAY TEST COMPLETE")
	print("==================================================")
	quit()
