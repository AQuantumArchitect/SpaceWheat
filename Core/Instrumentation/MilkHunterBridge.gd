class_name MilkHunterBridge
extends Node

## MilkHunterBridge - Phrame-paced IPC bridge for visual milk hunter runs.
##
## Reads the rig queue file (queue.jsonl) and processes exactly 1 action per
## _physics_process tick (6Hz). This lets the Python milk hunter drive the game
## at visualization speed so you can watch quantum bubbles, quests, and economy
## unfold in real-time.
##
## Usage:
##   RIG_PHRAME_BRIDGE=1 ./dev_launch.sh
##   python3 .../milk_hunt_runner_graphics_waits.py --config .../milk_hunt_phrame_bridge.json \
##       --reuse-listener --no-stop --no-clear-rig

const BiomeHandler = preload("res://UI/Handlers/BiomeHandler.gd")
const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")

signal action_executed(turn_id: int, action: String, result: Dictionary)
signal bridge_idle()
signal bridge_stopped()

var _queue_path: String = ""  # Resolved from XDG_ROOT in setup()
var _result_path: String = ""  # Resolved from XDG_ROOT in setup()
var _queue_file_byte_offset: int = 0
var _active: bool = true
var _idle_emitted: bool = false

var _farm: Node = null
var _farm_instrument: Node = null  # FarmInstrument
var _last_offers: Array = []
var _actions_executed: int = 0
var _start_time_ms: int = 0
var _auto_quit: bool = false  # If true, quit game on stop action

var _verbose = null


func _ready() -> void:
	_verbose = get_node_or_null("/root/VerboseConfig")


func setup(farm_ref: Node, farm_instrument_ref: Node) -> void:
	if not _verbose:
		_verbose = get_node_or_null("/root/VerboseConfig")
	_farm = farm_ref
	_farm_instrument = farm_instrument_ref
	_start_time_ms = Time.get_ticks_msec()

	# Match milk hunter's XDG path (/tmp/sw_godot_milk_hunt by default)
	var xdg_root = OS.get_environment("XDG_ROOT")
	if xdg_root == "":
		xdg_root = "/tmp/sw_godot_milk_hunt"
	var app_name = OS.get_environment("APPLICATION_NAME")
	if app_name == "":
		app_name = "SpaceWheat - Quantum Farm"
	var rig_dir = xdg_root.path_join("godot").path_join("app_userdata").path_join(app_name).path_join("rig")
	_queue_path = rig_dir.path_join("queue.jsonl")
	_result_path = rig_dir.path_join("results.jsonl")

	# Check if game should auto-quit when milk hunt completes
	_auto_quit = OS.get_environment("RIG_AUTO_QUIT") == "1"

	_ensure_rig_dir()
	set_physics_process(true)
	print("[MilkHunterBridge] Phrame bridge active:")
	print("  XDG_ROOT: %s" % xdg_root)
	print("  Queue: %s" % _queue_path)
	print("  Auto-quit: %s" % ("enabled" if _auto_quit else "disabled (handoff mode)"))
	print("  Result: %s" % _result_path)


func _physics_process(_delta: float) -> void:
	if not _active:
		return
	var line = _read_next_line()
	if line == "":
		if not _idle_emitted:
			_idle_emitted = true
			bridge_idle.emit()
		return
	_idle_emitted = false
	var data = JSON.parse_string(line)
	if data == null:
		# Partial write — don't advance offset, retry next tick
		return
	_execute_action(data)


func _read_next_line() -> String:
	var file = FileAccess.open(_queue_path, FileAccess.READ)
	if not file:
		return ""
	var file_len = file.get_length()
	if _queue_file_byte_offset >= file_len:
		return ""
	file.seek(_queue_file_byte_offset)
	var line = file.get_line()
	if line.strip_edges() == "":
		return ""
	_queue_file_byte_offset = file.get_position()
	return line


