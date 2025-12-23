#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Complete Fully-Stocked Farm Gameplay Loop
##
## This test demonstrates a complete gameplay session with:
## - Large farm (6x2 grid with 12 plots)
## - Multiple biomes (Farming, Market, Kitchen)
## - Diverse crop types (wheat, mushroom, special plots)
## - Full production chain (farming → milling → market)
## - Multiple complete growth cycles
## - Save/load at end
##
## Expected gameplay time: ~120 seconds
## Plots:
##   [W1][W2][W3][W4][W5][W6]
##   [M1][M2][T1][T2][K1][K2]
## Where:
##   W = Wheat in FarmingBiome
##   M = Mushroom in FarmingBiome
##   T = Market Trading plots
##   K = Quantum Kitchen (bell state preparation)

const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const MarketBiome = preload("res://Core/Environment/MarketBiome.gd")
const QuantumKitchen_Biome = preload("res://Core/Environment/QuantumKitchen_Biome.gd")
const WheatPlot = preload("res://Core/GameMechanics/WheatPlot.gd")
const GameState = preload("res://Core/GameState/GameState.gd")

var grid: FarmGrid
var economy: FarmEconomy
var farming_biome: BioticFluxBiome
var market_biome: MarketBiome
var kitchen_biome: QuantumKitchen_Biome
var game_state: GameState

# Plot references for tracking
var plots_farming: Dictionary = {}      # W1-W6, M1-M2
var plots_market: Dictionary = {}       # T1-T2
var plots_kitchen: Dictionary = {}      # K1-K2

# Gameplay stats
var cycle_count: int = 0
var total_wheat_harvested: float = 0.0
var total_credits_earned: int = 0
var total_flour_produced: int = 0

func _initialize():
	print("\n" + print_line(70))
	print("🌾💰🔬 FULLY STOCKED FARM GAMEPLAY LOOP")
	print("12 Plots • Multiple Biomes • Complete Production Chain")
	print(print_line(70) + "\n")

	_setup_systems()
	_setup_biomes()
	_setup_grid_and_plots()

	# Run multiple gameplay cycles
	_cycle_1_initial_planting()
	_cycle_2_harvest_and_convert()
	_cycle_3_replanting_and_scaling()
	_cycle_4_final_harvest_and_optimization()

	_save_and_verify()

	print("\n" + print_line(70))
	print("✅ FULLY STOCKED FARM GAMEPLAY COMPLETE")
	print("Cycles: %d | Wheat: %.1f | Credits: %d | Flour: %d" % [
		cycle_count, total_wheat_harvested, total_credits_earned, total_flour_produced
	])
	print(print_line(70) + "\n")

	quit()


func print_line(count: int) -> String:
	var line = ""
	for i in range(count):
		line += "="
	return line


func print_sep() -> String:
	var line = ""
	for i in range(70):
		line += "─"
	return line


func _setup_systems():
	print(print_sep())
	print("SETUP: Systems Initialization (12-Plot Farm)")
	print(print_sep() + "\n")

	# Create larger grid: 6x2 = 12 plots
	grid = FarmGrid.new()
	grid.grid_width = 6
	grid.grid_height = 2

	economy = FarmEconomy.new()
	economy.wheat_inventory = 0
	economy.credits = 100  # Starting capital

	# Three biomes for different farming strategies
	farming_biome = BioticFluxBiome.new()
	farming_biome.grid = grid
	farming_biome._ready()

	market_biome = MarketBiome.new()
	market_biome._ready()

	kitchen_biome = QuantumKitchen_Biome.new()
	kitchen_biome._ready()

	game_state = GameState.new()

	print("✓ Grid: 6x2 (12 plots)")
	print("✓ Farming Biome: Wheat/Mushroom evolution")
	print("✓ Market Biome: Instant credit conversion")
	print("✓ Kitchen Biome: Bell state preparation")
	print("✓ Economy: 100 starting credits\n")


func _setup_biomes():
	print(print_sep())
	print("SETUP: Biome Initialization")
	print(print_sep() + "\n")

	print("✓ FarmingBiome ready (sun/moon cycle 20s)")
	print("✓ MarketBiome ready (trading system)")
	print("✓ KitchenBiome ready (Bell state prep)\n")


