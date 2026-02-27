class_name BalanceConfig
extends RefCounted

## BalanceConfig - Runtime/default balance profile resolver.
## Canonical profile lives in GameState.balance_workbench_config.

const LEGACY_DEFAULT_CONFIG_PATH := "res://config/balance/workbench_default.json"

const DEFAULTS: Dictionary = {
	"profile_id": "default",
	"display_name": "Default Runtime Balance",
	"action_roi_notes": {},
	"quest_reward_notes": {},
	"economy_variables": {
		"quantum_to_credits": 1.0,
		"max_biome_qubits": 12
	},
	"tuning": {
		"pop_base_yield_scale": 100.0,
		"reap_base_yield": 50.0,
		"reap_evolution_cycles": 13,
		"flux_to_credits": 1.0,
		"reap_cost_sequence": [1, 1, 2, 3, 5, 8, 13, 21],
		"reap_starting_tokens": 6
	}
}


static func load_default_config(state = null) -> Dictionary:
	if state and ("balance_workbench_config" in state):
		var state_cfg = state.balance_workbench_config
		if state_cfg is Dictionary and not state_cfg.is_empty():
			return merge_with_defaults(state_cfg)
	return DEFAULTS.duplicate(true)


static func merge_with_defaults(raw: Dictionary) -> Dictionary:
	var merged = DEFAULTS.duplicate(true)
	if not (raw is Dictionary):
		return merged
	if raw.has("profile_id"):
		merged["profile_id"] = str(raw.get("profile_id", "default"))
	if raw.has("display_name"):
		merged["display_name"] = str(raw.get("display_name", "Default Runtime Balance"))
	for key in [
		"action_roi_notes",
		"quest_reward_notes",
		"economy_variables",
		"tuning",
		"action_costs",
		"gate_costs",
		"quest_rewards",
		"production"
	]:
		var block = raw.get(key, null)
		if block is Dictionary:
			var dest = merged.get(key, {}).duplicate(true)
			for sub_key in block.keys():
				dest[str(sub_key)] = block[sub_key]
			merged[key] = dest
	for key in raw.keys():
		var normalized = str(key)
		if not merged.has(normalized):
			merged[normalized] = raw[key]
	return merged


static func load_config(path: String) -> Dictionary:
	# Legacy import path support for existing tooling.
	if path == "" or not FileAccess.file_exists(path):
		return DEFAULTS.duplicate(true)
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return DEFAULTS.duplicate(true)
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return DEFAULTS.duplicate(true)
	return merge_with_defaults(parsed)
