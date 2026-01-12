extends Node

## Quick test to verify native backend in interactive mode

const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")

func _ready():
	print("\n=== INTERACTIVE MODE TEST ===\n")

	# Test 1: Native backend
	print("Native available: %s" % ComplexMatrix.is_native_available())

	# Test 2: IconRegistry access
	var icon_reg = get_node_or_null("IconRegistry")
	if icon_reg:
		print("IconRegistry found: YES")
		print("Icons registered: %d" % icon_reg.icons.size())
	else:
		print("IconRegistry found: NO")

	# Test 3: QuantumGateLibrary access
	var gate_lib = load("res://Core/QuantumSubstrate/QuantumGateLibrary.gd").new()
	if gate_lib:
		print("QuantumGateLibrary instantiated: YES")
		# Try different API signatures
		var X_1arg = gate_lib.get_gate("X")
		print("  get_gate('X') works: %s" % (X_1arg != null))

		# Check if method accepts dimension as param
		var methods = gate_lib.get_method_list()
		for method in methods:
			if method.name == "get_gate":
				print("  get_gate parameters: %d" % method.args.size())
	else:
		print("QuantumGateLibrary instantiated: NO")

	# Test 4: Native matrix operations
	var A = ComplexMatrix.new(4)
	var B = ComplexMatrix.new(4)
	for i in range(16):
		A._data[i] = Complex.new(randf(), randf())
		B._data[i] = Complex.new(randf(), randf())
	var C = A.mul(B)
	print("4x4 mul result dimension: %d" % C.n)

	print("\n=== TEST COMPLETE ===\n")
	# Don't quit so we can see output

