extends Node

## Automated Tap Test
## Injects fake mouse clicks and monitors which debug messages appear

var test_phase: int = 0
var frame_count: int = 0
var debug_output: Array[String] = []
var original_print = null

# Track which debug messages we've seen
var saw_plotgrid_input: bool = false
var saw_farmview_input: bool = false
var saw_quantumgraph_input: bool = false
var saw_bubble_tap_handler: bool = false

# Positions to test
var test_positions: Array[Vector2] = [
	Vector2(640, 360),   # Center of screen
	Vector2(640, 473),   # BioticFlux oval center
	Vector2(350, 297),   # Market oval center
	Vector2(800, 300),   # Forest oval area
]

var current_test_index: int = 0

func _ready() -> void:
	print("\n")
	print("🤖 ═══════════════════════════════════════════════")
	print("🤖 AUTOMATED TAP TEST")
	print("🤖 This test will inject fake mouse clicks and")
	print("🤖 monitor which debug messages appear")
	print("🤖 ═══════════════════════════════════════════════")
	print("\n")

	# Wait for game to fully initialize
	print("⏳ Phase 0: Waiting for game initialization (3 seconds)...")
	await get_tree().create_timer(3.0).timeout

	print("✅ Initialization complete")
	print("\n")

	# Start testing
	_run_next_test()


func _run_next_test() -> void:
	if current_test_index >= test_positions.size():
		_finish_tests()
		return

	var pos = test_positions[current_test_index]

	print("═══════════════════════════════════════════════")
	print("TEST %d/%d: Injecting click at %s" % [current_test_index + 1, test_positions.size(), pos])
	print("═══════════════════════════════════════════════")

	# Reset detection flags
	saw_plotgrid_input = false
	saw_farmview_input = false
	saw_quantumgraph_input = false
	saw_bubble_tap_handler = false

	# Inject mouse button press
	await get_tree().create_timer(0.2).timeout
	_inject_mouse_event(pos, true)

	# Wait a bit
	await get_tree().create_timer(0.1).timeout

	# Inject mouse button release
	_inject_mouse_event(pos, false)

	# Wait for debug output to appear
	await get_tree().create_timer(0.3).timeout

	# Analyze results
	_analyze_test_result(current_test_index)

	print("\n")

	current_test_index += 1
	_run_next_test()


func _inject_mouse_event(pos: Vector2, pressed: bool) -> void:
	"""Inject a fake mouse button event"""
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = pos
	event.global_position = pos

	var action = "PRESS" if pressed else "RELEASE"
	print("   💉 Injecting %s at %s" % [action, pos])

	# Try multiple injection methods to ensure it works
	Input.parse_input_event(event)
	get_viewport().push_input(event)


func _analyze_test_result(test_index: int) -> void:
	"""Analyze which debug messages appeared for this test"""
	print("\n   📊 ANALYSIS:")

	# We can't actually capture print output in GDScript, so we'll just wait
	# and let the user see the console output
	print("   Check console output above for:")
	print("      🎯 PlotGridDisplay._input")
	print("      📍 FarmView._unhandled_input")
	print("      🖱️  QuantumForceGraph._unhandled_input")
	print("      🎯🎯🎯 BUBBLE TAP HANDLER CALLED")


func _finish_tests() -> void:
	print("\n")
	print("═══════════════════════════════════════════════")
	print("🤖 ALL TESTS COMPLETE")
	print("═══════════════════════════════════════════════")
	print("\n")

	print("📊 FINAL ANALYSIS:")
	print("\n")
	print("Look at the console output above. For each test, you should see:")
	print("\n")
	print("EXPECTED PATTERN A (Input chain works):")
	print("  🎯 PlotGridDisplay._input: Mouse click at ...")
	print("  📍 FarmView._unhandled_input: Mouse click at ...")
	print("  🖱️  QuantumForceGraph._unhandled_input: Mouse click at ...")
	print("\n")
	print("If you see different patterns:")
	print("\n")
	print("PATTERN B (PlotGridDisplay consuming input):")
	print("  🎯 PlotGridDisplay._input: Mouse click at ...")
	print("  (nothing else)")
	print("  → Fix: PlotGridDisplay needs to skip non-plot clicks")
	print("\n")
	print("PATTERN C (Forwarding broken):")
	print("  🎯 PlotGridDisplay._input: Mouse click at ...")
	print("  📍 FarmView._unhandled_input: Mouse click at ...")
	print("  (no QuantumForceGraph message)")
	print("  → Fix: FarmView forwarding to QuantumForceGraph is broken")
	print("\n")
	print("PATTERN D (Complete blockage):")
	print("  (no debug output at all)")
	print("  → Fix: Something consuming ALL input before PlotGridDisplay")
	print("\n")

	# Wait a bit before quitting
	await get_tree().create_timer(2.0).timeout

	print("Test complete. Exiting...")
	get_tree().quit()
