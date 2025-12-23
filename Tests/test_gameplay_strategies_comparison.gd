#!/usr/bin/env -S godot --headless -s
extends SceneTree

## STRATEGY COMPARISON TEST
## Run all 3 strategies and compare outcomes
## Shows different ways to play the same game with different tradeoffs

const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
const Biome = preload("res://Core/Environment/Biome.gd")
const MarketBiome = preload("res://Core/Environment/MarketBiome.gd")
const WheatPlot = preload("res://Core/GameMechanics/WheatPlot.gd")

var results: Array = []

func _initialize():
	print("\n" + "=".repeat(80))
	print("🎮 STRATEGY COMPARISON: Three Ways to Play SpaceWheat")
	print("=".repeat(80) + "\n")

	_strategy_1_aggressive_market()
	_strategy_2_patient_farmer()
	_strategy_3_balanced_hybrid()
	_compare_outcomes()

	quit()


func _strategy_1_aggressive_market():
	print(print_sep())
	print("STRATEGY 1: AGGRESSIVE MARKET FOCUS")
	print(print_sep() + "\n")

	var grid = FarmGrid.new()
	grid.grid_width = 3
	grid.grid_height = 2

	var economy = FarmEconomy.new()
	economy.credits = 50

	var market_biome = MarketBioticFluxBiome.new()
	market_biome._initialize_market_qubits()

	# Create plots
	for y in range(grid.grid_height):
		for x in range(grid.grid_width):
			var plot = WheatPlot.new()
			plot.plot_id = char(65 + y * grid.grid_width + x)
			plot.grid_position = Vector2i(x, y)
			grid.plots[Vector2i(x, y)] = plot

	# Plant all to market
	var total_market_credits = 0
	for pos in grid.plots:
		var plot = grid.plots[pos]
		var coin_qubit = market_biome.inject_planting(pos, 0.22, 0.08, 4)
		plot.quantum_state = coin_qubit
		plot.is_planted = true

		var harvest = market_biome.harvest_coin_energy(coin_qubit)
		if harvest["success"]:
			total_market_credits += harvest["credits"]

	economy.credits += total_market_credits

	print("Result:")
	print("  Wheat:   %d" % economy.wheat_inventory)
	print("  Flour:   %d" % economy.flour_inventory)
	print("  Credits: %d (+%d from market)" % [economy.credits, total_market_credits])
	print()

	results.append({
		"name": "Aggressive Market",
		"wheat": economy.wheat_inventory,
		"flour": economy.flour_inventory,
		"credits": economy.credits,
		"time": 0,
		"complexity": "Simple"
	})


func _strategy_2_patient_farmer():
	print(print_sep())
	print("STRATEGY 2: PATIENT FARMER")
	print(print_sep() + "\n")

	var grid = FarmGrid.new()
	grid.grid_width = 3
	grid.grid_height = 2

	var economy = FarmEconomy.new()
	economy.credits = 50

	var biome = BioticFluxBiome.new()
	biome.grid = grid
	biome._ready()

	# Create plots
	for y in range(grid.grid_height):
		for x in range(grid.grid_width):
			var plot = WheatPlot.new()
			plot.plot_id = char(65 + y * grid.grid_width + x)
			plot.grid_position = Vector2i(x, y)
			grid.plots[Vector2i(x, y)] = plot

	# Plant all to farming
	for pos in grid.plots:
		var plot = grid.plots[pos]
		var planting_qubit = biome.inject_planting(pos, 0.22, 0.08, 0)
		plot.quantum_state = planting_qubit
		plot.is_planted = true

	# Simulate evolution
	for cycle in range(5):
		for pos in grid.plots:
			var plot = grid.plots[pos]
			if plot.quantum_state:
				var current_theta = plot.quantum_state.theta
				var target_theta = PI / 2.0
				var drift = (target_theta - current_theta) * 0.1
				plot.quantum_state.theta += drift

	# Harvest
	var total_wheat = 0.0
	for pos in grid.plots:
		var plot = grid.plots[pos]
		if plot.quantum_state:
			var harvest = biome.harvest_quantum_planting(plot.quantum_state)
			if harvest["success"]:
				total_wheat += harvest["wheat"]

	economy.wheat_inventory += int(total_wheat)

	# Optional: mill wheat
	if economy.wheat_inventory > 5:
		var mill_result = economy.process_wheat_to_flour(economy.wheat_inventory)
		if mill_result["success"]:
			economy.credits += mill_result["credits_earned"]

	print("Result:")
	print("  Wheat:   %d" % economy.wheat_inventory)
	print("  Flour:   %d" % economy.flour_inventory)
	print("  Credits: %d" % economy.credits)
	print()

	results.append({
		"name": "Patient Farmer",
		"wheat": economy.wheat_inventory,
		"flour": economy.flour_inventory,
		"credits": economy.credits,
		"time": 60,
		"complexity": "Complex"
	})


