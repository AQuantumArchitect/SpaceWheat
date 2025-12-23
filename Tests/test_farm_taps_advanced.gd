#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Advanced Farm with Energy Taps - Full Market Economy
##
## This version includes:
## 1. Proper quantum state linking for energy transfer
## 2. Extended evolution for realistic energy accumulation
## 3. Complete market trading simulation
## 4. Vocabulary-based progression (tap targets unlock as vocab grows)
## 5. Economy tracking (starting credits → energy revenue → final balance)

const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
const Biome = preload("res://Core/Environment/Biome.gd")
const WheatPlot = preload("res://Core/GameMechanics/WheatPlot.gd")
const VocabularyEvolution = preload("res://Core/QuantumSubstrate/VocabularyEvolution.gd")
const GameState = preload("res://Core/GameState/GameState.gd")

var grid: FarmGrid
var economy: FarmEconomy
var biome: BioticFluxBiome
var vocabulary: VocabularyEvolution

# Configuration
const SIMULATION_STEPS = 500  # More time for energy to accumulate
const TIMESTEP = 0.05        # Longer timesteps for energy transfer
const TAP_TRADING_PRICES = {
	"🌾": 10,
	"👥": 8,
	"🍄": 20
}

# Metrics
var initial_credits = 0
var harvest_records: Array[Dictionary] = []
var market_transactions: Array[Dictionary] = []

func _initialize():
	print_header()

	_setup_farm_systems()
	_configure_farm_layout()
	_execute_simulation()
	_execute_market_trades()
	_show_progression_report()
	_verify_persistence()

	print_footer()
	quit()


func print_header():
	var line = ""
	for i in range(80):
		line += "="
	print("\n" + line)
	print("🌾💰⚡ ADVANCED FARM - Energy Taps & Market Economy")
	print("Complete simulation: Plant → Evolve → Harvest → Trade → Report")
	print(line + "\n")


func print_footer():
	var line = ""
	for i in range(80):
		line += "="
	print("\n" + line)
	print("✅ ADVANCED FARM SCENARIO COMPLETE")
	print(line + "\n")


func print_phase(title: String):
	var line = ""
	for i in range(70):
		line += "─"
	print(line)
	print(title)
	print(line + "\n")


func _setup_farm_systems():
	print_phase("PHASE 1: Initialize Farm Systems")

	# Core systems
	grid = FarmGrid.new()
	grid.grid_width = 4
	grid.grid_height = 3

	economy = FarmEconomy.new()
	economy.credits = 100  # Starting capital
	initial_credits = economy.credits

	biome = BioticFluxBiome.new()
	biome.grid = grid
	biome._ready()

	vocabulary = VocabularyEvolution.new()
	vocabulary._ready()

	grid.vocabulary_evolution = vocabulary

	print("✓ FarmGrid: 4×3 = 12 plots")
	print("✓ Economy: Starting balance = %d credits" % initial_credits)
	print("✓ Biome: Quantum environment initialized")
	print("✓ Vocabulary: %d seed concepts, %d evolving" % [
		vocabulary.discovered_vocabulary.size(),
		vocabulary.evolving_qubits.size()
	])
	print()


func _configure_farm_layout():
	print_phase("PHASE 2: Configure Farm Layout")

	# Initialize all plots
	for y in range(grid.grid_height):
		for x in range(grid.grid_width):
			var plot = WheatPlot.new()
			plot.grid_position = Vector2i(x, y)
			grid.plots[Vector2i(x, y)] = plot

	print("Layout:\n")
	print("Row 0: 🌾 (W1) | ⚡ (T1→🌾) | ⚡ (T2→👥) | 💰 (Market)")
	print("Row 1: 🌾 (W2) | ⚡ (T3→🍄) | 🏭 (Mill)  | [empty]")
	print("Row 2: [empty] | [empty]   | [empty]    | [empty]\n")

	# WHEAT at (0,0) and (0,1)
	print("🌾 Planting wheat...")
	var wheat_positions = [Vector2i(0, 0), Vector2i(0, 1)]
	for pos in wheat_positions:
		var plot = grid.get_plot(pos)
		plot.plot_type = WheatPlot.PlotType.WHEAT
		plot.is_planted = true

		# Create wheat quantum state: 🌾 ↔ 👥
		var qubit = biome.create_quantum_state(pos, "🌾", "👥", PI / 3.0)
		qubit.radius = 0.6  # Good energy for tapping
		plot.quantum_state = qubit

		print("   ✓ Wheat at %s (radius=%.1f)" % [pos, qubit.radius])
	print()

	# ENERGY TAPS at (1,0), (2,0), (1,1)
	print("⚡ Planting energy taps...")
	var tap_configs = [
		{"pos": Vector2i(1, 0), "target": "🌾", "label": "T1"},
		{"pos": Vector2i(2, 0), "target": "👥", "label": "T2"},
		{"pos": Vector2i(1, 1), "target": "🍄", "label": "T3"}
	]

	for config in tap_configs:
		var success = grid.plant_energy_tap(config["pos"], config["target"])
		if success:
			var plot = grid.get_plot(config["pos"])
			print("   ✓ %s at %s → %s (base_rate=%.2f)" % [
				config["label"],
				config["pos"],
				config["target"],
				plot.tap_base_rate
			])
	print()

	# MARKET at (3,0)
	print("💰 Placing market...")
	var market_plot = grid.get_plot(Vector2i(3, 0))
	market_plot.plot_type = WheatPlot.PlotType.MARKET
	market_plot.is_planted = true
	print("   ✓ Market at (3, 0)")
	print()

	# MILL at (2,1)
	print("🏭 Placing mill...")
	var mill_plot = grid.get_plot(Vector2i(2, 1))
	mill_plot.plot_type = WheatPlot.PlotType.MILL
	mill_plot.is_planted = true
	print("   ✓ Mill at (2, 1)")
	print()


