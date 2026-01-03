extends SceneTree
## Minimal test to verify headless testing works

func _init():
	print("=".repeat(50))
	print("MINIMAL HEADLESS TEST")
	print("=".repeat(50))
	print("Test 1: Print works")
	print("Test 2: Math works: 2+2 = %d" % (2+2))
	print("Test 3: quit() works...")
	print("=".repeat(50))
	quit()
