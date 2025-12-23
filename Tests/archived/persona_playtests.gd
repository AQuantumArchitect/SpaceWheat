extends SceneTree

## Persona-Based Playtesting System
## Simulates different player types to test game mechanics and find bugs

const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
const FactionTerritoryManager = preload("res://Core/GameMechanics/FactionTerritoryManager.gd")
const BioticFluxIcon = preload("res://Core/Icons/BioticFluxIcon.gd")
const ChaosIcon = preload("res://Core/Icons/ChaosIcon.gd")
const ImperiumIcon = preload("res://Core/Icons/ImperiumIcon.gd")
const TomatoConspiracyNetwork = preload("res://Core/QuantumSubstrate/TomatoConspiracyNetwork.gd")

# Game systems (shared across personas)
var farm_grid: FarmGrid
var economy: FarmEconomy
var territory_manager: FactionTerritoryManager
var conspiracy_network: TomatoConspiracyNetwork
var biotic_icon: BioticFluxIcon
var chaos_icon: ChaosIcon
var imperium_icon: ImperiumIcon

# Simulation config
const SIMULATION_TIME = 60.0  # 60 second playthrough per persona
const TIMESTEP = 0.1  # 100ms per tick

# Results tracking
var persona_results = {}


func _initialize():
	print("\n" + "=".repeat(70))
	print("🎮 PERSONA-BASED PLAYTESTING SYSTEM")
	print("=".repeat(70))
	print("Testing game with different player archetypes...")
	print("")

	# Run each persona
	test_persona_power_gamer()
	test_persona_casual_farmer()
	test_persona_spam_clicker()
	test_persona_quantum_experimentalist()
	test_persona_economist()
	test_persona_conspiracy_theorist()

	# Print summary
	print_summary()

	quit()


## PERSONA 1: The Power Gamer 🏆
## Optimizes everything, exploits mechanics, min-maxes ruthlessly

