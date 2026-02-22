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

const ACTION_CATALOG: Array[String] = [
	"explore",
	"measure",
	"pop",
	"reap",
	"harvest_all",
	"explore_biome",
	"inject_vocabulary",
	"remove_vocabulary",
	"lindblad_pump",
	"lindblad_drain",
	"quest_reroll",
	"quest_lock",
]


static func get_snapshot(farm: Node) -> Dictionary:
	var config = BalanceConfig.load_default_config()
	var profile_id = "default"
	var overrides: Dictionary = {}
	var quest_tuning = QuestRewards.get_reward_tuning()
	var action_costs: Dictionary = {}
	var gate_costs: Dictionary = {}
	var tuning = config.get("tuning", {}).duplicate(true)

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
		"overrides": overrides,
		"roi_notes": config.get("action_roi_notes", {}),
		"quest_notes": config.get("quest_reward_notes", {})
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

	if patch.has("profile_id"):
		merged["profile_id"] = str(patch.get("profile_id", "default"))

	if not economy.has_method("apply_economy_overrides"):
		return {"ok": false, "error": "economy_override_unavailable"}
	var applied = economy.apply_economy_overrides(merged)
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
	return {"ok": true, "applied": applied, "profile_id": "default"}


static func get_tuning_value(farm: Node, key: String, default_value):
	var config = BalanceConfig.load_default_config()
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
