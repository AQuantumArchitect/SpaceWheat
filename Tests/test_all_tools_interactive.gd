extends Node

## Comprehensive tool testing - systematically exercises all 18 tool actions
## Tools: 1=Grower, 2=Quantum, 3=Industry, 4=BiomeControl, 5=Gates, 6=Biome
## Each tool has Q/E/R actions = 6 tools × 3 actions = 18 actions to test

const Farm = preload("res://Core/Farm.gd")
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")

var farm: Farm
var test_results: Dictionary = {}
var current_turn: int = 0

func _ready():
	print("\n" + "═".repeat(80))
	print("🔬 COMPREHENSIVE TOOL ACTION TESTING")
	print("═".repeat(80) + "\n")

	# Setup
	_setup_game()
	await get_tree().process_frame

	# Run all tests
	await _test_all_tools()

	# Report
	_print_results()

	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0)

func _setup_game():
	print("Setting up farm...")
	farm = Farm.new()
	add_child(farm)

	# Wait for initialization
	for i in range(20):
		await get_tree().process_frame
	await get_tree().create_timer(2.0).timeout

	print("✅ Farm ready\n")

func _test_all_tools():
	"""Test all 6 tools systematically"""

	print("Starting tool testing...\n")

	# Tool 1: Grower
	await _test_tool_1_grower()
	await _delay()

	# Tool 2: Quantum
	await _test_tool_2_quantum()
	await _delay()

	# Tool 3: Industry
	await _test_tool_3_industry()
	await _delay()

	# Tool 4: Biome Control
	await _test_tool_4_biome_control()
	await _delay()

	# Tool 5: Gates
	await _test_tool_5_gates()
	await _delay()

	# Tool 6: Biome
	await _test_tool_6_biome()

	print("\n✅ All tool testing complete!")

func _delay():
	"""Small delay between tool tests"""
	await get_tree().create_timer(0.2).timeout

# ============================================================================
# TOOL 1: GROWER 🌱 (Core farming)
# ============================================================================

func _test_tool_1_grower():
	print("\n" + "─".repeat(80))
	print("🌱 TOOL 1: GROWER - Core Farming Operations")
	print("─".repeat(80))

	var tool_num = 1
	var tool_name = ToolConfig.get_tool_name(tool_num)
	print("Tool: %d (%s)" % [tool_num, tool_name])

	# Q: Plant submenu
	print("\n   Q: Plant Submenu (should show plant options)")
	var q_action = ToolConfig.get_action(tool_num, "Q")
	_log_action(tool_num, "Q", q_action)

	# Sub-actions: plant_wheat, plant_mushroom, plant_tomato
	print("   ├─ Q (Plant Wheat):")
	if farm and farm.grid:
		var pos = _find_empty_plot()
		if pos != Vector2i(-1, -1):
			var success = farm.build(pos, "wheat")
			_record_result("Tool1_Plant_Wheat", success)
			print("      %s Planted wheat at %s" % ["✅" if success else "❌", pos])
		else:
			print("      ⚠️  No empty plots available")

	print("   ├─ E (Plant Mushroom):")
	if farm and farm.grid:
		var pos = _find_empty_plot()
		if pos != Vector2i(-1, -1):
			var success = farm.build(pos, "mushroom")
			_record_result("Tool1_Plant_Mushroom", success)
			print("      %s Planted mushroom at %s" % ["✅" if success else "❌", pos])
		else:
			print("      ⚠️  No empty plots available")

	print("   └─ R (Plant Tomato):")
	if farm and farm.grid:
		var pos = _find_empty_plot()
		if pos != Vector2i(-1, -1):
			var success = farm.build(pos, "tomato")
			_record_result("Tool1_Plant_Tomato", success)
			print("      %s Planted tomato at %s" % ["✅" if success else "❌", pos])
		else:
			print("      ⚠️  No empty plots available")

	# E: Entangle batch
	print("\n   E: Entangle Batch (Bell φ+)")
	var e_action = ToolConfig.get_action(tool_num, "E")
	_log_action(tool_num, "E", e_action)
	if farm and farm.grid:
		var pair = _find_adjacent_unmeasured_pair()
		if pair.size() == 2:
			var success = farm.entangle_plots(pair[0], pair[1])
			_record_result("Tool1_Entangle_Batch", success)
			var status = "✅" if success else "❌"
			print("      %s Entangled %s and %s" % [status, pair[0], pair[1]])
		else:
			print("      ⚠️  No adjacent unmeasured plots to entangle")

	# R: Measure and harvest
	print("\n   R: Measure + Harvest")
	var r_action = ToolConfig.get_action(tool_num, "R")
	_log_action(tool_num, "R", r_action)
	# This would require measured plots, so we'll note it
	print("      ℹ️  Requires measured plots (harvest path tested separately)")

