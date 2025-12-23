class_name FarmUIControlsManager
extends Node

## FarmUIControlsManager
## Separated concerns: Handles ALL input, signals, and event routing
## Leaves FarmUIController clean for visual layout only
##
## ARCHITECTURE:
## - FarmInputHandler (keyboard: 1-6, Q/E/R, WASD)
## - InputController (overlay toggles: ESC, C, V, N, K)
## - Uses ControlsInterface to abstract simulation machinery
## - Allows swapping simulations by providing different ControlsInterface implementations

# Preload input handlers and interface
const FarmInputHandler = preload("res://UI/FarmInputHandler.gd")
const InputController = preload("res://UI/Controllers/InputController.gd")
const ControlsInterface = preload("res://UI/ControlsInterface.gd")

# Input handlers
var input_handler: FarmInputHandler = null
var input_controller: InputController = null

# Reference to UI controller (for event emission)
var ui_controller: Node = null

# Reference to simulation machinery via abstract interface (typed as Node for flexibility/duck typing)
var controls: Node = null

# Fallback: reference to Farm for backward compatibility / adapter creation
var farm: Node = null

# For lazy-init pattern (connect signals when simulation is injected)
var signals_connected: bool = false


func _ready() -> void:
	"""Initialize input handlers (Farm may be injected later)"""
	print("⌨️  FarmUIControlsManager initializing...")

	# Create input handlers
	_create_input_handlers()


func inject_ui_controller(controller: Node) -> void:
	"""Set the UI controller reference (for signal routing)"""
	ui_controller = controller
	print("📡 Controls manager connected to UI controller")


func inject_controls(controls_interface: Node) -> void:
	"""Inject any simulation machinery that implements ControlsInterface contract"""
	controls = controls_interface

	if not signals_connected:
		_connect_controls_signals()
		signals_connected = true


func inject_farm(farm_ref: Node) -> void:
	"""Set the Farm reference and optionally wrap it with ControlsInterface"""
	farm = farm_ref

	# Inject farm into input handler so keyboard actions can access it
	if input_handler:
		input_handler.farm = farm
		if farm:
			input_handler.grid_width = farm.grid_width
			input_handler.grid_height = farm.grid_height
		print("💉 Farm injected into FarmInputHandler")

	# If farm implements ControlsInterface, use it directly
	if farm is ControlsInterface:
		inject_controls(farm as ControlsInterface)
	else:
		# Otherwise, create an adapter (simulation team can provide one)
		print("⚠️  Farm does not implement ControlsInterface - backward compatibility mode")
		if not signals_connected:
			_connect_all_signals()
			signals_connected = true
			print("📡 Farm signals connected to controls (legacy mode)")


func _create_input_handlers() -> void:
	"""Create input handling systems"""
	# Input Controller MUST be added FIRST so it gets priority for input processing
	# This ensures menu/overlay keys (ESC, Q, R when menu visible) are handled
	# BEFORE FarmInputHandler can intercept them (overlay toggles: ESC, C, V, N, K)
	input_controller = InputController.new()
	add_child(input_controller)
	print("🎮 InputController created")

	# Farm Input Handler (keyboard-driven farm actions: 1-6, Q/E/R, WASD)
	# Added second so it only processes when no menu is open
	input_handler = FarmInputHandler.new()
	add_child(input_handler)
	if farm:
		input_handler.farm = farm
		input_handler.grid_width = farm.grid_width
		input_handler.grid_height = farm.grid_height
	print("⌨️  FarmInputHandler created")


func get_input_handler() -> Node:
	"""Get the input handler (for external access)"""
	return input_handler


func set_plot_grid_display(plot_grid_display: Node) -> void:
	"""Set PlotGridDisplay reference on FarmInputHandler (for wiring phase)"""
	if input_handler:
		input_handler.plot_grid_display = plot_grid_display
		print("   💉 PlotGridDisplay wired to FarmInputHandler")


func _connect_all_signals() -> void:
	"""Establish all signal connections between systems (legacy mode)"""
	if not farm:
		return

	print("🔗 Connecting farm input signals (legacy)...")

	_connect_farm_signals()
	_connect_input_signals()
	_connect_plot_signals()
	_connect_measurement_signals()
	_connect_harvest_signals()
	_connect_entanglement_signals()
	_connect_tool_signals()

	print("✅ All input signals connected (legacy)")


