class_name QuantumComputer
extends Resource

## Central quantum state core for one biome (Model C Architecture)
##
## The QuantumComputer is the ONLY owner of quantum state for the biome.
## Uses a single density_matrix with RegisterMap for emoji↔qubit coordination.
## Entanglement tracked via entanglement_graph metadata (adjacency lists).
##
## In the shipped closed system this core IS the story's "enclave"
## (docs/glossary/enclave.md): evolution is exact-unitary — ρ → UρU†, trace and
## purity conserved to machine precision — the authored Lindblad webway is sealed
## (docs/glossary/webway.md; LindbladBuilder builds zero operators), and projective
## measurement is the single irreversible operation (docs/glossary/measurement.md —
## measurement IS the economy).

# Sparse-matrix optimization is now handled by the native C++ backend.

func _log(level: String, category: String, emoji: String, message: String) -> void:
	VerboseHelper.log(level, category, emoji, message)

@export var biome_name: String = ""

## Per-biome thermodynamic regime — the What Fades seam (docs/OPEN_CAMPAIGN.md).
## "" = inherit the global switches (BalanceConfig); "open" = this biome runs
## dissipative even while the world is sealed (wet country: the Fallow, the
## circuit shelf); "closed" = this biome stays unitary even after the door
## opens (the island enclave — inviolable, owner decision 2026-07-04).
## Honored at the three physics sites: the Lindblad build gate, the exact-unitary
## evolve kernel, and ground-state init.
var regime_override: String = ""


## Is THIS biome's dissipative generator active? (per-biome regime, then global)
func is_open_here() -> bool:
	if regime_override == "open":
		return true
	if regime_override == "closed":
		return false
	return BalanceConfig.dissipative_enabled()


## Is THIS biome purely unitary? (r = 1 exactly; exact-propagator kernel + pure init)
func is_closed_here() -> bool:
	return BalanceConfig.coherent_enabled() and not is_open_here()


## Model C (Analog Upgrade): RegisterMap-based architecture
var register_map: RegisterMap = RegisterMap.new()
var density_matrix: ComplexMatrix = null

## Per-qubit Berry phase (geometric solid angle) tracking. Sim-side truth;
## viz layer reads from here. Headless-visible.
var berry_register: BerryPhaseRegister = BerryPhaseRegister.new()

## Lindblad evolution operators (set by biome via HamiltonianBuilder/LindbladBuilder)
var hamiltonian: ComplexMatrix = null         # H matrix (Hermitian, dim×dim)
var lindblad_operators: Array = []            # Array of L_k matrices (ComplexMatrix)

## CACHED Lindblad pre-computations (rebuilt when operators change)
## L_dag[k] = L_k†,  Ldag_L[k] = L_k† L_k — saves 2 matmuls per operator per substep
var _lindblad_L_dag: Array = []              # Array of L_k† (ComplexMatrix)
var _lindblad_Ldag_L: Array = []             # Array of L_k† L_k (ComplexMatrix)
var _lindblad_cache_valid: bool = false

## SPARSE optimized operators (10-50x faster for sparse Hamiltonians/Lindblad)
var sparse_hamiltonian = null                 # SparseMatrix (auto-converted if sparse)
var sparse_lindblad_operators: Array = []     # Array of SparseMatrix (auto-converted)

## CLOSED-SYSTEM unitary propagator cache. In the closed (unitary) system, evolution is
## the EXACT map ρ → U ρ U† with U = exp(−iH·dt) — purity-conserving to machine precision
## (no Euler drift). U depends only on (H, dt); it is rebuilt when H is reassigned (ref
## changes), mutated in place (_unitary_dirty), or dt changes. Static-H biomes reuse one U.
var _unitary_cache = null                     # ComplexMatrix U = exp(−iH·dt)
var _unitary_cache_dt: float = -1.0
var _unitary_cache_h = null                   # the hamiltonian instance U was built from
var _unitary_dirty: bool = false              # set when H is mutated in place

## CACHED MUTUAL INFORMATION (computed in C++ during evolution at 5Hz)
## Format: {qubit_pair_index: mi_value} where index = i * num_qubits + j (upper triangular)
## Access via get_cached_mutual_information(qubit_a, qubit_b)
var _cached_mi_values: PackedFloat64Array = PackedFloat64Array()

## Time-dependent driver configurations (set via set_driven_icons)
## Format: [{emoji, qubit, pole, icon_ref, driver_type, base_energy}, ...]
## Used to update Hamiltonian diagonal terms each frame for oscillating self-energies
var driven_icons: Array = []
var _last_driver_update_time: float = -1.0  # Track when we last updated drivers

@export var entanglement_graph: Dictionary = {}  # register_id → Array[register_id] (adjacency)

## Cached native engine used solely for Bloch metric computation.
## compute_bloch_metrics_from_packed is a pure const function — no H/L setup needed.
var _bloch_engine: QuantumEvolutionEngine = null

## Phase 3: Register-level infrastructure (gates, lindblad, theta_frozen, entanglement blueprints)
## Persists per-biome, survives harvest/replant naturally.
var register_infrastructure: Dictionary = {}  # register_id → {field: value}

## Phase 4: Energy tap flux tracking
## Accumulated energy flux per tapped emoji (accumulated this frame from Lindblad drain operators)
var sink_flux_per_emoji: Dictionary = {}  # emoji → float (accumulated flux)
var _last_renorm_trace_before_cap: float = 1.0
var _last_renorm_scale: float = 1.0
var _cumulative_renorm_excess: float = 0.0
var _catastrophic_recovery_count: int = 0

## TIME TRACKING FOR TIME-DEPENDENT HAMILTONIAN
## Tracks elapsed time to apply time-dependent drivers (e.g., sun oscillation)
var elapsed_time: float = 0.0  # Total time elapsed since biome initialization

## PHASE MODULATION VIA LEARNED NEURAL NETWORK (Phasic Shadow)
## Flip ENABLE_PHASE_LNN to true and assign a native LNN binding to phase_lnn
## to activate phasic perturbation during evolution. Useful for nudging biomes
## out of stuck attractors or testing sensitivity. C++ implementation lives in
## native/src/liquid_neural_net.cpp (see NATIVE_LNN_IMPLEMENTATION.md).
const ENABLE_PHASE_LNN: bool = false
var phase_lnn = null  # Assign a native LiquidNeuralNetNative instance to activate

# Performance: Purity cache (invalidated on density matrix changes)
var _purity_cache: float = -1.0
var _sparse_evolution_enabled_cached: int = -1  # -1 unknown, 0 false, 1 true


func _sparse_evolution_enabled() -> bool:
	if _sparse_evolution_enabled_cached < 0:
		var raw = OS.get_environment("SW_ENABLE_SPARSE_EVOLVE").to_lower()
		_sparse_evolution_enabled_cached = 1 if raw in ["1", "true", "yes", "on"] else 0
	return _sparse_evolution_enabled_cached == 1

func _init(name: String = ""):
	biome_name = name


func clear() -> void:
	# Release runtime state so biome/session teardown can break ref cycles.
	if register_map and register_map.has_method("clear"):
		register_map.clear()
	register_map = RegisterMap.new()
	density_matrix = null
	hamiltonian = null
	lindblad_operators.clear()
	_lindblad_L_dag.clear()
	_lindblad_Ldag_L.clear()
	_lindblad_cache_valid = false
	sparse_hamiltonian = null
	sparse_lindblad_operators.clear()
	driven_icons.clear()
	entanglement_graph.clear()
	register_infrastructure.clear()
	if berry_register:
		berry_register.clear()
	sink_flux_per_emoji.clear()
	_cached_mi_values = PackedFloat64Array()
	phase_lnn = null
	_purity_cache = -1.0


func restore_register_map_from_axes(axes_data: Array) -> bool:
	# Rebuild the RegisterMap from serialized axis data.
	#
	# This is used by save/load so a restored density_matrix is not left
	# stranded on a zero-qubit register_map.
	if register_map == null:
		register_map = RegisterMap.new()
	elif register_map.has_method("clear"):
		register_map.clear()

	var restored_any := false
	for axis_data in axes_data:
		if not (axis_data is Dictionary):
			continue
		var qubit_raw = axis_data.get("qubit", -1)
		var north_raw = axis_data.get("north", "")
		var south_raw = axis_data.get("south", "")
		if not str(qubit_raw).is_valid_int():
			continue
		var qubit_index := int(qubit_raw)
		var north_emoji := str(north_raw)
		var south_emoji := str(south_raw)
		if north_emoji == "" or south_emoji == "":
			continue
		register_map.register_axis(qubit_index, north_emoji, south_emoji)
		_ensure_entanglement_node(qubit_index)
		_ensure_register_infra(qubit_index)
		restored_any = true

	if restored_any:
		_log("debug", "quantum", "🧩", "Restored register map from %d serialized axes" % axes_data.size())
	return restored_any


func _ensure_entanglement_node(reg_id: int) -> void:
	if not entanglement_graph.has(reg_id):
		entanglement_graph[reg_id] = []


func _collect_component_registers(reg_id: int) -> Array[int]:
	var visited: Dictionary = {}
	var queue: Array = [reg_id]

	while queue.size() > 0:
		var current = queue.pop_front()
		if visited.has(current):
			continue
		visited[current] = true
		for neighbor in entanglement_graph.get(current, []):
			if not visited.has(neighbor):
				queue.append(neighbor)

	var result: Array[int] = []
	for key in visited.keys():
		result.append(int(key))
	result.sort()
	return result

## ============================================================================
## UNITARY GATE OPERATIONS (Model C)
## ============================================================================

func _embed_1q_unitary(U: ComplexMatrix, target_index: int, num_qubits: int) -> ComplexMatrix:
	# Embed 1Q gate U at target_index into full Hilbert space.

	# Result: I ⊗ ... ⊗ U ⊗ ... ⊗ I (where U is at target_index)

	# Sparse optimization: only non-zero blocks computed.
	if target_index == 0:
		# U ⊗ I^(n-1)
		var I = ComplexMatrix.identity(1 << (num_qubits - 1))
		return U.tensor_product(I)
	elif target_index == num_qubits - 1:
		# I^(n-1) ⊗ U
		var I = ComplexMatrix.identity(1 << (num_qubits - 1))
		return I.tensor_product(U)
	else:
		# I ⊗ ... ⊗ U ⊗ I ⊗ ... ⊗ I (middle)
		# Recursively build left and right
		var left_I = ComplexMatrix.identity(1 << target_index)
		var right_I = ComplexMatrix.identity(1 << (num_qubits - target_index - 1))

		# (I_left ⊗ U) ⊗ I_right
		var left_part = left_I.tensor_product(U)
		return left_part.tensor_product(right_I)

func _embed_2q_unitary(U: ComplexMatrix, idx_a: int, idx_b: int, num_qubits: int) -> ComplexMatrix:
	# Embed 2Q gate U at indices (idx_a, idx_b) into full Hilbert space.

	# Result: I ⊗ ... ⊗ U_{ab} ⊗ ... ⊗ I
	# where U_{ab} acts on qubits at idx_a and idx_b.

	# Convention: Uses MSB indexing (qubit 0 = most significant bit) to match _embed_1q_unitary.
	# For CNOT, idx_a is control and idx_b is target.

	# Implementation: Builds full 4-dimensional operator by iterating over all basis states,
	# applying U only to the (idx_a, idx_b) subspace and passing through other qubits.
	# NOTE: Do NOT swap idx_a and idx_b - order matters for non-symmetric gates like CNOT!

	var total_dim = 1 << num_qubits
	var result = ComplexMatrix.new(total_dim)

	# Build operator by iterating over all 2Q basis states and embedding
	# For basis state |i_a, i_b⟩ at (idx_a, idx_b) with other indices fixed:
	# The operator applies U to (i_a, i_b) and passes through other qubits

	# Iterate over all basis states
	for out_basis in range(total_dim):
		# Decompose output basis state into qubit indices (MSB convention)
		var out_qubits = _decompose_basis_msb(out_basis, num_qubits)

		for in_basis in range(total_dim):
			# Decompose input basis state (MSB convention)
			var in_qubits = _decompose_basis_msb(in_basis, num_qubits)

			# Check if non-target qubits match (pass-through condition)
			var pass_through = true
			for q in range(num_qubits):
				if q != idx_a and q != idx_b:
					if out_qubits[q] != in_qubits[q]:
						pass_through = false
						break

			if not pass_through:
				continue  # Skip: non-target qubits don't match

			# Extract 2-qubit indices for U
			# idx_a is high bit (control for CNOT), idx_b is low bit (target for CNOT)
			var in_2q_idx = (in_qubits[idx_a] << 1) | in_qubits[idx_b]
			var out_2q_idx = (out_qubits[idx_a] << 1) | out_qubits[idx_b]

			# Get U[out_2q, in_2q]
			var u_element = U.get_element(out_2q_idx, in_2q_idx)

			# Set result[out_basis, in_basis] = U[out_2q, in_2q]
			result.set_element(out_basis, in_basis, u_element)

	return result


func _decompose_basis_msb(basis: int, num_qubits: int) -> Array[int]:
	# Decompose a basis state index into individual qubit indices (MSB convention).

	# MSB convention: qubit index k corresponds to bit (n-1-k).
	# This matches _embed_1q_unitary where qubit 0 affects the most significant bit.

	# For num_qubits=3, basis=5 (binary 101):
	# - qubit 0 = bit 2 = 1
	# - qubit 1 = bit 1 = 0
	# - qubit 2 = bit 0 = 1
	# Returns [1, 0, 1]
	var qubits: Array[int] = []
	for i in range(num_qubits):
		var bit_pos = num_qubits - 1 - i
		qubits.append((basis >> bit_pos) & 1)
	return qubits


