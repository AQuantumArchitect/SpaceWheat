extends SceneTree

## Test Suite: Semantic Uncertainty Principle (Feature 4)
## Tests precision/flexibility uncertainty relation

const SemanticUncertainty = preload("res://Core/QuantumSubstrate/SemanticUncertainty.gd")
const QuantumComputer = preload("res://Core/QuantumSubstrate/QuantumComputer.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")

var test_count: int = 0
var pass_count: int = 0


func _init():
	print("\n" + "=".repeat(70))
	print("SEMANTIC UNCERTAINTY PRINCIPLE TEST SUITE (Feature 4)")
	print("=".repeat(70) + "\n")

	# Core uncertainty tests
	test_pure_state_uncertainty()
	test_mixed_state_uncertainty()
	test_maximally_mixed_state()
	test_principle_satisfaction()

	# Regime classification tests
	test_regime_classification()
	test_regime_descriptions()
	test_regime_colors()

	# Gameplay modifier tests
	test_action_modifiers()

	# Integration tests
	test_quantum_computer_integration()
	test_real_biome_evolution()

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


func assert_range(value: float, min_val: float, max_val: float, message: String):
	test_count += 1
	if value >= min_val and value <= max_val:
		pass_count += 1
		print("  ✓ " + message)
	else:
		print("  ✗ FAILED: %s (value %.4f not in [%.4f, %.4f])" % [message, value, min_val, max_val])


## ========================================
## Pure State Tests
## ========================================

func test_pure_state_uncertainty():
	print("\nTEST: Pure State Uncertainty")

	# Create a pure state |0⟩ (only diagonal[0,0] = 1)
	var dm = ComplexMatrix.new(4)  # 2-qubit system
	dm.set_element(0, 0, Complex.new(1.0, 0.0))

	var uncertainty = SemanticUncertainty.compute_uncertainty(dm)

	# Pure state: precision = 1 (no entropy)
	assert_approx(uncertainty.precision, 1.0, 0.01, "Pure state has precision = 1")

	# Pure state: flexibility = 0 (no entropy)
	assert_approx(uncertainty.flexibility, 0.0, 0.01, "Pure state has flexibility = 0")

	# Product = 0 (less than threshold, but that's OK for pure states)
	assert_approx(uncertainty.product, 0.0, 0.01, "Pure state product = 0")

	# Purity should be 1
	assert_approx(uncertainty.purity, 1.0, 0.01, "Pure state purity = 1")

	print()


func test_mixed_state_uncertainty():
	print("\nTEST: Mixed State Uncertainty")

	# Create a partially mixed state: 0.7|0⟩ + 0.3|1⟩
	var dm = ComplexMatrix.new(4)
	dm.set_element(0, 0, Complex.new(0.7, 0.0))
	dm.set_element(1, 1, Complex.new(0.3, 0.0))

	var uncertainty = SemanticUncertainty.compute_uncertainty(dm)

	# Should have non-zero entropy
	assert_true(uncertainty.entropy > 0.0, "Mixed state has positive entropy")

	# Precision should be between 0 and 1
	assert_range(uncertainty.precision, 0.0, 1.0, "Precision in valid range")

	# Flexibility should be between 0 and 1
	assert_range(uncertainty.flexibility, 0.0, 1.0, "Flexibility in valid range")

	# precision + flexibility = 1 (by definition)
	assert_approx(
		uncertainty.precision + uncertainty.flexibility,
		1.0,
		0.01,
		"Precision + Flexibility = 1"
	)

	# Purity should be less than 1
	assert_true(uncertainty.purity < 1.0, "Mixed state purity < 1")

	print()


func test_maximally_mixed_state():
	print("\nTEST: Maximally Mixed State")

	# Create maximally mixed state: all diagonal = 1/4
	var dm = ComplexMatrix.new(4)
	dm.set_element(0, 0, Complex.new(0.25, 0.0))
	dm.set_element(1, 1, Complex.new(0.25, 0.0))
	dm.set_element(2, 2, Complex.new(0.25, 0.0))
	dm.set_element(3, 3, Complex.new(0.25, 0.0))

	var uncertainty = SemanticUncertainty.compute_uncertainty(dm)

	# Maximum entropy state: precision = 0, flexibility = 1
	assert_approx(uncertainty.precision, 0.0, 0.01, "Max mixed state has precision = 0")
	assert_approx(uncertainty.flexibility, 1.0, 0.01, "Max mixed state has flexibility = 1")

	# Product = 0 (edge case)
	assert_approx(uncertainty.product, 0.0, 0.01, "Max mixed product = 0")

	# Purity = 1/d = 0.25
	assert_approx(uncertainty.purity, 0.25, 0.01, "Max mixed purity = 1/d")

	print()


