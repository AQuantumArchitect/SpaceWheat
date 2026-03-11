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
	var candidates: Array = []
	var resources = _as_resource_map(state.get("resources", {}))
	var known_pairs = _as_pairs(state.get("known_pairs", []))
	var active_quests = _as_dict_array(state.get("active_quests", []))
	var offers = _as_dict_array(state.get("offers", []))
	var biomes = _as_string_array(state.get("biomes", []))
	var floors = _as_resource_map(state.get("resource_floors", {}))
	var lindblad = state.get("lindblad", {})
	if not (lindblad is Dictionary):
		lindblad = {}
	var forbid_actions: Dictionary = {}
	var forbid_raw = state.get("forbid_actions", [])
	if forbid_raw is Array:
		for action_name in forbid_raw:
			var key = str(action_name)
			if key != "":
				forbid_actions[key] = true

	if _contains_milk_pair(known_pairs):
		candidates.append({
			"action": "victory_lap_partial",
			"params": {"max_registers": 8, "milk_spend": 0, "phase_window": 1},
			"prior": 8.5,
			"tags": ["milk_known"],
		})

	var quest_pressure = _quest_pressure(resources, offers, active_quests, known_pairs)
	candidates.append({
		"action": "quest_cycle",
		"params": {},
		"prior": quest_pressure + 3.0,
		"tags": ["economy", "vocab"],
	})

	var probe_biome = _choose_probe_biome(biomes, lindblad, resources, floors)
	if probe_biome != "":
		candidates.append({
			"action": "probe_cycle",
			"params": {"biome": probe_biome},
			"prior": 0.5 + _resource_pressure(resources, floors) * 0.8,
			"tags": ["projection", probe_biome],
		})

	var drain_biome = _choose_drain_biome(biomes, lindblad, resources, floors)
	if drain_biome != "":
		var active_drain = int(_active_drain_count(lindblad))
		candidates.append({
			"action": "lindblad_drain",
			"params": {"biome": drain_biome},
			"prior": 0.4 + float(active_drain) * 0.15,
			"tags": ["passive_gain", drain_biome],
		})

	var forecast = state.get("discovery_forecast", {})
	if not (forecast is Dictionary):
		forecast = {}
	var locked_offers = _as_dict_array(state.get("locked_offers", []))

	var lock_result = _best_lockable_offer(offers, locked_offers, active_quests, known_pairs)
	if lock_result.has("offer_index"):
		candidates.append({
			"action": "lock_offer",
			"params": {"offer_index": lock_result.get("offer_index", 0)},
			"prior": 0.5 + float(lock_result.get("discovery_value", 0.0)) * 6.0 + float(lock_result.get("novelty", 0.0)) * 1.5,
			"tags": ["planning", "lock"],
		})

	var eagle_stock = float(resources.get("🦅", 0.0))
	if eagle_stock >= 8.0 and biomes.size() < 6:
		var forecast_bonus = _discovery_forecast_bonus(forecast)
		candidates.append({
			"action": "discover_biome",
			"params": {},
			"prior": 0.7 + min(2.0, eagle_stock / 16.0) + forecast_bonus,
			"tags": ["expansion"],
		})

	candidates.append({
		"action": "time_skip",
		"params": {"phrames": _suggest_wait_phrames(lindblad)},
		"prior": 0.4 + float(_active_drain_count(lindblad)) * 0.35,
		"tags": ["accumulate"],
	})

	# channel_drain: needs at least one biome with active drains and known emojis
	var channel_target = _choose_channel_drain_target(biomes, lindblad, resources)
	if not channel_target.is_empty():
		var active_drains = _active_drain_count(lindblad)
		candidates.append({
			"action": "channel_drain",
			"params": channel_target,
			"prior": 0.6 + float(active_drains) * 0.2,
			"tags": ["strategic_drain"],
		})

	if forbid_actions.is_empty():
		return candidates
	var filtered: Array = []
	for row in candidates:
		if not (row is Dictionary):
			continue
		var action_name = str(row.get("action", ""))
		if action_name != "" and forbid_actions.has(action_name):
			continue
		filtered.append(row)
	if filtered.is_empty():
		return candidates
	return filtered


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
	var affordable = 0
	for offer in offers:
		if not (offer is Dictionary):
			continue
		var resource = str(offer.get("resource", ""))
		var quantity = float(offer.get("quantity", 0.0))
		if resource != "" and quantity > 0.0 and float(resources.get(resource, 0.0)) >= quantity:
			affordable += 1
	var unknown_vocab_reward = 0
	var known = _known_emoji_map(known_pairs)
	for offer in offers:
		if not (offer is Dictionary):
			continue
		var n = str(offer.get("reward_vocab_north", ""))
		var s = str(offer.get("reward_vocab_south", ""))
		if n != "" and not known.has(n):
			unknown_vocab_reward += 1
		if s != "" and not known.has(s):
			unknown_vocab_reward += 1
	# Stagnation: when quests aren't producing vocab, reduce penalty gently.
	# Unlike UCB policy, we can't just "try something else" — quests are THE
	# primary vocab mechanism.  Cap stagnation drag at 1.5 (not 6.0).
	var stagnation_bias = min(1.5, float(_quest_no_vocab_streak) * 0.15)
	return 2.0 + float(active_quests.size()) * 0.3 + float(affordable) * 0.25 + float(unknown_vocab_reward) * 1.25 - stagnation_bias


