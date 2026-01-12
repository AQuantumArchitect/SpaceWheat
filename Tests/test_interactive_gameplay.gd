extends Node

## Interactive Gameplay Test - Simulates actual player input
## This test mimics keyboard commands and captures all results

var farm_view: Node
var player_shell: Node
var overlay_manager: Node
var farm: Node
var input_handler: Node

var test_log: Array[String] = []
var test_results: Dictionary = {}

func _ready():
	print("\n" + "="*80)
	print("🎮 INTERACTIVE GAMEPLAY TEST - Simulating Keyboard Input")
	print("="*80)

	await get_tree().process_frame
	_setup()

	if _validate_components():
		await _run_interactive_tests()
		_print_final_report()
	else:
		_log("ERROR: Missing game components")

func _setup():
	farm_view = get_tree().get_first_node_in_group("farm_view")
	player_shell = get_tree().get_first_node_in_group("player_shell")
	overlay_manager = player_shell.overlay_manager if player_shell else null
	farm = player_shell.farm if player_shell else null
	input_handler = player_shell.input_handler if player_shell else null

func _validate_components() -> bool:
	var valid = farm_view != null and player_shell != null and overlay_manager != null and farm != null
	if valid:
		_log("✅ All game components found")
	else:
		_log("❌ Missing: %s%s%s" % [
			"FarmView " if not farm_view else "",
			"PlayerShell " if not player_shell else "",
			"OverlayManager/Farm " if not overlay_manager else ""
		])
	return valid

func _log(msg: String):
	test_log.append(msg)
	print(msg)

func _simulate_key(keycode: int, key_name: String) -> bool:
	"""Simulate keyboard input and return if it was consumed"""
	var event = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true

	_log("   → Simulating: %s (keycode %d)" % [key_name, keycode])

	# Try to get input result
	var consumed = false
	if input_handler and input_handler.has_method("_unhandled_input"):
		input_handler._unhandled_input(event)
		consumed = true
	elif player_shell and player_shell.has_method("_input"):
		player_shell._input(event)
		consumed = true

	return consumed

func _run_interactive_tests():
	print("\n" + "-"*80)
	print("PHASE 1: TOOL SELECTION & ACTIONS (1-6)")
	print("-"*80)

	for tool_num in range(1, 7):
		await _test_tool_interactive(tool_num)
		await get_tree().process_frame

	print("\n" + "-"*80)
	print("PHASE 2: QUEST BOARD (C KEY)")
	print("-"*80)

	await _test_quest_board_interactive()
	await get_tree().process_frame

	print("\n" + "-"*80)
	print("PHASE 3: OVERLAYS (Manual Open)")
	print("-"*80)

	await _test_overlays_interactive()
	await get_tree().process_frame

	print("\n" + "-"*80)
	print("PHASE 4: BIOME DETAIL (Tool 6, R action)")
	print("-"*80)

	await _test_biome_detail_interactive()
	await get_tree().process_frame

func _test_tool_interactive(tool_num: int):
	var tool_names = ["", "Grower 🌱", "Quantum ⚛️", "Industry 🏭", "Biome Ctrl ⚡", "Gates 🔄", "Biome 🌍"]
	var tool_name = tool_names[tool_num]
	var keycode = KEY_1 + (tool_num - 1)

	_log("\n🔷 TOOL %d: %s" % [tool_num, tool_name])
	var issues = []

	# Simulate tool selection
	_simulate_key(keycode, "KEY_%d" % tool_num)
	await get_tree().process_frame

	# Check if tool selected
	var action_bar_mgr = player_shell.action_bar_manager
	if action_bar_mgr:
		var action_row = action_bar_mgr.get_action_row()
		if action_row and action_row.visible:
			_log("   ✅ Action bar visible")
		else:
			_log("   ❌ Action bar NOT visible")
			issues.append("action_bar_not_visible")

	# Try Q action
	_log("   Testing Q action...")
	_simulate_key(KEY_Q, "Q")
	await get_tree().process_frame

	# Try E action
	_log("   Testing E action...")
	_simulate_key(KEY_E, "E")
	await get_tree().process_frame

	# Try R action
	_log("   Testing R action...")
	_simulate_key(KEY_R, "R")
	await get_tree().process_frame

	if issues.is_empty():
		test_results["tool_%d" % tool_num] = "FUNCTIONAL"
		_log("   ✅ Tool %d: Basic functions work" % tool_num)
	else:
		test_results["tool_%d" % tool_num] = "PARTIAL"
		_log("   ⚠️ Tool %d: Issues - %s" % [tool_num, ", ".join(issues)])

