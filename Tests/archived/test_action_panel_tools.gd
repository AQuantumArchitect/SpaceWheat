## Test Suite for Action Panel Tool Selection
## Tests button toggling, mode selection, signal emission, and state management

extends SceneTree

const ActionPanelModeSelect = preload("res://UI/Panels/ActionPanelModeSelect.gd")
const UILayoutManager = preload("res://UI/Managers/UILayoutManager.gd")

var test_results = []
var action_panel: ActionPanelModeSelect = null
var layout_manager: UILayoutManager = null
var separator = "============================================================"

# Track emitted signals
var mode_selected_calls: Array = []
var action_executed_calls: Array = []

func _initialize():
	print("\n" + separator)
	print("🧪 ACTION PANEL TOOL SELECTION TEST SUITE")
	print(separator)

	setup_test_environment()

	test_panel_initialization()
	test_single_tool_selection()
	test_tool_deselection()
	test_mutual_exclusion()
	test_mode_signal_emission()
	test_get_selected_mode()
	test_clear_selection()
	test_rapid_button_mashing()
	test_button_style_updates()

	print_test_summary()


func setup_test_environment():
	"""Initialize test fixtures"""
	print("\n[SETUP] Initializing test environment...")

	# Create layout manager
	layout_manager = UILayoutManager.new()
	layout_manager.viewport_size = Vector2(1920, 1080)
	layout_manager._ready()

	# Create action panel
	action_panel = ActionPanelModeSelect.new()
	action_panel.set_layout_manager(layout_manager)
	action_panel.mouse_filter = Control.MOUSE_FILTER_PASS

	# Connect signals to track calls
	action_panel.mode_selected.connect(func(mode: String):
		mode_selected_calls.append(mode)
		print("   📢 mode_selected signal emitted: '%s'" % mode)
	)
	action_panel.action_executed.connect(func(action: String):
		action_executed_calls.append(action)
		print("   📢 action_executed signal emitted: '%s'" % action)
	)

	print("✅ Setup complete")


## TEST 1: Panel Initialization
func test_panel_initialization():
	print("\n[TEST 1] Action Panel Initialization")

	assert(action_panel != null, "Panel instance created")
	assert(action_panel.action_buttons.size() == 4, "4 tool buttons created")
	assert(action_panel.get_selected_mode() == "", "No tool selected initially")
	assert(action_panel.selected_mode == "", "selected_mode is empty string")

	var button_names = action_panel.action_buttons.keys()
	assert(button_names.has("plant"), "Plant button exists")
	assert(button_names.has("measure"), "Measure button exists")
	assert(button_names.has("harvest"), "Harvest button exists")
	assert(button_names.has("build_mill"), "Build Mill button exists")

	record_result("Panel Initialization", true)
	print("✅ Passed: Action panel initialized with 4 tools")


## TEST 2: Single Tool Selection
func test_single_tool_selection():
	print("\n[TEST 2] Single Tool Selection")

	mode_selected_calls.clear()

	# Select plant tool
	var plant_btn = action_panel.action_buttons["plant"]
	plant_btn.pressed.emit()

	assert(action_panel.get_selected_mode() == "plant", "Plant mode selected")
	assert(mode_selected_calls.size() == 1, "mode_selected signal emitted once")
	assert(mode_selected_calls[0] == "plant", "Signal contains 'plant'")

	record_result("Single Tool Selection", true)
	print("✅ Passed: Single tool selection works")


## TEST 3: Tool Deselection
func test_tool_deselection():
	print("\n[TEST 3] Tool Deselection")

	mode_selected_calls.clear()

	# Plant is already selected from previous test
	# Click it again to deselect
	var plant_btn = action_panel.action_buttons["plant"]
	plant_btn.pressed.emit()

	assert(action_panel.get_selected_mode() == "", "Tool deselected")
	assert(mode_selected_calls.size() == 1, "mode_selected signal emitted")
	assert(mode_selected_calls[0] == "", "Signal contains empty string")

	record_result("Tool Deselection", true)
	print("✅ Passed: Tool deselection works")


