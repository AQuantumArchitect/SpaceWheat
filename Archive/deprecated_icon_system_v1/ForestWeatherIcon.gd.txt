class_name ForestWeatherIcon extends IconHamiltonian

## Forest Weather Icon - Couples to weather/season qubits
## Affects growth rates via water/sun availability
## Drives weather transitions and seasonal cycles

var weather_type: String = "wind"  # "wind", "water", "sun", "rain"

func _ready():
	super._ready()
	icon_name = "Forest Weather"
	icon_emoji = _get_weather_emoji()

	# Internal qubit couples to forest biome's weather qubits
	internal_qubit = DualEmojiQubit.new(icon_emoji, "⛔", PI / 4.0)
	internal_qubit.radius = 1.0

	# Hamiltonian: σ_x transverse field
	# Creates superposition - weather is inherently uncertain
	hamiltonian_terms = {
		"sigma_x": 0.2,  # Strong transverse field
		"sigma_y": 0.0,
		"sigma_z": 0.05,  # Weak longitudinal
	}

	# No stable point - weather cycles naturally
	stable_theta = 0.0
	spring_constant = 0.0

	# Moderate influence on growth
	icon_influence = 0.5

func _get_weather_emoji() -> String:
	"""Convert weather_type to emoji representation"""
	match weather_type:
		"wind": return "🌬️"
		"water": return "💧"
		"sun": return "☀️"
		"rain": return "🌧️"
		_: return "🌍"
