extends SceneTree

## Simple Tool 6 Test - No game loop processing
## Tests core functionality synchronously

const Farm = preload("res://Core/Farm.gd")
const FarmInputHandler = preload("res://UI/FarmInputHandler.gd")
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")

func _init():
	print("\n======================================================================")
	print("🧪 TOOL 6 SIMPLE TEST")
	print("======================================================================\n")

	# Setup farm
	var farm = Farm.new()
	root.add_child(farm)

	# Setup input handler
	var input_handler = FarmInputHandler.new()
	root.add_child(input_handler)
	input_handler.farm = farm

	# Wait for initialization
	await process_frame
	await process_frame

	# Disable _process to stop quantum evolution (prevents timeout)
	farm.set_process(false)
	if farm.biotic_flux_biome:
		farm.biotic_flux_biome.set_process(false)
	if farm.market_biome:
		farm.market_biome.set_process(false)
	if farm.forest_biome:
		farm.forest_biome.set_process(false)
	if farm.kitchen_biome:
		farm.kitchen_biome.set_process(false)

	print("\n✅ Farm initialized, processing disabled")
	print("   Registered biomes: %d" % farm.grid.biomes.size())
	for biome_name in farm.grid.biomes.keys():
		print("      • %s" % biome_name)

	# Run tests
	_test_1_tool_config(farm)
	_test_2_dynamic_submenu(farm)
	_test_3_plot_assignment(farm, input_handler)
	_test_4_plot_inspection(farm, input_handler)

	print("\n======================================================================")
	print("✅ ALL TESTS PASSED")
	print("======================================================================\n")

	quit(0)


func _test_1_tool_config(farm):
	"""Test 1: Tool 6 exists in ToolConfig"""
	print("\n──────────────────────────────────────────────────────────────────────")
	print("TEST 1: Tool Config Validation")
	print("──────────────────────────────────────────────────────────────────────\n")

	var tool6 = ToolConfig.get_tool(6)

	print("Tool 6 definition:")
	print("  Name: %s" % tool6.get("name", "MISSING"))
	print("  Emoji: %s" % tool6.get("emoji", "MISSING"))
	print("  Q action: %s" % tool6.get("Q", {}).get("action", "MISSING"))
	print("  E action: %s" % tool6.get("E", {}).get("action", "MISSING"))
	print("  R action: %s" % tool6.get("R", {}).get("action", "MISSING"))

	assert(tool6.get("name") == "Biome", "Tool 6 name should be 'Biome'")
	assert(tool6.get("emoji") == "🌍", "Tool 6 emoji should be 🌍")
	assert(tool6.get("Q", {}).get("action") == "submenu_biome_assign", "Q should open biome_assign submenu")
	assert(tool6.get("E", {}).get("action") == "clear_biome_assignment", "E should clear assignment")
	assert(tool6.get("R", {}).get("action") == "inspect_plot", "R should inspect plot")

	print("\n✅ PASS: Tool 6 configured correctly")


func _test_2_dynamic_submenu(farm):
	"""Test 2: Dynamic submenu generation"""
	print("\n──────────────────────────────────────────────────────────────────────")
	print("TEST 2: Dynamic Submenu Generation")
	print("──────────────────────────────────────────────────────────────────────\n")

	var submenu = ToolConfig.get_dynamic_submenu("biome_assign", farm)

	print("Generated biome_assign submenu:")
	print("  Q: %s %s (%s)" % [
		submenu.get("Q", {}).get("emoji", ""),
		submenu.get("Q", {}).get("label", ""),
		submenu.get("Q", {}).get("action", "")
	])
	print("  E: %s %s (%s)" % [
		submenu.get("E", {}).get("emoji", ""),
		submenu.get("E", {}).get("label", ""),
		submenu.get("E", {}).get("action", "")
	])
	print("  R: %s %s (%s)" % [
		submenu.get("R", {}).get("emoji", ""),
		submenu.get("R", {}).get("label", ""),
		submenu.get("R", {}).get("action", "")
	])

	# Verify actions reference registered biomes
	var q_action = submenu.get("Q", {}).get("action", "")
	var e_action = submenu.get("E", {}).get("action", "")
	var r_action = submenu.get("R", {}).get("action", "")

	assert(q_action.begins_with("assign_to_"), "Q action should be assign_to_*")
	assert(e_action.begins_with("assign_to_"), "E action should be assign_to_*")
	assert(r_action.begins_with("assign_to_"), "R action should be assign_to_*")

	# Extract biome names
	var q_biome = q_action.replace("assign_to_", "")
	var e_biome = e_action.replace("assign_to_", "")
	var r_biome = r_action.replace("assign_to_", "")

	print("\nBiomes mapped to buttons:")
	print("  Q → %s" % q_biome)
	print("  E → %s" % e_biome)
	print("  R → %s" % r_biome)

	# Verify biomes exist in registry
	assert(farm.grid.biomes.has(q_biome), "Q biome should exist in registry")
	assert(farm.grid.biomes.has(e_biome), "E biome should exist in registry")
	assert(farm.grid.biomes.has(r_biome), "R biome should exist in registry")

	print("\n✅ PASS: Dynamic submenu generated correctly")


func _test_3_plot_assignment(farm, input_handler):
	"""Test 3: Plot reassignment"""
	print("\n──────────────────────────────────────────────────────────────────────")
	print("TEST 3: Plot Reassignment")
	print("──────────────────────────────────────────────────────────────────────\n")

	var test_plot = Vector2i(0, 0)
	var original_biome = farm.grid.plot_biome_assignments.get(test_plot, "Unknown")

	print("Test plot: %s" % test_plot)
	print("Original biome: %s" % original_biome)

	# Reassign to different biome
	var target_biome = "Market"
	if original_biome == "Market":
		target_biome = "BioticFlux"

	print("\nReassigning to: %s" % target_biome)
	input_handler._action_assign_plots_to_biome([test_plot], target_biome)

	# Verify change
	var new_biome = farm.grid.plot_biome_assignments.get(test_plot, "Unknown")
	print("New biome: %s" % new_biome)

	assert(new_biome == target_biome, "Biome should have changed to %s" % target_biome)

	print("\n✅ PASS: Plot reassignment works")

	# Restore original
	print("\nRestoring original biome...")
	input_handler._action_assign_plots_to_biome([test_plot], original_biome)
	var restored = farm.grid.plot_biome_assignments.get(test_plot, "Unknown")
	assert(restored == original_biome, "Should restore to original biome")
	print("✅ Restored to: %s" % restored)


func _test_4_plot_inspection(farm, input_handler):
	"""Test 4: Plot inspection"""
	print("\n──────────────────────────────────────────────────────────────────────")
	print("TEST 4: Plot Inspection")
	print("──────────────────────────────────────────────────────────────────────\n")

	var test_plot = Vector2i(0, 0)

	print("Inspecting plot %s...\n" % test_plot)
	input_handler._action_inspect_plot([test_plot])

	print("\n✅ PASS: Inspection completed without errors")
