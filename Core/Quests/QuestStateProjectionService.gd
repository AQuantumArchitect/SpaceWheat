class_name QuestStateProjectionService
extends RefCounted

const FactionStateMatcher = preload("res://Core/QuantumSubstrate/FactionStateMatcher.gd")

const MAX_ACTION_HISTORY: int = 64

## Completion threshold: evaluate_all() must reach this to mark a quest ready.
const COMPLETION_THRESHOLD: float = 0.85

var _last_observables: Dictionary = {}
var _action_history: Array = []
var _last_biome = null  # Retained for on-demand predict_population calls


func observe_biome(biome, delta: float = 0.0) -> Dictionary:
	if biome == null:
		return _last_observables
	_last_biome = biome
	var obs = FactionStateMatcher.extract_observables(null, biome)
	var biome_name = ""
	if biome and biome.has_method("get"):
		biome_name = str(biome.get("biome_name"))
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
			var pop := _last_biome.predict_population(str(predicate.get("emoji", "")), steps)
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