func _resource_pressure(resources: Dictionary, floors: Dictionary) -> float:
	if floors.is_empty():
		return 0.0
	var p = 0.0
	for emoji in floors.keys():
		var floor = float(floors.get(emoji, 0.0))
		if floor <= 0.0:
			continue
		var have = float(resources.get(emoji, 0.0))
		if have < floor:
			p += (floor - have) / max(1.0, floor)
	return p


func _choose_probe_biome(biomes: Array, lindblad: Dictionary, resources: Dictionary, floors: Dictionary) -> String:
	if biomes.is_empty():
		return ""
	var best_biome = str(biomes[0])
	var best_score = -1e18
	var biome_data = lindblad.get("biomes", {})
	if not (biome_data is Dictionary):
		biome_data = {}
	var pressure = _resource_pressure(resources, floors)
	for biome in biomes:
		var bname = str(biome)
		var score = 1.0
		var sink = _biome_sink_flux(biome_data, bname)
		for emoji in sink.keys():
			var flux = float(sink.get(emoji, 0.0))
			var floor = float(floors.get(emoji, 0.0))
			if floor > 0.0 and float(resources.get(emoji, 0.0)) < floor:
				score += flux * 4.0
			else:
				score += flux * 0.5
		score += pressure * 0.25
		if score > best_score:
			best_score = score
			best_biome = bname
	return best_biome


func _choose_drain_biome(biomes: Array, lindblad: Dictionary, resources: Dictionary, floors: Dictionary) -> String:
	if biomes.is_empty():
		return ""
	var best_biome = str(biomes[0])
	var best_score = -1e18
	var biome_data = lindblad.get("biomes", {})
	if not (biome_data is Dictionary):
		biome_data = {}
	for biome in biomes:
		var bname = str(biome)
		var sink = _biome_sink_flux(biome_data, bname)
		var score = 0.0
		for emoji in sink.keys():
			var flux = float(sink.get(emoji, 0.0))
			var floor = float(floors.get(emoji, 0.0))
			if floor > 0.0 and float(resources.get(emoji, 0.0)) < floor:
				score += flux * 5.0
			else:
				score += flux
		if score > best_score:
			best_score = score
			best_biome = bname
	return best_biome


