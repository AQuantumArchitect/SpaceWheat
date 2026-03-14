class_name PolicyQuantumRegister
extends RefCounted

## PolicyQuantumRegister
## ---------------------
## Hunter AI as a quantum fiber: 3 qubits → 8 basis states → 8 actions.
## Hamiltonian encodes economy pressure (self-energies + couplings).
## Lindblad operators encode reward feedback (pump/drain rates).
## Decision = Born rule measurement on density matrix diagonal.
## Exploration/exploitation emerges from coherent rotation (H) vs
## incoherent dissipation (L).

const MILK_EMOJI := "🍼"
const PolicyGraph = preload("res://Core/AI/PolicyGraph.gd")
const PolicyStateProjector = preload("res://Core/AI/PolicyStateProjector.gd")
const ACTIONS: Array[String] = [
	"quest_cycle",        # |000⟩ = 0
	"probe_cycle",        # |001⟩ = 1
	"lindblad_drain",     # |010⟩ = 2
	"time_skip",          # |011⟩ = 3
	"discover_biome",     # |100⟩ = 4
	"victory_lap_partial",# |101⟩ = 5
	"lock_offer",         # |110⟩ = 6
	"channel_drain",      # |111⟩ = 7
]
const DIM := 8
const NUM_QUBITS := 3

# ── Internal quantum state ──────────────────────────────────────────
var _qc: QuantumComputer
var _pump_rates: PackedFloat64Array   # per-action reward pump strength
var _drain_rates: PackedFloat64Array  # per-action penalty drain strength
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# ── Tracking ────────────────────────────────────────────────────────
var _profile: String = "default"
var _step_count: int = 0
var _quest_no_vocab_streak: int = 0
var _last_decision: Dictionary = {}
var _last_reward: float = 0.0
var _last_reward_components: Dictionary = {}
var _history: Array = []
var _max_history: int = 160
var _policy_graph: Dictionary = {}

# ── Tunable config ──────────────────────────────────────────────────
var _coupling_strength: float = 0.15  # off-diagonal H scale
var _pump_scale: float = 0.08         # reward → pump rate
var _drain_scale: float = 0.05        # penalty → drain rate
var _decay_rate: float = 0.12         # Lindblad rate decay per step
var _collapse_strength: float = 0.3   # partial projection after decision
var _prior_injection: float = 0.8     # blend ρ diagonal with prior scores (0=none, 1=full replace)
var _evolution_steps: int = 1         # Lindblad evolution steps per decision (0 = skip)


func _init() -> void:
	_rng.randomize()
	reset({})


# ════════════════════════════════════════════════════════════════════
#  PUBLIC API  (same interface as QuantumFiberPolicy)
# ════════════════════════════════════════════════════════════════════

func reset(config: Dictionary = {}) -> Dictionary:
	_profile = str(config.get("profile", "default") or "default")
	_coupling_strength = clamp(float(config.get("coupling_strength", 0.15)), 0.0, 2.0)
	_pump_scale = clamp(float(config.get("pump_scale", 0.08)), 0.0, 1.0)
	_drain_scale = clamp(float(config.get("drain_scale", 0.05)), 0.0, 1.0)
	_decay_rate = clamp(float(config.get("decay_rate", 0.12)), 0.0, 1.0)
	_collapse_strength = clamp(float(config.get("collapse_strength", 0.3)), 0.0, 1.0)
	_prior_injection = clamp(float(config.get("prior_injection", 0.6)), 0.0, 1.0)
	_evolution_steps = clampi(int(config.get("evolution_steps", 5)), 1, 50)
	_max_history = max(16, int(config.get("max_history", 160)))
	_step_count = 0
	_quest_no_vocab_streak = 0
	_last_decision = {}
	_last_reward = 0.0
	_last_reward_components = {}
	_history.clear()

	_pump_rates = PackedFloat64Array()
	_pump_rates.resize(DIM)
	_pump_rates.fill(0.0)
	_drain_rates = PackedFloat64Array()
	_drain_rates.resize(DIM)
	_drain_rates.fill(0.0)

	# Build 3-qubit quantum computer with maximally mixed initial state (I/8)
	_qc = QuantumComputer.new("_policy_qr")
	_qc.allocate_qubit("_pq0_n", "_pq0_s")
	_qc.allocate_qubit("_pq1_n", "_pq1_s")
	_qc.allocate_qubit("_pq2_n", "_pq2_s")
	# Initialize to maximally mixed state: ρ = I/8
	_init_maximally_mixed()
	var graph_lines = config.get("policy_graph_jsonl", [])
	_policy_graph = PolicyGraph.load_resolved_graph("quantum_register", _profile, graph_lines)
	if config.get("policy_graph", null) is Dictionary:
		_policy_graph = PolicyGraph.apply_patch(_policy_graph, config.get("policy_graph", {}))
	return get_snapshot()


