class_name LoggerConfigPanel
extends "res://UI/Core/OverlayBase.gd"


## Logger Configuration Panel
## Runtime UI for configuring log categories and levels.
## Registered as a debug overlay and intentionally unbound from the top-level menu row.

# Category controls
var category_checkboxes: Dictionary = {}  # category_name -> CheckBox
var category_option_buttons: Dictionary = {}  # category_name -> OptionButton

# Console/file toggles
var console_checkbox: CheckBox
var file_checkbox: CheckBox
var timestamps_checkbox: CheckBox

# Category emojis for display
const CATEGORY_EMOJIS = {
	"ui": "📋",
	"input": "⌨️",
	"quantum": "🔬",
	"farm": "🌾",
	"economy": "💰",
	"biome": "🌍",
	"save": "💾",
	"quest": "📋",
	"boot": "🚀",
	"test": "🧪",
	"perf": "⏱️",
	"network": "🕸️",
}


func _init():
	name = "LoggerConfigPanel"
	overlay_name = "logger"
	panel_title = "Logger Config"
	panel_size_mode = PanelSizeMode.MEDIUM
	panel_border_color = Color(0.3, 0.5, 0.3, 0.8)  # Green border
	show_dimmer = true
	use_scroll_container = false
	navigation_mode = NavigationMode.NONE
	overlay_tier = 11  # Info-tier overlay, below buttons and above gameplay
	set_action_info("R", {"label": "Reset Defaults"})


func _build_content(container: Control) -> void:
	# Build logger config UI inside OverlayBase panel.
	var _verbose = get_node_or_null("/root/VerboseConfig")
	if not _verbose:
		var err = Label.new()
		err.text = "VerboseConfig not available"
		container.add_child(err)
		return

	# Output options section
	_create_output_options(container, _verbose)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 8)
	container.add_child(spacer1)

	# Categories label
	var cat_label = Label.new()
	cat_label.text = "Categories (Enable | Level)"
	cat_label.add_theme_font_size_override("font_size", 16)
	cat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(cat_label)

	# Scroll container for categories
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 240)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(scroll)

	var categories_vbox = VBoxContainer.new()
	categories_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(categories_vbox)

	# Create category controls
	_create_category_controls(categories_vbox, _verbose)

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 8)
	container.add_child(spacer2)

	# Buttons
	_create_buttons(container)


func _create_output_options(parent: Control, _verbose: Node) -> void:
	# Create output toggles (console, file, timestamps)
	var output_hbox = HBoxContainer.new()
	output_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	output_hbox.add_theme_constant_override("separation", 20)
	parent.add_child(output_hbox)

	# Console output
	console_checkbox = CheckBox.new()
	console_checkbox.text = "Console Output"
	console_checkbox.button_pressed = _verbose.enable_console_output
	console_checkbox.toggled.connect(func(enabled): _on_console_toggled(enabled, _verbose))
	output_hbox.add_child(console_checkbox)

	# File logging
	file_checkbox = CheckBox.new()
	file_checkbox.text = "File Logging"
	file_checkbox.button_pressed = _verbose.enable_file_logging
	file_checkbox.toggled.connect(func(enabled): _on_file_toggled(enabled, _verbose))
	output_hbox.add_child(file_checkbox)

	# Timestamps
	timestamps_checkbox = CheckBox.new()
	timestamps_checkbox.text = "Timestamps"
	timestamps_checkbox.button_pressed = _verbose.show_timestamps
	timestamps_checkbox.toggled.connect(func(enabled): _on_timestamps_toggled(enabled, _verbose))
	output_hbox.add_child(timestamps_checkbox)


func _create_category_controls(categories_vbox: VBoxContainer, _verbose: Node) -> void:
	# Create checkbox + dropdown for each category
	var categories = _verbose.get_all_categories()
	categories.sort()  # Alphabetical order

	for category in categories:
		var row_hbox = HBoxContainer.new()
		row_hbox.add_theme_constant_override("separation", 10)
		categories_vbox.add_child(row_hbox)

		# Checkbox (enable/disable)
		var checkbox = CheckBox.new()
		checkbox.button_pressed = _verbose.category_enabled.get(category, true)
		checkbox.toggled.connect(func(enabled): _on_category_enabled_changed(category, enabled, _verbose))
		row_hbox.add_child(checkbox)
		category_checkboxes[category] = checkbox

		# Category label with emoji
		var emoji = CATEGORY_EMOJIS.get(category, "📌")
		var label = Label.new()
		label.text = "%s %s" % [emoji, category.capitalize()]
		label.custom_minimum_size = Vector2(180, 0)
		row_hbox.add_child(label)

		# Log level dropdown
		var option_btn = OptionButton.new()
		option_btn.custom_minimum_size = Vector2(100, 0)

		# Add log level options
		for i in range(_verbose.LogLevel.size()):
			option_btn.add_item(_verbose.LEVEL_NAMES[i])

		# Set current level
		var current_level = _verbose.get_category_level(category)
		option_btn.selected = current_level
		option_btn.item_selected.connect(func(idx): _on_category_level_changed(category, idx, _verbose))
		row_hbox.add_child(option_btn)
		category_option_buttons[category] = option_btn


