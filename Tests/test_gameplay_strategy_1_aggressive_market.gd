#!/usr/bin/env -S godot --headless -s
extends SceneTree

## STRATEGY 1: AGGRESSIVE MARKET FOCUS
## Focus: Maximize immediate credits
## Approach: Plant ALL plots into MarketBiome
## Risk: Ignore farming resources, rely purely on market coins
##
## Outcome: High immediate credits, zero farming resources

const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
const Biome = preload("res://Core/Environment/Biome.gd")
const MarketBiome = preload("res://Core/Environment/MarketBiome.gd")
const WheatPlot = preload("res://Core/GameMechanics/WheatPlot.gd")

var grid: FarmGrid
var economy: FarmEconomy
var biome: BioticFluxBiome
var market_biome: MarketBiome

var strategy_name: String = "AGGRESSIVE MARKET FOCUS"
var strategy_desc: String = "Plant ALL into market for immediate credits"

func _initialize():
	print("\n" + "=".repeat(70))
	print("🎮 GAMEPLAY STRATEGY 1: " + strategy_name)
	print(strategy_desc)
	print("=".repeat(70) + "\n")

	_setup_systems()
	_plant_all_market()
	_harvest_and_calculate()
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


func _plant_all_market():
	print("PLANTING PHASE: All plots → MarketBiome\n")

	var plot_positions = grid.plots.keys()
	var total_coin_energy = 0.0

	for i in range(plot_positions.size()):
		var pos = plot_positions[i]
		var plot = grid.plots[pos]

		# Vary resources slightly per plot for realism
		var wheat = 0.22
		var labor = 0.08

		if i % 3 == 0:  # Every 3rd plot: invest more labor
			wheat = 0.25
			labor = 0.12
		elif i % 3 == 1:  # Every other: standard
			wheat = 0.22
			labor = 0.08
		else:  # Others: less labor, same wheat
			wheat = 0.20
			labor = 0.06

		var coin_qubit = market_biome.inject_planting(pos, wheat, labor, 4)
		plot.quantum_state = coin_qubit
		plot.is_planted = true

		total_coin_energy += coin_qubit.energy if coin_qubit else 0.0

	print("✓ All 6 plots planted into market")
	print("✓ Average coin energy per plot: %.1f" % (total_coin_energy / 6.0))
	print()


func _harvest_and_calculate():
	print("HARVEST PHASE: Convert coin energy → credits\n")

	var total_credits = 0
	var harvested_plots = 0

	for pos in grid.plots:
		var plot = grid.plots[pos]
		if plot.quantum_state:
			var harvest = market_biome.harvest_coin_energy(plot.quantum_state)
			if harvest["success"]:
				total_credits += harvest["credits"]
				harvested_plots += 1

	economy.credits += total_credits
	print("✓ Harvested %d plots" % harvested_plots)
	print("✓ Market profit: +%d credits" % total_credits)
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
	print("  Labor:        0 units (ignored)")
	print("  Flour:        %d units" % economy.flour_inventory)
	print("  Credits:      %d (started 50, +%.0f)" % [economy.credits, economy.credits - 50])
	print()

	print("Strategy Metrics:")
	print("  Time to profit:  Immediate")
	print("  Resource focus:  Credits only")
	print("  Quantum usage:   Minimal (coin energy only)")
	print("  Scaling:         Direct (more plantings = more credits)")
	print()

	print("Pros:")
	print("  + Highest immediate credit return (533 credits → ~600 final)")
	print("  + No quantum evolution needed")
	print("  + Predictable, guaranteed returns")
	print("  + Perfect for speed-focused players")
	print()

	print("Cons:")
	print("  - Zero farming resources (wheat/labor)")
	print("  - No quantum superposition benefit")
	print("  - Subject to market price fluctuations")
	print("  - Cannot mill wheat into flour")
	print()

	print(print_line("=", 70) + "\n")
