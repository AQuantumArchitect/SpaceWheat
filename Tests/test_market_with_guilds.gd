#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: Market with Granary Guilds Integration
##
## Demonstrates:
## 1. Bread qubit created in market
## 2. Guilds constantly drain bread energy
## 3. Guild supply monitoring and market pressure
## 4. Player trading flour in response to guild-affected market
## 5. Feedback loop: guild consumption → market pressure → player response → supply adjustment

const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const MarketQubit = preload("res://Core/GameMechanics/MarketQubit.gd")
const GranaryGuilds_MarketProjection_Biome = preload("res://Core/Environment/GranaryGuilds_MarketProjection_Biome.gd")

var market: MarketQubit
var guilds: GranaryGuilds_MarketProjection_Biome
var bread_qubit: DualEmojiQubit

var simulation_time: float = 0.0
var simulation_steps: int = 0

func _initialize():
	print("\n" + print_line("=", 80))
	print("🏢💰 MARKET WITH GRANARY GUILDS INTEGRATION TEST")
	print("Market Measurement + Guild Consumption + Player Response")
	print(print_line("=", 80) + "\n")

	# Initialize components
	market = MarketQubit.new()
	guilds = GranaryGuilds_MarketProjection_BioticFluxBiome.new()

	# Create bread qubit (🍞, 👥) - guilds will drain this
	bread_qubit = DualEmojiQubit.new("🍞", "👥", PI / 2.0)
	bread_qubit.phi = 0.0
	bread_qubit.radius = 1.0  # Full bread energy

	print("📊 Initial State:\n")
	print("   Bread energy: %.2f" % bread_qubit.radius)
	print("   Bread theta: %.2f rad (%.0f°)\n" % [
		bread_qubit.theta,
		bread_qubit.theta * 180.0 / PI
	])

	_simulate_integrated_gameplay()

	print(print_line("=", 80))
	print("✅ INTEGRATION TEST COMPLETE")
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


