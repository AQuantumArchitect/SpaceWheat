class_name QuantumEvolver
extends RefCounted

const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const DensityMatrix = preload("res://Core/QuantumSubstrate/DensityMatrix.gd")
const Hamiltonian = preload("res://Core/QuantumSubstrate/Hamiltonian.gd")
const LindbladSuperoperator = preload("res://Core/QuantumSubstrate/LindbladSuperoperator.gd")

## QuantumEvolver: Numerical integration engine for quantum dynamics
##
## Solves the Lindblad master equation:
##   dρ/dt = -i[H,ρ] + Σₖ γₖ D[Lₖ](ρ)
##
## Integration methods:
## - EULER: First-order Euler (fast but approximate)
## - CAYLEY: Cayley form for unitary part (exactly unitary, good for small dt)
## - EXPM: Full matrix exponential (most accurate, slower)
## - RK4: 4th order Runge-Kutta for full Lindblad (best for strong dissipation)
##
## Default behavior:
## - Small systems (N ≤ 12): CAYLEY for unitarity, Euler for Lindblad
## - Large systems (N > 12): EULER for performance

enum IntegrationMethod {
	EULER,      # Fast, approximate
	CAYLEY,     # Exactly unitary Hamiltonian
	EXPM,       # Full matrix exponential
	RK4         # 4th order Runge-Kutta
}

var method: IntegrationMethod = IntegrationMethod.CAYLEY
var hamiltonian: Hamiltonian
var lindblad: LindbladSuperoperator
var _dimension: int = 0
var _time: float = 0.0  # Accumulated simulation time

## Sparse operations optimization
var use_sparse_operations: bool = true  # Use sparse matrix operations for better performance

## Performance tracking
var _evolution_count: int = 0
var _total_evolution_time_ms: float = 0.0

#region Construction

func _init():
	pass

## Initialize with Hamiltonian and Lindblad superoperator
func initialize(H: Hamiltonian, L: LindbladSuperoperator) -> void:
	hamiltonian = H
	lindblad = L
	_dimension = H.dimension()

	# Choose default method based on system size
	if _dimension <= 12:
		method = IntegrationMethod.CAYLEY
	else:
		method = IntegrationMethod.EULER

## Set integration method
func set_method(m: IntegrationMethod) -> void:
	method = m

#endregion

#region Evolution

## Evolve density matrix by timestep dt
## Returns evolved density matrix (does not modify input)
func evolve(rho, dt: float):
	var start_time = Time.get_ticks_usec()

	# Update time-dependent Hamiltonian
	hamiltonian.update(_time)

	var result: DensityMatrix

	match method:
		IntegrationMethod.EULER:
			result = _evolve_euler(rho, dt)
		IntegrationMethod.CAYLEY:
			result = _evolve_cayley(rho, dt)
		IntegrationMethod.EXPM:
			result = _evolve_expm(rho, dt)
		IntegrationMethod.RK4:
			result = _evolve_rk4(rho, dt)
		_:
			result = _evolve_euler(rho, dt)

	_time += dt
	_evolution_count += 1
	_total_evolution_time_ms += (Time.get_ticks_usec() - start_time) / 1000.0

	return result

## Evolve in place (modifies the density matrix directly)
func evolve_in_place(rho, dt: float) -> void:
	var evolved = evolve(rho, dt)
	rho.set_matrix(evolved.get_matrix())

#endregion

#region Integration Methods

## Euler method: simple first-order
## ρ(t+dt) ≈ ρ(t) + dt × dρ/dt
func _evolve_euler(rho, dt: float):
	var result = rho.duplicate_density()
	var rho_mat = result.get_matrix()

	# Unitary part: -i[H,ρ]
	var commutator: ComplexMatrix
	if use_sparse_operations:
		# Use sparse commutator (much faster for sparse Hamiltonians)
		commutator = hamiltonian.get_sparse_commutator(rho_mat)
	else:
		# Use dense commutator (original method)
		var H_mat = hamiltonian.get_matrix()
		commutator = H_mat.commutator(rho_mat)

	var unitary_change = commutator.scale(Complex.new(0.0, -dt))
	rho_mat = rho_mat.add(unitary_change)
	result.set_matrix(rho_mat)

	# Dissipative part
	if use_sparse_operations:
		# Use sparse Lindblad application (much faster for jump operators)
		result = lindblad.apply_sparse(result, dt)
	else:
		# Use dense Lindblad application (original method)
		result = lindblad.apply(result, dt)

	# Enforce validity
	result._enforce_hermitian()
	result._enforce_trace_one()

	return result

## Cayley method: exactly unitary for Hamiltonian part
## U = (I - iHdt/2)⁻¹(I + iHdt/2)
## Then ρ' = UρU† + Lindblad
func _evolve_cayley(rho, dt: float):
	var result = rho.duplicate_density()

	# Get Cayley unitary
	var U = hamiltonian.get_cayley_operator(dt)

	# Apply unitary evolution: ρ' = UρU†
	result.apply_unitary(U)

	# Apply Lindblad
	if use_sparse_operations:
		# Use sparse Lindblad application (much faster for jump operators)
		result = lindblad.apply_sparse(result, dt)
	else:
		# Use dense Lindblad application (original method)
		result = lindblad.apply(result, dt)

	# Enforce validity
	result._enforce_hermitian()
	result._enforce_trace_one()

	return result