func _execute_action(cmd: Dictionary) -> void:
	var action = str(cmd.get("action", ""))
	var turn_id = int(cmd.get("turn", -1))
	var started = Time.get_ticks_msec()

	var result: Dictionary = {"ok": true, "turn": turn_id, "action": action}

	match action:
		"resource_snapshot":
			result["resources"] = _farm_instrument.get_resource_snapshot()

		"add_resource":
			var emoji = str(cmd.get("emoji", ""))
			var amount = int(cmd.get("amount", 0))
			result["added"] = _farm_instrument.add_resource(emoji, amount, "rig_add")

		"set_resource":
			var emoji = str(cmd.get("emoji", ""))
			var amount = int(cmd.get("amount", 0))
			result["set"] = _farm_instrument.set_resource(emoji, amount, "rig_set")

		"grid_snapshot":
			result["grid"] = _farm_instrument.get_grid_snapshot()

		"known_vocab_pairs":
			result["pairs"] = _farm_instrument.get_known_vocab_pairs()

		"offer_quests":
			var offers = _farm_instrument.get_quest_offers_for_current_biome()
			_last_offers = offers
			result["offers"] = _slim_offers(offers)

		"accept_offer":
			var idx = int(cmd.get("offer_index", -1))
			if idx < 0 or idx >= _last_offers.size():
				result = {"ok": false, "turn": turn_id, "action": action, "error": "invalid_offer_index"}
			else:
				var offer = _last_offers[idx]
				result["accepted"] = _farm_instrument.accept_quest_data(offer)
				result["quest_id"] = offer.get("id", -1)

		"active_quests":
			result["quests"] = _farm_instrument.get_active_quests()

		"complete_quest":
			var quest_id = int(cmd.get("quest_id", -1))
			result["completed"] = _farm_instrument.complete_quest(quest_id)

		"complete_or_claim":
			var quest_id = int(cmd.get("quest_id", -1))
			result["completed_or_claimed"] = _farm_instrument.complete_or_claim_quest(quest_id)

		"configure_economy":
			var overrides = cmd.get("overrides", {})
			if not (overrides is Dictionary) or overrides.is_empty():
				result = {"ok": false, "turn": turn_id, "action": action, "error": "empty_overrides"}
			else:
				result["configured"] = _farm_instrument.configure_economy(overrides)

		"balance_snapshot":
			result["balance"] = _farm_instrument.get_balance_snapshot()

		"balance_patch":
			var patch = cmd.get("patch", {})
			if not (patch is Dictionary) or patch.is_empty():
				result = {"ok": false, "turn": turn_id, "action": action, "error": "empty_patch"}
			else:
				result["balance"] = _farm_instrument.patch_balance(patch, "rig_balance_patch")

		"balance_reset":
			result["balance"] = _farm_instrument.reset_balance_to_default()

		"balance_export":
			var export_path = str(cmd.get("path", "user://saves/balance_profile_last.json"))
			result["balance"] = _farm_instrument.export_balance_profile(export_path)

		"balance_load":
			var load_path = str(cmd.get("path", ""))
			result["balance"] = _farm_instrument.load_balance_profile(load_path)

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
					result["gate_result"] = _farm_instrument.gate_inject(gate_name, positions)

		"probe_cycle":
			var biome_name = str(cmd.get("biome", ""))
			result["probe"] = _probe_cycle(biome_name)

		"configure_seed_state":
			result["seed_state"] = _configure_seed_state(cmd)

		"explore_biome":
			if not _farm or not _farm.has_method("explore_biome"):
				result = {"ok": false, "turn": turn_id, "action": action, "error": "farm_explore_unavailable"}
			else:
				result["explore_biome"] = _farm.explore_biome()

		"victory_lap":
			result["victory_lap"] = _run_victory_lap()

		"inject_vocab":
			var biome_name = str(cmd.get("biome", ""))
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

		"stop":
			_active = false
			result["stopped"] = true
			result["duration_ms"] = Time.get_ticks_msec() - started
			_write_result(result)
			_actions_executed += 1
			action_executed.emit(turn_id, action, result)
			bridge_stopped.emit()

			if _auto_quit:
				_v_info("Bridge stopped (turn %d) - auto-quitting in 1 second" % turn_id)
				print("[MilkHunterBridge] Milk hunt complete. Shutting down game...")
				# Brief delay to ensure result is written to disk
				await get_tree().create_timer(1.0).timeout
				get_tree().quit()
			else:
				_v_info("Bridge stopped (turn %d) - handoff to user" % turn_id)
				print("[MilkHunterBridge] Milk hunt complete. Game ready for user control.")
			return

		_:
			result = {"ok": false, "turn": turn_id, "action": action, "error": "unknown_action"}

	result["duration_ms"] = Time.get_ticks_msec() - started
	_write_result(result)
	_actions_executed += 1
	action_executed.emit(turn_id, action, result)


# ==========================================================================
# Replicated from rig_listener.gd — these access farm internals beyond
# FarmInstrument's API
# ==========================================================================

