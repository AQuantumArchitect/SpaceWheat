class_name ParametricPolicyGraph
extends RefCounted

## ParametricPolicyGraph
## ---------------------
## Quantum meta-learner over policy, economy, and scoring parameters.
##
## 4 qubits -> 16 basis states, each representing one tunable scalar.
## Slots 0-7:  action priors (how eagerly each action fires)
## Slots 8-10: biome economics (how strongly biome locality affects quests)
## Slots 11-12: quest scoring (novelty vs milk exploitation balance)
## Slots 13-14: signal routing (how strongly outcomes reinforce the PPG itself)
## Slot 15: entropy strength (meta-meta: exploration vs exploitation rate)
##
## rho starts maximally mixed (I/16): all parameters at JSONL defaults.
## Lindblad feedback from action outcomes pumps/drains parameter slots.
## Hamiltonian couplings encode parameter group correlations.
##
## resolve_graph(raw_graph) applies learned multipliers:
##   effective_value = jsonl_value * clamp(rho_ii * DIM, multiplier_min, multiplier_max)
##
## At uniform rho (1/DIM per slot): multiplier = 1.0 -> exact JSONL values.
## Entropy regularization prevents collapse to a single-strategy attractor.

const DIM := 16
const NUM_QUBITS := 4
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")

## Parameter slot registry: basis state |i> <-> dotted policy graph path.
const PARAM_PATHS: Array[String] = [
	# ── Action priors (slots 0-7) ──
	"action_priors.quest_cycle.milk_distance_gain",  # 0
	"action_priors.quest_cycle.frontier_bonus",       # 1
	"action_priors.probe_cycle.base",                 # 2
	"action_priors.lindblad_drain.base",              # 3
	"action_priors.time_skip.base",                   # 4
	"action_priors.lock_offer.milk_distance_gain",    # 5
	"action_priors.quest_cycle.unknown_vocab",        # 6
	"action_priors.discover_biome.base",              # 7
	# ── Biome economics (slots 8-10) ──
	"biome_economics.south_pole_affinity",            # 8
	"biome_economics.native_faction_score_bonus",     # 9
	"biome_economics.non_native_resonance_factor",    # 10
	# ── Quest scoring (slots 11-12) ──
	"quest_scoring.novelty_weight",                   # 11
	"quest_scoring.milk_score",                       # 12
	# ── Signal routing (slots 13-14) ──
	"ppg.signal_milk_progress",                       # 13
	"ppg.signal_biome_discover",                      # 14
	# ── Meta-meta (slot 15) ──
	"ppg.entropy_strength",                           # 15
]

const PARAM_LABELS: Array[String] = [
	"quest_milk_gain",       # 0
	"quest_frontier",        # 1
	"probe_base",            # 2
	"drain_base",            # 3
	"skip_base",             # 4
	"lock_milk_gain",        # 5
	"quest_unknown_vocab",   # 6
	"discover_base",         # 7
	"south_pole_affinity",   # 8
	"native_faction_bonus",  # 9
	"non_native_resonance",  # 10
	"novelty_weight",        # 11
	"milk_score",            # 12
	"signal_milk_progress",  # 13
	"signal_biome_discover", # 14
	"entropy_strength",      # 15
]

## Hamiltonian couplings: [slot_i, slot_j, base_strength]
## Off-diagonal H elements encode which parameters naturally co-evolve.
const H_COUPLINGS: Array = [
	# ── Original action prior clusters ──
	[0, 5, 0.15],   # quest_milk_gain <-> lock_milk_gain  (milk-navigation)
	[1, 6, 0.12],   # quest_frontier  <-> unknown_vocab    (exploration)
	[2, 3, 0.10],   # probe_base      <-> drain_base        (resource-mgmt)
	[3, 4, 0.10],   # drain_base      <-> skip_base         (time-mgmt)
	[6, 7, 0.08],   # unknown_vocab   <-> discover_base     (vocab expansion)
	# ── Biome economics cluster ──
	[8, 9, 0.12],   # south_pole_affinity <-> native_faction_bonus (locality)
	[9, 10, 0.10],  # native_bonus <-> non_native_resonance (complementary)
	# ── Cross-cluster bridges ──
	[7, 9, 0.10],   # discover_base <-> native_faction_bonus (discovery rewards locality)
	[7, 14, 0.12],  # discover_base <-> signal_biome_discover (discovery reinforces)
	[0, 13, 0.15],  # quest_milk_gain <-> signal_milk_progress (milk-seeking reinforces)
	[6, 11, 0.10],  # unknown_vocab <-> novelty_weight (vocab-chasing + novelty scoring)
	[11, 12, 0.08], # novelty_weight <-> milk_score (exploration vs exploitation)
	# ── Meta: entropy connects to exploration ──
	[15, 11, 0.06], # entropy <-> novelty (more exploration = more entropy)
	[15, 7, 0.06],  # entropy <-> discover (more exploration = more entropy)
]

