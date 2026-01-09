class_name LindbladEvolution
extends Resource

## Lindblad Evolution - Open Quantum System Dynamics
## Implements Lindblad master equation for decoherence and dissipation
##
## Master equation: dρ/dt = -i[H,ρ] + Σ_k (L_k ρ L_k† - ½{L_k†L_k, ρ})
##                          └─ Hamiltonian ─┘  └─────── Dissipation ────────┘
##
## This is the REAL physics of open quantum systems (quantum optics, ion traps, etc.)

## Standard Pauli Matrices (for jump operators)
## These are the building blocks of quantum operations

static func sigma_x() -> Array:
	"""Pauli-X (bit flip): [[0, 1], [1, 0]]"""
	return [
		[Vector2(0, 0), Vector2(1, 0)],
		[Vector2(1, 0), Vector2(0, 0)]
	]


static func sigma_y() -> Array:
	"""Pauli-Y (bit + phase flip): [[0, -i], [i, 0]]"""
	return [
		[Vector2(0, 0), Vector2(0, -1)],  # -i
		[Vector2(0, 1), Vector2(0, 0)]    # +i
	]


static func sigma_z() -> Array:
	"""Pauli-Z (phase flip): [[1, 0], [0, -1]]"""
	return [
		[Vector2(1, 0), Vector2(0, 0)],
		[Vector2(0, 0), Vector2(-1, 0)]
	]


static func sigma_plus() -> Array:
	"""Raising operator: [[0, 1], [0, 0]]"""
	return [
		[Vector2(0, 0), Vector2(1, 0)],
		[Vector2(0, 0), Vector2(0, 0)]
	]


static func sigma_minus() -> Array:
	"""Lowering operator: [[0, 0], [1, 0]]"""
	return [
		[Vector2(0, 0), Vector2(0, 0)],
		[Vector2(1, 0), Vector2(0, 0)]
	]


static func identity_2x2() -> Array:
	"""Identity: [[1, 0], [0, 1]]"""
	return [
		[Vector2(1, 0), Vector2(0, 0)],
		[Vector2(0, 0), Vector2(1, 0)]
	]


## Temperature-Dependent Decoherence Rates

static func get_T1_time(base_T1: float, temperature: float) -> float:
	"""Calculate T₁ (amplitude damping time) with temperature dependence

	T₁ governs energy relaxation: |excited⟩ → |ground⟩

	Physics: Thermal bath causes transitions.
	At high temperature: more thermal photons → faster relaxation.

	Args:
		base_T1: T₁ at zero temperature (seconds)
		temperature: Environment temperature (Kelvin or Celsius, relative scale)

	Returns:
		Effective T₁ time (seconds)
	"""
	# Simplified thermal model: T₁ decreases with temperature
	# Real physics: Γ₁ ∝ (n_th + 1) where n_th = Bose-Einstein distribution
	# For gameplay: linear approximation

	var thermal_factor = 1.0 + (temperature / 100.0)  # Normalized to ~room temp
	return base_T1 / thermal_factor


static func get_T2_time(T1: float, temperature: float, pure_dephasing_rate: float = 0.01) -> float:
	"""Calculate T₂ (dephasing time) with temperature dependence

	T₂ governs phase coherence loss.
	Always satisfies: T₂ ≤ 2T₁ (fundamental quantum limit)

	Physics: T₂ = 1 / (1/(2T₁) + Γ_φ)
	where Γ_φ is pure dephasing rate (phase noise without energy loss)

	Args:
		T1: Amplitude damping time (from get_T1_time)
		temperature: Environment temperature
		pure_dephasing_rate: Additional pure dephasing (temperature-dependent)

	Returns:
		Effective T₂ time (seconds)
	"""
	# Pure dephasing increases with temperature (phase noise)
	var gamma_phi = pure_dephasing_rate * (1.0 + temperature / 100.0)

	# T₂ relation: 1/T₂ = 1/(2T₁) + Γ_φ
	var T2_inv = (1.0 / (2.0 * T1)) + gamma_phi
	return 1.0 / T2_inv


