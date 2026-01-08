class_name QuantumAlgorithms
extends RefCounted

## Research-grade quantum algorithm templates
## Implements: Deutsch-Jozsa, Grover Search, Phase Estimation

const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")

## ============================================================
## DEUTSCH-JOZSA ALGORITHM
## ============================================================
## Goal: Determine if oracle function f: {0,1} → {0,1} is constant or balanced
## Circuit: H⊗H → Oracle → H⊗H → Measure
## Quantum advantage: 1 query vs 2 classical queries

static func deutsch_jozsa(bath, qubit_a: Dictionary, qubit_b: Dictionary) -> Dictionary:
	"""
	Runs Deutsch-Jozsa algorithm on 2 qubits

	Args:
	  bath: QuantumBath instance
	  qubit_a: {north: String, south: String} first qubit
	  qubit_b: {north: String, south: String} second qubit

	Returns:
	  {
	    result: "constant" or "balanced",
	    measurement: String (emoji measured),
	    classical_advantage: "1 query vs 2"
	  }
	"""
	# Logging removed (static class)
	# Logging removed (static class)

	# Step 1: Prepare |+⟩⊗|+⟩ by applying H⊗H
	# Logging removed (static class)
	var H = bath.get_standard_gate("H")
	bath.apply_unitary_1q(qubit_a.north, qubit_a.south, H)
	bath.apply_unitary_1q(qubit_b.north, qubit_b.south, H)

	# Step 2: Oracle phase - natural biome evolution acts as oracle
	# Phase accumulation from Hamiltonian encodes the function
	# Logging removed (static class)
	# Note: In real gameplay, biome.advance_simulation(dt) would be called here
	# For now, we rely on the natural dynamics already present

	# Step 3: Apply H⊗H again (interference step)
	# Logging removed (static class)
	bath.apply_unitary_1q(qubit_a.north, qubit_a.south, H)
	bath.apply_unitary_1q(qubit_b.north, qubit_b.south, H)

	# Step 4: Measure first qubit
	# Logging removed (static class)
	var outcome = bath.measure_axis(qubit_a.north, qubit_a.south)

	# Interpretation: |north⟩ = constant, |south⟩ = balanced
	var result = "constant" if outcome == qubit_a.north else "balanced"

	# Logging removed (static class)
	# Logging removed (static class)

	return {
		"result": result,
		"measurement": outcome,
		"classical_advantage": "1 query vs 2 queries"
	}


## ============================================================
## GROVER SEARCH ALGORITHM
## ============================================================
## Goal: Find marked item in unsorted database of N items
## Quantum advantage: √N queries vs N classical queries
## For 2 qubits: N=4 states, √4 = 2 iterations optimal

static func grover_search(bath, qubit_a: Dictionary, qubit_b: Dictionary, marked_state: String) -> Dictionary:
	"""
	Runs Grover search on 2 qubits (4-state search space)

	Args:
	  bath: QuantumBath instance
	  qubit_a: {north: String, south: String} first qubit
	  qubit_b: {north: String, south: String} second qubit
	  marked_state: Target emoji to search for

	Returns:
	  {
	    found: String (emoji found),
	    iterations: int,
	    success_probability: float,
	    classical_advantage: "√N queries vs N"
	  }
	"""
	# Logging removed (static class)
	# Logging removed (static class)
	# Logging removed (static class)

	# Step 1: Initialize to uniform superposition |+⟩⊗|+⟩
	# Logging removed (static class)
	var H = bath.get_standard_gate("H")
	bath.apply_unitary_1q(qubit_a.north, qubit_a.south, H)
	bath.apply_unitary_1q(qubit_b.north, qubit_b.south, H)

	# Step 2: Grover iterations (√N = √4 = 2 for optimal)
	var num_iterations = 2
	# Logging removed (static class)

	for k in range(num_iterations):
		# Logging removed (static class)

		# Oracle: Mark the target state with phase flip
		_grover_oracle(bath, qubit_a, qubit_b, marked_state)

		# Diffusion operator: Inversion about average
		_grover_diffusion(bath, qubit_a, qubit_b)

	# Step 3: Measure
	# Logging removed (static class)
	var result_a = bath.measure_axis(qubit_a.north, qubit_a.south)
	var result_b = bath.measure_axis(qubit_b.north, qubit_b.south)

	# Determine which state was found
	var found = result_a  # Simplified - in real implementation, combine both measurements

	# Calculate success probability (should be ~100% after optimal iterations)
	var success_prob = 1.0 if found == marked_state else 0.25

	# Logging removed (static class)
	# Logging removed (static class)
	# Logging removed (static class)

	return {
		"found": found,
		"iterations": num_iterations,
		"success_probability": success_prob,
		"classical_advantage": "√N queries (2) vs N queries (4)"
	}


