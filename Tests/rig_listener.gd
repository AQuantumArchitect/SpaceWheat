#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Live rig listener: persists a single game session and executes one queued turn at a time.
## Queue file:   user://rig/queue.jsonl (append-only)
## Result file:  user://rig/results.jsonl (append-only)
##
## Actions supported:
## - open_overlay: {name: "quests"|"vocabulary"|"controls"}
## - offer_quests
## - accept_offer: {offer_index: int}
## - complete_quest: {quest_id: int}
## - complete_or_claim: {quest_id: int}
## - claim_quest: {quest_id: int}
## - accept_quest: {quest_id: int}
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
## - time_skip: {phrames: int, delta?: float}
## - configure_economy: {overrides: {action_costs?, gate_costs?, quest_rewards?, production?}}
## - configure_seed_state: {known_pairs, unlocked_biomes, unexplored_biomes, active_biome}
## - probe_cycle: {biome: String}
## - discover_biome (preferred; biome unlock/expansion)
## - explore_biome (deprecated alias for discover_biome)
## - victory_lap
## - victory_lap_partial: {selected_biomes?: [String], max_registers?: int, milk_spend?: int, phase_window?: int}
## - batcher_metrics
## - save_game: {slot: int}
## - load_game: {slot: int}
## - load_game_alias: {alias: String}
## - save_info: {slot: int}
## - stop
##
## Future actions can be added to the match statement in _execute_command().

const PlayerShellScene = preload("res://UI/PlayerShell.tscn")
const BiomeHandler = preload("res://UI/Handlers/BiomeHandler.gd")
const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")

var _queue_path = "user://rig/queue.jsonl"
var _result_path = "user://rig/results.jsonl"
var _bridge_sentinel_path = "user://rig/bridge_ready"

var _queue_offset: int = 0
var _shell = null
var _farm_instrument = null
var _instrument = null  # QuantumInstrument
var _farm = null
var _loop_started: bool = false
var _last_offers: Array = []
var _is_headless: bool = true
var _turn_log_enabled: bool = true


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

	# Boot UI so FarmInstrument exists (no visualization in headless)
	await boot_manager.boot_ui(_farm, _shell, null)

	_on_ready()


func _on_ready() -> void:
	_ensure_rig_dir()
	_apply_rig_logger_profile()
	_write_bridge_ready_sentinel()
	if _shell and "farm_instrument" in _shell:
		_farm_instrument = _shell.farm_instrument
		if _farm_instrument and "instrument" in _farm_instrument:
			_instrument = _farm_instrument.instrument
	var turn_log_env = OS.get_environment("RIG_VERBOSE_TURN_LOG").to_lower()
	_turn_log_enabled = (not _is_headless) or (turn_log_env in ["1", "true", "yes", "on"])
	print("🎛️ Rig ready. Waiting for turns in:", _queue_path)
	if not _loop_started:
		_loop_started = true
		call_deferred("_run_loop")


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


func _run_loop() -> void:
	while true:
		_poll_queue()
		# process_always=true prevents deadlock if UI/menu pauses the SceneTree.
		await create_timer(0.1, true).timeout


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
		_handle_line(raw)
	file.close()


func _ensure_farm_instrument() -> bool:
	if _farm_instrument:
		return true
	if _shell and "farm_instrument" in _shell:
		_farm_instrument = _shell.farm_instrument
	return _farm_instrument != null


