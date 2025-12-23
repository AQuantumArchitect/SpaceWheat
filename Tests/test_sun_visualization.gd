#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test sun qubit visualization in QuantumForceGraph

var farm = null
var game_manager = null
var test_complete = false

func _process(delta):
	if not test_complete:
		test_complete = true
		await run_test()

func run_test():
	print("\n" + "=".repeat(70))
	print("SUN QUBIT VISUALIZATION TEST")
	print("=".repeat(70) + "\n")

	# Initialize manager
	const MemoryManager = preload("res://Core/GameState/MemoryManager.gd")
	game_manager = MemoryManager.new()
	root.add_child(game_manager)

	# Create new game
	var state = game_manager.new_game("default")
	print("Created game state")

	# Boot farm
	const Farm = preload("res://Core/Farm.gd")
	farm = Farm.new()
	root.add_child(farm)
	await root.get_tree().process_frame

	print("Farm initialized with biome")

	# Check that sun_qubit exists
	if not farm.biome or not farm.biome.sun_qubit:
		print("ERROR: Biome or sun_qubit not initialized")
		quit()
		return

	print("Sun qubit found: theta=%.1f degrees" % [farm.biome.sun_qubit.theta * 180.0 / PI])
	print("  North emoji: %s" % farm.biome.sun_qubit.north_emoji)
	print("  South emoji: %s" % farm.biome.sun_qubit.south_emoji)

	# Create QuantumForceGraph
	const QuantumForceGraph = preload("res://Core/Visualization/QuantumForceGraph.gd")
	var quantum_graph = QuantumForceGraph.new()
	root.add_child(quantum_graph)

	# Initialize with farm grid
	var center = Vector2(500, 300)
	var radius = 300.0
	quantum_graph.initialize(farm.grid, center, radius)
	print("\nQuantumForceGraph initialized")

	# Set biome and create sun node
	quantum_graph.set_biome(farm.biome)
	quantum_graph.create_sun_qubit_node()
	print("Sun qubit node created")

	# Verify sun node
	if not quantum_graph.sun_qubit_node:
		print("ERROR: Sun qubit node not created")
		quit()
		return

	var sun_node = quantum_graph.sun_qubit_node
	print("\nSun node details:")
	print("  Position: %s" % sun_node.position)
	print("  Grid position: %s" % sun_node.grid_position)
	print("  Plot ID: %s" % sun_node.plot_id)
	print("  Emoji north: %s" % sun_node.emoji_north)
	print("  Emoji south: %s" % sun_node.emoji_south)
	print("  Radius: %.1f" % sun_node.radius)
	print("  Color: %s" % sun_node.color)

	# Verify node properties
	var success_count = 0

	if quantum_graph.sun_qubit_node:
		print("  OK: Sun node exists")
		success_count += 1
	else:
		print("  FAIL: Sun node is null")

	if sun_node.plot_id == "celestial_sun":
		print("  OK: Sun node has correct plot_id")
		success_count += 1
	else:
		print("  FAIL: Sun node plot_id mismatch")

	if sun_node.emoji_north == farm.biome.sun_qubit.north_emoji:
		print("  OK: Sun node has correct north emoji")
		success_count += 1
	else:
		print("  FAIL: Sun node emoji mismatch")

	# Sun should be positioned at a distance from the play area center
	var center_pos = Vector2(500, 300)  # Same as initialized above
	var distance_from_center = sun_node.position.distance_to(center_pos)
	if distance_from_center > 100:
		print("  OK: Sun positioned away from center (distance: %.1f)" % distance_from_center)
		success_count += 1
	else:
		print("  FAIL: Sun too close to center (distance: %.1f)" % distance_from_center)

	# Test day/night cycle by updating sun theta
	print("\nTesting day/night cycle:")
	var initial_theta = farm.biome.sun_qubit.theta
	farm.biome.time_elapsed = 5.0  # Advance time
	farm.biome._sync_sun_qubit(0.016)  # One frame
	var new_theta = farm.biome.sun_qubit.theta

	# Update node from quantum state
	sun_node.update_from_quantum_state()

	print("  Initial theta: %.1f degrees" % [initial_theta * 180.0 / PI])
	print("  New theta: %.1f degrees" % [new_theta * 180.0 / PI])

	if abs(new_theta - initial_theta) > 0.001:
		print("  OK: Sun theta updated")
		success_count += 1
	else:
		print("  FAIL: Sun theta not changing")

	# Final report
	print("\n" + "=".repeat(70))
	if success_count == 5:
		print("PASS: All 5 checks passed")
	else:
		print("PARTIAL: %d/5 checks passed" % success_count)
	print("=".repeat(70) + "\n")

	quit()
