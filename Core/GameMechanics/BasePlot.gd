class_name BasePlot
extends Resource

## BasePlot - Foundation class for all farm plots
## Contains core properties and quantum state management
## All plots share: quantum state, position, basic signals

const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

signal growth_complete
signal state_collapsed(final_state: String)

# Plot identification
@export var plot_id: String = ""
@export var grid_position: Vector2i = Vector2i.ZERO

# Quantum state (DualEmojiQubit for quantum plots, null for non-quantum)
var quantum_state = null  # Injected DualEmojiQubit instance from Biome

# Quantum state accessors (for backwards compatibility)
@export var theta: float:
	get: return quantum_state.theta if quantum_state else PI/2.0
	set(value): if quantum_state: quantum_state.theta = value

@export var phi: float:
	get: return quantum_state.phi if quantum_state else 0.0
	set(value): if quantum_state: quantum_state.phi = value

# Plot state
@export var is_planted: bool = false
@export var has_been_measured: bool = false
@export var theta_frozen: bool = false  # True after measurement - stops theta drift

# Conspiracy network connection
@export var conspiracy_node_id: String = ""
@export var conspiracy_bond_strength: float = 0.0

# Berry phase accumulator (plot memory)
@export var replant_cycles: int = 0
@export var berry_phase: float = 0.0

# Entanglement tracking
var entangled_plots: Dictionary = {}  # plot_id -> strength
var plot_infrastructure_entanglements: Array[Vector2i] = []
const MAX_ENTANGLEMENTS = 3


func _init():
	plot_id = "plot_%d" % randi()


## Core Methods


func get_dominant_emoji() -> String:
	"""Get the current dominant emoji based on quantum state"""
	if not quantum_state:
		return "?"
	return quantum_state.get_semantic_state()


func collapse_to_measurement(outcome: String) -> void:
	"""Collapse quantum state based on measurement outcome"""
	if quantum_state:
		quantum_state.measured_energy = quantum_state.radius
		theta_frozen = true
		has_been_measured = true
		state_collapsed.emit(outcome)
