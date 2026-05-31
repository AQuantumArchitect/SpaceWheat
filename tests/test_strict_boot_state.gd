#!/usr/bin/env -S godot --headless -s
extends SceneTree



func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var boot_manager = root.get_node_or_null("/root/BootManager")
	if boot_manager == null:
		printerr("BootManager autoload missing")
		quit(2)
		return

	if not await _expect_boot_error(boot_manager, GameState.new(), "no_biomes"):
		quit(3)
		return

	var unknown_state := GameState.new()
	unknown_state.unlocked_biomes = ["NoSuchBiome"]
	unknown_state.active_biome_name = "NoSuchBiome"
	if not await _expect_boot_error(boot_manager, unknown_state, "unknown_biome"):
		quit(4)
		return

	var bad_active_state := GameState.new()
	bad_active_state.unlocked_biomes = ["StarterForest"]
	bad_active_state.active_biome_name = "Village"
	if not await _expect_boot_error(boot_manager, bad_active_state, "active_biome_not_loaded"):
		quit(5)
		return

	print("strict boot state ok")
	quit(0)


func _expect_boot_error(boot_manager: Node, state: GameState, expected_error: String) -> bool:
	var farm := Farm.new()
	root.add_child(farm)
	if not farm.is_node_ready():
		await farm.ready
	var result = boot_manager.boot_initial_biomes(farm, state)
	farm.queue_free()
	await process_frame
	if result.get("success", false):
		printerr("expected boot error '%s', got success" % expected_error)
		return false
	if str(result.get("error", "")) != expected_error:
		printerr("expected boot error '%s', got '%s': %s" % [
			expected_error,
			str(result.get("error", "")),
			str(result)
		])
		return false
	return true
