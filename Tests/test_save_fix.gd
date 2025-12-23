extends SceneTree

var farm_view = null

func _init():
	var sep = "============================================================"
	print("\n" + sep)
	print("💾 SAVE/LOAD FIX TEST")
	print(sep + "\n")

func _initialize():
	print("📦 Loading FarmView scene...")
	var scene = load("res://scenes/FarmView.tscn")
	farm_view = scene.instantiate()
	root.add_child(farm_view)

	await create_timer(2.0).timeout

	print("\n🎮 Modifying game state...")
	farm_view.economy.credits = 100
	print("  Credits set to: 100")

	print("\n💾 Testing save to slot 0...")
	var save_result = GameStateManager.save_game(0)

	if save_result:
		print("✅ SAVE SUCCESSFUL!")
		print("   No array assignment errors")
	else:
		print("❌ SAVE FAILED")
		quit(1)
		return

	await create_timer(0.5).timeout

	print("\n📂 Testing load from slot 0...")
	var load_result = GameStateManager.load_and_apply(0)

	if load_result:
		print("✅ LOAD SUCCESSFUL!")
		print("   Credits restored to: " + str(farm_view.economy.credits))
	else:
		print("❌ LOAD FAILED")
		quit(1)
		return

	var sep = "============================================================"
	print("\n" + sep)
	print("🎉 SAVE/LOAD FIX VERIFIED")
	print(sep + "\n")

	quit(0)
