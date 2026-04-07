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
##   var state = MemoryManager.new_game(SaveStore.DEFAULT_SCENARIO_ID)
##   # ... simulate ...
##   MemoryManager.save_game(state, 0)
##   # ... later ...
##   var loaded = MemoryManager.load_game(0)

extends Node

const GameState = preload("res://Core/GameState/GameState.gd")
const SaveStore = preload("res://Core/GameState/SaveStore.gd")

# Signals for UI layer to observe
signal game_state_created(state: GameState)
signal game_state_saved(state: GameState, slot: int)
signal game_state_loaded(state: GameState, slot: int)
signal game_state_changed(state: GameState)

# Current working state (for convenience, not authoritative)
var current_state: GameState = null


func _ready():
	# Ensure save directory exists
	SaveStore.ensure_save_dir()
	print("💾 MemoryManager ready - Save dir: " + SaveStore.SAVE_DIR)


## CREATE NEW GAME STATE
## Returns a fresh GameState from scenario or default
func new_game(scenario_id: String = SaveStore.DEFAULT_SCENARIO_ID) -> GameState:
	"""Create new game state from scenario template"""
	print("🎮 Creating new game: " + scenario_id)

	var state: GameState = null
	if scenario_id.strip_edges() == "" or scenario_id == SaveStore.DEFAULT_SCENARIO_ID:
		state = SaveStore.load_new_game_template()
	else:
		state = SaveStore.load_scenario(scenario_id)
		if state and state.scenario_id == "":
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
	if not state:
		push_error("No game state to save!")
		return false

	# Update metadata
	state.save_timestamp = Time.get_unix_time_from_system()

	# Save to disk
	var result = SaveStore.save_state(state, slot)
	if result == OK:
		var money = state.all_emoji_credits.get("💰", 0) if state.all_emoji_credits else 0
		print("💾 Game saved to slot " + str(slot + 1) + ": " + SaveStore.get_save_path(slot))
		print("   💰: %d | Plots: %d | Time: %.1fs" % [
			money,
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
	var state = SaveStore.load_state(slot)
	if state:
		var money = state.all_emoji_credits.get("💰", 0) if state.all_emoji_credits else 0
		print("📂 Loaded save from slot " + str(slot + 1))
		print("   💰: %d | Plots: %d | Time: %.1fs" % [
			money,
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
	return SaveStore.get_save_info(slot)


## SAVE EXISTS
## Check if save file exists
func save_exists(slot: int) -> bool:
	"""Check if save file exists in slot"""
	return SaveStore.save_exists(slot)


## GET SAVE PATH
## Get file path for save slot
func get_save_path(slot: int) -> String:
	"""Get file path for save slot"""
	return SaveStore.get_save_path(slot)


## LIST ALL SAVES
## Get info about all save slots
func get_all_saves() -> Array[Dictionary]:
	"""Get info about all save slots"""
	var saves: Array[Dictionary] = []
	for slot in range(SaveStore.NUM_SAVE_SLOTS):
		saves.append(get_save_info(slot))
	return saves
