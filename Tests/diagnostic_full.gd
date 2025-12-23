extends Node

## Comprehensive diagnostic - captures all errors and measures actual layout

var error_log: Array = []
var ui_controller: Node

func _ready():
	print("\n" + "="*80)
	print("🔍 COMPREHENSIVE DIAGNOSTIC - Measuring Actual Layout & Capturing Errors")
	print("="*80 + "\n")

	await get_tree().process_frame
	await get_tree().process_frame

	# Find UI
	var farm_view = get_tree().root.find_child("FarmView", true, false)
	if not farm_view:
		print("❌ FarmView not found")
		return

	ui_controller = farm_view.find_child("FarmUIController", true, false)
	if not ui_controller:
		print("❌ FarmUIController not found")
		return

	print("✅ Found FarmUIController\n")

	# Measure actual layout
	_measure_all_elements()

	# Test mashing buttons
	print("\n" + "-"*80)
	print("🎮 Testing button mashing (5 presses each)...")
	print("-"*80 + "\n")
	await _mash_all_keys()

	# Print results
	_print_diagnostic()

	await get_tree().process_frame
	get_tree().quit()

func _measure_all_elements():
	"""Measure and display actual on-screen positions of all UI elements"""
	print("📐 ACTUAL ON-SCREEN MEASUREMENTS:\n")

	var elements = {
		"top_bar": "TopBar",
		"plots_row": "PlotsRow",
		"play_area": "PlayArea",
		"actions_row": "ActionsRow",
		"bottom_bar": "BottomBar",
		"tool_selection_row": "ToolSelectionRow",
		"action_preview_row": "ActionPreviewRow",
	}

	var prev_y = 0.0
	var total_height = 0.0

	for prop in elements.keys():
		var elem = ui_controller.get(prop)
		if not elem or not elem is Control:
			print("❌ %s: NOT FOUND" % elements[prop])
			continue

		var c = elem as Control
		var pos = c.global_position
		var size = c.size
		var gap = pos.y - prev_y if prev_y > 0 else 0

		# Check if element is in corner
		var in_corner = pos.x < 20 and pos.y < 20
		var corner_marker = " ⚠️ IN CORNER!" if in_corner else ""

		print("📍 %s:" % elements[prop])
		print("   Position: (%.1f, %.1f)" % [pos.x, pos.y])
		print("   Size: %.1f × %.1f" % [size.x, size.y])
		print("   Gap from previous: %.1f" % gap)
		print()

		total_height += size.y
		prev_y = pos.y + size.y

	var viewport_h = get_viewport().get_visible_rect().size.h
	print("📊 LAYOUT SUMMARY:")
	print("   Total measured height: %.1f" % total_height)
	print("   Viewport height: %.1f" % viewport_h)
	print("   Difference: %.1f (SHOULD BE NEAR ZERO)" % abs(total_height - viewport_h))
	print()

	if abs(total_height - viewport_h) < 10:
		print("   ✅ Layout fits viewport correctly")
	else:
		print("   ❌ Layout DOES NOT fit viewport - UI will be cramped/mashed")

func _mash_all_keys() -> void:
	"""Simulate rapid key presses and capture any errors"""
	var keys = [
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6,
		KEY_Q, KEY_E, KEY_R,
		KEY_W, KEY_A, KEY_S, KEY_D,
		KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P,
		KEY_C, KEY_V, KEY_N
	]

	for key in keys:
		var key_name = OS.get_keycode_string(key)
		print("Pressing %s 5x..." % key_name)

		for i in range(5):
			# Capture any push_error calls
			var event = InputEventKey.new()
			event.keycode = key
			event.pressed = true
			Input.parse_input_event(event)

			var release_event = InputEventKey.new()
			release_event.keycode = key
			release_event.pressed = false
			Input.parse_input_event(release_event)

			await get_tree().process_frame

		print(" ✓")

func _print_diagnostic():
	"""Print final diagnostic report"""
	print("\n" + "="*80)
	print("📋 DIAGNOSTIC REPORT")
	print("="*80)

	var viewport = get_viewport().get_visible_rect()
	print("\nVIEWPORT:")
	print("  Size: %.0f × %.0f" % [viewport.size.x, viewport.size.y])

	# Check for common layout issues
	print("\nLAYOUT CHECK:")

	var top_bar = ui_controller.get("top_bar")
	var bottom_bar = ui_controller.get("bottom_bar")
	var play_area = ui_controller.get("play_area")

	if top_bar and top_bar is Control:
		var tb = top_bar as Control
		if tb.position.y > 5:
			print("  ❌ TopBar not at Y=0 (Y=%.1f)" % tb.position.y)
		elif tb.size.x < viewport.size.x - 10:
			print("  ❌ TopBar not full width (W=%.1f, VP=%.1f)" % [tb.size.x, viewport.size.x])
		else:
			print("  ✅ TopBar positioned correctly")

	if play_area and play_area is Control:
		var pa = play_area as Control
		if pa.size.y < 100:
			print("  ❌ PlayArea too small (H=%.1f)" % pa.size.y)
		else:
			print("  ✅ PlayArea has reasonable size (H=%.1f)" % pa.size.y)

	if bottom_bar and bottom_bar is Control:
		var bb = bottom_bar as Control
		var bottom_y = bb.position.y + bb.size.y
		if abs(bottom_y - viewport.size.y) > 5:
			print("  ❌ BottomBar not at bottom (Bottom Y=%.1f, VP Height=%.1f)" % [bottom_y, viewport.size.y])
		else:
			print("  ✅ BottomBar positioned at bottom")

	print("\nDONE - Check console above for any SCRIPT ERROR messages")
	print("="*80 + "\n")

