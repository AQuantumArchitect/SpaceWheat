extends Node

# Access autoload safely (avoids compile-time errors)
@onready var _verbose = get_node("/root/VerboseConfig")

## GameStateManager - Singleton for save/load operations
## Handles 3 save slots, scenarios, and state capture/restore

const GameState = preload("res://Core/GameState/GameState.gd")
const GameStateSerializer = preload("res://Core/GameState/GameStateSerializer.gd")
const SaveStore = preload("res://Core/GameState/SaveStore.gd")
const VocabularyEvolution = preload("res://Core/QuantumSubstrate/VocabularyEvolution.gd")
const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")
const QuantumRigorConfig = preload("res://Core/GameState/QuantumRigorConfig.gd")
const Farm = preload("res://Core/Farm.gd")

# Signals
signal emoji_discovered(emoji: String)
signal pair_discovered(north: String, south: String)
signal factions_unlocked(factions: Array)
signal farm_ready(farm: Node, state: GameState)

# Current state
var current_state: GameState = null
var current_scenario_id: String = "default"
var last_saved_slot: int = -1   # Track most recent save
var last_active_slot: int = -1  # Track most recently saved OR loaded slot
var pending_restart_slot: int = -1  # Set before reload_current_scene(); FarmView reads+clears it

# Removed: active_farm_view (never used)

# Direct reference to Farm simulation (Phase 1: Simulation-only saves)
var active_farm = null

# PERSISTENT VOCABULARY EVOLUTION - Travels with player across farms/biomes
var vocabulary_evolution: VocabularyEvolution = null

# Serializer for capture/apply (keeps GSM orchestration-only)
var _serializer: GameStateSerializer = null

# Milk autosave
const MILK_EMOJI := "🍼"
const MILK_AUTOSAVE_SLOT := 2
var _milk_autosave_done := false
var last_milk_autosave_path: String = ""


func _ready():
	# Ensure save directory exists
	SaveStore.ensure_save_dir()
	_verbose.info("save", "💾", "GameStateManager ready - Save dir: " + SaveStore.SAVE_DIR)

	# Initialize quantum rigor configuration (singleton)
	if not QuantumRigorConfig.instance:
		var config = QuantumRigorConfig.new()
		_verbose.info("quantum", "⚛️", "QuantumRigorConfig initialized: %s" % config.mode_description())

	# Initialize persistent vocabulary evolution system
	if not vocabulary_evolution:
		vocabulary_evolution = VocabularyEvolution.new()
		vocabulary_evolution._ready()
		add_child(vocabulary_evolution)
		_verbose.info("quest", "📚", "Persistent VocabularyEvolution initialized")


## ============================================================================
## SESSION BOOTSTRAP (GSM owns Farm lifecycle)
## ============================================================================

func start_session(load_slot: int = -1, scenario_id: String = "default", reset_farm: bool = true) -> Node:
	"""Start or load a session and ensure Farm exists (headless-safe).

	Order:
	1) Load or create GameState
	2) Ensure Farm exists (create if missing)
	3) Wait for Farm _ready
	4) Apply state to Farm
	"""
	var state: GameState = null
	if load_slot >= 0:
		state = load_game_state(load_slot)
		if not state:
			state = _build_new_session_state(scenario_id)
	else:
		state = _build_new_session_state(scenario_id)

	current_state = state
	current_scenario_id = state.scenario_id if state else scenario_id

	if reset_farm and active_farm:
		active_farm.queue_free()
		active_farm = null

	if not active_farm:
		active_farm = _create_farm()

	if active_farm:
		await _await_farm_ready(active_farm)

	if state:
		apply_state_to_game(state)

	farm_ready.emit(active_farm, state)
	return active_farm