## Lindblad Evolution for Single Qubit (2×2 Density Matrix)

static func apply_lindblad_step_2x2(rho: Array, jump_operators: Array, dt: float) -> Array:
	"""Apply Lindblad evolution for single qubit (2×2 density matrix)

	dρ/dt = Σ_k (L_k ρ L_k† - ½{L_k†L_k, ρ})

	Args:
		rho: 2×2 density matrix (Array of Vector2)
		jump_operators: Array of {operator: Array, rate: float}
		dt: Time step (seconds)

	Returns:
		Updated 2×2 density matrix
	"""
	var drho = [
		[Vector2(0, 0), Vector2(0, 0)],
		[Vector2(0, 0), Vector2(0, 0)]
	]

	# Apply each jump operator
	for jump_data in jump_operators:
		var L = jump_data["operator"]  # 2×2 matrix
		var gamma = jump_data["rate"]   # Jump rate

		if gamma <= 0.0:
			continue

		# Compute: L ρ L†
		var L_rho = _matrix_multiply_2x2(L, rho)
		var L_rho_Ldagger = _matrix_multiply_2x2(L_rho, _dagger_2x2(L))

		# Compute: L† L
		var Ldagger_L = _matrix_multiply_2x2(_dagger_2x2(L), L)

		# Compute: {L†L, ρ} = L†L ρ + ρ L†L
		var LdL_rho = _matrix_multiply_2x2(Ldagger_L, rho)
		var rho_LdL = _matrix_multiply_2x2(rho, Ldagger_L)
		var anticommutator = _matrix_add_2x2(LdL_rho, rho_LdL)

		# Add to drho: γ(L ρ L† - ½{L†L, ρ})
		var term = _matrix_subtract_2x2(L_rho_Ldagger, _matrix_scale_2x2(anticommutator, 0.5))
		drho = _matrix_add_2x2(drho, _matrix_scale_2x2(term, gamma))

	# Euler step: ρ(t+dt) = ρ(t) + dt·dρ/dt
	var rho_new = _matrix_add_2x2(rho, _matrix_scale_2x2(drho, dt))

	# Ensure hermiticity and trace preservation (numerical stability)
	rho_new = _enforce_hermitian_2x2(rho_new)
	rho_new = _normalize_trace_2x2(rho_new)

	return rho_new


static func apply_T1_damping_2x2(rho: Array, dt: float, T1: float) -> Array:
	"""Apply T₁ (amplitude damping) decoherence

	Physics: Energy relaxation toward ground state |0⟩
	Jump operator: L = √(1/T₁) · σ_- = [[0, 0], [√Γ₁, 0]]
	"""
	if T1 <= 0.0:
		return rho

	var gamma_1 = 1.0 / T1
	var jump_ops = [{"operator": sigma_minus(), "rate": gamma_1}]

	return apply_lindblad_step_2x2(rho, jump_ops, dt)


static func apply_T2_dephasing_2x2(rho: Array, dt: float, T2: float) -> Array:
	"""Apply T₂ (pure dephasing) decoherence

	Physics: Phase randomization without energy loss
	Jump operator: L = √(Γ_φ) · σ_z where Γ_φ = 1/T₂ - 1/(2T₁)
	"""
	if T2 <= 0.0:
		return rho

	# For pure dephasing, use effective rate
	var gamma_phi = 1.0 / T2
	var jump_ops = [{"operator": sigma_z(), "rate": gamma_phi * 0.5}]  # Factor 0.5 for σ_z

	return apply_lindblad_step_2x2(rho, jump_ops, dt)


static func apply_realistic_decoherence_2x2(rho: Array, dt: float, temperature: float, base_T1: float = 100.0) -> Array:
	"""Apply realistic T₁ + T₂ decoherence with temperature dependence

	This is the main function for physically accurate decoherence.

	Args:
		rho: 2×2 density matrix
		dt: Time step
		temperature: Environment temperature (K or relative units)
		base_T1: Base T₁ time at zero temperature

	Returns:
		Decohered density matrix
	"""
	var T1 = get_T1_time(base_T1, temperature)
	var T2 = get_T2_time(T1, temperature)

	# Apply both processes
	rho = apply_T1_damping_2x2(rho, dt, T1)
	rho = apply_T2_dephasing_2x2(rho, dt, T2)

	return rho


