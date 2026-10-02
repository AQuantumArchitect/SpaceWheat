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


const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")

# =============================================================================
# SIGNALS
# =============================================================================

signal overlay_opened()
signal overlay_closed()
signal action_performed(action: String, data: Dictionary)
signal action_labels_changed()

# =============================================================================
# OVERLAY INTERFACE (for OverlayStackManager)
# =============================================================================

var overlay_name: String = "overlay"
var overlay_icon: String = ""
var overlay_tier: int = 11  # Z_TIER_INFO=11, Z_TIER_MODAL=14, Z_TIER_SYSTEM=18

var action_labels: Dictionary = {
	"Q": "",
	"E": "",
	"R": "",
	"F": ""
}

# Rich action metadata — set via set_action_info(). Overlays that populate this
# get full chip rendering (emoji, icon, hint, destructive color) instead of string-only labels.
var _action_infos: Dictionary = {"Q": {}, "E": {}, "R": {}, "F": {}}

# =============================================================================
# PANEL CONFIGURATION (set in _init before _ready)
# =============================================================================

var panel_title: String = ""
var panel_title_size: int = 24
var panel_size: Vector2 = Vector2(600, 450)
enum PanelSizeMode { SMALL, MEDIUM, LARGE, CUSTOM }
var panel_size_mode: PanelSizeMode = PanelSizeMode.MEDIUM
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
var _resolved_panel_size: Vector2 = Vector2.ZERO

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
	# Direct input handling when overlay is visible.
	#
	# This captures input directly rather than relying only on OverlayStackManager routing.
	if not visible or not is_active:
		return

	if handle_input(event):
		get_viewport().set_input_as_handled()


func _build_panel() -> void:
	# Build the overlay UI structure.
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
	_resolved_panel_size = _resolve_panel_size()
	_panel.custom_minimum_size = _resolved_panel_size
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
		var scroll_size = Vector2(_resolved_panel_size.x - 40, _resolved_panel_size.y - 80)
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
	# Override to add content. Called during _ready().
	pass


# =============================================================================
# ACTIVATION / DEACTIVATION
# =============================================================================

func activate() -> void:
	# Called when overlay opens.
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
	# Called when overlay closes.
	is_active = false
	visible = false
	_on_deactivated()
	overlay_closed.emit()


func _on_activated() -> void:
	# Override for custom activation logic.
	pass


func _on_deactivated() -> void:
	# Override for custom deactivation logic.
	pass


# =============================================================================
# INPUT HANDLING
# =============================================================================

func handle_input(event: InputEvent) -> bool:
	# Handle input when overlay is active. Returns true if consumed.
	if not visible or not is_active:
		return false

	if not event is InputEventKey or not event.pressed or event.echo:
		return false

	var keycode = event.keycode

	# ESC - don't consume, let OverlayStackManager handle it
	if keycode == KEY_ESCAPE:
		return false

	# QERF action keys. Chip-honesty gate: when this overlay declares action
	# labels, a key whose chip reads "—" must NO-OP — a dash chip with a live
	# key is a text lie (fleet playtest). Overlays that declare nothing keep
	# legacy behavior. F takes the SAME gate as Q/E/R (it was keyboard-only
	# ungated while chip-tap-F was gated — an input-path asymmetry), and a
	# gated-off key speaks instead of dying silently (anti-gating law).
	# Shift rides the same chip: a declared shift_label / shift_action fires
	# the shift handler; otherwise Shift+key is the same verb (mouse parity).
	var shift: bool = false
	if event is InputEventWithModifiers:
		shift = (event as InputEventWithModifiers).is_shift_pressed()
	if keycode == InputBindingRegistry.get_action_keycode("Q"):
		return _dispatch_action_key("Q", shift)
	if keycode == InputBindingRegistry.get_action_keycode("E"):
		return _dispatch_action_key("E", shift)
	if keycode == InputBindingRegistry.get_action_keycode("R"):
		return _dispatch_action_key("R", shift)
	if keycode == InputBindingRegistry.get_action_keycode("F"):
		if _action_key_declared_live("F"):
			_fire_action_key("F", shift)
			return true
		# Dead F must not eat a live toast-follow (wave 16: Market "—"
		# toasted `nothing on F here` over `[F] opens Self`).
		return false

	# ENTER/SPACE keys - activate selected item
	if InputBindingRegistry.is_menu_confirm_key(keycode):
		_activate_selected()
		return true

	# Let subclass handle other keys
	return _on_unhandled_key(keycode, event)


func _on_unhandled_key(_keycode: int, _event: InputEvent) -> bool:
	# Override to handle keys not caught by standard routing.
	return false


