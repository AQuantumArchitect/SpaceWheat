extends Node

## End-to-End Bubble Tap Test
## Verifies the complete flow: plant → bubble appears → click bubble → measure → click → harvest

var test_results: Dictionary = {
	"initialization": false,
	"plant_creates_bubble": false,
	"tap_measures_plot": false,
	"tap_harvests_plot": false,
	"bubble_removed_on_harvest": false
}

func _ready() -> void:
	print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("END-TO-END BUBBLE TAP TEST")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

	await get_tree().create_timer(2.0).timeout
	await run_test()
	print_results()
	get_tree().quit()


func run_test() -> void:
	# Get references
	var scene = get_tree().current_scene
	var farm_view = scene.get_node_or_null("FarmView")

	if not farm_view:
		print("❌ FAILED: Could not find FarmView")
		return

	var farm = farm_view.farm
	var quantum_viz = farm_view.quantum_viz

	if not farm or not quantum_viz:
		print("❌ FAILED: Farm or quantum_viz not available")
		return

	test_results["initialization"] = true
	print("✓ Initialization successful\n")

	# Test position
	var test_plot = Vector2i(2, 0)

	print("━━━ TEST 1: Plant wheat and verify bubble creation ━━━")

	# Get initial state
	var plot_before = farm.grid.get_plot(test_plot)
	var bubbles_before = quantum_viz.graph.quantum_nodes.size()

	print("  Before plant:")
	print("    Plot planted: %s" % (plot_before.is_planted if plot_before else "no plot"))
	print("    Bubble count: %d" % bubbles_before)

	# Plant wheat
	var positions: Array[Vector2i] = [test_plot]
	farm.batch_plant(positions, "wheat")
	await get_tree().create_timer(0.5).timeout

	# Verify plot state
	var plot_after = farm.grid.get_plot(test_plot)
	var bubbles_after = quantum_viz.graph.quantum_nodes.size()

	print("  After plant:")
	print("    Plot planted: %s" % plot_after.is_planted)
	print("    Plot measured: %s" % plot_after.is_measured)
	print("    Bubble count: %d" % bubbles_after)

	if plot_after.is_planted and bubbles_after > bubbles_before:
		test_results["plant_creates_bubble"] = true
		print("  ✓ Plant created bubble\n")
	else:
		print("  ❌ Plant did NOT create bubble\n")
		return

	# Get the bubble
	var bubble = null
	for node in quantum_viz.graph.quantum_nodes:
		if node.grid_position == test_plot:
			bubble = node
			break

	if not bubble:
		print("  ❌ Could not find bubble at grid position %s\n" % test_plot)
		return

	print("━━━ TEST 2: Click bubble to MEASURE plot ━━━")

	# Click the bubble (press + release)
	var bubble_pos = bubble.position
	print("  Clicking at screen position: %s" % bubble_pos)

	await inject_click(bubble_pos)
	await get_tree().create_timer(0.5).timeout

	# Verify plot was measured
	plot_after = farm.grid.get_plot(test_plot)

	print("  After click:")
	print("    Plot planted: %s" % plot_after.is_planted)
	print("    Plot measured: %s" % plot_after.is_measured)

	if plot_after.is_measured:
		test_results["tap_measures_plot"] = true
		print("  ✓ Tap measured the plot\n")
	else:
		print("  ❌ Tap did NOT measure the plot")
		print("  Checking handler was called...")
		# The handler should have printed debug output
		print("")
		return

	print("━━━ TEST 3: Click bubble again to HARVEST plot ━━━")

	# Click again to harvest
	await inject_click(bubble_pos)
	await get_tree().create_timer(0.5).timeout

	# Verify plot was harvested
	plot_after = farm.grid.get_plot(test_plot)
	var bubbles_final = quantum_viz.graph.quantum_nodes.size()

	print("  After second click:")
	print("    Plot planted: %s" % plot_after.is_planted)
	print("    Plot measured: %s" % plot_after.is_measured)
	print("    Bubble count: %d" % bubbles_final)

	if not plot_after.is_planted:
		test_results["tap_harvests_plot"] = true
		print("  ✓ Tap harvested the plot")
	else:
		print("  ❌ Tap did NOT harvest the plot")

	if bubbles_final < bubbles_after:
		test_results["bubble_removed_on_harvest"] = true
		print("  ✓ Bubble removed on harvest\n")
	else:
		print("  ❌ Bubble NOT removed on harvest\n")


func inject_click(pos: Vector2) -> void:
	"""Inject mouse click (press + release) at position"""
	# Press
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = pos
	press.global_position = pos

	Input.parse_input_event(press)
	get_viewport().push_input(press)

	await get_tree().create_timer(0.05).timeout

	# Release
	var release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = pos
	release.global_position = pos

	Input.parse_input_event(release)
	get_viewport().push_input(release)


func print_results() -> void:
	print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("TEST RESULTS")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

	var all_passed = true

	for test_name in test_results.keys():
		var passed = test_results[test_name]
		var symbol = "✓" if passed else "✗"
		var status = "PASS" if passed else "FAIL"
		print("  %s %-30s %s" % [symbol, test_name + ":", status])
		if not passed:
			all_passed = false

	print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	if all_passed:
		print("OVERALL: ✓ ALL TESTS PASSED")
	else:
		print("OVERALL: ✗ SOME TESTS FAILED")

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

	# Diagnostic info if tests failed
	if not all_passed:
		print("DIAGNOSTIC INFO:")

		if not test_results["plant_creates_bubble"]:
			print("  - plot_planted signal may not be connected")
			print("  - BathQuantumViz.request_plot_bubble() may not be working")

		if not test_results["tap_measures_plot"]:
			print("  - Input routing may be broken")
			print("  - farm.measure_plot() may not be working")
			print("  - Check if handler was called (look for 🎯🎯🎯 in output)")

		if not test_results["tap_harvests_plot"]:
			print("  - farm.harvest_plot() may not be working")
			print("  - Plot state may not be updating correctly")

		if not test_results["bubble_removed_on_harvest"]:
			print("  - plot_harvested signal may not be connected")
			print("  - BathQuantumViz._on_plot_harvested() may not be working")

		print("")
