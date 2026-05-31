class_name EntangledPair
extends Resource

## Entangled Pair - Real Two-Qubit Density Matrix
## Physically correct representation of entangled quantum states
##
## Uses 4×4 density matrix to represent joint quantum state.
## Cannot be factored into separate single-qubit states (non-separable).
## Measurement of one qubit affects the other (spooky action at a distance).

# Qubit identifiers (plot IDs)
var qubit_a_id: String = ""
var qubit_b_id: String = ""

# Emoji poles for each qubit
var north_emoji_a: String = ""
var south_emoji_a: String = ""
var north_emoji_b: String = ""
var south_emoji_b: String = ""

# Density matrix: 4×4 complex matrix
# Basis ordering: |00⟩, |01⟩, |10⟩, |11⟩
# where 0 = north, 1 = south
# Each element is Vector2(real, imag)
var density_matrix: Array = []  # 4×4 array of Vector2

# Decoherence parameters
var coherence_time_T1: float = 100.0  # Amplitude damping
var coherence_time_T2: float = 50.0   # Dephasing


func _init():
	_initialize_density_matrix()


func _initialize_density_matrix():
	# Initialize as maximally mixed state (identity/4)
	density_matrix = []
	for i in range(4):
		var row = []
		for j in range(4):
			if i == j:
				row.append(Vector2(0.25, 0.0))  # Diagonal: 1/4
			else:
				row.append(Vector2(0.0, 0.0))   # Off-diagonal: 0
		density_matrix.append(row)


## Bell State Creation

func create_bell_phi_plus():
	# Create |Φ+⟩ = (|00⟩ + |11⟩)/√2

	# Maximally entangled: measuring one qubit gives perfect correlation.
	# Both qubits collapse to same state.
	_clear_matrix()

	# |Φ+⟩⟨Φ+| = 1/2 * (|00⟩⟨00| + |00⟩⟨11| + |11⟩⟨00| + |11⟩⟨11|)
	var half = 0.5
	density_matrix[0][0] = Vector2(half, 0.0)  # ⟨00|Φ+⟩⟨Φ+|00⟩
	density_matrix[0][3] = Vector2(half, 0.0)  # ⟨00|Φ+⟩⟨Φ+|11⟩
	density_matrix[3][0] = Vector2(half, 0.0)  # ⟨11|Φ+⟩⟨Φ+|00⟩
	density_matrix[3][3] = Vector2(half, 0.0)  # ⟨11|Φ+⟩⟨Φ+|11⟩

	if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_QUANTUM") == "1":
		print("🔗 Created Bell state |Φ+⟩ for %s ↔ %s" % [qubit_a_id, qubit_b_id])


func create_bell_phi_minus():
	# Create |Φ-⟩ = (|00⟩ - |11⟩)/√2

	# Same correlation as Φ+, but with phase flip.
	# Clear to zeros
	_clear_matrix()

	var half = 0.5
	density_matrix[0][0] = Vector2(half, 0.0)
	density_matrix[0][3] = Vector2(-half, 0.0)  # Negative (phase flip)
	density_matrix[3][0] = Vector2(-half, 0.0)
	density_matrix[3][3] = Vector2(half, 0.0)

	if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_QUANTUM") == "1":
		print("🔗 Created Bell state |Φ-⟩ for %s ↔ %s" % [qubit_a_id, qubit_b_id])


func create_bell_psi_plus():
	# Create |Ψ+⟩ = (|01⟩ + |10⟩)/√2

	# Anti-correlated: measuring one qubit gives opposite result for other.
	_clear_matrix()

	var half = 0.5
	density_matrix[1][1] = Vector2(half, 0.0)  # |01⟩⟨01|
	density_matrix[1][2] = Vector2(half, 0.0)  # |01⟩⟨10|
	density_matrix[2][1] = Vector2(half, 0.0)  # |10⟩⟨01|
	density_matrix[2][2] = Vector2(half, 0.0)  # |10⟩⟨10|

	if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_QUANTUM") == "1":
		print("🔗 Created Bell state |Ψ+⟩ for %s ↔ %s" % [qubit_a_id, qubit_b_id])


