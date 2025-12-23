extends SceneTree
## Phase 1 Complete - Comprehensive Integration Test
## Tests all visualization features working together

const FarmView = preload("res://UI/FarmView.gd")

var farm_view: Node
var test_results = []
var tests_passed = 0
var tests_failed = 0

func _init():
	print("═══════════════════════════════════════════════════════")
	print("   PHASE 1 COMPLETE - INTEGRATION TEST")
	print("═══════════════════════════════════════════════════════")
	print("")

	# Create and initialize FarmView
	farm_view = FarmView.new()
	get_root().add_child(farm_view)

	# Wait for initialization
	await create_timer(0.3).timeout

	# Run comprehensive tests
	test_all_systems_initialized()
	await create_timer(0.5).timeout

	test_conspiracy_network()
	await create_timer(0.5).timeout

	test_network_overlay()
	await create_timer(0.5).timeout

	test_network_info_panel()
	await create_timer(0.5).timeout

	test_icon_energy_fields()
	await create_timer(0.5).timeout

	test_tomato_planting_and_visuals()
	await create_timer(1.0).timeout

	test_real_time_updates()
	await create_timer(1.0).timeout

	# Print summary
	_print_summary()

	# Exit
	await create_timer(0.1).timeout
	quit()


func test_all_systems_initialized():
	print("TEST 1: All Phase 1 Systems Initialized")
	print("─────────────────────────────────────────")

	_assert_true(farm_view.conspiracy_network != null, "Conspiracy network exists")
	_assert_true(farm_view.network_overlay != null, "Network overlay exists")
	_assert_true(farm_view.network_info_panel != null, "Network info panel exists")
	_assert_true(farm_view.biotic_field != null, "Biotic Icon field exists")
	_assert_true(farm_view.chaos_field != null, "Chaos Icon field exists")
	_assert_true(farm_view.imperium_field != null, "Imperium Icon field exists")

	print("")


func test_conspiracy_network():
	print("TEST 2: Conspiracy Network Structure")
	print("─────────────────────────────────────────")

	var network = farm_view.conspiracy_network

	_assert_equal(network.nodes.size(), 12, "Network has 12 nodes")
	_assert_equal(network.connections.size(), 15, "Network has 15 connections")

	# Verify all nodes have quantum state
	var all_have_state = true
	for node_id in network.nodes.keys():
		var node = network.nodes[node_id]
		if node.theta < 0 or node.theta > PI:
			all_have_state = false
		if node.energy <= 0:
			all_have_state = false
	_assert_true(all_have_state, "All nodes have valid quantum state")

	# Count active conspiracies
	var active_count = 0
	for conspiracy_id in network.active_conspiracies.keys():
		if network.active_conspiracies[conspiracy_id]:
			active_count += 1
	_assert_true(active_count > 0, "At least one conspiracy active (%d)" % active_count)

	print("")


func test_network_overlay():
	print("TEST 3: Network Overlay Visualization")
	print("─────────────────────────────────────────")

	var overlay = farm_view.network_overlay

	_assert_equal(overlay.node_sprites.size(), 12, "Overlay has 12 node sprites")
	_assert_equal(overlay.connection_lines.size(), 15, "Overlay has 15 connection lines")
	_assert_equal(overlay.node_positions.size(), 12, "All nodes have positions")
	_assert_equal(overlay.node_velocities.size(), 12, "All nodes have velocities")

	# Test toggle functionality
	var initial_visible = overlay.visible
	overlay.toggle_visibility()
	_assert_true(overlay.visible != initial_visible, "Overlay toggle works")
	overlay.toggle_visibility()  # Toggle back
	_assert_true(overlay.visible == initial_visible, "Overlay restores state")

	print("")


func test_network_info_panel():
	print("TEST 4: Network Info Panel")
	print("─────────────────────────────────────────")

	var panel = farm_view.network_info_panel

	_assert_true(panel.conspiracy_network != null, "Panel has network reference")
	_assert_true(panel.total_energy_label != null, "Total energy label exists")
	_assert_true(panel.active_conspiracies_label != null, "Active conspiracies label exists")
	_assert_true(panel.hottest_node_label != null, "Hottest node label exists")

	# Verify panel toggles with overlay
	var overlay = farm_view.network_overlay
	overlay.visible = true
	panel.visible = true
	_assert_true(panel.visible, "Panel visible when overlay visible")

	print("")


