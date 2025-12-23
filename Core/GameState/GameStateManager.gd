extends Node

## GameStateManager - Singleton for save/load operations
## Handles 3 save slots, scenarios, and state capture/restore

const GameState = preload("res://Core/GameState/GameState.gd")
const VocabularyEvolution = preload("res://Core/QuantumSubstrate/VocabularyEvolution.gd")

# Save configuration
const SAVE_DIR = "user://saves/"
const NUM_SAVE_SLOTS = 3
const SCENARIO_DIR = "res://Scenarios/"

# Current state
var current_state: GameState = null
var current_scenario_id: String = "default"
var last_saved_slot: int = -1  # Track most recent save for "Reload Last Save"

# Reference to active game (set by FarmView)
var active_farm_view = null

# PERSISTENT VOCABULARY EVOLUTION - Travels with player across farms/biomes
var vocabulary_evolution: VocabularyEvolution = null


func _ready():
	# Ensure save directory exists
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")
	print("💾 GameStateManager ready - Save dir: " + SAVE_DIR)

	# Initialize persistent vocabulary evolution system
	if not vocabulary_evolution:
		vocabulary_evolution = VocabularyEvolution.new()
		vocabulary_evolution._ready()
		add_child(vocabulary_evolution)
		print("   📚 Persistent VocabularyEvolution initialized")


## New Game / Scenarios

func new_game(scenario_id: String = "default") -> GameState:
	"""Start new game by loading a scenario template"""
	print("🎮 Starting new game with scenario: " + scenario_id)
	current_scenario_id = scenario_id
	
	# Try to load scenario file, fall back to default state
	var scenario_path = SCENARIO_DIR + scenario_id + ".tres"
	if ResourceLoader.exists(scenario_path):
		current_state = ResourceLoader.load(scenario_path).duplicate()
		print("✓ Loaded scenario from: " + scenario_path)
	else:
		print("⚠ Scenario not found, using default state")
		current_state = GameState.new()
		current_state.scenario_id = scenario_id
	
	current_state.save_timestamp = Time.get_unix_time_from_system()
	current_state.game_time = 0.0
	return current_state


## Save Operations

func save_game(slot: int) -> bool:
	"""Save current game state to slot (0-2)"""
	if slot < 0 or slot >= NUM_SAVE_SLOTS:
		push_error("Invalid save slot: " + str(slot))
		return false
	
	if not active_farm_view:
		push_error("No active game to save!")
		return false
	
	# Capture current state from live game
	var state = capture_state_from_game()
	
	# Save to disk
	var path = get_save_path(slot)
	var result = ResourceSaver.save(state, path)
	
	if result == OK:
		last_saved_slot = slot
		print("💾 Game saved to slot " + str(slot + 1) + ": " + path)
		return true
	else:
		push_error("Failed to save game to slot " + str(slot))
		return false


func get_save_path(slot: int) -> String:
	"""Get file path for save slot"""
	return SAVE_DIR + "save_slot_" + str(slot) + ".tres"


func save_exists(slot: int) -> bool:
	"""Check if save file exists in slot"""
	return FileAccess.file_exists(get_save_path(slot))


func get_save_info(slot: int) -> Dictionary:
	"""Get save file info for display in load menu"""
	if not save_exists(slot):
		return {"exists": false, "slot": slot}
	
	var state = load_game_state(slot)
	if not state:
		return {"exists": false, "slot": slot}
	
	return {
		"exists": true,
		"slot": slot,
		"display_name": state.get_save_display_name(),
		"scenario": state.scenario_id,
		"credits": state.credits,
		"goal_index": state.current_goal_index,
		"playtime": state.game_time
	}


## Load Operations

func load_game_state(slot: int) -> GameState:
	"""Load game state from slot (returns state, doesn't apply it)"""
	if slot < 0 or slot >= NUM_SAVE_SLOTS:
		push_error("Invalid save slot: " + str(slot))
		return null
	
	var path = get_save_path(slot)
	if not FileAccess.file_exists(path):
		print("⚠ No save file in slot " + str(slot + 1))
		return null
	
	var state = ResourceLoader.load(path)
	if state:
		print("📂 Loaded save from slot " + str(slot + 1))
		return state
	else:
		push_error("Failed to load save from slot " + str(slot))
		return null