## Route an action verb (Q/E/R/F) from a non-keyboard source (button tap, touch).
## Mirrors handle_input() for QERF without needing a key event.
## Called by PlayerShell._route_action_key() when action chips are tapped.
## `shift` is the same modifier the keyboard path reads — Shift+click on a
## chip must fire the advertised shift verb (Market Shift+F Lock, Ace Reap).
func handle_action(action_key: String, shift: bool = false) -> bool:
	if not is_active:
		return false
	match action_key:
		"Q", "E", "R", "F":
			return _dispatch_action_key(action_key, shift)
	return false


func _dispatch_action_key(key: String, shift: bool = false) -> bool:
	if _action_key_declared_live(key):
		_fire_action_key(key, shift)
	else:
		RefusalVoice.note("nothing on %s here" % key)
	return true


func _has_shift_action(key: String) -> bool:
	var info = _action_infos.get(key, {})
	if not (info is Dictionary):
		return false
	if str(info.get("shift_label", "")).strip_edges() != "":
		return true
	if str(info.get("shift_action", "")).strip_edges() != "":
		return true
	return false


func _fire_action_key(key: String, shift: bool = false) -> void:
	if shift and _has_shift_action(key):
		match key:
			"Q": _on_action_shift_q()
			"E": _on_action_shift_e()
			"R": _on_action_shift_r()
			"F": _on_action_shift_f()
		return
	match key:
		"Q": _on_action_q()
		"E":
			_on_action_e()
			_maybe_show_inspect_toast()
		"R": _on_action_r()
		"F": _on_action_f()


## Chip-honesty gate: true when this key may fire its handler. Overlays that
## declare action infos bind their keys to their chips — a "—" chip means the
## key must no-op. Overlays that declare nothing keep legacy pass-through.
## E stays live whenever inspect text exists — the universal "tell me more"
## is its own honest feedback.
func _action_key_declared_live(key: String) -> bool:
	if _action_infos.is_empty():
		return true
	if key == "E" and get_inspect_text() != "":
		return true
	var label := str(_action_infos.get(key, {}).get("label", ""))
	return label != "" and label != "—" and label != "-"


# =============================================================================
# ACTION HANDLERS (override in subclass)
# =============================================================================

func _on_action_q() -> void:
	# Q key action. Override for custom behavior.
	action_performed.emit("q", {"selected": selected_index})


func _on_action_e() -> void:
	# E key action. Override for custom behavior.
	action_performed.emit("e", {"selected": selected_index})


## Inspect text for the currently-focused item. Override per overlay to return
## a string the player can read on E-press. Default returns "". When non-empty,
## OverlayBase routes it to PlayerShell.show_hint() as a teal toast on every E.
## Return "" and unfold in-menu when the overlay IS the room (Arc inspect).
##
## Convention: keep it short (one item's worth of detail). Use \n between lines.
## Empty string means "no inspect content here" — E continues to do its normal
## action without a toast popup.
func get_inspect_text() -> String:
	return ""


## Secondary text hook: the tooltip of whatever UI element is currently
## highlighted/selected. Override per overlay. Default returns "".
## Checked only when get_inspect_text() is empty, so inspect_text wins.
func get_hovered_tooltip() -> String:
	return ""


## Spawn an inspect toast if get_inspect_text() returns non-empty. Called by
## OverlayBase right after _on_action_e() so subclasses don't need to opt in
## explicitly — they just override get_inspect_text() and the toast follows.
func _maybe_show_inspect_toast() -> void:
	var text: String = get_inspect_text()
	if text == "":
		text = get_hovered_tooltip()
	if text == "":
		return
	var ps: Node = _find_player_shell()
	if ps == null or not ps.has_method("show_hint"):
		return
	ps.show_hint(text, 2, "")


func _find_player_shell() -> Node:
	var n: Node = self
	while n != null:
		if n is PlayerShell:
			return n
		n = n.get_parent()
	return null


func _on_action_r() -> void:
	# R key action. Override for custom behavior.
	action_performed.emit("r", {"selected": selected_index})


func _on_action_f() -> void:
	# F key action. Override for custom behavior.
	action_performed.emit("f", {"selected": selected_index})


## Shift+QERF — default is the unshifted verb so a held Shift never eats the
## advertised action. Overlays that bind a real shift_label override these.
func _on_action_shift_q() -> void:
	_on_action_q()


func _on_action_shift_e() -> void:
	_on_action_e()
	_maybe_show_inspect_toast()


func _on_action_shift_r() -> void:
	_on_action_r()


func _on_action_shift_f() -> void:
	_on_action_f()


# =============================================================================
# OVERLAY INTERFACE
# =============================================================================