func create_bell_psi_minus():
	# Create |Ψ-⟩ = (|01⟩ - |10⟩)/√2

	# Anti-correlated with phase flip.
	# This state violates Bell inequalities maximally.
	_clear_matrix()

	var half = 0.5
	density_matrix[1][1] = Vector2(half, 0.0)
	density_matrix[1][2] = Vector2(-half, 0.0)  # Phase flip
	density_matrix[2][1] = Vector2(-half, 0.0)
	density_matrix[2][2] = Vector2(half, 0.0)

	if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_QUANTUM") == "1":
		print("🔗 Created Bell state |Ψ-⟩ for %s ↔ %s" % [qubit_a_id, qubit_b_id])


func _clear_matrix():
	# Clear density matrix to all zeros
	density_matrix = []
	for i in range(4):
		var row = []
		for j in range(4):
			row.append(Vector2(0.0, 0.0))
		density_matrix.append(row)


## Measurement Operations

func measure_qubit_a() -> String:
	# Measure qubit A, collapsing joint state

	# Uses partial trace to get reduced density matrix for A,
	# then samples from Born rule, then collapses full state.

	# Returns: north_emoji_a or south_emoji_a
	# Compute reduced density matrix for qubit A: ρ_A = Tr_B(ρ)
	var rho_a = _partial_trace_a()  # FIX: _partial_trace_a() computes ρ_A

	# Probability of measuring north (0): P(0) = ρ_A[0][0]
	var prob_north = rho_a[0][0].x  # Real part (should be real anyway)

	# Sample from Born rule
	var result_north = randf() < prob_north
	var result = 0 if result_north else 1
	var result_emoji = north_emoji_a if result_north else south_emoji_a

	# Collapse full state based on measurement
	_collapse_qubit_a(result)

	if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_QUANTUM") == "1":
		print("📏 Measured qubit A: %s (P=%.2f)" % [result_emoji, prob_north if result_north else (1.0 - prob_north)])

	return result_emoji


func measure_qubit_b() -> String:
	# Measure qubit B, collapsing joint state

	# Returns: north_emoji_b or south_emoji_b
	var rho_b = _partial_trace_b()  # FIX: _partial_trace_b() computes ρ_B
	var prob_north = rho_b[0][0].x

	var result_north = randf() < prob_north
	var result = 0 if result_north else 1
	var result_emoji = north_emoji_b if result_north else south_emoji_b

	_collapse_qubit_b(result)

	if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_QUANTUM") == "1":
		print("📏 Measured qubit B: %s (P=%.2f)" % [result_emoji, prob_north if result_north else (1.0 - prob_north)])

	return result_emoji


func measure_both() -> Dictionary:
	# Measure both qubits simultaneously

	# Returns: {a: String, b: String}
	# Get joint probabilities from diagonal of density matrix
	var probs = []
	for i in range(4):
		probs.append(density_matrix[i][i].x)

	# Sample from joint distribution
	var rnd = randf()
	var cumulative = 0.0
	var outcome = 0
	for i in range(4):
		cumulative += probs[i]
		if rnd < cumulative:
			outcome = i
			break

	# Decode outcome: 0=|00⟩, 1=|01⟩, 2=|10⟩, 3=|11⟩
	var a_result = 0 if outcome < 2 else 1
	var b_result = outcome % 2

	var a_emoji = north_emoji_a if a_result == 0 else south_emoji_a
	var b_emoji = north_emoji_b if b_result == 0 else south_emoji_b

	# Collapse to product state
	_collapse_to_product_state(a_result, b_result)

	if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_QUANTUM") == "1":
		print("📏 Measured both: A=%s, B=%s" % [a_emoji, b_emoji])

	return {"a": a_emoji, "b": b_emoji}


## Partial Trace (for single-qubit measurement)

func _partial_trace_a() -> Array:
	# Compute reduced density matrix for qubit A: ρ_A = Tr_B(ρ)

	# Traces out qubit B, leaving 2×2 matrix for qubit A.
	# ρ_A[i][j] = Σ_k ρ[2i+k][2j+k]

	# Returns: 2×2 array of Vector2
	var rho_a = [
		[Vector2(0, 0), Vector2(0, 0)],
		[Vector2(0, 0), Vector2(0, 0)]
	]

	for i in range(2):
		for j in range(2):
			for k in range(2):
				rho_a[i][j] += density_matrix[2*i + k][2*j + k]

	return rho_a


func _partial_trace_b() -> Array:
	# Compute reduced density matrix for qubit B: ρ_B = Tr_A(ρ)

	# Returns: 2×2 array of Vector2
	var rho_b = [
		[Vector2(0, 0), Vector2(0, 0)],
		[Vector2(0, 0), Vector2(0, 0)]
	]

	for i in range(2):
		for j in range(2):
			for k in range(2):
				rho_b[i][j] += density_matrix[k*2 + i][k*2 + j]

	return rho_b


