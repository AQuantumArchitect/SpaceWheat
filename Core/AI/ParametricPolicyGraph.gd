class_name ParametricPolicyGraph
extends RefCounted

## ParametricPolicyGraph
## ---------------------
## Quantum meta-learner over policy prior parameters.
##
## 3 qubits → 8 basis states, each representing one tunable policy scalar
## (e.g., "quest_cycle.milk_distance_gain", "probe_cycle.base").
##
## ρ starts maximally mixed (I/8): all parameters at JSONL defaults.
## Lindblad feedback from action outcomes pumps/drains parameter slots.
## Hamiltonian couplings encode parameter group correlations:
##   - Milk-navigation cluster:  quest_milk_gain ↔ lock_milk_gain
##   - Exploration cluster:      quest_frontier ↔ unknown_vocab ↔ discover_base
##   - Resource-mgmt cluster:    probe_base ↔ drain_base
##   - Time-mgmt cluster:        drain_base ↔ skip_base
##
## resolve_graph(raw_graph) applies learned multipliers to the policy graph:
##   effective_value = jsonl_value × clamp(ρ_ii × DIM, 0.2, 5.0)
##
## At uniform ρ (1/DIM per slot): multiplier = 1.0 → exact JSONL values.
## After learning: pumped params are boosted, drained ones are suppressed.
## This is a slower meta-learning layer: decay_rate = 0.04 vs 0.12 for
## the action-selection register.

const DIM := 8
const NUM_QUBITS := 3
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")

## Parameter slot registry: basis state |i⟩ ↔ dotted policy graph path.
## Ordering chosen to align with H_COUPLINGS cluster groupings.
const PARAM_PATHS: Array[String] = [
	"action_priors.quest_cycle.milk_distance_gain",  # 0: steer quests toward milk-proximal vocab
	"action_priors.quest_cycle.frontier_bonus",       # 1: prefer new-biome quests
	"action_priors.probe_cycle.base",                 # 2: resource-probing urgency
	"action_priors.lindblad_drain.base",              # 3: active biome draining
	"action_priors.time_skip.base",                   # 4: idle time-skip tolerance
	"action_priors.lock_offer.milk_distance_gain",    # 5: lock milk-proximal offers
	"action_priors.quest_cycle.unknown_vocab",        # 6: chase unknown vocabulary
	"action_priors.discover_biome.base",              # 7: biome expansion eagerness
]

const PARAM_LABELS: Array[String] = [
	"quest_milk_gain",
	"quest_frontier",
	"probe_base",
	"drain_base",
	"skip_base",
	"lock_milk_gain",
	"quest_unknown_vocab",
	"discover_base",
]

## Hamiltonian couplings: [slot_i, slot_j, base_strength]
## Off-diagonal H elements encode which parameters naturally co-evolve.
## Applied as: H[i,j] = H[j,i] = base_strength * (_coupling_strength / 0.12)
const H_COUPLINGS: Array = [
	[0, 5, 0.15],  # quest_milk_gain ↔ lock_milk_gain  (milk-navigation)
	[1, 6, 0.12],  # quest_frontier  ↔ unknown_vocab    (exploration)
	[2, 3, 0.10],  # probe_base      ↔ drain_base        (resource-mgmt)
	[3, 4, 0.10],  # drain_base      ↔ skip_base         (time-mgmt)
	[6, 7, 0.08],  # unknown_vocab   ↔ discover_base     (vocab expansion)
]

const MULTIPLIER_MIN := 0.2
const MULTIPLIER_MAX := 5.0

# ── Internal quantum state ──────────────────────────────────────────
var _qc: QuantumComputer
var _pump_rates: PackedFloat64Array
var _drain_rates: PackedFloat64Array

# ── Tunable (meta-learning timescale) ──
# Tuned for visible divergence within 20-40 steps (one Fibonacci round).
# Previous values (0.04/0.03/0.04/0.12) required 100+ steps to move ρ.
var _pump_scale: float = 0.15        # reward → pump rate increment
var _drain_scale: float = 0.10       # penalty → drain rate increment
var _decay_rate: float = 0.02        # per-step exponential rate decay (slow forget)
var _coupling_strength: float = 0.20 # H off-diagonal scale