## ========================================
## Principle Tests
## ========================================

func test_principle_satisfaction():
	print("\nTEST: Uncertainty Principle Satisfaction")

	# Test various intermediate states
	var test_cases = [
		[0.5, 0.5, 0.0, 0.0],  # 50-50 superposition of |00⟩ and |01⟩
		[0.4, 0.3, 0.2, 0.1],  # Varied distribution
		[0.9, 0.05, 0.03, 0.02],  # Mostly localized
	]

	for i in range(test_cases.size()):
		var probs = test_cases[i]

		var dm = ComplexMatrix.new(4)
		dm.set_element(0, 0, Complex.new(probs[0], 0.0))
		dm.set_element(1, 1, Complex.new(probs[1], 0.0))
		dm.set_element(2, 2, Complex.new(probs[2], 0.0))
		dm.set_element(3, 3, Complex.new(probs[3], 0.0))

		var uncertainty = SemanticUncertainty.compute_uncertainty(dm)

		# The product should be >= 0 (theoretical minimum for diagonal states is 0)
		assert_true(
			uncertainty.product >= 0.0,
			"Test case %d: product >= 0" % i
		)

		# precision + flexibility = 1
		assert_approx(
			uncertainty.precision + uncertainty.flexibility,
			1.0,
			0.01,
			"Test case %d: precision + flexibility = 1" % i
		)

	print()


## ========================================
## Regime Tests
## ========================================

func test_regime_classification():
	print("\nTEST: Regime Classification")

	# Test different regime conditions
	# Crystallized: high precision + high purity
	var dm_crystal = ComplexMatrix.new(4)
	dm_crystal.set_element(0, 0, Complex.new(0.99, 0.0))
	dm_crystal.set_element(1, 1, Complex.new(0.01, 0.0))
	var u_crystal = SemanticUncertainty.compute_uncertainty(dm_crystal)
	assert_true(
		u_crystal.regime in ["crystallized", "stable"],
		"High precision -> crystallized or stable"
	)

	# Fluid: high flexibility
	var dm_fluid = ComplexMatrix.new(4)
	dm_fluid.set_element(0, 0, Complex.new(0.26, 0.0))
	dm_fluid.set_element(1, 1, Complex.new(0.25, 0.0))
	dm_fluid.set_element(2, 2, Complex.new(0.25, 0.0))
	dm_fluid.set_element(3, 3, Complex.new(0.24, 0.0))
	var u_fluid = SemanticUncertainty.compute_uncertainty(dm_fluid)
	assert_true(
		u_fluid.regime in ["fluid", "chaotic"],
		"High flexibility -> fluid or chaotic"
	)

	# Balanced: moderate values
	var dm_balanced = ComplexMatrix.new(4)
	dm_balanced.set_element(0, 0, Complex.new(0.4, 0.0))
	dm_balanced.set_element(1, 1, Complex.new(0.3, 0.0))
	dm_balanced.set_element(2, 2, Complex.new(0.2, 0.0))
	dm_balanced.set_element(3, 3, Complex.new(0.1, 0.0))
	var u_balanced = SemanticUncertainty.compute_uncertainty(dm_balanced)
	assert_true(
		u_balanced.precision > 0.2 and u_balanced.flexibility > 0.2,
		"Balanced state has moderate precision and flexibility"
	)

	print()


func test_regime_descriptions():
	print("\nTEST: Regime Descriptions")

	var regimes = ["crystallized", "fluid", "balanced", "stable", "chaotic", "diffuse", "transitional"]

	for regime in regimes:
		var desc = SemanticUncertainty.get_regime_description(regime)
		assert_true(desc.length() > 10, "%s has description" % regime)

		var emoji = SemanticUncertainty.get_regime_emoji(regime)
		assert_true(emoji.length() > 0, "%s has emoji" % regime)

	print()


