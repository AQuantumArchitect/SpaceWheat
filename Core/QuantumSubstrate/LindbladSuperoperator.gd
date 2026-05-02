class_name LindbladSuperoperator
extends RefCounted

const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const DensityMatrix = preload("res://Core/QuantumSubstrate/DensityMatrix.gd")

## LindbladSuperoperator: Dissipative quantum evolution
##
## The Lindblad master equation describes open quantum system dynamics:
##
##   dρ/dt = -i[H,ρ] + Σₖ γₖ D[Lₖ](ρ)
##
## where D[L](ρ) = LρL† - ½{L†L, ρ} is the dissipator
##
## This class handles the dissipative part: Σₖ γₖ D[Lₖ](ρ)
##
## Physical interpretation:
## - Each Lindblad operator Lₖ represents a "jump" or "decay" channel
## - γₖ is the rate of that channel
## - For population transfer i→j: L = |j⟩⟨i| (creates j, destroys i)
## - Decoherence: L = |i⟩⟨i| causes pure dephasing
##
## Trace preservation:
## - The Lindblad form guarantees Tr(ρ) is preserved
## - Each D[L](ρ) has Tr(D[L](ρ)) = 0

## Storage for Lindblad terms
## Each term is { "L": ComplexMatrix, "rate": float, "source": String, "target": String }
var _terms: Array = []
var _dimension: int = 0
var emoji_list: Array[String] = []
var emoji_to_index: Dictionary = {}

#region Construction

## Build Lindblad operators from Icons and emoji list
func build_from_icons(icons: Array, emojis: Array) -> void:
	_terms = []
	emoji_list = []
	emoji_to_index = {}

	for i in range(emojis.size()):
		var emoji = emojis[i]
		emoji_list.append(emoji)
		emoji_to_index[emoji] = i

	_dimension = emojis.size()

	# Build terms from each Icon
	for icon in icons:
		var source_idx = emoji_to_index.get(icon.emoji, -1)
		if source_idx < 0:
			continue

		# Lindblad outgoing: source loses population to target
		# L = |target⟩⟨source|
		for target_emoji in icon.lindblad_outgoing:
			var target_idx = emoji_to_index.get(target_emoji, -1)
			if target_idx >= 0:
				var rate = icon.lindblad_outgoing[target_emoji]
				var L = _create_jump_operator(target_idx, source_idx)
				_terms.append({
					"L": L,
					"rate": rate,
					"source": icon.emoji,
					"target": target_emoji,
					"type": "transfer"
				})

		# Decay: source loses to decay_target
		if icon.decay_rate > 0 and icon.decay_target:
			var decay_idx = emoji_to_index.get(icon.decay_target, -1)
			if decay_idx >= 0:
				var L = _create_jump_operator(decay_idx, source_idx)
				_terms.append({
					"L": L,
					"rate": icon.decay_rate,
					"source": icon.emoji,
					"target": icon.decay_target,
					"type": "decay"
				})

	# Process lindblad_incoming (convert to outgoing from source perspective)
	# This is syntactic sugar: if A has incoming from B, treat as B→A
	for icon in icons:
		var target_idx = emoji_to_index.get(icon.emoji, -1)
		if target_idx < 0:
			continue

		for source_emoji in icon.lindblad_incoming:
			var source_idx = emoji_to_index.get(source_emoji, -1)
			if source_idx >= 0:
				var rate = icon.lindblad_incoming[source_emoji]

				# Check if this term already exists (from source's outgoing)
				var exists = false
				for term in _terms:
					if term.source == source_emoji and term.target == icon.emoji:
						exists = true
						break

				if not exists:
					var L = _create_jump_operator(target_idx, source_idx)
					_terms.append({
						"L": L,
						"rate": rate,
						"source": source_emoji,
						"target": icon.emoji,
						"type": "incoming"
					})

