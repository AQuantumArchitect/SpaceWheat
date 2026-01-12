extends Node

## Minimal test for GDExtension loading - bypasses BootManager completely
## Run with: godot --path . -s Tests/test_native_minimal.gd

const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")

func _ready():
	print("")
	print("═══════════════════════════════════════════════════════")
	print("  MINIMAL NATIVE GDEXTENSION TEST")
	print("  (Bypasses BootManager)")
	print("═══════════════════════════════════════════════════════")
	print("")

	# Test 1: Direct ClassDB check
	print("--- Test 1: ClassDB Check ---")
	var class_exists = ClassDB.class_exists("QuantumMatrixNative")
	print("  ClassDB.class_exists('QuantumMatrixNative'): %s" % class_exists)

	if class_exists:
		print("  ✅ GDExtension LOADED")

		# Test 2: Instantiate native class
		print("")
		print("--- Test 2: Native Instantiation ---")
		var native = ClassDB.instantiate("QuantumMatrixNative")
		print("  Instantiated: %s" % (native != null))
		print("  Type: %s" % (native.get_class() if native else "null"))

		# Test 3: Call native methods
		if native:
			print("")
			print("--- Test 3: Native Method Calls ---")

			# Create test data
			var packed = PackedFloat64Array()
			packed.resize(8)  # 2x2 matrix * 2 (re/im)
			packed[0] = 1.0; packed[1] = 0.0  # (0,0) = 1+0i
			packed[2] = 0.0; packed[3] = 0.0  # (0,1) = 0
			packed[4] = 0.0; packed[5] = 0.0  # (1,0) = 0
			packed[6] = 1.0; packed[7] = 0.0  # (1,1) = 1+0i (identity)

			native.from_packed(packed, 2)
			print("  from_packed() called successfully")

			var dim = native.get_dimension()
			print("  get_dimension(): %d" % dim)

			var trace_re = native.trace_real()
			print("  trace_real(): %.3f (expected: 2.0)" % trace_re)

			# Test multiplication
			var result = native.mul(packed, 2)
			print("  mul() returned array size: %d (expected: 8)" % result.size())

			print("")
			print("  ✅ Native backend WORKING")
	else:
		print("  ❌ GDExtension NOT LOADED")
		print("")
		print("--- Debugging Info ---")

		# List all registered classes containing "Quantum" or "Matrix"
		var all_classes = ClassDB.get_class_list()
		var quantum_classes = []
		for cls in all_classes:
			if "Quantum" in cls or "Matrix" in cls:
				quantum_classes.append(cls)

		if quantum_classes.size() > 0:
			print("  Classes containing 'Quantum' or 'Matrix':")
			for cls in quantum_classes:
				print("    - %s" % cls)
		else:
			print("  No classes containing 'Quantum' or 'Matrix' found")

		# Check if .gdextension file exists
		print("")
		print("  .gdextension file check:")
		if FileAccess.file_exists("res://quantum_matrix.gdextension"):
			print("    ✅ quantum_matrix.gdextension exists")
		else:
			print("    ❌ quantum_matrix.gdextension NOT FOUND")

		# Check if .so file exists
		print("")
		print("  Native library check:")
		if FileAccess.file_exists("res://native/bin/libquantummatrix.linux.template_release.x86_64.so"):
			print("    ✅ .so file exists")
		else:
			print("    ❌ .so file NOT FOUND")

	# Test 4: ComplexMatrix wrapper detection
	print("")
	print("--- Test 4: ComplexMatrix Wrapper ---")
	ComplexMatrix._native_checked = false  # Force recheck
	var is_native = ComplexMatrix.is_native_available()
	print("  ComplexMatrix.is_native_available(): %s" % is_native)

	# Test 5: Performance comparison if native available
	if is_native:
		print("")
		print("--- Test 5: Performance Benchmark ---")
		_run_benchmark()

	print("")
	print("═══════════════════════════════════════════════════════")
	print("  TEST COMPLETE")
	print("═══════════════════════════════════════════════════════")
	print("")

	# Auto-quit after 2 seconds
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()

func _run_benchmark():
	var sizes = [4, 8, 16]

	for size in sizes:
		var A = _random_matrix(size)
		var B = _random_matrix(size)

		# Benchmark mul
		var start = Time.get_ticks_usec()
		for i in range(10):
			var C = A.mul(B)
		var elapsed = (Time.get_ticks_usec() - start) / 10.0

		print("  %dx%d mul: %.1f μs" % [size, size, elapsed])

func _random_matrix(dim: int) -> ComplexMatrix:
	var m = ComplexMatrix.new(dim)
	for i in range(dim * dim):
		m._data[i] = Complex.new(randf() * 2.0 - 1.0, randf() * 2.0 - 1.0)
	return m
