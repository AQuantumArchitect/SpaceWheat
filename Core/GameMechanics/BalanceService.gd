class_name BalanceService
extends RefCounted

## BalanceService - Shared balance tuning API for headless and UI layers.
##
## Ownership remains with runtime/headless systems (FarmEconomy + QuestRewards).
## UI overlays should call this service and never hardcode constants.

const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")
const ActionIds = preload("res://Core/GameMechanics/ActionIds.gd")
const QuestRewards = preload("res://Core/Quests/QuestRewards.gd")
const BalanceConfig = preload("res://Core/GameMechanics/BalanceConfig.gd")
const FarmVariableGraph = preload("res://Core/GameMechanics/FarmVariableGraph.gd")

const ACTION_CATALOG: Array[String] = [
	"explore",
	"measure",
	"pop",
	"reap",
	"discover_biome",
	"inject_vocabulary",
	"remove_vocabulary",
	"lindblad_pump",
	"lindblad_drain",
	"quest_reroll",
	"quest_lock",
]


static func get_snapshot(farm: Node) -> Dictionary:
	var state = _get_current_state(farm)
	var config = BalanceConfig.load_default_config(state)
	var profile_id = "default"
	var overrides: Dictionary = {}
	var quest_tuning = QuestRewards.get_reward_tuning()
	var action_costs: Dictionary = {}
	var gate_costs: Dictionary = {}
	var tuning = config.get("tuning", {}).duplicate(true)
	var economy_variables = config.get("economy_variables", {}).duplicate(true)

	var economy = _get_economy(farm)
	if economy:
		if economy.has_method("get_balance_profile_id"):
			profile_id = str(economy.get_balance_profile_id())
		if economy.has_method("get_economy_overrides"):
			overrides = economy.get_economy_overrides().duplicate(true)
			var override_tuning = overrides.get("tuning", {})
			if override_tuning is Dictionary:
				for key in override_tuning.keys():
					tuning[str(key)] = override_tuning[key]
			var override_vars = overrides.get("economy_variables", {})
			if override_vars is Dictionary:
				for key in override_vars.keys():
					economy_variables[str(key)] = override_vars[key]

	for action in ACTION_CATALOG:
		var normalized = ActionIds.normalize_action(action)
		if economy and economy.has_method("get_overridden_action_cost"):
			action_costs[normalized] = economy.get_overridden_action_cost(normalized, {})
		else:
			action_costs[normalized] = EconomyConstants.get_action_cost(normalized, {})

	for gate_name in EconomyConstants.GATE_COSTS.keys():
		if economy and economy.has_method("get_overridden_gate_cost"):
			gate_costs[gate_name] = economy.get_overridden_gate_cost(gate_name)
		else:
			gate_costs[gate_name] = EconomyConstants.get_gate_cost(gate_name)

	return {
		"profile_id": profile_id,
		"profile_display_name": str(config.get("display_name", profile_id)),
		"action_costs": action_costs,
		"gate_costs": gate_costs,
		"quest_rewards": quest_tuning,
		"tuning": tuning,
		"economy_variables": economy_variables,
		"overrides": overrides,
		"roi_notes": config.get("action_roi_notes", {}),
		"quest_notes": config.get("quest_reward_notes", {}),
		"farm_variable_graph_jsonl": FarmVariableGraph.snapshot_to_graph_lines({
			"profile_id": profile_id,
			"action_costs": action_costs,
			"gate_costs": gate_costs,
			"quest_rewards": quest_tuning,
			"tuning": tuning,
			"economy_variables": economy_variables,
		}),
	}