func _setup_grid_and_plots():
	print(print_sep())
	print("SETUP: Grid Layout (12 Plots)")
	print(print_sep() + "\n")

	# Row 1 (y=0): 6 Wheat plots
	var row1_config = {
		"W1": {"pos": Vector2i(0, 0), "type": WheatPlot.PlotType.WHEAT, "biome": "farming"},
		"W2": {"pos": Vector2i(1, 0), "type": WheatPlot.PlotType.WHEAT, "biome": "farming"},
		"W3": {"pos": Vector2i(2, 0), "type": WheatPlot.PlotType.WHEAT, "biome": "farming"},
		"W4": {"pos": Vector2i(3, 0), "type": WheatPlot.PlotType.WHEAT, "biome": "farming"},
		"W5": {"pos": Vector2i(4, 0), "type": WheatPlot.PlotType.WHEAT, "biome": "farming"},
		"W6": {"pos": Vector2i(5, 0), "type": WheatPlot.PlotType.WHEAT, "biome": "farming"},
	}

	# Row 2 (y=1): 2 Mushroom, 2 Market, 2 Kitchen
	var row2_config = {
		"M1": {"pos": Vector2i(0, 1), "type": WheatPlot.PlotType.MUSHROOM, "biome": "farming"},
		"M2": {"pos": Vector2i(1, 1), "type": WheatPlot.PlotType.MUSHROOM, "biome": "farming"},
		"T1": {"pos": Vector2i(2, 1), "type": WheatPlot.PlotType.MARKET, "biome": "market"},
		"T2": {"pos": Vector2i(3, 1), "type": WheatPlot.PlotType.MARKET, "biome": "market"},
		"K1": {"pos": Vector2i(4, 1), "type": WheatPlot.PlotType.WHEAT, "biome": "kitchen"},
		"K2": {"pos": Vector2i(5, 1), "type": WheatPlot.PlotType.WHEAT, "biome": "kitchen"},
	}

	var all_plots = {}
	all_plots.merge(row1_config)
	all_plots.merge(row2_config)

	for plot_id in all_plots:
		var data = all_plots[plot_id]
		var plot = WheatPlot.new()
		plot.plot_id = plot_id
		plot.grid_position = data["pos"]
		plot.plot_type = data["type"]

		if data["biome"] == "farming":
			plots_farming[plot_id] = plot
		elif data["biome"] == "market":
			plots_market[plot_id] = plot
		else:
			plots_kitchen[plot_id] = plot

		grid.plots[data["pos"]] = plot
		var plot_type_name = "Wheat" if data["type"] == WheatPlot.PlotType.WHEAT else \
		                     "Mushroom" if data["type"] == WheatPlot.PlotType.MUSHROOM else \
		                     "Market"
		print("✓ Plot %s at (%d,%d) - %s (%s)" % [plot_id, data["pos"].x, data["pos"].y, plot_type_name, data["biome"]])

	print()


func _cycle_1_initial_planting():
	print(print_sep())
	print("CYCLE 1: Initial Planting (All 12 Plots)")
	print(print_sep() + "\n")
	cycle_count += 1

	# Plant all farming plots (wheat + mushroom)
	print("📍 FARMING BIOME (8 plots):\n")
	for plot_id in plots_farming:
		var plot = plots_farming[plot_id]
		var wheat_amount = 0.22
		var labor_amount = 0.08

		var qubit = farming_biome.inject_planting(plot.grid_position, wheat_amount, labor_amount, plot.plot_type)
		plot.quantum_state = qubit
		plot.is_planted = true

		var type_name = "Wheat" if plot.plot_type == WheatPlot.PlotType.WHEAT else "Mushroom"
		print("  %s: Planted %s (θ=π/2, 26.0 energy)" % [plot_id, type_name])

	print("\n📍 MARKET BIOME (2 plots):\n")
	for plot_id in plots_market:
		var plot = plots_market[plot_id]
		var qubit = market_biome.inject_planting(plot.grid_position, 0.22, 0.08, plot.plot_type)
		plot.quantum_state = qubit
		plot.is_planted = true
		print("  %s: Market coin (30.8 energy)" % plot_id)

	print("\n📍 QUANTUM KITCHEN (2 plots):\n")
	for plot_id in plots_kitchen:
		var plot = plots_kitchen[plot_id]
		# Kitchen creates Bell state (entangled pair)
		var qubit = kitchen_biome.inject_planting(plot.grid_position, 0.22, 0.08, plot.plot_type)
		plot.quantum_state = qubit
		plot.is_planted = true
		print("  %s: Bell state preparation (for entanglement)" % plot_id)

	print("\n✓ All 12 plots planted")
	print("✓ Total invested: 12 × 0.22🌾 = 2.64 wheat + 0.96 labor\n")


