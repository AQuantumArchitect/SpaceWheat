extends SceneTree

## Benchmark: Pure GDScript vs Native Eigen
## Compares performance of matrix operations with and without native acceleration

const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")

func _init():
	print("")
	print("═══════════════════════════════════════════════════════════════")
	print("  BENCHMARK: Pure GDScript vs Native Eigen")
	print("═══════════════════════════════════════════════════════════════")
	print("")

	# Check current status
	var is_native = ComplexMatrix.is_native_available()
	print("Current backend: %s" % ("Native (Eigen)" if is_native else "Pure GDScript"))
	print("")

	if not is_native:
		print("ERROR: Native backend not available!")
		print("Cannot run comparison benchmark.")
		print("")
		quit()
		return

	# Run benchmarks for different matrix sizes
	print("Running benchmarks for matrix operations...")
	print("")
	print("┌──────────┬─────────────────┬─────────────────┬──────────┐")
	print("│   Size   │   GDScript (μs) │    Native (μs)  │  Speedup │")
	print("├──────────┼─────────────────┼─────────────────┼──────────┤")

	for size in [2, 4, 8, 16, 24, 32]:
		benchmark_size(size)

	print("└──────────┴─────────────────┴─────────────────┴──────────┘")
	print("")

	# Test game-relevant operations
	print("═══════════════════════════════════════════════════════════════")
	print("  Game-Relevant Operations (Biome Simulation)")
	print("═══════════════════════════════════════════════════════════════")
	print("")

	benchmark_biome_operations()

	print("")
	print("═══════════════════════════════════════════════════════════════")
	print("  BENCHMARK COMPLETE")
	print("═══════════════════════════════════════════════════════════════")
	print("")

	quit()

func benchmark_size(size: int):
	var A = _random_hermitian(size)
	var B = _random_hermitian(size)

	# Get native backend
	var native = A._get_native()
	if not native:
		print("│ %2dx%2d    │      ERROR      │      ERROR      │    -     │" % [size, size])
		return

	# Benchmark multiplication with NATIVE
	var native_time = _benchmark_native_mul(A, B, native, 10)

	# Benchmark multiplication with GDSCRIPT (force fallback)
	var gdscript_time = _benchmark_gdscript_mul(A, B, 10)

	var speedup = gdscript_time / native_time if native_time > 0 else 0.0

	print("│ %2dx%2d    │ %15.1f │ %15.1f │ %7.1fx │" % [
		size, size,
		gdscript_time,
		native_time,
		speedup
	])

func _benchmark_native_mul(A: ComplexMatrix, B: ComplexMatrix, native, iterations: int) -> float:
	var start = Time.get_ticks_usec()

	for i in range(iterations):
		# Sync to native and multiply
		native.from_packed(A._to_packed(), A.n)
		var result_packed = native.mul(B._to_packed(), A.n)
		var result = A._result_from_packed(result_packed, A.n)

	var elapsed = Time.get_ticks_usec() - start
	return elapsed / float(iterations)

func _benchmark_gdscript_mul(A: ComplexMatrix, B: ComplexMatrix, iterations: int) -> float:
	var start = Time.get_ticks_usec()

	for i in range(iterations):
		# Pure GDScript multiplication (O(n³))
		var result = ComplexMatrix.new(A.n)
		for i_row in range(A.n):
			for j_col in range(A.n):
				var sum = Complex.zero()
				for k in range(A.n):
					sum = sum.add(A.get_element(i_row, k).mul(B.get_element(k, j_col)))
				result.set_element(i_row, j_col, sum)

	var elapsed = Time.get_ticks_usec() - start
	return elapsed / float(iterations)

func benchmark_biome_operations():
	print("Testing operations used in biome quantum simulations...")
	print("")

	# Typical biome: 3-5 qubits = 8-32 dimensional density matrix
	var sizes = {
		"BioticFlux (3 qubits)": 8,
		"Forest (5 qubits)": 32,
		"Market (3 qubits)": 8,
		"Kitchen (4 qubits)": 16
	}

	for biome_name in sizes:
		var dim = sizes[biome_name]
		print("  %s → %dx%d density matrix" % [biome_name, dim, dim])

		# Simulate typical evolution step
		var rho = _random_density_matrix(dim)
		var H = _random_hermitian(dim)

		# Hamiltonian evolution: U = exp(-iHt)
		var native = rho._get_native()
		if native:
			var start = Time.get_ticks_usec()

			# Scale Hamiltonian by timestep
			var Ht = H.scale(Complex.new(0.0, -0.1))  # dt = 0.1

			# Compute exponential (native)
			native.from_packed(Ht._to_packed(), Ht.n)
			var U_packed = native.expm()
			var U = rho._result_from_packed(U_packed, dim)

			# Apply: rho' = U * rho * U†
			var U_dag_packed = native.dagger()
			var U_dag = rho._result_from_packed(U_dag_packed, dim)

			native.from_packed(U._to_packed(), U.n)
			var temp_packed = native.mul(rho._to_packed(), rho.n)
			var temp = rho._result_from_packed(temp_packed, dim)

			native.from_packed(temp._to_packed(), temp.n)
			var rho_new_packed = native.mul(U_dag._to_packed(), U_dag.n)

			var elapsed = Time.get_ticks_usec() - start
			print("    Native evolution step: %.1f μs" % elapsed)
		else:
			print("    ERROR: Native not available")

	print("")

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

func _random_density_matrix(dim: int) -> ComplexMatrix:
	# Create random positive semidefinite matrix
	var m = _random_hermitian(dim)
	# Make positive: M = A * A†
	var result = m.mul(m.dagger())
	# Normalize trace to 1
	var tr = result.trace()
	var tr_val = sqrt(tr.re * tr.re + tr.im * tr.im)
	if tr_val > 1e-10:
		result = result.scale_real(1.0 / tr_val)
	return result