var _step_count: int = 0


func _init() -> void:
	reset({})


func reset(config: Dictionary = {}) -> void:
	"""Initialize to maximally mixed state. Reads ppg_* keys from config."""
	_pump_scale = clamp(float(config.get("ppg_pump_scale", 0.15)), 0.0, 1.0)
	_drain_scale = clamp(float(config.get("ppg_drain_scale", 0.10)), 0.0, 1.0)
	_decay_rate = clamp(float(config.get("ppg_decay_rate", 0.02)), 0.0, 1.0)
	_coupling_strength = clamp(float(config.get("ppg_coupling_strength", 0.20)), 0.0, 2.0)
	_step_count = 0
	_pump_rates = PackedFloat64Array()
	_pump_rates.resize(DIM)
	_pump_rates.fill(0.0)
	_drain_rates = PackedFloat64Array()
	_drain_rates.resize(DIM)
	_drain_rates.fill(0.0)
	_qc = QuantumComputer.new("_ppg")
	_qc.allocate_qubit("_pp0_n", "_pp0_s")
	_qc.allocate_qubit("_pp1_n", "_pp1_s")
	_qc.allocate_qubit("_pp2_n", "_pp2_s")
	_init_maximally_mixed()


# ════════════════════════════════════════════════════════════════════
#  PUBLIC API
# ════════════════════════════════════════════════════════════════════

func resolve_graph(raw_graph: Dictionary) -> Dictionary:
	"""Return a deep copy of raw_graph with learned multipliers applied.

	For each parameter slot i, computes:
	  multiplier = clamp(ρ_ii × DIM, MULTIPLIER_MIN, MULTIPLIER_MAX)
	then multiplies the corresponding leaf value in the policy graph dict.

	At uniform ρ (1/DIM per slot), multiplier = 1.0 → no change.
	"""
	if not (_qc and _qc.density_matrix):
		return raw_graph
	var effective = raw_graph.duplicate(true)
	for slot in range(DIM):
		var rho_ii = _qc.density_matrix.get_diagonal_real(slot)
		var multiplier = clamp(rho_ii * float(DIM), MULTIPLIER_MIN, MULTIPLIER_MAX)
		if abs(multiplier - 1.0) < 0.005:
			continue  # near-identity: skip unnecessary dict traversal
		_apply_multiplier_at_path(effective, PARAM_PATHS[slot], multiplier)
	return effective