func _connect_controls_signals() -> void:
	"""Establish signal connections using ControlsInterface (modern architecture)"""
	if not controls:
		return

	# Connect input handler → controls interface
	_connect_input_signals()

	# Connect controls interface → UI updates
	if controls.has_signal("tool_selected"):
		controls.tool_selected.connect(_on_controls_tool_selected)
	if controls.has_signal("wheat_changed"):
		controls.wheat_changed.connect(_on_wheat_changed)
	if controls.has_signal("inventory_changed"):
		controls.inventory_changed.connect(_on_inventory_changed)
	if controls.has_signal("plot_state_changed"):
		controls.plot_state_changed.connect(_on_plot_state_changed)
	if controls.has_signal("plot_planted"):
		controls.plot_planted.connect(_on_plot_planted)
	if controls.has_signal("plot_harvested"):
		controls.plot_harvested.connect(_on_plot_harvested)
	if controls.has_signal("qubit_measured"):
		controls.qubit_measured.connect(_on_qubit_measured)
	if controls.has_signal("plots_entangled"):
		controls.plots_entangled.connect(_on_plots_entangled)

	print("📡 ControlsInterface signal bridge connected")


func _connect_farm_signals() -> void:
	"""Connect Farm simulation signals"""
	if not farm:
		return

	# Plant/unplant signals
	if farm.has_signal("plot_planted"):
		farm.plot_planted.connect(_on_plot_planted)
	if farm.has_signal("plot_unplanted"):
		farm.plot_unplanted.connect(_on_plot_unplanted)

	# Economy signals
	if farm.economy and farm.economy.has_signal("wheat_changed"):
		farm.economy.wheat_changed.connect(_on_wheat_changed)
	if farm.economy and farm.economy.has_signal("inventory_changed"):
		farm.economy.inventory_changed.connect(_on_inventory_changed)


func _connect_input_signals() -> void:
	"""Connect input handler signals"""
	if input_handler:
		if input_handler.has_signal("tool_changed"):
			input_handler.tool_changed.connect(_on_tool_changed)
		if input_handler.has_signal("plot_selected"):
			input_handler.plot_selected.connect(_on_plot_selected)
		if input_handler.has_signal("action_performed"):
			input_handler.action_performed.connect(_on_action_performed)

	if input_controller:
		# Menu/Overlay toggles (ESC, V, C, N keys)
		if input_controller.has_signal("menu_toggled"):
			input_controller.menu_toggled.connect(_on_menu_toggled)
		if input_controller.has_signal("vocabulary_requested"):
			input_controller.vocabulary_requested.connect(_on_vocabulary_requested)
		if input_controller.has_signal("contracts_toggled"):
			input_controller.contracts_toggled.connect(_on_contracts_toggled)
		if input_controller.has_signal("network_toggled"):
			input_controller.network_toggled.connect(_on_network_toggled)

		# Keyboard help (K key)
		if input_controller.has_signal("keyboard_help_requested"):
			input_controller.keyboard_help_requested.connect(_on_keyboard_help_requested)

		# Menu actions (Q, R keys when menu is visible)
		if input_controller.has_signal("quit_requested"):
			input_controller.quit_requested.connect(_on_quit_requested)
		if input_controller.has_signal("restart_requested"):
			input_controller.restart_requested.connect(_on_restart_requested)

		# Legacy debug signals
		if input_controller.has_signal("toggle_keyboard_help"):
			input_controller.toggle_keyboard_help.connect(_on_toggle_keyboard_help)
		if input_controller.has_signal("toggle_debug"):
			input_controller.toggle_debug.connect(_on_toggle_debug)


func _connect_plot_signals() -> void:
	"""Connect plot-related signals"""
	if not farm or not farm.grid:
		return

	# Monitor plot states
	for pos in farm.grid.get_all_positions():
		var plot = farm.grid.get_plot(pos)
		if plot:
			if plot.has_signal("state_changed"):
				plot.state_changed.connect(func(): _on_plot_state_changed(pos))

	# Connect plot_measured for immediate action feedback
	if farm and farm.has_signal("plot_measured"):
		farm.plot_measured.connect(_on_plot_measured)
		print("   📡 Connected farm.plot_measured")


