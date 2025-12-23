extends Node

## Test suite for ConspiracyNetworkOverlay visualization
## Tests force-directed graph, visual encoding, and tomato integration

# Preload required classes
const TomatoConspiracyNetwork = preload("res://Core/QuantumSubstrate/TomatoConspiracyNetwork.gd")
const ConspiracyNetworkOverlay = preload("res://UI/ConspiracyNetworkOverlay.gd")

var test_results = []
var tests_passed = 0
var tests_failed = 0

# Test components
var conspiracy_network
var network_overlay


func _ready():
	print("═══════════════════════════════════════════════════════")
	print("   CONSPIRACY NETWORK OVERLAY TEST SUITE")
	print("═══════════════════════════════════════════════════════")
	print("")

	# Run all tests
	test_conspiracy_network_initialization()
	test_network_overlay_creation()
	test_force_directed_graph_setup()
	test_node_visual_encoding()
	test_connection_line_encoding()
	test_temperature_color_mapping()
	test_energy_flow_direction()
	test_force_directed_convergence()

	# Print summary
	_print_summary()

	# Exit
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()


func test_conspiracy_network_initialization():
	print("TEST 1: Conspiracy Network Initialization")
	print("─────────────────────────────────────────")

	conspiracy_network = TomatoConspiracyNetwork.new()
	add_child(conspiracy_network)

	# Wait one frame for _ready()
	await get_tree().process_frame

	# Test: Should have 12 nodes
	_assert_equal(conspiracy_network.nodes.size(), 12, "12 nodes created")

	# Test: Should have 15 connections
	_assert_equal(conspiracy_network.connections.size(), 15, "15 connections created")

	# Test: All nodes should have initial energy
	var all_have_energy = true
	for node_id in conspiracy_network.nodes.keys():
		var node = conspiracy_network.nodes[node_id]
		if node.energy == 0.0:
			all_have_energy = false
			break
	_assert_true(all_have_energy, "All nodes have non-zero energy")

	# Test: Specific nodes exist
	_assert_true(conspiracy_network.nodes.has("seed"), "Seed node exists")
	_assert_true(conspiracy_network.nodes.has("meta"), "Meta node exists")
	_assert_true(conspiracy_network.nodes.has("observer"), "Observer node exists")

	print("")


func test_network_overlay_creation():
	print("TEST 2: Network Overlay Creation")
	print("─────────────────────────────────────────")

	network_overlay = ConspiracyNetworkOverlay.new()
	network_overlay.conspiracy_network = conspiracy_network
	add_child(network_overlay)

	# Wait for _ready()
	await get_tree().process_frame

	# Test: Should have created 12 node sprites
	_assert_equal(network_overlay.node_sprites.size(), 12, "12 node sprites created")

	# Test: Should have created 15 connection lines
	_assert_equal(network_overlay.connection_lines.size(), 15, "15 connection lines created")

	# Test: All nodes should have positions
	_assert_equal(network_overlay.node_positions.size(), 12, "All nodes have positions")

	# Test: All nodes should have velocities
	_assert_equal(network_overlay.node_velocities.size(), 12, "All nodes have velocities")

	# Test: Center should be set
	_assert_true(network_overlay.center != Vector2.ZERO, "Center position set")

	print("")


func test_force_directed_graph_setup():
	print("TEST 3: Force-Directed Graph Setup")
	print("─────────────────────────────────────────")

	# Test: All nodes should be positioned in circular layout
	var all_in_bounds = true
	for pos in network_overlay.node_positions.values():
		var dist = pos.distance_to(network_overlay.center)
		if dist > network_overlay.bounds_radius * 1.2:  # Allow 20% margin
			all_in_bounds = false
			break
	_assert_true(all_in_bounds, "All nodes within bounds radius")

	# Test: Velocities should start at zero
	var all_zero_velocity = true
	for vel in network_overlay.node_velocities.values():
		if vel != Vector2.ZERO:
			all_zero_velocity = false
			break
	_assert_true(all_zero_velocity, "All velocities start at zero")

	# Test: No two nodes should have exact same position
	var positions_unique = true
	var pos_array = network_overlay.node_positions.values()
	for i in range(pos_array.size()):
		for j in range(i + 1, pos_array.size()):
			if pos_array[i] == pos_array[j]:
				positions_unique = false
				break
	_assert_true(positions_unique, "All node positions unique")

	print("")


func test_node_visual_encoding():
	print("TEST 4: Node Visual Encoding")
	print("─────────────────────────────────────────")

	# Test: Node color should reflect theta
	var seed_node = conspiracy_network.nodes["seed"]
	var color = network_overlay._get_temperature_color(seed_node.theta)
	_assert_true(color.r >= 0.0 and color.r <= 1.0, "Color R component valid")
	_assert_true(color.g >= 0.0 and color.g <= 1.0, "Color G component valid")
	_assert_true(color.b >= 0.0 and color.b <= 1.0, "Color B component valid")

	# Test: High energy node should have larger scale
	var meta_node = conspiracy_network.nodes["meta"]
	var energy_scale = 1.0 + clamp(meta_node.energy / 5.0, 0.0, 1.0) * network_overlay.ENERGY_GLOW_SCALE
	_assert_true(energy_scale > 1.0, "High energy nodes scale larger")

	# Test: Node sprites should have correct children
	var first_sprite = network_overlay.node_sprites.values()[0]
	_assert_true(first_sprite.has_node("Circle"), "Node has Circle sprite")
	_assert_true(first_sprite.has_node("Glow"), "Node has Glow sprite")
	_assert_true(first_sprite.has_node("Label"), "Node has emoji Label")
	_assert_true(first_sprite.has_node("EnergyLabel"), "Node has energy Label")

	print("")