## Collapse Operations

func _collapse_qubit_a(result: int):
	# Collapse density matrix after measuring qubit A

	# Projects onto subspace where qubit A = result.
	# New state: P_A ρ P_A / Tr(P_A ρ)
	# where P_A = |result⟩⟨result| ⊗ I_B
	var new_rho = []
	for i in range(4):
		var row = []
		for j in range(4):
			row.append(Vector2(0, 0))
		new_rho.append(row)

	# Extract 2×2 subblock where qubit A = result
	var offset = result * 2
	for i in range(2):
		for j in range(2):
			new_rho[offset + i][offset + j] = density_matrix[offset + i][offset + j]

	# Normalize (ensure Tr(ρ) = 1)
	var trace = Vector2(0, 0)
	for i in range(4):
		trace += new_rho[i][i]

	if trace.x > 0.0001:  # Avoid division by zero
		for i in range(4):
			for j in range(4):
				new_rho[i][j] /= trace.x

	density_matrix = new_rho


func _collapse_qubit_b(result: int):
	# Collapse density matrix after measuring qubit B
	var new_rho = []
	for i in range(4):
		var row = []
		for j in range(4):
			row.append(Vector2(0, 0))
		new_rho.append(row)

	# Extract elements where qubit B = result
	# Qubit B is in the least significant bit position
	var indices = [result, 2 + result]  # 0→[0,2], 1→[1,3]

	for i in indices:
		for j in indices:
			new_rho[i][j] = density_matrix[i][j]

	# Normalize
	var trace = Vector2(0, 0)
	for i in range(4):
		trace += new_rho[i][i]

	if trace.x > 0.0001:
		for i in range(4):
			for j in range(4):
				new_rho[i][j] /= trace.x

	density_matrix = new_rho


func _collapse_to_product_state(a_result: int, b_result: int):
	# Collapse to product state |a⟩⊗|b⟩

	# Sets density matrix to pure product state.
	_initialize_density_matrix()
	var index = a_result * 2 + b_result
	density_matrix[index][index] = Vector2(1.0, 0.0)


## Quantum State Properties

func get_purity() -> float:
	# Calculate purity: Tr(ρ²)

	# Purity = 1 for pure states, < 1 for mixed states.
	# Range: [1/4, 1] for two-qubit systems.
	var rho_squared = _matrix_multiply(density_matrix, density_matrix)
	var trace = Vector2(0, 0)
	for i in range(4):
		trace += rho_squared[i][i]
	return trace.x  # Should be real


func get_entanglement_entropy() -> float:
	# Calculate entanglement entropy (von Neumann entropy of reduced state)

	# S = -Tr(ρ_A log ρ_A)

	# S = 0 for product states, S = 1 (in nats) for maximally entangled.
	var rho_a = _partial_trace_b()

	# Get eigenvalues (for 2×2 Hermitian matrix)
	var eigs = _eigenvalues_2x2(rho_a)

	# Calculate entropy: S = -Σ λ log(λ)
	var entropy = 0.0
	for eig in eigs:
		if eig > 0.0001:  # Avoid log(0)
			entropy -= eig * log(eig)

	return entropy


func get_concurrence() -> float:
	# Calculate concurrence (entanglement measure)

	# C = 0 for separable states, C = 1 for maximally entangled.

	# For two qubits: C = max(0, λ₁ - λ₂ - λ₃ - λ₄)
	# where λᵢ are square roots of eigenvalues of ρ·σ_y⊗σ_y·ρ*·σ_y⊗σ_y

	# Simplified approximation: Use purity as proxy
	# Full concurrence calculation is complex, use purity-based approximation
	var purity = get_purity()

	# For Bell states: purity = 1, concurrence = 1
	# For mixed states: approximate
	var concurrence = sqrt(max(0.0, 2.0 * purity - 0.5))

	return clamp(concurrence, 0.0, 1.0)


func is_separable() -> bool:
	# Check if state is separable (not entangled)

	# Uses purity criterion: if purity ≈ 1 and entropy ≈ 0, likely separable.
	var entropy = get_entanglement_entropy()
	return entropy < 0.1  # Threshold for "nearly zero"


## Measurement Correlations (for Emoji Entanglement)

