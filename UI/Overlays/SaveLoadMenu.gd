class_name SaveLoadMenu
extends "res://UI/Core/OverlayBase.gd"

## Save/Load Menu
## Unified modal implementation using OverlayBase.

signal slot_selected(slot: int, mode: String)
signal debug_environment_selected(env_name: String)
signal menu_closed()

enum Mode { SAVE, LOAD }

var current_mode: Mode = Mode.LOAD
var slot_buttons: Array[Button] = []
var debug_env_buttons: Array[Button] = []
var selected_slot_index: int = 0
var selected_is_debug: bool = false

# Optional InputController injection (legacy compatibility)
var input_controller: Node = null

# Debug environments: name -> display name
var debug_environments = {
	"minimal_farm": "🌱 Minimal Farm",
	"wealthy_farm": "💰 Wealthy Farm",
	"fully_planted_farm": "🌾 Fully Planted",
	"fully_measured_farm": "🔬 Fully Measured",
	"fully_entangled_farm": "🔗 Entangled Chain",
	"mixed_quantum_farm": "⚛️ Mixed Quantum",
	"icons_active_farm": "✨ Icons Active",
	"mid_game_farm": "🎮 Mid-Game State"
}

var hints_label: Label
var scroll_container: ScrollContainer
var content_vbox: VBoxContainer
var debug_section_label: Label


func _init():
	overlay_name = "save_load_menu"
	overlay_tier = 19  # Above EscapeMenu, still below action bars
	panel_title = "LOAD GAME"
	panel_title_size = 28
	panel_size_mode = PanelSizeMode.LARGE
	panel_border_color = Color(0.4, 0.6, 0.8, 0.8)
	navigation_mode = NavigationMode.NONE
	use_scroll_container = false
	content_spacing = 8
	action_labels = {
		"Q": "Confirm",
		"E": "Cancel",
		"R": "Previous",
		"F": "Next"
	}


func _build_content(container: Control) -> void:
	hints_label = Label.new()
	hints_label.text = "WASD or arrows to select  |  Q, ENTER, or SPACE to confirm  |  E or ESC to cancel"
	hints_label.add_theme_font_size_override("font_size", 14)
	hints_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hints_label.add_theme_color_override("font_color", UIStyleFactory.COLOR_TEXT_SUBTITLE)
	container.add_child(hints_label)

	scroll_container = ScrollContainer.new()
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.custom_minimum_size = Vector2(0, 340)
	container.add_child(scroll_container)

	content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", UIStyleFactory.VBOX_SPACING_NORMAL)
	scroll_container.add_child(content_vbox)

	var saves_label = Label.new()
	saves_label.name = "SavesLabel"
	saves_label.text = "💾 SAVE SLOTS"
	saves_label.add_theme_font_size_override("font_size", 18)
	saves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	saves_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	content_vbox.add_child(saves_label)

	for slot in range(3):
		var slot_btn = _create_slot_button(slot)
		slot_buttons.append(slot_btn)
		content_vbox.add_child(slot_btn)

	debug_section_label = Label.new()
	debug_section_label.name = "DebugSectionLabel"
	debug_section_label.text = "🧪 DEBUG SCENARIOS"
	debug_section_label.add_theme_font_size_override("font_size", 18)
	debug_section_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	debug_section_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	debug_section_label.visible = false
	content_vbox.add_child(debug_section_label)

	for env_name in debug_environments.keys():
		var env_btn = _create_debug_env_button(env_name, debug_environments[env_name])
		debug_env_buttons.append(env_btn)
		content_vbox.add_child(env_btn)
		env_btn.visible = false

	var cancel_btn = _create_menu_button("Cancel [E/ESC]", Color(0.6, 0.3, 0.3))
	cancel_btn.pressed.connect(_on_cancel_pressed)
	container.add_child(cancel_btn)


func handle_input(event: InputEvent) -> bool:
	if not visible or not is_active:
		return false
	if not event is InputEventKey or not event.pressed or event.echo:
		return false

	match event.keycode:
		KEY_ESCAPE:
			_on_cancel_pressed()
			return true
		KEY_Q:
			_confirm_selection()
			return true
		KEY_E:
			_on_cancel_pressed()
			return true
		KEY_R:
			_select_previous_slot()
			return true
		KEY_F:
			_select_next_slot()
			return true
		KEY_UP, KEY_W, KEY_LEFT, KEY_A:
			_select_previous_slot()
			return true
		KEY_DOWN, KEY_S, KEY_RIGHT, KEY_D:
			_select_next_slot()
			return true
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_confirm_selection()
			return true

	return false