## ============================================================================
## MEASUREMENT (Ace Frame Backend)
## ============================================================================

func inspect_register_distribution(_comp, reg_id: int) -> Dictionary:
	# Non-destructive peek at measurement probabilities.

	# Returns marginal probabilities WITHOUT collapsing state.
	# This is simulator introspection, not physical measurement.

	# Returns: {north: float, south: float}
	var p0 = get_marginal(reg_id, 0)
	var p1 = get_marginal(reg_id, 1)
	return {"north": p0, "south": p1}

func _project_component_state(_comp, reg_id: int, outcome_idx: int) -> void:
	# Apply projector to component state after measurement.

	# outcome_idx: 0 = |0⟩ (north), 1 = |1⟩ (south)

	# Math: ρ' = P ρ P† / Tr(P ρ P†) where P = |outcome⟩⟨outcome|
	project_qubit(reg_id, outcome_idx)

## ============================================================================
## ENTANGLEMENT (Operator Frame Backend)
## ============================================================================

func entangle_plots(reg_a: int, reg_b: int) -> bool:
	# Entangle two registers (from same biome) using Bell circuit.

	# Circuit: H on reg_a, then CNOT(reg_a, reg_b)
	# Result: Bell Φ+ = (|00⟩ + |11⟩) / √2

	# Merges components if in different connected sets.
	if density_matrix == null:
		push_error("Entanglement attempted without density_matrix")
		return false

	# Apply Bell circuit (Model C)
	var H = QuantumGateLibrary.get_gate("H")["matrix"]
	if not apply_gate(reg_a, H):
		return false

	var CNOT = QuantumGateLibrary.get_gate("CNOT")["matrix"]
	if not apply_gate_2q(reg_a, reg_b, CNOT):
		return false

	# Track entanglement metadata
	_ensure_entanglement_node(reg_a)
	_ensure_entanglement_node(reg_b)
	if reg_b not in entanglement_graph[reg_a]:
		entanglement_graph[reg_a].append(reg_b)
	if reg_a not in entanglement_graph[reg_b]:
		entanglement_graph[reg_b].append(reg_a)

	return true

func get_entangled_component(reg_id: int) -> Array[int]:
	# Get all registers entangled with this one (in same component).
	if reg_id < 0:
		return []
	return _collect_component_registers(reg_id)


## ============================================================================
## UTILITY METHODS
## ============================================================================

func get_marginal_density_matrix(_comp, reg_id: int) -> ComplexMatrix:
	# Get 2×2 marginal density matrix for one register (Model C).
	var result = ComplexMatrix.new(2)
	if density_matrix == null:
		return result

	var num_qubits = register_map.num_qubits
	if reg_id < 0 or reg_id >= num_qubits:
		return result

	var dim = register_map.dim()
	var shift = num_qubits - 1 - reg_id
	var target_bit = 1 << shift
	var mask_other = (dim - 1) ^ target_bit

	for i in range(dim):
		var i_other = i & mask_other
		var i_bit = (i >> shift) & 1
		for j in range(dim):
			if (j & mask_other) != i_other:
				continue
			var j_bit = (j >> shift) & 1
			var accum = result.get_element(i_bit, j_bit)
			result.set_element(i_bit, j_bit, accum.add(density_matrix.get_element(i, j)))

	return result

func get_marginal_probability_subspace(_comp, reg_id: int, _basis_labels: Array[String]) -> float:
	# Get total probability in subspace spanned by two basis states.

	# Used for plots with (north_emoji, south_emoji) basis.
	# Returns: P(north) + P(south)
	var marginal = get_marginal_density_matrix(null, reg_id)
	var p0 = marginal.get_element(0, 0).re
	var p1 = marginal.get_element(1, 1).re
	return p0 + p1

func get_marginal_purity(_comp, reg_id: int) -> float:
	# Get purity of marginal state for one register.
	var marginal = get_marginal_density_matrix(null, reg_id)
	var rho_sq = marginal.mul(marginal)
	return clamp(rho_sq.trace().re, 0.0, 1.0)

func get_marginal_coherence(_comp, reg_id: int) -> float:
	# Get coherence (off-diagonal element) for one register.
	var marginal = get_marginal_density_matrix(null, reg_id)
	return marginal.get_element(0, 1).abs()


func get_attractor_state() -> Dictionary:
	# Return the biome's attractor — the dominant eigenstate of the current ρ.
	#
	# The dominant eigenvector is the pure state the biome is most "trying to
	# become" given its current Hamiltonian and Lindblad dissipation. It answers
	# "what would this biome look like if left to fully relax?"
	#
	# Returns:
	#   {emoji: float}  — per-emoji probability in the dominant mode
	#   "dominant_eigenvalue": float  — weight of this mode (max = 1.0 for pure state)
	#   "eigenvalue_gap": float  — separation from next mode (large gap = strong attractor)
	#   "emojis": Array[String]  — emojis sorted descending by attractor probability
	if not _bloch_engine or not density_matrix or not register_map:
		return {}
	var dim_expected := register_map.dim()
	if dim_expected <= 0:
		return {}
	var packed := density_matrix._to_packed()
	# Guard: packed must be exactly 2*dim² floats (re+im per element).
	if packed.size() != dim_expected * dim_expected * 2:
		return {}
	# Ensure engine dimension matches this biome before calling Eigen.
	if _bloch_engine.get_dimension() != dim_expected:
		_bloch_engine.set_dimension(dim_expected)
	var result = _bloch_engine.compute_eigenstates(packed)
	if result.is_empty() or result.has("error"):
		return {}

	var dominant_vec: PackedFloat64Array = result["dominant_eigenvector"]
	var eigenvalues: PackedFloat64Array = result["eigenvalues"]
	var dominant_ev: float = result.get("dominant_eigenvalue", 0.0)
	var dim := register_map.dim()
	var nq := register_map.num_qubits

	# Per-qubit marginals: P(qubit q = pole p | dominant eigenvector)
	# = Σ_{basis i where qubit q == p} |ψ_i|²
	var qubit_marginals: Array = []  # qubit_marginals[q][p] = probability
	qubit_marginals.resize(nq)
	for q in range(nq):
		qubit_marginals[q] = [0.0, 0.0]

	for i in range(dim):
		var re: float = dominant_vec[i * 2]
		var im: float = dominant_vec[i * 2 + 1]
		var prob: float = re * re + im * im
		for q in range(nq):
			var shift := nq - 1 - q
			var pole_idx := (i >> shift) & 1
			qubit_marginals[q][pole_idx] += prob

	# Build emoji-keyed output
	var out: Dictionary = {}
	for q in range(nq):
		var axis := register_map.axis(q)
		var north: String = axis.get("north", "")
		var south: String = axis.get("south", "")
		if north != "":
			out[north] = qubit_marginals[q][0]
		if south != "":
			out[south] = qubit_marginals[q][1]

	out["dominant_eigenvalue"] = dominant_ev
	out["eigenvalue_gap"] = (dominant_ev - float(eigenvalues[1])) if eigenvalues.size() > 1 else dominant_ev

	# Convenience: emojis sorted by attractor probability (descending)
	var emoji_probs: Array = []
	for emoji in out:
		if emoji in ["dominant_eigenvalue", "eigenvalue_gap", "emojis"]:
			continue
		emoji_probs.append({"emoji": emoji, "p": out[emoji]})
	emoji_probs.sort_custom(func(a, b): return a.p > b.p)
	out["emojis"] = emoji_probs.map(func(e): return e.emoji)

	return out


func export_bloch_packet() -> PackedFloat64Array:
	# Export current state as Bloch packet via native C++ engine.
	# Format: [p0, p1, x, y, z, r, theta, phi, r_xy] per qubit (stride=9)
	if not _bloch_engine:
		_bloch_engine = QuantumEvolutionEngine.new()
	if not _bloch_engine:
		push_error("QuantumComputer: native QuantumEvolutionEngine unavailable — bloch packet empty")
		return PackedFloat64Array()
	if not density_matrix or not register_map:
		return PackedFloat64Array()
	var nq := register_map.num_qubits
	var dim := register_map.dim()
	var packed := density_matrix._to_packed()
	if packed.size() != dim * dim * 2:
		return PackedFloat64Array()
	# set_dimension ensures m_dim matches this biome before any Eigen operations.
	# Without this, a freshly-created engine has m_dim=0 → 0×0 matrix → crash.
	if _bloch_engine.get_dimension() != dim:
		_bloch_engine.set_dimension(dim)
	return _bloch_engine.compute_bloch_metrics_from_packed(packed, nq)


## ============================================================================
## PHASE 4: ENERGY TAP SINK FLUX TRACKING
## ============================================================================

func get_sink_flux(emoji: String) -> float:
	# Get accumulated energy flux that drained to sink state from an emoji this frame.

	# Manifest Section 4.1: Lindblad drain operators L_e = |sink⟩⟨e| transfer
	# population from emoji to sink state. This tracks how much was drained.

	# Called during each frame to collect energy from energy tap plots.
	return sink_flux_per_emoji.get(emoji, 0.0)

func get_all_sink_fluxes() -> Dictionary:
	# Get dictionary of all accumulated fluxes per emoji this frame.

	# Returns: {emoji: float} of all drained energies
	return sink_flux_per_emoji.duplicate()


func add_sink_flux(emoji: String, amount: float) -> void:
	# Accumulate positive sink flux for one emoji.
	if emoji == "" or amount <= 0.0:
		return
	sink_flux_per_emoji[emoji] = float(sink_flux_per_emoji.get(emoji, 0.0)) + amount


func consume_sink_flux(emoji: String, amount: float) -> float:
	# Consume sink flux so payouts and reap do not double count the same mass.
	if emoji == "" or amount <= 0.0:
		return 0.0
	var available = float(sink_flux_per_emoji.get(emoji, 0.0))
	if available <= 0.0:
		return 0.0
	var consumed = min(available, amount)
	var remaining = available - consumed
	if remaining <= 1e-12:
		sink_flux_per_emoji.erase(emoji)
	else:
		sink_flux_per_emoji[emoji] = remaining
	return consumed


func accumulate_sink_flux_from_rates(rate_map: Dictionary, dt: float) -> void:
	# Accumulate flux from structural Lindblad rates and current emoji populations.
	if rate_map.is_empty() or dt <= 0.0:
		return
	for key in rate_map.keys():
		var emoji = str(key)
		if emoji == "" or not register_map.has(emoji):
			continue
		var rate = max(0.0, float(rate_map.get(key, 0.0)))
		if rate <= 0.0:
			continue
		var population = max(0.0, get_population(emoji))
		var flux = population * rate * dt
		if flux > 0.0:
			add_sink_flux(emoji, flux)


func reset_sink_flux() -> void:
	# Reset accumulated sink flux for next frame.
	sink_flux_per_emoji.clear()


func get_renorm_diagnostics() -> Dictionary:
	# Expose renormalization diagnostics for debugging only (not gameplay economy).
	return {
		"last_trace_before_cap": _last_renorm_trace_before_cap,
		"last_scale": _last_renorm_scale,
		"cumulative_trace_excess": _cumulative_renorm_excess
	}

func debug_dump() -> String:
	# Generate human-readable dump of quantum computer state.
	var s = "=== QuantumComputer %s ===\n" % biome_name
	s += "Qubits: %d\n" % register_map.num_qubits
	s += "Dim: %d\n" % register_map.dim()

	s += "Entanglement Graph:\n"
	for reg_id in entanglement_graph.keys():
		if entanglement_graph[reg_id].size() > 0:
			s += "  Register %d ↔ %s\n" % [reg_id, entanglement_graph[reg_id]]

	return s


# ============================================================================
# MODEL C: Analog Upgrade - RegisterMap-based Architecture
# ============================================================================

func allocate_axis(qubit_index: int, north_emoji: String, south_emoji: String) -> void:
	# Register a qubit axis in the RegisterMap.

	# Args:
	# qubit_index: Qubit number (0, 1, 2, ...)
	# north_emoji: Emoji for |0⟩ (north pole)
	# south_emoji: Emoji for |1⟩ (south pole)

	# Example:
	# allocate_axis(0, "🔥", "❄️")  # Qubit 0: Temperature axis
	register_map.register_axis(qubit_index, north_emoji, south_emoji)
	_ensure_entanglement_node(qubit_index)
	_ensure_register_infra(qubit_index)
	_resize_density_matrix()
	_log("debug", "quantum", "📍", "Allocated axis %d: %s (north) ↔ %s (south)" % [qubit_index, north_emoji, south_emoji])


# ============================================================================
# REGISTER INFRASTRUCTURE (per-register gates, lindblad, blueprints)
# ============================================================================

func _ensure_register_infra(reg_id: int) -> Dictionary:
	if not register_infrastructure.has(reg_id):
		register_infrastructure[reg_id] = {
			"lindblad_pump_active": false, "lindblad_pump_rate": 0.5,
			"lindblad_drain_active": false, "lindblad_drain_rate": 0.5,
			"lindblad_drain_accumulator": 0.0,
			"lindblad_harvest_visible": false,
			"theta_frozen": false,
			"persistent_gates": [],
			"entanglement_blueprints": [],
		}
	return register_infrastructure[reg_id]


func get_register_infra_field(reg_id: int, field: String, default = null):
	var infra = _ensure_register_infra(reg_id)
	return infra.get(field, default)


func set_register_infra_field(reg_id: int, field: String, value) -> void:
	var infra = _ensure_register_infra(reg_id)
	infra[field] = value


