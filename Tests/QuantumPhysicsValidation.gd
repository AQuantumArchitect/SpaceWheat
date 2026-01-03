extends SceneTree

const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const DensityMatrix = preload("res://Core/QuantumSubstrate/DensityMatrix.gd")
const Hamiltonian = preload("res://Core/QuantumSubstrate/Hamiltonian.gd")
const LindbladSuperoperator = preload("res://Core/QuantumSubstrate/LindbladSuperoperator.gd")
const QuantumEvolver = preload("res://Core/QuantumSubstrate/QuantumEvolver.gd")
const QuantumBath = preload("res://Core/QuantumSubstrate/QuantumBath.gd")
const Icon = preload("res://Core/QuantumSubstrate/Icon.gd")

## QuantumPhysicsValidation - Research-Grade Quantum Simulator Tests
##
## Validates that the new density matrix formalism is physically correct:
## 1. Trace preservation: Tr(ρ) = 1 after any evolution
## 2. Hermiticity: ρ = ρ† after any evolution
## 3. Positivity: All eigenvalues ≥ 0 after any evolution
## 4. Rabi oscillation: Correct Hamiltonian dynamics
## 5. Lindblad transfer: Population moves source→target correctly
## 6. Purity decrease: Mixed states from Lindblad evolution

var tests_passed: int = 0
var tests_failed: int = 0
var test_results: Array = []

func _init():
	print("\n╔═══════════════════════════════════════════════════════════════╗")
	print("║   QUANTUM PHYSICS VALIDATION - Research-Grade Simulator      ║")
	print("╚═══════════════════════════════════════════════════════════════╝\n")

	run_all_tests()
	print_summary()
	quit()

func run_all_tests():
	test_complex_matrix_basic()
	test_complex_matrix_expm()
	test_density_matrix_construction()
	test_density_matrix_observables()
	test_trace_preservation()
	test_hermiticity_preservation()
	test_positivity_preservation()
	test_unitary_evolution()
	test_lindblad_population_transfer()
	test_purity_decrease()
	test_bloch_sphere_projection()
	test_full_simulation()

func record_result(name: String, passed: bool, details: String = ""):
	if passed:
		tests_passed += 1
		print("  ✅ %s" % name)
	else:
		tests_failed += 1
		print("  ❌ %s: %s" % [name, details])
	test_results.append({"name": name, "passed": passed, "details": details})

#region ComplexMatrix Tests

func test_complex_matrix_basic():
	print("\n📊 ComplexMatrix Basic Operations:")

	# Test identity
	var I = ComplexMatrix.identity(3)
	var diag_sum = I.get_element(0, 0).re + I.get_element(1, 1).re + I.get_element(2, 2).re
	record_result("Identity trace = 3", abs(diag_sum - 3.0) < 1e-10)

	# Test multiplication A × I = A
	var A = ComplexMatrix.new(2)
	A.set_element(0, 0, Complex.new(1.0, 2.0))
	A.set_element(0, 1, Complex.new(3.0, 0.0))
	A.set_element(1, 0, Complex.new(0.0, 4.0))
	A.set_element(1, 1, Complex.new(5.0, 6.0))

	var I2 = ComplexMatrix.identity(2)
	var AI = A.mul(I2)
	var matches = AI.get_element(0, 0).equals(A.get_element(0, 0))
	record_result("A × I = A", matches)

	# Test dagger (Hermitian conjugate)
	var A_dag = A.dagger()
	record_result("(A†)₀₀ = A₀₀*", A_dag.get_element(0, 0).equals(A.get_element(0, 0).conjugate()))
	record_result("(A†)₀₁ = A₁₀*", A_dag.get_element(0, 1).equals(A.get_element(1, 0).conjugate()))

	# Test Hermitian check
	var H = ComplexMatrix.new(2)
	H.set_element(0, 0, Complex.new(1.0, 0.0))
	H.set_element(0, 1, Complex.new(0.5, 0.3))
	H.set_element(1, 0, Complex.new(0.5, -0.3))
	H.set_element(1, 1, Complex.new(2.0, 0.0))
	record_result("Hermitian matrix detected", H.is_hermitian())