func decide(state: Dictionary) -> Dictionary:
	var candidates = _build_candidates(state)
	var available_mask = _build_availability_mask(candidates)
	var available_count = 0
	for i in range(DIM):
		if available_mask[i]:
			available_count += 1
	if available_count == 0:
		return {
			"ok": true,
			"mode": "fallback",
			"action": "time_skip",
			"params": {"phrames": 6},
			"score": 0.0,
			"rankings": [],
		}

	# 1. Build & set Hamiltonian from economy state
	var H = _build_hamiltonian(state, candidates)
	_qc.set_hamiltonian(H)

	# 2. Build & set Lindblad operators from accumulated pump/drain
	var L_ops = _build_lindblad_operators()
	_qc.set_lindblad_operators(L_ops)

	# 3. Evolve (Lindblad learning adjusts ρ based on reward history)
	if _evolution_steps > 0:
		var dt_step = 1.0
		_qc.evolve(float(_evolution_steps) * dt_step, dt_step)

	# 4. Prior injection AFTER evolution: blend ρ diagonal with economy priors.
	#    This is a partial preparation channel — ρ = (1-α)ρ + α·diag(π)
	#    where π_i = prior_i / Σ priors.  Applied AFTER evolution so the
	#    economy signal isn't destroyed by Hamiltonian rotation.  The evolution
	#    adjusts the 30% retained from the previous cycle; the prior injection
	#    grounds 70% in current economy reality.
	if _prior_injection > 0.001:
		var prior_scores = PackedFloat64Array()
		prior_scores.resize(DIM)
		prior_scores.fill(0.0)
		var prior_sum = 0.0
		for candidate in candidates:
			if candidate is Dictionary:
				var action_name = str(candidate.get("action", ""))
				var idx = ACTIONS.find(action_name)
				if idx >= 0 and available_mask[idx]:
					var p = max(0.0, float(candidate.get("prior", 0.0)))
					# Learn-aware prior: modulate by accumulated pump/drain rates.
					var boost = 1.0 + _pump_rates[idx]
					var damp = 1.0 + _drain_rates[idx]
					p = p * boost / damp
					prior_scores[idx] = p
					prior_sum += p
		if prior_sum > 1e-12:
			_inject_prior_into_density_matrix(prior_scores, prior_sum, _prior_injection)

	# 5. Read diagonal probabilities
	var rho = _qc.density_matrix
	var probs = PackedFloat64Array()
	probs.resize(DIM)
	var prob_sum = 0.0
	for i in range(DIM):
		var p = max(0.0, rho.get_diagonal_real(i))
		if not available_mask[i]:
			p = 0.0
		probs[i] = p
		prob_sum += p

	# Renormalize
	if prob_sum < 1e-12:
		# Uniform over available
		for i in range(DIM):
			if available_mask[i]:
				probs[i] = 1.0 / float(available_count)
		prob_sum = 1.0
	else:
		for i in range(DIM):
			probs[i] /= prob_sum


	# 6. Born rule roulette
	var roll = _rng.randf()
	var cumulative = 0.0
	var selected_idx = 0
	for i in range(DIM):
		cumulative += probs[i]
		if roll <= cumulative:
			selected_idx = i
			break

	# 7. Partial collapse: ρ = (1-α)ρ + α|i⟩⟨i|
	if _collapse_strength > 0.001:
		_apply_partial_collapse(selected_idx)

	# 8. Determine mode from purity
	var purity = _compute_purity()
	var mode = "explore" if purity < 0.3 else "exploit"

	var selected_action = ACTIONS[selected_idx]
	var params = _get_params_for_action(selected_action, candidates)

	# Build rankings (all 8 probabilities)
	var rankings: Array = []
	for i in range(DIM):
		rankings.append({
			"action": ACTIONS[i],
			"score": probs[i],
			"available": available_mask[i],
		})
	rankings.sort_custom(func(a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))

	_last_decision = {
		"step": _step_count + 1,
		"mode": mode,
		"action": selected_action,
		"params": params,
		"score": probs[selected_idx],
		"purity": purity,
	}

	return {
		"ok": true,
		"mode": mode,
		"action": selected_action,
		"params": params,
		"score": probs[selected_idx],
		"rankings": rankings,
	}


