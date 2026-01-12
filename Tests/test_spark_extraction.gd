extends SceneTree

## Test Suite: Spark Extraction (Feature 3)
## Tests the SparkConverter and energy split mechanics

const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const QuantumComputer = preload("res://Core/QuantumSubstrate/QuantumComputer.gd")
const SparkConverter = preload("res://Core/QuantumSubstrate/SparkConverter.gd")
const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")

var test_count: int = 0
var pass_count: int = 0


func _init():
	print("\n" + "=".repeat(70))
	print("SPARK EXTRACTION TEST SUITE (Feature 3)")
	print("=".repeat(70) + "\n")

	# Core tests
	test_energy_split_pure_state()
	test_energy_split_mixed_state()
	test_energy_split_coherent_state()

	# SparkConverter tests
	test_spark_extraction_basic()
	test_spark_extraction_insufficient_coherence()
	test_spark_extraction_invalid_target()
	test_energy_status_reporting()

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


func assert_approx(actual: float, expected: float, tolerance: float, message: String):
	test_count += 1
	if abs(actual - expected) < tolerance:
		pass_count += 1
		print("  ✓ " + message)
	else:
		print("  ✗ FAILED: %s (expected: %.4f, got: %.4f)" % [message, expected, actual])


## ========================================
## Energy Split Tests
## ========================================

func test_energy_split_pure_state():
	print("\nTEST: Energy Split - Pure State |0⟩")

	# Create pure state |0⟩⟨0|
	var rho = ComplexMatrix.new(2)
	rho.set_element(0, 0, Complex.one())  # |0⟩⟨0|

	var energy = rho.compute_energy_split()

	assert_approx(energy.real, 1.0, 0.001, "Real energy should be 1.0 (full population)")
	assert_approx(energy.imaginary, 0.0, 0.001, "Imaginary energy should be 0.0 (no coherence)")
	assert_approx(energy.total, 1.0, 0.001, "Total energy should be 1.0")
	assert_approx(energy.coherence_ratio, 0.0, 0.001, "Coherence ratio should be 0.0")
	print()


func test_energy_split_mixed_state():
	print("\nTEST: Energy Split - Maximally Mixed State")

	# Create maximally mixed state ρ = I/2
	var rho = ComplexMatrix.new(2)
	rho.set_element(0, 0, Complex.new(0.5, 0.0))
	rho.set_element(1, 1, Complex.new(0.5, 0.0))

	var energy = rho.compute_energy_split()

	assert_approx(energy.real, 1.0, 0.001, "Real energy should be 1.0 (trace)")
	assert_approx(energy.imaginary, 0.0, 0.001, "Imaginary energy should be 0.0 (no coherence)")
	assert_approx(energy.coherence_ratio, 0.0, 0.001, "Coherence ratio should be 0.0")
	print()


func test_energy_split_coherent_state():
	print("\nTEST: Energy Split - Coherent Superposition |+⟩")

	# Create superposition |+⟩⟨+| = (|0⟩ + |1⟩)(⟨0| + ⟨1|)/2
	# ρ = [[0.5, 0.5], [0.5, 0.5]]
	var rho = ComplexMatrix.new(2)
	rho.set_element(0, 0, Complex.new(0.5, 0.0))
	rho.set_element(0, 1, Complex.new(0.5, 0.0))  # Coherence
	rho.set_element(1, 0, Complex.new(0.5, 0.0))  # Coherence
	rho.set_element(1, 1, Complex.new(0.5, 0.0))

	var energy = rho.compute_energy_split()

	assert_approx(energy.real, 1.0, 0.001, "Real energy should be 1.0")
	assert_approx(energy.imaginary, 1.0, 0.001, "Imaginary energy should be 1.0 (max coherence)")
	assert_approx(energy.total, 2.0, 0.001, "Total should be 2.0")
	assert_approx(energy.coherence_ratio, 0.5, 0.001, "Coherence ratio should be 0.5")

	print("    Energy split: real=%.2f, imaginary=%.2f, ratio=%.2f" % [
		energy.real, energy.imaginary, energy.coherence_ratio
	])
	print()