func _probe_cycle(biome_name: String) -> Dictionary:
	if not _farm or not ("terminal_pool" in _farm) or not _farm.terminal_pool:
		return {"success": false, "error": "no_terminal_pool"}
	if not _farm.grid or not _farm.grid.biomes:
		return {"success": false, "error": "no_biomes"}
	var biome = _farm.grid.biomes.get(biome_name, null)
	if not biome:
		return {"success": false, "error": "unknown_biome"}

	var active_biome_manager = get_node_or_null("/root/ActiveBiomeManager")
	if active_biome_manager and active_biome_manager.has_method("set_active_biome"):
		active_biome_manager.set_active_biome(biome_name)
	var obs = get_node_or_null("/root/ObservationFrame")
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
		milk_amount = float(_farm.economy.get_resource("\ud83c\udf7c"))

	return {
		"success": true,
		"biomes": biomes,
		"explore_total": explore_total,
		"explore_failures": explore_failures,
		"measure_total": measure_total,
		"measure_failures": measure_failures,
		"harvest_total": harvest_total,
		"harvest_failures": harvest_failures,
		"milk_after": milk_amount
	}


func _configure_seed_state(cmd: Dictionary) -> Dictionary:
	var out: Dictionary = {"ok": true}
	var gsm = get_node_or_null("/root/GameStateManager")
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
		var obs = get_node_or_null("/root/ObservationFrame")
		if obs and obs.has_method("get_loadable_biomes"):
			default_pool = obs.get_loadable_biomes()
		else:
			default_pool = ["StarterForest", "Village", "BioticFlux", "StellarForges", "FungalNetworks", "VolcanicWorlds"]
		var pool: Array[String] = []
		for biome_name in default_pool:
			if biome_name not in unlocked_biomes:
				pool.append(biome_name)
		gsm.current_state.unexplored_biome_pool = pool
		var active_biome_manager = get_node_or_null("/root/ActiveBiomeManager")
		if active_biome_manager and active_biome_manager.has_method("set_biome_order"):
			active_biome_manager.set_biome_order(unlocked_biomes)

	var unexplored_biomes = _sanitize_biomes(cmd.get("unexplored_biomes", []))
	if not unexplored_biomes.is_empty():
		gsm.current_state.unexplored_biome_pool = unexplored_biomes.duplicate()
		out["unexplored_biomes"] = unexplored_biomes

	var active_biome = str(cmd.get("active_biome", ""))
	if active_biome != "":
		var obs2 = get_node_or_null("/root/ObservationFrame")
		if obs2 and obs2.has_method("set_neutral_biome"):
			obs2.set_neutral_biome(active_biome)
		var active_biome_manager2 = get_node_or_null("/root/ActiveBiomeManager")
		if active_biome_manager2 and active_biome_manager2.has_method("set_active_biome"):
			active_biome_manager2.set_active_biome(active_biome)
		out["active_biome"] = active_biome

	return out


# ==========================================================================
# Helpers
# ==========================================================================

func _write_result(payload: Dictionary) -> void:
	var line = JSON.stringify(payload)
	var file = FileAccess.open(_result_path, FileAccess.READ_WRITE)
	if not file:
		file = FileAccess.open(_result_path, FileAccess.WRITE)
	if not file:
		return
	file.seek_end()
	file.store_line(line)
	file.close()


func _ensure_rig_dir() -> void:
	var rig_dir = _queue_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(rig_dir)


func _slim_offers(offers: Array) -> Array:
	var slim: Array = []
	for offer in offers:
		var quest_type = int(offer.get("type", -1))
		var completion_action = "complete_quest" if quest_type == 0 else "complete_or_claim"
		slim.append({
			"id": offer.get("id", -1),
			"faction": offer.get("faction", ""),
			"type": quest_type,
			"resource": offer.get("resource", ""),
			"quantity": offer.get("quantity", 0),
			"body": offer.get("body", ""),
			"time_limit": offer.get("time_limit", -1),
			"reward_vocab_north": offer.get("reward_vocab_north", ""),
			"reward_vocab_south": offer.get("reward_vocab_south", ""),
			"reward_resources": offer.get("reward_resources", {}),
			"biome": offer.get("biome", ""),
			"status": offer.get("status", ""),
			"completion_action": completion_action
		})
	return slim


func _parse_positions(raw_positions, biome_name: String) -> Array[Vector2i]:
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


func get_actions_executed() -> int:
	return _actions_executed


func get_actions_per_second() -> float:
	var elapsed_ms = Time.get_ticks_msec() - _start_time_ms
	if elapsed_ms <= 0:
		return 0.0
	return float(_actions_executed) / (float(elapsed_ms) / 1000.0)


func is_active() -> bool:
	return _active


func _v_info(msg: String) -> void:
	if _verbose:
		_verbose.info("bridge", "\ud83c\udf09", msg)
