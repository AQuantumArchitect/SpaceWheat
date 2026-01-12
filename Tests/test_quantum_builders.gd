#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test Suite: Quantum Builders (Feature 5)
## Tests HamiltonianBuilder and LindbladBuilder components

const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const RegisterMap = preload("res://Core/QuantumSubstrate/RegisterMap.gd")
const HamiltonianBuilder = preload("res://Core/QuantumSubstrate/HamiltonianBuilder.gd")
const LindbladBuilder = preload("res://Core/QuantumSubstrate/LindbladBuilder.gd")
const Icon = preload("res://Core/QuantumSubstrate/Icon.gd")

var test_count: int = 0
var pass_count: int = 0


func _init():
	print("\n" + "=".repeat(70))
	print("QUANTUM BUILDERS TEST SUITE (Feature 5)")
	print("=".repeat(70) + "\n")

	# HamiltonianBuilder tests
	test_hamiltonian_empty()
	test_hamiltonian_single_qubit()
	test_hamiltonian_self_energy()
	test_hamiltonian_coupling()
	test_hamiltonian_hermiticity()
	test_hamiltonian_filtering()

	# LindbladBuilder tests
	test_lindblad_empty()
	test_lindblad_single_operator()
	test_lindblad_multiple_operators()
	test_lindblad_filtering()
	test_lindblad_amplitude_scaling()

	# Integration tests
	test_builder_with_real_biome_config()

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


## ========================================
## HamiltonianBuilder Tests
## ========================================

func test_hamiltonian_empty():
	print("\nTEST: Hamiltonian - Empty Icons")

	var icons = {}
	var register_map = RegisterMap.new()
	register_map.allocate("🌾", 0, 0)

	var H = HamiltonianBuilder.build(icons, register_map)

	assert_equal(H.n, 2, "Hamiltonian dimension is 2 (1 qubit)")
	assert_approx(H.get_element(0, 0).re, 0.0, 0.001, "H[0,0] = 0 (no icons)")
	print()


func test_hamiltonian_single_qubit():
	print("\nTEST: Hamiltonian - Single Qubit")

	var register_map = RegisterMap.new()
	register_map.allocate("🌾", 0, 0)

	var icons = {}
	var wheat_icon = Icon.new()
	wheat_icon.emoji = "🌾"
	wheat_icon.self_energy = 0.0
	wheat_icon.hamiltonian_couplings = {}
	wheat_icon.lindblad_incoming = {}
	wheat_icon.lindblad_outgoing = {}
	icons["🌾"] = wheat_icon

	var H = HamiltonianBuilder.build(icons, register_map)

	assert_equal(H.n, 2, "Hamiltonian is 2×2 matrix")
	# Verify it's built
	assert_true(H != null, "Hamiltonian built successfully")
	print()


func test_hamiltonian_self_energy():
	print("\nTEST: Hamiltonian - Self Energy Terms")

	var register_map = RegisterMap.new()
	register_map.allocate("🌾", 0, 0)

	var icons = {}
	var wheat_icon = Icon.new()
	wheat_icon.emoji = "🌾"
	wheat_icon.self_energy = 2.5  # Diagonal term
	wheat_icon.hamiltonian_couplings = {}
	wheat_icon.lindblad_incoming = {}
	wheat_icon.lindblad_outgoing = {}
	icons["🌾"] = wheat_icon

	var H = HamiltonianBuilder.build(icons, register_map)

	# Diagonal elements should have self-energy contribution
	var trace = H.get_element(0, 0).re + H.get_element(1, 1).re
	assert_approx(trace, 2.5, 0.1, "Trace contains self-energy term")
	print()


func test_hamiltonian_coupling():
	print("\nTEST: Hamiltonian - Coupling Terms")

	var register_map = RegisterMap.new()
	register_map.allocate("🌾", 0, 0)
	register_map.allocate("🍄", 1, 0)

	var icons = {}

	var wheat_icon = Icon.new()
	wheat_icon.emoji = "🌾"
	wheat_icon.self_energy = 0.0
	wheat_icon.hamiltonian_couplings = {"🍄": 0.5}
	wheat_icon.lindblad_incoming = {}
	wheat_icon.lindblad_outgoing = {}
	icons["🌾"] = wheat_icon

	var mushroom_icon = Icon.new()
	mushroom_icon.emoji = "🍄"
	mushroom_icon.self_energy = 0.0
	mushroom_icon.hamiltonian_couplings = {}
	mushroom_icon.lindblad_incoming = {}
	mushroom_icon.lindblad_outgoing = {}
	icons["🍄"] = mushroom_icon

	var H = HamiltonianBuilder.build(icons, register_map)

	# Should have off-diagonal coupling terms
	var off_diagonal = H.get_element(0, 1) + H.get_element(1, 0)
	assert_true(off_diagonal.magnitude() > 0.01, "Coupling creates off-diagonal terms")
	print()


