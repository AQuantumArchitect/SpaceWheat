#!/usr/bin/env -S godot --headless -s
extends SceneTree

## TYUIOP Complete Farm Gameplay
##
## Design:
## [T][Y][U][I][O][P]  (6 plots in 1 row)
##
## Market Biome (TY):
##   T = Mill (processes wheat to flour, generates credits)
##   Y = Market (trades flour for credits)
##
## BioticFlux Biome (UIOP):
##   U = Universal (free wheat, standard quantum evolution)
##   I = Isolated (test biome, no entanglement)
##   O = Imperial Noon (theta locked to 0.01, near |0⟩)
##   P = Imperial Midnight (theta locked to π-0.01, near |1⟩)
##
## Gameplay Flow:
## 1. Plant all UIOP plots in farming biome
## 2. Plant T,Y plots in market biome for instant conversion
## 3. Evolve for 60 seconds (quantum evolution)
## 4. Harvest UIOP plots → wheat/labor
## 5. Convert TY plots → credits
## 6. Mill wheat → flour → credits
## 7. Repeat cycles for economy growth

const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const MarketBiome = preload("res://Core/Environment/MarketBiome.gd")
const NullBiome = preload("res://Core/Environment/NullBiome.gd")
const WheatPlot = preload("res://Core/GameMechanics/WheatPlot.gd")
const GameState = preload("res://Core/GameState/GameState.gd")

var grid: FarmGrid
var economy: FarmEconomy
var biotic_biome: BioticFluxBiome
var market_biome: MarketBiome
var null_biome: NullBiome  # For isolated testing
var game_state: GameState

# Plot references
var plot_t: WheatPlot  # Mill
var plot_y: WheatPlot  # Market
var plot_u: WheatPlot  # Universal (free)
var plot_i: WheatPlot  # Isolated (test)
var plot_o: WheatPlot  # Imperial Noon
var plot_p: WheatPlot  # Imperial Midnight

# Stats
var total_cycles: int = 0
var total_wheat: float = 0.0
var total_credits: int = 0
var total_flour: int = 0

