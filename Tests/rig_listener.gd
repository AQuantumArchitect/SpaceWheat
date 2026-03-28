#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Live rig listener: persists a single game session and executes one queued turn at a time.
## Queue file:   user://rig/queue.jsonl (append-only)
## Result file:  user://rig/results.jsonl (append-only)
##
## Actions supported:
## - open_overlay: {name: "quests"|"vocabulary"|"controls"}
## - offer_quests: {include_reward_resources?: bool, include_market_projection?: bool}
## - accept_offer: {offer_index: int}
## - complete_quest: {quest_id: int}
## - complete_or_claim: {quest_id: int}
## - claim_quest: {quest_id: int}
## - accept_quest: {quest_id: int}
## - lock_offer: {offer_index: int} — pin an offered quest (max 3 locked)
## - unlock_offer: {quest_id: int} — release a locked offer
## - accept_locked: {quest_id: int} — accept a locked offer (locked → active)
## - locked_offers — returns list of locked offers
## - resource_snapshot
## - add_resource: {emoji: String, amount: int}
## - set_resource: {emoji: String, amount: int}
## - resource_mutations: {limit?: int}
## - grid_snapshot
## - biome_positions: {biome: String}
## - active_quests
## - known_vocab_pairs
## - inject_vocab: {biome: String, pair_index: int}
## - gate_inject: {gate: String, biome: String, positions: [[x,y],...]}
## - lindblad_pump: {biome: String, positions: [[x,y],...]}
## - lindblad_drain: {biome: String, positions: [[x,y],...]}
## - channel_drain: {biome: String, source_emoji: String, target_emoji: String} — strategic drain by emoji pair
## - time_skip: {phrames: int, delta?: float}
## - set_stride: {biome: String, stride: int}
## - set_resolution: {biome: String, dt: float}
## - get_timescale: {biome: String}
## - set_timescale_objective: {objective: Dictionary}
## - get_timescale_objective
## - clear_timescale_objective
## - timescale_projection: {biome: String, top_k?: int}
## - recommend_timescale: {biome: String, top_k?: int}
## - auto_timescale: {biome: String, top_k?: int}
## - configure_economy: {overrides: {action_costs?, gate_costs?, quest_rewards?, production?}}
## - configure_seed_state: {known_pairs, unlocked_biomes, unexplored_biomes, active_biome, policy_graph_path?, policy_graph_jsonl?}
## - probe_cycle: {biome: String}
## - discover_biome (biome unlock/expansion)
## - discovery_forecast — returns vocab-weighted probabilities for each unexplored biome
## - victory_lap
## - victory_lap_partial: {selected_biomes?: [String], max_registers?: int, milk_spend?: int, phase_window?: int}
## - batcher_metrics
## - balance_snapshot
## - balance_patch: {patch: {key: value, ...}, source?: String}
## - balance_reset
## - balance_export: {path?: String}
## - balance_load: {path: String}
## - farm_variable_graph
## - farm_variable_graph_apply: {lines: [String], source?: String}
## - farm_variable_graph_load: {path: String}
## - policy_graph
## - policy_graph_apply: {lines: [String]}
## - policy_graph_load: {path: String}
## - action_cost: {name: String, context?: Dictionary}
## - action_preflight: {name: String, context?: Dictionary}
## - save_game: {slot: int}
## - save_game_path: {path: String}
## - load_game: {slot: int}
## - load_game_alias: {alias: String}
## - save_info: {slot: int}
## - overlay_snapshot: {overlay: String} — returns structured dict from overlay.get_snapshot()
## - widget_snapshot: {widget: String} — returns structured dict from widget.get_snapshot()
## - hud_snapshot: {hud: String} — returns structured dict from hud.get_snapshot()
## - full_snapshot — aggregates all widget + HUD + overlay snapshots in one call
## - policy_reset: {config?: Dictionary}
## - policy_snapshot
## - policy_step: {execute?: bool, include_state?: bool, resource_floors?: {emoji: amount}, execution_backend?: "direct"|"player_input"|"auto"}
## - press_key: {keycode?: int, key?: String, shift?: bool, settle_frames?: int}
## - key_sequence: {keys: [{keycode?: int, key?: String, shift?: bool, settle_frames?: int}, ...]}
## - stop
##
## Future actions can be added to the match statement in _execute_command().

const PlayerShellScene = preload("res://UI/PlayerShell.tscn")
const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")
const QuantumForceGraph = preload("res://Core/Visualization/QuantumForceGraph.gd")
const QuantumInstrumentClass = preload("res://Core/Instrumentation/QuantumInstrument.gd")
const QuantumFiberPolicyClass = preload("res://Core/AI/QuantumFiberPolicy.gd")
const PolicyQuantumRegisterClass = preload("res://Core/AI/PolicyQuantumRegister.gd")
const PolicyGraph = preload("res://Core/AI/PolicyGraph.gd")
const BiomeAffinityCalc = preload("res://Core/Quantum/BiomeAffinityCalculator.gd")
const PolicySnapshotBuilder = preload("res://Core/Instrumentation/PolicySnapshotBuilder.gd")
const PhysicsConfig = preload("res://Core/Config/PhysicsConfig.gd")
const InstrumentLocator = preload("res://Core/Instrumentation/InstrumentLocator.gd")
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
const PlayerInputMacroRunner = preload("res://UI/Core/PlayerInputMacroRunner.gd")

signal action_executed(turn_id: int, action: String, result: Dictionary)
signal bridge_idle()
signal bridge_stopped()

var _queue_path = "user://rig/queue.jsonl"
var _result_path = "user://rig/results.jsonl"
var _bridge_sentinel_path = "user://rig/bridge_ready"
var _heartbeat_path = "user://rig/heartbeat"
var _heartbeat_interval_ms: int = 2000
var _next_heartbeat_at_ms: int = 0
var _last_command_completed_at_ms: int = 0  # Tracks last successful command for heartbeat liveness
var _polling_started_at_ms: int = 0  # Watchdog: detect hung _poll_queue coroutine
const _POLLING_WATCHDOG_MS: int = 120_000  # Force-reset _polling after 120s stuck

var _queue_offset: int = 0
var _shell = null
var _snapshot_service = null
var _instrument = null  # QuantumInstrument
var _farm = null
var _policy = null  # QuantumFiberPolicy
var _cached_offers: Array = []
var _cached_offers_pairs_count: int = -1  # Invalidate when pairs change
var _player_input_macro_runner = null
var _last_offers: Array = []
var _is_headless: bool = true
var _turn_log_enabled: bool = true
var _polling: bool = false  # Re-entrancy guard for async commands (e.g. victory_lap visual delays)
var _poll_interval_ms: int = 0
var _next_poll_at_ms: int = 0
var _result_writer: FileAccess = null

const _PLOT_KEYCODES: Array[int] = [KEY_J, KEY_K, KEY_L, KEY_SEMICOLON, KEY_APOSTROPHE, KEY_H, KEY_G]
const _QUEST_SLOT_KEYCODES: Array[int] = [KEY_U, KEY_I, KEY_O, KEY_P]


func _phrame_hz() -> float:
	return float(PhysicsConfig.PHRAME_HZ)


func _init() -> void:
	print("🎛️ Rig listener starting...")
	call_deferred("_bootstrap")


func _bootstrap() -> void:
	var boot_manager = get_root().get_node_or_null("BootManager")
	if not boot_manager:
		print("❌ BootManager not found; cannot start rig")
		return

	var is_headless = DisplayServer.get_name() == "headless"
	_is_headless = is_headless
	var load_slot = int(OS.get_environment("RIG_LOAD_SLOT")) if OS.get_environment("RIG_LOAD_SLOT") != "" else -1
	var scenario_id = OS.get_environment("RIG_SCENARIO") if OS.get_environment("RIG_SCENARIO") != "" else "default"
	_farm = await boot_manager.boot_core(load_slot, scenario_id, is_headless)
	if not _farm:
		print("❌ Farm failed to boot; cannot start rig")
		return

	# Create a FarmView container so paths like /root/FarmView/PlayerShell resolve.
	var farm_view = Node.new()
	farm_view.name = "FarmView"
	get_root().add_child(farm_view)

	if not PlayerShellScene:
		print("❌ PlayerShell.tscn missing; cannot start rig")
		return

	_shell = PlayerShellScene.instantiate()
	farm_view.add_child(_shell)

	# Create visualization when running with display (viz = outflow)
	var quantum_viz = null
	if not _is_headless:
		quantum_viz = QuantumForceGraph.new()
		farm_view.add_child(quantum_viz)
		quantum_viz.top_level = true
		quantum_viz.position = Vector2.ZERO
		quantum_viz.z_index = 100

	# boot_ui wires biomes → quantum_viz via _stage_visualization.
	# Farm signals (terminal_bound, etc.) already connected by boot_ui's
	# connect_to_farm() call — no extra wiring needed.
	await boot_manager.boot_ui(_farm, _shell, quantum_viz)

	_on_ready()


func _on_ready() -> void:
	_ensure_rig_dir()
	_prime_queue_cursor_to_end()
	_apply_rig_logger_profile()
	_snapshot_service = InstrumentLocator.resolve_snapshot_service(_shell)
	_instrument = InstrumentLocator.resolve_quantum_instrument(_shell)
	_ensure_policy()
	_sync_policy_from_game_state()
	_ensure_player_input_macro_runner()
	var turn_log_env = OS.get_environment("RIG_VERBOSE_TURN_LOG").to_lower()
	if turn_log_env == "":
		var profile = OS.get_environment("RIG_LOG_PROFILE").to_lower()
		_turn_log_enabled = (not _is_headless) or (profile in ["debug", "trace", "test"])
	else:
		_turn_log_enabled = (not _is_headless) or (turn_log_env in ["1", "true", "yes", "on"])
	var poll_ms_env = int(OS.get_environment("RIG_QUEUE_POLL_MS")) if OS.get_environment("RIG_QUEUE_POLL_MS") != "" else -1
	_poll_interval_ms = poll_ms_env if poll_ms_env >= 0 else (100 if _is_headless else 16)
	_next_poll_at_ms = 0
	print("🎛️ Rig ready (%dHz phrame clock). Waiting for turns in:" % int(_phrame_hz()), _queue_path)
	_write_bridge_ready_sentinel()
	physics_frame.connect(_on_physics_frame)


func _prime_queue_cursor_to_end() -> void:
	var queue_file_path = ProjectSettings.globalize_path(_queue_path)
	var file = FileAccess.open(queue_file_path, FileAccess.READ)
	if not file:
		_queue_offset = 0
		return
	_queue_offset = file.get_length()
	file.close()


func _turn_log(level: String, turn_id: int, action: String, details: String = "") -> void:
	if not _turn_log_enabled:
		return
	var tail = (" " + details) if details != "" else ""
	print("[RIG][%s] turn=%d action=%s%s" % [level, turn_id, action, tail])


func _ensure_runtime_unpaused_for_rig() -> bool:
	if not paused:
		return false
	paused = false
	print("[RIG][INFO] SceneTree was paused; unpausing for rig command processing")
	return true


func _on_physics_frame() -> void:
	var now = Time.get_ticks_msec()

	# Heartbeat: write timestamp + liveness flag so runner can distinguish
	# "busy processing a command" from "stuck/dead".
	if now >= _next_heartbeat_at_ms:
		_next_heartbeat_at_ms = now + _heartbeat_interval_ms
		_write_heartbeat(now)

	# Watchdog: if _poll_queue has been running for > _POLLING_WATCHDOG_MS,
	# the coroutine is likely hung. Force-reset so the queue can drain again.
	if _polling and _polling_started_at_ms > 0 and (now - _polling_started_at_ms) > _POLLING_WATCHDOG_MS:
		print("[RIG][WARN] Polling watchdog: _poll_queue stuck for %dms — force-resetting" % (now - _polling_started_at_ms))
		_polling = false
		_polling_started_at_ms = 0

	if _polling:
		return
	if _poll_interval_ms > 0 and now < _next_poll_at_ms:
		return
	_next_poll_at_ms = now + _poll_interval_ms
	_polling = true
	_polling_started_at_ms = now
	_ensure_runtime_unpaused_for_rig()
	await _poll_queue()
	_polling = false
	_polling_started_at_ms = 0


func _write_heartbeat(now_ms: int = -1) -> void:
	var hb_path = ProjectSettings.globalize_path(_heartbeat_path)
	var file = FileAccess.open(hb_path, FileAccess.WRITE)
	if file:
		var unix_time = Time.get_unix_time_from_system()
		if now_ms < 0:
			now_ms = Time.get_ticks_msec()
		# Line 1: unix timestamp (backward compat — runner reads this)
		# Line 2: command_idle_ms — how long since last command completed
		#   If this grows while _polling is true, the coroutine is hung.
		var cmd_idle_ms = now_ms - _last_command_completed_at_ms if _last_command_completed_at_ms > 0 else -1
		var polling_dur_ms = (now_ms - _polling_started_at_ms) if (_polling and _polling_started_at_ms > 0) else 0
		file.store_string("%.3f\n%d\n%d" % [unix_time, cmd_idle_ms, polling_dur_ms])
		file.close()


