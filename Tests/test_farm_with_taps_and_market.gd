#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Complete Farm with Energy Taps & Market Strategy
##
## Demonstrates a realistic farm setup with:
## 1. Wheat production (baseline)
## 2. Energy taps to harvest quantum resources
## 3. Market trading system (sell resources for credits)
## 4. Progressive vocabulary discovery (tap targets unlock as vocab evolves)
##
## Layout (5x2 grid):
## [Row 0] 🌾 (Wheat) | ⚡ (Energy Tap - 🌾) | ⚡ (Energy Tap - 👥) | 💰 (Market) | 🏭 (Mill)
## [Row 1] 🌾 (Wheat) | ⚡ (Energy Tap - 🍄) | [empty]           | [empty]    | [empty]
##
## Resource Flow:
## Wheat grows → quantum energy tapped → accumulated in taps → harvested as 🌾 resources
## Resources sold at Market → Credits earned → Buy more crops

const Farm = preload("res://Core/Farm.gd")
const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
const Biome = preload("res://Core/Environment/Biome.gd")
const WheatPlot = preload("res://Core/GameMechanics/WheatPlot.gd")
const VocabularyEvolution = preload("res://Core/QuantumSubstrate/VocabularyEvolution.gd")
const GameState = preload("res://Core/GameState/GameState.gd")

var farm: Farm
var grid: FarmGrid
var economy: FarmEconomy
var biome: BioticFluxBiome
var vocabulary: VocabularyEvolution

# Track resources and strategy
var tap_positions: Array[Vector2i] = []
var market_position: Vector2i
var mill_position: Vector2i
var harvest_log: Array = []

func _initialize():
	print_header()

	_setup_complete_farm()
	_plant_crops_and_taps()
	_evolve_and_harvest()
	_simulate_market_trading()
	_demonstrate_progression()
	_save_and_verify()

	print_footer()
	quit()


func print_header():
	var line = ""
	for i in range(80):
		line += "="
	print("\n" + line)
	print("🌾💰⚡ FARM WITH ENERGY TAPS & MARKET STRATEGY")
	print("Realistic farm setup: Grow wheat → Tap energy → Trade resources")
	print(line + "\n")


func print_footer():
	var line = ""
	for i in range(80):
		line += "="
	print(line)
	print("✅ FARM SCENARIO COMPLETE - Ready for gameplay!")
	print(line + "\n")


func print_sep() -> String:
	var line = ""
	for i in range(70):
		line += "─"
	return line


func _setup_complete_farm():
	print(print_sep())
	print("PHASE 1: Farm System Setup")
	print(print_sep() + "\n")

	# Create core systems
	grid = FarmGrid.new()
	grid.grid_width = 5
	grid.grid_height = 2

	economy = FarmEconomy.new()

	biome = BioticFluxBiome.new()
	biome.grid = grid
	biome._ready()

	# Create vocabulary system
	vocabulary = VocabularyEvolution.new()
	vocabulary._ready()

	# Inject vocabulary into grid
	grid.vocabulary_evolution = vocabulary

	print("✓ FarmGrid: 5×2 = 10 plots")
	print("✓ Economy: %d starting credits" % economy.credits)
	print("✓ Biome: Farming environment initialized")
	print("✓ Vocabulary: %d discovered, %d evolving" % [
		vocabulary.discovered_vocabulary.size(),
		vocabulary.evolving_qubits.size()
	])
	print()


func _plant_crops_and_taps():
	print(print_sep())
	print("PHASE 2: Plant Crops & Energy Taps")
	print(print_sep() + "\n")

	# Initialize all plots
	for y in range(grid.grid_height):
		for x in range(grid.grid_width):
			var plot = WheatPlot.new()
			plot.grid_position = Vector2i(x, y)
			grid.plots[Vector2i(x, y)] = plot

	# Row 0: [0,0]=Wheat | [1,0]=Tap | [2,0]=Tap | [3,0]=Market | [4,0]=Mill
	# Row 1: [0,1]=Wheat | [1,1]=Tap | [2,1]=empty | [3,1]=empty | [4,1]=empty

	# Plant wheat at (0,0) and (0,1)
	print("🌾 Planting wheat...")
	var wheat_pos = [Vector2i(0, 0), Vector2i(0, 1)]
	for pos in wheat_pos:
		var plot = grid.get_plot(pos)
		plot.plot_type = WheatPlot.PlotType.WHEAT
		plot.is_planted = true

		# Create quantum state for wheat
		var qubit = biome.create_quantum_state(pos, "🌾", "👥", PI / 2.0)
		qubit.radius = 0.5  # Start with decent energy
		plot.quantum_state = qubit

		print("   ✓ Wheat at %s" % pos)

	print()

	# Plant energy taps targeting discovered vocabulary
	print("⚡ Planting energy taps (targeting discovered vocabulary)...")

	# Get available tap targets from vocabulary
	var available_emojis = grid.get_available_tap_emojis()
	var tap_targets = ["🌾", "👥", "🍄"]

	tap_positions = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)]

	for i in range(tap_positions.size()):
		var pos = tap_positions[i]
		var target = tap_targets[i] if i < tap_targets.size() else "🌾"

		# Try to plant tap (will validate against vocabulary)
		var success = grid.plant_energy_tap(pos, target)

		if success:
			print("   ✓ Tap at %s targeting %s" % [pos, target])
		else:
			print("   ⚠️  Could not plant tap at %s for %s" % [pos, target])

	print()

	# Plant Market at (3,0)
	print("💰 Placing market...")
	market_position = Vector2i(3, 0)
	var market_plot = grid.get_plot(market_position)
	market_plot.plot_type = WheatPlot.PlotType.MARKET
	market_plot.is_planted = true
	print("   ✓ Market at %s" % market_position)
	print()

	# Plant Mill at (4,0)
	print("🏭 Placing mill...")
	mill_position = Vector2i(4, 0)
	var mill_plot = grid.get_plot(mill_position)
	mill_plot.plot_type = WheatPlot.PlotType.MILL
	mill_plot.is_planted = true
	print("   ✓ Mill at %s" % mill_position)
	print()


