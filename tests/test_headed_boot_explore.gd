#!/usr/bin/env -S godot -s
extends SceneTree



func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var gsm = root.get_node_or_null("/root/GameStateManager")
	if gsm == null:
		printerr("no gsm")
		quit(2)
		return

	var main_scene = load("res://scenes/Main.tscn")
	if main_scene == null:
		printerr("no Main.tscn")
		quit(3)
		return

	var main = main_scene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame

	var app_root = await _wait_for_app_root()
	if app_root == null:
		printerr("app root timeout")
		quit(3)
		return

	await app_root.start_game({"slot": -1, "scenario_id": "new_game_easy", "headless": false})
	var farm_view = app_root.game_root.farm_view if app_root.game_root else null

	var farm = await _wait_for_farm(gsm)
	if farm == null:
		printerr("farm boot timeout")
		quit(4)
		return

	var quantum_viz = await _wait_for_quantum_viz(farm_view)
	if quantum_viz == null:
		printerr("quantum viz timeout")
		quit(5)
		return

	var instrument = await _wait_for_instrument(farm)
	if instrument == null:
		printerr("instrument timeout")
		quit(6)
		return

	var biome_name := _resolve_biome_name(farm)
	if biome_name == "":
		printerr("no biome available")
		quit(7)
		return

	var plot_pos := _resolve_plot_position(farm, biome_name)
	if plot_pos == GridSentinel.INVALID_POSITION:
		printerr("no plot for biome %s" % biome_name)
		quit(8)
		return

	print("headed boot ready: biome=%s plot=%s display=%s" % [
		biome_name,
		str(plot_pos),
		DisplayServer.get_name()
	])

	var explore_result = instrument.action_explore(biome_name, plot_pos)
	if not explore_result.get("success", false):
		printerr("explore failed: %s" % explore_result.get("message", "unknown"))
		quit(9)
		return

	var bubble_ok = await _wait_for_bubble(quantum_viz, plot_pos)
	if not bubble_ok:
		printerr("bubble did not appear at %s" % str(plot_pos))
		quit(10)
		return

	var restore_ok = await _roundtrip_restore(gsm, quantum_viz, plot_pos)
	if not restore_ok:
		printerr("restore failed to rehydrate bound bubble at %s" % str(plot_pos))
		quit(11)
		return

	var measured_ok = await _measure_terminal(instrument, quantum_viz, plot_pos)
	if not measured_ok:
		printerr("measure failed at %s" % str(plot_pos))
		quit(12)
		return

	var popped_ok = await _pop_terminal(instrument, quantum_viz, plot_pos)
	if not popped_ok:
		printerr("pop failed at %s" % str(plot_pos))
		quit(13)
		return

	var dormant_ok = await _wait_for_runtime_dormant(farm)
	if not dormant_ok:
		printerr("runtime failed to return dormant after pop")
		quit(14)
		return

	for _i in range(10):
		await process_frame

	print("headed lifecycle ok: nodes=%d dormant=%s" % [
		quantum_viz.quantum_nodes.size(),
		str(_is_runtime_dormant(farm))
	])

	await gsm.session_lifecycle.shutdown_session(true, true)
	await process_frame
	await process_frame
	quit(0)


func _wait_for_farm(gsm) -> Node:
	for _i in range(240):
		var farm = gsm.get_active_farm() if gsm.has_method("get_active_farm") else gsm.active_farm
		if farm and farm.grid and farm.terminal_pool:
			return farm
		await process_frame
	return null


func _wait_for_app_root() -> Node:
	for _i in range(120):
		var nodes = get_nodes_in_group("app_root")
		if nodes.size() > 0:
			return nodes[0]
		await process_frame
	return null


func _wait_for_quantum_viz(farm_view) -> Node:
	for _i in range(240):
		if farm_view and is_instance_valid(farm_view) and farm_view.quantum_viz:
			return farm_view.quantum_viz
		await process_frame
	return null


func _wait_for_instrument(farm) -> Object:
	for _i in range(240):
		if farm and farm.instrument:
			return farm.instrument
		await process_frame
	return null


func _resolve_biome_name(farm) -> String:
	var abm = root.get_node_or_null("/root/ActiveBiomeManager")
	if abm and abm.has_method("get_active_biome"):
		var active = str(abm.get_active_biome())
		if active != "":
			return active
	if farm and farm.grid:
		var names = farm.grid.get_biome_names()
		if names.size() > 0:
			return str(names[0])
	return ""


func _resolve_plot_position(farm, biome_name: String) -> Vector2i:
	if not farm or not farm.grid:
		return GridSentinel.INVALID_POSITION
	var positions = farm.grid.get_plot_positions_for_biome(biome_name)
	for pos in positions:
		var plot = farm.grid.get_plot(pos)
		if plot and (not plot.is_active() or not plot.terminal):
			return pos
	if positions.size() > 0:
		return positions[0]
	return GridSentinel.INVALID_POSITION


func _wait_for_bubble(quantum_viz, plot_pos: Vector2i) -> bool:
	for _i in range(120):
		if quantum_viz and quantum_viz.quantum_nodes_by_grid_pos.has(plot_pos):
			return true
		await process_frame
	return false


func _measure_terminal(instrument, quantum_viz, plot_pos: Vector2i) -> bool:
	for _i in range(20):
		await process_frame
	var result = instrument.action_measure(plot_pos)
	if not result.get("success", false):
		return false
	for _i in range(120):
		var bubble = quantum_viz.quantum_nodes_by_grid_pos.get(plot_pos, null) if quantum_viz else null
		if bubble and bubble.terminal and bubble.terminal.is_measured:
			return true
		await process_frame
	return false


func _pop_terminal(instrument, quantum_viz, plot_pos: Vector2i) -> bool:
	var result = instrument.action_pop(plot_pos)
	if not result.get("success", false):
		return false
	for _i in range(120):
		if quantum_viz and not quantum_viz.quantum_nodes_by_grid_pos.has(plot_pos):
			return true
		await process_frame
	return false


func _wait_for_runtime_dormant(farm) -> bool:
	for _i in range(120):
		if _is_runtime_dormant(farm):
			return true
		await process_frame
	return false


func _is_runtime_dormant(farm) -> bool:
	if not farm or not farm.biome_evolution_batcher:
		return false
	var batcher = farm.biome_evolution_batcher
	return batcher.has_method("is_runtime_dormant") and batcher.is_runtime_dormant()


func _roundtrip_restore(gsm, quantum_viz, plot_pos: Vector2i) -> bool:
	if not gsm.save_load.save_game(0):
		return false
	if not await gsm.save_load.load_and_apply(0):
		return false
	for _i in range(120):
		var bubble = quantum_viz.quantum_nodes_by_grid_pos.get(plot_pos, null) if quantum_viz else null
		if bubble and bubble.terminal and bubble.terminal.is_bound:
			return true
		await process_frame
	return false
