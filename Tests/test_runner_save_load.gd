## Test runner for save/load cycle testing
## Execute: godot --headless -s test_runner_save_load.gd

extends SceneTree

func _initialize():
	var sep = "=" * 70
	print("\n" + sep)
	print("🧪 SPACEWHEAT SAVE/LOAD TEST RUNNER")
	print(sep)

	# Ensure GameStateManager is available
	var manager = load("res://Core/GameState/GameStateManager.gd").new()
	manager.name = "GameStateManager"
	root.add_child(manager)
	await manager.tree_entered

	# Load and run the test
	var test_script = load("res://tests/test_complete_save_load_cycle.gd")
	var test_instance = test_script.new()
	test_instance.name = "SaveLoadTest"
	root.add_child(test_instance)

	# Let the test run
	await test_instance.tree_entered