func _evolve_and_harvest():
	print(print_sep())
	print("PHASE 3: Evolution & Energy Tapping")
	print(print_sep() + "\n")

	# Simulate time passing - wheat grows, energy accumulates in taps
	print("⏳ Simulating 100 time steps (grain ripens, energy taps collect)...\n")

	for step in range(100):
		# Evolve biome (grows crops, taps drain energy)
		biome._evolve_quantum_substrate(0.1)

		# Evolve vocabulary (might discover new concepts)
		vocabulary.evolve(0.1)

		# Apply mutation pressure boost from active taps
		var tap_boost = grid.get_tap_mutation_pressure_boost()
		vocabulary.mutation_pressure = min(0.15 + tap_boost, 2.0)

		if step % 20 == 0:
			print("   [Step %03d] Time: %.1fs" % [step, step * 0.1])

	print()

	# Harvest accumulated energy from taps
	print("🔨 Harvesting energy from taps...\n")

	for tap_pos in tap_positions:
		var result = grid.harvest_energy_tap(tap_pos)

		if result["success"]:
			var amount = result["amount"]
			var emoji = result["emoji"]

			print("   💧 Tap at %s: Harvested %d × %s" % [tap_pos, amount, emoji])
			harvest_log.append({
				"position": tap_pos,
				"emoji": emoji,
				"amount": amount
			})
		else:
			print("   ⚠️  Tap at %s: Nothing to harvest" % tap_pos)

	print()


func _simulate_market_trading():
	print(print_sep())
	print("PHASE 4: Market Trading Strategy")
	print(print_sep() + "\n")

	print("💰 Market Trading System:\n")

	# Simple trading strategy: sell harvested resources for credits
	var trading_price = {
		"🌾": 10,  # Grain: 10 credits each
		"👥": 5,   # Labor: 5 credits each
		"🍄": 15   # Mushrooms: 15 credits each (rare)
	}

	var total_revenue = 0

	for harvest in harvest_log:
		var emoji = harvest["emoji"]
		var amount = harvest["amount"]
		var price_per_unit = trading_price.get(emoji, 10)
		var revenue = amount * price_per_unit

		print("   Sale: %d × %s @ %d credits = %d 💵" % [amount, emoji, price_per_unit, revenue])
		total_revenue += revenue

	# Add to economy
	economy.credits += total_revenue
	print("\n   Total revenue: %d credits" % total_revenue)
	print("   Economy balance: %d credits\n" % economy.credits)


func _demonstrate_progression():
	print(print_sep())
	print("PHASE 5: Vocabulary Progression")
	print(print_sep() + "\n")

	var current_discovered = vocabulary.discovered_vocabulary.size()
	var current_evolving = vocabulary.evolving_qubits.size()

	print("📚 Vocabulary Evolution Progress:\n")
	print("   Discovered concepts: %d" % current_discovered)
	print("   Evolving pool: %d" % current_evolving)
	print("   Mutation pressure: %.3f" % vocabulary.mutation_pressure)
	print()

	# Show active taps and their effect
	var tap_stats = grid._count_active_energy_taps()
	var tap_boost = grid.get_tap_mutation_pressure_boost()

	print("⚡ Active Tap Effects on Vocabulary:\n")
	print("   Active taps: %d" % tap_stats["count"])
	print("   Accumulated energy: %.1f" % tap_stats["total_energy"])
	print("   Mutation pressure boost: %.3f (%.0f%% increase)" % [
		tap_boost,
		(tap_boost / 0.15) * 100
	])
	print()

	# Show what emojis can be tapped
	var available = grid.get_available_tap_emojis()
	print("🎯 Available Tap Targets (discovered vocabulary):\n   %s\n" % ", ".join(available))


func _save_and_verify():
	print(print_sep())
	print("PHASE 6: Save & Verify")
	print(print_sep() + "\n")

	# Create game state snapshot
	var game_state = GameState.new()

	# Capture farm state
	game_state.grid_width = grid.grid_width
	game_state.grid_height = grid.grid_height
	game_state.credits = economy.credits

	# Capture vocabulary state (will be persisted!)
	game_state.vocabulary_state = vocabulary.serialize()

	print("✓ GameState created")
	print("  - Grid: %dx%d" % [game_state.grid_width, game_state.grid_height])
	print("  - Credits: %d" % game_state.credits)
	print("  - Vocabulary persisted: %d discovered" % game_state.vocabulary_state.get("discovered_vocabulary", []).size())
	print()

	# Verify vocabulary restoration
	var vocab_restored = VocabularyEvolution.new()
	vocab_restored._ready()
	vocab_restored.deserialize(game_state.vocabulary_state)

	var restored_count = vocab_restored.discovered_vocabulary.size()
	print("✓ Vocabulary restore verification:")
	print("  - Original: %d discovered" % vocabulary.discovered_vocabulary.size())
	print("  - Restored: %d discovered" % restored_count)
	print("  - Match: %s" % (restored_count == vocabulary.discovered_vocabulary.size()))
	print()