func get_measurement_correlation() -> Dictionary:
	# Analyze measurement correlation type

	# Returns how the two qubits' measurement outcomes are related:
	# - correlation_type: "same" (|Φ⟩ bells), "opposite" (|Ψ⟩ bells), or "mixed"
	# - correlation_strength: [0, 1] how strongly correlated
	# - prob_same: Probability both collapse to same emoji
	# - prob_opposite: Probability they collapse to opposite emojis

	# Used for gameplay: entangled plots have correlated harvests!

	# Extract diagonal probabilities (measurement outcomes)
	# |00⟩, |01⟩, |10⟩, |11⟩
	var p00 = density_matrix[0][0].x  # Both north
	var p01 = density_matrix[1][1].x  # A north, B south
	var p10 = density_matrix[2][2].x  # A south, B north
	var p11 = density_matrix[3][3].x  # Both south

	var prob_same = p00 + p11  # Both same emoji
	var prob_opposite = p01 + p10  # Opposite emojis

	# Determine correlation type
	var correlation_type = "mixed"
	var correlation_strength = 0.0

	if prob_same > 0.7:
		correlation_type = "same"
		correlation_strength = prob_same
	elif prob_opposite > 0.7:
		correlation_type = "opposite"
		correlation_strength = prob_opposite
	else:
		# Mixed: neither strongly correlated nor anti-correlated
		correlation_strength = max(prob_same, prob_opposite)

	return {
		"type": correlation_type,
		"strength": correlation_strength,
		"prob_same": prob_same,
		"prob_opposite": prob_opposite,
		"concurrence": get_concurrence()
	}


## Matrix Operations (Helper Functions)

func _matrix_multiply(A: Array, B: Array) -> Array:
	# Multiply two 4×4 complex matrices

	# (A·B)[i][j] = Σ_k A[i][k] · B[k][j]
	var result = []
	for i in range(4):
		var row = []
		for j in range(4):
			var sum = Vector2(0, 0)
			for k in range(4):
				sum += _complex_multiply(A[i][k], B[k][j])
			row.append(sum)
		result.append(row)
	return result


func _complex_multiply(a: Vector2, b: Vector2) -> Vector2:
	# Multiply two complex numbers (a + bi)(c + di) = (ac - bd) + (ad + bc)i
	return Vector2(
		a.x * b.x - a.y * b.y,  # Real part
		a.x * b.y + a.y * b.x   # Imaginary part
	)


func _eigenvalues_2x2(m: Array) -> Array:
	# Calculate eigenvalues of 2×2 Hermitian matrix

	# For [[a, b], [c, d]], eigenvalues are:
	# λ = (a+d ± sqrt((a-d)² + 4|b|²)) / 2

	# Returns: [λ₁, λ₂] (both real for Hermitian matrix)
	var a = m[0][0].x  # Should be real (diagonal)
	var d = m[1][1].x
	var b = m[0][1]

	var trace = a + d
	var b_squared = b.x * b.x + b.y * b.y
	var discriminant = sqrt(max(0.0, (a - d) * (a - d) + 4.0 * b_squared))

	var lambda1 = (trace + discriminant) / 2.0
	var lambda2 = (trace - discriminant) / 2.0

	return [lambda1, lambda2]


## Debug

func get_debug_string() -> String:
	var purity = get_purity()
	var entropy = get_entanglement_entropy()
	var concurrence = get_concurrence()

	var state_type = ""
	if is_separable():
		state_type = "Separable"
	elif concurrence > 0.9:
		state_type = "Maximally Entangled"
	else:
		state_type = "Partially Entangled"

	return "%s ↔ %s | %s | P=%.3f S=%.3f C=%.3f" % [
		qubit_a_id, qubit_b_id, state_type, purity, entropy, concurrence
	]


func print_density_matrix():
	# Debug: Print density matrix
	print("\n=== Density Matrix (%s ↔ %s) ===" % [qubit_a_id, qubit_b_id])
	print("Basis: |00⟩ |01⟩ |10⟩ |11⟩")
	for i in range(4):
		var row_str = ""
		for j in range(4):
			var elem = density_matrix[i][j]
			if abs(elem.y) < 0.001:
				row_str += "%6.3f    " % elem.x
			else:
				row_str += "%6.3f%+.3fi " % [elem.x, elem.y]
		print(row_str)
	print("Purity: %.3f | Entropy: %.3f | Concurrence: %.3f" % [get_purity(), get_entanglement_entropy(), get_concurrence()])
	print("==================\n")
