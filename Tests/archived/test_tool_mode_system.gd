extends Node

## Test: Tool Mode System (Keyboard Input + Farm Actions)
## Simulates keyboard input and verifies complete game flow

var farm  # Farm instance (typed dynamically to avoid parse issues)
var input_handler  # FarmInputHandler instance
var test_results: Dictionary = {}

func _ready():
	print("\n" + _repeat_string("=", 70))
	print("🎮 TOOL MODE SYSTEM TEST - Headless Game Simulation")
	print(_repeat_string("=", 70))

	# Test 1: Component instantiation
	test_component_creation()

	# Test 2: Tool switching
	test_tool_switching()

	# Test 3: Location selection
	test_location_selection()

	# Test 4: Complete game flow
	test_complete_game_flow()

	# Test 5: Multi-tool operations
	test_multi_tool_operations()

	# Print results
	print_test_results()

	get_tree().quit()


func test_component_creation():
	"""Test: Instantiate Farm and FarmInputHandler"""
	print("\n" + _repeat_string("-", 70))
	print("TEST 1: Component Creation")
	print(_repeat_string("-", 70))

	# Load classes
	var FarmClass = load("res://Core/Farm.gd")
	var FarmInputHandlerClass = load("res://UI/FarmInputHandler.gd")

	if not FarmClass or not FarmInputHandlerClass:
		print("❌ Failed to load Farm or FarmInputHandler classes")
		test_results["Component Creation"] = false
		return

	# Create Farm
	farm = FarmClass.new()
	add_child(farm)

	# Create FarmInputHandler
	input_handler = FarmInputHandlerClass.new()
	add_child(input_handler)
	input_handler.farm = farm
	input_handler.grid_width = farm.grid_width
	input_handler.grid_height = farm.grid_height

	# Connect signals for monitoring
	input_handler.action_performed.connect(_on_action_performed)
	input_handler.selection_changed.connect(_on_selection_changed)
	input_handler.tool_changed.connect(_on_tool_changed)
	farm.action_result.connect(_on_farm_action_result)

	print("✅ Farm created")
	print("✅ FarmInputHandler created")
	print("✅ Signals connected")
	test_results["Component Creation"] = true


func test_tool_switching():
	"""Test: Switch between tools 1-3 and verify actions"""
	print("\n" + _repeat_string("-", 70))
	print("TEST 2: Tool Switching")
	print(_repeat_string("-", 70))

	var success = true

	# Test Tool 1: Plant
	print("\n→ Switching to Tool 1 (Plant)...")
	_simulate_key_press(KEY_1)
	await get_tree().process_frame
	if input_handler.current_tool == 1:
		print("✅ Tool 1 selected: Plant")
	else:
		print("❌ Tool 1 selection failed")
		success = false

	# Test Tool 2: Quantum Ops
	print("→ Switching to Tool 2 (Quantum Ops)...")
	_simulate_key_press(KEY_2)
	await get_tree().process_frame
	if input_handler.current_tool == 2:
		print("✅ Tool 2 selected: Quantum Ops")
	else:
		print("❌ Tool 2 selection failed")
		success = false

	# Test Tool 3: Economy
	print("→ Switching to Tool 3 (Economy)...")
	_simulate_key_press(KEY_3)
	await get_tree().process_frame
	if input_handler.current_tool == 3:
		print("✅ Tool 3 selected: Economy")
	else:
		print("❌ Tool 3 selection failed")
		success = false

	test_results["Tool Switching"] = success


func test_location_selection():
	"""Test: Select locations with WASD and YUIOP"""
	print("\n" + _repeat_string("-", 70))
	print("TEST 3: Location Selection")
	print(_repeat_string("-", 70))

	var success = true

	# Test YUIOP quick-select
	print("\n→ Testing YUIOP quick-select...")
	_simulate_key_press(KEY_Y)
	await get_tree().process_frame
	if input_handler.current_selection == Vector2i(0, 0):
		print("✅ Y selected location (0, 0)")
	else:
		print("❌ Y selection failed: got %s" % input_handler.current_selection)
		success = false

	_simulate_key_press(KEY_U)
	await get_tree().process_frame
	if input_handler.current_selection == Vector2i(1, 0):
		print("✅ U selected location (1, 0)")
	else:
		print("❌ U selection failed: got %s" % input_handler.current_selection)
		success = false

	# Test WASD movement
	print("\n→ Testing WASD movement...")
	_simulate_key_press(KEY_D)  # Move right
	await get_tree().process_frame
	if input_handler.current_selection == Vector2i(2, 0):
		print("✅ D moved right to (2, 0)")
	else:
		print("❌ D movement failed: got %s" % input_handler.current_selection)
		success = false

	_simulate_key_press(KEY_A)  # Move left
	await get_tree().process_frame
	if input_handler.current_selection == Vector2i(1, 0):
		print("✅ A moved left to (1, 0)")
	else:
		print("❌ A movement failed: got %s" % input_handler.current_selection)
		success = false

	test_results["Location Selection"] = success