## ========================================
## SparkConverter Tests
## ========================================

func test_spark_extraction_basic():
	print("\nTEST: Spark Extraction - Basic")

	# Create a quantum computer with some coherence
	var qc = QuantumComputer.new("test")
	qc.allocate_axis(0, "🌾", "🍄")
	qc.allocate_axis(1, "☀", "🌙")

	# Initialize to superposition (has coherence)
	# We'll manually create a state with coherence
	var dim = qc.density_matrix.n
	var initial_pop = 1.0 / dim

	# Set diagonal (populations)
	for i in range(dim):
		qc.density_matrix.set_element(i, i, Complex.new(initial_pop, 0.0))

	# Add some coherence (off-diagonal)
	qc.density_matrix.set_element(0, 1, Complex.new(0.2, 0.1))
	qc.density_matrix.set_element(1, 0, Complex.new(0.2, -0.1))  # Hermitian conjugate

	# Check initial energy
	var before_energy = qc.density_matrix.compute_energy_split()
	print("    Before: real=%.3f, imaginary=%.3f" % [before_energy.real, before_energy.imaginary])

	var before_population = qc.get_population("🌾")

	# Extract spark
	var result = SparkConverter.extract_spark(qc, "🌾", 0.5)

	assert_true(result.success, "Extraction should succeed")
	assert_true(result.extracted_amount > 0.0, "Should extract some energy")
	assert_true(result.coherence_lost > 0.0, "Should lose some coherence")

	# Check population increased
	var after_population = qc.get_population("🌾")
	assert_true(after_population >= before_population, "Target population should increase or stay same")

	# Check coherence decreased
	var after_energy = qc.density_matrix.compute_energy_split()
	assert_true(after_energy.imaginary < before_energy.imaginary, "Imaginary energy should decrease")

	print("    After: real=%.3f, imaginary=%.3f" % [after_energy.real, after_energy.imaginary])
	print("    Extracted: %.3f, Coherence lost: %.3f" % [result.extracted_amount, result.coherence_lost])
	print()


func test_spark_extraction_insufficient_coherence():
	print("\nTEST: Spark Extraction - Insufficient Coherence")

	# Create a quantum computer with NO coherence (pure diagonal)
	var qc = QuantumComputer.new("test")
	qc.allocate_axis(0, "🌾", "🍄")
	qc.initialize_basis(0)  # Pure |0⟩ state - no coherence

	# Try to extract
	var result = SparkConverter.extract_spark(qc, "🌾", 0.5)

	assert_false(result.success, "Extraction should fail with no coherence")
	print("    Message: %s" % result.message)
	print()


func test_spark_extraction_invalid_target():
	print("\nTEST: Spark Extraction - Invalid Target Emoji")

	# Create a quantum computer
	var qc = QuantumComputer.new("test")
	qc.allocate_axis(0, "🌾", "🍄")
	qc.initialize_basis(0)

	# Try to extract with invalid emoji
	var result = SparkConverter.extract_spark(qc, "🔥", 0.5)

	assert_false(result.success, "Extraction should fail with invalid target")
	print("    Message: %s" % result.message)
	print()


func test_energy_status_reporting():
	print("\nTEST: Energy Status Reporting")

	# Create quantum computer with varying coherence
	var qc = QuantumComputer.new("test")
	qc.allocate_axis(0, "🌾", "🍄")
	qc.allocate_axis(1, "☀", "🌙")
	qc.initialize_basis(0)

	# Test low coherence state
	var status = SparkConverter.get_energy_status(qc)
	assert_true(status.regime == "mostly_classical", "Should be mostly_classical with no coherence")
	print("    Pure state regime: %s" % status.regime)

	# Add coherence
	qc.density_matrix.set_element(0, 3, Complex.new(0.4, 0.0))
	qc.density_matrix.set_element(3, 0, Complex.new(0.4, 0.0))

	status = SparkConverter.get_energy_status(qc)
	print("    With coherence regime: %s (ratio=%.2f)" % [status.regime, status.coherence_ratio])
	assert_true(status.extractable > 0.0, "Should have extractable energy")
	print()
