extends SceneTree
## Test runner for ConspiracyNetworkOverlay tests

const TestSuite = preload("res://tests/test_conspiracy_network_overlay.gd")

func _init():
	# Create root node
	var root = Node.new()
	root.set_name("Root")
	get_root().add_child(root)

	# Add and run test suite
	var tests = TestSuite.new()
	root.add_child(tests)

	# Tests will call get_tree().quit() when done
