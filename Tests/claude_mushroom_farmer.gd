extends SceneTree

## Claude becomes a mushroom farmer!
## Tests the complete mushroom economy loop:
##   Forest harvest → Plant mushroom → Harvest → Composting

const Farm = preload("res://Core/Farm.gd")

var farm: Farm
var game_time: float = 0.0
var turn: int = 0

func _init():
	print("\n" + "═".repeat(80))
	print("🍄 CLAUDE THE MUSHROOM FARMER")
	print("═".repeat(80))
	print("Testing: Forest → Detritus → Mushroom → Composting loop")
	print("═".repeat(80) + "\n")

	# Create farm
	farm = Farm.new()
	root.add_child(farm)

	# Wait for initialization
	var timer = Timer.new()
	root.add_child(timer)
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.timeout.connect(_start_farming)
	timer.start()

func _start_farming():
	print("🌾 Farm initialized!\n")
	_print_resources()

	# Execute farming strategy
	_turn_1_gather_detritus()
	_turn_2_plant_mushrooms()
	_turn_3_wait_and_harvest()
	_turn_4_observe_composting()

	print("\n" + "═".repeat(80))
	print("✅ MUSHROOM FARMING COMPLETE!")
	print("═".repeat(80) + "\n")
	quit()

func _turn_1_gather_detritus():
	turn += 1
	print("─".repeat(80))
	print("🎮 TURN %d: GATHER DETRITUS FROM FOREST" % turn)
	print("─".repeat(80))

	print("🌲 Walking to Forest biome (plot F at 3,1)...")
	var forest_plot = Vector2i(3, 1)  # F key

	print("🍂 Attempting to gather fallen leaves and deadwood...")
	var success = farm.build(forest_plot, "forest_harvest")

	if success:
		print("   ✅ Gathered detritus from forest floor!")
	else:
		print("   ❌ Failed to gather - maybe not in Forest?")

	_print_resources()
	print("")

func _turn_2_plant_mushrooms():
	turn += 1
	print("─".repeat(80))
	print("🎮 TURN %d: PLANT MUSHROOMS" % turn)
	print("─".repeat(80))

	var mushroom = farm.economy.get_resource("🍄")
	var detritus = farm.economy.get_resource("🍂")

	print("💰 Current: 🍄 %d  🍂 %d" % [mushroom, detritus])

	if mushroom >= 10 and detritus >= 10:
		print("🍄 Planting mushroom at plot T (2,0)...")
		var plot_pos = Vector2i(2, 0)
		var success = farm.build(plot_pos, "mushroom")

		if success:
			print("   ✅ Mushroom spores planted!")
		else:
			print("   ❌ Failed to plant mushroom")
	else:
		print("⚠️  Not enough resources to plant mushroom!")
		print("   Need: 🍄 10  🍂 10")

	_print_resources()
	print("")

func _turn_3_wait_and_harvest():
	turn += 1
	print("─".repeat(80))
	print("🎮 TURN %d: WAIT FOR GROWTH & HARVEST" % turn)
	print("─".repeat(80))

	var plot_pos = Vector2i(2, 0)
	var plot = farm.grid.get_plot(plot_pos)

	if not plot or not plot.is_planted:
		print("⚠️  No mushroom planted to harvest!")
		print("")
		return

	print("🌙 Waiting for mushroom to grow (prefer nighttime)...")
	print("   Simulating 2 days of quantum evolution...")

	if farm.biotic_flux_biome:
		# Simulate day/night cycles
		for day in range(2):
			farm.biotic_flux_biome._process(10.0)  # Shorter sim
			game_time += 10.0

			var radius = plot.quantum_state.radius if plot.quantum_state else 0.0
			print("   Day %d: radius = %.3f" % [day + 1, radius])

	print("\n📏 Measuring mushroom...")
	var outcome = farm.measure_plot(plot_pos)
	print("   Outcome: %s" % outcome)

	print("🚜 Harvesting...")
	var result = farm.harvest_plot(plot_pos)
	if result.get("success"):
		var yield_credits = result.get("yield", 0)
		print("   ✅ Harvested! Yield: %d credits" % yield_credits)
	else:
		print("   ❌ Harvest failed!")

	_print_resources()
	print("")

func _turn_4_observe_composting():
	turn += 1
	print("─".repeat(80))
	print("🎮 TURN %d: OBSERVE PASSIVE COMPOSTING" % turn)
	print("─".repeat(80))

	print("🍄 Planting another mushroom to activate composting...")
	var plot_pos = Vector2i(1, 0)  # Different plot
	var plant_success = farm.build(plot_pos, "mushroom")

	if not plant_success:
		print("   ⚠️  Couldn't plant second mushroom (may need more resources)")

	print("\n🍂→🍄 Watching composting system over 10 seconds...")
	var before_mushroom = farm.economy.get_resource("🍄")
	var before_detritus = farm.economy.get_resource("🍂")
	print("   Before: 🍄 %d  🍂 %d" % [before_mushroom, before_detritus])

	# Simulate time passing with farm._process running
	print("   ⏰ Waiting...")
	for i in range(100):  # 10 seconds at 0.1s per frame
		farm._process(0.1)
		if i % 30 == 29:  # Every 3 seconds
			var mushroom_now = farm.economy.get_resource("🍄")
			var detritus_now = farm.economy.get_resource("🍂")
			var change_m = mushroom_now - before_mushroom
			var change_d = before_detritus - detritus_now
			print("   [%.1fs] 🍄 %d (+%d)  🍂 %d (-%d)" % [(i+1.0)*0.1, mushroom_now, change_m, detritus_now, change_d])

	var after_mushroom = farm.economy.get_resource("🍄")
	var after_detritus = farm.economy.get_resource("🍂")
	var composted_mushroom = after_mushroom - before_mushroom
	var consumed_detritus = before_detritus - after_detritus

	print("\n   After:  🍄 %d  🍂 %d" % [after_mushroom, after_detritus])
	print("   Change: 🍄 +%d  🍂 -%d" % [composted_mushroom, consumed_detritus])

	if composted_mushroom > 0:
		var ratio = float(consumed_detritus) / float(composted_mushroom)
		print("   📊 Conversion ratio: %.1f:1 (expected 2:1)" % ratio)
		print("   ✅ COMPOSTING WORKING!")
	else:
		print("   ⚠️  No composting observed")

	print("")
	_print_resources()

func _print_resources():
	var wheat = farm.economy.get_resource("🌾")
	var mushroom = farm.economy.get_resource("🍄")
	var detritus = farm.economy.get_resource("🍂")
	var labor = farm.economy.get_resource("👥")

	print("📊 Resources: 🌾 %d  🍄 %d  🍂 %d  👥 %d" % [wheat, mushroom, detritus, labor])
