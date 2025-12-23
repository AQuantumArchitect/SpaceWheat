class_name IconHamiltonian
extends Node

## Base class for Icon Hamiltonian systems
## Icons are PURE HAMILTONIANS - define unitary evolution only
## Dissipation (damping) is handled by Biome, not Icons

const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

signal activation_changed(icon_name: String, new_strength: float)

# Identity
@export var icon_name: String = ""
@export var icon_emoji: String = ""

# Influence parameters
@export var active_strength: float = 0.0  # 0.0 to 1.0, controls overall influence
@export var spatial_extent: float = 500.0  # How far influence reaches (for future use)

# Temperature modulation (for subclasses like BioticFluxIcon)
@export var base_temperature: float = 20.0  # Baseline temperature effect
@export var temperature_scaling: float = 1.0  # Positive = warming, negative = cooling

# HAMILTONIAN TERMS (Pure unitary evolution - Pauli operators)
var hamiltonian_terms: Dictionary = {
	"sigma_x": 0.0,  # Transverse field strength
	"sigma_y": 0.0,  # Rotation strength
	"sigma_z": 0.0,  # Longitudinal field strength
}

# Icon's internal quantum state (crop icons use this for influence calculation)
var internal_qubit: DualEmojiQubit = null

# Icon influence strength on crops (used in energy transfer, not Hamiltonian)
var icon_influence: float = 1.0

# Stable point attraction (Hooke's law for rotation on Bloch sphere)
var stable_theta: float = 0.0  # Target angle on Bloch sphere
var spring_constant: float = 0.0  # Rotational spring constant (0.0 = no attraction)

# Sun damage parameters (for environmental effects)
var sun_damage_strength: float = 0.0  # Damage rate at peak sun

# Two-qubit coupling terms for entanglement (future use)
var coupling_matrix: Dictionary = {}  # (node_a, node_b) -> coupling_strength

# Sparse coupling to conspiracy nodes (node_id -> coupling_strength)
var node_couplings: Dictionary = {}


func _ready():
	_initialize_couplings()


## Override in subclasses to define node couplings
func _initialize_couplings():
	pass


## Apply Hamiltonian evolution to a DualEmojiQubit (wheat plot)
## Pure unitary evolution on Bloch sphere
func apply_hamiltonian_evolution(qubit: DualEmojiQubit, dt: float) -> void:
	if active_strength <= 0.0 or not qubit:
		return

	# Scale Hamiltonian by icon activation strength
	var effective_H = {
		"sigma_x": hamiltonian_terms.get("sigma_x", 0.0) * active_strength,
		"sigma_y": hamiltonian_terms.get("sigma_y", 0.0) * active_strength,
		"sigma_z": hamiltonian_terms.get("sigma_z", 0.0) * active_strength,
	}

	# Apply unitary rotation (NO dissipation here!)
	qubit.apply_hamiltonian_rotation(effective_H, dt)


## Apply Icon modulation to a conspiracy node (for TomatoConspiracyNetwork)
## NOTE: Dissipation (damping) is NO LONGER applied here - handled by Biome
func modulate_node_evolution(node, dt: float) -> void:
	if active_strength <= 0.0:
		return

	var coupling = node_couplings.get(node.node_id, 0.0)
	if abs(coupling) < 0.01:
		return  # No significant coupling

	var effective_strength = coupling * active_strength

	# Apply ONLY Hamiltonian evolution (theta/phi) - NO DAMPING
	node.theta += hamiltonian_terms.get("sigma_y", 0.0) * effective_strength * dt
	node.theta = clamp(node.theta, 0.0, PI)

	node.phi += hamiltonian_terms.get("sigma_z", 0.0) * effective_strength * dt
	node.phi = fmod(node.phi + PI, TAU) - PI

	# Dissipation moved to Biome! (was: node.q/p *= damping_factor)

	node.update_energy()


## Set activation strength (0.0 to 1.0)
func set_activation(strength: float) -> void:
	var new_strength = clamp(strength, 0.0, 1.0)
	if abs(new_strength - active_strength) > 0.01:
		active_strength = new_strength
		activation_changed.emit(icon_name, active_strength)


## Get current activation level
func get_activation() -> float:
	return active_strength


## Check if Icon influences a specific node
func influences_node(node_id: String) -> bool:
	return node_couplings.has(node_id) and abs(node_couplings[node_id]) > 0.01


## Get coupling strength for a node
func get_coupling_strength(node_id: String) -> float:
	return node_couplings.get(node_id, 0.0)


## Debug output
func get_debug_string() -> String:
	return "[%s %s] Strength: %.2f | Influenced nodes: %d" % [
		icon_emoji, icon_name, active_strength, node_couplings.size()
	]