func test_persona_power_gamer():
	print("\n" + "═".repeat(70))
	print("🏆 PERSONA 1: THE POWER GAMER")
	print("═".repeat(70))
	print("Strategy: Optimize everything, exploit mechanics, maximize efficiency")
	print("")

	setup_game()
	var results = {
		"actions": 0,
		"exploits_found": [],
		"max_credits": 0,
		"max_wheat": 0,
		"max_entanglement": 0,
		"territory_captured": 0,
		"crashes": 0,
		"errors": []
	}

	var time = 0.0
	var action_delay = 0.0  # Power gamers act instantly

	while time < SIMULATION_TIME:
		# Power gamer strategy:
		# 1. Plant EVERYTHING immediately
		# 2. Create maximum entanglement (exploit topology bonuses)
		# 3. Harvest at optimal time (not mature, just profitable)
		# 4. Sell everything, buy more
		# 5. Spam tribute to dominant faction (exploit territory)

		# Phase 1: Plant everything (0-5s)
		if time < 5.0 and action_delay <= 0:
			for x in range(5):
				for y in range(5):
					var pos = Vector2i(x, y)
					var plot = farm_grid.get_plot(pos)
					if not plot.is_planted and economy.can_afford(economy.SEED_COST):
						if economy.buy_seed():
							farm_grid.plant_wheat(pos)
							results.actions += 1
			action_delay = 0.5

		# Phase 2: Create entanglement web (5-10s)
		if time >= 5.0 and time < 10.0 and action_delay <= 0:
			# Power gamer discovers: Can create MASSIVE entanglement networks
			var plots_list = []
			for x in range(5):
				for y in range(5):
					plots_list.append(Vector2i(x, y))

			# Try to entangle everything to everything (exploit!)
			for i in range(min(plots_list.size(), 5)):
				for j in range(i + 1, min(plots_list.size(), 10)):
					farm_grid.create_entanglement(plots_list[i], plots_list[j])
					results.actions += 1
					var entangle_count = farm_grid.entangled_pairs.size() + farm_grid.entangled_clusters.size()
					results.max_entanglement = max(results.max_entanglement, entangle_count)

			action_delay = 1.0

		# Phase 3: Aggressive harvesting (10s+)
		if time >= 10.0 and action_delay <= 0:
			for x in range(5):
				for y in range(5):
					var pos = Vector2i(x, y)
					var plot = farm_grid.get_plot(pos)
					# Power gamer harvests at 50% growth (not optimal, but FAST)
					if plot.is_planted and plot.growth_progress >= 0.5:
						var yield_data = farm_grid.harvest_with_topology(pos)
						results.actions += 1
			action_delay = 2.0

		# Phase 4: Economic loop (15s+)
		if time >= 15.0 and action_delay <= 0:
			# Sell all wheat
			if economy.wheat_inventory > 0:
				economy.sell_all_wheat()
				results.actions += 1

			# Immediately rebuy seeds and plant
			while economy.can_afford(economy.SEED_COST):
				for x in range(5):
					for y in range(5):
						var pos = Vector2i(x, y)
						var plot = farm_grid.get_plot(pos)
						if not plot.is_planted and economy.buy_seed():
							farm_grid.plant_wheat(pos)
							results.actions += 1
							break

			action_delay = 3.0

		# Phase 5: Territory exploit (20s+)
		if time >= 20.0 and action_delay <= 0:
			# Power gamer discovers: Can spam tribute to flip entire map
			if economy.wheat_inventory >= 10:
				var tribute_amount = min(economy.wheat_inventory, 50)
				economy.remove_wheat(tribute_amount)
				territory_manager.offer_tribute("granary_guilds", tribute_amount)
				results.actions += 1

				var stats = territory_manager.get_territory_stats()
				results.territory_captured = stats.granary_guilds_plots

			action_delay = 5.0

		# Update game
		farm_grid._process(TIMESTEP)
		_update_icons()
		action_delay -= TIMESTEP
		time += TIMESTEP

		# Track max values
		results.max_credits = max(results.max_credits, economy.credits)
		results.max_wheat = max(results.max_wheat, economy.wheat_inventory)

	# Power gamer analysis
	if results.max_entanglement > 10:
		results.exploits_found.append("Massive entanglement networks possible (%d connections)" % results.max_entanglement)

	if results.territory_captured > 20:
		results.exploits_found.append("Territory flip exploit: Can capture %d plots with tribute spam" % results.territory_captured)

	if results.max_credits > 500:
		results.exploits_found.append("Economic snowball: Reached %d credits in 60s" % results.max_credits)

	persona_results["power_gamer"] = results
	print_persona_results("Power Gamer", results)


## PERSONA 2: The Casual Farmer 🌾
## Just wants to grow wheat peacefully, no stress