static func apply_patch(farm: Node, patch: Dictionary, source: String = "balance_service") -> Dictionary:
	var economy = _get_economy(farm)
	if not economy:
		return {"ok": false, "error": "no_economy"}
	if patch.is_empty():
		return {"ok": false, "error": "empty_patch"}

	var merged = economy.get_economy_overrides().duplicate(true)

	var action_patch = patch.get("action_costs", {})
	if action_patch is Dictionary and not action_patch.is_empty():
		var target = merged.get("action_costs", {})
		if not (target is Dictionary):
			target = {}
		for action in action_patch.keys():
			var normalized = ActionIds.normalize_action(str(action))
			var cost = action_patch[action]
			if cost is Dictionary:
				target[normalized] = cost.duplicate(true)
		merged["action_costs"] = target

	var gate_patch = patch.get("gate_costs", {})
	if gate_patch is Dictionary and not gate_patch.is_empty():
		var gate_target = merged.get("gate_costs", {})
		if not (gate_target is Dictionary):
			gate_target = {}
		for gate_name in gate_patch.keys():
			var gate_cost = gate_patch[gate_name]
			if gate_cost is Dictionary:
				gate_target[str(gate_name)] = gate_cost.duplicate(true)
		merged["gate_costs"] = gate_target

	var quest_patch = patch.get("quest_rewards", {})
	if quest_patch is Dictionary and not quest_patch.is_empty():
		var quest_target = merged.get("quest_rewards", {})
		if not (quest_target is Dictionary):
			quest_target = {}
		for key in quest_patch.keys():
			quest_target[str(key)] = quest_patch[key]
		merged["quest_rewards"] = quest_target

	var tuning_patch = patch.get("tuning", {})
	if tuning_patch is Dictionary and not tuning_patch.is_empty():
		var tuning_target = merged.get("tuning", {})
		if not (tuning_target is Dictionary):
			tuning_target = {}
		for key in tuning_patch.keys():
			tuning_target[str(key)] = tuning_patch[key]
		merged["tuning"] = tuning_target

	var variable_patch = patch.get("economy_variables", {})
	if variable_patch is Dictionary and not variable_patch.is_empty():
		var variable_target = merged.get("economy_variables", {})
		if not (variable_target is Dictionary):
			variable_target = {}
		for key in variable_patch.keys():
			variable_target[str(key)] = variable_patch[key]
		merged["economy_variables"] = variable_target

	if patch.has("profile_id"):
		merged["profile_id"] = str(patch.get("profile_id", "default"))

	if not economy.has_method("apply_economy_overrides"):
		return {"ok": false, "error": "economy_override_unavailable"}
	var applied = economy.apply_economy_overrides(merged)
	_sync_state_from_economy(farm, economy)
	return {
		"ok": true,
		"applied": applied,
		"profile_id": economy.get_balance_profile_id() if economy.has_method("get_balance_profile_id") else merged.get("profile_id", "default"),
		"source": source
	}


static func reset_to_default(farm: Node) -> Dictionary:
	var economy = _get_economy(farm)
	if not economy:
		return {"ok": false, "error": "no_economy"}
	if not economy.has_method("apply_economy_overrides"):
		return {"ok": false, "error": "economy_override_unavailable"}
	var defaults = {"profile_id": "default"}
	var applied = economy.apply_economy_overrides(defaults)
	_sync_state_from_economy(farm, economy)
	return {"ok": true, "applied": applied, "profile_id": "default"}


static func get_farm_variable_graph(farm: Node) -> Dictionary:
	var snapshot = get_snapshot(farm)
	return {
		"ok": true,
		"profile_id": str(snapshot.get("profile_id", "default")),
		"lines": FarmVariableGraph.snapshot_to_graph_lines(snapshot),
		"patch": {
			"profile_id": snapshot.get("profile_id", "default"),
			"action_costs": snapshot.get("action_costs", {}),
			"gate_costs": snapshot.get("gate_costs", {}),
			"quest_rewards": snapshot.get("quest_rewards", {}),
			"tuning": snapshot.get("tuning", {}),
			"economy_variables": snapshot.get("economy_variables", {}),
		}
	}