func observe(pre_state: Dictionary, decision: Dictionary, post_state: Dictionary, execution: Dictionary) -> Dictionary:
	var action_name = str(decision.get("action", ""))
	var reward_components = _compute_reward_components(pre_state, post_state, execution)
	var reward = float(reward_components.get("reward", 0.0))

	# Stagnation tracking — updates streak counter for quest_pressure raw prior.
	# Unlike QuantumFiberPolicy, we do NOT add stagnation_penalty to the reward
	# signal because the learn-aware prior modulation would amplify it through
	# drain_rates, creating a feedback loop that kills quest priority.
	# Instead, stagnation only affects the raw prior in _quest_pressure().
	var delta_pairs = float(reward_components.get("delta_pairs", 0.0))
	if action_name == "quest_cycle":
		if delta_pairs <= 0.0:
			_quest_no_vocab_streak += 1
		else:
			_quest_no_vocab_streak = 0
	else:
		if delta_pairs > 0.0:
			_quest_no_vocab_streak = 0
	reward = clamp(reward, -120.0, 220.0)
	reward_components["quest_no_vocab_streak"] = _quest_no_vocab_streak

	_last_reward = reward
	_last_reward_components = reward_components.duplicate(true)
	_step_count += 1

	# Decay all pump/drain rates
	var decay_factor = exp(-_decay_rate)
	for i in range(DIM):
		_pump_rates[i] *= decay_factor
		_drain_rates[i] *= decay_factor

	# Apply reward signal to pump/drain rates
	var action_idx = ACTIONS.find(action_name)
	if action_idx >= 0:
		if reward > 0.0:
			_pump_rates[action_idx] += reward * _pump_scale
		elif reward < 0.0:
			_drain_rates[action_idx] += abs(reward) * _drain_scale

	# History
	var row = {
		"step": _step_count,
		"action": action_name,
		"reward": reward,
		"quest_no_vocab_streak": _quest_no_vocab_streak,
		"mode": str(decision.get("mode", "")),
		"exec_ok": bool(execution.get("ok", false)),
	}
	_history.append(row)
	if _history.size() > _max_history:
		_history = _history.slice(_history.size() - _max_history, _history.size())

	return {
		"ok": true,
		"step": _step_count,
		"action": action_name,
		"reward": reward,
		"reward_components": reward_components,
		"pump_rates": Array(_pump_rates),
		"drain_rates": Array(_drain_rates),
	}


func get_snapshot() -> Dictionary:
	var probs: Array = []
	var purity = 0.0
	var coherence = 0.0
	if _qc and _qc.density_matrix:
		var rho = _qc.density_matrix
		for i in range(DIM):
			probs.append(rho.get_diagonal_real(i))
		purity = _compute_purity()
		coherence = _compute_coherence()
	return {
		"policy_type": "quantum_register",
		"profile": _profile,
		"step_count": _step_count,
		"last_reward": _last_reward,
		"last_reward_components": _last_reward_components.duplicate(true),
		"quest_no_vocab_streak": _quest_no_vocab_streak,
		"last_decision": _last_decision.duplicate(true),
		"action_probabilities": probs,
		"purity": purity,
		"coherence": coherence,
		"pump_rates": Array(_pump_rates),
		"drain_rates": Array(_drain_rates),
		"coupling_strength": _coupling_strength,
		"collapse_strength": _collapse_strength,
		"history_tail": _history.duplicate(true),
		"policy_graph": _policy_graph.duplicate(true),
		"policy_graph_jsonl": PolicyGraph.snapshot_to_graph_lines(_policy_graph),
	}