const MULTIPLIER_MIN_DEFAULT := 0.5
const MULTIPLIER_MAX_DEFAULT := 3.0

# ── Internal quantum state ──────────────────────────────────────────
var _qc: QuantumComputer
var _pump_rates: PackedFloat64Array
var _drain_rates: PackedFloat64Array

# ── Tunable (all readable from policy graph ppg.* section) ──
var _pump_scale: float = 0.15
var _drain_scale: float = 0.10
var _decay_rate: float = 0.02
var _coupling_strength: float = 0.20
var _multiplier_min: float = MULTIPLIER_MIN_DEFAULT
var _multiplier_max: float = MULTIPLIER_MAX_DEFAULT
var _entropy_strength: float = 0.005
var _ppg_cfg: Dictionary = {}

var _step_count: int = 0
var _stagnation_counter: int = 0  # steps since last milk progress


func _init() -> void:
	reset({})


func reset(config: Dictionary = {}) -> void:
	"""Initialize to maximally mixed state. Reads ppg.* keys from config graph."""
	var ppg_cfg = config.get("ppg", {})
	if not (ppg_cfg is Dictionary):
		ppg_cfg = {}
	_pump_scale = clamp(float(ppg_cfg.get("pump_scale", config.get("ppg_pump_scale", 0.15))), 0.0, 1.0)
	_drain_scale = clamp(float(ppg_cfg.get("drain_scale", config.get("ppg_drain_scale", 0.10))), 0.0, 1.0)
	_decay_rate = clamp(float(ppg_cfg.get("decay_rate", config.get("ppg_decay_rate", 0.02))), 0.0, 1.0)
	_coupling_strength = clamp(float(ppg_cfg.get("coupling_strength", config.get("ppg_coupling_strength", 0.20))), 0.0, 2.0)
	_multiplier_min = float(ppg_cfg.get("multiplier_min", MULTIPLIER_MIN_DEFAULT))
	_multiplier_max = float(ppg_cfg.get("multiplier_max", MULTIPLIER_MAX_DEFAULT))
	_entropy_strength = float(ppg_cfg.get("entropy_strength", 0.005))
	_ppg_cfg = ppg_cfg
	_step_count = 0
	_stagnation_counter = 0
	_pump_rates = PackedFloat64Array()
	_pump_rates.resize(DIM)
	_pump_rates.fill(0.0)
	_drain_rates = PackedFloat64Array()
	_drain_rates.resize(DIM)
	_drain_rates.fill(0.0)
	_qc = QuantumComputer.new("_ppg")
	for i in range(NUM_QUBITS):
		_qc.allocate_qubit("_pp%d_n" % i, "_pp%d_s" % i)
	_init_maximally_mixed()


# ════════════════════════════════════════════════════════════════════
#  PUBLIC API
# ════════════════════════════════════════════════════════════════════

func resolve_graph(raw_graph: Dictionary) -> Dictionary:
	"""Return a deep copy of raw_graph with learned multipliers applied.

	For each parameter slot i, computes:
	  multiplier = clamp(rho_ii * DIM, multiplier_min, multiplier_max)
	then multiplies the corresponding leaf value in the policy graph dict.

	At uniform rho (1/DIM per slot), multiplier = 1.0 -> no change.
	"""
	if not (_qc and _qc.density_matrix):
		return raw_graph
	var effective = raw_graph.duplicate(true)
	for slot in range(DIM):
		var rho_ii = _qc.density_matrix.get_diagonal_real(slot)
		var multiplier = clamp(rho_ii * float(DIM), _multiplier_min, _multiplier_max)
		if abs(multiplier - 1.0) < 0.005:
			continue
		_apply_multiplier_at_path(effective, PARAM_PATHS[slot], multiplier)
	return effective


