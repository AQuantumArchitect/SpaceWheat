#!/usr/bin/env -S godot --headless -s
extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var gsm = root.get_node_or_null("/root/GameStateManager")
	if gsm == null:
		printerr("no gsm")
		quit(2)
		return

	var state = gsm.load_new_game_template()
	if state == null:
		printerr("no state")
		quit(3)
		return

	state.unlocked_biomes.clear()
	state.unlocked_biomes.append("StarterForest")
	gsm.current_state = state
	gsm.current_scenario_id = "default"

	var observation_frame = root.get_node_or_null("/root/ObservationFrame")
	if observation_frame:
		observation_frame.BIOME_ORDER.clear()
		observation_frame.BIOME_ORDER.append("StarterForest")
		if observation_frame.has_method("set_neutral_biome"):
			observation_frame.set_neutral_biome("StarterForest")

	var active_biome_manager = root.get_node_or_null("/root/ActiveBiomeManager")
	if active_biome_manager and active_biome_manager.has_method("set_biome_order"):
		active_biome_manager.set_biome_order(["StarterForest"])
		if active_biome_manager.has_method("set_active_biome"):
			active_biome_manager.set_active_biome("StarterForest")

	gsm.active_farm = gsm._create_farm()
	var farm = gsm.active_farm
	await gsm._await_farm_ready(farm)

	var frames := 0
	while frames < 30 and (farm == null or farm.grid == null or farm.terminal_pool == null or farm.economy == null):
		await process_frame
		frames += 1

	if gsm.has_method("shutdown_session"):
		await gsm.shutdown_session(true)
	else:
		if farm:
			farm.queue_free()
		await process_frame
		await process_frame

	quit(0)
