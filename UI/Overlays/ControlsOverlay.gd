class_name ControlsOverlay
extends "res://UI/Core/OverlayBase.gd"

const MenuRegistry = preload("res://UI/Core/MenuRegistry.gd")
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")

## ControlsOverlay - Full keyboard reference with section navigation
##
## Controls:
##   Q/E = Navigate sections
##   R = Search/filter (future)
##   F = Toggle compact/full mode
##   WASD = Navigate within section
##   ESC = Close overlay

# Sections
enum Section {
	TOOL_SELECTION,
	ACTIONS,
	NAVIGATION,
	OVERLAYS,
	QUANTUM_UI,
	ADVANCED
}

const SECTION_NAMES = [
	"Tool Selection",
	"Actions (QERF)",
	"Biome & Plot Nav",
	"Overlays & Menus",
	"Quantum UI",
	"Advanced Actions"
]

const SECTION_ICONS = ["Tools", "Actions", "Nav", "Overlays", "Quantum", "Advanced"]

var current_section: int = Section.TOOL_SELECTION
var compact_mode: bool = false
var overlay_source = null

# UI elements
var section_tabs: HBoxContainer
var sections_container: VBoxContainer
var section_panels: Array = []

# Layout
const COMPACT_HEIGHT: int = 300


func _init():
	overlay_name = "controls"
	overlay_icon = ""
	overlay_tier = 11  # Z_TIER_INFO
	panel_title = "Keyboard Controls"
	panel_size_mode = PanelSizeMode.LARGE
	panel_border_color = Color(0.5, 0.5, 0.3, 0.8)  # Gold/tan border
	navigation_mode = NavigationMode.NONE  # We handle our own Q/E navigation
	action_labels = {
		"Q": "Prev Section",
		"E": "Next Section",
		"R": "Search",
		"F": "Compact/Full"
	}


func _build_content(container: Control) -> void:
	"""Build the controls overlay content."""
	# Section tabs
	section_tabs = _create_section_tabs()
	container.add_child(section_tabs)

	# Sections container
	sections_container = VBoxContainer.new()
	sections_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(sections_container)

	# Create section panels
	_create_section_panels()
	_update_section_display()


func set_overlay_source(source) -> void:
	overlay_source = source
	if sections_container:
		_rebuild_sections()


func _create_section_tabs() -> HBoxContainer:
	"""Create section tab bar."""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	for i in range(SECTION_NAMES.size()):
		var tab = Button.new()
		tab.text = SECTION_ICONS[i]
		tab.add_theme_font_size_override("font_size", 11)
		tab.toggle_mode = true
		tab.button_pressed = (i == current_section)
		tab.pressed.connect(func(): _select_section(i))
		hbox.add_child(tab)

	return hbox


func _create_section_panels() -> void:
	"""Create content for each section."""
	section_panels.clear()
	section_panels.append(_create_tool_section())
	section_panels.append(_create_actions_section())
	section_panels.append(_create_navigation_section())
	section_panels.append(_create_overlays_section())
	section_panels.append(_create_quantum_section())
	section_panels.append(_create_advanced_section())


func _rebuild_sections() -> void:
	if not sections_container:
		return

	for child in sections_container.get_children():
		sections_container.remove_child(child)

	_create_section_panels()
	_update_section_display()


func _create_tool_section() -> Control:
	"""Create tool selection help section."""
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)

	var mode_header = Label.new()
	mode_header.text = "1-4 select the active tool group. F cycles the current group."
	mode_header.add_theme_font_size_override("font_size", 14)
	mode_header.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	content.add_child(mode_header)

	for entry in _build_tool_help_entries():
		content.add_child(_create_help_row(entry[0], entry[1], entry[2]))

	var alias_note = Label.new()
	alias_note.text = "\nTab currently mirrors mode cycling for the selected tool. It is an alias, not a separate global mode layer."
	alias_note.add_theme_font_size_override("font_size", 12)
	alias_note.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
	alias_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(alias_note)

	return content


