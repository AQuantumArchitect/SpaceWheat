extends Node

## Comprehensive System Test
## Deep analysis of tools, overlays, and data flow

func _ready():
	print("\n" + "="*100)
	print("🔬 COMPREHENSIVE SYSTEM ANALYSIS TEST")
	print("="*100)

	await get_tree().process_frame
	_run_comprehensive_tests()

func _run_comprehensive_tests():
	var farm_view = get_tree().get_first_node_in_group("farm_view")
	var player_shell = get_tree().get_first_node_in_group("player_shell")

	if not farm_view or not player_shell:
		print("❌ Game not ready")
		return

	print("\n" + "─"*100)
	print("SECTION 1: COMPONENT VERIFICATION")
	print("─"*100)

	_verify_components(player_shell)

	print("\n" + "─"*100)
	print("SECTION 2: OVERLAY SYSTEM VERIFICATION")
	print("─"*100)

	_verify_overlays(player_shell)

	print("\n" + "─"*100)
	print("SECTION 3: TOOL SYSTEM VERIFICATION")
	print("─"*100)

	_verify_tools(player_shell)

	print("\n" + "─"*100)
	print("SECTION 4: INPUT ROUTING VERIFICATION")
	print("─"*100)

	_verify_input_routing(player_shell)

	print("\n" + "─"*100)
	print("SECTION 5: DATA FLOW VERIFICATION")
	print("─"*100)

	_verify_data_flow(player_shell)

	print("\n" + "="*100)
	print("✅ ANALYSIS COMPLETE")
	print("="*100)

func _verify_components(shell: Node):
	"""Check if all required components exist and are accessible"""
	print("\n🔍 Checking core components...")

	var checks = {
		"PlayerShell": shell,
		"OverlayManager": shell.overlay_manager if shell.has_meta("overlay_manager") or "overlay_manager" in shell else null,
		"ActionBarManager": shell.action_bar_manager if shell.has_meta("action_bar_manager") or "action_bar_manager" in shell else null,
		"Farm": shell.farm if shell.has_meta("farm") or "farm" in shell else null,
		"InputHandler": shell.input_handler if shell.has_meta("input_handler") or "input_handler" in shell else null,
		"QuestManager": shell.quest_manager if shell.has_meta("quest_manager") or "quest_manager" in shell else null,
	}

	for name in checks.keys():
		var component = checks[name]
		if component:
			print("   ✅ %s: Present" % name)
		else:
			print("   ❌ %s: MISSING" % name)

func _verify_overlays(shell: Node):
	"""Check overlay system"""
	print("\n🔍 Checking overlay system...")

	var overlay_mgr = shell.overlay_manager
	if not overlay_mgr:
		print("   ❌ OverlayManager is null")
		return

	if not overlay_mgr.v2_overlays:
		print("   ❌ v2_overlays dictionary missing")
		return

	print("   ✅ Overlays registered: %d" % overlay_mgr.v2_overlays.size())

	var expected = ["inspector", "controls", "semantic_map", "quests", "biome_detail"]
	for overlay_name in expected:
		if overlay_mgr.v2_overlays.has(overlay_name):
			var overlay = overlay_mgr.v2_overlays[overlay_name]
			var methods_ok = true
			var missing_methods = []

			for method in ["handle_input", "activate", "deactivate", "get_action_labels"]:
				if not overlay.has_method(method):
					methods_ok = false
					missing_methods.append(method)

			if methods_ok:
				print("      ✅ %s: All methods present" % overlay_name)
			else:
				print("      ❌ %s: Missing methods - %s" % [overlay_name, ", ".join(missing_methods)])
		else:
			print("      ❌ %s: NOT registered" % overlay_name)

	# Test opening/closing
	print("\n   Testing open/close mechanism:")
	if overlay_mgr.has_method("open_v2_overlay"):
		var test_opened = overlay_mgr.open_v2_overlay("controls")
		if test_opened:
			print("      ✅ Can open overlays")
			overlay_mgr.close_v2_overlay()
			print("      ✅ Can close overlays")
		else:
			print("      ❌ Failed to open overlay")
	else:
		print("      ❌ open_v2_overlay() method missing")