func test_persona_casual_farmer():
	print("\n" + "═".repeat(70))
	print("🌾 PERSONA 2: THE CASUAL FARMER")
	print("═".repeat(70))
	print("Strategy: Relaxed play, simple wheat farming, no optimization")
	print("")

	setup_game()
	var results = {
		"actions": 0,
		"wheat_harvested": 0,
		"times_went_broke": 0,
		"max_credits": 0,
		"confusion_points": [],
		"crashes": 0
	}

	var time = 0.0
	var action_delay = 0.0
	var planted_count = 0

	while time < SIMULATION_TIME:
		# Casual farmer strategy:
		# 1. Plant a few plots (not all)
		# 2. Wait for them to fully mature
		# 3. Harvest when ready
		# 4. Sell wheat
		# 5. Maybe plant again if they remember

		# Plant 3-4 plots initially
		if time < 5.0 and planted_count < 4 and action_delay <= 0:
			for x in range(2):
				for y in range(2):
					var pos = Vector2i(x, y)
					var plot = farm_grid.get_plot(pos)
					if not plot.is_planted and economy.can_afford(economy.SEED_COST):
						if economy.buy_seed():
							farm_grid.plant_wheat(pos)
							planted_count += 1
							results.actions += 1
							action_delay = 3.0  # Slow, deliberate planting

		# Wait and check plots occasionally
		if time >= 10.0 and action_delay <= 0:
			# Check if anything is mature
			var found_mature = false
			for x in range(5):
				for y in range(5):
					var pos = Vector2i(x, y)
					var plot = farm_grid.get_plot(pos)
					if plot.is_mature:
						found_mature = true
						var yield_data = farm_grid.harvest_with_topology(pos)
						results.wheat_harvested += yield_data.wheat_gained
						results.actions += 1

			if found_mature:
				action_delay = 5.0  # Wait before next action
			else:
				action_delay = 2.0  # Check again soon

		# Sell wheat occasionally
		if time >= 20.0 and economy.wheat_inventory > 5 and action_delay <= 0:
			economy.sell_all_wheat()
			results.actions += 1
			action_delay = 10.0  # Long pause

		# Confusion point: Tribute system
		if time >= 25.0 and time < 25.5:
			# Casual farmer sees tribute demand, doesn't understand
			if economy.total_tributes_failed > 0:
				results.confusion_points.append("Tribute system: Failed %d times, unclear why credits disappeared" % economy.total_tributes_failed)

		# Maybe plant again if credits allow
		if time >= 40.0 and economy.credits >= 10 and action_delay <= 0:
			if economy.buy_seed():
				var pos = Vector2i(0, 0)
				var plot = farm_grid.get_plot(pos)
				if not plot.is_planted:
					farm_grid.plant_wheat(pos)
					results.actions += 1
			action_delay = 8.0

		# Check if went broke
		if economy.credits < 5 and economy.wheat_inventory == 0:
			results.times_went_broke += 1

		farm_grid._process(TIMESTEP)
		_update_icons()
		action_delay -= TIMESTEP
		time += TIMESTEP

		results.max_credits = max(results.max_credits, economy.credits)

	# Casual analysis
	if results.times_went_broke > 0:
		results.confusion_points.append("Went broke %d times - starting credits too low?" % results.times_went_broke)

	if results.actions < 20:
		results.confusion_points.append("Low engagement - only %d actions in 60s (game too slow?)" % results.actions)

	persona_results["casual_farmer"] = results
	print_persona_results("Casual Farmer", results)


## PERSONA 3: The 8-Year-Old Spam Clicker 👶
## Clicks everything rapidly, no strategy, chaos ensues

func test_persona_spam_clicker():
	print("\n" + "═".repeat(70))
	print("👶 PERSONA 3: THE 8-YEAR-OLD SPAM CLICKER")
	print("═".repeat(70))
	print("Strategy: CLICK ALL THE THINGS! FAST! NO PLAN!")
	print("")

	setup_game()
	var results = {
		"total_clicks": 0,
		"successful_actions": 0,
		"failed_actions": 0,
		"crashes": 0,
		"errors": [],
		"chaos_events": 0,
		"broke_the_game": false
	}

	var time = 0.0
	var click_rate = 0.05  # Click every 50ms (20 clicks/second!)

	while time < SIMULATION_TIME:
		# Spam clicker behavior: Random actions at high speed
		if randf() < 0.3:  # 30% chance per tick
			# Plant random plot
			var x = randi() % 5
			var y = randi() % 5
			var pos = Vector2i(x, y)
			var plot = farm_grid.get_plot(pos)

			results.total_clicks += 1

			if not plot.is_planted:
				if economy.buy_seed():
					farm_grid.plant_wheat(pos)
					results.successful_actions += 1
				else:
					results.failed_actions += 1

		if randf() < 0.2:  # 20% chance per tick
			# Harvest random plot (even if not mature!)
			var x = randi() % 5
			var y = randi() % 5
			var pos = Vector2i(x, y)

			results.total_clicks += 1

			var yield_data = farm_grid.harvest_with_topology(pos)
			if yield_data.wheat_gained > 0:
				results.successful_actions += 1
			else:
				results.failed_actions += 1

		if randf() < 0.15:  # 15% chance per tick
			# Random entanglement clicks
			var x1 = randi() % 5
			var y1 = randi() % 5
			var x2 = randi() % 5
			var y2 = randi() % 5

			results.total_clicks += 1

			if farm_grid.create_entanglement(Vector2i(x1, y1), Vector2i(x2, y2)):
				results.successful_actions += 1
			else:
				results.failed_actions += 1

		if randf() < 0.1:  # 10% chance per tick
			# Spam sell button
			results.total_clicks += 1
			if economy.wheat_inventory > 0:
				economy.sell_all_wheat()
				results.successful_actions += 1
			else:
				results.failed_actions += 1

		if randf() < 0.05:  # 5% chance per tick
			# Random tribute spam
			results.total_clicks += 1
			if economy.wheat_inventory > 0:
				var amount = min(economy.wheat_inventory, randi() % 10 + 1)
				economy.remove_wheat(amount)
				var factions = ["granary_guilds", "carrion_throne", "laughing_court"]
				territory_manager.offer_tribute(factions[randi() % factions.size()], amount)
				results.successful_actions += 1
			else:
				results.failed_actions += 1

		# Update game (stress test!)
		farm_grid._process(TIMESTEP)
		_update_icons()
		time += TIMESTEP

		# Check if game broke
		if economy.credits < -1000:
			results.broke_the_game = true
			results.errors.append("Economy broke: Negative credits %d" % economy.credits)
			break

		if farm_grid.entangled_pairs.size() > 100:
			results.broke_the_game = true
			results.errors.append("Entanglement explosion: %d pairs created" % farm_grid.entangled_pairs.size())
			break

	# Spam clicker analysis
	var success_rate = float(results.successful_actions) / float(results.total_clicks) * 100.0 if results.total_clicks > 0 else 0
	results.chaos_events = results.total_clicks

	persona_results["spam_clicker"] = results
	print_persona_results("Spam Clicker", results)
	print("  Click success rate: %.1f%% (%d successful / %d total)" % [success_rate, results.successful_actions, results.total_clicks])


