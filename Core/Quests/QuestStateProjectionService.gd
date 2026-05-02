class_name QuestStateProjectionService
extends RefCounted

const FactionStateMatcher = preload("res://Core/QuantumSubstrate/FactionStateMatcher.gd")

const MAX_ACTION_HISTORY: int = 64

var _last_observables: Dictionary = {}
var _action_history: Array = []


func observe_biome(biome, delta: float = 0.0) -> Dictionary:
	if biome == null:
		return _last_observables
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


func evaluate_predicate(predicate: Dictionary) -> bool:
	var predicate_type = str(predicate.get("type", ""))
	match predicate_type:
		"purity_at_least":
			var target = float(predicate.get("value", 0.0))
			return float(_last_observables.get("purity", 0.0)) >= target
		"coherence_at_least":
			var target = float(predicate.get("value", 0.0))
			return float(_last_observables.get("coherence", 0.0)) >= target
		"entropy_at_most":
			var target = float(predicate.get("value", 1.0))
			return float(_last_observables.get("entropy", 1.0)) <= target
		"gate_sequence_contains":
			var pattern = str(predicate.get("gate", "")).strip_edges().to_lower()
			var min_count = max(1, int(predicate.get("count", 1)))
			if pattern == "":
				return false
			var hits = 0
			for row in _action_history:
				var action_name = str(row.get("action", "")).to_lower()
				if action_name.find(pattern) >= 0:
					hits += 1
				if hits >= min_count:
					return true
			return false
		_:
			return false


func evaluate_all(predicates: Array) -> bool:
	if predicates.is_empty():
		return false
	for raw in predicates:
		if not (raw is Dictionary):
			return false
		if not evaluate_predicate(raw):
			return false
	return true