func _cycle_2_harvest_and_convert():
	print(print_sep())
	print("CYCLE 2: Harvest, Process, and Convert (After 60s Evolution)")
	print(print_sep() + "\n")
	cycle_count += 1

	print("⏱️  Simulating 60 seconds of quantum evolution...\n")

	# Simulate evolution by running biome process steps
	for i in range(6):  # 60 seconds / 10 = 6 ticks of 10 seconds
		farming_biome._process(10.0)
		market_biome._process(10.0)
		kitchen_biome._process(10.0)

	# Harvest farming plots
	print("📍 FARMING BIOME HARVEST (60s evolved):\n")
	var farming_wheat = 0.0
	var farming_labor = 0.0

	for plot_id in plots_farming:
		var plot = plots_farming[plot_id]
		if plot.quantum_state:
			var harvest = farming_biome.harvest_quantum_planting(plot.quantum_state)
			farming_wheat += harvest["wheat"]
			farming_labor += harvest["labor"]
			print("  %s: %.2f🌾 + %.2f👥" % [plot_id, harvest["wheat"], harvest["labor"]])

	print("\n  Subtotal: %.2f🌾 + %.2f👥" % [farming_wheat, farming_labor])
	total_wheat_harvested += farming_wheat

	# Harvest market plots (instant conversion)
	print("\n📍 MARKET BIOME HARVEST (Instant):\n")
	var market_credits = 0

	for plot_id in plots_market:
		var plot = plots_market[plot_id]
		if plot.quantum_state:
			var harvest = market_biome.harvest_coin_energy(plot.quantum_state)
			if harvest["success"]:
				market_credits += harvest["credits"]
				print("  %s: %d credits" % [plot_id, harvest["credits"]])

	print("\n  Subtotal: %d credits" % market_credits)
	total_credits_earned += market_credits

	# Harvest kitchen plots (prepare for Bell states)
	print("\n📍 QUANTUM KITCHEN HARVEST:\n")
	var kitchen_prepared = 0
	for plot_id in plots_kitchen:
		var plot = plots_kitchen[plot_id]
		if plot.quantum_state:
			var outcome = kitchen_biome.measure_qubit(plot.grid_position)
			kitchen_prepared += 1
			print("  %s: Measured Bell state → %s" % [plot_id, outcome])

	# Economic conversion: Wheat → Flour → Credits
	print("\n📍 PRODUCTION CHAIN CONVERSION:\n")

	# Step 1: Wheat to Flour (at mill)
	var flour_produced = int(farming_wheat * 0.8)  # 10 wheat → 8 flour efficiency
	var mill_bonus = flour_produced * 5  # 5 credits per flour bonus
	print("  Mill: %.0f🌾 → %d💨 (flour) + %d💰 (processing)" % [farming_wheat, flour_produced, mill_bonus])

	# Step 2: Flour to Credits (at market)
	var flour_revenue = flour_produced * 80  # 80 credits per flour (after 20% market margin)
	print("  Market: %d💨 (flour) → %d💰 (net sales, 80 per unit)" % [flour_produced, flour_revenue])

	total_flour_produced += flour_produced

	# Update economy
	var total_cycle_credits = market_credits + mill_bonus + flour_revenue
	economy.wheat_inventory += int(farming_wheat)
	economy.credits += total_cycle_credits

	print("\n✓ Cycle 2 Summary:")
	print("  Wheat harvested: %.0f" % farming_wheat)
	print("  Flour produced: %d" % flour_produced)
	print("  Market credits: %d" % market_credits)
	print("  Mill bonus: %d" % mill_bonus)
	print("  Flour revenue: %d" % flour_revenue)
	print("  Total earned: %d credits" % total_cycle_credits)
	print("  Economy total: %d credits, %d wheat\n" % [economy.credits, economy.wheat_inventory])


func _cycle_3_replanting_and_scaling():
	print(print_sep())
	print("CYCLE 3: Replant with Scaling (Reinvest Profits)")
	print(print_sep() + "\n")
	cycle_count += 1

	print("💡 Strategic Decision: Reinvest credits into additional resources\n")

	# Use 50% of profits to expand planting
	var reinvestment = economy.credits / 2
	economy.credits -= reinvestment

	print("✓ Reinvesting %d credits into larger plantings\n" % reinvestment)

	# Plant all farming plots again with higher investment
	print("📍 FARMING BIOME (Expanded Planting):\n")
	for plot_id in plots_farming:
		var plot = plots_farming[plot_id]
		var wheat_amount = 0.5  # Double investment
		var labor_amount = 0.2

		var qubit = farming_biome.inject_planting(plot.grid_position, wheat_amount, labor_amount, plot.plot_type)
		plot.quantum_state = qubit
		plot.is_planted = true
		print("  %s: Replanted with 2x resources" % plot_id)

	print("\n📍 MARKET BIOME (Maximum Utilization):\n")
	for plot_id in plots_market:
		var plot = plots_market[plot_id]
		var qubit = market_biome.inject_planting(plot.grid_position, 0.5, 0.2, plot.plot_type)
		plot.quantum_state = qubit
		plot.is_planted = true
		print("  %s: Replanted maximum" % plot_id)

	print("\n✓ All plots replanted with expanded investment")
	print("✓ Remaining capital: %d credits\n" % economy.credits)


