class_name GateInjector
extends RefCounted

## GateInjector - applies gates to a biome's QuantumComputer, singly or in order.
##
## Flow:
##   input/instrument command → GateActionHandler → GateInjector.inject_gate()
##        ↓
##   QuantumComputer.apply_gate()  →  ρ written, state_epoch stamped
##
## Nothing here touches the lookahead batcher. A gate is a write to ρ like any
## other; the batcher sees the QuantumComputer's state_epoch move past the epoch
## its frames were forecast from, and evolves from the live ρ instead of replaying
## them (BiomeEvolutionBatcher._forecast_epoch). The one thing left to do after a
## gate is braid_order's: refresh the cached mutual information from the live ρ,
## so a just-built Bell scores at once (_refresh_mi).
##
## Batch Flow (for multi-select):
##   UI Shift+E → GateInjector.inject_gate_batch(ordered_gates)
##        ↓
##   Apply all gates in order → one MI refresh per touched biome at the end



## ============================================================================
## BATCH GATE INJECTION (Multi-select operations)
## ============================================================================

static func inject_gate_batch(gate_ops: Array, _farm = null) -> Dictionary:
	# Apply multiple gates in order, refresh MI once per biome at the end.

	# Args:
	# gate_ops: Array of gate operations, each is a Dictionary:
	# {
	# biome: BiomeBase,
	# qubit: int,
	# gate_name: String (e.g., "H", "X", "Rx"),
	# gate_matrix: ComplexMatrix (optional, if not using gate_name)
	# }
	# _farm: unused (kept for callers; the batcher notices writes itself)

	# Returns:
	# Dictionary with:
	# - success: bool (true if any gate succeeded)
	# - applied_count: int
	# - failed_count: int
	# - results: Array of per-gate results
	# - order: Array of qubit indices in application order
	if gate_ops.is_empty():
		return {"success": false, "error": "empty_batch", "applied_count": 0}

	var results: Array = []
	var applied_count = 0
	var failed_count = 0
	var order: Array = []
	var touched: Array = []

	# Apply gates in order
	for op in gate_ops:
		var biome = op.get("biome")
		var qubit = op.get("qubit", -1)
		var gate_name = op.get("gate_name", "")
		var gate_matrix = op.get("gate_matrix")

		if not biome or not biome.quantum_computer:
			results.append({"success": false, "error": "no_quantum_computer", "qubit": qubit})
			failed_count += 1
			continue

		if not touched.has(biome):
			touched.append(biome)

		# Get gate matrix from library if not provided
		if gate_matrix == null and gate_name != "":
			var gate_lib = QuantumGateLibrary.new()
			if gate_lib.GATES.has(gate_name):
				gate_matrix = gate_lib.GATES[gate_name]["matrix"]

		if gate_matrix == null:
			results.append({"success": false, "error": "no_gate_matrix", "qubit": qubit, "gate": gate_name})
			failed_count += 1
			continue

		var success = biome.quantum_computer.apply_gate(qubit, gate_matrix)

		if success:
			applied_count += 1
			order.append(qubit)
			results.append({"success": true, "qubit": qubit, "gate": gate_name})
		else:
			failed_count += 1
			results.append({"success": false, "error": "apply_failed", "qubit": qubit, "gate": gate_name})

	# One MI refresh per touched biome, after all gates applied
	if applied_count > 0:
		for touched_biome in touched:
			_refresh_mi(touched_biome)

	return {
		"success": applied_count > 0,
		"applied_count": applied_count,
		"failed_count": failed_count,
		"results": results,
		"order": order,
		"batch_injected": true
	}


static func inject_named_gate_batch(biome, qubits: Array, gate_name: String, farm = null) -> Dictionary:
	# Apply the same named gate to multiple qubits in order.

	# Convenience wrapper for inject_gate_batch when applying same gate to multiple qubits.

	# Args:
	# biome: Biome containing the quantum computer
	# qubits: Array of qubit indices in application order
	# gate_name: Gate name (H, X, Y, Z, Rx, Ry, Rz, etc.)
	# farm: Farm reference for batcher access

	# Returns:
	# Same as inject_gate_batch
	var gate_ops: Array = []
	for qubit in qubits:
		gate_ops.append({
			"biome": biome,
			"qubit": qubit,
			"gate_name": gate_name
		})

	return inject_gate_batch(gate_ops, farm)