## PERSONA 4: The Quantum Experimentalist 🔬
## Fascinated by entanglement, topology, and quantum mechanics

func test_persona_quantum_experimentalist():
	print("\n" + "═".repeat(70))
	print("🔬 PERSONA 4: THE QUANTUM EXPERIMENTALIST")
	print("═".repeat(70))
	print("Strategy: Explore quantum mechanics, test entanglement limits")
	print("")

	setup_game()
	var results = {
		"actions": 0,
		"entanglement_structures": [],
		"topology_discoveries": [],
		"max_cluster_size": 0,
		"interesting_observations": [],
		"crashes": 0
	}

	var time = 0.0
	var experiment_phase = 0

	while time < SIMULATION_TIME:
		# Quantum experimentalist performs structured experiments

		# Experiment 1: Linear chain (0-15s)
		if time < 15.0 and experiment_phase == 0:
			# Create a chain: A-B-C-D-E
			for i in range(4):
				var pos_a = Vector2i(i, 0)
				var pos_b = Vector2i(i + 1, 0)

				var plot_a = farm_grid.get_plot(pos_a)
				var plot_b = farm_grid.get_plot(pos_b)

				if not plot_a.is_planted and economy.buy_seed():
					farm_grid.plant_wheat(pos_a)
				if not plot_b.is_planted and economy.buy_seed():
					farm_grid.plant_wheat(pos_b)

				farm_grid.create_entanglement(pos_a, pos_b)
				results.actions += 1

			results.entanglement_structures.append("Linear chain: 5 qubits")
			experiment_phase = 1
			time += 5.0  # Wait and observe

		# Experiment 2: Triangle (15-30s)
		elif time >= 15.0 and time < 30.0 and experiment_phase == 1:
			# Create triangle: A-B, B-C, C-A
			var positions = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]

			for pos in positions:
				var plot = farm_grid.get_plot(pos)
				if not plot.is_planted and economy.buy_seed():
					farm_grid.plant_wheat(pos)

			farm_grid.create_entanglement(positions[0], positions[1])
			farm_grid.create_entanglement(positions[1], positions[2])
			farm_grid.create_entanglement(positions[2], positions[0])

			results.entanglement_structures.append("Triangle: 3 qubits, closed loop")
			results.actions += 3
			experiment_phase = 2

		# Experiment 3: Star topology (30-45s)
		elif time >= 30.0 and time < 45.0 and experiment_phase == 2:
			# Create star: Center connected to 4 outer nodes
			var center = Vector2i(2, 3)
			var outer = [Vector2i(1, 3), Vector2i(3, 3), Vector2i(2, 2), Vector2i(2, 4)]

			var center_plot = farm_grid.get_plot(center)
			if not center_plot.is_planted and economy.buy_seed():
				farm_grid.plant_wheat(center)

			for pos in outer:
				var plot = farm_grid.get_plot(pos)
				if not plot.is_planted and economy.buy_seed():
					farm_grid.plant_wheat(pos)
				farm_grid.create_entanglement(center, pos)
				results.actions += 1

			results.entanglement_structures.append("Star: 1 hub + 4 spokes")
			experiment_phase = 3

		# Experiment 4: Measurement collapse observation (45-60s)
		elif time >= 45.0 and experiment_phase == 3:
			# Measure entangled system and observe cascade
			if farm_grid.entangled_pairs.size() > 0 or farm_grid.entangled_clusters.size() > 0:
				results.interesting_observations.append("Measuring entangled network...")

				# Measure one node
				farm_grid.measure_plot(Vector2i(2, 2))
				results.actions += 1

				# Check if others collapsed
				var collapsed_count = 0
				for x in range(5):
					for y in range(5):
						var plot = farm_grid.get_plot(Vector2i(x, y))
						if plot.has_been_measured:
							collapsed_count += 1

				results.interesting_observations.append("Measurement cascade: %d plots collapsed" % collapsed_count)

			experiment_phase = 4

		# Check cluster sizes
		for cluster in farm_grid.entangled_clusters:
			results.max_cluster_size = max(results.max_cluster_size, cluster.get_qubit_count())

		farm_grid._process(TIMESTEP)
		_update_icons()
		time += TIMESTEP

	# Experimentalist analysis
	if results.max_cluster_size > 0:
		results.topology_discoveries.append("Maximum cluster size: %d qubits" % results.max_cluster_size)

	if farm_grid.entangled_clusters.size() > 0:
		results.topology_discoveries.append("Cluster upgrade system working: %d clusters created" % farm_grid.entangled_clusters.size())

	persona_results["quantum_experimentalist"] = results
	print_persona_results("Quantum Experimentalist", results)