func add_persistent_gate_to_register(reg_id: int, gate_type: String, linked_registers: Array[int] = []) -> void:
	var infra = _ensure_register_infra(reg_id)
	infra["persistent_gates"].append({
		"type": gate_type,
		"active": true,
		"linked_registers": linked_registers.duplicate()
	})
	_log("debug", "quantum", "🔧", "Added persistent gate '%s' to register %d (linked: %d registers)" % [gate_type, reg_id, linked_registers.size()])


func get_active_gates_for_register(reg_id: int) -> Array[Dictionary]:
	var infra = _ensure_register_infra(reg_id)
	var active: Array[Dictionary] = []
	for gate in infra.get("persistent_gates", []):
		if gate.get("active", false):
			active.append(gate)
	return active


func clear_register_infrastructure(reg_id: int) -> void:
	if register_infrastructure.has(reg_id):
		register_infrastructure.erase(reg_id)


func _resize_density_matrix() -> void:
	# Resize density matrix when qubits are added.

	# When adding a new qubit, tensor-extends existing state with |0⟩⟨0|.
	# New qubit starts in ground state (north pole).
	var num_qubits = register_map.num_qubits
	var dim = register_map.dim()

	if density_matrix == null:
		density_matrix = ComplexMatrix.zeros(dim)
		_log("debug", "quantum", "🔧", "Created density matrix: %d qubits → %dD" % [num_qubits, dim])
	elif density_matrix.n != dim:
		# Tensor-extend: ρ_new = ρ_old ⊗ |0⟩⟨0|
		var old_dim = density_matrix.n
		var ket0_bra0 = ComplexMatrix.zeros(2)
		ket0_bra0.set_element(0, 0, Complex.one())  # |0⟩⟨0| = [[1,0],[0,0]]
		var new_density = density_matrix.tensor_product(ket0_bra0)
		density_matrix = new_density
		_log("debug", "quantum", "🔧", "Extended density matrix: %dD → %dD (tensor with |0⟩⟨0|)" % [old_dim, dim])


func initialize_basis(basis_index: int) -> void:
	# Initialize density matrix to pure state |i⟩⟨i|.

	# Args:
	# basis_index: Computational basis index (0 to 2^n - 1)

	# Example:
	# initialize_basis(7)  # |111⟩ for 3 qubits (ground state)
	var dim = register_map.dim()
	if basis_index < 0 or basis_index >= dim:
		push_error("❌ Basis index %d out of range [0, %d)" % [basis_index, dim])
		return

	density_matrix = ComplexMatrix.zeros(dim)
	density_matrix.set_element(basis_index, basis_index, Complex.one())
	_log("debug", "quantum", "🎯", "Initialized to |%d⟩ = %s" % [basis_index, register_map.basis_to_emojis(basis_index)])


func initialize_uniform_superposition() -> void:
	# Initialize density matrix to uniform superposition |ψ⟩ over all basis states.

	# |ψ⟩ = (1/√d) Σ_i |i⟩, so ρ = |ψ⟩⟨ψ| has all entries = 1/d.
	var dim = register_map.dim()
	if dim <= 0:
		push_error("❌ Cannot initialize superposition: invalid dimension %d" % dim)
		return
	density_matrix = ComplexMatrix.zeros(dim)
	var value = Complex.new(1.0 / float(dim), 0.0)
	for i in range(dim):
		for j in range(dim):
			density_matrix.set_element(i, j, value)
	_log("debug", "quantum", "✨", "Initialized to uniform superposition (dim=%d)" % dim)


func initialize_thermal(beta: float) -> void:
	# Initialize to Gibbs state ρ = exp(-βH) / Z at inverse temperature β.

	# β=0   → uniform superposition (maximally mixed)
	# β=5   → mild ecological bias toward ground state
	# β=20  → near-pure ground state (recommended for biome load)

	# Uses the static Hamiltonian H(t=0). At StarterForest energy scales (|E|≤1.5),
	# β=20 gives Boltzmann weights that are effectively the ground-state projection.
	if hamiltonian == null:
		push_warning("initialize_thermal: hamiltonian not built yet, falling back to uniform superposition")
		initialize_uniform_superposition()
		return
	var neg_beta_H = hamiltonian.scale_real(-beta)
	density_matrix = neg_beta_H.expm()
	density_matrix.renormalize_trace()
	_purity_cache = -1.0  # state changed — don't serve a stale purity
	_log("debug", "quantum", "🌡️", "Initialized to thermal state β=%.1f (dim=%d)" % [beta, register_map.dim()])


func initialize_ground_state() -> void:
	# Closed (unitary) system: start in the EXACT Hamiltonian ground state |g⟩ (the
	# lowest-energy eigenvector), ρ = |g⟩⟨g| — a pure state (r = 1), which the unitary
	# kernel then preserves for all time. Open (dissipative) system: the ecological Gibbs
	# state ρ ∝ exp(−βH) at β=20 is the correct MIXED starting point (eagle ~2%, wolf ~16%,
	# …). Falls back to uniform superposition if H is not yet built.
	if is_closed_here() and hamiltonian != null:
		if _init_pure_ground_state():
			return
	initialize_thermal(20.0)
	if is_closed_here():
		_collapse_to_dominant_eigenstate()  # fallback: purify the thermal state


## Set ρ = |g⟩⟨g| where |g⟩ is the lowest-energy eigenvector of H (the pure ground state).
## |g⟩ is the DOMINANT (largest-eigenvalue) eigenvector of −H, so we reuse the one
## eigensolver. Returns false if it's unavailable (caller falls back to thermal+purify).
func _init_pure_ground_state() -> bool:
	if hamiltonian == null:
		return false
	return _set_pure_state_from_dominant_eigenvector(hamiltonian.scale_real(-1.0))


## ρ → |v₀⟩⟨v₀|, where v₀ is the dominant eigenvector of the Hermitian `source` matrix.
## A rank-1 projector ⇒ Tr(ρ²) = 1 exactly. Returns false if the eigensolver is
## unavailable (state left untouched rather than crashing).
func _set_pure_state_from_dominant_eigenvector(source) -> bool:
	if source == null or register_map == null:
		return false
	var dim := register_map.dim()
	if dim <= 0:
		return false
	if not _bloch_engine:
		_bloch_engine = QuantumEvolutionEngine.new()
	if not _bloch_engine:
		return false
	var packed: PackedFloat64Array = source._to_packed()
	if packed.size() != dim * dim * 2:
		return false
	if _bloch_engine.get_dimension() != dim:
		_bloch_engine.set_dimension(dim)
	var result = _bloch_engine.compute_eigenstates(packed)
	if result.is_empty() or result.has("error") or not result.has("dominant_eigenvector"):
		return false
	var v: PackedFloat64Array = result["dominant_eigenvector"]
	if v.size() != dim * 2:
		return false
	# ρ_ij = v_i · conj(v_j). Rank-1 projector ⇒ Tr(ρ²) = 1 (v is normalized).
	var rho = ComplexMatrix.zeros(dim)
	for i in range(dim):
		var vi_re := v[i * 2]
		var vi_im := v[i * 2 + 1]
		for j in range(dim):
			var vj_re := v[j * 2]
			var vj_im := v[j * 2 + 1]
			rho.set_element(i, j, Complex.new(vi_re * vj_re + vi_im * vj_im, vi_im * vj_re - vi_re * vj_im))
	density_matrix = rho
	_purity_cache = -1.0
	return true


## Fallback purify: collapse the CURRENT ρ onto its own dominant eigenvector. Used when
## the direct H-ground init can't run (e.g. eigensolver returns nothing).
func _collapse_to_dominant_eigenstate() -> void:
	if density_matrix != null:
		_set_pure_state_from_dominant_eigenvector(density_matrix)


# Delegate RegisterMap queries
func has(emoji: String) -> bool:
	# Check if emoji is registered in this quantum computer.
	return register_map.has(emoji)


func qubit(emoji: String) -> int:
	# Get qubit index for emoji (-1 if not found).
	return register_map.qubit(emoji)


func pole(emoji: String) -> int:
	# Get pole for emoji (0=north, 1=south, -1 if not found).
	return register_map.pole(emoji)


func get_density_matrix() -> ComplexMatrix:
	# Get the density matrix (ρ) for this quantum computer.

	# Returns the full density matrix representing the quantum state.
	# Used by BiomeBase for measurements, coherence checks, and draining.
	return density_matrix


## ============================================================================
## MODEL C: Public API Methods
## ============================================================================

func allocate_qubit(north_emoji: String, south_emoji: String) -> int:
	# Allocate a new qubit axis and return its index.

	# Adds an axis to RegisterMap and resizes density_matrix.

	# Args:
	# north_emoji: Emoji for |0⟩ (north pole)
	# south_emoji: Emoji for |1⟩ (south pole)

	# Returns:
	# Qubit index (0, 1, 2, ...) or -1 on error
	if north_emoji == south_emoji:
		push_error("allocate_qubit: north and south emojis must differ")
		return -1

	var qubit_index = register_map.num_qubits
	allocate_axis(qubit_index, north_emoji, south_emoji)
	return qubit_index


func project_qubit(qubit_index: int, outcome: int) -> bool:
	# Project density matrix onto measurement outcome.

	# Model C measurement projection: collapses state without sampling.
	# Use measure_axis() for sampling + projection, or this for post-selection.

	# Args:
	# qubit_index: Which qubit (0 to num_qubits-1)
	# outcome: 0 (north/|0⟩) or 1 (south/|1⟩)

	# Returns:
	# true if projection succeeded
	if density_matrix == null:
		push_error("project_qubit: density_matrix not initialized")
		return false

	var num_qubits = register_map.num_qubits
	if qubit_index < 0 or qubit_index >= num_qubits:
		push_error("project_qubit: qubit %d out of range [0, %d)" % [qubit_index, num_qubits])
		return false

	if outcome != 0 and outcome != 1:
		push_error("project_qubit: outcome must be 0 or 1, got %d" % outcome)
		return false

	_project_qubit(qubit_index, outcome)
	return true


func get_qubit_for_emoji(emoji: String) -> int:
	# Get qubit index for an emoji.

	# Args:
	# emoji: Emoji to look up

	# Returns:
	# Qubit index (0, 1, 2, ...) or -1 if not found
	return register_map.qubit(emoji)


func get_emoji_pair_for_qubit(qubit_index: int) -> Dictionary:
	# Get {north, south} emoji pair for a qubit.

	# Migration bridge: use this to get axis emojis from qubit index.

	# Args:
	# qubit_index: Qubit to look up (0 to num_qubits-1)

	# Returns:
	# {north: String, south: String} or empty dict if not found
	return register_map.axis(qubit_index)


## ============================================================================
## GATE APPLICATION (Model C: RegisterMap-based)
## ============================================================================

func apply_gate(qubit_idx: int, U: ComplexMatrix) -> bool:
	# Apply 1-qubit unitary gate to the density matrix.

	# Model C (RegisterMap): Operates on the top-level density_matrix directly.
	# Used by UI gate tools when register_map is active.

	# Operation: ρ' = (I⊗...⊗U⊗...⊗I) ρ (I⊗...⊗U†⊗...⊗I)

	# Args:
	# qubit_idx: Qubit index (0 to num_qubits-1)
	# U: 2×2 unitary gate matrix

	# Returns:
	# true if gate applied successfully
	if density_matrix == null:
		push_error("apply_gate: density_matrix not initialized")
		return false

	var num_qubits = register_map.num_qubits
	if qubit_idx < 0 or qubit_idx >= num_qubits:
		push_error("apply_gate: qubit %d out of range [0, %d)" % [qubit_idx, num_qubits])
		return false

	# Embed 1Q gate into full Hilbert space
	var embedded_U = _embed_1q_unitary(U, qubit_idx, num_qubits)

	# Apply gate: ρ' = U ρ U†
	var rho_new = embedded_U.mul(density_matrix).mul(embedded_U.conjugate_transpose())
	rho_new.renormalize_trace()

	density_matrix = rho_new

	return true


func apply_gate_2q(qubit_a: int, qubit_b: int, U: ComplexMatrix) -> bool:
	# Apply 2-qubit unitary gate to the density matrix.

	# Model C (RegisterMap): Operates on the top-level density_matrix directly.
	# Used by UI gate tools when register_map is active.

	# Operation: ρ' = U_{ab} ρ U†_{ab}

	# Args:
	# qubit_a: First qubit index (control for CNOT)
	# qubit_b: Second qubit index (target for CNOT)
	# U: 4×4 unitary gate matrix

	# Returns:
	# true if gate applied successfully
	if density_matrix == null:
		push_error("apply_gate_2q: density_matrix not initialized")
		return false

	var num_qubits = register_map.num_qubits
	if qubit_a < 0 or qubit_a >= num_qubits:
		push_error("apply_gate_2q: qubit_a %d out of range [0, %d)" % [qubit_a, num_qubits])
		return false
	if qubit_b < 0 or qubit_b >= num_qubits:
		push_error("apply_gate_2q: qubit_b %d out of range [0, %d)" % [qubit_b, num_qubits])
		return false
	if qubit_a == qubit_b:
		push_error("apply_gate_2q: qubit_a and qubit_b must differ")
		return false

	# Embed 2Q gate into full Hilbert space
	var embedded_U = _embed_2q_unitary(U, qubit_a, qubit_b, num_qubits)

	# Apply gate: ρ' = U ρ U†
	var rho_new = embedded_U.mul(density_matrix).mul(embedded_U.conjugate_transpose())
	rho_new.renormalize_trace()

	density_matrix = rho_new

	return true


# ============================================================================
# HIGH-LEVEL GATE CONVENIENCE METHODS
# ============================================================================

