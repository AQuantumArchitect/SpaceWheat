class_name ComplexMatrix
extends RefCounted


# Self-reference helper for internal constructors (avoid circular reference issues)
static var _class_ref = null

static func _self() -> GDScript:
	if not _class_ref:
		_class_ref = load("res://Core/QuantumSubstrate/ComplexMatrix.gd")
	return _class_ref

#region Native Backend (GDExtension Acceleration)

## Native backend detection - checked once, cached
static var _native_available: bool = false
static var _native_checked: bool = false
static var _zero_trace_warn_count: int = 0
static var _zero_trace_warn_last_ms: int = 0
const _ZERO_TRACE_WARN_LIMIT: int = 5
const _ZERO_TRACE_WARN_INTERVAL_MS: int = 5000

static func _check_native() -> void:
	if _native_checked:
		return
	_native_checked = true

	if ClassDB.class_exists("QuantumMatrixNative"):
		_native_available = true
		VerboseHelper.info("quantum", "matrix", "ComplexMatrix native acceleration enabled (Eigen)")
	else:
		_native_available = false
		VerboseHelper.warn("quantum", "matrix", "ComplexMatrix using pure GDScript")

static func is_native_available() -> bool:
	_check_native()
	return _native_available

## Instance-level native backend
var _native_backend = null

func _get_native():
	if _native_backend == null and _native_available and n > 0:
		_native_backend = ClassDB.instantiate("QuantumMatrixNative")
	return _native_backend

## The native backend (QuantumMatrixNative, Eigen) is the SINGLE compute authority —
## there is no GDScript matrix-math twin. Returns the backend loaded with this matrix's
## current value, ready for an op. For an empty (n==0) matrix returns null (callers
## return the trivial result). If native is genuinely unavailable for n>0 that's a fatal
## misconfiguration — the game requires the C++ extension (cd native && make) — so we
## fail LOUD rather than silently diverging into a parallel GDScript computation.
func _compute_kernel(op_name: String):
	if n == 0:
		return null
	var native = _get_native()
	if native == null:
		push_error("ComplexMatrix.%s: native backend unavailable — it is the single compute authority. Build the C++ extension: cd native && make." % op_name)
		return null
	native.from_packed(_to_packed(), n)
	return native

## Return the authoritative packed store (the single source of truth). Kept as a
## method for API stability across the many call sites; it now simply guarantees the
## buffer is sized and hands it back — no representation reconciliation, no drift.
func _to_packed() -> PackedFloat64Array:
	_ensure_packed_sized()
	return _packed_cache

## Load a packed buffer as this matrix's value. The buffer becomes the store directly.
func _from_packed(packed: PackedFloat64Array, dim: int) -> void:
	n = dim
	_packed_cache = packed
	_ensure_packed_sized()

## Guarantee the packed store is allocated to n*n*2 (zero-filled). The ONLY invariant
## the store needs — there is nothing else to keep in sync.
func _ensure_packed_sized() -> void:
	if _packed_cache.size() < n * n * 2:
		_packed_cache.resize(n * n * 2)

#region Sparse Matrix Transfer (CSR Format)

## Sparsity threshold - elements below this magnitude are considered zero
const SPARSITY_THRESHOLD: float = 1e-12

## Calculate sparsity ratio (0.0 = all zero, 1.0 = all non-zero)
func get_sparsity_ratio() -> float:
	if n <= 0:
		return 0.0
	var total = n * n
	return float(count_nonzeros()) / float(total) if total > 0 else 0.0

## Count non-zero elements (reads the single packed store).
func count_nonzeros() -> int:
	if n <= 0:
		return 0
	_ensure_packed_sized()
	var count = 0
	var thresh_sq = SPARSITY_THRESHOLD * SPARSITY_THRESHOLD
	for i in range(n * n):
		var re = _packed_cache[i * 2]
		var im = _packed_cache[i * 2 + 1]
		if re * re + im * im > thresh_sq:
			count += 1
	return count