## Build Lindblad operators directly from a biome's atom_components dict.
##
## Atoms-native path (biome-owned). Each entry in atom_components is keyed by
## an atom (emoji) and may carry `lindblad_outgoing`, `lindblad_incoming`,
## and `decay` term shapes. Gated channels live elsewhere (QuantumComputer
## handles state-dependent rates and reads its own config path).
##
## A term is *built* only when every endpoint is in `basis`. Terms with a
## missing endpoint are silently *primed* — the data is retained on the
## biome (caller still owns atom_components) but no operator is emitted yet.
## This is what lets a biome carry pre-loaded reactions for emojis the
## player has not yet brought in.
func build_from_atoms(atom_components: Dictionary, basis: Array) -> void:
	_terms = []
	emoji_list = []
	emoji_to_index = {}

	for i in range(basis.size()):
		var emoji = basis[i]
		emoji_list.append(emoji)
		emoji_to_index[emoji] = i
	_dimension = basis.size()

	# Track (source, target) pairs already emitted so incoming-direction
	# entries don't double-up on outgoing-direction declarations.
	var emitted: Dictionary = {}

	for source_emoji in atom_components.keys():
		var source_idx: int = emoji_to_index.get(source_emoji, -1)
		var component = atom_components[source_emoji]
		if not (component is Dictionary):
			continue

		# Outgoing transfers: source → target
		var outgoing = component.get("lindblad_outgoing", {})
		if outgoing is Dictionary:
			for target_emoji in outgoing.keys():
				var target_idx: int = emoji_to_index.get(target_emoji, -1)
				if source_idx < 0 or target_idx < 0:
					continue  # primed
				var rate: float = float(outgoing[target_emoji])
				var L = _create_jump_operator(target_idx, source_idx)
				_terms.append({
					"L": L, "rate": rate,
					"source": source_emoji, "target": target_emoji,
					"type": "transfer"
				})
				emitted[source_emoji + "→" + target_emoji] = true

		# Decay: source → decay_target (same operator shape as transfer)
		var decay = component.get("decay", {})
		if decay is Dictionary and decay.has("rate"):
			var dt_emoji: String = str(decay.get("target", ""))
			var dt_rate: float = float(decay.get("rate", 0.0))
			var dt_idx: int = emoji_to_index.get(dt_emoji, -1)
			if source_idx >= 0 and dt_idx >= 0 and dt_rate > 0.0:
				var L = _create_jump_operator(dt_idx, source_idx)
				_terms.append({
					"L": L, "rate": dt_rate,
					"source": source_emoji, "target": dt_emoji,
					"type": "decay"
				})
				emitted[source_emoji + "→" + dt_emoji] = true

	# Incoming-direction sweep (syntactic sugar; dedup against outgoing)
	for receiver_emoji in atom_components.keys():
		var receiver_idx: int = emoji_to_index.get(receiver_emoji, -1)
		var component = atom_components[receiver_emoji]
		if not (component is Dictionary):
			continue
		var incoming = component.get("lindblad_incoming", {})
		if not (incoming is Dictionary):
			continue
		for src_emoji in incoming.keys():
			var src_idx: int = emoji_to_index.get(src_emoji, -1)
			if receiver_idx < 0 or src_idx < 0:
				continue  # primed
			if emitted.has(src_emoji + "→" + receiver_emoji):
				continue
			var rate: float = float(incoming[src_emoji])
			var L = _create_jump_operator(receiver_idx, src_idx)
			_terms.append({
				"L": L, "rate": rate,
				"source": src_emoji, "target": receiver_emoji,
				"type": "incoming"
			})


## Create jump operator |j⟩⟨i| that transfers from i to j
func _create_jump_operator(j: int, i: int) -> ComplexMatrix:
	var L = ComplexMatrix.new(_dimension)
	L.set_element(j, i, Complex.one())
	return L

## Add a custom Lindblad term
func add_term(L: ComplexMatrix, rate: float, description: String = "") -> void:
	_terms.append({
		"L": L,
		"rate": rate,
		"source": "",
		"target": "",
		"type": "custom",
		"description": description
	})

