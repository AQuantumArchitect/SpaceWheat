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

	# DEBUG: Check if FarmView is properly sized
	print("📏 FarmView size: %.0f × %.0f" % [size.x, size.y])
	print("   FarmView anchors: L%.1f T%.1f R%.1f B%.1f" % [anchor_left, anchor_top, anchor_right, anchor_bottom])
	print("   Viewport: %.0f × %.0f" % [get_viewport_rect().size.x, get_viewport_rect().size.y])

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

	# Wire input controller signals directly to overlay manager
	print("🔗 Connecting overlay signals...")

	# Get reference to overlay manager from shell
	if not shell.overlay_manager:
		print("❌ ERROR: OverlayManager not available in shell!")
		return

	if input_controller.has_signal("menu_toggled"):
		input_controller.menu_toggled.connect(shell.overlay_manager.toggle_escape_menu)
		print("   ✅ ESC key (escape menu) connected")

	if input_controller.has_signal("vocabulary_requested"):
		input_controller.vocabulary_requested.connect(shell.overlay_manager.toggle_vocabulary_overlay)
		print("   ✅ V key (vocabulary) connected")

	if input_controller.has_signal("contracts_toggled"):
		input_controller.contracts_toggled.connect(func(): shell.overlay_manager.toggle_overlay("contracts"))
		print("   ✅ C key (contracts) connected")

	if input_controller.has_signal("network_toggled"):
		input_controller.network_toggled.connect(shell.overlay_manager.toggle_network_overlay)
		print("   ✅ N key (network) connected")

	if input_controller.has_signal("keyboard_help_requested"):
		input_controller.keyboard_help_requested.connect(shell.overlay_manager.toggle_keyboard_help)
		print("   ✅ K key (keyboard help) connected")

	# Connect quit/restart signals
	if input_controller.has_signal("quit_requested"):
		input_controller.quit_requested.connect(_on_quit_requested)
		print("   ✅ Q key (quit) connected")

	if input_controller.has_signal("restart_requested"):
		input_controller.restart_requested.connect(_on_restart_requested)
		print("   ✅ R key (restart) connected")

	# CRITICAL: Listen to overlay state changes to sync InputController.menu_visible
	# This prevents input from being blocked when menu fails to show
	if shell.overlay_manager.has_signal("overlay_toggled"):
		shell.overlay_manager.overlay_toggled.connect(_on_overlay_state_changed)
		print("   ✅ Overlay state sync connected")

	# CRITICAL: Inject InputController into SaveLoadMenu so it can manage input
	# SaveLoadMenu needs to disable InputController when it opens to prevent conflicts
	if shell.overlay_manager.save_load_menu:
		shell.overlay_manager.save_load_menu.inject_input_controller(input_controller)
		print("   ✅ InputController injected into SaveLoadMenu")
	else:
		print("   ⚠️  SaveLoadMenu not available for input controller injection")

	print("✅ FarmView ready - game started!")


func _on_quit_requested() -> void:
	"""Handle quit request"""
	print("🛑 Quit requested - exiting game")
	get_tree().quit()


func _on_restart_requested() -> void:
	"""Handle restart request"""
	print("🔄 Restart requested - reloading scene")
	get_tree().reload_current_scene()


func _on_overlay_state_changed(overlay_name: String, visible: bool) -> void:
	"""Sync InputController.menu_visible when escape menu state changes

	CRITICAL: When the escape menu visibility changes, update InputController's internal state
	to stay in sync. This prevents the game from blocking input when the menu fails to display.
	"""
	if overlay_name == "escape_menu":
		input_controller.menu_visible = visible
		print("🔗 Synced InputController.menu_visible = %s" % visible)


func get_farm() -> Node:
	"""Get the current farm (for external access)"""
	return farm


func get_shell() -> Node:
	"""Get the shell (for external access)"""
	return shell
