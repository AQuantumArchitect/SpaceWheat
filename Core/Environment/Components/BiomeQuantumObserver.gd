class_name BiomeQuantumObserver
extends RefCounted

## Quantum Observable Reader Component
##
## Extracted from BiomeBase to handle:
## - Observable readers (theta, phi, coherence, radius, amplitude, phase)
## - Visualization support (emoji probability, purity)
## - Register queries for quantum state inspection

const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")

# Injected dependency
var quantum_computer = null


func set_quantum_computer(qc) -> void:
	"""Set the quantum computer reference"""
	quantum_computer = qc


# ============================================================================
# Quest System Observable Readers (Phase 4)
# ============================================================================
# Safe read-only methods that work in both bath-first and legacy modes
# Used by quest system to track quantum state progress

func get_observable_theta(north: String, south: String) -> float:
	"""Get polar angle theta for projection [0, PI]

	Physical meaning: theta=0 is pure north, theta=PI is pure south, theta=PI/2 is equal superposition
	Safe read-only method that works in both bath and legacy modes.

	Args:
		north: North pole emoji (e.g., "🌾")
		south: South pole emoji (e.g., "👥")

	Returns:
		Polar angle in radians [0, PI], or PI/2 if projection doesn't exist
	"""
	if quantum_computer and quantum_computer.has_method("get_population"):
		var p_north = quantum_computer.get_population(north)
		var p_south = quantum_computer.get_population(south)
		var mass = p_north + p_south
		if mass > 0.001:
			# theta = 2 * acos(sqrt(p_north / mass))
			return 2.0 * acos(sqrt(p_north / mass))
	return PI/2


func get_observable_phi(_north: String, _south: String) -> float:
	"""Get azimuthal phase phi for projection [0, 2*PI]

	Physical meaning: relative quantum phase between north and south states
	Note: Phase information not available from populations alone, return 0.

	Args:
		north: North pole emoji
		south: South pole emoji

	Returns:
		Azimuthal angle in radians [0, 2*PI], or 0.0 if unavailable
	"""
	# Phase requires off-diagonal elements which aren't easily accessible
	return 0.0


func get_observable_coherence(north: String, south: String) -> float:
	"""Get coherence (superposition strength) [0, 1]

	Physical meaning: How much in superposition vs classical mixture
	coherence = sin(theta), maximized at theta=PI/2 (equal superposition)

	Args:
		north: North pole emoji
		south: South pole emoji

	Returns:
		Coherence value [0, 1], where 1.0 is maximum superposition
	"""
	var theta = get_observable_theta(north, south)
	return abs(sin(theta))


func get_observable_radius(north: String, south: String) -> float:
	"""Get amplitude radius in projection subspace [0, 1]

	Physical meaning: How much "spirit" lives in this north/south axis
	radius = sqrt(|alpha_north|^2 + |alpha_south|^2)
	"""
	if quantum_computer and quantum_computer.has_method("get_population"):
		var p_north = quantum_computer.get_population(north)
		var p_south = quantum_computer.get_population(south)
		return sqrt(p_north + p_south)
	return 0.0


func get_observable_amplitude(emoji: String) -> float:
	"""Get probability of specific emoji in quantum_computer [0, 1]

	Returns sqrt of population as amplitude proxy.
	"""
	if quantum_computer and quantum_computer.has_method("get_population"):
		return sqrt(quantum_computer.get_population(emoji))
	return 0.0


func get_observable_phase(_emoji: String) -> float:
	"""Get phase of specific emoji [-PI, PI]

	Phase information not directly available from quantum_computer populations.
	Returns 0.0.
	"""
	return 0.0


# ============================================================================
# Quantum Data Access (for QuantumNode visualization)
# ============================================================================

func get_emoji_probability(emoji: String) -> float:
	"""Get probability of seeing this emoji when measured.

	Maps emoji to its register and pole, then computes marginal probability.
	Used by QuantumNode for opacity visualization.
	"""
	if not quantum_computer or not quantum_computer.register_map:
		return 0.5

	if not quantum_computer.register_map.has(emoji):
		return 0.0

	var qubit = quantum_computer.register_map.qubit(emoji)
	var pole = quantum_computer.register_map.pole(emoji)

	# Get probability of |0> (north) for this qubit
	var p_north = get_register_probability(qubit)

	# Return probability based on pole (0 = north, 1 = south)
	return p_north if pole == 0 else (1.0 - p_north)


