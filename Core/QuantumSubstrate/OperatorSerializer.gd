class_name OperatorSerializer
extends RefCounted

## Serializes quantum operators (ComplexMatrix) to/from Dictionary
## Used by OperatorCache to save/load cached operators


## Convert ComplexMatrix to saveable Dictionary.
##
## CRITICAL: read the matrix through `_to_packed()`, NOT the raw `_data` array.
## After the packed-matrix optimization, a freshly built/derived matrix (e.g. the
## output of HamiltonianBuilder's `_hermitianize` → add/scale) keeps its values in
## the PackedFloat64Array / native backend, leaving the legacy `_data` Complex array
## empty. Iterating `_data` directly serialized an all-zero Hamiltonian (`{"data":[],
## "n":N}`) — the dead-substrate bug (#118) that froze every qubit. `_to_packed()`
## canonically pulls from native → packed regardless of which backend is live.
static func serialize_matrix(matrix: ComplexMatrix) -> Dictionary:
	if not matrix:
		return {}

	var n: int = matrix.n
	var data = {
		"n": n,  # Dimension (n×n square matrix)
		"data": []
	}

	# Dense [re, im] pairs, read from the authoritative packed representation.
	var packed: PackedFloat64Array = matrix._to_packed()
	var count: int = n * n
	if packed.size() >= count * 2:
		for idx in range(count):
			data.data.append([packed[idx * 2], packed[idx * 2 + 1]])

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