func _build_new_session_state(scenario_id: String) -> GameState:
	"""Create a fresh session state honoring explicit scenario IDs."""
	var requested = scenario_id.strip_edges()
	if requested != "" and requested != "default":
		var scenario_path = SaveStore.SCENARIO_DIR + requested + ".tres"
		if ResourceLoader.exists(scenario_path):
			var scenario_state = SaveStore.load_scenario(requested)
			if scenario_state:
				return _hydrate_state_defaults(scenario_state)
		_verbose.warn("save", "⚠", "Scenario '%s' not found, falling back to new game template" % requested)
	return _hydrate_state_defaults(load_new_game_template())


func _create_farm() -> Node:
	"""Create and attach a Farm node to the scene tree."""
	var farm = Farm.new()
	farm.name = "Farm"
	var root = get_tree().root if get_tree() else null
	if root:
		# Avoid add_child during parent setup (boot-time safety)
		root.call_deferred("add_child", farm)
	else:
		add_child(farm)
	return farm


func _await_farm_ready(farm: Node) -> void:
	"""Wait until Farm is in-tree and fully initialized."""
	var attempts = 0
	while farm and not farm.is_inside_tree() and attempts < 10:
		await get_tree().process_frame
		attempts += 1
	if farm and farm.has_signal("ready"):
		# Avoid hanging if Farm is already ready
		if not farm.is_node_ready():
			await farm.ready
	var tries = 0
	while farm and (farm.get("economy") == null or farm.get("grid") == null) and tries < 10:
		await get_tree().process_frame
		tries += 1


## Player Vocabulary Discovery
## Farm-owned vocabulary is canonical; GameState keeps a persisted copy.

func discover_pair(north: String, south: String) -> void:
	"""Player learns a vocabulary pair (plantable qubit axis)

	This forwards to the active Farm (canonical vocab owner).

	Called when:
	- Quest completion grants paired vocabulary
	- Starting the game with initial pairs

	Args:
		north: The North pole emoji (from faction)
		south: The South pole emoji (rolled from physics)
	"""
	# Get emojis before adding (for checking newly accessible factions)
	var old_emojis = _get_player_vocab_emojis()

	# Prefer farm-owned vocabulary
	var farm = active_farm if "active_farm" in self else null
	var added = false
	if farm and farm.has_method("discover_pair"):
		added = farm.discover_pair(north, south)
	elif current_state:
		# Legacy fallback (should be avoided)
		for pair in current_state.known_pairs:
			if pair.get("north") == north and pair.get("south") == south:
				return  # Already known
		current_state.known_pairs.append({"north": north, "south": south})
		added = true

	if not added:
		return

	# Emit signals for each new emoji
	if north not in old_emojis:
		emit_signal("emoji_discovered", north)
	if south not in old_emojis:
		emit_signal("emoji_discovered", south)

	emit_signal("pair_discovered", north, south)
	var pair_count = _get_player_vocab_pairs().size()
	_verbose.info("quest", "📖", "Discovered pair: %s/%s (vocabulary: %d pairs)" % [north, south, pair_count])

	# Keep persisted state in sync (legacy readers)
	if current_state:
		current_state.known_pairs = _get_player_vocab_pairs()
		current_state.known_emojis = _get_player_vocab_emojis()

	# Check if new emojis unlock factions
	var new_emojis = _get_player_vocab_emojis()
	for emoji in [north, south]:
		if emoji not in old_emojis:
			var newly_accessible = _check_newly_accessible_factions(emoji, old_emojis, new_emojis)
			if newly_accessible.size() > 0:
				emit_signal("factions_unlocked", newly_accessible)
				_verbose.info("quest", "🔓", "Unlocked %d new faction(s)!" % newly_accessible.size())
				for faction in newly_accessible:
					var sig = faction.get("sig", [])
					_verbose.info("quest", "-", "%s %s" % ["".join(sig.slice(0, 3)), faction.get("name", "?")])

	# Autosave on first milk discovery.
	if MILK_EMOJI in new_emojis and MILK_EMOJI not in old_emojis:
		_handle_milk_autosave(north, south)


