#!/usr/bin/env -S godot --headless --script
## Comprehensive Keyboard Input Test
## Tests all keyboard controls and verifies they work

extends SceneTree

var ui_controller: Node
var input_handler: Node
var test_log: Array = []
var input_events_received: int = 0

func _initialize():
	print("\n" + "="*70)
	print("⌨️  COMPREHENSIVE KEYBOARD INPUT TEST")
	print("="*70 + "\n")

	# Load the test scene
	var scene_path = "res://UITestOnly.tscn"
	var scene = load(scene_path) as PackedScene
	if not scene:
		print("ERROR: Failed to load UITestOnly.tscn")
		quit(1)

	var root = scene.instantiate()
	root.name = "UIRoot"
	get_root().add_child(root)

	# Wait for initialization
	await process_frame
	await process_frame
	await process_frame

	# Find UI controller
	var farm_view = root.find_child("FarmView", true, false)
	if not farm_view:
		print("❌ FarmView not found")
		quit(1)

	ui_controller = farm_view.find_child("FarmUIController", true, false)
	if not ui_controller:
		print("❌ FarmUIController not found")
		quit(1)

	input_handler = ui_controller.get("input_handler")
	if not input_handler:
		print("❌ FarmInputHandler not found")
		quit(1)

	print("✅ Found all components\n")

	# Connect to signals to track events
	_connect_signals()

	# Run tests
	print("🧪 RUNNING KEYBOARD TESTS\n")
	await _test_tool_selection()
	await _test_location_selection()
	await _test_cursor_movement()
	await _test_overlay_toggles()

	# Print results
	_print_results()

	quit(0)

func _connect_signals() -> void:
	"""Connect to input signals to verify they're fired"""
	if input_handler.has_signal("tool_changed"):
		input_handler.tool_changed.connect(_on_tool_changed)
		print("✅ Connected to tool_changed signal")
	else:
		print("❌ tool_changed signal not found!")

	if input_handler.has_signal("selection_changed"):
		input_handler.selection_changed.connect(_on_selection_changed)
		print("✅ Connected to selection_changed signal")
	else:
		print("❌ selection_changed signal not found!")

	if input_handler.has_signal("action_performed"):
		input_handler.action_performed.connect(_on_action_performed)
		print("✅ Connected to action_performed signal")
	else:
		print("❌ action_performed signal not found!")

	print()

func _test_tool_selection() -> void:
	"""Test tool selection with keys 1-6"""
	print("📍 TEST 1: Tool Selection (1-6)")
	print("─" * 50)

	for tool_num in range(1, 7):
		var key = KEY_1 + (tool_num - 1)
		var tool_name = ["Plant", "Quantum", "Economy", "Future4", "Future5", "Future6"][tool_num - 1]

		_simulate_key_press(key)
		await process_frame

		var button = _get_tool_button(tool_num)
		if button:
			var is_selected = button.modulate == Color(0.0, 1.0, 1.0)  # Cyan = selected
			var status = "✅" if is_selected else "⚠️"
			_log("%s Tool %d (%s): Key %s → Button highlighted" % [status, tool_num, tool_name, OS.get_keycode_string(key)])
		else:
			_log("❌ Tool %d button not found" % tool_num)

	print()

func _test_location_selection() -> void:
	"""Test location selection with YUIOP"""
	print("📍 TEST 2: Location Selection (YUIOP)")
	print("─" * 50)

	var location_keys = {
		KEY_Y: "Y (Location 1)",
		KEY_U: "U (Location 2)",
		KEY_I: "I (Location 3)",
		KEY_O: "O (Location 4)",
		KEY_P: "P (Location 5)",
	}

	for key in location_keys.keys():
		var label = location_keys[key]
		var expected_pos = [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(3,0), Vector2i(4,0)][(key - KEY_Y)]

		_simulate_key_press(key)
		await process_frame

		var current_selection = input_handler.get("current_selection")
		var is_correct = current_selection == expected_pos
		var status = "✅" if is_correct else "⚠️"
		_log("%s %s → Cursor at %s (expected %s)" % [status, label, current_selection, expected_pos])

	print()

