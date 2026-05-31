extends SceneTree

const GameStateManager = preload("res://Core/GameState/GameStateManager.gd")
const BootManager = preload("res://Core/Boot/BootManager.gd")
const EXPORT_TARGET = "llm_inbox/pop_rework/live_icon_map.json"

func _init():
	call_deferred("_run_export")

func _run_export() -> void:
	print("starting live icon map export")
	var gsm = _ensure_gsm()
	print("game state manager prepared")
	var boot_manager = _ensure_boot_manager()
	var farm = await boot_manager.boot_session({"slot": -1, "scenario_id": "new_game_easy", "headless": true}, null)
	print("boot_session returned")
	await create_timer(1.0).timeout
	print("farm looked ready after delay")
	var batcher = await _wait_for_batcher(farm, 30.0)
	print("batcher wait complete", batcher)
	_spin_up_terminal(farm)
	await create_timer(12.0).timeout
	print("waited after batcher ready")
	if not batcher:
		push_error("Live export: biome batcher never initialized")
		quit()
		return
	var icon_map = await _wait_for_map(batcher, 25.0)
	if icon_map.is_empty():
		push_warning("Live export: icon map is empty or never populated")
	var payload := {
		"icon_map": icon_map,
		"source": "live_global_icon_map",
		"time": int(Time.get_unix_time_from_system() * 1000.0)
	}
	_write_payload(payload)
	quit()

func _ensure_gsm() -> Node:
	var root = get_root()
	var gsm = root.get_node_or_null("/root/GameStateManager")
	if not gsm:
		gsm = GameStateManager.new()
		gsm.name = "GameStateManager"
		root.add_child(gsm)
	return gsm

func _ensure_boot_manager() -> Node:
	var root = get_root()
	var boot_manager = root.get_node_or_null("/root/BootManager")
	if not boot_manager:
		boot_manager = BootManager.new()
		boot_manager.name = "BootManager"
		root.add_child(boot_manager)
	return boot_manager

func _wait_for_batcher(farm: Node, timeout_seconds: float):
	var attempts = max(1, int(timeout_seconds / 0.25) + 1)
	for _i in range(attempts):
		var batcher = farm.get("biome_evolution_batcher") if farm.has_method("get") else null
		print("wait_for_batcher attempt", _i, "batcher?", !!batcher)
		if batcher and batcher.has_method("get_global_icon_map"):
			return batcher
		await create_timer(0.25).timeout
	return null

func _wait_for_map(batcher: Object, timeout_seconds: float) -> Dictionary:
	var attempts = max(1, int(timeout_seconds / 0.25) + 1)
	var last_map := {}
	for _i in range(attempts):
		var icon_map = _build_icon_map_snapshot(batcher, "StarterForest")
		print("wait_for_map attempt", _i, "custom_map total", icon_map.get("total", 0.0), "steps", icon_map.get("steps", 0))
		if icon_map and icon_map.get("total", 0.0) > 0.0:
			return icon_map
		if icon_map and icon_map.size() > 0:
			last_map = icon_map
		await create_timer(0.25).timeout
	return last_map

func _spin_up_terminal(farm: Node) -> void:
	if not farm:
		return
	var biome = farm.grid.get_biome("StarterForest") if farm.grid else null
	var terminal_pool = farm.terminal_pool
	if not biome or not terminal_pool:
		return
	if "economy" in farm and farm.economy:
		farm.economy.add_resource("🍞", 500, "live_icon_map")
	var res = ProbeActions.action_explore(terminal_pool, biome, farm.economy if "economy" in farm else null)
	print("terminal spin-up:", res)

func _write_payload(payload: Dictionary) -> void:
	var expanded_path = ProjectSettings.globalize_path(EXPORT_TARGET)
	var file = FileAccess.open(expanded_path, FileAccess.WRITE)
	if not file:
		push_error("Live export: failed to open %s" % expanded_path)
		return
	var safe_payload := payload.duplicate(true)
	if safe_payload.has("icon_map"):
		var icon_map = safe_payload["icon_map"]
		if icon_map is Dictionary and icon_map.has("weights"):
			var weights = icon_map["weights"]
			if weights is PackedFloat64Array:
				var weights_arr := []
				for v in weights:
					weights_arr.append(v)
				icon_map["weights"] = weights_arr
		safe_payload["icon_map"] = icon_map
	file.store_string(JSON.stringify(safe_payload, "\t"))
	file.close()
	print("Live icon map exported to %s" % expanded_path)

func _build_icon_map_snapshot(batcher: Object, biome_name: String) -> Dictionary:
	if not batcher or not biome_name:
		return {}
	var metadata = batcher.metadata_payloads.get(biome_name, {})
	if metadata.is_empty():
		return {}
	var emoji_list = metadata.get("emoji_list", [])
	var emoji_to_qubit = metadata.get("emoji_to_qubit", {})
	var emoji_to_pole = metadata.get("emoji_to_pole", {})
	var num_qubits = int(metadata.get("num_qubits", 0))
	if emoji_list.size() == 0 or num_qubits <= 0:
		return {}
	var stride = 8
	var expected = num_qubits * stride
	var totals := []
	for emoji in emoji_list:
		totals.append(0.0)
	var bloch_steps = batcher.bloch_buffers.get(biome_name, [])
	var valid_steps = 0
	for step in bloch_steps:
		if step.size() < expected:
			continue
		valid_steps += 1
		for idx in range(emoji_list.size()):
			var emoji = emoji_list[idx]
			var qubit = int(emoji_to_qubit.get(emoji, -1))
			var pole = int(emoji_to_pole.get(emoji, -1))
			if qubit < 0 or qubit >= num_qubits or (pole != 0 and pole != 1):
				continue
			var base = qubit * stride
			var prob = float(step[base + 0]) if pole == 0 else float(step[base + 1])
			totals[idx] += prob
	if valid_steps == 0:
		return {}
	var weights = PackedFloat64Array()
	weights.resize(emoji_list.size())
	var by_emoji := {}
	var total_sum = 0.0
	for idx in range(emoji_list.size()):
		var emoji = emoji_list[idx]
		var weight = float(totals[idx])
		weights[idx] = weight
		by_emoji[emoji] = weight
		total_sum += weight
	return {
		"emojis": emoji_list.duplicate(),
		"weights": weights,
		"by_emoji": by_emoji,
		"steps": valid_steps,
		"total": total_sum,
		"num_qubits": num_qubits
	}
