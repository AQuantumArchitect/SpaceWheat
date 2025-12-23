extends SceneTree
## Test tomato planting and visual encoding

const FarmView = preload("res://UI/FarmView.gd")

var farm_view: Node
var test_results = []
var tests_passed = 0
var tests_failed = 0

func _init():
	print("═══════════════════════════════════════════════════════")
	print("   TOMATO VISUAL ENCODING TEST")
	print("═══════════════════════════════════════════════════════")
	print("")

	# Create and initialize FarmView
	farm_view = FarmView.new()
	get_root().add_child(farm_view)

	# Wait for initialization
	await create_timer(0.2).timeout

	# Run tests
	test_tomato_planting()
	await create_timer(0.5).timeout

	test_tomato_conspiracy_assignment()
	await create_timer(0.5).timeout

	test_tomato_visual_updates()
	await create_timer(0.5).timeout

	test_network_overlay_toggle()
	await create_timer(0.5).timeout

	# Print summary
	_print_summary()

	# Exit
	await create_timer(0.1).timeout
	quit()


func test_tomato_planting():
	print("TEST 1: Tomato Planting")
	print("─────────────────────────────────────────")

	# Get first empty plot
	var farm_grid = farm_view.farm_grid
	var position = Vector2i(0, 0)

	# Plant tomato
	var initial_credits = farm_view.economy.credits
	var success = farm_grid.plant_tomato(position, farm_view.conspiracy_network)

	_assert_true(success, "Tomato planted successfully")

	var plot = farm_grid.get_plot(position)
	if plot:
		_assert_equal(plot.plot_type, 1, "Plot type is TOMATO")  # WheatPlot.PlotType.TOMATO = 1
		_assert_true(plot.conspiracy_node_id != "", "Conspiracy node assigned")
		_assert_true(farm_view.economy.credits < initial_credits, "Credits deducted")
	else:
		_assert_true(false, "Failed to get plot at (0,0)")

	print("")


func test_tomato_conspiracy_assignment():
	print("TEST 2: Conspiracy Node Assignment")
	print("─────────────────────────────────────────")

	var farm_grid = farm_view.farm_grid
	var conspiracy_network = farm_view.conspiracy_network

	# Plant 3 tomatoes
	for i in range(1, 4):  # Start at 1 since (0,0) already planted
		farm_grid.plant_tomato(Vector2i(i, 0), conspiracy_network)

	# Check that tomatoes have different conspiracy nodes
	var assigned_nodes = []
	for i in range(4):  # Check all 4 tomatoes (0-3)
		var plot = farm_grid.get_plot(Vector2i(i, 0))
		if plot and plot.plot_type == 1:  # TOMATO
			assigned_nodes.append(plot.conspiracy_node_id)

	_assert_true(assigned_nodes.size() >= 3, "Multiple tomatoes planted (%d)" % assigned_nodes.size())

	# Verify nodes exist in conspiracy network
	var all_nodes_valid = true
	for node_id in assigned_nodes:
		if not conspiracy_network.nodes.has(node_id):
			all_nodes_valid = false
			break
	_assert_true(all_nodes_valid, "All assigned nodes exist in network")

	print("")


func test_tomato_visual_updates():
	print("TEST 3: Tomato Visual Updates")
	print("─────────────────────────────────────────")

	var farm_grid = farm_view.farm_grid
	var conspiracy_network = farm_view.conspiracy_network

	# Find a tomato plot
	var tomato_plot = null
	for x in range(5):
		for y in range(5):
			var plot = farm_grid.get_plot(Vector2i(x, y))
			if plot and plot.plot_type == 1:  # TOMATO
				tomato_plot = plot
				break
		if tomato_plot:
			break

	if tomato_plot:
		# Get the conspiracy node
		var node = conspiracy_network.get_tomato_node(tomato_plot.conspiracy_node_id)

		if node:
			_assert_true(node.theta >= 0.0 and node.theta <= PI, "Node theta in valid range")
			_assert_true(node.energy > 0.0, "Node has energy")
			_assert_true(node.phi != 0.0, "Node phi is evolving")

			# Get the plot tile
			var tile = null
			for plot_tile in farm_view.plot_tiles:
				if plot_tile.grid_position == tomato_plot.position:
					tile = plot_tile
					break

			if tile:
				# Call update function manually
				tile.update_tomato_visuals(conspiracy_network)
				_assert_true(true, "Tomato visual update called successfully")
			else:
				_assert_true(false, "Could not find PlotTile for tomato")
		else:
			_assert_true(false, "Could not find conspiracy node")
	else:
		_assert_true(false, "No tomato plots found")

	print("")


func test_network_overlay_toggle():
	print("TEST 4: Network Overlay Toggle")
	print("─────────────────────────────────────────")

	var overlay = farm_view.network_overlay

	if overlay:
		# Initial state should be hidden
		var initial_visible = overlay.visible

		# Toggle visibility
		overlay.toggle_visibility()
		var toggled_visible = overlay.visible

		_assert_true(toggled_visible != initial_visible, "Overlay visibility toggled")

		# Toggle back
		overlay.toggle_visibility()
		var restored_visible = overlay.visible

		_assert_true(restored_visible == initial_visible, "Overlay visibility restored")

		# Check that overlay has correct number of nodes
		_assert_equal(overlay.node_sprites.size(), 12, "Overlay has 12 node sprites")
		_assert_equal(overlay.connection_lines.size(), 15, "Overlay has 15 connection lines")
	else:
		_assert_true(false, "Network overlay not found")

	print("")


## Helper functions

func _assert_true(condition: bool, description: String):
	if condition:
		print("  ✅ %s" % description)
		tests_passed += 1
	else:
		print("  ❌ %s" % description)
		tests_failed += 1
	test_results.append({"passed": condition, "description": description})


func _assert_equal(actual, expected, description: String):
	if actual == expected:
		print("  ✅ %s (got %s)" % [description, str(actual)])
		tests_passed += 1
	else:
		print("  ❌ %s (expected %s, got %s)" % [description, str(expected), str(actual)])
		tests_failed += 1
	test_results.append({"passed": actual == expected, "description": description})


func _print_summary():
	print("═══════════════════════════════════════════════════════")
	print("   TEST SUMMARY")
	print("═══════════════════════════════════════════════════════")
	print("")
	print("Total tests: %d" % (tests_passed + tests_failed))
	print("Passed: %d ✅" % tests_passed)
	print("Failed: %d ❌" % tests_failed)
	print("")

	if tests_failed == 0:
		print("🎉 ALL TESTS PASSED!")
	else:
		print("⚠️  SOME TESTS FAILED")
		print("")
		print("Failed tests:")
		for result in test_results:
			if not result["passed"]:
				print("  - %s" % result["description"])

	print("")
	print("═══════════════════════════════════════════════════════")
