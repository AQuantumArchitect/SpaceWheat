extends SceneTree

## rho_write_epoch_check.gd — every way to write ρ stamps QuantumComputer.state_epoch.
##
## The lookahead batcher drops a forecast when the epoch moves past the one its
## frames came from, so a write that forgot to stamp would be overwritten by the
## next buffered frame (the 2026-11-10 strike bug, in general form). One line per
## writer:
##
##   EPOCH <writer> ok|MISSING
##
##   godot --headless --script tests/rho_write_epoch_check.gd
##
## tests/test_lookahead_follows_writes.py runs it. No boot: a bare QuantumComputer.

func _init() -> void:
	var qc := QuantumComputer.new("epoch_check")
	qc.allocate_axis(0, "A", "a")
	qc.allocate_axis(1, "B", "b")
	qc.initialize_basis(0)
	var h = QuantumGateLibrary.get_gate("H")["matrix"]
	var cnot = QuantumGateLibrary.get_gate("CNOT")["matrix"]
	var writers := [
		["assign density_matrix", func(): qc.density_matrix = qc.density_matrix.duplicate()],
		["apply_gate", func(): qc.apply_gate(0, h)],
		["apply_gate_2q", func(): qc.apply_gate_2q(0, 1, cnot)],
		["apply_dephase", func(): qc.apply_dephase(0, 1.0, 0.1)],
		["apply_drive", func(): qc.apply_drive("A", 1.0, 0.1)],
		["apply_decay", func(): qc.apply_decay(1, 1.0, 0.1)],
		["apply_jump_channel", func(): qc.apply_jump_channel(0, 0, 1, 1, 1.0, 0.1)],
		["drain_qubit", func(): qc.drain_qubit(0, 0, 0.3)],
		["project_qubit", func(): qc.project_qubit(1, 1)],
		["load_packed_state", func(): qc.load_packed_state(qc.density_matrix._to_packed().duplicate(), 4, true)],
		["load_packed_state (renormalize)", func(): qc.load_packed_state(qc.density_matrix._to_packed().duplicate(), 4, false)],
		["initialize_basis", func(): qc.initialize_basis(2)],
		["initialize_uniform_superposition", func(): qc.initialize_uniform_superposition()],
		["allocate_axis (resize)", func(): qc.allocate_axis(2, "C", "c")],
		["mark_state_written", func(): qc.mark_state_written()],
	]
	for w in writers:
		var before: int = qc.state_epoch
		w[1].call()
		print("EPOCH %s %s" % [w[0], "ok" if qc.state_epoch > before else "MISSING"])
	quit(0)