## Lindblad Evolution for Entangled Pair (4×4 Density Matrix)

static func apply_lindblad_step_4x4(rho: Array, jump_operators: Array, dt: float) -> Array:
	"""Apply Lindblad evolution for two-qubit system (4×4 density matrix)

	Same formula as 2×2, but with 4×4 matrices.
	"""
	var drho = []
	for i in range(4):
		var row = []
		for j in range(4):
			row.append(Vector2(0, 0))
		drho.append(row)

	for jump_data in jump_operators:
		var L = jump_data["operator"]  # 4×4 matrix
		var gamma = jump_data["rate"]

		if gamma <= 0.0:
			continue

		var L_rho = _matrix_multiply_4x4(L, rho)
		var L_rho_Ldagger = _matrix_multiply_4x4(L_rho, _dagger_4x4(L))

		var Ldagger_L = _matrix_multiply_4x4(_dagger_4x4(L), L)
		var LdL_rho = _matrix_multiply_4x4(Ldagger_L, rho)
		var rho_LdL = _matrix_multiply_4x4(rho, Ldagger_L)
		var anticommutator = _matrix_add_4x4(LdL_rho, rho_LdL)

		var term = _matrix_subtract_4x4(L_rho_Ldagger, _matrix_scale_4x4(anticommutator, 0.5))
		drho = _matrix_add_4x4(drho, _matrix_scale_4x4(term, gamma))

	var rho_new = _matrix_add_4x4(rho, _matrix_scale_4x4(drho, dt))

	rho_new = _enforce_hermitian_4x4(rho_new)
	rho_new = _normalize_trace_4x4(rho_new)

	return rho_new


static func apply_two_qubit_decoherence_4x4(rho: Array, dt: float, temperature: float, base_T1: float = 100.0) -> Array:
	"""Apply decoherence to entangled pair

	Each qubit decoheres independently.
	Jump operators: σ_- ⊗ I and I ⊗ σ_- for amplitude damping
	                σ_z ⊗ I and I ⊗ σ_z for dephasing
	"""
	var T1 = get_T1_time(base_T1, temperature)
	var T2 = get_T2_time(T1, temperature)

	var gamma_1 = 1.0 / T1
	var gamma_phi = 1.0 / T2

	# Amplitude damping on both qubits
	var sigma_m_I = _tensor_product(sigma_minus(), identity_2x2())  # σ_- ⊗ I
	var I_sigma_m = _tensor_product(identity_2x2(), sigma_minus())  # I ⊗ σ_-

	# Dephasing on both qubits
	var sigma_z_I = _tensor_product(sigma_z(), identity_2x2())
	var I_sigma_z = _tensor_product(identity_2x2(), sigma_z())

	var jump_ops = [
		{"operator": sigma_m_I, "rate": gamma_1},
		{"operator": I_sigma_m, "rate": gamma_1},
		{"operator": sigma_z_I, "rate": gamma_phi * 0.5},
		{"operator": I_sigma_z, "rate": gamma_phi * 0.5}
	]

	return apply_lindblad_step_4x4(rho, jump_ops, dt)


## Matrix Operations - 2×2

static func _matrix_multiply_2x2(A: Array, B: Array) -> Array:
	var result = [[Vector2(0, 0), Vector2(0, 0)], [Vector2(0, 0), Vector2(0, 0)]]
	for i in range(2):
		for j in range(2):
			for k in range(2):
				result[i][j] += _complex_mult(A[i][k], B[k][j])
	return result


static func _matrix_add_2x2(A: Array, B: Array) -> Array:
	return [
		[A[0][0] + B[0][0], A[0][1] + B[0][1]],
		[A[1][0] + B[1][0], A[1][1] + B[1][1]]
	]


