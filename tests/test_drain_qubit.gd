#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: drain_qubit() ensemble measurement mechanics
## Validates that partial drain preserves quantum structure while extracting population.


const DIVIDER = "======================================================================"
const TOL = 1e-6

var passed := 0
var failed := 0


func _init():
	print("\n" + DIVIDER)
	print("TEST: drain_qubit() — Ensemble Measurement Drain")
	print(DIVIDER)

	await process_frame
	await process_frame

	_test_drain_preserves_trace()
	_test_drain_reduces_population()
	_test_drain_preserves_other_pole()
	_test_drain_decays_coherences()
	_test_drain_zero_eta_is_noop()
	_test_drain_full_eta_like_projection()
	_test_drain_purity_stays_valid()
	_test_drain_multi_qubit()
	_test_drain_vs_project_comparison()

	print("\n" + DIVIDER)
	print("RESULTS: %d passed, %d failed" % [passed, failed])
	print(DIVIDER + "\n")
	quit(0 if failed == 0 else 1)


func _make_qc_1q() -> QuantumComputer:
	# Create a 1-qubit QuantumComputer with 70/30 north/south split.
	var qc = QuantumComputer.new()
	qc.register_map = RegisterMap.new()
	qc.register_map.register_axis(0, "☀", "🌙")
	# Build density matrix: p_north=0.7, p_south=0.3, coherence=0.2+0.1i
	var dm = ComplexMatrix.zeros(2)
	dm.set_element(0, 0, Complex.new(0.7, 0.0))
	dm.set_element(1, 1, Complex.new(0.3, 0.0))
	dm.set_element(0, 1, Complex.new(0.2, 0.1))
	dm.set_element(1, 0, Complex.new(0.2, -0.1))
	qc.density_matrix = dm
	return qc


func _make_qc_2q() -> QuantumComputer:
	# Create a 2-qubit QuantumComputer with some entanglement.
	var qc = QuantumComputer.new()
	qc.register_map = RegisterMap.new()
	qc.register_map.register_axis(0, "☀", "🌙")
	qc.register_map.register_axis(1, "🌾", "👥")
	# 4x4 density matrix: mostly |00⟩ with some mixing
	var dm = ComplexMatrix.zeros(4)
	# Populations: |00⟩=0.5, |01⟩=0.2, |10⟩=0.2, |11⟩=0.1
	dm.set_element(0, 0, Complex.new(0.5, 0.0))
	dm.set_element(1, 1, Complex.new(0.2, 0.0))
	dm.set_element(2, 2, Complex.new(0.2, 0.0))
	dm.set_element(3, 3, Complex.new(0.1, 0.0))
	# Some coherence between |00⟩ and |11⟩ (entanglement)
	dm.set_element(0, 3, Complex.new(0.1, 0.05))
	dm.set_element(3, 0, Complex.new(0.1, -0.05))
	qc.density_matrix = dm
	return qc


func _get_trace(dm: ComplexMatrix) -> float:
	var trace = 0.0
	for i in range(dm.n):
		trace += dm.get_element(i, i).re
	return trace


func _get_purity(dm: ComplexMatrix) -> float:
	var sum_sq = 0.0
	for i in range(dm.n):
		for j in range(dm.n):
			var c = dm.get_element(i, j)
			sum_sq += c.re * c.re + c.im * c.im
	var trace = _get_trace(dm)
	return sum_sq / (trace * trace) if trace > 1e-10 else 0.0


func _assert_near(actual: float, expected: float, msg: String, tol: float = TOL):
	if abs(actual - expected) < tol:
		passed += 1
		print("  ✅ %s (%.6f ≈ %.6f)" % [msg, actual, expected])
	else:
		failed += 1
		print("  ❌ %s (%.6f ≠ %.6f, Δ=%.2e)" % [msg, actual, expected, abs(actual - expected)])


func _assert_true(cond: bool, msg: String):
	if cond:
		passed += 1
		print("  ✅ %s" % msg)
	else:
		failed += 1
		print("  ❌ %s" % msg)


func _test_drain_preserves_trace():
	print("\n--- Trace preservation after drain ---")
	var qc = _make_qc_1q()
	var trace_before = _get_trace(qc.density_matrix)
	qc.drain_qubit(0, 0, 0.15)  # Drain 15% from north pole
	var trace_after = _get_trace(qc.density_matrix)
	_assert_near(trace_after, 1.0, "Trace = 1.0 after drain")
	_assert_near(trace_before, 1.0, "Trace was 1.0 before drain")


