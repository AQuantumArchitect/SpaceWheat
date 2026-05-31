#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Serializer regression for ρ + register_map round-tripping.
##
## The save path stores both density_matrix and register_axes. The restore
## path must rebuild RegisterMap first, then apply ρ, so evolve does not see
## a 16x16 matrix stranded on a zero-qubit register map.



func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var serializer := GameStateSerializer.new()

	var source_qc := QuantumComputer.new("RoundTripSource")
	source_qc.allocate_axis(0, "🔥", "❄️")
	source_qc.allocate_axis(1, "💧", "🏜️")
	source_qc.initialize_basis(0)
	var source_rho = source_qc.density_matrix
	if source_rho == null:
		printerr("source density_matrix missing")
		quit(2)
		return
	source_rho.set_element(0, 1, Complex.new(0.123, 0.456))
	source_rho.set_element(1, 0, Complex.new(0.123, -0.456))

	var state := {
		"register_axes": [
			{"qubit": 0, "north": "🔥", "south": "❄️"},
			{"qubit": 1, "north": "💧", "south": "🏜️"},
		],
		"register_infrastructure": {
			"0": {"theta_frozen": true, "lindblad_pump_active": true},
			"1": {"theta_frozen": false, "lindblad_drain_active": true},
		},
		"density_matrix": serializer._encode_complex_matrix(source_rho),
	}

	var target_biome := BiomeBase.new()
	target_biome.viz_cache = QuantumVizCache.new()
	target_biome.quantum_computer = QuantumComputer.new("RoundTripTarget")
	target_biome.quantum_computer.register_map.clear()

	await serializer._restore_single_biome_state(target_biome, state, "RoundTripTarget")

	var qc: QuantumComputer = target_biome.quantum_computer
	if qc == null:
		printerr("target qc missing after restore")
		quit(3)
		return
	if qc.register_map == null or qc.register_map.num_qubits != 2:
		printerr("register_map was not restored: %d qubits" % (qc.register_map.num_qubits if qc.register_map else -1))
		quit(4)
		return
	if qc.density_matrix == null or int(qc.density_matrix.n) != 4:
		printerr("density_matrix was not restored to 4x4")
		quit(5)
		return
	if target_biome.viz_cache == null:
		printerr("viz_cache missing after restore")
		quit(7)
		return
	if target_biome.viz_cache.get_num_qubits() != 2:
		printerr("viz_cache metadata was not restored: num_qubits=%d" % target_biome.viz_cache.get_num_qubits())
		quit(8)
		return

	var max_err := 0.0
	for i in range(4):
		for j in range(4):
			var expected = source_rho.get_element(i, j)
			var got = qc.density_matrix.get_element(i, j)
			max_err = max(max_err, max(abs(got.re - expected.re), abs(got.im - expected.im)))
	if max_err > 1e-9:
		printerr("density_matrix mismatch after restore: max_err=%s" % str(max_err))
		quit(6)
		return

	print("density/register round-trip ok (max_err=%s)" % str(max_err))
	quit(0)
