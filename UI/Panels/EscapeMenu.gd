class_name EscapeMenu
extends "res://UI/Core/OverlayBase.gd"

## Escape Menu
## Shows when ESC is pressed, provides save, load, restart and quit options
##
## OverlayStackManager Integration:
##   System-tier overlay (Z_TIER_SYSTEM = 4000)

signal restart_pressed()
signal dev_restart_pressed()  # Shift+R: Hard reset autoloads + reload
signal resume_pressed()
signal quit_pressed()
signal save_pressed()
signal load_pressed()
signal reload_last_save_pressed()
signal quantum_settings_pressed()
signal music_volume_changed(volume: float)

# Button indices for keyboard shortcuts
enum ButtonIndex {
	RESUME = 0,
	SAVE = 1,
	LOAD = 2,
	QUANTUM = 3,
	RELOAD = 4,
	RESTART = 5,
	QUIT = 6
}

# Volume control
var volume_slider: HSlider
var volume_label: Label


func _init():
	name = "EscapeMenu"

	# Configure OverlayBase
	overlay_name = "escape_menu"
	overlay_tier = 4000  # Z_TIER_SYSTEM
	panel_title = "PAUSED"
	panel_title_size = 28
	panel_size = Vector2(360, 420)
	panel_border_color = Color(0.5, 0.5, 0.3, 0.8)  # Gold border
	navigation_mode = NavigationMode.LINEAR
	use_scroll_container = false
	content_spacing = 8


func _build_content(container: Control) -> void:
	"""Build menu buttons."""
	# Ignore the container parameter - we add to _content_container via add_menu_button
	add_menu_button("Resume [ESC]", Color(0.3, 0.6, 0.3))
	add_menu_button("Save Game [S]", Color(0.2, 0.5, 0.7))
	add_menu_button("Load Game [L]", Color(0.5, 0.4, 0.7))
	add_menu_button("Quantum Settings [X]", Color(0.2, 0.6, 0.8))

	# Volume control
	_add_volume_control()

	add_menu_button("Reload Last Save [D]", Color(0.7, 0.4, 0.2))
	add_menu_button("Restart [R/⇧R]", Color(0.6, 0.5, 0.2))  # Shift+R = dev restart
	add_menu_button("Quit [Q]", Color(0.6, 0.3, 0.3))


func _add_volume_control() -> void:
	"""Add the music volume slider control."""
	var volume_container = HBoxContainer.new()
	volume_container.alignment = BoxContainer.ALIGNMENT_CENTER
	volume_container.add_theme_constant_override("separation", 8)

	var volume_icon = Label.new()
	volume_icon.text = "Music"
	volume_icon.add_theme_font_size_override("font_size", 14)
	volume_container.add_child(volume_icon)

	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.value = 0.7
	volume_slider.custom_minimum_size = Vector2(180, 24)
	volume_slider.value_changed.connect(_on_volume_changed)
	volume_container.add_child(volume_slider)

	volume_label = Label.new()
	volume_label.text = "70%"
	volume_label.custom_minimum_size = Vector2(40, 0)
	volume_label.add_theme_font_size_override("font_size", 14)
	volume_label.add_theme_color_override("font_color", UIStyleFactory.COLOR_TEXT_SUBTITLE)
	volume_container.add_child(volume_label)

	add_custom_control(volume_container)


func _on_button_activated(index: int) -> void:
	"""Handle button activation from keyboard or click."""
	match index:
		ButtonIndex.RESUME:
			_on_resume_pressed()
		ButtonIndex.SAVE:
			_on_save_pressed()
		ButtonIndex.LOAD:
			_on_load_pressed()
		ButtonIndex.QUANTUM:
			_on_quantum_settings_pressed()
		ButtonIndex.RELOAD:
			_on_reload_last_save_pressed()
		ButtonIndex.RESTART:
			_on_restart_pressed()
		ButtonIndex.QUIT:
			_on_quit_pressed()


func _on_action_q() -> void:
	"""Q = Quit (override base class action)."""
	_on_quit_pressed()


