extends SceneTree

## Comparative Benchmark: Native vs GDScript
## Measures actual speedup with both backends

const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")

const ITERATIONS := 3

func _init():
	print("\n═══ NATIVE vs GDSCRIPT COMPARISON ═══\n")

	# Test with 8x8 matrices (reasonable for comparison)
	var size := 8
	var A = _random_hermitian(size)
	var B = _random_hermitian(size)

	print("Testing %dx%d matrices with %d iterations each\n" % [size, size, ITERATIONS])

	# Test MUL
	print("--- Matrix Multiplication (mul) ---")
	var native_mul = benchmark_mul_native(A, B)
	var gdscript_mul = benchmark_mul_gdscript(A, B)
	print("Native:   %8.1f us" % native_mul)
	print("GDScript: %8.1f us" % gdscript_mul)
	print("Speedup:  %.1fx\n" % (gdscript_mul / max(native_mul, 1)))

	# Test EXPM
	print("--- Matrix Exponential (expm) ---")
	var native_expm = benchmark_expm_native(A)
	var gdscript_expm = benchmark_expm_gdscript(A)
	print("Native:   %8.1f us" % native_expm)
	print("GDScript: %8.1f us" % gdscript_expm)
	print("Speedup:  %.1fx\n" % (gdscript_expm / max(native_expm, 1)))

	# Test INVERSE
	print("--- Matrix Inverse ---")
	var native_inv = benchmark_inverse_native(A)
	var gdscript_inv = benchmark_inverse_gdscript(A)
	print("Native:   %8.1f us" % native_inv)
	print("GDScript: %8.1f us" % gdscript_inv)
	print("Speedup:  %.1fx\n" % (gdscript_inv / max(native_inv, 1)))

	print("═══ COMPARISON COMPLETE ═══\n")
	quit()

#region Native benchmarks (uses GDExtension)

func benchmark_mul_native(A: ComplexMatrix, B: ComplexMatrix) -> float:
	# Uses native path automatically
	var start = Time.get_ticks_usec()
	for i in range(ITERATIONS):
		var _c = A.mul(B)
	return float(Time.get_ticks_usec() - start) / ITERATIONS

func benchmark_expm_native(A: ComplexMatrix) -> float:
	var start = Time.get_ticks_usec()
	for i in range(ITERATIONS):
		var _e = A.expm()
	return float(Time.get_ticks_usec() - start) / ITERATIONS

func benchmark_inverse_native(A: ComplexMatrix) -> float:
	var start = Time.get_ticks_usec()
	for i in range(ITERATIONS):
		var _i = A.inverse()
	return float(Time.get_ticks_usec() - start) / ITERATIONS

#endregion

#region Pure GDScript benchmarks (bypasses native)

func benchmark_mul_gdscript(A: ComplexMatrix, B: ComplexMatrix) -> float:
	var start = Time.get_ticks_usec()
	for iter in range(ITERATIONS):
		# Direct GDScript O(n^3) implementation
		var result = ComplexMatrix.new(A.n)
		for i in range(A.n):
			for j in range(A.n):
				var sum = Complex.zero()
				for k in range(A.n):
					sum = sum.add(A.get_element(i, k).mul(B.get_element(k, j)))
				result.set_element(i, j, sum)
	return float(Time.get_ticks_usec() - start) / ITERATIONS

func benchmark_expm_gdscript(A: ComplexMatrix) -> float:
	var start = Time.get_ticks_usec()
	for iter in range(ITERATIONS):
		# Pure GDScript Pade approximation
		var norm = _one_norm_gs(A)
		var k = max(0, int(ceil(log(norm) / log(2.0))))
		var scaled = _scale_real_gs(A, 1.0 / pow(2.0, k))
		var pade = _pade_6_6_gs(scaled)
		for i in range(k):
			pade = _mul_gs(pade, pade)
	return float(Time.get_ticks_usec() - start) / ITERATIONS

func benchmark_inverse_gdscript(A: ComplexMatrix) -> float:
	var start = Time.get_ticks_usec()
	for iter in range(ITERATIONS):
		# Pure GDScript Gauss-Jordan
		var aug = []
		for i in range(A.n):
			var row = []
			for j in range(A.n):
				row.append(A.get_element(i, j))
			for j in range(A.n):
				row.append(Complex.one() if i == j else Complex.zero())
			aug.append(row)

		for pivot in range(A.n):
			var max_row = pivot
			var max_val = aug[pivot][pivot].abs()
			for i in range(pivot + 1, A.n):
				if aug[i][pivot].abs() > max_val:
					max_val = aug[i][pivot].abs()
					max_row = i

			if max_row != pivot:
				var temp = aug[pivot]
				aug[pivot] = aug[max_row]
				aug[max_row] = temp

			var pivot_val = aug[pivot][pivot]
			for j in range(2 * A.n):
				aug[pivot][j] = aug[pivot][j].div(pivot_val)

			for i in range(A.n):
				if i != pivot:
					var factor = aug[i][pivot]
					for j in range(2 * A.n):
						aug[i][j] = aug[i][j].sub(factor.mul(aug[pivot][j]))

		var result = ComplexMatrix.new(A.n)
		for i in range(A.n):
			for j in range(A.n):
				result.set_element(i, j, aug[i][j + A.n])
	return float(Time.get_ticks_usec() - start) / ITERATIONS

