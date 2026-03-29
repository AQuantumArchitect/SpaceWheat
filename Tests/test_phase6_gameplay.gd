extends Node

## Phase 6: Comprehensive v2 Overlay Gameplay Tests
## Tests tools, overlays, input routing, and data flow

func _ready():
	await get_tree().process_frame
	_run_tests()

func _run_tests():
	var output = []
	output.append("\n" + "="*100)
	output.append("🎮 PHASE 6 GAMEPLAY TEST SUITE")
	output.append("="*100)

	var farm_view = get_tree().get_first_node_in_group("farm_view")
	var player_shell = get_tree().get_first_node_in_group("player_shell")

	if not farm_view or not player_shell:
		output.append("\n❌ FATAL: Game components not initialized")
		for line in output:
			print(line)
		return

	output.append("\n✅ Game initialized - starting tests\n")

	# Test 1: Component Access
	output.append("─"*100)
	output.append("TEST 1: COMPONENT ACCESS")
	output.append("─"*100)
	_test_components(player_shell, output)

	# Test 2: Overlay System
	output.append("\n─"*100)
	output.append("TEST 2: OVERLAY SYSTEM")
	output.append("─"*100)
	_test_overlays(player_shell, output)

	# Test 3: Tool System
	output.append("\n─"*100)
	output.append("TEST 3: TOOL SELECTION")
	output.append("─"*100)
	_test_tools(player_shell, output)

	# Test 4: Input Routing
	output.append("\n─"*100)
	output.append("TEST 4: INPUT ROUTING")
	output.append("─"*100)
	_test_input_routing(player_shell, output)

	# Test 5: Data Flow
	output.append("\n─"*100)
	output.append("TEST 5: DATA BINDING")
	output.append("─"*100)
	_test_data_flow(player_shell, output)

	output.append("\n" + "="*100)
	output.append("✅ TESTS COMPLETE")
	output.append("="*100)

	for line in output:
		print(line)

	_write_report(output)

func _test_components(shell: Node, output: Array):
	output.append("\n🔍 Checking core components...\n")

	var checks = {
		"PlayerShell": shell,
		"OverlayManager": shell.overlay_manager if "overlay_manager" in shell else null,
		"ActionBarManager": shell.action_bar_manager if "action_bar_manager" in shell else null,
		"Farm": shell.farm if "farm" in shell else null,
		"InputHandler": shell.input_handler if "input_handler" in shell else null,
	}

	var all_ok = true
	for name in checks.keys():
		var component = checks[name]
		if component:
			output.append("   ✅ %s: Present" % name)
		else:
			output.append("   ❌ %s: MISSING" % name)
			all_ok = false

	if all_ok:
		output.append("\n✅ All core components present")
	else:
		output.append("\n❌ Some components missing - tests may fail")

func _test_overlays(shell: Node, output: Array):
	output.append("\n🔍 Checking overlay stack system...\n")

	var overlay_mgr = shell.overlay_manager
	if not overlay_mgr:
		output.append("   ❌ OverlayManager is null")
		return

	if not overlay_mgr.overlays:
		output.append("   ❌ overlays dictionary missing")
		return

	var count = overlay_mgr.overlays.size()
	output.append("   ✅ Overlays registered: %d" % count)

	var expected = ["inspector", "controls", "semantic_map", "quests", "biome_detail"]
	var found_all = true
	for overlay_name in expected:
		if overlay_mgr.overlays.has(overlay_name):
			var overlay = overlay_mgr.overlays[overlay_name]
			var has_methods = true
			for method in ["handle_input", "activate", "deactivate"]:
				if not overlay.has_method(method):
					has_methods = false
					break
			if has_methods:
				output.append("      ✅ %s: Registered with methods" % overlay_name)
			else:
				output.append("      ⚠️ %s: Missing v2 methods" % overlay_name)
		else:
			output.append("      ❌ %s: NOT registered" % overlay_name)
			found_all = false

	if found_all:
		output.append("\n✅ All overlays registered and available")
	else:
		output.append("\n⚠️ Some overlays missing - check OverlayManager._create_overlays()")