## Marshal to CSR (Compressed Sparse Row) format for efficient transfer
## Returns Dictionary with: row_ptr, col_idx, values_real, values_imag, dim, nnz
func _to_packed_csr() -> Dictionary:
	var row_ptr = PackedInt32Array()
	var col_idx = PackedInt32Array()
	var values_real = PackedFloat64Array()
	var values_imag = PackedFloat64Array()

	row_ptr.resize(n + 1)
	var current_nnz = 0

	for i in range(n):
		row_ptr[i] = current_nnz
		for j in range(n):
			var elem = get_element(i, j)
			if elem.abs() > SPARSITY_THRESHOLD:
				col_idx.append(j)
				values_real.append(elem.re)
				values_imag.append(elem.im)
				current_nnz += 1

	row_ptr[n] = current_nnz

	return {
		"format": "csr",
		"dim": n,
		"nnz": current_nnz,
		"row_ptr": row_ptr,
		"col_idx": col_idx,
		"values_real": values_real,
		"values_imag": values_imag
	}

## Unmarshal from CSR format
func _from_packed_csr(csr_data: Dictionary) -> void:
	n = csr_data.dim
	_packed_cache = PackedFloat64Array()
	_packed_cache.resize(n * n * 2)  # zero-filled

	var row_ptr = csr_data.row_ptr
	var col_idx = csr_data.col_idx
	var values_real = csr_data.values_real
	var values_imag = csr_data.values_imag

	for i in range(n):
		var row_start = row_ptr[i]
		var row_end = row_ptr[i + 1]
		for k in range(row_start, row_end):
			var j = col_idx[k]
			set_element(i, j, Complex.new(values_real[k], values_imag[k]))

## Smart marshal: choose dense or sparse based on sparsity ratio
## Uses sparse if less than 40% non-zero (60% sparse or more)
func _to_packed_auto() -> Dictionary:
	var sparsity_ratio = get_sparsity_ratio()
	var use_sparse = sparsity_ratio < 0.4  # Use sparse if <40% non-zero

	if use_sparse:
		var csr = _to_packed_csr()
		# Calculate transfer savings for logging
		var dense_bytes = n * n * 2 * 8
		var sparse_bytes = (n + 1) * 4 + csr.nnz * 4 + csr.nnz * 2 * 8
		# Only use sparse if it actually saves bytes
		if sparse_bytes < dense_bytes:
			return csr

	# Fall back to dense
	return {
		"format": "dense",
		"dim": n,
		"data": _to_packed()
	}

## Smart unmarshal: detect format and use appropriate method
func _from_packed_auto(packed_data) -> void:
	if packed_data is Dictionary:
		if packed_data.format == "csr":
			_from_packed_csr(packed_data)
		else:
			_from_packed(packed_data.data, packed_data.dim)
	else:
		# Legacy: PackedFloat64Array, assume square matrix
		var dim = int(sqrt(packed_data.size() / 2))
		_from_packed(packed_data, dim)

#endregion

## Create result matrix from packed native output
func _result_from_packed(packed: PackedFloat64Array, dim: int):
	var result = load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(dim)
	result._from_packed(packed, dim)
	return result

#endregion

## N×N Complex Matrix for quantum mechanics
## Supports density matrices, Hamiltonians, and unitary operators
##
## Key operations:
## - Arithmetic: add, sub, mul, scale
## - Linear algebra: inverse, determinant, trace
## - Quantum: dagger (Hermitian conjugate), commutator, expm (matrix exponential)

var n: int = 0  # Dimension
## THE single authoritative store: dense row-major [re, im] pairs; element (i,j)
## lives at index (i*n + j)*2. There is no second representation — the old _data
## Array[Complex] and the _data_valid/_packed_valid flags (the source of read drift)
## are gone. Bulk compute delegates to the native backend, loaded FROM this buffer
## per op; the backend is a stateless compute kernel, never a parallel store.
var _packed_cache: PackedFloat64Array = PackedFloat64Array()

