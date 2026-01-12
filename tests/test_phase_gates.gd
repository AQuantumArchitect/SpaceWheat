#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: Phase Gates Exposure
## Tests that Y, S, T gates are properly exposed to players via Tool 5 menu system

const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const QuantumGateLibrary = preload("res://Core/QuantumSubstrate/QuantumGateLibrary.gd")

var passed := 0
var failed := 0

func _initialize():
	print("\n" + "=".repeat(80))
	print("🔬 PHASE GATES EXPOSURE TEST")
	print("=".repeat(80))

	await get_root().ready

	# Run all tests
	test_phase_gates_submenu_exists()
	test_phase_gates_submenu_actions()
	test_tool5_submenu_routing()
	test_single_gates_submenu_renamed()
	test_two_gates_submenu_intact()
	test_quantum_gate_library_complete()
	test_gate_dimensions()
	test_gate_hermiticity()

	# Print summary
	print("\n" + "=".repeat(80))
	print("📊 RESULTS: %d passed, %d failed" % [passed, failed])
	print("=".repeat(80))

	if failed == 0:
		print("✅ ALL TESTS PASSED")
	else:
		print("❌ SOME TESTS FAILED")

	quit(1 if failed > 0 else 0)


## Test 1: Verify phase_gates submenu exists in ToolConfig
func test_phase_gates_submenu_exists():
	print("\n📍 Test 1: phase_gates submenu exists")
	var submenu = ToolConfig.get_submenu("phase_gates")

	check(submenu != null, "phase_gates submenu should exist")
	check(submenu.has("name"), "submenu should have 'name' field")
	check(submenu.get("name") == "Phase Gates", "submenu name should be 'Phase Gates'")


## Test 2: Verify phase_gates submenu has Y, S, T actions
func test_phase_gates_submenu_actions():
	print("\n📍 Test 2: phase_gates submenu has Y, S, T actions")
	var submenu = ToolConfig.get_submenu("phase_gates")

	# Check Y gate
	check(submenu.has("Q"), "submenu should have Q action")
	var y_action = submenu.get("Q", {})
	check(y_action.get("action") == "apply_pauli_y", "Q should map to apply_pauli_y")
	check(y_action.get("label") == "Pauli-Y", "Q label should be 'Pauli-Y'")
	check(y_action.get("emoji") == "🔄", "Q emoji should be 🔄")

	# Check S gate
	check(submenu.has("E"), "submenu should have E action")
	var s_action = submenu.get("E", {})
	check(s_action.get("action") == "apply_s_gate", "E should map to apply_s_gate")
	check(s_action.get("label") == "S-Gate (π/2)", "E label should be 'S-Gate (π/2)'")
	check(s_action.get("emoji") == "🌊", "E emoji should be 🌊")

	# Check T gate
	check(submenu.has("R"), "submenu should have R action")
	var t_action = submenu.get("R", {})
	check(t_action.get("action") == "apply_t_gate", "R should map to apply_t_gate")
	check(t_action.get("label") == "T-Gate (π/4)", "R label should be 'T-Gate (π/4)'")
	check(t_action.get("emoji") == "✨", "R emoji should be ✨")


## Test 3: Verify Tool 5 menu routing is correct
func test_tool5_submenu_routing():
	print("\n📍 Test 3: Tool 5 submenu routing")
	var tool_5 = ToolConfig.get_tool(5)

	# Check Q action
	var q_action = tool_5.get("Q", {})
	check(q_action.get("action") == "submenu_single_gates", "Q should route to single_gates submenu")
	check(q_action.get("submenu") == "single_gates", "Q submenu field should be 'single_gates'")

	# Check E action (should be phase_gates)
	var e_action = tool_5.get("E", {})
	check(e_action.get("action") == "submenu_phase_gates", "E should route to phase_gates submenu")
	check(e_action.get("submenu") == "phase_gates", "E submenu field should be 'phase_gates'")
	check(e_action.get("label") == "Phase Gates ▸", "E label should be 'Phase Gates ▸'")

	# Check R action (2-Qubit Gates)
	var r_action = tool_5.get("R", {})
	check(r_action.get("action") == "submenu_two_gates", "R should route to two_gates submenu")
	check(r_action.get("submenu") == "two_gates", "R submenu field should be 'two_gates'")
	check(r_action.get("label") == "2-Qubit ▸", "R label should be '2-Qubit ▸'")


## Test 4: Verify single_gates submenu name changed
func test_single_gates_submenu_renamed():
	print("\n📍 Test 4: single_gates submenu renamed")
	var submenu = ToolConfig.get_submenu("single_gates")
	check(submenu.get("name") == "Basic 1-Qubit Gates", "single_gates name should be 'Basic 1-Qubit Gates'")


## Test 5: Verify two_gates submenu still intact
func test_two_gates_submenu_intact():
	print("\n📍 Test 5: two_gates submenu intact")
	var submenu = ToolConfig.get_submenu("two_gates")

	check(submenu != null, "two_gates submenu should exist")
	check(submenu.has("Q"), "should have Q action")
	check(submenu["Q"]["action"] == "apply_cnot", "Q should be CNOT")
	check(submenu.has("E"), "should have E action")
	check(submenu["E"]["action"] == "apply_cz", "E should be CZ")
	check(submenu.has("R"), "should have R action")
	check(submenu["R"]["action"] == "apply_swap", "R should be SWAP")


## Test 6: Verify gate library has all gates
func test_quantum_gate_library_complete():
	print("\n📍 Test 6: QuantumGateLibrary completeness")
	var gate_lib = QuantumGateLibrary.new()

	# Check all single-qubit gates exist
	for gate_name in ["X", "Y", "Z", "H", "S", "T"]:
		check(gate_lib.GATES.has(gate_name), "Gate library should have %s gate" % gate_name)

	# Check all 2-qubit gates exist
	for gate_name in ["CNOT", "CZ", "SWAP"]:
		check(gate_lib.GATES.has(gate_name), "Gate library should have %s gate" % gate_name)


## Test 7: Verify gate matrices are 2x2
func test_gate_dimensions():
	print("\n📍 Test 7: Gate matrix dimensions")
	var gate_lib = QuantumGateLibrary.new()

	for gate_name in ["X", "Y", "Z", "H", "S", "T"]:
		var gate_matrix = gate_lib.GATES[gate_name].get("matrix")
		check(gate_matrix != null, "Gate %s should have matrix" % gate_name)
		if gate_matrix:
			check(gate_matrix.n == 2, "Gate %s should be 2x2" % gate_name)


## Test 8: Verify Pauli gates are Hermitian
func test_gate_hermiticity():
	print("\n📍 Test 8: Pauli gate Hermiticity")
	var gate_lib = QuantumGateLibrary.new()

	# X, Y, Z should be Hermitian (self-adjoint)
	for gate_name in ["X", "Y", "Z"]:
		var matrix = gate_lib.GATES[gate_name].get("matrix")
		if matrix and matrix.has_method("is_hermitian"):
			check(matrix.is_hermitian(), "Gate %s should be Hermitian" % gate_name)
		else:
			print("  ⚠️  Skipping Hermiticity check for %s (no is_hermitian method)" % gate_name)


## Helper: Check condition and track pass/fail
func check(condition: bool, message: String) -> void:
	if condition:
		print("  ✅ %s" % message)
		passed += 1
	else:
		print("  ❌ %s" % message)
		failed += 1
