extends Node

## Automated test for quantum force-directed graph
## Simulates gameplay to verify entanglement visualization

var farm_view: Node
var test_results: Array[String] = []

func _ready():
	print("\n🧪 ===== QUANTUM GRAPH PHANTOM PLAY TEST =====\n")

	# Wait a frame for everything to initialize
	await get_tree().process_frame
	await get_tree().process_frame

	# Find FarmView in scene tree (it's a sibling node)
	farm_view = get_parent().get_node("FarmView")
	if not farm_view:
		print("❌ FAILED: Could not find FarmView")
		print("   Available nodes: %s" % get_parent().get_children())
		get_tree().quit(1)
		return

	print("✅ Found FarmView")

	# Wait for FarmView to fully initialize
	await get_tree().process_frame
	await get_tree().process_frame

	# Run test sequence
	await _run_tests()

	# Print results
	print("\n🧪 ===== TEST RESULTS =====")
	for result in test_results:
		print(result)

	print("\n🧪 Tests complete! Exiting in 2 seconds...")
	await get_tree().create_timer(2.0).timeout
	get_tree().quit(0)


func _run_tests():
	"""Run automated gameplay tests"""

	# Test 1: Plant wheat at plot (1, 1)
	await _test_plant_wheat(Vector2i(1, 1))
	await get_tree().create_timer(0.5).timeout

	# Test 2: Plant wheat at plot (2, 2)
	await _test_plant_wheat(Vector2i(2, 2))
	await get_tree().create_timer(0.5).timeout

	# Test 3: Create entanglement between (1,1) and (2,2)
	await _test_create_entanglement(Vector2i(1, 1), Vector2i(2, 2))
	await get_tree().create_timer(0.5).timeout

	# Test 4: Check quantum graph has entanglement
	await _test_check_entanglement()
	await get_tree().create_timer(0.5).timeout

	# Test 5: Plant tomato at plot (3, 3)
	await _test_plant_tomato(Vector2i(3, 3))
	await get_tree().create_timer(0.5).timeout

	# Test 6: Verify force-directed graph movement
	await _test_check_node_movement()


func _test_plant_wheat(pos: Vector2i):
	"""Test planting wheat"""
	print("\n🌾 Test: Plant wheat at %s" % pos)

	# Select plot
	farm_view._select_plot(pos)

	# Plant wheat (simulate P key press)
	farm_view._on_plant_pressed()

	# Verify plot is planted
	var plot = farm_view.farm_grid.get_plot(pos)
	if plot and plot.is_planted and plot.plot_type == 0:  # 0 = WHEAT
		test_results.append("✅ Wheat planted at %s" % pos)
	else:
		test_results.append("❌ FAILED: Wheat not planted at %s" % pos)


func _test_plant_tomato(pos: Vector2i):
	"""Test planting tomato"""
	print("\n🍅 Test: Plant tomato at %s" % pos)

	# Select plot
	farm_view._select_plot(pos)

	# Plant tomato (simulate T key press)
	farm_view._on_plant_tomato_pressed()

	# Verify plot is planted
	var plot = farm_view.farm_grid.get_plot(pos)
	if plot and plot.is_planted and plot.plot_type == 1:  # 1 = TOMATO
		test_results.append("✅ Tomato planted at %s" % pos)
	else:
		test_results.append("❌ FAILED: Tomato not planted at %s" % pos)


func _test_create_entanglement(pos_a: Vector2i, pos_b: Vector2i):
	"""Test creating entanglement"""
	print("\n🔗 Test: Create entanglement %s ↔ %s" % [pos_a, pos_b])

	# Select first plot
	farm_view._select_plot(pos_a)

	# Start entangle mode (simulate E key)
	farm_view._on_entangle_pressed()

	# Select second plot (this should create entanglement)
	farm_view._on_tile_clicked(pos_b)

	# Verify entanglement exists
	var plot_a = farm_view.farm_grid.get_plot(pos_a)
	var plot_b = farm_view.farm_grid.get_plot(pos_b)

	if plot_a and plot_b:
		if plot_a.entangled_plots.has(plot_b.plot_id):
			test_results.append("✅ Entanglement created: %s ↔ %s" % [pos_a, pos_b])
		else:
			test_results.append("❌ FAILED: No entanglement between %s and %s" % [pos_a, pos_b])
	else:
		test_results.append("❌ FAILED: Could not find plots for entanglement")


func _test_check_entanglement():
	"""Test quantum graph detects entanglement"""
	print("\n⚛️ Test: Check quantum graph entanglement detection")

	var stats = farm_view.quantum_graph.get_stats()

	print("   Active nodes: %d" % stats.active_nodes)
	print("   Entanglements: %d" % stats.total_entanglements)

	if stats.total_entanglements > 0:
		test_results.append("✅ Quantum graph detects %d entanglement(s)" % stats.total_entanglements)
	else:
		test_results.append("❌ FAILED: Quantum graph shows 0 entanglements (should be 1+)")


func _test_check_node_movement():
	"""Test quantum nodes are moving"""
	print("\n🎯 Test: Check quantum node movement")

	# Record initial positions
	var quantum_graph = farm_view.quantum_graph
	var initial_positions = {}

	for node in quantum_graph.quantum_nodes:
		if node.plot and node.plot.is_planted:
			initial_positions[node.plot_id] = node.position

	print("   Recorded %d node positions" % initial_positions.size())

	# Wait for physics to update
	for i in range(60):  # Wait 60 frames (1 second at 60 FPS)
		await get_tree().process_frame

	# Check if positions changed
	var moved_count = 0
	for plot_id in initial_positions:
		for node in quantum_graph.quantum_nodes:
			if node.plot and node.plot.plot_id == plot_id:
				var initial_pos = initial_positions[plot_id]
				var distance_moved = node.position.distance_to(initial_pos)
				if distance_moved > 1.0:  # Moved more than 1 pixel
					moved_count += 1
					print("   Node %s moved %.1f pixels" % [plot_id, distance_moved])

	if moved_count > 0:
		test_results.append("✅ %d quantum nodes are moving (force-directed physics working)" % moved_count)
	else:
		test_results.append("❌ FAILED: No nodes moved (force-directed physics may be broken)")
