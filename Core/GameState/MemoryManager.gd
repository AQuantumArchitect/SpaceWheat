## MemoryManager - CLEAN ARCHITECTURE FOR SAVE/LOAD
##
## Single responsibility: Save/Load GameState objects (pure data)
## NO dependencies on UI, FarmView, or simulation
##
## Architecture:
## - GameState = Source of truth (serializable data)
## - Simulation = Reads/writes GameState
## - UI = Observes GameState changes via signals
##
## Usage:
##   var state = MemoryManager.new_game("default")
##   var farm = Farm.new()
##   farm.apply_game_state(state)
##   # ... simulate ...
##   MemoryManager.save_game(state, 0)
##   # ... later ...
##   var loaded = MemoryManager.load_game(0)
##   farm.apply_game_state(loaded)

extends Node

const GameState = preload("res://Core/GameState/GameState.gd")

# Save configuration
const SAVE_DIR = "user://saves/"
const NUM_SAVE_SLOTS = 3
const SCENARIO_DIR = "res://Scenarios/"

# Signals for UI layer to observe
signal game_state_created(state: GameState)
signal game_state_saved(state: GameState, slot: int)
signal game_state_loaded(state: GameState, slot: int)
signal game_state_changed(state: GameState)

# Current working state (for convenience, not authoritative)
var current_state: GameState = null


func _ready():
	# Ensure save directory exists
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")
	print("💾 MemoryManager ready - Save dir: " + SAVE_DIR)


## CREATE NEW GAME STATE
## Returns a fresh GameState from scenario or default
func new_game(scenario_id: String = "default") -> GameState:
	"""Create new game state from scenario template"""
	print("🎮 Creating new game: " + scenario_id)

	var state: GameState

	# Try to load scenario file, fall back to default
	var scenario_path = SCENARIO_DIR + scenario_id + ".tres"
	if ResourceLoader.exists(scenario_path):
		state = ResourceLoader.load(scenario_path).duplicate()
		print("✓ Loaded scenario from: " + scenario_path)
	else:
		print("⚠ Scenario not found, creating default state")
		state = GameState.new()
		state.scenario_id = scenario_id

	state.save_timestamp = Time.get_unix_time_from_system()
	state.game_time = 0.0

	current_state = state
	game_state_created.emit(state)
	return state


## SAVE GAME STATE
## Saves a GameState object to disk
func save_game(state: GameState, slot: int) -> bool:
	"""Save GameState to slot (0-2)"""
	if slot < 0 or slot >= NUM_SAVE_SLOTS:
		push_error("Invalid save slot: " + str(slot))
		return false

	if not state:
		push_error("No game state to save!")
		return false

	# Update metadata
	state.save_timestamp = Time.get_unix_time_from_system()

	# Save to disk
	var path = get_save_path(slot)
	var result = ResourceSaver.save(state, path)

	if result == OK:
		print("💾 Game saved to slot " + str(slot + 1) + ": " + path)
		print("   Credits: %d | Plots: %d | Time: %.1fs" % [
			state.credits,
			state.plots.size(),
			state.game_time
		])
		current_state = state
		game_state_saved.emit(state, slot)
		return true
	else:
		push_error("Failed to save game to slot " + str(slot))
		return false


## LOAD GAME STATE
## Loads a GameState object from disk (doesn't apply it)
func load_game(slot: int) -> GameState:
	"""Load GameState from slot (returns state, doesn't apply it)"""
	if slot < 0 or slot >= NUM_SAVE_SLOTS:
		push_error("Invalid save slot: " + str(slot))
		return null

	var path = get_save_path(slot)
	if not FileAccess.file_exists(path):
		print("⚠ No save file in slot " + str(slot + 1))
		return null

	var state = ResourceLoader.load(path) as GameState
	if state:
		print("📂 Loaded save from slot " + str(slot + 1))
		print("   Credits: %d | Plots: %d | Time: %.1fs" % [
			state.credits,
			state.plots.size(),
			state.game_time
		])
		current_state = state
		game_state_loaded.emit(state, slot)
		return state
	else:
		push_error("Failed to load save from slot " + str(slot))
		return null


## SAVE INFO
## Get metadata about a save slot without loading full state
func get_save_info(slot: int) -> Dictionary:
	"""Get save slot info for display in UI"""
	if not save_exists(slot):
		return {"exists": false, "slot": slot}

	var state = load_game(slot)
	if not state:
		return {"exists": false, "slot": slot}

	return {
		"exists": true,
		"slot": slot,
		"display_name": state.get_save_display_name(),
		"scenario": state.scenario_id,
		"credits": state.credits,
		"goal_index": state.current_goal_index,
		"playtime": state.game_time,
		"grid_size": "%dx%d" % [state.grid_width, state.grid_height]
	}


## SAVE EXISTS
## Check if save file exists
func save_exists(slot: int) -> bool:
	"""Check if save file exists in slot"""
	return FileAccess.file_exists(get_save_path(slot))


## GET SAVE PATH
## Get file path for save slot
func get_save_path(slot: int) -> String:
	"""Get file path for save slot"""
	return SAVE_DIR + "save_slot_" + str(slot) + ".tres"


## LIST ALL SAVES
## Get info about all save slots
func get_all_saves() -> Array[Dictionary]:
	"""Get info about all save slots"""
	var saves: Array[Dictionary] = []
	for slot in range(NUM_SAVE_SLOTS):
		saves.append(get_save_info(slot))
	return saves
