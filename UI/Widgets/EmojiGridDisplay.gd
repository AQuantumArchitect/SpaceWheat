class_name EmojiGridDisplay
extends VBoxContainer

## Emoji Grid Display
## Shows emojis with visual energy indicators (dots + percentage)
## Used in BiomeOvalPanel to display biome contents

signal emoji_tapped(emoji: String)

# Layout settings
var emoji_size: int = 48
var dot_size: int = 8
var spacing: int = 16
var columns: int = 3  # Default columns, auto-adjusts

# Visual settings
var dot_color: Color = Color(1.0, 0.8, 0.2)  # Yellow/gold dots
var text_color: Color = Color(0.9, 0.9, 0.9)
var emoji_bg_color: Color = Color(0.2, 0.2, 0.2, 0.5)

# Data
var emoji_states: Array[Dictionary] = []  # From BiomeInspectionController

func _ready():
	custom_minimum_size = Vector2(200, 100)


## Set emoji data and rebuild grid
func set_emoji_data(data: Array[Dictionary]) -> void:
	"""Update grid with new emoji state data

	data format:
		[{
			"emoji": "🌾",
			"percentage": 42.0,
			"energy_dots": 4,
			"trend": "stable"
		}, ...]
	"""
	emoji_states = data
	_rebuild_grid()


## Rebuild entire grid from current data
func _rebuild_grid() -> void:
	"""Clear and recreate grid based on emoji_states"""

	# Clear existing children
	for child in get_children():
		child.queue_free()

	if emoji_states.is_empty():
		_add_empty_state_label()
		return

	# Calculate optimal columns based on emoji count
	columns = _calculate_optimal_columns(emoji_states.size())

	# Create rows
	var row_container: HBoxContainer = null
	var col_index = 0

	for emoji_data in emoji_states:
		# Create new row if needed
		if col_index == 0:
			row_container = HBoxContainer.new()
			row_container.add_theme_constant_override("separation", spacing)
			add_child(row_container)

		# Create emoji cell
		var cell = _create_emoji_cell(emoji_data)
		row_container.add_child(cell)

		col_index += 1
		if col_index >= columns:
			col_index = 0


## Create individual emoji cell
func _create_emoji_cell(emoji_data: Dictionary) -> Control:
	"""Create a cell displaying emoji + dots + percentage

	Layout:
		┌─────────┐
		│   🌾    │  ← Emoji (large)
		│  ●●●●   │  ← Energy dots
		│   42%   │  ← Percentage
		└─────────┘
	"""
	var cell = VBoxContainer.new()
	cell.custom_minimum_size = Vector2(emoji_size + 20, emoji_size + 40)
	cell.add_theme_constant_override("separation", 4)

	# Background panel for tap target
	var panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = emoji_bg_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)

	# Container for all elements
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)

	# Emoji label
	var emoji_label = Label.new()
	emoji_label.text = emoji_data.get("emoji", "❓")
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.add_theme_font_size_override("font_size", emoji_size)
	content.add_child(emoji_label)

	# Energy dots
	var dots_container = HBoxContainer.new()
	dots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	dots_container.add_theme_constant_override("separation", 4)

	var dot_count = emoji_data.get("energy_dots", 1)
	for i in range(dot_count):
		var dot = _create_energy_dot()
		dots_container.add_child(dot)

	content.add_child(dots_container)

	# Percentage label
	var percent_label = Label.new()
	var percentage = emoji_data.get("percentage", 0.0)
	percent_label.text = "%d%%" % int(percentage)
	percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	percent_label.add_theme_font_size_override("font_size", 14)
	percent_label.add_theme_color_override("font_color", text_color)
	content.add_child(percent_label)

	# Add content to cell
	cell.add_child(content)

	# Make cell tappable
	var button = Button.new()
	button.flat = true
	button.custom_minimum_size = cell.custom_minimum_size
	button.mouse_filter = Control.MOUSE_FILTER_PASS

	var emoji = emoji_data.get("emoji", "")
	button.pressed.connect(func(): _on_emoji_tapped(emoji))

	cell.add_child(button)
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	return cell


## Create a single energy dot
func _create_energy_dot() -> Control:
	"""Create colored circle representing energy unit"""
	var dot = ColorRect.new()
	dot.custom_minimum_size = Vector2(dot_size, dot_size)
	dot.color = dot_color

	# Make it circular using a shader or custom draw
	# For now, using ColorRect (will appear as square, can upgrade later)

	return dot


## Calculate optimal grid columns
func _calculate_optimal_columns(emoji_count: int) -> int:
	"""Determine best column count for given emoji count

	Small biomes (3-6): 3 columns
	Medium biomes (7-12): 4 columns
	Large biomes (13+): 5 columns
	"""
	if emoji_count <= 6:
		return 3
	elif emoji_count <= 12:
		return 4
	else:
		return 5


## Add empty state when no data
func _add_empty_state_label() -> void:
	"""Show message when biome has no emojis"""
	var label = Label.new()
	label.text = "No emojis in biome"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	add_child(label)


## Handle emoji tap
func _on_emoji_tapped(emoji: String) -> void:
	"""Emit signal when emoji is tapped"""
	print("🔍 Emoji tapped: %s" % emoji)
	emoji_tapped.emit(emoji)


## Update only percentages (lightweight refresh)
func update_percentages(data: Array[Dictionary]) -> void:
	"""Update just the percentage labels without rebuilding grid

	More efficient than full rebuild for periodic updates
	"""
	# TODO: Implement selective update
	# For now, just rebuild (can optimize later)
	set_emoji_data(data)
