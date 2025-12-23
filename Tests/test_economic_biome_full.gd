#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: Complete Economic Biome (Market + Guilds)
##
## Demonstrates the unified economic system where:
## 1. Guilds consume bread (creating demand)
## 2. Market measures and sets exchange rates
## 3. Player trades flour in response
## 4. Guild pressure adjusts market based on supplies
## 5. Feedback loop creates self-correcting boom/bust cycles

const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const EconomicBiome = preload("res://Core/Environment/EconomicBiome.gd")

var economy: EconomicBiome
var bread_qubit: DualEmojiQubit

func _initialize():
	print("\n" + print_line("=", 80))
	print("🏢💰 ECONOMIC BIOME COMPLETE INTEGRATION TEST")
	print("Market Measurement + Guild Consumption + Player Trading + Feedback Loop")
	print(print_line("=", 80) + "\n")

	# Create unified economic biome
	economy = EconomicBioticFluxBiome.new()

	# Create bread qubit (🍞, 👥) - guilds will consume this
	bread_qubit = DualEmojiQubit.new("🍞", "👥", PI / 2.0)
	bread_qubit.phi = 0.0
	bread_qubit.radius = 1.0

	# Link bread to economy
	economy.set_bread_qubit(bread_qubit)

	_simulate_complete_economic_cycle()

	print(print_line("=", 80))
	print("✅ ECONOMIC BIOME TEST COMPLETE")
	print(print_line("=", 80) + "\n")

	quit()


func print_line(char: String, count: int) -> String:
	var line = ""
	for i in range(count):
		line += char
	return line


func print_sep() -> String:
	var line = ""
	for i in range(80):
		line += "─"
	return line


func _simulate_complete_economic_cycle():
	"""
	Simulate 5 cycles showing complete economic feedback:

	CYCLE 1: Initial state, guilds start consuming
	CYCLE 2: Player trades flour, market responds
	CYCLE 3: Guilds perceive scarcity, push market
	CYCLE 4: Mill production injection
	CYCLE 5: Complete feedback loop
	"""

	for cycle in range(1, 6):
		print(print_sep())
		print("CYCLE %d" % cycle)
		print(print_sep() + "\n")

		# BREAD CONSUMPTION
		print("🍞 Guild Consumption Phase:\n")
		print("   Draining bread energy...")
		economy.drain_bread_energy()
		print("   Bread energy: %.2f" % bread_qubit.radius)
		print()

		# MARKET OBSERVATION
		print("📊 Market Status:\n")
		var market_state = economy.get_market_state()
		print("   Theta: %.2f° → P(flour): %.1f%%, P(coins): %.1f%%" % [
			market_state["theta_degrees"],
			market_state["flour_probability"] * 100,
			market_state["coins_probability"] * 100
		])
		print("   Market energy: %.2f" % market_state["energy"])
		print()

		# GUILD STATUS
		print("🏢 Guild Status:\n")
		var guild_status = economy.get_guild_status()
		print("   Storage level: %.2f" % guild_status["storage_level"])
		print("   Flour satisfaction: %.1f%%" % [guild_status["flour_satisfaction"] * 100])
		print()

		# CYCLE-SPECIFIC ACTIONS
		match cycle:
			1:
				_cycle_1_initial(economy, market_state)
			2:
				_cycle_2_player_trade(economy)
			3:
				_cycle_3_guild_response(economy)
			4:
				_cycle_4_mill_injection(economy)
			5:
				_cycle_5_feedback_loop(economy)

		print()


func _cycle_1_initial(economy: EconomicBiome, market_state: Dictionary):
	"""Cycle 1: Show initial balanced market"""
	print("💡 Observation: Market balanced (π/2), both flour and coins equally likely")
	print()


func _cycle_2_player_trade(economy: EconomicBiome):
	"""Cycle 2: Player has flour and trades"""
	print("💰 Trading Phase:\n")

	var flour_to_sell = 100
	print("   Player selling %d flour..." % flour_to_sell)

	# Preview exchange rate
	var preview = economy.get_exchange_rate_for_flour(flour_to_sell)
	print("   Range: %d - %d credits (expected: %d)" % [
		preview["worst_case_rate"],
		preview["best_case_rate"],
		preview["expected_rate"]
	])
	print()

	# Execute trade
	var result = economy.trade_flour_for_coins(flour_to_sell)

	print("   Result:")
	print("   • Measured: %s state" % result["measurement"].to_upper())
	print("   • Rate: %d credits/flour" % result["rate_achieved"])
	print("   • Total: %d credits" % result["credits_received"])
	print("   • Market theta: %.2f° → %.2f°" % [
		result["new_theta"] * 180.0 / PI + (flour_to_sell * 0.01 * 180.0 / PI),
		result["new_theta"] * 180.0 / PI
	])
	print()


