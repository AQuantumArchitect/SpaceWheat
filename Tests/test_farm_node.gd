#!/usr/bin/env -S godot --headless -s
extends Node

## Farm test as a regular Node (not SceneTree)

func _ready():
	print("\n🔧 Node-based farm test _ready()")

	# Create and test Farm
	print("Loading Farm class...")
	const Farm = preload("res://Core/Farm.gd")

	var farm = Farm.new()
	add_child(farm)

	print("✓ Farm instance created")
	print("  Grid size: %dx%d" % [farm.grid_width, farm.grid_height])
	print("  Has biome: %s" % (farm.biome != null))
	print("  Has grid: %s" % (farm.grid != null))

	# Simple test
	if farm.grid and farm.biome:
		var pos = Vector2i(0, 0)
		var plot = farm.grid.get_plot(pos)
		if plot:
			print("\n✓ Got plot at (0,0)")

			# Plant
			var qubit = farm.biome.create_quantum_state(pos, "🌾", "🌱", PI/2)
			plot.plant(qubit)
			print("✓ Planted qubit")

			# Evolve
			farm.biome._evolve_quantum_substrate(0.1)
			print("✓ Evolved quantum state")

			# Measure
			var outcome = farm.biome.measure_qubit(pos)
			plot.measure(outcome)
			print("✓ Measured qubit (outcome: %s)" % outcome)

			print("\n✅ SUCCESS: Simulation works!")

	print("\nExiting...")
	get_tree().quit()