func get_overlay_tier() -> int:
	# Get z-index tier for OverlayStackManager.
	return overlay_tier


func get_action_labels() -> Dictionary:
	# Get current QER+F labels.
	return action_labels.duplicate()


func set_action_info(key: String, info: Dictionary) -> void:
	# Store rich action metadata for a key. Does NOT emit action_labels_changed —
	# call that yourself once after setting all keys for the current update cycle.
	_action_infos[key] = info
	action_labels[key] = str(info.get("label", ""))  # keep string path in sync


func get_action_info(key: String) -> Dictionary:
	return _action_infos.get(key, {})


func push_action_infos(infos: Dictionary) -> void:
	for key in ["Q", "E", "R", "F"]:
		set_action_info(key, infos.get(key, {"label": "—"}))
	action_labels_changed.emit()


func push_action_label_strings(labels: Dictionary) -> void:
	for key in ["Q", "E", "R", "F"]:
		set_action_info(key, {"label": str(labels.get(key, "—"))})
	action_labels_changed.emit()


## One spelling of this overlay's live chip for toasts, banners, notes.
## Reads the same _action_infos the HUD bar already shows.
func action_cue(key: String, shift: bool = false) -> String:
	var k := str(key).strip_edges().to_upper()
	var info = _action_infos.get(k, {})
	if not (info is Dictionary):
		info = {}
	var label := str(info.get("label", action_labels.get(k, "")))
	if shift:
		label = str(info.get("shift_label", ""))
	return ToolConfig.cue(k, label, shift)


# =============================================================================
# LAYOUT MANAGER
# =============================================================================

func set_layout_manager(layout_mgr: Node) -> void:
	# Set UILayoutManager reference for responsive sizing.
	if layout_manager and layout_manager.has_signal("layout_changed"):
		if layout_manager.layout_changed.is_connected(_on_layout_changed):
			layout_manager.layout_changed.disconnect(_on_layout_changed)
	layout_manager = layout_mgr
	if layout_manager and layout_manager.has_signal("layout_changed"):
		if not layout_manager.layout_changed.is_connected(_on_layout_changed):
			layout_manager.layout_changed.connect(_on_layout_changed)
	_apply_panel_size()


func _on_layout_changed(_new_layout: Dictionary) -> void:
	_apply_panel_size()


func _resolve_panel_size() -> Vector2:
	# Resolve panel size from layout manager + panel_size_mode.
	if panel_size_mode == PanelSizeMode.CUSTOM:
		return panel_size
	if not layout_manager or not layout_manager.has_method("get_modal_size"):
		return panel_size
	match panel_size_mode:
		PanelSizeMode.SMALL:
			return layout_manager.get_modal_size("small")
		PanelSizeMode.LARGE:
			return layout_manager.get_modal_size("large")
		_:
			return layout_manager.get_modal_size("medium")


func _apply_panel_size() -> void:
	if not _panel:
		return
	_resolved_panel_size = _resolve_panel_size()
	if _resolved_panel_size == Vector2.ZERO:
		return
	_panel.custom_minimum_size = _resolved_panel_size
	if _scroll_container:
		_scroll_container.custom_minimum_size = Vector2(_resolved_panel_size.x - 40, _resolved_panel_size.y - 80)


# =============================================================================
# UTILITY
# =============================================================================

func set_title(text: String) -> void:
	# Update the panel title.
	panel_title = text
	if _title_label:
		_title_label.text = text


func get_panel() -> PanelContainer:
	# Get the main panel for custom styling.
	return _panel


# =============================================================================
# BUTTON MENU SUPPORT
# =============================================================================

var _menu_buttons: Array[Button] = []

func add_menu_button(text: String, color: Color, callback: Callable = Callable()) -> Button:
	# Add a styled button to the content area.
	#
	# Args:
	# text: Button text
	# color: Button background color
	# callback: Optional callback for button press
	#
	# Returns the created Button.
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
	# Add a custom control (slider, separator, etc.) to the content area.
	_content_container.add_child(control)


func _on_menu_button_pressed(index: int) -> void:
	# Internal handler for button presses.
	_on_button_activated(index)


func _on_button_activated(_index: int) -> void:
	# Override in subclass to handle button activation.
	pass


func _update_selection_visual() -> void:
	# Update visual indication of selection.
	for i in range(_menu_buttons.size()):
		UIStyleFactory.apply_selection_modulate(_menu_buttons[i], i == selected_index)


func _activate_selected() -> void:
	# Activate the currently selected item (for ENTER key).
	if selected_index >= 0 and selected_index < _menu_buttons.size():
		_menu_buttons[selected_index].emit_signal("pressed")