func _handle_milk_autosave(north: String, south: String) -> void:
	if _milk_autosave_done:
		return
	if not active_farm:
		_verbose.warn("save", "🥛", "Milk autosave skipped: no active farm")
		return
	var state = capture_state_from_game()
	var slot_result = SaveStore.save_state(state, MILK_AUTOSAVE_SLOT)
	if slot_result == OK:
		last_saved_slot = MILK_AUTOSAVE_SLOT
	else:
		_verbose.warn("save", "🥛", "Milk vocab autosave failed (slot %d)" % (MILK_AUTOSAVE_SLOT + 1))

	var stamp = "%s_%s" % [Time.get_datetime_string_from_system().replace(":", ""), str(Time.get_ticks_msec())]
	var milk_path = SaveStore.SAVE_DIR + "milk_autosave_" + stamp + ".tres"
	var file_result = SaveStore.save_state_to_path(state, milk_path)
	if file_result == OK:
		_milk_autosave_done = true
		last_milk_autosave_path = milk_path
		_verbose.info("save", "🥛", "Milk vocab autosave → slot %d (%s) [%s/%s]" % [
			MILK_AUTOSAVE_SLOT + 1, SaveStore.get_save_path(MILK_AUTOSAVE_SLOT), north, south
		])
		_verbose.info("save", "🥛", "Milk vocab autosave file → %s" % milk_path)
	else:
		_verbose.warn("save", "🥛", "Milk vocab autosave file failed: %s" % milk_path)


func _check_newly_accessible_factions(new_emoji: String, old_emojis: Array, new_emojis: Array) -> Array:
	"""Find factions that just became accessible due to vocabulary overlap

	A faction is "newly accessible" if:
	- It had NO vocabulary overlap before (inaccessible)
	- It has vocabulary overlap now (accessible)
	"""
	var newly_accessible = []

	for faction in FactionDatabase.ALL_FACTIONS:
		var faction_vocab = FactionDatabase.get_faction_vocabulary(faction)

		# Check if faction was inaccessible before
		var old_overlap = FactionDatabase.get_vocabulary_overlap(faction_vocab.all, old_emojis)
		var new_overlap = FactionDatabase.get_vocabulary_overlap(faction_vocab.all, new_emojis)

		if old_overlap.is_empty() and not new_overlap.is_empty():
			newly_accessible.append(faction)

	return newly_accessible


func get_accessible_factions() -> Array:
	"""Get all factions that have vocabulary overlap with player (can receive quests)"""
	var accessible = []
	var known_emojis = _get_player_vocab_emojis()

	for faction in FactionDatabase.ALL_FACTIONS:
		var faction_vocab = FactionDatabase.get_faction_vocabulary(faction)
		var overlap = FactionDatabase.get_vocabulary_overlap(faction_vocab.all, known_emojis)

		if not overlap.is_empty():
			accessible.append(faction)

	return accessible


func _get_player_vocab_pairs() -> Array:
	"""Return canonical player vocab pairs (farm-owned preferred)."""
	if "active_farm" in self and active_farm and active_farm.has_method("get_known_pairs"):
		return active_farm.get_known_pairs()
	if current_state:
		return current_state.known_pairs.duplicate(true)
	return []


func _get_player_vocab_emojis() -> Array:
	"""Return canonical player vocab emojis (farm-owned preferred)."""
	if "active_farm" in self and active_farm and active_farm.has_method("get_known_emojis"):
		return active_farm.get_known_emojis()
	if current_state and current_state.has_method("get_known_emojis"):
		return current_state.get_known_emojis()
	return []


## New Game / Scenarios

func new_game(scenario_id: String = "default") -> GameState:
	"""Start new game by loading a scenario template"""
	_verbose.info("quest", "🎮", "Starting new game with scenario: " + scenario_id)
	current_scenario_id = scenario_id

	current_state = SaveStore.load_scenario(scenario_id)
	if current_state and current_state.scenario_id == "":
		current_state.scenario_id = scenario_id
	current_state = _hydrate_state_defaults(current_state)

	current_state.save_timestamp = Time.get_unix_time_from_system()
	current_state.game_time = 0.0
	return current_state


## Save Operations

