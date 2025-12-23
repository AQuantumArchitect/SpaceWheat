class_name ScenarioRegistry
extends Node

const SCENARIOS_DIR = "res://Scenarios/"
const COMPLETED_SCENARIOS_FILE = "user://" + "saves/completed_scenarios.json"

# Scenario metadata (loaded once at startup)
var scenario_list: Array[ScenarioMetadata] = []
var _completed_scenarios: Array[String] = []

func _ready():
	_load_all_scenarios()
	_load_completed_scenarios()

func _load_all_scenarios():
	"""Scan Scenarios/ directory and load all .metadata.tres files"""
	scenario_list.clear()

	var dir = DirAccess.open(SCENARIOS_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".metadata.tres"):
				var metadata_path = SCENARIOS_DIR + file_name
				if ResourceLoader.exists(metadata_path):
					var meta = load(metadata_path) as ScenarioMetadata
					if meta:
						scenario_list.append(meta)
			file_name = dir.get_next()

	# Sort by difficulty, then name
	scenario_list.sort_custom(_sort_by_difficulty)

func get_all_scenarios() -> Array[ScenarioMetadata]:
	"""Return all scenarios (regardless of unlock status)"""
	return scenario_list.duplicate()

func get_unlocked_scenarios() -> Array[ScenarioMetadata]:
	"""Return scenarios available to player (respects prerequisites and unlock status)"""
	var unlocked = []
	for meta in scenario_list:
		if _is_scenario_unlocked(meta):
			unlocked.append(meta)
	return unlocked

func get_scenario_by_id(scenario_id: String) -> ScenarioMetadata:
	"""Find scenario metadata by ID"""
	for meta in scenario_list:
		if meta.scenario_id == scenario_id:
			return meta
	return null

func load_scenario_gamestate(scenario_id: String) -> GameState:
	"""Load the GameState resource for a scenario"""
	var gamestate_path = SCENARIOS_DIR + scenario_id + ".tres"
	if ResourceLoader.exists(gamestate_path):
		return load(gamestate_path) as GameState
	return null

func is_scenario_completed(scenario_id: String) -> bool:
	"""Check if player has completed this scenario"""
	return scenario_id in _completed_scenarios

func mark_scenario_completed(scenario_id: String):
	"""Mark scenario as completed (unlocks next scenarios)"""
	if scenario_id not in _completed_scenarios:
		_completed_scenarios.append(scenario_id)
		_save_completed_scenarios()

func clear_completed_scenarios():
	"""Clear all completed scenarios (for testing/reset)"""
	_completed_scenarios.clear()
	_save_completed_scenarios()

func _is_scenario_unlocked(meta: ScenarioMetadata) -> bool:
	"""Check if prerequisites are met and scenario is unlocked by default"""
	if meta.unlocked_by_default:
		return true

	# Check if all prerequisite scenarios are completed
	for prereq_id in meta.prerequisites:
		if not is_scenario_completed(prereq_id):
			return false
	return true

func _sort_by_difficulty(a: ScenarioMetadata, b: ScenarioMetadata) -> bool:
	"""Sort scenarios by difficulty order, then alphabetically"""
	const DIFFICULTY_ORDER = ["tutorial", "easy", "normal", "hard", "expert", "sandbox"]
	var a_idx = DIFFICULTY_ORDER.find(a.difficulty)
	var b_idx = DIFFICULTY_ORDER.find(b.difficulty)

	# Handle unknown difficulties (put at end)
	if a_idx == -1:
		a_idx = DIFFICULTY_ORDER.size()
	if b_idx == -1:
		b_idx = DIFFICULTY_ORDER.size()

	if a_idx != b_idx:
		return a_idx < b_idx
	return a.display_name < b.display_name

func _load_completed_scenarios():
	"""Load completed scenarios from save file"""
	_completed_scenarios.clear()

	if FileAccess.file_exists(COMPLETED_SCENARIOS_FILE):
		var file = FileAccess.open(COMPLETED_SCENARIOS_FILE, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			var json = JSON.parse_string(json_string)
			if json and json is Array:
				_completed_scenarios = json as Array[String]

func _save_completed_scenarios():
	"""Save completed scenarios to save file"""
	# Ensure save directory exists
	var save_dir = "user://saves"
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_absolute(save_dir)

	var file = FileAccess.open(COMPLETED_SCENARIOS_FILE, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(_completed_scenarios)
		file.store_string(json_string)
