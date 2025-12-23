extends Control
## Clean test scene for touch gestures (TAP and SWIPE)
## Uses DebugEnvironment to load a pre-built game state
## Focuses ONLY on gesture detection and Bell state selection

const DebugEnvironment = preload("res://Core/GameState/DebugEnvironment.gd")
const GameStateManager = preload("res://Core/GameState/GameStateManager.gd")
const QuantumForceGraph = preload("res://Core/Visualization/QuantumForceGraph.gd")
const GameController = preload("res://Core/GameController.gd")

var quantum_graph: QuantumForceGraph
var game_controller: GameController
var test_log: TextEdit

# Gesture tracking
var tap_count = 0
var swipe_count = 0

func _ready():
	print("\n" + "="*60)
	print("TOUCH GESTURE TEST SCENE")
	print("="*60)

	set_process_input(true)

	# Create simple UI
	_setup_ui()

	# Load test scenario
	print("Loading test scenario...")
	var test_state = DebugEnvironment.fully_planted_farm()
	GameStateManager.apply_state_to_game(test_state)
	print("✅ Test scenario loaded: fully_planted_farm")

	# Create minimal game objects for testing
	_setup_test_environment()

	await get_tree().create_timer(0.5).timeout
	_log_instructions()


func _setup_ui():
	"""Create simple test UI"""
	var vbox = VBoxContainer.new()
	add_child(vbox)
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0

	# Title
	var title = Label.new()
	title.text = "TOUCH GESTURE TEST"
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	# Instructions
	var instructions = Label.new()
	instructions.text = "TAP a bubble → Measure\nSWIPE between bubbles → Entangle (choose Bell state)"
	instructions.add_theme_font_size_override("font_size", 14)
	vbox.add_child(instructions)

	# Log area
	test_log = TextEdit.new()
	test_log.custom_minimum_size = Vector2(400, 300)
	test_log.editable = false
	vbox.add_child(test_log)


func _setup_test_environment():
	"""Create quantum graph and game controller for testing"""
	# Create game controller
	game_controller = GameController.new()
	add_child(game_controller)
	game_controller.economy = FarmEconomy.new()
	add_child(game_controller.economy)

	# TODO: Wire up farm_grid and other systems
	print("✅ Game controller initialized")


func _log_instructions():
	"""Log test instructions"""
	_log("GESTURE TESTS:")
	_log("")
	_log("1️⃣  TAP TEST:")
	_log("   - Click on a quantum bubble in the center")
	_log("   - Should print: TAP DETECTED")
	_log("   - Plot should change to MEASURED state")
	_log("")
	_log("2️⃣  SWIPE TEST:")
	_log("   - Click and hold on bubble A")
	_log("   - Drag ≥50px to bubble B (within 1.0s)")
	_log("   - Release on bubble B")
	_log("   - Should show Bell state dialog")
	_log("")
	_log("Press ESC to quit")
	_log("")
	_log("Waiting for gestures...")


func _log(message: String):
	"""Add message to test log"""
	if test_log:
		test_log.text += message + "\n"
		test_log.scroll_vertical = INT_MAX  # Auto-scroll


func _input(event: InputEvent):
	"""Handle input for testing"""
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()


func test_tap_detection():
	"""Simulate a TAP gesture"""
	tap_count += 1
	_log("📊 TAP #%d detected" % tap_count)


func test_swipe_detection(from_pos: Vector2i, to_pos: Vector2i):
	"""Simulate a SWIPE gesture"""
	swipe_count += 1
	_log("📊 SWIPE #%d: %s → %s" % [swipe_count, from_pos, to_pos])


func test_bell_state_selection(bell_state: String):
	"""Log Bell state selection"""
	var state_name = "SAME (Φ+)" if bell_state == "phi_plus" else "OPPOSITE (Ψ+)"
	_log("🔗 Bell state selected: %s" % state_name)


## FarmEconomy mock for testing
class FarmEconomy:
	var credits = 20
	var seed_cost = 5
	var wheat_price = 2
	func get_credits() -> int:
		return credits
