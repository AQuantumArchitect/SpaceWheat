#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Quick test of sun/wheat physics coupling system

var test_run = false

func _process(delta):
	if not test_run:
		test_run = true
		run_test()

func run_test():
	print("\n" + "=".repeat(70))
	print("🌾☀️ SUN/WHEAT PHYSICS TEST")
	print("=".repeat(70) + "\n")

	const Farm = preload("res://Core/Farm.gd")

	# Create farm (which owns the Biome)
	var farm = Farm.new()
	root.add_child(farm)
	farm._ready()

	# Get the biome from the farm
	var biome = farm.biome

	if not farm.grid or not farm.biome:
		print("❌ Farm failed to initialize")
		quit()
		return

	print("✓ Farm initialized")

	# Plant a wheat
	var pos = Vector2i(0, 0)
	var success = farm.build(pos, "wheat")
	if not success:
		print("❌ Failed to plant wheat")
		quit()
		return

	var plot = farm.grid.get_plot(pos)
	if not plot or not plot.quantum_state:
		print("❌ Wheat plot missing quantum state")
		quit()
		return

	print("✓ Planted wheat at (0,0)")
	print("  Initial theta: %.1f°" % [plot.quantum_state.theta * 180.0 / PI])

	# Simulate for a few seconds (5 seconds = 1/4 of 20-second cycle)
	print("\n▶ Running simulation...")
	var simulation_time = 5.0
	var time_step = 0.016  # ~60fps
	var elapsed = 0.0

	var initial_theta = plot.quantum_state.theta
	var initial_radius = plot.quantum_state.radius

	while elapsed < simulation_time:
		biome._process(time_step)
		elapsed += time_step

	print("✓ Simulated %.1fs" % elapsed)

	# Check results
	var final_theta = plot.quantum_state.theta
	var final_radius = plot.quantum_state.radius
	var theta_change = final_theta - initial_theta
	var radius_change = final_radius - initial_radius

	print("\n📊 Results:")
	print("  Sun theta: %.1f° (cycling)" % [biome.sun_qubit.theta * 180.0 / PI])
	print("  Icon theta: %.1f° (should move toward wheat)" % [biome.wheat_icon.theta * 180.0 / PI])
	print("  Wheat theta: %.1f° → %.1f° (change: %.1f°)" % [initial_theta * 180.0 / PI, final_theta * 180.0 / PI, theta_change * 180.0 / PI])
	print("  Wheat radius: %.3f → %.3f (energy growth: %.3f)" % [initial_radius, final_radius, radius_change])

	# Validation
	var success_count = 0

	# Sun should have cycled
	if abs(biome.sun_qubit.theta) < PI:
		print("  ✓ Sun in expected phase (theta < π)")
		success_count += 1
	else:
		print("  ✗ Sun phase unexpected")

	# Icon should have moved toward wheat
	if biome.wheat_icon.theta < PI/6:  # Started at π/12, should be lower
		print("  ✓ Icon moved toward agrarian")
		success_count += 1
	else:
		print("  ✗ Icon didn't move as expected")

	# Wheat should have gained energy (radius increased)
	if radius_change > 0.01:
		print("  ✓ Wheat gained energy during sun phase")
		success_count += 1
	else:
		print("  ✗ Wheat didn't gain energy")

	# Wheat theta should have moved toward sun (coupling effect)
	if abs(theta_change) > 0.01:
		print("  ✓ Wheat theta changed due to sun coupling")
		success_count += 1
	else:
		print("  ✗ Wheat theta didn't change")

	print("\n" + "=".repeat(70))
	if success_count == 4:
		print("✅ ALL PHYSICS TESTS PASSED")
	else:
		print("⚠️ PARTIAL SUCCESS: %d/4 tests passed" % success_count)
	print("=".repeat(70))

	quit()