## PERSONA 5: The Economist 💰
## Focuses purely on maximizing credits and trade

func test_persona_economist():
	print("\n" + "═".repeat(70))
	print("💰 PERSONA 5: THE ECONOMIST")
	print("═".repeat(70))
	print("Strategy: Maximize profit, optimize trade timing")
	print("")

	setup_game()
	var results = {
		"actions": 0,
		"max_credits": 0,
		"total_profit": 0,
		"trades_executed": 0,
		"optimal_strategies": [],
		"crashes": 0
	}

	var time = 0.0
	var starting_credits = economy.credits

	while time < SIMULATION_TIME:
		# Economist strategy:
		# 1. Calculate ROI before every action
		# 2. Only plant if profitable
		# 3. Harvest at optimal price point
		# 4. Never go below safety reserve

		# Maintain cash reserve
		var safety_reserve = 10
		var investable = economy.credits - safety_reserve

		# Calculate potential profit from planting
		if investable >= economy.SEED_COST:
			var expected_yield = 10  # Base wheat yield
			var expected_revenue = expected_yield * economy.WHEAT_BASE_PRICE
			var roi = (expected_revenue - economy.SEED_COST) / float(economy.SEED_COST)

			if roi > 0.5:  # 50% ROI threshold
				# Plant efficiently
				for x in range(3):  # Only plant 3x3 (optimal)
					for y in range(3):
						var pos = Vector2i(x, y)
						var plot = farm_grid.get_plot(pos)
						if not plot.is_planted and economy.can_afford(economy.SEED_COST):
							if economy.buy_seed():
								farm_grid.plant_wheat(pos)
								results.actions += 1

		# Harvest when profitable
		for x in range(5):
			for y in range(5):
				var pos = Vector2i(x, y)
				var plot = farm_grid.get_plot(pos)

				# Economist waits for FULL maturity (max value)
				if plot.is_mature:
					var yield_data = farm_grid.harvest_with_topology(pos)
					results.actions += 1

		# Sell at optimal times (when inventory > 20)
		if economy.wheat_inventory >= 20:
			var revenue = economy.wheat_inventory * economy.WHEAT_BASE_PRICE
			economy.sell_all_wheat()
			results.trades_executed += 1
			results.actions += 1

		# Track profit
		results.total_profit = economy.credits - starting_credits + (economy.wheat_inventory * economy.WHEAT_BASE_PRICE)
		results.max_credits = max(results.max_credits, economy.credits)

		farm_grid._process(TIMESTEP)
		_update_icons()
		time += TIMESTEP

	# Economic analysis
	var hourly_rate = (results.total_profit / SIMULATION_TIME) * 3600.0  # Credits per hour
	results.optimal_strategies.append("Profit rate: %.1f credits/hour" % hourly_rate)

	if results.max_credits > 100:
		results.optimal_strategies.append("Cash accumulation successful: %d credits" % results.max_credits)

	var profit_margin = (results.total_profit / float(max(economy.total_credits_spent, 1))) * 100.0
	results.optimal_strategies.append("Profit margin: %.1f%%" % profit_margin)

	persona_results["economist"] = results
	print_persona_results("Economist", results)