func _on_unhandled_key(keycode: int, event: InputEvent) -> bool:
	"""Handle keyboard shortcuts not captured by QER+F."""
	# Check for SaveLoadMenu being visible (don't process if it's open)
	var parent = get_parent()
	if parent:
		for child in parent.get_children():
			if child.name == "SaveLoadMenu" and child.visible:
				return false

	match keycode:
		KEY_S:
			_on_save_pressed()
			return true
		KEY_L:
			_on_load_pressed()
			return true
		KEY_D:
			_on_reload_last_save_pressed()
			return true
		KEY_X:
			_on_quantum_settings_pressed()
			return true
		KEY_COMMA:
			_adjust_volume(-0.1)
			return true
		KEY_PERIOD:
			_adjust_volume(0.1)
			return true
		KEY_SLASH:
			_toggle_mute()
			return true

	return false


func _on_action_r() -> void:
	"""R = Restart, Shift+R = Dev Restart (hard reset autoloads)."""
	# Check if shift is held for dev restart
	if Input.is_key_pressed(KEY_SHIFT):
		_on_dev_restart_pressed()
	else:
		_on_restart_pressed()


# =============================================================================
# BUTTON HANDLERS
# =============================================================================

func _on_resume_pressed():
	print("[INFO][UI] Resume pressed")
	close_menu()
	resume_pressed.emit()


func _on_restart_pressed():
	print("[INFO][UI] Restart pressed")
	restart_pressed.emit()
	close_menu()


func _on_dev_restart_pressed():
	print("[INFO][UI] DEV RESTART pressed (Shift+R) - Hard reset autoloads")
	dev_restart_pressed.emit()
	close_menu()


func _on_quit_pressed():
	print("[INFO][UI] Quit pressed from menu")
	quit_pressed.emit()
	get_tree().quit()


func _on_save_pressed():
	print("[INFO][UI] Save pressed")
	save_pressed.emit()


func _on_load_pressed():
	print("[INFO][UI] Load pressed")
	load_pressed.emit()


func _on_reload_last_save_pressed():
	print("[INFO][UI] Reload last save pressed")
	reload_last_save_pressed.emit()


func _on_quantum_settings_pressed():
	print("[INFO][UI] Quantum settings pressed")
	quantum_settings_pressed.emit()
	close_menu()


# =============================================================================
# VOLUME CONTROL
# =============================================================================

func _on_volume_changed(value: float):
	"""Handle volume slider change."""
	var percent = int(value * 100)
	volume_label.text = "%d%%" % percent

	# Update MusicManager if available
	if Engine.has_singleton("MusicManager"):
		Engine.get_singleton("MusicManager").set_volume(value)
	elif has_node("/root/MusicManager"):
		get_node("/root/MusicManager").set_volume(value)

	music_volume_changed.emit(value)


func _sync_volume_slider():
	"""Sync slider with current MusicManager volume."""
	var current_volume = 0.7  # Default

	if Engine.has_singleton("MusicManager"):
		current_volume = Engine.get_singleton("MusicManager").get_volume()
	elif has_node("/root/MusicManager"):
		current_volume = get_node("/root/MusicManager").get_volume()

	if volume_slider:
		volume_slider.value = current_volume
		volume_label.text = "%d%%" % int(current_volume * 100)


func _adjust_volume(delta: float):
	"""Adjust volume by delta amount."""
	if volume_slider:
		volume_slider.value = clampf(volume_slider.value + delta, 0.0, 1.0)


func _toggle_mute():
	"""Toggle music mute state."""
	if has_node("/root/MusicManager"):
		var music = get_node("/root/MusicManager")
		music.set_muted(not music.is_muted())
		if music.is_muted():
			volume_label.text = "MUTE"
		else:
			volume_label.text = "%d%%" % int(music.get_volume() * 100)


# =============================================================================
# SHOW/HIDE OVERRIDES
# =============================================================================

func _on_activated() -> void:
	_sync_volume_slider()
	# Pause the game when menu opens
	if is_inside_tree():
		get_tree().paused = true
	print("[INFO][UI] Menu opened - Game PAUSED")


func _on_deactivated() -> void:
	# Unpause the game when menu closes
	if is_inside_tree():
		get_tree().paused = false
	print("[INFO][UI] Menu closed - Game RESUMED")


# Legacy compatibility aliases
func hide_menu():
	close_menu()