func _poll_queue() -> void:
	var queue_file_path = ProjectSettings.globalize_path(_queue_path)
	var file = FileAccess.open(queue_file_path, FileAccess.READ)
	if not file:
		return

	var queue_size = file.get_length()
	if _queue_offset > queue_size:
		print("[RIG][INFO] Queue rewind detected (bytes %d -> %d), resetting cursor" % [_queue_offset, queue_size])
		_queue_offset = 0

	file.seek(_queue_offset)
	while not file.eof_reached():
		var raw_line = file.get_line()
		_queue_offset = file.get_position()
		var raw = raw_line.strip_edges()
		if raw == "":
			continue
		await _handle_line(raw)
		if not _is_headless:
			break  # Visual: one action per physics tick
	file.close()


func _ensure_snapshot_service() -> bool:
	if not _snapshot_service:
		_snapshot_service = InstrumentLocator.resolve_snapshot_service(_shell)
	if not _instrument:
		_instrument = InstrumentLocator.resolve_quantum_instrument(_shell)
	return _snapshot_service != null


func _requires_snapshot_service(action: String) -> bool:
	return action in [
		"open_overlay",
		"resource_snapshot",
		"policy_snapshot",
		"grid_snapshot",
		"biome_positions",
		"active_quests",
		"known_vocab_pairs",
		"batcher_metrics",
		"probability_map",
		"lindblad_snapshot",
		"overlay_snapshot",
		"widget_snapshot",
		"hud_snapshot",
		"full_snapshot",
	]


func _requires_quantum_instrument(action: String) -> bool:
	return action in [
		"offer_quests",
		"accept_offer",
		"accept_quest",
		"lock_offer",
		"unlock_offer",
		"accept_locked",
		"complete_quest",
		"complete_or_claim",
		"claim_quest",
		"locked_offers",
		"add_resource",
		"set_resource",
		"resource_mutations",
		"inject_vocab",
		"gate_inject",
		"lindblad_pump",
		"lindblad_drain",
		"time_skip",
		"set_stride",
		"set_resolution",
		"get_timescale",
		"set_timescale_objective",
		"get_timescale_objective",
		"clear_timescale_objective",
		"timescale_projection",
		"recommend_timescale",
		"auto_timescale",
		"configure_economy",
		"balance_snapshot",
		"balance_patch",
		"balance_reset",
		"balance_export",
		"balance_load",
		"farm_variable_graph",
		"farm_variable_graph_apply",
		"farm_variable_graph_load",
		"policy_graph",
		"policy_graph_apply",
		"policy_graph_load",
		"action_cost",
		"action_preflight",
		"configure_seed_state",
		"probe_cycle",
		"discover_biome",
		"victory_lap",
		"victory_lap_partial",
		"policy_step",
	]


func _handle_line(raw: String) -> void:
	var data = JSON.parse_string(raw)
	if data == null:
		_write_result({
			"ok": false,
			"error": "bad_json",
			"raw": raw
		})
		return
	if not (data is Dictionary):
		_write_result({
			"ok": false,
			"error": "bad_payload_type",
			"raw": raw
		})
		return

	var cmd: Dictionary = data
	var action = str(cmd.get("action", ""))
	var turn_id = int(cmd.get("turn", -1))
	var request_id = str(cmd.get("request_id", ""))
	_turn_log("BEGIN", turn_id, action)
	_ensure_runtime_unpaused_for_rig()
	var result = await _execute_command(cmd)
	result["turn"] = turn_id
	result["action"] = action
	if request_id != "":
		result["request_id"] = request_id
	_write_result(result)
	_last_command_completed_at_ms = Time.get_ticks_msec()
	var ok = bool(result.get("ok", false))
	if ok:
		_turn_log("END", turn_id, action, "ok=true dur=%sms" % [str(result.get("duration_ms", -1))])
	else:
		_turn_log("ERR", turn_id, action, "error=%s dur=%sms" % [str(result.get("error", "unknown")), str(result.get("duration_ms", -1))])
	action_executed.emit(turn_id, action, result)
	if bool(result.get("__stop__", false)):
		bridge_stopped.emit()
		quit()


