#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Live rig listener: persists a single game session and executes one queued turn at a time.
## Queue file:   user://rig/queue.jsonl (append-only)
## Result file:  user://rig/results.jsonl (append-only)
##
## Actions supported:
## - open_overlay: {_name: "quests"|"atlas"|"controls"}
## - offer_quests: {include_reward_resources?: bool, include_market_projection?: bool}
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
## - known_icons
## - story_flags — returns {flags_fired: {id→phrame}, story_log: [{id,act,arc_beat,...}]}
## - consume_berry: {biome?: String, count?: int, phase_each?: float} — rig-only: advance berry harvest counter
## - bridge_build: {a: {biome, north, south}, b: {biome, north, south}} — raise a Majorana span
## - bridge_braid: {id: int, end: "a"|"b"} — S at end a, √X at end b
## - bridge_fuse: {id: int, roll?: float} — Born-sample joint parity (deterministic with roll)
## - bridge_list — BridgeRegister.to_dict() snapshot
## - inject_icon: {biome: String, icon_index: int}
## - gate_inject: {gate: String, biome: String, positions: [[x,y],...]}
## - lindblad_pump: {biome: String, positions: [[x,y],...]}
## - lindblad_drain: {biome: String, positions: [[x,y],...]}
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
## - configure_seed_state: {known_icons, unlocked_biomes, unexplored_biomes, active_biome, policy_graph_path?, policy_graph_jsonl?}
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
## - action_cost: {_name: String, context?: Dictionary}
## - action_preflight: {_name: String, context?: Dictionary}
## - save_game: {slot: int}
## - save_game_path: {path: String}
## - load_game: {slot: int}
## - load_game_path: {path: String}
## - save_info: {slot: int}
## - overlay_snapshot: {overlay: String} — returns structured dict from overlay.get_snapshot()
## - widget_snapshot: {widget: String} — returns structured dict from widget.get_snapshot()
## - hud_snapshot: {hud: String} — returns structured dict from hud.get_snapshot()
## - full_snapshot — aggregates all widget + HUD + overlay snapshots in one call
## - policy_snapshot
## - press_key: {keycode?: int, key?: String, shift?: bool, settle_frames?: int}
## - key_sequence: {keys: [{keycode?: int, key?: String, shift?: bool, settle_frames?: int}, ...]}
## - stop
##
## Future actions can be added to the match statement in _execute_command().

# PlayerShell.tscn is loaded at RUNTIME (in _bootstrap), not preloaded here: a
# parse-time preload would eagerly compile the whole UI tree (OverlayManager →
# BiomeInspectorOverlay) before the autoloads register, and BiomeInspectorOverlay
# references the `IconRegistry` autoload — yielding "Identifier not found" at compile
# time. Runtime load() defers compilation until after boot_session wires autoloads.
const QuantumInstrumentClass = preload("res://Core/Instrumentation/QuantumInstrument.gd")
const BiomeAlignmentCalc = preload("res://Core/Quantum/BiomeAlignmentCalculator.gd")
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")
# PlayerInputMacroRunner removed — macro input not available in headless mode

signal action_executed(turn_id: int, action: String, result: Dictionary)
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
var _app_root = null  # headed real-boot root, kept for RIG_DRIVE_TITLE deferred start
var _pending_boot_request: Dictionary = {}
var _last_offers: Array = []
var _is_headless: bool = true
var _turn_log_enabled: bool = true
var _polling: bool = false  # Re-entrancy guard for async commands (e.g. victory_lap visual delays)
var _poll_interval_ms: int = 0
var _next_poll_at_ms: int = 0
var _result_writer: FileAccess = null

func _phrame_hz() -> float:
	return float(PhysicsConfig.PHRAME_HZ)


func _init() -> void:
	print("🎛️ Rig listener starting...")
	call_deferred("_bootstrap")


func _resolve_rig_path(env_name: String, default_path: String) -> String:
	var override_path := OS.get_environment(env_name).strip_edges()
	if override_path == "":
		return default_path
	return override_path


func _bootstrap() -> void:
	_queue_path = _resolve_rig_path("RIG_QUEUE_PATH", _queue_path)
	_result_path = _resolve_rig_path("RIG_RESULT_PATH", _result_path)
	_bridge_sentinel_path = _resolve_rig_path("RIG_BRIDGE_SENTINEL_PATH", _bridge_sentinel_path)
	_heartbeat_path = _resolve_rig_path("RIG_HEARTBEAT_PATH", _heartbeat_path)

	var is_headless = RuntimeEnv.is_headless()
	_is_headless = is_headless
	var load_slot = int(OS.get_environment("RIG_LOAD_SLOT")) if OS.get_environment("RIG_LOAD_SLOT") != "" else -1
	var scenario_id = OS.get_environment("RIG_SCENARIO") if OS.get_environment("RIG_SCENARIO") != "" else SaveStore.DEFAULT_SCENARIO_ID
	var boot_request := {
		"slot": load_slot,
		"scenario_id": scenario_id,
		"headless": is_headless,
	}
	# ONE boot path for player and rig alike: bring up the real AppRoot and let it boot
	# AppRoot → GameRoot → the app-owned PlayerShell (headless or headed). The rig then
	# drives keys into the SAME shell a human would — no parallel hand-mounted shell.
	var AppRootClass = load("res://scenes/AppRoot.gd")
	var app_root = AppRootClass.new()
	app_root.name = "AppRoot"
	get_root().add_child(app_root)
	_app_root = app_root
	_pending_boot_request = boot_request

	if RuntimeEnv.drive_title():
		# Leave the title up; the rig drives the real player path (title → F opens the X
		# menu → start → welcome) via the `start_from_title` action. The shell already
		# exists from AppRoot._ready; _farm is resolved by start_from_title.
		await process_frame
		await process_frame
		_shell = app_root.get_player_shell()
		if not _shell:
			print("❌ Title boot did not yield shell; cannot start rig")
			return
	else:
		# Request a boot exactly like the player's "New game" menu does: set pending so
		# AppRoot._maybe_auto_start drives the real start_game with the rig's scenario
		# (auto-starts headless; the pending flag also triggers it headed). Then await
		# the shared shell + farm. AppRoot itself calls set_farm_attached(true).
		var gsm = get_root().get_node_or_null("GameStateManager")
		if gsm and gsm.pending_boot:
			gsm.pending_boot.requested = true
			gsm.pending_boot.slot = load_slot
			gsm.pending_boot.scenario_id = scenario_id
		if not await _await_real_boot(app_root):
			print("❌ Real boot did not yield farm/shell; cannot start rig")
			return
		_shell = app_root.get_player_shell()
		_farm = app_root.game_root.farm if (app_root.game_root and is_instance_valid(app_root.game_root)) else null
		if not _farm or not _shell:
			print("❌ Real boot did not yield farm/shell; cannot start rig")
			return

	_on_ready()


func _await_real_boot(app_root) -> bool:
	# Wait for AppRoot's auto-start to finish booting GameRoot → farm. Bounded so a
	# broken boot fails loudly instead of hanging the rig forever.
	var max_frames := 3000  # ~50s @ 60Hz; a healthy boot completes in well under 1s
	for _i in range(max_frames):
		var gr = app_root.game_root if (app_root and "game_root" in app_root) else null
		if gr and is_instance_valid(gr) and gr._started and gr.farm != null:
			return true
		await process_frame
	return false


