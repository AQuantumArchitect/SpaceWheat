extends SceneTree

## Test: Verify quantum bubbles are created when planting

func _init():
	print("\n" + "=".repeat(70))
	print("TEST: Quantum Bubble Creation on Plant")
	print("=".repeat(70))

	# Create farm
	var Farm = load("res://Core/Farm.gd")
	var farm = Farm.new()
	root.add_child(farm)

	# Wait for farm to initialize
	await get_tree().process_frame
	await get_tree().process_frame

	# Create visualization
	var BathQuantumViz = load("res://Core/Visualization/BathQuantumVisualizationController.gd")
	var viz = BathQuantumViz.new()
	root.add_child(viz)

	# Register biomes
	viz.add_biome("BioticFlux", farm.biotic_flux_biome)
	viz.add_biome("Market", farm.market_biome)
	viz.add_biome("Forest", farm.forest_biome)
	viz.add_biome("Kitchen", farm.kitchen_biome)

	# Initialize visualization
	viz.initialize()
	await get_tree().process_frame

	# Connect to farm signals
	viz.connect_to_farm(farm)

	print("\n📊 Initial State:")
	print("  - BioticFlux bubbles: %d" % viz.basis_bubbles.get("BioticFlux", []).size())
	print("  - Market bubbles: %d" % viz.basis_bubbles.get("Market", []).size())
	print("  - Forest bubbles: %d" % viz.basis_bubbles.get("Forest", []).size())
	print("  - Kitchen bubbles: %d" % viz.basis_bubbles.get("Kitchen", []).size())
	print("  - Total graph nodes: %d" % viz.graph.quantum_nodes.size())

	# Give starting resources
	farm.economy.add_resource("🌾", 100)
	farm.economy.add_resource("🍄", 100)
	farm.economy.add_resource("🍂", 100)

	print("\n🌱 Test 1: Plant wheat at BioticFlux plot (2,0)")
	var success = farm.build(Vector2i(2, 0), "wheat")
	print("  - Plant result: %s" % ("SUCCESS" if success else "FAILED"))

	await get_tree().process_frame
	await get_tree().process_frame

	print("\n📊 After planting wheat:")
	print("  - BioticFlux bubbles: %d" % viz.basis_bubbles.get("BioticFlux", []).size())
	print("  - Total graph nodes: %d" % viz.graph.quantum_nodes.size())
	print("  - Nodes by grid pos: %d entries" % viz.graph.quantum_nodes_by_grid_pos.size())

	if viz.graph.quantum_nodes_by_grid_pos.has(Vector2i(2, 0)):
		var bubble = viz.graph.quantum_nodes_by_grid_pos[Vector2i(2, 0)]
		print("  ✅ FOUND bubble at (2,0): %s/%s" % [bubble.emoji_north, bubble.emoji_south])
	else:
		print("  ❌ NO bubble found at (2,0)")

	print("\n🌱 Test 2: Plant mushroom at BioticFlux plot (3,0)")
	success = farm.build(Vector2i(3, 0), "mushroom")
	print("  - Plant result: %s" % ("SUCCESS" if success else "FAILED"))

	await get_tree().process_frame
	await get_tree().process_frame

	print("\n📊 After planting mushroom:")
	print("  - BioticFlux bubbles: %d" % viz.basis_bubbles.get("BioticFlux", []).size())
	print("  - Total graph nodes: %d" % viz.graph.quantum_nodes.size())

	if viz.graph.quantum_nodes_by_grid_pos.has(Vector2i(3, 0)):
		var bubble = viz.graph.quantum_nodes_by_grid_pos[Vector2i(3, 0)]
		print("  ✅ FOUND bubble at (3,0): %s/%s" % [bubble.emoji_north, bubble.emoji_south])
	else:
		print("  ❌ NO bubble found at (3,0)")

	print("\n🌱 Test 3: Plant vegetation at Forest plot (0,1)")
	success = farm.build(Vector2i(0, 1), "vegetation")
	print("  - Plant result: %s" % ("SUCCESS" if success else "FAILED"))

	await get_tree().process_frame
	await get_tree().process_frame

	print("\n📊 After planting vegetation:")
	print("  - Forest bubbles: %d" % viz.basis_bubbles.get("Forest", []).size())
	print("  - Total graph nodes: %d" % viz.graph.quantum_nodes.size())

	if viz.graph.quantum_nodes_by_grid_pos.has(Vector2i(0, 1)):
		var bubble = viz.graph.quantum_nodes_by_grid_pos[Vector2i(0, 1)]
		print("  ✅ FOUND bubble at (0,1): %s/%s" % [bubble.emoji_north, bubble.emoji_south])
	else:
		print("  ❌ NO bubble found at (0,1)")

	print("\n" + "=".repeat(70))
	print("TEST COMPLETE")
	print("=".repeat(70))

	quit()