func test_regime_colors():
	print("\nTEST: Regime Colors")

	var regimes = ["crystallized", "fluid", "balanced", "stable", "chaotic", "diffuse", "transitional"]

	for regime in regimes:
		var color = SemanticUncertainty.get_regime_color(regime)
		assert_true(color != Color.BLACK, "%s has non-black color" % regime)

	# Specific color checks
	var crystal_color = SemanticUncertainty.get_regime_color("crystallized")
	assert_true(crystal_color.b > crystal_color.r, "Crystallized is blueish")

	var chaotic_color = SemanticUncertainty.get_regime_color("chaotic")
	assert_true(chaotic_color.r > chaotic_color.b, "Chaotic is reddish")

	print()


## ========================================
## Modifier Tests
## ========================================

func test_action_modifiers():
	print("\nTEST: Action Modifiers")

	# Crystallized regime: rigid
	var crystal_mods = SemanticUncertainty.get_action_modifier({
		"precision": 0.9,
		"flexibility": 0.1,
		"regime": "crystallized"
	})
	assert_true(crystal_mods.tool_effectiveness < 1.0, "Crystallized: tools less effective")
	assert_true(crystal_mods.meaning_stability > 1.0, "Crystallized: meanings more stable")
	assert_true(crystal_mods.state_change_cost > 1.0, "Crystallized: expensive to change")

	# Fluid regime: adaptable
	var fluid_mods = SemanticUncertainty.get_action_modifier({
		"precision": 0.1,
		"flexibility": 0.9,
		"regime": "fluid"
	})
	assert_true(fluid_mods.tool_effectiveness > 1.0, "Fluid: tools more effective")
	assert_true(fluid_mods.meaning_stability < 1.0, "Fluid: meanings unstable")
	assert_true(fluid_mods.state_change_cost < 1.0, "Fluid: cheap to change")

	# Balanced: neutral
	var balanced_mods = SemanticUncertainty.get_action_modifier({
		"precision": 0.5,
		"flexibility": 0.5,
		"regime": "balanced"
	})
	assert_approx(balanced_mods.tool_effectiveness, 1.0, 0.01, "Balanced: neutral effectiveness")
	assert_approx(balanced_mods.meaning_stability, 1.0, 0.01, "Balanced: neutral stability")

	print()


## ========================================
## Integration Tests
## ========================================

func test_quantum_computer_integration():
	print("\nTEST: Quantum Computer Integration")

	# Create a quantum computer
	var qc = QuantumComputer.new("test_uncertainty")
	qc.allocate_axis(0, "🌾", "🍄")
	qc.allocate_axis(1, "☀️", "🌙")

	# Initialize to basis state
	qc.initialize_basis(0)

	# Compute uncertainty
	var uncertainty = SemanticUncertainty.compute_from_quantum_computer(qc)

	assert_true(uncertainty.has("precision"), "Has precision")
	assert_true(uncertainty.has("flexibility"), "Has flexibility")
	assert_true(uncertainty.has("regime"), "Has regime")

	# Pure state should have high precision
	assert_true(uncertainty.precision > 0.9, "Basis state has high precision")

	print()


func test_real_biome_evolution():
	print("\nTEST: Real Biome Evolution")

	# Create quantum computer and evolve
	var qc = QuantumComputer.new("evolution_test")
	qc.allocate_axis(0, "🌾", "🍄")
	qc.allocate_axis(1, "☀️", "🌙")
	qc.allocate_axis(2, "💰", "📦")

	# Start from superposition
	qc.initialize_basis(0)

	# Apply some evolution to create mixed state
	# (Without actual Hamiltonian, just modify density matrix directly)
	if qc.density_matrix:
		# Add some off-diagonal coherence
		qc.density_matrix.set_element(0, 1, Complex.new(0.2, 0.1))
		qc.density_matrix.set_element(1, 0, Complex.new(0.2, -0.1))

		# Redistribute diagonal
		qc.density_matrix.set_element(0, 0, Complex.new(0.6, 0.0))
		qc.density_matrix.set_element(1, 1, Complex.new(0.3, 0.0))
		qc.density_matrix.set_element(2, 2, Complex.new(0.1, 0.0))

	# Compute uncertainty after "evolution"
	var uncertainty = SemanticUncertainty.compute_from_quantum_computer(qc)

	# Should have some entropy now
	assert_true(uncertainty.entropy > 0.0, "Evolved state has entropy")

	# Check report generation works
	var report = SemanticUncertainty.format_uncertainty_report(uncertainty)
	assert_true(report.length() > 100, "Report is substantial")

	print()

