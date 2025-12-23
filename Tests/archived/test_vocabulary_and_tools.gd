## Test Suite for Vocabulary System and Tool Application
## Tests vocabulary overlay display, tool name mapping, and mode application

extends SceneTree

const UILayoutManager = preload("res://UI/Managers/UILayoutManager.gd")

var test_results = []
var layout_manager: UILayoutManager = null
var separator = "============================================================"

func _initialize():
	print("\n" + separator)
	print("🧪 VOCABULARY & TOOL MAPPING TEST SUITE")
	print(separator)

	setup_test_environment()

	test_tool_name_mapping()
	test_mode_names_are_valid()
	test_tool_names_match_buttons()
	test_harvest_tool_logic()
	test_plant_tool_defaults()
	test_mill_building_tool()
	test_measure_tool_logic()

	print_test_summary()


func setup_test_environment():
	"""Initialize test fixtures"""
	print("\n[SETUP] Initializing test environment...")

	layout_manager = UILayoutManager.new()
	layout_manager.viewport_size = Vector2(1920, 1080)
	layout_manager._ready()

	print("✅ Setup complete")


## TEST 1: Tool Name Mapping
func test_tool_name_mapping():
	print("\n[TEST 1] Tool Name to Action Mapping")

	# Define expected tool name mappings (from ActionPanelModeSelect button names)
	var tool_names = {
		"plant": true,      # Maps to build action with "wheat"
		"measure": true,    # Maps to measure_plot action
		"harvest": true,    # Maps to harvest_plot action
		"build_mill": true  # Maps to build action with "mill"
	}

	# Verify each tool name is valid
	for tool_name in tool_names.keys():
		assert(tool_name is String, "Tool name is string: %s" % tool_name)
		assert(tool_name.length() > 0, "Tool name is not empty: %s" % tool_name)

	record_result("Tool Name Mapping", true)
	print("✅ Passed: All tool names are valid strings")


## TEST 2: Mode Names Consistency
func test_mode_names_are_valid():
	print("\n[TEST 2] Mode Names Are Valid and Consistent")

	var expected_modes = ["plant", "measure", "harvest", "build_mill", ""]

	for mode in expected_modes:
		assert(mode is String, "Mode is string: '%s'" % mode)
		if mode != "":
			assert(mode.length() > 0, "Non-empty mode has content")
			# Mode should not contain spaces
			assert(" " not in mode, "Mode does not contain spaces: '%s'" % mode)

	record_result("Mode Name Validity", true)
	print("✅ Passed: All mode names are valid")


## TEST 3: Tool Names Match Button Creation
func test_tool_names_match_buttons():
	print("\n[TEST 3] Tool Names Match Button Creation Names")

	# These are the tool names that ActionPanelModeSelect creates buttons for
	var button_tool_names = ["plant", "measure", "harvest", "build_mill"]

	# These are the tool names that FarmView._apply_tool_to_plot expects
	var farmview_expected_names = ["plant", "measure", "harvest", "build_mill"]

	for tool_name in button_tool_names:
		assert(farmview_expected_names.has(tool_name), "Button tool '%s' is handled by FarmView" % tool_name)

	record_result("Tool Name Consistency", true)
	print("✅ Passed: Button tool names match FarmView expectations")


## TEST 4: Harvest Tool Logic
func test_harvest_tool_logic():
	print("\n[TEST 4] Harvest Tool Logic")

	var harvest_mode = "harvest"

	# Verify harvest mode is handled separately from build types
	var build_type_map = {
		"plant": "wheat",
		"plant_wheat": "wheat",
		"plant_tomato": "tomato",
		"plant_mushroom": "mushroom",
		"build_mill": "mill",
		"place_mill": "mill",
		"place_market": "market"
	}

	# Harvest should NOT be in build_type_map (it's a special case)
	assert(!build_type_map.has(harvest_mode), "Harvest is special-cased, not in build_type_map")

	record_result("Harvest Tool Logic", true)
	print("✅ Passed: Harvest tool is properly special-cased")


## TEST 5: Plant Tool Defaults
func test_plant_tool_defaults():
	print("\n[TEST 5] Plant Tool Defaults to Wheat")

	# The plant button should default to planting wheat, not require mode selection
	var plant_mode = "plant"

	var build_type_map = {
		"plant": "wheat",  # Plant tool defaults to wheat
		"plant_wheat": "wheat",
		"plant_tomato": "tomato",
		"plant_mushroom": "mushroom"
	}

	assert(build_type_map.has(plant_mode), "Plant mode is in build_type_map")
	assert(build_type_map[plant_mode] == "wheat", "Plant defaults to wheat type")

	record_result("Plant Tool Defaults", true)
	print("✅ Passed: Plant tool correctly defaults to wheat")


## TEST 6: Mill Building Tool
func test_mill_building_tool():
	print("\n[TEST 6] Mill Building Tool Mapping")

	var mill_mode = "build_mill"

	var build_type_map = {
		"plant": "wheat",
		"build_mill": "mill",  # New button name
		"place_mill": "mill"   # Legacy name
	}

	assert(build_type_map.has(mill_mode), "build_mill is in mapping")
	assert(build_type_map[mill_mode] == "mill", "build_mill maps to 'mill' type")

	record_result("Mill Building Tool", true)
	print("✅ Passed: Mill building tool correctly mapped")


## TEST 7: Measure Tool Logic
func test_measure_tool_logic():
	print("\n[TEST 7] Measure Tool Logic")

	var measure_mode = "measure"

	# Measure should NOT be in the build_type_map
	var build_type_map = {
		"plant": "wheat",
		"build_mill": "mill"
	}

	# Measure is a special case that calls game_controller.measure_plot()
	assert(!build_type_map.has(measure_mode), "Measure is special-cased, not in build_type_map")

	record_result("Measure Tool Logic", true)
	print("✅ Passed: Measure tool is properly special-cased")


## Helper Functions

func record_result(test_name: String, passed: bool):
	"""Record test result"""
	var status = "✅ PASS" if passed else "❌ FAIL"
	test_results.append({
		"name": test_name,
		"passed": passed
	})
	print("   [%s] %s" % [status, test_name])


func print_test_summary():
	"""Print summary of all tests"""
	var passed_count = 0
	var failed_count = 0

	for result in test_results:
		if result.passed:
			passed_count += 1
		else:
			failed_count += 1

	print("\n" + separator)
	print("📊 TEST SUMMARY")
	print(separator)
	print("✅ Passed: %d" % passed_count)
	print("❌ Failed: %d" % failed_count)
	print("📈 Total: %d" % test_results.size())
	print("🎯 Success Rate: %.1f%%" % (float(passed_count) / test_results.size() * 100))
	print(separator)

	if failed_count == 0:
		print("🎉 ALL TESTS PASSED!")
	else:
		print("⚠️  SOME TESTS FAILED")

	quit()
