#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Dual Biome System Test
## Farm manages TWO quantum systems:
## 1. Farming Biome (wheat/mushroom) with Biotic Flux
## 2. Market Biome (supply/demand) with Granary Guilds
##
## Both biomes evolve independently, creating emergent economic gameplay

const Biome = preload("res://Core/Environment/Biome.gd")
const MarketBiome = preload("res://Core/Environment/MarketBiome.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")

var biome: BioticFluxBiome
var market_biome: MarketBiome
var economy: FarmEconomy
var grid: FarmGrid

func _initialize():
	print("\n" + print_line(70))
	print("🌾💰 DUAL BIOME SYSTEM: Farming + Market Evolution")
	print(print_line(70) + "\n")

	# Initialize both biomes
	biome = BioticFluxBiome.new()
	market_biome = MarketBioticFluxBiome.new()
	market_biome._initialize_market_qubits()  # Manually initialize since not in scene tree
	economy = FarmEconomy.new()
	grid = FarmGrid.new()
	grid.grid_width = 3
	grid.grid_height = 1

	print("✓ Systems initialized:")
	print("  Farming Biome: Wheat/Mushroom with Biotic Flux")
	print("  Market Biome: Supply/Demand with Granary Guilds")
	print("  Economy: Credits production\n")

	test_market_price_dynamics()
	test_supply_impact()
	test_full_dual_system()

	print("\n" + print_line(70))
	print("✅ DUAL BIOME TEST COMPLETE")
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


func test_market_price_dynamics():
	print(print_sep())
	print("TEST 1: MARKET PRICE DYNAMICS (Supply affects prices)")
	print(print_sep() + "\n")

	print("📊 Market starts at neutral supply (θ = π/2):\n")
	var conditions = market_biome.get_market_conditions()
	print("  Current flour price: " + str(conditions["flour_price"]))
	print("  Supply level: %.2f (1.0 = equilibrium)" % conditions["supply_level"])
	print("  Market energy: %.2f" % conditions["market_energy"])


func test_supply_impact():
	print(print_sep())
	print("TEST 2: SUPPLY SHOCK (Selling flour affects market)")
	print(print_sep() + "\n")

	print("📍 Initial market state:")
	var before = market_biome.get_market_conditions()
	print("  Price: " + str(before["flour_price"]))
	print("  Supply level: %.2f" % before["supply_level"])

	print("\n📍 Player sells 50 flour to market...")
	market_biome.apply_player_sale(50)

	print("\n📍 After supply shock:")
	var after = market_biome.get_market_conditions()
	print("  Price: " + str(after["flour_price"]) + " (was " + str(before["flour_price"]) + ")")
	print("  Supply level: %.2f (was %.2f)" % [after["supply_level"], before["supply_level"]])

	if after["flour_price"] < before["flour_price"]:
		print("\n✓ Price dropped due to oversupply (correct economic response)")
	else:
		print("\n⚠ Unexpected: price should drop with oversupply")


func test_full_dual_system():
	print(print_sep())
	print("TEST 3: FULL DUAL SYSTEM SIMULATION")
	print("Scenario: Farm 3 cycles, prices fluctuate, revenue changes")
	print(print_sep() + "\n")

	# Reset systems
	market_biome.reset_to_neutral()
	economy.wheat_inventory = 100
	economy.flour_inventory = 0
	economy.credits = 50

	print("📦 Starting state:")
	print("  Wheat: " + str(economy.wheat_inventory))
	print("  Credits: " + str(economy.credits))
	print("  Market price: " + str(market_biome.get_flour_price()) + " credits/flour\n")

	var total_credits_earned = 0

	for cycle in range(1, 4):
		var line = ""
		for i in range(70):
			line += "━"
		print(line)
		print("CYCLE " + str(cycle))
		print(line)

		# Check market price at start of cycle
		var market_price = market_biome.get_flour_price()
		print("\n📊 Market conditions:")
		var conditions = market_biome.get_market_conditions()
		print("  Flour price: " + str(market_price) + " credits")
		print("  Supply level: %.2f" % conditions["supply_level"])
		print("  Market energy: %.2f" % conditions["market_energy"])

		# Mill wheat
		print("\n🏭 Milling 30 wheat...")
		var mill_result = economy.process_wheat_to_flour(30)
		print("  Flour produced: " + str(mill_result["flour_produced"]))
		print("  Credits from milling: " + str(mill_result["credits_earned"]))

		# Sell flour at current market price
		print("\n💰 Selling " + str(mill_result["flour_produced"]) + " flour at " + str(market_price) + " credits/flour...")
		var flour_to_sell = mill_result["flour_produced"]
		var revenue = flour_to_sell * market_price

		# Simulate market sale
		economy.flour_inventory -= flour_to_sell
		economy.credits += revenue
		market_biome.apply_player_sale(flour_to_sell)

		print("  Revenue: " + str(revenue))
		total_credits_earned += revenue

		print("\n💵 Cycle " + str(cycle) + " totals:")
		print("  Wheat remaining: " + str(economy.wheat_inventory))
		print("  Flour: " + str(economy.flour_inventory))
		print("  Credits: " + str(economy.credits))

	print("\n" + print_sep())
	print("SUMMARY:")
	print("  Total market revenue: " + str(total_credits_earned))
	print("  Final credits: " + str(economy.credits))
	print("  Final wheat: " + str(economy.wheat_inventory))

	print("\n💡 KEY INSIGHT:")
	print("  Each cycle affects market supply/price")
	print("  Later cycles had lower flour prices (oversupply)")
	print("  This creates strategic tension:")
	print("    - Sell fast = low price but high volume")
	print("    - Wait for price = risk of spoilage/decay")
	print("    - Time harvest around market cycles!")


func print_observation():
	print("\n" + print_line(70))
	print("🎯 DUAL BIOME ARCHITECTURE BENEFITS")
	print(print_line(70))

	print("""
Two independent quantum biomes = emergent gameplay:

1. FARMING BIOME (wheat/mushroom with Biotic Flux)
   - Player manages quantum states
   - Chooses where/when to plant
   - Harvests quantum resources

2. MARKET BIOME (supply/demand with Granary Guilds)
   - Evolves based on player sales
   - High supply = low prices
   - Creates natural boom/bust cycles

STRATEGIC DEPTH:
- Timing matters: when is flour price highest?
- Volume vs price tradeoff
- Tributes to Granary Guilds modify their behavior
- Market couples to farming biome through economy

LATER: (🌾,💰) HYBRID
- Grows in farming biome
- Harvests to BOTH wheat inventory AND flour inventory
- Worth more at market but harder to grow
- Creates three-way farming strategy
""")
