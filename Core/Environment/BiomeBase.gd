class_name BiomeBase
extends Node

## Abstract base class for all biomes
## Provides shared infrastructure for quantum evolution without enforcing specific physics
## All 8 biome implementations extend this class

const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const BiomeUtilities = preload("res://Core/Environment/BiomeUtilities.gd")
const BiomeTimeTracker = preload("res://Core/Environment/BiomeTimeTracker.gd")

# Common infrastructure
var time_tracker: BiomeTimeTracker = BiomeTimeTracker.new()
var quantum_states: Dictionary = {}  # Vector2i -> DualEmojiQubit
var grid = null  # Injected FarmGrid reference

# Bell Gates: Historical entanglement relationships
# Tracks which plots have been entangled together in the past
# Structure: Array of [pos1, pos2, pos3] triplets (for kitchen) or [pos1, pos2] pairs (for 2-qubit)
var bell_gates: Array = []  # Array of Vector2i arrays (triplets or pairs)

# Signals - common interface for all biomes
signal qubit_created(position: Vector2i, qubit: Resource)
signal qubit_measured(position: Vector2i, outcome: String)
signal qubit_evolved(position: Vector2i)
signal bell_gate_created(positions: Array)  # New: emitted when plots are entangled


func _ready() -> void:
	"""Initialize biome - called by Godot when node enters scene tree"""
	set_process(true)


func _process(dt: float) -> void:
	"""Main process loop - delegates to biome-specific evolution"""
	time_tracker.update(dt)
	_update_quantum_substrate(dt)


func _update_quantum_substrate(dt: float) -> void:
	"""Override in subclasses to define biome-specific quantum evolution"""
	pass


# ============================================================================
# Common Quantum Operations
# ============================================================================

func create_quantum_state(position: Vector2i, north: String, south: String, theta: float = PI/2) -> Resource:
	"""Create and store a quantum state at grid position"""
	var qubit = BiomeUtilities.create_qubit(north, south, theta)
	quantum_states[position] = qubit
	qubit_created.emit(position, qubit)
	return qubit


func get_qubit(position: Vector2i) -> Resource:
	"""Retrieve quantum state at position"""
	return quantum_states.get(position)


func measure_qubit(position: Vector2i) -> String:
	"""Measure (collapse) quantum state at position"""
	var qubit = quantum_states.get(position)
	if not qubit:
		return ""
	var outcome = qubit.measure()
	qubit_measured.emit(position, outcome)
	return outcome


func clear_qubit(position: Vector2i) -> void:
	"""Remove quantum state at position"""
	if position in quantum_states:
		quantum_states.erase(position)


# ============================================================================
# Bell Gates - Historical Entanglement Relationships
# ============================================================================

func mark_bell_gate(positions: Array) -> void:
	"""
	Mark plots as having been entangled (creates a Bell gate)

	This records the historical relationship - even if plots are no longer
	entangled now, they can be used as a measurement target later.

	NOTE: Biome subclasses can override to apply energy boosts to entangled qubits.

	Args:
		positions: [Vector2i, Vector2i] for 2-qubit OR [Vector2i, Vector2i, Vector2i] for 3-qubit
	"""
	if positions.size() < 2:
		push_error("Bell gate requires at least 2 positions")
		return

	# Check if this exact gate already exists
	for existing_gate in bell_gates:
		if _gates_equal(existing_gate, positions):
			return  # Already recorded

	bell_gates.append(positions.duplicate())
	bell_gate_created.emit(positions)

	print("🔔 Bell gate created at biome %s: %s" % [get_biome_type(), _format_positions(positions)])


func get_bell_gate(index: int) -> Array:
	"""Get a specific Bell gate by index"""
	if index >= 0 and index < bell_gates.size():
		return bell_gates[index]
	return []


func get_all_bell_gates() -> Array:
	"""Get all Bell gates in this biome"""
	return bell_gates.duplicate()


func get_bell_gates_of_size(size: int) -> Array:
	"""Get all Bell gates with specific size (2 for pairs, 3 for triplets)"""
	var filtered = []
	for gate in bell_gates:
		if gate.size() == size:
			filtered.append(gate)
	return filtered


func get_triplet_bell_gates() -> Array:
	"""Get all 3-qubit Bell gates (for kitchen use)"""
	return get_bell_gates_of_size(3)


func get_pair_bell_gates() -> Array:
	"""Get all 2-qubit Bell gates"""
	return get_bell_gates_of_size(2)


func has_bell_gates() -> bool:
	"""Check if any Bell gates exist"""
	return bell_gates.size() > 0


func bell_gate_count() -> int:
	"""Get number of Bell gates"""
	return bell_gates.size()


# ============================================================================
# Status & Debug
# ============================================================================

func get_status() -> Dictionary:
	"""Get current biome status (override to add custom fields)"""
	return BiomeUtilities.create_status_dict({
		"type": get_biome_type(),
		"qubits": quantum_states.size(),
		"time": time_tracker.time_elapsed,
		"cycles": time_tracker.cycle_count
	})


func get_biome_type() -> String:
	"""Override in subclasses to return biome type name"""
	return "Base"


# ============================================================================
# Reset & Lifecycle
# ============================================================================

func reset() -> void:
	"""Reset biome to initial state"""
	quantum_states.clear()
	bell_gates.clear()
	time_tracker.reset()
	_reset_custom()


func _reset_custom() -> void:
	"""Override in subclasses for biome-specific reset logic"""
	pass


# ============================================================================
# Helper Functions - Bell Gate Utilities
# ============================================================================

func _gates_equal(gate1: Array, gate2: Array) -> bool:
	"""Check if two gates are equal (same positions, any order)"""
	if gate1.size() != gate2.size():
		return false

	var g1_sorted = gate1.duplicate()
	var g2_sorted = gate2.duplicate()
	g1_sorted.sort()
	g2_sorted.sort()

	for i in range(g1_sorted.size()):
		if g1_sorted[i] != g2_sorted[i]:
			return false

	return true


func _format_positions(positions: Array) -> String:
	"""Format position array as readable string"""
	var parts = []
	for pos in positions:
		parts.append(str(pos))
	return "[" + ", ".join(parts) + "]"