func _on_ready() -> void:
	_ensure_rig_dir()
	_prime_queue_cursor_to_end()
	_apply_rig_logger_profile()
	_snapshot_service = InstrumentLocator.resolve_snapshot_service(_shell)
	_instrument = InstrumentLocator.resolve_quantum_instrument(_shell)
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
		# Line 1: unix timestamp
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
		"known_icons",
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
		"reservoir_sweep",
		"offer_quests",
		"accept_offer",
		"accept_quest",
		"complete_quest",
		"complete_or_claim",
		"claim_quest",
		"add_resource",
		"set_resource",
		"resource_mutations",
		"story_flags",
		"consume_berry",
		"bridge_build",
		"bridge_braid",
		"bridge_fuse",
		"bridge_list",
		"inject_icon",
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
		"configure_discovery",
		"balance_snapshot",
		"balance_patch",
		"balance_reset",
		"balance_export",
		"balance_load",
		"farm_variable_graph",
		"farm_variable_graph_apply",
		"farm_variable_graph_load",
		"action_cost",
		"action_preflight",
		"configure_seed_state",
		"probe_cycle",
		"discover_biome",
		"victory_lap",
		"victory_lap_partial",
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
			var _name = cmd.get("name", "")
			var opened = _snapshot_service.open_quest_board() if _name == "quests" \
				else _snapshot_service.open_icon_panel() if _name == "atlas" \
				else _snapshot_service.open_controls_panel() if _name == "controls" \
				else false
			result["opened"] = opened

		"entropy_snapshot":
			# Read-only balance probe: per-biome von Neumann entropy S, purity, the
			# Boltzmann temperature kT, the reap bank kT·S, and a sample surprisal
			# price (−kT·log p of the biome's most-populated atom). Drives the
			# webway-vs-decay measurement (no state mutation).
			var rows: Array = []
			if _farm and "grid" in _farm and _farm.grid and _farm.grid.has_biomes():
				for bkey in _farm.grid.get_biome_names():
					var biome = _farm.grid.get_biome(str(bkey))
					if not biome or not biome.quantum_computer:
						continue
					var qc = biome.quantum_computer
					var s_val: float = float(qc.get_entropy()) if qc.has_method("get_entropy") else 0.0
					var purity: float = float(qc.get_purity()) if qc.has_method("get_purity") else 0.0
					var kT: float = float(EnergyPricing.biome_temperature(biome, _farm))
					var pops: Dictionary = qc.get_all_populations() if qc.has_method("get_all_populations") else {}
					var pmax: float = 0.0
					for e in pops:
						pmax = maxf(pmax, float(pops[e]))
					var sample_price: float = EnergyPricing.surprisal_energy(pmax, kT) if pmax > 0.0 else 0.0
					rows.append({
						"biome": str(bkey), "S": s_val, "purity": purity, "kT": kT,
						"bank_kTS": kT * s_val, "sample_price": sample_price, "atoms": pops.size()
					})
			result["entropy_snapshot"] = rows

		"reap_probe":
			# Conservation probe: for each biome, bracket the REAL reap-bank
			# extraction with S before/after and confirm the entropy-bank payout
			# (credits) ≈ kT·ΔS. Exercises ProbeActions._collect_reap_rewards
			# directly (mutates live state — rig only). expected vs credits should
			# match within rounding; a near-pure biome pays ≈0 (dS≈0).
			var probe_rows: Array = []
			if _farm and "grid" in _farm and _farm.grid and _farm.grid.has_biomes():
				var f2c: float = float(BalanceService.get_tuning_value(_farm, "flux_to_credits"))
				for bkey in _farm.grid.get_biome_names():
					var biome = _farm.grid.get_biome(str(bkey))
					if not biome or not biome.quantum_computer:
						continue
					var qc = biome.quantum_computer
					if not qc.has_method("get_entropy"):
						continue
					var S0: float = float(qc.get_entropy())
					var kT: float = float(EnergyPricing.biome_temperature(biome, _farm))
					var rr: Dictionary = ProbeActions._collect_reap_rewards([biome], _farm.economy, _farm, f2c)
					var S1: float = float(qc.get_entropy())
					var dS: float = S0 - S1
					probe_rows.append({
						"biome": str(bkey), "S0": S0, "S1": S1, "dS": dS, "kT": kT,
						"expected": kT * dS, "credits": int(rr.get("total_icon_credits", 0)),
						"flux_credits": int(rr.get("total_flux_credits", 0))
					})
			result["reap_probe"] = probe_rows

		"reservoir_sweep":
			# Map the broad graph's reservoir REGIME across (H-coupling × L-rate)
			# scales — the edge-of-chaos dial. Per grid point: retune the global
			# physics knobs, rebuild every biome's operators at that regime, reset to
			# ground, evolve, then read learning/intelligence metrics:
			#   richness     = mean von-Neumann-style entropy  (dynamic range)
			#   integration  = mean pairwise mutual information (information sharing)
			#   order        = mean purity                      (1=frozen, low=lively)
			# One boot; the canonical regime is restored at the end. Offline tool.
			var h_scales: Array = cmd.get("h_scales", [0.5, 1.0, 2.0])
			var l_scales: Array = cmd.get("l_scales", [0.5, 1.0, 2.0])
			# Optional generator-switch overrides — probe any of the four physics quadrants
			# (coherent × dissipative). Default: leave the live config untouched.
			var sweep_coherent = cmd.get("coherent", null)
			var sweep_dissipative = cmd.get("dissipative", null)
			var diss_on: bool = (bool(sweep_dissipative) if sweep_dissipative != null else BalanceConfig.dissipative_enabled())
			# Dissipative OFF: no Lindblad operators are built, so lindblad_rate_scale is inert —
			# the L axis just repeats the same regime. Collapse it to a single point ⇒ a 1D scan
			# over hamiltonian_coupling_scale. Expect order≈1 (pure), richness tracking H.
			if not diss_on:
				l_scales = [1.0]
			var sweep_phrames: int = int(cmd.get("phrames", 600))
			var sweep_rows: Array = []
			if _farm and "grid" in _farm and _farm.grid and _farm.grid.has_biomes():
				var BalanceCfg = load("res://Core/GameMechanics/BalanceConfig.gd")
				var bnames: Array = []
				for bk in _farm.grid.get_biome_names():
					bnames.append(str(bk))
				for hs in h_scales:
					for ls in l_scales:
						var ov := {
							"hamiltonian_coupling_scale": float(hs),
							"lindblad_rate_scale": float(ls),
						}
						if sweep_coherent != null:
							ov["coherent_dynamics"] = bool(sweep_coherent)
						if sweep_dissipative != null:
							ov["dissipative_dynamics"] = bool(sweep_dissipative)
						BalanceCfg.set_physics_override(ov)
						_reservoir_rebuild_all(bnames)
						_perform_time_skip(sweep_phrames, -1.0)
						var per: Array = []
						var agg_s := 0.0
						var agg_p := 0.0
						var agg_mi := 0.0
						var cnt := 0
						for bn in bnames:
							var biome = _farm.grid.get_biome(bn)
							if not biome or not biome.quantum_computer:
								continue
							var qc = biome.quantum_computer
							var s_val := float(qc.get_entropy()) if qc.has_method("get_entropy") else 0.0
							var pur := float(qc.get_purity()) if qc.has_method("get_purity") else 0.0
							var mi := _mean_mutual_information(qc)
							per.append({"biome": bn, "S": s_val, "purity": pur, "mi": mi})
							agg_s += s_val
							agg_p += pur
							agg_mi += mi
							cnt += 1
						var inv := 1.0 / float(maxi(cnt, 1))
						sweep_rows.append({
							"h": float(hs), "l": float(ls),
							"richness": agg_s * inv, "integration": agg_mi * inv, "order": agg_p * inv,
							"biomes": per,
						})
				# Restore the canonical regime so the session isn't left retuned.
				BalanceCfg.clear_physics_override()
				_reservoir_rebuild_all(bnames)
			result["reservoir_sweep"] = sweep_rows

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
			var accepted := false
			for offer in _last_offers:
				if offer is Dictionary and int(offer.get("id", -1)) == quest_id:
					var accept_result = _instrument.quest_accept(offer)
					accepted = bool(accept_result.get("accepted", false))
					break
			if not accepted:
				var accept_by_id_result = _instrument.quest_accept_by_id(quest_id)
				accepted = bool(accept_by_id_result.get("accepted", false))
			result["accepted"] = accepted

		"complete_quest":
			var quest_id = int(cmd.get("quest_id", -1))
			var complete_result = _instrument.quest_complete(quest_id)
			result["completed"] = bool(complete_result.get("completed", false))
			result["quest_id"] = int(complete_result.get("quest_id", quest_id))
			result["rewards"] = complete_result.get("rewards", {})

		"complete_or_claim":
			var quest_id = int(cmd.get("quest_id", -1))
			var coc_result = _instrument.quest_complete_or_claim(quest_id)
			result["completed_or_claimed"] = bool(coc_result.get("completed_or_claimed", false))

		"claim_quest":
			var quest_id = int(cmd.get("quest_id", -1))
			var claim_result = _instrument.quest_claim(quest_id)
			result["claimed"] = bool(claim_result.get("claimed", false))

		"resource_snapshot":
			result["resources"] = _instrument.get_resource_snapshot() if _instrument else {}

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
			result["grid"] = _instrument.get_grid_snapshot() if _instrument else {}

		"biome_positions":
			var biome_name = str(cmd.get("biome", ""))
			result["biome"] = biome_name
			result["positions"] = _instrument.get_biome_positions(biome_name) if _instrument else []

		"active_quests":
			var full = bool(cmd.get("full", false))
			var active = _instrument.get_active_quests() if _instrument else []
			if not (active is Array):
				active = []
			result["quests"] = active if full else _slim_active_quests(active)

		"story_offers":
			# Pending story arc-quest offers (separate from market offers).
			var sqm = _resolve_quest_manager()
			result["story_offers"] = sqm.get_story_offers() if sqm and sqm.has_method("get_story_offers") else []

		"known_icons":
			var icons = _instrument.get_known_icons() if _instrument else []
			result["icons"] = icons if icons is Array else []

		"atom_diversity":
			# Distinct atom emojis across all loaded biomes + per-biome breakdown — used to
			# calibrate village_identity's atom_diversity_gte threshold empirically.
			if _farm == null or _farm.grid == null:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_grid"}
			else:
				var ad_seen: Dictionary = {}
				var ad_per: Dictionary = {}
				for ad_name in _farm.grid.get_biome_names():
					var ad_b = _farm.grid.get_biome(str(ad_name))
					if ad_b == null or not ("quantum_computer" in ad_b) or ad_b.quantum_computer == null or ad_b.quantum_computer.register_map == null:
						continue
					var ad_keys = ad_b.quantum_computer.register_map.coordinates.keys()
					ad_per[str(ad_name)] = ad_keys.size()
					for ad_atom in ad_keys:
						ad_seen[str(ad_atom)] = true
				result["distinct"] = ad_seen.size()
				result["atoms"] = ad_seen.keys()
				result["per_biome"] = ad_per

		"confirm_state":
			# Read QII._confirm_pending so a rig driver can see whether a destructive
			# verb (Cull/Trim/Break) armed its Q→F confirm chord, and the active biome.
			var ci = _shell.instrument_input if _shell and "instrument_input" in _shell else null
			result["pending"] = (ci._confirm_pending.duplicate() if ci != null and "_confirm_pending" in ci and ci._confirm_pending != null else {})
			var cf_abm = get_root().get_node_or_null("/root/ActiveBiomeManager")
			result["active_biome"] = str(cf_abm.get_active_biome()) if cf_abm and cf_abm.has_method("get_active_biome") else ""
			result["current_frame"] = str(ToolConfig.get_current_frame()) if ToolConfig else ""

		"story_flags":
			var farm = _farm
			if farm == null:
				result["flags_fired"] = {}
				result["story_log"] = []
			else:
				result["flags_fired"] = farm.story_flags_fired.duplicate() if "story_flags_fired" in farm else {}
				result["story_log"] = farm.story_log.duplicate(true) if "story_log" in farm else []

		"biome_slots":
			# Read-only: the TYUIOP slot → biome mapping. grid_snapshot lists biomes in a
			# different (sorted) order, so a driver must use THIS to press the right biome key.
			var bsl_abm = get_root().get_node_or_null("/root/ActiveBiomeManager")
			if bsl_abm == null:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_active_biome_manager"}
			else:
				var bsl_slots: Array = []
				var n_slots: int = InputBindingRegistry.get_biome_keys().size()
				for si in range(n_slots):
					var bn := str(bsl_abm.get_biome_for_slot(si)) if bsl_abm.has_method("get_biome_for_slot") else ""
					var sk := str(bsl_abm.get_slot_key(si)) if bsl_abm.has_method("get_slot_key") else ""
					if bn != "":
						bsl_slots.append({"slot": si, "key": sk, "biome": bn})
				result["slots"] = bsl_slots
				result["active"] = str(bsl_abm.get_active_biome()) if bsl_abm.has_method("get_active_biome") else ""

		"board_visible":
			# Read-only: the live QuestBoard market's SORTED visible offers (the order the plot
			# keys G-; select), each tagged with reward_resources + affordability. Lets a smart
			# driving heuristic pick the keyboard index of an affordable, wanted-reward contract
			# instead of blindly accepting all (which jams the 5-slot commitment cap).
			var bv_om = _resolve_overlay_manager()
			var bv_board = bv_om.get_overlay("quests") if bv_om and bv_om.has_method("get_overlay") else null
			if bv_board == null:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_quest_board"}
			else:
				var bv_pool: Array = bv_board._offer_pool if ("_offer_pool" in bv_board) else []
				var bv_inv: Dictionary = bv_board._get_inventory() if bv_board.has_method("_get_inventory") else {}
				var bv_mode: int = int(bv_board._market_sort_mode) if ("_market_sort_mode" in bv_board) else 0
				var bv_visible: Array = MarketView.sort_view(bv_pool, bv_inv, bv_mode)
				var bv_out: Array = []
				for vi in range(bv_visible.size()):
					var vo = bv_visible[vi]
					var vr := str(vo.get("resource", ""))
					var vq := int(vo.get("quantity", 0))
					bv_out.append({
						"index": vi,
						"faction": str(vo.get("faction", "")),
						"resource": vr,
						"quantity": vq,
						"reward_resources": vo.get("reward_resources", {}),
						"affordable": float(bv_inv.get(vr, 0.0)) >= float(vq),
					})
				result["visible"] = bv_out

		"board_state":
			# Read the LIVE QuestBoard overlay's market state to pinpoint why keyboard
			# accept returns nothing: frame, pool size, selection, status note.
			var bs_om = _resolve_overlay_manager()
			var bs_board = bs_om.get_overlay("quests") if bs_om and bs_om.has_method("get_overlay") else null
			if bs_board == null:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_quest_board"}
			else:
				result["visible"] = bool(bs_board.visible)
				result["frame_id"] = str(bs_board.frame_id) if ("frame_id" in bs_board) else "?"
				result["offer_pool_size"] = (bs_board._offer_pool.size() if ("_offer_pool" in bs_board) else -1)
				result["selected_index"] = (int(bs_board._selected_index) if ("_selected_index" in bs_board) else -999)
				result["market_status_note"] = (str(bs_board._market_status_note) if ("_market_status_note" in bs_board) else "")
				result["nb_name"] = (str(bs_board._nb_name) if ("_nb_name" in bs_board) else "")
				result["pair"] = [(str(bs_board._pair_a_name) if ("_pair_a_name" in bs_board) else ""), (str(bs_board._pair_b_name) if ("_pair_b_name" in bs_board) else "")]
				# The biome the board actually scoped to (the live current_biome it used).
				var bs_cb = bs_board.current_biome if ("current_biome" in bs_board) else null
				result["current_biome"] = (str(bs_cb.name) if bs_cb != null and "name" in bs_cb else "<null>")

		"nb_probe":
			var nbp_name: String = str(cmd.get("biome", "Village"))
			var nbp_farm = _farm
			if nbp_farm == null or not nbp_farm.has_method("get_market_lattice"):
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_farm_or_lattice"}
			else:
				var nbp_lattice = nbp_farm.get_market_lattice()
				var nbp_biome = nbp_farm.grid.get_biome(nbp_name) if nbp_farm.grid else null
				if nbp_lattice == null or nbp_biome == null:
					result = {"ok": false, "turn": turn_id, "action": action, "error": "no_lattice_or_biome", "biome": nbp_name}
				else:
					var nbp_qc = nbp_biome.quantum_computer if "quantum_computer" in nbp_biome else null
					result["biome"] = nbp_name
					result["has_qc"] = nbp_qc != null
					result["num_qubits"] = (nbp_qc.register_map.num_qubits if nbp_qc != null and nbp_qc.register_map != null else -1)
					result["best_neighborhood"] = str(nbp_lattice.best_neighborhood_name(nbp_biome))
					var nbp_abm = get_root().get_node_or_null("/root/ActiveBiomeManager")
					result["active"] = str(nbp_abm.get_active_biome()) if nbp_abm and nbp_abm.has_method("get_active_biome") else ""
					# Admitted factions (signature gate) + whether the target faction is among them.
					var nbp_admitted: Array = FactionBiomeMap.factions_for_biome_by_signature(nbp_biome)
					result["admitted_factions"] = nbp_admitted
					var nbp_target := str(cmd.get("faction", ""))
					if nbp_target != "":
						result["target_admitted"] = nbp_admitted.has(nbp_target)
						var nbp_reg = get_root().get_node_or_null("IconRegistry")
						var nbp_freg = nbp_farm.faction_density.get_registry() if "faction_density" in nbp_farm and nbp_farm.faction_density != null else null
						if nbp_freg != null and nbp_freg.has_method("get_by_name"):
							var tf = nbp_freg.get_by_name(nbp_target)
							var spoken: Array = []
							for em in ["🍞", "⚙", "🪵", "🔥", "❄", "🌱"]:
								if tf != null and tf.has_method("speaks") and tf.speaks(em):
									spoken.append(em)
							result["target_speaks"] = spoken

		"board_market":
			# Read-only: replicate QuestBoard._refresh_pool's KEYBOARD market scoping
			# (best tension pair → propose_pair_offers, else neighborhood-scoped) and run
			# each contract through QuestPipeline.from_market_contract, so we see EXACTLY
			# what the keyboard player's market shows — incl. reward_resources (🔨 etc.).
			var bm_name: String = str(cmd.get("biome", "Village"))
			var bm_farm = _farm
			if bm_farm == null or not bm_farm.has_method("get_market_lattice"):
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_farm_or_lattice"}
			else:
				var bm_lattice = bm_farm.get_market_lattice()
				var bm_biome = bm_farm.grid.get_biome(bm_name) if bm_farm.grid else null
				if bm_lattice == null or bm_biome == null:
					result = {"ok": false, "turn": turn_id, "action": action, "error": "no_lattice_or_biome"}
				else:
					var all_biomes: Dictionary = bm_farm.grid.get_all_biomes() if bm_farm.grid.has_method("get_all_biomes") else {}
					var best_pair: Dictionary = bm_lattice.best_live_tension_pair(all_biomes)
					var raw_contracts: Array = []
					var scope := ""
					if not best_pair.is_empty():
						var ba = all_biomes.get(str(best_pair.get("a", "")), null)
						var bb = all_biomes.get(str(best_pair.get("b", "")), null)
						if ba != null and bb != null:
							raw_contracts = bm_lattice.propose_pair_offers(ba, bb, 24)
							scope = "pair:%s×%s" % [best_pair.get("a", ""), best_pair.get("b", "")]
					if raw_contracts.is_empty():
						var nb := str(bm_lattice.best_neighborhood_name(bm_biome))
						if nb != "":
							raw_contracts = bm_lattice.propose_neighborhood_offers_scoped(bm_biome, nb, 24)
							scope = "neighborhood:%s" % nb
					var bm_offers: Array = []
					for rc in raw_contracts:
						var q: Dictionary = QuestPipeline.from_market_contract(rc, bm_biome)
						if q.is_empty():
							continue
						bm_offers.append({
							"faction": q.get("faction", ""),
							"resource": q.get("resource", ""),
							"quantity": q.get("quantity", 0),
							"reward_resources": q.get("reward_resources", {}),
						})
					result["scope"] = scope
					result["count"] = bm_offers.size()
					result["offers"] = bm_offers

		"flag_progress":
			# Read-only: per-predicate + combined smooth_and score for a named story flag,
			# exactly as the C-surface Arc tab shows it. The instrument for driving an arc
			# beat to its FLAG_FIRE_THRESHOLD (0.85) without forcing the flag.
			var fp_qm = _resolve_quest_manager()
			var fp_id: String = str(cmd.get("id", ""))
			if fp_qm == null or not fp_qm.has_method("get_all_story_flags"):
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_quest_manager"}
			else:
				var fp_flag: Dictionary = {}
				for f in fp_qm.get_all_story_flags():
					if str(f.get("id", "")) == fp_id:
						fp_flag = f
						break
				if fp_flag.is_empty():
					result = {"ok": false, "turn": turn_id, "action": action, "error": "unknown_flag", "id": fp_id}
				else:
					var fp_preds: Array = fp_flag.get("predicates", [])
					var fp_scored: Array = []
					for p in fp_preds:
						fp_scored.append({"pred": p, "score": fp_qm.evaluate_predicate_score(p)})
					result["id"] = fp_id
					result["fired"] = (_farm != null and "story_flags_fired" in _farm and _farm.story_flags_fired.has(fp_id))
					result["combined"] = fp_qm.evaluate_flag_score(fp_flag)
					result["threshold"] = fp_qm.FLAG_FIRE_THRESHOLD
					result["predicates"] = fp_scored

		"berry_track":
			# Start Berry-phase tracking on qubit(s) of a biome (test harness for the
			# incorporation loop, bypassing the Icon-hat keypress ritual).
			var bt_name: String = str(cmd.get("biome", "StarterForest"))
			var bt_biome = _farm.grid.get_biome(bt_name) if _farm and _farm.grid else null
			if bt_biome == null or not ("quantum_computer" in bt_biome) or bt_biome.quantum_computer == null:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_biome_or_qc"}
			else:
				var bt_qc = bt_biome.quantum_computer
				var bt_n: int = bt_qc.register_map.num_qubits if bt_qc.register_map else 0
				var bt_qubit = cmd.get("qubit", -1)
				var bt_started: Array = []
				if int(bt_qubit) >= 0:
					bt_qc.berry_register.start_tracking(int(bt_qubit))
					bt_started.append(int(bt_qubit))
				else:
					for qi in range(bt_n):
						bt_qc.berry_register.start_tracking(qi)
						bt_started.append(qi)
				result["tracked"] = bt_started

		"viz_bloch":
			# Diagnostic: read the viz cache's per-qubit z (population proxy) AND the live
			# qc's z, so a driver can verify the projection isn't stale after a discrete
			# mutation (gate) with no evolution tick. They should match.
			var vb_name: String = str(cmd.get("biome", "StarterForest"))
			var vb_biome = _farm.grid.get_biome(vb_name) if _farm and _farm.grid else null
			if vb_biome == null or not ("quantum_computer" in vb_biome) or vb_biome.quantum_computer == null:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_biome_or_qc"}
			else:
				var vb_qc = vb_biome.quantum_computer
				var vb_n: int = vb_qc.register_map.num_qubits if vb_qc.register_map else 0
				var live_packet: PackedFloat64Array = vb_qc.export_bloch_packet() if vb_qc.has_method("export_bloch_packet") else PackedFloat64Array()
				var per: Array = []
				for qi in range(vb_n):
					var cache_z: float = float(vb_biome.viz_cache.get_bloch(qi).get("z", 999.0)) if vb_biome.viz_cache else 999.0
					var live_z: float = live_packet[qi * 9 + 4] if live_packet.size() > qi * 9 + 4 else 999.0
					per.append({"qubit": qi, "cache_z": cache_z, "live_z": live_z})
				result["qubits"] = per

		"berry_state":
			# Read per-qubit Berry-phase state (accumulated/ripe) + consumed totals.
			var bs_name: String = str(cmd.get("biome", "StarterForest"))
			var bs_biome = _farm.grid.get_biome(bs_name) if _farm and _farm.grid else null
			if bs_biome == null or not ("quantum_computer" in bs_biome) or bs_biome.quantum_computer == null:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_biome_or_qc"}
			else:
				var bs_qc = bs_biome.quantum_computer
				var bs_n: int = bs_qc.register_map.num_qubits if bs_qc.register_map else 0
				var br = bs_qc.berry_register
				var per: Array = []
				for qi in range(bs_n):
					per.append({
						"qubit": qi,
						"tracked": br.is_tracked(qi),
						"phase": br.get_phase(qi),
						"ripe": br.is_ripe(qi),
						"threshold": br.get_ripe_threshold(qi),
					})
				result["qubits"] = per
				result["consumed_count"] = br.get_consumed_count()
				result["consumed_phase"] = br.get_consumed_phase()

		"energy_variance":
			# Closed-native chaos↔stability readout: Var(H) = ⟨H²⟩−⟨H⟩² (restless vs settled),
			# alongside the OPEN-system relaxation quantities (ρ eigenvalue gap, purity) so a
			# probe can show they're degenerate in the closed system (gap≡1, purity≡1) while
			# Var(H) actually discriminates.
			var ev_name: String = str(cmd.get("biome", "StarterForest"))
			var ev_biome = _farm.grid.get_biome(ev_name) if _farm and _farm.grid else null
			if ev_biome == null or not ("quantum_computer" in ev_biome) or ev_biome.quantum_computer == null:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_biome_or_qc"}
			else:
				var ev_qc = ev_biome.quantum_computer
				result["var_h"] = ev_qc.get_energy_variance() if ev_qc.has_method("get_energy_variance") else -1.0
				result["h_gap"] = ev_qc.get_hamiltonian_spectral_gap() if ev_qc.has_method("get_hamiltonian_spectral_gap") else -1.0
				result["purity"] = ev_qc.get_purity() if ev_qc.has_method("get_purity") else -1.0
				var attr: Dictionary = ev_biome.get_attractor_state() if ev_biome.has_method("get_attractor_state") else {}
				result["eigenvalue_gap"] = attr.get("eigenvalue_gap", -1.0)
				result["attractor_emojis"] = attr.get("emojis", [])

		"realization_debug":
			# Pinpoint why a biome's H is empty: emojis basis, native_factions, per-faction
			# registry icons (with poles), and the final realized neighborhood icon list.
			var rd_name: String = str(cmd.get("biome", "StarterForest"))
			var rd_biome = _farm.grid.get_biome(rd_name) if _farm and _farm.grid else null
			if rd_biome == null:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_biome"}
			else:
				result["emojis"] = rd_biome.emojis if "emojis" in rd_biome else []
				var nf = rd_biome.get_native_factions() if rd_biome.has_method("get_native_factions") else []
				result["native_factions"] = nf
				var reg = get_root().get_node_or_null("IconRegistry")
				var per_fac: Dictionary = {}
				if reg:
					for fname in nf:
						var ics = reg.get_icons_for_faction(str(fname))
						var brief: Array = []
						for ic in ics:
							if ic is Dictionary:
								brief.append("%s/%s" % [str(ic.get("pole_0", "")), str(ic.get("pole_1", ""))])
						per_fac[str(fname)] = brief
				result["registry_icons_per_faction"] = per_fac
				# Also query the registry DIRECTLY for any explicitly-requested factions,
				# independent of what the runtime biome reports — separates "registry empty"
				# from "biome data not transferred to runtime".
				var probe_facs = cmd.get("probe_factions", [])
				var direct: Dictionary = {}
				if reg and probe_facs is Array:
					for fname in probe_facs:
						var ics2 = reg.get_icons_for_faction(str(fname))
						var brief2: Array = []
						for ic in ics2:
							if ic is Dictionary:
								brief2.append("%s/%s" % [str(ic.get("pole_0", "")), str(ic.get("pole_1", ""))])
						direct[str(fname)] = brief2
				result["registry_direct_query"] = direct
				# Compare the canonical BiomeRegistry record vs this runtime/grid biome:
				# if registry has native_factions/emojis but runtime doesn't, the build
				# pipeline drops them (fix = thread through); if registry is ALSO empty,
				# the loader is broken.
				var breg = get_root().get_node_or_null("BiomeRegistry")
				if breg == null:
					var BR = load("res://Core/Biomes/BiomeRegistry.gd")
					if BR and BR.has_method("get_shared"):
						breg = BR.get_shared()
				if breg and breg.has_method("get_by_name"):
					var canon = breg.get_by_name(rd_name)
					if canon:
						result["registry_biome_native_factions"] = canon.get_native_factions() if canon.has_method("get_native_factions") else (canon.native_factions if "native_factions" in canon else "n/a")
						result["registry_biome_emojis"] = canon.emojis if "emojis" in canon else "n/a"
						result["runtime_vs_registry_same_object"] = (canon == rd_biome)
					else:
						result["registry_biome_native_factions"] = "get_by_name->null"
				if rd_biome.has_method("get_neighborhood_icons"):
					var nbh = rd_biome.get_neighborhood_icons()
					var nbh_brief: Array = []
					for e in nbh:
						if e is Dictionary:
							nbh_brief.append("%s/%s" % [str(e.get("pole_0", "")), str(e.get("pole_1", ""))])
					result["realized_neighborhood_icons"] = nbh_brief
				# Decisive: for the CANONICAL biome's realized pairs, does the registry
				# return non-zero Hamiltonian physics (se0/se1/rabi)? Zero ⇒ physics never
				# reached H ⇒ the real H≡0 cause.
				var canon_for_phys = breg.get_by_name(rd_name) if (breg and breg.has_method("get_by_name")) else null
				if canon_for_phys and canon_for_phys.has_method("get_neighborhood_icons") and reg and reg.has_method("get_icon_physics_by_pair"):
					var phys_report: Array = []
					for e in canon_for_phys.get_neighborhood_icons():
						if not (e is Dictionary):
							continue
						var pp0 := str(e.get("pole_0", ""))
						var pp1 := str(e.get("pole_1", ""))
						var ph = reg.get_icon_physics_by_pair(pp0, pp1)
						phys_report.append("%s/%s se0=%.4f se1=%.4f rabi=%.4f hc=%d" % [
							pp0, pp1,
							float(ph.get("self_energy_0", 0.0)), float(ph.get("self_energy_1", 0.0)),
							float(ph.get("rabi_coupling", 0.0)),
							(ph.get("hamiltonian_couplings", {}) as Dictionary).size() if ph.get("hamiltonian_couplings", {}) is Dictionary else 0])
					result["canonical_realized_physics"] = phys_report

		"hamiltonian_stats":
			# Does this biome's H actually drive dynamics? Report total / off-diagonal /
			# diagonal-spread norms. Off-diagonal ~0 + tiny spread ⇒ no precession ⇒ the
			# Berry mechanic can never ripen (the real campaign blocker).
			var hs_name: String = str(cmd.get("biome", "StarterForest"))
			var hs_biome = _farm.grid.get_biome(hs_name) if _farm and _farm.grid else null
			var hs_qc = hs_biome.quantum_computer if (hs_biome and "quantum_computer" in hs_biome) else null
			var H = hs_qc.hamiltonian if hs_qc else null
			if H == null:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_hamiltonian"}
			else:
				var hs_n: int = int(H.n)
				var total_sq := 0.0
				var offdiag_sq := 0.0
				var dmin := INF
				var dmax := -INF
				for i in range(hs_n):
					for j in range(hs_n):
						var mag: float = H.get_element(i, j).abs()
						total_sq += mag * mag
						if i != j:
							offdiag_sq += mag * mag
						else:
							dmin = min(dmin, H.get_element(i, j).re)
							dmax = max(dmax, H.get_element(i, j).re)
				result["dim"] = hs_n
				result["frobenius"] = sqrt(total_sq)
				result["offdiagonal_norm"] = sqrt(offdiag_sq)
				result["diag_min"] = dmin if dmin != INF else 0.0
				result["diag_max"] = dmax if dmax != -INF else 0.0
				result["diag_spread"] = (dmax - dmin) if (dmax != -INF and dmin != INF) else 0.0

		"inject_icon":
			var biome_name = str(cmd.get("biome", ""))
			if biome_name != "":
				result["inject_result"] = _instrument.action_inject_icon(biome_name)
			else:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "missing_biome"}

		"consume_berry":
			var cb_biome_name: String = str(cmd.get("biome", "StarterForest"))
			var cb_count: int = max(1, int(cmd.get("count", 1)))
			var cb_phase: float = float(cmd.get("phase_each", PI))
			var cb_biome = _farm.grid.get_biome(cb_biome_name) if _farm and _farm.grid else null
			if cb_biome == null or not ("quantum_computer" in cb_biome) or cb_biome.quantum_computer == null:
				result["ok"] = false
				result["error"] = "no_biome_or_qc"
			else:
				var berry = cb_biome.quantum_computer.berry_register
				var qc = cb_biome.quantum_computer
				var qcount: int = qc.get_qubit_count() if qc.has_method("get_qubit_count") else 1
				for i in range(cb_count):
					var qid: int = i % max(1, qcount)
					berry.start_tracking(qid)
					berry._state[qid]["accumulated"] = cb_phase
					berry.consume(qid)
				result["consumed_count"] = berry.get_consumed_count()
				result["consumed_phase"] = berry.get_consumed_phase()

		"bridge_build":
			# {a: {biome, north, south}, b: {biome, north, south}} — raise a span.
			if _farm == null or not ("bridge_register" in _farm) or _farm.bridge_register == null:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_bridge_register"}
			else:
				result["bridge_result"] = _farm.bridge_register.build(
					cmd.get("a", {}) if cmd.get("a", {}) is Dictionary else {},
					cmd.get("b", {}) if cmd.get("b", {}) is Dictionary else {})

		"bridge_braid":
			# {id: int, end: "a"|"b"} — S at end a, √X at end b.
			if _farm == null or not ("bridge_register" in _farm) or _farm.bridge_register == null:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_bridge_register"}
			else:
				result["braid_result"] = _farm.bridge_register.braid(int(cmd.get("id", -1)), str(cmd.get("end", "a")))

		"bridge_fuse":
			# {id: int, roll?: float} — Born-sample the parity; deterministic when
			# the caller passes roll. Payout is the caller's business (rig-only).
			if _farm == null or not ("bridge_register" in _farm) or _farm.bridge_register == null:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_bridge_register"}
			else:
				var roll: float = float(cmd.get("roll", randf()))
				result["fuse_result"] = _farm.bridge_register.fuse(int(cmd.get("id", -1)), roll)

		"bridge_list":
			if _farm == null or not ("bridge_register" in _farm) or _farm.bridge_register == null:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_bridge_register"}
			else:
				result["bridges"] = _farm.bridge_register.to_dict()

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

		"configure_discovery":
			var weights = cmd.get("weights", {})
			if weights is Dictionary and not weights.is_empty():
				BiomeDiscoveryForecastService.configure(weights)
				result["ok"] = true
				result["weights"] = weights
			else:
				result["ok"] = false
				result["error"] = "empty_weights"

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

		"pressure_debug":
			# Trace _biomes_under_pressure piece by piece against the LIVE farm/qm.
			var pdq = InstrumentLocator.resolve_quest_manager(_farm, _farm)
			result["qm_found"] = pdq != null
			if pdq != null and _farm != null:
				result["n_flags"] = pdq.get_all_story_flags().size() if pdq.has_method("get_all_story_flags") else -1
				result["fired"] = _farm.story_flags_fired.keys() if "story_flags_fired" in _farm else []
				var trace: Dictionary = {}
				for fl in pdq.get_all_story_flags():
					if not (fl is Dictionary):
						continue
					var fid := str(fl.get("id", ""))
					if fid not in ["chain_ends", "the_crossing", "ledger_opens", "spring_connects"]:
						continue
					var row := {"unfired": not _farm.story_flags_fired.has(fid), "preds": []}
					for pr in fl.get("predicates", []):
						if pr is Dictionary:
							row["preds"].append({"type": pr.get("type"), "id": pr.get("id", ""), "biome": pr.get("biome", "")})
					trace[fid] = row
				result["trace"] = trace
				result["pressured"] = BiomeDiscoveryForecastService._biomes_under_pressure(_farm)
				result["projection"] = pdq.get_state_projection_snapshot() if pdq.has_method("get_state_projection_snapshot") else {}

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
			if not gsm or not ("save_load" in gsm) or gsm.save_load == null:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_game_state_manager"}
			else:
				result["slot"] = slot
				result["saved"] = gsm.save_load.save_game(slot)
				result["save_path"] = gsm.get_save_path(slot) if gsm.has_method("get_save_path") else ""

		"save_game_path":
			var save_path = str(cmd.get("path", ""))
			var gsm = get_root().get_node_or_null("GameStateManager")
			if not gsm or not ("save_load" in gsm) or gsm.save_load == null:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_game_state_manager"}
			elif save_path == "":
				result = {"ok": false, "turn": turn_id, "action": action, "error": "missing_save_path"}
			else:
				result["path"] = save_path
				result["saved"] = gsm.save_load.save_game_to_path(save_path)

		"load_game":
			var slot = int(cmd.get("slot", -1))
			var gsm = get_root().get_node_or_null("GameStateManager")
			if not gsm:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_game_state_manager"}
			elif not ("save_load" in gsm) or gsm.save_load == null:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_save_load_coordinator"}
			else:
				result["slot"] = slot
				result["loaded"] = gsm.save_load.load_and_apply(slot)
				_rebind_after_load(gsm)

		"load_game_path":
			var path = str(cmd.get("path", ""))
			var gsm = get_root().get_node_or_null("GameStateManager")
			if not gsm:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_game_state_manager"}
			elif path == "":
				result = {"ok": false, "turn": turn_id, "action": action, "error": "missing_path"}
			elif not ("save_load" in gsm) or gsm.save_load == null:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_save_load_coordinator"}
			else:
				result["path"] = path
				result["loaded"] = await gsm.save_load.load_and_apply_path(path)
				_rebind_after_load(gsm)

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

		"perf":
			# Engine performance monitors — fps + frame-time split so a driver can
			# localize a slowdown (script process vs physics vs rendering) per platform.
			result["fps"] = Performance.get_monitor(Performance.TIME_FPS)
			result["process_ms"] = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			result["physics_process_ms"] = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			result["static_memory_mb"] = Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
			result["object_count"] = Performance.get_monitor(Performance.OBJECT_COUNT)
			result["node_count"] = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
			result["orphan_nodes"] = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
			result["draw_calls"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			result["video_mem_mb"] = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0)
			result["cpp_engine_loaded"] = ClassDB.class_exists("MultiBiomeLookaheadEngine")
			# Force-graph stage breakdown (it keeps its own rolling samples).
			var fg_stack: Array = [root]
			while not fg_stack.is_empty():
				var fg_n: Node = fg_stack.pop_back()
				for fg_ch in fg_n.get_children():
					fg_stack.push_back(fg_ch)
				if fg_n.has_method("get_perf_averages") and fg_n.has_method("get_stats"):
					result["force_graph_ms"] = fg_n.get_perf_averages()
					result["force_graph_stats"] = fg_n.get_stats()
					break

		"toggle_process":
			# Perf bisection: enable/disable _process on every node whose name contains
			# the given substring. Sample `perf` between toggles to localize a frame cost.
			var needle := str(cmd.get("node", ""))
			var enable := bool(cmd.get("enable", false))
			if needle == "":
				result = {"ok": false, "turn": turn_id, "action": action, "error": "missing_node"}
			else:
				var touched: Array = []
				var stack: Array = [root]
				while not stack.is_empty():
					var n: Node = stack.pop_back()
					for ch in n.get_children():
						stack.push_back(ch)
					if needle.to_lower() in str(n.name).to_lower():
						n.set_process(enable)
						touched.append(str(n.get_path()))
				result["touched"] = touched

		"instrument_state":
			# Diagnostic: read back the dispatch result (cursor ring + selection +
			# modal state) so a driver can verify input routing after key presses.
			var qi = _resolve_quantum_input()
			if qi == null:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_quantum_input"}
			else:
				var inst = qi._instrument if ("_instrument" in qi) else null
				result["cursor_layer"] = int(qi.cursor_layer) if ("cursor_layer" in qi) else -1
				result["current_plot_idx"] = int(inst.current_plot_idx) if inst else -999
				result["current_biome"] = str(inst.current_biome) if inst else ""
				result["in_submenu"] = (inst and inst.has_method("is_in_submenu") and inst.is_in_submenu())
				var cp = qi._confirm_pending if ("_confirm_pending" in qi) else {}
				result["confirm_pending"] = not cp.is_empty()
				result["confirm_label"] = str(cp.get("label", ""))

		"submenu_state":
			# Diagnostic: read the open submenu (e.g. icon_injection) so a driver can find
			# which Q/E/R slot (and page) holds a given icon before selecting it.
			var qis = _resolve_quantum_input()
			if qis == null:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_quantum_input"}
			else:
				var inst2 = qis._instrument if ("_instrument" in qis) else null
				result["in_submenu"] = (inst2 and inst2.has_method("is_in_submenu") and inst2.is_in_submenu())
				result["submenu_page"] = int(qis._submenu_page) if ("_submenu_page" in qis) else 0
				var sm = qis._current_submenu if ("_current_submenu" in qis) else {}
				var acts = sm.get("actions", {}) if sm is Dictionary else {}
				var slots: Dictionary = {}
				for slot_key in ["Q", "E", "R"]:
					if acts.has(slot_key):
						var a = acts[slot_key]
						var ic = a.get("icon", {}) if a is Dictionary else {}
						slots[slot_key] = {"label": str(a.get("label", "")), "north": str(ic.get("north", "")), "south": str(ic.get("south", ""))}
				result["slots"] = slots

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

		"set_window_size":
			# Resize the headed window so we can verify responsive layout at various
			# resolutions (the action bar / hat rows reflow on the window's resized signal).
			var ww := int(cmd.get("w", 1280))
			var wh := int(cmd.get("h", 720))
			DisplayServer.window_set_size(Vector2i(ww, wh))
			await process_frame
			await process_frame
			await process_frame
			var got := DisplayServer.window_get_size()
			result["window_size"] = {"w": got.x, "h": got.y}

		"screenshot":
			# Capture the rendered viewport to a PNG (headed mode only — headless has no
			# render target). Returns the globalized absolute path for the caller to read.
			var shot_path = str(cmd.get("path", "user://rig/shot.png"))
			await process_frame
			await process_frame
			var vp = get_root()
			var img = vp.get_texture().get_image() if (vp and vp.get_texture()) else null
			if img == null:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_render_target"}
			else:
				var err = img.save_png(shot_path)
				result["screenshot"] = {
					"path": shot_path,
					"abs": ProjectSettings.globalize_path(shot_path),
					"saved": err == OK, "w": img.get_width(), "h": img.get_height(),
				}

		"start_from_title":
			# RIG_DRIVE_TITLE companion: drive the real title→start path. Optionally press
			# `keys` first (e.g. ["F","F"] = open the X menu + start the default scenario,
			# exactly the player's "F twice"). Then ensure the game actually booted — if the
			# menu path didn't start it, call start_game directly (the same entrypoint the
			# EscapeMenu uses), so the welcome appears either way. Finally resolve farm+shell.
			if _app_root == null:
				result = {"ok": false, "turn": turn_id, "action": action, "error": "no_app_root"}
			else:
				var keys = cmd.get("keys", [])
				if keys is Array:
					for k in keys:
						var kc = _extract_keycode({"key": str(k)})
						if kc != KEY_UNKNOWN:
							await _press_key(kc, false, int(cmd.get("settle_frames", 8)))
				if not (_app_root.game_root and is_instance_valid(_app_root.game_root)):
					await _app_root.start_game(_pending_boot_request)
				_shell = _app_root.get_player_shell()
				_farm = _app_root.game_root.farm if (_app_root.game_root and is_instance_valid(_app_root.game_root)) else null
				if _shell and _shell.has_method("set_farm_attached"):
					_shell.set_farm_attached(true)
				if _shell:
					_snapshot_service = InstrumentLocator.resolve_snapshot_service(_shell)
					_instrument = InstrumentLocator.resolve_quantum_instrument(_shell)
				result["start_from_title"] = {
					"farm": _farm != null, "shell": _shell != null,
					"game_root": _app_root.game_root != null,
				}

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
			"reward_icon_north": offer.get("reward_icon_north", ""),
			"reward_icon_south": offer.get("reward_icon_south", ""),
			"completion_action": completion_action,
			"biome": offer.get("biome", ""),
			"is_biome_native": bool(offer.get("is_biome_native", false)),
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
			"reward_icon_north": quest.get("reward_icon_north", ""),
			"reward_icon_south": quest.get("reward_icon_south", ""),
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
	if not _farm.grid or not _farm.grid.has_biomes():
		return {"success": false, "error": "no_biomes"}
	var biome = _farm.grid.get_biome(biome_name)
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