func _init(dimension: int = 0):
	_check_native()
	n = dimension
	_packed_cache = PackedFloat64Array()
	_packed_cache.resize(n * n * 2)  # PackedFloat64Array is zero-initialized by resize

## Create a matrix directly from packed data (fast — no Complex allocation)
static func from_packed_direct(packed: PackedFloat64Array, dimension: int):
	var m = load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(0)
	m.n = dimension
	m._packed_cache = packed
	m._ensure_packed_sized()
	return m

## Create zero matrix of given dimension (packed-primary — no Complex allocation)
static func zeros(dimension: int):
	var packed = PackedFloat64Array()
	packed.resize(dimension * dimension * 2)
	# PackedFloat64Array is zero-initialized by resize
	return _self().from_packed_direct(packed, dimension)

## Create identity matrix
static func identity(dimension: int):
	var m = load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(dimension)
	for i in range(dimension):
		m.set_element(i, i, Complex.one())
	return m

## Create from 2D array of Complex numbers
static func from_array(arr: Array):
	var dim = arr.size()
	var m = load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(dim)
	for i in range(dim):
		for j in range(dim):
			if j < arr[i].size():
				m.set_element(i, j, arr[i][j])
	return m

## Create diagonal matrix from array of Complex numbers
static func diagonal(diag: Array):
	var dim = diag.size()
	var m = load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(dim)
	for i in range(dim):
		m.set_element(i, i, diag[i])
	return m

## Deep copy
func duplicate():
	var packed = _to_packed()
	return _self().from_packed_direct(packed.duplicate(), n)

#region Element Access

func get_element(i: int, j: int):
	if i < 0 or i >= n or j < 0 or j >= n:
		push_error("ComplexMatrix index out of bounds: (%d, %d) for %dx%d matrix" % [i, j, n, n])
		return Complex.zero()
	_ensure_packed_sized()
	var idx = (i * n + j) * 2
	return Complex.new(_packed_cache[idx], _packed_cache[idx + 1])

## Read a diagonal real value (a population) straight from the packed store.
func get_diagonal_real(i: int) -> float:
	if i < 0 or i >= n:
		return 0.0
	_ensure_packed_sized()
	return _packed_cache[(i * n + i) * 2]

func get_heatmap_colors(max_dim: int = 0) -> PackedColorArray:
	# Return per-cell colors for a density matrix heatmap.

	# Diagonal cells:    grayscale V  (population purity).
	# Off-diagonal cells: HSV  hue=phase, sat+val=|ρ_ij|.

	# Computed in C++ (QuantumMatrixNative.heatmap_colors) to avoid GDScript
	# per-cell sqrt/atan2/HSV overhead.  max_dim caps to the first NxN block.
	if n == 0:
		return PackedColorArray()
	var native = _compute_kernel("heatmap_colors")
	if native == null:
		return PackedColorArray()
	return native.heatmap_colors(max_dim)


func set_element(i: int, j: int, value):
	if i < 0 or i >= n or j < 0 or j >= n:
		push_error("ComplexMatrix index out of bounds: (%d, %d) for %dx%d matrix" % [i, j, n, n])
		return
	# Write straight into the single packed store — no _data, no invalidation dance.
	_ensure_packed_sized()
	var idx = (i * n + j) * 2
	_packed_cache[idx] = value.re
	_packed_cache[idx + 1] = value.im

#endregion

#region Matrix Arithmetic

func add(other):
	if other.n != n:
		push_error("Matrix dimension mismatch in add: %d vs %d" % [n, other.n])
		return load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(n)
	if n == 0:
		return _self().zeros(0)
	var native = _compute_kernel("add")
	if native == null:
		return _self().zeros(n)
	return _self().from_packed_direct(native.add(other._to_packed(), n), n)

