#!/usr/bin/env -S godot --headless -s
extends SceneTree

## STRATEGY 3: BALANCED HYBRID
## Focus: Diversified approach balancing immediate returns with long-term growth
## Approach: Split plots 3/3 between MarketBiome (fast credits) and FarmingBiome (resources)
## Risk: Moderate - benefits from both systems, but doesn't maximize either
##
## Outcome: Balanced resources AND moderate credits with growth potential

const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
const Biome = preload("res://Core/Environment/Biome.gd")
const MarketBiome = preload("res://Core/Environment/MarketBiome.gd")
const WheatPlot = preload("res://Core/GameMechanics/WheatPlot.gd")

var grid: FarmGrid
var economy: FarmEconomy
var biome: BioticFluxBiome
var market_biome: MarketBiome

var strategy_name: String = "BALANCED HYBRID"
var strategy_desc: String = "Split equally: 3 plots market (fast credits) + 3 plots farming (resources)"

var market_plots: Array = []
var farming_plots: Array = []

func _initialize():
	print("\n" + "=".repeat(70))
	print("🎮 GAMEPLAY STRATEGY 3: " + strategy_name)
	print(strategy_desc)
	print("=".repeat(70) + "\n")

	_setup_systems()
	_plant_balanced()
	_evolve_and_harvest()
	_production_phase()
	_print_results()

	quit()


func _setup_systems():
	print("SETUP: Initializing systems...\n")
	grid = FarmGrid.new()
	grid.grid_width = 3
	grid.grid_height = 2

	economy = FarmEconomy.new()
	economy.credits = 50

	biome = BioticFluxBiome.new()
	biome.grid = grid
	biome._ready()

	market_biome = MarketBioticFluxBiome.new()
	market_biome._initialize_market_qubits()

	# Create 6 empty plots
	for y in range(grid.grid_height):
		for x in range(grid.grid_width):
			var plot = WheatPlot.new()
			plot.plot_id = char(65 + y * grid.grid_width + x)  # A-F
			plot.grid_position = Vector2i(x, y)
			grid.plots[Vector2i(x, y)] = plot

	print("✓ Grid: %dx%d (%d plots)" % [grid.grid_width, grid.grid_height, 6])
	print("✓ Starting credits: %d" % economy.credits)
	print()


func _plant_balanced():
	print("PLANTING PHASE: Split strategy (3 market + 3 farming)\n")

	var plot_positions = grid.plots.keys()

	# Split: first 3 to market, last 3 to farming
	for i in range(plot_positions.size()):
		var pos = plot_positions[i]
		var plot = grid.plots[pos]

		if i < 3:
			# MARKET PLOTS (A, B, C)
			var wheat = 0.22
			var labor = 0.08
			var coin_qubit = market_biome.inject_planting(pos, wheat, labor, 4)
			plot.quantum_state = coin_qubit
			plot.is_planted = true
			market_plots.append(plot)
			print("  Plot %s → Market (coin energy)" % plot.plot_id)
		else:
			# FARMING PLOTS (D, E, F)
			var wheat = 0.22
			var labor = 0.08
			var planting_qubit = biome.inject_planting(pos, wheat, labor, 0)
			plot.quantum_state = planting_qubit
			plot.is_planted = true
			farming_plots.append(plot)
			print("  Plot %s → Farming (quantum superposition)" % plot.plot_id)

	print()
	print("✓ Planted 3 plots to each biome")
	print()


func _evolve_and_harvest():
	print("HARVEST PHASE: Fast market harvests + Quantum farming evolution\n")

	# Market plots: instant harvest
	print("📍 MARKET BIOME HARVEST (Immediate):\n")
	var market_credits = 0
	for plot in market_plots:
		if plot.quantum_state:
			var harvest = market_biome.harvest_coin_energy(plot.quantum_state)
			if harvest["success"]:
				market_credits += harvest["credits"]
				print("  %s: +%d credits" % [plot.plot_id, harvest["credits"]])

	economy.credits += market_credits
	print("\n  Subtotal: +%d credits\n" % market_credits)

	# Farming plots: simulate quantum evolution then measure
	print("📍 FARMING BIOME HARVEST (After evolution):\n")

	# Simulate a couple evolution cycles
	for cycle in range(3):
		for plot in farming_plots:
			if plot.quantum_state:
				var current_theta = plot.quantum_state.theta
				var target_theta = PI / 2.0
				var drift = (target_theta - current_theta) * 0.08
				plot.quantum_state.theta += drift

	# Now measure
	var total_wheat = 0.0
	var total_labor = 0.0

	for plot in farming_plots:
		if plot.quantum_state:
			var harvest = biome.harvest_quantum_planting(plot.quantum_state)
			if harvest["success"]:
				total_wheat += harvest["wheat"]
				total_labor += harvest["labor"]
				print("  %s: %.2f🌾 + %.2f👥" % [plot.plot_id, harvest["wheat"], harvest["labor"]])

	economy.wheat_inventory += int(total_wheat)
	print("\n  Subtotal: %.2f🌾 + %.2f👥\n" % [total_wheat, total_labor])


func _production_phase():
	print("PRODUCTION PHASE: Convert resources to additional credits\n")

	# Mill the wheat into flour
	if economy.wheat_inventory > 0:
		var wheat_to_mill = min(economy.wheat_inventory, int(economy.wheat_inventory * 0.8))
		var mill_result = economy.process_wheat_to_flour(wheat_to_mill)

		if mill_result["success"]:
			print("✓ Milled %d wheat → %d flour" % [mill_result["wheat_used"], mill_result["flour_produced"]])
			print("  Processing bonus: +%d credits" % mill_result["credits_earned"])
			economy.credits += mill_result["credits_earned"]

			# Sell the flour
			if mill_result["flour_produced"] > 0:
				var market_result = economy.sell_flour_at_market(mill_result["flour_produced"])
				if market_result["success"]:
					print("✓ Sold %d flour → %d credits" % [market_result["flour_sold"], market_result["credits_received"]])
					economy.credits += market_result["credits_received"]

	print()


func print_line(char: String, count: int) -> String:
	var line = ""
	for i in range(count):
		line += char
	return line

func _print_results():
	print(print_line("=", 70))
	print("📊 RESULTS: " + strategy_name)
	print(print_line("=", 70))

	print("Final Economy:")
	print("  Wheat:        %d units" % economy.wheat_inventory)
	print("  Labor:        ~0.3 units")
	print("  Flour:        %d units" % economy.flour_inventory)
	print("  Credits:      %d (started 50, +%d)" % [economy.credits, economy.credits - 50])
	print()

	print("Strategy Metrics:")
	print("  Time to profit:  Hybrid (instant market + 30s farming evolution)")
	print("  Resource focus:  Balanced (credits + wheat + labor)")
	print("  Quantum usage:   Mixed (coin energy + superposition)")
	print("  Scaling:         Exponential (both chains working together)")
	print()

	print("Pros:")
	print("  + Immediate credit returns from market plots")
	print("  + Accumulates wheat for production chain")
	print("  + Balanced risk across both systems")
	print("  + Production chain multiplies returns")
	print("  + Perfect for players wanting depth + reward")
	print()

	print("Cons:")
	print("  - Neither system maximized")
	print("  - Moderate complexity (manage 2 biomes)")
	print("  - Requires waiting for farming evolution")
	print("  - Market price fluctuations still impact returns")
	print()



func print_sep() -> String:
	var line = ""
	for i in range(70):
		line += "─"
	return line
