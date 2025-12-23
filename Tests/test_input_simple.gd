extends Node

## Simple keyboard input test - just simulate keys and watch for results

var input_handler: Node
var ui_controller: Node

func _ready():
	print("\n=== KEYBOARD INPUT TEST ===\n")

	# Find UI controller
	await get_tree().process_frame
	var farm_view = get_tree().root.find_child("FarmView", true, false)
	if not farm_view:
		print("ERROR: FarmView not found")
		return

	ui_controller = farm_view.find_child("FarmUIController", true, false)
	if not ui_controller:
		print("ERROR: FarmUIController not found")
		return

	input_handler = ui_controller.get("input_handler")
	if not input_handler:
		print("ERROR: FarmInputHandler not found")
		return

	print("OK: Found all components\n")
	print("TESTING KEY PRESSES:\n")

	# Test tool selection 1-6
	print("--- Tool Selection (1-6) ---")
	for i in range(1, 7):
		var key = KEY_1 + (i - 1)
		print("Pressing " + str(i) + "...")
		_simulate_key(key)
		await get_tree().process_frame
		var current_tool = input_handler.get("current_tool")
		print("  Current tool: " + str(current_tool))

	print("\n--- Location Selection (Y,U,I,O,P) ---")
	var loc_keys = [KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P]
	for key in loc_keys:
		print("Pressing " + OS.get_keycode_string(key) + "...")
		_simulate_key(key)
		await get_tree().process_frame
		var pos = input_handler.get("current_selection")
		print("  Position: " + str(pos))

	print("\n--- Cursor Movement (W,A,S,D) ---")
	var movement_keys = [KEY_W, KEY_A, KEY_S, KEY_D]
	var move_labels = ["W (up)", "A (left)", "S (down)", "D (right)"]
	for i in range(movement_keys.size()):
		var key = movement_keys[i]
		print("Pressing " + move_labels[i] + "...")
		_simulate_key(key)
		await get_tree().process_frame
		var pos = input_handler.get("current_selection")
		print("  Position: " + str(pos))

	print("\n--- Overlay Toggles (C,V,N) ---")
	var overlay_keys = [KEY_C, KEY_V, KEY_N]
	var overlay_labels = ["C (contracts)", "V (vocabulary)", "N (network)"]
	for i in range(overlay_keys.size()):
		var key = overlay_keys[i]
		print("Pressing " + overlay_labels[i] + "...")
		_simulate_key(key)
		await get_tree().process_frame

	print("\nTEST COMPLETE\n")
	get_tree().quit()

func _simulate_key(keycode: int):
	var event = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)