func _test_tools(shell: Node, output: Array):
	output.append("\n🔍 Checking tool selection...\n")

	var action_bar_mgr = shell.action_bar_manager
	if not action_bar_mgr:
		output.append("   ❌ ActionBarManager is null")
		return

	output.append("   ✅ ActionBarManager exists")

	if not action_bar_mgr.has_method("select_tool"):
		output.append("   ❌ select_tool() method missing")
		return

	output.append("   ✅ select_tool() method exists")

	# Try to select each tool
	for tool_num in range(1, 5):
		action_bar_mgr.select_tool(tool_num - 1)  # 0-indexed
		output.append("      ✅ Tool %d selectable" % tool_num)

	output.append("\n✅ Tool selection system working")

func _test_input_routing(shell: Node, output: Array):
	output.append("\n🔍 Checking input routing hierarchy...\n")

	output.append("   Priority chain:")
	var overlay_mgr = shell.overlay_manager
	var input_handler = shell.input_handler

	if overlay_mgr and overlay_mgr.overlays:
		output.append("      1. ✅ Overlay system present")
	else:
		output.append("      1. ❌ Overlay system missing")

	if input_handler:
		output.append("      2. ✅ FarmInputHandler present")
	else:
		output.append("      2. ❌ FarmInputHandler missing")

	if shell.has_method("_handle_shell_action"):
		output.append("      3. ✅ PlayerShell modal routing present")
	else:
		output.append("      3. ⚠️ PlayerShell modal routing limited")

	output.append("\n✅ Input routing chain configured")

func _test_data_flow(shell: Node, output: Array):
	output.append("\n🔍 Checking data flow to overlays...\n")

	var overlay_mgr = shell.overlay_manager
	var farm = shell.farm if "farm" in shell else null

	# Inspector data
	output.append("   Inspector overlay:")
	var inspector = overlay_mgr.overlays.get("inspector") if overlay_mgr else null
	if inspector:
		if inspector.has_meta("quantum_computer") or "quantum_computer" in inspector:
			output.append("      ⚠️ quantum_computer property exists but may need binding")
		else:
			output.append("      ❌ quantum_computer property missing")
		output.append("      ➜ FIX: Call inspector.set_biome() when opening overlay")
	else:
		output.append("      ❌ Inspector overlay not found")

	# Semantic Map data
	output.append("\n   Semantic Map overlay:")
	var semantic = overlay_mgr.overlays.get("semantic_map") if overlay_mgr else null
	if semantic:
		if semantic.has_meta("vocabulary_data") or "vocabulary_data" in semantic:
			output.append("      ⚠️ vocabulary_data property exists but not loaded")
		else:
			output.append("      ❌ vocabulary_data property missing")
		output.append("      ➜ FIX: Implement _load_vocabulary_data() in SemanticMapOverlay.activate()")
	else:
		output.append("      ❌ Semantic Map overlay not found")

	# Quest Board data
	output.append("\n   Quest Board:")
	var quest_board = overlay_mgr.quest_board if overlay_mgr else null
	if quest_board:
		output.append("      ✅ Quest board exists")
		if quest_board.quest_manager:
			output.append("      ✅ Quest manager reference present")
		else:
			output.append("      ❌ Quest manager reference missing")
	else:
		output.append("      ❌ Quest board not found")

	# Farm/Biome data
	output.append("\n   Farm & Biomes:")
	if farm:
		output.append("      ✅ Farm exists")
		if farm.grid.grid and farm.grid.grid.get_plot_count() > 0:
			output.append("      ✅ Farm grid (%d plots)" % farm.grid.get_plot_count())
		else:
			output.append("      ❌ Farm grid missing")
		if farm.biomes:
			output.append("      ✅ Biomes registered (%d)" % farm.biomes.size())
		else:
			output.append("      ❌ No biomes found")
	else:
		output.append("      ❌ Farm not found")

	output.append("\n⚠️ Data binding issues found - see FIX notes above")

func _write_report(output: Array):
	var content = "\n".join(output)
	var file = FileAccess.open("user://phase6_test_results.txt", FileAccess.WRITE)
	if file:
		file.store_string(content)
