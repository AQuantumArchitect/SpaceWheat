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
		_gsm.phase = SessionLifecycle.SessionPhase.BOOTING
		var boot_mgr = (Engine.get_main_loop().root.get_node_or_null("/root/BootManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
		if boot_mgr == null:
			_gsm.phase = SessionLifecycle.SessionPhase.IDLE
			push_warning("SaveLoadCoordinator.load_and_apply: BootManager autoload missing")
			return false
		var peek := peek_save_slot(slot)
		var scenario_for_boot: String = str(_gsm.current_scenario_id)
		if peek and bool(peek.get("exists", false)):
			scenario_for_boot = str(peek.get("scenario", _gsm.current_scenario_id))
		await _gsm.session_lifecycle.shutdown_session(true, false)
		var boot_request := {
			"slot": slot,
			"scenario_id": scenario_for_boot,
			"headless": false,
		}
		var farm = await boot_mgr.boot_session(boot_request, null)
		if farm:
			_gsm.last_active_slot = slot
			_gsm.phase = SessionLifecycle.SessionPhase.RUNNING
		else:
			_gsm.phase = SessionLifecycle.SessionPhase.IDLE
		return farm != null

	# Pre-session with AppRoot: route through the proper boot pipeline so
	# GameRoot, BootManager, and PlayerShell all participate. restart_into()
	# is safe at the title screen (shutdown_session is a no-op with no farm).
	var tree = Engine.get_main_loop()
	var app_roots = tree.get_nodes_in_group("app_root") if tree else []
	if not app_roots.is_empty():
		_gsm.phase = SessionLifecycle.SessionPhase.BOOTING
		_gsm.last_active_slot = slot
		await _gsm.session_lifecycle.restart_into(slot)
		_gsm.phase = SessionLifecycle.SessionPhase.RUNNING
		return true

	# Headless / test path (no AppRoot, no active_farm): direct apply.
	_gsm.phase = SessionLifecycle.SessionPhase.BOOTING
	var state = load_game_state(slot)
	if not state:
		_gsm.phase = SessionLifecycle.SessionPhase.IDLE
		return false
	await _attach_state_to_fresh_farm(state)
	_gsm.last_active_slot = slot
	_gsm.phase = SessionLifecycle.SessionPhase.RUNNING
	return true


func load_and_apply_path(save_path: String) -> bool:
	if _gsm.active_farm:
		_gsm.phase = SessionLifecycle.SessionPhase.BOOTING
		var state_pre := load_game_state_by_path(save_path)
		if not state_pre:
			_gsm.phase = SessionLifecycle.SessionPhase.IDLE
			return false
		await _gsm.session_lifecycle.shutdown_session(true, false)
		await _attach_state_to_fresh_farm(state_pre)
		_gsm.phase = SessionLifecycle.SessionPhase.RUNNING
		return true

	_gsm.phase = SessionLifecycle.SessionPhase.BOOTING
	var state = load_game_state_by_path(save_path)
	if not state:
		_gsm.phase = SessionLifecycle.SessionPhase.IDLE
		return false
	await _attach_state_to_fresh_farm(state)
	_gsm.phase = SessionLifecycle.SessionPhase.RUNNING
	return true


func _attach_state_to_fresh_farm(state: GameState) -> void:
	# Pre-session / headless apply path: spin up a Farm, await full state
	# restore (bath await + ρ + viz_cache), THEN return so the caller's
	# `bool` reflects actual readiness instead of "we kicked off the work."
	# Mid-session loads with an existing farm go through boot_core above.
	if _verbose and state and state.known_icons is Array:
		_verbose.info("save", "📖", "Loaded save signature has %d known icon(s)" % state.known_icons.size())
	_gsm.active_farm = _gsm.session_lifecycle.create_farm()
	_gsm.current_state = state
	_gsm.current_scenario_id = state.scenario_id
	await _gsm.session_lifecycle.await_farm_ready(_gsm.active_farm)
	var tree = Engine.get_main_loop() if Engine.get_main_loop() is SceneTree else null
	var boot_mgr = tree.root.get_node_or_null("/root/BootManager") if tree and tree.root else null
	if boot_mgr and boot_mgr.has_method("boot_initial_biomes"):
		var biome_boot = await boot_mgr.boot_initial_biomes(_gsm.active_farm, state)
		if not bool(biome_boot.get("success", false)):
			push_warning("SaveLoadCoordinator: initial biome boot failed during load: %s" % biome_boot.get("message", "unknown error"))
		elif _gsm.active_farm and _gsm.active_farm.has_method("finalize_initial_biome_boot"):
			_gsm.active_farm.finalize_initial_biome_boot()
	await _gsm._apply_loaded_state_deferred(state)
	if _gsm.active_farm and _gsm.active_farm.has_method("set_known_icons") and state.known_icons is Array:
		_gsm.active_farm.set_known_icons(state.known_icons)
	if _gsm.active_farm and "active_icon_slots" in _gsm.active_farm and state.active_icon_slots is Array:
		_gsm.active_farm.active_icon_slots = (state.active_icon_slots as Array).duplicate()


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