func export_state() -> Dictionary:
	var packed = _qc.density_matrix._to_packed() if _qc and _qc.density_matrix else PackedFloat64Array()
	return {
		"version": 2,
		"policy_type": "quantum_register",
		"profile": _profile,
		"coupling_strength": _coupling_strength,
		"pump_scale": _pump_scale,
		"drain_scale": _drain_scale,
		"decay_rate": _decay_rate,
		"collapse_strength": _collapse_strength,
		"density_matrix_packed": Array(packed),
		"pump_rates": Array(_pump_rates),
		"drain_rates": Array(_drain_rates),
		"step_count": _step_count,
		"last_reward": _last_reward,
		"last_reward_components": _last_reward_components.duplicate(true),
		"quest_no_vocab_streak": _quest_no_vocab_streak,
		"last_decision": _last_decision.duplicate(true),
		"history_tail": _history.duplicate(true),
		"policy_graph": _policy_graph.duplicate(true),
		"policy_graph_jsonl": PolicyGraph.snapshot_to_graph_lines(_policy_graph),
	}


func load_state(state: Dictionary) -> Dictionary:
	if not (state is Dictionary) or state.is_empty():
		return get_snapshot()

	var policy_type = str(state.get("policy_type", ""))
	if policy_type != "quantum_register":
		# Mismatch (e.g. old UCB save) — fresh start
		reset({})
		return get_snapshot()

	_profile = str(state.get("profile", _profile))
	_coupling_strength = clamp(float(state.get("coupling_strength", _coupling_strength)), 0.0, 2.0)
	_pump_scale = clamp(float(state.get("pump_scale", _pump_scale)), 0.0, 1.0)
	_drain_scale = clamp(float(state.get("drain_scale", _drain_scale)), 0.0, 1.0)
	_decay_rate = clamp(float(state.get("decay_rate", _decay_rate)), 0.0, 1.0)
	_collapse_strength = clamp(float(state.get("collapse_strength", _collapse_strength)), 0.0, 1.0)
	_step_count = max(0, int(state.get("step_count", _step_count)))
	_last_reward = float(state.get("last_reward", _last_reward))
	var reward_components = state.get("last_reward_components", {})
	_last_reward_components = reward_components.duplicate(true) if reward_components is Dictionary else {}
	_quest_no_vocab_streak = max(0, int(state.get("quest_no_vocab_streak", 0)))

	var decision = state.get("last_decision", {})
	_last_decision = decision.duplicate(true) if decision is Dictionary else {}

	_history.clear()
	var raw_history = state.get("history_tail", [])
	if raw_history is Array:
		for row_entry in raw_history:
			if row_entry is Dictionary:
				_history.append(row_entry.duplicate(true))
	if _history.size() > _max_history:
		_history = _history.slice(_history.size() - _max_history, _history.size())

	# Restore pump/drain rates
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

	# Restore density matrix
	if not _qc:
		_qc = QuantumComputer.new("_policy_qr")
		_qc.allocate_qubit("_pq0_n", "_pq0_s")
		_qc.allocate_qubit("_pq1_n", "_pq1_s")
		_qc.allocate_qubit("_pq2_n", "_pq2_s")
	var raw_packed = state.get("density_matrix_packed", [])
	if raw_packed is Array and raw_packed.size() == DIM * DIM * 2:
		var packed = PackedFloat64Array()
		packed.resize(raw_packed.size())
		for i in range(raw_packed.size()):
			packed[i] = float(raw_packed[i])
		_qc.load_packed_state(packed, DIM)
	else:
		_init_maximally_mixed()
	var graph_lines = state.get("policy_graph_jsonl", [])
	_policy_graph = PolicyGraph.load_resolved_graph("quantum_register", _profile, graph_lines)
	var state_graph = state.get("policy_graph", {})
	if state_graph is Dictionary and not state_graph.is_empty():
		_policy_graph = PolicyGraph.apply_patch(_policy_graph, state_graph)

	return get_snapshot()