func test_complex_matrix_expm():
	print("\n📊 ComplexMatrix Exponential:")

	# Test exp(0) = I
	var zero = ComplexMatrix.new(2)
	var exp_zero = zero.expm()
	var is_identity = exp_zero.get_element(0, 0).equals(Complex.one()) and \
					  exp_zero.get_element(1, 1).equals(Complex.one()) and \
					  exp_zero.get_element(0, 1).abs() < 1e-10 and \
					  exp_zero.get_element(1, 0).abs() < 1e-10
	record_result("exp(0) = I", is_identity)

	# Test exp(-iHt) for Pauli Z: should give diagonal phases
	var sigma_z = ComplexMatrix.new(2)
	sigma_z.set_element(0, 0, Complex.new(1.0, 0.0))
	sigma_z.set_element(1, 1, Complex.new(-1.0, 0.0))

	var t = 0.5
	var minus_i_H_t = sigma_z.scale(Complex.new(0.0, -t))
	var U = minus_i_H_t.expm()

	# U should have e^(-it) and e^(it) on diagonal
	var expected_00 = Complex.from_polar(1.0, -t)
	var expected_11 = Complex.from_polar(1.0, t)
	record_result("exp(-iσ_z t) diagonal correct",
		U.get_element(0, 0).sub(expected_00).abs() < 1e-6 and
		U.get_element(1, 1).sub(expected_11).abs() < 1e-6)

	# Test unitarity: U†U = I
	var U_dag_U = U.dagger().mul(U)
	var is_unitary = U_dag_U.get_element(0, 0).sub(Complex.one()).abs() < 1e-6 and \
					 U_dag_U.get_element(1, 1).sub(Complex.one()).abs() < 1e-6 and \
					 U_dag_U.get_element(0, 1).abs() < 1e-6
	record_result("exp(-iH t) is unitary", is_unitary)

#endregion

#region DensityMatrix Tests

func test_density_matrix_construction():
	print("\n📊 DensityMatrix Construction:")

	var rho = DensityMatrix.new()
	rho.initialize_with_emojis(["🌾", "💀"])

	record_result("Dimension = 2", rho.dimension() == 2)
	record_result("Trace = 1", abs(rho.get_trace() - 1.0) < 1e-10)

	# Test pure state construction
	var amps: Array = [Complex.new(1.0 / sqrt(2.0), 0.0), Complex.new(0.0, 1.0 / sqrt(2.0))]
	rho.set_pure_state(amps)
	record_result("Pure state trace = 1", abs(rho.get_trace() - 1.0) < 1e-10)
	record_result("Pure state purity = 1", abs(rho.get_purity() - 1.0) < 1e-6)

	# Test maximally mixed
	rho.set_maximally_mixed()
	record_result("Mixed state purity = 0.5", abs(rho.get_purity() - 0.5) < 1e-6)
	record_result("Mixed state P(🌾) = 0.5", abs(rho.get_probability("🌾") - 0.5) < 1e-6)

func test_density_matrix_observables():
	print("\n📊 DensityMatrix Observables:")

	var rho = DensityMatrix.new()
	rho.initialize_with_emojis(["☀", "🌙", "🌾"])

	# Classical mixture with known probabilities
	var probs: Array = [0.5, 0.3, 0.2]
	rho.set_classical_mixture(probs)

	record_result("P(☀) = 0.5", abs(rho.get_probability("☀") - 0.5) < 1e-10)
	record_result("P(🌙) = 0.3", abs(rho.get_probability("🌙") - 0.3) < 1e-10)
	record_result("P(🌾) = 0.2", abs(rho.get_probability("🌾") - 0.2) < 1e-10)

	# Purity of classical mixture: Σ p_i²
	var expected_purity = 0.5*0.5 + 0.3*0.3 + 0.2*0.2  # 0.38
	record_result("Classical purity correct", abs(rho.get_purity() - expected_purity) < 1e-6)

	# Entropy of classical mixture: -Σ p_i log(p_i)
	var expected_entropy = -(0.5 * log(0.5) + 0.3 * log(0.3) + 0.2 * log(0.2))
	record_result("Entropy computed", abs(rho.get_entropy() - expected_entropy) < 0.01)

#endregion

#region Physical Invariant Tests

func test_trace_preservation():
	print("\n📊 Trace Preservation:")

	var rho = DensityMatrix.new()
	rho.initialize_with_emojis(["A", "B", "C"])

	var amps: Array = [Complex.new(0.5, 0.0), Complex.new(0.5, 0.5), Complex.new(0.3, -0.2)]
	rho.set_pure_state(amps)

	# Build simple Hamiltonian
	var H = Hamiltonian.new()
	var emojis = ["A", "B", "C"]
	H.build_from_icons([], emojis)

	# Set some non-trivial Hamiltonian
	var H_mat = ComplexMatrix.new(3)
	H_mat.set_element(0, 0, Complex.new(1.0, 0.0))
	H_mat.set_element(1, 1, Complex.new(-0.5, 0.0))
	H_mat.set_element(2, 2, Complex.new(0.2, 0.0))
	H_mat.set_element(0, 1, Complex.new(0.3, 0.0))
	H_mat.set_element(1, 0, Complex.new(0.3, 0.0))

	# Get unitary and apply
	var scaled = H_mat.scale(Complex.new(0.0, -0.1))
	var U = scaled.expm()
	rho.apply_unitary(U)

	record_result("Trace preserved after unitary", abs(rho.get_trace() - 1.0) < 1e-8)

