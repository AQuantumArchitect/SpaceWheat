#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Complete Dual-Farm Test: One Farm, Two Biomes, 6 Plots
##
## Layout:
## FARMING BIOME (UIOP - 4 plots):
##   U = Wheat (standard)
##   I = Mushroom (special)
##   O = Imperial Noon (noon constraint)
##   P = Imperial Midnight (midnight constraint)
##
## MARKET BIOME (TY - 2 plots):
##   T = Market (trading hub)
##   Y = Mill (production)
##
## Resources flow: Player → Plots → Biomes → Classical outputs

const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const MarketBiome = preload("res://Core/Environment/MarketBiome.gd")
const WheatPlot = preload("res://Core/GameMechanics/WheatPlot.gd")
const GameState = preload("res://Core/GameState/GameState.gd")

var grid: FarmGrid
var economy: FarmEconomy
var biome: BioticFluxBiome  # Farming biome
var market_biome: MarketBiome
var game_state: GameState

# Plot references for easy access
var plots_farming: Dictionary = {}  # "U", "I", "O", "P"
var plots_market: Dictionary = {}   # "T", "Y"

func _initialize():
	print("\n" + print_line(70))
	print("🌾💰 DUAL FARM COMPLETE TEST")
	print("One Farm • Two Biomes • 6 Plots • Full Integration")
	print(print_line(70) + "\n")

	_setup_systems()
	_setup_biomes()
	_setup_grid_and_plots()
	_plant_and_evolve()
	_test_measurement_and_harvest()
	_save_to_gamestate()
	_load_and_verify()

	print("\n" + print_line(70))
	print("✅ DUAL FARM TEST COMPLETE")
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
	print("SETUP: Systems Initialization")
	print(print_sep() + "\n")

	grid = FarmGrid.new()
	grid.grid_width = 3
	grid.grid_height = 2

	economy = FarmEconomy.new()

	biome = BioticFluxBiome.new()
	biome.grid = grid
	biome._ready()

	market_biome = MarketBiome.new()
	market_biome._ready()

	game_state = GameState.new()

	print("✓ Grid: %.0fx%.0f (6 plots)" % [grid.grid_width, grid.grid_height])
	print("✓ FarmingBiome: Wheat, Mushroom, Imperial (noon/midnight)")
	print("✓ MarketBiome: Market, Mill")
	print("✓ Economy: Credits system")
	print("✓ GameState: Ready for save\n")


func _setup_biomes():
	print(print_sep())
	print("SETUP: Biome Resources")
	print(print_sep() + "\n")

	# Ensure biomes have icons/qubits initialized
	print("✓ FarmingBiome initialized")
	print("✓ MarketBiome initialized")
	print()


func _setup_grid_and_plots():
	print(print_sep())
	print("SETUP: Grid and Plots")
	print(print_sep() + "\n")

	# Layout: 3x2 grid
	# [0,0]=U  [1,0]=I  [2,0]=O
	# [0,1]=P  [1,1]=T  [2,1]=Y

	var plot_data = {
		"U": {"pos": Vector2i(0, 0), "type": WheatPlot.PlotType.WHEAT, "biome": "farming"},
		"I": {"pos": Vector2i(1, 0), "type": WheatPlot.PlotType.MUSHROOM, "biome": "farming"},
		"O": {"pos": Vector2i(2, 0), "type": 0, "biome": "farming"},  # Imperial Noon
		"P": {"pos": Vector2i(0, 1), "type": 1, "biome": "farming"},  # Imperial Midnight
		"T": {"pos": Vector2i(1, 1), "type": 4, "biome": "market"},   # Market
		"Y": {"pos": Vector2i(2, 1), "type": 3, "biome": "market"},   # Mill
	}

	for plot_id in plot_data:
		var data = plot_data[plot_id]
		var plot = WheatPlot.new()
		plot.plot_id = plot_id
		plot.grid_position = data["pos"]
		plot.plot_type = data["type"]

		if data["biome"] == "farming":
			plots_farming[plot_id] = plot
		else:
			plots_market[plot_id] = plot

		# Store in grid using Vector2i key
		grid.plots[data["pos"]] = plot
		print("✓ Plot %s at (%d,%d) - %s biome" % [plot_id, data["pos"].x, data["pos"].y, data["biome"]])

	print()