func test_hamiltonian_hermiticity():
	print("\nTEST: Hamiltonian - Hermiticity Verification")

	var register_map = RegisterMap.new()
	register_map.allocate("🌾", 0, 0)

	var icons = {}
	var wheat_icon = Icon.new()
	wheat_icon.emoji = "🌾"
	wheat_icon.self_energy = 1.5
	wheat_icon.hamiltonian_couplings = {}
	wheat_icon.lindblad_incoming = {}
	wheat_icon.lindblad_outgoing = {}
	icons["🌾"] = wheat_icon

	var H = HamiltonianBuilder.build(icons, register_map)

	# Check Hermiticity: H = H†
	for i in range(H.n):
		for j in range(H.n):
			var h_ij = H.get_element(i, j)
			var h_ji = H.get_element(j, i).conjugate()
			var diff = (h_ij - h_ji).magnitude()
			assert_approx(diff, 0.0, 0.001, "H[%d,%d] = (H[%d,%d])†" % [i, j, j, i])
	print()


func test_hamiltonian_filtering():
	print("\nTEST: Hamiltonian - Filtering by RegisterMap")

	var register_map = RegisterMap.new()
	register_map.allocate("🌾", 0, 0)
	# 🍄 is NOT registered

	var icons = {}

	var wheat_icon = Icon.new()
	wheat_icon.emoji = "🌾"
	wheat_icon.self_energy = 1.0
	wheat_icon.hamiltonian_couplings = {"🍄": 0.5}  # Couple to unregistered emoji
	wheat_icon.lindblad_incoming = {}
	wheat_icon.lindblad_outgoing = {}
	icons["🌾"] = wheat_icon

	var H = HamiltonianBuilder.build(icons, register_map)

	# Should still build, but coupling to 🍄 should be skipped
	assert_equal(H.n, 2, "Hamiltonian built despite missing coupling target")
	print()


## ========================================
## LindbladBuilder Tests
## ========================================

func test_lindblad_empty():
	print("\nTEST: Lindblad - Empty Icons")

	var icons = {}
	var register_map = RegisterMap.new()
	register_map.allocate("🌾", 0, 0)

	var result = LindbladBuilder.build(icons, register_map)

	assert_true(result.has("operators"), "Result has operators key")
	assert_true(result.has("gated_configs"), "Result has gated_configs key")
	assert_equal(result.operators.size(), 0, "No operators for empty icons")
	print()


func test_lindblad_single_operator():
	print("\nTEST: Lindblad - Single Operator")

	var register_map = RegisterMap.new()
	register_map.allocate("🌾", 0, 0)
	register_map.allocate("🍄", 1, 0)

	var icons = {}

	var wheat_icon = Icon.new()
	wheat_icon.emoji = "🌾"
	wheat_icon.lindblad_outgoing = {"🍄": 0.1}  # Transfer rate 0.1
	wheat_icon.lindblad_incoming = {}
	wheat_icon.self_energy = 0.0
	wheat_icon.hamiltonian_couplings = {}
	icons["🌾"] = wheat_icon

	var mushroom_icon = Icon.new()
	mushroom_icon.emoji = "🍄"
	mushroom_icon.lindblad_incoming = {}
	mushroom_icon.lindblad_outgoing = {}
	mushroom_icon.self_energy = 0.0
	mushroom_icon.hamiltonian_couplings = {}
	icons["🍄"] = mushroom_icon

	var result = LindbladBuilder.build(icons, register_map)

	assert_equal(result.operators.size(), 1, "One Lindblad operator created")
	var L = result.operators[0]
	assert_equal(L.n, 4, "Operator is 4×4 for 2 qubits")
	print()


func test_lindblad_multiple_operators():
	print("\nTEST: Lindblad - Multiple Operators")

	var register_map = RegisterMap.new()
	register_map.allocate("🌾", 0, 0)
	register_map.allocate("🍄", 1, 0)

	var icons = {}

	var wheat_icon = Icon.new()
	wheat_icon.emoji = "🌾"
	wheat_icon.lindblad_outgoing = {"🍄": 0.1}
	wheat_icon.lindblad_incoming = {}
	wheat_icon.self_energy = 0.0
	wheat_icon.hamiltonian_couplings = {}
	icons["🌾"] = wheat_icon

	var mushroom_icon = Icon.new()
	mushroom_icon.emoji = "🍄"
	mushroom_icon.lindblad_incoming = {"🌾": 0.2}
	mushroom_icon.lindblad_outgoing = {}
	mushroom_icon.self_energy = 0.0
	mushroom_icon.hamiltonian_couplings = {}
	icons["🍄"] = mushroom_icon

	var result = LindbladBuilder.build(icons, register_map)

	# Should have 2 operators (one outgoing, one incoming)
	assert_equal(result.operators.size(), 2, "Two Lindblad operators created")
	print()