func load_and_apply(slot: int) -> bool:
	"""Load game state from slot and apply it to active game"""
	var state = load_game_state(slot)
	if not state:
		return false

	if not active_farm_view:
		push_error("No active game to apply state to!")
		return false

	apply_state_to_game(state)
	current_state = state
	current_scenario_id = state.scenario_id
	# NOTE: Don't update last_saved_slot here - only update on actual save
	# This ensures "Reload Last Save" reloads the last SAVED file, not last LOADED file
	return true


func reload_last_save() -> bool:
	"""Reload the most recently saved game by scanning all slots for latest timestamp"""
	var latest_slot = -1
	var latest_timestamp = 0.0

	# Scan all save slots to find the most recent
	for slot in range(NUM_SAVE_SLOTS):
		if not save_exists(slot):
			continue

		var state = load_game_state(slot)
		if state and state.save_timestamp > latest_timestamp:
			latest_timestamp = state.save_timestamp
			latest_slot = slot

	# No saves found
	if latest_slot < 0:
		print("⚠ No saves found to reload")
		return false

	print("🔄 Reloading most recent save from slot " + str(latest_slot + 1) + " (saved at " + str(latest_timestamp) + ")")
	return load_and_apply(latest_slot)


## State Capture/Restore

func capture_state_from_game() -> GameState:
	"""Capture current game state from active Farm (from FarmView)

	Refactored for Farm/Biome/Qubit architecture:
	- Economy: All resource inventories
	- Plots: Configuration, planted/measured/entanglement state
	- Goals: Progress
	- Icons: Activation levels
	- Time: Biome elapsed time + sun/moon phase
	- Quantum State: Complete biome_state tree (sun qubit, icon qubits, emoji qubits)
	"""
	var state = GameState.new()
	var fv = active_farm_view

	# Get reference to the Farm (pure simulation object)
	var farm = fv.farm  # Should be accessible from FarmView
	if not farm:
		push_error("Farm not found in FarmView - cannot capture state")
		return state

	# Meta
	state.scenario_id = current_scenario_id
	state.save_timestamp = Time.get_unix_time_from_system()
	state.game_time = current_state.game_time if current_state else 0.0

	# Grid Dimensions (from Farm)
	state.grid_width = farm.grid_width
	state.grid_height = farm.grid_height

	# Economy (from Farm.economy)
	var economy = farm.economy
	state.credits = economy.credits
	state.wheat_inventory = economy.wheat_inventory
	state.labor_inventory = economy.labor_inventory
	state.flour_inventory = economy.flour_inventory
	state.flower_inventory = economy.flower_inventory
	state.mushroom_inventory = economy.mushroom_inventory if economy.has_method("get_mushroom_inventory") else 0
	state.detritus_inventory = economy.detritus_inventory if economy.has_method("get_detritus_inventory") else 0
	state.imperium_resource = economy.imperium_resource if economy.has_method("get_imperium_resource") else 0
	state.tributes_paid = economy.total_tributes_paid if economy.has_method("get_tributes_paid") else 0
	state.tributes_failed = economy.total_tributes_failed if economy.has_method("get_tributes_failed") else 0

	# Plots (from Farm.grid)
	state.plots.clear()
	var grid = farm.grid
	for y in range(state.grid_height):
		for x in range(state.grid_width):
			var pos = Vector2i(x, y)
			var plot = grid.get_plot(pos)

			# Capture plot configuration and measurement state
			# NOTE: Quantum state details (theta, phi, radius, energy, berry_phase) are NOT saved
			#       They regenerate when plots are planted from the biome environment
			var plot_data = {
				"position": pos,
				"type": plot.plot_type,
				"is_planted": plot.is_planted,
				"has_been_measured": plot.has_been_measured,
				"theta_frozen": plot.theta_frozen,
				"entangled_with": plot.entangled_plots.keys()
			}
			state.plots.append(plot_data)

	# Goals
	var goals = farm.goals
	state.current_goal_index = goals.current_goal_index
	state.completed_goals.clear()
	for i in range(goals.goals_completed.size()):
		if goals.goals_completed[i]:
			state.completed_goals.append(goals.goals[i]["id"])

	# Icons (from FarmView UI layer)
	state.biotic_activation = fv.biotic_icon.active_strength if fv.has_node("BioticIcon") else 0.0
	state.chaos_activation = fv.chaos_icon.active_strength if fv.has_node("ChaosIcon") else 0.0
	state.imperium_activation = fv.imperium_icon.active_strength if fv.has_node("ImperiumIcon") else 0.0

	# Time - Biome elapsed time and celestial state
	var biome = farm.biome
	state.time_elapsed = biome.time_elapsed
	if biome.sun_qubit:
		state.sun_theta = biome.sun_qubit.theta
		state.sun_phi = biome.sun_qubit.phi

	# Capture Biome quantum state tree (mirrors architecture)
	state.biome_state = {
		"time_elapsed": biome.time_elapsed,
		"sun_qubit": {},
		"wheat_icon": {},
		"mushroom_icon": {},
		"quantum_states": []
	}

	# Sun qubit
	if biome.sun_qubit:
		state.biome_state["sun_qubit"] = {
			"theta": biome.sun_qubit.theta,
			"phi": biome.sun_qubit.phi,
			"radius": biome.sun_qubit.radius,
			"energy": biome.sun_qubit.energy
		}

	# Wheat icon (may be Dictionary or WheatIcon)
	if biome.wheat_icon:
		if biome.wheat_icon is Dictionary and biome.wheat_icon.has("internal_qubit"):
			var iq = biome.wheat_icon["internal_qubit"]
			state.biome_state["wheat_icon"] = {
				"theta": iq.theta,
				"phi": iq.phi,
				"radius": iq.radius,
				"energy": iq.energy
			}
		elif not (biome.wheat_icon is Dictionary) and biome.wheat_icon.has("internal_qubit"):
			var iq = biome.wheat_icon.internal_qubit
			state.biome_state["wheat_icon"] = {
				"theta": iq.theta,
				"phi": iq.phi,
				"radius": iq.radius,
				"energy": iq.energy
			}

	# Mushroom icon (may be Dictionary or MushroomIcon)
	if biome.mushroom_icon:
		if biome.mushroom_icon is Dictionary and biome.mushroom_icon.has("internal_qubit"):
			var iq = biome.mushroom_icon["internal_qubit"]
			state.biome_state["mushroom_icon"] = {
				"theta": iq.theta,
				"phi": iq.phi,
				"radius": iq.radius,
				"energy": iq.energy
			}
		elif not (biome.mushroom_icon is Dictionary) and biome.mushroom_icon.has("internal_qubit"):
			var iq = biome.mushroom_icon.internal_qubit
			state.biome_state["mushroom_icon"] = {
				"theta": iq.theta,
				"phi": iq.phi,
				"radius": iq.radius,
				"energy": iq.energy
			}

	# Quantum states (emoji qubits for each plot)
	for pos in biome.quantum_states.keys():
		var qubit = biome.quantum_states[pos]
		state.biome_state["quantum_states"].append({
			"position": pos,
			"theta": qubit.theta,
			"phi": qubit.phi,
			"radius": qubit.radius,
			"energy": qubit.energy
		})

	# Vocabulary Evolution State (PERSISTED - player's discovered vocabulary travels with them)
	if vocabulary_evolution:
		state.vocabulary_state = vocabulary_evolution.serialize()
		print("   📚 Captured vocabulary: %d discovered, %d evolving" % [
			state.vocabulary_state.get("discovered_vocabulary", []).size(),
			state.vocabulary_state.get("evolving_qubits", []).size()
		])

	# Conspiracy Network NOT saved (dynamic, regenerated each session)

	print("📸 Captured game state: grid=" + str(state.grid_width) + "x" + str(state.grid_height) +
		  ", plots=" + str(state.plots.size()) + ", credits=" + str(state.credits))
	return state


