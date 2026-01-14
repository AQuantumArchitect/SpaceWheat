extends SceneTree

## Headless Simulation Layer Tests
## Tests the quantum simulation layer without GUI/autoloads
## Uses IconBuilder directly to create icon data

const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const IconBuilder = preload("res://Core/Factions/IconBuilder.gd")
const AllFactions = preload("res://Core/Factions/AllFactions.gd")
const QuantumGateLibrary = preload("res://Core/QuantumSubstrate/QuantumGateLibrary.gd")
const QuantumBath = preload("res://Core/QuantumSubstrate/QuantumBath.gd")

var tests_passed := 0
var tests_failed := 0
var errors: Array = []

func _init():
	print("")
	print("============================================================")
	print("HEADLESS SIMULATION LAYER TEST")
	print("============================================================")
	print("")

	# Phase 1: Core Math Layer
	print("--- Phase 1: Core Math Layer ---")
	test_complex_matrix_basics()
	test_complex_matrix_operations()

	# Phase 2: Icon System (Direct Build)
	print("")
	print("--- Phase 2: Icon System (Direct Build) ---")
	test_icon_builder_direct()
	test_faction_icon_creation()

	# Phase 3: Quantum Gate System
	print("")
	print("--- Phase 3: Quantum Gate System ---")
	test_gate_library_api()
	test_gate_matrices()

	# Phase 4: Quantum Bath Simulation
	print("")
	print("--- Phase 4: Quantum Bath Simulation ---")
	test_quantum_bath_creation()
	test_density_matrix_evolution()

	# Phase 5: Full Simulation Cycle
	print("")
	print("--- Phase 5: Full Simulation Cycle ---")
	test_biome_simulation()

	print_report()
	quit()

func test(name: String, success: bool, error_msg: String = "") -> void:
	if success:
		tests_passed += 1
		print("[PASS] " + name)
	else:
		tests_failed += 1
		print("[FAIL] " + name)
		if error_msg != "":
			print("       Error: " + error_msg)
			errors.append({"test": name, "error": error_msg})

#region Phase 1: Core Math Layer

func test_complex_matrix_basics():
	# Test matrix creation
	var m = ComplexMatrix.new(4)
	test("ComplexMatrix creation (4x4)", m.n == 4, "Dimension mismatch")

	# Test element access
	m.set_element(1, 2, Complex.new(3.14, 2.71))
	var elem = m.get_element(1, 2)
	test("ComplexMatrix element set/get", abs(elem.re - 3.14) < 0.001 and abs(elem.im - 2.71) < 0.001, "Element values incorrect")

	# Test identity
	var I = ComplexMatrix.identity(4)
	var diag_sum = 0.0
	for i in range(4):
		diag_sum += I.get_element(i, i).re
	test("ComplexMatrix.identity diagonal sum", abs(diag_sum - 4.0) < 0.001, "Identity diagonal sum != 4")

func test_complex_matrix_operations():
	var A = _random_hermitian(4)
	var B = _random_hermitian(4)

	# Test multiplication
	var C = A.mul(B)
	test("ComplexMatrix.mul produces result", C != null and C.n == 4, "mul() failed")

	# Test trace
	var tr = A.trace()
	test("ComplexMatrix.trace returns Complex", tr != null, "trace() returned null")

	# Test expm
	var exp_A = A.scale(Complex.new(0.1, 0.0)).expm()
	test("ComplexMatrix.expm produces result", exp_A != null and exp_A.n == 4, "expm() failed")

	# Test inverse
	var A_inv = A.inverse()
	test("ComplexMatrix.inverse produces result", A_inv != null and A_inv.n == 4, "inverse() failed")

	# Test eigensystem
	var eig = A.eigensystem()
	var has_vals = eig.has("eigenvalues") and eig["eigenvalues"].size() == 4
	var has_vecs = eig.has("eigenvectors")
	test("ComplexMatrix.eigensystem structure", has_vals and has_vecs, "eigensystem() structure invalid")

