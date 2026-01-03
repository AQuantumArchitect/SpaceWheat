extends SceneTree

## Quick boot test - loads main scene and quits after 2 seconds

func _init():
	print("======================================================================")
	print("BOOT TEST: Loading main game scene")
	print("======================================================================\n")

	# Load main scene
	var main_scene = load("res://scenes/FarmView.tscn")
	if not main_scene:
		print("❌ Failed to load FarmView.tscn")
		quit(1)

	var scene_instance = main_scene.instantiate()
	root.add_child(scene_instance)

	# Create timer to quit after boot
	var timer = Timer.new()
	root.add_child(timer)
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(_finish_test)
	timer.start()

	print("⏰ Waiting 2 seconds for boot to complete...\n")


func _finish_test():
	print("\n======================================================================")
	print("BOOT TEST COMPLETE")
	print("======================================================================")
	print("✅ Boot completed successfully (check console for any ERROR messages)")
	quit(0)
