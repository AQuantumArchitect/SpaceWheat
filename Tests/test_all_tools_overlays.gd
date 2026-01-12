extends Node

## Comprehensive Test of All Tools and Overlays
##
## Tests each of the 6 tools and 5 overlays for functionality

var test_results = {}
var farm_view: Node
var player_shell: Node
var overlay_manager: Node
var farm: Node
var input_handler: Node

func _ready():
	print("\n" + "="*70)
	print("🧪 COMPREHENSIVE TOOL & OVERLAY TEST SUITE")
	print("="*70)

	await get_tree().process_frame
	_find_components()

	if farm_view and player_shell and overlay_manager:
		_run_all_tests()
	else:
		print("❌ Missing game components - cannot run tests")

func _find_components():
	farm_view = get_tree().get_first_node_in_group("farm_view")
	player_shell = get_tree().get_first_node_in_group("player_shell")
	overlay_manager = player_shell.overlay_manager if player_shell else null
	farm = overlay_manager.farm if overlay_manager else null
	input_handler = player_shell.input_handler if player_shell else null

	print("\n✅ Found components:")
	print("   - FarmView: %s" % ("✓" if farm_view else "✗"))
	print("   - PlayerShell: %s" % ("✓" if player_shell else "✗"))
	print("   - OverlayManager: %s" % ("✓" if overlay_manager else "✗"))
	print("   - Farm: %s" % ("✓" if farm else "✗"))
	print("   - InputHandler: %s" % ("✓" if input_handler else "✗"))

func _run_all_tests():
	print("\n" + "-"*70)
	print("TESTING OVERLAYS")
	print("-"*70)

	_test_overlays()

	await get_tree().process_frame

	print("\n" + "-"*70)
	print("TESTING TOOLS")
	print("-"*70)

	_test_tools()

	await get_tree().process_frame

	_print_results()

func _test_overlays():
	"""Test all 5 v2 overlays"""
	print("\n1️⃣ INSPECTOR OVERLAY (📊)")
	_test_overlay("inspector", "InspectorOverlay")

	print("\n2️⃣ CONTROLS OVERLAY (⌨️)")
	_test_overlay("controls", "ControlsOverlay")

	print("\n3️⃣ SEMANTIC MAP OVERLAY (🧭)")
	_test_overlay("semantic_map", "SemanticMapOverlay")

	print("\n4️⃣ QUESTS OVERLAY (📜)")
	_test_overlay("quests", "QuestBoard")

	print("\n5️⃣ BIOME DETAIL OVERLAY (🔬)")
	_test_overlay("biome_detail", "BiomeInspectorOverlay")

func _test_overlay(name: String, class_name: String):
	"""Test a single overlay"""
	if not overlay_manager.v2_overlays.has(name):
		print("   ❌ Not registered")
		test_results["overlay_%s" % name] = "NOT_REGISTERED"
		return

	var overlay = overlay_manager.v2_overlays[name]
	var issues = []

	# Test properties
	if not overlay.has_property("overlay_name"):
		issues.append("Missing overlay_name")
	if not overlay.has_property("overlay_icon"):
		issues.append("Missing overlay_icon")
	if not overlay.has_property("action_labels"):
		issues.append("Missing action_labels")

	# Test methods
	var required_methods = ["handle_input", "activate", "deactivate", "on_q_pressed", "on_e_pressed", "on_r_pressed", "on_f_pressed", "get_action_labels"]
	for method in required_methods:
		if not overlay.has_method(method):
			issues.append("Missing method: %s" % method)

	# Test opening
	var opened = overlay_manager.open_v2_overlay(name)
	if not opened:
		issues.append("Failed to open")
	elif not overlay.is_active or not overlay.visible:
		issues.append("Opened but not active/visible")

	overlay_manager.close_v2_overlay()

	if issues.is_empty():
		print("   ✅ All checks passed")
		test_results["overlay_%s" % name] = "PASS"
	else:
		print("   ⚠️ Issues found:")
		for issue in issues:
			print("      - %s" % issue)
		test_results["overlay_%s" % name] = "FAIL: " + ", ".join(issues)