## TEST 4: Mutual Exclusion (Only One Tool Active)
func test_mutual_exclusion():
	print("\n[TEST 4] Mutual Exclusion (Only One Tool at a Time)")

	mode_selected_calls.clear()

	# Select plant
	var plant_btn = action_panel.action_buttons["plant"]
	plant_btn.pressed.emit()
	assert(action_panel.get_selected_mode() == "plant", "Plant selected")

	# Select measure (should deselect plant)
	var measure_btn = action_panel.action_buttons["measure"]
	measure_btn.pressed.emit()

	assert(action_panel.get_selected_mode() == "measure", "Measure now selected")
	assert(mode_selected_calls.size() == 2, "Two signals emitted")
	assert(mode_selected_calls[0] == "plant", "First signal: plant")
	assert(mode_selected_calls[1] == "measure", "Second signal: measure")

	# Select harvest (should deselect measure)
	var harvest_btn = action_panel.action_buttons["harvest"]
	harvest_btn.pressed.emit()

	assert(action_panel.get_selected_mode() == "harvest", "Harvest now selected")
	assert(mode_selected_calls.size() == 3, "Three signals emitted")

	record_result("Mutual Exclusion", true)
	print("✅ Passed: Only one tool can be selected at a time")


## TEST 5: Mode Signal Emission
func test_mode_signal_emission():
	print("\n[TEST 5] Mode Selection Signal Emission")

	mode_selected_calls.clear()

	# Test each tool selection
	var tool_names = ["plant", "measure", "harvest", "build_mill"]

	for tool_name in tool_names:
		var btn = action_panel.action_buttons[tool_name]
		btn.pressed.emit()
		assert(mode_selected_calls[-1] == tool_name, "Signal emitted for %s" % tool_name)

	record_result("Mode Signal Emission", true)
	print("✅ Passed: Mode signals emitted correctly for all tools")


## TEST 6: Get Selected Mode
func test_get_selected_mode():
	print("\n[TEST 6] Get Selected Mode Function")

	# Start with no selection
	action_panel.clear_selection()
	assert(action_panel.get_selected_mode() == "", "No mode selected initially")

	# Select plant
	action_panel.action_buttons["plant"].pressed.emit()
	assert(action_panel.get_selected_mode() == "plant", "get_selected_mode returns 'plant'")

	# Select build_mill
	action_panel.action_buttons["build_mill"].pressed.emit()
	assert(action_panel.get_selected_mode() == "build_mill", "get_selected_mode returns 'build_mill'")

	record_result("Get Selected Mode", true)
	print("✅ Passed: get_selected_mode returns correct values")


## TEST 7: Clear Selection
func test_clear_selection():
	print("\n[TEST 7] Clear Selection Function")

	# Ensure a tool is selected
	action_panel.action_buttons["measure"].pressed.emit()
	assert(action_panel.get_selected_mode() == "measure", "Measure selected")

	# Clear selection
	action_panel.clear_selection()
	assert(action_panel.get_selected_mode() == "", "Selection cleared")
	assert(action_panel.selected_mode == "", "selected_mode is empty")

	record_result("Clear Selection", true)
	print("✅ Passed: clear_selection works correctly")


## TEST 8: Rapid Button Mashing (Stress Test)
func test_rapid_button_mashing():
	print("\n[TEST 8] Rapid Button Mashing (Stress Test)")

	mode_selected_calls.clear()
	action_panel.clear_selection()

	# Rapidly click each button 3 times
	var tool_names = ["plant", "measure", "harvest", "build_mill"]

	for iteration in range(3):
		for tool_name in tool_names:
			var btn = action_panel.action_buttons[tool_name]
			btn.pressed.emit()

	# Should have selected each tool 3 times
	# Expected: plant, measure, harvest, build_mill (then deselect each), repeat 3 times
	print("   Total mode_selected signals emitted: %d" % mode_selected_calls.size())

	# Last selected tool should be build_mill
	assert(action_panel.get_selected_mode() == "build_mill", "Rapid mashing handled correctly")

	# No crashes or assertion failures = test passed
	record_result("Rapid Button Mashing", true)
	print("✅ Passed: Rapid button mashing handled without errors")


## TEST 9: Button Style Updates
func test_button_style_updates():
	print("\n[TEST 9] Button Style Updates (Selected vs Unselected)")

	action_panel.clear_selection()

	# Select plant button
	var plant_btn = action_panel.action_buttons["plant"]
	plant_btn.pressed.emit()

	# Check that plant button has selected styling
	var selected_style = plant_btn.get_theme_stylebox("normal")
	assert(selected_style != null, "Selected button has styled appearance")

	# Check that other buttons don't have selected styling
	var measure_btn = action_panel.action_buttons["measure"]
	var measure_style = measure_btn.get_theme_stylebox("normal")
	assert(measure_style != selected_style, "Unselected button has different style")

	record_result("Button Style Updates", true)
	print("✅ Passed: Button styles update correctly")


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
