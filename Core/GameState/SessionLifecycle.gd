class_name SessionLifecycle
extends Node

## SessionLifecycle — owns session start/shutdown/restart for GameStateManager.
##
## Held as a child Node on the GameStateManager autoload. State (phase,
## pending_boot, session_load_slot, current_state, current_scenario_id, active_farm)
## remains on GSM so existing back-references keep working; this node carries
## the operations. Mirrors the BootManager → SessionLoader/WorldBuilder/RuntimeMount
## split.
##
## Signals farm_ready and session_ending live on GSM (forwarded) so external
## listeners don't have to care about the split.


enum SessionPhase { IDLE, BOOTING, RUNNING, RESTARTING, QUITTING }

class BootRequest:
	var slot: int = -1
	var requested: bool = false
	var scenario_id: String = "new_game_easy"

	func clear() -> void:
		slot = -1
		requested = false
		scenario_id = "new_game_easy"


var _gsm: Node = null
var _verbose = null


func _init(gsm: Node = null, verbose = null) -> void:
	_gsm = gsm
	_verbose = verbose
	name = "SessionLifecycle"


func ensure_pending_boot() -> BootRequest:
	if _gsm.pending_boot == null:
		_gsm.pending_boot = BootRequest.new()
	return _gsm.pending_boot


func start_session(load_slot: int = -1, scenario_id: String = SaveStore.DEFAULT_SCENARIO_ID, reset_farm: bool = true, farm_parent: Node = null, apply_state_after_create: bool = true) -> Node:
	# Phase contract: enter BOOTING on first work, leave as RUNNING on success
	# or back to IDLE on failure. This is the only place the constructive
	# transitions live; destructive transitions (RESTARTING, QUITTING) live in
	# request_restart / request_application_quit.
	_gsm.phase = SessionPhase.BOOTING

	var state: GameState = null
	if load_slot >= 0:
		state = _gsm.save_load.load_game_state(load_slot)
		if not state:
			# The slot is empty, unreadable, or pre-beta (refused by the
			# compatibility floor). The shutdown already ran by the time we
			# get here on the restart path — stranding the player in a dead
			# scene is worse than any fallback, so boot a fresh default run
			# and say so.
			push_warning("SessionLifecycle: slot %d missing or incompatible — starting a fresh '%s' instead" % [
				load_slot, SaveStore.DEFAULT_SCENARIO_ID])
			load_slot = -1
			_gsm.session_load_slot = -1
			_gsm.last_active_slot = -1
			state = build_new_session_state(SaveStore.DEFAULT_SCENARIO_ID)
			if not state:
				push_error("SessionLifecycle: fallback scenario '%s' could not be loaded" % SaveStore.DEFAULT_SCENARIO_ID)
				_gsm.phase = SessionPhase.IDLE
				return null
	else:
		state = build_new_session_state(scenario_id)
		if not state:
			push_error("SessionLifecycle: scenario '%s' could not be loaded" % scenario_id)
			_gsm.phase = SessionPhase.IDLE
			return null

	_gsm.current_state = state
	_gsm.current_scenario_id = state.scenario_id if state else scenario_id
	_gsm.session_load_slot = load_slot

	if reset_farm and _gsm.active_farm:
		var old_farm = _gsm.active_farm
		_gsm.active_farm = null
		if is_instance_valid(old_farm):
			old_farm.queue_free()
			var tree = get_tree()
			if tree:
				await tree.process_frame
				await tree.process_frame

	if not _gsm.active_farm:
		_gsm.active_farm = create_farm(farm_parent)

	var farm = _gsm.active_farm
	if farm:
		await await_farm_ready(farm)
	if farm == null or not is_instance_valid(farm):
		_gsm.phase = SessionPhase.IDLE
		return null

	if apply_state_after_create:
		await complete_session_boot(farm)

	_gsm.phase = SessionPhase.RUNNING
	return farm


func complete_session_boot(farm: Node = null) -> void:
	# Coroutine: apply_state_to_game awaits the biome restore. farm_ready
	# must NOT fire until restore completes — UI listeners refresh on the
	# signal, and refreshing against half-restored ρ leaves plot tiles
	# bound to stale Bloch snapshots.
	if farm:
		_gsm.active_farm = farm
	if _gsm.current_state:
		await _gsm.apply_state_to_game(_gsm.current_state)
	_gsm.session_baseline = _capture_session_baseline(_gsm.active_farm)
	_gsm.farm_ready.emit(_gsm.active_farm, _gsm.current_state)


