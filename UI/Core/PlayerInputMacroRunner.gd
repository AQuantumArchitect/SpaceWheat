class_name PlayerInputMacroRunner
extends RefCounted

## PlayerInputMacroRunner - reusable headed/player-input action macros for rig automation.
##
## Keeps key-sequence orchestration out of Tests/rig_listener.gd while still
## using the real QuantumInstrumentInput + overlay keyboard surfaces.

var host = null


func setup(host_ref) -> void:
	host = host_ref


func execute(decision: Dictionary) -> Dictionary:
	if not host:
		return {"ok": false, "action": str(decision.get("action", "")), "backend": "player_input", "error": "no_host"}

	var action = str(decision.get("action", ""))
	var params = decision.get("params", {})
	if not (params is Dictionary):
		params = {}

	match action:
		"probe_cycle":
			return await _execute_probe_cycle(params)
		"quest_cycle":
			return await _execute_quest_cycle(decision, params)
		"lock_offer":
			return await _execute_lock_offer(decision, params)
		"lindblad_drain":
			return await _execute_lindblad_drain(params)
		"discover_biome":
			return await _execute_discover_biome()
		"time_skip", "victory_lap_partial", "channel_drain":
			return _unsupported_action(action)
		_:
			return _unsupported_action(action)


func _unsupported_action(action: String) -> Dictionary:
	return {
		"ok": false,
		"action": action,
		"backend": "player_input",
		"error": "not_supported_by_player_input",
	}


func _execute_probe_cycle(params: Dictionary) -> Dictionary:
	var biome_name = str(params.get("biome", ""))
	await host._close_player_overlays_via_input()
	var mode_result = await host._ensure_tool_group_mode(3, "probe")
	if not bool(mode_result.get("ok", false)):
		return {"ok": false, "action": "probe_cycle", "backend": "player_input", "error": "probe_mode_unavailable"}
	var biome_result = await host._select_biome_via_input(biome_name)
	if not bool(biome_result.get("ok", false)):
		return {"ok": false, "action": "probe_cycle", "backend": "player_input", "error": str(biome_result.get("error", "biome_select_failed")), "biome": biome_name}
	var plot_idx = host._find_plot_index_for_state(biome_name, "measured")
	if plot_idx >= 0:
		await host._select_plot_via_input(plot_idx)
		await host._press_key(KEY_R, false, 3)
	else:
		if host._find_plot_index_for_state(biome_name, "measurable") < 0:
			await host._press_key(KEY_Q, false, 3)
		plot_idx = host._find_plot_index_for_state(biome_name, "measurable")
		if plot_idx < 0:
			plot_idx = host._find_plot_index_for_state(biome_name, "terminal")
		if plot_idx < 0:
			return {"ok": false, "action": "probe_cycle", "backend": "player_input", "error": "no_terminal_after_explore", "biome": biome_name}
		await host._select_plot_via_input(plot_idx)
		await host._press_key(KEY_E, false, 3)
		await host._press_key(KEY_R, false, 3)
	return {
		"ok": true,
		"action": "probe_cycle",
		"backend": "player_input",
		"biome": biome_name,
		"plot_idx": plot_idx,
		"resources": host._get_resource_map(),
	}


func _execute_quest_cycle(decision: Dictionary, params: Dictionary) -> Dictionary:
	var open_result = await host._open_quest_board_via_input()
	if not bool(open_result.get("ok", false)):
		return {"ok": false, "action": "quest_cycle", "backend": "player_input", "error": str(open_result.get("error", "quest_board_open_failed"))}
	var overlay_manager = host._resolve_overlay_manager()
	var board = overlay_manager.get_overlay("quests") if overlay_manager and overlay_manager.has_method("get_overlay") else null
	if not board or not board.has_method("get_snapshot"):
		return {"ok": false, "action": "quest_cycle", "backend": "player_input", "error": "quest_board_unavailable"}
	var snapshot = board.get_snapshot()
	var target_page = 0
	var target_slot = -1
	var target_state = ""
	var slots = snapshot.get("slots", [])
	if slots is Array:
		for slot in slots:
			if slot is Dictionary and str(slot.get("state", "")) in ["ready", "active"]:
				target_slot = int(slot.get("index", -1))
				target_state = str(slot.get("state", ""))
				break
	if target_slot < 0:
		var offer_index = int(params.get("offer_index", -1))
		if offer_index >= 0:
			target_page = int(offer_index / 4)
			target_slot = offer_index % 4
		else:
			for slot in slots:
				if slot is Dictionary and str(slot.get("state", "")) == "offered":
					target_slot = int(slot.get("index", -1))
					target_state = "offered"
					break
	if target_slot < 0:
		await host._press_key(KEY_ESCAPE, false, 2)
		return {"ok": false, "action": "quest_cycle", "backend": "player_input", "error": "no_actionable_quest_slot"}
	var nav = await host._navigate_quest_slot_via_input(target_page, target_slot)
	if not bool(nav.get("ok", false)):
		await host._press_key(KEY_ESCAPE, false, 2)
		return {"ok": false, "action": "quest_cycle", "backend": "player_input", "error": str(nav.get("error", "quest_nav_failed"))}
	await host._press_key(KEY_Q, false, 3)
	var post_snapshot = board.get_snapshot()
	await host._press_key(KEY_ESCAPE, false, 2)
	return {
		"ok": true,
		"action": "quest_cycle",
		"backend": "player_input",
		"quest_page": target_page,
		"quest_slot": target_slot,
		"quest_state": target_state,
		"quest_board": post_snapshot,
	}


