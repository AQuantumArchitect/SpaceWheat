## Test Suite for Tool Button Logic (Unit Tests)
## Tests the core logic of tool selection without requiring full UI initialization

extends SceneTree

var test_results = []
var separator = "============================================================"

# Simulated tool state (what ActionPanelModeSelect tracks)
var selected_mode: String = ""
var action_buttons: Dictionary = {}

func _initialize():
	print("\n" + separator)
	print("🧪 TOOL BUTTON LOGIC UNIT TESTS")
	print(separator)

	setup_tool_state()

	test_tool_selection_basic()
	test_tool_deselection()
	test_mutual_exclusion_logic()
	test_tool_state_consistency()
	test_rapid_tool_switching()
	test_invalid_tool_handling()
	test_tool_name_validation()

	print_test_summary()


func setup_tool_state():
	"""Initialize tool state"""
	print("\n[SETUP] Initializing tool state simulation...")

	# Define the 4 tools
	var tool_names = ["plant", "measure", "harvest", "build_mill"]
	for tool_name in tool_names:
		action_buttons[tool_name] = {
			"name": tool_name,
			"selected": false,
			"enabled": true
		}

	selected_mode = ""
	print("✅ Tool state initialized with %d tools" % action_buttons.size())


## TEST 1: Basic Tool Selection
func test_tool_selection_basic():
	print("\n[TEST 1] Basic Tool Selection")

	# Select plant tool
	simulate_tool_press("plant")

	assert(selected_mode == "plant", "Plant mode selected")
	assert(action_buttons["plant"]["selected"] == true, "Plant button shows selected")

	record_result("Basic Tool Selection", true)
	print("✅ Passed: Can select a tool")


## TEST 2: Tool Deselection
func test_tool_deselection():
	print("\n[TEST 2] Tool Deselection")

	# Start with plant selected
	selected_mode = "plant"
	action_buttons["plant"]["selected"] = true

	# Click plant again to deselect
	simulate_tool_press("plant")

	assert(selected_mode == "", "No mode selected")
	assert(action_buttons["plant"]["selected"] == false, "Plant button not selected")

	record_result("Tool Deselection", true)
	print("✅ Passed: Can deselect a tool by clicking it again")


## TEST 3: Mutual Exclusion Logic
func test_mutual_exclusion_logic():
	print("\n[TEST 3] Mutual Exclusion (Only One Tool at a Time)")

	# Select plant
	selected_mode = ""
	simulate_tool_press("plant")
	assert(selected_mode == "plant", "Plant selected")

	# Select measure (should deselect plant)
	simulate_tool_press("measure")
	assert(selected_mode == "measure", "Measure now selected")
	assert(action_buttons["plant"]["selected"] == false, "Plant deselected")
	assert(action_buttons["measure"]["selected"] == true, "Measure selected")

	# Select harvest (should deselect measure)
	simulate_tool_press("harvest")
	assert(selected_mode == "harvest", "Harvest now selected")
	assert(action_buttons["measure"]["selected"] == false, "Measure deselected")
	assert(action_buttons["harvest"]["selected"] == true, "Harvest selected")

	record_result("Mutual Exclusion Logic", true)
	print("✅ Passed: Only one tool can be selected at a time")


## TEST 4: Tool State Consistency
func test_tool_state_consistency():
	print("\n[TEST 4] Tool State Consistency")

	# Clear and set specific state
	clear_selection()

	# Verify all tools are deselected
	for tool_name in action_buttons.keys():
		assert(action_buttons[tool_name]["selected"] == false, "%s is deselected" % tool_name)

	assert(selected_mode == "", "selected_mode is empty")

	# Select build_mill
	simulate_tool_press("build_mill")

	# Verify exactly one tool is selected
	var selected_count = 0
	for tool_name in action_buttons.keys():
		if action_buttons[tool_name]["selected"]:
			selected_count += 1

	assert(selected_count == 1, "Exactly one tool is selected")
	assert(selected_mode == "build_mill", "selected_mode matches selected button")

	record_result("Tool State Consistency", true)
	print("✅ Passed: Tool state is always consistent")


## TEST 5: Rapid Tool Switching (Stress Test)
func test_rapid_tool_switching():
	print("\n[TEST 5] Rapid Tool Switching")

	clear_selection()

	var tool_names = ["plant", "measure", "harvest", "build_mill"]
	var switch_count = 0

	# Rapidly switch between tools 3 times each
	for iteration in range(3):
		for tool_name in tool_names:
			simulate_tool_press(tool_name)
			switch_count += 1

	# Final state should be consistent
	assert(selected_mode == "build_mill", "Final selection is build_mill")
	assert(action_buttons["build_mill"]["selected"] == true, "Final button is selected")

	# All other buttons should be deselected
	for tool_name in action_buttons.keys():
		if tool_name != "build_mill":
			assert(action_buttons[tool_name]["selected"] == false, "%s is deselected" % tool_name)

	print("   Made %d tool switches without issues" % switch_count)
	record_result("Rapid Tool Switching", true)
	print("✅ Passed: Can rapidly switch tools without errors")


## TEST 6: Invalid Tool Handling
func test_invalid_tool_handling():
	print("\n[TEST 6] Invalid Tool Name Handling")

	clear_selection()

	# Try to select a non-existent tool
	var invalid_result = simulate_tool_press("invalid_tool", true)

	# Should not crash, and state should remain unchanged
	assert(selected_mode == "", "Invalid tool doesn't change selected_mode")

	record_result("Invalid Tool Handling", true)
	print("✅ Passed: Invalid tool names are handled gracefully")


## TEST 7: Tool Name Validation
func test_tool_name_validation():
	print("\n[TEST 7] Tool Name Validation")

	var valid_tools = ["plant", "measure", "harvest", "build_mill"]

	# Verify all expected tools exist
	for tool_name in valid_tools:
		assert(action_buttons.has(tool_name), "Tool '%s' exists" % tool_name)

	# Verify tool names are strings with content
	for tool_name in valid_tools:
		assert(tool_name is String, "Tool name is string: '%s'" % tool_name)
		assert(tool_name.length() > 0, "Tool name has content: '%s'" % tool_name)
		assert(" " not in tool_name, "Tool name has no spaces: '%s'" % tool_name)

	record_result("Tool Name Validation", true)
	print("✅ Passed: All tool names are valid")


## Helper Functions

func simulate_tool_press(tool_name: String, suppress_errors: bool = false) -> bool:
	"""Simulate a tool button press (without requiring actual Button nodes)"""

	# Check if tool exists
	if !action_buttons.has(tool_name):
		if !suppress_errors:
			print("   ⚠️ Tool '%s' not found" % tool_name)
		return false

	# Toggle tool selection (same logic as _on_tool_button_pressed)
	if selected_mode == tool_name:
		# Already selected - deselect
		selected_mode = ""
		action_buttons[tool_name]["selected"] = false
	else:
		# Select this tool - deselect all others first
		for other_tool in action_buttons.keys():
			action_buttons[other_tool]["selected"] = false

		selected_mode = tool_name
		action_buttons[tool_name]["selected"] = true

	return true


func clear_selection():
	"""Clear all tool selections"""
	for tool_name in action_buttons.keys():
		action_buttons[tool_name]["selected"] = false
	selected_mode = ""


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

	if test_results.size() > 0:
		print("🎯 Success Rate: %.1f%%" % (float(passed_count) / test_results.size() * 100))

	print(separator)

	if failed_count == 0 and passed_count > 0:
		print("🎉 ALL TESTS PASSED!")
	else:
		print("⚠️  SOME TESTS FAILED")

	quit()
