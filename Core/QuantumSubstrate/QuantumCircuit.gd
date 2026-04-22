extends RefCounted

## Declarative quantum circuit builder for SpaceWheat.
##
## Compose gate sequences, then execute them on a QuantumComputer.
## Designed for testing, headless simulation, and the 🍄 quantum composer.
##
## Usage:
##   var circuit = QuantumCircuit.new()
##   circuit.h(0).cnot(0, 1).measure(0)
##   var result = circuit.run_on(quantum_computer)

const QuantumGateLibrary = preload("res://Core/QuantumSubstrate/QuantumGateLibrary.gd")

## Internal instruction list: [{op, args}]
var _instructions: Array = []

## Labels for named checkpoints
var _labels: Dictionary = {}  # label_name → instruction_index


# =============================================================================
# SINGLE-QUBIT GATES (return self for chaining)
# =============================================================================

func h(qubit: int) :
	_instructions.append({"op": "gate_1q", "gate": "H", "qubit": qubit})
	return self

func x(qubit: int) :
	_instructions.append({"op": "gate_1q", "gate": "X", "qubit": qubit})
	return self

func y(qubit: int) :
	_instructions.append({"op": "gate_1q", "gate": "Y", "qubit": qubit})
	return self

func z(qubit: int) :
	_instructions.append({"op": "gate_1q", "gate": "Z", "qubit": qubit})
	return self

func s(qubit: int) :
	_instructions.append({"op": "gate_1q", "gate": "S", "qubit": qubit})
	return self

func sdg(qubit: int) :
	_instructions.append({"op": "gate_1q", "gate": "Sdg", "qubit": qubit})
	return self

func t(qubit: int) :
	_instructions.append({"op": "gate_1q", "gate": "T", "qubit": qubit})
	return self

func tdg(qubit: int) :
	_instructions.append({"op": "gate_1q", "gate": "Tdg", "qubit": qubit})
	return self

func rx(qubit: int, theta: float = PI / 4.0) :
	_instructions.append({"op": "gate_1q_param", "gate": "Rx", "qubit": qubit, "theta": theta})
	return self

func ry(qubit: int, theta: float = PI / 4.0) :
	_instructions.append({"op": "gate_1q_param", "gate": "Ry", "qubit": qubit, "theta": theta})
	return self

func rz(qubit: int, theta: float = PI / 4.0) :
	_instructions.append({"op": "gate_1q_param", "gate": "Rz", "qubit": qubit, "theta": theta})
	return self


# =============================================================================
# TWO-QUBIT GATES
# =============================================================================

func cnot(control: int, target: int) :
	_instructions.append({"op": "gate_2q", "gate": "CNOT", "qubit_a": control, "qubit_b": target})
	return self

func cz(qubit_a: int, qubit_b: int) :
	_instructions.append({"op": "gate_2q", "gate": "CZ", "qubit_a": qubit_a, "qubit_b": qubit_b})
	return self

func swap(qubit_a: int, qubit_b: int) :
	_instructions.append({"op": "gate_2q", "gate": "SWAP", "qubit_a": qubit_a, "qubit_b": qubit_b})
	return self


# =============================================================================
# STATE PREPARATION
# =============================================================================

func bell(qubit_a: int, qubit_b: int) :
	"""H on qubit_a then CNOT(a,b) → Bell Φ+."""
	return h(qubit_a).cnot(qubit_a, qubit_b)

func ghz(qubits: Array[int]) :
	"""Create GHZ state: H on first, CNOT chain down the rest."""
	if qubits.size() < 2:
		return self
	h(qubits[0])
	for i in range(1, qubits.size()):
		cnot(qubits[i - 1], qubits[i])
	return self


# =============================================================================
# MEASUREMENT
# =============================================================================

func measure(qubit: int, outcome: int = -1) :
	"""Add measurement instruction. outcome=-1 means sample from Born rule."""
	_instructions.append({"op": "measure", "qubit": qubit, "outcome": outcome})
	return self

func measure_all() :
	"""Measure all qubits (determined at execution time)."""
	_instructions.append({"op": "measure_all"})
	return self

func project(qubit: int, outcome: int) :
	"""Post-select: project onto specific outcome (no sampling)."""
	_instructions.append({"op": "project", "qubit": qubit, "outcome": outcome})
	return self


# =============================================================================
# EVOLUTION
# =============================================================================

func evolve(dt: float) :
	"""Hamiltonian/Lindblad evolution for dt seconds."""
	_instructions.append({"op": "evolve", "dt": dt})
	return self


# =============================================================================
# CHECKPOINTS & OBSERVABLES
# =============================================================================

func snapshot(label: String) :
	"""Record a named checkpoint. Observables at this point are saved in results."""
	_instructions.append({"op": "snapshot", "label": label})
	return self

func barrier() :
	"""No-op barrier (for visual circuit layout)."""
	_instructions.append({"op": "barrier"})
	return self


# =============================================================================
# EXECUTION
# =============================================================================