func test_complete_game_flow():
	"""Test: Complete gameplay loop (Plant → Measure → Harvest → Sell)"""
	print("\n" + _repeat_string("-", 70))
	print("TEST 4: Complete Game Flow")
	print(_repeat_string("-", 70))

	var success = true
	var current_credits = farm.economy.credits

	# Step 1: Switch to Plant tool
	print("\n→ STEP 1: Select Plant tool...")
	_simulate_key_press(KEY_1)
	if input_handler.current_tool == 1:
		print("✅ Plant tool active")
	else:
		print("❌ Plant tool failed")
		success = false

	# Step 2: Select location
	print("→ STEP 2: Select location (0,0)...")
	_simulate_key_press(KEY_Y)
	if input_handler.current_selection == Vector2i(0, 0):
		print("✅ Location selected")
	else:
		print("❌ Location selection failed")
		success = false

	# Step 3: Plant wheat (Q action)
	print("→ STEP 3: Plant Wheat (Q action)...")
	_simulate_key_press(KEY_Q)
	await get_tree().process_frame  # Wait for async operations

	var plot = farm.get_plot(Vector2i(0, 0))
	if plot and plot.is_planted:
		print("✅ Wheat planted at (0,0)")
		print("   Credits spent: %d → %d" % [current_credits, farm.economy.credits])
	else:
		print("❌ Plant failed")
		success = false

	# Step 4: Measure quantum state
	print("\n→ STEP 4: Switch to Quantum tool...")
	_simulate_key_press(KEY_2)
	if input_handler.current_tool == 2:
		print("✅ Quantum tool active")
	else:
		success = false

	print("→ STEP 5: Measure plot (E action)...")
	_simulate_key_press(KEY_E)
	await get_tree().process_frame

	if plot and plot.is_measured:
		print("✅ Plot measured - state collapsed")
	else:
		print("❌ Measure failed")
		success = false

	# Step 6: Harvest
	print("→ STEP 6: Harvest plot (R action)...")
	_simulate_key_press(KEY_R)
	await get_tree().process_frame

	if farm.economy.wheat_inventory > 0:
		print("✅ Harvested! Wheat inventory: %d" % farm.economy.wheat_inventory)
	else:
		print("⚠️  No wheat harvested (may be detritus/labor outcome)")

	test_results["Complete Game Flow"] = success


func test_multi_tool_operations():
	"""Test: Plant multiple crops and test Economy tool"""
	print("\n" + _repeat_string("-", 70))
	print("TEST 5: Multi-Tool Operations")
	print(_repeat_string("-", 70))

	var success = true
	var initial_credits = farm.economy.credits

	# Plant mushroom at location 1
	print("\n→ Plant Mushroom at location 1...")
	_simulate_key_press(KEY_1)  # Plant tool
	_simulate_key_press(KEY_U)  # Location (1,0)
	_simulate_key_press(KEY_E)  # Mushroom (E action in Plant tool)
	await get_tree().process_frame

	var plot1 = farm.get_plot(Vector2i(1, 0))
	if plot1 and plot1.is_planted:
		print("✅ Mushroom planted at (1,0)")
	else:
		print("❌ Mushroom plant failed")
		success = false

	# Plant tomato at location 2
	print("→ Plant Tomato (Ultimate!) at location 2...")
	_simulate_key_press(KEY_I)  # Location (2,0)
	_simulate_key_press(KEY_R)  # Tomato (R action in Plant tool)
	await get_tree().process_frame

	var plot2 = farm.get_plot(Vector2i(2, 0))
	if plot2 and plot2.is_planted:
		print("✅ Tomato planted at (2,0)")
	else:
		print("❌ Tomato plant failed")
		success = false

	# Test Economy tool - Sell All
	print("\n→ Test Economy tool (Sell All)...")
	_simulate_key_press(KEY_3)  # Economy tool
	if input_handler.current_tool == 3:
		print("✅ Economy tool active (sell all available)")
	else:
		success = false

	print("\n✅ Multi-tool operations complete")
	test_results["Multi-Tool Operations"] = success


## Signal Handlers - For monitoring

func _on_action_performed(action: String, success: bool, message: String):
	"""Monitor action_performed signal"""
	if success:
		print("   📊 Action: %s → %s" % [action, message])


func _on_selection_changed(pos: Vector2i):
	"""Monitor selection_changed signal"""
	print("   📍 Selection: %s" % pos)


func _on_tool_changed(tool_num: int, tool_info: Dictionary):
	"""Monitor tool_changed signal"""
	var tool_name = tool_info.get("name", "?")
	print("   🛠️  Tool Changed: %d (%s)" % [tool_num, tool_name])


func _on_farm_action_result(action: String, success: bool, message: String):
	"""Monitor Farm action_result signal"""
	if not success:
		print("   ⚠️  Farm result: %s" % message)


## Utilities

func _simulate_key_press(keycode: int):
	"""Simulate a keyboard key press"""
	var event = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)


func _repeat_string(text: String, count: int) -> String:
	"""Repeat a string N times (replacement for 'text * N' syntax)"""
	var result = ""
	for i in range(count):
		result += text
	return result


func print_test_results():
	"""Print summary of all test results"""
	print("\n" + _repeat_string("=", 70))
	print("📊 TEST RESULTS SUMMARY")
	print(_repeat_string("=", 70))

	var passed = 0
	var failed = 0

	for test_name in test_results.keys():
		var result = test_results[test_name]
		if result:
			print("✅ %s" % test_name)
			passed += 1
		else:
			print("❌ %s" % test_name)
			failed += 1

	print("\n" + _repeat_string("-", 70))
	print("TOTAL: %d passed, %d failed (out of %d tests)" % [passed, failed, passed + failed])

	if failed == 0:
		print("\n🎉 ALL TESTS PASSED!")
	else:
		print("\n⚠️  Some tests failed - see details above")

	print(_repeat_string("=", 70) + "\n")
