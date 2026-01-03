extends SceneTree

## Automated Touch Input Test
## Simulates mouse clicks to verify input routing through:
## PlotGridDisplay → FarmView → QuantumForceGraph

var main_scene: Node = null
var test_clicks: Array[Dictionary] = []
var current_test: int = 0
var frame_count: int = 0

func _init():
	print("🧪 ═══════════════════════════════════════════════")
	print("🧪 TOUCH INPUT CHAIN TEST")
	print("🧪 Simulating fake mouse clicks to test input routing")
	print("🧪 ═══════════════════════════════════════════════\n")

func _ready():
	# Load main game scene
	print("📦 Loading main game scene...")
	var scene_path = "res://scenes/FarmView.tscn"
	var packed_scene = load(scene_path)

	if not packed_scene:
		print("❌ FAILED: Could not load %s" % scene_path)
		quit(1)
		return

	main_scene = packed_scene.instantiate()
	if not main_scene:
		print("❌ FAILED: Could not instantiate scene")
		quit(1)
		return

	root.add_child(main_scene)
	print("✅ Main scene loaded\n")

	# Wait for initialization
	print("⏳ Waiting for game initialization...")
	await create_timer(2.0).timeout

	# Define test clicks at different positions
	test_clicks = [
		{
			"name": "Center of screen",
			"position": Vector2(640, 360),
			"purpose": "Test general input routing"
		},
		{
			"name": "Top-left (likely UI)",
			"position": Vector2(100, 50),
			"purpose": "Test UI vs quantum input separation"
		},
		{
			"name": "Bottom area (likely plot grid)",
			"position": Vector2(640, 600),
			"purpose": "Test plot vs bubble input"
		},
		{
			"name": "Right side",
			"position": Vector2(1000, 360),
			"purpose": "Test off-center bubble area"
		}
	]

	print("✅ Initialization complete\n")
	print("🎯 Starting automated click tests...\n")

	# Start testing
	_run_next_test()

func _run_next_test():
	if current_test >= test_clicks.size():
		_finish_tests()
		return

	var test = test_clicks[current_test]
	print("═══════════════════════════════════════════════")
	print("TEST %d/%d: %s" % [current_test + 1, test_clicks.size(), test["name"]])
	print("Position: %s" % test["position"])
	print("Purpose: %s" % test["purpose"])
	print("───────────────────────────────────────────────")

	# Inject fake mouse click (press and release)
	await create_timer(0.5).timeout
	_inject_mouse_click(test["position"], true)  # Press

	await create_timer(0.1).timeout
	_inject_mouse_click(test["position"], false)  # Release

	await create_timer(0.5).timeout

	current_test += 1
	_run_next_test()

func _inject_mouse_click(pos: Vector2, pressed: bool):
	"""Inject a fake mouse click event into the input system"""
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = pos
	event.global_position = pos

	var action = "PRESS" if pressed else "RELEASE"
	print("💉 Injecting %s at %s..." % [action, pos])

	# Send to viewport
	Input.parse_input_event(event)

	# Also try direct viewport injection
	root.push_input(event)

func _finish_tests():
	print("\n═══════════════════════════════════════════════")
	print("🧪 ALL TESTS COMPLETE")
	print("═══════════════════════════════════════════════")
	print("\n📊 ANALYSIS:")
	print("\nLook at the output above for these debug messages:")
	print("  🎯 PlotGridDisplay._input → Shows if PlotGridDisplay receives input")
	print("  📍 FarmView._unhandled_input → Shows if FarmView receives unhandled input")
	print("  🖱️  QuantumForceGraph._unhandled_input → Shows if graph receives input")
	print("\nIf you see:")
	print("  ✅ All three → Input chain works, problem is elsewhere")
	print("  ⚠️  Only 🎯 → PlotGridDisplay consuming input (use Fix #1)")
	print("  ⚠️  🎯 and 📍 but not 🖱️ → Forwarding broken (use Fix #2)")
	print("  ❌ None → Something consuming input before PlotGridDisplay")

	await create_timer(1.0).timeout
	quit(0)

func _process(_delta):
	frame_count += 1
