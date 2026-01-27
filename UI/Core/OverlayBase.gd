class_name OverlayBase
extends Control

## OverlayBase - Unified base class for all overlays and modal menus
##
## Consolidates ResponsiveModalBase, MenuPanelBase, and V2OverlayBase into one.
##
## Provides:
##   - Full-screen setup with optional dimmer
##   - Centered panel with configurable styling
##   - Unified input routing (QER+F actions, navigation)
##   - Overlay lifecycle (activate/deactivate)
##   - OverlayStackManager integration
##
## Subclasses should:
##   1. Configure properties in _init()
##   2. Override _build_content(container) to add UI
##   3. Override action handlers: _on_action_q/e/r/f()
##   4. Override navigation: _on_navigate(direction) or set navigation_mode

const UIStyleFactory = preload("res://UI/Core/UIStyleFactory.gd")

# =============================================================================
# SIGNALS
# =============================================================================

signal overlay_opened()
signal overlay_closed()
signal action_performed(action: String, data: Dictionary)
signal selection_changed(index: int)

# =============================================================================
# OVERLAY INTERFACE (for OverlayStackManager)
# =============================================================================

var overlay_name: String = "overlay"
var overlay_icon: String = ""
var overlay_tier: int = 2000  # Z_TIER_INFO=2000, Z_TIER_MODAL=3000, Z_TIER_SYSTEM=4000

var action_labels: Dictionary = {
	"Q": "",
	"E": "",
	"R": "",
	"F": ""
}

# =============================================================================
# PANEL CONFIGURATION (set in _init before _ready)
# =============================================================================

var panel_title: String = ""
var panel_title_size: int = 24
var panel_size: Vector2 = Vector2(600, 450)
var panel_border_color: Color = Color(0.3, 0.4, 0.5, 0.8)

# Dimmer configuration (off by default - enable in subclass if needed)
var show_dimmer: bool = false
var dimmer_color: Color = Color(0, 0, 0, 0.7)

# Content configuration
var use_scroll_container: bool = true
var content_spacing: int = 8

# =============================================================================
# NAVIGATION CONFIGURATION
# =============================================================================

enum NavigationMode {
	NONE,           # No keyboard navigation
	LINEAR,         # Up/Down only (for button menus)
	GRID,           # WASD with grid columns/rows
	CALLBACK        # Calls _on_navigate_* methods
}

var navigation_mode: NavigationMode = NavigationMode.CALLBACK
var grid_columns: int = 1
var grid_rows: int = 1
var nav_wrap: bool = true  # Wrap around at edges

# =============================================================================
# UI REFERENCES (populated by _build_panel)
# =============================================================================

var _dimmer: ColorRect
var _center: CenterContainer
var _panel: PanelContainer
var _main_vbox: VBoxContainer
var _title_label: Label
var _scroll_container: ScrollContainer
var _content_container: VBoxContainer

# =============================================================================
# STATE
# =============================================================================

var is_active: bool = false
var selected_index: int = -1
var selectable_count: int = 0
var layout_manager: Node = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_build_panel()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	"""Direct input handling when overlay is visible.

	This captures input directly rather than relying only on OverlayStackManager routing.
	"""
	if not visible or not is_active:
		return

	if handle_input(event):
		get_viewport().set_input_as_handled()


func _build_panel() -> void:
	"""Build the overlay UI structure."""
	# Fill entire screen with explicit anchors
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_right = 0
	offset_top = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Dimmer (optional - off by default)
	if show_dimmer:
		_dimmer = ColorRect.new()
		_dimmer.color = dimmer_color
		_dimmer.anchor_left = 0.0
		_dimmer.anchor_right = 1.0
		_dimmer.anchor_top = 0.0
		_dimmer.anchor_bottom = 1.0
		_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_dimmer)

	# CenterContainer to center the panel - fill entire overlay
	_center = CenterContainer.new()
	_center.anchor_left = 0.0
	_center.anchor_right = 1.0
	_center.anchor_top = 0.0
	_center.anchor_bottom = 1.0
	_center.offset_left = 0
	_center.offset_right = 0
	_center.offset_top = 0
	_center.offset_bottom = 0
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)

	# Panel inside center container - will be auto-centered
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = panel_size
	_panel.add_theme_stylebox_override("panel", UIStyleFactory.create_panel_style(
		UIStyleFactory.COLOR_PANEL_BG,
		panel_border_color
	))
	_center.add_child(_panel)

	# Main VBox
	_main_vbox = UIStyleFactory.create_vbox(content_spacing)
	_panel.add_child(_main_vbox)

	# Title (optional)
	if not panel_title.is_empty():
		_title_label = UIStyleFactory.create_title_label(panel_title, panel_title_size)
		_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_main_vbox.add_child(_title_label)

	# Content area
	if use_scroll_container:
		var scroll_size = Vector2(panel_size.x - 40, panel_size.y - 80)
		_scroll_container = ScrollContainer.new()
		_scroll_container.custom_minimum_size = scroll_size
		_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_main_vbox.add_child(_scroll_container)

		_content_container = UIStyleFactory.create_vbox(content_spacing)
		_content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_scroll_container.add_child(_content_container)
	else:
		_content_container = _main_vbox

	# Let subclass build content
	_build_content(_content_container)