func apply_pauli_x(qubit_idx: int) -> bool:
	# Apply Pauli-X (NOT/bit-flip) gate to a qubit.
	var X = QuantumGateLibrary.get_gate("X")["matrix"]
	return apply_gate(qubit_idx, X)


func apply_hadamard(qubit_idx: int) -> bool:
	# Apply Hadamard gate to create superposition.
	var H = QuantumGateLibrary.get_gate("H")["matrix"]
	return apply_gate(qubit_idx, H)


func apply_pauli_y(qubit_idx: int) -> bool:
	# Apply Pauli-Y gate.
	var Y = QuantumGateLibrary.get_gate("Y")["matrix"]
	return apply_gate(qubit_idx, Y)


func apply_pauli_z(qubit_idx: int) -> bool:
	# Apply Pauli-Z (phase-flip) gate.
	var Z = QuantumGateLibrary.get_gate("Z")["matrix"]
	return apply_gate(qubit_idx, Z)


func apply_ry(qubit_idx: int, theta: float = PI / 4.0) -> bool:
	# Apply Ry rotation gate with angle theta (default π/4).
	var Ry = QuantumGateLibrary._ry_gate(theta)
	return apply_gate(qubit_idx, Ry)


func apply_rx(qubit_idx: int, theta: float = PI / 4.0) -> bool:
	# Apply Rx rotation gate with angle theta (default π/4).
	var Rx = QuantumGateLibrary._rx_gate(theta)
	return apply_gate(qubit_idx, Rx)


func apply_rz(qubit_idx: int, theta: float = PI / 4.0) -> bool:
	# Apply Rz rotation gate with angle theta (default π/4).
	var Rz = QuantumGateLibrary._rz_gate(theta)
	return apply_gate(qubit_idx, Rz)


func apply_perturbation(strength: float = 0.8) -> Dictionary:
	# Kick every qubit by random Ry+Rx rotations scaled by strength (radians).
	# Returns the attractor state captured *before* the perturbation so callers
	# can use it as a recovery target.  strength ≈ 0.8 is enough to scatter the
	# dominant state without fully destroying structure; PI/2 ≈ maximum chaos.
	var pre_attractor := get_attractor_state()
	if not register_map:
		return {}
	var nq := register_map.num_qubits
	for q in range(nq):
		var angle_y := randf_range(strength * 0.5, strength)
		var angle_x := randf_range(-strength * 0.3, strength * 0.3)
		apply_ry(q, angle_y)
		apply_rx(q, angle_x)
	return {"pre_attractor": pre_attractor, "qubits_perturbed": nq}


func apply_cnot(control_qubit: int, target_qubit: int) -> bool:
	# Apply CNOT (controlled-NOT) gate. First arg is control, second is target.
	var CNOT = QuantumGateLibrary.get_gate("CNOT")["matrix"]
	return apply_gate_2q(control_qubit, target_qubit, CNOT)


func apply_swap(qubit_a: int, qubit_b: int) -> bool:
	# Apply SWAP gate to exchange two qubit states.
	var SWAP = QuantumGateLibrary.get_gate("SWAP")["matrix"]
	return apply_gate_2q(qubit_a, qubit_b, SWAP)


func apply_cz(control_qubit: int, target_qubit: int) -> bool:
	# Apply CZ (controlled-Z) gate.
	var CZ = QuantumGateLibrary.get_gate("CZ")["matrix"]
	return apply_gate_2q(control_qubit, target_qubit, CZ)


func get_marginal(qubit_index: int, pole_value: int) -> float:
	# Get marginal probability P(qubit = pole) via partial trace.

	# Args:
	# qubit_index: Which qubit to measure
	# pole_value: 0 (north) or 1 (south)

	# Returns:
	# Probability in [0, 1]

	# Example:
	# get_marginal(0, 0)  # P(qubit 0 = north) = P(🔥)
	if density_matrix == null:
		return 0.0

	var num_qubits = register_map.num_qubits
	var dim = register_map.dim()
	var shift = num_qubits - 1 - qubit_index
	var prob = 0.0

	# Use fast path for diagonal reads (avoids O(n²) object creation)
	for i in range(dim):
		if ((i >> shift) & 1) == pole_value:
			prob += density_matrix.get_diagonal_real(i)

	return clamp(prob, 0.0, 1.0)


func get_population(emoji: String) -> float:
	# Get probability of emoji state via RegisterMap lookup.

	# Args:
	# emoji: Emoji to query (must be registered)

	# Returns:
	# P(emoji) in [0, 1]

	# Example:
	# get_population("🔥")  # Returns P(qubit 0 = north)
	if not register_map.has(emoji):
		# Unregistered emojis have 0 probability - no warning needed
		return 0.0

	var q = register_map.qubit(emoji)
	var p = register_map.pole(emoji)
	return get_marginal(q, p)


func get_all_populations() -> Dictionary:
	# Get populations for all registered emojis.

	# Returns:
	# Dictionary: {emoji: float} for all registered emojis

	# Example:
	# {"🔥": 0.7, "❄️": 0.3, "💧": 0.5, "🏜️": 0.5}
	var populations: Dictionary = {}

	if register_map == null:
		return populations

	# Iterate over all registered emojis
	for emoji in register_map.coordinates.keys():
		populations[emoji] = get_population(emoji)

	return populations


func get_basis_state_probabilities() -> Array:
	# Get probability of each computational basis state (ρ diagonal).

	# Each basis state is a tensor product of north/south poles.
	# Index bits map to qubits: bit=0 → north, bit=1 → south.

	# Returns:
	# Array of {label: String, probability: float} sorted by probability (descending).
	# label is the emoji string for the state, e.g. "☀🌾🍂".
	var result: Array = []
	if density_matrix == null or register_map == null:
		return result

	var num_qubits = register_map.num_qubits
	var dim = register_map.dim()
	if dim > 1024:  # > 10 qubits — too large to enumerate
		return result

	# Build qubit axis labels (north/south emojis per qubit)
	var axes: Array = []  # [{north: emoji, south: emoji}, ...]
	for qi in range(num_qubits):
		var north = ""
		var south = ""
		for emoji in register_map.coordinates.keys():
			var q = register_map.qubit(emoji)
			var p = register_map.pole(emoji)
			if q == qi:
				if p == 0:
					north = emoji
				else:
					south = emoji
		axes.append({"north": north, "south": south})

	# Read diagonal and build labels
	for i in range(dim):
		var prob = density_matrix.get_diagonal_real(i)
		if prob < 0.0:
			prob = 0.0
		var label = ""
		for qi in range(num_qubits):
			var shift = num_qubits - 1 - qi
			var bit = (i >> shift) & 1
			label += axes[qi]["south"] if bit == 1 else axes[qi]["north"]
		result.append({"label": label, "probability": prob})

	result.sort_custom(func(a, b): return a.probability > b.probability)
	return result


func measure_axis(north_emoji: String, south_emoji: String) -> String:
	# Projective measurement on a north/south emoji axis.

	# Model C measurement: samples from Born probabilities and collapses state.

	# Args:
	# north_emoji: North pole emoji (e.g., "🌾")
	# south_emoji: South pole emoji (e.g., "🍄")

	# Returns:
	# Measured emoji (north_emoji or south_emoji), or "" on error
	if not register_map.has(north_emoji) or not register_map.has(south_emoji):
		push_warning("⚠️ Emoji axis not registered: %s/%s" % [north_emoji, south_emoji])
		return ""

	var q_north = register_map.qubit(north_emoji)
	var q_south = register_map.qubit(south_emoji)

	if q_north != q_south:
		push_warning("⚠️ Emojis not on same qubit: %s (q%d) / %s (q%d)" % [
			north_emoji, q_north, south_emoji, q_south])
		return ""

	var qubit_idx = q_north
	var p_north = get_marginal(qubit_idx, 0)  # pole 0 = north
	var p_south = get_marginal(qubit_idx, 1)  # pole 1 = south
	var p_total = p_north + p_south

	if p_total < 1e-14:
		push_error("⚠️ Measurement probabilities sum to zero for axis %s/%s" % [north_emoji, south_emoji])
		return north_emoji  # Default

	# Sample outcome
	var rnd = randf()
	var outcome_pole = 0 if (rnd < p_north / p_total) else 1
	var outcome_emoji = north_emoji if outcome_pole == 0 else south_emoji

	# Project density matrix onto outcome
	_project_qubit(qubit_idx, outcome_pole)

	_log("debug", "quantum", "🔬", "Measured axis %s/%s: outcome=%s (p_north=%.3f, p_south=%.3f)" % [
		north_emoji, south_emoji, outcome_emoji, p_north, p_south])

	return outcome_emoji


func _project_qubit(qubit_index: int, outcome_pole: int) -> void:
	# Project density matrix onto qubit measurement outcome.

	# Implements projective measurement collapse:
	# ρ → P_k ρ P_k / Tr(P_k ρ)

	# where P_k is the projector onto |k⟩⟨k| for the measured qubit.
	var num_qubits = register_map.num_qubits
	var dim = register_map.dim()
	var shift = num_qubits - 1 - qubit_index
	var rho_new = ComplexMatrix.zeros(dim)

	# Apply projector: keep only states where qubit = outcome_pole
	for i in range(dim):
		var qubit_i = (i >> shift) & 1
		if qubit_i != outcome_pole:
			continue  # Project out

		for j in range(dim):
			var qubit_j = (j >> shift) & 1
			if qubit_j != outcome_pole:
				continue  # Project out

			rho_new.set_element(i, j, density_matrix.get_element(i, j))

	# Renormalize and invalidate caches
	density_matrix = rho_new
	density_matrix.renormalize_trace()
	_purity_cache = -1.0


func drain_qubit(qubit_index: int, outcome_pole: int, eta: float) -> void:
	# Partial ensemble measurement: drain η of population from measured pole.

	# Instead of full projective collapse (ρ → P_k ρ P_k / Tr(P_k ρ)),
	# this applies a partial drain that extracts a fraction of population
	# while preserving the biome's quantum structure.

	# Physics: equivalent to a weak measurement / partial Lindblad jump.
	# - Diagonal elements where qubit = outcome_pole: ρ_ii *= (1 - η)
	# - Off-diagonals touching measured pole: ρ_ij *= √(1 - η)
	# (coherence decays at half the population rate, matching Lindblad T₂)
	# - All other elements: untouched
	# - Trace renormalized to 1 after drain

	# Args:
	# qubit_index: Which qubit (0 to num_qubits-1)
	# outcome_pole: 0 (north/|0⟩) or 1 (south/|1⟩) — the measured pole
	# eta: Drain fraction in [0, 1]. 0 = no effect, 1 = full projection.
	if density_matrix == null:
		push_error("drain_qubit: density_matrix not initialized")
		return

	var num_qubits = register_map.num_qubits
	if qubit_index < 0 or qubit_index >= num_qubits:
		push_error("drain_qubit: qubit %d out of range [0, %d)" % [qubit_index, num_qubits])
		return

	eta = clampf(eta, 0.0, 1.0)
	if eta < 1e-12:
		return  # No-op drain

	var dim = register_map.dim()
	var shift = num_qubits - 1 - qubit_index
	var pop_scale = 1.0 - eta                 # Population retention factor
	var coh_scale = sqrt(1.0 - eta)           # Coherence decay (T₂ relationship)

	for i in range(dim):
		var qi = (i >> shift) & 1
		for j in range(dim):
			var qj = (j >> shift) & 1

			if qi == outcome_pole and qj == outcome_pole:
				# Diagonal block of measured pole: drain population
				density_matrix.set_element(i, j,
					density_matrix.get_element(i, j).scale(pop_scale))
			elif qi == outcome_pole or qj == outcome_pole:
				# Off-diagonal touching measured pole: coherence decay
				density_matrix.set_element(i, j,
					density_matrix.get_element(i, j).scale(coh_scale))
			# else: other pole's block — untouched

	density_matrix.renormalize_trace()
	_purity_cache = -1.0


func get_basis_probability(basis_index: int) -> float:
	# Get probability of computational basis state |i⟩.

	# Args:
	# basis_index: Basis state index (0 to 2^n - 1)

	# Returns:
	# P(|i⟩) = ρ[i,i] (diagonal element)

	# Example:
	# get_basis_probability(0)  # P(|000⟩) = P(bread)
	if density_matrix == null:
		return 0.0

	var dim = register_map.dim()
	if basis_index < 0 or basis_index >= dim:
		return 0.0

	return clamp(density_matrix.get_element(basis_index, basis_index).re, 0.0, 1.0)


func apply_drive(target_emoji: String, rate: float, dt: float) -> void:
	# Apply Lindblad drive pushing population toward target emoji.

	# This implements trace-preserving population transfer:
	# dρ/dt = γ(L ρ L† - {L†L, ρ}/2)

	# where L = √γ |target⟩⟨source| flips the qubit from opposite pole to target.

	# Args:
	# target_emoji: Emoji to drive toward (must be registered)
	# rate: Drive strength γ (1/s)
	# dt: Time step (s)

	# Example:
	# apply_drive("🔥", 2.0, 0.1)  # Drive toward hot for 0.1s
	if not register_map.has(target_emoji):
		push_warning("⚠️ Cannot drive to unregistered emoji: %s" % target_emoji)
		return

	var q = register_map.qubit(target_emoji)
	var target_pole = register_map.pole(target_emoji)
	var source_pole = 1 - target_pole  # Opposite pole

	_apply_lindblad_1q(q, source_pole, target_pole, rate, dt)


