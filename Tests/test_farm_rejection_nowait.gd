extends SceneTree

## Test Farm rejection without waiting for full initialization

var signal_fired: bool = false
var signal_action: String = ""
var signal_position: Vector2i = Vector2i.ZERO
var signal_reason: String = ""

func _init():
	print("\n" + "=".repeat(80))
	print("TEST: Farm Rejection Signal (No Wait)")
	print("=".repeat(80))

	# Load Farm
	var Farm = load("res://Core/Farm.gd")

	# Create farm (don't add to tree - avoid initialization hang)
	print("\nCreating farm...")
	var farm = Farm.new()

	# Check if action_rejected signal exists
	if farm.has_signal("action_rejected"):
		print("   ✅ Farm has action_rejected signal")
		farm.action_rejected.connect(_on_action_rejected)
		print("   ✅ Connected to signal")
	else:
		push_error("   ❌ Farm does NOT have action_rejected signal!")
		quit(1)
		return

	# Now add to tree (this may trigger initialization)
	print("\nAdding farm to tree...")
	root.add_child(farm)

	# Don't await - just give it a few frames
	print("Waiting a few frames...")
	for i in range(10):
		await process_frame

	# Try to trigger a rejection by planting at an invalid position
	print("\nTrying to plant wheat at (0,0)...")
	signal_fired = false

	# Try the build method
	if farm.has_method("build"):
		var result = farm.build(Vector2i(0, 0), "wheat")
		print("   Build returned: %s" % result)
	else:
		print("   ❌ Farm does not have build() method")

	# Wait a frame for signal to propagate
	await process_frame

	# Check if signal fired
	if signal_fired:
		print("\n✅ SUCCESS: Signal fired!")
		print("   Action: %s" % signal_action)
		print("   Position: %s" % signal_position)
		print("   Reason: %s" % signal_reason)
	else:
		print("\n❌ FAILURE: Signal did not fire")
		print("   This could mean:")
		print("   1. Build succeeded (no rejection)")
		print("   2. Signal is not being emitted")
		print("   3. Signal connection failed")

	print("\n" + "=".repeat(80))
	print("Test complete")
	print("=".repeat(80))

	quit(0)

func _on_action_rejected(action: String, position: Vector2i, reason: String):
	print("   >>> SIGNAL FIRED: action_rejected <<<")
	signal_fired = true
	signal_action = action
	signal_position = position
	signal_reason = reason
