class_name BalanceConfig
extends RefCounted

## BalanceConfig - Loads and validates shared balance workbench config.
## This config is read by both headless tooling and UI projection layers.

const DEFAULT_CONFIG_PATH := "res://config/balance/workbench_default.json"

const DEFAULTS: Dictionary = {
	"profile_id": "default",
	"display_name": "Default Balance",
	"action_roi_notes": {},
	"quest_reward_notes": {},
	"tuning": {
		"pop_base_yield_scale": 100.0,
		"reap_base_yield": 50.0,
		"reap_evolution_cycles": 13,
		"flux_to_credits": 1.0,
		"reap_cost_sequence": [1, 1, 2, 3, 5, 8, 13, 21],
		"reap_starting_tokens": 6
	}
}


static func load_default_config() -> Dictionary:
	return load_config(DEFAULT_CONFIG_PATH)


static func load_config(path: String) -> Dictionary:
	var merged = DEFAULTS.duplicate(true)
	if path == "" or not FileAccess.file_exists(path):
		return merged

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return merged

	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return merged

	var raw: Dictionary = parsed
	if raw.has("profile_id"):
		merged["profile_id"] = str(raw.get("profile_id", "default"))
	if raw.has("display_name"):
		merged["display_name"] = str(raw.get("display_name", "Default Balance"))
	if raw.get("action_roi_notes", {}) is Dictionary:
		merged["action_roi_notes"] = raw.get("action_roi_notes", {}).duplicate(true)
	if raw.get("quest_reward_notes", {}) is Dictionary:
		merged["quest_reward_notes"] = raw.get("quest_reward_notes", {}).duplicate(true)
	if raw.get("tuning", {}) is Dictionary:
		var tuning = merged.get("tuning", {}).duplicate(true)
		for key in raw.get("tuning", {}).keys():
			tuning[str(key)] = raw["tuning"][key]
		merged["tuning"] = tuning
	return merged