func _apply_lindblad_1q(qubit_index: int, from_pole: int, to_pole: int,
                        gamma: float, dt: float) -> void:
	# Apply single-qubit amplitude damping channel (exact Kraus map).

	# Implements the CPTP map:
	# ρ → K₀ρK₀† + K₁ρK₁†
	# where:
	# p = 1 - exp(-γ·dt)          (transition probability)
	# K₀ = |from⟩⟨from| + √(1-p)|to⟩⟨to| + Σ_other |k⟩⟨k|  (no-jump)
	# K₁ = √p |to⟩⟨from|                                      (jump)

	# This is trace-preserving and completely positive BY CONSTRUCTION —
	# no Euler instability, no negative populations, no catastrophic resets.
	# Quantum Zeno saturation emerges naturally: as γ→∞, p→1, state collapses
	# to |to⟩⟨to| (drain target) — the physics is exact for arbitrary dt.
	if density_matrix == null:
		return

	var num_qubits = register_map.num_qubits
	var dim = register_map.dim()
	var shift = num_qubits - 1 - qubit_index
	var source_emoji = _emoji_for_qubit_pole(qubit_index, from_pole)
	var before_source_pop = get_marginal(qubit_index, from_pole)

	# Exact transition probability (amplitude damping channel)
	var p = 1.0 - exp(-gamma * dt)
	p = clampf(p, 0.0, 1.0)
	var sqrt_1mp = sqrt(1.0 - p)  # Survival amplitude

	# Apply Kraus map element-by-element:
	#   ρ'[i,j] = K₀[i,·] ρ K₀†[·,j] + K₁[i,·] ρ K₁†[·,j]
	#
	# K₀ is diagonal: K₀[k,k] = 1 if qubit has from_pole, √(1-p) if to_pole
	# K₁ has one nonzero per block: K₁[k',k] = √p where k has from_pole, k'=flip(k)
	var rho_new = ComplexMatrix.zeros(dim)
	for i in range(dim):
		for j in range(dim):
			var bit_i = (i >> shift) & 1
			var bit_j = (j >> shift) & 1

			# K₀ ρ K₀† term: K₀ is diagonal, so K₀ρK₀†[i,j] = K₀[i,i] * ρ[i,j] * K₀[j,j]
			var k0_i = 1.0 if bit_i == from_pole else sqrt_1mp
			var k0_j = 1.0 if bit_j == from_pole else sqrt_1mp
			var rho_ij = density_matrix.get_element(i, j)
			var term0 = rho_ij.scale(k0_i * k0_j)

			# K₁ ρ K₁† term: K₁[i,·] is nonzero only when bit_i == to_pole,
			# mapping from the flipped source state
			var term1 = Complex.zero()
			if bit_i == to_pole and bit_j == to_pole:
				var i_src = i ^ (1 << shift)  # Flip to from_pole
				var j_src = j ^ (1 << shift)
				term1 = density_matrix.get_element(i_src, j_src).scale(p)

			rho_new.set_element(i, j, term0.add(term1))

	density_matrix = rho_new
	# No _renormalize() needed — Kraus map is CPTP by construction.
	# Only invalidate purity cache.
	_purity_cache = -1.0

	if source_emoji != "":
		var after_source_pop = get_marginal(qubit_index, from_pole)
		var drained = max(0.0, before_source_pop - after_source_pop)
		if drained > 0.0:
			add_sink_flux(source_emoji, drained)


func _emoji_for_qubit_pole(qubit_index: int, pole_str: int) -> String:
	var axis = register_map.axis(qubit_index)
	if axis.is_empty():
		return ""
	return str(axis.get("north", "")) if pole_str == 0 else str(axis.get("south", ""))


func _renormalize() -> void:
	# Ensure Tr(ρ) = 1 after numerical integration.

	# Three-stage approach:
	# 1. Clip small negative diagonal values to zero (numerical noise fix)
	# 2. Reinitialize only on truly catastrophic failure
	# 3. Normalize trace to 1

	# Operates directly on PackedFloat64Array to avoid Complex object allocation.
	if density_matrix == null:
		return

	var dim = register_map.dim()
	var p = density_matrix._to_packed()
	if p.size() < dim * dim * 2:
		return

	# Stage 1: Clip small negative diagonal values (numerical noise fix)
	for i in range(dim):
		var idx = (i * dim + i) * 2  # real part of diagonal element
		var diag_re = p[idx]
		if diag_re < 0.0 and diag_re > -0.15:
			p[idx] = 0.0
			p[idx + 1] = 0.0

	# Compute trace and check for catastrophic failure
	var trace_val = 0.0
	var min_diag = 1.0
	for i in range(dim):
		var diag_re = p[(i * dim + i) * 2]
		trace_val += diag_re
		if diag_re < min_diag:
			min_diag = diag_re
	_last_renorm_trace_before_cap = trace_val

	# Stage 2: Catastrophic failure — target Lindbladian steady state
	if abs(trace_val) < 1e-10 or min_diag < -0.15:
		_catastrophic_recovery_count += 1
		if _catastrophic_recovery_count <= 3 or _catastrophic_recovery_count % 100 == 0:
			push_warning("⚠️ Quantum state catastrophic (trace=%.4f, min_diag=%.4f), recovering to steady state (count=%d)" % [trace_val, min_diag, _catastrophic_recovery_count])
		_last_renorm_scale = 0.0
		# Write back clipped state before recovery
		density_matrix._packed_cache = p
		density_matrix._packed_valid = true
		density_matrix._data_valid = false
		density_matrix._data = []
		_recover_to_steady_state()
		return

	# Stage 3: Cap trace to 1 (allow dissipative trace < 1)
	if trace_val > 1.0 + 1e-10:
		var s = 1.0 / trace_val
		_last_renorm_scale = s
		_cumulative_renorm_excess += (trace_val - 1.0)
		var total = p.size()
		for i in range(total):
			p[i] *= s
	else:
		_last_renorm_scale = 1.0

	# Stage 4: Clamp off-diagonal coherences (Euler stability guard)
	# For a physical ρ, |ρ_ij| ≤ √(ρ_ii × ρ_jj) (Cauchy-Schwarz).
	# Euler integration can violate this, causing exponential blowup of
	# off-diagonal elements while trace stays ~1. Clamp to physical bounds.
	for i in range(dim):
		var pi_re = p[(i * dim + i) * 2]
		if pi_re < 0.0:
			pi_re = 0.0
		for j in range(i + 1, dim):
			var pj_re = p[(j * dim + j) * 2]
			if pj_re < 0.0:
				pj_re = 0.0
			var max_coherence = sqrt(pi_re * pj_re)
			# Check |ρ_ij|
			var ij2 = (i * dim + j) * 2
			var ji2 = (j * dim + i) * 2
			var re = p[ij2]
			var im = p[ij2 + 1]
			var mag = sqrt(re * re + im * im)
			if mag > max_coherence and mag > 1e-14:
				var s = max_coherence / mag
				p[ij2] *= s
				p[ij2 + 1] *= s
				# Hermitian: ρ_ji = conj(ρ_ij)
				p[ji2] = p[ij2]
				p[ji2 + 1] = -p[ij2 + 1]

	# Write packed data back as authoritative
	density_matrix._packed_cache = p
	density_matrix._packed_valid = true
	density_matrix._data_valid = false
	density_matrix._data = []
	_purity_cache = -1.0


func load_packed_state(rho_packed: PackedFloat64Array, dim: int, already_normalized: bool = false) -> void:
	# Load a packed density matrix, with optional trusted normalization.
	if density_matrix == null or density_matrix.n != dim:
		density_matrix = ComplexMatrix.zeros(dim)
	density_matrix._from_packed(rho_packed, dim)
	if not already_normalized:
		_renormalize()
	# The state changed — invalidate the purity cache. Without this, get_purity() returns a
	# STALE value after a C++ writeback (the cache was only refreshed by evolve()). Shipping
	# closed mode masked it (always pure ⇒ stale 1.0 is coincidentally right); dissipative
	# modes exposed it as "purity stuck at 1.0 despite mixing".
	_purity_cache = -1.0


func _reinitialize_mixed_state() -> void:
	# Reinitialize to maximally mixed state (ρ = I/d) when trace collapses.
	if density_matrix == null:
		return

	var dim = register_map.dim()
	if dim == 0:
		return

	push_warning("⚠️ Quantum %s: hard reinit to I/d (state lost — coherence-dependent gameplay will read flat)" % biome_name)

	# Set to ρ = I/d (uniform distribution over all basis states)
	var diag_val = 1.0 / float(dim)
	for i in range(dim):
		for j in range(dim):
			if i == j:
				density_matrix.set_element(i, j, Complex.new(diag_val, 0.0))
			else:
				density_matrix.set_element(i, j, Complex.zero())


func _recover_to_steady_state() -> void:
	# Recover from catastrophic state by targeting the Lindbladian steady state.

	# Instead of reinitializing to I/d (which destroys all quantum information),
	# project onto the diagonal (complete decoherence) and clamp negative
	# populations to zero. This preserves the population distribution that the
	# Hamiltonian + Lindblad dynamics were driving toward — the physical steady
	# state of the dissipator — rather than resetting to 'know nothing.'

	# For amplitude damping (drain), the steady state is the drain target pole.
	# For driven systems, it's the balance between pump and drain rates.
	# Projecting onto the diagonal is equivalent to a complete dephasing channel,
	# which is the correct physical limit of strong environment coupling.
	if density_matrix == null:
		return

	var dim = register_map.dim()
	if dim == 0:
		return

	# Extract diagonal populations, clamp negatives to zero
	var populations = PackedFloat64Array()
	populations.resize(dim)
	var pop_sum = 0.0
	for i in range(dim):
		var p = density_matrix.get_element(i, i).re
		p = max(0.0, p)
		populations[i] = p
		pop_sum += p

	# Renormalize populations (or fall back to I/d if all zero)
	if pop_sum < 1e-12:
		push_warning("⚠️ Quantum %s: steady-state recovery hit zero populations — falling back to I/d" % biome_name)
		var diag_val = 1.0 / float(dim)
		for i in range(dim):
			populations[i] = diag_val
	else:
		var scale = 1.0 / pop_sum
		for i in range(dim):
			populations[i] *= scale

	# Write back as diagonal density matrix (zero off-diagonals = dephased)
	for i in range(dim):
		for j in range(dim):
			if i == j:
				density_matrix.set_element(i, j, Complex.new(populations[i], 0.0))
			else:
				density_matrix.set_element(i, j, Complex.zero())

	_purity_cache = -1.0


func _apply_phase_lnn(lnn: Object) -> void:
	# Apply learned phase modulation from neural network to density matrix diagonal.

	# The LNN operates in the phasic shadow - it learns to modulate the phases of
	# the diagonal density matrix elements. This creates an undercurrent of learned
	# intelligence that shapes quantum evolution.

	# Args:
	# lnn: LiquidNeuralNetNative instance with forward(phases: PackedFloat64Array) method
	# Gated by ENABLE_PHASE_LNN const above and phase_lnn assignment
	if density_matrix == null or not lnn:
		return

	var dim = register_map.dim()
	if dim == 0:
		return

	# Extract current phases from density matrix diagonal
	var phases = PackedFloat64Array()
	phases.resize(dim)

	for i in range(dim):
		var diag_elem = density_matrix.get_element(i, i)
		var phase = atan2(diag_elem.im, diag_elem.re)
		phases[i] = phase

	# Run LNN forward pass to get learned phase modulations
	var modulated_phases = lnn.forward(phases)
	if modulated_phases.is_empty():
		return

	# Apply phase shifts to density matrix diagonal (packed path)
	var p = density_matrix._to_packed()
	for i in range(dim):
		var idx = (i * dim + i) * 2
		var old_re = p[idx]
		var old_im = p[idx + 1]
		var magnitude = sqrt(old_re * old_re + old_im * old_im)

		# Phase shift from LNN
		var new_phase = modulated_phases[i]
		p[idx] = magnitude * cos(new_phase)
		p[idx + 1] = magnitude * sin(new_phase)

	density_matrix._packed_cache = p
	density_matrix._packed_valid = true
	density_matrix._data_valid = false
	density_matrix._data = []

	# Invalidate caches since we modified the state
	_purity_cache = -1.0


# ============================================================================
# MODEL C: FULL LINDBLAD EVOLUTION
# ============================================================================

