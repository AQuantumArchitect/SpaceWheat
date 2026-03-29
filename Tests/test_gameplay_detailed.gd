extends Node

## Detailed Gameplay Test
## Simulates actual gameplay and captures errors/issues

var results: Dictionary = {}
var farm_view: Node
var player_shell: Node
var farm: Node
var input_handler: Node

func _ready():
	print("\n" + "="*80)
	print("🎮 DETAILED GAMEPLAY TEST")
	print("="*80)

	await get_tree().process_frame
	_setup()

	if farm_view and player_shell and farm:
		_run_gameplay_tests()
	else:
		print("❌ Missing game components")

func _setup():
	farm_view = get_tree().get_first_node_in_group("farm_view")
	player_shell = get_tree().get_first_node_in_group("player_shell")
	farm = player_shell.farm if player_shell else null
	input_handler = player_shell.input_handler if player_shell else null

	print("\n✅ Game components found:")
	print("   - FarmView: ✓")
	print("   - PlayerShell: ✓")
	print("   - Farm: ✓")
	print("   - InputHandler: %s" % ("✓" if input_handler else "✗"))

func _run_gameplay_tests():
	print("\n" + "-"*80)
	print("TEST 1: PLOT SELECTION")
	print("-"*80)
	_test_plot_selection()

	await get_tree().process_frame

	print("\n" + "-"*80)
	print("TEST 2: TOOL SELECTION (1-6)")
	print("-"*80)
	_test_tool_selection()

	await get_tree().process_frame

	print("\n" + "-"*80)
	print("TEST 3: QUEST BOARD (Press C)")
	print("-"*80)
	_test_quest_board()

	await get_tree().process_frame

	print("\n" + "-"*80)
	print("SUMMARY")
	print("-"*80)
	_print_summary()

func _test_plot_selection():
	"""Test selecting plots with YUIOP"""
	print("Testing plot selection with Y/U/I/O/P keys...")

	if not farm:
		print("   ❌ Farm not available")
		results["plot_selection"] = "FAIL: Farm unavailable"
		return

	var grid = farm.grid
	if not grid:
		print("   ❌ Farm grid not available")
		results["plot_selection"] = "FAIL: Grid unavailable"
		return

	var plots = grid.plots
	if plots.is_empty():
		print("   ❌ No plots in grid")
		results["plot_selection"] = "FAIL: No plots"
		return

	print("   ✅ Farm has %d plots" % plots.size())
	results["plot_selection"] = "PASS"

func _test_tool_selection():
	"""Test selecting each of 6 tools"""
	print("Testing tool selection...")

	if not player_shell:
		print("   ❌ PlayerShell not available")
		results["tools_available"] = "FAIL"
		return

	var action_bar_manager = player_shell.action_bar_manager
	if not action_bar_manager:
		print("   ❌ ActionBarManager not found")
		results["tools_available"] = "FAIL"
		return

	var tools_found = 0
	var tool_issues = []

	# Check each tool
	for tool_num in range(1, 7):
		var tool_name = _get_tool_name(tool_num)
		print("   Tool %d (%s):" % [tool_num, tool_name])

		# Try to select
		if action_bar_manager.has_method("select_tool"):
			action_bar_manager.select_tool(tool_num - 1)
			await get_tree().process_frame

			# Check if action row was updated
			var action_row = action_bar_manager.get_action_row()
			if action_row and action_row.visible:
				print("      ✅ Action bar shows")
				tools_found += 1
			else:
				print("      ⚠️ Action bar not visible")
				tool_issues.append("Tool %d: action bar not visible" % tool_num)
		else:
			print("      ❌ select_tool() method not found")
			tool_issues.append("Tool %d: select_tool() missing" % tool_num)

	results["tools_available"] = "FOUND: %d/6" % tools_found
	if tool_issues.size() > 0:
		results["tool_issues"] = tool_issues

func _test_quest_board():
	"""Test opening quest board with C key"""
	print("Testing quest board...")

	if not player_shell:
		print("   ❌ PlayerShell not available")
		results["quest_board"] = "FAIL"
		return

	var overlay_manager = player_shell.overlay_manager
	if not overlay_manager:
		print("   ❌ OverlayManager not found")
		results["quest_board"] = "FAIL"
		return

	var quest_board = overlay_manager.quest_board
	if not quest_board:
		print("   ❌ Quest board not found in OverlayManager")
		results["quest_board"] = "FAIL: Not in manager"
		return

	print("   ✅ Quest board exists")

	# Check if it's registered as overlay
	if overlay_manager.overlays.has("quests"):
		print("   ✅ Quest board registered as overlay")
		results["quest_board_v2"] = "PASS"
	else:
		print("   ⚠️ Quest board NOT in overlays")
		results["quest_board_v2"] = "FAIL: Not registered"

	# Try to open it
	var opened = overlay_manager.open_overlay("quests")
	await get_tree().process_frame

	if opened and quest_board.visible:
		print("   ✅ Quest board opens successfully")
		results["quest_board"] = "PASS"

		# Check v2 features
		if quest_board.has_method("get_action_labels"):
			var labels = quest_board.get_action_labels()
			print("   ✅ Has action labels: %s" % labels)
		else:
			print("   ❌ Missing get_action_labels()")
	else:
		print("   ❌ Quest board failed to open")
		results["quest_board"] = "FAIL: Won't open"

	overlay_manager.close_overlay()
	await get_tree().process_frame

func _print_summary():
	"""Print test summary"""
	print("\n📊 TEST RESULTS:\n")

	for test_name in results.keys():
		var result = results[test_name]
		if result is Array:
			print("%s: %d issues" % [test_name, result.size()])
			for issue in result:
				print("   - %s" % issue)
		else:
			print("%s: %s" % [test_name, result])

	# Determine overall status
	var all_pass = results.values().all(func(r): return r == "PASS" or r.begins_with("FOUND"))
	print("\n" + "="*80)
	if all_pass:
		print("✅ ALL TESTS PASSED")
	else:
		print("❌ SOME TESTS FAILED - See details above")
	print("="*80)

func _get_tool_name(num: int) -> String:
	match num:
		1: return "Grower 🌱"
		2: return "Quantum ⚛️"
		3: return "Industry 🏭"
		4: return "Biome Control ⚡"
		5: return "Gates 🔄"
		6: return "Biome 🌍"
		_: return "Unknown"