func _on_activated() -> void:
	_refresh_menu_state()
	if input_controller:
		input_controller.set_process_input(false)


func _on_deactivated() -> void:
	if input_controller:
		input_controller.set_process_input(true)


func _on_action_q() -> void:
	_confirm_selection()


func _on_action_e() -> void:
	_on_cancel_pressed()


func _on_action_r() -> void:
	_select_previous_slot()


func _on_action_f() -> void:
	_select_next_slot()


func _create_slot_button(slot: int) -> Button:
	var btn = UIStyleFactory.create_styled_button("[Empty]", Color(0.3, 0.4, 0.5))
	btn.name = "SlotButton" + str(slot)
	btn.custom_minimum_size = Vector2(0, 80)
	btn.add_theme_font_size_override("font_size", 20)
	btn.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	btn.pressed.connect(_on_slot_pressed.bind(slot))
	return btn


func _create_debug_env_button(env_name: String, display_name: String) -> Button:
	var btn = UIStyleFactory.create_styled_button(display_name, Color(0.4, 0.35, 0.2))
	btn.name = "DebugEnvButton_" + env_name
	btn.custom_minimum_size = Vector2(0, 60)
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(_on_debug_env_pressed.bind(env_name))
	return btn


func _create_menu_button(text: String, color: Color) -> Button:
	var btn = UIStyleFactory.create_styled_button(text, color)
	btn.custom_minimum_size = Vector2(0, 50)
	btn.add_theme_font_size_override("font_size", 24)
	return btn


func _select_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= slot_buttons.size():
		return
	if current_mode == Mode.LOAD and slot_buttons[slot_index].disabled:
		return
	selected_slot_index = slot_index
	selected_is_debug = false
	_update_visual_selection()


func _select_next_slot() -> void:
	if selected_is_debug:
		if debug_env_buttons.is_empty():
			return
		selected_slot_index = (selected_slot_index + 1) % debug_env_buttons.size()
		_update_visual_selection()
		return

	var next_slot = (selected_slot_index + 1) % 3
	var is_wrapping = next_slot == 0 and selected_slot_index == 2

	if current_mode == Mode.LOAD:
		if not is_wrapping and not slot_buttons[next_slot].disabled:
			selected_slot_index = next_slot
			selected_is_debug = false
			_update_visual_selection()
			return
		if not debug_env_buttons.is_empty():
			selected_slot_index = 0
			selected_is_debug = true
			_update_visual_selection()
			return
	else:
		selected_slot_index = next_slot
		_update_visual_selection()


func _select_previous_slot() -> void:
	if selected_is_debug:
		if debug_env_buttons.is_empty():
			return
		selected_slot_index = (selected_slot_index - 1 + debug_env_buttons.size()) % debug_env_buttons.size()
		_update_visual_selection()
		return

	var prev_slot = (selected_slot_index - 1 + 3) % 3
	var is_wrapping = prev_slot == 2 and selected_slot_index == 0

	if current_mode == Mode.LOAD:
		if not is_wrapping and not slot_buttons[prev_slot].disabled:
			selected_slot_index = prev_slot
			selected_is_debug = false
			_update_visual_selection()
			return
		if not debug_env_buttons.is_empty():
			selected_slot_index = debug_env_buttons.size() - 1
			selected_is_debug = true
			_update_visual_selection()
			return
	else:
		selected_slot_index = prev_slot
		_update_visual_selection()


