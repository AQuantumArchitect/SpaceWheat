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


func plant(quantum_state_or_labor = null, wheat_cost: float = 0.0, biome = null) -> void:
	"""Plant this plot with a quantum state

	Overloaded method supports both:
	1. plant(quantum_state: DualEmojiQubit) - direct quantum state injection
	2. plant(labor: float, wheat: float, biome: BiomeBase) - biome resource-based planting
	"""
	# Handle both calling conventions
	if quantum_state_or_labor is Resource:
		# Direct quantum state injection (Resource type check)
		quantum_state = quantum_state_or_labor
		print("🌱 Plot.plant(): injected quantum state at %s" % grid_position)
	elif biome != null:
		# Resource-based planting: biome will handle quantum state creation
		# For now, create a default quantum state
		# (Biome can override this if needed)
		quantum_state = DualEmojiQubit.new("?", "?", PI/2)
		print("🌱 Plot.plant(): created default quantum state at %s" % grid_position)
	else:
		# Fallback: create minimal quantum state
		quantum_state = DualEmojiQubit.new("?", "?", PI/2)
		print("🌱 Plot.plant(): fallback quantum state at %s" % grid_position)

	# Mark as planted
	is_planted = true
	print("   ✅ Plot %s now planted=%s, quantum_state exists=%s" % [grid_position, is_planted, quantum_state != null])


func measure(icon_network = null) -> String:
	"""Measure (collapse) quantum state at this plot

	Args:
		icon_network: Optional icon network for measurement bias (from Imperium)

	Returns: The measurement outcome emoji (e.g., "🌾", "👥")
	Sets: has_been_measured = true on success
	"""
	if not quantum_state:
		return ""

	# Call the quantum state's measure method
	var outcome = quantum_state.measure()

	# Mark as measured
	has_been_measured = true
	theta_frozen = true
	print("🔬 Plot %s measured: outcome=%s" % [grid_position, outcome])

	return outcome


func harvest() -> Dictionary:
	"""Harvest this plot - collect yield and clear quantum state

	Returns: Dictionary with {success: bool, yield: int, outcome: String}
	"""
	if not is_planted:
		return {"success": false, "yield": 0}

	if not has_been_measured:
		return {"success": false, "yield": 0}

	# Get the outcome emoji from the measurement
	var outcome = quantum_state.get_semantic_state() if quantum_state else "?"

	# Calculate yield (quantum-only: depends on Berry phase and entanglement)
	var yield_amount = 1
	if quantum_state:
		# Base yield from energy
		yield_amount = max(1, int(quantum_state.energy * 10))
		# Bonus from Berry phase (entanglement memory)
		yield_amount += int(berry_phase)

	# Clear the plot
	is_planted = false
	quantum_state = null
	has_been_measured = false
	theta_frozen = false
	replant_cycles += 1

	print("✂️  Plot %s harvested: yield=%d, outcome=%s" % [grid_position, yield_amount, outcome])

	return {
		"success": true,
		"yield": yield_amount,
		"outcome": outcome
	}


func collapse_to_measurement(outcome: String) -> void:
	"""Collapse quantum state based on measurement outcome"""
	if quantum_state:
		quantum_state.measured_energy = quantum_state.radius
		theta_frozen = true
		has_been_measured = true
		state_collapsed.emit(outcome)
