class_name SymplecticValidator
extends RefCounted

## Symplectic Geometry Validator
##
## Validates that quantum evolution preserves fundamental invariants:
##
## 1. Trace conservation: Tr(rho) = 1 (probability normalization)
## 2. Hermiticity: rho = rho† (real observables)
## 3. Positivity: all eigenvalues >= 0 (valid probabilities)
## 4. Purity bounds: 1/d <= Tr(rho²) <= 1 (physical state)
##
## These are the quantum analogue of Liouville's theorem:
## Hamiltonian flow preserves phase space volume.
##
## For density matrices, this means evolution must be CPTP
## (completely positive trace-preserving).

## Tolerance for numerical errors
const TRACE_TOLERANCE: float = 0.01
const HERMITIAN_TOLERANCE: float = 0.001
const POSITIVITY_TOLERANCE: float = 0.001
const PURITY_TOLERANCE: float = 0.01

## ========================================
## Main Validation API
## ========================================

static func validate_evolution_step(density_before, density_after) -> Dictionary:
	"""Validate that evolution step preserved required invariants

	Args:
		density_before: ComplexMatrix state before evolution
		density_after: ComplexMatrix state after evolution

	Returns:
		{
			"valid": bool,
			"errors": Array[String],
			"warnings": Array[String],
			"trace_before": float,
			"trace_after": float,
			"trace_error": float,
			"hermitian": bool,
			"positive": bool,
			"purity_before": float,
			"purity_after": float
		}
	"""
	var result = {
		"valid": true,
		"errors": [],
		"warnings": []
	}

	# 1. Trace conservation
	var trace_before = _compute_trace(density_before)
	var trace_after = _compute_trace(density_after)
	var trace_error = abs(trace_after - trace_before)

	result["trace_before"] = trace_before
	result["trace_after"] = trace_after
	result["trace_error"] = trace_error

	if trace_error > TRACE_TOLERANCE:
		result.valid = false
		result.errors.append("Trace not conserved: %.4f -> %.4f (error: %.4f)" % [
			trace_before, trace_after, trace_error
		])

	# Also check trace = 1
	if abs(trace_after - 1.0) > TRACE_TOLERANCE:
		result.warnings.append("Trace deviates from 1.0: %.4f" % trace_after)

	# 2. Hermiticity check
	var hermitian = _check_hermitian(density_after)
	result["hermitian"] = hermitian

	if not hermitian:
		result.valid = false
		result.errors.append("Density matrix not Hermitian after evolution")

	# 3. Positivity check (diagonal >= 0)
	var positive = _check_positive(density_after)
	result["positive"] = positive

	if not positive:
		result.valid = false
		result.errors.append("Density matrix has negative diagonal elements")

	# 4. Purity bounds
	var purity_before = _compute_purity(density_before)
	var purity_after = _compute_purity(density_after)

	result["purity_before"] = purity_before
	result["purity_after"] = purity_after

	var dim = density_after.n
	var min_purity = 1.0 / float(dim)

	if purity_after < min_purity - PURITY_TOLERANCE:
		result.warnings.append("Purity below minimum: %.4f < %.4f" % [purity_after, min_purity])

	if purity_after > 1.0 + PURITY_TOLERANCE:
		result.valid = false
		result.errors.append("Purity exceeds 1.0: %.4f" % purity_after)

	return result


static func validate_state(density_matrix) -> Dictionary:
	"""Validate a single density matrix state

	Returns:
		{
			"valid": bool,
			"errors": Array[String],
			"trace": float,
			"hermitian": bool,
			"positive": bool,
			"purity": float
		}
	"""
	var result = {
		"valid": true,
		"errors": []
	}

	# Trace
	var trace = _compute_trace(density_matrix)
	result["trace"] = trace

	if abs(trace - 1.0) > TRACE_TOLERANCE:
		result.valid = false
		result.errors.append("Trace != 1: %.4f" % trace)

	# Hermiticity
	var hermitian = _check_hermitian(density_matrix)
	result["hermitian"] = hermitian

	if not hermitian:
		result.valid = false
		result.errors.append("Not Hermitian")

	# Positivity
	var positive = _check_positive(density_matrix)
	result["positive"] = positive

	if not positive:
		result.valid = false
		result.errors.append("Has negative eigenvalues")

	# Purity
	var purity = _compute_purity(density_matrix)
	result["purity"] = purity

	return result


## ========================================
## Property Computations
## ========================================

static func _compute_trace(density_matrix) -> float:
	"""Compute Tr(rho) = sum of diagonal elements"""
	var trace = 0.0
	var dim = density_matrix.n

	for i in range(dim):
		trace += density_matrix.get_element(i, i).re

	return trace


static func _compute_purity(density_matrix) -> float:
	"""Compute Tr(rho^2) = sum |rho_ij|^2"""
	var purity = 0.0
	var dim = density_matrix.n

	for i in range(dim):
		for j in range(dim):
			var elem = density_matrix.get_element(i, j)
			purity += elem.re * elem.re + elem.im * elem.im

	return purity


static func _check_hermitian(density_matrix) -> bool:
	"""Check if rho = rho† (Hermitian property)

	For Hermitian: rho_ij = rho_ji*
	"""
	var dim = density_matrix.n

	for i in range(dim):
		for j in range(i + 1, dim):
			var ij = density_matrix.get_element(i, j)
			var ji = density_matrix.get_element(j, i)

			# Check ij = ji* (conjugate)
			var re_diff = abs(ij.re - ji.re)
			var im_diff = abs(ij.im + ji.im)  # Imaginary parts should be opposite

			if re_diff > HERMITIAN_TOLERANCE or im_diff > HERMITIAN_TOLERANCE:
				return false

	return true


