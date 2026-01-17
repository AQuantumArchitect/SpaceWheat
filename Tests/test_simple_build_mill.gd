#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Simple test - just try to build a mill and see what error we get

var farm = null
var frame_count = 0
var scene_loaded = false
var tests_done = false

func _init():
	print("\n" + "═".repeat(80))
	print("🏭 SIMPLE MILL BUILD TEST")
	print("═".repeat(80))

func _process(_delta):
	frame_count += 1

	if frame_count == 5 and not scene_loaded:
		print("\n⏳ Loading scene...")
		var scene = load("res://scenes/FarmView.tscn")
		if scene:
			var instance = scene.instantiate()
			root.add_child(instance)
			scene_loaded = true
			var boot_manager = root.get_node_or_null("/root/BootManager")
			if boot_manager:
				boot_manager.game_ready.connect(_on_game_ready)

func _on_game_ready():
	if tests_done:
		return
	tests_done = true

	print("\n✅ Game ready!")

	var fv = root.get_node_or_null("FarmView")
	if not fv:
		print("❌ FarmView not found")
		quit(1)
		return

	print("FarmView: %s" % fv)
	print("FarmView.farm: %s" % fv.farm)

	if not fv.farm:
		print("❌ Farm not found")
		quit(1)
		return

	farm = fv.farm
	print("Farm: %s" % farm)
	print("Farm.grid: %s" % farm.grid)
	print("Farm.economy: %s" % farm.economy)

	# Bootstrap resources
	farm.economy.add_resource("🌾", 100, "test")

	# Try to build a mill at (0,0)
	print("\nAttempting to build mill at (0,0)...")
	var result = farm.build(Vector2i(0, 0), "mill")
	print("Result: %s" % result)

	if result:
		print("✅ Mill built successfully!")
	else:
		print("❌ Mill build failed")

	quit()