func _choose_channel_drain_target(biomes: Array, lindblad: Dictionary, _resources: Dictionary) -> Dictionary:
	"""Pick a biome + source/target emoji pair for quantum channel_drain.

	Reads biome population snapshots to find natural gradients: a high-population
	emoji (source) paired with a low-population emoji (target). The dissipative
	channel transfers population along this gradient — the policy reads quantum
	state to decide where to open quantum channels.
	"""
	var biome_data = lindblad.get("biomes", {})
	if not (biome_data is Dictionary):
		return {}

	var best_gradient = 0.0
	var best_result: Dictionary = {}

	for biome in biomes:
		var bname = str(biome)
		var entry = biome_data.get(bname, {})
		if not (entry is Dictionary):
			continue
		# Read population snapshot if available (from biome quantum state)
		var populations = entry.get("populations", {})
		if not (populations is Dictionary) or populations.size() < 2:
			# Fallback: use sink_fluxes as proxy for population gradients
			var sink = entry.get("sink_fluxes", {})
			if sink is Dictionary and sink.size() >= 2:
				populations = sink
			else:
				continue

		# Find the pair with the largest population gradient
		var emojis = populations.keys()
		for i in range(emojis.size()):
			for j in range(i + 1, emojis.size()):
				var e_i = str(emojis[i])
				var e_j = str(emojis[j])
				var p_i = float(populations.get(e_i, 0.0))
				var p_j = float(populations.get(e_j, 0.0))
				var gradient = abs(p_i - p_j)
				if gradient > best_gradient:
					best_gradient = gradient
					if p_i > p_j:
						best_result = {"biome": bname, "source_emoji": e_i, "target_emoji": e_j}
					else:
						best_result = {"biome": bname, "source_emoji": e_j, "target_emoji": e_i}

	if best_gradient < 0.05:
		return {}  # No meaningful gradient — channel would be unproductive
	return best_result


func _biome_sink_flux(biome_data: Dictionary, biome_name: String) -> Dictionary:
	var entry = biome_data.get(biome_name, {})
	if not (entry is Dictionary):
		return {}
	var sink = entry.get("sink_fluxes", {})
	return sink if sink is Dictionary else {}


func _active_drain_count(lindblad: Dictionary) -> int:
	return int(lindblad.get("active_plot_count", 0))


func _suggest_wait_phrames(lindblad: Dictionary) -> int:
	var active_drains = _active_drain_count(lindblad)
	if active_drains <= 0:
		return 4
	if active_drains <= 4:
		return 10
	return 16


# ════════════════════════════════════════════════════════════════════
#  REWARD COMPUTATION (copied from QuantumFiberPolicy)
# ════════════════════════════════════════════════════════════════════

func _compute_reward_components(pre_state: Dictionary, post_state: Dictionary, execution: Dictionary) -> Dictionary:
	var pre_resources = _as_resource_map(pre_state.get("resources", {}))
	var post_resources = _as_resource_map(post_state.get("resources", {}))
	var pre_pairs = _as_pairs(pre_state.get("known_pairs", []))
	var post_pairs = _as_pairs(post_state.get("known_pairs", []))
	var pre_active = _as_dict_array(pre_state.get("active_quests", []))
	var post_active = _as_dict_array(post_state.get("active_quests", []))
	var pre_biomes = _as_string_array(pre_state.get("biomes", []))
	var post_biomes = _as_string_array(post_state.get("biomes", []))

	var pre_lind = pre_state.get("lindblad", {})
	var post_lind = post_state.get("lindblad", {})
	if not (pre_lind is Dictionary):
		pre_lind = {}
	if not (post_lind is Dictionary):
		post_lind = {}

	var delta_resources = _sum_resources(post_resources) - _sum_resources(pre_resources)
	var delta_pairs = float(post_pairs.size() - pre_pairs.size())
	var delta_active = float(pre_active.size() - post_active.size())
	var delta_biomes = float(post_biomes.size() - pre_biomes.size())
	var delta_drains = float(_active_drain_count(post_lind) - _active_drain_count(pre_lind))
	var milk_bonus = 0.0
	if (not _contains_milk_pair(pre_pairs)) and _contains_milk_pair(post_pairs):
		milk_bonus = 120.0

	var pre_locked = _as_dict_array(pre_state.get("locked_offers", []))
	var post_locked = _as_dict_array(post_state.get("locked_offers", []))
	var delta_locked = float(post_locked.size() - pre_locked.size())
	var lock_term = delta_locked * 3.0

	var resource_term = delta_resources * 0.08
	var pair_term = delta_pairs * 42.0
	var active_quest_term = delta_active * 5.0
	var biome_term = delta_biomes * 8.0
	var drain_term = delta_drains * 2.5
	var reward = resource_term + pair_term + active_quest_term + biome_term + drain_term + lock_term + milk_bonus
	var execution_penalty = 0.0

	if execution is Dictionary and not bool(execution.get("ok", false)):
		execution_penalty = -8.0
		reward += execution_penalty
	var clamped = clamp(reward, -120.0, 220.0)
	return {
		"delta_resources": delta_resources,
		"delta_pairs": delta_pairs,
		"delta_active_quests": delta_active,
		"delta_biomes": delta_biomes,
		"delta_drains": delta_drains,
		"delta_locked": delta_locked,
		"resource_term": resource_term,
		"pair_term": pair_term,
		"active_quest_term": active_quest_term,
		"biome_term": biome_term,
		"drain_term": drain_term,
		"lock_term": lock_term,
		"milk_bonus": milk_bonus,
		"execution_penalty": execution_penalty,
		"reward_raw": reward,
		"reward": clamped,
	}


