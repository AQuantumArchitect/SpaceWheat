class_name ChipContext
extends RefCounted

## Lightweight context object passed to chip resolvers. Built once per
## UIContextController refresh by reading current state; resolvers project
## from it without pulling state themselves.

var quantum_computer = null   # QuantumComputer for the active biome (may be null)
var qubit_index: int = -1     # plot_idx ≡ register_id (per Plot-Register Invariant)
var register_bound: bool = false  # focused plot has a bound terminal (explored)


func _init(qc = null, qid: int = -1, bound: bool = false) -> void:
	quantum_computer = qc
	qubit_index = qid
	register_bound = bound


func has_focused_qubit() -> bool:
	if quantum_computer == null or qubit_index < 0:
		return false
	if quantum_computer.register_map == null:
		return false
	return qubit_index < quantum_computer.register_map.num_qubits


func get_berry_register():
	if quantum_computer == null:
		return null
	return quantum_computer.berry_register