func _update_visual_selection() -> void:
	var selected_control: Control = null

	for i in range(slot_buttons.size()):
		var btn = slot_buttons[i]
		var style = btn.get_theme_stylebox("normal") as StyleBoxFlat
		if not style:
			continue
		if i == selected_slot_index and not selected_is_debug and not btn.disabled:
			style.border_width_left = 4
			style.border_width_right = 4
			style.border_width_top = 4
			style.border_width_bottom = 4
			style.border_color = Color(1.0, 0.8, 0.0)
			selected_control = btn
		else:
			style.border_width_left = 0
			style.border_width_right = 0
			style.border_width_top = 0
			style.border_width_bottom = 0

	for i in range(debug_env_buttons.size()):
		var env_btn = debug_env_buttons[i]
		var env_style = env_btn.get_theme_stylebox("normal") as StyleBoxFlat
		if not env_style:
			continue
		if i == selected_slot_index and selected_is_debug:
			env_style.border_width_left = 4
			env_style.border_width_right = 4
			env_style.border_width_top = 4
			env_style.border_width_bottom = 4
			env_style.border_color = Color(1.0, 0.8, 0.0)
			selected_control = env_btn
		else:
			env_style.border_width_left = 0
			env_style.border_width_right = 0
			env_style.border_width_top = 0
			env_style.border_width_bottom = 0

	if selected_control and scroll_container:
		_scroll_to_control(selected_control)


func _scroll_to_control(ctrl: Control) -> void:
	if not scroll_container or not ctrl:
		return

	var ctrl_pos = ctrl.position.y
	var ctrl_height = ctrl.size.y
	var scroll_pos = scroll_container.scroll_vertical
	var view_height = scroll_container.size.y

	if ctrl_pos < scroll_pos:
		scroll_container.scroll_vertical = int(ctrl_pos)
	elif ctrl_pos + ctrl_height > scroll_pos + view_height:
		scroll_container.scroll_vertical = int(ctrl_pos + ctrl_height - view_height)


func _confirm_selection() -> void:
	if selected_is_debug:
		var env_name = debug_env_buttons[selected_slot_index].name.trim_prefix("DebugEnvButton_")
		_on_debug_env_pressed(env_name)
		return
	if slot_buttons[selected_slot_index].disabled:
		return
	_on_slot_pressed(selected_slot_index)


func inject_input_controller(controller: Node) -> void:
	input_controller = controller


func _refresh_menu_state() -> void:
	panel_title = "SAVE GAME" if current_mode == Mode.SAVE else "LOAD GAME"
	set_title(panel_title)

	_update_slot_info()

	var is_load = current_mode == Mode.LOAD
	if debug_section_label:
		debug_section_label.visible = is_load
	for env_btn in debug_env_buttons:
		env_btn.visible = is_load

	selected_slot_index = 0
	selected_is_debug = false
	if is_load:
		for i in range(3):
			if not slot_buttons[i].disabled:
				selected_slot_index = i
				break

	_update_visual_selection()


func open_menu(mode: Mode) -> void:
	current_mode = mode
	if not visible:
		activate()
	else:
		_refresh_menu_state()


func show_menu() -> void:
	# MenuPanelBase compatibility signature (no args).
	open_menu(current_mode)


func hide_menu() -> void:
	deactivate()


func _update_slot_info() -> void:
	if not is_node_ready():
		return

	var gsm = get_node_or_null("/root/GameStateManager")
	if not gsm:
		return

	for slot in range(3):
		var btn = slot_buttons[slot]
		var save_info = gsm.get_save_info(slot)
		if save_info["exists"]:
			btn.text = "Slot %d\n%s\n💰%d credits" % [slot + 1, save_info["display_name"], save_info["credits"]]
			var style = btn.get_theme_stylebox("normal") as StyleBoxFlat
			if style:
				style.bg_color = Color(0.2, 0.5, 0.7)
			btn.disabled = false
		else:
			btn.text = "Slot %d\n[Empty - Click to Save]" % [slot + 1] if current_mode == Mode.SAVE else "Slot %d\n[Empty]" % [slot + 1]
			var empty_style = btn.get_theme_stylebox("normal") as StyleBoxFlat
			if empty_style:
				empty_style.bg_color = Color(0.2, 0.2, 0.2) if current_mode == Mode.LOAD else Color(0.3, 0.4, 0.5)
			btn.disabled = (current_mode == Mode.LOAD)


func _on_slot_pressed(slot: int) -> void:
	slot_selected.emit(slot, "save" if current_mode == Mode.SAVE else "load")
	hide_menu()


func _on_debug_env_pressed(env_name: String) -> void:
	debug_environment_selected.emit(env_name)
	hide_menu()


func _on_cancel_pressed() -> void:
	menu_closed.emit()
	hide_menu()
