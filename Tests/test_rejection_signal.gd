extends SceneTree

## Test: Rejection signal emission
## Test that action_rejected signal fires correctly

const Farm = preload("res://Core/Farm.gd")

var farm: Farm
var signal_received: bool = false
var signal_action: String = ""
var signal_position: Vector2i
var signal_reason: String = ""

func _initialize():
	print("\n" + "=".repeat(80))
	print("TEST: Rejection Signal Emission")
	print("=".repeat(80))

	await get_root().ready

	# Create farm
	farm = Farm.new()
	farm.name = "Farm"
	get_root().add_child(farm)
	await farm.ready

	# Connect to action_rejected signal
	if farm.has_signal("action_rejected"):
		farm.action_rejected.connect(_on_action_rejected)
		print("   Connected to action_rejected signal")
	else:
		push_error("Farm does not have action_rejected signal!")
		quit(1)
		return

	print("\nStarting rejection tests...")

	# Test 1: Try to plant WHEAT at (0,0) [Market biome - should REJECT]
	print("\n1. Test: Try to plant WHEAT at (0,0) [Market biome - should REJECT]")
	if farm.grid.biomes.has("Market"):
		var market = farm.grid.biomes.get("Market")
		if market and market.bath:
			print("   Market biome emojis: %s" % market.bath.emoji_list)
			print("   Wheat in Market? %s" % ("🌾" in market.bath.emoji_to_index))

	signal_received = false
	var result1 = farm.build(Vector2i(0, 0), "wheat")

	await process_frame

	if result1:
		print("   Build result: ALLOWED (ERROR - should reject)")
	else:
		print("   Build result: REJECTED (CORRECT)")

	if signal_received:
		print("   Signal received: YES")
		print("   Action: %s" % signal_action)
		print("   Position: %s" % signal_position)
		print("   Reason: %s" % signal_reason)
	else:
		print("   Signal received: NO (ERROR)")

	# Test 2: Try to plant TOMATO at (2,0) [BioticFlux biome - should REJECT]
	print("\n2. Test: Try to plant TOMATO at (2,0) [BioticFlux biome - should REJECT]")
	if farm.grid.biomes.has("BioticFlux"):
		var biotic = farm.grid.biomes.get("BioticFlux")
		if biotic and biotic.bath:
			print("   BioticFlux biome emojis: %s" % biotic.bath.emoji_list)
			print("   Tomato in BioticFlux? %s" % ("🍅" in biotic.bath.emoji_to_index))

	signal_received = false
	var result2 = farm.build(Vector2i(2, 0), "tomato")

	await process_frame

	if result2:
		print("   Build result: ALLOWED (ERROR - should reject)")
	else:
		print("   Build result: REJECTED (CORRECT)")

	if signal_received:
		print("   Signal received: YES")
		print("   Action: %s" % signal_action)
		print("   Position: %s" % signal_position)
		print("   Reason: %s" % signal_reason)
	else:
		print("   Signal received: NO (ERROR)")

	# Test 3: Plant WHEAT at (2,0) [BioticFlux biome - should ALLOW]
	print("\n3. Test: Try to plant WHEAT at (2,0) [BioticFlux biome - should ALLOW]")
	if farm.grid.biomes.has("BioticFlux"):
		var biotic = farm.grid.biomes.get("BioticFlux")
		if biotic and biotic.bath:
			print("   Wheat in BioticFlux? %s" % ("🌾" in biotic.bath.emoji_to_index))

	signal_received = false
	var result3 = farm.build(Vector2i(2, 0), "wheat")

	await process_frame

	if result3:
		print("   Build result: ALLOWED (CORRECT)")
	else:
		print("   Build result: REJECTED (ERROR - should allow)")

	if signal_received:
		print("   Signal received: YES (ERROR - should not reject on success)")
	else:
		print("   Signal received: NO (CORRECT)")

	# Test 4: Try to plant WHEAT at (2,0) again [should REJECT - occupied]
	print("\n4. Test: Try to plant WHEAT at (2,0) again [should REJECT - occupied]")

	signal_received = false
	var result4 = farm.build(Vector2i(2, 0), "wheat")

	await process_frame

	if result4:
		print("   Build result: ALLOWED (ERROR - should reject)")
	else:
		print("   Build result: REJECTED (CORRECT)")

	if signal_received:
		print("   Signal received: YES")
		print("   Action: %s" % signal_action)
		print("   Position: %s" % signal_position)
		print("   Reason: %s" % signal_reason)
	else:
		print("   Signal received: NO (ERROR)")

	print("\n" + "=".repeat(80))
	print("Test complete!")
	print("=".repeat(80))

	quit(0)

func _on_action_rejected(action: String, position: Vector2i, reason: String):
	print("   >>> action_rejected SIGNAL FIRED! <<<")
	signal_received = true
	signal_action = action
	signal_position = position
	signal_reason = reason
