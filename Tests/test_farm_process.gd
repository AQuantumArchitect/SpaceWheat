#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Farm test using _process callback

var test_run = false

func _process(delta):
	if not test_run:
		test_run = true
		run_test()

func run_test():
	print("\n🔧 PROCESS CALLBACK: Farm test running")

	const Farm = preload("res://Core/Farm.gd")
	var farm = Farm.new()
	root.add_child(farm)

	# Brief pause for initialization
	await root.get_tree().process_frame

	if not (farm and farm.grid and farm.biome):
		print("❌ Farm initialization failed")
		print("  Farm: %s, Grid: %s, Biome: %s" % [farm != null, farm.grid != null if farm else false, farm.biome != null if farm else false])
		quit()
		return

	print("✓ Farm created (Grid: %dx%d)" % [farm.grid_width, farm.grid_height])

	# Test single plot cycle
	var pos = Vector2i(0, 0)
	var plot = farm.grid.get_plot(pos)

	if not plot:
		print("❌ Could not get plot")
		quit()
		return

	# Plant
	var qubit = farm.biome.create_quantum_state(pos, "🌾", "🌱", PI/2)
	plot.plant(qubit)
	print("✓ Planted qubit at (0,0)")

	# Evolve
	for i in range(3):
		farm.biome._evolve_quantum_substrate(0.1)
	print("✓ Evolved quantum state")

	# Measure
	var outcome = farm.biome.measure_qubit(pos)
	plot.measure(outcome)
	print("✓ Measured qubit (outcome: %s)" % outcome)

	# Harvest
	plot.harvest()
	farm.biome.clear_qubit(pos)
	print("✓ Harvested crop")

	print("\n✅ SUCCESS: Simulation works in headless mode!")
	print("   Farm → Plant → Evolve → Measure → Harvest CYCLE COMPLETE\n")

	quit()
