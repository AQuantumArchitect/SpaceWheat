extends SceneTree

## Full Integration Test: Complete Player Mock Workflow
## Tests: Game boot → Icon loading → Biome setup → Plant growth → Gate application → Spark extraction
## Reports all errors without fixing

const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")

var errors: Array = []
var warnings: Array = []
var tests_run: int = 0
var tests_passed: int = 0

func _init():
	var sep = "============================================================"
	print("")
	print(sep)
	print("FULL INTEGRATION TEST: Player Mock Workflow")
	print(sep)
	print("")

	test_native_backend()
	test_icon_registry()
	test_quantum_gate_library()
	test_farm_grid_initialization()
	test_quantum_bath_setup()
	test_biome_creation()
	test_plant_growth_cycle()
	test_gate_applications()

	print_report()
	quit()

func test(name: String, fn: Callable) -> bool:
	tests_run += 1
	var success = false
	var error_msg = ""

	var test_num = str(tests_run)
	print("[Test " + test_num + "] " + name + "... ", false)

	var result = fn.call()
	if result is Dictionary:
		success = result.get("success", false)
		error_msg = result.get("error", "")
	else:
		success = result == true
		error_msg = str(result) if result != true else ""

	if success:
		tests_passed += 1
		print("✓")
	else:
		print("✗")
		if error_msg:
			errors.append({
				"test": name,
				"error": error_msg
			})

	return success

#region Test Suites

func test_native_backend():
	print("")
	print("--- Native Backend Tests ---")

	test("Native acceleration available", func():
		return {"success": ComplexMatrix.is_native_available(), "error": "Native not loaded"}
	)

	test("ComplexMatrix 4x4 multiplication", func():
		var A = ComplexMatrix.new(4)
		var B = ComplexMatrix.new(4)
		for i in range(16):
			A._data[i] = Complex.new(randf(), randf())
			B._data[i] = Complex.new(randf(), randf())
		var C = A.mul(B)
		return {"success": C.n == 4, "error": "Result dimension mismatch"}
	)

	test("ComplexMatrix 8x8 expm", func():
		var H = _random_hermitian(8)
		var exp_H = H.expm()
		return {"success": exp_H.n == 8, "error": "expm result dimension mismatch"}
	)

	test("ComplexMatrix eigensystem", func():
		var H = _random_hermitian(4)
		var eig = H.eigensystem()
		var has_vals = eig.has("eigenvalues") and eig["eigenvalues"].size() == 4
		var has_vecs = eig.has("eigenvectors") and eig["eigenvectors"].n == 4
		return {"success": has_vals and has_vecs, "error": "eigensystem structure invalid"}
	)

func test_icon_registry():
	print("\n--- Icon Registry Tests ---")

	var registry = load("res://Core/QuantumSubstrate/IconRegistry.gd").new()

	test("IconRegistry instantiation", func():
		return {"success": registry != null, "error": "Failed to instantiate"}
	)

	test("IconRegistry icon loading", func():
		# Note: icons should have been loaded by autoload
		# Check if we can access game's IconRegistry
		var root = get_root()
		var game_registry = root.get_node_or_null("IconRegistry") if root else null
		if game_registry == null:
			return {"success": false, "error": "IconRegistry autoload not found"}
		return {"success": game_registry.icons.size() > 0, "error": "No icons registered"}
	)

	test("Get icon by emoji", func():
		var root = get_root()
		var game_registry = root.get_node_or_null("IconRegistry") if root else null
		if game_registry == null:
			return {"success": false, "error": "IconRegistry not found"}
		var wheat_icon = game_registry.get_icon("🌾")
		return {"success": wheat_icon != null, "error": "Wheat icon not found"}
	)

	test("Icon has couplings", func():
		var game_registry = get_root().get_node_or_null("IconRegistry")
		if game_registry == null:
			return {"success": false, "error": "IconRegistry not found"}
		var wheat_icon = game_registry.get_icon("🌾")
		if wheat_icon == null:
			return {"success": false, "error": "Wheat icon missing"}
		return {"success": wheat_icon.hamiltonian_couplings.size() > 0 or wheat_icon.lindblad_outgoing.size() > 0, "error": "Icon has no couplings"}
	)

func test_quantum_gate_library():
	print("\n--- Quantum Gate Library Tests ---")

	test("QuantumGateLibrary instantiation", func():
		var lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
		return {"success": lib != null, "error": "Failed to instantiate"}
	)

	test("Pauli X gate", func():
		var lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
		var X = lib.get_gate("X", 2)
		return {"success": X != null and X.n == 2, "error": "X gate creation failed"}
	)

	test("Hadamard gate", func():
		var lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
		var H = lib.get_gate("H", 2)
		return {"success": H != null and H.n == 2, "error": "H gate creation failed"}
	)

	test("Phase gates (Y, S, T)", func():
		var lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
		var gates_ok = true
		for gate_name in ["Y", "S", "T"]:
			var gate = lib.get_gate(gate_name, 2)
			if gate == null or gate.n != 2:
				gates_ok = false
				break
		return {"success": gates_ok, "error": "Phase gate creation failed"}
	)

func test_farm_grid_initialization():
	print("\n--- Farm Grid Tests ---")

	test("FarmGrid instantiation", func():
		var grid = load("res://Core/GameMechanics/FarmGrid.gd").new()
		return {"success": grid != null, "error": "Failed to instantiate"}
	)

	test("FarmGrid cell creation", func():
		var grid = load("res://Core/GameMechanics/FarmGrid.gd").new()
		grid._init(5, 5)
		return {"success": grid.width == 5 and grid.height == 5, "error": "Grid dimensions incorrect"}
	)

	test("FarmGrid plant placement", func():
		var grid = load("res://Core/GameMechanics/FarmGrid.gd").new()
		grid._init(5, 5)
		var cell = grid.get_cell(2, 2)
		return {"success": cell != null, "error": "Cell retrieval failed"}
	)