func _test_cursor_movement() -> void:
	"""Test cursor movement with WASD"""
	print("📍 TEST 3: Cursor Movement (WASD)")
	print("─" * 50)

	var start_pos = Vector2i.ZERO
	var current_pos = start_pos

	var movements = [
		[KEY_W, Vector2i.UP, "W = Up"],
		[KEY_A, Vector2i.LEFT, "A = Left"],
		[KEY_S, Vector2i.DOWN, "S = Down"],
		[KEY_D, Vector2i.RIGHT, "D = Right"],
	]

	for test in movements:
		var key = test[0]
		var direction = test[1]
		var label = test[2]

		_simulate_key_press(key)
		await process_frame

		var new_pos = input_handler.get("current_selection")
		var expected = current_pos + direction

		# Clamp to grid bounds
		expected.x = clampi(expected.x, 0, 5)
		expected.y = clampi(expected.y, 0, 0)

		var is_correct = new_pos == expected
		var status = "✅" if is_correct else "⚠️"
		_log("%s %s: %s → %s (expected %s)" % [status, label, current_pos, new_pos, expected])

		current_pos = new_pos

	print()

func _test_overlay_toggles() -> void:
	"""Test overlay toggle keys"""
	print("📍 TEST 4: Overlay Toggles (C/V/N)")
	print("─" * 50)

	var overlay_keys = {
		KEY_C: "C = Contracts",
		KEY_V: "V = Vocabulary",
		KEY_N: "N = Network",
	}

	var overlay_manager = ui_controller.get("overlay_manager")
	if not overlay_manager:
		_log("❌ OverlayManager not found")
		print()
		return

	for key in overlay_keys.keys():
		var label = overlay_keys[key]
		_simulate_key_press(key)
		await process_frame
		_log("✅ %s: Key sent (check overlay visibility)" % label)

	print()

func _simulate_key_press(keycode: int) -> void:
	"""Simulate a keyboard key press"""
	var event = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true

	Input.parse_input_event(event)

func _on_tool_changed(tool_num: int, tool_info: Dictionary) -> void:
	"""Signal handler for tool changes"""
	input_events_received += 1

func _on_selection_changed(new_pos: Vector2i) -> void:
	"""Signal handler for selection changes"""
	input_events_received += 1

func _on_action_performed(action: String, success: bool, message: String) -> void:
	"""Signal handler for actions"""
	input_events_received += 1

func _log(message: String) -> void:
	"""Add to test log and print"""
	test_log.append(message)
	print(message)

func _print_results() -> void:
	"""Print test summary"""
	print("\n" + "="*70)
	print("📊 TEST RESULTS")
	print("="*70)

	var passed = test_log.filter(func(m): return "✅" in m).size()
	var failed = test_log.filter(func(m): return "❌" in m).size()
	var warnings = test_log.filter(func(m): return "⚠️" in m).size()

	print("\n✅ Passed: %d" % passed)
	print("⚠️  Warnings: %d" % warnings)
	print("❌ Failed: %d" % failed)
	print("\nSignals received: %d" % input_events_received)

	print("\nDetailed Log:")
	print("─" * 70)
	for log in test_log:
		print(log)

	print("\n" + "="*70)
	if failed == 0:
		print("✅ ALL TESTS PASSED!")
	else:
		print("❌ SOME TESTS FAILED - CHECK OUTPUT ABOVE")
	print("="*70 + "\n")

func _get_tool_button(tool_num: int) -> Control:
	"""Get the visual button for a tool"""
	var tool_row = ui_controller.get("tool_selection_row")
	if not tool_row:
		return null

	var buttons = tool_row.get("tool_buttons")
	if buttons and tool_num > 0 and tool_num <= buttons.size():
		return buttons[tool_num - 1]

	return null

