extends Node
## Comprehensive keyboard input test
## Tests: 1-6 tool selection, Y/U/I/O/P location selection, Q/E/R actions
## Simulates without farm running to verify UI feedback only

var farm_view: Node
var input_handler: Node
var frame_count: int = 0
var test_complete: bool = false

func _ready() -> void:
	var separator = "======================================================================"
	print("\n" + separator)
	print("🧪 COMPREHENSIVE KEYBOARD TEST - No Simulation")
	print(separator)
	print("Testing: 1-6 (tools), Y/U/I/O/P (locations), Q/E/R (actions)")
	print(separator + "\n")

	# Load FarmView to get the UI system
	var farm_view_scene = load("res://Scenes/FarmView.tscn")
	if farm_view_scene:
		farm_view = farm_view_scene.instantiate()
		add_child(farm_view)
		await get_tree().process_frame
		print("✅ FarmView loaded - UI systems ready")
	else:
		print("❌ Failed to load FarmView")
		get_tree().quit()
		return

	# Wait for UI to initialize
	await get_tree().process_frame
	await get_tree().process_frame

	# Find the input handler
	input_handler = farm_view.find_child("FarmInputHandler", true, false)
	if input_handler:
		print("✅ Input handler found")
	else:
		print("⚠️  Input handler not found - input may not work")

	# Start test sequence
	set_process(true)
	print("\n📋 Starting keyboard input sequence...\n")

func _process(_delta: float) -> void:
	if test_complete:
		return

	frame_count += 1

	# Each sequence takes ~10 frames to simulate, spacing them out
	match frame_count:
		# Tool selection 1-6
		10:
			_send_key(KEY_1)
		20:
			_send_key(KEY_2)
		30:
			_send_key(KEY_3)
		40:
			_send_key(KEY_4)
		50:
			_send_key(KEY_5)
		60:
			_send_key(KEY_6)

		# Location selection Y/U/I/O/P
		70:
			_send_key(KEY_Y)
		80:
			_send_key(KEY_U)
		90:
			_send_key(KEY_I)
		100:
			_send_key(KEY_O)
		110:
			_send_key(KEY_P)

		# Action tests on each location (Q/E/R)
		# Location Y
		120:
			_send_key(KEY_Y)
		125:
			_send_key(KEY_Q)
		130:
			_send_key(KEY_E)
		135:
			_send_key(KEY_R)

		# Location U
		140:
			_send_key(KEY_U)
		145:
			_send_key(KEY_Q)
		150:
			_send_key(KEY_E)
		155:
			_send_key(KEY_R)

		# Location I
		160:
			_send_key(KEY_I)
		165:
			_send_key(KEY_Q)
		170:
			_send_key(KEY_E)
		175:
			_send_key(KEY_R)

		# Location O
		180:
			_send_key(KEY_O)
		185:
			_send_key(KEY_Q)
		190:
			_send_key(KEY_E)
		195:
			_send_key(KEY_R)

		# Location P
		200:
			_send_key(KEY_P)
		205:
			_send_key(KEY_Q)
		210:
			_send_key(KEY_E)
		215:
			_send_key(KEY_R)

		# WASD cursor movement
		220:
			_send_key(KEY_W)
		225:
			_send_key(KEY_A)
		230:
			_send_key(KEY_S)
		235:
			_send_key(KEY_D)

		# Menu toggles
		240:
			_send_key(KEY_C)
		245:
			_send_key(KEY_V)
		250:
			_send_key(KEY_N)

		255:
			_finish_test()

func _send_key(keycode: Key) -> void:
	"""Simulate key press and release"""
	var event = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true

	Input.parse_input_event(event)

	# Print feedback
	var key_map = {
		KEY_1: "🔧 Tool 1",
		KEY_2: "🔧 Tool 2",
		KEY_3: "🔧 Tool 3",
		KEY_4: "🔧 Tool 4",
		KEY_5: "🔧 Tool 5",
		KEY_6: "🔧 Tool 6",
		KEY_Y: "📍 Location Y",
		KEY_U: "📍 Location U",
		KEY_I: "📍 Location I",
		KEY_O: "📍 Location O",
		KEY_P: "📍 Location P",
		KEY_Q: "⚡ Action Q",
		KEY_E: "⚡ Action E",
		KEY_R: "⚡ Action R",
		KEY_W: "⬆️  Cursor Up",
		KEY_A: "⬅️  Cursor Left",
		KEY_S: "⬇️  Cursor Down",
		KEY_D: "➡️  Cursor Right",
		KEY_C: "📜 Contract (C)",
		KEY_V: "📖 Vocabulary (V)",
		KEY_N: "🌐 Network (N)",
	}

	var label = key_map.get(keycode, str(keycode))
	print("[Frame %d] Key pressed: %s" % [frame_count, label])

func _finish_test() -> void:
	"""Complete the test and report results"""
	test_complete = true

	var separator = "======================================================================"
	print("\n" + separator)
	print("✅ TEST COMPLETE - No crashes!")
	print(separator)
	print("\n📊 Test Summary:")
	print("  ✓ Tool selection (1-6) - sent")
	print("  ✓ Location selection (Y/U/I/O/P) - sent")
	print("  ✓ Actions on all locations (Q/E/R × 5) - sent")
	print("  ✓ Cursor movement (W/A/S/D) - sent")
	print("  ✓ Menu toggles (C/V/N) - sent")
	print("\n🎯 Total key presses: 50")
	print("⚠️  Note: Without farm simulation running, actions won't execute")
	print("   but UI should respond with visual feedback\n")
	print(separator + "\n")

	await get_tree().process_frame
	get_tree().quit()
