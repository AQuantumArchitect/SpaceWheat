extends SceneTree

## Test rejection visual feedback in real-time with simulated input

var farm_view = null
var test_step: int = 0
var wait_frames: int = 0

func _init():
	print("\n" + "=".repeat(80))
	print("TEST: Real-time Rejection Visual Feedback")
	print("=".repeat(80))

	# Load the actual game scene
	var scene = load("res://scenes/FarmView.tscn")
	if not scene:
		push_error("Failed to load FarmView scene!")
		quit(1)
		return

	print("\nLoading FarmView scene...")
	farm_view = scene.instantiate()
	root.add_child(farm_view)

func _process(_delta: float) -> bool:
	# Wait for initialization
	if test_step == 0:
		wait_frames += 1
		if wait_frames < 60:  # Wait 1 second at 60fps
			return true
		print("\nStarting rejection tests...")
		test_step = 1
		wait_frames = 0

	# Test 1: Try to plant wheat in Market biome (should reject)
	elif test_step == 1:
		print("\n1. Simulating: Select plot (0,0) and try to plant wheat [Market biome]")

		# Get farm reference
		var farm = _get_farm()
		if not farm:
			print("   ❌ Could not find farm!")
			quit(1)
			return false

		# Try to build wheat at (0,0) - Market biome
		print("   Attempting: farm.build(Vector2i(0, 0), 'wheat')")
		var result = farm.build(Vector2i(0, 0), "wheat")
		print("   Result: %s" % ("ALLOWED" if result else "REJECTED"))

		test_step = 2
		wait_frames = 0

	# Wait for visual to appear
	elif test_step == 2:
		wait_frames += 1
		if wait_frames >= 30:  # Wait 0.5 seconds
			print("\n2. Checking if visual appeared...")
			test_step = 3
			wait_frames = 0

	# Test 2: Try again (second rejection)
	elif test_step == 3:
		print("\n3. Simulating: Try to plant wheat at (0,0) AGAIN")

		var farm = _get_farm()
		if farm:
			var result = farm.build(Vector2i(0, 0), "wheat")
			print("   Result: %s" % ("ALLOWED" if result else "REJECTED"))

		test_step = 4
		wait_frames = 0

	# Wait again
	elif test_step == 4:
		wait_frames += 1
		if wait_frames >= 30:
			print("\n4. Checking if visual appeared after second rejection...")
			test_step = 5
			wait_frames = 0

	# Test 3: Rapid spam (3 rejections)
	elif test_step == 5:
		print("\n5. Simulating: SPAM 3 rejections rapidly")

		var farm = _get_farm()
		if farm:
			for i in range(3):
				var result = farm.build(Vector2i(0, 0), "wheat")
				print("   Spam %d: %s" % [i+1, "ALLOWED" if result else "REJECTED"])

		test_step = 6
		wait_frames = 0

	# Wait for visual
	elif test_step == 6:
		wait_frames += 1
		if wait_frames >= 30:
			print("\n6. Checking if visual appeared after spam...")
			test_step = 7

	# Finish
	elif test_step == 7:
		print("\n" + "=".repeat(80))
		print("TEST COMPLETE")
		print("Look for debug output above to see what happened")
		print("=".repeat(80))
		quit(0)

	return true

func _get_farm():
	"""Find the Farm instance in the scene tree"""
	if not farm_view:
		return null

	# Try to find farm through PlayerShell
	var player_shell = farm_view.get_node_or_null("PlayerShell")
	if player_shell:
		return player_shell.get("farm")

	return null
