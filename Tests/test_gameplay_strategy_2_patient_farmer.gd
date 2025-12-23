#!/usr/bin/env -S godot --headless -s
extends SceneTree

## STRATEGY 2: PATIENT FARMER
## Focus: Maximize long-term resource accumulation
## Approach: Plant ALL plots into FarmingBiome for quantum evolution
## Risk: Delayed returns, quantum uncertainty, no immediate credits
##
## Outcome: Rich resource base (wheat+labor), potential for production chain

const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
const Biome = preload("res://Core/Environment/Biome.gd")
const MarketBiome = preload("res://Core/Environment/MarketBiome.gd")
const WheatPlot = preload("res://Core/GameMechanics/WheatPlot.gd")

var grid: FarmGrid
var economy: FarmEconomy
var biome: BioticFluxBiome
var market_biome: MarketBiome

var strategy_name: String = "PATIENT FARMER"
var strategy_desc: String = "Plant ALL into farming for quantum evolution + resources"

func _initialize():
	print("\n" + "=".repeat(70))
	print("🎮 GAMEPLAY STRATEGY 2: " + strategy_name)
	print(strategy_desc)
	print("=".repeat(70) + "\n")

	_setup_systems()
	_plant_all_farming()
	_simulate_quantum_evolution()
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


func _plant_all_farming():
	print("PLANTING PHASE: All plots → FarmingBiome\n")

	var plot_positions = grid.plots.keys()

	for i in range(plot_positions.size()):
		var pos = plot_positions[i]
		var plot = grid.plots[pos]

		# Standard planting input
		var wheat = 0.22
		var labor = 0.08

		var planting_qubit = biome.inject_planting(pos, wheat, labor, 0)
		plot.quantum_state = planting_qubit
		plot.is_planted = true

	print("✓ All 6 plots planted into farming biome")
	print("✓ Each plot: quantum superposition (25% wheat / 75% labor avg)")
	print()


func _simulate_quantum_evolution():
	print("EVOLUTION PHASE: Bloch sphere dynamics over time\n")

	# Simulate theta drift toward equilibrium (π/2 = balanced)
	var evolution_cycles = 5

	for cycle in range(evolution_cycles):
		print("  Cycle %d: Quantum evolution..." % (cycle + 1))

		var total_theta_change = 0.0
		for pos in grid.plots:
			var plot = grid.plots[pos]
			if plot.quantum_state:
				# Drift toward balanced superposition
				var current_theta = plot.quantum_state.theta
				var target_theta = PI / 2.0  # Balanced
				var drift = (target_theta - current_theta) * 0.1  # 10% toward target
				plot.quantum_state.theta += drift
				total_theta_change += abs(drift)

		var avg_theta_change = total_theta_change / 6.0
		print("    Average theta drift: %.3f rad" % avg_theta_change)

	print("\n✓ Quantum states evolved")
	print("✓ Plots have drifted toward balanced superposition")
	print()


func _harvest_and_calculate():
	print("HARVEST PHASE: Measure and collapse superpositions\n")

	var total_wheat = 0.0
	var total_labor = 0.0
	var harvested_plots = 0

	for pos in grid.plots:
		var plot = grid.plots[pos]
		if plot.quantum_state:
			var harvest = biome.harvest_quantum_planting(plot.quantum_state)
			if harvest["success"]:
				total_wheat += harvest["wheat"]
				total_labor += harvest["labor"]
				harvested_plots += 1

	economy.wheat_inventory += int(total_wheat)

	print("✓ Harvested %d plots" % harvested_plots)
	print("✓ Total wheat: %.2f units" % total_wheat)
	print("✓ Total labor: %.2f units" % total_labor)
	print()

	# Optional: Convert wheat to flour for additional value
	print("PRODUCTION CHAIN PHASE (Optional):\n")

	var wheat_to_mill = int(total_wheat)
	if wheat_to_mill > 0:
		var mill_result = economy.process_wheat_to_flour(wheat_to_mill)
		if mill_result["success"]:
			print("✓ Milled %d wheat → %d flour" % [mill_result["wheat_used"], mill_result["flour_produced"]])
			print("✓ Processing bonus: +%d credits" % mill_result["credits_earned"])
		else:
			print("⚠ Milling insufficient (need 10+ wheat)")

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
	print("  Labor:        ~0.5 units (from superposition)")
	print("  Flour:        %d units" % economy.flour_inventory)
	print("  Credits:      %d (started 50, +%d)" % [economy.credits, economy.credits - 50])
	print()

	print("Strategy Metrics:")
	print("  Time to profit:  60+ seconds (quantum evolution)")
	print("  Resource focus:  Wheat + Labor")
	print("  Quantum usage:   Full (superposition + measurement)")
	print("  Scaling:         Multiplicative (resources → production chain → more credits)")
	print()

	print("Pros:")
	print("  + Accumulates wheat for later conversion")
	print("  + Creates labor resources for labor-intensive plots")
	print("  + Quantum evolution provides strategy depth")
	print("  + Can trigger production chain (wheat → flour → credits)")
	print("  + Perfect for long-game players")
	print()

	print("Cons:")
	print("  - Requires 60+ seconds per cycle")
	print("  - Initial return is low (mostly resources, not credits)")
	print("  - Quantum uncertainty means variable yields")
	print("  - Requires additional time to convert wheat → credits")
	print()