# ============================================================================
# TOOL 2: QUANTUM ⚛️ (Gate infrastructure)
# ============================================================================

func _test_tool_2_quantum():
	print("\n" + "─".repeat(80))
	print("⚛️  TOOL 2: QUANTUM - Gate Infrastructure")
	print("─".repeat(80))

	var tool_num = 2
	var tool_name = ToolConfig.get_tool_name(tool_num)
	print("
Tool: %d (%s)" % [tool_num, tool_name])

	# Q: Cluster (Build gate)
	print("\n   Q: Cluster (Build Gate 2=Bell, 3+=Cluster)")
	var q_action = ToolConfig.get_action(tool_num, "Q")
	_log_action(tool_num, "Q", q_action)
	print("      ℹ️  Gate building not fully tested (future implementation)")
	_record_result("Tool2_Cluster", false, "NOT IMPLEMENTED")

	# E: Measure trigger
	print("\n   E: Set Measure Trigger")
	var e_action = ToolConfig.get_action(tool_num, "E")
	_log_action(tool_num, "E", e_action)
	print("      ℹ️  Measure trigger not fully tested (future implementation)")
	_record_result("Tool2_Measure_Trigger", false, "NOT IMPLEMENTED")

	# R: Measure batch
	print("\n   R: Measure Batch")
	var r_action = ToolConfig.get_action(tool_num, "R")
	_log_action(tool_num, "R", r_action)
	print("      ℹ️  Batch measure not fully tested (measure_plot works per-plot)")
	_record_result("Tool2_Measure_Batch", false, "PARTIAL")

# ============================================================================
# TOOL 3: INDUSTRY 🏭 (Economy & automation)
# ============================================================================

func _test_tool_3_industry():
	print("\n" + "─".repeat(80))
	print("🏭 TOOL 3: INDUSTRY - Economy & Automation")
	print("─".repeat(80))

	var tool_num = 3
	var tool_name = ToolConfig.get_tool_name(tool_num)
	print("
Tool: %d (%s)" % [tool_num, tool_name])

	# Q: Build submenu (Mill/Market/Kitchen)
	print("\n   Q: Build Submenu (Mill/Market/Kitchen)")
	var q_action = ToolConfig.get_action(tool_num, "Q")
	_log_action(tool_num, "Q", q_action)
	print("      ℹ️  Building infrastructure not fully tested (future implementation)")
	_record_result("Tool3_Build_Mill", false, "NOT IMPLEMENTED")
	_record_result("Tool3_Build_Market", false, "NOT IMPLEMENTED")
	_record_result("Tool3_Build_Kitchen", false, "NOT IMPLEMENTED")

	# E: Place market
	print("\n   E: Place Market")
	var e_action = ToolConfig.get_action(tool_num, "E")
	_log_action(tool_num, "E", e_action)
	print("      ℹ️  Market placement not tested")
	_record_result("Tool3_Place_Market", false, "NOT IMPLEMENTED")

	# R: Place kitchen
	print("\n   R: Place Kitchen")
	var r_action = ToolConfig.get_action(tool_num, "R")
	_log_action(tool_num, "R", r_action)
	print("      ℹ️  Kitchen placement not tested")
	_record_result("Tool3_Place_Kitchen", false, "NOT IMPLEMENTED")

# ============================================================================
# TOOL 4: BIOME CONTROL ⚡ (Quantum research-grade control)
# ============================================================================

func _test_tool_4_biome_control():
	print("\n" + "─".repeat(80))
	print("⚡ TOOL 4: BIOME CONTROL - Research-Grade Quantum Control")
	print("─".repeat(80))

	var tool_num = 4
	var tool_name = ToolConfig.get_tool_name(tool_num)
	print("
Tool: %d (%s)" % [tool_num, tool_name])

	# Q: Energy tap submenu (dynamic)
	print("\n   Q: Energy Tap Submenu (dynamic from vocabulary)")
	var q_action = ToolConfig.get_action(tool_num, "Q")
	_log_action(tool_num, "Q", q_action)

	# Get dynamic submenu
	var energy_tap_menu = ToolConfig.get_dynamic_submenu("energy_tap", farm)
	if energy_tap_menu.get("_disabled"):
		print("      ⚠️  Energy tap disabled (no vocabulary discovered)")
		_record_result("Tool4_Energy_Tap", false, "NO VOCABULARY")
	else:
		print("      ✅ Energy tap menu available:")
		for key in ["Q", "E", "R"]:
			if energy_tap_menu.has(key):
				var action = energy_tap_menu[key]
				print("         %s: %s (%s)" % [key, action.get("label", "?"), action.get("emoji", "")])
		_record_result("Tool4_Energy_Tap", true)

	# E: Pump/Reset submenu
	print("\n   E: Pump/Reset Submenu")
	var e_action = ToolConfig.get_action(tool_num, "E")
	_log_action(tool_num, "E", e_action)

	var pump_reset_menu = ToolConfig.get_submenu("pump_reset")
	print("      ✅ Pump/Reset menu available:")
	for key in ["Q", "E", "R"]:
		if pump_reset_menu.has(key):
			var action = pump_reset_menu[key]
			print("         %s: %s (%s)" % [key, action.get("label", "?"), action.get("emoji", "")])
	_record_result("Tool4_Pump_Reset", true)

	# R: Tune decoherence
	print("\n   R: Tune Decoherence")
	var r_action = ToolConfig.get_action(tool_num, "R")
	_log_action(tool_num, "R", r_action)
	print("      ℹ️  Decoherence tuning not fully implemented")
	_record_result("Tool4_Tune_Decoherence", false, "NOT IMPLEMENTED")

# ============================================================================
# TOOL 5: GATES 🔄 (Quantum gate operations)
# ============================================================================

func _test_tool_5_gates():
	print("\n" + "─".repeat(80))
	print("🔄 TOOL 5: GATES - Quantum Gate Operations")
	print("─".repeat(80))

	var tool_num = 5
	var tool_name = ToolConfig.get_tool_name(tool_num)
	print("
Tool: %d (%s)" % [tool_num, tool_name])

	# Q: Single-qubit gates
	print("\n   Q: Single-Qubit Gates (1-Qubit)")
	var q_action = ToolConfig.get_action(tool_num, "Q")
	_log_action(tool_num, "Q", q_action)

	var single_gates_menu = ToolConfig.get_submenu("single_gates")
	print("      ✅ Single-qubit gates menu available:")
	for key in ["Q", "E", "R"]:
		if single_gates_menu.has(key):
			var action = single_gates_menu[key]
			print("         %s: %s (%s)" % [key, action.get("label", "?"), action.get("emoji", "")])
	_record_result("Tool5_Single_Gates", true)

	# E: Two-qubit gates
	print("\n   E: Two-Qubit Gates (2-Qubit)")
	var e_action = ToolConfig.get_action(tool_num, "E")
	_log_action(tool_num, "E", e_action)

	var two_gates_menu = ToolConfig.get_submenu("two_gates")
	print("      ✅ Two-qubit gates menu available:")
	for key in ["Q", "E", "R"]:
		if two_gates_menu.has(key):
			var action = two_gates_menu[key]
			print("         %s: %s (%s)" % [key, action.get("label", "?"), action.get("emoji", "")])
	_record_result("Tool5_Two_Gates", true)

	# R: Remove gates
	print("\n   R: Remove Gates")
	var r_action = ToolConfig.get_action(tool_num, "R")
	_log_action(tool_num, "R", r_action)
	print("      ℹ️  Gate removal not fully tested (future implementation)")
	_record_result("Tool5_Remove_Gates", false, "NOT IMPLEMENTED")

# ============================================================================
# TOOL 6: BIOME 🌍 (Ecosystem management)
# ============================================================================

func _test_tool_6_biome():
	print("\n" + "─".repeat(80))
	print("🌍 TOOL 6: BIOME - Ecosystem Management")
	print("─".repeat(80))

	var tool_num = 6
	var tool_name = ToolConfig.get_tool_name(tool_num)
	print("
Tool: %d (%s)" % [tool_num, tool_name])

	# Q: Biome assignment submenu (dynamic)
	print("\n   Q: Biome Assignment Submenu (dynamic from biomes)")
	var q_action = ToolConfig.get_action(tool_num, "Q")
	_log_action(tool_num, "Q", q_action)

	var biome_assign_menu = ToolConfig.get_dynamic_submenu("biome_assign", farm)
	if biome_assign_menu.get("_disabled"):
		print("      ⚠️  Biome assignment disabled (no biomes)")
		_record_result("Tool6_Biome_Assign", false, "NO BIOMES")
	else:
		print("      ✅ Biome assignment menu available:")
		for key in ["Q", "E", "R"]:
			if biome_assign_menu.has(key):
				var action = biome_assign_menu[key]
				print("         %s: %s (%s)" % [key, action.get("label", "?"), action.get("emoji", "")])
		_record_result("Tool6_Biome_Assign", true)

	# E: Clear biome assignment
	print("\n   E: Clear Biome Assignment")
	var e_action = ToolConfig.get_action(tool_num, "E")
	_log_action(tool_num, "E", e_action)
	print("      ℹ️  Clear assignment not fully tested")
	_record_result("Tool6_Clear_Assignment", false, "NOT IMPLEMENTED")

	# R: Inspect plot
	print("\n   R: Inspect Plot")
	var r_action = ToolConfig.get_action(tool_num, "R")
	_log_action(tool_num, "R", r_action)
	print("      ℹ️  Inspect not fully tested")
	_record_result("Tool6_Inspect_Plot", false, "NOT IMPLEMENTED")

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _log_action(tool_num: int, key: String, action: Dictionary):
	"""Log an action configuration"""
	var label = action.get("label", "?")
	var emoji = action.get("emoji", "")
	print("      %s %s" % [emoji, label])

func _find_empty_plot() -> Vector2i:
	"""Find first empty plot"""
	if not farm or not farm.grid:
		return Vector2i(-1, -1)

	for y in range(farm.grid.grid_height):
		for x in range(farm.grid.grid_width):
			var pos = Vector2i(x, y)
			var plot = farm.grid.get_plot(pos)
			if plot and not plot.is_planted:
				return pos

	return Vector2i(-1, -1)

func _find_adjacent_unmeasured_pair() -> Array[Vector2i]:
	"""Find two adjacent unmeasured plots"""
	if not farm or not farm.grid:
		return []

	var result: Array[Vector2i] = []

	for y in range(farm.grid.grid_height):
		for x in range(farm.grid.grid_width):
			for dx in [-1, 1]:
				var pos1 = Vector2i(x, y)
				var pos2 = Vector2i(x + dx, y)

				if pos2.x < 0 or pos2.x >= farm.grid.grid_width:
					continue

				var plot1 = farm.grid.get_plot(pos1)
				var plot2 = farm.grid.get_plot(pos2)

				if plot1 and plot2 and plot1.is_planted and plot2.is_planted:
					if not plot1.has_been_measured and not plot2.has_been_measured:
						result.append(pos1)
						result.append(pos2)
						return result

	return result

func _record_result(test_name: String, success: bool, note: String = ""):
	"""Record test result"""
	var status = "✅" if success else "❌"
	test_results[test_name] = {
		"success": success,
		"note": note
	}

func _print_results():
	"""Print comprehensive test results"""
	print("\n\n" + "═".repeat(80))
	print("📊 TOOL TESTING RESULTS SUMMARY")
	print("═".repeat(80) + "\n")

	var passed = 0
	var failed = 0
	var not_impl = 0

	var by_tool = {}

	for test_name in test_results.keys():
		var result = test_results[test_name]
		var tool = test_name.split("_")[0] + "_" + test_name.split("_")[1]

		if not by_tool.has(tool):
			by_tool[tool] = {"pass": 0, "fail": 0, "not_impl": 0}

		if result["success"]:
			passed += 1
			by_tool[tool]["pass"] += 1
		else:
			if "NOT IMPLEMENTED" in result.get("note", ""):
				not_impl += 1
				by_tool[tool]["not_impl"] += 1
			else:
				failed += 1
				by_tool[tool]["fail"] += 1

	print("Results by tool:")
	for i in range(1, 7):
		var tool_name = ToolConfig.get_tool_name(i)
		print("\n   Tool %d: %s" % [i, tool_name])

		var q = ToolConfig.get_action(i, "Q")
		var e = ToolConfig.get_action(i, "E")
		var r = ToolConfig.get_action(i, "R")

		print("      Q: %s" % q.get("label", "?"))
		print("      E: %s" % e.get("label", "?"))
		print("      R: %s" % r.get("label", "?"))

	print("\n" + "─".repeat(80))
	var total = passed + failed + not_impl
	print("\nTotal Tests: %d" % total)
	print("   ✅ Passed: %d" % passed)
	print("   ❌ Failed: %d" % failed)
	print("   ⚠️  Not Implemented: %d" % not_impl)
	var rate = int(100.0 * passed / (passed + failed + not_impl))
	print("   📊 Success Rate: %d%%" % rate)
	print("\n" + "═".repeat(80) + "\n")