func _create_actions_section() -> Control:
	"""Create QERF actions help section."""
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)

	var desc = Label.new()
	desc.text = "Q, E, R, F are projected from the active tool or menu contract. The rows below are pulled from the live tool config."
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(desc)

	for tool_num in range(1, 5):
		var group_def = ToolConfig.get_group(tool_num)
		var group_header = Label.new()
		group_header.text = "\nTool %d (%s):" % [tool_num, str(group_def.get("name", "Tool"))]
		group_header.add_theme_font_size_override("font_size", 13)
		group_header.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
		content.add_child(group_header)

		for action_key in InputBindingRegistry.ACTION_KEYS:
			var action_info = ToolConfig.get_action(tool_num, action_key)
			if action_info.is_empty():
				continue

			var label = str(action_info.get("label", "-"))
			var description = str(action_info.get("hint", ""))
			if action_key == "F":
				var mode_name = ToolConfig.get_group_mode_name(tool_num)
				description = "Current mode: %s. %s" % [mode_name, description]
			content.add_child(_create_help_row(action_key, label, description))

	var global_header = Label.new()
	global_header.text = "\nGlobal Bindings:"
	global_header.add_theme_font_size_override("font_size", 13)
	global_header.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	content.add_child(global_header)

	for entry in InputBindingRegistry.get_global_bindings():
		content.add_child(_create_help_row(
			str(entry.get("key", "")),
			str(entry.get("label", "")),
			str(entry.get("description", ""))
		))

	return content


func _create_navigation_section() -> Control:
	"""Create biome and plot navigation help section."""
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)

	var biome_header = Label.new()
	biome_header.text = "Biome Selection (%s):" % "".join(InputBindingRegistry.get_biome_keys())
	biome_header.add_theme_font_size_override("font_size", 14)
	biome_header.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	content.add_child(biome_header)

	for entry in InputBindingRegistry.get_biome_entries():
		content.add_child(_create_help_row(
			str(entry.get("key", "")),
			str(entry.get("label", "")),
			str(entry.get("description", ""))
		))

	var plot_header = Label.new()
	plot_header.text = "\nPlot Selection (%s):" % "".join(InputBindingRegistry.get_plot_keys())
	plot_header.add_theme_font_size_override("font_size", 14)
	plot_header.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	content.add_child(plot_header)

	for entry in InputBindingRegistry.get_plot_entries():
		content.add_child(_create_help_row(
			str(entry.get("key", "")),
			str(entry.get("label", "")),
			str(entry.get("description", ""))
		))

	var subspace_header = Label.new()
	subspace_header.text = "\nSubspace Navigation (%s):" % " ".join(InputBindingRegistry.get_subspace_keys())
	subspace_header.add_theme_font_size_override("font_size", 14)
	subspace_header.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	content.add_child(subspace_header)

	for entry in InputBindingRegistry.get_subspace_entries():
		content.add_child(_create_help_row(
			str(entry.get("key", "")),
			str(entry.get("label", "")),
			str(entry.get("description", ""))
		))

	var quest_header = Label.new()
	quest_header.text = "\nQuest Oracle Direct Slots (%s):" % "".join(InputBindingRegistry.get_quest_slot_keys())
	quest_header.add_theme_font_size_override("font_size", 14)
	quest_header.add_theme_color_override("font_color", Color(0.9, 0.7, 1.0))
	content.add_child(quest_header)

	for entry in InputBindingRegistry.get_quest_slot_entries():
		content.add_child(_create_help_row(
			str(entry.get("key", "")),
			str(entry.get("label", "")),
			str(entry.get("description", ""))
		))

	content.add_child(_create_help_row("Q / Enter / Space", "Confirm", "Shared menu confirm alias used across overlays and browser lists"))
	content.add_child(_create_help_row("E / ESC", "Back", "Shared menu cancel alias used across overlays and browser lists"))
	content.add_child(_create_help_row("R / F", "Page", "Shared menu page aliases where a menu supports previous/next paging"))

	return content