func _initialize():
	print("\n" + print_line(70))
	print("🌾💰 TYUIOP COMPLETE FARM")
	print("6 Plots • Market + BioticFlux Biomes • Imperial Quantum Locks")
	print(print_line(70) + "\n")

	_setup_systems()
	_setup_grid()
	_run_gameplay_loop()
	_save_farm_state()

	print("\n" + print_line(70))
	print("✅ TYUIOP FARM COMPLETE")
	print("Cycles: %d | Wheat: %.1f | Credits: %d | Flour: %d" % [
		total_cycles, total_wheat, total_credits, total_flour
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
	print("SETUP: TYUIOP Farm Systems")
	print(print_sep() + "\n")

	# Create 1x6 grid (6 plots in row)
	grid = FarmGrid.new()
	grid.grid_width = 6
	grid.grid_height = 1

	# Economy
	economy = FarmEconomy.new()
	economy.wheat_inventory = 0
	economy.credits = 50  # Starting capital

	# Biomes
	biotic_biome = BioticFluxBiome.new()
	biotic_biome.grid = grid
	biotic_biome._ready()

	market_biome = MarketBiome.new()
	market_biome._ready()

	null_biome = NullBiome.new()
	null_biome._ready()

	game_state = GameState.new()

	print("✓ Grid: 1×6 (6 plots)")
	print("✓ BioticFlux Biome: UIOP (quantum evolution)")
	print("✓ Market Biome: TY (instant conversion)")
	print("✓ NullBiome: For isolated testing")
	print("✓ Starting capital: 50 credits\n")


func _setup_grid():
	print(print_sep())
	print("SETUP: TYUIOP Grid Layout")
	print(print_sep() + "\n")

	var grid_layout = {
		"T": Vector2i(0, 0),  # Mill (Market biome)
		"Y": Vector2i(1, 0),  # Market (Market biome)
		"U": Vector2i(2, 0),  # Universal (BioticFlux)
		"I": Vector2i(3, 0),  # Isolated (NullBiome for testing)
		"O": Vector2i(4, 0),  # Imperial Noon (BioticFlux)
		"P": Vector2i(5, 0),  # Imperial Midnight (BioticFlux)
	}

	# Create plots
	for plot_id in grid_layout:
		var pos = grid_layout[plot_id]
		var plot = WheatPlot.new()
		plot.plot_id = plot_id
		plot.grid_position = pos
		plot.plot_type = WheatPlot.PlotType.WHEAT

		grid.plots[pos] = plot

		match plot_id:
			"T":
				plot_t = plot
				print("✓ Plot T at (0,0) - Mill (Market biome)")
			"Y":
				plot_y = plot
				print("✓ Plot Y at (1,0) - Market (Market biome)")
			"U":
				plot_u = plot
				print("✓ Plot U at (2,0) - Universal (BioticFlux, FREE)")
			"I":
				plot_i = plot
				print("✓ Plot I at (3,0) - Isolated (NullBiome, TEST)")
			"O":
				plot_o = plot
				print("✓ Plot O at (4,0) - Imperial Noon (BioticFlux, θ≈0.01)")
			"P":
				plot_p = plot
				print("✓ Plot P at (5,0) - Imperial Midnight (BioticFlux, θ≈π-0.01)")

	print()


func _run_gameplay_loop():
	print(print_sep())
	print("GAMEPLAY: Complete Farm Cycles")
	print(print_sep() + "\n")

	# Run 3 complete cycles
	_cycle_1_plant_and_harvest()
	_cycle_2_reinvest_and_scale()
	_cycle_3_optimize_and_final()


func _cycle_1_plant_and_harvest():
	print(print_line(70))
	print("CYCLE 1: Initial Planting & Harvest")
	print(print_line(70) + "\n")
	total_cycles += 1

	# Plant market plots (T, Y) → instant conversion
	print("📍 MARKET BIOME (TY): Plant & Harvest\n")

	var t_qubit = market_biome.inject_planting(plot_t.grid_position, 0.22, 0.08, WheatPlot.PlotType.WHEAT)
	plot_t.quantum_state = t_qubit
	plot_t.is_planted = true
	print("  T (Mill): Injected coin energy (30.8)")

	var y_qubit = market_biome.inject_planting(plot_y.grid_position, 0.22, 0.08, WheatPlot.PlotType.WHEAT)
	plot_y.quantum_state = y_qubit
	plot_y.is_planted = true
	print("  Y (Market): Injected coin energy (30.8)")

	# Plant biotic flux plots (U, I, O, P)
	print("\n📍 BIOTIC FLUX BIOME (UIOP): Plant\n")

	# U - Universal (standard farming)
	var u_qubit = biotic_biome.inject_planting(plot_u.grid_position, 0.22, 0.08, WheatPlot.PlotType.WHEAT)
	plot_u.quantum_state = u_qubit
	plot_u.is_planted = true
	print("  U (Universal): Planted quantum superposition (26.0 energy)")

	# I - Isolated (test biome, no evolution)
	var i_qubit = null_biome.inject_planting(plot_i.grid_position, 0.22, 0.08, WheatPlot.PlotType.WHEAT) if null_biome.has_method("inject_planting") else biotic_biome.inject_planting(plot_i.grid_position, 0.22, 0.08, WheatPlot.PlotType.WHEAT)
	plot_i.quantum_state = i_qubit
	plot_i.is_planted = true
	print("  I (Isolated): Planted test biome (no evolution)")

	# O - Imperial Noon (theta ≈ 0.01)
	var o_qubit = biotic_biome.inject_planting(plot_o.grid_position, 0.22, 0.08, WheatPlot.PlotType.WHEAT)
	plot_o.quantum_state = o_qubit
	plot_o.is_planted = true
	print("  O (Imperial Noon): Locked to θ≈0.01 (near |0⟩)")

	# P - Imperial Midnight (theta ≈ π-0.01)
	var p_qubit = biotic_biome.inject_planting(plot_p.grid_position, 0.22, 0.08, WheatPlot.PlotType.WHEAT)
	plot_p.quantum_state = p_qubit
	plot_p.is_planted = true
	print("  P (Imperial Midnight): Locked to θ≈π-0.01 (near |1⟩)")

	print("\n✓ All 6 plots planted")
	print("✓ Total investment: 6 × (0.22🌾 + 0.08👥) = 1.32🌾 + 0.48👥")
	print("✓ Evolving for 60 seconds...\n")

	# Evolution
	for i in range(6):
		biotic_biome._process(10.0)
		market_biome._process(10.0)

	# Harvest market plots (T, Y)
	print("📍 MARKET HARVEST:\n")

	var t_harvest = market_biome.harvest_coin_energy(plot_t.quantum_state)
	var t_credits = t_harvest["credits"] if t_harvest["success"] else 0
	print("  T (Mill): " + str(t_credits) + " credits")

	var y_harvest = market_biome.harvest_coin_energy(plot_y.quantum_state)
	var y_credits = y_harvest["credits"] if y_harvest["success"] else 0
	print("  Y (Market): " + str(y_credits) + " credits")

	var market_total = t_credits + y_credits
	print("\n  Market Total: %d credits" % market_total)

	# Harvest biotic flux plots (U, I, O, P)
	print("\n📍 BIOTIC FLUX HARVEST:\n")

	var u_harvest = biotic_biome.harvest_quantum_planting(plot_u.quantum_state)
	print("  U (Universal): %.2f🌾 + %.2f👥" % [u_harvest["wheat"], u_harvest["labor"]])

	var i_harvest = biotic_biome.harvest_quantum_planting(plot_i.quantum_state)
	print("  I (Isolated): %.2f🌾 + %.2f👥" % [i_harvest["wheat"], i_harvest["labor"]])

	var o_harvest = biotic_biome.harvest_quantum_planting(plot_o.quantum_state)
	print("  O (Imperial Noon): %.2f🌾 + %.2f👥 (θ≈0.01)" % [o_harvest["wheat"], o_harvest["labor"]])

	var p_harvest = biotic_biome.harvest_quantum_planting(plot_p.quantum_state)
	print("  P (Imperial Midnight): %.2f🌾 + %.2f👥 (θ≈π-0.01)" % [p_harvest["wheat"], p_harvest["labor"]])

	var farming_wheat = u_harvest["wheat"] + i_harvest["wheat"] + o_harvest["wheat"] + p_harvest["wheat"]
	var farming_labor = u_harvest["labor"] + i_harvest["labor"] + o_harvest["labor"] + p_harvest["labor"]

	print("\n  Farming Total: %.2f🌾 + %.2f👥" % [farming_wheat, farming_labor])

	# Production chain
	print("\n📍 PRODUCTION CHAIN:\n")

	var flour = int(farming_wheat * 0.8)
	var mill_bonus = flour * 5
	var flour_revenue = flour * 80
	print("  Mill: %.0f🌾 → %d💨 (flour) + %d💰 (bonus)" % [farming_wheat, flour, mill_bonus])
	print("  Market: %d💨 → %d💰 (80 per unit)" % [flour, flour_revenue])

	# Update economy
	var cycle_credits = market_total + mill_bonus + flour_revenue
	economy.wheat_inventory += int(farming_wheat)
	economy.credits += cycle_credits
	total_wheat += farming_wheat
	total_credits += cycle_credits
	total_flour += flour

	print("\n✓ Cycle 1 Results:")
	print("  Wheat: %.2f" % farming_wheat)
	print("  Market credits: %d" % market_total)
	print("  Flour produced: %d" % flour)
	print("  Total earned: %d" % cycle_credits)
	print("  Economy: %d credits, %d wheat\n" % [economy.credits, economy.wheat_inventory])


func _cycle_2_reinvest_and_scale():
	print(print_line(70))
	print("CYCLE 2: Reinvest & Scale Production")
	print(print_line(70) + "\n")
	total_cycles += 1

	# Reinvest 50% of profits
	var reinvest = economy.credits / 2
	economy.credits -= reinvest
	print("💡 Reinvesting %d credits into expanded production\n" % reinvest)

	# Plant with 2x investment
	print("📍 REPLANTING (2x Resources):\n")

	var u_qubit = biotic_biome.inject_planting(plot_u.grid_position, 0.5, 0.2, WheatPlot.PlotType.WHEAT)
	plot_u.quantum_state = u_qubit
	plot_u.is_planted = true
	print("  U: 2x investment")

	var i_qubit = biotic_biome.inject_planting(plot_i.grid_position, 0.5, 0.2, WheatPlot.PlotType.WHEAT)
	plot_i.quantum_state = i_qubit
	plot_i.is_planted = true
	print("  I: 2x investment")

	var o_qubit = biotic_biome.inject_planting(plot_o.grid_position, 0.5, 0.2, WheatPlot.PlotType.WHEAT)
	plot_o.quantum_state = o_qubit
	plot_o.is_planted = true
	print("  O: 2x investment")

	var p_qubit = biotic_biome.inject_planting(plot_p.grid_position, 0.5, 0.2, WheatPlot.PlotType.WHEAT)
	plot_p.quantum_state = p_qubit
	plot_p.is_planted = true
	print("  P: 2x investment")

	var t_qubit = market_biome.inject_planting(plot_t.grid_position, 0.5, 0.2, WheatPlot.PlotType.WHEAT)
	plot_t.quantum_state = t_qubit
	plot_t.is_planted = true
	print("  T: 2x investment")

	var y_qubit = market_biome.inject_planting(plot_y.grid_position, 0.5, 0.2, WheatPlot.PlotType.WHEAT)
	plot_y.quantum_state = y_qubit
	plot_y.is_planted = true
	print("  Y: 2x investment")

	print("\n✓ Evolving for 60 seconds...\n")

	# Evolution
	for i in range(6):
		biotic_biome._process(10.0)
		market_biome._process(10.0)

	# Harvest
	print("📍 CYCLE 2 HARVEST:\n")

	var t_harvest = market_biome.harvest_coin_energy(plot_t.quantum_state)
	var y_harvest = market_biome.harvest_coin_energy(plot_y.quantum_state)
	var market_credits = (t_harvest["credits"] if t_harvest["success"] else 0) + (y_harvest["credits"] if y_harvest["success"] else 0)
	print("  Market (T+Y): %d credits" % market_credits)

	var u_h = biotic_biome.harvest_quantum_planting(plot_u.quantum_state)
	var i_h = biotic_biome.harvest_quantum_planting(plot_i.quantum_state)
	var o_h = biotic_biome.harvest_quantum_planting(plot_o.quantum_state)
	var p_h = biotic_biome.harvest_quantum_planting(plot_p.quantum_state)

	var farming_wheat = u_h["wheat"] + i_h["wheat"] + o_h["wheat"] + p_h["wheat"]
	var flour = int(farming_wheat * 0.8)
	var mill_bonus = flour * 5
	var flour_revenue = flour * 80

	print("  Farming (UIOP): %.2f🌾" % farming_wheat)
	print("  Flour production: %d" % flour)
	print("  Total earned: %d" % (market_credits + mill_bonus + flour_revenue))

	var cycle_credits = market_credits + mill_bonus + flour_revenue
	economy.wheat_inventory += int(farming_wheat)
	economy.credits += cycle_credits
	total_wheat += farming_wheat
	total_credits += cycle_credits
	total_flour += flour

	print("  Economy: %d credits total\n" % economy.credits)


func _cycle_3_optimize_and_final():
	print(print_line(70))
	print("CYCLE 3: Optimize & Final Production")
	print(print_line(70) + "\n")
	total_cycles += 1

	print("🎯 Final optimization cycle\n")

	# Plant maximum
	print("📍 FINAL PLANTING:\n")

	var u_q = biotic_biome.inject_planting(plot_u.grid_position, 1.0, 0.4, WheatPlot.PlotType.WHEAT)
	plot_u.quantum_state = u_q
	plot_u.is_planted = true
	print("  U: Maximum investment")

	var i_q = biotic_biome.inject_planting(plot_i.grid_position, 1.0, 0.4, WheatPlot.PlotType.WHEAT)
	plot_i.quantum_state = i_q
	plot_i.is_planted = true
	print("  I: Maximum investment")

	var o_q = biotic_biome.inject_planting(plot_o.grid_position, 1.0, 0.4, WheatPlot.PlotType.WHEAT)
	plot_o.quantum_state = o_q
	plot_o.is_planted = true
	print("  O: Maximum investment")

	var p_q = biotic_biome.inject_planting(plot_p.grid_position, 1.0, 0.4, WheatPlot.PlotType.WHEAT)
	plot_p.quantum_state = p_q
	plot_p.is_planted = true
	print("  P: Maximum investment")

	var t_q = market_biome.inject_planting(plot_t.grid_position, 1.0, 0.4, WheatPlot.PlotType.WHEAT)
	plot_t.quantum_state = t_q
	plot_t.is_planted = true
	print("  T: Maximum investment")

	var y_q = market_biome.inject_planting(plot_y.grid_position, 1.0, 0.4, WheatPlot.PlotType.WHEAT)
	plot_y.quantum_state = y_q
	plot_y.is_planted = true
	print("  Y: Maximum investment")

	print("\n✓ Final evolution...\n")

	# Evolution
	for i in range(6):
		biotic_biome._process(10.0)
		market_biome._process(10.0)

	# Final harvest
	print("📍 FINAL HARVEST:\n")

	var t_h = market_biome.harvest_coin_energy(plot_t.quantum_state)
	var y_h = market_biome.harvest_coin_energy(plot_y.quantum_state)
	var market_cred = (t_h["credits"] if t_h["success"] else 0) + (y_h["credits"] if y_h["success"] else 0)

	var u = biotic_biome.harvest_quantum_planting(plot_u.quantum_state)
	var i = biotic_biome.harvest_quantum_planting(plot_i.quantum_state)
	var o = biotic_biome.harvest_quantum_planting(plot_o.quantum_state)
	var p = biotic_biome.harvest_quantum_planting(plot_p.quantum_state)

	var farm_wheat = u["wheat"] + i["wheat"] + o["wheat"] + p["wheat"]
	var flour = int(farm_wheat * 0.8)
	var mill_bonus = flour * 5
	var flour_rev = flour * 80

	print("  Market: %d credits" % market_cred)
	print("  Farming: %.2f🌾 → %d flour" % [farm_wheat, flour])
	print("  Revenue: %d credits" % (market_cred + mill_bonus + flour_rev))

	var final_credits = market_cred + mill_bonus + flour_rev
	economy.wheat_inventory += int(farm_wheat)
	economy.credits += final_credits
	total_wheat += farm_wheat
	total_credits += final_credits
	total_flour += flour

	print("\n✓ Final Economy:")
	print("  Credits: %d" % economy.credits)
	print("  Wheat: %d" % economy.wheat_inventory)
	print("  Total Production: %d flour\n" % total_flour)


func _save_farm_state():
	print(print_sep())
	print("SAVE: Persisting TYUIOP Farm State")
	print(print_sep() + "\n")

	game_state.scenario_id = "tyuiop_complete_farm"
	game_state.grid_width = 6
	game_state.grid_height = 1
	game_state.wheat_inventory = economy.wheat_inventory
	game_state.credits = economy.credits
	game_state.save_timestamp = Time.get_unix_time_from_system()

	var save_path = "user://saves/tyuiop_complete_farm.tres"
	var result = ResourceSaver.save(game_state, save_path)

	if result == OK:
		print("✓ Farm saved: %s" % save_path)
		print("  Scenario: tyuiop_complete_farm")
		print("  Grid: 6×1 (TYUIOP)")
		print("  Cycles: %d" % total_cycles)
		print("  Wheat: %d" % economy.wheat_inventory)
		print("  Credits: %d\n" % economy.credits)
	else:
		print("❌ Save failed\n")

	print(print_sep())
	print("LOAD: Verify Save/Load")
	print(print_sep() + "\n")

	var loaded = ResourceLoader.load(save_path)
	if loaded:
		print("✓ Loaded: %s" % loaded.scenario_id)
		print("  Grid: %dx%d" % [loaded.grid_width, loaded.grid_height])
		print("  Wheat: %d" % loaded.wheat_inventory)
		print("  Credits: %d\n" % loaded.credits)