func _capture_session_baseline(farm: Node) -> Dictionary:
	# Session-start snapshot the quit summary diffs against. Wallet + fired
	# flags are the only fields that persist across sessions; runtime counters
	# (completed_quests) start empty each session and need no baseline.
	if farm == null or not is_instance_valid(farm):
		return {}
	var wallet: Dictionary = {}
	var economy = farm.get("economy")
	if economy != null and economy.get("emoji_credits") is Dictionary:
		wallet = economy.emoji_credits.duplicate()
	var flags: Dictionary = {}
	if "story_flags_fired" in farm and farm.story_flags_fired is Dictionary:
		flags = farm.story_flags_fired.duplicate()
	return {
		"wallet": wallet,
		"flags": flags,
		"start_ms": Time.get_ticks_msec(),
	}


func build_new_session_state(scenario_id: String) -> GameState:
	var requested = scenario_id.strip_edges()
	if requested == "":
		requested = SaveStore.DEFAULT_SCENARIO_ID
	var scenario_state = SaveStore.load_scenario(requested)
	if not scenario_state:
		return null
	return _gsm._hydrate_state_defaults(scenario_state)


func create_farm(parent: Node = null) -> Node:
	var farm = Farm.new()
	farm.name = "Farm"
	if parent:
		if parent.is_inside_tree():
			parent.add_child(farm)
		else:
			parent.call_deferred("add_child", farm)
		return farm
	var root = get_tree().root if get_tree() else null
	if root:
		root.call_deferred("add_child", farm)
	else:
		_gsm.add_child(farm)
	return farm


func await_farm_ready(farm: Node) -> void:
	var attempts = 0
	while farm and not farm.is_inside_tree() and attempts < 10:
		await get_tree().process_frame
		attempts += 1
	if farm and farm.has_signal("ready"):
		if not farm.is_node_ready():
			await farm.ready
	var tries = 0
	while farm and (farm.get("economy") == null or farm.get("grid") == null) and tries < 10:
		await get_tree().process_frame
		tries += 1


func shutdown_session(reset_singletons: bool = true, quick: bool = false) -> void:
	var farm = _gsm.active_farm
	_gsm.active_farm = null

	if reset_singletons:
		reset_runtime_singletons()

	if farm and is_instance_valid(farm):
		farm.set_physics_process(false)
		farm.set_process(false)
		var batcher = farm.get("biome_evolution_batcher")
		if batcher != null:
			if quick:
				if batcher.has_method("abort_for_quit"):
					batcher.abort_for_quit()
				else:
					if "lookahead_enabled" in batcher:
						batcher.lookahead_enabled = false
					if "_engine_ready" in batcher:
						batcher._engine_ready = false
				farm.set("biome_evolution_batcher", null)
			elif batcher.has_method("cleanup"):
				batcher.cleanup()

	var tree = get_tree()
	if tree and tree.current_scene == farm:
		tree.current_scene = null

	if farm and is_instance_valid(farm):
		farm.queue_free()

	if tree:
		await tree.process_frame
		await tree.process_frame


func request_application_quit(reset_singletons: bool = true) -> void:
	if _gsm.phase == SessionPhase.QUITTING:
		return
	_gsm.phase = SessionPhase.QUITTING
	_gsm.session_ending.emit(SessionPhase.QUITTING)

	start_force_quit_timer(4.0)

	await shutdown_session(reset_singletons, true)

	var tree = get_tree()
	if tree:
		await tree.process_frame
		var music = get_node_or_null("/root/MusicManager")
		if music and music.has_method("reset"):
			music.reset()
		await tree.process_frame
		tree.quit()


func start_force_quit_timer(delay_sec: float) -> void:
	var timer = Timer.new()
	timer.name = "ForceQuitTimer"
	timer.wait_time = delay_sec
	timer.one_shot = true
	timer.process_callback = Timer.TIMER_PROCESS_IDLE
	timer.timeout.connect(func():
		if _gsm.phase == SessionPhase.QUITTING:
			push_warning("SessionLifecycle: force-quitting after %.1fs timeout (shutdown hung)" % delay_sec)
			get_tree().quit()
	)
	add_child(timer)
	timer.start()