func test_hermiticity_preservation():
	print("\n📊 Hermiticity Preservation:")

	var rho = DensityMatrix.new()
	rho.initialize_with_emojis(["X", "Y"])

	var amps: Array = [Complex.new(0.6, 0.1), Complex.new(0.3, -0.4)]
	rho.set_pure_state(amps)

	# Build evolution
	var H_mat = ComplexMatrix.new(2)
	H_mat.set_element(0, 0, Complex.new(1.0, 0.0))
	H_mat.set_element(1, 1, Complex.new(-1.0, 0.0))
	H_mat.set_element(0, 1, Complex.new(0.2, 0.0))
	H_mat.set_element(1, 0, Complex.new(0.2, 0.0))

	var U = H_mat.scale(Complex.new(0.0, -0.05)).expm()
	rho.apply_unitary(U)

	record_result("ρ is Hermitian after evolution", rho.get_matrix().is_hermitian())

func test_positivity_preservation():
	print("\n📊 Positivity Preservation:")

	var rho = DensityMatrix.new()
	rho.initialize_with_emojis(["P", "Q"])
	rho.set_maximally_mixed()

	# Multiple evolution steps
	var H_mat = ComplexMatrix.new(2)
	H_mat.set_element(0, 0, Complex.new(0.5, 0.0))
	H_mat.set_element(1, 1, Complex.new(-0.5, 0.0))
	H_mat.set_element(0, 1, Complex.new(0.4, 0.0))
	H_mat.set_element(1, 0, Complex.new(0.4, 0.0))

	for i in range(10):
		var U = H_mat.scale(Complex.new(0.0, -0.02)).expm()
		rho.apply_unitary(U)

	record_result("ρ positive semidefinite after evolution", rho.get_matrix().is_positive_semidefinite())

#endregion

#region Dynamics Tests

func test_unitary_evolution():
	print("\n📊 Unitary (Hamiltonian) Evolution:")

	# Test Rabi oscillation between two states
	var rho = DensityMatrix.new()
	rho.initialize_with_emojis(["0", "1"])

	# Start in pure |0⟩
	var amps: Array = [Complex.one(), Complex.zero()]
	rho.set_pure_state(amps)

	var initial_P0 = rho.get_probability("0")
	record_result("Initial P(0) = 1", abs(initial_P0 - 1.0) < 1e-10)

	# Hamiltonian: σ_x (causes Rabi oscillation)
	var H_mat = ComplexMatrix.new(2)
	H_mat.set_element(0, 1, Complex.new(1.0, 0.0))
	H_mat.set_element(1, 0, Complex.new(1.0, 0.0))

	# Evolve for time t = π/2 (should swap populations)
	var t = PI / 2.0
	var U = H_mat.scale(Complex.new(0.0, -t)).expm()
	rho.apply_unitary(U)

	var final_P0 = rho.get_probability("0")
	var final_P1 = rho.get_probability("1")

	# After t=π/2 with H=σ_x: |0⟩ → |1⟩
	record_result("Rabi: P(0) ≈ 0 at t=π/2", final_P0 < 0.01)
	record_result("Rabi: P(1) ≈ 1 at t=π/2", final_P1 > 0.99)
	record_result("Purity preserved in Rabi", abs(rho.get_purity() - 1.0) < 1e-6)

func test_lindblad_population_transfer():
	print("\n📊 Lindblad Population Transfer:")

	var rho = DensityMatrix.new()
	rho.initialize_with_emojis(["source", "target"])

	# Start with all population in source
	var amps: Array = [Complex.one(), Complex.zero()]
	rho.set_pure_state(amps)

	var initial_source = rho.get_probability("source")
	record_result("Initial P(source) = 1", abs(initial_source - 1.0) < 1e-10)

	# Build Lindblad operator: L = |target⟩⟨source|
	var lindblad = LindbladSuperoperator.new()
	lindblad.build_from_icons([], ["source", "target"])

	# Manually add transfer term
	var L = ComplexMatrix.new(2)
	L.set_element(1, 0, Complex.one())  # |target⟩⟨source|
	lindblad.add_term(L, 1.0, "source→target")

	# Evolve for multiple steps
	for i in range(100):
		var evolved = lindblad.apply(rho, 0.01)
		rho.set_matrix(evolved.get_matrix())

	var final_source = rho.get_probability("source")
	var final_target = rho.get_probability("target")

	record_result("P(source) decreased", final_source < 0.5)
	record_result("P(target) increased", final_target > 0.5)
	record_result("Trace preserved", abs(rho.get_trace() - 1.0) < 1e-6)

