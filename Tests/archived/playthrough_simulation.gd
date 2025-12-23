extends SceneTree

## Interactive Playthrough Simulation
## Simulates a player making strategic decisions to win territory control

const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
const FactionTerritoryManager = preload("res://Core/GameMechanics/FactionTerritoryManager.gd")
const BioticFluxIcon = preload("res://Core/Icons/BioticFluxIcon.gd")
const ChaosIcon = preload("res://Core/Icons/ChaosIcon.gd")
const ImperiumIcon = preload("res://Core/Icons/ImperiumIcon.gd")

# Game systems
var farm_grid: FarmGrid
var economy: FarmEconomy
var territory_manager: FactionTerritoryManager
var biotic_icon: BioticFluxIcon
var chaos_icon: ChaosIcon
var imperium_icon: ImperiumIcon

# Game state
var game_time: float = 0.0
var turn: int = 0
var player_strategy = "BIOTIC_DOMINANCE"  # Goal: Get Biotic to 75% control

# Stats tracking
var total_wheat_harvested: int = 0
var total_tribute_offered: int = 0
var harvests_completed: int = 0


func _initialize():
	print("\n" + "=".repeat(60))
	print("🎮 SPACE WHEAT - INTERACTIVE PLAYTHROUGH")
	print("=".repeat(60))
	print("Strategy: Achieve Biotic Dominance (75%+ territory)")
	print("Starting Credits: 100")
	print("Starting Wheat: 0")
	print("=".repeat(60) + "\n")

	setup_game()
	play_game()

	print("\n" + "=".repeat(60))
	print("🎮 PLAYTHROUGH COMPLETE")
	print("=".repeat(60))
	print_final_stats()
	print("=".repeat(60) + "\n")

	quit()


func setup_game():
	print("📦 Setting up game systems...\n")

	# Create economy
	economy = FarmEconomy.new()

	# Create Icons
	biotic_icon = BioticFluxIcon.new()
	chaos_icon = ChaosIcon.new()
	imperium_icon = ImperiumIcon.new()

	# Create territory manager (Factions control territory, Icons are quantum layer)
	territory_manager = FactionTerritoryManager.new()
	# NOTE: Icons are separate from factions - no set_icons() call needed

	# Create farm grid
	farm_grid = FarmGrid.new()
	farm_grid.grid_width = 5
	farm_grid.grid_height = 5
	farm_grid.faction_territory_manager = territory_manager

	print("  ✅ Game systems ready\n")