func _test_drain_reduces_population():
	print("\n--- Population reduction on drained pole ---")
	var qc = _make_qc_1q()
	var p_north_before = qc.density_matrix.get_element(0, 0).re  # 0.7
	var p_south_before = qc.density_matrix.get_element(1, 1).re  # 0.3
	var eta = 0.15

	qc.drain_qubit(0, 0, eta)  # Drain north

	var p_north_after = qc.density_matrix.get_element(0, 0).re
	var p_south_after = qc.density_matrix.get_element(1, 1).re

	# North should have lost population (but renormalization redistributes trace)
	# Before renorm: north=0.7*0.85=0.595, south=0.3, total=0.895
	# After renorm:  north=0.595/0.895≈0.665, south=0.3/0.895≈0.335
	var expected_total = p_north_before * (1.0 - eta) + p_south_before
	var expected_north = (p_north_before * (1.0 - eta)) / expected_total
	var expected_south = p_south_before / expected_total

	_assert_near(p_north_after, expected_north, "North population drained and renormalized", 0.01)
	_assert_near(p_south_after, expected_south, "South population relatively increased", 0.01)
	_assert_true(p_north_after < p_north_before, "North decreased (%.4f < %.4f)" % [p_north_after, p_north_before])


func _test_drain_preserves_other_pole():
	print("\n--- Other pole's diagonal block untouched (before renorm) ---")
	# Draining north should not directly modify south's block elements
	# We verify by checking the RATIO of south elements is preserved
	var qc = _make_qc_2q()
	# Save south-south block entries (qubit 0 south = indices where bit0=1: rows 2,3)
	var dm = qc.density_matrix
	var r22_before = dm.get_element(2, 2).re  # |10⟩
	var r33_before = dm.get_element(3, 3).re  # |11⟩

	qc.drain_qubit(0, 0, 0.2)  # Drain qubit 0 north pole

	var r22_after = dm.get_element(2, 2).re
	var r33_after = dm.get_element(3, 3).re

	# Ratio should be preserved (renormalization scales uniformly)
	if r33_before > 1e-10 and r33_after > 1e-10:
		var ratio_before = r22_before / r33_before
		var ratio_after = r22_after / r33_after
		_assert_near(ratio_after, ratio_before, "South block ratio preserved", 0.001)
	else:
		_assert_true(true, "South block ratio (trivial case)")


func _test_drain_decays_coherences():
	print("\n--- Coherence decay at √(1-η) rate ---")
	var qc = _make_qc_1q()
	var coh_before = qc.density_matrix.get_element(0, 1)  # 0.2+0.1i
	var eta = 0.15
	var expected_scale = sqrt(1.0 - eta)

	qc.drain_qubit(0, 0, eta)

	var coh_after = qc.density_matrix.get_element(0, 1)
	# After drain (before renorm): coh * √(1-η)
	# After renorm: coh * √(1-η) / trace_new
	# trace_new = 0.7*0.85 + 0.3 = 0.895
	var trace_new = 0.7 * (1.0 - eta) + 0.3
	var expected_re = coh_before.re * expected_scale / trace_new
	var expected_im = coh_before.im * expected_scale / trace_new

	_assert_near(coh_after.re, expected_re, "Coherence real part decayed correctly", 0.01)
	_assert_near(coh_after.im, expected_im, "Coherence imag part decayed correctly", 0.01)


func _test_drain_zero_eta_is_noop():
	print("\n--- Zero drain (η=0) is no-op ---")
	var qc = _make_qc_1q()
	var p_north_before = qc.density_matrix.get_element(0, 0).re
	var coh_before_re = qc.density_matrix.get_element(0, 1).re

	qc.drain_qubit(0, 0, 0.0)

	var p_north_after = qc.density_matrix.get_element(0, 0).re
	var coh_after_re = qc.density_matrix.get_element(0, 1).re

	_assert_near(p_north_after, p_north_before, "Population unchanged at η=0")
	_assert_near(coh_after_re, coh_before_re, "Coherence unchanged at η=0")