func _simulate_integrated_gameplay():
	"""
	Simulate economic cycle:
	1. Guilds drain bread
	2. Guilds check supply levels
	3. Guilds apply pressure to market
	4. Player observes market pressure (flour expensive → bread must be scarce)
	5. Player injects flour by selling
	6. Market responds to injection
	7. Repeat
	"""

	print(print_sep())
	print("CYCLE 1: INITIAL STATE - BALANCED MARKET")
	print(print_sep() + "\n")

	# Step 1: Show initial market state
	var market_state = market.get_market_state()
	print("📊 Market Status:\n")
	print("   Theta: %.2f° (θ = %.2f rad)" % [
		market_state["theta_degrees"],
		market_state["theta"]
	])
	print("   P(flour): %.1f%%" % [market_state["flour_probability"] * 100])
	print("   P(coins): %.1f%%" % [market_state["coins_probability"] * 100])
	print("   Energy: %.2f\n" % market_state["energy"])

	# Step 2: Guilds drain bread
	print("🏢 Guild Activity:\n")
	print("   Guilds draining bread energy...")
	var drain_result = guilds.drain_bread_energy(bread_qubit)
	print("   Drained: %.3f energy" % drain_result["drained"])
	print("   Remaining: %.2f (was %.2f)" % [
		bread_qubit.radius,
		drain_result["remaining_radius"]
	])
	print("   Storage filled: %.2f\n" % drain_result["storage_level"])

	# Step 3: Player has flour to sell
	print("💰 Trading Phase:\n")
	var flour_to_sell = 100
	print("   Player has %d flour from harvesting" % flour_to_sell)

	var rate_preview = market.get_exchange_rate_for_flour(flour_to_sell)
	print("   Could get: %d - %d credits" % [
		rate_preview["worst_case"],
		rate_preview["best_case"]
	])
	print()

	# Execute trade
	var trade1 = market.trade_flour_for_coins(flour_to_sell)
	print("   ✓ Sold %d flour for %d credits (rate: %d/flour)" % [
		trade1["flour_sold"],
		trade1["credits_received"],
		trade1["rate_achieved"]
	])
	print()

	# Step 4: Guild perceives market change and applies pressure
	print("🏢 Guild Market Response:\n")
	var guild_pressure = guilds.apply_guild_pressure_to_market(market.market_qubit)
	print("   Flour probability was: %.1f%%" % [guild_pressure["flour_prob"] * 100])
	print("   Guild target: %.1f%%" % [guild_pressure["target"] * 100])
	print("   Pressure applied: %.4f" % guild_pressure["pressure_applied"])
	print("   Guild storage now: %.2f\n" % guild_pressure["storage_level"])

	# Show market after guild pressure
	var market_after = market.get_market_state()
	print("   Market theta after guild pressure: %.2f°" % market_after["theta_degrees"])
	print()

	# Second cycle: More aggressive guild consumption
	print(print_sep())
	print("CYCLE 2: GUILDS HUNGRY - BREAD SCARCE")
	print(print_sep() + "\n")

	print("🏢 Guild Consumption (No Player Action):\n")

	# Drain more bread (simulate passage of time)
	for i in range(3):
		guilds.drain_bread_energy(bread_qubit)

	print("   Guilds drain aggressively (3 pulses)")
	print("   Bread energy: %.2f (storage: %.2f)" % [
		bread_qubit.radius,
		guilds.storage_icon.radius
	])
	print()

	# Check if guild storage is empty and they push for bread production
	print("🏢 Guild Status Check:\n")
	var guild_status = guilds.get_guild_status()
	print("   Storage level: %.2f" % guild_status["storage_level"])
	print("   Flour satisfaction: %.1f%%" % [guild_status["flour_satisfaction"] * 100])
	print("   Consumption rate: %.2f" % guild_status["consumption_rate"])
	print()

	if guild_status["storage_level"] < 0.3:
		print("   ⚠️  Guild storage EMPTY - will push market to encourage bread!")
	elif guild_status["storage_level"] > 0.7:
		print("   ⚠️  Guild storage FULL - will suppress bread value!")
	else:
		print("   ✓ Guild storage at comfortable level\n")

	# Step: Guild applies pressure again
	var guild_pressure_2 = guilds.apply_guild_pressure_to_market(market.market_qubit)
	print("   New market theta: %.2f°\n" % [market.get_market_state()["theta_degrees"]])

	# Third cycle: Shows self-correcting mechanism
	print(print_sep())
	print("CYCLE 3: MARKET DYNAMICS - RICH/POOR CYCLES")
	print(print_sep() + "\n")

	# Reset market to show dramatic swing
	print("📊 Market Observation:\n")

	var measurements_summary = market.measurement_history.slice(-3)
	if measurements_summary.size() > 0:
		print("   Recent measurements:")
		for i in range(measurements_summary.size()):
			var m = measurements_summary[i]
			print("   • Measurement %d: %s (P(flour)=%.1f%%)" % [
				i + 1,
				m["outcome"].to_upper(),
				m["flour_prob"] * 100
			])
	print()

	# Final state
	print(print_sep())
	print("INTEGRATION SUMMARY")
	print(print_sep() + "\n")

	var final_market = market.get_market_state()
	var final_guild = guilds.get_guild_status()

	print("🍞 Bread System:")
	print("   Qubit energy: %.2f" % bread_qubit.radius)
	print("   Qubit theta: %.2f°" % [bread_qubit.theta * 180.0 / PI])
	print()

	print("🏢 Guild Biome:")
	print("   Storage: %.2f" % final_guild["storage_level"])
	print("   Flour satisfaction: %.1f%%" % [final_guild["flour_satisfaction"] * 100])
	print("   Wheat reserves: %.1f%%" % [final_guild["wheat_reserves"] * 100])
	print("   Water reserves: %.1f%%" % [final_guild["water_reserves"] * 100])
	print()

	print("💰 Market State:")
	print("   Theta: %.2f°" % final_market["theta_degrees"])
	print("   P(flour): %.1f%%" % [final_market["flour_probability"] * 100])
	print("   P(coins): %.1f%%" % [final_market["coins_probability"] * 100])
	print("   Energy: %.2f" % final_market["energy"])
	print()

	print("💡 Key Insights:")
	print("   1. Guilds drain bread, creating constant demand")
	print("   2. Guild storage level determines market pressure (theta adjustment)")
	print("   3. Player trades flour in response to market conditions")
	print("   4. Trading injection shifts market theta away from flour")
	print("   5. Guild consumption creates natural boom/bust cycle")
	print("   6. Market measurement probability drives player decision timing")
	print()

	print("🔄 Feedback Loop:")
	print("   Guilds drain 🍞 → Low storage → Push market toward bread prices")
	print("   → Player sees bread value rising (coins abundant state)")
	print("   → Player trades flour for coins → Market swings to coins-abundant")
	print("   → Guilds see flour scarce, push market up again")
	print("   → Cycle repeats with natural self-correction")
	print()


func print_market_state(state: Dictionary, label: String = ""):
	if label:
		print("%s" % label)
	print("   Theta: %.2f° (P(flour)=%.1f%%, P(coins)=%.1f%%)" % [
		state["theta_degrees"],
		state["flour_probability"] * 100,
		state["coins_probability"] * 100
	])
	print("   Energy: %.2f" % state["energy"])