func run_on(qc) -> Dictionary:
	"""Execute this circuit on a QuantumComputer. Returns result dictionary.

	Result format:
	{
	    "measurements": [{qubit, outcome}],
	    "snapshots": {label: {purity, populations, basis_probs, marginal_purities}},
	    "final": {purity, populations, basis_probs, marginal_purities},
	    "gate_count": int,
	    "error": "" or error message
	}
	"""
	var result = {
		"measurements": [],
		"snapshots": {},
		"final": {},
		"gate_count": 0,
		"error": ""
	}

	for instr in _instructions:
		var op = instr.get("op", "")

		match op:
			"gate_1q":
				var gate_def = QuantumGateLibrary.get_gate(instr.gate)
				if gate_def.matrix == null:
					result.error = "Unknown gate: %s" % instr.gate
					return result
				if not qc.apply_gate(instr.qubit, gate_def.matrix):
					result.error = "Failed to apply %s on qubit %d" % [instr.gate, instr.qubit]
					return result
				result.gate_count += 1

			"gate_1q_param":
				var matrix = null
				match instr.gate:
					"Rx": matrix = QuantumGateLibrary._rx_gate(instr.theta)
					"Ry": matrix = QuantumGateLibrary._ry_gate(instr.theta)
					"Rz": matrix = QuantumGateLibrary._rz_gate(instr.theta)
				if matrix == null:
					result.error = "Unknown parameterized gate: %s" % instr.gate
					return result
				if not qc.apply_gate(instr.qubit, matrix):
					result.error = "Failed to apply %s on qubit %d" % [instr.gate, instr.qubit]
					return result
				result.gate_count += 1

			"gate_2q":
				var gate_def = QuantumGateLibrary.get_gate(instr.gate)
				if gate_def.matrix == null:
					result.error = "Unknown gate: %s" % instr.gate
					return result
				if not qc.apply_gate_2q(instr.qubit_a, instr.qubit_b, gate_def.matrix):
					result.error = "Failed to apply %s on qubits %d,%d" % [instr.gate, instr.qubit_a, instr.qubit_b]
					return result
				result.gate_count += 1

			"measure":
				var qubit = instr.qubit
				var outcome = instr.outcome
				if outcome < 0:
					# Sample from Born rule
					var p0 = qc.get_marginal(qubit, 0)
					outcome = 0 if randf() < p0 else 1
				qc.project_qubit(qubit, outcome)
				result.measurements.append({"qubit": qubit, "outcome": outcome})

			"measure_all":
				var num_q = qc.register_map.num_qubits
				for qi in range(num_q):
					var p0 = qc.get_marginal(qi, 0)
					var outcome = 0 if randf() < p0 else 1
					qc.project_qubit(qi, outcome)
					result.measurements.append({"qubit": qi, "outcome": outcome})

			"project":
				qc.project_qubit(instr.qubit, instr.outcome)
				result.measurements.append({"qubit": instr.qubit, "outcome": instr.outcome})

			"evolve":
				qc.evolve(instr.dt)

			"snapshot":
				result.snapshots[instr.label] = _extract_observables(qc)

			"barrier":
				pass

	result.final = _extract_observables(qc)
	return result


func _extract_observables(qc) -> Dictionary:
	"""Extract current observables from a QuantumComputer."""
	var obs = {
		"purity": qc.get_purity(),
		"populations": qc.get_all_populations(),
		"marginal_purities": {},
	}

	var num_q = qc.register_map.num_qubits
	for qi in range(num_q):
		obs.marginal_purities[qi] = qc.get_marginal_purity(null, qi)

	# Basis probabilities (skip if too many qubits)
	var dim = qc.register_map.dim()
	if dim <= 64:
		obs["basis_probs"] = {}
		for i in range(dim):
			var p = qc.get_basis_probability(i)
			if p > 1e-10:
				obs.basis_probs[i] = p

	return obs


# =============================================================================
# UTILITIES
# =============================================================================

func depth() -> int:
	"""Number of instructions in this circuit."""
	return _instructions.size()

func clear() :
	"""Remove all instructions."""
	_instructions.clear()
	_labels.clear()
	return self

func duplicate_circuit() :
	"""Create a copy of this circuit."""
	var c = get_script().new()
	c._instructions = _instructions.duplicate(true)
	c._labels = _labels.duplicate(true)
	return c

func to_string_repr() -> String:
	"""Human-readable circuit description."""
	var lines: PackedStringArray = []
	for instr in _instructions:
		match instr.op:
			"gate_1q":
				lines.append("%s q%d" % [instr.gate, instr.qubit])
			"gate_1q_param":
				lines.append("%s(%.4f) q%d" % [instr.gate, instr.theta, instr.qubit])
			"gate_2q":
				lines.append("%s q%d,q%d" % [instr.gate, instr.qubit_a, instr.qubit_b])
			"measure":
				if instr.outcome < 0:
					lines.append("MEASURE q%d" % instr.qubit)
				else:
					lines.append("MEASURE q%d→%d" % [instr.qubit, instr.outcome])
			"measure_all":
				lines.append("MEASURE_ALL")
			"project":
				lines.append("PROJECT q%d→%d" % [instr.qubit, instr.outcome])
			"evolve":
				lines.append("EVOLVE %.4fs" % instr.dt)
			"snapshot":
				lines.append("SNAPSHOT '%s'" % instr.label)
			"barrier":
				lines.append("---")
	return "\n".join(lines)