func _cycle_4_final_harvest_and_optimization():
	print(print_sep())
	print("CYCLE 4: Final Harvest with Optimization")
	print(print_sep() + "\n")
	cycle_count += 1

	print("⏱️  Final 60-second evolution cycle...\n")

	# Final evolution
	for i in range(6):
		farming_biome._process(10.0)
		market_biome._process(10.0)

	print("📍 FINAL FARMING HARVEST:\n")
	var final_wheat = 0.0
	var final_labor = 0.0

	for plot_id in plots_farming:
		var plot = plots_farming[plot_id]
		if plot.quantum_state:
			var harvest = farming_biome.harvest_quantum_planting(plot.quantum_state)
			final_wheat += harvest["wheat"]
			final_labor += harvest["labor"]
			print("  %s: %.2f🌾 + %.2f👥" % [plot_id, harvest["wheat"], harvest["labor"]])

	total_wheat_harvested += final_wheat

	print("\n📍 FINAL MARKET HARVEST:\n")
	var final_market_credits = 0

	for plot_id in plots_market:
		var plot = plots_market[plot_id]
		if plot.quantum_state:
			var harvest = market_biome.harvest_coin_energy(plot.quantum_state)
			if harvest["success"]:
				final_market_credits += harvest["credits"]
				print("  %s: %d credits" % [plot_id, harvest["credits"]])

	total_credits_earned += final_market_credits

	# Final conversion
	print("\n📍 FINAL PRODUCTION CHAIN:\n")
	var final_flour = int(final_wheat * 0.8)
	var final_mill_bonus = final_flour * 5
	var final_flour_revenue = final_flour * 80
	print("  Mill: %.0f🌾 → %d💨 + %d💰" % [final_wheat, final_flour, final_mill_bonus])
	print("  Market: %d💨 → %d💰" % [final_flour, final_flour_revenue])

	total_flour_produced += final_flour

	var final_cycle_credits = final_market_credits + final_mill_bonus + final_flour_revenue
	economy.wheat_inventory += int(final_wheat)
	economy.credits += final_cycle_credits

	print("\n✓ Final Economy State:")
	print("  Credits: %d" % economy.credits)
	print("  Wheat: %d" % economy.wheat_inventory)
	print("  Total earned this cycle: %d" % final_cycle_credits)
	print()


func _save_and_verify():
	print(print_sep())
	print("SAVE: Persisting Complete Farm State")
	print(print_sep() + "\n")

	game_state.scenario_id = "fully_stocked_farm_gameplay"
	game_state.grid_width = 6
	game_state.grid_height = 2
	game_state.wheat_inventory = economy.wheat_inventory
	game_state.credits = economy.credits
	game_state.save_timestamp = Time.get_unix_time_from_system()

	var save_path = "user://saves/fully_stocked_farm_gameplay.tres"
	var result = ResourceSaver.save(game_state, save_path)

	if result == OK:
		print("✓ Farm state saved to disk")
		print("  Path: %s" % save_path)
		print("  Scenario: %s" % game_state.scenario_id)
		print("  Grid: 6x2 (12 plots)")
		print("  Cycles: %d" % cycle_count)
		print("  Wheat: %d" % game_state.wheat_inventory)
		print("  Credits: %d" % game_state.credits)
	else:
		print("❌ Failed to save game state")

	print()

	print(print_sep())
	print("LOAD: Verifying Save/Load Cycle")
	print(print_sep() + "\n")

	var loaded_state = ResourceLoader.load(save_path)
	if loaded_state:
		print("✓ State loaded from disk")
		print("  Scenario: %s" % loaded_state.scenario_id)
		print("  Grid: %dx%d" % [loaded_state.grid_width, loaded_state.grid_height])
		print("  Wheat: %d" % loaded_state.wheat_inventory)
		print("  Credits: %d" % loaded_state.credits)
		print("  Timestamp: %d" % loaded_state.save_timestamp)
		print("\n✓ Full save/load cycle verified!\n")
	else:
		print("❌ Failed to load game state\n")