func _execute_command(cmd: Dictionary) -> Dictionary:
	var action = cmd.get("action", "")
	var turn_id = cmd.get("turn", -1)
	var started = Time.get_ticks_msec()

	if _requires_snapshot_service(action) and not _ensure_snapshot_service():
		# Readiness race guard: allow one frame for shell wiring to settle.
		await process_frame
		if _ensure_snapshot_service():
			pass
		else:
			return {
				"ok": false,
				"turn": turn_id,
				"action": action,
				"error": "no_snapshot_service",
				"duration_ms": Time.get_ticks_msec() - started
			}
	if _requires_quantum_instrument(action):
		if not _ensure_snapshot_service():
			await process_frame
			_ensure_snapshot_service()
		if not _instrument:
			return {
				"ok": false,
				"turn": turn_id,
				"action": action,
				"error": "no_quantum_instrument",
				"duration_ms": Time.get_ticks_msec() - started
			}

	var result: Dictionary = {"ok": true, "turn": turn_id, "action": action}

	match action:
		"open_overlay":
			var name = cmd.get("name", "")
			var opened = _snapshot_service.open_quest_board() if name == "quests" \
				else _snapshot_service.open_vocabulary_panel() if name == "vocabulary" \
				else _snapshot_service.open_controls_panel() if name == "controls" \
				else false
			result["opened"] = opened

		"offer_quests":
			var offers: Array = []
			var offer_result = _instrument.quest_offer_all()
			if bool(offer_result.get("ok", false)):
				var offered = offer_result.get("offers", [])
				if offered is Array:
					offers = offered
			else:
				result["ok"] = false
				result["error"] = str(offer_result.get("error", "offer_failed"))
			_last_offers = offers
			var full = bool(cmd.get("full", false))
			var include_reward_resources = bool(cmd.get("include_reward_resources", true))
			var include_market_projection = bool(cmd.get("include_market_projection", true))
			result["offers"] = offers if full else _slim_offers(offers, include_reward_resources, include_market_projection)

		"accept_offer":
			var idx = int(cmd.get("offer_index", -1))
			if idx < 0 or idx >= _last_offers.size():
				result = {"ok": false, "turn": turn_id, "action": action, "error": "invalid_offer_index"}
			else:
				var offer = _last_offers[idx]
				var accept_result = _instrument.quest_accept(offer)
				result["accepted"] = bool(accept_result.get("accepted", false))
				result["quest_id"] = offer.get("id", -1)

		"accept_quest":
			var quest_id = int(cmd.get("quest_id", -1))
			var accept_by_id_result = _instrument.quest_accept_by_id(quest_id)
			result["accepted"] = bool(accept_by_id_result.get("accepted", false))

		"lock_offer":
			var idx = int(cmd.get("offer_index", -1))
			if idx < 0 or idx >= _last_offers.size():
				result = {"ok": false, "turn": turn_id, "action": action, "error": "invalid_offer_index"}
			else:
				var offer = _last_offers[idx]
				var lock_result = _instrument.quest_lock_offer(offer)
				result["locked"] = bool(lock_result.get("locked", false))
				result["quest_id"] = int(lock_result.get("quest_id", offer.get("id", -1)))

		"unlock_offer":
			var quest_id = int(cmd.get("quest_id", -1))
			var unlock_result = _instrument.quest_unlock_offer(quest_id)
			result["unlocked"] = bool(unlock_result.get("unlocked", false))

		"accept_locked":
			var quest_id = int(cmd.get("quest_id", -1))
			var accept_locked_result = _instrument.quest_accept_locked(quest_id)
			result["accepted"] = bool(accept_locked_result.get("accepted", false))

		"locked_offers":
			var locked: Array = []
			var locked_result = _instrument.quest_locked_offers()
			var locked_raw = locked_result.get("offers", [])
			if locked_raw is Array:
				locked = locked_raw
			if locked is Array:
				result["locked_offers"] = _slim_offers(locked, true, false)
				result["count"] = locked.size()
			else:
				result["locked_offers"] = []
				result["count"] = 0

		"complete_quest":
			var quest_id = int(cmd.get("quest_id", -1))
			var complete_result = _instrument.quest_complete(quest_id)
			result["completed"] = bool(complete_result.get("completed", false))

		"complete_or_claim":
			var quest_id = int(cmd.get("quest_id", -1))
			var coc_result = _instrument.quest_complete_or_claim(quest_id)
			result["completed_or_claimed"] = bool(coc_result.get("completed_or_claimed", false))

		"claim_quest":
			var quest_id = int(cmd.get("quest_id", -1))
			var claim_result = _instrument.quest_claim(quest_id)
			result["claimed"] = bool(claim_result.get("claimed", false))

		"resource_snapshot":
			result["resources"] = _snapshot_service.get_resource_snapshot() if _snapshot_service else {}

		"policy_snapshot":
			var include_offers = bool(cmd.get("include_offers", true))
			var include_grid = bool(cmd.get("include_grid", true))
			result["policy_snapshot"] = _get_policy_snapshot(include_offers, include_grid)

		"add_resource":
			var emoji = str(cmd.get("emoji", ""))
			var amount = int(cmd.get("amount", 0))
			if not _allow_rig_resource_injection():
				result = {"ok": false, "turn": turn_id, "action": action, "error": "rig_resource_injection_disabled"}
			else:
				result["added"] = bool(_instrument.add_resource(emoji, amount, "rig_add").get("ok", false))

		"set_resource":
			var emoji = str(cmd.get("emoji", ""))
			var amount = int(cmd.get("amount", 0))
			if not _allow_rig_resource_injection():
				result = {"ok": false, "turn": turn_id, "action": action, "error": "rig_resource_injection_disabled"}
			else:
				result["set"] = bool(_instrument.set_resource(emoji, amount, "rig_set").get("ok", false))

		"resource_mutations":
			var limit = int(cmd.get("limit", 40))
			result["mutations"] = _instrument.get_recent_resource_mutations(limit)

		"grid_snapshot":
			result["grid"] = _snapshot_service.get_grid_snapshot() if _snapshot_service else {}

		"biome_positions":
			var biome_name = str(cmd.get("biome", ""))
			result["biome"] = biome_name
			result["positions"] = _snapshot_service.get_biome_positions(biome_name) if _snapshot_service else []

		"active_quests":
			var full = bool(cmd.get("full", false))
			var active = _snapshot_service.get_active_quests() if _snapshot_service else []
			if not (active is Array):
				active = []
			result["quests"] = active if full else _slim_active_quests(active)

		"known_vocab_pairs":
			var pairs = _snapshot_service.get_known_vocab_pairs() if _snapshot_service else []
			result["pairs"] = pairs if pairs is Array else []

		"inject_vocab":
			var biome_name = str(cmd.get("biome", ""))
			if biome_name != "":
				result["inject_result"] = _instrument.action_inject_vocabulary(biome_name)
			else:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "missing_biome"}

		"gate_inject":
			var gate_name = str(cmd.get("gate", ""))
			var biome_name = str(cmd.get("biome", ""))
			var raw_positions = cmd.get("positions", [])
			if gate_name == "" or biome_name == "":
				result = {"ok": false, "turn": turn_id, "action": action, "error": "missing_gate_or_biome"}
			else:
				var positions: Array[Vector2i] = _parse_positions(raw_positions, biome_name)
				if positions.is_empty():
					result = {"ok": false, "turn": turn_id, "action": action, "error": "no_valid_positions"}
				else:
					result["gate_result"] = _instrument.gate_inject(gate_name, positions)

		"lindblad_pump":
			var biome_name = str(cmd.get("biome", ""))
			var raw_positions = cmd.get("positions", [])
			var positions: Array[Vector2i] = _parse_positions(raw_positions, biome_name)
			if positions.is_empty():
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_valid_positions"}
			else:
				result["pump_result"] = _instrument.lindblad_pump(positions)

		"lindblad_drain":
			var biome_name = str(cmd.get("biome", ""))
			var raw_positions = cmd.get("positions", [])
			var positions: Array[Vector2i] = _parse_positions(raw_positions, biome_name)
			if positions.is_empty():
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_valid_positions"}
			else:
				result["drain_result"] = _instrument.lindblad_drain(positions)

		"channel_drain":
			# Strategic framing: drain by emoji pair instead of raw positions
			# {biome, source_emoji, target_emoji} → find matching plots → activate drain
			var biome_name = str(cmd.get("biome", ""))
			var source_emoji = str(cmd.get("source_emoji", ""))
			var target_emoji = str(cmd.get("target_emoji", ""))
			if biome_name == "" or source_emoji == "" or target_emoji == "":
				result = {"ok": false, "turn": turn_id, "action": action, "error": "missing_biome_source_or_target"}
			else:
				var channel_result = _execute_channel_drain(biome_name, source_emoji, target_emoji)
				result["channel_drain"] = channel_result

		"time_skip":
			var phrames = int(cmd.get("phrames", 0))
			var delta = float(cmd.get("delta", -1.0))
			var wait_for = cmd.get("wait_for_resource", {})
			var max_phrames = int(cmd.get("max_phrames", phrames))
			var poll_phrames = int(cmd.get("poll_phrames", phrames))
			if poll_phrames <= 0:
				poll_phrames = 1
			if phrames <= 0:
				phrames = poll_phrames
			max_phrames = max(phrames, max_phrames)
			if max_phrames <= 0:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "invalid_phrames"}
			else:
				var threshold = _parse_wait_threshold(wait_for)
				if threshold.is_empty():
					var skip_result = _perform_time_skip(phrames, delta)
					if bool(skip_result.get("ok", false)):
						skip_result["resources"] = _get_resource_map()
						result["time_skip"] = skip_result
					else:
						result = {"ok": false, "turn": turn_id, "action": action, "error": str(skip_result.get("error", "time_skip_failed"))}
				else:
					var waited = 0
					var polls = 0
					var met = false
					var final_resources: Dictionary = {}
					while waited < max_phrames:
						var chunk = min(poll_phrames, max_phrames - waited)
						if chunk <= 0:
							break
						var chunk_result = _perform_time_skip(chunk, delta)
						if not bool(chunk_result.get("ok", false)):
							result = {"ok": false, "turn": turn_id, "action": action, "error": str(chunk_result.get("error", "time_skip_failed"))}
							break
						waited += chunk
						polls += 1
						final_resources = _get_resource_map()
						if _resource_threshold_met(final_resources, threshold):
							met = true
							break
					if result.get("ok", true):
						result["time_skip"] = {
							"ok": true,
							"mode": "threshold",
							"phrames": waited,
							"max_phrames": max_phrames,
							"poll_phrames": poll_phrames,
							"polls": polls,
							"met": met,
							"threshold": threshold,
							"resources": final_resources,
						}

		"set_stride":
			var biome_name = str(cmd.get("biome", ""))
			var stride = int(cmd.get("stride", 1))
			if biome_name == "":
				result = {"ok": false, "turn": turn_id, "action": action, "error": "missing_biome"}
			else:
				result["stride_result"] = _instrument.set_biome_stride(biome_name, stride)

		"set_resolution":
			var biome_name = str(cmd.get("biome", ""))
			var dt = float(cmd.get("dt", 0.02))
			if biome_name == "":
				result = {"ok": false, "turn": turn_id, "action": action, "error": "missing_biome"}
			else:
				result["resolution_result"] = _instrument.set_biome_resolution(biome_name, dt)

		"get_timescale":
			var biome_name = str(cmd.get("biome", ""))
			if biome_name == "":
				result = {"ok": false, "turn": turn_id, "action": action, "error": "missing_biome"}
			else:
				result["timescale"] = _instrument.get_biome_timescale(biome_name)

		"set_timescale_objective":
			var objective = cmd.get("objective", {})
			if not (objective is Dictionary):
				result = {"ok": false, "turn": turn_id, "action": action, "error": "invalid_objective"}
			else:
				result["timescale_objective"] = _instrument.set_timescale_objective(objective)

		"get_timescale_objective":
			result["timescale_objective"] = _instrument.get_timescale_objective()

		"clear_timescale_objective":
			result["timescale_objective"] = _instrument.clear_timescale_objective()

		"timescale_projection":
			var biome_name = str(cmd.get("biome", ""))
			var top_k = int(cmd.get("top_k", -1))
			if biome_name == "":
				result = {"ok": false, "turn": turn_id, "action": action, "error": "missing_biome"}
			else:
				result["timescale_projection"] = _instrument.get_timescale_projection(biome_name, top_k)

		"recommend_timescale":
			var biome_name = str(cmd.get("biome", ""))
			var top_k = int(cmd.get("top_k", -1))
			if biome_name == "":
				result = {"ok": false, "turn": turn_id, "action": action, "error": "missing_biome"}
			else:
				result["recommendation"] = _instrument.recommend_timescale(biome_name, top_k)

		"auto_timescale":
			var biome_name = str(cmd.get("biome", ""))
			var top_k = int(cmd.get("top_k", -1))
			if biome_name == "":
				result = {"ok": false, "turn": turn_id, "action": action, "error": "missing_biome"}
			else:
				result["auto_timescale"] = _instrument.auto_apply_timescale(biome_name, top_k)

		"configure_economy":
			var overrides = cmd.get("overrides", {})
			if not (overrides is Dictionary) or overrides.is_empty():
				result = {"ok": false, "turn": turn_id, "action": action, "error": "empty_overrides"}
			else:
				result["configured"] = _instrument.configure_economy(overrides)

		"configure_seed_state":
			result["seed_state"] = _instrument.configure_seed_state(cmd)

		"probe_cycle":
			var biome_name = str(cmd.get("biome", ""))
			var full_probe = bool(cmd.get("full", false))
			var probe_data = _instrument.probe_cycle(biome_name)
			result["probe"] = probe_data if full_probe else _slim_probe_result(probe_data)
			if _snapshot_service and _snapshot_service.has_method("show_probe_cycle_status"):
				_snapshot_service.show_probe_cycle_status(biome_name, probe_data)

		"discover_biome":
			if _instrument.has_method("action_discover_biome"):
				result["discover_biome"] = _instrument.action_discover_biome()
			# Attach discovery forecast to result
			if _farm and _farm.has_method("compute_discovery_forecast"):
				result["discovery_forecast"] = _farm.compute_discovery_forecast()

		"discovery_forecast":
			if _farm and _farm.has_method("compute_discovery_forecast"):
				result["forecast"] = _farm.compute_discovery_forecast()
			else:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "forecast_unavailable"}

		"victory_lap":
			result["victory_lap"] = _instrument.victory_lap()

		"victory_lap_partial":
			var selected_biomes_raw = cmd.get("selected_biomes", [])
			var selected_biomes: Array[String] = []
			if selected_biomes_raw is Array:
				for biome_name in selected_biomes_raw:
					var b = str(biome_name)
					if b != "":
						selected_biomes.append(b)
			var max_registers = int(cmd.get("max_registers", 8))
			var milk_spend = int(cmd.get("milk_spend", 0))
			var phase_window = int(cmd.get("phase_window", 1))
			result["victory_lap_partial"] = _instrument.victory_lap_partial(
				selected_biomes,
				max_registers,
				milk_spend,
				phase_window
			)

		"batcher_metrics":
			result["metrics"] = _snapshot_service.get_batcher_metrics() if _snapshot_service else {}

		"probability_map":
			var biome_name = str(cmd.get("biome", ""))
			result["probability_map"] = _snapshot_service.get_probability_map(biome_name)

		"lindblad_snapshot":
			var biome_name = str(cmd.get("biome", ""))
			var include_populations = bool(cmd.get("include_populations", true))
			result["lindblad_snapshot"] = _snapshot_service.get_lindblad_snapshot(biome_name, include_populations)

		"balance_snapshot":
			result["balance"] = _instrument.get_balance_snapshot()

		"balance_patch":
			var patch = cmd.get("patch", {})
			if not (patch is Dictionary) or patch.is_empty():
				result = {"ok": false, "turn": turn_id, "action": action, "error": "empty_patch"}
			else:
				var source = str(cmd.get("source", "rig_balance_patch"))
				result["balance"] = _instrument.patch_balance(patch, source)

		"balance_reset":
			result["balance"] = _instrument.reset_balance_to_default()

		"balance_export":
			var export_path = str(cmd.get("path", "user://saves/balance_profile_last.json"))
			result["balance"] = _instrument.export_balance_profile(export_path)

		"balance_load":
			var load_path = str(cmd.get("path", ""))
			result["balance"] = _instrument.load_balance_profile(load_path)

		"farm_variable_graph":
			result["farm_variable_graph"] = _instrument.get_farm_variable_graph()

		"farm_variable_graph_apply":
			var lines = cmd.get("lines", [])
			if not (lines is Array) or lines.is_empty():
				result = {"ok": false, "turn": turn_id, "action": action, "error": "empty_graph_lines"}
			else:
				var source = str(cmd.get("source", "rig.farm_variable_graph_apply"))
				result["farm_variable_graph"] = _instrument.apply_farm_variable_graph(lines, source)

		"farm_variable_graph_load":
			var graph_path = str(cmd.get("path", ""))
			if graph_path == "":
				result = {"ok": false, "turn": turn_id, "action": action, "error": "missing_graph_path"}
			else:
				result["farm_variable_graph"] = _instrument.load_farm_variable_graph_file(graph_path)

		"policy_graph":
			var policy = _ensure_policy()
			result["policy_graph"] = policy.get_policy_graph() if policy and policy.has_method("get_policy_graph") else {}

		"policy_describe":
			result["schema"] = PolicyStateProjector.policy_describe()

		"policy_graph_apply":
			var policy = _ensure_policy()
			var lines = cmd.get("lines", [])
			if not (lines is Array) or lines.is_empty():
				result = {"ok": false, "turn": turn_id, "action": action, "error": "empty_graph_lines"}
			elif not policy or not policy.has_method("apply_policy_graph_lines"):
				result = {"ok": false, "turn": turn_id, "action": action, "error": "policy_graph_unavailable"}
			else:
				result["policy_graph"] = policy.apply_policy_graph_lines(lines)
				_sync_policy_into_game_state()

		"policy_graph_load":
			var policy = _ensure_policy()
			var graph_path = str(cmd.get("path", ""))
			if graph_path == "":
				result = {"ok": false, "turn": turn_id, "action": action, "error": "missing_graph_path"}
			elif not policy or not policy.has_method("apply_policy_graph_lines"):
				result = {"ok": false, "turn": turn_id, "action": action, "error": "policy_graph_unavailable"}
			else:
				var lines = PolicyGraph.load_graph_lines(graph_path)
				if lines.is_empty():
					result = {"ok": false, "turn": turn_id, "action": action, "error": "missing_or_empty_graph_file", "path": graph_path}
				else:
					result["policy_graph"] = policy.apply_policy_graph_lines(lines)
					_sync_policy_into_game_state()

		"action_cost":
			var action_name = str(cmd.get("name", cmd.get("action_name", "")))
			var context = cmd.get("context", {})
			if action_name == "":
				result = {"ok": false, "turn": turn_id, "action": action, "error": "missing_action_name"}
			elif not (context is Dictionary):
				result = {"ok": false, "turn": turn_id, "action": action, "error": "invalid_context"}
			else:
				result["action_name"] = action_name
				result["context"] = context
				result["cost"] = _instrument.get_action_cost(action_name, context)

		"action_preflight":
			var action_name = str(cmd.get("name", cmd.get("action_name", "")))
			var context = cmd.get("context", {})
			if action_name == "":
				result = {"ok": false, "turn": turn_id, "action": action, "error": "missing_action_name"}
			elif not (context is Dictionary):
				result = {"ok": false, "turn": turn_id, "action": action, "error": "invalid_context"}
			else:
				result["action_name"] = action_name
				result["context"] = context
				result["preflight"] = _instrument.preflight_action_cost(action_name, context)

		"save_game":
			var slot = int(cmd.get("slot", -1))
			var gsm = get_root().get_node_or_null("GameStateManager")
			if not gsm:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_game_state_manager"}
			else:
				_sync_policy_into_game_state()
				result["slot"] = slot
				result["saved"] = gsm.save_game(slot)
				result["save_path"] = gsm.get_save_path(slot) if gsm.has_method("get_save_path") else ""

		"save_game_path":
			var save_path = str(cmd.get("path", ""))
			var gsm = get_root().get_node_or_null("GameStateManager")
			if not gsm:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_game_state_manager"}
			elif save_path == "":
				result = {"ok": false, "turn": turn_id, "action": action, "error": "missing_save_path"}
			else:
				_sync_policy_into_game_state()
				result["path"] = save_path
				if gsm.has_method("save_game_to_path"):
					result["saved"] = gsm.save_game_to_path(save_path)
				else:
					result = {"ok": false, "turn": turn_id, "action": action, "error": "save_game_to_path_unavailable"}

		"load_game":
			var slot = int(cmd.get("slot", -1))
			var gsm = get_root().get_node_or_null("GameStateManager")
			if not gsm:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_game_state_manager"}
			else:
				result["slot"] = slot
				result["loaded"] = gsm.load_and_apply(slot)
				if bool(result.get("loaded", false)):
					_sync_policy_from_game_state()

		"load_game_alias":
			var alias = str(cmd.get("alias", ""))
			var gsm = get_root().get_node_or_null("GameStateManager")
			if not gsm:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_game_state_manager"}
			elif alias == "":
				result = {"ok": false, "turn": turn_id, "action": action, "error": "missing_alias"}
			else:
				result["alias"] = alias
				result["loaded"] = gsm.load_and_apply_emoji_alias(alias)
				if bool(result.get("loaded", false)):
					_sync_policy_from_game_state()

		"save_info":
			var slot = int(cmd.get("slot", -1))
			var gsm = get_root().get_node_or_null("GameStateManager")
			if not gsm:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_game_state_manager"}
			else:
				result["slot"] = slot
				result["info"] = gsm.get_save_info(slot)

		"overlay_snapshot":
			var overlay_name = str(cmd.get("overlay", ""))
			if overlay_name == "":
				result = {"ok": false, "turn": turn_id, "action": action, "error": "missing_overlay_name"}
			else:
				var overlay_snapshot = _snapshot_service.get_overlay_snapshot(overlay_name) if _snapshot_service else {"ok": false, "error": "overlay_not_found", "overlay": overlay_name}
				result.merge(overlay_snapshot, true)

		"widget_snapshot":
			var widget_name = str(cmd.get("widget", ""))
			if widget_name == "":
				result = {"ok": false, "turn": turn_id, "action": action, "error": "missing_widget_name"}
			else:
				var widget_snapshot = _snapshot_service.get_widget_snapshot(widget_name) if _snapshot_service else {"ok": false, "error": "widget_not_found", "widget": widget_name}
				result.merge(widget_snapshot, true)

		"hud_snapshot":
			var hud_name = str(cmd.get("hud", ""))
			if hud_name == "":
				result = {"ok": false, "turn": turn_id, "action": action, "error": "missing_hud_name"}
			else:
				var hud_snapshot = _snapshot_service.get_hud_snapshot(hud_name) if _snapshot_service else {"ok": false, "error": "hud_not_found", "hud": hud_name}
				result.merge(hud_snapshot, true)

		"full_snapshot":
			result["snapshot"] = _snapshot_service.get_full_ui_snapshot() if _snapshot_service else {}

		"policy_reset":
			var config = cmd.get("config", {})
			if not (config is Dictionary):
				config = {}
			var policy = _ensure_policy()
			result["policy"] = policy.reset(config)
			_sync_policy_into_game_state()

		"policy_debug_snapshot":
			var policy = _ensure_policy()
			result["policy"] = policy.get_snapshot()

		"policy_step":
			var policy = _ensure_policy()
			var include_state = bool(cmd.get("include_state", false))
			var compact = bool(cmd.get("compact", false))
			var execute = bool(cmd.get("execute", true))
			var execution_backend = _resolve_policy_execution_backend(str(cmd.get("execution_backend", "auto")))
			var pre_state = _build_policy_state(cmd)
			var decision = policy.decide(pre_state)
			var execution: Dictionary = {"ok": false, "error": "execution_skipped"}
			if execute:
				if execution_backend == "player_input":
					execution = await _execute_policy_action_via_input(decision)
				else:
					# Direct path is fully synchronous — no await needed.
					# Removing await prevents potential GDScript coroutine hangs.
					execution = _execute_policy_action(decision)
				execution["backend"] = str(execution.get("backend", execution_backend))
			# Build post_state WITHOUT regenerating quest offers (expensive).
			# Only resources, pairs, biomes, and lindblad need to be fresh for reward computation.
			var post_state = _build_policy_state_lightweight(cmd)
			var learning = policy.observe(pre_state, decision, post_state, execution)
			if compact:
				decision = {
					"action": str(decision.get("action", "")),
					"mode": str(decision.get("mode", "")),
					"ok": bool(decision.get("ok", false)),
					"score": float(decision.get("score", 0.0)),
					"params": decision.get("params", {}),
				}
				learning = {
					"ok": bool(learning.get("ok", false)),
					"action": str(learning.get("action", "")),
					"reward": float(learning.get("reward", 0.0)),
					"reward_components": learning.get("reward_components", {}),
				}
			var out: Dictionary = {
				"decision": decision,
				"execution": execution,
				"execution_backend": execution_backend,
				"learning": learning,
				"post_resources": post_state.get("resources", {}),
				"post_known_pairs_count": int((post_state.get("known_pairs", []) as Array).size()),
				"contains_milk_pair": _policy_state_has_milk(post_state),
			}
			if include_state:
				out["pre_state"] = pre_state
				out["post_state"] = post_state
			result["policy_step"] = out
			_sync_policy_into_game_state()

		"press_key":
			var keycode = _extract_keycode(cmd)
			if keycode == KEY_UNKNOWN:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "unknown_key"}
			else:
				result["press_key"] = await _press_key(
					keycode,
					bool(cmd.get("shift", false)),
					int(cmd.get("settle_frames", 2))
				)

		"key_sequence":
			var keys = cmd.get("keys", [])
			if not (keys is Array) or keys.is_empty():
				result = {"ok": false, "turn": turn_id, "action": action, "error": "empty_keys"}
			else:
				var steps: Array = []
				for item in keys:
					var key_cmd: Dictionary = item if item is Dictionary else {"key": str(item)}
					var keycode = _extract_keycode(key_cmd)
					if keycode == KEY_UNKNOWN:
						steps.append({"ok": false, "error": "unknown_key", "raw": item})
						result["ok"] = false
						result["error"] = "unknown_key"
						break
					steps.append(await _press_key(
						keycode,
						bool(key_cmd.get("shift", false)),
						int(key_cmd.get("settle_frames", 2))
					))
				result["key_sequence"] = {"count": steps.size(), "steps": steps}

		"stop":
			result["stopped"] = true
			result["__stop__"] = true

		"ping":
			result["pong"] = true
			result["uptime_ms"] = Time.get_ticks_msec()

		_:
			result = {"ok": false, "turn": turn_id, "action": action, "error": "unknown_action"}

	result["duration_ms"] = Time.get_ticks_msec() - started
	return result


