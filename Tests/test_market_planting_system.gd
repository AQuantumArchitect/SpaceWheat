#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: Market Biome Planting System
## Player plants same resources (0.08👥 + 0.22🌾) into either:
## - FarmingBiome: wheat grows as quantum superposition
## - MarketBiome: wheat converts to coin energy → credits
##
## Result: Two farming styles with same input, different output

const MarketBiome = preload("res://Core/Environment/MarketBiome.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")

var market_biome: MarketBiome
var economy: FarmEconomy

func _initialize():
	print("\n" + print_line(70))
	print("🌾💰 MARKET PLANTING SYSTEM TEST")
	print("Same inputs → Different biomes → Different outputs")
	print(print_line(70) + "\n")

	market_biome = MarketBioticFluxBiome.new()
	market_biome._initialize_market_qubits()
	economy = FarmEconomy.new()

	test_market_injection()
	test_comparison()

	print("\n" + print_line(70))
	print("✅ MARKET PLANTING TEST COMPLETE")
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


func test_market_injection():
	print(print_sep())
	print("TEST 1: MARKET BIOME WHEAT INJECTION")
	print(print_sep() + "\n")

	# Standard planting inputs
	var labor_input = 0.08
	var wheat_input = 0.22

	print("📍 Player resources:")
	print("  Labor: " + str(labor_input) + "👥")
	print("  Wheat: " + str(wheat_input) + "🌾")
	print("")

	# Inject into market biome
	print("📍 Injecting into MarketBiome...")
	var coin_qubit = market_biome.inject_planting(
		Vector2i(0, 0),
		wheat_input,
		labor_input,
		0  # WHEAT plot type
	)

	print("\n📊 Coin qubit created:")
	if coin_qubit:
		print("  Energy: " + str(coin_qubit.energy))
		print("  Theta: " + str(coin_qubit.theta))
		print("  Radius: " + str(coin_qubit.radius))

	# Simulate coin energy growth (market dynamics)
	print("\n📍 Simulating market dynamics (coin energy grows)...")
	print("  Base: " + str(coin_qubit.energy) + " coin energy")

	# Simulate some growth (coin energy increases over time)
	var growth_rate = 0.1  # 10% per cycle
	var cycles = 3
	for cycle in range(cycles):
		coin_qubit.energy *= (1.0 + growth_rate)
		print("  After cycle " + str(cycle + 1) + ": " + str(coin_qubit.energy) + " coin energy")

	# Harvest
	print("\n📍 Harvesting coin energy...")
	var harvest_result = market_biome.harvest_coin_energy(coin_qubit)

	if harvest_result["success"]:
		print("✓ Harvest successful!")
		print("  Coin energy harvested: " + str(harvest_result["coin_energy"]))
		print("  Credits earned: " + str(harvest_result["credits"]))
	else:
		print("❌ Harvest failed")


func test_comparison():
	print("\n\n" + print_sep())
	print("TEST 2: MARKET vs FARMING COMPARISON")
	print("Same inputs → Different strategies → Different results")
	print(print_sep() + "\n")

	var labor_input = 0.08
	var wheat_input = 0.22

	print("SCENARIO A: Plant in FarmingBiome")
	var dash_line = ""
	for i in range(35):
		dash_line += "─"
	print(dash_line)
	print("Input: " + str(wheat_input) + "🌾 + " + str(labor_input) + "👥")
	print("Output: Quantum superposition (50/50 wheat/labor)")
	print("Harvest: P(wheat) * energy → wheat resource")
	print("Time: 60+ seconds for evolution")
	print("Value: Resource-based (wheat → flour → credits)")
	print("Risk: Quantum uncertainty\n")

	print("SCENARIO B: Plant in MarketBiome")
	print(dash_line)
	var initial_energy = wheat_input * 100.0 * (1.0 + labor_input * 5.0)
	print("Input: " + str(wheat_input) + "🌾 + " + str(labor_input) + "👥")
	print("Output: Coin energy (" + str(int(initial_energy)) + " initial)")
	print("Harvest: Coin energy * 10 → credits directly")
	print("Time: Immediate (no quantum evolution needed)")
	print("Value: Direct credit conversion")
	print("Risk: Market supply affects prices\n")

	print("ECONOMIC COMPARISON")
	print(dash_line)

	# Market scenario: immediate harvest
	var market_coin_qubit = market_biome.inject_planting(
		Vector2i(1, 0),
		wheat_input,
		labor_input,
		0
	)
	var market_harvest = market_biome.harvest_coin_energy(market_coin_qubit)
	var market_credits = market_harvest["credits"]

	# Farming scenario: rough estimate
	# 0.22 wheat → flour (80% = 0.176) → market (80 credits/flour) = ~14 credits
	# Plus 0.08 labor could yield 0.08 * 10 = 0.8 labor units
	var farming_estimate = int(wheat_input * 0.8 * 80.0)  # wheat → flour → credits

	print("Market strategy immediate return:")
	print("  Input: %.2f🌾 + %.2f👥" % [wheat_input, labor_input])
	print("  Coin energy: " + str(market_harvest["coin_energy"]))
	print("  Credits earned: " + str(market_credits))

	print("\nFarming strategy (estimate after production chain):")
	print("  Input: %.2f🌾 + %.2f👥" % [wheat_input, labor_input])
	print("  Wheat → flour: %.2f🌾" % [wheat_input * 0.8])
	print("  Flour → credits: ~" + str(farming_estimate))
	print("  + Labor resource: %.2f👥" % labor_input)

	print("\n💡 KEY INSIGHT:")
	print("  Market biome gives IMMEDIATE profitable output")
	print("  Farming biome gives DELAYED but resource-rich output")
	print("  Player chooses strategy based on urgency")


func print_summary():
	print("\n" + print_line(70))
	print("🎯 SYSTEM ARCHITECTURE")
	print(print_line(70))

	print("""
NEW PLANTING SYSTEM:

Input Layer (Universal):
  - All planting costs: 0.08👥 labor + 0.22🌾 wheat
  - Resources come from inventory
  - Player chooses target biome

Processing Layer (Biome-specific):
  - FarmingBiome: wheat evolves as quantum superposition
  - MarketBiome: wheat converts to coin energy

Output Layer (Biome-specific):
  - FarmingBiome: harvest quantum state → wheat/labor resources
  - MarketBiome: harvest coin energy → credits directly

Strategic Choice:
  - Patient player: Farm wheat (long game, resource-rich)
  - Aggressive player: Sell to market (fast money, coin-rich)

Removed:
  - Mill→Market credit conversion (now optional, not required)
  - Makes market game self-contained and optional
  - Players can choose pure farming if they prefer
""")