static func inject_gate(biome, qubit: int, gate_matrix, _farm = null) -> Dictionary:
	# Apply a 1-qubit gate.

	# Args:
	# biome: Biome containing the quantum computer
	# qubit: Target qubit index
	# gate_matrix: 2x2 ComplexMatrix unitary
	# _farm: unused (kept for callers)

	# Returns:
	# Dictionary with success/error
	if not biome or not biome.quantum_computer:
		return {"success": false, "error": "no_quantum_computer"}

	if biome.quantum_computer.density_matrix == null:
		return {"success": false, "error": "no_density_matrix"}

	# Apply gate to density matrix
	var success = biome.quantum_computer.apply_gate(qubit, gate_matrix)

	if success:
		_refresh_mi(biome)

	return {
		"success": success,
		"qubit": qubit,
		"gate_injected": true
	}


static func inject_gate_2q(biome, qubit_a: int, qubit_b: int, gate_matrix, _farm = null) -> Dictionary:
	# Apply a 2-qubit gate.

	# Args:
	# biome: Biome containing the quantum computer
	# qubit_a: First qubit (control for CNOT)
	# qubit_b: Second qubit (target for CNOT)
	# gate_matrix: 4x4 ComplexMatrix unitary
	# _farm: unused (kept for callers)

	# Returns:
	# Dictionary with success/error
	if not biome or not biome.quantum_computer:
		return {"success": false, "error": "no_quantum_computer"}

	if biome.quantum_computer.density_matrix == null:
		return {"success": false, "error": "no_density_matrix"}

	# Apply 2-qubit gate to density matrix
	var success = biome.quantum_computer.apply_gate_2q(qubit_a, qubit_b, gate_matrix)

	if success:
		_refresh_mi(biome)

	return {
		"success": success,
		"qubit_a": qubit_a,
		"qubit_b": qubit_b,
		"gate_injected": true
	}


static func inject_named_gate(biome, qubit: int, gate_name: String, farm = null) -> Dictionary:
	# Apply a named gate from the library.

	# Args:
	# biome: Biome containing the quantum computer
	# qubit: Target qubit index
	# gate_name: Gate name (H, X, Y, Z, S, T, Rx, Ry, Rz, etc.)
	# farm: Farm reference for batcher access

	# Returns:
	# Dictionary with success/error
	var gate_lib = QuantumGateLibrary.new()
	if not gate_lib.GATES.has(gate_name):
		return {"success": false, "error": "unknown_gate", "gate": gate_name}

	var gate_matrix = gate_lib.GATES[gate_name]["matrix"]
	if not gate_matrix:
		return {"success": false, "error": "no_matrix", "gate": gate_name}

	var result = inject_gate(biome, qubit, gate_matrix, farm)
	result["gate"] = gate_name
	return result


static func inject_named_gate_2q(biome, qubit_a: int, qubit_b: int, gate_name: String, farm = null) -> Dictionary:
	# Apply a named 2-qubit gate from the library.

	# Args:
	# biome: Biome containing the quantum computer
	# qubit_a: First qubit
	# qubit_b: Second qubit
	# gate_name: Gate name (CNOT, CZ, SWAP, etc.)
	# farm: Farm reference for batcher access

	# Returns:
	# Dictionary with success/error
	var gate_lib = QuantumGateLibrary.new()
	if not gate_lib.GATES.has(gate_name):
		return {"success": false, "error": "unknown_gate", "gate": gate_name}

	var gate_matrix = gate_lib.GATES[gate_name]["matrix"]
	if not gate_matrix:
		return {"success": false, "error": "no_matrix", "gate": gate_name}

	var result = inject_gate_2q(biome, qubit_a, qubit_b, gate_matrix, farm)
	result["gate"] = gate_name
	return result


## braid_order: score the live ρ's mutual information now. A frozen or
## restarted lookahead would otherwise leave a just-built Bell scoring 0 until
## the next packet brings MI.
static func _refresh_mi(biome) -> void:
	if biome != null and biome.get("quantum_computer") != null 			and biome.quantum_computer.has_method("refresh_cached_mi"):
		biome.quantum_computer.refresh_cached_mi()
