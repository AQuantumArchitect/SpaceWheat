extends SceneTree

## Full game simulation - plant, grow, negotiate, harvest cycle

const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const FactionTerritoryManager = preload("res://Core/GameMechanics/FactionTerritoryManager.gd")
const BioticFluxIcon = preload("res://Core/Icons/BioticFluxIcon.gd")
const ChaosIcon = preload("res://Core/Icons/ChaosIcon.gd")
const ImperiumIcon = preload("res://Core/Icons/ImperiumIcon.gd")

var farm_grid: FarmGrid
var territory_manager: FactionTerritoryManager
var biotic_icon: BioticFluxIcon
var chaos_icon: ChaosIcon
var imperium_icon: ImperiumIcon

var simulation_time = 0.0
var errors_found = 0


func _initialize():
	print("\n🎮 Starting Full Game Simulation...\n")

	# Setup
	setup_game_systems()

	# Simulate 30 seconds of gameplay
	print("🕐 Simulating 30 seconds of gameplay...")
	for i in range(300):  # 30 seconds at 0.1s steps
		simulate_frame(0.1)
		simulation_time += 0.1

	print("\n" + "=".repeat(50))
	print("🎮 SIMULATION RESULTS")
	print("=".repeat(50))
	print("Simulation Time: %.1f seconds" % simulation_time)
	print("Errors Found: %d" % errors_found)

	if errors_found == 0:
		print("🎉 SIMULATION PASSED! No errors detected.")
	else:
		print("⚠️ SIMULATION FAILED! %d errors found." % errors_found)

	print("=".repeat(50) + "\n")

	quit()


func setup_game_systems():
	print("📦 Setting up game systems...")

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

	# Plant wheat on all plots
	for x in range(5):
		for y in range(5):
			var pos = Vector2i(x, y)
			var plot = farm_grid.get_plot(pos)
			plot.plant()

	print("  ✅ Icons created")
	print("  ✅ Territory manager initialized")
	print("  ✅ 25 plots planted\n")


func simulate_frame(delta: float):
	# Update Icons (simulate activation changes)
	if int(simulation_time) % 5 == 0 and simulation_time > 0:
		# Change Icon activations every 5 seconds
		biotic_icon.set_activation(randf())
		chaos_icon.set_activation(randf())
		imperium_icon.set_activation(randf())

	# Update territory manager
	territory_manager._process(delta)

	# Grow all plots
	for x in range(5):
		for y in range(5):
			var pos = Vector2i(x, y)
			var plot = farm_grid.get_plot(pos)

			if plot and plot.is_planted and not plot.is_mature:
				var growth_rate = plot.grow(delta, null, territory_manager)

				# Check for errors
				if growth_rate < 0.0:
					print("  ❌ ERROR: Negative growth rate at %s: %.3f" % [pos, growth_rate])
					errors_found += 1

				if plot.growth_progress < 0.0 or plot.growth_progress > 1.5:
					print("  ❌ ERROR: Invalid growth_progress at %s: %.3f" % [pos, plot.growth_progress])
					errors_found += 1

	# Harvest mature plots
	for x in range(5):
		for y in range(5):
			var pos = Vector2i(x, y)
			var plot = farm_grid.get_plot(pos)

			if plot and plot.is_mature:
				# Measure first
				plot.measure()

				# Harvest
				var result = plot.harvest()

				if result.success:
					# Replant
					plot.plant()

	# Print progress every 5 seconds
	if int(simulation_time) % 5 == 0 and simulation_time > 0:
		var stats = territory_manager.get_territory_stats()
		print("⏱️  t=%.0fs | Territory: B:%.0f%% C:%.0f%% I:%.0f%% N:%.0f%%" % [
			simulation_time,
			stats.biotic_percentage,
			stats.chaos_percentage,
			stats.imperium_percentage,
			stats.neutral_percentage
		])


func test_negotiation():
	print("\n🤝 Testing Icon Negotiation...")

	# Test tribute
	var wheat_amount = 10
	var success = territory_manager.offer_tribute("granary_guilds", wheat_amount)

	if success:
		print("  ✅ Tribute successful")
	else:
		print("  ❌ ERROR: Tribute failed")
		errors_found += 1

	# Test suppress
	var credit_amount = 100
	success = territory_manager.suppress_icon("chaos", credit_amount)

	if success:
		print("  ✅ Suppression successful")
	else:
		print("  ❌ ERROR: Suppression failed")
		errors_found += 1

	print("")
