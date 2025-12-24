class_name VisualEffects
extends Node2D

## VisualEffects - Handles particle effects and animations
## Harvest sparkles, planting animations, quantum collapse effects

# Effect configuration
const HARVEST_PARTICLE_COUNT = 15
const PLANT_PARTICLE_COUNT = 8
const MEASUREMENT_PARTICLE_COUNT = 20

const PARTICLE_LIFETIME = 1.0
const PARTICLE_SPREAD = 40.0
const PARTICLE_SPEED = 100.0

# Color schemes
const COLOR_HARVEST = Color(1.0, 0.9, 0.3)      # Golden
const COLOR_PLANT = Color(0.4, 0.9, 0.4)        # Green
const COLOR_MEASURE = Color(0.7, 0.3, 1.0)      # Purple
const COLOR_ENTANGLE = Color(0.3, 0.7, 1.0)     # Blue


func _ready():
	z_index = 10  # Draw above everything


## Public API - Call these to trigger effects

func play_harvest_effect(position: Vector2):
	"""Golden sparkles bursting outward"""
	_spawn_particles(position, HARVEST_PARTICLE_COUNT, COLOR_HARVEST, "🌾")


func play_plant_effect(position: Vector2):
	"""Green sprout animation"""
	_spawn_particles(position, PLANT_PARTICLE_COUNT, COLOR_PLANT, "🌱")


func play_measurement_effect(position: Vector2):
	"""Purple quantum collapse effect"""
	_spawn_particles(position, MEASUREMENT_PARTICLE_COUNT, COLOR_MEASURE, "👁️")


func play_entanglement_effect(position: Vector2):
	"""Blue sparkle at entanglement point"""
	_spawn_particles(position, 5, COLOR_ENTANGLE, "🔗")


func flash_tile(tile: Control, color: Color, duration: float = 0.3):
	"""Flash a tile with a color overlay"""
	var flash = ColorRect.new()
	flash.color = color
	flash.modulate.a = 0.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.position = Vector2.ZERO
	flash.size = tile.size
	tile.add_child(flash)

	# Fade in and out
	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.6, duration * 0.3)
	tween.tween_property(flash, "modulate:a", 0.0, duration * 0.7)
	tween.tween_callback(flash.queue_free)


## Private helpers

func _spawn_particles(pos: Vector2, count: int, color: Color, emoji: String):
	"""Spawn particle burst effect"""
	for i in range(count):
		var particle = _create_particle(emoji, color)
		add_child(particle)

		# Random velocity
		var angle = randf() * TAU
		var speed = PARTICLE_SPEED * (0.5 + randf() * 0.5)
		var velocity = Vector2(cos(angle), sin(angle)) * speed

		# Initial position with slight spread
		var spread = Vector2(randf() - 0.5, randf() - 0.5) * PARTICLE_SPREAD
		particle.position = pos + spread

		# Animate
		_animate_particle(particle, velocity)


func _create_particle(emoji: String, color: Color) -> Label:
	"""Create a single particle label"""
	var label = Label.new()
	label.text = emoji
	label.add_theme_font_size_override("font_size", 24)
	label.modulate = color
	return label


func _animate_particle(particle: Label, velocity: Vector2):
	"""Animate particle movement and fade"""
	var tween = create_tween()
	tween.set_parallel(true)

	# Move
	var end_pos = particle.position + velocity * PARTICLE_LIFETIME
	tween.tween_property(particle, "position", end_pos, PARTICLE_LIFETIME)

	# Fade out
	tween.tween_property(particle, "modulate:a", 0.0, PARTICLE_LIFETIME)

	# Scale down
	tween.tween_property(particle, "scale", Vector2(0.3, 0.3), PARTICLE_LIFETIME)

	# Cleanup
	tween.tween_callback(particle.queue_free)


## Number counter animations

func animate_number_change(label: Label, old_value: int, new_value: int):
	"""Animate a number changing (for credits/wheat)"""
	# Flash color on change
	var original_color = label.modulate
	var flash_color = Color.WHITE if new_value > old_value else Color(1.0, 0.5, 0.5)

	var tween = create_tween()
	tween.tween_property(label, "modulate", flash_color, 0.1)
	tween.tween_property(label, "modulate", original_color, 0.2)

	# Scale pulse
	var original_scale = label.scale
	tween.set_parallel(true)
	tween.tween_property(label, "scale", original_scale * 1.2, 0.1)
	tween.tween_property(label, "scale", original_scale, 0.2).set_delay(0.1)


## Growth animations

func animate_growth_progress(progress_bar: ProgressBar):
	"""Subtle pulse on growth bar"""
	if not is_instance_valid(progress_bar) or not progress_bar.visible:
		return

	var tween = create_tween()
	var original_modulate = progress_bar.modulate
	tween.tween_property(progress_bar, "modulate", Color(1.2, 1.2, 1.2), 0.2)
	tween.tween_property(progress_bar, "modulate", original_modulate, 0.2)