func apply_state_to_game(state: GameState):
	"""Apply loaded state to active Farm (through FarmView)

	Refactored for Farm/Biome/Qubit architecture:
	- Loads economy, plot configuration, goals, time from GameState
	- Restores complete biome quantum state tree (all qubits)
	- UI layer (icons, visuals) updated through FarmView
	"""
	var fv = active_farm_view

	if not fv:
		push_error("No active game to apply state to!")
		return

	var farm = fv.farm
	if not farm:
		push_error("Farm not found in FarmView - cannot apply state")
		return

	print("🔄 Applying game state to farm (" + str(state.grid_width) + "x" + str(state.grid_height) + ")...")

	# Apply Economy (from Farm.economy)
	var economy = farm.economy
	economy.credits = state.credits
	economy.wheat_inventory = state.wheat_inventory
	economy.labor_inventory = state.labor_inventory
	economy.flour_inventory = state.flour_inventory
	economy.flower_inventory = state.flower_inventory
	if economy.has_method("set_mushroom_inventory"):
		economy.set_mushroom_inventory(state.mushroom_inventory)
	if economy.has_method("set_detritus_inventory"):
		economy.set_detritus_inventory(state.detritus_inventory)
	if economy.has_method("set_imperium_resource"):
		economy.set_imperium_resource(state.imperium_resource)
	if economy.has_method("set_tributes"):
		economy.set_tributes(state.tributes_paid, state.tributes_failed)

	# Apply Plot Configuration (from Farm.grid)
	var grid = farm.grid
	for plot_data in state.plots:
		var pos = plot_data["position"]
		var plot = grid.get_plot(pos)

		if plot:
			plot.plot_type = plot_data["type"]
			plot.is_planted = plot_data["is_planted"]

			# Measurement state (collapses quantum superposition)
			plot.has_been_measured = plot_data.get("has_been_measured", false)
			plot.theta_frozen = plot_data.get("theta_frozen", false)

			# Restore entanglement relationships
			plot.entangled_plots.clear()
			for entangled_pos in plot_data.get("entangled_with", []):
				var other_plot = grid.get_plot(entangled_pos)
				if other_plot:
					plot.entangled_plots[other_plot.plot_id] = 1.0

			# IMPORTANT: Quantum state details (theta, phi, radius, energy, berry_phase)
			# are NOT restored - they regenerate from the biome when the plot is replanted.
			# This keeps the save format simple and maintains deterministic behavior through
			# the infrastructure model (entanglement gates persist, qubits regenerate).

	# Apply Goals
	var goals = farm.goals
	goals.current_goal_index = state.current_goal_index
	goals.goals_completed.clear()
	for goal in goals.goals:
		var is_completed = state.completed_goals.has(goal["id"])
		goals.goals_completed.append(is_completed)
		goal["completed"] = is_completed

	# Apply Time/Cycles (to Biome)
	var biome = farm.biome
	biome.time_elapsed = state.time_elapsed
	if biome.sun_qubit:
		biome.sun_qubit.theta = state.sun_theta
		biome.sun_qubit.phi = state.sun_phi

	# Restore Biome quantum state tree
	if state.biome_state:
		var bs = state.biome_state

		# Restore time_elapsed
		biome.time_elapsed = bs.get("time_elapsed", 0.0)

		# Restore sun qubit
		if bs.has("sun_qubit") and biome.sun_qubit:
			var sq = bs["sun_qubit"]
			biome.sun_qubit.theta = sq.get("theta", 0.0)
			biome.sun_qubit.phi = sq.get("phi", 0.0)
			biome.sun_qubit.radius = sq.get("radius", 1.0)
			biome.sun_qubit.energy = sq.get("energy", 1.0)

		# Restore wheat icon (if has internal_qubit)
		if bs.has("wheat_icon") and biome.wheat_icon:
			var wi = bs["wheat_icon"]
			if biome.wheat_icon is Dictionary and biome.wheat_icon.has("internal_qubit"):
				var iq = biome.wheat_icon["internal_qubit"]
				iq.theta = wi.get("theta", PI/4.0)
				iq.phi = wi.get("phi", 0.0)
				iq.radius = wi.get("radius", 1.0)
				iq.energy = wi.get("energy", 1.0)
			elif not (biome.wheat_icon is Dictionary) and biome.wheat_icon.has("internal_qubit"):
				var iq = biome.wheat_icon.internal_qubit
				iq.theta = wi.get("theta", PI/4.0)
				iq.phi = wi.get("phi", 0.0)
				iq.radius = wi.get("radius", 1.0)
				iq.energy = wi.get("energy", 1.0)

		# Restore mushroom icon (if has internal_qubit)
		if bs.has("mushroom_icon") and biome.mushroom_icon:
			var mi = bs["mushroom_icon"]
			if biome.mushroom_icon is Dictionary and biome.mushroom_icon.has("internal_qubit"):
				var iq = biome.mushroom_icon["internal_qubit"]
				iq.theta = mi.get("theta", PI)
				iq.phi = mi.get("phi", 0.0)
				iq.radius = mi.get("radius", 1.0)
				iq.energy = mi.get("energy", 1.0)
			elif not (biome.mushroom_icon is Dictionary) and biome.mushroom_icon.has("internal_qubit"):
				var iq = biome.mushroom_icon.internal_qubit
				iq.theta = mi.get("theta", PI)
				iq.phi = mi.get("phi", 0.0)
				iq.radius = mi.get("radius", 1.0)
				iq.energy = mi.get("energy", 1.0)

		# Restore quantum states (emoji qubits)
		if bs.has("quantum_states"):
			for qubit_data in bs["quantum_states"]:
				var pos = qubit_data["position"]
				if biome.quantum_states.has(pos):
					var qubit = biome.quantum_states[pos]
					qubit.theta = qubit_data.get("theta", PI/2.0)
					qubit.phi = qubit_data.get("phi", 0.0)
					qubit.radius = qubit_data.get("radius", 0.3)
					qubit.energy = qubit_data.get("energy", 0.3)

	# Apply Icon Activation (UI layer - FarmView)
	if fv.has_node("BioticIcon"):
		fv.biotic_icon.set_activation(state.biotic_activation)
	if fv.has_node("ChaosIcon"):
		fv.chaos_icon.set_activation(state.chaos_activation)
	if fv.has_node("ImperiumIcon"):
		fv.imperium_icon.set_activation(state.imperium_activation)

	# Restore Vocabulary Evolution State (PERSISTED - player's discovered vocabulary)
	if vocabulary_evolution and state.vocabulary_state:
		vocabulary_evolution.deserialize(state.vocabulary_state)
		print("   📚 Restored vocabulary evolution from save")

	# Conspiracy Network NOT loaded (dynamic, regenerate each session)

	# Update UI through FarmView
	if fv.has_method("mark_ui_dirty"):
		fv.mark_ui_dirty()
	if fv.has_method("mark_goals_dirty"):
		fv.mark_goals_dirty()
	if fv.has_method("mark_icons_dirty"):
		fv.mark_icons_dirty()

	# Refresh plot tile visuals (fixes appearance after loading)
	if fv.has_method("refresh_all_plot_tiles"):
		fv.refresh_all_plot_tiles()

	print("✓ State applied to farm successfully - quantum states will regenerate from biome")


