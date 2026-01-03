extends Node

## Test harvest after quantum evolution to get actual resources

var farm: Node

func _ready():
	print("\n" + "=".repeat(80))
	print("HARVEST WITH QUANTUM EVOLUTION TEST")
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
	print("🌱 Planting wheat at (0,0)...")
	farm.build(Vector2i(0, 0), "wheat")
	await get_tree().process_frame

	var plot = farm.grid.get_plot(Vector2i(0, 0))
	print("   Plot planted: %s" % plot.is_planted)
	if plot.quantum_state:
		print("   Initial coherence: %.3f" % plot.quantum_state.radius)

	# Check resources before harvest
	print("\n📊 Resources BEFORE harvest:")
	var wheat_before = farm.economy.get_resource_units("🌾")
	var mushroom_before = farm.economy.get_resource_units("🍄")
	var labor_before = farm.economy.get_resource_units("👥")
	print("   🌾 Wheat: %d" % wheat_before)
	print("   🍄 Mushroom: %d" % mushroom_before)
	print("   👥 Labor: %d" % labor_before)

	# Let quantum state evolve for a bit
	print("\n⏱️  Waiting 2 seconds for quantum evolution...")
	await get_tree().create_timer(2.0).timeout

	if plot.quantum_state:
		print("   Coherence after evolution: %.3f" % plot.quantum_state.radius)
		print("   North probability: %.3f" % plot.quantum_state.get_north_probability())
		print("   South probability: %.3f" % plot.quantum_state.get_south_probability())

	# Harvest
	print("\n✂️  Harvesting plot (0,0)...")
	var result = farm.harvest_plot(Vector2i(0, 0))

	print("\n📋 Harvest result:")
	print("   success: %s" % result.get("success", false))
	print("   outcome: %s" % result.get("outcome", "?"))
	print("   yield: %s" % result.get("yield", 0))
	print("   coherence: %.3f" % result.get("energy", 0.0))

	# Check resources after harvest
	print("\n📊 Resources AFTER harvest:")
	var wheat_after = farm.economy.get_resource_units("🌾")
	var mushroom_after = farm.economy.get_resource_units("🍄")
	var labor_after = farm.economy.get_resource_units("👥")
	print("   🌾 Wheat: %d (Δ=%+d)" % [wheat_after, wheat_after - wheat_before])
	print("   🍄 Mushroom: %d (Δ=%+d)" % [mushroom_after, mushroom_after - mushroom_before])
	print("   👥 Labor: %d (Δ=%+d)" % [labor_after, labor_after - labor_before])

	# Check which resource increased
	print("\n✅ Resources gained:")
	var gained = false
	if wheat_after > wheat_before:
		print("   🌾 +%d Wheat" % (wheat_after - wheat_before))
		gained = true
	if mushroom_after > mushroom_before:
		print("   🍄 +%d Mushroom" % (mushroom_after - mushroom_before))
		gained = true
	if labor_after > labor_before:
		print("   👥 +%d Labor" % (labor_after - labor_before))
		gained = true

	if not gained:
		print("   ⚠️  No resources gained (might be unknown '?' emoji)")

	print("\n" + "=".repeat(80))
	print("TEST COMPLETE")
	print("=".repeat(80))

	get_tree().quit()