static func apply_farm_variable_graph(farm: Node, lines: Array, source: String = "balance_service.farm_variable_graph") -> Dictionary:
	if lines.is_empty():
		return {"ok": false, "error": "empty_graph"}
	var parsed = FarmVariableGraph.parse_graph_lines(lines)
	if not bool(parsed.get("ok", false)):
		return {"ok": false, "error": "invalid_graph", "errors": parsed.get("errors", [])}
	var patch: Dictionary = parsed.get("patch", {})
	if patch.is_empty():
		return {"ok": false, "error": "empty_patch"}
	var applied = apply_patch(farm, patch, source)
	applied["graph_errors"] = parsed.get("errors", [])
	return applied


static func load_farm_variable_graph_file(farm: Node, path: String, source: String = "balance_service.farm_variable_graph_file") -> Dictionary:
	var lines = FarmVariableGraph.load_graph_lines(path)
	if lines.is_empty():
		return {"ok": false, "error": "missing_or_empty_graph_file", "path": path}
	var applied = apply_farm_variable_graph(farm, lines, source)
	applied["path"] = path
	return applied


static func get_tuning_value(farm: Node, key: String, default_value):
	var config = BalanceConfig.load_default_config(_get_current_state(farm))
	var tuning = config.get("tuning", {}).duplicate(true)
	var economy = _get_economy(farm)
	if economy and economy.has_method("get_economy_overrides"):
		var overrides = economy.get_economy_overrides()
		var override_tuning = overrides.get("tuning", {})
		if override_tuning is Dictionary:
			for tuning_key in override_tuning.keys():
				tuning[str(tuning_key)] = override_tuning[tuning_key]
	return tuning.get(key, default_value)


static func get_reap_cost_sequence(farm: Node = null) -> Array:
	var sequence = get_tuning_value(farm, "reap_cost_sequence", EconomyConstants.REAP_COST_SEQUENCE)
	return sequence if sequence is Array else EconomyConstants.REAP_COST_SEQUENCE


static func get_reap_cost(farm: Node, reap_count: int) -> Dictionary:
	var sequence = get_reap_cost_sequence(farm)
	if sequence.is_empty():
		return {EconomyConstants.MIDWIFE_EMOJI: 1}
	var index = clampi(reap_count, 0, sequence.size() - 1)
	return {EconomyConstants.MIDWIFE_EMOJI: int(sequence[index])}


static func _get_economy(farm: Node):
	if farm and ("economy" in farm) and farm.economy:
		return farm.economy
	return null


static func _get_current_state(farm: Node):
	if not farm:
		return null
	var gsm = farm.get_node_or_null("/root/GameStateManager")
	if not gsm:
		return null
	if not ("current_state" in gsm):
		return null
	return gsm.current_state


static func _sync_state_from_economy(farm: Node, economy) -> void:
	var state = _get_current_state(farm)
	if not state:
		return
	if state.has_method("ensure_balance_workbench_defaults"):
		state.ensure_balance_workbench_defaults()
	if economy and economy.has_method("get_balance_profile_id"):
		state.balance_profile_id = str(economy.get_balance_profile_id())
	var cfg = {}
	if state.balance_workbench_config is Dictionary:
		cfg = state.balance_workbench_config.duplicate(true)
	if economy and economy.has_method("get_economy_overrides"):
		var overrides = economy.get_economy_overrides().duplicate(true)
		for key in ["action_costs", "gate_costs", "quest_rewards", "production", "tuning", "economy_variables"]:
			var block = overrides.get(key, null)
			if block is Dictionary:
				var merged_block = cfg.get(key, {})
				if not (merged_block is Dictionary):
					merged_block = {}
				for sub_key in block.keys():
					merged_block[str(sub_key)] = block[sub_key]
				cfg[key] = merged_block
	if economy and economy.has_method("get_economy_variables"):
		state.economy_variables = economy.get_economy_variables().duplicate(true)
	if state.balance_profile_id != "":
		cfg["profile_id"] = state.balance_profile_id
	if state.economy_variables is Dictionary and not state.economy_variables.is_empty():
		cfg["economy_variables"] = state.economy_variables.duplicate(true)
	state.balance_workbench_config = BalanceConfig.merge_with_defaults(cfg)
