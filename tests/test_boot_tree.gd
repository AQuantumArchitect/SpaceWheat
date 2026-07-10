#!/usr/bin/env -S godot -s
extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene = load("res://scenes/Main.tscn")
	if main_scene == null:
		printerr("missing Main.tscn")
		quit(2)
		return

	var main = main_scene.instantiate()
	root.add_child(main)
	current_scene = main

	var game_root = await _wait_for_group("game_root", 240)
	if game_root == null:
		printerr("game_root boot timeout")
		quit(3)
		return

	var farm = await _wait_for_farm(game_root)
	if farm == null:
		printerr("farm boot timeout")
		quit(4)
		return

	var farm_view = await _wait_for_group("farm_view", 120)
	if farm_view == null:
		printerr("farm_view boot timeout")
		quit(5)
		return

	if current_scene != main:
		printerr("current_scene changed away from Main")
		quit(6)
		return

	if root.get_node_or_null("/root/Farm") != null:
		printerr("Farm leaked to /root")
		quit(7)
		return

	if farm.get_parent() != game_root:
		printerr("Farm parent is not GameRoot: %s" % str(farm.get_parent()))
		quit(8)
		return

	if farm.grid == null or not farm.grid.has_biomes():
		printerr("Farm boot completed without root-owned initial biomes")
		quit(12)
		return

	var gsm = root.get_node_or_null("/root/GameStateManager")
	var state = gsm.current_state if gsm else null
	if state == null:
		printerr("GameStateManager.current_state missing")
		quit(13)
		return

	# Order-insensitive: the registry lists biomes alphabetically while the
	# scenario lists them in authoring order — the SET is the contract.
	var loaded_names: Array = farm.grid.get_biome_names().duplicate()
	var expected_names: Array = (state.unlocked_biomes as Array).duplicate()
	loaded_names.sort()
	expected_names.sort()
	if loaded_names != expected_names:
		printerr("loaded biomes do not match scenario/save state: loaded=%s state=%s" % [
			str(loaded_names),
			str(expected_names)
		])
		quit(14)
		return

	if str(state.active_biome_name) == "" or not farm.grid.has_biome(str(state.active_biome_name)):
		printerr("active biome is not loaded: %s" % str(state.active_biome_name))
		quit(15)
		return

	if farm_view.get_parent() == farm:
		printerr("FarmView is still parented under Farm")
		quit(9)
		return

	if get_nodes_in_group("game_root").size() != 1:
		printerr("expected exactly one GameRoot")
		quit(10)
		return

	if get_nodes_in_group("farm_view").size() != 1:
		printerr("expected exactly one FarmView")
		quit(11)
		return

	print("boot tree ok: current_scene=Main farm_parent=GameRoot farm_view_parent=%s" % farm_view.get_parent().name)
	quit(0)


func _wait_for_group(group_name: String, frames: int) -> Node:
	for _i in range(frames):
		var nodes = get_nodes_in_group(group_name)
		if nodes.size() > 0:
			return nodes[0]
		await process_frame
	return null


func _wait_for_farm(game_root: Node) -> Node:
	for _i in range(240):
		var farm = game_root.get_node_or_null("Farm") if game_root else null
		if farm and farm.get("grid") != null and farm.get("terminal_pool") != null:
			return farm
		await process_frame
	return null