func reset_runtime_singletons() -> void:
	# The single place that knows what needs resetting between sessions.
	_gsm._milk_autosave_done = false
	_gsm.last_milk_autosave_path = ""
	_gsm.session_baseline = {}

	var boot_mgr = get_node_or_null("/root/BootManager")
	if boot_mgr and boot_mgr.has_method("reset"):
		boot_mgr.reset()

	var abm = get_node_or_null("/root/ActiveBiomeManager")
	if abm and abm.has_method("reset"):
		abm.reset()

	var obs = get_node_or_null("/root/ObservationFrame")
	if obs and obs.has_method("reset"):
		obs.reset()

	var music = get_node_or_null("/root/MusicManager")
	if music and music.has_method("reset"):
		music.reset()

	var act = get_node_or_null("/root/ActionChainTracker")
	if act and act.has_method("reset"):
		act.reset()

	var sfx = get_node_or_null("/root/SFXRegistry")
	if sfx and sfx.has_method("reset"):
		sfx.reset()

	var story_engine = get_node_or_null("/root/StoryEngine")
	if story_engine and story_engine.has_method("reset"):
		story_engine.reset()

	# Quest offers/actives are session state; the next session regenerates
	# them from persisted truth (tutorial_seen, story_flags_fired, known_icons)
	# via connect_to_farm → maybe_start_tutorial + the StoryEngine re-offer
	# path. Without this, a mid-session path-load inherits the previous
	# campaign's board — a stale tutorial offer sat on every loaded
	# checkpoint's Arc tab (leg L2i).
	var qm = InstrumentLocator.resolve_quest_manager(self)
	if qm and qm.has_method("clear_all_quests"):
		qm.clear_all_quests()

	var shell = InstrumentLocator.resolve_player_shell(self)
	if shell:
		if "overlay_manager" in shell and shell.overlay_manager and shell.overlay_manager.has_method("reset"):
			shell.overlay_manager.reset()
		if "ui_context_controller" in shell and shell.ui_context_controller and shell.ui_context_controller.has_method("reset"):
			shell.ui_context_controller.reset()
		if "snapshot_service" in shell and shell.snapshot_service and shell.snapshot_service.has_method("reset"):
			shell.snapshot_service.reset()


func request_restart() -> void:
	if _gsm.phase == SessionPhase.RESTARTING or _gsm.phase == SessionPhase.QUITTING:
		return
	# Restart pulls from the most recent touched slot (saved OR loaded), not
	# the session-start checkpoint — so iterating from an old save you just
	# loaded still goes back to that old save, not the slot you booted from.
	var target_slot: int = _gsm.find_best_save_slot() if _gsm.has_method("find_best_save_slot") else _gsm.session_load_slot
	if _verbose:
		_verbose.info("save", "🔄", "Restart requested → slot=%d (last touched)" % target_slot)
	_gsm.session_ending.emit(SessionPhase.RESTARTING)
	await restart_into(target_slot)


func request_fresh_restart(_reset_progress: bool = true, scenario_id: String = "") -> void:
	if _gsm.phase == SessionPhase.RESTARTING or _gsm.phase == SessionPhase.QUITTING:
		return
	_gsm.last_active_slot = -1

	var sid = scenario_id.strip_edges()
	if sid != "":
		_gsm.current_scenario_id = sid

	if _verbose:
		_verbose.info("save", "🔄", "Fresh restart requested (%s)" % _gsm.current_scenario_id)
	_gsm.session_ending.emit(SessionPhase.RESTARTING)
	await restart_into(-1)


func restart_into(slot: int) -> void:
	# Single restart path: proper shutdown → set pending boot → reload scene.
	_gsm.phase = SessionPhase.RESTARTING
	await shutdown_session(true, false)

	var scenario = _gsm.current_scenario_id if _gsm.current_scenario_id != "" else SaveStore.DEFAULT_SCENARIO_ID
	_gsm.session_load_slot = slot
	var pb = ensure_pending_boot()
	pb.slot = slot
	pb.requested = true
	pb.scenario_id = scenario

	var tree = Engine.get_main_loop()
	if tree:
		if tree.paused:
			tree.paused = false
		var app_roots = tree.get_nodes_in_group("app_root")
		if app_roots.size() > 0:
			var app_root = app_roots[0]
			if app_root and app_root.has_method("restart_from_pending_boot"):
				app_root.restart_from_pending_boot()
				return
		tree.change_scene_to_file("res://scenes/Main.tscn")
