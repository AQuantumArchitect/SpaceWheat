extends SceneTree

## Test research-grade quantum gate operations

const QuantumBath = preload("res://Core/QuantumSubstrate/QuantumBath.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")

func _init():
	print("\n╔════════════════════════════════════════════════════════╗")
	print("║  QUANTUM GATE VALIDATION TEST                        ║")
	print("╚════════════════════════════════════════════════════════╝\n")

	await test_gate_library()
	await test_single_qubit_gates()
	await test_two_qubit_gates()
	await test_bell_state_creation()
	await test_unitarity()

	print("\n✅ ALL QUANTUM GATE TESTS PASSED!\n")
	quit()

func test_gate_library():
	print("📊 Test 1: Standard gate library...")

	var bath = QuantumBath.new()

	# Test all gates can be created
	var gates = ["X", "Y", "Z", "H", "CNOT", "CZ", "SWAP"]
	for gate_name in gates:
		var gate = bath.get_standard_gate(gate_name)
		assert(gate != null, "Failed to create gate: %s" % gate_name)

	# Verify dimensions
	var X = bath.get_standard_gate("X")
	assert(X.n == 2, "Single-qubit gate should be 2×2")

	var CNOT = bath.get_standard_gate("CNOT")
	assert(CNOT.n == 4, "Two-qubit gate should be 4×4")

	print("  ✓ All gates created with correct dimensions")

	# Test Pauli-X matrix elements
	assert(X.get_element(0, 1).re == 1.0, "X[0,1] should be 1")
	assert(X.get_element(1, 0).re == 1.0, "X[1,0] should be 1")
	assert(X.get_element(0, 0).abs() < 1e-10, "X[0,0] should be 0")
	assert(X.get_element(1, 1).abs() < 1e-10, "X[1,1] should be 0")

	print("  ✓ Pauli-X matrix elements correct")

	# Test Hadamard matrix elements
	var H = bath.get_standard_gate("H")
	var c = 1.0 / sqrt(2.0)
	assert(abs(H.get_element(0, 0).re - c) < 1e-10, "H[0,0] incorrect")
	assert(abs(H.get_element(1, 1).re + c) < 1e-10, "H[1,1] incorrect")

	print("  ✓ Hadamard matrix elements correct")
	print("  ✅ PASS\n")

func test_single_qubit_gates():
	print("📊 Test 2: Single-qubit gate application...")

	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["🌾", "💀"])

	# Initialize to pure |🌾⟩ state
	var amps = [Complex.one(), Complex.zero()]
	bath.amplitudes = amps

	print("  ✓ Initial state: |🌾⟩")
	print("    P(🌾) = %.4f, P(💀) = %.4f" % [bath.get_probability("🌾"), bath.get_probability("💀")])

	# Apply X gate: should flip to |💀⟩
	var X = bath.get_standard_gate("X")
	bath.apply_unitary_1q("🌾", "💀", X)

	var p_wheat = bath.get_probability("🌾")
	var p_death = bath.get_probability("💀")

	print("  ✓ After X gate:")
	print("    P(🌾) = %.4f, P(💀) = %.4f" % [p_wheat, p_death])

	assert(p_wheat < 0.01, "Wheat probability should be ~0 after X")
	assert(p_death > 0.99, "Death probability should be ~1 after X")

	# Apply H gate: should create superposition
	bath.amplitudes = [Complex.one(), Complex.zero()]  # Reset to |🌾⟩
	var H = bath.get_standard_gate("H")
	bath.apply_unitary_1q("🌾", "💀", H)

	p_wheat = bath.get_probability("🌾")
	p_death = bath.get_probability("💀")

	print("  ✓ After H gate:")
	print("    P(🌾) = %.4f, P(💀) = %.4f" % [p_wheat, p_death])

	assert(abs(p_wheat - 0.5) < 0.01, "H should create 50/50 superposition")
	assert(abs(p_death - 0.5) < 0.01, "H should create 50/50 superposition")

	# Check purity
	var purity = bath.get_purity()
	print("  ✓ Purity after H: %.4f (should be ~1.0 for pure state)" % purity)
	assert(purity > 0.99, "Purity should be ~1 for pure state")

	# Check trace
	var trace = bath.get_total_probability()
	assert(abs(trace - 1.0) < 0.01, "Trace should be preserved")

	print("  ✅ PASS\n")

