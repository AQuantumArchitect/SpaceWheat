extends SceneTree

## Simple verification test
## Tests farm methods directly and with simulated clicks

func _init():
	print("\n═══════════════════════════════════════════════")
	print("BUBBLE TAP ACTION VERIFICATION")
	print("═══════════════════════════════════════════════\n")

func _ready():
	# Load main scene
	var farm_view_scene = load("res://scenes/FarmView.tscn")
	if not farm_view_scene:
		print("❌ Could not load FarmView scene")
		quit(1)
		return

	var farm_view = farm_view_scene.instantiate()
	root.add_child(farm_view)

	print("⏳ Waiting for initialization...")
	await create_timer(3.0).timeout

	var farm = farm_view.farm
	if not farm:
		print("❌ Farm not available")
		quit(1)
		return

	print("✅ Farm initialized\n")

	# Test direct farm methods
	await test_farm_methods(farm)

	# Test with quantum viz
	await test_with_quantum_viz(farm, farm_view.quantum_viz)

	quit(0)


func test_farm_methods(farm) -> void:
	print("━━━ TEST 1: Direct farm.measure_plot() ━━━")

	var test_pos = Vector2i(2, 0)

	# Plant
	farm.plant_wheat(test_pos)
	await create_timer(0.2).timeout

	var plot = farm.grid.get_plot_at(test_pos)
	print("  After plant: planted=%s, measured=%s" % [plot.is_planted, plot.is_measured])

	# Measure
	farm.measure_plot(test_pos)
	await create_timer(0.2).timeout

	plot = farm.grid.get_plot_at(test_pos)
	print("  After measure_plot(): planted=%s, measured=%s" % [plot.is_planted, plot.is_measured])

	if plot.is_measured:
		print("  ✓ measure_plot() WORKS\n")
	else:
		print("  ✗ measure_plot() FAILED\n")

	# Harvest
	farm.harvest_plot(test_pos)
	await create_timer(0.2).timeout

	plot = farm.grid.get_plot_at(test_pos)
	print("  After harvest_plot(): planted=%s, measured=%s" % [plot.is_planted, plot.is_measured])

	if not plot.is_planted:
		print("  ✓ harvest_plot() WORKS\n")
	else:
		print("  ✗ harvest_plot() FAILED\n")


func test_with_quantum_viz(farm, quantum_viz) -> void:
	if not quantum_viz:
		print("━━━ Skipping quantum viz test (not available) ━━━\n")
		return

	print("━━━ TEST 2: With quantum visualization ━━━")

	var test_pos = Vector2i(3, 0)

	# Plant to create bubble
	farm.plant_wheat(test_pos)
	await create_timer(0.5).timeout

	var bubble_count = quantum_viz.graph.quantum_nodes.size()
	print("  Bubble count after plant: %d" % bubble_count)

	# Find the bubble
	var bubble = null
	for node in quantum_viz.graph.quantum_nodes:
		if node.grid_position == test_pos:
			bubble = node
			break

	if not bubble:
		print("  ✗ No bubble created for plot\n")
		return

	print("  ✓ Bubble created at screen pos: %s" % bubble.position)

	# Simulate click by calling handler directly
	print("\n  Calling tap handler directly...")
	var farm_view = farm.get_parent()  # FarmView
	if farm_view and farm_view.has_method("_on_quantum_node_clicked"):
		farm_view._on_quantum_node_clicked(test_pos, 1)
		await create_timer(0.3).timeout

		var plot = farm.grid.get_plot_at(test_pos)
		print("  After handler call: planted=%s, measured=%s" % [plot.is_planted, plot.is_measured])

		if plot.is_measured:
			print("  ✓ Handler call → measure WORKS\n")
		else:
			print("  ✗ Handler call → measure FAILED\n")
	else:
		print("  ✗ Could not find handler\n")
