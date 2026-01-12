extends SceneTree

## Native Matrix Accuracy Tests
## Tests that native Eigen backend produces results matching GDScript within tolerance

const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")

var tests_passed := 0
var tests_failed := 0

func _init():
	print("\n═══ NATIVE MATRIX ACCURACY TESTS ═══")
	print("Native available: %s\n" % ComplexMatrix.is_native_available())

	test_mul_trace()
	test_mul_associativity()
	test_expm_identity()
	test_expm_unitarity()
	test_inverse_identity()
	test_inverse_accuracy()
	test_eigensystem_trace()
	test_eigensystem_reconstruction()

	print("\n═══ RESULTS ═══")
	print("Passed: %d" % tests_passed)
	print("Failed: %d" % tests_failed)

	quit()

func report(name: String, passed: bool) -> void:
	if passed:
		tests_passed += 1
		print("[PASS] %s" % name)
	else:
		tests_failed += 1
		print("[FAIL] %s" % name)

func approx_equal(a: float, b: float, tol: float = 1e-6) -> bool:
	return abs(a - b) < tol

#region Test Cases

func test_mul_trace():
	# Tr(AB) should match expected value
	var A = ComplexMatrix.new(4)
	var B = ComplexMatrix.new(4)

	# Fill with predictable values
	for i in range(4):
		for j in range(4):
			A.set_element(i, j, Complex.new(float(i + 1), float(j) * 0.1))
			B.set_element(i, j, Complex.new(float(j + 1), float(i) * 0.1))

	var C = A.mul(B)
	var tr = C.trace()

	# Pre-computed expected trace for this specific case
	# Diagonal of AB: sum of A[i,:] . B[:,i]
	var expected_re = 0.0
	for i in range(4):
		for k in range(4):
			var a = A.get_element(i, k)
			var b = B.get_element(k, i)
			expected_re += a.re * b.re - a.im * b.im

	report("mul() trace accuracy", approx_equal(tr.re, expected_re, 1e-10))

func test_mul_associativity():
	# (AB)C = A(BC) for random matrices
	var A = _random_matrix(4)
	var B = _random_matrix(4)
	var C = _random_matrix(4)

	var left = A.mul(B).mul(C)
	var right = A.mul(B.mul(C))

	var max_diff = 0.0
	for i in range(4):
		for j in range(4):
			var diff = left.get_element(i, j).sub(right.get_element(i, j)).abs()
			max_diff = max(max_diff, diff)

	report("mul() associativity (AB)C = A(BC)", max_diff < 1e-10)

func test_expm_identity():
	# exp(0) = I
	var Z = ComplexMatrix.zeros(4)
	var exp_Z = Z.expm()

	var max_diff = 0.0
	for i in range(4):
		for j in range(4):
			var expected = Complex.one() if i == j else Complex.zero()
			var diff = exp_Z.get_element(i, j).sub(expected).abs()
			max_diff = max(max_diff, diff)

	report("expm(0) = I", max_diff < 1e-10)

func test_expm_unitarity():
	# exp(-iH) should be unitary for Hermitian H
	var H = _random_hermitian(4)
	var neg_i_H = H.scale(Complex.new(0.0, -1.0))
	var U = neg_i_H.expm()

	# U^dag * U should equal I
	var U_dag_U = U.dagger().mul(U)

	var max_diff = 0.0
	for i in range(4):
		for j in range(4):
			var expected = Complex.one() if i == j else Complex.zero()
			var diff = U_dag_U.get_element(i, j).sub(expected).abs()
			max_diff = max(max_diff, diff)

	report("expm(-iH) unitarity: U^dag U = I", max_diff < 1e-6)

func test_inverse_identity():
	# I^(-1) = I
	var I = ComplexMatrix.identity(4)
	var I_inv = I.inverse()

	var max_diff = 0.0
	for i in range(4):
		for j in range(4):
			var expected = Complex.one() if i == j else Complex.zero()
			var diff = I_inv.get_element(i, j).sub(expected).abs()
			max_diff = max(max_diff, diff)

	report("inverse(I) = I", max_diff < 1e-10)

func test_inverse_accuracy():
	# A * A^(-1) = I
	var A = _random_matrix(4)
	# Make it invertible by adding to diagonal
	for i in range(4):
		A.set_element(i, i, A.get_element(i, i).add(Complex.new(5.0, 0.0)))

	var A_inv = A.inverse()
	var prod = A.mul(A_inv)

	var max_diff = 0.0
	for i in range(4):
		for j in range(4):
			var expected = Complex.one() if i == j else Complex.zero()
			var diff = prod.get_element(i, j).sub(expected).abs()
			max_diff = max(max_diff, diff)

	report("A * A^(-1) = I", max_diff < 1e-6)

func test_eigensystem_trace():
	# Tr(A) = sum of eigenvalues
	var H = _random_hermitian(4)
	var tr = H.trace().re

	var eig = H.eigensystem()
	var sum_eigenvalues = 0.0
	for ev in eig["eigenvalues"]:
		sum_eigenvalues += ev

	report("eigensystem: Tr(H) = sum(eigenvalues)", approx_equal(tr, sum_eigenvalues, 1e-6))

func test_eigensystem_reconstruction():
	# A = V * D * V^dag for Hermitian A
	var H = _random_hermitian(4)
	var eig = H.eigensystem()

	var V = eig["eigenvectors"]
	var D = ComplexMatrix.diagonal([
		Complex.new(eig["eigenvalues"][0], 0.0),
		Complex.new(eig["eigenvalues"][1], 0.0),
		Complex.new(eig["eigenvalues"][2], 0.0),
		Complex.new(eig["eigenvalues"][3], 0.0)
	])

	var reconstructed = V.mul(D).mul(V.dagger())

	var max_diff = 0.0
	for i in range(4):
		for j in range(4):
			var diff = H.get_element(i, j).sub(reconstructed.get_element(i, j)).abs()
			max_diff = max(max_diff, diff)

	report("eigensystem: H = V D V^dag", max_diff < 1e-6)

#endregion

#region Helpers

func _random_matrix(dim: int) -> ComplexMatrix:
	var m = ComplexMatrix.new(dim)
	for i in range(dim):
		for j in range(dim):
			m.set_element(i, j, Complex.new(randf() - 0.5, randf() - 0.5))
	return m

func _random_hermitian(dim: int) -> ComplexMatrix:
	var m = ComplexMatrix.new(dim)
	# Build Hermitian: A = (B + B^dag)/2
	for i in range(dim):
		for j in range(i, dim):
			if i == j:
				m.set_element(i, j, Complex.new(randf() - 0.5, 0.0))
			else:
				var c = Complex.new(randf() - 0.5, randf() - 0.5)
				m.set_element(i, j, c)
				m.set_element(j, i, c.conjugate())
	return m

#endregion