func _write_result(payload: Dictionary) -> void:
	var line = JSON.stringify(payload)
	var file = _ensure_result_writer()
	if not file:
		return
	file.store_line(line)
	file.flush()


func _ensure_result_writer() -> FileAccess:
	if _result_writer:
		return _result_writer
	var result_file_path = ProjectSettings.globalize_path(_result_path)
	_result_writer = FileAccess.open(result_file_path, FileAccess.READ_WRITE)
	if not _result_writer:
		_result_writer = FileAccess.open(result_file_path, FileAccess.WRITE)
	if _result_writer:
		_result_writer.seek_end()
	return _result_writer


func _ensure_rig_dir() -> void:
	var rig_dir = ProjectSettings.globalize_path("user://rig")
	DirAccess.make_dir_recursive_absolute(rig_dir)


func _write_bridge_ready_sentinel() -> void:
	var path = ProjectSettings.globalize_path(_bridge_sentinel_path)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return
	file.store_line(str(OS.get_process_id()))
	file.close()


func _clear_bridge_ready_sentinel() -> void:
	var path = ProjectSettings.globalize_path(_bridge_sentinel_path)
	if not FileAccess.file_exists(path):
		return
	var sentinel_pid = -1
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var raw = file.get_as_text().strip_edges()
		file.close()
		sentinel_pid = int(raw) if raw.is_valid_int() else -1
	if sentinel_pid == -1 or sentinel_pid == OS.get_process_id():
		DirAccess.remove_absolute(path)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _result_writer:
			_result_writer.flush()
			_result_writer.close()
			_result_writer = null
		_clear_bridge_ready_sentinel()


func _apply_rig_logger_profile() -> void:
	var verbose = get_root().get_node_or_null("VerboseConfig")
	if not verbose:
		return
	var profile = OS.get_environment("RIG_LOG_PROFILE").to_lower()
	if profile == "":
		profile = "quiet"
	var overrides_raw = OS.get_environment("RIG_LOG_CATEGORY_LEVELS")
	verbose.apply_runtime_profile(profile, overrides_raw)


func _slim_offers(
	offers: Array,
	include_reward_resources: bool = true,
	include_market_projection: bool = true
) -> Array:
	var slim: Array = []
	for offer in offers:
		var quest_type = int(offer.get("type", -1))
		var completion_action = "complete_quest" if quest_type == 0 else "complete_or_claim"
		var row = {
			"id": offer.get("id", -1),
			"faction": offer.get("faction", ""),
			"type": quest_type,
			"resource": offer.get("resource", ""),
			"quantity": offer.get("quantity", 0),
			"reward_vocab_north": offer.get("reward_vocab_north", ""),
			"reward_vocab_south": offer.get("reward_vocab_south", ""),
			"completion_action": completion_action
		}
		if include_market_projection and offer.has("market_projection"):
			row["market_projection"] = offer.get("market_projection", {})
		if include_reward_resources:
			row["reward_resources"] = offer.get("reward_resources", {})
		slim.append(row)
	return slim


func _slim_active_quests(quests: Array) -> Array:
	var slim: Array = []
	for quest in quests:
		if not (quest is Dictionary):
			continue
		slim.append({
			"id": quest.get("id", -1),
			"faction": quest.get("faction", ""),
			"type": int(quest.get("type", -1)),
			"status": quest.get("status", ""),
			"resource": quest.get("resource", ""),
			"quantity": quest.get("quantity", 0),
			"time_limit": quest.get("time_limit", -1),
			"reward_vocab_north": quest.get("reward_vocab_north", ""),
			"reward_vocab_south": quest.get("reward_vocab_south", ""),
			"offered_at": int(quest.get("offered_at", 0)),
			"accepted_at": int(quest.get("accepted_at", 0)),
		})
	return slim


func _slim_probe_result(probe: Dictionary) -> Dictionary:
	if not (probe is Dictionary):
		return {"success": false, "error": "invalid_probe_payload"}
	if not bool(probe.get("success", false)):
		return {
			"success": false,
			"stage": str(probe.get("stage", "")),
			"error": str(probe.get("error", "")),
			"active_biome": str(probe.get("active_biome", ""))
		}
	var explore = probe.get("explore", {})
	var measure = probe.get("measure", {})
	var pop = probe.get("pop", {})
	return {
		"success": true,
		"active_biome": str(probe.get("active_biome", "")),
		"explore": {
			"success": bool(explore.get("success", false)),
			"register_id": int(explore.get("register_id", -1)),
			"biome_name": str(explore.get("biome_name", ""))
		},
		"measure": {
			"success": bool(measure.get("success", false)),
			"outcome": str(measure.get("outcome", "")),
			"probability": float(measure.get("probability", 0.0))
		},
		"pop": {
			"success": bool(pop.get("success", false)),
			"resource": str(pop.get("resource", "")),
			"amount": int(pop.get("amount", 0))
		}
	}


func _probe_cycle(biome_name: String) -> Dictionary:
	if not _farm or not ("terminal_pool" in _farm) or not _farm.terminal_pool:
		return {"success": false, "error": "no_terminal_pool"}
	if not _farm.grid or not _farm.grid.biomes:
		return {"success": false, "error": "no_biomes"}
	var biome = _farm.grid.biomes.get(biome_name, null)
	if not biome:
		return {"success": false, "error": "unknown_biome"}

	# Keep visual runs "following" the active biome while rig probes.
	var active_biome_manager = get_root().get_node_or_null("ActiveBiomeManager")
	if active_biome_manager and active_biome_manager.has_method("set_active_biome"):
		active_biome_manager.set_active_biome(biome_name)
	var obs = get_root().get_node_or_null("ObservationFrame")
	if obs and obs.has_method("set_neutral_biome"):
		obs.set_neutral_biome(biome_name)

	var explore = ProbeActions.action_explore(_farm.terminal_pool, biome, _farm.economy)
	if not explore.get("success", false):
		var explore_fail = {"success": false, "stage": "explore", "details": explore}
		if _snapshot_service and _snapshot_service.has_method("show_probe_cycle_status"):
			_snapshot_service.show_probe_cycle_status(biome_name, explore_fail)
		return explore_fail
	var terminal = explore.get("terminal", null)
	var measure = ProbeActions.action_measure(terminal, biome, _farm.economy)
	if not measure.get("success", false):
		var measure_fail = {"success": false, "stage": "measure", "details": measure}
		if _snapshot_service and _snapshot_service.has_method("show_probe_cycle_status"):
			_snapshot_service.show_probe_cycle_status(biome_name, measure_fail)
		return measure_fail
	var pop = ProbeActions.action_pop(terminal, _farm.terminal_pool, _farm.economy, _farm)
	var out = {"success": true, "explore": explore, "measure": measure, "pop": pop, "active_biome": biome_name}
	if _snapshot_service and _snapshot_service.has_method("show_probe_cycle_status"):
		_snapshot_service.show_probe_cycle_status(biome_name, out)
	return out


