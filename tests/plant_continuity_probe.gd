extends "res://tests/smoke_test_base.gd"

## Pin E1: PLANTING PRESERVES STATE (owner ruling, fable push 2026-08-04).
##
## expand_quantum_system used to end with initialize_ground_state(), wiping
## the whole biome's cultivated superposition on every plant — even though
## allocate_axis had ALREADY tensor-extended ρ → ρ ⊗ |0⟩⟨0| correctly (the
## reset discarded it), and the removal path already preserved state via
## partial trace. This smoke drives the REAL builder path and asserts:
##   1. every existing qubit's marginal is continuous through the plant
##      (partial trace of ρ ⊗ |0⟩⟨0| over the new qubit is exactly ρ);
##   2. purity stays 1 (pure ⊗ pure = pure — the closed-system invariant);
##   3. a tracked Berry walk survives un-cut (no reseed, no spurious
##      triangle: the Bloch path is continuous, unlike a collapse);
##   4. the NEW qubit is dawn-kicked off the exact pole (an exact |0⟩ never
##      precesses — it would be un-trackable, un-ripenable).
##
## Run: godot --headless --path . --script tests/plant_continuity_probe.gd

const QC := preload("res://Core/QuantumSubstrate/QuantumComputer.gd")
const Builder := preload("res://Core/Environment/Components/BiomeQuantumSystemBuilder.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== Plant-continuity smoke (E1: planting preserves state) ===")

	# Real axes with rabi + couplings (Hearth, Factory) so the state is
	# genuinely cultivated: superposition + off-diagonals, not a basis state.
	var qc = QC.new()
	qc.biome_name = "ProbeGarden"
	qc.allocate_axis(0, "🔥", "❄")
	qc.allocate_axis(1, "⚙", "🏭")
	var builder = Builder.new()
	builder.quantum_computer = qc
	builder.rebuild_operators_from_register_map()
	# Cultivate: pure state, tilted well off the poles on both qubits.
	qc.density_matrix.set_element(0, 0, Complex.one())
	qc.apply_ry(0, 0.9)
	qc.apply_ry(1, 0.6)

	var p0_before: float = qc.get_marginal(0, 0)
	var p1_before: float = qc.get_marginal(1, 0)
	var purity_before: float = qc.get_purity()
	_check(absf(purity_before - 1.0) < 1e-9, "cultivated state is pure")
	_check(p0_before < 0.999 and p0_before > 0.001, "qubit 0 is genuinely tilted")

	# Track qubit 0 and seed its walk from the live Bloch packet.
	qc.berry_register.start_tracking(0)
	var pk: PackedFloat64Array = qc.export_bloch_packet()
	var nq: int = qc.register_map.num_qubits
	qc.berry_register.integrate_step(pk, nq)
	qc.berry_register.integrate_step(qc.export_bloch_packet(), nq)
	var phase_before: float = qc.berry_register.get_phase(0)

	# --- THE PLANT (the real builder path the Icon-R verb drives) ------------
	var result: Dictionary = builder.expand_quantum_system("💧", "🌊")
	_check(bool(result.get("success", false)), "plant succeeded", str(result))
	_check(int(result.get("qubit_index", -1)) == 2, "new qubit appended at index 2")

	# 1. Continuity: existing marginals bit-preserved through the plant.
	_check(absf(qc.get_marginal(0, 0) - p0_before) < 1e-9,
			"qubit 0 marginal continuous through the plant",
			"%f → %f" % [p0_before, qc.get_marginal(0, 0)])
	_check(absf(qc.get_marginal(1, 0) - p1_before) < 1e-9,
			"qubit 1 marginal continuous through the plant")

	# 2. Purity invariant.
	_check(absf(qc.get_purity() - 1.0) < 1e-9, "purity stays 1 (pure ⊗ pure)",
			"got %f" % qc.get_purity())

	# 3. The Berry walk survives: still tracked, and one more slice on the
	# GROWN packet adds no spurious triangle (the Bloch path is continuous).
	_check(qc.berry_register.is_tracked(0), "berry walk still tracked (no reseed)")
	qc.berry_register.integrate_step(qc.export_bloch_packet(), qc.register_map.num_qubits)
	_check(absf(qc.berry_register.get_phase(0) - phase_before) < 1e-6,
			"no spurious solid angle across the plant",
			"%f → %f" % [phase_before, qc.berry_register.get_phase(0)])

	# 4. The new qubit is kicked off the exact pole.
	var p_new: float = qc.get_marginal(2, 0)
	_check(p_new < 1.0 - 1e-6 and p_new > 0.5,
			"new qubit dawn-kicked off |0⟩ (not pole-stationary, not scrambled)",
			"p(new=0) = %f" % p_new)

	_finish("plant continuity smoke")
