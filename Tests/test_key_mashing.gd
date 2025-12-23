extends Node

## Simulate rapid key mashing to catch all errors

func _ready():
	print("\n=== KEY MASHING TEST ===\n")
	print("Simulating rapid key presses to find errors...\n")

	await get_tree().process_frame

	var keys = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_Q, KEY_E, KEY_R, KEY_W, KEY_A, KEY_S, KEY_D, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P, KEY_C, KEY_V, KEY_N]

	# Mash each key 5 times rapidly
	for key in keys:
		for i in range(5):
			print("Pressing " + OS.get_keycode_string(key) + "...")
			var event = InputEventKey.new()
			event.keycode = key
			event.pressed = true
			Input.parse_input_event(event)

			# Also send key release
			var release_event = InputEventKey.new()
			release_event.keycode = key
			release_event.pressed = false
			Input.parse_input_event(release_event)

			await get_tree().process_frame

	print("\nTest complete!\n")
	get_tree().quit()