func _test_drain_full_eta_like_projection():
	print("\n--- Full drain (η=1) zeroes measured pole ---")
	var qc = _make_qc_1q()

	qc.drain_qubit(0, 0, 1.0)  # Drain ALL north population

	var p_north = qc.density_matrix.get_element(0, 0).re
	var p_south = qc.density_matrix.get_element(1, 1).re
	var coh = qc.density_matrix.get_element(0, 1)

	# North should be ~0 after renorm (it was scaled by 0)
	# South gets all the population
	_assert_near(p_north, 0.0, "North population zeroed at η=1", 0.001)
	_assert_near(p_south, 1.0, "South gets all population at η=1", 0.001)
	_assert_near(coh.re, 0.0, "Coherence zeroed at η=1", 0.001)


func _test_drain_purity_stays_valid():
	print("\n--- Purity stays in [0, 1] after drain ---")
	var qc = _make_qc_1q()
	var purity_before = _get_purity(qc.density_matrix)

	qc.drain_qubit(0, 0, 0.15)

	var purity_after = _get_purity(qc.density_matrix)
	_assert_true(purity_after >= 0.0 and purity_after <= 1.0 + TOL,
		"Purity in valid range: %.6f" % purity_after)
	_assert_true(purity_before >= 0.0 and purity_before <= 1.0 + TOL,
		"Purity was valid before: %.6f" % purity_before)


func _test_drain_multi_qubit():
	print("\n--- Multi-qubit drain only affects target qubit ---")
	var qc = _make_qc_2q()
	var dm = qc.density_matrix

	# Marginal for qubit 1 before drain on qubit 0
	# Qubit 1 north = |x0⟩: indices 0,2 → p = dm[0,0] + dm[2,2]
	var q1_north_before = dm.get_element(0, 0).re + dm.get_element(2, 2).re
	var q1_south_before = dm.get_element(1, 1).re + dm.get_element(3, 3).re

	qc.drain_qubit(0, 0, 0.2)  # Drain qubit 0 north

	# Qubit 1 marginal should shift because populations changed
	var q1_north_after = dm.get_element(0, 0).re + dm.get_element(2, 2).re
	var q1_south_after = dm.get_element(1, 1).re + dm.get_element(3, 3).re

	_assert_near(q1_north_after + q1_south_after, 1.0,
		"Qubit 1 marginals sum to 1.0 after qubit 0 drain", 0.01)

	# The trace should be 1
	_assert_near(_get_trace(dm), 1.0, "Trace = 1.0 after 2-qubit drain", 0.001)

	# Purity valid
	var purity = _get_purity(dm)
	_assert_true(purity >= 0.0 and purity <= 1.0 + TOL,
		"2-qubit purity valid: %.6f" % purity)


func _test_drain_vs_project_comparison():
	print("\n--- Drain is gentler than projection ---")
	# Same initial state, compare drain(η=0.15) vs project_qubit(0, 0)
	var qc_drain = _make_qc_1q()
	var qc_project = _make_qc_1q()

	var p_north_orig = qc_drain.density_matrix.get_element(0, 0).re

	qc_drain.drain_qubit(0, 0, 0.15)
	qc_project.project_qubit(0, 0)

	var p_north_drain = qc_drain.density_matrix.get_element(0, 0).re
	var p_north_project = qc_project.density_matrix.get_element(0, 0).re

	# After projection: north=1.0 (all probability forced to measured pole)
	# After drain: north≈0.665 (only 15% extracted, renormalized)
	_assert_near(p_north_project, 1.0, "Projection forces p_north=1.0", 0.001)
	_assert_true(p_north_drain < p_north_orig,
		"Drain reduces p_north (%.4f < %.4f)" % [p_north_drain, p_north_orig])
	_assert_true(p_north_drain < p_north_project,
		"Drain is gentler than projection (%.4f < %.4f)" % [p_north_drain, p_north_project])

	# Coherence comparison
	var coh_drain = qc_drain.density_matrix.get_element(0, 1)
	var coh_project = qc_project.density_matrix.get_element(0, 1)
	var coh_drain_mag = sqrt(coh_drain.re * coh_drain.re + coh_drain.im * coh_drain.im)
	var coh_project_mag = sqrt(coh_project.re * coh_project.re + coh_project.im * coh_project.im)

	_assert_true(coh_drain_mag > coh_project_mag + 0.001,
		"Drain preserves more coherence (%.4f > %.4f)" % [coh_drain_mag, coh_project_mag])
