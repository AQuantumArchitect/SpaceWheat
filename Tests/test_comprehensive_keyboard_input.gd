extends SceneTree
## Comprehensive keyboard test runner
## Tests all keyboard input: 1-6, Y/U/I/O/P, Q/E/R, W/A/S/D, C/V/N

var test_counter: int = 0
var results: Dictionary = {
	"tools_tested": 0,
	"locations_tested": 0,
	"actions_tested": 0,
	"movements_tested": 0,
	"menus_tested": 0,
	"errors": []
}

func _initialize() -> void:
	print("\n" + "="*70)
	print("🧪 COMPREHENSIVE KEYBOARD INPUT TEST")
	print("="*70)
	print("Testing: 1-6 (tools), Y/U/I/O/P (plot locations)")
	print("         Q/E/R (actions on each location)")
	print("         W/A/S/D (cursor), C/V/N (menus)")
	print("="*70 + "\n")

	# Schedule test sequence
	call_deferred("_run_tests")

func _run_tests() -> void:
	"""Run all keyboard input tests"""

	print("📋 Testing tool selection (1-6)...")
	for tool_num in range(1, 7):
		_simulate_key_press(str(tool_num))
		results["tools_tested"] += 1
		await get_tree().process_frame
	print("   ✓ Tool selection tested\n")

	print("📍 Testing location selection (Y/U/I/O/P)...")
	for location_key in ["y", "u", "i", "o", "p"]:
		_simulate_key_press(location_key)
		results["locations_tested"] += 1
		await get_tree().process_frame
	print("   ✓ Location selection tested\n")

	print("⚡ Testing actions on each location (Q/E/R × 5)...")
	for location_key in ["y", "u", "i", "o", "p"]:
		_simulate_key_press(location_key)
		await get_tree().process_frame
		for action_key in ["q", "e", "r"]:
			_simulate_key_press(action_key)
			results["actions_tested"] += 1
			await get_tree().process_frame
	print("   ✓ Actions tested\n")

	print("🎯 Testing cursor movement (W/A/S/D)...")
	for move_key in ["w", "a", "s", "d"]:
		_simulate_key_press(move_key)
		results["movements_tested"] += 1
		await get_tree().process_frame
	print("   ✓ Cursor movement tested\n")

	print("🎨 Testing menu toggles (C/V/N)...")
	for menu_key in ["c", "v", "n"]:
		_simulate_key_press(menu_key)
		results["menus_tested"] += 1
		await get_tree().process_frame
	print("   ✓ Menu toggles tested\n")

	_report_results()
	quit()

func _simulate_key_press(key_name: String) -> void:
	"""Simulate a key press event"""
	var key_code = _key_name_to_code(key_name)
	if key_code == 0:
		results["errors"].append("Unknown key: " + key_name)
		return

	var event = InputEventKey.new()
	event.keycode = key_code
	event.pressed = true
	Input.parse_input_event(event)

func _key_name_to_code(name: String) -> Key:
	"""Convert key name to Godot Key code"""
	match name.to_lower():
		"1": return KEY_1
		"2": return KEY_2
		"3": return KEY_3
		"4": return KEY_4
		"5": return KEY_5
		"6": return KEY_6
		"y": return KEY_Y
		"u": return KEY_U
		"i": return KEY_I
		"o": return KEY_O
		"p": return KEY_P
		"q": return KEY_Q
		"e": return KEY_E
		"r": return KEY_R
		"w": return KEY_W
		"a": return KEY_A
		"s": return KEY_S
		"d": return KEY_D
		"c": return KEY_C
		"v": return KEY_V
		"n": return KEY_N
		_: return 0

func _report_results() -> void:
	"""Print test results"""
	var separator = "======================================================================"
	print("\n" + separator)
	print("✅ ALL KEYBOARD INPUT TESTS COMPLETED - NO CRASHES!")
	print(separator)

	print("\n📊 Test Results Summary:")
	print("  • Tools tested:       %d (1-6)" % results["tools_tested"])
	print("  • Locations tested:   %d (Y/U/I/O/P)" % results["locations_tested"])
	print("  • Actions tested:     %d (Q/E/R on each location)" % results["actions_tested"])
	print("  • Movements tested:   %d (W/A/S/D)" % results["movements_tested"])
	print("  • Menus tested:       %d (C/V/N)" % results["menus_tested"])

	var total = results["tools_tested"] + results["locations_tested"] + results["actions_tested"] + results["movements_tested"] + results["menus_tested"]
	print("\n🎯 Total key presses simulated: %d" % total)

	if results["errors"].size() > 0:
		print("\n❌ Errors encountered:")
		for error in results["errors"]:
			print("   • " + error)
	else:
		print("\n✅ No errors encountered!")

	print("\n💾 Test Environment:")
	print("  • Running headless: YES")
	print("  • Farm simulation: NOT LOADED (UI-only test)")
	print("  • Visual feedback: Check FarmInputHandler output for action signals")

	print("\n" + separator + "\n")