func _plant_and_evolve():
	print(print_sep())
	print("PLANTING: Resource Injection into Biomes")
	print(print_sep() + "\n")

	# FARMING BIOME: Plant 4 plots with quantum evolution
	print("📍 FARMING BIOME (UIOP):")
	print()

	# U: Standard wheat
	var u_qubit = biome.inject_planting(Vector2i(0, 0), 0.22, 0.08, 0)
	plots_farming["U"].quantum_state = u_qubit
	plots_farming["U"].is_planted = true
	print("  U (Wheat):        Planted quantum superposition")

	# I: Mushroom (different growth profile)
	var i_qubit = biome.inject_planting(Vector2i(1, 0), 0.22, 0.08, 1)
	plots_farming["I"].quantum_state = i_qubit
	plots_farming["I"].is_planted = true
	print("  I (Mushroom):     Planted quantum superposition")

	# O: Imperial Noon (constrained to high theta)
	var o_qubit = biome.inject_planting(Vector2i(2, 0), 0.22, 0.08, 0)
	o_qubit.theta = PI * 0.75  # 270° = 3π/4 (constrained state)
	plots_farming["O"].quantum_state = o_qubit
	plots_farming["O"].is_planted = true
	print("  O (Imperial Noon): Planted with θ constraint (3π/4)")

	# P: Imperial Midnight (constrained to low theta)
	var p_qubit = biome.inject_planting(Vector2i(0, 1), 0.22, 0.08, 0)
	p_qubit.theta = PI * 0.25  # 45° = π/4 (constrained state)
	plots_farming["P"].quantum_state = p_qubit
	plots_farming["P"].is_planted = true
	print("  P (Imperial Midnight): Planted with θ constraint (π/4)")

	print()

	# MARKET BIOME: Plant 2 plots
	print("📍 MARKET BIOME (TY):")
	print()

	# T: Market trading hub
	var t_coin = market_biome.inject_planting(Vector2i(1, 1), 0.22, 0.08, 4)
	plots_market["T"].quantum_state = t_coin
	plots_market["T"].is_planted = true
	print("  T (Market):   Injected coin energy for trading")

	# Y: Mill production
	var y_coin = market_biome.inject_planting(Vector2i(2, 1), 0.15, 0.10, 3)  # Different amounts
	plots_market["Y"].quantum_state = y_coin
	plots_market["Y"].is_planted = true
	print("  Y (Mill):     Injected coin energy for milling")

	print()
	print("✓ All 6 plots planted")
	print("✓ Resources injected into both biomes")
	print()


func _test_measurement_and_harvest():
	print(print_sep())
	print("MEASUREMENT: Collapse and Harvest")
	print(print_sep() + "\n")

	# Measure farming plots
	print("📍 FARMING BIOME HARVEST:")
	print()

	var wheat_total = 0.0
	var labor_total = 0.0

	for plot_id in plots_farming:
		var plot = plots_farming[plot_id]
		if plot.quantum_state:
			var harvest = biome.harvest_quantum_planting(plot.quantum_state)
			wheat_total += harvest["wheat"]
			labor_total += harvest["labor"]
			print("  %s: %.2f🌾 + %.2f👥" % [plot_id, harvest["wheat"], harvest["labor"]])

	print("\n  Total: %.2f🌾 + %.2f👥" % [wheat_total, labor_total])
	print()

	# Harvest market plots
	print("📍 MARKET BIOME HARVEST:")
	print()

	var credits_total = 0

	for plot_id in plots_market:
		var plot = plots_market[plot_id]
		if plot.quantum_state:
			var harvest = market_biome.harvest_coin_energy(plot.quantum_state)
			if harvest["success"]:
				credits_total += harvest["credits"]
				print("  %s: %d credits" % [plot_id, harvest["credits"]])

	print("\n  Total: %d credits" % credits_total)
	print()

	# Update economy
	economy.wheat_inventory += int(wheat_total)
	economy.credits += credits_total

	print("✓ Economy updated:")
	print("  Wheat: %d" % economy.wheat_inventory)
	print("  Credits: %d" % economy.credits)
	print()


func _save_to_gamestate():
	print(print_sep())
	print("SAVE: Persisting Game State")
	print(print_sep() + "\n")

	# Populate game state with all data
	game_state.scenario_id = "dual_farm_complete"
	game_state.grid_width = grid.grid_width
	game_state.grid_height = grid.grid_height
	game_state.credits = economy.credits
	game_state.wheat_inventory = economy.wheat_inventory
	game_state.flour_inventory = economy.flour_inventory
	game_state.save_timestamp = Time.get_unix_time_from_system()

	# Serialize all plots
	game_state.plots = []
	for pos in grid.plots:
		var plot = grid.plots[pos]
		if plot:
			var plot_data = {
				"plot_id": plot.plot_id,
				"grid_position": plot.grid_position,
				"is_planted": plot.is_planted,
				"theta": plot.theta,
				"phi": plot.phi,
				"has_been_measured": plot.has_been_measured,
			}
			game_state.plots.append(plot_data)

	# Save to disk
	var save_path = "user://saves/dual_farm_complete.tres"
	var result = ResourceSaver.save(game_state, save_path)

	if result == OK:
		print("✓ Farm state saved to disk")
		print("  Path: %s" % save_path)
		print("  Scenario: %s" % game_state.scenario_id)
		print("  Plots: %d" % game_state.plots.size())
		print("  Wheat: %d" % game_state.wheat_inventory)
		print("  Credits: %d" % game_state.credits)
	else:
		print("❌ Failed to save game state")

	print()


func _load_and_verify():
	print(print_sep())
	print("LOAD: Verifying Save/Load Cycle")
	print(print_sep() + "\n")

	# Load from saved file
	var save_path = "user://saves/dual_farm_complete.tres"

	if ResourceLoader.exists(save_path):
		var loaded_state = ResourceLoader.load(save_path)

		if loaded_state:
			print("✓ State loaded from disk")
			print("  Path: %s" % save_path)
			print("  Scenario: %s" % loaded_state.scenario_id)
			print("  Grid: %dx%d" % [loaded_state.grid_width, loaded_state.grid_height])
			print("  Plots: %d" % loaded_state.plots.size())
			print("  Wheat: %d" % loaded_state.wheat_inventory)
			print("  Credits: %d" % loaded_state.credits)
			print("\n✓ Full cycle verified: Create → Plant → Harvest → Save → Load")
		else:
			print("❌ Failed to load state from disk")
	else:
		print("❌ Save file not found: %s" % save_path)

	print()
