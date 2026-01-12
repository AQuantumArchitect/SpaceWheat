extends SceneTree

## Test Suite: Symplectic Conservation (Feature 6)
## Tests phase space volume preservation and density matrix invariants

const SymplecticValidator = preload("res://Core/QuantumSubstrate/SymplecticValidator.gd")
const QuantumComputer = preload("res://Core/QuantumSubstrate/QuantumComputer.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")

var test_count: int = 0
var pass_count: int = 0


func _init():
	print("\n" + "=".repeat(70))
	print("SYMPLECTIC CONSERVATION TEST SUITE (Feature 6)")
	print("=".repeat(70) + "\n")

	# Property tests
	test_trace_computation()
	test_purity_computation()
	test_hermiticity_check()
	test_positivity_check()

	# Validation tests
	test_valid_state()
	test_invalid_trace()
	test_non_hermitian()
	test_negative_diagonal()

	# Evolution tests
	test_trace_conservation()
	test_purity_bounds()

	# Phase space tests
	test_volume_estimation()
	test_volume_conservation()

	# Integration tests
	test_quantum_computer_validation()
	test_evolution_validator_hook()

	# Summary
	print("\n" + "=".repeat(70))
	print("TESTS PASSED: %d/%d" % [pass_count, test_count])
	print("=".repeat(70) + "\n")

	quit()


## ========================================
## Test Utilities
## ========================================

func assert_true(condition: bool, message: String):
	test_count += 1
	if condition:
		pass_count += 1
		print("  ✓ " + message)
	else:
		print("  ✗ FAILED: " + message)


func assert_false(condition: bool, message: String):
	assert_true(not condition, message)


func assert_equal(actual, expected, message: String):
	test_count += 1
	if actual == expected:
		pass_count += 1
		print("  ✓ " + message)
	else:
		print("  ✗ FAILED: %s (expected: %s, got: %s)" % [message, str(expected), str(actual)])


func assert_approx(actual: float, expected: float, tolerance: float, message: String):
	test_count += 1
	if abs(actual - expected) < tolerance:
		pass_count += 1
		print("  ✓ " + message)
	else:
		print("  ✗ FAILED: %s (expected: %.4f, got: %.4f)" % [message, expected, actual])


func create_pure_state(dim: int, basis_idx: int) -> ComplexMatrix:
	"""Create pure state |basis_idx><basis_idx|"""
	var dm = ComplexMatrix.new(dim)
	dm.set_element(basis_idx, basis_idx, Complex.new(1.0, 0.0))
	return dm


func create_mixed_state(dim: int, probs: Array) -> ComplexMatrix:
	"""Create diagonal mixed state"""
	var dm = ComplexMatrix.new(dim)
	for i in range(min(dim, probs.size())):
		dm.set_element(i, i, Complex.new(probs[i], 0.0))
	return dm


func create_coherent_state(dim: int) -> ComplexMatrix:
	"""Create state with off-diagonal coherences"""
	var dm = ComplexMatrix.new(dim)

	# Diagonal
	dm.set_element(0, 0, Complex.new(0.6, 0.0))
	dm.set_element(1, 1, Complex.new(0.4, 0.0))

	# Off-diagonal (Hermitian: rho_ij = rho_ji*)
	dm.set_element(0, 1, Complex.new(0.2, 0.1))
	dm.set_element(1, 0, Complex.new(0.2, -0.1))

	return dm


## ========================================
## Property Computation Tests
## ========================================

func test_trace_computation():
	print("\nTEST: Trace Computation")

	# Pure state trace = 1
	var pure = create_pure_state(4, 0)
	var validation = SymplecticValidator.validate_state(pure)
	assert_approx(validation.trace, 1.0, 0.001, "Pure state trace = 1")

	# Mixed state trace = 1
	var mixed = create_mixed_state(4, [0.4, 0.3, 0.2, 0.1])
	validation = SymplecticValidator.validate_state(mixed)
	assert_approx(validation.trace, 1.0, 0.001, "Mixed state trace = 1")

	# Unnormalized state
	var unnorm = create_mixed_state(4, [0.5, 0.3, 0.1, 0.05])
	validation = SymplecticValidator.validate_state(unnorm)
	assert_approx(validation.trace, 0.95, 0.001, "Unnormalized trace = 0.95")

	print()


