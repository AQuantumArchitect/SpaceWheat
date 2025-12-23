extends SceneTree

func _init():
	var sep = "============================================================"
	print("\n" + sep)
	print("🎮 SIMPLE STARTUP TEST")
	print(sep + "\n")

func _initialize():
	print("📦 Loading FarmView scene...")

	var scene = load("res://scenes/FarmView.tscn")
	if not scene:
		print("✗ Failed to load scene")
		quit(1)
		return

	print("✓ Scene loaded successfully")

	var farm_view = scene.instantiate()
	if not farm_view:
		print("✗ Failed to instantiate scene")
		quit(1)
		return

	print("✓ Scene instantiated successfully")

	root.add_child(farm_view)
	print("✓ Scene added to tree")

	# Wait a bit for _ready to complete
	await create_timer(3.0).timeout

	var sep = "============================================================"
	print("\n" + sep)
	print("✅ STARTUP TEST PASSED")
	print(sep + "\n")

	quit(0)