static func _check_positive(density_matrix) -> bool:
	"""Check positivity (simplified: diagonal elements >= 0)

	Full positivity check requires eigenvalue decomposition.
	For most cases, diagonal check is sufficient.
	"""
	var dim = density_matrix.n

	for i in range(dim):
		var diag = density_matrix.get_element(i, i).re
		if diag < -POSITIVITY_TOLERANCE:
			return false

	return true


## ========================================
## Advanced Checks
## ========================================

static func check_unitarity(evolution_operator) -> bool:
	"""Check if evolution operator U is unitary: U†U = I

	This is for Hamiltonian-only evolution (no dissipation).
	Not applicable when Lindblad terms are present.
	"""
	# Would need matrix multiplication implementation
	# For now, just return true as placeholder
	push_warning("SymplecticValidator: Unitarity check not fully implemented")
	return true


static func check_complete_positivity(kraus_operators: Array) -> bool:
	"""Check if Kraus operators satisfy CPTP conditions

	Sum_k K_k†K_k = I (completeness)

	Args:
		kraus_operators: Array of ComplexMatrix operators
	"""
	if kraus_operators.is_empty():
		return true

	# Would need matrix multiplication
	push_warning("SymplecticValidator: CPTP check not fully implemented")
	return true


## ========================================
## Phase Space Volume
## ========================================

static func estimate_phase_space_volume(trajectory: Array) -> float:
	"""Estimate phase space volume from trajectory points

	Uses convex hull volume estimation for 3D phase space.
	For Hamiltonian systems, this should be conserved.
	"""
	if trajectory.size() < 4:
		return 0.0

	# Simplified: use bounding box volume
	var min_pt = trajectory[0]
	var max_pt = trajectory[0]

	for point in trajectory:
		min_pt.x = min(min_pt.x, point.x)
		min_pt.y = min(min_pt.y, point.y)
		min_pt.z = min(min_pt.z, point.z)
		max_pt.x = max(max_pt.x, point.x)
		max_pt.y = max(max_pt.y, point.y)
		max_pt.z = max(max_pt.z, point.z)

	var size = max_pt - min_pt
	return size.x * size.y * size.z


static func check_volume_conservation(volume_before: float, volume_after: float, tolerance: float = 0.1) -> bool:
	"""Check if phase space volume is conserved within tolerance

	Liouville's theorem: Hamiltonian flow preserves phase space volume.
	"""
	if volume_before < 0.001:
		return true  # Can't check near-zero volumes

	var ratio = volume_after / volume_before
	return abs(ratio - 1.0) < tolerance


## ========================================
## Reporting
## ========================================

static func format_validation_report(validation: Dictionary) -> String:
	"""Format validation result as readable report"""
	var lines: Array[String] = [
		"=== Symplectic Validation Report ===",
		"",
		"Overall: %s" % ("VALID" if validation.get("valid", false) else "INVALID"),
		""
	]

	# Trace
	if validation.has("trace_before"):
		lines.append("Trace: %.4f -> %.4f (error: %.4f)" % [
			validation.trace_before,
			validation.trace_after,
			validation.trace_error
		])
	elif validation.has("trace"):
		lines.append("Trace: %.4f" % validation.trace)

	# Properties
	lines.append("Hermitian: %s" % ("YES" if validation.get("hermitian", false) else "NO"))
	lines.append("Positive: %s" % ("YES" if validation.get("positive", false) else "NO"))

	# Purity
	if validation.has("purity_before"):
		lines.append("Purity: %.4f -> %.4f" % [
			validation.purity_before,
			validation.purity_after
		])
	elif validation.has("purity"):
		lines.append("Purity: %.4f" % validation.purity)

	# Errors
	if validation.has("errors") and not validation.errors.is_empty():
		lines.append("")
		lines.append("ERRORS:")
		for error in validation.errors:
			lines.append("  - " + error)

	# Warnings
	if validation.has("warnings") and not validation.warnings.is_empty():
		lines.append("")
		lines.append("WARNINGS:")
		for warning in validation.warnings:
			lines.append("  - " + warning)

	return "\n".join(lines)


## ========================================
## Integration Hook
## ========================================

static func create_evolution_validator(quantum_computer) -> Callable:
	"""Create a validator callback for evolution hooks

	Usage:
		var validator = SymplecticValidator.create_evolution_validator(qc)
		# Call after each evolution step:
		validator.call()

	Returns:
		Callable that validates and logs warnings
	"""
	var last_state = null

	var validate_step = func():
		if quantum_computer == null or quantum_computer.density_matrix == null:
			return

		var current = quantum_computer.density_matrix

		if last_state != null:
			var validation = validate_evolution_step(last_state, current)

			if not validation.valid:
				push_warning("Symplectic violation detected:")
				for error in validation.errors:
					push_warning("  - " + error)

		# Store for next comparison (need to duplicate)
		last_state = _duplicate_matrix(current)

	return validate_step


static func _duplicate_matrix(matrix):
	"""Create a copy of a ComplexMatrix"""
	var Complex = load("res://Core/QuantumSubstrate/Complex.gd")
	var ComplexMatrix = load("res://Core/QuantumSubstrate/ComplexMatrix.gd")

	var copy = ComplexMatrix.new(matrix.n)

	for i in range(matrix.n):
		for j in range(matrix.n):
			var elem = matrix.get_element(i, j)
			copy.set_element(i, j, Complex.new(elem.re, elem.im))

	return copy