func _strategy_3_balanced_hybrid():
	print(print_sep())
	print("STRATEGY 3: BALANCED HYBRID")
	print(print_sep() + "\n")

	var grid = FarmGrid.new()
	grid.grid_width = 3
	grid.grid_height = 2

	var economy = FarmEconomy.new()
	economy.credits = 50

	var biome = BioticFluxBiome.new()
	biome.grid = grid
	biome._ready()

	var market_biome = MarketBioticFluxBiome.new()
	market_biome._initialize_market_qubits()

	# Create plots
	for y in range(grid.grid_height):
		for x in range(grid.grid_width):
			var plot = WheatPlot.new()
			plot.plot_id = char(65 + y * grid.grid_width + x)
			plot.grid_position = Vector2i(x, y)
			grid.plots[Vector2i(x, y)] = plot

	# Split: 3 market, 3 farming
	var plot_list = grid.plots.keys()

	# Market plots (first 3)
	var market_credits = 0
	for i in range(3):
		var pos = plot_list[i]
		var plot = grid.plots[pos]
		var coin_qubit = market_biome.inject_planting(pos, 0.22, 0.08, 4)
		plot.quantum_state = coin_qubit
		plot.is_planted = true

		var harvest = market_biome.harvest_coin_energy(coin_qubit)
		if harvest["success"]:
			market_credits += harvest["credits"]

	economy.credits += market_credits

	# Farming plots (last 3)
	for i in range(3, 6):
		var pos = plot_list[i]
		var plot = grid.plots[pos]
		var planting_qubit = biome.inject_planting(pos, 0.22, 0.08, 0)
		plot.quantum_state = planting_qubit
		plot.is_planted = true

	# Simulate evolution
	for cycle in range(3):
		for i in range(3, 6):
			var pos = plot_list[i]
			var plot = grid.plots[pos]
			if plot.quantum_state:
				var current_theta = plot.quantum_state.theta
				var target_theta = PI / 2.0
				var drift = (target_theta - current_theta) * 0.08
				plot.quantum_state.theta += drift

	# Harvest farming plots
	var total_wheat = 0.0
	for i in range(3, 6):
		var pos = plot_list[i]
		var plot = grid.plots[pos]
		if plot.quantum_state:
			var harvest = biome.harvest_quantum_planting(plot.quantum_state)
			if harvest["success"]:
				total_wheat += harvest["wheat"]

	economy.wheat_inventory += int(total_wheat)

	# Mill and sell
	if economy.wheat_inventory > 5:
		var mill_result = economy.process_wheat_to_flour(economy.wheat_inventory)
		if mill_result["success"]:
			economy.credits += mill_result["credits_earned"]
			if mill_result["flour_produced"] > 0:
				var market_result = economy.sell_flour_at_market(mill_result["flour_produced"])
				if market_result["success"]:
					economy.credits += market_result["credits_received"]

	print("Result:")
	print("  Wheat:   %d" % economy.wheat_inventory)
	print("  Flour:   %d" % economy.flour_inventory)
	print("  Credits: %d" % economy.credits)
	print()

	results.append({
		"name": "Balanced Hybrid",
		"wheat": economy.wheat_inventory,
		"flour": economy.flour_inventory,
		"credits": economy.credits,
		"time": 30,
		"complexity": "Moderate"
	})


func print_line(char: String, count: int) -> String:
	var line = ""
	for i in range(count):
		line += char
	return line


func _compare_outcomes():
	print(print_line("=", 80))
	print("📊 STRATEGY COMPARISON MATRIX")
	print(print_line("=", 80) + "\n")

	print("Results Summary:\n")
	print("Strategy            Wheat  Flour  Credits  Time(s)  Complexity")
	print(print_line("-", 68))

	for result in results:
		var wheat_str = str(result["wheat"]).rpad(5)
		var flour_str = str(result["flour"]).rpad(5)
		var credits_str = str(result["credits"]).rpad(7)
		var time_str = str(result["time"]).rpad(7)

		print("%s  %s %s  %s  %s  %s" % [
			result["name"].rpad(15),
			wheat_str,
			flour_str,
			credits_str,
			time_str,
			result["complexity"]
		])

	print("\n" + print_sep() + "\n")

	print("Analysis by Metric:\n")

	# Credits ranking
	print("💰 CREDITS (Immediate Profit):")
	var credits_sorted = results.duplicate()
	credits_sorted.sort_custom(func(a, b): return a["credits"] > b["credits"])
	for i in range(credits_sorted.size()):
		print("  %d. %s: %d credits" % [i+1, credits_sorted[i]["name"], credits_sorted[i]["credits"]])
	print()

	# Wheat ranking
	print("🌾 WHEAT (Long-term Potential):")
	var wheat_sorted = results.duplicate()
	wheat_sorted.sort_custom(func(a, b): return a["wheat"] > b["wheat"])
	for i in range(wheat_sorted.size()):
		print("  %d. %s: %d wheat" % [i+1, wheat_sorted[i]["name"], wheat_sorted[i]["wheat"]])
	print()

	# Speed ranking
	print("⚡ SPEED (Time to Results):")
	var speed_sorted = results.duplicate()
	speed_sorted.sort_custom(func(a, b): return a["time"] < b["time"])
	for i in range(speed_sorted.size()):
		var speed_desc = "Immediate" if speed_sorted[i]["time"] == 0 else "%ds" % speed_sorted[i]["time"]
		print("  %d. %s: %s" % [i+1, speed_sorted[i]["name"], speed_desc])
	print()

	print(print_line("=", 80) + "\n")

	print("Strategy Recommendations:\n")

	print("🏃 For Speed Runners:")
	print("   → AGGRESSIVE MARKET: Highest immediate credits, perfect for speedruns")
	print("   → Best if: You want results NOW and don't care about resources\n")

	print("👨‍🌾 For Completionists:")
	print("   → PATIENT FARMER: Rich resource base for production chains")
	print("   → Best if: You enjoy managing quantum evolution and planning ahead\n")

	print("⚖️  For Strategists:")
	print("   → BALANCED HYBRID: Best of both worlds with good scaling")
	print("   → Best if: You want flexibility and long-term growth potential\n")

	print(print_line("=", 80) + "\n")


func print_sep() -> String:
	var line = ""
	for i in range(80):
		line += "─"
	return line