func _configure_seed_state(cmd: Dictionary) -> Dictionary:
	var out: Dictionary = {"ok": true}
	var gsm = get_root().get_node_or_null("GameStateManager")
	if not gsm or not gsm.current_state:
		return {"ok": false, "error": "no_game_state"}

	var known_icons = _sanitize_known_icons(cmd.get("known_icons", []))
	if not known_icons.is_empty():
		if _farm and _farm.has_method("set_known_icons"):
			_farm.set_known_icons(known_icons)
		gsm.current_state.known_icons = known_icons.duplicate(true)
		out["known_icons"] = known_icons

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


func _sanitize_known_icons(raw) -> Array:
	return QuantumInstrumentClass._sanitize_known_icons(raw)


func _perform_time_skip(phrames: int, delta: float) -> Dictionary:
	if _instrument and _instrument.has_method("time_skip"):
		return _instrument.time_skip(phrames, delta)
	return {"ok": false, "error": "no_quantum_instrument"}


## Rebuild every named biome's H+L operators from canonical (picking up the current
## BalanceConfig physics override) and reset it to ground. The reservoir-sweep retune
## primitive — reuses the instrument's canonical-rebuild path.
func _reservoir_rebuild_all(biome_names: Array) -> void:
	if _instrument == null or not _instrument.has_method("_rebuild_operators_after_shrink"):
		return
	for bn in biome_names:
		var biome = _farm.grid.get_biome(str(bn)) if (_farm and _farm.grid) else null
		if biome and biome.quantum_computer:
			_instrument._rebuild_operators_after_shrink(biome)
			if biome.quantum_computer.has_method("initialize_ground_state"):
				biome.quantum_computer.initialize_ground_state()


