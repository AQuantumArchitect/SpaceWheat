class_name OperatorSerializer
extends RefCounted

## Serializes quantum operators (ComplexMatrix) to/from Dictionary
## Used by OperatorCache to save/load cached operators

const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")

## Convert ComplexMatrix to saveable Dictionary
static func serialize_matrix(matrix: ComplexMatrix) -> Dictionary:
	if not matrix:
		return {}

	var data = {
		"n": matrix.n,  # Dimension (n×n square matrix)
		"data": []
	}

	# Serialize complex numbers as [re, im] pairs
	for c in matrix._data:  # Note: _data is the internal array
		data.data.append([c.re, c.im])

	return data

## Reconstruct ComplexMatrix from Dictionary
static func deserialize_matrix(data: Dictionary) -> ComplexMatrix:
	if data.is_empty():
		return null

	# ComplexMatrix is square (n×n)
	var matrix = ComplexMatrix.new(data.n)

	for i in range(data.data.size()):
		var pair = data.data[i]
		matrix._data[i] = Complex.new(pair[0], pair[1])

	return matrix

## Package Hamiltonian + Lindblad operators for saving
static func serialize_operators(hamiltonian: ComplexMatrix, lindblad_ops: Array) -> Dictionary:
	return {
		"hamiltonian": serialize_matrix(hamiltonian),
		"lindblad_operators": lindblad_ops.map(serialize_matrix),
		"lindblad_count": lindblad_ops.size(),
		"timestamp": Time.get_unix_time_from_system(),
		"format_version": 1
	}

## Unpack saved operators
static func deserialize_operators(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}

	return {
		"hamiltonian": deserialize_matrix(data.hamiltonian),
		"lindblad_operators": data.lindblad_operators.map(deserialize_matrix)
	}
