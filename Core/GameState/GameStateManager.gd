extends Node

# Access autoload safely (avoids compile-time errors)
@onready var _verbose = InstrumentLocator.resolve_verbose_config(self)

## GameStateManager — autoload that holds shared session state and wires up
## the four sub-modules (SessionLifecycle, SaveLoadCoordinator, PlayerProgress,
## ScenarioLedger). Sub-modules read/write GSM fields through the back-reference
## passed at construction time; external callers reach into the relevant
## sub-module directly (e.g. `gsm.save_load.save_game(slot)`).
##
## Shared signals live here so any listener can subscribe at one address; the
## actual emitters live in the sub-modules.

const GameState = preload("res://Core/GameState/GameState.gd")
const GameStateSerializer = preload("res://Core/GameState/GameStateSerializer.gd")
const SaveStore = preload("res://Core/GameState/SaveStore.gd")
const QuantumRigorConfig = preload("res://Core/GameState/QuantumRigorConfig.gd")
const InstrumentLocator = preload("res://Core/Instrumentation/InstrumentLocator.gd")
const SessionLifecycleClass = preload("res://Core/GameState/SessionLifecycle.gd")
const PlayerProgressClass = preload("res://Core/GameState/PlayerProgress.gd")
const SaveLoadCoordinatorClass = preload("res://Core/GameState/SaveLoadCoordinator.gd")
const ScenarioLedgerClass = preload("res://Core/GameState/ScenarioLedger.gd")

# Session phase enum re-exported here for back-compat (callers reference
# GameStateManager.SessionPhase). Actual values mirror SessionLifecycle.SessionPhase.
enum SessionPhase { IDLE, BOOTING, RUNNING, RESTARTING, QUITTING }

# Signals
signal emoji_discovered(emoji: String)
signal pair_discovered(north: String, south: String)
signal pair_removed(north: String, south: String)
signal factions_unlocked(factions: Array)
signal farm_ready(farm: Node, state: GameState)
## Emitted before any session teardown begins so listeners can show UI / teardown viz.
signal session_ending(next_phase: int)

# Shared session state (read by sub-modules through the back-reference; read by
# external callers via `gsm.<field>`).
var current_state: GameState = null
var current_scenario_id: String = SaveStore.DEFAULT_SCENARIO_ID
var last_active_slot: int = -1  # Most recent slot saved OR loaded — drives "continue" / restart targeting.
var session_load_slot: int = -1  # Slot loaded at session start; -1 = fresh game. Used by EscapeMenu to avoid clobbering the boot slot during restart autosave.
var pending_boot = null  # SessionLifecycle.BootRequest; initialized in _ready()
var active_farm = null
var phase: int = SessionPhase.IDLE

# Sub-modules (constructed in _ready, accessed by external callers as `gsm.session_lifecycle.X` etc).
var session_lifecycle: SessionLifecycleClass = null
var player_progress: PlayerProgressClass = null
var save_load: SaveLoadCoordinatorClass = null
var scenario_ledger: ScenarioLedgerClass = null

# Serializer for capture/apply (lazy; kept on GSM since both capture and apply
# orchestrate across multiple sub-modules + the FarmView).
var _serializer: GameStateSerializer = null

# Milk autosave bookkeeping (PlayerProgress.handle_milk_autosave reads/writes these).
var _milk_autosave_done := false
var last_milk_autosave_path: String = ""


func _ready():
	session_lifecycle = SessionLifecycleClass.new(self, _verbose)
	add_child(session_lifecycle)
	player_progress = PlayerProgressClass.new(self, _verbose)
	add_child(player_progress)
	save_load = SaveLoadCoordinatorClass.new(self, _verbose)
	scenario_ledger = ScenarioLedgerClass.new(_verbose)
	pending_boot = SessionLifecycleClass.BootRequest.new()
	SaveStore.ensure_save_dir()
	_verbose.info("save", "💾", "GameStateManager ready - Save dir: " + SaveStore.SAVE_DIR)
	# QuantumRigorConfig is session-scope and created lazily on first read
	# (QuantumRigorConfig.instance). Do not pre-warm here — that fires before
	# the title screen.


# Canonical "continue / restart from the latest touched slot" lookup. Returns
# last_active_slot (most recent save OR load this session) if valid, else falls
# back to a scan of the newest save file on disk, else -1 (no saves → fresh).
func find_best_save_slot() -> int:
	return save_load.find_best_save_slot()


# Called by SaveLoadCoordinator after a fresh-Farm headless apply path: waits
# for the new Farm to be ready, then awaits the full state restore so the
# caller's bool reflects actual readiness.
func _apply_loaded_state_deferred(state: GameState) -> void:
	if not active_farm or not state:
		return
	await session_lifecycle.await_farm_ready(active_farm)
	await apply_state_to_game(state)


# Capture/apply own a back-reference to the lazy serializer + the FarmView
# refresh, so they live here rather than on a sub-module.
func _get_serializer() -> GameStateSerializer:
	if not _serializer:
		_serializer = GameStateSerializer.new()
	_serializer.set_verbose(_verbose)
	return _serializer


func capture_state_from_game() -> GameState:
	var serializer = _get_serializer()
	return serializer.capture_state_from_farm(active_farm, current_state, current_scenario_id)


func apply_state_to_game(state: GameState) -> void:
	# Coroutine: the serializer awaits a process_frame for bath-less biomes
	# during restore. UI refresh must run AFTER restore completes, otherwise
	# plots render against half-restored ρ.
	var serializer = _get_serializer()
	await serializer.apply_state_to_farm(state, active_farm)
	var farm_view = InstrumentLocator.resolve_farm_view(self, active_farm)
	if farm_view and farm_view.has_method("refresh_runtime_views"):
		farm_view.refresh_runtime_views()


# Canonical Farm accessor for overlays and tools.
func get_active_farm() -> Node:
	return active_farm


# EmojiPhysicsRegistry autoload accessor (used by affinity/icon pairing helpers).
func get_icon_registry():
	return InstrumentLocator.resolve_icon_registry_main_loop()


func _hydrate_state_defaults(state: GameState) -> GameState:
	if not state:
		return null
	var migrated := false
	if state.has_method("ensure_balance_workbench_defaults"):
		migrated = state.ensure_balance_workbench_defaults()
	if migrated and state.farm_variable_graph_jsonl is Array:
		# Strip stale tuning.* overrides baked with old default values.
		# Tuning is now owned by the schema defaults; non-tuning overrides (costs, quests) are kept.
		var filtered: Array[String] = []
		for line in state.farm_variable_graph_jsonl:
			var parsed = JSON.parse_string(str(line))
			if parsed is Dictionary and str(parsed.get("path", "")).begins_with("tuning."):
				continue
			filtered.append(str(line))
		state.farm_variable_graph_jsonl = filtered
	if state.has_method("ensure_policy_state_defaults"):
		state.ensure_policy_state_defaults()
	# Ensure every session starts with at least 1 🍼 (reap resource)
	if state.all_emoji_credits.get("🍼", 0) < 1:
		state.all_emoji_credits["🍼"] = 1
	return state