func observe_outcome(action_name: String, reward_components: Dictionary) -> void:
	"""Route action outcome signals to parameter slots, then evolve rho.

	Signal routing uses full reward_components from PolicyStateProjector:
	  - delta_milk_distance: BFS hops gained toward milk (positive = closer)
	  - delta_pairs: vocab pairs learned this step
	  - delta_biomes: new biomes discovered
	  - milk_bonus: one-time milk discovery bonus
	  - reward: aggregate reward scalar
	"""
	var reward = float(reward_components.get("reward", 0.0))
	var delta_pairs = float(reward_components.get("delta_pairs", 0.0))
	var milk_bonus = float(reward_components.get("milk_bonus", 0.0))
	var delta_milk = float(reward_components.get("delta_milk_distance", 0.0))
	var delta_biomes = float(reward_components.get("delta_biomes", 0.0))

	# Track stagnation for entropy meta-learning
	if delta_milk > 0.0 or milk_bonus > 0.0:
		_stagnation_counter = 0
	else:
		_stagnation_counter += 1

	# Decay all rates
	var decay_factor = exp(-_decay_rate)
	for i in range(DIM):
		_pump_rates[i] *= decay_factor
		_drain_rates[i] *= decay_factor

	# Build signal dict: slot -> signed magnitude
	var signals: Dictionary = {}

	# Read configurable signal weights (slots 13-14 learn these via resolve_graph)
	var sig_milk = float(_ppg_cfg.get("signal_milk_progress", 15.0))
	var sig_milk_lock = float(_ppg_cfg.get("signal_milk_lock", 10.0))
	var sig_biome_disc = float(_ppg_cfg.get("signal_biome_discover", 25.0))
	var sig_biome_front = float(_ppg_cfg.get("signal_biome_frontier", 15.0))

	# ── Action-specific signals (slots 0-7) ─────────────────────────
	match action_name:
		"quest_cycle":
			if delta_pairs > 0.0:
				signals[6] = reward * 0.6
				if delta_milk > 0.0:
					signals[0] = delta_milk * 20.0
				else:
					signals[0] = reward * 0.3
				# Biome-native questing worked: pump locality slots
				signals[8] = delta_pairs * 3.0
				signals[9] = delta_pairs * 2.0
			else:
				signals[0] = -abs(reward) * 0.3
				signals[6] = -abs(reward) * 0.4
				# Quest didn't find vocab: drain locality (maybe try other factions)
				signals[8] = -abs(reward) * 0.2
		"probe_cycle":
			signals[2] = reward
		"lindblad_drain":
			signals[3] = reward
			if reward > 0.0:
				signals[4] = reward * 0.3
		"time_skip":
			signals[4] = reward
			if reward > 0.0:
				signals[3] = reward * 0.3
		"lock_offer":
			if milk_bonus > 0.0 or reward > 0.0:
				signals[5] = reward
			else:
				signals[5] = -abs(reward) * 0.3
		"discover_biome":
			signals[7] = reward
			if reward > 0.0:
				signals[1] = reward * 0.4
				# Discovery succeeded: pump biome economics cluster
				signals[9] = reward * 0.5
				signals[10] = -reward * 0.3  # discovered = less need to penalize non-native

	# ── Cross-cutting signals (fire regardless of action) ────────────

	# Milk progress: pumps milk-navigation and scoring clusters
	if delta_milk > 0.0:
		signals[0] = signals.get(0, 0.0) + delta_milk * sig_milk
		signals[5] = signals.get(5, 0.0) + delta_milk * sig_milk_lock
		signals[12] = signals.get(12, 0.0) + delta_milk * 8.0   # milk_score: milk approach validates pursuit
		signals[13] = signals.get(13, 0.0) + delta_milk * 5.0   # signal_milk_progress: self-reinforcing

	# Biome discovery: pumps exploration and biome economics
	if delta_biomes > 0.0:
		signals[7] = signals.get(7, 0.0) + delta_biomes * sig_biome_disc
		signals[1] = signals.get(1, 0.0) + delta_biomes * sig_biome_front
		signals[14] = signals.get(14, 0.0) + delta_biomes * 5.0  # signal_biome_discover: self-reinforcing
		signals[8] = signals.get(8, 0.0) + delta_biomes * 4.0    # new biome = new locality to exploit
		signals[9] = signals.get(9, 0.0) + delta_biomes * 4.0

	# Milk bonus (found milk!): pump the whole winning strategy
	if milk_bonus > 0.0:
		signals[0] = signals.get(0, 0.0) + 30.0
		signals[1] = signals.get(1, 0.0) + 15.0
		signals[5] = signals.get(5, 0.0) + 20.0
		signals[6] = signals.get(6, 0.0) + 25.0
		signals[12] = signals.get(12, 0.0) + 20.0  # milk_score worked
		# Drain entropy on success (converge toward working strategy)
		signals[15] = signals.get(15, 0.0) - 10.0

	# Novelty signal: high-novelty quests that yield pairs pump slot 11
	if delta_pairs > 0.0 and action_name == "quest_cycle":
		signals[11] = signals.get(11, 0.0) + delta_pairs * 6.0

	# Stagnation -> pump entropy (try something different)
	if _stagnation_counter > 8:
		signals[15] = signals.get(15, 0.0) + float(_stagnation_counter - 8) * 0.5

	# Apply signals to pump/drain rates
	for slot in signals.keys():
		var sig = float(signals[slot])
		if sig > 0.0:
			_pump_rates[slot] += sig * _pump_scale
		elif sig < 0.0:
			_drain_rates[slot] += abs(sig) * _drain_scale

	# Evolve rho one slow step
	_qc.set_hamiltonian(_build_hamiltonian())
	_qc.set_lindblad_operators(_build_lindblad_operators())
	_qc.evolve(1.0, 1.0)

	# Entropy regularization (strength itself is learnable via slot 15!)
	if _entropy_strength > 0.0:
		_entropy_regularize(_entropy_strength)
	_step_count += 1