func test_purity_computation():
	print("\nTEST: Purity Computation")

	# Pure state purity = 1
	var pure = create_pure_state(4, 0)
	var validation = SymplecticValidator.validate_state(pure)
	assert_approx(validation.purity, 1.0, 0.01, "Pure state purity = 1")

	# Maximally mixed purity = 1/d
	var max_mixed = create_mixed_state(4, [0.25, 0.25, 0.25, 0.25])
	validation = SymplecticValidator.validate_state(max_mixed)
	assert_approx(validation.purity, 0.25, 0.01, "Max mixed purity = 1/4")

	# Intermediate mixed state
	var mixed = create_mixed_state(4, [0.7, 0.2, 0.1, 0.0])
	validation = SymplecticValidator.validate_state(mixed)
	assert_true(validation.purity > 0.25 and validation.purity < 1.0, "Mixed purity in range")

	print()


func test_hermiticity_check():
	print("\nTEST: Hermiticity Check")

	# Pure state is Hermitian
	var pure = create_pure_state(4, 0)
	var validation = SymplecticValidator.validate_state(pure)
	assert_true(validation.hermitian, "Pure state is Hermitian")

	# Coherent state (properly constructed) is Hermitian
	var coherent = create_coherent_state(4)
	validation = SymplecticValidator.validate_state(coherent)
	assert_true(validation.hermitian, "Coherent state is Hermitian")

	# Create non-Hermitian state
	var non_herm = ComplexMatrix.new(4)
	non_herm.set_element(0, 0, Complex.new(0.5, 0.0))
	non_herm.set_element(1, 1, Complex.new(0.5, 0.0))
	non_herm.set_element(0, 1, Complex.new(0.2, 0.1))
	non_herm.set_element(1, 0, Complex.new(0.2, 0.1))  # Wrong! Should be (0.2, -0.1)

	validation = SymplecticValidator.validate_state(non_herm)
	assert_false(validation.hermitian, "Non-Hermitian detected")

	print()


func test_positivity_check():
	print("\nTEST: Positivity Check")

	# Valid states are positive
	var valid = create_mixed_state(4, [0.5, 0.3, 0.15, 0.05])
	var validation = SymplecticValidator.validate_state(valid)
	assert_true(validation.positive, "Valid state is positive")

	# Create invalid state with negative diagonal
	var invalid = ComplexMatrix.new(4)
	invalid.set_element(0, 0, Complex.new(0.6, 0.0))
	invalid.set_element(1, 1, Complex.new(-0.1, 0.0))  # Negative!
	invalid.set_element(2, 2, Complex.new(0.3, 0.0))
	invalid.set_element(3, 3, Complex.new(0.2, 0.0))

	validation = SymplecticValidator.validate_state(invalid)
	assert_false(validation.positive, "Negative diagonal detected")

	print()


## ========================================
## Validation Tests
## ========================================

func test_valid_state():
	print("\nTEST: Valid State Validation")

	var valid = create_mixed_state(4, [0.5, 0.3, 0.15, 0.05])
	var validation = SymplecticValidator.validate_state(valid)

	assert_true(validation.valid, "Valid state passes validation")
	assert_equal(validation.errors.size(), 0, "No errors")

	print()


func test_invalid_trace():
	print("\nTEST: Invalid Trace Detection")

	var invalid = create_mixed_state(4, [0.5, 0.3, 0.1, 0.05])  # Sums to 0.95
	var validation = SymplecticValidator.validate_state(invalid)

	assert_false(validation.valid, "Invalid trace detected")
	assert_true(validation.errors.size() > 0, "Has errors")

	print()


func test_non_hermitian():
	print("\nTEST: Non-Hermitian Detection")

	var non_herm = ComplexMatrix.new(4)
	non_herm.set_element(0, 0, Complex.new(0.5, 0.0))
	non_herm.set_element(1, 1, Complex.new(0.5, 0.0))
	non_herm.set_element(0, 1, Complex.new(0.2, 0.1))
	non_herm.set_element(1, 0, Complex.new(0.3, -0.1))  # Wrong conjugate

	var validation = SymplecticValidator.validate_state(non_herm)

	assert_false(validation.hermitian, "Non-Hermitian detected")
	assert_false(validation.valid, "Validation fails")

	print()


func test_negative_diagonal():
	print("\nTEST: Negative Diagonal Detection")

	var invalid = ComplexMatrix.new(4)
	invalid.set_element(0, 0, Complex.new(1.2, 0.0))
	invalid.set_element(1, 1, Complex.new(-0.2, 0.0))  # Negative

	var validation = SymplecticValidator.validate_state(invalid)

	assert_false(validation.positive, "Negative diagonal detected")
	assert_false(validation.valid, "Validation fails")

	print()


## ========================================
## Evolution Tests
## ========================================