func _build_content(_container: Control) -> void:
	"""Override to add content. Called during _ready()."""
	pass


# =============================================================================
# ACTIVATION / DEACTIVATION
# =============================================================================

func activate() -> void:
	"""Called when overlay opens."""
	is_active = true
	visible = true
	if _scroll_container:
		_scroll_container.scroll_vertical = 0
	if selectable_count > 0 and selected_index < 0:
		selected_index = 0
	_update_selection_visual()
	_on_activated()
	overlay_opened.emit()


func deactivate() -> void:
	"""Called when overlay closes."""
	is_active = false
	visible = false
	_on_deactivated()
	overlay_closed.emit()


func _on_activated() -> void:
	"""Override for custom activation logic."""
	pass


func _on_deactivated() -> void:
	"""Override for custom deactivation logic."""
	pass


# =============================================================================
# INPUT HANDLING
# =============================================================================

func handle_input(event: InputEvent) -> bool:
	"""Handle input when overlay is active. Returns true if consumed."""
	if not visible or not is_active:
		return false

	if not event is InputEventKey or not event.pressed or event.echo:
		return false

	var keycode = event.keycode

	# ESC - don't consume, let OverlayStackManager handle it
	if keycode == KEY_ESCAPE:
		return false

	# QER+F action keys
	if keycode == KEY_Q:
		_on_action_q()
		return true
	if keycode == KEY_E:
		_on_action_e()
		return true
	if keycode == KEY_R:
		_on_action_r()
		return true
	if keycode == KEY_F:
		_on_action_f()
		return true

	# ENTER key - activate selected item
	if keycode == KEY_ENTER or keycode == KEY_KP_ENTER:
		_activate_selected()
		return true

	# Navigation
	if navigation_mode != NavigationMode.NONE:
		var direction = _get_nav_direction(keycode)
		if direction != Vector2i.ZERO:
			_handle_navigation(direction)
			return true

	# Let subclass handle other keys
	return _on_unhandled_key(keycode, event)


func _get_nav_direction(keycode: int) -> Vector2i:
	"""Convert keycode to navigation direction."""
	match keycode:
		KEY_W, KEY_UP:
			return Vector2i.UP
		KEY_S, KEY_DOWN:
			return Vector2i.DOWN
		KEY_A, KEY_LEFT:
			return Vector2i.LEFT
		KEY_D, KEY_RIGHT:
			return Vector2i.RIGHT
	return Vector2i.ZERO


func _handle_navigation(direction: Vector2i) -> void:
	"""Route navigation based on mode."""
	match navigation_mode:
		NavigationMode.LINEAR:
			_navigate_linear(direction)
		NavigationMode.GRID:
			_navigate_grid(direction)
		NavigationMode.CALLBACK:
			_on_navigate(direction)


func _navigate_linear(direction: Vector2i) -> void:
	"""Navigate up/down through selectable items."""
	if selectable_count <= 0:
		return

	var delta = 0
	if direction == Vector2i.UP:
		delta = -1
	elif direction == Vector2i.DOWN:
		delta = 1
	else:
		return  # Linear only handles up/down

	var new_index = selected_index + delta
	if nav_wrap:
		new_index = posmod(new_index, selectable_count)
	else:
		new_index = clampi(new_index, 0, selectable_count - 1)

	if new_index != selected_index:
		selected_index = new_index
		_update_selection_visual()
		selection_changed.emit(selected_index)


func _navigate_grid(direction: Vector2i) -> void:
	"""Navigate through a grid of selectable items."""
	if selectable_count <= 0:
		return

	var new_index = selected_index
	match direction:
		Vector2i.UP:
			new_index -= grid_columns
		Vector2i.DOWN:
			new_index += grid_columns
		Vector2i.LEFT:
			new_index -= 1
		Vector2i.RIGHT:
			new_index += 1

	if nav_wrap:
		new_index = posmod(new_index, selectable_count)
	else:
		new_index = clampi(new_index, 0, selectable_count - 1)

	if new_index != selected_index:
		selected_index = new_index
		_update_selection_visual()
		selection_changed.emit(selected_index)