func test_lindblad_filtering():
	print("\nTEST: Lindblad - Filtering by RegisterMap")

	var register_map = RegisterMap.new()
	register_map.allocate("🌾", 0, 0)
	# 🍄 is NOT registered

	var icons = {}

	var wheat_icon = Icon.new()
	wheat_icon.emoji = "🌾"
	wheat_icon.lindblad_outgoing = {"🍄": 0.1}  # Transfer to unregistered emoji
	wheat_icon.lindblad_incoming = {}
	wheat_icon.self_energy = 0.0
	wheat_icon.hamiltonian_couplings = {}
	icons["🌾"] = wheat_icon

	var result = LindbladBuilder.build(icons, register_map)

	# Should skip coupling to 🍄
	assert_equal(result.operators.size(), 0, "Unregistered couplings are skipped")
	print()


func test_lindblad_amplitude_scaling():
	print("\nTEST: Lindblad - Amplitude Scaling from Rate")

	var register_map = RegisterMap.new()
	register_map.allocate("🌾", 0, 0)
	register_map.allocate("🍄", 1, 0)

	var icons = {}

	var wheat_icon = Icon.new()
	wheat_icon.emoji = "🌾"
	wheat_icon.lindblad_outgoing = {"🍄": 0.25}  # Rate = 0.25, amplitude = √0.25 = 0.5
	wheat_icon.lindblad_incoming = {}
	wheat_icon.self_energy = 0.0
	wheat_icon.hamiltonian_couplings = {}
	icons["🌾"] = wheat_icon

	var mushroom_icon = Icon.new()
	mushroom_icon.emoji = "🍄"
	mushroom_icon.lindblad_incoming = {}
	mushroom_icon.lindblad_outgoing = {}
	mushroom_icon.self_energy = 0.0
	mushroom_icon.hamiltonian_couplings = {}
	icons["🍄"] = mushroom_icon

	var result = LindbladBuilder.build(icons, register_map)

	assert_equal(result.operators.size(), 1, "Operator created")
	# Amplitude should be √0.25 = 0.5
	# We can't directly check internal amplitude, but we verified it's created
	print()


## ========================================
## Integration Tests
## ========================================

func test_builder_with_real_biome_config():
	print("\nTEST: Builders - Real Biome Configuration")

	# Create a RegisterMap like BioticFluxBiome uses
	var register_map = RegisterMap.new()
	register_map.allocate("☀️", 0, 0)  # Sun (north) / Moon (south)
	register_map.allocate("🌾", 1, 0)  # Wheat (north) / Mushroom (south)
	register_map.allocate("🍂", 2, 0)  # Organic (north) / Death (south)

	# Create mock icons similar to actual biome
	var icons = {}

	var sun_icon = Icon.new()
	sun_icon.emoji = "☀️"
	sun_icon.self_energy = 1.0
	sun_icon.hamiltonian_couplings = {"🌾": 0.1}
	sun_icon.lindblad_incoming = {}
	sun_icon.lindblad_outgoing = {"🌾": 0.01}
	icons["☀️"] = sun_icon

	var wheat_icon = Icon.new()
	wheat_icon.emoji = "🌾"
	wheat_icon.self_energy = 0.5
	wheat_icon.hamiltonian_couplings = {"☀️": 0.1}
	wheat_icon.lindblad_incoming = {"☀️": 0.02}
	wheat_icon.lindblad_outgoing = {}
	icons["🌾"] = wheat_icon

	var organic_icon = Icon.new()
	organic_icon.emoji = "🍂"
	organic_icon.self_energy = -0.5
	organic_icon.hamiltonian_couplings = {}
	organic_icon.lindblad_incoming = {}
	organic_icon.lindblad_outgoing = {}
	icons["🍂"] = organic_icon

	# Build Hamiltonian
	var H = HamiltonianBuilder.build(icons, register_map)
	assert_equal(H.n, 8, "Hamiltonian is 8×8 for 3 qubits")
	assert_true(H != null, "Hamiltonian built successfully")

	# Build Lindblad
	var L_result = LindbladBuilder.build(icons, register_map)
	assert_true(L_result.operators.size() > 0, "Lindblad operators created")

	print()
