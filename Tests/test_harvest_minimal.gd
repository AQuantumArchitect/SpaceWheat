extends Node

## Minimal harvest test - no UI dependencies

const Farm = preload("res://Core/Farm.gd")

func _ready():
	print("\n" + "=".repeat(80))
	print("MINIMAL HARVEST TEST")
	print("=".repeat(80) + "\n")

	# Create farm
	print("Creating farm...")
	var farm = Farm.new()

	# Wait for initialization
	print("Waiting for farm initialization...")
	await get_tree().process_frame
	for i in range(15):
		await get_tree().process_frame

	await get_tree().create_timer(1.0).timeout

	print("✅ Farm ready\n")

	# Plant wheat at (0,0)
	print("📍 Planting wheat at (0,0)...")
	var plant_result = farm.build(Vector2i(0, 0), "wheat")
	print("   Plant success: %s" % plant_result)

	await get_tree().process_frame

	var plot = farm.grid.get_plot(Vector2i(0, 0))
	print("   Plot planted: %s" % plot.is_planted)
	print("   Plot has_been_measured: %s" % plot.has_been_measured)
	if plot.quantum_state:
		print("   Quantum state: %s ↔ %s" % [
			plot.quantum_state.north_emoji,
			plot.quantum_state.south_emoji
		])

	# Check initial resources
	print("\n📊 Resources BEFORE harvest:")
	var initial_wheat = farm.economy.get_resource("🌾")
	var initial_labor = farm.economy.get_resource("👥")
	print("   🌾 Wheat: %d" % initial_wheat)
	print("   👥 Labor: %d" % initial_labor)

	# Now measure the plot (required before harvest)
	print("\n👁️  Measuring plot...")
	var measure_result = farm.measure_plot(Vector2i(0, 0))
	print("   Measure result: %s" % measure_result)

	plot = farm.grid.get_plot(Vector2i(0, 0))
	print("   Plot has_been_measured after: %s" % plot.has_been_measured)

	await get_tree().process_frame

	# Now harvest
	print("\n✂️  HARVESTING plot (0,0)...")
	print("-".repeat(80))

	var harvest_result = farm.harvest_plot(Vector2i(0, 0))

	print("-".repeat(80))
	print("\n📋 Harvest result:")
	print("   success: %s" % harvest_result.get("success", false))
	print("   outcome: %s" % harvest_result.get("outcome", "?"))
	print("   yield: %d" % harvest_result.get("yield", 0))

	if harvest_result.get("success"):
		var final_wheat = farm.economy.get_resource("🌾")
		var final_labor = farm.economy.get_resource("👥")
		print("\n📊 Resources AFTER harvest:")
		print("   🌾 Wheat: %d (was %d, gain: %d)" % [final_wheat, initial_wheat, final_wheat - initial_wheat])
		print("   👥 Labor: %d (was %d, gain: %d)" % [final_labor, initial_labor, final_labor - initial_labor])
		print("\n✅ HARVEST SUCCESSFUL!")
	else:
		print("\n❌ HARVEST FAILED!")
		print("   Error: %s" % harvest_result.get("error", "unknown"))

	print("\n" + "=".repeat(80))
	print("TEST COMPLETE")
	print("=".repeat(80) + "\n")

	get_tree().quit(0)