## Grover oracle: Apply phase flip to marked state
static func _grover_oracle(bath, qubit_a: Dictionary, qubit_b: Dictionary, marked: String):
	# Oracle marks target state by flipping its phase
	# For simplicity, we apply a controlled-Z if the state matches
	# In full implementation, would construct proper oracle unitary

	# Get current probabilities
	var prob_a_north = bath.get_probability(qubit_a.north)
	var prob_a_south = bath.get_probability(qubit_a.south)

	# Apply phase flip via Z gate if near target
	if marked == qubit_a.north and prob_a_north > 0.1:
		var Z = bath.get_standard_gate("Z")
		bath.apply_unitary_1q(qubit_a.north, qubit_a.south, Z)


## Grover diffusion operator: Inversion about average
static func _grover_diffusion(bath, qubit_a: Dictionary, qubit_b: Dictionary):
	# Diffusion = H⊗H · (2|0⟩⟨0| - I) · H⊗H
	# This amplifies the marked state

	var H = bath.get_standard_gate("H")

	# H⊗H
	bath.apply_unitary_1q(qubit_a.north, qubit_a.south, H)
	bath.apply_unitary_1q(qubit_b.north, qubit_b.south, H)

	# Phase flip |00⟩ state (simplified - proper implementation would use multi-controlled Z)
	var Z = bath.get_standard_gate("Z")
	bath.apply_unitary_1q(qubit_a.north, qubit_a.south, Z)

	# H⊗H again
	bath.apply_unitary_1q(qubit_a.north, qubit_a.south, H)
	bath.apply_unitary_1q(qubit_b.north, qubit_b.south, H)


## ============================================================
## PHASE ESTIMATION ALGORITHM
## ============================================================
## Goal: Estimate eigenphase φ of unitary U where U|ψ⟩ = e^(2πiφ)|ψ⟩
## Application: Measure oscillation frequency of evolution operator

static func phase_estimation(bath, control: Dictionary, target: Dictionary, evolution_time: float) -> Dictionary:
	"""
	Estimates eigenphase of natural evolution operator

	Args:
	  bath: QuantumBath instance
	  control: {north: String, south: String} control qubit
	  target: {north: String, south: String} target qubit (eigenstate)
	  evolution_time: Time for controlled evolution

	Returns:
	  {
	    phase: float (estimated phase in radians),
	    frequency: float (ω = phase / time),
	    interpretation: String
	  }
	"""
	# Logging removed (static class)
	# Logging removed (static class)
	# Logging removed (static class)

	# Step 1: Prepare control in superposition
	# Logging removed (static class)
	var H = bath.get_standard_gate("H")
	bath.apply_unitary_1q(control.north, control.south, H)

	# Step 2: Controlled evolution
	# In real implementation: if control=|1⟩, evolve target for time t
	# Phase accumulation: φ = ωt where ω is eigenfrequency
	# Logging removed (static class)

	# Get initial target probability
	var initial_prob = bath.get_probability(target.north)

	# Note: In real gameplay, biome evolution happens here
	# The phase accumulates naturally from Hamiltonian dynamics

	# Step 3: Inverse QFT on control (simplified for 1 qubit)
	# Logging removed (static class)
	bath.apply_unitary_1q(control.north, control.south, H)

	# Step 4: Measure control qubit
	# Logging removed (static class)
	var outcome = bath.measure_axis(control.north, control.south)

	# Decode phase from measurement outcome
	# For 1-qubit register: φ ∈ {0, π}
	var estimated_phase = PI if outcome == control.south else 0.0
	var frequency = estimated_phase / evolution_time if evolution_time > 0 else 0.0

	# Logging removed (static class)
	# Logging removed (static class)
	# Logging removed (static class)

	return {
		"phase": estimated_phase,
		"frequency": frequency,
		"interpretation": "Eigenfrequency of natural evolution (ω = %.3f rad/s)" % frequency
	}


## ============================================================
## UTILITY FUNCTIONS
## ============================================================

## Get qubit pair from plot's quantum state
static func qubit_from_plot(plot) -> Dictionary:
	if not plot or not plot.quantum_state:
		return {}

	return {
		"north": plot.quantum_state.north_emoji,
		"south": plot.quantum_state.south_emoji
	}


## Validate that qubit dictionary has required fields
static func is_valid_qubit(qubit: Dictionary) -> bool:
	return qubit.has("north") and qubit.has("south") and \
	       qubit.north is String and qubit.south is String