## Legacy fallback for victory_lap when no _instrument is available.
## When _instrument is set (standard case), _instrument.victory_lap() is called instead.
## Canonical implementation lives in QuantumInstrument.victory_lap().
func _run_victory_lap() -> Dictionary:
	if not _farm or not _farm.grid or not _farm.grid.biomes:
		return {"success": false, "error": "no_farm_or_biomes"}
	if not ("terminal_pool" in _farm) or not _farm.terminal_pool:
		return {"success": false, "error": "no_terminal_pool"}

	var selection_result = _select_all_plots_for_ui()
	var biomes: Array[String] = []
	for biome_name in _farm.grid.biomes.keys():
		if biome_name is String and str(biome_name) != "":
			biomes.append(str(biome_name))
	biomes.sort()

	var explore_total = 0
	var explore_failures: Array = []
	var terminal_pool = _farm.terminal_pool

	for biome_name in biomes:
		var biome = _farm.grid.biomes.get(biome_name, null)
		if not biome:
			continue
		while true:
			var explore = ProbeActions.action_explore(terminal_pool, biome, _farm.economy)
			if explore.get("success", false):
				explore_total += 1
				continue
			var reason = str(explore.get("error", "unknown"))
			if reason == "no_registers":
				break
			explore_failures.append({"biome": biome_name, "error": reason, "details": explore})
			if reason == "no_terminals":
				break
			break
		if terminal_pool.get_unbound_count() <= 0:
			break

	await _apply_visual_stage_delay("explore_batch")

	var measure_total = 0
	var measure_failures: Array = []
	var active_terminals: Array = terminal_pool.get_active_terminals().duplicate()
	for terminal in active_terminals:
		if not terminal or not terminal.is_bound:
			continue
		var biome_name = str(terminal.bound_biome_name)
		var biome = _farm.grid.biomes.get(biome_name, null)
		if not biome:
			measure_failures.append({"terminal": terminal.terminal_id, "error": "unknown_biome", "biome": biome_name})
			continue
		var measure = ProbeActions.action_measure(terminal, biome, _farm.economy)
		if measure.get("success", false):
			measure_total += 1
		else:
			measure_failures.append({
				"terminal": terminal.terminal_id,
				"biome": biome_name,
				"error": str(measure.get("error", "unknown")),
				"details": measure
			})

	await _apply_visual_stage_delay("measure_batch")

	var harvest_total = 0
	var harvest_failures: Array = []
	var measured_terminals: Array = terminal_pool.get_measured_terminals().duplicate()
	for terminal in measured_terminals:
		if not terminal:
			continue
		var pop = ProbeActions.action_pop(terminal, terminal_pool, _farm.economy, _farm)
		if pop.get("success", false):
			harvest_total += 1
		else:
			harvest_failures.append({
				"terminal": terminal.terminal_id,
				"error": str(pop.get("error", "unknown")),
				"details": pop
			})

	var milk_amount = 0.0
	if _farm and "economy" in _farm and _farm.economy and _farm.economy.has_method("get_resource"):
		milk_amount = float(_farm.economy.get_resource("🍼"))

	return {
		"success": true,
		"selected_plots": selection_result,
		"biomes": biomes,
		"visual_delays": {
			"explore_batch_s": _get_visual_stage_delay_seconds("explore_batch"),
			"measure_batch_s": _get_visual_stage_delay_seconds("measure_batch")
		},
		"explore_total": explore_total,
		"explore_failures": explore_failures,
		"measure_total": measure_total,
		"measure_failures": measure_failures,
		"harvest_total": harvest_total,
		"harvest_failures": harvest_failures,
		"milk_after": milk_amount
	}


func _run_victory_lap_partial(
	selected_biomes: Array[String],
	max_registers: int,
	milk_spend: int,
	phase_window: int
) -> Dictionary:
	if not _farm or not _farm.grid or not _farm.grid.biomes:
		return {"success": false, "error": "no_farm_or_biomes"}
	if not ("terminal_pool" in _farm) or not _farm.terminal_pool:
		return {"success": false, "error": "no_terminal_pool"}

	var target_registers = max(1, max_registers)
	var target_phase_window = max(1, phase_window)
	var target_milk_spend = max(0, milk_spend)
	var biomes: Array[String] = []
	var seen: Dictionary = {}
	if selected_biomes.is_empty():
		for biome_name in _farm.grid.biomes.keys():
			if biome_name is String and str(biome_name) != "":
				var b = str(biome_name)
				if not seen.has(b):
					biomes.append(b)
					seen[b] = true
	else:
		for biome_name in selected_biomes:
			if biome_name == "" or seen.has(biome_name):
				continue
			if not _farm.grid.biomes.has(biome_name):
				continue
			biomes.append(biome_name)
			seen[biome_name] = true
	biomes.sort()
	if biomes.is_empty():
		return {"success": false, "error": "no_target_biomes"}

	var terminal_pool = _farm.terminal_pool
	var explore_total = 0
	var measure_total = 0
	var harvest_total = 0
	var explore_failures: Array = []
	var measure_failures: Array = []
	var harvest_failures: Array = []
	var explored_terminals: Array = []

	for biome_name in biomes:
		if explore_total >= target_registers:
			break
		var biome = _farm.grid.biomes.get(biome_name, null)
		if not biome:
			continue
		while explore_total < target_registers:
			var explore = ProbeActions.action_explore(terminal_pool, biome, _farm.economy)
			if not explore.get("success", false):
				var reason = str(explore.get("error", "unknown"))
				if reason != "no_registers":
					explore_failures.append({"biome": biome_name, "error": reason, "details": explore})
				break
			explore_total += 1
			var term = explore.get("terminal", null)
			if term:
				explored_terminals.append(term)
			if terminal_pool.get_unbound_count() <= 0:
				break

	var measured_terminals: Array = []
	for terminal in explored_terminals:
		if not terminal or not terminal.is_bound:
			continue
		var t_biome_name = str(terminal.bound_biome_name)
		var biome = _farm.grid.biomes.get(t_biome_name, null)
		if not biome:
			measure_failures.append({"terminal": terminal.terminal_id, "error": "unknown_biome", "biome": t_biome_name})
			continue
		var measure = ProbeActions.action_measure(terminal, biome, _farm.economy)
		if measure.get("success", false):
			measure_total += 1
			measured_terminals.append(terminal)
		else:
			measure_failures.append({
				"terminal": terminal.terminal_id,
				"biome": t_biome_name,
				"error": str(measure.get("error", "unknown")),
				"details": measure
			})

	var milk_before = 0.0
	if _farm and "economy" in _farm and _farm.economy and _farm.economy.has_method("get_resource"):
		milk_before = float(_farm.economy.get_resource("🍼"))
	var actual_milk_spend = 0.0
	if target_milk_spend > 0 and _farm.economy and _farm.economy.has_method("remove_resource"):
		var spend = min(float(target_milk_spend), milk_before)
		if spend > 0.0 and _farm.economy.remove_resource("🍼", spend, "victory_lap_partial_spend"):
			actual_milk_spend = spend

	var register_factor = max(1.0, log(1.0 + float(max(0, measure_total))) / log(2.0))
	var milk_factor = 1.0 + (0.20 * (log(1.0 + max(0.0, actual_milk_spend)) / log(2.0)))
	var phase_factor = clamp(0.8 + (0.1 * float(target_phase_window - 1)), 0.8, 1.2)
	var reward_multiplier = max(1.0, register_factor * milk_factor * phase_factor)
	var bonus_total = 0.0
	var bonus_by_emoji: Dictionary = {}

	for terminal in measured_terminals:
		if not terminal:
			continue
		var pop = ProbeActions.action_pop(terminal, terminal_pool, _farm.economy, _farm)
		if pop.get("success", false):
			harvest_total += 1
			var resource = str(pop.get("resource", ""))
			var amount = float(pop.get("amount", 0))
			if resource != "" and amount > 0.0 and reward_multiplier > 1.0 and _farm.economy and _farm.economy.has_method("add_resource"):
				var bonus = floor(max(0.0, amount * (reward_multiplier - 1.0)))
				if bonus > 0.0:
					_farm.economy.add_resource(resource, bonus, "victory_lap_partial_bonus")
					bonus_total += bonus
					bonus_by_emoji[resource] = float(bonus_by_emoji.get(resource, 0.0)) + bonus
		else:
			harvest_failures.append({
				"terminal": terminal.terminal_id,
				"error": str(pop.get("error", "unknown")),
				"details": pop
			})

	var milk_after = milk_before
	if _farm and "economy" in _farm and _farm.economy and _farm.economy.has_method("get_resource"):
		milk_after = float(_farm.economy.get_resource("🍼"))

	return {
		"success": true,
		"mode": "partial",
		"biomes": biomes,
		"max_registers": target_registers,
		"phase_window": target_phase_window,
		"milk_spend_requested": target_milk_spend,
		"milk_spend_actual": actual_milk_spend,
		"reward_multiplier": reward_multiplier,
		"explore_total": explore_total,
		"explore_failures": explore_failures,
		"measure_total": measure_total,
		"measure_failures": measure_failures,
		"harvest_total": harvest_total,
		"harvest_failures": harvest_failures,
		"bonus_total": bonus_total,
		"bonus_by_emoji": bonus_by_emoji,
		"milk_before": milk_before,
		"milk_after": milk_after
	}


func _select_all_plots_for_ui() -> Dictionary:
	if not _farm or not _farm.grid:
		return {"ok": false, "error": "no_grid"}
	var positions: Array = []
	for y in range(_farm.grid.grid_height):
		for x in range(_farm.grid.grid_width):
			positions.append(Vector2i(x, y))

	var farm_ui = _shell.get_farm_ui() if _shell and _shell.has_method("get_farm_ui") else null
	var input_handler = null
	if farm_ui and "input_handler" in farm_ui:
		input_handler = farm_ui.input_handler

	if input_handler and input_handler.has_method("set_checked_plots"):
		input_handler.set_checked_plots(positions)
		return {"ok": true, "count": positions.size()}
	return {"ok": false, "count": positions.size(), "error": "no_input_handler"}


func _get_visual_stage_delay_seconds(stage: String) -> float:
	var default_seconds = 0.0 if _is_headless else (2.0 if stage == "explore_batch" else 0.5 if stage == "measure_batch" else 0.0)
	var specific_key = "RIG_VISUAL_DELAY_%s_S" % stage.to_upper()
	var specific_raw = OS.get_environment(specific_key)
	if specific_raw != "":
		return max(0.0, float(specific_raw))
	var global_raw = OS.get_environment("RIG_VISUAL_DELAY_S")
	if global_raw != "":
		return max(0.0, float(global_raw))
	return default_seconds


func _apply_visual_stage_delay(stage: String) -> void:
	var seconds = _get_visual_stage_delay_seconds(stage)
	if seconds <= 0.0:
		return
	var phrames = int(ceil(seconds * _phrame_hz()))
	for i in range(phrames):
		await physics_frame


func _configure_seed_state(cmd: Dictionary) -> Dictionary:
	var out: Dictionary = {"ok": true}
	var gsm = get_root().get_node_or_null("GameStateManager")
	if not gsm or not gsm.current_state:
		return {"ok": false, "error": "no_game_state"}

	var known_pairs = _sanitize_known_pairs(cmd.get("known_pairs", []))
	if not known_pairs.is_empty():
		if _farm and _farm.has_method("set_known_pairs"):
			_farm.set_known_pairs(known_pairs, true, true)
		gsm.current_state.known_pairs = known_pairs.duplicate(true)
		out["known_pairs"] = known_pairs

	var unlocked_biomes = _sanitize_biomes(cmd.get("unlocked_biomes", []))
	if not unlocked_biomes.is_empty():
		gsm.current_state.unlocked_biomes = unlocked_biomes.duplicate()
		if unlocked_biomes.size() > 0 and str(gsm.current_state.active_biome_name) == "":
			gsm.current_state.active_biome_name = str(unlocked_biomes[0])
		out["unlocked_biomes"] = unlocked_biomes
		var default_pool: Array[String] = []
		var obs = get_root().get_node_or_null("ObservationFrame")
		if obs and obs.has_method("get_loadable_biomes"):
			default_pool = obs.get_loadable_biomes()
		else:
			default_pool = ["StarterForest", "Village", "BioticFlux", "StellarForges", "FungalNetworks", "VolcanicWorlds"]
		var pool: Array[String] = []
		for biome_name in default_pool:
			if biome_name not in unlocked_biomes:
				pool.append(biome_name)
		gsm.current_state.unexplored_biome_pool = pool
		var active_biome_manager = get_root().get_node_or_null("ActiveBiomeManager")
		if active_biome_manager and active_biome_manager.has_method("set_biome_order"):
			active_biome_manager.set_biome_order(unlocked_biomes)

	var unexplored_biomes = _sanitize_biomes(cmd.get("unexplored_biomes", []))
	if not unexplored_biomes.is_empty():
		gsm.current_state.unexplored_biome_pool = unexplored_biomes.duplicate()
		out["unexplored_biomes"] = unexplored_biomes

	var active_biome = str(cmd.get("active_biome", ""))
	if active_biome != "":
		gsm.current_state.active_biome_name = active_biome
		var obs2 = get_root().get_node_or_null("ObservationFrame")
		if obs2 and obs2.has_method("set_neutral_biome"):
			obs2.set_neutral_biome(active_biome)
		var active_biome_manager2 = get_root().get_node_or_null("ActiveBiomeManager")
		if active_biome_manager2 and active_biome_manager2.has_method("set_active_biome"):
			active_biome_manager2.set_active_biome(active_biome)
		out["active_biome"] = active_biome

	var policy_graph_path = str(cmd.get("policy_graph_path", ""))
	if policy_graph_path != "":
		gsm.current_state.policy_graph_path = policy_graph_path
		out["policy_graph_path"] = policy_graph_path

	var policy_graph_jsonl = cmd.get("policy_graph_jsonl", [])
	if policy_graph_jsonl is Array:
		var typed_lines: Array[String] = []
		for raw_line in policy_graph_jsonl:
			var line = str(raw_line).strip_edges()
			if line != "":
				typed_lines.append(line)
		gsm.current_state.policy_graph_jsonl = typed_lines
		if not typed_lines.is_empty():
			out["policy_graph_jsonl"] = typed_lines

	return out