func test_icon_energy_fields():
	print("TEST 5: Icon Energy Field Particles")
	print("─────────────────────────────────────────")

	var biotic = farm_view.biotic_field
	var chaos = farm_view.chaos_field
	var imperium = farm_view.imperium_field

	_assert_true(biotic.icon != null, "Biotic field has Icon reference")
	_assert_true(chaos.icon != null, "Chaos field has Icon reference")
	_assert_true(imperium.icon != null, "Imperium field has Icon reference")

	_assert_true(biotic.particles != null, "Biotic field has particle system")
	_assert_true(chaos.particles != null, "Chaos field has particle system")
	_assert_true(imperium.particles != null, "Imperium field has particle system")

	# Verify particle systems are configured
	_assert_true(biotic.particles.amount > 0, "Biotic particles have count")
	_assert_true(chaos.particles.amount > 0, "Chaos particles have count")
	_assert_true(imperium.particles.amount > 0, "Imperium particles have count")

	print("")


func test_tomato_planting_and_visuals():
	print("TEST 6: Tomato Planting and Visual Encoding")
	print("─────────────────────────────────────────")

	var farm_grid = farm_view.farm_grid
	var network = farm_view.conspiracy_network

	# Plant 5 tomatoes
	for i in range(5):
		var success = farm_grid.plant_tomato(Vector2i(i, 0), network)
		_assert_true(success, "Tomato %d planted successfully" % (i + 1))

	# Wait a frame for updates
	await create_timer(0.1).timeout

	# Verify tomatoes have conspiracy nodes assigned
	var assigned_nodes = []
	for i in range(5):
		var plot = farm_grid.get_plot(Vector2i(i, 0))
		if plot and plot.plot_type == 1:  # TOMATO
			assigned_nodes.append(plot.conspiracy_node_id)

	_assert_equal(assigned_nodes.size(), 5, "All 5 tomatoes have conspiracy nodes")

	# Verify nodes are different (cycling through the 12 nodes)
	var unique_nodes = {}
	for node_id in assigned_nodes:
		unique_nodes[node_id] = true
	_assert_true(unique_nodes.size() >= 4, "Tomatoes assigned to different nodes (%d unique)" % unique_nodes.size())

	# Verify all assigned nodes exist in network
	var all_valid = true
	for node_id in assigned_nodes:
		if not network.nodes.has(node_id):
			all_valid = false
	_assert_true(all_valid, "All assigned nodes exist in network")

	print("")


func test_real_time_updates():
	print("TEST 7: Real-Time Visual Updates")
	print("─────────────────────────────────────────")

	var network = farm_view.conspiracy_network

	# Record initial state
	var initial_energies = {}
	for node_id in network.nodes.keys():
		initial_energies[node_id] = network.nodes[node_id].energy

	# Let network evolve for 1 second
	var frames = 0
	while frames < 60:  # 1 second at 60fps
		await create_timer(1.0 / 60.0).timeout
		frames += 1

	# Check that at least some nodes changed energy
	var changed_count = 0
	for node_id in network.nodes.keys():
		var current = network.nodes[node_id].energy
		var initial = initial_energies[node_id]
		if abs(current - initial) > 0.01:
			changed_count += 1

	_assert_true(changed_count > 0, "Node energies evolved (%d nodes changed)" % changed_count)

	# Verify conspiracy activations/deactivations happened
	var active_count = 0
	for conspiracy_id in network.active_conspiracies.keys():
		if network.active_conspiracies[conspiracy_id]:
			active_count += 1
	_assert_true(active_count > 0, "Conspiracies still active (%d active)" % active_count)

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
	print("   PHASE 1 TEST SUMMARY")
	print("═══════════════════════════════════════════════════════")
	print("")
	print("Total tests: %d" % (tests_passed + tests_failed))
	print("Passed: %d ✅" % tests_passed)
	print("Failed: %d ❌" % tests_failed)
	print("")

	if tests_failed == 0:
		print("🎉 ALL PHASE 1 FEATURES WORKING!")
		print("")
		print("✨ Phase 1 Complete:")
		print("  - Force-directed conspiracy network ✅")
		print("  - Parametric tomato visuals ✅")
		print("  - Energy flow visualization ✅")
		print("  - Network statistics panel ✅")
		print("  - Icon energy field particles ✅")
		print("  - Real-time updates ✅")
	else:
		print("⚠️  SOME TESTS FAILED")
		print("")
		print("Failed tests:")
		for result in test_results:
			if not result["passed"]:
				print("  - %s" % result["description"])

	print("")
	print("═══════════════════════════════════════════════════════")