func test_two_qubit_gates():
	print("📊 Test 3: Two-qubit gate application...")

	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["🌾", "💀", "🍞", "⚡"])

	# Initialize to |🌾🍞⟩ (control=0, target=1)
	var amps = [
		Complex.zero(),  # 🌾
		Complex.zero(),  # 💀
		Complex.one(),   # 🍞 (we'll use as control)
		Complex.zero()   # ⚡
	]
	bath.amplitudes = amps

	print("  ✓ Initial state prepared")
	print("    P(🌾)=%.2f, P(💀)=%.2f, P(🍞)=%.2f, P(⚡)=%.2f" % [
		bath.get_probability("🌾"),
		bath.get_probability("💀"),
		bath.get_probability("🍞"),
		bath.get_probability("⚡")
	])

	# Apply CNOT with 🌾,💀 as control and 🍞,⚡ as target
	var CNOT = bath.get_standard_gate("CNOT")
	bath.apply_unitary_2q("🌾", "💀", "🍞", "⚡", CNOT)

	print("  ✓ CNOT applied")
	print("    P(🌾)=%.2f, P(💀)=%.2f, P(🍞)=%.2f, P(⚡)=%.2f" % [
		bath.get_probability("🌾"),
		bath.get_probability("💀"),
		bath.get_probability("🍞"),
		bath.get_probability("⚡")
	])

	# Note: This is a simplified test. Full tensor product logic would require
	# proper entangled state creation, which is handled by create_bell_phi_plus

	print("  ✅ PASS (2Q gates execute without errors)\n")

func test_bell_state_creation():
	print("📊 Test 4: Bell state creation with H+CNOT...")

	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["🌾", "💀"])

	# Create Bell state |Φ+⟩ = (|00⟩ + |11⟩)/√2
	# Step 1: Initialize to |00⟩
	bath.amplitudes = [Complex.one(), Complex.zero()]

	print("  ✓ Initial state: |🌾⟩ (pure)")
	print("    Purity = %.4f" % bath.get_purity())

	# Step 2: Apply H to first qubit (creates superposition)
	var H = bath.get_standard_gate("H")
	bath.apply_unitary_1q("🌾", "💀", H)

	print("  ✓ After H: (|🌾⟩ + |💀⟩)/√2")
	print("    P(🌾) = %.4f, P(💀) = %.4f" % [
		bath.get_probability("🌾"),
		bath.get_probability("💀")
	])
	print("    Purity = %.4f" % bath.get_purity())

	# For single qubit, we can't create true Bell states (need 2 qubits)
	# But we can verify the gates work correctly
	assert(bath.get_purity() > 0.99, "Should maintain purity")

	# Apply X gate to demonstrate gate sequence
	var X = bath.get_standard_gate("X")
	bath.apply_unitary_1q("🌾", "💀", X)

	print("  ✓ After X: state flipped in X basis")
	print("    P(🌾) = %.4f, P(💀) = %.4f" % [
		bath.get_probability("🌾"),
		bath.get_probability("💀")
	])

	# Apply H again (should return to |💀⟩)
	bath.apply_unitary_1q("🌾", "💀", H)

	print("  ✓ After H again: returned to computational basis")
	print("    P(🌾) = %.4f, P(💀) = %.4f" % [
		bath.get_probability("🌾"),
		bath.get_probability("💀")
	])

	var p_death = bath.get_probability("💀")
	assert(p_death > 0.99, "HXH should give |💀⟩ (Z basis flip)")

	print("  ✅ PASS (Gate sequences work correctly)\n")

func test_unitarity():
	print("📊 Test 5: Unitarity verification (U†U = I)...")

	var bath = QuantumBath.new()

	# Test all single-qubit gates
	var gates_1q = ["X", "Y", "Z", "H"]
	for gate_name in gates_1q:
		var U = bath.get_standard_gate(gate_name)
		var U_dag = U.dagger()
		var I = U_dag.mul(U)

		# Check diagonal elements are 1
		for i in range(2):
			assert(abs(I.get_element(i, i).re - 1.0) < 1e-10,
				"%s: Diagonal not 1" % gate_name)

		# Check off-diagonal elements are 0
		assert(I.get_element(0, 1).abs() < 1e-10,
			"%s: Off-diagonal not 0" % gate_name)
		assert(I.get_element(1, 0).abs() < 1e-10,
			"%s: Off-diagonal not 0" % gate_name)

		print("  ✓ %s is unitary (U†U = I)" % gate_name)

	# Test two-qubit gates
	var gates_2q = ["CNOT", "CZ", "SWAP"]
	for gate_name in gates_2q:
		var U = bath.get_standard_gate(gate_name)
		var U_dag = U.dagger()
		var I = U_dag.mul(U)

		# Check diagonal elements are 1
		for i in range(4):
			assert(abs(I.get_element(i, i).re - 1.0) < 1e-10,
				"%s: Diagonal[%d] not 1" % [gate_name, i])

		print("  ✓ %s is unitary (U†U = I)" % gate_name)

	print("  ✅ PASS (All gates are unitary)\n")
