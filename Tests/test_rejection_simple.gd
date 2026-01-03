extends Node

## Simpletest: Just test signal emission without awaiting complex initialization

const Farm = preload("res://Core/Farm.gd")

var farm: Farm
var test_complete: bool = false

func _ready():
	print("\n" + "=".repeat(80))
	print("TEST: Simple Rejection Signal Test")
	print("=".repeat(80))

	# Create farm
	farm = Farm.new()
	farm.name = "Farm"
	add_child(farm)

	# Connect signal immediately
	if farm.has_signal("action_rejected"):
		farm.action_rejected.connect(_on_action_rejected)
		print("Connected to action_rejected signal\n")
	else:
		push_error("Farm does not have action_rejected signal!")
		get_tree().quit(1)
		return

	# Start test after a short delay
	get_tree().create_timer(1.0).timeout.connect(_run_tests)

func _run_tests():
	print("Starting tests...\n")

	# Test 1: Try to plant WHEAT at (0,0) [Market biome - should REJECT]
	print("1. Test: Try to plant WHEAT at (0,0) [Market biome]")
	if farm.grid and farm.grid.biomes.has("Market"):
		var market = farm.grid.biomes.get("Market")
		if market and market.bath:
			print("   Market emojis: %s" % market.bath.emoji_list)
			print("   Has wheat? %s" % ("🌾" in market.bath.emoji_to_index))

	var result1 = farm.build(Vector2i(0, 0), "wheat")
	print("   Result: %s\n" % ("ALLOWED" if result1 else "REJECTED"))

	await get_tree().create_timer(0.2).timeout

	# Test 2: Try to plant WHEAT at (2,0) [BioticFlux biome - should ALLOW]
	print("2. Test: Try to plant WHEAT at (2,0) [BioticFlux biome]")
	if farm.grid and farm.grid.biomes.has("BioticFlux"):
		var biotic = farm.grid.biomes.get("BioticFlux")
		if biotic and biotic.bath:
			print("   BioticFlux emojis: %s" % biotic.bath.emoji_list)
			print("   Has wheat? %s" % ("🌾" in biotic.bath.emoji_to_index))

	var result2 = farm.build(Vector2i(2, 0), "wheat")
	print("   Result: %s\n" % ("ALLOWED" if result2 else "REJECTED"))

	await get_tree().create_timer(0.2).timeout

	# Test 3: Try to plant again at (2,0) [should REJECT - occupied]
	print("3. Test: Try to plant WHEAT at (2,0) again [should REJECT - occupied]")
	var result3 = farm.build(Vector2i(2, 0), "wheat")
	print("   Result: %s\n" % ("ALLOWED" if result3 else "REJECTED"))

	await get_tree().create_timer(0.2).timeout

	print("=".repeat(80))
	print("Test complete!")
	print("=".repeat(80))

	test_complete = true
	get_tree().quit(0)

func _on_action_rejected(action: String, position: Vector2i, reason: String):
	print("   >>> SIGNAL FIRED: %s at %s - %s" % [action, position, reason])