func _create_overlays_section() -> Control:
	"""Create overlays help section."""
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)

	for entry in MenuRegistry.get_top_level_menus():
		var overlay_name = str(entry.get("overlay_name", ""))
		var description = str(entry.get("description", ""))
		var action_summary = _describe_overlay_actions(overlay_name)
		if action_summary != "":
			description = "%s | %s" % [description, action_summary]
		content.add_child(_create_help_row(
			str(entry.get("key_label", "")),
			str(entry.get("display_name", "")),
			description
		))

		for shortcut in InputBindingRegistry.get_overlay_shortcuts(overlay_name):
			content.add_child(_create_help_row(
				str(shortcut.get("key", "")),
				str(shortcut.get("label", "")),
				str(shortcut.get("description", ""))
			))

	content.add_child(_create_help_row("Shift+C", "Faction Browser", "Quest-board drill-down for all accessible factions"))
	content.add_child(_create_help_row("ESC", "Back / System", "Close current menu, or open system menu"))

	var pause_label = Label.new()
	pause_label.text = "\nIn system menus: use WASD or arrows to navigate, and Q/E/R/F for actions."
	pause_label.add_theme_font_size_override("font_size", 12)
	pause_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	pause_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(pause_label)

	for entry in MenuRegistry.get_debug_menus():
		var debug_note = Label.new()
		debug_note.text = "\nDebug overlay: %s (%s)" % [
			str(entry.get("display_name", "")),
			str(entry.get("description", ""))
		]
		debug_note.add_theme_font_size_override("font_size", 12)
		debug_note.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
		debug_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(debug_note)

	return content


func _describe_overlay_actions(overlay_name: String) -> String:
	if not overlay_source or not overlay_source.has_method("get_overlay"):
		return ""

	var overlay = overlay_source.get_overlay(overlay_name)
	if not overlay:
		return ""

	var labels: Dictionary = {}
	if overlay.has_method("get_action_info"):
		for key in InputBindingRegistry.ACTION_KEYS:
			var action_info = overlay.get_action_info(key)
			var label = str(action_info.get("label", ""))
			if label != "" and label != "-":
				labels[key] = label
	elif overlay.has_method("get_action_labels"):
		labels = overlay.get_action_labels()

	var parts: Array[String] = []
	for key in InputBindingRegistry.ACTION_KEYS:
		var label = str(labels.get(key, ""))
		if label == "":
			continue
		parts.append("%s=%s" % [key, label])

	return ", ".join(parts)


func _create_quantum_section() -> Control:
	"""Create quantum UI help section."""
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)

	var left_label = Label.new()
	left_label.text = "Left Side Panel (Collapsible):"
	left_label.add_theme_font_size_override("font_size", 14)
	left_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	content.add_child(left_label)

	var left_items = Label.new()
	left_items.text = "  - Energy Meter\n  - Uncertainty Meter\n  - Semantic Context\n  - Attractor Personality"
	left_items.add_theme_font_size_override("font_size", 13)
	left_items.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	content.add_child(left_items)

	var right_label = Label.new()
	right_label.text = "\nTop Right - Quantum Mode Indicator:"
	right_label.add_theme_font_size_override("font_size", 14)
	right_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	content.add_child(right_label)

	var right_items = Label.new()
	right_items.text = "  Shows: HARDWARE/INSPECTOR mode\n  Configure: open System Menu, then navigate to Quantum Settings"
	right_items.add_theme_font_size_override("font_size", 13)
	right_items.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	content.add_child(right_items)

	return content


func _create_advanced_section() -> Control:
	"""Create advanced tool actions help section."""
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)

	var play_header = Label.new()
	play_header.text = "F-Cycling Details:"
	play_header.add_theme_font_size_override("font_size", 14)
	play_header.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	content.add_child(play_header)

	for group_num in range(1, 5):
		var group_def = ToolConfig.get_group(group_num)
		if not bool(group_def.get("has_f_cycling", false)):
			continue

		var section_label = Label.new()
		section_label.text = "\nTool %d (%s) - F-cycles:" % [group_num, str(group_def.get("name", "Tool"))]
		section_label.add_theme_font_size_override("font_size", 13)
		section_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
		content.add_child(section_label)

		var modes: Array = group_def.get("modes", [])
		for mode_name in modes:
			var mode_actions = group_def.get("actions", {}).get(mode_name, {})
			var action_labels: Array[String] = []
			for key in ["Q", "E", "R"]:
				var action_info = mode_actions.get(key, {})
				var label = str(action_info.get("label", ""))
				if label != "" and label != "-":
					action_labels.append(label)
			content.add_child(_create_help_row(
				"F",
				str(mode_name).capitalize(),
				", ".join(action_labels)
			))

	return content


