extends SceneTree

## Test: Visual rejection feedback (red pulsing circle)
## Verify that when an action is rejected, a red circle pulses at the plot

const Farm = preload("res://Core/Farm.gd")

var farm: Farm

func _initialize():
	print("\n" + "=".repeat(80))
	print("🚫 TEST: Rejection Visual Feedback")
	print("=".repeat(80))

	await get_root().ready

	# Setup farm
	farm = Farm.new()
	farm.name = "Farm"
	get_root().add_child(farm)

	# Connect to action_rejected signal to verify it fires
	farm.action_rejected.connect(_on_action_rejected)

	print("\n📋 Testing rejection scenarios:")

	# Test 1: Plant wheat in Market biome (should reject - no 🌾 in Market)
	print("\n1️⃣ Test: Plant wheat at (0,0) [Market biome]...")
	var test1 = farm.build(Vector2i(0, 0), "wheat")
	print("   Result: %s" % ("REJECTED ✅" if not test1 else "ALLOWED ❌"))

	# Test 2: Plant tomato in BioticFlux (should reject - no 🍅 in BioticFlux)
	print("\n2️⃣ Test: Plant tomato at (2,0) [BioticFlux biome]...")
	var test2 = farm.build(Vector2i(2, 0), "tomato")
	print("   Result: %s" % ("REJECTED ✅" if not test2 else "ALLOWED ❌"))

	# Test 3: Plant wheat twice in same plot (should reject - occupied)
	print("\n3️⃣ Test: Plant wheat at (2,0), then plant again...")
	var test3a = farm.build(Vector2i(2, 0), "wheat")
	print("   First plant: %s" % ("ALLOWED ✅" if test3a else "REJECTED ❌"))
	var test3b = farm.build(Vector2i(2, 0), "wheat")
	print("   Second plant: %s" % ("REJECTED ✅" if not test3b else "ALLOWED ❌"))

	print("\n" + "=".repeat(80))
	print("✅ Test complete - check for 🚫 rejection signals above")
	print("   Visual feedback requires rendering, test signals only")
	print("=".repeat(80))
	quit(0)

func _on_action_rejected(action: String, position: Vector2i, reason: String):
	print("   🚫 action_rejected signal received:")
	print("      Action: %s" % action)
	print("      Position: %s" % position)
	print("      Reason: %s" % reason)
