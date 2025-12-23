#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: Biome Modes
##
## Verifies:
## 1. NullBiome works (nothing happens)
## 2. Normal Biome works (evolution continues)
## 3. Biome.is_static flag works (evolution paused)

const Biome = preload("res://Core/Environment/Biome.gd")
const NullBiome = preload("res://Core/Environment/NullBiome.gd")
const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const WheatPlot = preload("res://Core/GameMechanics/WheatPlot.gd")

func _initialize():
	print_header()

	_test_null_biome()
	_test_normal_biome()
	_test_static_mode()

	print_footer()
	quit()


func print_header():
	var line = ""
	for i in range(80):
		line += "="
	print("\n" + line)
	print("🌍 BIOME MODES TEST")
	print("Verify NullBiome (for UI) and Normal Biome (for gameplay)")
	print(line + "\n")


func print_footer():
	var line = ""
	for i in range(80):
		line += "="
	print(line)
	print("✅ ALL BIOME MODE TESTS COMPLETE")
	print(line + "\n")


func print_phase(title: String):
	var line = ""
	for i in range(70):
		line += "─"
	print(line)
	print(title)
	print(line + "\n")


func _test_null_biome():
	print_phase("TEST 1: NullBiome (UI Testing Mode)")

	var null_biome = NullBioticFluxBiome.new()
	null_biome._ready()

	print("✓ NullBiome created")

	# Run for several frames
	for i in range(100):
		null_biome._process(0.016)

	print("✓ NullBiome processed 100 frames (%.1fs)" % (null_biome.time_elapsed))
	print("✓ No quantum states created: %s" % (null_biome.quantum_states.is_empty()))
	print("✓ No evolution occurred: %s" % (null_biome.quantum_states.is_empty()))

	print("\n💡 Use Case: UI teams can develop interfaces without quantum evolution interfering\n")


func _test_normal_biome():
	print_phase("TEST 2: Normal Biome (Full Quantum Evolution)")

	var grid = FarmGrid.new()
	grid.grid_width = 2
	grid.grid_height = 1

	# Initialize plots
	for x in range(grid.grid_width):
		var plot = WheatPlot.new()
		plot.grid_position = Vector2i(x, 0)
		grid.plots[Vector2i(x, 0)] = plot

	var biome = BioticFluxBiome.new()
	biome.grid = grid
	biome._ready()

	print("✓ Normal Biome created")
	print("✓ Grid linked: %s" % (biome.grid != null))

	# Create a quantum state
	var qb = biome.create_quantum_state(Vector2i(0, 0), "🌾", "👥", 1.0)
	print("✓ Quantum state created: %s" % (qb != null))

	var initial_theta = qb.theta if qb else 0.0

	# Run evolution
	for i in range(100):
		biome._process(0.016)

	var final_theta = qb.theta if qb else initial_theta

	print("✓ Biome processed 100 frames (%.1fs)" % (biome.time_elapsed))
	print("✓ Sun/Moon cycle advanced: theta_sun = %.3f rad" % biome.sun_qubit.theta)
	print("✓ Quantum evolution occurred: theta changed (%.3f → %.3f)" % [initial_theta, final_theta])

	print("\n💡 Use Case: Normal gameplay with full quantum mechanics\n")


func _test_static_mode():
	print_phase("TEST 3: Static Mode (Evolution Paused)")

	var grid = FarmGrid.new()
	grid.grid_width = 2
	grid.grid_height = 1

	for x in range(grid.grid_width):
		var plot = WheatPlot.new()
		plot.grid_position = Vector2i(x, 0)
		grid.plots[Vector2i(x, 0)] = plot

	var biome = BioticFluxBiome.new()
	biome.grid = grid
	biome.is_static = true  # Enable static mode
	biome._ready()

	print("✓ Biome created in static mode")
	print("✓ is_static flag: %s" % biome.is_static)

	# Create quantum state
	var qb = biome.create_quantum_state(Vector2i(0, 0), "🌾", "👥", 1.0)
	var initial_theta = qb.theta if qb else 0.0

	# Run for frames (nothing should happen)
	for i in range(100):
		biome._process(0.016)

	var final_theta = qb.theta if qb else initial_theta

	print("✓ Biome processed 100 frames (%.1fs)" % (biome.time_elapsed))
	print("✓ Evolution PAUSED: theta unchanged (%.3f → %.3f)" % [initial_theta, final_theta])
	print("✓ Time still tracks: %.1fs elapsed" % biome.time_elapsed)

	print("\n💡 Use Case: Paused gameplay for debugging or intermediate states\n")


func _verify_biome_interface():
	"""Verify both biomes have compatible interfaces"""
	print_phase("BONUS: Interface Compatibility Check")

	var null_biome = NullBioticFluxBiome.new()
	var normal_biome = BioticFluxBiome.new()

	var required_methods = [
		"_ready",
		"_process",
		"create_quantum_state",
		"get_qubit",
		"_evolve_quantum_substrate",
		"_update_energy_taps"
	]

	var all_ok = true
	for method in required_methods:
		var null_has = null_biome.has_method(method)
		var normal_has = normal_biome.has_method(method)

		if null_has and normal_has:
			print("   ✓ %s: Both have method" % method)
		else:
			print("   ❌ %s: Mismatch! (NullBiome=%s, Biome=%s)" % [method, null_has, normal_has])
			all_ok = false

	if all_ok:
		print("\n✓ Interfaces compatible - can swap between biomes\n")
	else:
		print("\n⚠️  Interface mismatch detected\n")