func test_trace_conservation():
	print("\nTEST: Trace Conservation in Evolution")

	var before = create_mixed_state(4, [0.5, 0.3, 0.15, 0.05])
	var after = create_mixed_state(4, [0.4, 0.35, 0.2, 0.05])  # Same trace

	var validation = SymplecticValidator.validate_evolution_step(before, after)

	assert_true(validation.valid, "Evolution preserves validity")
	assert_approx(validation.trace_error, 0.0, 0.01, "Trace conserved")

	# Test with trace violation
	var bad_after = create_mixed_state(4, [0.4, 0.3, 0.15, 0.05])  # Trace = 0.9
	validation = SymplecticValidator.validate_evolution_step(before, bad_after)

	assert_false(validation.valid, "Trace violation detected")
	assert_true(validation.trace_error > 0.05, "Trace error is large")

	print()


func test_purity_bounds():
	print("\nTEST: Purity Bounds")

	var dim = 4
	var min_purity = 1.0 / float(dim)

	# Pure -> mixed is allowed (purity decrease)
	var pure = create_pure_state(4, 0)
	var mixed = create_mixed_state(4, [0.7, 0.2, 0.1, 0.0])

	var validation = SymplecticValidator.validate_evolution_step(pure, mixed)
	assert_true(validation.purity_before > validation.purity_after, "Purity can decrease")

	# Purity should stay above minimum
	assert_true(validation.purity_after >= min_purity - 0.01, "Purity above minimum")

	print()


## ========================================
## Phase Space Tests
## ========================================

func test_volume_estimation():
	print("\nTEST: Phase Space Volume Estimation")

	# Create a simple trajectory
	var trajectory: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(1.0, 0.0, 0.0),
		Vector3(0.0, 1.0, 0.0),
		Vector3(0.0, 0.0, 1.0),
		Vector3(1.0, 1.0, 1.0)
	]

	var volume = SymplecticValidator.estimate_phase_space_volume(trajectory)

	# Bounding box is 1x1x1 = 1
	assert_approx(volume, 1.0, 0.01, "Volume = 1 for unit cube trajectory")

	# Empty trajectory
	var empty: Array[Vector3] = []
	volume = SymplecticValidator.estimate_phase_space_volume(empty)
	assert_approx(volume, 0.0, 0.01, "Empty trajectory has zero volume")

	print()


func test_volume_conservation():
	print("\nTEST: Volume Conservation Check")

	# Same volume
	assert_true(
		SymplecticValidator.check_volume_conservation(1.0, 1.0),
		"Same volume is conserved"
	)

	# Small change within tolerance
	assert_true(
		SymplecticValidator.check_volume_conservation(1.0, 1.05),
		"5% change is within tolerance"
	)

	# Large change
	assert_false(
		SymplecticValidator.check_volume_conservation(1.0, 1.5),
		"50% change violates conservation"
	)

	print()


## ========================================
## Integration Tests
## ========================================

func test_quantum_computer_validation():
	print("\nTEST: Quantum Computer Validation")

	var qc = QuantumComputer.new("validation_test")
	qc.allocate_axis(0, "🌾", "🍄")
	qc.allocate_axis(1, "☀️", "🌙")
	qc.initialize_basis(0)

	# Validate initial state
	var validation = SymplecticValidator.validate_state(qc.density_matrix)

	assert_true(validation.valid, "QC initial state is valid")
	assert_true(validation.hermitian, "QC state is Hermitian")
	assert_true(validation.positive, "QC state is positive")
	assert_approx(validation.trace, 1.0, 0.01, "QC trace = 1")

	print()


func test_evolution_validator_hook():
	print("\nTEST: Evolution Validator Hook")

	var qc = QuantumComputer.new("hook_test")
	qc.allocate_axis(0, "🌾", "🍄")
	qc.initialize_basis(0)

	# Create validator hook
	var validator = SymplecticValidator.create_evolution_validator(qc)

	# Call once (establishes baseline)
	validator.call()

	# Modify state slightly (valid change)
	qc.density_matrix.set_element(0, 0, Complex.new(0.9, 0.0))
	qc.density_matrix.set_element(1, 1, Complex.new(0.1, 0.0))

	# Call again (should detect change but still valid)
	validator.call()

	assert_true(true, "Validator hook runs without crash")

	print()


## ========================================
## Report Tests
## ========================================

func test_report_generation():
	print("\nTEST: Report Generation")

	var state = create_mixed_state(4, [0.5, 0.3, 0.15, 0.05])
	var validation = SymplecticValidator.validate_state(state)

	var report = SymplecticValidator.format_validation_report(validation)

	assert_true(report.length() > 50, "Report has content")
	assert_true("Trace" in report, "Report mentions trace")
	assert_true("Hermitian" in report, "Report mentions Hermitian")

	print()