func evolve(dt: float, max_dt: float = 0.02, lnn: Object = null) -> void:
	var t0 = Time.get_ticks_usec()
	# Evolve density matrix under Lindblad master equation + optional phase modulation.

	# Implements: dρ/dt = -i[H,ρ] + Σ_k (L_k ρ L_k† - ½{L_k†L_k, ρ})
	# + phase modulation via learned neural network (if lnn provided)

	# Uses first-order Euler integration: ρ(t+dt) = ρ(t) + dt * dρ/dt

	# Args:
	# dt: Total simulated time this call advances (game seconds)
	# max_dt: Integrator substep ceiling — dt is subcycled into steps of at most
	#         max_dt (driven-H closed path and the Euler path both honor it)
	# lnn: Optional LiquidNeuralNet for phase modulation in phasic shadow
	# If provided, applies learned phase shifts to density matrix diagonal

	# Requires:
	# - density_matrix initialized (via initialize_basis or allocate_axis)
	# - hamiltonian set (via HamiltonianBuilder.build_from_icons)
	# - lindblad_operators set (via LindbladBuilder.build_from_atoms)
	if density_matrix == null:
		return  # Not initialized yet

	var dim = register_map.dim()
	if dim == 0:
		return

	# Use provided lnn or fall back to instance variable (only if master switch is on)
	if lnn == null and ENABLE_PHASE_LNN:
		lnn = phase_lnn

	# UPDATE TIME-DEPENDENT DRIVERS (e.g., sun/moon 20-second oscillation)
	# This modifies Hamiltonian diagonal terms for icons with active drivers.
	# dt controls total simulated time. max_dt controls integrator granularity.
	var total_dt = maxf(0.0, dt)
	if total_dt <= 0.0:
		return

	# COHERENT KERNEL — closed (unitary) system: evolve by the EXACT propagator
	# ρ → U ρ U†, U = exp(−iH·dt). Each step is a unitary similarity, so Tr(ρ²) and Tr(ρ)
	# are conserved to machine precision — r = 1 holds exactly, with no Euler drift, no
	# dissipator branch, and no renormalize-as-crutch. (Phase-LNN modulation, if ever
	# enabled, falls through to the legacy integrator below.)
	if is_closed_here() and lnn == null and hamiltonian != null:
		if driven_icons.is_empty():
			# Static H: one exact step over the whole interval (U cached + reused).
			elapsed_time += total_dt
			_evolve_unitary(total_dt)
		else:
			# Time-dependent H (sun/moon drivers): subcycle and rebuild U from the
			# instantaneous H each substep. Still exactly unitary per substep ⇒ purity exact.
			var sub_dt = maxf(0.000001, max_dt if max_dt > 0.0 else total_dt)
			var n_sub = maxi(1, int(ceili(total_dt / sub_dt)))
			var dt_each = total_dt / float(n_sub)
			for _i in range(n_sub):
				elapsed_time += dt_each
				update_driven_self_energies(elapsed_time)  # mutates H in place
				_unitary_dirty = true                       # H changed ⇒ rebuild U
				_evolve_unitary(dt_each)
		_purity_cache = -1.0
		return

	var substep_max_dt = maxf(0.000001, max_dt if max_dt > 0.0 else total_dt)
	var substeps = maxi(1, int(ceili(total_dt / substep_max_dt)))
	var step_dt = total_dt / float(substeps)

	# ==========================================================================
	# EVOLUTION PATH: subcycled Euler integration with optional phase modulation
	# ==========================================================================
	for _i in range(substeps):
		elapsed_time += step_dt
		if not driven_icons.is_empty():
			update_driven_self_energies(elapsed_time)
		_evolve_step(step_dt)
		if lnn:
			_apply_phase_lnn(lnn)

	# Evolution mutated ρ — invalidate the purity cache (gates/drain already do
	# this, but the evolution loop did not, so get_purity()/get_entropy() were
	# returning the stale init value while marginals evolved live).
	_purity_cache = -1.0

	var t1 = Time.get_ticks_usec()
	if Engine.get_process_frames() % 60 == 0:
		_log("trace", "quantum", "⏱️", "QC Evolve Trace (substeps=%d, dt=%.4f, max_dt=%.4f): Total %d us" % [
			substeps, total_dt, substep_max_dt, t1 - t0
		])


## Exact unitary evolution: ρ ← U ρ U†, U = exp(−iH·dt). The closed-system kernel.
## Unitary similarity preserves Tr(ρ²) and Tr(ρ) exactly, so a pure state stays pure
## (r = 1) for all time — no integrator drift. Used only by the closed-mode fast path
## in evolve() (static H, no LNN).
func _evolve_unitary(dt: float) -> void:
	var U = _unitary_for(dt)
	if U == null:
		return
	density_matrix = U.mul(density_matrix).mul(U.dagger())


## Build (or reuse) the propagator U = exp(−iH·dt). Cached per (H instance, dt): rebuilt
## when H is reassigned (ref changes), mutated in place (_unitary_dirty), or dt changes.
func _unitary_for(dt: float):
	if hamiltonian == null:
		return null
	if (not _unitary_dirty) and _unitary_cache != null and _unitary_cache_h == hamiltonian \
			and absf(_unitary_cache_dt - dt) < 1e-12:
		return _unitary_cache
	# U = exp(−i·dt·H). H is Hermitian ⇒ −i·dt·H is anti-Hermitian ⇒ U is unitary.
	_unitary_cache = hamiltonian.scale(Complex.new(0.0, -dt)).expm()
	_unitary_cache_h = hamiltonian
	_unitary_cache_dt = dt
	_unitary_dirty = false
	return _unitary_cache


func _evolve_step(dt: float) -> void:
	# Single Euler integration step (internal).
	var dim = register_map.dim()
	var use_sparse_evolution = _sparse_evolution_enabled()

	# Lazy-build Lindblad cache if operators were set directly (not via set_lindblad_operators)
	if not _lindblad_cache_valid and lindblad_operators.size() > 0:
		_rebuild_lindblad_cache()
	if dim <= 0 or density_matrix == null or int(density_matrix.n) != dim:
		_log("error", "quantum", "🛑", "Skipping evolve: invalid density matrix shape (dim=%d, rho=%s)" % [
			dim, str(density_matrix.n if density_matrix else -1)
		])
		return

	# Defensive shape sanitization before any native matrix products.
	if hamiltonian != null and int(hamiltonian.n) != dim:
		_log("warn", "quantum", "🧯", "Hamiltonian shape mismatch (H=%d dim=%d) - disabling Hamiltonian term this step" % [
			int(hamiltonian.n), dim
		])
		hamiltonian = null
		sparse_hamiltonian = null
	if sparse_hamiltonian != null and int(sparse_hamiltonian.n) != dim:
		_log("warn", "quantum", "🧯", "Sparse Hamiltonian shape mismatch (Hs=%d dim=%d) - falling back to dense/null" % [
			int(sparse_hamiltonian.n), dim
		])
		sparse_hamiltonian = null

	if lindblad_operators.size() > 0:
		var valid_lindblad: Array = []
		for L in lindblad_operators:
			if L == null:
				continue
			if int(L.n) == dim:
				valid_lindblad.append(L)
			else:
				_log("warn", "quantum", "🧯", "Dropping Lindblad op with shape %d (expected %d)" % [int(L.n), dim])
		if valid_lindblad.size() != lindblad_operators.size():
			lindblad_operators = valid_lindblad
			_lindblad_cache_valid = false  # Operators changed, rebuild cache next step

	if sparse_lindblad_operators.size() > 0:
		var valid_sparse_lindblad: Array = []
		for Ls in sparse_lindblad_operators:
			if Ls == null:
				continue
			if int(Ls.n) == dim:
				valid_sparse_lindblad.append(Ls)
			else:
				_log("warn", "quantum", "🧯", "Dropping sparse Lindblad op with shape %d (expected %d)" % [int(Ls.n), dim])
		if valid_sparse_lindblad.size() != sparse_lindblad_operators.size():
			sparse_lindblad_operators = valid_sparse_lindblad

	# Accumulate dρ/dt
	var drho = ComplexMatrix.zeros(dim)

	# -------------------------------------------------------------------------
	# Term 1: Hamiltonian evolution -i[H, ρ]  (coherent generator)
	# Gated by the coherent switch so pure-Lindbladian mode (H off, L on) runs the
	# dissipator alone. (Pure-coherent never reaches here — it takes the exact unitary
	# fast-path in evolve(). This Euler path serves full-open, pure-dissipative, driven,
	# and phase-LNN cases.)
	# -------------------------------------------------------------------------
	if BalanceConfig.coherent_enabled():
		if use_sparse_evolution and sparse_hamiltonian != null:
			# SPARSE path: 10-50x faster commutator
			var comm = sparse_hamiltonian.commutator_with_dense(density_matrix)
			drho = drho.add(comm.scale_neg_i())
		elif hamiltonian != null:
			# Dense packed path: fused commutator + scale by -i
			var comm = hamiltonian.commutator(density_matrix)
			drho = drho.add(comm.scale_neg_i())

	# -------------------------------------------------------------------------
	# Term 2: Lindblad dissipation Σ_k (L_k ρ L_k† - ½{L_k†L_k, ρ})
	# -------------------------------------------------------------------------
	# SPARSE path: use optimized native lindblad_dissipator()
	if use_sparse_evolution and sparse_lindblad_operators.size() > 0:
		for L_sparse in sparse_lindblad_operators:
			if L_sparse == null:
				continue
			# Single native call computes entire dissipator: L ρ L† - ½{L†L, ρ}
			var dissipator = L_sparse.lindblad_dissipator(density_matrix)
			drho = drho.add(dissipator)
	else:
		# Dense path — uses cached L† and L†L when available
		for idx in range(lindblad_operators.size()):
			var L = lindblad_operators[idx]
			if L == null:
				continue

			var L_dag: ComplexMatrix
			var Ldag_L: ComplexMatrix
			if _lindblad_cache_valid and idx < _lindblad_L_dag.size() and _lindblad_L_dag[idx] != null:
				L_dag = _lindblad_L_dag[idx]
				Ldag_L = _lindblad_Ldag_L[idx]
			else:
				L_dag = L.dagger()
				Ldag_L = L_dag.mul(L)

			# L ρ L†
			var L_rho = L.mul(density_matrix)
			var L_rho_Ldag = L_rho.mul(L_dag)

			# {L†L, ρ}/2 = (L†L ρ + ρ L†L)/2
			var anticomm = Ldag_L.anticommutator(density_matrix)
			var half_anticomm = anticomm.scale_real(0.5)

			# Dissipator: L ρ L† - {L†L, ρ}/2
			var dissipator = L_rho_Ldag.sub(half_anticomm)
			drho = drho.add(dissipator)

	# -------------------------------------------------------------------------
	# Euler integration: ρ_new = ρ + dt * dρ/dt
	# -------------------------------------------------------------------------
	var rho_new = density_matrix.add(drho.scale_real(dt))

	# DEBUG: Log density matrix before/after update
	if Engine.get_process_frames() % 100 == 0:
		var old_01 = density_matrix.get_element(0, 1)
		var new_01 = rho_new.get_element(0, 1)
		var drho_01 = drho.get_element(0, 1)
		_log("trace", "test", "⚛️", "Update: ρ_old[0,1]=%.6f+%.6fi, δρ[0,1]*dt=%.6f+%.6fi, ρ_new[0,1]=%.6f+%.6fi" % [
			old_01.re, old_01.im, drho_01.re * dt, drho_01.im * dt, new_01.re, new_01.im
		])

	density_matrix = rho_new

	# Renormalize to maintain Tr(ρ) = 1 (numerical stability)
	_renormalize()


## Hilbert-space dimension (2^num_qubits) of this biome's density matrix.
## Used by EnergyPricing.biome_temperature to normalize entropy — must match the
## `density_matrix.n` that get_entropy()/get_purity() use (NOT `.dimension()`,
## which returns the inner `_matrix.n` and can diverge, clamping s_norm to 1).
func get_dimension() -> int:
	return int(density_matrix.n) if density_matrix else 0


## Entropy of this biome's state — the extractable-energy "bank" in the reap
## conservation model (yield ≤ kT·S), and the basis for kT.
##
## Shannon entropy of the LIVE basis-state populations (the diagonal of ρ):
## S = −Σ pᵢ log pᵢ, read via `density_matrix.get_diagonal_real` — the SAME live
## source `get_marginal` trusts. The native evolution engine
## (`MultiBiomeLookaheadEngine`) writes the diagonal back here, but does NOT
## refresh the full packed copy `_to_packed()` uses — so `get_purity()`/Tr(ρ²)
## (and any entropy derived from it) read stale, pinned at the init value while
## populations evolve. Diagonal entropy is the population-spread the economy
## actually prices on, tracks the live evolution, and is 0 when concentrated /
## log(dim) when uniform.
func get_entropy() -> float:
	if density_matrix == null:
		return 0.0
	var dim = density_matrix.n
	var trace := 0.0
	for i in range(dim):
		trace += density_matrix.get_diagonal_real(i)
	if trace < 1e-12:
		return 0.0
	var s := 0.0
	for i in range(dim):
		var p = density_matrix.get_diagonal_real(i) / trace
		if p > 1e-14:
			s -= p * log(p)
	return s


func get_purity() -> float:
	# Get purity Tr(ρ²) of the quantum state.

	# Returns:
	# 1.0 for pure states, < 1.0 for mixed states
	# Minimum is 1/dim for maximally mixed state
	if _purity_cache >= 0.0:
		return _purity_cache

	if density_matrix == null:
		return 0.0

	# Tr(ρ²) / Tr(ρ)² — normalized so trace drift doesn't inflate purity above 1.
	# Use packed representation (always authoritative) — _data can be stale
	# when native ComplexMatrix backend is active.
	var packed = density_matrix._to_packed()
	var dim = density_matrix.n
	var expected = dim * dim * 2  # re,im pairs for each element
	if packed.size() < expected:
		return 0.0

	# Compute Tr(ρ) from diagonal real parts
	var trace: float = 0.0
	for i in range(dim):
		trace += packed[(i * dim + i) * 2]
	if trace < 1e-10:
		return 0.0

	# Tr(ρ²) = Σ_ij |ρ_ij|²
	var sum_sq = 0.0
	for k in range(dim * dim):
		var re = packed[k * 2]
		var im = packed[k * 2 + 1]
		sum_sq += re * re + im * im

	_purity_cache = sum_sq / (trace * trace)
	return _purity_cache


# ============================================================================
# MUTUAL INFORMATION: Physics-grounded correlation measure
# ============================================================================