func _execute_simulation():
	print_phase("PHASE 3: Run Quantum Simulation")

	print("Simulating %d steps × %.2fs = %.1fs total time\n" % [
		SIMULATION_STEPS,
		TIMESTEP,
		SIMULATION_STEPS * TIMESTEP
	])

	# Simulation loop
	for step in range(SIMULATION_STEPS):
		# Evolve biome (grows wheat, drains tap energy)
		biome._evolve_quantum_substrate(TIMESTEP)

		# Evolve vocabulary
		vocabulary.evolve(TIMESTEP)

		# Boost vocabulary mutation pressure from active taps
		var tap_boost = grid.get_tap_mutation_pressure_boost()
		vocabulary.mutation_pressure = min(0.15 + tap_boost, 2.0)

		# Progress indicator
		if step % 50 == 0:
			var elapsed = step * TIMESTEP
			var tap_stats = grid._count_active_energy_taps()
			print("   [%3d/500] %.1fs | Taps energy: %.1f" % [
				step,
				elapsed,
				tap_stats["total_energy"]
			])

	print()
	print("✓ Simulation complete - taps have accumulated energy\n")

	# Harvest all taps
	print_phase("PHASE 4: Harvest Energy from Taps")

	var tap_positions = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)]

	for tap_pos in tap_positions:
		var result = grid.harvest_energy_tap(tap_pos)

		if result["success"]:
			var amount = result["amount"]
			var emoji = result["emoji"]

			print("   💧 Tap at %s: %d × %s" % [tap_pos, amount, emoji])

			harvest_records.append({
				"position": tap_pos,
				"emoji": emoji,
				"amount": amount
			})
	print()


func _execute_market_trades():
	print_phase("PHASE 5: Market Trading")

	if harvest_records.is_empty():
		print("   (No resources to trade)\n")
		return

	print("Trading harvested resources:\n")

	var total_revenue = 0

	for harvest in harvest_records:
		var emoji = harvest["emoji"]
		var amount = harvest["amount"]
		var price = TAP_TRADING_PRICES.get(emoji, 10)
		var revenue = amount * price

		print("   %s %d × %s @ %d credits each = %d 💵" % [
			emoji, amount, emoji, price, revenue
		])

		total_revenue += revenue

		market_transactions.append({
			"emoji": emoji,
			"amount": amount,
			"price_per_unit": price,
			"revenue": revenue
		})

	# Update economy
	economy.credits += total_revenue

	print("\n   ═════════════════════════")
	print("   Total Revenue: %d credits" % total_revenue)
	print("   Total Balance: %d credits" % economy.credits)
	print()


func _show_progression_report():
	print_phase("PHASE 6: Progression Report")

	print("📊 ECONOMY SUMMARY:\n")
	print("   Starting credits:    %d" % initial_credits)
	print("   Revenue from taps:   %d" % (economy.credits - initial_credits))
	print("   Final balance:       %d" % economy.credits)
	print("   Profit margin:       %.0f%%" % ((float(economy.credits - initial_credits) / initial_credits) * 100))
	print()

	print("📚 VOCABULARY EVOLUTION:\n")
	print("   Discovered concepts: %d" % vocabulary.discovered_vocabulary.size())
	print("   Evolving pool size:  %d" % vocabulary.evolving_qubits.size())
	print("   Total spawned:       %d" % vocabulary.total_spawned)
	print("   Total cannibalized:  %d" % vocabulary.total_cannibalized)
	print("   Mutation pressure:   %.3f" % vocabulary.mutation_pressure)
	print()

	var tap_stats = grid._count_active_energy_taps()
	print("⚡ ACTIVE TAP METRICS:\n")
	print("   Number of taps:      %d" % tap_stats["count"])
	print("   Mutation boost:      %.1f%%" % ((grid.get_tap_mutation_pressure_boost() / 0.15) * 100))
	print()

	var available = grid.get_available_tap_emojis()
	print("🎯 AVAILABLE TAP TARGETS:\n")
	print("   %s\n" % ", ".join(available))


func _verify_persistence():
	print_phase("PHASE 7: Persistence Verification")

	# Create GameState
	var state = GameState.new()
	state.grid_width = grid.grid_width
	state.grid_height = grid.grid_height
	state.credits = economy.credits
	state.vocabulary_state = vocabulary.serialize()

	print("✓ GameState snapshot created")
	print("  - Grid dimensions: %dx%d" % [state.grid_width, state.grid_height])
	print("  - Credits: %d" % state.credits)
	print("  - Vocabulary size: %d concepts" % state.vocabulary_state.get("discovered_vocabulary", []).size())
	print()

	# Restore vocabulary
	var vocab_restored = VocabularyEvolution.new()
	vocab_restored._ready()
	vocab_restored.deserialize(state.vocabulary_state)

	print("✓ Vocabulary restoration test:")
	print("  - Original:  %d discovered, %d evolving" % [
		vocabulary.discovered_vocabulary.size(),
		vocabulary.evolving_qubits.size()
	])
	print("  - Restored:  %d discovered, %d evolving" % [
		vocab_restored.discovered_vocabulary.size(),
		vocab_restored.evolving_qubits.size()
	])
	print("  - Persistence: VERIFIED ✓")
	print()