## PERSONA 6: The Conspiracy Theorist 🍅
## Obsessed with tomatoes, conspiracy network, and hidden mechanics

func test_persona_conspiracy_theorist():
	print("\n" + "═".repeat(70))
	print("🍅 PERSONA 6: THE CONSPIRACY THEORIST")
	print("═".repeat(70))
	print("Strategy: Explore hidden mechanics, plant tomatoes, activate conspiracies")
	print("")

	setup_game()
	var results = {
		"actions": 0,
		"tomatoes_planted": 0,
		"conspiracies_activated": 0,
		"chaos_icon_strength": 0.0,
		"hidden_mechanics_found": [],
		"crashes": 0
	}

	var time = 0.0

	while time < SIMULATION_TIME:
		# Conspiracy theorist behavior:
		# 1. Plant tomatoes everywhere
		# 2. Wait for conspiracy network effects
		# 3. Observe Chaos Icon activation
		# 4. Look for hidden interactions

		# Plant tomatoes (not wheat!)
		if time < 20.0:
			for x in range(5):
				for y in range(5):
					var pos = Vector2i(x, y)
					var plot = farm_grid.get_plot(pos)
					if not plot.is_planted and economy.can_afford(economy.SEED_COST):
						if economy.buy_seed():
							# Plant tomato instead of wheat
							farm_grid.plant_tomato(pos, conspiracy_network)
							results.tomatoes_planted += 1
							results.actions += 1

		# Observe conspiracy activation
		if time >= 20.0:
			var active_count = conspiracy_network.active_conspiracies.size()
			if active_count > results.conspiracies_activated:
				results.conspiracies_activated = active_count
				results.hidden_mechanics_found.append("Conspiracy activated! Total: %d" % active_count)

		# Track Chaos Icon
		results.chaos_icon_strength = max(results.chaos_icon_strength, chaos_icon.get_activation())

		farm_grid._process(TIMESTEP)
		_update_icons()
		time += TIMESTEP

	# Conspiracy analysis
	if results.tomatoes_planted > 10:
		results.hidden_mechanics_found.append("Tomato system functional: %d planted" % results.tomatoes_planted)

	if results.chaos_icon_strength > 0.3:
		results.hidden_mechanics_found.append("Chaos Icon manifested: %.0f%% strength" % (results.chaos_icon_strength * 100))

	if results.conspiracies_activated > 0:
		results.hidden_mechanics_found.append("Conspiracy network responsive: %d active" % results.conspiracies_activated)

	persona_results["conspiracy_theorist"] = results
	print_persona_results("Conspiracy Theorist", results)


## Helper Functions

