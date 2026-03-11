class_name ActionCostRuntime
extends RefCounted

## ActionCostRuntime - shared runtime cost surface resolver.
##
## Centralizes economy lookup and action/cost preflight+commit helpers so
## UI, instrument, and headless action handlers use one path.

const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")


static func resolve_economy(source):
	if not source:
		return null
	if source is Object:
		# Already an economy-like object.
		if source.has_method("get_action_cost") or source.has_method("get_overridden_action_cost"):
			return source
		# Farm/manager-like object with `.economy`.
		if source.has_method("get"):
			var object_economy = source.get("economy")
			if object_economy:
				return object_economy
	elif source is Dictionary:
		var dict_economy = source.get("economy", null)
		if dict_economy:
			return dict_economy
	return null


static func get_action_cost(source, action_name: String, context: Dictionary = {}) -> Dictionary:
	var economy = resolve_economy(source)
	if economy:
		if economy.has_method("get_action_cost"):
			return economy.get_action_cost(action_name, context)
		if economy.has_method("get_overridden_action_cost"):
			return economy.get_overridden_action_cost(action_name, context)
	return EconomyConstants.get_action_cost(action_name, context)


static func preflight_action(source, action_name: String, context: Dictionary = {}, allow_missing_economy: bool = false) -> Dictionary:
	var economy = resolve_economy(source)
	if not economy:
		return {"ok": true, "cost": {}} if allow_missing_economy else {"ok": false, "error": "no_economy"}
	if economy.has_method("preflight_action"):
		return economy.preflight_action(action_name, context)
	return EconomyConstants.preflight_action(action_name, economy, context)


static func preflight_cost(source, cost: Dictionary, allow_missing_economy: bool = false) -> Dictionary:
	var economy = resolve_economy(source)
	if not economy:
		return {"ok": true, "cost": {}} if allow_missing_economy else {"ok": false, "error": "no_economy"}
	if economy.has_method("preflight_cost"):
		return economy.preflight_cost(cost)
	return EconomyConstants.preflight_cost(cost, economy)


static func commit_cost(source, cost: Dictionary, reason: String = "", allow_missing_economy: bool = false) -> bool:
	var economy = resolve_economy(source)
	if not economy:
		return allow_missing_economy
	if economy.has_method("commit_cost"):
		return bool(economy.commit_cost(cost, reason))
	return EconomyConstants.commit_cost(cost, economy, reason)


static func commit_action(source, action_name: String, context: Dictionary = {}, reason: String = "", allow_missing_economy: bool = false) -> bool:
	var economy = resolve_economy(source)
	if not economy:
		return allow_missing_economy
	if economy.has_method("commit_action"):
		return bool(economy.commit_action(action_name, context, reason))
	return EconomyConstants.commit_action(action_name, economy, context, reason)


static func get_max_biome_qubits(source) -> int:
	var economy = resolve_economy(source)
	if economy and economy.has_method("get_max_biome_qubits"):
		return int(economy.get_max_biome_qubits())
	return EconomyConstants.get_max_biome_qubits(economy)
