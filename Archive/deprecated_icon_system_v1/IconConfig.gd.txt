class_name IconConfig
extends Resource

## Configuration for Icon Hamiltonian systems
## Enables config-driven icon creation instead of duplicating _initialize() code

# Identity
@export var icon_name: String = ""
@export var icon_emoji: String = ""
@export var icon_description: String = ""

# Qubit configuration
@export var north_emoji: String = ""
@export var south_emoji: String = ""
@export var initial_theta: float = 0.0  # Initial angle on Bloch sphere
@export var qubit_radius: float = 1.0   # Always 1.0 for perfect coherence

# Hamiltonian terms (Pauli operators)
@export var sigma_x: float = 0.0   # Transverse field
@export var sigma_y: float = 0.0   # Rotation field
@export var sigma_z: float = 0.0   # Longitudinal field

# Icon influence strength on crops (0.0 to 1.0)
@export var icon_influence: float = 0.5

# Stable point attraction (Hooke's law on Bloch sphere)
@export var stable_theta: float = 0.0      # Target angle
@export var spring_constant: float = 0.5   # Rotational spring constant

# Environmental effects
@export var sun_damage_strength: float = 0.0  # Damage rate at peak sun

# Optional: Calculate icon_influence from qubit state instead of hardcoding
@export var auto_calculate_influence: bool = false  # If true, use cos²(theta/2)


func get_hamiltonian_terms() -> Dictionary:
	"""Return Hamiltonian terms as dictionary"""
	return {
		"sigma_x": sigma_x,
		"sigma_y": sigma_y,
		"sigma_z": sigma_z,
	}


func get_description() -> String:
	"""Return human-readable description"""
	if icon_description:
		return icon_description
	return "Icon: %s (%s↔%s)" % [icon_name, north_emoji, south_emoji]