func _create_buttons(parent: Control) -> void:
	# Create action buttons at bottom
	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_hbox.add_theme_constant_override("separation", 15)
	parent.add_child(button_hbox)

	# Reset to defaults button
	var reset_btn = Button.new()
	reset_btn.text = "Reset to Defaults [R]"
	reset_btn.custom_minimum_size = Vector2(170, 40)
	reset_btn.pressed.connect(_on_reset_pressed)
	button_hbox.add_child(reset_btn)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close [ESC]"
	close_btn.custom_minimum_size = Vector2(150, 40)
	close_btn.pressed.connect(deactivate)
	button_hbox.add_child(close_btn)


# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_console_toggled(enabled: bool, _verbose: Node) -> void:
	_verbose.enable_console_output = enabled


func _on_file_toggled(enabled: bool, _verbose: Node) -> void:
	_verbose.enable_file_logging = enabled
	if enabled and not _verbose._log_file:
		_verbose._init_file_logging()


func _on_timestamps_toggled(enabled: bool, _verbose: Node) -> void:
	_verbose.show_timestamps = enabled


func _on_category_enabled_changed(category: String, enabled: bool, _verbose: Node) -> void:
	_verbose.set_category_enabled(category, enabled)


func _on_category_level_changed(category: String, level_idx: int, _verbose: Node) -> void:
	_verbose.set_category_level(category, level_idx)


func _on_reset_pressed() -> void:
	# Reset all categories to default levels
	var _verbose = get_node_or_null("/root/VerboseConfig")
	if not _verbose:
		return

	_verbose.category_levels = {
		"ui": _verbose.LogLevel.INFO,
		"input": _verbose.LogLevel.WARN,
		"quantum": _verbose.LogLevel.INFO,
		"farm": _verbose.LogLevel.INFO,
		"economy": _verbose.LogLevel.INFO,
		"biome": _verbose.LogLevel.WARN,
		"save": _verbose.LogLevel.INFO,
		"quest": _verbose.LogLevel.INFO,
		"boot": _verbose.LogLevel.INFO,
		"test": _verbose.LogLevel.TRACE,
		"perf": _verbose.LogLevel.WARN,
		"network": _verbose.LogLevel.DEBUG,
	}

	# Enable all categories
	for category in _verbose.category_enabled.keys():
		_verbose.category_enabled[category] = true

	# Refresh UI
	_refresh_ui(_verbose)


func _on_action_r() -> void:
	# R = Reset to defaults.
	_on_reset_pressed()


func _refresh_ui(_verbose: Node) -> void:
	# Update UI controls to match current VerboseConfig state
	for category in category_checkboxes.keys():
		var checkbox = category_checkboxes[category]
		checkbox.button_pressed = _verbose.category_enabled.get(category, true)

		var option_btn = category_option_buttons[category]
		option_btn.selected = _verbose.get_category_level(category)

	if console_checkbox:
		console_checkbox.button_pressed = _verbose.enable_console_output
	if file_checkbox:
		file_checkbox.button_pressed = _verbose.enable_file_logging
	if timestamps_checkbox:
		timestamps_checkbox.button_pressed = _verbose.show_timestamps


# ============================================================================
# SNAPSHOT PROTOCOL
# ============================================================================

func get_snapshot() -> Dictionary:
	# Return all currently-displayed state as structured data.
	var _verbose = get_node_or_null("/root/VerboseConfig")
	if not _verbose:
		return {"error": "verbose_config_unavailable"}

	var categories: Array = []
	var all_cats = _verbose.get_all_categories()
	all_cats.sort()
	for cat in all_cats:
		var level_idx = _verbose.get_category_level(cat)
		var level_name = _verbose.LEVEL_NAMES[level_idx] if level_idx < _verbose.LEVEL_NAMES.size() else "UNKNOWN"
		categories.append({
			"name": cat,
			"enabled": _verbose.category_enabled.get(cat, true),
			"level": level_name
		})

	return {
		"categories": categories,
		"console_enabled": _verbose.enable_console_output,
		"file_enabled": _verbose.enable_file_logging,
		"timestamps_enabled": _verbose.show_timestamps
	}