## Mean pairwise mutual information across a biome's qubits — the reservoir's
## "integration" (how much its parts share information). 0 for <2 qubits.
func _mean_mutual_information(qc) -> float:
	if not qc.has_method("get_mutual_information"):
		return 0.0
	var nq := 0
	if "register_map" in qc and qc.register_map:
		nq = int(qc.register_map.num_qubits)
	if nq < 2:
		return 0.0
	var total := 0.0
	var pairs := 0
	for i in range(nq):
		for j in range(i + 1, nq):
			total += float(qc.get_mutual_information(i, j))
			pairs += 1
	return total / float(maxi(pairs, 1))


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
	if not _instrument:
		return {}
	var snap = _instrument.get_resource_snapshot()
	if not (snap is Dictionary):
		return {}
	var resources = snap.get("resources", {})
	return resources if resources is Dictionary else {}


func _get_policy_snapshot(include_offers: bool = true, include_grid: bool = true) -> Dictionary:
	if not _instrument:
		return {}
	if _instrument.has_method("get_policy_snapshot"):
		var bundled = _instrument.get_policy_snapshot(include_offers, include_grid)
		if bundled is Dictionary:
			return bundled
	return {}


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


func _resolve_quantum_input():
	if not _shell:
		return null
	for node in get_nodes_in_group("quantum_instrument_input"):
		if node and (_shell == node or _shell.is_ancestor_of(node)):
			return node
	return null


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
	# Inject through the engine's real dispatch (push_input) so the whole live tree sees
	# the event exactly as a hardware key would: PlayerShell._input → overlay stack →
	# Farm._unhandled_input → QuantumInstrumentInput._unhandled_key_input.
	#
	# This replaces hand-routing (_shell._input + _unhandled_key_input called directly and
	# gated on Viewport.is_input_handled()). That flag is only RESET inside push_input();
	# calling the handlers directly left it stuck `true` after the first consumed key, so
	# every later QII action (hat switch, measure, …) short-circuited before reaching QII.
	# push_input() resets it per event and dispatches in the correct order, in both headed
	# and headless modes (the synchronous push_input is not the async Input.parse_input_event
	# the earlier note warned about).
	var viewport: Viewport = root
	if viewport:
		viewport.push_input(event, true)
	elif _shell and _shell.has_method("_input"):
		_shell._input(event)


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