# ════════════════════════════════════════════════════════════════════
#  QUANTUM MECHANICS
# ════════════════════════════════════════════════════════════════════

func _init_maximally_mixed() -> void:
	"""Set ρ = I/8 (maximally mixed — 'we know nothing')."""
	var packed = PackedFloat64Array()
	packed.resize(DIM * DIM * 2)
	packed.fill(0.0)
	var val = 1.0 / float(DIM)
	for i in range(DIM):
		var idx = (i * DIM + i) * 2  # real part of diagonal element (i,i)
		packed[idx] = val
	_qc.load_packed_state(packed, DIM, true)


func _build_hamiltonian(state: Dictionary, candidates: Array) -> ComplexMatrix:
	"""Build 8×8 Hamiltonian from economy state.

	Diagonal: self-energies (prior scores from economy).
	Off-diagonal: couplings between related actions.
	"""
	var H = ComplexMatrix.zeros(DIM)

	# ── Diagonal self-energies ──────────────────────────────────────
	var self_energies = PackedFloat64Array()
	self_energies.resize(DIM)
	self_energies.fill(0.0)

	# Extract self-energies from candidates (which already computed priors)
	var candidate_priors: Dictionary = {}
	for candidate in candidates:
		if candidate is Dictionary:
			var action_name = str(candidate.get("action", ""))
			candidate_priors[action_name] = float(candidate.get("prior", 0.0))

	# Map action names to basis indices
	for i in range(DIM):
		self_energies[i] = float(candidate_priors.get(ACTIONS[i], 0.0))

	for i in range(DIM):
		H.set_element(i, i, Complex.new(self_energies[i], 0.0))

	# ── Off-diagonal couplings ──────────────────────────────────────
	var cs = _coupling_strength
	# quest(0) ↔ lock(6): both serve vocab discovery
	_set_hermitian_coupling(H, 0, 6, cs)
	# drain(2) ↔ skip(3): drain makes waiting productive
	_set_hermitian_coupling(H, 2, 3, cs * 0.8)
	# discover(4) ↔ quest(0): new biomes open new quests
	_set_hermitian_coupling(H, 4, 0, cs * 0.7)
	# quest(0) ↔ probe(1): quest costs need resources
	_set_hermitian_coupling(H, 0, 1, cs * 0.5)

	return H


func _set_hermitian_coupling(H: ComplexMatrix, i: int, j: int, strength: float) -> void:
	"""Set symmetric off-diagonal coupling H[i,j] = H[j,i] = strength."""
	H.set_element(i, j, Complex.new(strength, 0.0))
	H.set_element(j, i, Complex.new(strength, 0.0))


func _build_lindblad_operators() -> Array:
	"""Build jump operators from accumulated pump/drain rates.

	Pump: L = √(γ/(N-1)) |i⟩⟨j| for all j≠i (pulls population INTO i)
	Drain: L = √(γ/(N-1)) |j⟩⟨i| for all j≠i (pushes population OUT of i)
	"""
	var ops: Array = []
	var scale_factor = 1.0 / float(DIM - 1)

	for i in range(DIM):
		var pump_rate = _pump_rates[i]
		if pump_rate > 0.001:
			var gamma = sqrt(pump_rate * scale_factor)
			for j in range(DIM):
				if j == i:
					continue
				var L = ComplexMatrix.zeros(DIM)
				L.set_element(i, j, Complex.new(gamma, 0.0))
				ops.append(L)

		var drain_rate = _drain_rates[i]
		if drain_rate > 0.001:
			var gamma = sqrt(drain_rate * scale_factor)
			for j in range(DIM):
				if j == i:
					continue
				var L = ComplexMatrix.zeros(DIM)
				L.set_element(j, i, Complex.new(gamma, 0.0))
				ops.append(L)

	return ops


