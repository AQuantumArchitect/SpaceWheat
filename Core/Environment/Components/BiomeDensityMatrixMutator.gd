class_name BiomeDensityMatrixMutator
extends RefCounted

## Density Matrix Mutator Component
##
## Extracted from BiomeBase to handle:
## - collapse_register() - Project density matrix on measurement
## - drain_register_probability() - Ensemble drain model for MEASURE action

const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")

# Injected dependency
var quantum_computer = null


func set_quantum_computer(qc) -> void:
	"""Set the quantum computer reference"""
	quantum_computer = qc


# ============================================================================
# Density Matrix Collapse (for MEASURE action)
# ============================================================================

func collapse_register(register_id: int, is_north: bool) -> void:
	"""Collapse density matrix for a measured register.

	Applies projection operator P = |outcome><outcome| to density matrix.
	This zeros off-diagonal elements involving this register.

	Args:
		register_id: The register that was measured
		is_north: True if collapsed to north state, False for south
	"""
	if not quantum_computer:
		return

	# Get the density matrix
	var rho = quantum_computer.get_density_matrix()
	if not rho:
		return

	# Project to measured state
	# For single-qubit register: zero off-diagonal and normalize diagonal
	var outcome_index = 0 if is_north else 1

	# This is a simplified collapse - full implementation would use
	# proper projection operators on the multi-qubit density matrix
	if quantum_computer.has_method("project_register"):
		quantum_computer.project_register(register_id, outcome_index)
	else:
		# Fallback: just mark that collapse happened (logging)
		print("BiomeDensityMatrixMutator: collapse_register(%d, %s) - no quantum handler" % [
			register_id, "north" if is_north else "south"
		])


func drain_register_probability(register_id: int, is_north: bool, drain_factor: float) -> void:
	"""Drain probability from measured outcome (Ensemble model).

	Reduces probability in rho for the measured state without full collapse.
	Used by MEASURE action to simulate extracting from the ensemble.

	Args:
		register_id: Which qubit was measured
		is_north: True if outcome was north (|0>)
		drain_factor: Fraction to drain (e.g., 0.5 = reduce by half)
	"""
	if not quantum_computer:
		return

	var rho = quantum_computer.get_density_matrix()
	if not rho:
		return

	var num_qubits = quantum_computer.register_map.num_qubits
	if register_id < 0 or register_id >= num_qubits:
		return

	var dim = rho.n
	var outcome_pole = 0 if is_north else 1
	var shift = num_qubits - 1 - register_id

	# Drain diagonal elements where this qubit is in the measured state
	for basis_idx in range(dim):
		var bit = (basis_idx >> shift) & 1
		if bit == outcome_pole:
			var diag = rho.get_element(basis_idx, basis_idx)
			if diag:
				# Reduce by drain_factor (e.g., 0.5 means halve it)
				var new_re = diag.re * (1.0 - drain_factor)
				rho.set_element(basis_idx, basis_idx, Complex.new(new_re, diag.im))

	# Renormalize to maintain trace = 1
	var trace: float = 0.0
	for i in range(dim):
		var elem = rho.get_element(i, i)
		if elem:
			trace += elem.re

	if trace > 0.0:
		for i in range(dim):
			var elem = rho.get_element(i, i)
			if elem:
				rho.set_element(i, i, Complex.new(elem.re / trace, elem.im))