# Map tool group numbers to the current archetype-hat keycodes.
func _tool_group_keycode(group_num: int) -> int:
	match group_num:
		1:
			return KEY_0
		2:
			return KEY_4
		3:
			return KEY_8
		4:
			return KEY_7
	return KEY_UNKNOWN


func _ensure_tool_group_mode(group_num: int, mode_name: String = "") -> Dictionary:
	# ToolConfig group API replaced by frame API — tool group mode unavailable in headless.
	return {"ok": false, "error": "tool_group_mode_unavailable_headless", "group": group_num}


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
	var plot_keys = InputBindingRegistry.get_plot_keys()
	if plot_idx < 0 or plot_idx >= plot_keys.size():
		return {"ok": false, "error": "plot_idx_out_of_range", "plot_idx": plot_idx}
	var key_label = str(plot_keys[plot_idx])
	var keycode = InputBindingRegistry.get_keycode_for_label(key_label)
	if keycode == KEY_UNKNOWN:
		return {"ok": false, "error": "unknown_plot_key", "plot_idx": plot_idx, "key": key_label}
	await _press_key(keycode, false, 2)
	return {"ok": true, "plot_idx": plot_idx, "key": key_label}


func _open_quest_board_via_input() -> Dictionary:
	await _close_player_overlays_via_input()
	var overlay_manager = _resolve_overlay_manager()
	var board = overlay_manager.get_overlay("quests") if overlay_manager and overlay_manager.has_method("get_overlay") else null
	if board and board.visible:
		return {"ok": true, "already_open": true}
	await _press_key(KEY_C, false, 2)
	board = overlay_manager.get_overlay("quests") if overlay_manager and overlay_manager.has_method("get_overlay") else null
	return {"ok": board != null and board.visible, "opened": board != null and board.visible}



## Sibling: ReelRunner._positions — intentionally divergent (arrays-only,
## singular `position`, fallback on any empty parse). Divergence is by design.
func _parse_positions(raw_positions, biome_name: String) -> Array[Vector2i]:
	# Parse positions from JSON array [[x,y],...] or fall back to biome positions.
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


func _allow_rig_resource_injection() -> bool:
	return RuntimeEnv.allow_resource_injection()


## A load swaps in a FRESH farm (SaveLoadCoordinator._attach_state_to_fresh_farm),
## so every cached reference here goes stale — story_flags/discovery_forecast/etc.
## would silently read the shut-down pre-load farm (empty flags, no pressure).
## Rebind everything the way boot did.
func _rebind_after_load(gsm) -> void:
	if gsm and "active_farm" in gsm and gsm.active_farm:
		_farm = gsm.active_farm
	if _shell:
		_instrument = InstrumentLocator.resolve_quantum_instrument(_shell)
		_snapshot_service = InstrumentLocator.resolve_snapshot_service(_shell)