## Delegate to QuantumInstrument static helpers to avoid duplicate implementations.
func _sanitize_biomes(raw) -> Array[String]:
	return QuantumInstrumentClass._sanitize_biomes(raw)


func _sanitize_known_pairs(raw) -> Array:
	return QuantumInstrumentClass._sanitize_known_pairs(raw)


func _perform_time_skip(phrames: int, delta: float) -> Dictionary:
	if _instrument and _instrument.has_method("time_skip"):
		return _instrument.time_skip(phrames, delta)
	return {"ok": false, "error": "no_quantum_instrument"}


func _parse_wait_threshold(raw) -> Dictionary:
	var out: Dictionary = {}
	if not (raw is Dictionary):
		return out
	for key in raw.keys():
		var emoji = str(key)
		if emoji == "":
			continue
		var amount = float(raw.get(key, 0.0))
		if amount > 0.0:
			out[emoji] = amount
	return out


func _get_resource_map() -> Dictionary:
	if _snapshot_service and _snapshot_service.has_method("get_resource_snapshot"):
		var snap = _snapshot_service.get_resource_snapshot()
		if snap is Dictionary:
			var resources = snap.get("resources", {})
			return resources if resources is Dictionary else {}
	if not _instrument:
		return {}
	var snap = _instrument.get_resource_snapshot()
	if not (snap is Dictionary):
		return {}
	var resources = snap.get("resources", {})
	return resources if resources is Dictionary else {}


func _get_policy_snapshot(include_offers: bool = true, include_grid: bool = true) -> Dictionary:
	if _snapshot_service and _snapshot_service.has_method("get_policy_snapshot"):
		var via_snapshot = _snapshot_service.get_policy_snapshot(include_offers, include_grid)
		if via_snapshot is Dictionary:
			return via_snapshot
	if not _instrument:
		return {}
	if _instrument.has_method("get_policy_snapshot"):
		var bundled = _instrument.get_policy_snapshot(include_offers, include_grid)
		if bundled is Dictionary:
			return bundled
	return PolicySnapshotBuilder.build(_instrument, include_offers, include_grid)


func _resource_threshold_met(resources: Dictionary, threshold: Dictionary) -> bool:
	if threshold.is_empty():
		return false
	for emoji in threshold.keys():
		var target = float(threshold.get(emoji, 0.0))
		if float(resources.get(emoji, 0.0)) < target:
			return false
	return true


func _resolve_quest_manager():
	if _shell and "quest_manager" in _shell:
		var shell_qm = _shell.quest_manager
		if shell_qm:
			return shell_qm
	var autoload_qm = get_root().get_node_or_null("/root/QuestManager")
	if autoload_qm:
		return autoload_qm
	var local_qm = get_root().get_node_or_null("QuestManager")
	if local_qm:
		return local_qm
	if _shell:
		var child_qm = _shell.get_node_or_null("QuestManager")
		if child_qm:
			return child_qm
	return null


func _ensure_policy():
	if _policy:
		return _policy
	var policy_type = str(OS.get_environment("RIG_POLICY_TYPE"))
	if policy_type == "quantum_register":
		_policy = PolicyQuantumRegisterClass.new()
		var config: Dictionary = {}
		var profile_env = str(OS.get_environment("RIG_POLICY_PROFILE"))
		if profile_env != "":
			config["profile"] = profile_env
		var coupling_env = str(OS.get_environment("RIG_POLICY_COUPLING"))
		if coupling_env != "":
			config["coupling_strength"] = float(coupling_env)
		var pump_env = str(OS.get_environment("RIG_POLICY_PUMP_SCALE"))
		if pump_env != "":
			config["pump_scale"] = float(pump_env)
		var drain_env = str(OS.get_environment("RIG_POLICY_DRAIN_SCALE"))
		if drain_env != "":
			config["drain_scale"] = float(drain_env)
		var decay_env = str(OS.get_environment("RIG_POLICY_DECAY_RATE"))
		if decay_env != "":
			config["decay_rate"] = float(decay_env)
		var collapse_env = str(OS.get_environment("RIG_POLICY_COLLAPSE"))
		if collapse_env != "":
			config["collapse_strength"] = float(collapse_env)
		_policy.reset(config)
	else:
		_policy = QuantumFiberPolicyClass.new()
		var config: Dictionary = {}
		var profile_env = str(OS.get_environment("RIG_POLICY_PROFILE"))
		if profile_env != "":
			config["profile"] = profile_env
		var epsilon_env = str(OS.get_environment("RIG_POLICY_EPSILON"))
		if epsilon_env != "":
			config["epsilon"] = float(epsilon_env)
		var ucb_env = str(OS.get_environment("RIG_POLICY_UCB_SCALE"))
		if ucb_env != "":
			config["ucb_scale"] = float(ucb_env)
		_policy.reset(config)
	return _policy


func _sync_policy_into_game_state() -> void:
	if not _policy:
		return
	var gsm = get_root().get_node_or_null("GameStateManager")
	if not gsm or not gsm.current_state:
		return
	if not ("policy_state" in gsm.current_state):
		return
	if _policy.has_method("export_state"):
		gsm.current_state.policy_state = _policy.export_state()
	else:
		gsm.current_state.policy_state = _policy.get_snapshot()
	if "policy_graph_jsonl" in gsm.current_state and _policy.has_method("get_policy_graph"):
		var graph_snapshot = _policy.get_policy_graph()
		if graph_snapshot is Dictionary:
			gsm.current_state.policy_graph_jsonl = PolicyGraph.snapshot_to_graph_lines(graph_snapshot)


func _sync_policy_from_game_state() -> void:
	var gsm = get_root().get_node_or_null("GameStateManager")
	if not gsm or not gsm.current_state:
		return
	if not ("policy_state" in gsm.current_state):
		return
	var state = gsm.current_state.policy_state
	if not (state is Dictionary) or state.is_empty():
		return
	var policy = _ensure_policy()
	if policy.has_method("load_state"):
		policy.load_state(state)
	elif policy.has_method("reset"):
		policy.reset(state)
	if "policy_graph_jsonl" in gsm.current_state and policy.has_method("apply_policy_graph_lines"):
		var graph_lines = gsm.current_state.policy_graph_jsonl
		if (not (graph_lines is Array) or graph_lines.is_empty()) and "policy_graph_path" in gsm.current_state:
			graph_lines = PolicyGraph.load_graph_lines(str(gsm.current_state.policy_graph_path))
		if graph_lines is Array and not graph_lines.is_empty():
			policy.apply_policy_graph_lines(graph_lines)


func _build_policy_state(cmd: Dictionary = {}) -> Dictionary:
	# Cache quest offers: only regenerate when vocab count changes (89 factions is expensive).
	# MUST run before SnapshotService path — otherwise the snapshot service
	# calls quest_offer_all() uncached on every single policy_step.
	var known_pairs = _instrument.get_known_vocab_pairs() if _instrument else []
	var pairs_count = known_pairs.size() if known_pairs is Array else 0
	if pairs_count != _cached_offers_pairs_count:
		_cached_offers = _instrument.get_quest_offers_for_current_biome() if _instrument else []
		_cached_offers_pairs_count = pairs_count

	if _snapshot_service and _snapshot_service.has_method("build_policy_state_lightweight"):
		# Use lightweight path (skips quest_offer_all) and inject our cached offers.
		# build_policy_state() would call quest_offer_all() again uncached — defeating the cache.
		var projected = _snapshot_service.build_policy_state_lightweight(cmd)
		if projected is Dictionary:
			projected["offers"] = _cached_offers
			if _farm and _farm.has_method("compute_discovery_forecast"):
				projected["discovery_forecast"] = _farm.compute_discovery_forecast()
			return projected
	return {
		"profile": str(cmd.get("profile", "default")),
		"resources": _get_resource_map(),
		"resource_floors": _parse_wait_threshold(cmd.get("resource_floors", {})),
		"forbid_actions": cmd.get("forbid_actions", []),
		"known_pairs": known_pairs,
		"offers": _cached_offers,
		"active_quests": _instrument.get_active_quests() if _instrument else [],
		"biomes": [],
		"lindblad": _snapshot_service.get_lindblad_snapshot("", false) if _snapshot_service else {},
		"discovery_forecast": _farm.compute_discovery_forecast() if _farm and _farm.has_method("compute_discovery_forecast") else {},
		"locked_offers": _instrument.get_locked_offers() if _instrument else [],
	}


func _build_policy_state_lightweight(cmd: Dictionary = {}) -> Dictionary:
	"""Build post-action state for reward computation WITHOUT regenerating quest offers.
	Quest generation (89 factions × generate_quest) is expensive; the reward signal
	only needs resources, pairs, biomes, and lindblad state — not fresh offers."""
	if _snapshot_service and _snapshot_service.has_method("build_policy_state_lightweight"):
		var projected = _snapshot_service.build_policy_state_lightweight(cmd)
		if projected is Dictionary:
			return projected
	return {
		"profile": str(cmd.get("profile", "default")),
		"resources": _get_resource_map(),
		"resource_floors": _parse_wait_threshold(cmd.get("resource_floors", {})),
		"forbid_actions": cmd.get("forbid_actions", []),
		"known_pairs": _instrument.get_known_vocab_pairs() if _instrument else [],
		"offers": [],  # Skip expensive quest generation for post-state
		"active_quests": _instrument.get_active_quests() if _instrument else [],
		"biomes": [],
		"lindblad": _snapshot_service.get_lindblad_snapshot("", false) if _snapshot_service else {},
		"discovery_forecast": {},  # Skip expensive forecast for post-state
		"locked_offers": _instrument.get_locked_offers() if _instrument else [],
	}


func _ensure_player_input_macro_runner():
	if _player_input_macro_runner:
		return _player_input_macro_runner
	_player_input_macro_runner = PlayerInputMacroRunner.new()
	_player_input_macro_runner.setup(self)
	return _player_input_macro_runner


func _policy_state_has_milk(state: Dictionary) -> bool:
	var pairs = state.get("known_pairs", [])
	if not (pairs is Array):
		return false
	for pair in pairs:
		if not (pair is Dictionary):
			continue
		if str(pair.get("north", "")) == "🍼" or str(pair.get("south", "")) == "🍼":
			return true
	return false


func _resolve_policy_execution_backend(requested: String) -> String:
	var backend = requested.strip_edges().to_lower()
	if backend in ["direct", "player_input"]:
		return backend
	var env_backend = OS.get_environment("RIG_POLICY_EXECUTION_BACKEND").strip_edges().to_lower()
	if env_backend in ["direct", "player_input"]:
		return env_backend
	return "player_input" if not _is_headless else "direct"


func _resolve_quantum_input():
	if not _shell:
		return null
	for node in get_nodes_in_group("quantum_instrument_input"):
		if node and (_shell == node or _shell.is_ancestor_of(node)):
			return node
	var direct = _shell.get_node_or_null("FarmInputHandler")
	if direct:
		return direct
	return _shell.find_child("FarmInputHandler", true, false)


func _resolve_overlay_manager():
	if _shell and "overlay_manager" in _shell:
		return _shell.overlay_manager
	return null


func _extract_keycode(cmd: Dictionary) -> int:
	var explicit = int(cmd.get("keycode", KEY_UNKNOWN))
	if explicit != KEY_UNKNOWN and explicit > 0:
		return explicit
	return _keycode_from_name(str(cmd.get("key", "")))


func _keycode_from_name(key_name: String) -> int:
	var raw = key_name.strip_edges()
	if raw == "":
		return KEY_UNKNOWN
	var upper = raw.to_upper()
	match upper:
		"ESC", "ESCAPE":
			return KEY_ESCAPE
		"TAB":
			return KEY_TAB
		"SPACE":
			return KEY_SPACE
		"SEMICOLON":
			return KEY_SEMICOLON
		"APOSTROPHE", "QUOTE":
			return KEY_APOSTROPHE
		"MINUS":
			return KEY_MINUS
		"EQUAL", "EQUALS", "PLUS":
			return KEY_EQUAL
		"COMMA":
			return KEY_COMMA
		"PERIOD", "DOT":
			return KEY_PERIOD
		"SLASH":
			return KEY_SLASH
		_:
			return OS.find_keycode_from_string(upper)


func _route_rig_key_event(event: InputEventKey) -> void:
	# Synthetic rig input should traverse the same shell/overlay/input stack in
	# both headed and headless modes. Relying on parse_input_event alone is not
	# stable for modal overlay navigation in headed WSL sessions.
	var viewport: Viewport = root
	if _shell and _shell.has_method("_input"):
		_shell._input(event)
		if viewport and viewport.is_input_handled():
			return
	var qinput = _resolve_quantum_input()
	if qinput and qinput.has_method("_unhandled_key_input"):
		qinput._unhandled_key_input(event)
		if viewport and viewport.is_input_handled():
			return
	if qinput and qinput.has_method("_input"):
		qinput._input(event)


