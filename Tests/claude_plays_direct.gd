extends SceneTree

const Farm = preload("res://Core/Farm.gd")

func _init():
	print("\n🎮 DIRECT PLAY TEST\n")

	# Create farm
	var farm = Farm.new()
	root.add_child(farm)

	print("Farm created")
	print("Waiting for init...")

	# Use process frames to wait
	await_frames(2)

	print("\nStarting play!")
	print("Wheat: %d" % farm.economy.get_resource("🌾"))

	# Plant
	print("\n1. Planting...")
	farm.build(Vector2i(0, 0), "wheat")
	print("   Wheat after plant: %d" % farm.economy.get_resource("🌾"))

	# Evolve
	print("\n2. Evolving quantum bath...")
	if farm.biotic_flux_biome:
		farm.biotic_flux_biome._process(60.0)
	print("   Evolved 60 seconds")

	# Measure
	print("\n3. Measuring...")
	var outcome = farm.measure_plot(Vector2i(0, 0))
	print("   Outcome: %s" % outcome)

	# Harvest
	print("\n4. Harvesting...")
	var result = farm.harvest_plot(Vector2i(0, 0))
	print("   Success: %s" % result.get("success"))
	print("   Yield: %d" % result.get("yield", 0))
	print("   Final wheat: %d" % farm.economy.get_resource("🌾"))

	print("\n✅ DONE!\n")
	quit()

func await_frames(count: int):
	for i in range(count):
		await process_frame