func get_mutual_information(qubit_a: int, qubit_b: int) -> float:
	# Compute mutual information I(A:B) = S(A) + S(B) - S(AB) between two qubits.

	# Mutual information quantifies the total correlations (classical + quantum)
	# between two subsystems. For a Bell state: I(A:B) = 2 (maximum).
	# For a product state: I(A:B) = 0 (independent).

	# This is used for physics-grounded position encoding:
	# - High mutual info → bubbles cluster together
	# - Low mutual info → bubbles spread apart

	# Args:
	# qubit_a: First qubit index (0 to num_qubits-1)
	# qubit_b: Second qubit index (0 to num_qubits-1)

	# Returns:
	# Mutual information in bits [0, 2] for single qubits
	if density_matrix == null or qubit_a == qubit_b:
		return 0.0

	if qubit_a < 0 or qubit_a >= register_map.num_qubits:
		return 0.0
	if qubit_b < 0 or qubit_b >= register_map.num_qubits:
		return 0.0

	var S_A = _entropy_of_marginal(qubit_a)
	var S_B = _entropy_of_marginal(qubit_b)
	var S_AB = _entropy_of_joint(qubit_a, qubit_b)

	# I(A:B) = S(A) + S(B) - S(AB) (subadditivity guarantees this is >= 0)
	return max(S_A + S_B - S_AB, 0.0)


func get_cached_mutual_information(qubit_a: int, qubit_b: int) -> float:
	# Get mutual information from native C++ cache (computed during evolution).

	# This is the FAST path - MI is computed in C++ during evolve_with_mi() at physics rate.
	# Falls back to GDScript calculation if cache is empty or indices are invalid.

	# The cache stores MI in upper triangular order: [mi_01, mi_02, ..., mi_12, mi_13, ...]
	# Index formula: for i < j, index = i * (2*n - i - 1) / 2 + (j - i - 1)
	if qubit_a == qubit_b:
		return 0.0

	# Ensure a < b for cache lookup (MI is symmetric)
	var i = min(qubit_a, qubit_b)
	var j = max(qubit_a, qubit_b)
	var n = register_map.num_qubits

	if i < 0 or j >= n:
		return 0.0

	# Check if cache is valid
	if _cached_mi_values.is_empty():
		# Fallback to GDScript calculation
		return get_mutual_information(qubit_a, qubit_b)

	# Upper triangular index: i * (2n - i - 1) / 2 + (j - i - 1)
	var idx = i * (2 * n - i - 1) / 2 + (j - i - 1)

	if idx < 0 or idx >= _cached_mi_values.size():
		return get_mutual_information(qubit_a, qubit_b)

	return _cached_mi_values[idx]


func has_cached_mi() -> bool:
	# Check if MI cache is populated (native path is working).
	return not _cached_mi_values.is_empty()


func get_cached_max_mutual_information() -> float:
	# Max pairwise MI (bits) across the register, from the native cache ONLY.
	# Returns -1.0 (unknown) when the cache is empty rather than falling back to
	# the per-pair eigensolve path — too hot for UI/tracker polling rates.
	# The cache holds exactly the upper-triangular pairs, so max over the raw
	# array IS the max over pairs.
	if _cached_mi_values.is_empty():
		return -1.0
	var best := 0.0
	for v in _cached_mi_values:
		best = maxf(best, float(v))
	return best


func _entropy_of_marginal(qubit_index: int) -> float:
	# Compute von Neumann entropy S(ρ_A) = -Tr(ρ_A log ρ_A) of single-qubit marginal.

	# For a single qubit: S(ρ) = -p₀ log p₀ - p₁ log p₁
	# where p₀, p₁ are the eigenvalues of the 2×2 reduced density matrix.

	# Args:
	# qubit_index: Which qubit to compute entropy for

	# Returns:
	# Entropy in bits [0, 1] (0 = pure, 1 = maximally mixed)
	if density_matrix == null:
		return 0.0

	# Get diagonal elements of marginal (populations)
	var p0 = get_marginal(qubit_index, 0)  # P(|0⟩)
	var p1 = get_marginal(qubit_index, 1)  # P(|1⟩)

	# For full entropy, we need eigenvalues of reduced density matrix
	# The 2×2 reduced matrix is: [[p0, coh], [coh*, p1]]
	# Eigenvalues: λ± = (1 ± √(1 - 4·det))/2 where det = p0·p1 - |coh|²

	# Get coherence for this qubit's axis
	var coh_mag_sq = 0.0
	# Get the emoji pair for this qubit
	for emoji in register_map.coordinates.keys():
		var q = register_map.qubit(emoji)
		if q == qubit_index:
			var p = register_map.pole(emoji)
			if p == 0:  # Found north emoji
				# Find corresponding south emoji
				for other_emoji in register_map.coordinates.keys():
					var other_q = register_map.qubit(other_emoji)
					var other_p = register_map.pole(other_emoji)
					if other_q == qubit_index and other_p == 1:
						# Found the pair - get coherence
						var coh = get_coherence(emoji, other_emoji)
						if coh:
							coh_mag_sq = coh.re * coh.re + coh.im * coh.im
						break
				break

	# Compute determinant of 2×2 reduced density matrix
	var det = p0 * p1 - coh_mag_sq

	# Eigenvalues via characteristic polynomial
	var discriminant = max(1.0 - 4.0 * det, 0.0)
	var sqrt_disc = sqrt(discriminant)
	var lambda_plus = (1.0 + sqrt_disc) / 2.0
	var lambda_minus = (1.0 - sqrt_disc) / 2.0

	# von Neumann entropy: S = -Σ λ log λ (in nats, then convert to bits)
	var entropy = 0.0
	var eps = 1e-15

	if lambda_plus > eps:
		entropy -= lambda_plus * log(lambda_plus)
	if lambda_minus > eps:
		entropy -= lambda_minus * log(lambda_minus)

	# Convert from nats to bits (divide by ln(2))
	return entropy / log(2.0)


func _entropy_of_joint(qubit_a: int, qubit_b: int) -> float:
	# Compute von Neumann entropy S(ρ_AB) of the two-qubit reduced density matrix.

	# This is the entropy of the joint state of qubits A and B after tracing out
	# all other qubits.

	# Args:
	# qubit_a: First qubit index
	# qubit_b: Second qubit index

	# Returns:
	# Joint entropy in bits [0, 2] (0 = pure, 2 = maximally mixed)
	if density_matrix == null:
		return 0.0

	# Build the 4×4 reduced density matrix for qubits A and B
	var num_qubits = register_map.num_qubits
	var dim = register_map.dim()

	if num_qubits < 2:
		return 0.0

	# Ensure a < b for consistent indexing
	var qa = mini(qubit_a, qubit_b)
	var qb = maxi(qubit_a, qubit_b)

	# Partial trace over all qubits except qa and qb
	# Result is 4×4 matrix with indices (i_a, i_b) ∈ {0,1}²
	var rho_ab = ComplexMatrix.zeros(4)
	var shift_a = num_qubits - 1 - qa
	var shift_b = num_qubits - 1 - qb

	for out_a in range(2):
		for out_b in range(2):
			for in_a in range(2):
				for in_b in range(2):
					var out_ab = out_a * 2 + out_b
					var in_ab = in_a * 2 + in_b

					# Sum over all basis states where qubits a,b have specified values
					var accum = Complex.zero()
					for i in range(dim):
						var bit_a_i = (i >> shift_a) & 1
						var bit_b_i = (i >> shift_b) & 1
						if bit_a_i != out_a or bit_b_i != out_b:
							continue

						for j in range(dim):
							var bit_a_j = (j >> shift_a) & 1
							var bit_b_j = (j >> shift_b) & 1
							if bit_a_j != in_a or bit_b_j != in_b:
								continue

							# Check if other qubits match (partial trace condition)
							var other_match = true
							for k in range(num_qubits):
								if k == qa or k == qb:
									continue
								var shift_k = num_qubits - 1 - k
								if ((i >> shift_k) & 1) != ((j >> shift_k) & 1):
									other_match = false
									break

							if other_match:
								accum = accum.add(density_matrix.get_element(i, j))

					rho_ab.set_element(out_ab, in_ab, accum)

	# Compute eigenvalues of 4×4 matrix (numerical diagonalization)
	var eigenvalues = _eigenvalues_4x4(rho_ab)

	# von Neumann entropy: S = -Σ λ log λ
	var entropy = 0.0
	var eps = 1e-15

	for lambda_val in eigenvalues:
		if lambda_val > eps:
			entropy -= lambda_val * log(lambda_val)

	return entropy / log(2.0)


func _eigenvalues_4x4(mat: ComplexMatrix) -> Array[float]:
	# Compute eigenvalues of a 4×4 Hermitian matrix numerically.

	# Uses power iteration with deflation for simplicity.
	# For a Hermitian density matrix, all eigenvalues are real.

	# Returns:
	# Array of 4 real eigenvalues (may include near-zero values)
	var eigenvalues: Array[float] = []

	if mat == null or mat.n != 4:
		return [0.0, 0.0, 0.0, 0.0]

	# Work with a copy to avoid modifying original
	var work = ComplexMatrix.zeros(4)
	for i in range(4):
		for j in range(4):
			work.set_element(i, j, mat.get_element(i, j))

	# Power iteration with deflation to find eigenvalues
	for _ev_idx in range(4):
		var v = [Complex.new(1.0, 0.0), Complex.new(0.0, 0.0),
		         Complex.new(0.0, 0.0), Complex.new(0.0, 0.0)]

		# Power iteration
		for _iter in range(50):
			# w = work * v
			var w: Array = []
			for i in range(4):
				var sum = Complex.zero()
				for j in range(4):
					sum = sum.add(work.get_element(i, j).mul(v[j]))
				w.append(sum)

			# Normalize
			var norm_sq = 0.0
			for i in range(4):
				norm_sq += w[i].re * w[i].re + w[i].im * w[i].im
			var norm = sqrt(norm_sq)
			if norm < 1e-14:
				break
			for i in range(4):
				v[i] = Complex.new(w[i].re / norm, w[i].im / norm)

		# Compute Rayleigh quotient (eigenvalue estimate)
		var Av: Array = []
		for i in range(4):
			var sum = Complex.zero()
			for j in range(4):
				sum = sum.add(work.get_element(i, j).mul(v[j]))
			Av.append(sum)

		var numerator = Complex.zero()
		var denominator = 0.0
		for i in range(4):
			numerator = numerator.add(v[i].conjugate().mul(Av[i]))
			denominator += v[i].re * v[i].re + v[i].im * v[i].im

		var lambda_val = numerator.re / max(denominator, 1e-14)
		eigenvalues.append(max(lambda_val, 0.0))  # Clamp small negatives

		# Deflate: work = work - λ * v * v†
		for i in range(4):
			for j in range(4):
				var outer = v[i].mul(v[j].conjugate()).scale(lambda_val)
				work.set_element(i, j, work.get_element(i, j).sub(outer))

	return eigenvalues


func get_coherence(emoji_a: String, emoji_b: String):
	# Get coherence (off-diagonal element) between two emojis.

	# Returns the complex coherence ρ[a,b] from the density matrix.
	# Used for visualization and correlation calculations.

	# Args:
	# emoji_a: First emoji
	# emoji_b: Second emoji

	# Returns:
	# Complex coherence value, or null if emojis not registered
	if not register_map.has(emoji_a) or not register_map.has(emoji_b):
		return null

	if density_matrix == null:
		return null

	# For same-qubit emojis (north/south pair), return off-diagonal of reduced matrix
	var q_a = register_map.qubit(emoji_a)
	var q_b = register_map.qubit(emoji_b)
	var p_a = register_map.pole(emoji_a)
	var p_b = register_map.pole(emoji_b)

	if q_a != q_b:
		# Different qubits - return cross-correlation from density matrix
		# This is more complex - for now return null
		return null

	if p_a == p_b:
		# Same pole - no coherence (would be diagonal)
		return Complex.zero()

	# Same qubit, different poles - compute off-diagonal of reduced density matrix
	var num_qubits = register_map.num_qubits
	var dim = register_map.dim()
	var shift = num_qubits - 1 - q_a

	# Compute ρ[0,1] of the single-qubit reduced density matrix
	var coherence = Complex.zero()
	for i in range(dim):
		for j in range(dim):
			var bit_i = (i >> shift) & 1
			var bit_j = (j >> shift) & 1

			# We want ρ_reduced[p_a, p_b] (off-diagonal)
			# This accumulates when qubit has value p_a in bra and p_b in ket
			if bit_i == p_a and bit_j == p_b:
				# Check if other qubits match (partial trace condition)
				var other_match = true
				for k in range(num_qubits):
					if k == q_a:
						continue
					var shift_k = num_qubits - 1 - k
					if ((i >> shift_k) & 1) != ((j >> shift_k) & 1):
						other_match = false
						break

				if other_match:
					coherence = coherence.add(density_matrix.get_element(i, j))

	return coherence


func apply_decay(qubit_index: int, rate: float, dt: float) -> void:
	# Apply spontaneous decay toward south pole (thermal relaxation).

	# Implements: dρ/dt = γ(L ρ L† - {L†L, ρ}/2)
	# where L = √γ |south⟩⟨north| pushes north → south.

	# Args:
	# qubit_index: Which qubit to decay
	# rate: Decay rate γ (1/s)
	# dt: Time step (s)

	# Example:
	# apply_decay(0, 0.5, 0.1)  # Temperature decays toward cold
	var from_pole = 0  # North
	var to_pole = 1    # South
	_apply_lindblad_1q(qubit_index, from_pole, to_pole, rate, dt)