func sub(other):
	if other.n != n:
		push_error("Matrix dimension mismatch in sub: %d vs %d" % [n, other.n])
		return load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(n)
	if n == 0:
		return _self().zeros(0)
	var native = _compute_kernel("sub")
	if native == null:
		return _self().zeros(n)
	return _self().from_packed_direct(native.sub(other._to_packed(), n), n)

func mul(other):
	if other.n != n:
		push_error("Matrix dimension mismatch in mul: %d vs %d" % [n, other.n])
		return load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(n)
	if n == 0:
		return _self().zeros(0)
	var native = _compute_kernel("mul")
	if native == null:
		return _self().zeros(n)
	return _result_from_packed(native.mul(other._to_packed(), n), n)

func scale(s):
	if n == 0:
		return _self().zeros(0)
	var native = _compute_kernel("scale")
	if native == null:
		return _self().zeros(n)
	return _self().from_packed_direct(native.scale(s.re, s.im, n), n)

## Fast scale by -i: (re, im) → (im, -re).
func scale_neg_i():
	if n == 0:
		return _self().zeros(0)
	var native = _compute_kernel("scale_neg_i")
	if native == null:
		return _self().zeros(n)
	return _self().from_packed_direct(native.scale(0.0, -1.0, n), n)

func scale_real(s: float):
	if n == 0:
		return _self().zeros(0)
	var native = _compute_kernel("scale_real")
	if native == null:
		return _self().zeros(n)
	return _self().from_packed_direct(native.scale(s, 0.0, n), n)

#endregion

#region Linear Algebra Operations

func dagger():
	if n == 0:
		return _self().zeros(0)
	var native = _compute_kernel("dagger")
	if native == null:
		return _self().zeros(n)
	return _self().from_packed_direct(native.dagger(n), n)

func trace():
	# Fast path: read directly from packed data
	var a = _to_packed()
	var dim = n
	var sum_re = 0.0
	var sum_im = 0.0
	for i in range(dim):
		var idx = (i * dim + i) * 2
		sum_re += a[idx]
		sum_im += a[idx + 1]
	return Complex.new(sum_re, sum_im)


func compute_energy_split() -> Dictionary:
	# Split total energy into Real (diagonal) + Imaginary (off-diagonal)

	# For density matrices:
	# - Real energy = observable populations (diagonal elements)
	# - Imaginary energy = quantum coherence (off-diagonal elements)

	# The imaginary energy represents "potential" that can be extracted
	# via the Sparks mechanic (coherence → observable conversion).

	# Returns:
	# {
	# "real": float,           # Sum of diagonal probabilities
	# "imaginary": float,      # Sum of |off-diagonal| coherences
	# "total": float,          # real + imaginary
	# "coherence_ratio": float # imaginary / total (0.0 to 1.0)
	# }
	var p = _to_packed()
	var dim = n
	var real_energy = 0.0
	var imaginary_energy = 0.0

	# Real: sum of diagonal (populations)
	for i in range(dim):
		real_energy += p[(i * dim + i) * 2]

	# Imaginary: sum of |off-diagonal| (coherences)
	# Only count upper triangle and multiply by 2 (matrix is Hermitian)
	for i in range(dim):
		for j in range(i + 1, dim):
			var idx = (i * dim + j) * 2
			var re = p[idx]
			var im = p[idx + 1]
			imaginary_energy += sqrt(re * re + im * im) * 2.0

	var total = real_energy + imaginary_energy
	var ratio = imaginary_energy / total if total > 0.0 else 0.0

	return {
		"real": real_energy,
		"imaginary": imaginary_energy,
		"total": total,
		"coherence_ratio": ratio
	}


func commutator(other):
	# [A, B] = AB - BA
	if n == 0:
		return _self().zeros(0)
	var native = _compute_kernel("commutator")
	if native == null:
		return _self().zeros(n)
	return _self().from_packed_direct(native.commutator(other._to_packed(), n), n)