func save_game(slot: int) -> bool:
	"""Save current game state to slot (0-2)"""
	if not active_farm:
		push_error("No active game to save!")
		return false
	
	# Capture current state from live game
	var state = capture_state_from_game()
	
	# Save to disk
	var result = SaveStore.save_state(state, slot)
	if result == OK:
		last_saved_slot = slot
		last_active_slot = slot
		_verbose.info("save", "💾", "Game saved to slot " + str(slot + 1) + ": " + SaveStore.get_save_path(slot))
		return true
	else:
		push_error("Failed to save game to slot " + str(slot))
		return false


func save_game_to_path(path: String) -> bool:
	"""Save current game state to an explicit path (user://, res://, or absolute)."""
	if not active_farm:
		push_error("No active game to save!")
		return false

	if path.strip_edges() == "":
		push_error("Invalid save path")
		return false

	var state = capture_state_from_game()
	var result = SaveStore.save_state_to_path(state, path)
	if result == OK:
		_verbose.info("save", "💾", "Game saved to path: " + path)
		return true
	push_error("Failed to save game to path: " + path)
	return false


func get_save_path(slot: int) -> String:
	"""Get file path for save slot"""
	return SaveStore.get_save_path(slot)


func save_exists(slot: int) -> bool:
	"""Check if save file exists in slot"""
	return SaveStore.save_exists(slot)


func get_save_info(slot: int) -> Dictionary:
	"""Get save file info for display in load menu"""
	return SaveStore.get_save_info(slot)


## Load Operations

func load_new_game_template() -> GameState:
	"""Load new game template from new_game_easy.tres"""
	var user_path = SaveStore.SAVE_DIR + SaveStore.NEW_GAME_TEMPLATE
	var project_path = SaveStore.SCENARIO_DIR + SaveStore.NEW_GAME_TEMPLATE
	var has_user = FileAccess.file_exists(user_path)
	var has_project = ResourceLoader.exists(project_path)
	var state = SaveStore.load_new_game_template()
	if has_user:
		_verbose.info("save", "📂", "Loaded new game template from: " + user_path)
	elif has_project:
		_verbose.info("save", "📂", "Loaded new game template from: " + project_path)
	else:
		_verbose.warn("save", "⚠", "new_game_easy.tres not found, creating blank state")
	return _hydrate_state_defaults(state)


func load_game_state(slot: int) -> GameState:
	"""Load game state from slot (returns state, doesn't apply it)"""
	var state = SaveStore.load_state(slot)
	if state:
		state = _hydrate_state_defaults(state)
		_verbose.info("save", "📂", "Loaded save from slot " + str(slot + 1))
		return state
	_verbose.info("save", "⚠", "No save file in slot " + str(slot + 1))
	return null


func load_game_state_by_alias(alias_filename: String) -> GameState:
	"""Load game state from emoji alias filename/path (returns state, doesn't apply it)."""
	var state = SaveStore.load_state_by_emoji_alias(alias_filename)
	if state:
		state = _hydrate_state_defaults(state)
		_verbose.info("save", "📂", "Loaded save alias: " + alias_filename)
		return state
	_verbose.info("save", "⚠", "No save found for alias: " + alias_filename)
	return null


func load_and_apply(slot: int) -> bool:
	"""Load game state from slot and apply it to active game"""
	var state = load_game_state(slot)
	if not state:
		return false

	if not active_farm:
		# Create farm if missing (headless-safe load)
		active_farm = _create_farm()
		# Defer apply until Farm has initialized
		call_deferred("_apply_loaded_state_deferred", state)
		current_state = state
		current_scenario_id = state.scenario_id
		return true

	current_state = state
	current_scenario_id = state.scenario_id
	last_active_slot = slot
	apply_state_to_game(state)
	return true


func load_and_apply_emoji_alias(alias_filename: String) -> bool:
	"""Load game state from emoji alias filename/path and apply it to active game."""
	var state = load_game_state_by_alias(alias_filename)
	if not state:
		return false

	if not active_farm:
		active_farm = _create_farm()
		call_deferred("_apply_loaded_state_deferred", state)
		current_state = state
		current_scenario_id = state.scenario_id
		return true

	current_state = state
	current_scenario_id = state.scenario_id
	apply_state_to_game(state)
	return true