func _execute_lock_offer(decision: Dictionary, params: Dictionary) -> Dictionary:
	var open_result = await host._open_quest_board_via_input()
	if not bool(open_result.get("ok", false)):
		return {"ok": false, "action": "lock_offer", "backend": "player_input", "error": str(open_result.get("error", "quest_board_open_failed"))}
	var offer_index = int(params.get("offer_index", -1))
	if offer_index < 0:
		await host._press_key(KEY_ESCAPE, false, 2)
		return {"ok": false, "action": "lock_offer", "backend": "player_input", "error": "invalid_offer_index"}
	var nav = await host._navigate_quest_slot_via_input(int(offer_index / 4), offer_index % 4)
	if not bool(nav.get("ok", false)):
		await host._press_key(KEY_ESCAPE, false, 2)
		return {"ok": false, "action": "lock_offer", "backend": "player_input", "error": str(nav.get("error", "quest_nav_failed"))}
	await host._press_key(KEY_E, false, 3)
	await host._press_key(KEY_ESCAPE, false, 2)
	return {
		"ok": true,
		"action": "lock_offer",
		"backend": "player_input",
		"offer_index": offer_index,
	}


func _execute_lindblad_drain(params: Dictionary) -> Dictionary:
	var biome_name = str(params.get("biome", ""))
	await host._close_player_overlays_via_input()
	var mode_result = await host._ensure_tool_group_mode(2)
	if not bool(mode_result.get("ok", false)):
		return {"ok": false, "action": "lindblad_drain", "backend": "player_input", "error": "lindblad_tool_unavailable"}
	var biome_result = await host._select_biome_via_input(biome_name)
	if not bool(biome_result.get("ok", false)):
		return {"ok": false, "action": "lindblad_drain", "backend": "player_input", "error": str(biome_result.get("error", "biome_select_failed")), "biome": biome_name}
	var positions: Array[Vector2i] = host._parse_positions(params.get("positions", []), biome_name)
	var plot_idx = int(positions[0].x) if not positions.is_empty() else host._find_plot_index_for_state(biome_name, "terminal")
	if plot_idx < 0:
		plot_idx = 0
	var plot_result = await host._select_plot_via_input(plot_idx)
	if not bool(plot_result.get("ok", false)):
		return {"ok": false, "action": "lindblad_drain", "backend": "player_input", "error": str(plot_result.get("error", "plot_select_failed"))}
	await host._press_key(KEY_Q, false, 3)
	return {
		"ok": true,
		"action": "lindblad_drain",
		"backend": "player_input",
		"biome": biome_name,
		"plot_idx": plot_idx,
	}


func _execute_discover_biome() -> Dictionary:
	await host._close_player_overlays_via_input()
	var mode_result = await host._ensure_tool_group_mode(4)
	if not bool(mode_result.get("ok", false)):
		return {"ok": false, "action": "discover_biome", "backend": "player_input", "error": "meta_tool_unavailable"}
	await host._press_key(KEY_E, false, 4)
	return {
		"ok": true,
		"action": "discover_biome",
		"backend": "player_input",
		"discovery_forecast": host._farm.compute_discovery_forecast() if host._farm and host._farm.has_method("compute_discovery_forecast") else {},
	}