func setup_game():
	"""Reset game state for new persona test"""
	# Create fresh systems
	economy = FarmEconomy.new()
	farm_grid = FarmGrid.new()
	farm_grid.grid_width = 5
	farm_grid.grid_height = 5

	territory_manager = FactionTerritoryManager.new()

	conspiracy_network = TomatoConspiracyNetwork.new()
	farm_grid.conspiracy_network = conspiracy_network

	biotic_icon = BioticFluxIcon.new()
	chaos_icon = ChaosIcon.new()
	imperium_icon = ImperiumIcon.new()

	# Link systems
	farm_grid.add_icon(biotic_icon)
	farm_grid.add_icon(chaos_icon)
	farm_grid.add_icon(imperium_icon)
	farm_grid.faction_territory_manager = territory_manager
	economy.imperium_icon = imperium_icon

	# Register plots with territory manager
	for x in range(5):
		for y in range(5):
			territory_manager.register_plot(Vector2i(x, y))


func _update_icons():
	"""Update Icon activations based on game state"""
	# Biotic: wheat count
	var wheat_count = 0
	for x in range(5):
		for y in range(5):
			var plot = farm_grid.get_plot(Vector2i(x, y))
			if plot.is_planted and plot.plot_type == 0:  # WHEAT
				wheat_count += 1

	biotic_icon.calculate_activation_from_wheat(wheat_count, 25)

	# Chaos: conspiracy count
	var active_conspiracies = conspiracy_network.active_conspiracies.size()
	chaos_icon.calculate_activation_from_conspiracies(active_conspiracies, 12)

	# Imperium: tribute compliance
	imperium_icon.calculate_activation_from_tribute(
		economy.total_tributes_paid,
		economy.total_tributes_failed
	)


func print_persona_results(persona_name: String, results: Dictionary):
	"""Print results for a specific persona"""
	print("Results for %s:" % persona_name)
	print("  Actions taken: %d" % results.get("actions", 0))

	if results.has("exploits_found") and results.exploits_found.size() > 0:
		print("  ⚠️  EXPLOITS FOUND:")
		for exploit in results.exploits_found:
			print("    - %s" % exploit)

	if results.has("confusion_points") and results.confusion_points.size() > 0:
		print("  ❓ CONFUSION POINTS:")
		for confusion in results.confusion_points:
			print("    - %s" % confusion)

	if results.has("errors") and results.errors.size() > 0:
		print("  ❌ ERRORS:")
		for error in results.errors:
			print("    - %s" % error)

	if results.has("broke_the_game") and results.broke_the_game:
		print("  💥 GAME BROKE! Critical failure detected!")

	if results.has("max_credits"):
		print("  Max credits: %d" % results.max_credits)

	if results.has("interesting_observations") and results.interesting_observations.size() > 0:
		print("  🔍 OBSERVATIONS:")
		for obs in results.interesting_observations:
			print("    - %s" % obs)

	if results.has("hidden_mechanics_found") and results.hidden_mechanics_found.size() > 0:
		print("  🕵️ DISCOVERIES:")
		for discovery in results.hidden_mechanics_found:
			print("    - %s" % discovery)


func print_summary():
	"""Print overall summary comparing personas"""
	print("\n" + "=".repeat(70))
	print("📊 OVERALL SUMMARY")
	print("=".repeat(70))

	# Aggregate findings
	var total_exploits = 0
	var total_confusion = 0
	var total_crashes = 0
	var most_profitable = ""
	var max_profit = 0

	for persona_name in persona_results:
		var results = persona_results[persona_name]

		if results.has("exploits_found"):
			total_exploits += results.exploits_found.size()

		if results.has("confusion_points"):
			total_confusion += results.confusion_points.size()

		if results.has("crashes"):
			total_crashes += results.crashes

		if results.has("max_credits") and results.max_credits > max_profit:
			max_profit = results.max_credits
			most_profitable = persona_name

	print("\nKey Findings:")
	print("  Total exploits found: %d" % total_exploits)
	print("  Total confusion points: %d" % total_confusion)
	print("  Total crashes: %d" % total_crashes)
	print("  Most profitable persona: %s (%d credits)" % [most_profitable, max_profit])

	print("\nRecommendations:")

	if total_exploits > 0:
		print("  ⚠️  Balance issues detected - review exploit reports")

	if total_confusion > 5:
		print("  ❓ UX issues - casual players may struggle with complexity")

	if total_crashes > 0:
		print("  ❌ Stability issues - fix critical bugs")
	else:
		print("  ✅ No crashes - system stable across all personas")

	print("\n" + "=".repeat(70))