#endregion

#region Phase 2: Icon System

func test_icon_builder_direct():
	# Build icons directly without autoload
	var factions = AllFactions.get_all()
	test("AllFactions.get_all() returns factions", factions.size() > 0, "No factions returned")

	# Build faction index
	IconBuilder.build_faction_index(factions)
	test("IconBuilder index built", IconBuilder.is_index_built(), "Index not built")

	# Build icons
	var icons = IconBuilder.build_icons_for_factions(factions)
	test("IconBuilder built icons", icons.size() > 0, "No icons built, got " + str(icons.size()))

func test_faction_icon_creation():
	# Test specific biome creation
	var forest = IconBuilder.build_forest_biome()
	test("Forest biome has icons", forest.size() > 0, "Empty forest biome")

	# Check for expected emojis
	var has_wheat = forest.has("🌾")
	var has_sun = forest.has("☀")
	test("Forest has wheat and sun", has_wheat and has_sun, "Missing expected icons")

	# Check icon has properties
	if has_wheat:
		var wheat = forest["🌾"]
		var has_couplings = wheat.hamiltonian_couplings.size() > 0 or wheat.lindblad_outgoing.size() > 0 or wheat.lindblad_incoming.size() > 0
		test("Wheat icon has couplings", has_couplings, "Wheat has no couplings defined")

#endregion

#region Phase 3: Quantum Gate System

func test_gate_library_api():
	# Test get_gate returns Dictionary
	var gate_dict = QuantumGateLibrary.get_gate("X")
	test("get_gate returns Dictionary", gate_dict is Dictionary, "Expected Dictionary")

	# Test Dictionary has expected keys
	var has_keys = gate_dict.has("arity") and gate_dict.has("matrix") and gate_dict.has("description")
	test("Gate dict has arity/matrix/description", has_keys, "Missing keys in gate dict")

	# Test matrix is valid
	if gate_dict.has("matrix"):
		var matrix = gate_dict["matrix"]
		test("Gate matrix is ComplexMatrix", matrix is ComplexMatrix, "Matrix type incorrect")

func test_gate_matrices():
	# Test X gate properties
	var X_dict = QuantumGateLibrary.get_gate("X")
	var X = X_dict.get("matrix") as ComplexMatrix
	if X:
		# X^2 = I for Pauli X
		var X2 = X.mul(X)
		var is_identity = true
		for i in range(X.n):
			for j in range(X.n):
				var expected = Complex.one() if i == j else Complex.zero()
				if X2.get_element(i, j).sub(expected).abs() > 0.001:
					is_identity = false
					break
		test("X gate: X^2 = I", is_identity, "X^2 != Identity")
	else:
		test("X gate: X^2 = I", false, "X matrix is null")

	# Test Hadamard
	var H_dict = QuantumGateLibrary.get_gate("H")
	var H = H_dict.get("matrix") as ComplexMatrix
	if H:
		# H^2 = I for Hadamard
		var H2 = H.mul(H)
		var is_identity = true
		for i in range(H.n):
			for j in range(H.n):
				var expected = Complex.one() if i == j else Complex.zero()
				if H2.get_element(i, j).sub(expected).abs() > 0.01:
					is_identity = false
					break
		test("H gate: H^2 = I", is_identity, "H^2 != Identity")
	else:
		test("H gate: H^2 = I", false, "H matrix is null")

	# Test phase gates exist
	for gate_name in ["Y", "Z", "S", "T"]:
		var g_dict = QuantumGateLibrary.get_gate(gate_name)
		var g = g_dict.get("matrix")
		test(gate_name + " gate exists", g != null, gate_name + " matrix is null")

#endregion

#region Phase 4: Quantum Bath