func _build_tool_help_entries() -> Array:
	var entries: Array = []
	for tool_num in range(1, 5):
		var group_def = ToolConfig.get_group(tool_num)
		var description = _describe_tool_group(tool_num, group_def)
		entries.append([
			str(tool_num),
			str(group_def.get("name", "Tool")),
			description
		])
	return entries


func _describe_tool_group(tool_num: int, group_def: Dictionary) -> String:
	var mode_name = ToolConfig.get_group_mode_name(tool_num)
	var mode_actions = group_def.get("actions", {}).get(mode_name, {})
	var labels: Array[String] = []
	for key in ["Q", "E", "R"]:
		var action_info = mode_actions.get(key, {})
		var label = str(action_info.get("label", ""))
		if label != "" and label != "-":
			labels.append(label)

	var summary = ", ".join(labels)
	if bool(group_def.get("has_f_cycling", false)):
		var modes: Array = group_def.get("modes", [])
		if not modes.is_empty():
			return "%s; F cycles %s" % [summary, "/".join(modes)]
	return summary


func _create_help_row(key: String, action: String, description: String) -> Control:
	"""Create a help row: [KEY] Action - Description."""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var key_label = Label.new()
	key_label.text = "[%s]" % key
	key_label.custom_minimum_size = Vector2(70, 0)
	key_label.add_theme_font_size_override("font_size", 13)
	key_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	hbox.add_child(key_label)

	var action_label = Label.new()
	action_label.text = action
	action_label.custom_minimum_size = Vector2(120, 0)
	action_label.add_theme_font_size_override("font_size", 13)
	action_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	hbox.add_child(action_label)

	var desc_label = Label.new()
	desc_label.text = description
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(desc_label)

	return hbox


func _update_section_display() -> void:
	"""Update which section is visible."""
	for i in range(section_panels.size()):
		var panel = section_panels[i]
		if panel.get_parent() != sections_container:
			sections_container.add_child(panel)
		panel.visible = (i == current_section)

	for i in range(section_tabs.get_child_count()):
		var tab = section_tabs.get_child(i)
		if tab is Button:
			tab.button_pressed = (i == current_section)


func _select_section(index: int) -> void:
	"""Select a section by index."""
	if index >= 0 and index < SECTION_NAMES.size():
		current_section = index
		_update_section_display()
		action_performed.emit("section_changed", {"section": SECTION_NAMES[index]})


# ============================================================================
# ACTION HANDLERS
# ============================================================================

func _on_action_q() -> void:
	"""Q = Previous section."""
	current_section = posmod(current_section - 1, SECTION_NAMES.size())
	_update_section_display()
	action_performed.emit("prev_section", {"section": SECTION_NAMES[current_section]})


func _on_action_e() -> void:
	"""E = Next section."""
	current_section = (current_section + 1) % SECTION_NAMES.size()
	_update_section_display()
	action_performed.emit("next_section", {"section": SECTION_NAMES[current_section]})


func _on_action_r() -> void:
	"""R = Search/filter (future feature)."""
	action_performed.emit("search", {})


func _on_action_f() -> void:
	"""F = Toggle compact/full mode."""
	compact_mode = not compact_mode
	_update_section_display()
	action_performed.emit("toggle_compact", {"compact": compact_mode})


func get_snapshot() -> Dictionary:
	"""Return all currently-displayed state as structured data."""
	return {
		"current_section": current_section,
		"section_name": SECTION_NAMES[current_section],
		"sections": SECTION_NAMES,
		"compact_mode": compact_mode
	}
