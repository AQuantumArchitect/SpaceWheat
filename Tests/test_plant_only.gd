#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Minimal test: Just plant and verify bath coupling

const Farm = preload("res://Core/Farm.gd")

func _init():
	print("\n🧪 MINIMAL PLANT TEST")

	# Create farm
	var farm = Farm.new()
	farm._ready()

	# Init BioticFlux biome manually (position 2,0 is in BioticFlux)
	if farm.biotic_flux_biome and not farm.biotic_flux_biome.bath:
		farm.biotic_flux_biome._ready()

	# Give resources
	farm.economy.add_resource("🌾", 100, "test")

	# Plant at BioticFlux position (2,0) which has 🌾 in bath
	var test_pos = Vector2i(2, 0)
	print("🌱 Planting wheat at %s (BioticFlux biome)..." % test_pos)
	var result = farm.build(test_pos, "wheat")

	if not result:
		print("❌ Plant failed")
		quit(1)
		return

	print("✅ Plant succeeded")

	# Check plot
	var plot = farm.grid.get_plot(test_pos)
	if not plot or not plot.quantum_state:
		print("❌ No quantum state")
		quit(1)
		return

	var qubit = plot.quantum_state
	print("  Qubit: %s ↔ %s" % [qubit.north_emoji, qubit.south_emoji])

	# Check bath coupling
	if not qubit.bath:
		print("❌ No bath coupling!")
		quit(1)
		return

	print("✅ Bath coupled")
	print("  Theta from bath: %.4f" % qubit.theta)

	# Get biome (BioticFlux)
	var biome = farm.grid.get_biome("BioticFlux")
	if not biome or not biome.bath:
		print("❌ No biome bath")
		quit(1)
		return

	var north_pop = biome.bath.get_population(qubit.north_emoji)
	var south_pop = biome.bath.get_population(qubit.south_emoji)

	print("  Bath populations:")
	print("    %s: %.4f" % [qubit.north_emoji, north_pop])
	print("    %s: %.4f" % [qubit.south_emoji, south_pop])

	print("\n✅ ALL CHECKS PASSED")
	quit(0)