func apply_cross_register_channel(source_qubit: int, target_qubit: int,
                                   rate: float, dt: float) -> void:
	# Apply a dissipative channel transferring population between two qubits.

	# Creates a cross-register Lindblad jump operator:
	# L = √γ (σ⁺_target ⊗ σ⁻_source)

	# This simultaneously decays the source qubit (north→south) and excites
	# the target qubit (south→north), implementing directed energy/population
	# transfer through the density matrix. Uses the exact Kraus map (CPTP).

	# Args:
	# source_qubit: Qubit to drain FROM (population flows out of north pole)
	# target_qubit: Qubit to pump INTO (population flows into north pole)
	# rate: Channel strength γ (1/s)
	# dt: Time step (s)
	if density_matrix == null:
		return
	if source_qubit == target_qubit:
		return  # Self-channel is meaningless

	var num_qubits = register_map.num_qubits
	var dim = register_map.dim()
	if source_qubit < 0 or source_qubit >= num_qubits:
		return
	if target_qubit < 0 or target_qubit >= num_qubits:
		return

	var src_shift = num_qubits - 1 - source_qubit
	var tgt_shift = num_qubits - 1 - target_qubit

	# Exact transition probability (amplitude damping channel)
	var p = 1.0 - exp(-rate * dt)
	p = clampf(p, 0.0, 1.0)
	if p < 1e-15:
		return  # No effect

	var sqrt_1mp = sqrt(1.0 - p)

	# The cross-register channel acts on basis states where:
	#   source qubit has north pole (0) AND target qubit has south pole (1)
	# Flipping both: source goes 0→1 (decay), target goes 1→0 (excitation)
	#
	# K₀ (no-jump): identity on states without the pattern,
	#   √(1-p) scaling on states matching the pattern
	# K₁ (jump): √p × flip both qubits on matching states
	var rho_new = ComplexMatrix.zeros(dim)
	for i in range(dim):
		for j in range(dim):
			var src_bit_i = (i >> src_shift) & 1
			var tgt_bit_i = (i >> tgt_shift) & 1
			var src_bit_j = (j >> src_shift) & 1
			var tgt_bit_j = (j >> tgt_shift) & 1

			# Can this row/col participate in a jump?
			var jumpable_i = (src_bit_i == 0 and tgt_bit_i == 1)  # source=north, target=south
			var jumpable_j = (src_bit_j == 0 and tgt_bit_j == 1)

			# K₀ term: diagonal scaling
			var k0_i = sqrt_1mp if jumpable_i else 1.0
			var k0_j = sqrt_1mp if jumpable_j else 1.0
			var rho_ij = density_matrix.get_element(i, j)
			var result = rho_ij.scale(k0_i * k0_j)

			# K₁ term: jump (flip both qubits) for jumpable states
			# The flipped state has source=south(1), target=north(0)
			var flipped_i = (src_bit_i == 1 and tgt_bit_i == 0)  # post-jump pattern
			var flipped_j = (src_bit_j == 1 and tgt_bit_j == 0)
			if flipped_i and flipped_j:
				# Map back to pre-jump source indices
				var i_pre = i ^ (1 << src_shift) ^ (1 << tgt_shift)
				var j_pre = j ^ (1 << src_shift) ^ (1 << tgt_shift)
				result = result.add(density_matrix.get_element(i_pre, j_pre).scale(p))

			rho_new.set_element(i, j, result)

	density_matrix = rho_new
	_purity_cache = -1.0


func get_trace() -> float:
	# Get trace of density matrix (should always be 1.0).
	if density_matrix == null:
		return 0.0

	var trace = 0.0
	var dim = register_map.dim()
	for i in range(dim):
		trace += density_matrix.get_element(i, i).re

	return trace


# ============================================================================
# COUPLING INJECTION (Mill/Building Mechanics)
# ============================================================================

## Coupling registry: stores injected couplings for Hamiltonian rebuilds
## Format: {"qubit_a-qubit_b": {"a": int, "b": int, "J": float}}
var coupling_registry: Dictionary = {}


func add_coupling(qubit_a: int, qubit_b: int, strength: float) -> Dictionary:
	# Add ZZ coupling between two qubits in the Hamiltonian.

	# Creates/updates σz⊗σz interaction term: J × σz_a ⊗ σz_b
	# This causes population oscillation between the coupled axes.

	# Args:
	# qubit_a: First qubit index
	# qubit_b: Second qubit index
	# strength: Coupling strength J

	# Returns:
	# Dictionary with success/error keys
	if qubit_a < 0 or qubit_a >= register_map.num_qubits:
		return {"success": false, "error": "invalid_qubit_a", "qubit": qubit_a}
	if qubit_b < 0 or qubit_b >= register_map.num_qubits:
		return {"success": false, "error": "invalid_qubit_b", "qubit": qubit_b}
	if qubit_a == qubit_b:
		return {"success": false, "error": "same_qubit", "qubit": qubit_a}

	# Store coupling in registry (canonical order: smaller index first)
	var key = "%d-%d" % [mini(qubit_a, qubit_b), maxi(qubit_a, qubit_b)]
	coupling_registry[key] = {"a": qubit_a, "b": qubit_b, "J": strength}

	# Apply coupling directly to Hamiltonian
	_add_zz_coupling_to_hamiltonian(qubit_a, qubit_b, strength)

	_log("debug", "quantum", "⚛️", "Added ZZ coupling: qubit %d ↔ qubit %d (J=%.3f)" % [qubit_a, qubit_b, strength])
	return {"success": true, "coupling_key": key}


func _add_zz_coupling_to_hamiltonian(qubit_a: int, qubit_b: int, J: float) -> void:
	# Add σz⊗σz coupling term directly to Hamiltonian diagonal.

	# ZZ interaction: H += J × σz_a ⊗ σz_b
	# Diagonal elements only: ⟨i|σz_a⊗σz_b|i⟩ = ±1 depending on qubit states

	# Args:
	# qubit_a: First qubit index
	# qubit_b: Second qubit index
	# J: Coupling strength
	if hamiltonian == null:
		push_warning("⚠️ Cannot add coupling: Hamiltonian is null")
		return

	var n = register_map.num_qubits
	var dim = 1 << n  # 2^n
	var shift_a = n - 1 - qubit_a
	var shift_b = n - 1 - qubit_b

	for i in range(dim):
		# σz eigenvalue: +1 for |0⟩, -1 for |1⟩
		var bit_a = (i >> shift_a) & 1
		var bit_b = (i >> shift_b) & 1
		var sign_a = 1 - 2 * bit_a  # +1 if bit=0, -1 if bit=1
		var sign_b = 1 - 2 * bit_b
		var zz_value = sign_a * sign_b * J

		# Add to diagonal of Hamiltonian
		var current = hamiltonian.get_element(i, i)
		hamiltonian.set_element(i, i, Complex.new(current.re + zz_value, current.im))

	# H mutated in place → the closed-system propagator cache is stale.
	_unitary_dirty = true

	# Update sparse Hamiltonian if in use
	if sparse_hamiltonian != null:
		sparse_hamiltonian = hamiltonian  # Re-reference


func get_coupling(qubit_a: int, qubit_b: int) -> float:
	# Get current coupling strength between two qubits.

	# Returns:
	# Coupling strength J, or 0.0 if no coupling exists
	var key = "%d-%d" % [mini(qubit_a, qubit_b), maxi(qubit_a, qubit_b)]
	if coupling_registry.has(key):
		return coupling_registry[key].J
	return 0.0


func get_all_couplings() -> Array:
	# Get all registered couplings.

	# Returns:
	# Array of {a: int, b: int, J: float} dictionaries
	var result = []
	for key in coupling_registry:
		result.append(coupling_registry[key].duplicate())
	return result


# ============================================================================
# SPARSE OPERATOR SETUP (Performance Optimization)
# ============================================================================

func set_hamiltonian(H: ComplexMatrix) -> void:
	# Set Hamiltonian with auto-sparse conversion.

	# Automatically converts to sparse format if sparsity > 50%.
	# Sparse Hamiltonian: 10-50x faster commutator computation.
	hamiltonian = H

	if H == null:
		sparse_hamiltonian = null
		return

	# Sparsity check (simplified - native engine handles actual sparse ops)
	var nnz = 0
	var total = H.n * H.n
	for i in range(total):
		var c = H._data[i]
		if c.re * c.re + c.im * c.im > 1e-24:
			nnz += 1
	var sparsity = 1.0 - (float(nnz) / float(total)) if total > 0 else 0.0

	if sparsity > 0.5:
		sparse_hamiltonian = H  # Keep reference for native engine
		_log("debug", "quantum", "⚡", "Hamiltonian converted to sparse: %.1f%% zeros, nnz=%d" % [sparsity * 100, nnz])
	else:
		sparse_hamiltonian = null
		_log("debug", "quantum", "📊", "Hamiltonian kept dense: %.1f%% zeros (below threshold)" % [sparsity * 100])


func set_driven_icons(configs: Array) -> void:
	# Set time-dependent driver configurations for efficient Hamiltonian updates.

	# These configs are used by update_driven_self_energies() to update
	# Hamiltonian diagonal terms without full rebuild.

	# Args:
	# configs: Array from HamiltonianBuilder.get_driven_icons()
	# [{emoji, qubit, pole, icon_ref, driver_type, base_energy}, ...]
	driven_icons = configs
	_last_driver_update_time = -1.0

	if not configs.is_empty():
		var driver_emojis = []
		for cfg in configs:
			driver_emojis.append("%s(%s)" % [cfg.emoji, cfg.driver_type])
		_log("debug", "quantum", "⚡", "Registered %d driven icons: %s" % [configs.size(), ", ".join(driver_emojis)])


func update_driven_self_energies(time: float) -> void:
	# Update Hamiltonian diagonal terms for time-dependent drivers.

	# This is called during evolve() to apply oscillating self-energies
	# (e.g., sun/moon 20-second cycle) without rebuilding the full Hamiltonian.

	# Only modifies diagonal elements for icons with active drivers.
	# Invalidates native evolution engine cache if drivers changed significantly.

	# Args:
	# time: Current simulation time in seconds
	if driven_icons.is_empty():
		return

	if hamiltonian == null:
		return

	var num_qubits = register_map.num_qubits
	var dim = 1 << num_qubits
	var significant_change = false

	for cfg in driven_icons:
		var icon = cfg.icon_ref
		var qubit_idx = cfg.qubit
		var pole_str = cfg.pole

		# Get time-dependent energy from icon
		var old_energy = cfg.get("cached_energy", cfg.base_energy)
		if icon == null:
			push_warning("update_driven_self_energies: missing icon_ref for driven icon %s" % str(cfg.get("emoji", "")))
			continue
		var new_energy = icon.get_self_energy(time) if icon.has_method("get_self_energy") else cfg.base_energy

		# Skip if energy hasn't changed significantly
		if abs(new_energy - old_energy) < 1e-6:
			continue

		significant_change = true
		cfg["cached_energy"] = new_energy

		# Calculate the delta to add to Hamiltonian diagonal
		var delta = new_energy - old_energy
		var shift = num_qubits - 1 - qubit_idx

		# Update all basis states where this qubit is in the target pole
		for i in range(dim):
			if ((i >> shift) & 1) == pole_str:
				var current = hamiltonian.get_element(i, i)
				hamiltonian.set_element(i, i, Complex.new(current.re + delta, current.im))

	# Update sparse reference if needed
	if significant_change and sparse_hamiltonian != null:
		sparse_hamiltonian = hamiltonian

	# NOTE: Native evolution engine cache is not invalidated for small diagonal changes
	# The native engine stores its own copy, so for truly accurate time-dependent evolution,
	# we would need to rebuild the native engine. For now, we accept small drift.
	# Full rebuild happens every ~1 second via biome's periodic update.


func set_lindblad_operators(operators: Array) -> void:
	# Set Lindblad operators with auto-sparse conversion.

	# Converts each operator to sparse format. Lindblad operators are
	# typically very sparse (e.g., |target⟩⟨source| has only 1 non-zero).

	# Sparse Lindblad: 10-50x faster dissipator computation via native
	# lindblad_dissipator() which fuses L ρ L† - ½{L†L, ρ} into one call.
	lindblad_operators = operators
	sparse_lindblad_operators.clear()

	if operators.is_empty():
		return

	var total_nnz = 0
	var total_dense = 0

	for L in operators:
		if L == null:
			continue

		# Inline sparsity check (native engine handles actual sparse ops)
		var nnz = 0
		var total = L.n * L.n
		var lp = L._to_packed()
		for i in range(total):
			var re = lp[i * 2]
			var im = lp[i * 2 + 1]
			if re * re + im * im > 1e-24:
				nnz += 1

		sparse_lindblad_operators.append(L)  # Keep reference
		total_nnz += nnz
		total_dense += total

	var avg_sparsity = 1.0 - (float(total_nnz) / float(total_dense)) if total_dense > 0 else 0.0
	_log("debug", "quantum", "⚡", "%d Lindblad ops → sparse: avg %.1f%% zeros, total nnz=%d" % [
		operators.size(), avg_sparsity * 100, total_nnz])

	# Pre-compute L† and L†L for the dense fallback path (saves 2 matmuls/op/substep)
	_rebuild_lindblad_cache()


func _rebuild_lindblad_cache() -> void:
	# Pre-compute L† and L†L for each Lindblad operator.

	# These are constant between operator rebuilds (faction changes) but were
	# previously recomputed every substep. Caching saves 2 matmuls per operator
	# per substep — for 5 operators × 3 substeps/phrame = 30 fewer matmuls/phrame.
	_lindblad_L_dag.clear()
	_lindblad_Ldag_L.clear()
	_lindblad_cache_valid = false

	for L in lindblad_operators:
		if L == null:
			_lindblad_L_dag.append(null)
			_lindblad_Ldag_L.append(null)
			continue
		var L_dag = L.dagger()
		var Ldag_L = L_dag.mul(L)
		_lindblad_L_dag.append(L_dag)
		_lindblad_Ldag_L.append(Ldag_L)

	_lindblad_cache_valid = lindblad_operators.size() > 0
	if _lindblad_cache_valid:
		_log("debug", "quantum", "⚡", "Lindblad cache built: %d ops pre-computed (L†, L†L)" % lindblad_operators.size())