func test_connection_line_encoding():
	print("TEST 5: Connection Line Encoding")
	print("─────────────────────────────────────────")

	# Test: All connection lines should be Line2D
	var all_are_lines = true
	for conn_data in network_overlay.connection_lines:
		if not conn_data["line"] is Line2D:
			all_are_lines = false
			break
	_assert_true(all_are_lines, "All connections are Line2D objects")

	# Test: Connection widths should scale with strength
	var found_varying_widths = false
	var first_width = -1.0
	for conn_data in network_overlay.connection_lines:
		var expected_width = network_overlay.CONNECTION_BASE_WIDTH * conn_data["strength"]
		if first_width < 0:
			first_width = expected_width
		elif abs(expected_width - first_width) > 0.1:
			found_varying_widths = true
			break
	_assert_true(found_varying_widths, "Connection widths vary with strength")

	# Test: Lines should be antialiased
	var first_line = network_overlay.connection_lines[0]["line"]
	_assert_true(first_line.antialiased, "Lines are antialiased")

	print("")


func test_temperature_color_mapping():
	print("TEST 6: Temperature Color Mapping")
	print("─────────────────────────────────────────")

	# Test: theta=0 (north) should be blue-ish
	var cold_color = network_overlay._get_temperature_color(0.0)
	_assert_true(cold_color.b > cold_color.r, "North pole (θ=0) is blue-ish")

	# Test: theta=π/2 (middle) should be white-ish
	var neutral_color = network_overlay._get_temperature_color(PI / 2.0)
	var is_whitish = abs(neutral_color.r - neutral_color.g) < 0.2 and abs(neutral_color.g - neutral_color.b) < 0.2
	_assert_true(is_whitish, "Middle (θ=π/2) is white-ish")

	# Test: theta=π (south) should be red-ish
	var hot_color = network_overlay._get_temperature_color(PI)
	_assert_true(hot_color.r > hot_color.b, "South pole (θ=π) is red-ish")

	# Test: Color gradient is smooth
	var color_0_25 = network_overlay._get_temperature_color(PI * 0.25)
	var color_0_75 = network_overlay._get_temperature_color(PI * 0.75)
	_assert_true(color_0_25 != color_0_75, "Color gradient varies smoothly")

	print("")


func test_energy_flow_direction():
	print("TEST 7: Energy Flow Direction Encoding")
	print("─────────────────────────────────────────")

	# Test: Positive energy delta should give blue color
	var flow_color_positive = network_overlay._get_flow_color(1.5)
	_assert_true(flow_color_positive.b > flow_color_positive.r, "Positive flow is blue")

	# Test: Negative energy delta should give red color
	var flow_color_negative = network_overlay._get_flow_color(-1.5)
	_assert_true(flow_color_negative.r > flow_color_negative.b, "Negative flow is red")

	# Test: Larger delta should give higher alpha
	var small_flow = network_overlay._get_flow_color(0.5)
	var large_flow = network_overlay._get_flow_color(2.0)
	_assert_true(large_flow.a >= small_flow.a, "Larger flow has higher opacity")

	print("")


func test_force_directed_convergence():
	print("TEST 8: Force-Directed Graph Convergence")
	print("─────────────────────────────────────────")

	# Record initial positions
	var initial_positions = {}
	for node_id in network_overlay.node_positions.keys():
		initial_positions[node_id] = network_overlay.node_positions[node_id]

	# Run simulation for 3 seconds
	var frames = 0
	var max_frames = 180  # 3 seconds at 60fps

	while frames < max_frames:
		network_overlay._apply_forces(1.0 / 60.0)
		frames += 1
		await get_tree().process_frame

	# Test: Nodes should have moved from initial positions
	var nodes_moved = 0
	for node_id in network_overlay.node_positions.keys():
		var initial = initial_positions[node_id]
		var current = network_overlay.node_positions[node_id]
		if initial.distance_to(current) > 1.0:
			nodes_moved += 1
	_assert_true(nodes_moved >= 10, "Most nodes moved during simulation (%d/12)" % nodes_moved)

	# Test: Velocities should be small (converging)
	var max_velocity = 0.0
	for vel in network_overlay.node_velocities.values():
		max_velocity = max(max_velocity, vel.length())
	_assert_true(max_velocity < 50.0, "Velocities converging (max: %.1f)" % max_velocity)

	# Test: All nodes should still be within bounds
	var all_in_bounds = true
	for pos in network_overlay.node_positions.values():
		var dist = pos.distance_to(network_overlay.center)
		if dist > network_overlay.bounds_radius * 1.5:
			all_in_bounds = false
			break
	_assert_true(all_in_bounds, "All nodes remain within bounds after simulation")

	# Test: No nodes should overlap significantly
	var min_distance = 999999.0
	var pos_array = network_overlay.node_positions.values()
	for i in range(pos_array.size()):
		for j in range(i + 1, pos_array.size()):
			var dist = pos_array[i].distance_to(pos_array[j])
			min_distance = min(min_distance, dist)
	_assert_true(min_distance > 20.0, "Nodes well-separated (min dist: %.1f)" % min_distance)

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
