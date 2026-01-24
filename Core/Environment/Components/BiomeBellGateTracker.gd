class_name BiomeBellGateTracker
extends RefCounted

## Bell Gate Tracking Component
##
## Extracted from BiomeBase to handle:
## - Historical entanglement relationships (bell_gates array)
## - Bell gate creation and query methods

# Signals
signal bell_gate_created(positions: Array)

# Bell Gates: Historical entanglement relationships
# Tracks which plots have been entangled together in the past
# Structure: Array of [pos1, pos2, pos3] triplets (for kitchen) or [pos1, pos2] pairs (for 2-qubit)
var bell_gates: Array = []  # Array of Vector2i arrays (triplets or pairs)


# ============================================================================
# Bell Gate Management
# ============================================================================

func mark_bell_gate(positions: Array) -> void:
	"""Mark plots as having been entangled (creates a Bell gate)

	This records the historical relationship - even if plots are no longer
	entangled now, they can be used as a measurement target later.

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
# State Management
# ============================================================================

func clear() -> void:
	"""Clear all Bell gates"""
	bell_gates.clear()


# ============================================================================
# Helpers
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
