#!/usr/bin/env -S godot --headless -s
extends SceneTree


var _game_ready_emitted: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var boot_manager = root.get_node_or_null("/root/BootManager")
	if boot_manager == null:
		printerr("BootManager autoload missing")
		quit(2)
		return

	boot_manager.game_ready.connect(_on_game_ready, CONNECT_ONE_SHOT)

	var boot_request := {
		"slot": -1,
		"scenario_id": SaveStore.DEFAULT_SCENARIO_ID,
		"headless": true,
	}
	var farm = await boot_manager.boot_session(boot_request, null)
	if farm == null:
		printerr("headless boot_session returned null")
		quit(3)
		return

	if not _game_ready_emitted or not boot_manager.is_ready:
		printerr("game_ready was not emitted by canonical headless boot")
		quit(4)
		return

	if farm.get_parent() != root:
		printerr("headless farm was not attached to the scene root")
		quit(5)
		return

	print("boot session contract ok")
	quit(0)


func _on_game_ready() -> void:
	_game_ready_emitted = true