func _push_key_event(keycode: int, pressed: bool, shift: bool = false) -> bool:
	if keycode == KEY_UNKNOWN or keycode <= 0:
		return false
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	event.echo = false
	event.shift_pressed = shift
	_route_rig_key_event(event)
	return true


func _wait_settle_frames(count: int = 2) -> void:
	for _i in range(max(1, count)):
		await process_frame


func _press_key(keycode: int, shift: bool = false, settle_frames: int = 2) -> Dictionary:
	if not _push_key_event(keycode, true, shift):
		return {"ok": false, "error": "unknown_keycode", "keycode": keycode}
	await process_frame
	_push_key_event(keycode, false, shift)
	await _wait_settle_frames(settle_frames)
	return {
		"ok": true,
		"keycode": keycode,
		"shift": shift,
		"settle_frames": max(1, settle_frames),
	}


func _close_player_overlays_via_input(max_presses: int = 4) -> void:
	if not _shell or not _shell.has_method("_any_menu_open"):
		return
	for _i in range(max_presses):
		if not _shell._any_menu_open():
			return
		await _press_key(KEY_ESCAPE, false, 2)


func _tool_group_keycode(group_num: int) -> int:
	match group_num:
		1:
			return KEY_1
		2:
			return KEY_2
		3:
			return KEY_3
		4:
			return KEY_4
	return KEY_UNKNOWN


func _ensure_tool_group_mode(group_num: int, mode_name: String = "") -> Dictionary:
	var keycode = _tool_group_keycode(group_num)
	if keycode == KEY_UNKNOWN:
		return {"ok": false, "error": "unknown_tool_group", "group": group_num}
	if ToolConfig.get_current_group() != group_num:
		await _press_key(keycode, false, 2)
	if mode_name == "" or not ToolConfig.has_f_cycling(group_num):
		return {"ok": ToolConfig.get_current_group() == group_num, "group": group_num}
	var guard = 0
	while ToolConfig.get_group_mode_name(group_num) != mode_name and guard < 8:
		await _press_key(KEY_F, false, 2)
		guard += 1
	return {
		"ok": ToolConfig.get_current_group() == group_num and ToolConfig.get_group_mode_name(group_num) == mode_name,
		"group": group_num,
		"mode": ToolConfig.get_group_mode_name(group_num),
	}


func _sort_vec2i(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x if a.x != b.x else a.y < b.y


func _get_sorted_biome_positions(biome_name: String) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	if _instrument and _instrument.has_method("get_biome_positions"):
		var raw = _instrument.get_biome_positions(biome_name)
		if raw is Array:
			for pos in raw:
				if pos is Vector2i:
					positions.append(pos)
	if positions.size() > 1:
		positions.sort_custom(_sort_vec2i)
	return positions


func _get_plot_for_position(pos: Vector2i):
	if not _farm or not ("grid" in _farm) or not _farm.grid or not _farm.grid.has_method("get_plot"):
		return null
	return _farm.grid.get_plot(pos)


func _find_plot_index_for_state(biome_name: String, desired_state: String) -> int:
	for pos in _get_sorted_biome_positions(biome_name):
		var plot = _get_plot_for_position(pos)
		if not plot:
			continue
		var terminal = plot.get("terminal")
		match desired_state:
			"measured":
				if terminal and bool(terminal.is_measured):
					return int(pos.x)
			"measurable":
				if terminal and terminal.has_method("can_measure") and terminal.can_measure():
					return int(pos.x)
			"terminal":
				if terminal:
					return int(pos.x)
	return -1


func _select_biome_via_input(biome_name: String) -> Dictionary:
	if biome_name == "":
		return {"ok": false, "error": "missing_biome"}
	var active_biome_mgr = get_root().get_node_or_null("/root/ActiveBiomeManager")
	if not active_biome_mgr:
		return {"ok": false, "error": "no_active_biome_manager", "biome": biome_name}
	if str(active_biome_mgr.get_active_biome()) == biome_name:
		return {"ok": true, "biome": biome_name, "already_active": true}
	for slot_idx in range(int(active_biome_mgr.get_slot_count())):
		if str(active_biome_mgr.get_biome_for_slot(slot_idx)) != biome_name:
			continue
		var key_name = str(active_biome_mgr.get_slot_key(slot_idx))
		var keycode = _keycode_from_name(key_name)
		if keycode == KEY_UNKNOWN:
			return {"ok": false, "error": "unknown_biome_key", "biome": biome_name, "key": key_name}
		await _press_key(keycode, false, 2)
		return {"ok": str(active_biome_mgr.get_active_biome()) == biome_name, "biome": biome_name, "key": key_name}
	return {"ok": false, "error": "biome_not_on_slot_bar", "biome": biome_name}


func _select_plot_via_input(plot_idx: int) -> Dictionary:
	if plot_idx < 0 or plot_idx >= _PLOT_KEYCODES.size():
		return {"ok": false, "error": "plot_idx_out_of_range", "plot_idx": plot_idx}
	await _press_key(_PLOT_KEYCODES[plot_idx], false, 2)
	return {"ok": true, "plot_idx": plot_idx}


func _open_quest_board_via_input() -> Dictionary:
	await _close_player_overlays_via_input()
	var overlay_manager = _resolve_overlay_manager()
	var board = overlay_manager.get_v2_overlay("quests") if overlay_manager and overlay_manager.has_method("get_v2_overlay") else null
	if board and board.visible:
		return {"ok": true, "already_open": true}
	await _press_key(KEY_C, false, 2)
	board = overlay_manager.get_v2_overlay("quests") if overlay_manager and overlay_manager.has_method("get_v2_overlay") else null
	return {"ok": board != null and board.visible, "opened": board != null and board.visible}


func _navigate_quest_slot_via_input(page_idx: int, slot_idx: int) -> Dictionary:
	var overlay_manager = _resolve_overlay_manager()
	var board = overlay_manager.get_v2_overlay("quests") if overlay_manager and overlay_manager.has_method("get_v2_overlay") else null
	if not board or not board.visible:
		return {"ok": false, "error": "quest_board_not_open"}
	var total_pages = max(1, int(board.get_snapshot().get("total_pages", 1))) if board.has_method("get_snapshot") else 1
	var guard = 0
	while int(board.get("current_page")) != page_idx and guard < total_pages + 1:
		await _press_key(KEY_F, false, 2)
		guard += 1
	if slot_idx < 0 or slot_idx >= _QUEST_SLOT_KEYCODES.size():
		return {"ok": false, "error": "slot_idx_out_of_range", "slot_idx": slot_idx}
	await _press_key(_QUEST_SLOT_KEYCODES[slot_idx], false, 2)
	return {
		"ok": int(board.get("current_page")) == page_idx and int(board.get("selected_slot_index")) == slot_idx,
		"page": int(board.get("current_page")),
		"slot_idx": int(board.get("selected_slot_index")),
	}


func _execute_policy_action(decision: Dictionary) -> Dictionary:
	var action = str(decision.get("action", ""))
	var params = decision.get("params", {})
	if not (params is Dictionary):
		params = {}
	match action:
		"probe_cycle":
			var biome_name = str(params.get("biome", ""))
			if not _instrument:
				return {"ok": false, "action": action, "error": "no_quantum_instrument"}
			var probe_data = _instrument.probe_cycle(biome_name)
			var probe_ok = bool(probe_data.get("success", false)) if probe_data is Dictionary else false
			var harvested = ""
			if probe_data is Dictionary:
				var pop = probe_data.get("pop", {})
				if pop is Dictionary:
					harvested = str(pop.get("resource", ""))
			return {
				"ok": probe_ok,
				"action": action,
				"biome": biome_name,
				"probe": _slim_probe_result(probe_data),
				"harvested_resource": harvested,
			}
		"quest_cycle":
			return _execute_policy_quest_cycle(params)
		"lindblad_drain":
			var biome_name = str(params.get("biome", ""))
			var positions: Array[Vector2i] = _parse_positions(params.get("positions", []), biome_name)
			if positions.is_empty():
				return {"ok": false, "action": action, "error": "no_valid_positions", "biome": biome_name}
			if not _instrument:
				return {"ok": false, "action": action, "error": "no_quantum_instrument", "biome": biome_name}
			var drain_result = _instrument.lindblad_drain(positions)
			var ok = false
			if drain_result is Dictionary:
				ok = bool(drain_result.get("success", false))
				ok = ok or int(drain_result.get("charged_count", 0)) > 0
				ok = ok or int(drain_result.get("persistent_enabled", 0)) > 0
				ok = ok or int(drain_result.get("already_active", 0)) > 0
			return {
				"ok": ok,
				"action": action,
				"biome": biome_name,
				"drain_result": drain_result,
			}
		"channel_drain":
			var biome_name = str(params.get("biome", ""))
			var source_emoji = str(params.get("source_emoji", ""))
			var target_emoji = str(params.get("target_emoji", ""))
			if biome_name == "" or source_emoji == "" or target_emoji == "":
				return {"ok": false, "action": action, "error": "missing_biome_source_or_target"}
			var channel_result = _execute_channel_drain(biome_name, source_emoji, target_emoji)
			return {
				"ok": channel_result.get("ok", false),
				"action": action,
				"channel_drain": channel_result,
			}
		"time_skip":
			var phrames = max(1, int(params.get("phrames", 6)))
			var delta = float(params.get("delta", -1.0))
			var skip_result = _perform_time_skip(phrames, delta)
			var ok = bool(skip_result.get("ok", false)) if skip_result is Dictionary else false
			var resources = _get_resource_map()
			return {
				"ok": ok,
				"action": action,
				"time_skip": skip_result,
				"resources": resources,
			}
		"discover_biome":
			if not _instrument:
				return {"ok": false, "action": action, "error": "no_quantum_instrument"}
			var discover_result = {}
			if _instrument.has_method("action_discover_biome"):
				discover_result = _instrument.action_discover_biome()
			var ok = bool(discover_result.get("success", false)) if discover_result is Dictionary else false
			var policy_discover_return = {
				"ok": ok,
				"action": action,
				"discover_biome": discover_result,
			}
			if _farm and _farm.has_method("compute_discovery_forecast"):
				policy_discover_return["discovery_forecast"] = _farm.compute_discovery_forecast()
			return policy_discover_return
		"victory_lap_partial":
			if not _instrument:
				return {"ok": false, "action": action, "error": "no_quantum_instrument"}
			var selected_raw = params.get("selected_biomes", [])
			var selected_biomes: Array[String] = []
			if selected_raw is Array:
				for item in selected_raw:
					var b = str(item)
					if b != "":
						selected_biomes.append(b)
			var max_registers = int(params.get("max_registers", 8))
			var milk_spend = int(params.get("milk_spend", 0))
			var phase_window = int(params.get("phase_window", 1))
			var lap = _instrument.victory_lap_partial(selected_biomes, max_registers, milk_spend, phase_window)
			return {
				"ok": bool(lap.get("success", false)) if lap is Dictionary else false,
				"action": action,
				"victory_lap_partial": lap,
			}
		"lock_offer":
			if not _instrument:
				return {"ok": false, "action": action, "error": "no_quantum_instrument"}
			var offer_index = int(params.get("offer_index", -1))
			# Use cached offers instead of expensive quest_offer_all()
			var lock_offers: Array = _cached_offers if not _cached_offers.is_empty() else []
			if lock_offers.is_empty():
				var lock_offer_result = _instrument.quest_offer_all()
				var offered = lock_offer_result.get("offers", [])
				if offered is Array:
					lock_offers = offered
			if offer_index < 0 or offer_index >= lock_offers.size():
				return {"ok": false, "action": action, "error": "invalid_offer_index"}
			var locked = false
			var lock_res = _instrument.quest_lock_offer(lock_offers[offer_index])
			locked = bool(lock_res.get("locked", false))
			return {
				"ok": locked,
				"action": action,
				"quest_id": int(lock_offers[offer_index].get("id", -1)),
			}
		_:
			return {"ok": false, "action": action, "error": "unsupported_policy_action"}


func _execute_policy_action_via_input(decision: Dictionary) -> Dictionary:
	var runner = _ensure_player_input_macro_runner()
	return await runner.execute(decision)


func _execute_policy_quest_cycle(policy_params: Dictionary = {}) -> Dictionary:
	if not _instrument:
		return {"ok": false, "action": "quest_cycle", "error": "no_instrument"}
	var completed_ids: Array = []
	var active = _instrument.get_active_quests()
	if active is Array:
		for q in active:
			if not (q is Dictionary):
				continue
			var qid = int(q.get("id", -1))
			if qid < 0:
				continue
			var completed_or_claimed = false
			var complete_result = _instrument.quest_complete_or_claim(qid)
			completed_or_claimed = bool(complete_result.get("completed_or_claimed", false))
			if completed_or_claimed:
				completed_ids.append(qid)

	# Use cached offers for this cycle's selection, then invalidate after.
	# Like a human opening the quest board: you see current offers, act on them,
	# and next time you open the board you get fresh stochastic rolls.
	var offers: Array = _cached_offers if not _cached_offers.is_empty() else []
	if offers.is_empty():
		var offer_result = _instrument.quest_offer_all()
		var offered = offer_result.get("offers", [])
		if offered is Array:
			offers = offered
	var resources = _get_resource_map()
	var known_pairs = _instrument.get_known_vocab_pairs() if _instrument else []
	var known_emojis: Dictionary = {}
	if known_pairs is Array:
		for pair in known_pairs:
			if not (pair is Dictionary):
				continue
			var north = str(pair.get("north", ""))
			var south = str(pair.get("south", ""))
			if north != "":
				known_emojis[north] = true
			if south != "":
				known_emojis[south] = true

	var accepted = false
	var completed_after_accept = false
	var accepted_offer_index = -1
	var accepted_quest_id = -1
	var accepted_offer: Dictionary = {}
	var rerolls_spent: int = 0

	if offers is Array:
		# Use pre-ranked offer index from policy if available and still valid
		var hint_idx = int(policy_params.get("offer_index", -1))
		if hint_idx >= 0 and hint_idx < offers.size():
			var hint_offer = offers[hint_idx]
			if hint_offer is Dictionary:
				var resource = str(hint_offer.get("resource", ""))
				var qty = float(hint_offer.get("quantity", 0.0))
				var have = float(resources.get(resource, 0.0))
				if resource != "" and qty > 0.0 and have >= qty:
					accepted_offer_index = hint_idx
		# Fall back to scoring if hint was stale or missing
		if accepted_offer_index < 0:
			accepted_offer_index = _select_best_affordable_offer(offers, resources, known_emojis)

		# --- Reroll loop (A): if best offer has no milk progress, spend 🐇 to fish ---
		# Like a human scanning the quest board and rerolling bad slots.
		var max_rerolls = int(policy_params.get("max_rerolls", 3))
		if accepted_offer_index >= 0 and max_rerolls > 0 and _instrument:
			var best_offer = offers[accepted_offer_index] if accepted_offer_index < offers.size() else {}
			var best_has_milk_progress = _offer_has_milk_progress(best_offer, known_emojis)
			var reroll_attempts = 0
			while not best_has_milk_progress and reroll_attempts < max_rerolls:
				# Check if we can afford a reroll (costs 🐇)
				var preflight = _instrument.preflight_action_cost("quest_reroll")
				if not bool(preflight.get("ok", false)):
					break  # Can't afford 🐇
				# Spend 🐇 and regenerate offers
				var commit = _instrument.commit_action_cost("quest_reroll", {}, "policy_reroll")
				if not bool(commit.get("ok", false)):
					break  # Spend failed
				reroll_attempts += 1
				rerolls_spent += 1
				# Regenerate all offers (fresh stochastic rolls)
				var new_offer_result = _instrument.quest_offer_all()
				var new_offered = new_offer_result.get("offers", [])
				if new_offered is Array and not new_offered.is_empty():
					offers = new_offered
				resources = _get_resource_map()  # Resources changed (spent 🐇)
				# Re-score with new offers
				accepted_offer_index = _select_best_affordable_offer(offers, resources, known_emojis)
				if accepted_offer_index >= 0 and accepted_offer_index < offers.size():
					best_offer = offers[accepted_offer_index]
					best_has_milk_progress = _offer_has_milk_progress(best_offer, known_emojis)
				else:
					break  # No affordable offers after reroll

		if accepted_offer_index >= 0 and accepted_offer_index < offers.size():
			var offer = offers[accepted_offer_index]
			if offer is Dictionary:
				accepted_offer = offer
				var accept_result = _instrument.quest_accept(offer)
				accepted = bool(accept_result.get("accepted", false))
				accepted_quest_id = int(offer.get("id", -1))
				if accepted and accepted_quest_id >= 0:
					var complete_after_result = _instrument.quest_complete_or_claim(accepted_quest_id)
					completed_after_accept = bool(complete_after_result.get("completed_or_claimed", false))

	# Invalidate offer cache after quest interaction — next policy_step gets fresh
	# stochastic rolls, just like a human re-opening the quest board.
	# Non-quest actions (probe, drain, skip, discover) keep using cached offers.
	_cached_offers_pairs_count = -1

	var ok = (completed_ids.size() > 0) or accepted or completed_after_accept
	return {
		"ok": ok,
		"action": "quest_cycle",
		"completed_ids": completed_ids,
		"offers_seen": offers.size() if offers is Array else 0,
		"accepted": accepted,
		"accepted_offer_index": accepted_offer_index,
		"accepted_quest_id": accepted_quest_id,
		"accepted_offer_reward_vocab_north": str(accepted_offer.get("reward_vocab_north", "")),
		"accepted_offer_reward_vocab_south": str(accepted_offer.get("reward_vocab_south", "")),
		"completed_after_accept": completed_after_accept,
		"rerolls_spent": rerolls_spent,
	}


func _select_best_affordable_offer(offers: Array, resources: Dictionary, known_emojis: Dictionary) -> int:
	var affordable_rows: Array = []
	for i in range(offers.size()):
		var offer = offers[i]
		if not (offer is Dictionary):
			continue
		var resource = str(offer.get("resource", ""))
		var qty = float(offer.get("quantity", 0.0))
		if resource == "" or qty <= 0.0:
			continue
		if float(resources.get(resource, 0.0)) < qty:
			continue
		var north = str(offer.get("reward_vocab_north", ""))
		var south = str(offer.get("reward_vocab_south", ""))
		var reward_resources = offer.get("reward_resources", {})
		var reward_sum = 0.0
		if reward_resources is Dictionary:
			for emoji in reward_resources.keys():
				reward_sum += max(0.0, float(reward_resources.get(emoji, 0.0)))
		var novelty = 0.0
		if north != "" and not known_emojis.has(north):
			novelty += 1.0
		if south != "" and not known_emojis.has(south):
			novelty += 1.0
		var discovery_aff = float(offer.get("discovery_affinity", 0.0))
		var milk_bonus = 420.0 if (north == "🍼" or south == "🍼") else 0.0
		# Milk graph hint (tie-breaker; real learning comes from reward signal)
		var milk_hint = 0.0
		for e in [north, south]:
			if e == "":
				continue
			var d = PolicyStateProjector.milk_distance(e)
			if d < 8:
				milk_hint = maxf(milk_hint, 8.0 / maxf(1.0, float(d)))
			var c = PolicyStateProjector.milk_cascade_value(e)
			if c < 8:
				milk_hint = maxf(milk_hint, 5.0 / maxf(1.0, float(c)))
		var pair_frontier_bonus = 20.0 if novelty >= 2.0 else 0.0
		var surplus = (1.0 - qty / max(1.0, float(resources.get(resource, 0.0)))) * 12.0
		var score = reward_sum * 0.22 + novelty * 32.0 + pair_frontier_bonus + milk_bonus + milk_hint + discovery_aff * 18.0 + surplus
		affordable_rows.append({
			"idx": i,
			"score": score,
			"novelty": novelty,
			"is_milk": milk_bonus > 0.0,
		})

	if affordable_rows.is_empty():
		return -1
	var frontier: Array = []
	for row in affordable_rows:
		if bool(row.get("is_milk", false)) or float(row.get("novelty", 0.0)) > 0.0:
			frontier.append(row)
	var pool: Array = frontier if not frontier.is_empty() else affordable_rows
	var best_idx = int(pool[0].get("idx", -1))
	var best_score = float(pool[0].get("score", -1e18))
	for row in pool:
		var score = float(row.get("score", -1e18))
		if score > best_score:
			best_score = score
			best_idx = int(row.get("idx", -1))
	return best_idx


func _offer_has_milk_progress(offer: Dictionary, known_emojis: Dictionary) -> bool:
	"""Check if an offer teaches vocab that advances toward milk in the webway.
	Returns true if the north or south emoji has milk_distance < MAX or
	unlocks a new faction path via webway_offer_value."""
	if offer.is_empty():
		return false
	var north = str(offer.get("reward_vocab_north", ""))
	var south = str(offer.get("reward_vocab_south", ""))
	if north == "" and south == "":
		return false  # No vocab reward at all
	for emoji in [north, south]:
		if emoji == "":
			continue
		# Direct milk distance check
		var d = PolicyStateProjector.milk_distance(emoji)
		if d < PolicyStateProjector._MILK_MAX_DISTANCE:
			return true
		# Webway 2-hop check: does this emoji unlock a faction path toward milk?
		var w = PolicyStateProjector.webway_offer_value(emoji, known_emojis)
		if w < PolicyStateProjector._MILK_MAX_DISTANCE:
			return true
	return false


func _parse_positions(raw_positions, biome_name: String) -> Array[Vector2i]:
	"""Parse positions from JSON array [[x,y],...] or fall back to biome positions."""
	var positions: Array[Vector2i] = []
	if raw_positions is Array and not raw_positions.is_empty():
		for entry in raw_positions:
			if entry is Array and entry.size() >= 2:
				positions.append(Vector2i(int(entry[0]), int(entry[1])))
			elif entry is Dictionary:
				if entry.has("x") and entry.has("y"):
					positions.append(Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0))))
			elif entry is String:
				var raw = str(entry).strip_edges()
				if raw.begins_with("(") and raw.ends_with(")"):
					raw = raw.substr(1, raw.length() - 2)
				var parts = raw.split(",", false)
				if parts.size() >= 2:
					var x_raw = parts[0].strip_edges()
					var y_raw = parts[1].strip_edges()
					if x_raw.is_valid_int() and y_raw.is_valid_int():
						positions.append(Vector2i(int(x_raw), int(y_raw)))
	elif biome_name != "" and _snapshot_service:
		var biome_positions = _instrument.get_biome_positions(biome_name) if _instrument else []
		for pos in biome_positions:
			positions.append(pos)
	return positions


