class_name ScenarioLedger
extends RefCounted

## ScenarioLedger — persistence for completed-scenario flags.
##
## Reads/writes user://saves/completed_scenarios.json. Held as a RefCounted
## member of GameStateManager.


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
	# One JSON-load authority (slop knot #7); a missing/unreadable ledger is an
	# empty ledger, exactly as before. Malformed files are loud via the loader.
	var res: Dictionary = preload("res://Core/Config/JsonFileLoader.gd").load_json(
		path, {"context": "ScenarioLedger", "required": false})
	if res.ok and res.data is Array:
		return res.data
	return []


func _save(completed: Array) -> void:
	var path = SaveStore.SAVE_DIR + FILE_NAME
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(completed)
		file.store_string(json_string)