func _entropy_regularize(strength: float) -> void:
	"""Blend rho toward I/DIM by `strength` fraction."""
	if not (_qc and _qc.density_matrix):
		return
	var dm = _qc.density_matrix
	var uniform_diag = 1.0 / float(DIM)
	for i in range(DIM):
		for j in range(DIM):
			var old_re = dm.get_element(i, j).re
			var old_im = dm.get_element(i, j).im
			var target_re = uniform_diag if i == j else 0.0
			dm.set_element(i, j, Complex.new(
				old_re * (1.0 - strength) + target_re * strength,
				old_im * (1.0 - strength)
			))


func get_snapshot() -> Dictionary:
	var probs: Array = []
	var multipliers: Array = []
	if _qc and _qc.density_matrix:
		for i in range(DIM):
			var rho_ii = _qc.density_matrix.get_diagonal_real(i)
			probs.append(rho_ii)
			multipliers.append(clamp(rho_ii * float(DIM), _multiplier_min, _multiplier_max))
	return {
		"step_count": _step_count,
		"stagnation_counter": _stagnation_counter,
		"param_labels": PARAM_LABELS.duplicate(),
		"param_probs": probs,
		"multipliers": multipliers,
		"pump_rates": Array(_pump_rates),
		"drain_rates": Array(_drain_rates),
	}


func export_state() -> Dictionary:
	var packed = _qc.density_matrix._to_packed() if (_qc and _qc.density_matrix) else PackedFloat64Array()
	return {
		"version": 2,
		"num_qubits": NUM_QUBITS,
		"step_count": _step_count,
		"stagnation_counter": _stagnation_counter,
		"density_matrix_packed": Array(packed),
		"pump_rates": Array(_pump_rates),
		"drain_rates": Array(_drain_rates),
		"pump_scale": _pump_scale,
		"drain_scale": _drain_scale,
		"decay_rate": _decay_rate,
		"coupling_strength": _coupling_strength,
		"multiplier_min": _multiplier_min,
		"multiplier_max": _multiplier_max,
		"entropy_strength": _entropy_strength,
	}


