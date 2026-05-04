class_name ScenarioLedger
extends RefCounted

## ScenarioLedger — persistence for completed-scenario flags.
##
## Reads/writes user://saves/completed_scenarios.json. Held as a RefCounted
## member of GameStateManager.

const SaveStore = preload("res://Core/GameState/SaveStore.gd")

const FILE_NAME := "completed_scenarios.json"

var _verbose = null


func _init(verbose = null) -> void:
	_verbose = verbose


func mark_completed(scenario_id: String) -> void:
	var completed = _load()
	if scenario_id not in completed:
		completed.append(scenario_id)
		_save(completed)
		if _verbose:
			_verbose.info("quest", "🏆", "Scenario completed: " + scenario_id)


func is_completed(scenario_id: String) -> bool:
	var completed = _load()
	return scenario_id in completed


func get_all() -> Array[String]:
	return _load() as Array[String]


func clear_all() -> void:
	_save([])
	if _verbose:
		_verbose.info("quest", "🔄", "Cleared all completed scenarios")


func _load() -> Array:
	var path = SaveStore.SAVE_DIR + FILE_NAME
	if not FileAccess.file_exists(path):
		return []
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var json = JSON.parse_string(json_string)
		if json and json is Array:
			return json
	return []


func _save(completed: Array) -> void:
	var path = SaveStore.SAVE_DIR + FILE_NAME
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(completed)
		file.store_string(json_string)