func anticommutator(other):
	# {A, B} = AB + BA — no native method, decompose via native mul + native add
	return mul(other).add(other.mul(self))

static func outer_product(ket: Array, bra: Array):
	var dim = ket.size()
	if bra.size() != dim:
		push_error("Outer product dimension mismatch")
		return load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(dim)
	var m = load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(dim)
	for i in range(dim):
		for j in range(dim):
			m.set_element(i, j, ket[i].mul(bra[j].conjugate()))
	return m

#endregion

#region Matrix Exponential (Padé Approximation)

func expm():
	# Matrix exponential — Eigen's Padé approximation in the native backend.
	if n == 0:
		return _self().zeros(0)
	var native = _compute_kernel("expm")
	if native == null:
		return _self().identity(n)
	return _result_from_packed(native.expm(), n)

func frobenius_norm() -> float:
	# ||A||_F = sqrt(Σ|A_ij|²) = sqrt(Tr(A†A))
	var sum_sq = 0.0
	for i in range(n):
		for j in range(n):
			var v = get_element(i, j).abs()
			sum_sq += v * v
	return sqrt(sum_sq)

#endregion

#region Matrix Inverse (Gauss-Jordan)

func inverse():
	# Matrix inverse — Eigen's LU decomposition in the native backend.
	if n == 0:
		return load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(0)
	var native = _compute_kernel("inverse")
	if native == null:
		return _self().identity(n)
	return _result_from_packed(native.inverse(), n)

#endregion

#region Eigenvalue Decomposition (Jacobi for Hermitian)

func eigensystem() -> Dictionary:
	# Returns { "eigenvalues": Array[float], "eigenvectors": ComplexMatrix }.
	# Eigen's SelfAdjointEigenSolver in the native backend (the single authority).
	if not is_hermitian():
		push_warning("eigensystem() called on non-Hermitian matrix - results may be unreliable")
	if n == 0:
		return {"eigenvalues": [], "eigenvectors": _self().zeros(0)}
	var native = _compute_kernel("eigensystem")
	if native == null:
		return {"eigenvalues": [], "eigenvectors": _self().identity(n)}
	var result = native.eigensystem()
	return {
		"eigenvalues": result["eigenvalues"],
		"eigenvectors": _result_from_packed(result["eigenvectors"], n)
	}

#endregion

#region Validation

func is_hermitian(tolerance: float = 1e-10) -> bool:
	for i in range(n):
		for j in range(i, n):
			var aij = get_element(i, j)
			var aji = get_element(j, i)
			if not aij.sub(aji.conjugate()).abs() < tolerance:
				return false
	return true

func is_positive_semidefinite(tolerance: float = 1e-10) -> bool:
	var eig = eigensystem()
	for eigenvalue in eig.eigenvalues:
		if eigenvalue < -tolerance:
			return false
	return true

func has_unit_trace(tolerance: float = 1e-10) -> bool:
	return abs(trace().re - 1.0) < tolerance

#endregion

#region Tensor Products & State Conversion

func tensor_product(other: ComplexMatrix) -> ComplexMatrix:
	# Compute Kronecker product: self ⊗ other (sparse-optimized)
	# Result dimension: (n × m) × (n × m) where self is n×n, other is m×m

	# Sparse optimization: skip zero blocks, compute only non-zero products.
	# Time: O(nnz₁ × nnz₂) where nnz = number of non-zero elements
	var m = other.n
	var result_dim = n * m
	var result = load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(result_dim)

	# Sparse computation: iterate only through non-zero elements of self
	var self_sparsity = _get_sparsity_pattern()
	var other_sparsity = other._get_sparsity_pattern()

	for i_pair in self_sparsity:
		var i = i_pair[0]
		var j = i_pair[1]
		var self_ij = get_element(i, j)

		# Skip if essentially zero
		if self_ij.abs() < 1e-14:
			continue

		# Multiply by all non-zero elements of other
		for k_pair in other_sparsity:
			var k = k_pair[0]
			var l = k_pair[1]
			var other_kl = other.get_element(k, l)

			# Skip if essentially zero
			if other_kl.abs() < 1e-14:
				continue

			# (A ⊗ B)[i*m+k, j*m+l] = A[i,j] * B[k,l]
			var res_i = i * m + k
			var res_j = j * m + l
			result.set_element(res_i, res_j, self_ij.mul(other_kl))

	return result