func _verify_tools(shell: Node):
	"""Check tool system"""
	print("\n🔍 Checking tool system...")

	var action_bar_mgr = shell.action_bar_manager
	if not action_bar_mgr:
		print("   ❌ ActionBarManager is null")
		return

	print("   ✅ ActionBarManager exists")

	# Check if tools can be selected
	if action_bar_mgr.has_method("select_tool"):
		print("   ✅ select_tool() method exists")

		# Try selecting a tool
		action_bar_mgr.select_tool(0)  # Tool 1
		print("   ✅ Tool selection callable")
	else:
		print("   ❌ select_tool() method missing")

	# Check action row
	if action_bar_mgr.has_method("get_action_row"):
		var action_row = action_bar_mgr.get_action_row()
		if action_row:
			print("   ✅ Action row accessible")
		else:
			print("   ❌ Action row is null")
	else:
		print("   ❌ get_action_row() method missing")

	# Check quest board integration
	var quest_board = shell.overlay_manager.quest_board if shell.overlay_manager else null
	if quest_board:
		print("   ✅ Quest board exists")

		if quest_board.has_method("get_action_labels"):
			print("   ✅ Quest board has v2 interface")
		else:
			print("   ❌ Quest board missing v2 methods")
	else:
		print("   ❌ Quest board not found")

func _verify_input_routing(shell: Node):
	"""Check input routing hierarchy"""
	print("\n🔍 Checking input routing...")

	var input_handler = shell.input_handler
	var overlay_mgr = shell.overlay_manager

	print("   Checking routing priority:")
	print("      1. v2 Overlays ......... ", end="")
	if overlay_mgr and overlay_mgr.v2_overlays:
		print("✅")
	else:
		print("❌")

	print("      2. PlayerShell ........ ", end="")
	if shell.has_method("_handle_shell_action"):
		print("✅")
	else:
		print("❌")

	print("      3. FarmInputHandler ... ", end="")
	if input_handler:
		print("✅")
	else:
		print("❌")

	# Check if overlays have input handlers
	print("\n   Checking overlay input methods:")
	for overlay_name in overlay_mgr.v2_overlays.keys():
		var overlay = overlay_mgr.v2_overlays[overlay_name]
		if overlay.has_method("handle_input"):
			print("      ✅ %s: handle_input() exists" % overlay_name)
		else:
			print("      ❌ %s: handle_input() missing" % overlay_name)

func _verify_data_flow(shell: Node):
	"""Check if data flows correctly to components"""
	print("\n🔍 Checking data flow...")

	var overlay_mgr = shell.overlay_manager
	var farm = shell.farm

	# Check quest board quest data
	print("   Quest Board data:")
	var quest_board = overlay_mgr.quest_board
	if quest_board:
		print("      ✅ Quest board exists")

		if quest_board.quest_slots and quest_board.quest_slots.size() > 0:
			print("      ✅ Quest slots created (%d slots)" % quest_board.quest_slots.size())

			var slot = quest_board.quest_slots[0]
			if slot and slot.state >= 0:
				print("      ✅ Quest slot state accessible")
			else:
				print("      ❌ Quest slot state invalid")
		else:
			print("      ❌ No quest slots found")

		if quest_board.quest_manager:
			print("      ✅ Quest board has quest_manager reference")
		else:
			print("      ❌ Quest board missing quest_manager")
	else:
		print("      ❌ Quest board not found")

	# Check inspector data
	print("\n   Inspector Overlay data:")
	var inspector = overlay_mgr.v2_overlays.get("inspector")
	if inspector:
		print("      ✅ Inspector overlay exists")

		if inspector.has_property("quantum_computer"):
			if inspector.quantum_computer:
				print("      ✅ Inspector has quantum_computer set")
			else:
				print("      ❌ Inspector quantum_computer is null")
		else:
			print("      ⚠️ Inspector property not found (might be dynamic)")
	else:
		print("      ❌ Inspector overlay not found")

	# Check semantic map data
	print("\n   Semantic Map data:")
	var semantic = overlay_mgr.v2_overlays.get("semantic_map")
	if semantic:
		print("      ✅ Semantic map exists")

		if semantic.has_property("vocabulary_data"):
			if semantic.vocabulary_data and not semantic.vocabulary_data.is_empty():
				print("      ✅ Vocabulary data loaded (%d items)" % semantic.vocabulary_data.size())
			else:
				print("      ❌ Vocabulary data empty or missing")
		else:
			print("      ⚠️ Vocabulary property not directly accessible")
	else:
		print("      ❌ Semantic map not found")

	# Check farm/biome data
	print("\n   Farm/Biome data:")
	if farm:
		print("      ✅ Farm exists")

		if farm.grid:
			print("      ✅ Farm grid exists (%d plots)" % farm.grid.plots.size())
		else:
			print("      ❌ Farm grid missing")

		if farm.biomes and not farm.biomes.is_empty():
			print("      ✅ Biomes registered (%d biomes)" % farm.biomes.size())
		else:
			print("      ❌ No biomes found")
	else:
		print("      ❌ Farm not found")