## Add a dephasing term on state i (pure decoherence without population change)
func add_dephasing(i: int, rate: float) -> void:
	var L = ComplexMatrix.new(_dimension)
	L.set_element(i, i, Complex.one())
	_terms.append({
		"L": L,
		"rate": rate,
		"source": emoji_list[i] if i < emoji_list.size() else "",
		"target": emoji_list[i] if i < emoji_list.size() else "",
		"type": "dephasing"
	})

#endregion

#region Evolution

## Apply all Lindblad terms to density matrix for timestep dt
## Returns new density matrix (does not modify in place)
func apply(rho, dt: float):
	var result = rho.duplicate_density()

	for term in _terms:
		_apply_single_term(result, term.L, term.rate, dt)

	return result

## Apply all Lindblad terms using sparse jump operator optimization
## Much faster for jump operators L = |j⟩⟨i| (which are extremely sparse)
## Returns new density matrix (does not modify in place)
func apply_sparse(rho, dt: float):
	var result = rho.duplicate_density()

	for term in _terms:
		# Extract source and target indices from the term
		var source_idx = emoji_to_index.get(term.source, -1)
		var target_idx = emoji_to_index.get(term.target, -1)

		if source_idx >= 0 and target_idx >= 0:
			_apply_jump_operator_sparse(result, source_idx, target_idx, term.rate, dt)
		else:
			# Fallback to dense for custom terms
			_apply_single_term(result, term.L, term.rate, dt)

	return result

## Apply single Lindblad term: γ D[L](ρ) = γ (LρL† - ½{L†L, ρ})
func _apply_single_term(rho, L: ComplexMatrix, rate: float, dt: float) -> void:
	var rho_mat = rho.get_matrix()
	var L_dag = L.dagger()
	var L_dag_L = L_dag.mul(L)

	# LρL†
	var term1 = L.mul(rho_mat).mul(L_dag)

	# ½ L†L ρ
	var term2 = L_dag_L.mul(rho_mat).scale_real(0.5)

	# ½ ρ L†L
	var term3 = rho_mat.mul(L_dag_L).scale_real(0.5)

	# D[L](ρ) = term1 - term2 - term3
	var dissipator = term1.sub(term2).sub(term3)

	# Apply: ρ += γ dt D[L](ρ)
	var new_rho = rho_mat.add(dissipator.scale_real(rate * dt))
	rho.set_matrix(new_rho)

## Apply jump operator L = |j⟩⟨i| using sparse optimization
## For jump operators, the Lindblad dissipator can be computed without matrix multiplication
##
## D[L](ρ) = LρL† - ½{L†L, ρ}
## where L = |j⟩⟨i| has only ONE non-zero element at (j,i)
##
## Derivation for L = |j⟩⟨i|:
##   LρL† = |j⟩⟨i|ρ|i⟩⟨j| = ρ_ii |j⟩⟨j|   (purely diagonal!)
##   L†L  = |i⟩⟨i|   (projector onto source)
##   ½{L†L, ρ}_ab = ½(δ_ai ρ_ib + ρ_ai δ_bi)
##
## Result (only three effects):
##   1. ρ_jj += γdt × ρ_ii          (population transfer: source → target)
##   2. ρ_ii *= (1 - γdt)            (population loss from source)
##   3. ρ_ik *= (1 - γdt/2) ∀ k≠i   (coherence decay involving source)
##
## NOTE: No off-diagonal coherence transfer to target. LρL† is purely diagonal
## for jump operators. An earlier version of this code incorrectly added
## ρ_jk += γdt × ρ_ik, which inflated Tr(ρ²) above 1.0 over time.
func _apply_jump_operator_sparse(rho, source_idx: int, target_idx: int, rate: float, dt: float) -> void:
	var rho_mat = rho.get_matrix()
	var gamma_dt = rate * dt

	var rho_data = rho_mat._data
	var dim = _dimension

	# Source population (before modification)
	var source_diag_idx = source_idx * dim + source_idx
	var rho_ii = rho_data[source_diag_idx]

	# Use exact exponential decay instead of Euler (1 - γdt).
	# Euler overshoots to negative when γdt > 1 (strong drain).
	# exp(-γdt) is always positive and exact for constant-rate decay.
	var decay = exp(-gamma_dt)          # Population: exp(-γdt)
	var half_decay = exp(-gamma_dt * 0.5)  # Coherence: exp(-γdt/2)

	# 1. LρL† = ρ_ii |j⟩⟨j|  →  ρ_jj += (1 - decay) × ρ_ii
	# Transfer the population that LEFT the source (not γdt × ρ_ii which can exceed ρ_ii)
	var target_diag_idx = target_idx * dim + target_idx
	rho_data[target_diag_idx] = rho_data[target_diag_idx].add(rho_ii.scale(1.0 - decay))

	# 2. -½{L†L, ρ} diagonal: ρ_ii *= exp(-γdt)
	rho_data[source_diag_idx] = rho_ii.mul(Complex.new(decay, 0.0))

	# 3. -½{L†L, ρ} off-diagonal: ρ_ik *= exp(-γdt/2)
	var coh_damping = Complex.new(half_decay, 0.0)
	for k in range(dim):
		if k != source_idx:
			rho_data[source_idx * dim + k] = rho_data[source_idx * dim + k].mul(coh_damping)
			rho_data[k * dim + source_idx] = rho_data[k * dim + source_idx].mul(coh_damping)

	rho.set_matrix(rho_mat)