func observe_outcome(action_name: String, reward_components: Dictionary) -> void:
	"""Route action outcome signals to parameter slots, then evolve ρ.

	Signal routing:
	  quest_cycle → slots 0 (milk_gain), 6 (unknown_vocab), 1 (frontier if milk_bonus)
	  probe_cycle → slot 2 (probe_base)
	  lindblad_drain → slot 3 (drain_base), weakly slot 4 (skip_base)
	  time_skip → slot 4 (skip_base), weakly slot 3 (drain_base)
	  lock_offer → slot 5 (lock_milk_gain)
	  discover_biome → slot 7 (discover_base), weakly slot 1 (quest_frontier)
	"""
	var reward = float(reward_components.get("reward", 0.0))
	var delta_pairs = float(reward_components.get("delta_pairs", 0.0))
	var milk_bonus = float(reward_components.get("milk_bonus", 0.0))

	# Decay all rates
	var decay_factor = exp(-_decay_rate)
	for i in range(DIM):
		_pump_rates[i] *= decay_factor
		_drain_rates[i] *= decay_factor

	# Build signal dict: slot → signed magnitude
	var signals: Dictionary = {}
	match action_name:
		"quest_cycle":
			if delta_pairs > 0.0:
				signals[0] = reward * 0.7   # quest_milk_gain: quests are finding vocab
				signals[6] = reward * 0.8   # unknown_vocab: vocab-chasing is working
				if milk_bonus > 0.0:
					signals[1] = reward * 0.6  # frontier: milk-proximal ↔ new-biome synergy
			else:
				signals[0] = -abs(reward) * 0.4  # quest isn't finding milk-proximal vocab
				signals[6] = -abs(reward) * 0.5  # vocab-chasing stagnating
		"probe_cycle":
			signals[2] = reward
		"lindblad_drain":
			signals[3] = reward
			if reward > 0.0:
				signals[4] = reward * 0.3  # skip+drain synergy: drain works → skip worth it
		"time_skip":
			signals[4] = reward
			if reward > 0.0:
				signals[3] = reward * 0.3  # drain still running → drain base worthwhile
		"lock_offer":
			if milk_bonus > 0.0 or reward > 0.0:
				signals[5] = reward
			else:
				signals[5] = -abs(reward) * 0.3
		"discover_biome":
			signals[7] = reward
			if reward > 0.0:
				signals[1] = reward * 0.4  # discovery → frontier quests become useful

	# Apply signals to pump/drain rates
	for slot in signals.keys():
		var sig = float(signals[slot])
		if sig > 0.0:
			_pump_rates[slot] += sig * _pump_scale
		elif sig < 0.0:
			_drain_rates[slot] += abs(sig) * _drain_scale

	# Evolve ρ one slow step (meta-learning: dt=1.0, 1 substep)
	_qc.set_hamiltonian(_build_hamiltonian())
	_qc.set_lindblad_operators(_build_lindblad_operators())
	_qc.evolve(1.0, 1.0)
	_step_count += 1


func get_snapshot() -> Dictionary:
	var probs: Array = []
	var multipliers: Array = []
	if _qc and _qc.density_matrix:
		for i in range(DIM):
			var rho_ii = _qc.density_matrix.get_diagonal_real(i)
			probs.append(rho_ii)
			multipliers.append(clamp(rho_ii * float(DIM), MULTIPLIER_MIN, MULTIPLIER_MAX))
	return {
		"step_count": _step_count,
		"param_labels": PARAM_LABELS.duplicate(),
		"param_probs": probs,
		"multipliers": multipliers,
		"pump_rates": Array(_pump_rates),
		"drain_rates": Array(_drain_rates),
	}


func export_state() -> Dictionary:
	var packed = _qc.density_matrix._to_packed() if (_qc and _qc.density_matrix) else PackedFloat64Array()
	return {
		"version": 1,
		"step_count": _step_count,
		"density_matrix_packed": Array(packed),
		"pump_rates": Array(_pump_rates),
		"drain_rates": Array(_drain_rates),
		"pump_scale": _pump_scale,
		"drain_scale": _drain_scale,
		"decay_rate": _decay_rate,
		"coupling_strength": _coupling_strength,
	}


func load_state(state: Dictionary) -> void:
	if not (state is Dictionary) or state.is_empty():
		return
	_step_count = max(0, int(state.get("step_count", 0)))
	_pump_scale = clamp(float(state.get("pump_scale", _pump_scale)), 0.0, 1.0)
	_drain_scale = clamp(float(state.get("drain_scale", _drain_scale)), 0.0, 1.0)
	_decay_rate = clamp(float(state.get("decay_rate", _decay_rate)), 0.0, 1.0)
	_coupling_strength = clamp(float(state.get("coupling_strength", _coupling_strength)), 0.0, 2.0)

	_pump_rates.resize(DIM)
	_pump_rates.fill(0.0)
	_drain_rates.resize(DIM)
	_drain_rates.fill(0.0)
	var raw_pump = state.get("pump_rates", [])
	if raw_pump is Array:
		for i in range(min(DIM, raw_pump.size())):
			_pump_rates[i] = float(raw_pump[i])
	var raw_drain = state.get("drain_rates", [])
	if raw_drain is Array:
		for i in range(min(DIM, raw_drain.size())):
			_drain_rates[i] = float(raw_drain[i])

	if not _qc:
		_qc = QuantumComputer.new("_ppg")
		_qc.allocate_qubit("_pp0_n", "_pp0_s")
		_qc.allocate_qubit("_pp1_n", "_pp1_s")
		_qc.allocate_qubit("_pp2_n", "_pp2_s")

	var raw_packed = state.get("density_matrix_packed", [])
	if raw_packed is Array and raw_packed.size() == DIM * DIM * 2:
		var packed = PackedFloat64Array()
		packed.resize(raw_packed.size())
		for i in range(raw_packed.size()):
			packed[i] = float(raw_packed[i])
		_qc.load_packed_state(packed, DIM)
	else:
		_init_maximally_mixed()


