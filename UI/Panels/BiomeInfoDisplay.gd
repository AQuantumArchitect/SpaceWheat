class_name BiomeInfoDisplay
extends PanelContainer

## BiomeInfoDisplay - Shows temperature and sun/moon cycle info
## Positioned in the farm play area (not the top bar)
## Displays: Sun/Moon phase, time remaining, temperature

# Layout manager reference (for dynamic scaling)
var layout_manager: Node  # Will be UILayoutManager instance

# UI elements
var sun_moon_label: Label
var temperature_label: Label
var info_container: VBoxContainer

# Visual styling
const PANEL_BG_COLOR = Color(0.1, 0.15, 0.1, 0.85)
const TEXT_COLOR = Color(0.9, 1.0, 0.9, 1.0)
const ACCENT_COLOR = Color(0.5, 1.0, 0.5, 1.0)


func set_layout_manager(manager: Node):
	"""Set the layout manager reference for dynamic scaling"""
	layout_manager = manager


func _ready():
	# Set panel style
	_setup_style()

	# Get font sizes from layout manager (or use defaults)
	var title_font_size = layout_manager.get_scaled_font_size(16) if layout_manager else 16
	var stat_font_size = layout_manager.get_scaled_font_size(14) if layout_manager else 14
	var scale_factor = layout_manager.scale_factor if layout_manager else 1.0

	# Create UI layout
	info_container = VBoxContainer.new()
	info_container.add_theme_constant_override("separation", int(4 * scale_factor))
	add_child(info_container)

	# Title
	var title_label = Label.new()
	title_label.text = "🌍 BIOME"
	title_label.add_theme_color_override("font_color", ACCENT_COLOR)
	title_label.add_theme_font_size_override("font_size", title_font_size)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_container.add_child(title_label)

	# Add separator
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", int(2 * scale_factor))
	info_container.add_child(separator)

	# Sun/Moon stat
	sun_moon_label = Label.new()
	sun_moon_label.text = "☀️ Sun (10.0s)"
	sun_moon_label.add_theme_color_override("font_color", TEXT_COLOR)
	sun_moon_label.add_theme_font_size_override("font_size", stat_font_size)
	sun_moon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_container.add_child(sun_moon_label)

	# Temperature stat
	temperature_label = Label.new()
	temperature_label.text = "🌡️ 300K"
	temperature_label.add_theme_color_override("font_color", TEXT_COLOR)
	temperature_label.add_theme_font_size_override("font_size", stat_font_size)
	temperature_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_container.add_child(temperature_label)

	# Set initial size (scaled)
	var base_size = Vector2(200, 120)
	custom_minimum_size = base_size * scale_factor


func _setup_style():
	"""Configure panel appearance"""
	# Create StyleBoxFlat for background
	var style = StyleBoxFlat.new()
	style.bg_color = PANEL_BG_COLOR
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = ACCENT_COLOR
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10
	style.content_margin_top = 10
	style.content_margin_right = 10
	style.content_margin_bottom = 10

	add_theme_stylebox_override("panel", style)


func update_sun_moon(is_sun: bool, time_remaining: float):
	"""Update sun/moon cycle display"""
	if is_sun:
		sun_moon_label.text = "☀️ Sun"
		sun_moon_label.modulate = Color(1.0, 0.9, 0.3)  # Golden
	else:
		sun_moon_label.text = "🌙 Moon"
		sun_moon_label.modulate = Color(0.7, 0.7, 1.0)  # Bluish

	# Add timer
	sun_moon_label.text += " (%.1fs)" % time_remaining


func update_biome_info(temperature: float, energy_strength: float = -1.0):
	"""Update biome display (temperature and energy level)

	Args:
		temperature: Current biome temperature (Kelvin)
		energy_strength: Energy level 0.0-1.0 (optional, for future use)
	"""
	temperature_label.text = "🌡️ %.0fK" % temperature

	# Color code based on temperature
	if temperature < 250.0:
		temperature_label.modulate = Color(0.5, 0.8, 1.0)  # Cool blue
	elif temperature < 300.0:
		temperature_label.modulate = Color(0.8, 1.0, 0.8)  # Cool green
	elif temperature < 350.0:
		temperature_label.modulate = Color(1.0, 1.0, 0.7)  # Warm yellow
	else:
		temperature_label.modulate = Color(1.0, 0.8, 0.5)  # Hot orange