## Get total transfer rate out of a state
func get_outgoing_rate(emoji: String) -> float:
	var total = 0.0
	for term in _terms:
		if term.source == emoji:
			total += term.rate
	return total

## Get total transfer rate into a state
func get_incoming_rate(emoji: String) -> float:
	var total = 0.0
	for term in _terms:
		if term.target == emoji:
			total += term.rate
	return total

#endregion

#region Query

## Get all terms
func get_terms() -> Array:
	return _terms

## Get terms by type
func get_terms_by_type(type: String) -> Array:
	var result: Array = []
	for term in _terms:
		if term.type == type:
			result.append(term)
	return result

## Get dimension
func dimension() -> int:
	return _dimension

#endregion

#region Validation

## Verify trace preservation (should be automatic for Lindblad form)
## Returns true if applying superoperator preserves trace
func verify_trace_preservation(test_dt: float = 0.01) -> bool:
	# Create test density matrix (maximally mixed)
	var test_rho = DensityMatrix.new()
	test_rho.initialize_with_emojis(emoji_list)
	test_rho.set_maximally_mixed()

	var initial_trace = test_rho.get_trace()
	var evolved = apply(test_rho, test_dt)
	var final_trace = evolved.get_trace()

	return abs(initial_trace - final_trace) < 1e-10

## Verify complete positivity (eigenvalues of evolved ρ should be ≥ 0)
func verify_positivity(test_dt: float = 0.01) -> bool:
	# Create test density matrix (pure state)
	var test_rho = DensityMatrix.new()
	test_rho.initialize_with_emojis(emoji_list)
	var amps: Array = []
	for i in range(_dimension):
		amps.append(Complex.new(1.0 / sqrt(_dimension), 0.0))
	test_rho.set_pure_state(amps)

	var evolved = apply(test_rho, test_dt)
	var validation = evolved.is_valid()

	return validation.positive_semidefinite

#endregion

#region Debug

func _to_string() -> String:
	return "LindbladSuperoperator(%d states, %d terms)" % [_dimension, _terms.size()]

func debug_print() -> void:
	print("=== Lindblad Superoperator ===")
	print("Dimension: %d" % _dimension)
	print("Number of terms: %d" % _terms.size())
	print("\nTransfer terms:")
	for term in _terms:
		if term.source and term.target:
			print("  %s → %s: γ = %.5f/sec (type: %s)" % [
				term.source, term.target, term.rate, term.type
			])
		elif term.has("description"):
			print("  Custom: %s, γ = %.5f/sec" % [term.description, term.rate])

#endregion
