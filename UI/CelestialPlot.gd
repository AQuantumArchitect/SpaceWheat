## CelestialPlot - Visual representation of sun/moon and its effects on wheat
## Displays in the play area and creates force-directed bonds to affected wheat

extends Control
class_name CelestialPlot

## References
var biome: Node = null
var wheat_plots: Array = []  # Array of plot positions

## Visual elements
var celestial_body: Control = null
var bond_lines: Array = []

## Configuration
const CELESTIAL_SIZE = 60.0
const BOND_LINE_WIDTH = 2.0
const BOND_STRENGTH_MULTIPLIER = 100.0

func _ready():
	print("🌞 CelestialPlot initializing...")
	_create_visual_elements()
	set_process(true)


func set_biome(new_biome: Node):
	"""Set the biome reference"""
	biome = new_biome
	print("🌞 CelestialPlot connected to biome")


func set_wheat_plots(plots: Array):
	"""Set the wheat plot positions for bonding"""
	wheat_plots = plots
	print("🌞 CelestialPlot tracking %d wheat plots" % wheat_plots.size())


func _create_visual_elements():
	"""Create the celestial body display"""

	# Create celestial body (sun or moon)
	celestial_body = Control.new()
	celestial_body.custom_minimum_size = Vector2(CELESTIAL_SIZE, CELESTIAL_SIZE)
	add_child(celestial_body)

	# Draw will be handled in _process()
	print("🌞 Celestial body created")


func _process(delta):
	"""Update celestial position and bonds based on biome state"""
	if not biome or not is_node_ready():
		return

	# Update celestial body appearance and position
	_update_celestial_body()

	# Update bonds to wheat plots
	_update_bonds()

	# Redraw
	queue_redraw()


func _update_celestial_body():
	"""Update celestial body (sun or moon) based on biome phase"""
	if not biome:
		return

	var phase = biome.sun_moon_phase if biome.has_meta("sun_moon_phase") else 0.0
	var strength = biome.get_sun_moon_strength() if biome.has_method("get_sun_moon_strength") else 0.5

	# Position in center of play area
	var center = size / 2.0

	# Orbital motion - sun/moon moves in a circle based on phase
	var orbit_radius = size.length() * 0.3  # Orbit 30% of diagonal
	var orbital_x = center.x + cos(phase) * orbit_radius
	var orbital_y = center.y + sin(phase) * orbit_radius

	celestial_body.position = Vector2(orbital_x, orbital_y) - Vector2(CELESTIAL_SIZE / 2.0, CELESTIAL_SIZE / 2.0)

	# Store for bond drawing
	celestial_body.position = celestial_body.position


func _update_bonds():
	"""Update visual bonds from celestial body to wheat plots"""
	if not biome or wheat_plots.is_empty():
		return

	# Get celestial body center
	var celestial_center = celestial_body.position + Vector2(CELESTIAL_SIZE / 2.0, CELESTIAL_SIZE / 2.0)

	# Get sun strength for bond intensity
	var sun_strength = biome.get_sun_moon_strength() if biome.has_method("get_sun_moon_strength") else 0.5
	var is_sun = biome.is_currently_sun() if biome.has_method("is_currently_sun") else false

	# Update bonds only if sun is active
	if is_sun and sun_strength > 0.1:
		# Draw bonds to affected wheat (for visualization in _draw)
		pass


func _draw():
	"""Draw celestial body and bonds"""
	if not biome or not is_node_ready():
		return

	# Get current state
	var phase = biome.sun_moon_phase if biome.has_meta("sun_moon_phase") else 0.0
	var strength = biome.get_sun_moon_strength() if biome.has_method("get_sun_moon_strength") else 0.5
	var is_sun = biome.is_currently_sun() if biome.has_method("is_currently_sun") else false

	var celestial_center = celestial_body.position + Vector2(CELESTIAL_SIZE / 2.0, CELESTIAL_SIZE / 2.0)

	# Draw celestial body (sun or moon)
	if is_sun:
		# Draw sun (yellow circle with rays)
		draw_circle(celestial_center, CELESTIAL_SIZE / 2.0, Color.YELLOW)
		# Draw rays
		for i in range(8):
			var angle = (TAU / 8.0) * i
			var ray_start = celestial_center + Vector2(cos(angle), sin(angle)) * (CELESTIAL_SIZE / 2.0 + 5)
			var ray_end = celestial_center + Vector2(cos(angle), sin(angle)) * (CELESTIAL_SIZE / 2.0 + 20)
			draw_line(ray_start, ray_end, Color.YELLOW, 2.0)
	else:
		# Draw moon (pale blue circle with glow)
		draw_circle(celestial_center, CELESTIAL_SIZE / 2.0, Color(0.7, 0.8, 1.0))
		draw_circle(celestial_center, CELESTIAL_SIZE / 2.0 - 2, Color(0.9, 0.95, 1.0))

	# Draw bonds to wheat plots (sun only)
	if is_sun and strength > 0.1 and not wheat_plots.is_empty():
		_draw_bonds(celestial_center, strength)

	# Draw strength indicator
	_draw_strength_indicator(celestial_center, strength)


func _draw_bonds(celestial_center: Vector2, strength: float):
	"""Draw bonds from celestial body to wheat plots"""
	for wheat_pos in wheat_plots:
		# Convert wheat position to screen coordinates if needed
		var bond_target = wheat_pos if wheat_pos is Vector2 else Vector2(wheat_pos)

		# Bond color: stronger sun = brighter yellow bond
		var bond_color = Color.YELLOW.lerp(Color.ORANGE, 0.5 - strength * 0.5)
		bond_color.a = strength * 0.7

		# Bond width scales with strength
		var bond_width = BOND_LINE_WIDTH * strength

		# Draw bond line
		draw_line(celestial_center, bond_target, bond_color, bond_width)

		# Draw small connection nodes at wheat plots
		var node_size = 3.0 + (strength * 3.0)
		draw_circle(bond_target, node_size, Color.YELLOW.lerp(Color.ORANGE, 0.5))


func _draw_strength_indicator(celestial_center: Vector2, strength: float):
	"""Draw sun strength indicator"""
	var indicator_text = "☀️ Sun Strength: %.1f%%" % (strength * 100.0)
	if strength < 0.2:
		indicator_text = "🌙 Moon Phase"

	var font = get_theme_font("font") if has_theme_font("font", "Label") else null
	var font_size = 14

	draw_string(font, celestial_center + Vector2(20, 30), indicator_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func update_wheat_positions(positions: Array):
	"""Update wheat plot positions for bonds"""
	wheat_plots = positions
	queue_redraw()