func _apply_partial_collapse(action_idx: int) -> void:
	"""Blend ρ toward |action⟩⟨action|: ρ = (1-α)ρ + α|i⟩⟨i|."""
	var alpha = _collapse_strength
	var rho = _qc.density_matrix
	if rho == null:
		return

	var packed = rho._to_packed()
	if packed.size() != DIM * DIM * 2:
		return

	# Scale existing ρ by (1 - α)
	var one_minus_alpha = 1.0 - alpha
	for k in range(packed.size()):
		packed[k] *= one_minus_alpha

	# Add α to diagonal element (action_idx, action_idx)
	var diag_idx = (action_idx * DIM + action_idx) * 2
	packed[diag_idx] += alpha

	_qc.load_packed_state(packed, DIM, false)


func _inject_prior_into_density_matrix(prior_scores: PackedFloat64Array, prior_sum: float, alpha: float) -> void:
	"""Partial preparation channel: ρ = (1-α)ρ + α·diag(π/Σπ).

	Blends current density matrix with economy-informed prior distribution.
	This grounds the quantum state in the current economy reality each cycle,
	while preserving Lindblad-learned correlations in the off-diagonal elements
	(scaled by 1-α).
	"""
	var rho = _qc.density_matrix
	if rho == null:
		return
	var packed = rho._to_packed()
	if packed.size() != DIM * DIM * 2:
		return

	var one_minus_alpha = 1.0 - alpha
	# Scale entire ρ by (1-α) — preserves off-diagonal coherences (dampened)
	for k in range(packed.size()):
		packed[k] *= one_minus_alpha

	# Add α·π_i to each diagonal element
	for i in range(DIM):
		var pi_i = prior_scores[i] / prior_sum
		var diag_idx = (i * DIM + i) * 2  # real part of (i,i)
		packed[diag_idx] += alpha * pi_i

	_qc.load_packed_state(packed, DIM, false)


func _compute_purity() -> float:
	"""Tr(ρ²) — 1/8 for maximally mixed, 1 for pure."""
	var rho = _qc.density_matrix
	if rho == null:
		return 0.125
	var rho_sq = rho.mul(rho)
	return rho_sq.trace().re


func _compute_coherence() -> float:
	"""Sum of |ρ_ij| for i≠j — measures off-diagonal magnitude."""
	var rho = _qc.density_matrix
	if rho == null:
		return 0.0
	var total = 0.0
	for i in range(DIM):
		for j in range(DIM):
			if i == j:
				continue
			var elem = rho.get_element(i, j)
			total += elem.abs()
	return total


# ════════════════════════════════════════════════════════════════════
#  CANDIDATE BUILDING (reused from QuantumFiberPolicy)
# ════════════════════════════════════════════════════════════════════

func _build_candidates(state: Dictionary) -> Array:
	var projected_state = state.duplicate(true)
	projected_state["quest_no_vocab_streak"] = _quest_no_vocab_streak
	return PolicyStateProjector.build_candidates(projected_state, _policy_graph, ACTIONS)


func _build_availability_mask(candidates: Array) -> Array:
	"""Return bool[8] — true if action appears in candidates."""
	var mask: Array = []
	mask.resize(DIM)
	mask.fill(false)
	var candidate_actions: Dictionary = {}
	for candidate in candidates:
		if candidate is Dictionary:
			candidate_actions[str(candidate.get("action", ""))] = true
	for i in range(DIM):
		mask[i] = candidate_actions.has(ACTIONS[i])
	return mask


func _get_params_for_action(action_name: String, candidates: Array) -> Dictionary:
	"""Extract params from the candidate matching this action."""
	for candidate in candidates:
		if candidate is Dictionary and str(candidate.get("action", "")) == action_name:
			var params = candidate.get("params", {})
			return params if params is Dictionary else {}
	# Fallback defaults
	match action_name:
		"time_skip":
			return {"phrames": 6}
		_:
			return {}


# ════════════════════════════════════════════════════════════════════
#  ECONOMY HELPERS (copied from QuantumFiberPolicy)
# ════════════════════════════════════════════════════════════════════

func _quest_pressure(resources: Dictionary, offers: Array, active_quests: Array, known_pairs: Array) -> float:
	return PolicyStateProjector.quest_pressure(resources, offers, active_quests, known_pairs, _policy_graph, _quest_no_vocab_streak)