func _test_tools():
	"""Test all 6 tools"""
	var tools = [
		{"num": 1, "name": "Grower", "emoji": "🌱"},
		{"num": 2, "name": "Quantum", "emoji": "⚛️"},
		{"num": 3, "name": "Industry", "emoji": "🏭"},
		{"num": 4, "name": "Biome Control", "emoji": "⚡"},
		{"num": 5, "name": "Gates", "emoji": "🔄"},
		{"num": 6, "name": "Biome", "emoji": "🌍"}
	]

	for tool in tools:
		_test_tool(tool)
		await get_tree().process_frame

func _test_tool(tool: Dictionary):
	"""Test a single tool"""
	var num = tool.num
	var name = tool.name
	var emoji = tool.emoji

	print("\n%d️⃣ TOOL %d - %s %s" % [num, num, emoji, name])

	var issues = []

	# Try to select the tool
	if not player_shell.has_method("select_tool"):
		issues.append("PlayerShell missing select_tool()")
		print("   ❌ Cannot test - missing method")
		test_results["tool_%d" % num] = "ERROR"
		return

	player_shell.select_tool(num - 1)  # 0-indexed
	await get_tree().process_frame

	# Check if tool_config was set
	var tool_config = player_shell.tool_config
	if not tool_config:
		issues.append("tool_config is null")
	else:
		# Check if tool has required methods
		var required_methods = ["q_action", "e_action", "r_action"]
		for method in required_methods:
			if not tool_config.has_method(method):
				issues.append("Missing action method: %s" % method)

	# Check action bar labels
	if player_shell.has_method("get_current_actions"):
		var actions = player_shell.get_current_actions()
		if not actions or actions.is_empty():
			issues.append("No actions returned")

	# Check if UI shows tool selected
	var action_bar = player_shell.action_bar
	if action_bar and action_bar.visible:
		print("   ✅ Action bar visible")
	else:
		issues.append("Action bar not visible")

	# Summary
	if issues.is_empty():
		print("   ✅ Tool selectable and configured")
		test_results["tool_%d" % num] = "PASS"
	else:
		print("   ⚠️ Issues found:")
		for issue in issues:
			print("      - %s" % issue)
		test_results["tool_%d" % num] = "FAIL: " + ", ".join(issues)

func _print_results():
	"""Print summary results in table format"""
	print("\n" + "="*70)
	print("📊 TEST RESULTS SUMMARY")
	print("="*70)

	var overlay_results = []
	var tool_results = []

	for key in test_results.keys():
		var result = test_results[key]
		if key.starts_with("overlay_"):
			overlay_results.append({"key": key.trim_prefix("overlay_"), "result": result})
		else:
			tool_results.append({"key": key.trim_prefix("tool_"), "result": result})

	# Sort for display
	overlay_results.sort_custom(func(a, b): return a.key < b.key)
	tool_results.sort_custom(func(a, b): return int(a.key) < int(b.key))

	print("\nOVERLAYS:")
	print("-" * 70)
	var overlay_pass = 0
	for item in overlay_results:
		var symbol = "✅" if item.result == "PASS" else "❌"
		print("%s %s: %s" % [symbol, item.key, item.result])
		if item.result == "PASS":
			overlay_pass += 1
	print("Result: %d/%d PASS" % [overlay_pass, overlay_results.size()])

	print("\nTOOLS:")
	print("-" * 70)
	var tool_pass = 0
	for item in tool_results:
		var symbol = "✅" if item.result == "PASS" else "❌"
		print("%s Tool %s: %s" % [symbol, item.key, item.result])
		if item.result == "PASS":
			tool_pass += 1
	print("Result: %d/%d PASS" % [tool_pass, tool_results.size()])

	print("\n" + "="*70)
	var total_pass = overlay_pass + tool_pass
	var total_tests = overlay_results.size() + tool_results.size()
	print("OVERALL: %d/%d PASS (%.0f%%)" % [total_pass, total_tests, float(total_pass)/total_tests*100])
	print("="*70)

	if total_pass < total_tests:
		print("\n⚠️ ISSUES DETECTED - Review output above for details")
	else:
		print("\n🎉 ALL TESTS PASSED!")