func load_state(state: Dictionary) -> void:
	if not (state is Dictionary) or state.is_empty():
		return

	# Version check: v1 was 3-qubit (8 slots), v2 is 4-qubit (16 slots)
	var saved_version = int(state.get("version", 1))
	var saved_dim = int(pow(2, int(state.get("num_qubits", 3))))

	_step_count = max(0, int(state.get("step_count", 0)))
	_stagnation_counter = max(0, int(state.get("stagnation_counter", 0)))
	_pump_scale = clamp(float(state.get("pump_scale", _pump_scale)), 0.0, 1.0)
	_drain_scale = clamp(float(state.get("drain_scale", _drain_scale)), 0.0, 1.0)
	_decay_rate = clamp(float(state.get("decay_rate", _decay_rate)), 0.0, 1.0)
	_coupling_strength = clamp(float(state.get("coupling_strength", _coupling_strength)), 0.0, 2.0)
	_multiplier_min = float(state.get("multiplier_min", _multiplier_min))
	_multiplier_max = float(state.get("multiplier_max", _multiplier_max))
	_entropy_strength = float(state.get("entropy_strength", _entropy_strength))

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
		for i in range(NUM_QUBITS):
			_qc.allocate_qubit("_pp%d_n" % i, "_pp%d_s" % i)

	var raw_packed = state.get("density_matrix_packed", [])
	if raw_packed is Array and raw_packed.size() == DIM * DIM * 2:
		# Same dimension: load directly
		var packed = PackedFloat64Array()
		packed.resize(raw_packed.size())
		for i in range(raw_packed.size()):
			packed[i] = float(raw_packed[i])
		_qc.load_packed_state(packed, DIM)
	elif raw_packed is Array and saved_dim < DIM and raw_packed.size() == saved_dim * saved_dim * 2:
		# Migration: embed old smaller rho into top-left of new larger rho.
		# New slots (8-15) start maximally mixed (uniform within their subspace).
		_migrate_density_matrix(raw_packed, saved_dim)
	else:
		_init_maximally_mixed()


# ════════════════════════════════════════════════════════════════════
#  QUANTUM MECHANICS
# ════════════════════════════════════════════════════════════════════

func _init_maximally_mixed() -> void:
	"""Set rho = I/DIM (maximally mixed)."""
	var packed = PackedFloat64Array()
	packed.resize(DIM * DIM * 2)
	packed.fill(0.0)
	var val = 1.0 / float(DIM)
	for i in range(DIM):
		packed[(i * DIM + i) * 2] = val
	_qc.load_packed_state(packed, DIM, true)


func _migrate_density_matrix(old_packed: Array, old_dim: int) -> void:
	"""Embed old_dim x old_dim rho into DIM x DIM rho.

	Old slots keep their learned probabilities (rescaled to DIM).
	New slots get uniform 1/DIM each.
	Total trace = 1.0 is preserved.
	"""
	var packed = PackedFloat64Array()
	packed.resize(DIM * DIM * 2)
	packed.fill(0.0)

	# Compute how much probability the old slots occupy
	var old_trace = 0.0
	for i in range(old_dim):
		old_trace += float(old_packed[(i * old_dim + i) * 2])

	# New slots share the remaining probability uniformly
	var new_slot_count = DIM - old_dim
	var new_slot_prob = (1.0 - old_trace) / float(new_slot_count) if new_slot_count > 0 else 0.0
	if new_slot_prob < 0.0:
		# Old trace > 1 due to numerical drift; normalize
		new_slot_prob = 1.0 / float(DIM)

	# Copy old block (re/im interleaved)
	for i in range(old_dim):
		for j in range(old_dim):
			var old_idx = (i * old_dim + j) * 2
			var new_idx = (i * DIM + j) * 2
			packed[new_idx] = float(old_packed[old_idx])       # re
			packed[new_idx + 1] = float(old_packed[old_idx + 1]) # im

	# New diagonal slots get uniform probability
	for i in range(old_dim, DIM):
		packed[(i * DIM + i) * 2] = new_slot_prob

	_qc.load_packed_state(packed, DIM, true)


func _build_hamiltonian() -> ComplexMatrix:
	"""Static coupling Hamiltonian encoding parameter group correlations."""
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
	"""Jump operators from accumulated pump/drain rates."""
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
	"""Navigate dotted path in graph and multiply the leaf scalar."""
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
