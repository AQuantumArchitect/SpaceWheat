class_name ForestEcosystemIcon extends IconHamiltonian

## Forest Ecosystem Icon - Affects ecological succession rates
## Influences forest growth from seedling to mature stages
## Stable point at mature forest (🌲)

func _ready():
	super._ready()
	icon_name = "Forest Ecosystem"
	icon_emoji = "🌲"

	# Internal qubit represents icon's quantum properties
	internal_qubit = DualEmojiQubit.new("🌱", "🌲", PI / 2.0)
	internal_qubit.radius = 1.0

	# Hamiltonian: σ_z coupling (phase/longitudinal alignment)
	# Stronger than wheat (forest is persistent, takes time)
	hamiltonian_terms = {
		"sigma_x": 0.0,
		"sigma_y": 0.0,
		"sigma_z": 0.15,
	}

	# Stable point: Mature forest state (θ = π means 100% mature emoji)
	stable_theta = PI

	# Slower than crops (forests take time to grow)
	spring_constant = 0.3

	# Icon influence strength
	icon_influence = pow(cos(internal_qubit.theta / 2.0), 2)