func test_quantum_bath_creation():
	# Build icons directly for bath
	var forest = IconBuilder.build_forest_biome()

	# Create bath with icons
	var bath = QuantumBath.new()
	bath.initialize_with_emojis(forest.keys())

	test("QuantumBath created", bath != null, "Bath is null")
	var rho = bath.get_density_matrix()
	test("QuantumBath has dimension > 0", rho != null and rho.dimension() > 0, "Bath dimension is 0")

func test_density_matrix_evolution():
	# Build minimal biome for testing
	var forest = IconBuilder.build_forest_biome()

	# Create bath
	var bath = QuantumBath.new()
	bath.initialize_with_emojis(forest.keys())

	# Get initial density matrix
	var rho = bath.get_density_matrix()
	test("Initial density matrix exists", rho != null, "rho is null")

	if rho:
		# Check trace = 1
		var tr = rho.get_trace()
		test("Density matrix Tr(rho) = 1", abs(tr - 1.0) < 0.01, "Trace = " + str(tr))

		# Check validity (returns Dictionary with "valid" key)
		var validity = rho.is_valid()
		test("Density matrix is valid", validity.get("valid", false), "Validity: " + str(validity))

#endregion

#region Phase 5: Full Simulation

func test_biome_simulation():
	# Build forest biome
	var forest = IconBuilder.build_forest_biome()
	test("Biome created with " + str(forest.size()) + " icons", forest.size() > 5, "Too few icons")

	# Create quantum bath with full initialization
	var bath = QuantumBath.new()
	bath.initialize_with_emojis(forest.keys())

	# Build operators from icons (required before evolve!)
	var icons_array = forest.values()
	bath.build_hamiltonian_from_icons(icons_array)
	bath.build_lindblad_from_icons(icons_array)

	# Get initial state
	var rho_initial = bath.get_density_matrix()
	if rho_initial == null:
		test("Simulation cycle", false, "Initial rho is null")
		return

	var initial_trace = rho_initial.get_trace()

	# Run evolution step (if method exists)
	if bath.has_method("evolve"):
		bath.evolve(0.1)  # 100ms timestep
		var rho_final = bath.get_density_matrix()
		var final_trace = rho_final.get_trace()

		# Trace should be preserved
		test("Trace preserved after evolution", abs(final_trace - initial_trace) < 0.01, "Trace changed from " + str(initial_trace) + " to " + str(final_trace))
	else:
		print("       [SKIP] Bath.evolve() not found - checking alternative methods")
		# Check for alternative evolution methods
		if bath.has_method("step"):
			test("Bath has step() method", true, "")
		elif bath.has_method("apply_lindblad"):
			test("Bath has apply_lindblad() method", true, "")
		else:
			test("Bath has evolution method", false, "No evolve/step/apply_lindblad found")

	# Test measurement if available
	if bath.has_method("get_probabilities"):
		var probs = bath.get_probabilities()
		test("get_probabilities() works", probs != null, "Probabilities returned null")
	else:
		print("       [SKIP] get_probabilities() not implemented")

#endregion

#region Helpers

func _random_hermitian(dim: int) -> ComplexMatrix:
	var m = ComplexMatrix.new(dim)
	for i in range(dim):
		for j in range(i, dim):
			if i == j:
				m.set_element(i, j, Complex.new(randf() * 2.0 - 1.0, 0.0))
			else:
				var c = Complex.new(randf() * 2.0 - 1.0, randf() * 2.0 - 1.0)
				m.set_element(i, j, c)
				m.set_element(j, i, c.conjugate())
	return m

func print_report():
	var total = tests_passed + tests_failed
	print("")
	print("============================================================")
	print("TEST REPORT")
	print("============================================================")
	print("")
	print("Tests passed: " + str(tests_passed) + "/" + str(total))
	print("Tests failed: " + str(tests_failed))

	if errors.size() > 0:
		print("")
		print("--- ERRORS ---")
		for err in errors:
			print("  [" + err["test"] + "]")
			print("    " + err["error"])

	print("")
	print("============================================================")

#endregion
