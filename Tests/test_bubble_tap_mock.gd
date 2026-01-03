extends Node

## Mock Bubble Tap Test
## Uses keyboard to plant, then directly calls tap handler to verify flow

func _ready() -> void:
	print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("MOCK BUBBLE TAP TEST (Keyboard + Direct Handler Call)")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

	await get_tree().create_timer(2.5).timeout
	await run_test()
	get_tree().quit()


func run_test() -> void:
	var scene = get_tree().current_scene
	var farm_view = scene.get_node_or_null("FarmView")

	if not farm_view:
		print("❌ No FarmView")
		return

	var farm = farm_view.get_farm()
	var quantum_viz = farm_view.quantum_viz

	if not farm or not quantum_viz:
		print("❌ Farm/quantum_viz missing")
		return

	print("✓ Setup complete\n")

	var test_pos = Vector2i(2, 0)

	# TEST 1: Plant wheat directly (bypass keyboard)
	print("━━━ TEST 1: Plant wheat ━━━")
	var positions: Array[Vector2i] = [test_pos]
	farm.batch_plant(positions, "wheat")
	await get_tree().create_timer(0.5).timeout

	var plot = farm.grid.get_plot(test_pos)
	var bubbles = quantum_viz.graph.quantum_nodes.size()

	print("  Plot planted: %s" % plot.is_planted)
	print("  Bubbles: %d" % bubbles)

	if not plot.is_planted or bubbles == 0:
		print("  ❌ FAILED: Plant didn't create bubble\n")
		return

	print("  ✓ Wheat planted, bubble created\n")

	# TEST 2: Call tap handler directly (bypass mouse routing)
	print("━━━ TEST 2: Tap handler → Measure ━━━")
	print("  Calling _on_quantum_node_clicked(%s, 1)..." % test_pos)

	farm_view._on_quantum_node_clicked(test_pos, 1)
	await get_tree().create_timer(0.3).timeout

	plot = farm.grid.get_plot(test_pos)
	print("  Plot planted: %s" % plot.is_planted)
	print("  Plot measured: %s" % plot.has_been_measured)

	if not plot.has_been_measured:
		print("  ❌ FAILED: Plot NOT measured\n")
		return

	print("  ✓ Measure worked!\n")

	# TEST 3: Tap again → Harvest
	print("━━━ TEST 3: Tap handler → Harvest ━━━")
	print("  Calling _on_quantum_node_clicked(%s, 1)..." % test_pos)

	farm_view._on_quantum_node_clicked(test_pos, 1)
	await get_tree().create_timer(0.3).timeout

	plot = farm.grid.get_plot(test_pos)
	bubbles = quantum_viz.graph.quantum_nodes.size()

	print("  Plot planted: %s" % plot.is_planted)
	print("  Plot measured: %s" % plot.has_been_measured)
	print("  Bubbles: %d" % bubbles)

	if plot.is_planted:
		print("  ❌ FAILED: Plot still planted (not harvested)\n")
		return

	print("  ✓ Harvest worked!\n")

	if bubbles == 0:
		print("  ✓ Bubble removed on harvest\n")
	else:
		print("  ⚠️  Bubble NOT removed (count=%d)\n" % bubbles)

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("✅ ALL CORE TESTS PASSED!")
	print("   Plant → Measure → Harvest flow works!")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")


func inject_key(keycode: int) -> void:
	"""Inject keyboard event"""
	var event = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)

	await get_tree().create_timer(0.05).timeout

	event = InputEventKey.new()
	event.keycode = keycode
	event.pressed = false
	Input.parse_input_event(event)