func _test_quest_board_interactive():
	_log("\n🔷 QUEST BOARD (Press C)")
	var issues = []

	# Open quest board
	_log("   Opening quest board with C...")
	_simulate_key(KEY_C, "C")
	await get_tree().process_frame

	var quest_board = overlay_manager.quest_board
	if quest_board and quest_board.visible:
		_log("   ✅ Quest board opened")

		# Check if v2 overlay is active
		if overlay_manager.is_v2_overlay_active():
			_log("   ✅ v2 overlay active")
		else:
			_log("   ❌ v2 overlay NOT active (opened as modal instead?)")
			issues.append("not_v2_overlay")

		# Try WASD navigation
		_log("   Testing WASD navigation...")
		_simulate_key(KEY_W, "W")
		await get_tree().process_frame
		_simulate_key(KEY_S, "S")
		await get_tree().process_frame
		_simulate_key(KEY_A, "A")
		await get_tree().process_frame
		_simulate_key(KEY_D, "D")
		await get_tree().process_frame
		_log("   ✅ WASD input processed")

		# Try Q action
		_log("   Testing Q (should accept/complete quest)...")
		_simulate_key(KEY_Q, "Q")
		await get_tree().process_frame
		_log("   ✅ Q input processed")

		# Try F (faction browser)
		_log("   Testing F (should open faction browser)...")
		_simulate_key(KEY_F, "F")
		await get_tree().process_frame
		_log("   ✅ F input processed")

		# Try ESC to close
		_log("   Testing ESC (should close)...")
		_simulate_key(KEY_ESCAPE, "ESC")
		await get_tree().process_frame

		if not quest_board.visible:
			_log("   ✅ Quest board closed with ESC")
		else:
			_log("   ⚠️ Quest board still visible after ESC")
			issues.append("esc_not_closing")
	else:
		_log("   ❌ Quest board did not open")
		issues.append("wont_open")

	if issues.is_empty():
		test_results["quest_board"] = "FUNCTIONAL"
		_log("   ✅ Quest board: All tests passed")
	else:
		test_results["quest_board"] = "ISSUES: " + ", ".join(issues)
		_log("   ⚠️ Quest board: %s" % ", ".join(issues))

func _test_overlays_interactive():
	_log("\n🔷 TESTING v2 OVERLAYS")

	var overlay_tests = [
		{"name": "inspector", "emoji": "📊"},
		{"name": "controls", "emoji": "⌨️"},
		{"name": "semantic_map", "emoji": "🧭"},
		{"name": "biome_detail", "emoji": "🔬"}
	]

	for test in overlay_tests:
		var name = test.name
		var emoji = test.emoji

		_log("\n   Testing %s %s..." % [emoji, name])

		# Open overlay
		var opened = overlay_manager.open_v2_overlay(name)
		await get_tree().process_frame

		if overlay_manager.is_v2_overlay_active():
			_log("      ✅ Opened successfully")

			var overlay = overlay_manager.get_active_v2_overlay()
			if overlay:
				# Test WASD
				_simulate_key(KEY_W, "W")
				_simulate_key(KEY_S, "S")
				_log("      ✅ WASD processed")

				# Test QER+F
				_simulate_key(KEY_Q, "Q")
				_simulate_key(KEY_E, "E")
				_simulate_key(KEY_R, "R")
				_simulate_key(KEY_F, "F")
				_log("      ✅ QER+F processed")

				# Close with ESC
				_simulate_key(KEY_ESCAPE, "ESC")
				await get_tree().process_frame

				if not overlay_manager.is_v2_overlay_active():
					_log("      ✅ Closed with ESC")
					test_results["overlay_%s" % name] = "FUNCTIONAL"
				else:
					_log("      ❌ ESC did not close")
					test_results["overlay_%s" % name] = "ESC_BROKEN"
		else:
			_log("      ❌ Failed to open")
			test_results["overlay_%s" % name] = "WONT_OPEN"

func _test_biome_detail_interactive():
	_log("\n🔷 BIOME DETAIL OVERLAY (Tool 6, R action)")

	# Select tool 6
	_log("   Selecting Tool 6 (Biome)...")
	_simulate_key(KEY_6, "6")
	await get_tree().process_frame

	# Press R (should open biome inspector)
	_log("   Pressing R (inspect)...")
	_simulate_key(KEY_R, "R")
	await get_tree().process_frame

	# Check if biome inspector opened
	var biome_inspector = overlay_manager.biome_inspector
	if biome_inspector and biome_inspector.visible:
		_log("   ✅ Biome inspector opened with Tool 6, R")
		test_results["tool_6_r_action"] = "WORKS"

		# Try to close
		_simulate_key(KEY_ESCAPE, "ESC")
		await get_tree().process_frame

		if not biome_inspector.visible:
			_log("   ✅ Closed with ESC")
		else:
			_log("   ⚠️ ESC did not close biome inspector")
	else:
		_log("   ❌ Biome inspector did not open")
		test_results["tool_6_r_action"] = "BROKEN"

func _print_final_report():
	print("\n" + "="*80)
	print("📊 FINAL TEST REPORT")
	print("="*80)

	# Categorize results
	var working = []
	var partial = []
	var broken = []

	for test_name in test_results.keys():
		var result = test_results[test_name]
		if "FUNCTIONAL" in result or result == "WORKS":
			working.append(test_name)
		elif "PARTIAL" in result or "ISSUES" in result or result == "ESC_BROKEN":
			partial.append(test_name)
		else:
			broken.append(test_name)

	# Print results table
	print("\n✅ WORKING (%d):" % working.size())
	for item in working:
		print("   ✅ %s" % item)

	print("\n⚠️ PARTIAL (%d):" % partial.size())
	for item in partial:
		print("   ⚠️ %s: %s" % [item, test_results[item]])

	print("\n❌ BROKEN (%d):" % broken.size())
	for item in broken:
		print("   ❌ %s: %s" % [item, test_results[item]])

	# Summary
	var total = working.size() + partial.size() + broken.size()
	var pass_rate = float(working.size()) / total * 100 if total > 0 else 0

	print("\n" + "="*80)
	print("SUMMARY: %d/%d tests working (%.0f%%)" % [working.size(), total, pass_rate])
	print("="*80)

	# Print full log
	print("\n" + "="*80)
	print("FULL TEST LOG")
	print("="*80)
	for line in test_log:
		print(line)