# ════════════════════════════════════════════════════════════════════
#  QUANTUM MECHANICS
# ════════════════════════════════════════════════════════════════════

func _init_maximally_mixed() -> void:
	"""Set ρ = I/8 (maximally mixed — 'we know nothing about which params work')."""
	var packed = PackedFloat64Array()
	packed.resize(DIM * DIM * 2)
	packed.fill(0.0)
	var val = 1.0 / float(DIM)
	for i in range(DIM):
		packed[(i * DIM + i) * 2] = val  # real part of diagonal element (i,i)
	_qc.load_packed_state(packed, DIM, true)


func _build_hamiltonian() -> ComplexMatrix:
	"""Static coupling Hamiltonian encoding parameter group correlations.

	Diagonal: small uniform self-energies (let Lindblad rewards dominate).
	Off-diagonal: cluster couplings from H_COUPLINGS, scaled by _coupling_strength.
	"""
	var H = ComplexMatrix.zeros(DIM)
	for i in range(DIM):
		H.set_element(i, i, Complex.new(0.1, 0.0))
	var cs_scale = _coupling_strength / 0.12
	for coupling in H_COUPLINGS:
		var i = int(coupling[0])
		var j = int(coupling[1])
		var strength = float(coupling[2]) * cs_scale
		H.set_element(i, j, Complex.new(strength, 0.0))
		H.set_element(j, i, Complex.new(strength, 0.0))
	return H


func _build_lindblad_operators() -> Array:
	"""Jump operators from accumulated pump/drain rates.

	Pump slot i:  L = √(γ/(N-1)) |i⟩⟨j| for j≠i  (pull population INTO i)
	Drain slot i: L = √(γ/(N-1)) |j⟩⟨i| for j≠i  (push population OUT of i)
	"""
	var ops: Array = []
	var scale_factor = 1.0 / float(DIM - 1)
	for i in range(DIM):
		var pump_rate = _pump_rates[i]
		if pump_rate > 0.001:
			var gamma = sqrt(pump_rate * scale_factor)
			for j in range(DIM):
				if j != i:
					var L = ComplexMatrix.zeros(DIM)
					L.set_element(i, j, Complex.new(gamma, 0.0))
					ops.append(L)
		var drain_rate = _drain_rates[i]
		if drain_rate > 0.001:
			var gamma = sqrt(drain_rate * scale_factor)
			for j in range(DIM):
				if j != i:
					var L = ComplexMatrix.zeros(DIM)
					L.set_element(j, i, Complex.new(gamma, 0.0))
					ops.append(L)
	return ops


# ── Graph path traversal ────────────────────────────────────────────

func _apply_multiplier_at_path(graph: Dictionary, path: String, multiplier: float) -> void:
	"""Navigate dotted path in graph and multiply the leaf scalar.

	If any segment of the path is missing, returns silently (no change).
	Dictionary values are reference types in GDScript 4, so modifications
	to nested dicts propagate back through the traversal chain.
	"""
	var parts = path.split(".")
	var node: Variant = graph
	for p_idx in range(parts.size() - 1):
		if not (node is Dictionary) or not node.has(parts[p_idx]):
			return
		node = node[parts[p_idx]]
	if not (node is Dictionary):
		return
	var leaf = parts[-1]
	if not node.has(leaf):
		return
	node[leaf] = float(node[leaf]) * multiplier