func _apply_loaded_state_deferred(state: GameState) -> void:
	if not active_farm or not state:
		return
	await _await_farm_ready(active_farm)
	apply_state_to_game(state)


func request_restart() -> bool:
	"""Set pending_restart_slot to the most recently active slot and reload the scene.

	Prefers last_active_slot (most recently saved OR loaded). Falls back to scanning
	all slots by timestamp. If no saves exist, reboots to a fresh new game (slot -1).
	FarmView reads pending_restart_slot in _ready() and passes it to boot_core().
	"""
	var slot = last_active_slot

	if slot < 0:
		# Fall back to most-recently-saved slot by timestamp scan
		var latest_timestamp = 0.0
		for s in range(SaveStore.NUM_SAVE_SLOTS):
			if not SaveStore.save_exists(s):
				continue
			var state = SaveStore.load_state(s)
			if state and state.save_timestamp > latest_timestamp:
				latest_timestamp = state.save_timestamp
				slot = s

	pending_restart_slot = slot  # -1 = fresh game, >=0 = load that slot
	_verbose.info("save", "🔄", "Restart requested → slot %d" % pending_restart_slot)

	# Full scene reload; FarmView._ready() picks up pending_restart_slot
	var tree = Engine.get_main_loop()
	if tree and tree.has_method("reload_current_scene"):
		if tree.paused:
			tree.paused = false
		tree.reload_current_scene()
		return true
	return false


## State Capture/Restore (delegates to serializer)

func _get_serializer() -> GameStateSerializer:
	if not _serializer:
		_serializer = GameStateSerializer.new()
	_serializer.set_verbose(_verbose)
	_serializer.set_vocabulary_evolution(vocabulary_evolution)
	_serializer.set_player_vocab(get_node_or_null("/root/PlayerVocabulary"))
	return _serializer


func capture_state_from_game() -> GameState:
	var serializer = _get_serializer()
	return serializer.capture_state_from_farm(active_farm, current_state, current_scenario_id)


func apply_state_to_game(state: GameState):
	var serializer = _get_serializer()
	serializer.apply_state_to_farm(state, active_farm)


## Scenario Completion Tracking

func mark_scenario_completed(scenario_id: String):
	"""Mark scenario as completed (unlocks next scenarios)"""
	var completed = _load_completed_scenarios()
	if scenario_id not in completed:
		completed.append(scenario_id)
		_save_completed_scenarios(completed)
		_verbose.info("quest", "🏆", "Scenario completed: " + scenario_id)

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
	_verbose.info("quest", "🔄", "Cleared all completed scenarios")

func _load_completed_scenarios() -> Array:
	"""Load completed scenarios from save file"""
	var completed_file = SaveStore.SAVE_DIR + "completed_scenarios.json"
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
	var completed_file = SaveStore.SAVE_DIR + "completed_scenarios.json"
	var file = FileAccess.open(completed_file, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(completed)
		file.store_string(json_string)

## Restart

func restart_current_scenario():
	"""Restart by reloading current scenario (not scene reload!)"""
	_verbose.info("quest", "🔄", "Restarting scenario: " + current_scenario_id)
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


func get_active_farm() -> Node:
	"""Return the active Farm node. Canonical accessor for overlays and tools."""
	return active_farm


func get_icon_registry():
	"""Get IconRegistry autoload (used by affinity/vocab pairing helpers)."""
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		return tree.root.get_node_or_null("/root/IconRegistry")
	return null


func _hydrate_state_defaults(state: GameState) -> GameState:
	if not state:
		return null
	if state.has_method("ensure_balance_workbench_defaults"):
		state.ensure_balance_workbench_defaults()
	if state.has_method("ensure_policy_state_defaults"):
		state.ensure_policy_state_defaults()
	return state