func play_game():
	print("🎬 Starting playthrough...\n")

	# Turn 1: Plant initial crops
	execute_turn("Plant 9 wheat plots in center area", func():
		print("💡 Action: Planting wheat in center 3x3 area")
		var plots_planted = 0
		for x in range(1, 4):
			for y in range(1, 4):
				if economy.credits >= economy.SEED_COST:
					var pos = Vector2i(x, y)
					var plot = farm_grid.get_plot(pos)
					plot.plant()
					economy.spend_credits(economy.SEED_COST)
					plots_planted += 1
		print("  🌱 Planted %d plots" % plots_planted)
		print("  💰 Credits remaining: %d" % economy.credits)
	)

	# Turn 2: Wait for some growth
	execute_turn("Wait 5 seconds for crops to grow", func():
		print("💡 Action: Waiting for growth...")
		simulate_time(5.0)
		print("  ⏱️  5 seconds passed")
	)

	# Turn 3: Check territory and offer tribute to Biotic
	execute_turn("Boost Biotic Icon with tribute", func():
		print("💡 Action: Offering tribute to Biotic Icon")
		var stats = territory_manager.get_territory_stats()
		print("  📊 Current Territory:")
		print("     Biotic: %.0f%% | Chaos: %.0f%% | Imperium: %.0f%%" % [
			stats.biotic_percentage, stats.chaos_percentage, stats.imperium_percentage
		])

		# Harvest any mature crops first
		var wheat_gained = harvest_all_mature()
		if wheat_gained > 0:
			print("  ✂️  Harvested %d wheat" % wheat_gained)

		# Offer tribute if we have wheat
		if economy.wheat_inventory >= 10:
			var tribute_amount = min(20, economy.wheat_inventory)
			economy.wheat_inventory -= tribute_amount
			territory_manager.offer_tribute("granary_guilds", tribute_amount)
			total_tribute_offered += tribute_amount
			print("  🌾 Offered %d wheat to Biotic Icon" % tribute_amount)
		else:
			print("  ⚠️  Not enough wheat for tribute (have: %d)" % economy.wheat_inventory)
	)

	# Turn 4: More growth and check results
	execute_turn("Wait for territory shift", func():
		print("💡 Action: Observing territory changes...")
		simulate_time(3.0)
		var stats = territory_manager.get_territory_stats()
		print("  📊 Territory Update:")
		print("     Biotic: %.0f%% | Chaos: %.0f%% | Imperium: %.0f%%" % [
			stats.biotic_percentage, stats.chaos_percentage, stats.imperium_percentage
		])
	)

	# Turn 5: Entangle plots for growth bonus
	execute_turn("Create entanglements for bonus", func():
		print("💡 Action: Entangling plots for growth boost")
		var entangled = 0

		# Entangle center plot with neighbors
		var center = Vector2i(2, 2)
		var neighbors = [Vector2i(2, 1), Vector2i(2, 3), Vector2i(1, 2)]

		for neighbor in neighbors:
			var success = farm_grid.create_entanglement(center, neighbor)
			if success:
				entangled += 1

		print("  🔗 Created %d entanglements" % entangled)
	)

	# Turn 6: Wait for entanglement growth bonus
	execute_turn("Let entangled plots grow faster", func():
		print("💡 Action: Waiting for entanglement growth bonus...")
		simulate_time(5.0)
		print("  ⏱️  5 seconds with entanglement bonuses")
		var wheat_gained = harvest_all_mature()
		if wheat_gained > 0:
			print("  ✂️  Harvested %d wheat" % wheat_gained)
	)

	# Turn 7: Suppress competing Icons
	execute_turn("Suppress Chaos Icon", func():
		print("💡 Action: Suppressing Chaos Icon expansion")
		var stats = territory_manager.get_territory_stats()
		print("  📊 Current Territory:")
		print("     Biotic: %.0f%% | Chaos: %.0f%% | Imperium: %.0f%%" % [
			stats.biotic_percentage, stats.chaos_percentage, stats.imperium_percentage
		])

		if economy.credits >= 100:
			economy.spend_credits(100)
			territory_manager.suppress_icon("chaos", 100)
			print("  💰 Paid 100 credits to suppress Chaos")
		else:
			print("  ⚠️  Not enough credits to suppress (have: %d)" % economy.credits)
	)

	# Turn 8: Final harvest and tribute push
	execute_turn("Final push for Biotic dominance", func():
		print("💡 Action: Harvesting and offering massive tribute")

		# Harvest everything
		var wheat_gained = harvest_all_mature()
		print("  ✂️  Harvested %d wheat" % wheat_gained)

		# Offer all wheat as tribute
		if economy.wheat_inventory > 0:
			var tribute = economy.wheat_inventory
			economy.wheat_inventory = 0
			territory_manager.offer_tribute("biotic", tribute)
			total_tribute_offered += tribute
			print("  🌾 Offered %d wheat to Biotic Icon (ALL IN!)" % tribute)

		simulate_time(3.0)
	)

	# Turn 9: Check final result
	execute_turn("Check final territory control", func():
		print("💡 Action: Checking if we achieved dominance...")
		simulate_time(2.0)

		var stats = territory_manager.get_territory_stats()
		print("\n  🏆 FINAL TERRITORY REPORT:")
		print("     Biotic:    %.0f%% %s" % [
			stats.biotic_percentage,
			"👑 DOMINANT!" if stats.dominant_icon == "biotic" else ""
		])
		print("     Chaos:     %.0f%%" % stats.chaos_percentage)
		print("     Imperium:  %.0f%%" % stats.imperium_percentage)
		print("     Neutral:   %.0f%%" % stats.neutral_percentage)

		if stats.biotic_percentage >= 75.0:
			print("\n  🎉 VICTORY! Biotic Dominance achieved!")
		elif stats.dominant_icon == "biotic":
			print("\n  ✅ SUCCESS! Biotic is dominant (goal: 75%%, actual: %.0f%%)" % stats.biotic_percentage)
		else:
			print("\n  ❌ FAILED! Biotic did not achieve dominance (%.0f%%)" % stats.biotic_percentage)
	)


func execute_turn(description: String, action: Callable):
	turn += 1
	print("\n" + "-".repeat(60))
	print("Turn %d: %s" % [turn, description])
	print("-".repeat(60))

	action.call()


func simulate_time(seconds: float):
	var steps = int(seconds * 10)  # 10 steps per second
	for i in range(steps):
		var delta = 0.1
		game_time += delta

		# Update territory manager
		territory_manager._process(delta)

		# Grow all plots
		for x in range(5):
			for y in range(5):
				var pos = Vector2i(x, y)
				var plot = farm_grid.get_plot(pos)
				if plot and plot.is_planted and not plot.is_mature:
					plot.grow(delta, null, territory_manager)


func harvest_all_mature() -> int:
	var wheat_gained = 0

	for x in range(5):
		for y in range(5):
			var pos = Vector2i(x, y)
			var plot = farm_grid.get_plot(pos)

			if plot and plot.is_mature:
				# Measure
				plot.measure()

				# Harvest
				var result = plot.harvest()
				if result.success:
					var yield_amount = result.yield
					wheat_gained += yield_amount
					economy.wheat_inventory += yield_amount
					harvests_completed += 1

					# Replant
					if economy.credits >= economy.SEED_COST:
						plot.plant()
						economy.spend_credits(economy.SEED_COST)

	total_wheat_harvested += wheat_gained
	return wheat_gained


func print_final_stats():
	print("📊 PLAYTHROUGH STATISTICS")
	print("")
	print("  Game Time:           %.1f seconds" % game_time)
	print("  Turns Taken:         %d" % turn)
	print("  Wheat Harvested:     %d" % total_wheat_harvested)
	print("  Tribute Offered:     %d wheat" % total_tribute_offered)
	print("  Harvests Completed:  %d" % harvests_completed)
	print("  Final Credits:       %d" % economy.credits)
	print("  Final Wheat:         %d" % economy.wheat_inventory)
	print("")

	var stats = territory_manager.get_territory_stats()
	print("  Final Territory:")
	print("    Biotic:    %.0f%%" % stats.biotic_percentage)
	print("    Chaos:     %.0f%%" % stats.chaos_percentage)
	print("    Imperium:  %.0f%%" % stats.imperium_percentage)
