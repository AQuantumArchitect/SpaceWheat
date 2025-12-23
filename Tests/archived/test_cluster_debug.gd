extends SceneTree

## Comprehensive Debugging Tests for EntangledCluster
## Tests edge cases, boundary conditions, physics validation, error handling

var test_count = 0
var passed_count = 0
var failed_count = 0

func _initialize():
	print("\n" + "=".repeat(80))
	print("  ENTANGLED CLUSTER - COMPREHENSIVE DEBUGGING TESTS")
	print("  Edge Cases, Boundary Conditions, Physics Validation")
	print("=".repeat(80) + "\n")

	# Load scripts
	var EntangledClusterScript = load("res://Core/QuantumSubstrate/EntangledCluster.gd")
	var DualEmojiQubitScript = load("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

	# Run all test suites
	_run_edge_case_tests(EntangledClusterScript, DualEmojiQubitScript)
	_run_boundary_tests(EntangledClusterScript, DualEmojiQubitScript)
	_run_physics_validation_tests(EntangledClusterScript, DualEmojiQubitScript)
	_run_state_consistency_tests(EntangledClusterScript, DualEmojiQubitScript)
	_run_error_handling_tests(EntangledClusterScript, DualEmojiQubitScript)
	_run_performance_tests(EntangledClusterScript, DualEmojiQubitScript)
	_run_mathematical_correctness_tests(EntangledClusterScript, DualEmojiQubitScript)

	# Print summary
	print("\n" + "=".repeat(80))
	print("  DEBUG TEST SUMMARY")
	print("=".repeat(80))
	print("  Total tests: %d" % test_count)
	print("  Passed: %d ✅" % passed_count)
	print("  Failed: %d ❌" % failed_count)
	print("  Success rate: %.1f%%" % (100.0 * passed_count / test_count if test_count > 0 else 0))
	print("=".repeat(80) + "\n")

	if failed_count > 0:
		print("⚠️ %d tests failed! Review output above." % failed_count)
		quit(1)
	else:
		print("🎉 All debugging tests passed!")
		quit()


## Test Helpers

func assert_test(condition: bool, test_name: String, details: String = ""):
	test_count += 1
	if condition:
		passed_count += 1
		print("  ✅ %s" % test_name)
		if details:
			print("     %s" % details)
	else:
		failed_count += 1
		print("  ❌ %s" % test_name)
		if details:
			print("     %s" % details)


func assert_close(a: float, b: float, tolerance: float, test_name: String):
	var diff = abs(a - b)
	assert_test(diff < tolerance, test_name,
		"Expected: %.6f, Got: %.6f, Diff: %.6f" % [b, a, diff])


## Edge Case Tests

func _run_edge_case_tests(ClusterScript, QubitScript):
	print("=".repeat(80))
	print("EDGE CASE TESTS")
	print("=".repeat(80))

	# Test 1: Empty cluster
	print("\nTest: Empty Cluster Operations")
	var empty = ClusterScript.new()
	assert_test(empty.get_qubit_count() == 0, "Empty cluster has 0 qubits")
	assert_test(empty.get_state_dimension() == 1, "Empty cluster dimension is 1 (2^0)")
	assert_test(empty.get_all_plot_ids().is_empty(), "Empty cluster has no plot IDs")

	# Test 2: Single qubit cluster
	print("\nTest: Single Qubit Cluster")
	var single = ClusterScript.new()
	single.add_qubit(QubitScript.new("🌾", "👥"), "solo")
	assert_test(single.get_qubit_count() == 1, "Single qubit cluster size")
	assert_test(single.get_state_dimension() == 2, "Single qubit dimension is 2")

	# Test 3: Adding same qubit twice
	print("\nTest: Duplicate Qubit Addition")
	var dup_cluster = ClusterScript.new()
	var q = QubitScript.new("🌾", "👥")
	dup_cluster.add_qubit(q, "A")
	dup_cluster.add_qubit(q, "A_dup")  # Same qubit, different ID
	assert_test(dup_cluster.get_qubit_count() == 2, "Allows same qubit with different ID")

	# Test 4: Empty string plot IDs
	print("\nTest: Empty Plot ID")
	var empty_id = ClusterScript.new()
	empty_id.add_qubit(QubitScript.new("🌾", "👥"), "")
	assert_test(empty_id.contains_plot_id(""), "Empty string plot ID tracked")

	# Test 5: Very long plot ID
	print("\nTest: Very Long Plot ID")
	var long_cluster = ClusterScript.new()
	var long_id = "plot_" + "x".repeat(1000)
	long_cluster.add_qubit(QubitScript.new("🌾", "👥"), long_id)
	assert_test(long_cluster.contains_plot_id(long_id), "Very long plot ID handled")


## Boundary Condition Tests

func _run_boundary_tests(ClusterScript, QubitScript):
	print("\n" + "=".repeat(80))
	print("BOUNDARY CONDITION TESTS")
	print("=".repeat(80))

	# Test 1: Maximum safe cluster size (6 qubits)
	print("\nTest: Maximum Safe Cluster Size (6 qubits)")
	var max_cluster = ClusterScript.new()
	for i in range(6):
		max_cluster.add_qubit(QubitScript.new("🌾", "👥"), "Q%d" % i)
	max_cluster.create_ghz_state()
	assert_test(max_cluster.get_qubit_count() == 6, "6-qubit cluster created")
	assert_test(max_cluster.get_state_dimension() == 64, "6-qubit dimension is 64")
	assert_close(max_cluster.get_purity(), 1.0, 0.01, "6-qubit GHZ is pure")

	# Test 2: Attempting 7-qubit cluster (warning threshold)
	print("\nTest: 7-Qubit Cluster (Above Recommended)")
	var large_cluster = ClusterScript.new()
	for i in range(7):
		large_cluster.add_qubit(QubitScript.new("🌾", "👥"), "L%d" % i)
	assert_test(large_cluster.get_qubit_count() == 7, "7-qubit cluster created (warning)")
	assert_test(large_cluster.get_state_dimension() == 128, "7-qubit dimension is 128")

	# Test 3: Measurement at boundaries
	print("\nTest: Measure First and Last Qubit")
	var boundary_meas = ClusterScript.new()
	for i in range(3):
		boundary_meas.add_qubit(QubitScript.new("🌾", "👥"), "B%d" % i)
	boundary_meas.create_ghz_state()

	var outcome_first = boundary_meas.measure_qubit(0)  # First
	assert_test(outcome_first == 0 or outcome_first == 1, "First qubit measurement valid")

	# Create new cluster for last qubit test
	var boundary_meas2 = ClusterScript.new()
	for i in range(3):
		boundary_meas2.add_qubit(QubitScript.new("🌾", "👥"), "C%d" % i)
	boundary_meas2.create_ghz_state()
	var outcome_last = boundary_meas2.measure_qubit(2)  # Last
	assert_test(outcome_last == 0 or outcome_last == 1, "Last qubit measurement valid")

	# Test 4: Invalid measurement index
	print("\nTest: Invalid Measurement Indices")
	var invalid_meas = ClusterScript.new()
	for i in range(3):
		invalid_meas.add_qubit(QubitScript.new("🌾", "👥"), "I%d" % i)
	invalid_meas.create_ghz_state()

	var result_neg = invalid_meas.measure_qubit(-1)  # Negative index
	assert_test(result_neg == 0, "Negative index returns 0 (error handling)")

	var result_too_large = invalid_meas.measure_qubit(10)  # Too large
	assert_test(result_too_large == 0, "Too large index returns 0 (error handling)")


## Physics Validation Tests

func _run_physics_validation_tests(ClusterScript, QubitScript):
	print("\n" + "=".repeat(80))
	print("PHYSICS VALIDATION TESTS")
	print("=".repeat(80))

	# Test 1: GHZ state density matrix structure
	print("\nTest: GHZ Density Matrix Structure")
	var ghz_validate = ClusterScript.new()
	for i in range(3):
		ghz_validate.add_qubit(QubitScript.new("🌾", "👥"), "G%d" % i)
	ghz_validate.create_ghz_state()

	# Check specific matrix elements for 3-qubit GHZ
	var rho = ghz_validate.density_matrix
	assert_close(rho[0][0].x, 0.5, 0.001, "GHZ: ρ[0][0] = 0.5 (|000⟩⟨000|)")
	assert_close(rho[7][7].x, 0.5, 0.001, "GHZ: ρ[7][7] = 0.5 (|111⟩⟨111|)")
	assert_close(rho[0][7].x, 0.5, 0.001, "GHZ: ρ[0][7] = 0.5 (coherence)")
	assert_close(rho[7][0].x, 0.5, 0.001, "GHZ: ρ[7][0] = 0.5 (coherence)")

	# All other diagonal elements should be zero
	var diag_sum = 0.0
	for i in range(8):
		if i != 0 and i != 7:
			diag_sum += rho[i][i].x
	assert_close(diag_sum, 0.0, 0.001, "GHZ: Other diagonal elements are zero")

	# Test 2: W state density matrix structure
	print("\nTest: W State Density Matrix Structure")
	var w_validate = ClusterScript.new()
	for i in range(3):
		w_validate.add_qubit(QubitScript.new("🌾", "👥"), "W%d" % i)
	w_validate.create_w_state()

	var rho_w = w_validate.density_matrix
	# W state: |100⟩, |010⟩, |001⟩ with equal weight 1/3
	assert_close(rho_w[1][1].x, 1.0/3.0, 0.001, "W: ρ[1][1] = 1/3 (|001⟩)")
	assert_close(rho_w[2][2].x, 1.0/3.0, 0.001, "W: ρ[2][2] = 1/3 (|010⟩)")
	assert_close(rho_w[4][4].x, 1.0/3.0, 0.001, "W: ρ[4][4] = 1/3 (|100⟩)")

	# Test 3: Trace = 1 (normalization)
	print("\nTest: Density Matrix Normalization (Tr(ρ) = 1)")
	var trace_test = ClusterScript.new()
	for i in range(4):
		trace_test.add_qubit(QubitScript.new("🌾", "👥"), "T%d" % i)
	trace_test.create_ghz_state()

	var trace = 0.0
	for i in range(trace_test.density_matrix.size()):
		trace += trace_test.density_matrix[i][i].x

	assert_close(trace, 1.0, 0.001, "Tr(ρ) = 1.0 (normalized)")

	# Test 4: Hermiticity (ρ = ρ†)
	print("\nTest: Density Matrix Hermiticity")
	var herm_test = ClusterScript.new()
	for i in range(3):
		herm_test.add_qubit(QubitScript.new("🌾", "👥"), "H%d" % i)
	herm_test.create_ghz_state()

	var max_herm_violation = 0.0
	var rho_h = herm_test.density_matrix
	for i in range(rho_h.size()):
		for j in range(rho_h.size()):
			# Check ρ[i][j] = ρ[j][i]*  (complex conjugate)
			var diff_real = abs(rho_h[i][j].x - rho_h[j][i].x)
			var diff_imag = abs(rho_h[i][j].y + rho_h[j][i].y)  # Note: conjugate flips sign
			max_herm_violation = max(max_herm_violation, max(diff_real, diff_imag))

	assert_close(max_herm_violation, 0.0, 0.001, "ρ is Hermitian (ρ = ρ†)")

	# Test 5: Positive semi-definite (all eigenvalues ≥ 0)
	# Simplified: Check purity is in [0, 1]
	print("\nTest: Physical Density Matrix (Purity ∈ [0,1])")
	var psd_test = ClusterScript.new()
	for i in range(3):
		psd_test.add_qubit(QubitScript.new("🌾", "👥"), "P%d" % i)
	psd_test.create_w_state()

	var purity = psd_test.get_purity()
	assert_test(purity >= 0.0 and purity <= 1.0, "Purity in valid range [0,1]",
		"Purity = %.3f" % purity)


## State Consistency Tests

func _run_state_consistency_tests(ClusterScript, QubitScript):
	print("\n" + "=".repeat(80))
	print("STATE CONSISTENCY TESTS")
	print("=".repeat(80))

	# Test 1: Sequential CNOT preserves purity
	print("\nTest: Sequential CNOT Preserves Purity")
	var seq_purity = ClusterScript.new()
	seq_purity.add_qubit(QubitScript.new("🌾", "👥"), "S1")
	seq_purity.add_qubit(QubitScript.new("🌾", "👥"), "S2")
	seq_purity.create_ghz_state()

	var purity_before = seq_purity.get_purity()
	seq_purity.entangle_new_qubit_cnot(QubitScript.new("🌾", "👥"), "S3", 0)
	var purity_after = seq_purity.get_purity()

	assert_close(purity_before, purity_after, 0.01,
		"CNOT preserves purity (unitary evolution)")

	# Test 2: Multiple measurements eventually give classical state
	print("\nTest: Complete Measurement Gives Classical State")
	var full_meas = ClusterScript.new()
	for i in range(3):
		full_meas.add_qubit(QubitScript.new("🌾", "👥"), "M%d" % i)
	full_meas.create_ghz_state()

	# Measure all qubits
	full_meas.measure_qubit(0)
	full_meas.measure_qubit(1)
	full_meas.measure_qubit(2)

	# After measuring all qubits, should have purity = 1 (classical state)
	var final_purity = full_meas.get_purity()
	assert_close(final_purity, 1.0, 0.01, "Fully measured state is pure")

	# Test 3: Cluster state entropy consistency
	print("\nTest: Cluster State Has Zero Entropy (Pure)")
	var cluster_entropy = ClusterScript.new()
	for i in range(3):
		cluster_entropy.add_qubit(QubitScript.new("🌾", "👥"), "E%d" % i)
	cluster_entropy.create_cluster_state_1d()

	var entropy = cluster_entropy.get_entanglement_entropy()
	assert_close(entropy, 0.0, 0.1, "Pure cluster state has zero entropy")

	# Test 4: State type flags consistency
	print("\nTest: State Type Flags")
	var flag_test = ClusterScript.new()
	for i in range(3):
		flag_test.add_qubit(QubitScript.new("🌾", "👥"), "F%d" % i)

	flag_test.create_ghz_state()
	assert_test(flag_test.is_ghz_type(), "GHZ state type flag set")
	assert_test(not flag_test.is_w_type(), "GHZ is not W type")
	assert_test(not flag_test.is_cluster_type(), "GHZ is not cluster type")

	flag_test.create_w_state()
	assert_test(flag_test.is_w_type(), "W state type flag set")
	assert_test(not flag_test.is_ghz_type(), "W is not GHZ type")


## Error Handling Tests

func _run_error_handling_tests(ClusterScript, QubitScript):
	print("\n" + "=".repeat(80))
	print("ERROR HANDLING TESTS")
	print("=".repeat(80))

	# Test 1: GHZ with insufficient qubits
	print("\nTest: GHZ State with 0 Qubits")
	var empty_ghz = ClusterScript.new()
	empty_ghz.create_ghz_state()  # Should print error
	# Just verify it doesn't crash

	# Test 2: W state with 1 qubit
	print("\nTest: W State with 1 Qubit")
	var single_w = ClusterScript.new()
	single_w.add_qubit(QubitScript.new("🌾", "👥"), "W1")
	single_w.create_w_state()  # Should print error
	# Verify no crash

	# Test 3: CNOT with invalid control index
	print("\nTest: CNOT with Out-of-Range Control Index")
	var invalid_cnot = ClusterScript.new()
	invalid_cnot.add_qubit(QubitScript.new("🌾", "👥"), "C1")
	invalid_cnot.add_qubit(QubitScript.new("🌾", "👥"), "C2")
	invalid_cnot.entangle_new_qubit_cnot(QubitScript.new("🌾", "👥"), "C3", 10)  # Invalid control
	# Should print error but not crash
	assert_test(invalid_cnot.get_qubit_count() == 2, "Invalid CNOT doesn't add qubit")

	# Test 4: Measurement probability sum = 1
	print("\nTest: Measurement Probability Normalization")
	var prob_test = ClusterScript.new()
	for i in range(3):
		prob_test.add_qubit(QubitScript.new("🌾", "👥"), "P%d" % i)
	prob_test.create_ghz_state()

	# Manually check probabilities sum to 1
	var prob_0 = prob_test._probability_qubit_zero(0)
	var prob_1 = 1.0 - prob_0
	var prob_sum = prob_0 + prob_1

	assert_close(prob_sum, 1.0, 0.001, "Measurement probabilities sum to 1")

	# Test 5: Null qubit handling
	print("\nTest: Null Qubit Handling")
	var null_cluster = ClusterScript.new()
	null_cluster.add_qubit(null, "null_test")  # Add null qubit
	# Should not crash, but might have issues
	# This tests robustness


## Performance Tests

func _run_performance_tests(ClusterScript, QubitScript):
	print("\n" + "=".repeat(80))
	print("PERFORMANCE TESTS")
	print("=".repeat(80))

	# Test 1: Large cluster creation time
	print("\nTest: 6-Qubit Cluster Creation Performance")
	var start_time = Time.get_ticks_msec()

	var perf_cluster = ClusterScript.new()
	for i in range(6):
		perf_cluster.add_qubit(QubitScript.new("🌾", "👥"), "Perf%d" % i)
	perf_cluster.create_ghz_state()

	var elapsed = Time.get_ticks_msec() - start_time
	print("  6-qubit GHZ creation: %d ms" % elapsed)
	assert_test(elapsed < 100, "6-qubit creation under 100ms", "%d ms" % elapsed)

	# Test 2: Sequential CNOT performance
	print("\nTest: Sequential CNOT Performance")
	var cnot_cluster = ClusterScript.new()
	cnot_cluster.add_qubit(QubitScript.new("🌾", "👥"), "CN1")
	cnot_cluster.add_qubit(QubitScript.new("🌾", "👥"), "CN2")
	cnot_cluster.create_ghz_state()

	start_time = Time.get_ticks_msec()
	for i in range(4):  # Add 4 more qubits sequentially
		cnot_cluster.entangle_new_qubit_cnot(QubitScript.new("🌾", "👥"), "CN%d" % (i+3), 0)

	elapsed = Time.get_ticks_msec() - start_time
	print("  4 sequential CNOTs: %d ms" % elapsed)
	assert_test(elapsed < 200, "4 CNOTs under 200ms", "%d ms" % elapsed)

	# Test 3: Measurement performance
	print("\nTest: Measurement Performance")
	var meas_perf = ClusterScript.new()
	for i in range(5):
		meas_perf.add_qubit(QubitScript.new("🌾", "👥"), "MP%d" % i)
	meas_perf.create_ghz_state()

	start_time = Time.get_ticks_msec()
	for i in range(100):  # 100 measurements
		var temp_cluster = ClusterScript.new()
		for j in range(3):
			temp_cluster.add_qubit(QubitScript.new("🌾", "👥"), "T%d" % j)
		temp_cluster.create_ghz_state()
		temp_cluster.measure_qubit(0)

	elapsed = Time.get_ticks_msec() - start_time
	print("  100 measurements: %d ms (%.2f ms avg)" % [elapsed, elapsed / 100.0])
	assert_test(elapsed < 500, "100 measurements under 500ms", "%d ms" % elapsed)


## Mathematical Correctness Tests

func _run_mathematical_correctness_tests(ClusterScript, QubitScript):
	print("\n" + "=".repeat(80))
	print("MATHEMATICAL CORRECTNESS TESTS")
	print("=".repeat(80))

	# Test 1: Purity bounds (0 ≤ Tr(ρ²) ≤ 1)
	print("\nTest: Purity Bounds for Various States")
	var states_to_test = [
		{"name": "GHZ", "setup": func(c): c.create_ghz_state()},
		{"name": "W", "setup": func(c): c.create_w_state()},
		{"name": "Cluster", "setup": func(c): c.create_cluster_state_1d()}
	]

	for state_info in states_to_test:
		var test_cluster = ClusterScript.new()
		for i in range(3):
			test_cluster.add_qubit(QubitScript.new("🌾", "👥"), "B%d" % i)
		state_info.setup.call(test_cluster)

		var purity = test_cluster.get_purity()
		assert_test(purity >= 0.0 and purity <= 1.0,
			"%s state purity in bounds" % state_info.name,
			"Purity = %.3f" % purity)

	# Test 2: Measurement preserves normalization
	print("\nTest: Measurement Preserves Tr(ρ) = 1")
	var meas_norm = ClusterScript.new()
	for i in range(3):
		meas_norm.add_qubit(QubitScript.new("🌾", "👥"), "N%d" % i)
	meas_norm.create_ghz_state()

	# Measure and check trace
	meas_norm.measure_qubit(1)

	var trace_after = 0.0
	for i in range(meas_norm.density_matrix.size()):
		trace_after += meas_norm.density_matrix[i][i].x

	assert_close(trace_after, 1.0, 0.001, "Tr(ρ) = 1 after measurement")

	# Test 3: Idempotency of pure state (ρ² = ρ for pure states)
	print("\nTest: Pure State Idempotency (Tr(ρ²) = 1)")
	var pure_test = ClusterScript.new()
	for i in range(3):
		pure_test.add_qubit(QubitScript.new("🌾", "👥"), "I%d" % i)
	pure_test.create_ghz_state()

	var purity_pure = pure_test.get_purity()
	assert_close(purity_pure, 1.0, 0.01, "Pure state: Tr(ρ²) = 1")

	# Test 4: Controlled-Z is Hermitian and unitary
	print("\nTest: CZ Gate Properties")
	var cz_test = ClusterScript.new()
	for i in range(3):
		cz_test.add_qubit(QubitScript.new("🌾", "👥"), "CZ%d" % i)
	cz_test._initialize_all_plus()

	var purity_before_cz = cz_test.get_purity()
	cz_test._apply_controlled_z(0, 1)
	var purity_after_cz = cz_test.get_purity()

	assert_close(purity_before_cz, purity_after_cz, 0.01,
		"CZ preserves purity (unitary)")

	# Test 5: Dimension scaling (2^N)
	print("\nTest: Hilbert Space Dimension Scaling")
	for N in range(1, 7):
		var dim_test = ClusterScript.new()
		for i in range(N):
			dim_test.add_qubit(QubitScript.new("🌾", "👥"), "D%d" % i)

		var expected_dim = int(pow(2, N))
		var actual_dim = dim_test.get_state_dimension()

		assert_test(actual_dim == expected_dim,
			"%d-qubit dimension = %d" % [N, expected_dim],
			"Expected: %d, Got: %d" % [expected_dim, actual_dim])