func _connect_measurement_signals() -> void:
	"""Connect measurement signals"""
	if not farm or not farm.has_signal("qubit_measured"):
		return

	farm.qubit_measured.connect(_on_qubit_measured)


func _connect_harvest_signals() -> void:
	"""Connect harvest signals"""
	if not farm or not farm.has_signal("plot_harvested"):
		return

	farm.plot_harvested.connect(_on_plot_harvested)


func _connect_entanglement_signals() -> void:
	"""Connect entanglement signals"""
	if not farm or not farm.has_signal("plots_entangled"):
		return

	farm.plots_entangled.connect(_on_plots_entangled)


func _connect_tool_signals() -> void:
	"""Connect tool/action signals"""
	if not farm or not farm.has_signal("tool_applied"):
		return

	farm.tool_applied.connect(_on_tool_applied)


## EVENT HANDLERS - Farm Events

func _on_plot_planted(pos: Vector2i) -> void:
	"""Handle plot planting"""
	print("🌱 Plot planted at %s" % pos)
	if ui_controller and ui_controller.has_method("on_plot_planted"):
		ui_controller.on_plot_planted(pos)


func _on_plot_unplanted(pos: Vector2i) -> void:
	"""Handle plot unplanting"""
	print("🗑️  Plot unplanted at %s" % pos)
	if ui_controller and ui_controller.has_method("on_plot_unplanted"):
		ui_controller.on_plot_unplanted(pos)


func _on_wheat_changed(new_amount: int) -> void:
	"""Handle wheat currency changes"""
	if ui_controller and ui_controller.has_method("update_wheat"):
		ui_controller.update_wheat(new_amount)


func _on_inventory_changed(resource: String, amount: int) -> void:
	"""Handle inventory changes"""
	if ui_controller and ui_controller.has_method("update_inventory"):
		ui_controller.update_inventory(resource, amount)


func _on_qubit_measured(pos: Vector2i, outcome: String) -> void:
	"""Handle quantum measurement"""
	print("📊 Qubit measured at %s: %s" % [pos, outcome])
	if ui_controller and ui_controller.has_method("on_qubit_measured"):
		ui_controller.on_qubit_measured(pos, outcome)


func _on_plot_measured(pos: Vector2i, outcome: String) -> void:
	"""Handle plot measurement - provide feedback to input handler"""
	if input_handler:
		input_handler.action_performed.emit("measure", true,
			"👁️ Measured at %s → %s" % [pos, outcome])
	print("📡 Plot measurement result sent to input handler: %s → %s" % [pos, outcome])


func _on_plot_harvested(pos: Vector2i, yield_amount: int) -> void:
	"""Handle plot harvest"""
	print("✂️  Harvested %d from %s" % [yield_amount, pos])
	if ui_controller and ui_controller.has_method("on_plot_harvested"):
		ui_controller.on_plot_harvested(pos, yield_amount)


func _on_plots_entangled(pos1: Vector2i, pos2: Vector2i) -> void:
	"""Handle entanglement creation"""
	print("🔗 Plots entangled: %s ↔ %s" % [pos1, pos2])
	if ui_controller and ui_controller.has_method("on_plots_entangled"):
		ui_controller.on_plots_entangled(pos1, pos2)


func _on_tool_applied(tool: String, pos: Vector2i, result: bool) -> void:
	"""Handle tool application"""
	print("🛠️  Tool %s applied at %s: %s" % [tool, pos, "SUCCESS" if result else "FAILED"])
	if ui_controller and ui_controller.has_method("on_tool_applied"):
		ui_controller.on_tool_applied(tool, pos, result)


func _on_plot_state_changed(pos: Vector2i) -> void:
	"""Handle plot state changes"""
	if ui_controller and ui_controller.has_method("on_plot_state_changed"):
		ui_controller.on_plot_state_changed(pos)


## EVENT HANDLERS - Input Events