## Full matrix exponential method
## U = exp(-iH dt)
## ρ' = UρU† + Lindblad
func _evolve_expm(rho, dt: float):
	var result = rho.duplicate_density()

	# Get exact unitary
	var U = hamiltonian.get_evolution_operator(dt)

	# Apply unitary evolution
	result.apply_unitary(U)

	# Apply Lindblad
	if use_sparse_operations:
		# Use sparse Lindblad application (much faster for jump operators)
		result = lindblad.apply_sparse(result, dt)
	else:
		# Use dense Lindblad application (original method)
		result = lindblad.apply(result, dt)

	# Enforce validity
	result._enforce_hermitian()
	result._enforce_trace_one()

	return result

## 4th order Runge-Kutta for full Lindblad master equation
## Best when dissipation is strong relative to coherent dynamics
func _evolve_rk4(rho, dt: float):
	# RK4 stages
	var k1 = _compute_drho_dt(rho)
	var rho_2 = _add_scaled_matrix(rho, k1, dt / 2.0)
	var k2 = _compute_drho_dt(rho_2)
	var rho_3 = _add_scaled_matrix(rho, k2, dt / 2.0)
	var k3 = _compute_drho_dt(rho_3)
	var rho_4 = _add_scaled_matrix(rho, k3, dt)
	var k4 = _compute_drho_dt(rho_4)

	# Combine: ρ' = ρ + (dt/6)(k1 + 2k2 + 2k3 + k4)
	var result = rho.duplicate_density()
	var rho_mat = result.get_matrix()

	var combined = k1.add(k2.scale_real(2.0)).add(k3.scale_real(2.0)).add(k4)
	rho_mat = rho_mat.add(combined.scale_real(dt / 6.0))
	result.set_matrix(rho_mat)

	# Enforce validity
	result._enforce_hermitian()
	result._enforce_trace_one()

	return result

## Compute dρ/dt = -i[H,ρ] + Σ D[L](ρ)
func _compute_drho_dt(rho) -> ComplexMatrix:
	var rho_mat = rho.get_matrix()
	var H_mat = hamiltonian.get_matrix()

	# Unitary part: -i[H,ρ]
	var commutator = H_mat.commutator(rho_mat)
	var result = commutator.scale(Complex.new(0.0, -1.0))

	# Lindblad part
	for term in lindblad.get_terms():
		var L = term.L
		var rate = term.rate
		var L_dag = L.dagger()
		var L_dag_L = L_dag.mul(L)

		var term1 = L.mul(rho_mat).mul(L_dag)
		var term2 = L_dag_L.mul(rho_mat).scale_real(0.5)
		var term3 = rho_mat.mul(L_dag_L).scale_real(0.5)

		var dissipator = term1.sub(term2).sub(term3)
		result = result.add(dissipator.scale_real(rate))

	return result

## Helper: add scaled matrix to density matrix
func _add_scaled_matrix(rho, delta: ComplexMatrix, scale: float):
	var result = rho.duplicate_density()
	var new_mat = result.get_matrix().add(delta.scale_real(scale))
	result.set_matrix(new_mat)
	return result

#endregion

#region Time Management

## Get current simulation time
func get_time() -> float:
	return _time

## Set simulation time (for synchronization)
func set_time(t: float) -> void:
	_time = t

## Reset time to zero
func reset_time() -> void:
	_time = 0.0

#endregion

#region Performance

## Get average evolution time in milliseconds
func get_average_evolution_time_ms() -> float:
	if _evolution_count == 0:
		return 0.0
	return _total_evolution_time_ms / _evolution_count

## Reset performance counters
func reset_performance_counters() -> void:
	_evolution_count = 0
	_total_evolution_time_ms = 0.0

## Get evolution count
func get_evolution_count() -> int:
	return _evolution_count

#endregion

#region Validation

## Validate that evolution preserves density matrix properties
func validate_evolution(rho, dt: float, steps: int = 10) -> Dictionary:
	var test_rho = rho.duplicate_density()
	var initial_trace = test_rho.get_trace()
	var initial_purity = test_rho.get_purity()

	var max_trace_error = 0.0
	var positivity_ok = true

	for i in range(steps):
		test_rho = evolve(test_rho, dt)
		var trace_error = abs(test_rho.get_trace() - 1.0)
		if trace_error > max_trace_error:
			max_trace_error = trace_error

		var validation = test_rho.is_valid()
		if not validation.positive_semidefinite:
			positivity_ok = false

	return {
		"trace_preserved": max_trace_error < 1e-6,
		"max_trace_error": max_trace_error,
		"positivity_preserved": positivity_ok,
		"initial_trace": initial_trace,
		"final_trace": test_rho.get_trace(),
		"initial_purity": initial_purity,
		"final_purity": test_rho.get_purity()
	}

#endregion

#region Debug

func _to_string() -> String:
	var method_name = ["EULER", "CAYLEY", "EXPM", "RK4"][method]
	return "QuantumEvolver(method=%s, t=%.3f)" % [method_name, _time]

func debug_print() -> void:
	var method_name = ["EULER", "CAYLEY", "EXPM", "RK4"][method]
	print("=== Quantum Evolver ===")
	print("Integration method: %s" % method_name)
	print("Dimension: %d" % _dimension)
	print("Simulation time: %.3f" % _time)
	print("Evolution count: %d" % _evolution_count)
	print("Avg evolution time: %.3f ms" % get_average_evolution_time_ms())

#endregion