func _resource_pressure(resources: Dictionary, floors: Dictionary) -> float:
	return PolicyStateProjector.resource_pressure(resources, floors)


func _choose_probe_biome(biomes: Array, lindblad: Dictionary, resources: Dictionary, floors: Dictionary) -> String:
	return PolicyStateProjector.choose_probe_biome(biomes, lindblad, resources, floors, _policy_graph)


func _choose_drain_biome(biomes: Array, lindblad: Dictionary, resources: Dictionary, floors: Dictionary) -> String:
	return PolicyStateProjector.choose_drain_biome(biomes, lindblad, resources, floors, _policy_graph)


func _choose_channel_drain_target(biomes: Array, lindblad: Dictionary, _resources: Dictionary) -> Dictionary:
	return PolicyStateProjector.choose_channel_drain_target(biomes, lindblad, _policy_graph)


func _biome_sink_flux(biome_data: Dictionary, biome_name: String) -> Dictionary:
	return PolicyStateProjector.biome_sink_flux(biome_data, biome_name)


func _active_drain_count(lindblad: Dictionary) -> int:
	return PolicyStateProjector.active_drain_count(lindblad)


func _suggest_wait_phrames(lindblad: Dictionary) -> int:
	return PolicyStateProjector.suggest_wait_phrames(lindblad, _policy_graph)


# ════════════════════════════════════════════════════════════════════
#  REWARD COMPUTATION (copied from QuantumFiberPolicy)
# ════════════════════════════════════════════════════════════════════

func _compute_reward_components(pre_state: Dictionary, post_state: Dictionary, execution: Dictionary) -> Dictionary:
	return PolicyStateProjector.compute_reward_components(pre_state, post_state, execution, _policy_graph)


func _sum_resources(resources: Dictionary) -> float:
	return PolicyStateProjector.sum_resources(resources)


# ════════════════════════════════════════════════════════════════════
#  DATA HELPERS (copied from QuantumFiberPolicy)
# ════════════════════════════════════════════════════════════════════

func _contains_milk_pair(pairs: Array) -> bool:
	return PolicyStateProjector.contains_milk_pair(pairs)


func _known_emoji_map(pairs: Array) -> Dictionary:
	return PolicyStateProjector.known_emoji_map(pairs)


func _best_lockable_offer(offers: Array, locked_offers: Array, active_quests: Array, known_pairs: Array) -> Dictionary:
	return PolicyStateProjector.best_lockable_offer(offers, locked_offers, active_quests, known_pairs)


func _discovery_forecast_bonus(forecast: Dictionary) -> float:
	return PolicyStateProjector.discovery_forecast_bonus(forecast)


func get_policy_graph() -> Dictionary:
	return _policy_graph.duplicate(true)


func apply_policy_graph_lines(lines: Array) -> Dictionary:
	var result = PolicyGraph.apply_graph_lines(_policy_graph, lines)
	if bool(result.get("ok", false)):
		_policy_graph = result.get("graph", _policy_graph)
	return {
		"ok": bool(result.get("ok", false)),
		"errors": result.get("errors", []),
		"policy_graph": _policy_graph.duplicate(true),
	}


func _as_pairs(raw) -> Array:
	var out: Array = []
	if not (raw is Array):
		return out
	for pair in raw:
		if not (pair is Dictionary):
			continue
		out.append({
			"north": str(pair.get("north", "")),
			"south": str(pair.get("south", "")),
		})
	return out


func _as_dict_array(raw) -> Array:
	var out: Array = []
	if not (raw is Array):
		return out
	for row in raw:
		if row is Dictionary:
			out.append(row)
	return out


func _as_string_array(raw) -> Array:
	var out: Array = []
	if not (raw is Array):
		return out
	for item in raw:
		var s = str(item)
		if s == "":
			continue
		out.append(s)
	return out


func _as_resource_map(raw) -> Dictionary:
	var out: Dictionary = {}
	if not (raw is Dictionary):
		return out
	for emoji in raw.keys():
		var key = str(emoji)
		if key == "":
			continue
		out[key] = float(raw.get(emoji, 0.0))
	return out