func _cycle_3_guild_response(economy: EconomicBiome):
	"""Cycle 3: Show guilds responding to market change"""
	print("🏢 Guild Market Adjustment:\n")

	# Guilds perceive the flour scarcity from previous cycle
	# and will apply pressure
	print("   Guilds detect market conditions from player trading")
	print("   Analyzing flour availability...")
	print()

	var market_state = economy.get_market_state()
	print("   Current P(flour): %.1f%%" % [market_state["flour_probability"] * 100])

	if market_state["flour_probability"] < 0.3:
		print("   → Flour SCARCE: Guilds push market to encourage flour production")
	elif market_state["flour_probability"] > 0.7:
		print("   → Flour ABUNDANT: Guilds push market to discourage flour production")
	else:
		print("   → Flour at equilibrium: Guilds maintain balance")

	print()


func _cycle_4_mill_injection(economy: EconomicBiome):
	"""Cycle 4: Mill produces flour"""
	print("🏭 Mill Production Phase:\n")

	var flour_produced = 150
	print("   Mill producing %d flour..." % flour_produced)

	var injection = economy.inject_flour_from_mill(flour_produced)

	print("   Market response:")
	print("   • Flour injected, theta pushed toward abundance")
	print("   • New theta: %.2f°" % [injection["new_theta"] * 180.0 / PI])
	print("   • New P(flour): %.1f%%" % [injection["flour_probability"] * 100])
	print()


func _cycle_5_feedback_loop(economy: EconomicBiome):
	"""Cycle 5: Show complete feedback loop"""
	print("🔄 Complete Feedback Loop:\n")

	# Drain more bread
	for i in range(2):
		economy.drain_bread_energy()

	var bread_energy = bread_qubit.radius
	var guild_status = economy.get_guild_status()
	var market_state = economy.get_market_state()

	print("   Bread status: %.2f (guild storage: %.2f)" % [
		bread_energy,
		guild_status["storage_level"]
	])
	print("   Market state: %.2f° (P(flour): %.1f%%)" % [
		market_state["theta_degrees"],
		market_state["flour_probability"] * 100
	])
	print()

	# Show the logic
	print("   Logic Flow:")
	print("   1. Player trading → Market theta shifts")
	print("   2. Guild perceives theta change → Applies counter-pressure")
	print("   3. Guilds consume bread → Storage level drops")
	print("   4. Low storage → Guild pushes for bread production")
	print("   5. Player responds to market signals → Trades again")
	print("   → Self-correcting boom/bust cycle emerges!")
	print()


func print_summary(economy: EconomicBiome, bread: DualEmojiQubit):
	"""Print final summary"""
	print(print_sep())
	print("FINAL ECONOMIC STATE")
	print(print_sep() + "\n")

	var market_state = economy.get_market_state()
	var guild_status = economy.get_guild_status()

	print("🍞 Bread System:")
	print("   Energy: %.2f" % bread.radius)
	print()

	print("🏢 Guild Biome:")
	print("   Storage: %.2f" % guild_status["storage_level"])
	print("   Flour satisfaction: %.1f%%" % [guild_status["flour_satisfaction"] * 100])
	print("   Wheat reserves: %.1f%%" % [guild_status["wheat_reserves"] * 100])
	print("   Water reserves: %.1f%%" % [guild_status["water_reserves"] * 100])
	print()

	print("💰 Market State:")
	print("   Theta: %.2f°" % market_state["theta_degrees"])
	print("   P(flour): %.1f%%" % [market_state["flour_probability"] * 100])
	print("   P(coins): %.1f%%" % [market_state["coins_probability"] * 100])
	print("   Energy: %.2f" % market_state["energy"])
	print()

	print("💡 System Properties:")
	print("   • Market is quantum (measurement-based)")
	print("   • Guilds are quantum projections (pure effects, no resources)")
	print("   • Bread is the bridge (kitchen produces → guilds consume)")
	print("   • Flour is the medium (player produces → market trades)")
	print("   • Boom/bust cycles emerge from feedback loop")
	print()
