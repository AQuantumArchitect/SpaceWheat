class_name QuestStateProjectionService
extends RefCounted


const MAX_ACTION_HISTORY: int = 64

## Completion threshold: evaluate_all() must reach this to mark a quest ready.
const COMPLETION_THRESHOLD: float = 0.85

var _last_observables: Dictionary = {}
var _action_history: Array = []
var _last_biome = null  # Retained for on-demand predict_population calls

## Per-biome coherence high-watermark — the witness for coherence_fell (What Fades:
## the first quests that ask the player to LOSE something need proof there was
## something to lose). Session-scoped; resets on load, which only delays the witness.
var _coherence_watermark: Dictionary = {}


func observe_biome(biome, delta: float = 0.0) -> Dictionary:
	if biome == null:
		return _last_observables
	_last_biome = biome
	var obs = FactionStateMatcher.extract_observables(null, biome)
	var biome_name = ""
	if biome and biome.has_method("get"):
		biome_name = str(biome.get("biome_name"))
	if biome_name != "":
		var mark := float(_coherence_watermark.get(biome_name, 0.0))
		if float(obs.coherence) > mark:
			_coherence_watermark[biome_name] = float(obs.coherence)
	_last_observables = {
		"biome": biome_name,
		"purity": float(obs.purity),
		"entropy": float(obs.entropy),
		"coherence": float(obs.coherence),
		"distribution_shape": str(obs.distribution_shape),
		"scale": str(obs.scale),
		"dynamics": str(obs.dynamics),
		"delta": float(delta),
		"time_msec": Time.get_ticks_msec()
	}
	# Physics projection observables (new read-ports from BiomeBase)
	if biome.has_method("get_attractor_state"):
		_last_observables["attractor"] = biome.get_attractor_state()
	if biome.has_method("predict_purity"):
		_last_observables["predict_purity_5"]  = biome.predict_purity(5)
		_last_observables["predict_purity_10"] = biome.predict_purity(10)
	# Entanglement observable: max pairwise mutual information (bits; Bell pair = 2.0).
	# Cache-only scan — the GDScript MI fallback re-eigensolves per pair, too hot for a
	# per-frame observer. No native cache → observable absent (predicate scores 0).
	var qc = biome.get("quantum_computer")
	if qc != null and qc.has_method("has_cached_mi") and qc.has_cached_mi():
		var n: int = qc.register_map.num_qubits
		var best_mi := 0.0
		var best_pair := Vector2i(-1, -1)
		for i in range(n):
			for j in range(i + 1, n):
				var mi: float = qc.get_cached_mutual_information(i, j)
				if mi > best_mi:
					best_mi = mi
					best_pair = Vector2i(i, j)
		_last_observables["max_mutual_information"] = best_mi
		_last_observables["max_mi_pair"] = best_pair
	# Knot observables: frozen Berry loop records + the strongest pair invariant
	# (mutual winding — KnotRegister). The record is capped at FROZEN_LOOP_CAP,
	# so the pair scan is trivially cheap at observe rate.
	if qc != null and "berry_register" in qc and qc.berry_register != null:
		var loops: Array = qc.berry_register.frozen_loops()
		_last_observables["frozen_loops"] = loops.size()
		_last_observables["max_mutual_winding"] = KnotRegister.max_mutual_winding(loops) if loops.size() >= 2 else 0
	return _last_observables


func record_action(action_name: String, payload: Dictionary = {}) -> void:
	var row = {
		"action": action_name,
		"time_msec": Time.get_ticks_msec(),
		"payload": payload.duplicate(true)
	}
	_action_history.append(row)
	if _action_history.size() > MAX_ACTION_HISTORY:
		_action_history.pop_front()


func get_snapshot() -> Dictionary:
	return {
		"observables": _last_observables.duplicate(true),
		"recent_actions": _action_history.duplicate(true)
	}


