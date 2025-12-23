## SunMoonPlot - Special locked plot displaying sun/moon at its orbital position
## Positioned parametrically where the sun/moon currently is in the play area
## Cannot be planted, harvested, or modified - purely informational

extends Control
class_name SunMoonPlot

## References
var biome: Node = null
var wheat_plot: WheatPlot = null  # Reference to internal quantum state (read-only)

## Visual elements
var background: ColorRect
var emoji_label: Label
var glow_effect: Control
var info_label: Label

## Configuration
const CELESTIAL_SIZE = 60.0
const GLOW_SIZE_MULTIPLIER = 1.5

## Colors
const COLOR_SUN = Color(1.0, 0.85, 0.2)      # Golden yellow
const COLOR_MOON = Color(0.7, 0.8, 1.0)      # Pale blue
const COLOR_EMPTY = Color(0.15, 0.15, 0.15)
const COLOR_BACKGROUND = Color(0.1, 0.12, 0.15)

func _ready():
	print("🌞🌙 SunMoonPlot initializing...")
	_create_ui_elements()
	custom_minimum_size = Vector2(CELESTIAL_SIZE, CELESTIAL_SIZE)
	size = Vector2(CELESTIAL_SIZE, CELESTIAL_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Non-interactive

	set_process(true)
	print("🌞🌙 SunMoonPlot ready")


func set_biome(new_biome: Node):
	"""Set the biome reference for sun/moon phase and data"""
	biome = new_biome
	print("🌞🌙 SunMoonPlot connected to biome")


func _create_ui_elements():
	"""Create visual elements"""
	# Background
	background = ColorRect.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.color = COLOR_BACKGROUND
	add_child(background)

	# Glow effect (for visual enhancement)
	glow_effect = Control.new()
	glow_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow_effect.z_index = -1
	add_child(glow_effect)

	# Emoji label (sun or moon)
	emoji_label = Label.new()
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_label.add_theme_font_size_override("font_size", 48)
	add_child(emoji_label)

	# Info label (shows phase time or energy)
	info_label = Label.new()
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_label.add_theme_font_size_override("font_size", 10)
	info_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.7))
	add_child(info_label)


func _process(delta):
	"""Update sun/moon position and visual state based on biome"""
	if not biome or not is_node_ready():
		return

	_update_visuals()
	queue_redraw()


func _update_visuals():
	"""Update appearance based on biome state"""
	if not biome:
		return

	var phase = biome.sun_moon_phase if biome.has_meta("sun_moon_phase") else 0.0
	var strength = biome.get_energy_strength() if biome.has_method("get_energy_strength") else 0.5
	var is_sun = biome.is_currently_sun() if biome.has_method("is_currently_sun") else false
	var temp = 300.0
	if biome:
		if biome.has_meta("base_temperature"):
			temp = biome.base_temperature
		elif biome.has_method("get_base_temperature"):
			temp = biome.get_base_temperature()

	# Update emoji and colors
	if is_sun:
		emoji_label.text = "☀️"
		background.color = COLOR_SUN.darkened(0.3)
	else:
		emoji_label.text = "🌙"
		background.color = COLOR_MOON.darkened(0.3)

	# Update info label with time remaining
	var time_remaining = biome.get_sun_moon_time_remaining() if biome.has_method("get_sun_moon_time_remaining") else 0.0
	info_label.text = "%.1fs" % time_remaining

	# Update background color based on temperature (parametric effect)
	_update_background_from_temperature(temp, is_sun)


func _update_background_from_temperature(temp: float, is_sun: bool):
	"""Update background color based on temperature (parametric biome effect)"""
	var base_color = COLOR_SUN if is_sun else COLOR_MOON

	# Temperature affects color saturation and brightness
	# Cold (< 300K): more saturated, brighter
	# Hot (> 350K): less saturated, dimmer
	var temp_factor = clamp((temp - 250.0) / 150.0, 0.0, 1.0)  # 250K-400K range

	# Interpolate: cold (bright) to hot (dark)
	var color = base_color.darkened(temp_factor * 0.4)
	color = color.lerp(Color(0.1, 0.1, 0.15), temp_factor * 0.2)

	background.color = color


func _layout_elements():
	"""Position UI elements"""
	var rect = get_rect()

	# Background fills entire tile
	background.position = Vector2.ZERO
	background.size = rect.size

	# Emoji centered
	emoji_label.position = Vector2.ZERO
	emoji_label.size = rect.size

	# Info label at top
	info_label.position = Vector2(0, 4)
	info_label.size = Vector2(rect.size.x, 16)


func _draw():
	"""Draw sun/moon with glow effects"""
	var rect = get_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return

	var center = rect.size / 2.0
	var is_sun = biome.is_currently_sun() if biome and biome.has_method("is_currently_sun") else false
	var strength = biome.get_energy_strength() if biome and biome.has_method("get_energy_strength") else 0.5

	# Draw glow aura
	if is_sun:
		# Sun: golden glow with rays
		var glow_color = COLOR_SUN
		glow_color.a = strength * 0.3
		draw_circle(center, CELESTIAL_SIZE / 2.0 * GLOW_SIZE_MULTIPLIER, glow_color)

		# Sun rays
		for i in range(8):
			var angle = (TAU / 8.0) * i
			var ray_start = center + Vector2(cos(angle), sin(angle)) * (CELESTIAL_SIZE / 2.0 + 5)
			var ray_end = center + Vector2(cos(angle), sin(angle)) * (CELESTIAL_SIZE / 2.0 + 15)
			var ray_color = COLOR_SUN
			ray_color.a = strength * 0.6
			draw_line(ray_start, ray_end, ray_color, 2.0)
	else:
		# Moon: pale blue glow with halo
		var glow_color = COLOR_MOON
		glow_color.a = strength * 0.2
		draw_circle(center, CELESTIAL_SIZE / 2.0 * GLOW_SIZE_MULTIPLIER, glow_color)

	# Draw edge border (like PCB component)
	_draw_edges(rect)


func _draw_edges(rect: Rect2):
	"""Draw subtle edges"""
	var edge_width = 1
	var edge_light = Color(0.25, 0.25, 0.25)
	var edge_dark = Color(0.08, 0.08, 0.08)

	draw_line(Vector2(0, 0), Vector2(rect.size.x, 0), edge_light, edge_width)
	draw_line(Vector2(0, rect.size.y - 1), Vector2(rect.size.x, rect.size.y - 1), edge_dark, edge_width)