func _on_tool_changed(tool_num: int, tool_info: Dictionary) -> void:
	"""Handle tool selection change from FarmInputHandler - route to simulation and UI"""
	# Route to simulation machinery via ControlsInterface
	if controls and controls.has_method("select_tool"):
		controls.select_tool(tool_num)

	# Update UI display
	if ui_controller and ui_controller.has_method("on_tool_changed"):
		ui_controller.on_tool_changed(tool_num, tool_info)


func _on_controls_tool_selected(tool_num: int) -> void:
	"""Handle tool selection from ControlsInterface (adapter) - update UI only"""
	# Just update UI display - no need to route back to controls
	if ui_controller and ui_controller.has_method("on_tool_changed"):
		# Create minimal tool_info dict for UI update
		var tool_info = {"name": "Tool %d" % tool_num}
		ui_controller.on_tool_changed(tool_num, tool_info)


func _on_plot_selected(pos: Vector2i) -> void:
	"""Handle plot selection via keyboard - route to simulation and UI"""
	print("📍 Plot selected via keyboard: %s" % pos)

	# Route to simulation machinery via ControlsInterface
	if controls and controls.has_method("select_plot"):
		controls.select_plot(pos)

	# Update UI display
	if ui_controller and ui_controller.has_method("on_plot_selected"):
		ui_controller.on_plot_selected(pos)


func _on_action_performed(action: String, success: bool, message: String) -> void:
	"""Handle action execution from FarmInputHandler - route feedback to UI"""
	print("⚡ Action performed: %s (success: %s)" % [action, success])
	print("   Message: %s" % message)

	# Update UI with action result
	if ui_controller and ui_controller.has_method("on_action_performed"):
		ui_controller.on_action_performed(action, success, message)


func _on_toggle_keyboard_help() -> void:
	"""Toggle keyboard help overlay"""
	if ui_controller and ui_controller.has_method("toggle_keyboard_help"):
		ui_controller.toggle_keyboard_help()


func _on_toggle_debug() -> void:
	"""Toggle debug mode"""
	if ui_controller and ui_controller.has_method("toggle_debug"):
		ui_controller.toggle_debug()


## OVERLAY TOGGLE HANDLERS (ESC, V, C, N keys)

func _on_menu_toggled() -> void:
	"""Handle ESC key - toggle escape menu"""
	if ui_controller and ui_controller.overlay_manager:
		ui_controller.overlay_manager.toggle_escape_menu()
		print("🎮 ESC: Toggling escape menu")


func _on_vocabulary_requested() -> void:
	"""Handle V key - toggle vocabulary overlay"""
	if ui_controller and ui_controller.overlay_manager:
		ui_controller.overlay_manager.toggle_vocabulary_overlay()
		print("📖 V: Toggling vocabulary overlay")


func _on_contracts_toggled() -> void:
	"""Handle C key - toggle contracts overlay"""
	if ui_controller and ui_controller.overlay_manager:
		ui_controller.overlay_manager.toggle_overlay("contracts")
		print("📋 C: Toggling contracts overlay")


func _on_network_toggled() -> void:
	"""Handle N key - toggle network overlay"""
	if ui_controller and ui_controller.overlay_manager:
		ui_controller.overlay_manager.toggle_network_overlay()
		print("🕸️  N: Toggling network overlay")


func _on_keyboard_help_requested() -> void:
	"""Handle K key - toggle keyboard help overlay"""
	if ui_controller and ui_controller.layout_manager and ui_controller.layout_manager.keyboard_hint_button:
		ui_controller.layout_manager.keyboard_hint_button.toggle_hints()
		print("⌨️  K: Toggling keyboard help")


## MENU ACTION HANDLERS (Q, R keys when menu is visible)

func _on_quit_requested() -> void:
	"""Handle Q key - quit game (when menu is visible)"""
	if ui_controller and ui_controller.overlay_manager and ui_controller.overlay_manager.escape_menu:
		ui_controller.overlay_manager.escape_menu._on_quit_pressed()
		print("🚪 Q: Quitting game")


func _on_restart_requested() -> void:
	"""Handle R key - restart game (when menu is visible)"""
	if ui_controller and ui_controller.overlay_manager:
		ui_controller.overlay_manager._on_restart_pressed()
		print("🔄 R: Restarting game")