func evaluate_predicate(predicate: Dictionary) -> float:
	## Returns a continuous confidence score in [0, 1] rather than a binary bool.
	## 0.0 = condition clearly unmet; 1.0 = condition clearly met;
	## 0.5 = right at the threshold boundary.
	var predicate_type = str(predicate.get("type", ""))
	match predicate_type:
		"purity_at_least":
			var target := float(predicate.get("value", 0.0))
			return QuestMath.soft_gate(float(_last_observables.get("purity", 0.0)), target)
		"purity_at_most":
			# What Fades: the first predicate where LOW purity is the goal — let the
			# Bath in, watch Tr(ρ²) fall. Meaningless in the enclave (purity ≡ 1).
			var target := float(predicate.get("value", 1.0))
			return QuestMath.soft_gate_inv(float(_last_observables.get("purity", 1.0)), target)
		"coherence_fell":
			# The fading witness: proof the ACTIVE biome once held coherence at the
			# high-water mark ("from") AND stands below "to" now. Asking a player to
			# lose something only counts if they had it first.
			var from := float(predicate.get("from", 0.3))
			var to := float(predicate.get("to", 0.15))
			var bname := str(_last_observables.get("biome", ""))
			var had := QuestMath.soft_gate(float(_coherence_watermark.get(bname, 0.0)), from)
			var lost := QuestMath.soft_gate_inv(float(_last_observables.get("coherence", 1.0)), to)
			return QuestMath.smooth_and([had, lost])
		"coherence_at_least":
			var target := float(predicate.get("value", 0.0))
			return QuestMath.soft_gate(float(_last_observables.get("coherence", 0.0)), target)
		"entropy_at_most":
			var target := float(predicate.get("value", 1.0))
			return QuestMath.soft_gate_inv(float(_last_observables.get("entropy", 1.0)), target)
		"gate_sequence_contains":
			var pattern := str(predicate.get("gate", "")).strip_edges().to_lower()
			var min_count := maxf(1.0, float(predicate.get("count", 1)))
			if pattern == "":
				return 0.0
			var hits := 0.0
			for row in _action_history:
				var action_name := str(row.get("action", "")).to_lower()
				if action_name.find(pattern) >= 0:
					hits += 1.0
			# Smooth over ±1.5 hits so "just short" isn't a cliff
			return QuestMath.soft_gate(hits, min_count, 1.5)
		"gate_order":
			# The braid teacher: ordered subsequence match over the action history.
			# {"type": "gate_order", "gates": ["hadamard", "cnot"]} scores the
			# fraction of the word spelled IN ORDER (each history row consumes at
			# most one step). Where gate_sequence_contains counts, this one reads —
			# non-commuting operations are words, not sets (docs/TOPOLOGY_CAMPAIGN.md,
			# Chapter 4). Progress bar = how much of the braid word is spelled.
			var word: Array = predicate.get("gates", [])
			if not (word is Array) or word.is_empty():
				return 0.0
			var step := 0
			for row in _action_history:
				if step >= word.size():
					break
				var action_name := str(row.get("action", "")).to_lower()
				if action_name.find(str(word[step]).strip_edges().to_lower()) >= 0:
					step += 1
			return float(step) / float(word.size())
		"frozen_loops_gte":
			# The loop farmer: closed Berry walks banked in the active biome's
			# record (BerryPhaseRegister freezes a loop when the walk returns to
			# its seed vertex having enclosed real solid angle).
			var target := maxf(1.0, float(predicate.get("count", 1)))
			return QuestMath.soft_gate(float(_last_observables.get("frozen_loops", 0)), target, 0.75)
		"loops_linked":
			# The knot witness: two frozen loops whose mutual winding is nonzero —
			# loop A turns about loop B's area axis. On the Bloch sphere nothing
			# links; the invariant lives one floor up (the Berry lift), and this
			# integer is its shadow (docs/ENGINE_FRONTIER.md, Machine 2).
			var w := float(absi(int(_last_observables.get("max_mutual_winding", 0))))
			var have := QuestMath.soft_gate(float(_last_observables.get("frozen_loops", 0)), 2.0, 0.75)
			var linked := QuestMath.soft_gate(w, maxf(1.0, float(predicate.get("value", 1))), 0.5)
			return QuestMath.smooth_and([have, linked])
		"winding_gte":
			# Graded knot: |mutual winding| of the strongest frozen pair — ±1 is
			# a simple link, ±2 doubly wound.
			var w := float(absi(int(_last_observables.get("max_mutual_winding", 0))))
			return QuestMath.soft_gate(w, maxf(1.0, float(predicate.get("value", 1))), 0.75)
		"dynamics_at_most":
			# Stillness teacher: the biome's evolution rate (BiomeDynamicsTracker,
			# 0 = still, 1 = storming). In the enclave purity and entropy are frozen,
			# so all motion this sees is coherence + population sloshing — which is
			# exactly the motion the player can quiet. Unknown (-1) scores 0: you
			# cannot claim stillness before the pond has been watched.
			var d := float(str(_last_observables.get("dynamics", "-1")))
			if d < 0.0:
				return 0.0
			return QuestMath.soft_gate_inv(d, float(predicate.get("value", 0.2)), 0.08)
		"dynamics_at_least":
			# Breathing teacher: falling twin of dynamics_at_most.
			var d := float(str(_last_observables.get("dynamics", "-1")))
			if d < 0.0:
				return 0.0
			return QuestMath.soft_gate(d, float(predicate.get("value", 0.25)), 0.08)
		"mutual_information_at_least":
			# Entanglement teacher: max pairwise MI in the active biome, in bits
			# (Bell pair = 2.0, product state = 0). Wider gate (±0.1) than the
			# defaults because the MI scale runs 0–2, not 0–1.
			var target := float(predicate.get("value", 0.5))
			return QuestMath.soft_gate(
				float(_last_observables.get("max_mutual_information", 0.0)), target, 0.1)
		"attractor_emoji_gte":
			var attractor: Dictionary = _last_observables.get("attractor", {})
			return QuestMath.soft_gate(attractor.get(str(predicate.get("emoji", "")), 0.0),
					float(predicate.get("value", 0.5)))
		"eigenvalue_gap_gte":
			var attractor: Dictionary = _last_observables.get("attractor", {})
			return QuestMath.soft_gate(attractor.get("eigenvalue_gap", 0.0),
					float(predicate.get("value", 0.10)), 0.02)
		"predict_population_gte":
			if _last_biome == null or not _last_biome.has_method("predict_population"):
				return 0.0
			var steps := int(predicate.get("steps", 5))
			var value := float(predicate.get("value", 0.5))
			var pop: float = float(_last_biome.predict_population(str(predicate.get("emoji", "")), steps))
			return QuestMath.soft_gate(pop, value)
		"predict_purity_gte":
			var steps := int(predicate.get("steps", 5))
			var key := "predict_purity_%d" % steps
			var predicted: float
			if _last_observables.has(key):
				predicted = float(_last_observables[key])
			elif _last_biome and _last_biome.has_method("predict_purity"):
				predicted = _last_biome.predict_purity(steps)
			else:
				return 0.0
			return QuestMath.soft_gate(predicted, float(predicate.get("value", 0.5)))
		_:
			return 0.0


func evaluate_all(predicates: Array) -> float:
	## Returns the geometric mean of all predicate confidence scores.
	## Empty list → 0.0 (never fires).  All predicates must score well for
	## the result to be high.  Compare against COMPLETION_THRESHOLD (0.85).
	if predicates.is_empty():
		return 0.0
	var scores: Array = []
	for raw in predicates:
		if not (raw is Dictionary):
			return 0.0
		scores.append(evaluate_predicate(raw))
	return QuestMath.smooth_and(scores)