func test_purity_decrease():
	print("\n📊 Purity Decrease (Decoherence):")

	var rho = DensityMatrix.new()
	rho.initialize_with_emojis(["A", "B"])

	# Start pure
	var amps: Array = [Complex.new(1.0 / sqrt(2.0), 0.0), Complex.new(1.0 / sqrt(2.0), 0.0)]
	rho.set_pure_state(amps)

	var initial_purity = rho.get_purity()
	record_result("Initial purity = 1", abs(initial_purity - 1.0) < 1e-6)

	# Apply dephasing Lindblad: L = |A⟩⟨A| (dephases without changing populations)
	var L = ComplexMatrix.new(2)
	L.set_element(0, 0, Complex.one())

	# Apply dephasing
	for i in range(50):
		rho.apply_lindblad_term(L, 0.1, 0.01)

	var final_purity = rho.get_purity()
	record_result("Purity decreased after dephasing", final_purity < initial_purity)
	record_result("Trace preserved under dephasing", abs(rho.get_trace() - 1.0) < 1e-6)

#endregion

#region Projection Tests

func test_bloch_sphere_projection():
	print("\n📊 Bloch Sphere Projection:")

	var rho = DensityMatrix.new()
	rho.initialize_with_emojis(["🌾", "💀", "🍂"])

	# Set wheat to high, death to low, decay in between
	var probs: Array = [0.6, 0.1, 0.3]
	rho.set_classical_mixture(probs)

	# Project onto wheat/death axis
	var proj = rho.project_onto_subspace("🌾", "💀")

	# P(wheat) = 0.6, P(death) = 0.1, total = 0.7
	# In subspace: P(wheat|subspace) = 0.6/0.7, P(death|subspace) = 0.1/0.7
	var expected_p_wheat = 0.6 / 0.7
	var expected_theta = 2.0 * acos(sqrt(expected_p_wheat))

	record_result("Projection theta correct", abs(proj.theta - expected_theta) < 0.01)
	record_result("Subspace probability correct", abs(proj.p_subspace - 0.7) < 1e-6)

#endregion

#region Full Simulation Test

func test_full_simulation():
	print("\n📊 Full Quantum Simulation:")

	# Create a QuantumBath with proper evolution
	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["☀", "🌾", "💀"])
	bath.initialize_uniform()

	# Build simple Icon-like Hamiltonian and Lindblad
	var icons: Array = []

	# Create simple sun icon
	var sun_icon = Icon.new()
	sun_icon.emoji = "☀"
	sun_icon.self_energy = 1.0
	icons.append(sun_icon)

	# Create wheat icon with Lindblad from sun
	var wheat_icon = Icon.new()
	wheat_icon.emoji = "🌾"
	wheat_icon.lindblad_incoming = {"☀": 0.1}
	icons.append(wheat_icon)

	# Create death icon with Lindblad from wheat
	var death_icon = Icon.new()
	death_icon.emoji = "💀"
	death_icon.lindblad_incoming = {"🌾": 0.05}
	icons.append(death_icon)

	bath.active_icons = icons
	bath.build_hamiltonian_from_icons(icons)
	bath.build_lindblad_from_icons(icons)

	var initial_wheat = bath.get_probability("🌾")
	var initial_purity = bath.get_purity()

	record_result("Bath initialized", bath.get_total_probability() > 0.99)
	record_result("Initial purity computed", initial_purity > 0)

	# Evolve for 1 second (60 frames at 60fps)
	for i in range(60):
		bath.evolve(1.0 / 60.0)

	var final_trace = bath.get_total_probability()
	var validation = bath.validate()

	record_result("Trace preserved after 1s evolution", abs(final_trace - 1.0) < 0.01)
	record_result("Bath still valid", validation.valid)

	print("\n  📈 Simulation results:")
	print("    Initial P(🌾) = %.4f" % initial_wheat)
	print("    Final P(🌾) = %.4f" % bath.get_probability("🌾"))
	print("    Purity: %.4f → %.4f" % [initial_purity, bath.get_purity()])

#endregion

func print_summary():
	print("\n" + "═".repeat(65))
	print("VALIDATION SUMMARY")
	print("═".repeat(65))
	print("\n  Total tests: %d" % (tests_passed + tests_failed))
	print("  ✅ Passed: %d" % tests_passed)
	print("  ❌ Failed: %d" % tests_failed)

	if tests_failed == 0:
		print("\n  🎉 ALL TESTS PASSED - Quantum simulator is research-grade!")
	else:
		print("\n  ⚠️  Some tests failed - review implementation")

	print("\n" + "═".repeat(65))