func _execute_channel_drain(biome_name: String, source_emoji: String, target_emoji: String) -> Dictionary:
	"""Quantum dissipative channel: apply cross-register Lindblad operator.

	Creates L = √γ (σ⁺_target ⊗ σ⁻_source) on the biome's quantum computer,
	transferring population from source_emoji to target_emoji through the
	density matrix. This is a genuine quantum channel, not a flag toggle.

	Falls back to classical drain activation if the quantum channel can't be
	created (e.g., emojis on the same qubit axis or not registered).
	"""
	if not _farm or not _farm.grid:
		return {"ok": false, "error": "farm_not_ready"}

	# Find the biome's quantum computer
	var biome = null
	for b in _farm.grid.get_all_biomes():
		var bname = ""
		if b.has_method("get_biome_type"):
			bname = str(b.get_biome_type())
		elif "name" in b:
			bname = str(b.name)
		if bname == biome_name:
			biome = b
			break

	if not biome or not biome.quantum_computer:
		return {"ok": false, "error": "biome_not_found", "biome": biome_name}

	var qc = biome.quantum_computer
	var rm = qc.register_map

	# Resolve qubits for source and target emojis
	if not rm.has(source_emoji) or not rm.has(target_emoji):
		return {
			"ok": false,
			"error": "emoji_not_in_register_map",
			"biome": biome_name,
			"source_emoji": source_emoji,
			"target_emoji": target_emoji,
			"registered_emojis": rm.all_emojis() if rm.has_method("all_emojis") else [],
		}

	var source_qubit = rm.qubit(source_emoji)
	var target_qubit = rm.qubit(target_emoji)

	if source_qubit == target_qubit:
		# Same axis — fall back to single-qubit drain toward target
		var target_pole = rm.pole(target_emoji)
		var source_pole = 1 - target_pole
		var before_pop = qc.get_marginal(source_qubit, source_pole)
		qc._apply_lindblad_1q(source_qubit, source_pole, target_pole, 0.5, 1.0)
		var after_pop = qc.get_marginal(source_qubit, source_pole)
		return {
			"ok": true,
			"biome": biome_name,
			"channel_type": "same_axis_drain",
			"source_emoji": source_emoji,
			"target_emoji": target_emoji,
			"population_transferred": max(0.0, before_pop - after_pop),
		}

	# Cross-register quantum channel: directed population transfer
	var before_source_pop = qc.get_population(source_emoji)
	var before_target_pop = qc.get_population(target_emoji)

	qc.apply_cross_register_channel(source_qubit, target_qubit, 0.5, 1.0)

	var after_source_pop = qc.get_population(source_emoji)
	var after_target_pop = qc.get_population(target_emoji)

	return {
		"ok": true,
		"biome": biome_name,
		"channel_type": "cross_register",
		"source_emoji": source_emoji,
		"target_emoji": target_emoji,
		"source_qubit": source_qubit,
		"target_qubit": target_qubit,
		"source_pop_delta": after_source_pop - before_source_pop,
		"target_pop_delta": after_target_pop - before_target_pop,
		"population_transferred": max(0.0, before_source_pop - after_source_pop),
	}


func _allow_rig_resource_injection() -> bool:
	var raw = OS.get_environment("RIG_ALLOW_RESOURCE_INJECTION").to_lower()
	if raw == "":
		return true
	return raw in ["1", "true", "yes", "on"]
