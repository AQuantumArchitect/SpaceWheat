## FarmView - Simplified entry point
## Creates the farm and loads it into PlayerShell
##
## This used to be 50+ lines of orchestration.
## Now it's just: create farm, load into shell.

extends Control

const Farm = preload("res://Core/Farm.gd")
const InputController = preload("res://UI/Controllers/InputController.gd")

var shell = null  # PlayerShell (from scene)
var farm: Node = null
var input_controller: InputController = null


func _ready() -> void:
	"""Initialize: create farm and shell, wire them together"""
	print("🌾 FarmView starting...")

	# Load PlayerShell scene
	print("🎪 Loading player shell scene...")
	var shell_scene = load("res://UI/PlayerShell.tscn")
	if shell_scene:
		shell = shell_scene.instantiate()
		add_child(shell)
		print("   ✅ Player shell loaded and added to tree")
	else:
		print("❌ PlayerShell.tscn not found!")
		return

	# Create farm (synchronous)
	print("📝 Creating farm...")
	farm = Farm.new()
	add_child(farm)
	print("   ✅ Farm created and added to tree")

	# Load farm into shell (this configures FarmUI)
	shell.load_farm(farm)

	# Create input controller and wire signals
	print("🎮 Creating input controller...")
	input_controller = InputController.new()
	add_child(input_controller)

	# Wire input controller signals to overlay manager
	print("🔗 Connecting overlay signals...")

	if input_controller.has_signal("menu_toggled"):
		input_controller.menu_toggled.connect(shell._toggle_escape_menu)
		print("   ✅ ESC key (escape menu) connected")

	if input_controller.has_signal("vocabulary_requested"):
		input_controller.vocabulary_requested.connect(shell._toggle_vocabulary)
		print("   ✅ V key (vocabulary) connected")

	if input_controller.has_signal("contracts_toggled"):
		input_controller.contracts_toggled.connect(shell._toggle_contracts)
		print("   ✅ C key (contracts) connected")

	if input_controller.has_signal("network_toggled"):
		input_controller.network_toggled.connect(shell._toggle_network)
		print("   ✅ N key (network) connected")

	if input_controller.has_signal("keyboard_help_requested"):
		input_controller.keyboard_help_requested.connect(shell._toggle_keyboard_help)
		print("   ✅ K key (keyboard help) connected")

	print("✅ FarmView ready - game started!")


func get_farm() -> Node:
	"""Get the current farm (for external access)"""
	return farm


func get_shell() -> Node:
	"""Get the shell (for external access)"""
	return shell