func _requires_farm_instrument(action: String) -> bool:
	return action in [
		"open_overlay",
		"offer_quests",
		"accept_offer",
		"accept_quest",
		"complete_quest",
		"complete_or_claim",
		"claim_quest",
		"resource_snapshot",
		"add_resource",
		"set_resource",
		"resource_mutations",
		"grid_snapshot",
		"biome_positions",
		"active_quests",
		"known_vocab_pairs",
		"inject_vocab",
		"gate_inject",
		"lindblad_pump",
		"lindblad_drain",
		"time_skip",
		"configure_economy",
		"victory_lap",
		"victory_lap_partial",
		"batcher_metrics",
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
	_turn_log("BEGIN", turn_id, action)
	_ensure_runtime_unpaused_for_rig()
	var result = _execute_command(cmd)
	result["turn"] = turn_id
	result["action"] = action
	_write_result(result)
	var ok = bool(result.get("ok", false))
	if ok:
		_turn_log("END", turn_id, action, "ok=true dur=%sms" % [str(result.get("duration_ms", -1))])
	else:
		_turn_log("ERR", turn_id, action, "error=%s dur=%sms" % [str(result.get("error", "unknown")), str(result.get("duration_ms", -1))])
	if bool(result.get("__stop__", false)):
		quit()


func _execute_command(cmd: Dictionary) -> Dictionary:
	var action = cmd.get("action", "")
	var turn_id = cmd.get("turn", -1)
	var started = Time.get_ticks_msec()

	if _requires_farm_instrument(action) and not _ensure_farm_instrument():
		return {
			"ok": false,
			"turn": turn_id,
			"action": action,
			"error": "no_farm_instrument",
			"duration_ms": Time.get_ticks_msec() - started
		}

	var result: Dictionary = {"ok": true, "turn": turn_id, "action": action}

	match action:
		"open_overlay":
			var name = cmd.get("name", "")
			var opened = _farm_instrument.open_quest_board() if name == "quests" \
				else _farm_instrument.open_vocabulary_panel() if name == "vocabulary" \
				else _farm_instrument.open_controls_panel() if name == "controls" \
				else false
			result["opened"] = opened

		"offer_quests":
			var offers = _farm_instrument.get_quest_offers_for_current_biome()
			_last_offers = offers
			var full = bool(cmd.get("full", false))
			var include_reward_resources = bool(cmd.get("include_reward_resources", true))
			result["offers"] = offers if full else _slim_offers(offers, include_reward_resources)

		"accept_offer":
			var idx = int(cmd.get("offer_index", -1))
			if idx < 0 or idx >= _last_offers.size():
				result = {"ok": false, "turn": turn_id, "action": action, "error": "invalid_offer_index"}
			else:
				var offer = _last_offers[idx]
				result["accepted"] = _farm_instrument.accept_quest_data(offer)
				result["quest_id"] = offer.get("id", -1)

		"accept_quest":
			var quest_id = int(cmd.get("quest_id", -1))
			result["accepted"] = _farm_instrument.accept_quest_by_id(quest_id)

		"complete_quest":
			var quest_id = int(cmd.get("quest_id", -1))
			result["completed"] = _farm_instrument.complete_quest(quest_id)

		"complete_or_claim":
			var quest_id = int(cmd.get("quest_id", -1))
			result["completed_or_claimed"] = _farm_instrument.complete_or_claim_quest(quest_id)

		"claim_quest":
			var quest_id = int(cmd.get("quest_id", -1))
			result["claimed"] = _farm_instrument.claim_quest(quest_id)

		"resource_snapshot":
			result["resources"] = _farm_instrument.get_resource_snapshot()

		"add_resource":
			var emoji = str(cmd.get("emoji", ""))
			var amount = int(cmd.get("amount", 0))
			if not _allow_rig_resource_injection():
				result = {"ok": false, "turn": turn_id, "action": action, "error": "rig_resource_injection_disabled"}
			else:
				result["added"] = _farm_instrument.add_resource(emoji, amount, "rig_add")

		"set_resource":
			var emoji = str(cmd.get("emoji", ""))
			var amount = int(cmd.get("amount", 0))
			if not _allow_rig_resource_injection():
				result = {"ok": false, "turn": turn_id, "action": action, "error": "rig_resource_injection_disabled"}
			else:
				result["set"] = _farm_instrument.set_resource(emoji, amount, "rig_set")

		"resource_mutations":
			var limit = int(cmd.get("limit", 40))
			result["mutations"] = _farm_instrument.get_recent_resource_mutations(limit)

		"grid_snapshot":
			result["grid"] = _farm_instrument.get_grid_snapshot()

		"biome_positions":
			var biome_name = str(cmd.get("biome", ""))
			result["biome"] = biome_name
			result["positions"] = _farm_instrument.get_biome_positions(biome_name)

		"active_quests":
			var full = bool(cmd.get("full", false))
			var active = _farm_instrument.get_active_quests()
			result["quests"] = active if full else _slim_active_quests(active)

		"known_vocab_pairs":
			result["pairs"] = _farm_instrument.get_known_vocab_pairs()

		"inject_vocab":
			var biome_name = str(cmd.get("biome", ""))
			if _instrument and biome_name != "":
				result["inject_result"] = _instrument.action_inject_vocabulary(biome_name)
			else:
				var pair_index = int(cmd.get("pair_index", -1))
				var pairs = _farm_instrument.get_known_vocab_pairs()
				if biome_name == "" or pair_index < 0 or pair_index >= pairs.size():
					result = {"ok": false, "turn": turn_id, "action": action, "error": "invalid_inject_args"}
				else:
					var positions_raw = _farm_instrument.get_biome_positions(biome_name)
					if positions_raw.is_empty():
						result = {"ok": false, "turn": turn_id, "action": action, "error": "no_biome_positions"}
					else:
						var pair = pairs[pair_index]
						var positions: Array[Vector2i] = []
						for pos in positions_raw:
							positions.append(pos)
						result["inject_result"] = BiomeHandler.inject_vocabulary(_farm, positions, pair)

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
				elif _instrument:
					result["gate_result"] = _instrument.gate_inject(gate_name, positions)
				else:
					result["gate_result"] = _farm_instrument.gate_inject(gate_name, positions)

		"lindblad_pump":
			var biome_name = str(cmd.get("biome", ""))
			var raw_positions = cmd.get("positions", [])
			var positions: Array[Vector2i] = _parse_positions(raw_positions, biome_name)
			if positions.is_empty():
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_valid_positions"}
			elif _instrument:
				result["pump_result"] = _instrument.lindblad_pump(positions)
			else:
				result["pump_result"] = _farm_instrument.lindblad_pump(positions)

		"lindblad_drain":
			var biome_name = str(cmd.get("biome", ""))
			var raw_positions = cmd.get("positions", [])
			var positions: Array[Vector2i] = _parse_positions(raw_positions, biome_name)
			if positions.is_empty():
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_valid_positions"}
			elif _instrument:
				result["drain_result"] = _instrument.lindblad_drain(positions)
			else:
				result["drain_result"] = _farm_instrument.lindblad_drain(positions)

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

		"configure_economy":
			var overrides = cmd.get("overrides", {})
			if not (overrides is Dictionary) or overrides.is_empty():
				result = {"ok": false, "turn": turn_id, "action": action, "error": "empty_overrides"}
			else:
				result["configured"] = _farm_instrument.configure_economy(overrides)

		"configure_seed_state":
			if _instrument:
				result["seed_state"] = _instrument.configure_seed_state(cmd)
			else:
				result["seed_state"] = _configure_seed_state(cmd)

		"probe_cycle":
			var biome_name = str(cmd.get("biome", ""))
			var full_probe = bool(cmd.get("full", false))
			if _instrument:
				var probe_data = _instrument.probe_cycle(biome_name)
				result["probe"] = probe_data if full_probe else _slim_probe_result(probe_data)
				if _farm_instrument and _farm_instrument.has_method("show_probe_cycle_status"):
					_farm_instrument.show_probe_cycle_status(biome_name, probe_data)
			else:
				var probe_data_fallback = _probe_cycle(biome_name)
				result["probe"] = probe_data_fallback if full_probe else _slim_probe_result(probe_data_fallback)

		"discover_biome", "explore_biome":
			if _instrument:
				if _instrument.has_method("action_discover_biome"):
					result["discover_biome"] = _instrument.action_discover_biome()
				else:
					result["discover_biome"] = _instrument.action_explore_biome()
			elif not _farm or not _farm.has_method("explore_biome"):
				result = {"ok": false, "turn": turn_id, "action": action, "error": "farm_discover_unavailable"}
			else:
				result["discover_biome"] = _farm.explore_biome()

		"victory_lap":
			if _instrument:
				result["victory_lap"] = _instrument.victory_lap()
			else:
				result["victory_lap"] = _run_victory_lap()

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
			if _instrument:
				result["victory_lap_partial"] = _instrument.victory_lap_partial(
					selected_biomes,
					max_registers,
					milk_spend,
					phase_window
				)
			else:
				result["victory_lap_partial"] = _run_victory_lap_partial(
					selected_biomes,
					max_registers,
					milk_spend,
					phase_window
				)

		"batcher_metrics":
			result["metrics"] = _farm_instrument.get_batcher_metrics() if _farm_instrument else {}

		"save_game":
			var slot = int(cmd.get("slot", -1))
			var gsm = get_root().get_node_or_null("GameStateManager")
			if not gsm:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_game_state_manager"}
			else:
				result["slot"] = slot
				result["saved"] = gsm.save_game(slot)
				result["save_path"] = gsm.get_save_path(slot) if gsm.has_method("get_save_path") else ""

		"load_game":
			var slot = int(cmd.get("slot", -1))
			var gsm = get_root().get_node_or_null("GameStateManager")
			if not gsm:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_game_state_manager"}
			else:
				result["slot"] = slot
				result["loaded"] = gsm.load_and_apply(slot)

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

		"save_info":
			var slot = int(cmd.get("slot", -1))
			var gsm = get_root().get_node_or_null("GameStateManager")
			if not gsm:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_game_state_manager"}
			else:
				result["slot"] = slot
				result["info"] = gsm.get_save_info(slot)

		"stop":
			result["stopped"] = true
			result["__stop__"] = true

		_:
			result = {"ok": false, "turn": turn_id, "action": action, "error": "unknown_action"}

	result["duration_ms"] = Time.get_ticks_msec() - started
	return result


func _write_result(payload: Dictionary) -> void:
	var line = JSON.stringify(payload)
	var result_file_path = ProjectSettings.globalize_path(_result_path)
	var file = FileAccess.open(result_file_path, FileAccess.READ_WRITE)
	if not file:
		file = FileAccess.open(result_file_path, FileAccess.WRITE)
	if not file:
		return
	file.seek_end()
	file.store_line(line)
	file.close()


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
		_clear_bridge_ready_sentinel()


func _apply_rig_logger_profile() -> void:
	var verbose = get_root().get_node_or_null("VerboseConfig")
	if not verbose:
		return

	var profile = OS.get_environment("RIG_LOG_PROFILE").to_lower()
	if profile == "":
		profile = "quiet"

	match profile:
		"quiet":
			verbose.enable_console_output = false
			verbose.enable_file_logging = false
		"test", "trace":
			_set_all_logger_levels(verbose, 4)
		"debug":
			_set_all_logger_levels(verbose, 3)
		"normal":
			pass

	var overrides_raw = OS.get_environment("RIG_LOG_CATEGORY_LEVELS")
	if overrides_raw == "":
		return
	for token in overrides_raw.split(","):
		var trimmed = token.strip_edges()
		if trimmed == "":
			continue
		var kv = trimmed.split(":")
		if kv.size() != 2:
			continue
		var category = kv[0].strip_edges().to_lower()
		var level_name = kv[1].strip_edges().to_lower()
		var level = _parse_log_level(level_name)
		if level >= 0 and verbose.has_method("set_category_level"):
			verbose.set_category_level(category, level)


func _set_all_logger_levels(verbose: Node, level: int) -> void:
	if not verbose.has_method("get_all_categories") or not verbose.has_method("set_category_level"):
		return
	var categories = verbose.get_all_categories()
	for category in categories:
		verbose.set_category_level(str(category), level)


func _parse_log_level(level_name: String) -> int:
	match level_name:
		"error":
			return 0
		"warn", "warning":
			return 1
		"info":
			return 2
		"debug":
			return 3
		"trace":
			return 4
		_:
			return -1


func _slim_offers(offers: Array, include_reward_resources: bool = true) -> Array:
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
		if offer.has("market_projection"):
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
		if _farm_instrument and _farm_instrument.has_method("show_probe_cycle_status"):
			_farm_instrument.show_probe_cycle_status(biome_name, explore_fail)
		return explore_fail
	var terminal = explore.get("terminal", null)
	var measure = ProbeActions.action_measure(terminal, biome, _farm.economy)
	if not measure.get("success", false):
		var measure_fail = {"success": false, "stage": "measure", "details": measure}
		if _farm_instrument and _farm_instrument.has_method("show_probe_cycle_status"):
			_farm_instrument.show_probe_cycle_status(biome_name, measure_fail)
		return measure_fail
	var pop = ProbeActions.action_pop(terminal, _farm.terminal_pool, _farm.economy, _farm)
	var out = {"success": true, "explore": explore, "measure": measure, "pop": pop, "active_biome": biome_name}
	if _farm_instrument and _farm_instrument.has_method("show_probe_cycle_status"):
		_farm_instrument.show_probe_cycle_status(biome_name, out)
	return out


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

	_apply_visual_stage_delay("explore_batch")

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

	_apply_visual_stage_delay("measure_batch")

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
	OS.delay_msec(int(round(seconds * 1000.0)))


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
		gsm.current_state.known_emojis = gsm.current_state.get_known_emojis()
		out["known_pairs"] = known_pairs

	var unlocked_biomes = _sanitize_biomes(cmd.get("unlocked_biomes", []))
	if not unlocked_biomes.is_empty():
		gsm.current_state.unlocked_biomes = unlocked_biomes.duplicate()
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
		var obs2 = get_root().get_node_or_null("ObservationFrame")
		if obs2 and obs2.has_method("set_neutral_biome"):
			obs2.set_neutral_biome(active_biome)
		var active_biome_manager2 = get_root().get_node_or_null("ActiveBiomeManager")
		if active_biome_manager2 and active_biome_manager2.has_method("set_active_biome"):
			active_biome_manager2.set_active_biome(active_biome)
		out["active_biome"] = active_biome

	return out


func _sanitize_biomes(raw) -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	if raw is Array:
		for value in raw:
			var biome_name = str(value)
			if biome_name == "" or seen.has(biome_name):
				continue
			seen[biome_name] = true
			out.append(biome_name)
	return out


func _sanitize_known_pairs(raw) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	if raw is Array:
		for pair in raw:
			if not (pair is Dictionary):
				continue
			var north = str(pair.get("north", ""))
			var south = str(pair.get("south", ""))
			if north == "" or south == "" or north == south:
				continue
			var key = "%s|%s" % [north, south]
			if seen.has(key):
				continue
			seen[key] = true
			out.append({"north": north, "south": south})
	return out


func _perform_time_skip(phrames: int, delta: float) -> Dictionary:
	if _instrument and _instrument.has_method("time_skip"):
		return _instrument.time_skip(phrames, delta)
	if _farm_instrument and _farm_instrument.has_method("time_skip"):
		return _farm_instrument.time_skip(phrames, delta)
	if _farm and _farm.has_method("time_skip_phrames"):
		var dt = delta if delta > 0.0 else 1.0 / 6.0
		return _farm.time_skip_phrames(phrames, dt)
	return {"ok": false, "error": "time_skip_unavailable"}


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
	if not _farm_instrument:
		return {}
	var snap = _farm_instrument.get_resource_snapshot()
	if not (snap is Dictionary):
		return {}
	var resources = snap.get("resources", {})
	return resources if resources is Dictionary else {}


func _resource_threshold_met(resources: Dictionary, threshold: Dictionary) -> bool:
	if threshold.is_empty():
		return false
	for emoji in threshold.keys():
		var target = float(threshold.get(emoji, 0.0))
		if float(resources.get(emoji, 0.0)) < target:
			return false
	return true


func _parse_positions(raw_positions, biome_name: String) -> Array[Vector2i]:
	"""Parse positions from JSON array [[x,y],...] or fall back to biome positions."""
	var positions: Array[Vector2i] = []
	if raw_positions is Array and not raw_positions.is_empty():
		for entry in raw_positions:
			if entry is Array and entry.size() >= 2:
				positions.append(Vector2i(int(entry[0]), int(entry[1])))
	elif biome_name != "" and _farm_instrument:
		var biome_positions = _farm_instrument.get_biome_positions(biome_name)
		for pos in biome_positions:
			positions.append(pos)
	return positions


func _allow_rig_resource_injection() -> bool:
	var raw = OS.get_environment("RIG_ALLOW_RESOURCE_INJECTION").to_lower()
	if raw == "":
		return true
	return raw in ["1", "true", "yes", "on"]
