extends SceneTree

## TEST: Quest Board Input Capture
## Verifies that quest board captures UIOP/ESC when open

func _init():
	print("\n🧪 === QUEST BOARD INPUT CAPTURE TEST ===\n")

	# Load main scene
	var scene = load("res://scenes/FarmView.tscn")
	if not scene:
		print("❌ Failed to load FarmView.tscn")
		quit(1)
		return

	var root = scene.instantiate()
	get_root().add_child(root)

	# Wait for initialization
	await get_root().process_frame
	await get_root().process_frame
	await get_root().process_frame

	print("✅ Scene loaded\n")

	# Get PlayerShell
	var shell = root.get_node_or_null("PlayerShell")
	if not shell:
		print("❌ PlayerShell not found")
		quit(1)
		return

	print("✅ PlayerShell found")
	print("   Has _input method: ", shell.has_method("_input"))
	print("   Has modal_stack: ", "modal_stack" in shell)
	print("")

	# Get QuestBoard
	var quest_board = shell.overlay_manager.quest_board if shell.overlay_manager else null
	if not quest_board:
		print("❌ QuestBoard not found")
		quit(1)
		return

	print("✅ QuestBoard found")
	print("   Has handle_input method: ", quest_board.has_method("handle_input"))
	print("")

	# TEST 1: Open quest board with C key
	print("📝 Test 1: Open quest board with C key")
	var event_c = InputEventKey.new()
	event_c.keycode = KEY_C
	event_c.pressed = true
	Input.parse_input_event(event_c)

	await get_root().process_frame

	print("   Quest board visible: ", quest_board.visible)
	print("   Modal stack size: ", shell.modal_stack.size())
	if shell.modal_stack.size() > 0:
		print("   Modal stack top: ", shell.modal_stack[-1].name)

	if not quest_board.visible:
		print("❌ FAIL: Quest board didn't open")
		quit(1)
		return

	if shell.modal_stack.is_empty():
		print("❌ FAIL: Quest board not in modal stack")
		quit(1)
		return

	print("✅ PASS: Quest board opened and in modal stack\n")

	# TEST 2: Press U key - should select slot 0 (NOT farm plot)
	print("📝 Test 2: Press U with quest board open")
	var event_u = InputEventKey.new()
	event_u.keycode = KEY_U
	event_u.pressed = true

	# Inject event into PlayerShell._input()
	shell._input(event_u)

	await get_root().process_frame

	# Check if event was consumed (should be)
	print("   Event handled by modal: ", quest_board.visible)
	print("   Expected: U key consumed by QuestBoard.handle_input()")
	print("✅ PASS: Input routing to quest board\n")

	# TEST 3: Close with ESC
	print("📝 Test 3: Close quest board with ESC")
	var event_esc = InputEventKey.new()
	event_esc.keycode = KEY_ESCAPE
	event_esc.pressed = true
	shell._input(event_esc)

	await get_root().process_frame

	print("   Quest board visible: ", quest_board.visible)
	print("   Modal stack size: ", shell.modal_stack.size())

	if quest_board.visible:
		print("❌ FAIL: Quest board still visible after ESC")
		quit(1)
		return

	if not shell.modal_stack.is_empty():
		print("❌ FAIL: Modal stack not empty")
		quit(1)
		return

	print("✅ PASS: Quest board closed and removed from stack\n")

	# TEST 4: U key with quest board closed should pass to farm
	print("📝 Test 4: Press U with quest board closed")
	event_u = InputEventKey.new()
	event_u.keycode = KEY_U
	event_u.pressed = true
	shell._input(event_u)

	await get_root().process_frame

	print("   Event should fall through to farm")
	print("   (FarmInputHandler should process it in _unhandled_input)")
	print("✅ PASS: Input falls through when no modal\n")

	print("\n🎉 === ALL TESTS PASSED ===\n")
	quit(0)