func _on_navigate(direction: Vector2i) -> void:
	"""Override for custom navigation handling."""
	pass


func _on_unhandled_key(_keycode: int, _event: InputEvent) -> bool:
	"""Override to handle keys not caught by standard routing."""
	return false


# =============================================================================
# ACTION HANDLERS (override in subclass)
# =============================================================================

func _on_action_q() -> void:
	"""Q key action. Override for custom behavior."""
	action_performed.emit("q", {"selected": selected_index})


func _on_action_e() -> void:
	"""E key action. Override for custom behavior."""
	action_performed.emit("e", {"selected": selected_index})


func _on_action_r() -> void:
	"""R key action. Override for custom behavior."""
	action_performed.emit("r", {"selected": selected_index})


func _on_action_f() -> void:
	"""F key action. Override for custom behavior."""
	action_performed.emit("f", {"selected": selected_index})


# =============================================================================
# OVERLAY INTERFACE
# =============================================================================

func get_overlay_info() -> Dictionary:
	"""Get overlay metadata for registration."""
	return {
		"name": overlay_name,
		"icon": overlay_icon,
		"action_labels": action_labels.duplicate(),
		"tier": overlay_tier
	}


func get_overlay_tier() -> int:
	"""Get z-index tier for OverlayStackManager."""
	return overlay_tier


func get_action_labels() -> Dictionary:
	"""Get current QER+F labels."""
	return action_labels.duplicate()


func set_action_label(key: String, label: String) -> void:
	"""Update a single action label."""
	if key in ["Q", "E", "R", "F"]:
		action_labels[key] = label


# =============================================================================
# LAYOUT MANAGER
# =============================================================================

func set_layout_manager(manager: Node) -> void:
	"""Set UILayoutManager reference for responsive sizing."""
	layout_manager = manager


# =============================================================================
# UTILITY
# =============================================================================

func set_title(text: String) -> void:
	"""Update the panel title."""
	panel_title = text
	if _title_label:
		_title_label.text = text


func get_panel() -> PanelContainer:
	"""Get the main panel for custom styling."""
	return _panel


func get_content_container() -> Control:
	"""Get the content container for adding content after _ready."""
	return _content_container


func set_selectable_count(count: int) -> void:
	"""Set number of selectable items for navigation."""
	selectable_count = count
	if selected_index >= count:
		selected_index = max(0, count - 1)
	if selected_index < 0 and count > 0:
		selected_index = 0


func set_grid_dimensions(columns: int, rows: int) -> void:
	"""Set grid dimensions for GRID navigation mode."""
	grid_columns = columns
	grid_rows = rows


# =============================================================================
# BUTTON MENU SUPPORT
# =============================================================================

var _menu_buttons: Array[Button] = []

func add_menu_button(text: String, color: Color, callback: Callable = Callable()) -> Button:
	"""Add a styled button to the content area.

	Args:
		text: Button text
		color: Button background color
		callback: Optional callback for button press

	Returns the created Button.
	"""
	var btn = UIStyleFactory.create_styled_button(text, color)
	_content_container.add_child(btn)
	_menu_buttons.append(btn)

	var btn_index = _menu_buttons.size() - 1
	btn.pressed.connect(_on_menu_button_pressed.bind(btn_index))

	if callback.is_valid():
		btn.pressed.connect(callback)

	selectable_count = _menu_buttons.size()
	return btn


func add_custom_control(control: Control) -> void:
	"""Add a custom control (slider, separator, etc.) to the content area."""
	_content_container.add_child(control)


func _on_menu_button_pressed(index: int) -> void:
	"""Internal handler for button presses."""
	_on_button_activated(index)


func _on_button_activated(index: int) -> void:
	"""Override in subclass to handle button activation."""
	pass


func _update_selection_visual() -> void:
	"""Update visual indication of selection."""
	for i in range(_menu_buttons.size()):
		UIStyleFactory.apply_selection_modulate(_menu_buttons[i], i == selected_index)


func _activate_selected() -> void:
	"""Activate the currently selected item (for ENTER key)."""
	if selected_index >= 0 and selected_index < _menu_buttons.size():
		_menu_buttons[selected_index].emit_signal("pressed")


# =============================================================================
# MENU ALIASES (for MenuPanelBase compatibility)
# =============================================================================

func show_menu() -> void:
	"""Show the menu (alias for activate with game pause)."""
	activate()
	if is_inside_tree():
		get_tree().paused = true


func close_menu() -> void:
	"""Close the menu (alias for deactivate with game unpause)."""
	if is_inside_tree():
		get_tree().paused = false
	deactivate()
