## Test Phase 1: Unitary Gate Operations (Tool 5 Backend)
## Verifies that 1Q and 2Q gates work correctly

extends SceneTree

var QuantumComputer = preload("res://Core/QuantumSubstrate/QuantumComputer.gd")
var QuantumGateLibrary = preload("res://Core/QuantumSubstrate/QuantumGateLibrary.gd")

func _init():
	print("\n=== PHASE 1: UNITARY GATE OPERATIONS TEST ===\n")

	# Test 1: Single-qubit gates
	test_1q_gates()

	# Test 2: Two-qubit gates
	test_2q_gates()

	# Test 3: Component merging for 2Q gates
	test_component_merging()

	print("\n✅ Phase 1 Tests Passed!\n")
	quit()


func test_1q_gates() -> void:
	print("TEST 1: Single-Qubit Gates")
	print("----------------------------------------")

	# Create quantum computer
	var qc = QuantumComputer.new("test_biome")

	# Allocate two registers (isolated qubits)
	var reg0 = qc.allocate_register("🌾", "🌽")  # Register 0
	var reg1 = qc.allocate_register("👥", "🔥")  # Register 1

	print("✓ Allocated registers: ", reg0, ", ", reg1)

	# Get components
	var comp0 = qc.get_component_containing(reg0)
	var comp1 = qc.get_component_containing(reg1)

	print("✓ Components: ", comp0.component_id, " (reg0), ", comp1.component_id, " (reg1)")

	# Get initial purity
	var purity_before = comp0.get_purity(reg0)
	print("✓ Initial purity: ", "%.6f" % purity_before)

	# Apply Hadamard gate (creates superposition)
	var H = QuantumGateLibrary.get_gate("H")["matrix"]
	var success = qc.apply_unitary_1q(comp0, reg0, H)
	if not success:
		push_error("Failed to apply Hadamard gate!")
		return

	print("✓ Applied Hadamard gate to register ", reg0)

	# Check purity changed (Hadamard should maintain purity=1 for pure |0⟩)
	var purity_after = comp0.get_purity(reg0)
	print("✓ Purity after H: ", "%.6f" % purity_after)

	# Apply X gate (bit flip)
	var X = QuantumGateLibrary.get_gate("X")["matrix"]
	success = qc.apply_unitary_1q(comp0, reg0, X)
	if not success:
		push_error("Failed to apply X gate!")
		return

	print("✓ Applied X gate to register ", reg0)

	# Apply Z gate (phase flip)
	var Z = QuantumGateLibrary.get_gate("Z")["matrix"]
	success = qc.apply_unitary_1q(comp0, reg0, Z)
	if not success:
		push_error("Failed to apply Z gate!")
		return

	print("✓ Applied Z gate to register ", reg0)
	print()


func test_2q_gates() -> void:
	print("TEST 2: Two-Qubit Gates (Same Component)")
	print("----------------------------------------")

	# Create quantum computer
	var qc = QuantumComputer.new("test_biome")

	# Allocate two registers in same component
	var reg0 = qc.allocate_register("🌾", "🌽")
	var reg1 = qc.allocate_register("👥", "🔥")

	# Create Bell state (entangle them)
	var success = qc.entangle_plots(reg0, reg1)
	if not success:
		push_error("Failed to entangle plots!")
		return

	print("✓ Created Bell state between registers ", reg0, " and ", reg1)

	# Get merged component
	var comp = qc.get_component_containing(reg0)
	print("✓ Component ID after entanglement: ", comp.component_id)
	print("✓ Qubits in component: ", comp.register_ids)

	# Apply CNOT gate
	var CNOT = QuantumGateLibrary.get_gate("CNOT")["matrix"]
	success = qc.apply_unitary_2q(comp, reg0, reg1, CNOT)
	if not success:
		push_error("Failed to apply CNOT gate!")
		return

	print("✓ Applied CNOT gate (control=", reg0, ", target=", reg1, ")")

	# Apply CZ gate
	var CZ = QuantumGateLibrary.get_gate("CZ")["matrix"]
	success = qc.apply_unitary_2q(comp, reg0, reg1, CZ)
	if not success:
		push_error("Failed to apply CZ gate!")
		return

	print("✓ Applied CZ gate")

	# Apply SWAP gate
	var SWAP = QuantumGateLibrary.get_gate("SWAP")["matrix"]
	success = qc.apply_unitary_2q(comp, reg0, reg1, SWAP)
	if not success:
		push_error("Failed to apply SWAP gate!")
		return

	print("✓ Applied SWAP gate")
	print()


func test_component_merging() -> void:
	print("TEST 3: Component Merging for 2Q Gates")
	print("----------------------------------------")

	# Create quantum computer
	var qc = QuantumComputer.new("test_biome")

	# Allocate 4 registers (2 separate components initially)
	var reg0 = qc.allocate_register("🌾", "🌽")  # Component 0
	var reg1 = qc.allocate_register("👥", "🔥")  # Component 1
	var reg2 = qc.allocate_register("🔴", "⚪")  # Component 2
	var reg3 = qc.allocate_register("💧", "🌊")  # Component 3

	print("✓ Allocated 4 isolated registers: ", reg0, ", ", reg1, ", ", reg2, ", ", reg3)

	var comp0 = qc.get_component_containing(reg0)
	var comp1 = qc.get_component_containing(reg1)
	print("✓ Initial components separate: ", comp0.component_id, " vs ", comp1.component_id)

	# Merge components by applying 2Q gate
	var CNOT = QuantumGateLibrary.get_gate("CNOT")["matrix"]
	var success = qc.apply_unitary_2q(comp0, reg0, reg1, CNOT)
	if not success:
		push_error("Failed to merge components via 2Q gate!")
		return

	print("✓ Applied CNOT across components (auto-merged)")

	# Verify they're now in same component
	var comp0_new = qc.get_component_containing(reg0)
	var comp1_new = qc.get_component_containing(reg1)
	if comp0_new.component_id != comp1_new.component_id:
		push_error("Components not merged after 2Q gate!")
		return

	print("✓ Components merged: both now ", comp0_new.component_id)
	print("✓ Qubits in merged component: ", comp0_new.register_ids)
	print()
