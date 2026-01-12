extends SceneTree

## Native Matrix Performance Benchmark
## Measures speedup of native Eigen backend vs GDScript

const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")

const WARMUP_ITERATIONS := 2
const BENCHMARK_ITERATIONS := 5

func _init():
	print("\n═══ NATIVE MATRIX PERFORMANCE BENCHMARK ═══")
	print("Backend: %s\n" % ("Native (Eigen)" if ComplexMatrix.is_native_available() else "GDScript"))

	print("Size | Operation  | Time (us) | Speedup vs baseline")
	print("-----|------------|-----------|--------------------")

	# Benchmark different matrix sizes
	for size in [4, 8, 12, 16]:
		benchmark_size(size)

	print("\n═══ BENCHMARK COMPLETE ═══\n")
	quit()

func benchmark_size(size: int) -> void:
	var A = _random_hermitian(size)
	var B = _random_hermitian(size)

	# Baseline estimates (GDScript, approximate us per operation)
	# These are rough estimates for comparison
	var baseline = {
		"mul": size * size * size * 0.5,  # O(n^3) scaling
		"expm": size * size * size * 10.0,  # Much more complex
		"inverse": size * size * size * 2.0,
		"eigensystem": size * size * size * 50.0
	}

	# Warmup
	for i in range(WARMUP_ITERATIONS):
		var _w = A.mul(B)
		_w = A.expm()

	# mul benchmark
	var start = Time.get_ticks_usec()
	for i in range(BENCHMARK_ITERATIONS):
		var _c = A.mul(B)
	var mul_time = float(Time.get_ticks_usec() - start) / BENCHMARK_ITERATIONS
	var mul_speedup = baseline["mul"] / max(mul_time, 1.0)

	# expm benchmark
	start = Time.get_ticks_usec()
	for i in range(BENCHMARK_ITERATIONS):
		var _e = A.expm()
	var expm_time = float(Time.get_ticks_usec() - start) / BENCHMARK_ITERATIONS
	var expm_speedup = baseline["expm"] / max(expm_time, 1.0)

	# inverse benchmark
	start = Time.get_ticks_usec()
	for i in range(BENCHMARK_ITERATIONS):
		var _inv = A.inverse()
	var inverse_time = float(Time.get_ticks_usec() - start) / BENCHMARK_ITERATIONS
	var inverse_speedup = baseline["inverse"] / max(inverse_time, 1.0)

	# eigensystem benchmark (fewer iterations due to cost)
	start = Time.get_ticks_usec()
	for i in range(max(1, BENCHMARK_ITERATIONS / 2)):
		var _eig = A.eigensystem()
	var eigen_time = float(Time.get_ticks_usec() - start) / max(1, BENCHMARK_ITERATIONS / 2)
	var eigen_speedup = baseline["eigensystem"] / max(eigen_time, 1.0)

	# Print results
	print("%2dx%2d | mul        | %9.1f |" % [size, size, mul_time])
	print("     | expm       | %9.1f |" % [expm_time])
	print("     | inverse    | %9.1f |" % [inverse_time])
	print("     | eigensystem| %9.1f |" % [eigen_time])
	print("-----|------------|-----------|")

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