static func _matrix_subtract_2x2(A: Array, B: Array) -> Array:
	return [
		[A[0][0] - B[0][0], A[0][1] - B[0][1]],
		[A[1][0] - B[1][0], A[1][1] - B[1][1]]
	]


static func _matrix_scale_2x2(A: Array, s: float) -> Array:
	return [
		[A[0][0] * s, A[0][1] * s],
		[A[1][0] * s, A[1][1] * s]
	]


static func _dagger_2x2(A: Array) -> Array:
	"""Hermitian conjugate (transpose + complex conjugate)"""
	return [
		[Vector2(A[0][0].x, -A[0][0].y), Vector2(A[1][0].x, -A[1][0].y)],
		[Vector2(A[0][1].x, -A[0][1].y), Vector2(A[1][1].x, -A[1][1].y)]
	]


static func _enforce_hermitian_2x2(A: Array) -> Array:
	"""Force matrix to be Hermitian: A = (A + A†)/2"""
	var Ad = _dagger_2x2(A)
	return _matrix_scale_2x2(_matrix_add_2x2(A, Ad), 0.5)


static func _normalize_trace_2x2(A: Array) -> Array:
	"""Normalize trace to 1"""
	var trace = A[0][0].x + A[1][1].x
	if abs(trace) > 0.0001:
		return _matrix_scale_2x2(A, 1.0 / trace)
	return A


## Matrix Operations - 4×4

static func _matrix_multiply_4x4(A: Array, B: Array) -> Array:
	var result = []
	for i in range(4):
		var row = []
		for j in range(4):
			var sum = Vector2(0, 0)
			for k in range(4):
				sum += _complex_mult(A[i][k], B[k][j])
			row.append(sum)
		result.append(row)
	return result


static func _matrix_add_4x4(A: Array, B: Array) -> Array:
	var result = []
	for i in range(4):
		var row = []
		for j in range(4):
			row.append(A[i][j] + B[i][j])
		result.append(row)
	return result


static func _matrix_subtract_4x4(A: Array, B: Array) -> Array:
	var result = []
	for i in range(4):
		var row = []
		for j in range(4):
			row.append(A[i][j] - B[i][j])
		result.append(row)
	return result


static func _matrix_scale_4x4(A: Array, s: float) -> Array:
	var result = []
	for i in range(4):
		var row = []
		for j in range(4):
			row.append(A[i][j] * s)
		result.append(row)
	return result


static func _dagger_4x4(A: Array) -> Array:
	var result = []
	for i in range(4):
		var row = []
		for j in range(4):
			row.append(Vector2(A[j][i].x, -A[j][i].y))  # Transpose + conjugate
		result.append(row)
	return result


static func _enforce_hermitian_4x4(A: Array) -> Array:
	var Ad = _dagger_4x4(A)
	return _matrix_scale_4x4(_matrix_add_4x4(A, Ad), 0.5)


static func _normalize_trace_4x4(A: Array) -> Array:
	var trace = Vector2(0, 0)
	for i in range(4):
		trace += A[i][i]
	if abs(trace.x) > 0.0001:
		return _matrix_scale_4x4(A, 1.0 / trace.x)
	return A


## Tensor Product

static func _tensor_product(A: Array, B: Array) -> Array:
	"""Compute tensor product A ⊗ B (Kronecker product)

	For 2×2 matrices: (A ⊗ B) is 4×4
	Result[i*2+j][k*2+l] = A[i][k] * B[j][l]
	"""
	var result = []
	for i in range(4):
		var row = []
		for j in range(4):
			var A_row = i / 2
			var A_col = j / 2
			var B_row = i % 2
			var B_col = j % 2
			row.append(_complex_mult(A[A_row][A_col], B[B_row][B_col]))
		result.append(row)
	return result


## Complex Arithmetic

static func _complex_mult(a: Vector2, b: Vector2) -> Vector2:
	"""Complex multiplication: (a+bi)(c+di)"""
	return Vector2(
		a.x * b.x - a.y * b.y,
		a.x * b.y + a.y * b.x
	)