func _sum_resources(resources: Dictionary) -> float:
	var total = 0.0
	for emoji in resources.keys():
		total += max(0.0, float(resources.get(emoji, 0.0)))
	return total


# ════════════════════════════════════════════════════════════════════
#  DATA HELPERS (copied from QuantumFiberPolicy)
# ════════════════════════════════════════════════════════════════════

func _contains_milk_pair(pairs: Array) -> bool:
	for pair in pairs:
		if not (pair is Dictionary):
			continue
		if str(pair.get("north", "")) == MILK_EMOJI or str(pair.get("south", "")) == MILK_EMOJI:
			return true
	return false


func _known_emoji_map(pairs: Array) -> Dictionary:
	var out: Dictionary = {}
	for pair in pairs:
		if not (pair is Dictionary):
			continue
		var north = str(pair.get("north", ""))
		var south = str(pair.get("south", ""))
		if north != "":
			out[north] = true
		if south != "":
			out[south] = true
	return out


func _best_lockable_offer(offers: Array, locked_offers: Array, active_quests: Array, known_pairs: Array) -> Dictionary:
	if locked_offers.size() >= 3:
		return {}
	var locked_ids: Dictionary = {}
	for locked in locked_offers:
		if locked is Dictionary:
			var lid = str(locked.get("id", ""))
			if lid != "":
				locked_ids[lid] = true
	var active_ids: Dictionary = {}
	for quest in active_quests:
		if quest is Dictionary:
			var aid = str(quest.get("id", ""))
			if aid != "":
				active_ids[aid] = true
	var known = _known_emoji_map(known_pairs)
	var best: Dictionary = {}
	var best_score = -1.0
	for i in range(offers.size()):
		var offer = offers[i]
		if not (offer is Dictionary):
			continue
		var oid = str(offer.get("id", ""))
		if oid != "" and (locked_ids.has(oid) or active_ids.has(oid)):
			continue
		var north = str(offer.get("reward_vocab_north", ""))
		var south = str(offer.get("reward_vocab_south", ""))
		var novelty = 0.0
		if north != "" and not known.has(north):
			novelty += 1.0
		if south != "" and not known.has(south):
			novelty += 1.0
		if novelty <= 0.0:
			continue
		var discovery_aff = float(offer.get("discovery_affinity", 0.0))
		var score = discovery_aff + novelty * 0.5
		if score > best_score:
			best_score = score
			best = {
				"offer_index": i,
				"discovery_value": discovery_aff,
				"novelty": novelty,
			}
	return best


func _discovery_forecast_bonus(forecast: Dictionary) -> float:
	if forecast.is_empty():
		return 0.0
	var max_prob = 0.0
	var sum_prob = 0.0
	var count = 0
	for biome_name in forecast.keys():
		var entry = forecast.get(biome_name, {})
		if not (entry is Dictionary):
			continue
		var prob = float(entry.get("probability", 0.0))
		sum_prob += prob
		count += 1
		if prob > max_prob:
			max_prob = prob
	if count <= 0:
		return 0.0
	var mean_prob = sum_prob / float(count)
	var spread = max_prob - mean_prob
	return clamp(spread * 25.0, 0.0, 1.5)


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