func _get_sparsity_pattern() -> Array:
	# Get list of (i, j) indices where element is non-zero.
	# Caches result for repeated calls.

	# Sparse optimization: O(n²) initial scan, then O(nnz) for returns.
	var pattern = []

	for i in range(n):
		for j in range(n):
			if get_element(i, j).abs() > 1e-14:
				pattern.append([i, j])

	return pattern

static func from_statevector(statevector: Array) -> ComplexMatrix:
	# Convert state vector |ψ⟩ to density matrix ρ = |ψ⟩⟨ψ| (sparse-optimized)

	# Input: statevector as Array[Complex]
	# Output: density matrix ρ where ρ_ij = ψ_i * conj(ψ_j)

	# Sparse optimization: only compute ρ_ij where both ψ_i and ψ_j are non-zero.
	# Time: O(nnz²) where nnz = number of non-zero components in |ψ⟩
	# Space: O(nnz²) instead of O(n²)

	# Typical case: superposition of 2-4 basis states → nnz ≈ 4, time ≈ O(16) vs O(2^(2n))
	var dim = statevector.size()
	var rho = load("res://Core/QuantumSubstrate/ComplexMatrix.gd").new(dim)

	# Find non-zero indices in statevector
	var nonzero_indices = []
	for i in range(dim):
		if statevector[i].abs() > 1e-14:
			nonzero_indices.append(i)

	# Only compute ρ_ij for non-zero pairs
	for i in nonzero_indices:
		for j in nonzero_indices:
			var psi_i = statevector[i]
			var psi_j = statevector[j]
			# ρ_ij = ψ_i * conj(ψ_j)
			var rho_ij = psi_i.mul(psi_j.conjugate())
			rho.set_element(i, j, rho_ij)

	return rho

func conjugate_transpose() -> ComplexMatrix:
	# Alias for dagger() for physics naming convention.
	return dagger()

func renormalize_trace() -> void:
	# Renormalize matrix so Tr(M) = 1 (in-place).
	# Used after measurement/projection to restore unit trace.
	var trace_val_cx = trace()
	var tr_val = trace_val_cx.abs()

	if tr_val < 1e-14:
		var now_ms = Time.get_ticks_msec()
		var should_warn = _zero_trace_warn_count < _ZERO_TRACE_WARN_LIMIT
		if not should_warn and (now_ms - _zero_trace_warn_last_ms) >= _ZERO_TRACE_WARN_INTERVAL_MS:
			should_warn = true
		if should_warn:
			_zero_trace_warn_count += 1
			_zero_trace_warn_last_ms = now_ms
			push_warning("Cannot renormalize: trace is essentially zero")
		return

	# Scale all elements by 1/|trace| in place on the single packed store. No second
	# representation to reconcile — the old _data/native lock-step dance is gone.
	_ensure_packed_sized()
	var s = 1.0 / tr_val
	for i in range(n * n * 2):
		_packed_cache[i] *= s

#endregion

#region Debug

func _to_string() -> String:
	var s = "ComplexMatrix(%dx%d):\n" % [n, n]
	for i in range(min(n, 4)):
		s += "  ["
		for j in range(min(n, 4)):
			var elem = get_element(i, j)
			s += "%.3f%+.3fi" % [elem.re, elem.im]
			if j < min(n, 4) - 1:
				s += ", "
		if n > 4:
			s += " ..."
		s += "]\n"
	if n > 4:
		s += "  ...\n"
	return s

#endregion
