extends Node

## Debug harvest to find the energy error

var farm: Node

func _ready():
	print("\n" + "=".repeat(80))
	print("HARVEST DEBUG TEST")
	print("=".repeat(80) + "\n")

	# Wait for BootManager
	var boot_mgr = get_node_or_null("/root/BootManager")
	if boot_mgr:
		if not boot_mgr.is_ready:
			await boot_mgr.game_ready
		for i in range(5):
			await get_tree().process_frame

	# Find farm
	var farm_view = get_tree().root.find_child("FarmView", true, false)
	if farm_view:
		farm = farm_view.get_farm()

	if not farm:
		print("❌ Farm not found")
		get_tree().quit()
		return

	print("✅ Farm found\n")

	# Plant wheat
	print("📍 Planting wheat at (0,0)...")
	farm.build(Vector2i(0, 0), "wheat")
	await get_tree().process_frame

	var plot = farm.grid.get_plot(Vector2i(0, 0))
	print("   Plot planted: %s" % plot.is_planted)
	if plot.quantum_state:
		print("   Quantum state exists: YES")
		print("   North emoji: %s" % plot.quantum_state.north_emoji)
		print("   South emoji: %s" % plot.quantum_state.south_emoji)

	# Check resources before harvest
	print("\n📊 Resources BEFORE harvest:")
	for emoji in farm.economy.emoji_credits.keys():
		var amount = farm.economy.get_resource_units(emoji)
		if amount > 0:
			print("   %s: %d" % [emoji, amount])

	# Harvest
	print("\n✂️  Harvesting plot (0,0)...")
	print("=" * 80)
	var result = farm.harvest_plot(Vector2i(0, 0))
	print("=" * 80)

	print("\n📋 Harvest result:")
	print("   success: %s" % result.get("success", false))
	print("   outcome: %s" % result.get("outcome", "?"))
	print("   yield: %s" % result.get("yield", 0))
	print("   energy: %s" % result.get("energy", "N/A"))

	# Check resources after harvest
	print("\n📊 Resources AFTER harvest:")
	for emoji in farm.economy.emoji_credits.keys():
		var amount = farm.economy.get_resource_units(emoji)
		if amount > 0:
			print("   %s: %d" % [emoji, amount])

	print("\n" + "=".repeat(80))
	print("TEST COMPLETE")
	print("=".repeat(80))

	get_tree().quit()