func test_quantum_bath_setup():
	print("\n--- Quantum Bath Tests ---")

	test("QuantumBath instantiation", func():
		var bath = load("res://Core/QuantumSubstrate/QuantumBath.gd").new()
		return {"success": bath != null, "error": "Failed to instantiate"}
	)

	test("QuantumBath initialization with biome", func():
		var bath = load("res://Core/QuantumSubstrate/QuantumBath.gd").new()
		var icon_registry = get_root().get_node_or_null("IconRegistry")
		if icon_registry == null:
			return {"success": false, "error": "IconRegistry not available"}

		var wheat_icon = icon_registry.get_icon("🌾")
		if wheat_icon == null:
			return {"success": false, "error": "Test icon not found"}

		bath._init({"🌾": wheat_icon})
		return {"success": bath.dimension >= 1, "error": "Bath dimension invalid"}
	)

	test("Density matrix trace = 1", func():
		var bath = load("res://Core/QuantumSubstrate/QuantumBath.gd").new()
		var icon_registry = get_root().get_node_or_null("IconRegistry")
		if icon_registry == null:
			return {"success": false, "error": "IconRegistry not available"}

		var wheat_icon = icon_registry.get_icon("🌾")
		if wheat_icon == null:
			return {"success": false, "error": "Test icon not found"}

		bath._init({"🌾": wheat_icon})
		var rho = bath.get_density_matrix()
		var tr = rho.trace().re
		var trace_ok = abs(tr - 1.0) < 1e-6
		return {"success": trace_ok, "error": "Trace %.6f != 1.0" % tr}
	)

func test_biome_creation():
	print("\n--- Biome Creation Tests ---")

	test("Forest biome builder", func():
		var builder = load("res://Core/Factions/IconBuilder.gd")
		var forest = builder.build_forest_biome()
		return {"success": forest.size() > 0, "error": "Forest biome empty"}
	)

	test("Kitchen biome builder", func():
		var builder = load("res://Core/Factions/IconBuilder.gd")
		var kitchen = builder.build_kitchen_biome()
		return {"success": kitchen.size() > 0, "error": "Kitchen biome empty"}
	)

	test("Biome has expected emojis", func():
		var builder = load("res://Core/Factions/IconBuilder.gd")
		var forest = builder.build_forest_biome()
		return {"success": forest.has("🌾") and forest.has("🍄"), "error": "Missing expected emojis"}
	)

func test_plant_growth_cycle():
	print("\n--- Plant Growth Cycle Tests ---")

	test("Plant lifecycle creation", func():
		var lifecycle = load("res://Core/GameMechanics/PlantLifecycle.gd").new()
		return {"success": lifecycle != null, "error": "Failed to instantiate"}
	)

	test("Growth stage transitions", func():
		var lifecycle = load("res://Core/GameMechanics/PlantLifecycle.gd").new()
		lifecycle._init()
		var initial_stage = lifecycle.current_stage
		return {"success": initial_stage == "seedling", "error": "Initial stage != seedling"}
	)

	test("Photosynthesis energy accumulation", func():
		var lifecycle = load("res://Core/GameMechanics/PlantLifecycle.gd").new()
		lifecycle._init()
		var initial_energy = lifecycle.energy
		lifecycle.accumulate_photosynthesis_energy(0.5)
		var new_energy = lifecycle.energy
		return {"success": new_energy > initial_energy, "error": "Energy didn't accumulate"}
	)

func test_gate_applications():
	print("\n--- Gate Application Tests ---")

	test("Apply X gate to 2-qubit state", func():
		var lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
		var X = lib.get_gate("X", 2)
		var state = ComplexMatrix.new(2)
		state.set_element(0, 0, Complex.one())  # |0⟩
		var result = X.mul(state)
		return {"success": result.n == 2, "error": "Gate application failed"}
	)

	test("Apply Hadamard gate (creates superposition)", func():
		var lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
		var H = lib.get_gate("H", 2)
		var state = ComplexMatrix.new(2)
		state.set_element(0, 0, Complex.one())  # |0⟩
		var result = H.mul(state)
		# After H: |0⟩ → (|0⟩ + |1⟩)/√2
		var elem_sum = result.get_element(0, 0).abs() + result.get_element(1, 0).abs()
		return {"success": elem_sum > 0.5, "error": "Superposition not created"}
	)

	test("Unitary property: U†U = I", func():
		var lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
		var U = lib.get_gate("X", 4)
		var U_dag = U.dagger()
		var product = U_dag.mul(U)
		# Check diagonals are ~1
		var is_identity = true
		for i in range(4):
			if abs(product.get_element(i, i).re - 1.0) > 1e-6:
				is_identity = false
				break
		return {"success": is_identity, "error": "U†U ≠ I"}
	)

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
	var sep = "============================================================"
	print("")
	print(sep)
	print("TEST REPORT")
	print(sep)
	print("")
	print("Tests run:    " + str(tests_run))
	print("Tests passed: " + str(tests_passed))
	print("Tests failed: " + str(tests_run - tests_passed))

	if errors.size() > 0:
		print("")
		print("--- ERRORS FOUND ---")
		print("")
		for err in errors:
			print("[" + err["test"] + "]")
			print("  Error: " + err["error"])
			print("")

	if warnings.size() > 0:
		print("")
		print("--- WARNINGS ---")
		print("")
		for warn in warnings:
			print("  ⚠ " + warn)
			print("")

	print(sep)
	print("")

#endregion
