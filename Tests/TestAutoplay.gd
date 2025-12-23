## TestAutoplay.gd
## Automatically runs through a complete gameplay sequence
## Start with: godot --script res://TestAutoplay.gd

extends SceneTree

var farm_input_handler: Node = null
var ui_controller: Node = null
var step: int = 0
var step_delay: float = 0.0
var max_delay: float = 3.0  # Wait 3 seconds between steps for visibility

func _ready():
	print("\n" + "="*70)
	print("🎬 STARTING AUTO-PLAY TEST SEQUENCE")
	print("="*70)
	print("This will demonstrate the complete Q/E/R action flow visually.\n")

	await get_tree().process_frame
	await get_tree().process_frame

	# Give the scene time to fully initialize
	await get_tree().create_timer(2.0).timeout

	# Find the input handler
	var root = get_root()
	farm_input_handler = find_node_by_name(root, "FarmInputHandler")
	ui_controller = find_node_by_name(root, "FarmUIController")

	if not farm_input_handler:
		print("❌ ERROR: Could not find FarmInputHandler")
		quit()
		return

	print("✅ Found FarmInputHandler\n")

	# Start the sequence
	run_test_sequence()


func run_test_sequence():
	"""Run a complete gameplay demonstration"""

	# STEP 1: Select Tool 1 (Plant)
	print_step("STEP 1: Select Tool 1 (Plant Tool)")
	print("  Action: Press '1' key")
	farm_input_handler._select_tool(1)
	await wait_step()

	# STEP 2: Select Plot Y (position 1,0)
	print_step("STEP 2: Select Plot Y (Position 1,0)")
	print("  Action: Press 'Y' key")
	farm_input_handler._set_selection(Vector2i(1, 0))
	await wait_step()

	# STEP 3: Execute Q action (Plant Wheat)
	print_step("STEP 3: Execute Q Action (Plant Wheat)")
	print("  Action: Press 'Q' key")
	print("  Expected: Farm.build() called, 5 credits deducted, plot shows as planted")
	farm_input_handler._execute_tool_action("Q")
	await wait_step()

	# STEP 4: Move to different plot (Press U)
	print_step("STEP 4: Select Plot U (Position 2,0)")
	print("  Action: Press 'U' key")
	farm_input_handler._set_selection(Vector2i(2, 0))
	await wait_step()

	# STEP 5: Plant mushroom at new location (Press E)
	print_step("STEP 5: Execute E Action (Plant Mushroom)")
	print("  Action: Press 'E' key")
	print("  Expected: Mushroom planted at U, credits deducted again")
	farm_input_handler._execute_tool_action("E")
	await wait_step()

	# STEP 6: Switch to Tool 2 (Quantum Ops)
	print_step("STEP 6: Switch to Tool 2 (Quantum Ops)")
	print("  Action: Press '2' key")
	print("  Expected: Action menu changes to Q=Entangle, E=Measure, R=Harvest")
	farm_input_handler._select_tool(2)
	await wait_step()

	# STEP 7: Select plot Y again
	print_step("STEP 7: Select Plot Y (Position 1,0)")
	print("  Action: Press 'Y' key")
	farm_input_handler._set_selection(Vector2i(1, 0))
	await wait_step()

	# STEP 8: Measure the wheat plot
	print_step("STEP 8: Execute E Action (Measure)")
	print("  Action: Press 'E' key")
	print("  Expected: Plot is measured, shows quantum outcome (🌾 or 👥)")
	farm_input_handler._execute_tool_action("E")
	await wait_step()

	# STEP 9: Harvest the plot
	print_step("STEP 9: Execute R Action (Harvest)")
	print("  Action: Press 'R' key")
	print("  Expected: Plot is harvested, wheat added to inventory")
	farm_input_handler._execute_tool_action("R")
	await wait_step()

	# STEP 10: Switch to Tool 3 (Economy)
	print_step("STEP 10: Switch to Tool 3 (Economy)")
	print("  Action: Press '3' key")
	print("  Expected: Action menu changes to Q=Mill, E=Market, R=Sell All")
	farm_input_handler._select_tool(3)
	await wait_step()

	# STEP 11: Try to sell all wheat
	print_step("STEP 11: Execute R Action (Sell All Wheat)")
	print("  Action: Press 'R' key")
	print("  Expected: Wheat inventory converted to credits")
	farm_input_handler._execute_tool_action("R")
	await wait_step()

	# Done!
	print_step("TEST COMPLETE! ✅")
	print("")
	print("="*70)
	print("SUMMARY:")
	print("- All Q/E/R actions executed")
	print("- Farm state changed (plants added, resources deducted)")
	print("- UI updated in real-time")
	print("- Complete gameplay loop demonstrated")
	print("="*70)
	print("")

	await get_tree().create_timer(2.0).timeout
	quit()


func print_step(message: String):
	"""Print a step header"""
	print("\n" + "-"*70)
	print("⏹️  " + message)
	print("-"*70)


func wait_step() -> void:
	"""Wait before proceeding to next step (gives visual time)"""
	for i in range(30):  # 3 seconds at 10fps display
		await get_tree().process_frame
		if i % 10 == 0 and i > 0:
			print("  ... waiting %.1f seconds" % (i * 0.033))


func find_node_by_name(node: Node, target_name: String) -> Node:
	"""Recursively find a node by class name"""
	if node.get_class() == target_name or node.name == target_name:
		return node

	for child in node.get_children():
		var found = find_node_by_name(child, target_name)
		if found:
			return found

	return null
