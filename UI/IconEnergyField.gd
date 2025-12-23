extends CanvasLayer
## Icon Energy Field Visualization
## Renders background particle systems that encode Icon influence
## Zero-waste design: every particle property = data

# Icon reference
var icon = null  # BioticIcon, ChaosIcon, or ImperiumIcon

# Visual properties
var icon_color: Color = Color.WHITE
var icon_name: String = ""

# Particle system
var particles: CPUParticles2D

# Constants (reduced for performance and less visual noise)
const BASE_PARTICLE_COUNT = 10  # Reduced from 50
const MAX_PARTICLE_COUNT = 60   # Reduced from 200
const BASE_PARTICLE_SIZE = 3.0  # Reduced from 4.0
const MAX_PARTICLE_SIZE = 8.0   # Reduced from 12.0
const BASE_LIFETIME = 2.0
const BASE_SPEED = 20.0         # Reduced from 30.0
const MAX_SPEED = 80.0          # Reduced from 120.0


func _ready():
	# Set layer to render behind everything
	layer = -10

	# Create particle system
	particles = CPUParticles2D.new()
	add_child(particles)

	# Configure particle appearance
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 350.0  # Cover farm area

	# Particle rendering
	particles.draw_order = CPUParticles2D.DRAW_ORDER_LIFETIME

	# Initial configuration (will be updated in _process)
	_configure_particles()

	if icon:
		print("⚡ IconEnergyField ready: %s" % icon_name)


func _configure_particles():
	"""Configure particle properties based on Icon state"""
	if not icon:
		particles.emitting = false
		return

	# Get Icon properties
	var activation = _get_icon_activation()
	var temperature = _get_icon_temperature()

	# Zero-waste encoding: every property = data

	# 1. Particle count: encodes activation strength
	var particle_count = int(BASE_PARTICLE_COUNT + activation * (MAX_PARTICLE_COUNT - BASE_PARTICLE_COUNT))
	particles.amount = particle_count

	# 2. Particle size: encodes activation intensity
	var particle_size = BASE_PARTICLE_SIZE + activation * (MAX_PARTICLE_SIZE - BASE_PARTICLE_SIZE)
	particles.scale_amount_min = particle_size * 0.5
	particles.scale_amount_max = particle_size * 1.5

	# 3. Particle speed: encodes temperature
	var temperature_factor = clamp(temperature / 100.0, 0.1, 3.0)
	var particle_speed = BASE_SPEED * temperature_factor
	particles.initial_velocity_min = particle_speed * 0.5
	particles.initial_velocity_max = particle_speed * 1.5

	# 4. Particle lifetime: inversely proportional to temperature (hot = short-lived)
	var lifetime = BASE_LIFETIME / temperature_factor
	particles.lifetime = clamp(lifetime, 0.5, 4.0)

	# 5. Particle color: Icon-specific
	particles.color = icon_color.lerp(Color.WHITE, 0.3)  # Slightly desaturated

	# 6. Particle direction: random spread
	particles.direction = Vector2(0, -1)  # Upward bias
	particles.spread = 180.0  # Full hemisphere

	# 7. Particle gravity: subtle downward pull
	particles.gravity = Vector2(0, 10.0 * temperature_factor)

	# 8. Particle damping: based on activation
	particles.damping_min = 0.5 + activation * 0.5
	particles.damping_max = 1.0 + activation * 1.0

	# Enable emission only if Icon is significantly active (reduced visual noise)
	particles.emitting = activation > 0.15  # Increased from 0.01 to 0.15


# Update timer to reduce configuration frequency
var update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.1  # Update every 100ms instead of every frame

func _process(delta: float):
	"""Update particle properties periodically based on Icon state"""
	if not icon:
		return

	# Only update every UPDATE_INTERVAL seconds (not every frame)
	update_timer += delta
	if update_timer >= UPDATE_INTERVAL:
		update_timer = 0.0
		_configure_particles()


func _get_icon_activation() -> float:
	"""Get Icon activation strength (0.0 to 1.0)"""
	if not icon:
		return 0.0

	# All Icons have active_strength property
	if "active_strength" in icon:
		return clamp(icon.active_strength, 0.0, 1.0)
	else:
		return 0.0


func _get_icon_temperature() -> float:
	"""Get Icon temperature (Kelvin)"""
	if not icon:
		return 20.0

	# All Icons have get_effective_temperature() method
	if icon.has_method("get_effective_temperature"):
		return icon.get_effective_temperature()
	else:
		return 20.0


func set_icon(icon_ref, color: Color, name: String):
	"""Set the Icon this field visualizes"""
	icon = icon_ref
	icon_color = color
	icon_name = name

	if particles:
		_configure_particles()


func set_center_position(pos: Vector2):
	"""Set the center of the particle emission area"""
	if particles:
		particles.position = pos