## Scenario Completion Tracking

func mark_scenario_completed(scenario_id: String):
	"""Mark scenario as completed (unlocks next scenarios)"""
	var completed = _load_completed_scenarios()
	if scenario_id not in completed:
		completed.append(scenario_id)
		_save_completed_scenarios(completed)
		print("🏆 Scenario completed: " + scenario_id)

func is_scenario_completed(scenario_id: String) -> bool:
	"""Check if player has completed this scenario"""
	var completed = _load_completed_scenarios()
	return scenario_id in completed

func get_completed_scenarios() -> Array[String]:
	"""Get list of all completed scenarios"""
	return _load_completed_scenarios() as Array[String]

func clear_completed_scenarios():
	"""Clear all completed scenarios (for testing/reset)"""
	_save_completed_scenarios([])
	print("🔄 Cleared all completed scenarios")

func _load_completed_scenarios() -> Array:
	"""Load completed scenarios from save file"""
	var completed_file = SAVE_DIR + "completed_scenarios.json"
	if not FileAccess.file_exists(completed_file):
		return []

	var file = FileAccess.open(completed_file, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		var json = JSON.parse_string(json_string)
		if json and json is Array:
			return json
	return []

func _save_completed_scenarios(completed: Array):
	"""Save completed scenarios to save file"""
	var completed_file = SAVE_DIR + "completed_scenarios.json"
	var file = FileAccess.open(completed_file, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(completed)
		file.store_string(json_string)

## Restart

func restart_current_scenario():
	"""Restart by reloading current scenario (not scene reload!)"""
	print("🔄 Restarting scenario: " + current_scenario_id)
	var state = new_game(current_scenario_id)
	apply_state_to_game(state)


## Persistent Vocabulary Access

func get_vocabulary_evolution() -> VocabularyEvolution:
	"""Get the persistent vocabulary evolution system

	The vocabulary persists across farm/biome changes and travels with the player.
	This ensures discovered vocabulary remains available even when switching contexts.
	"""
	if not vocabulary_evolution:
		# Safety fallback - should not happen if _ready() was called
		vocabulary_evolution = VocabularyEvolution.new()
		vocabulary_evolution._ready()
		add_child(vocabulary_evolution)

	return vocabulary_evolution
