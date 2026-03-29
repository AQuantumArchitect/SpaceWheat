#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: Measurement & Collapse (No Evolution)
## Skip evolution to isolate measurement testing

const Farm = preload("res://Core/Farm.gd")

func _init():
	print("\n🧪 MEASUREMENT TEST (No Evolution)")
	print("=" + "=".repeat(49))

	# Setup
	var farm = Farm.new()
	farm._ready()

	if farm.biotic_flux_biome and not farm.biotic_flux_biome.bath:
		farm.biotic_flux_biome._ready()

	farm.economy.add_resource("🌾", 100, "test")

	var biome = farm.grid.get_biome("BioticFlux")
	var test_pos = Vector2i(2, 0)

	# Plant
	print("\n🌱 Planting...")
	farm.build(test_pos, "wheat")

	var plot = farm.grid.get_plot(test_pos)
	var qubit = plot.quantum_state

	print("  ✓ Qubit: %s ↔ %s" % [qubit.north_emoji, qubit.south_emoji])

	# Check initial bath state
	var wheat_before = biome.bath.get_population("🌾")
	var labor_before = biome.bath.get_population("👥")

	print("\n📊 Before measurement:")
	print("  🌾 = %.4f" % wheat_before)
	print("  👥 = %.4f" % labor_before)
	print("  θ = %.4f" % qubit.theta)

	# Measure
	print("\n🔬 Measuring...")
	var outcome = farm.measure_plot(test_pos)
	print("  Result: %s" % outcome)

	# Check after measurement
	var wheat_after = biome.bath.get_population("🌾")
	var labor_after = biome.bath.get_population("👥")
	var theta_after = qubit.theta

	print("\n📊 After measurement:")
	print("  🌾 = %.4f → %.4f" % [wheat_before, wheat_after])
	print("  👥 = %.4f → %.4f" % [labor_before, labor_after])
	print("  θ = %.4f" % theta_after)

	# Verify collapse
	print("\n🔍 Checking collapse...")
	if outcome == "🌾":
		if labor_after < 0.01:
			print("  ✅ 👥 collapsed to 0")
		else:
			print("  ⚠️  👥 = %.4f (expected ~0)" % labor_after)
	else:
		if wheat_after < 0.01:
			print("  ✅ 🌾 collapsed to 0")
		else:
			print("  ⚠️  🌾 = %.4f (expected ~0)" % wheat_after)

	# Check normalization
	var total = 0.0
	for emoji in biome.bath.emoji_list:
		total += biome.bath.get_probability(emoji)

	print("\n🔄 Normalization:")
	print("  Total = %.6f" % total)
	if abs(total - 1.0) < 0.01:
		print("  ✅ Bath normalized")
	else:
		print("  ❌ Bath NOT normalized!")

	print("\n✅ TEST COMPLETE")
	quit(0)