#endregion

#region GDScript helper functions (for pure GDScript benchmark)

func _mul_gs(A: ComplexMatrix, B: ComplexMatrix) -> ComplexMatrix:
	var result = ComplexMatrix.new(A.n)
	for i in range(A.n):
		for j in range(A.n):
			var sum = Complex.zero()
			for k in range(A.n):
				sum = sum.add(A.get_element(i, k).mul(B.get_element(k, j)))
			result.set_element(i, j, sum)
	return result

func _scale_real_gs(A: ComplexMatrix, s: float) -> ComplexMatrix:
	var result = ComplexMatrix.new(A.n)
	for i in range(A.n * A.n):
		result._data[i] = Complex.new(A._data[i].re * s, A._data[i].im * s)
	return result

func _one_norm_gs(A: ComplexMatrix) -> float:
	var max_sum = 0.0
	for j in range(A.n):
		var col_sum = 0.0
		for i in range(A.n):
			col_sum += A.get_element(i, j).abs()
		max_sum = max(max_sum, col_sum)
	return max_sum

func _add_gs(A: ComplexMatrix, B: ComplexMatrix) -> ComplexMatrix:
	var result = ComplexMatrix.new(A.n)
	for i in range(A.n * A.n):
		result._data[i] = A._data[i].add(B._data[i])
	return result

func _pade_6_6_gs(A: ComplexMatrix) -> ComplexMatrix:
	var c = [1.0, 0.5, 0.117857142857143, 0.019841269841270, 0.002480158730159, 0.000198412698412698, 0.000008267195767196]
	var I = ComplexMatrix.identity(A.n)
	var A2 = _mul_gs(A, A)
	var A4 = _mul_gs(A2, A2)
	var A6 = _mul_gs(A2, A4)

	var U = _add_gs(_add_gs(_scale_real_gs(I, c[1]), _scale_real_gs(A2, c[3])), _scale_real_gs(A4, c[5]))
	U = _mul_gs(A, U)

	var V = _add_gs(_add_gs(_add_gs(_scale_real_gs(I, c[0]), _scale_real_gs(A2, c[2])), _scale_real_gs(A4, c[4])), _scale_real_gs(A6, c[6]))

	var numerator = _add_gs(V, U)
	var denom_inv = _inverse_gs(_sub_gs(V, U))
	return _mul_gs(denom_inv, numerator)

func _sub_gs(A: ComplexMatrix, B: ComplexMatrix) -> ComplexMatrix:
	var result = ComplexMatrix.new(A.n)
	for i in range(A.n * A.n):
		result._data[i] = A._data[i].sub(B._data[i])
	return result

func _inverse_gs(A: ComplexMatrix) -> ComplexMatrix:
	var aug = []
	for i in range(A.n):
		var row = []
		for j in range(A.n):
			row.append(A.get_element(i, j))
		for j in range(A.n):
			row.append(Complex.one() if i == j else Complex.zero())
		aug.append(row)

	for pivot in range(A.n):
		var max_row = pivot
		var max_val = aug[pivot][pivot].abs()
		for i in range(pivot + 1, A.n):
			if aug[i][pivot].abs() > max_val:
				max_val = aug[i][pivot].abs()
				max_row = i

		if max_row != pivot:
			var temp = aug[pivot]
			aug[pivot] = aug[max_row]
			aug[max_row] = temp

		var pivot_val = aug[pivot][pivot]
		for j in range(2 * A.n):
			aug[pivot][j] = aug[pivot][j].div(pivot_val)

		for i in range(A.n):
			if i != pivot:
				var factor = aug[i][pivot]
				for j in range(2 * A.n):
					aug[i][j] = aug[i][j].sub(factor.mul(aug[pivot][j]))

	var result = ComplexMatrix.new(A.n)
	for i in range(A.n):
		for j in range(A.n):
			result.set_element(i, j, aug[i][j + A.n])
	return result

#endregion

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