func get_emoji_coherence(north_emoji: String, south_emoji: String):
	"""Get coherence (off-diagonal element) between north and south states.

	Returns Complex or null if not computable.
	Used by QuantumNode for color phase visualization.
	"""
	if not quantum_computer or not quantum_computer.register_map or not quantum_computer.density_matrix:
		return null

	# Both emojis should be on same qubit
	if not quantum_computer.register_map.has(north_emoji):
		return null
	if not quantum_computer.register_map.has(south_emoji):
		return null

	var north_q = quantum_computer.register_map.qubit(north_emoji)
	var south_q = quantum_computer.register_map.qubit(south_emoji)

	if north_q != south_q:
		return null  # Not on same qubit

	# DIRECT COMPUTATION: Compute reduced 2x2 density matrix for this qubit
	var num_qubits = quantum_computer.register_map.num_qubits
	if num_qubits == 0:
		return null

	var dim_full = quantum_computer.density_matrix.n
	var north_pole = quantum_computer.register_map.pole(north_emoji)  # 0 for north
	var south_pole = quantum_computer.register_map.pole(south_emoji)  # 1 for south

	# Ensure poles are different
	if north_pole == south_pole:
		return null

	# Build reduced density matrix: rho_marginal[a,b] where a,b in {0,1}
	var rho_marginal = ComplexMatrix.new(2)

	for a in range(2):  # a = 0 (north) or 1 (south)
		for b in range(2):  # b = 0 (north) or 1 (south)
			var element = Complex.zero()

			# Trace over all other qubits
			for basis_i in range(dim_full):
				for basis_j in range(dim_full):
					# Check if north_q bit matches a in basis_i, b in basis_j
					var shift = num_qubits - 1 - north_q
					var bit_i = (basis_i >> shift) & 1
					var bit_j = (basis_j >> shift) & 1

					if bit_i == a and bit_j == b:
						# Check if other qubits are the same
						var mask = (1 << num_qubits) - 1 - (1 << shift)
						if (basis_i & mask) == (basis_j & mask):
							element = element.add(quantum_computer.density_matrix.get_element(basis_i, basis_j))

			rho_marginal.set_element(a, b, element)

	# Return the off-diagonal element rho[0,1] (coherence from north to south)
	var coherence = rho_marginal.get_element(0, 1)
	return coherence if coherence and coherence.abs() > 1e-15 else null


func get_purity() -> float:
	"""Get purity Tr(rho^2) of the quantum state.

	Pure state = 1.0 (bright glow), maximally mixed = 1/N (dim).
	Used by QuantumNode for glow intensity.
	"""
	if quantum_computer:
		return quantum_computer.get_purity()
	return 0.5  # Default: partially mixed


# ============================================================================
# Register Probability Queries
# ============================================================================

func get_register_probability(register_id: int) -> float:
	"""Get probability of |0> (north) state for a qubit (register).

	Used by EXPLORE for weighted random selection.
	Returns P(|0>) for the specified qubit by tracing out other qubits.
	"""
	if not quantum_computer:
		return 0.5  # Default: equal probability

	# Access density_matrix property directly
	var rho = quantum_computer.density_matrix
	if not rho:
		return 0.5

	var num_qubits = quantum_computer.register_map.num_qubits
	if register_id < 0 or register_id >= num_qubits:
		return 0.5

	# Sum probabilities of all basis states where this qubit is |0>
	var dim = rho.n  # ComplexMatrix.n is the dimension
	var prob_north: float = 0.0

	for basis_idx in range(dim):
		# Check if qubit `register_id` is |0> in this basis state
		# Bit position: leftmost qubit is highest bit
		var shift = num_qubits - 1 - register_id
		var bit = (basis_idx >> shift) & 1

		if bit == 0:  # North state (|0>)
			var diag = rho.get_element(basis_idx, basis_idx)
			if diag:
				prob_north += diag.re

	# Clamp to valid probability range (numerical precision can cause small negatives)
	return clamp(prob_north, 0.0, 1.0)


func get_register_emoji_pair(register_id: int) -> Dictionary:
	"""Get the north/south emoji pair for a register (qubit).

	Returns: {"north": "🌾", "south": "🍄"} or empty dict if not found.
	"""
	if not quantum_computer or not quantum_computer.register_map:
		return {}

	# Use RegisterMap.axis() to get the emoji pair for this qubit
	var axis = quantum_computer.register_map.axis(register_id)
	if axis.is_empty():
		return {}

	return {
		"north": axis.get("north", "?"),
		"south": axis.get("south", "?")
	}


func get_coherence_with_other_registers(register_id: int) -> float:
	"""Get total coherence (entanglement indicator) between this register and others.

	Returns sum of |rho_ij| for off-diagonal elements involving this register.
	High value indicates entanglement that will break on measurement.
	"""
	if not quantum_computer:
		return 0.0

	var rho = quantum_computer.get_density_matrix()
	if not rho:
		return 0.0

	var dim = rho.n  # ComplexMatrix uses .n for dimension
	if register_id < 0 or register_id >= dim:
		return 0.0

	# Sum off-diagonal magnitudes for this row/column
	var coherence: float = 0.0
	for i in range(dim):
		if i != register_id:
			var elem = rho.get_element(register_id, i)
			if elem:
				coherence += sqrt(elem.re * elem.re + elem.im * elem.im)

	return coherence
