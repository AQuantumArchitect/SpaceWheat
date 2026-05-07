class_name SaveLoadCoordinator
extends RefCounted

## SaveLoadCoordinator — orchestrates save/load above SaveStore.
##
## SaveStore handles filesystem IO; this layer handles the boot-aware policy:
##   - mid-session loads tear down via SessionLifecycle and re-boot via BootManager
##   - pre-session loads use the lighter headless path
##   - peek/save/find_best_slot are pure orchestration over SaveStore
##
## Held as a RefCounted member of GameStateManager (constructor-injected with
## a back-reference to GSM for state access).

const GameState = preload("res://Core/GameState/GameState.gd")
const SaveStore = preload("res://Core/GameState/SaveStore.gd")
const InstrumentLocator = preload("res://Core/Instrumentation/InstrumentLocator.gd")

var _gsm: Node = null
var _verbose = null


func _init(gsm: Node = null, verbose = null) -> void:
	_gsm = gsm
	_verbose = verbose


func new_game(scenario_id: String = SaveStore.DEFAULT_SCENARIO_ID) -> GameState:
	if _verbose:
		_verbose.info("quest", "🎮", "Starting new game with scenario: " + scenario_id)
	_gsm.current_scenario_id = scenario_id

	_gsm.current_state = SaveStore.load_scenario(scenario_id)
	if not _gsm.current_state:
		push_error("SaveLoadCoordinator: scenario '%s' could not be loaded" % scenario_id)
		return null
	if _gsm.current_state and _gsm.current_state.scenario_id == "":
		_gsm.current_state.scenario_id = scenario_id
	_gsm.current_state = _gsm._hydrate_state_defaults(_gsm.current_state)

	_gsm.current_state.save_timestamp = Time.get_unix_time_from_system()
	_gsm.current_state.game_time = 0.0
	return _gsm.current_state


func save_game(slot: int) -> bool:
	if not _gsm.active_farm:
		push_error("SaveLoadCoordinator: no active game to save")
		return false
	var state = _gsm.capture_state_from_game()
	var result = SaveStore.save_state(state, slot)
	if result == OK:
		_gsm.last_active_slot = slot
		if _verbose:
			_verbose.info("save", "💾", "Game saved to slot " + str(slot + 1) + ": " + SaveStore.get_save_path(slot))
		return true
	push_error("SaveLoadCoordinator: failed to save to slot " + str(slot))
	return false


func save_game_to_path(path: String) -> bool:
	if not _gsm.active_farm:
		push_error("SaveLoadCoordinator: no active game to save")
		return false
	if path.strip_edges() == "":
		push_error("SaveLoadCoordinator: invalid save path")
		return false
	var state = _gsm.capture_state_from_game()
	var result = SaveStore.save_state_to_path(state, path)
	if result == OK:
		if _verbose:
			_verbose.info("save", "💾", "Game saved to path: " + path)
		return true
	push_error("SaveLoadCoordinator: failed to save to path: " + path)
	return false


func peek_save_slot(slot: int) -> Dictionary:
	var info := SaveStore.get_save_info(slot)
	if info.get("exists", false):
		info["summary"] = str(info.get("display_name", "saved"))
	return info


func load_new_game_template() -> GameState:
	var project_path = SaveStore.SCENARIO_DIR + SaveStore.NEW_GAME_TEMPLATE
	var has_project = ResourceLoader.exists(project_path)
	var state = SaveStore.load_new_game_template()
	if state and has_project and _verbose:
		_verbose.info("save", "📂", "Loaded new game template from: " + project_path)
	elif _verbose:
		_verbose.warn("save", "⚠", "Default scenario not found: " + project_path)
	return _gsm._hydrate_state_defaults(state)


func load_game_state(slot: int) -> GameState:
	var state = SaveStore.load_state(slot)
	if state:
		state = _gsm._hydrate_state_defaults(state)
		if _verbose:
			_verbose.info("save", "📂", "Loaded save from slot " + str(slot + 1))
		return state
	if _verbose:
		_verbose.info("save", "⚠", "No save file in slot " + str(slot + 1))
	return null


func load_game_state_by_path(save_path: String) -> GameState:
	var state = SaveStore.load_state_by_path(save_path)
	if state:
		state = _gsm._hydrate_state_defaults(state)
		if _verbose:
			_verbose.info("save", "📂", "Loaded save path: " + save_path)
		return state
	if _verbose:
		_verbose.info("save", "⚠", "No save found for path: " + save_path)
	return null


func load_and_apply(slot: int) -> bool:
	# Mid-session: tear the live session down and re-boot via BootManager so
	# autoloads + active_farm don't carry stale state across the boundary.
	# Pre-session: lighter headless path used by tools and tests.
	if _gsm.active_farm:
		var boot_mgr = InstrumentLocator.resolve_root_node(_gsm, "/root/BootManager")
		if boot_mgr == null:
			push_warning("SaveLoadCoordinator.load_and_apply: BootManager autoload missing")
			return false
		var peek := peek_save_slot(slot)
		var scenario_for_boot: String = str(_gsm.current_scenario_id)
		if peek and bool(peek.get("exists", false)):
			scenario_for_boot = str(peek.get("scenario", _gsm.current_scenario_id))
		await _gsm.session_lifecycle.shutdown_session(true, false)
		var farm = await boot_mgr.boot_core(slot, scenario_for_boot, false, null)
		if farm:
			_gsm.last_active_slot = slot
		return farm != null

	# Pre-session with AppRoot: route through the proper boot pipeline so
	# GameRoot, BootManager, and PlayerShell all participate. restart_into()
	# is safe at the title screen (shutdown_session is a no-op with no farm).
	var tree = Engine.get_main_loop()
	var app_roots = tree.get_nodes_in_group("app_root") if tree else []
	if not app_roots.is_empty():
		_gsm.last_active_slot = slot
		await _gsm.session_lifecycle.restart_into(slot)
		return true

	# Headless / test path (no AppRoot, no active_farm): direct apply.
	var state = load_game_state(slot)
	if not state:
		return false
	await _attach_state_to_fresh_farm(state)
	_gsm.last_active_slot = slot
	return true


func load_and_apply_path(save_path: String) -> bool:
	if _gsm.active_farm:
		var state_pre := load_game_state_by_path(save_path)
		if not state_pre:
			return false
		await _gsm.session_lifecycle.shutdown_session(true, false)
		await _attach_state_to_fresh_farm(state_pre)
		return true

	var state = load_game_state_by_path(save_path)
	if not state:
		return false
	await _attach_state_to_fresh_farm(state)
	return true


func _attach_state_to_fresh_farm(state: GameState) -> void:
	# Pre-session / headless apply path: spin up a Farm, await full state
	# restore (bath await + ρ + viz_cache), THEN return so the caller's
	# `bool` reflects actual readiness instead of "we kicked off the work."
	# Mid-session loads with an existing farm go through boot_core above.
	_gsm.active_farm = _gsm.session_lifecycle.create_farm()
	_gsm.current_state = state
	_gsm.current_scenario_id = state.scenario_id
	await _gsm._apply_loaded_state_deferred(state)


func find_best_save_slot() -> int:
	if _gsm.last_active_slot >= 0:
		return _gsm.last_active_slot
	var best_slot := -1
	var best_time := 0.0
	for s in range(SaveStore.NUM_SAVE_SLOTS):
		if not SaveStore.save_exists(s):
			continue
		var state = SaveStore.load_state(s)
		if state and state.save_timestamp > best_time:
			best_time = state.save_timestamp
			best_slot = s
	return best_slot
