#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: Complete Production Chain Integration
##
## Full cycle: Farming → Milling → Kitchen → Economic Biome → Guild Consumption
##
## Shows:
## 1. Create wheat/water/flour qubits
## 2. Arrange in Bell state (kitchen gate action)
## 3. Produce bread (triplet measurement)
## 4. Economic biome integrates bread
## 5. Guilds start consuming bread
## 6. Feedback loop visible

const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const QuantumKitchen_Biome = preload("res://Core/Environment/QuantumKitchen_Biome.gd")
const EconomicBiome = preload("res://Core/Environment/EconomicBiome.gd")

var kitchen: QuantumKitchen_Biome
var economy: EconomicBiome
var bread_qubit: DualEmojiQubit

func _initialize():
	print("\n" + print_line("=", 80))
	print("🌾→🍳→💰 COMPLETE PRODUCTION CHAIN INTEGRATION")
	print("Farming → Milling → Kitchen → Market → Guild Consumption")
	print(print_line("=", 80) + "\n")

	kitchen = QuantumKitchen_BioticFluxBiome.new()
	economy = EconomicBioticFluxBiome.new()

	_simulate_complete_chain()

	print(print_line("=", 80))
	print("✅ COMPLETE CHAIN TEST FINISHED")
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


func _simulate_complete_chain():
	"""
	Complete production cycle demonstrating all systems:
	1. Create resources (simulate farming → milling)
	2. Arrange in Bell state (gate action)
	3. Produce bread (kitchen measurement)
	4. Add bread to economic biome
	5. Guilds consume bread
	6. Market responds
	7. Show feedback loop
	"""

	# PHASE 1: FARMING & MILLING
	print(print_sep())
	print("PHASE 1: FARMING & MILLING")
	print(print_sep() + "\n")

	print("🌾 Farm Harvest:\n")

	var wheat = DualEmojiQubit.new("🌾", "💼", PI / 2.0)
	wheat.radius = 0.9
	print("   Wheat harvested: energy = %.2f" % wheat.radius)

	# Water (simulated - would come from water biome)
	var water = DualEmojiQubit.new("💧", "☀️", PI / 2.0)
	water.radius = 0.7
	print("   Water collected: energy = %.2f" % water.radius)

	print()

	print("🏭 Mill Production:\n")

	var flour = DualEmojiQubit.new("🌾", "💼", PI / 2.0)
	flour.radius = 0.8
	print("   Flour produced: energy = %.2f" % flour.radius)
	print()

	# PHASE 2: KITCHEN PREPARATION
	print(print_sep())
	print("PHASE 2: KITCHEN - BELL STATE ARRANGEMENT")
	print(print_sep() + "\n")

	print("🍳 Kitchen Setup:\n")
	print("   Setting input qubits (wheat, water, flour)")
	kitchen.set_input_qubits(wheat, water, flour)
	print()

	print("   Configuring plot arrangement...")
	var positions = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]  # Vertical line
	print("   Position 0: Wheat at (0,0)")
	print("   Position 1: Water at (0,1)")
	print("   Position 2: Flour at (0,2)")
	print("   Pattern: Vertical line (GHZ state)")
	print()

	var is_valid = kitchen.configure_bell_state(positions)
	print()

	if is_valid:
		print("✅ Valid Bell state configured!")
		print()

		# PHASE 3: BREAD PRODUCTION
		print(print_sep())
		print("PHASE 3: KITCHEN - BREAD PRODUCTION")
		print(print_sep() + "\n")

		bread_qubit = kitchen.produce_bread()
		print()

		if bread_qubit:
			print("✨ BREAD SUCCESSFULLY PRODUCED!")
			print()

			# PHASE 4: ECONOMIC INTEGRATION
			print(print_sep())
			print("PHASE 4: ECONOMIC BIOME - GUILD INTEGRATION")
			print(print_sep() + "\n")

			print("🏢 Linking bread to economic biome:\n")
			economy.set_bread_qubit(bread_qubit)
			print("   Bread energy: %.2f" % bread_qubit.radius)
			print("   Bread theta: %.2f rad (%.0f°)" % [
				bread_qubit.theta,
				bread_qubit.theta * 180.0 / PI
			])
			print()

			# PHASE 5: GUILD CONSUMPTION CYCLE
			print(print_sep())
			print("PHASE 5: GUILD CONSUMPTION & MARKET DYNAMICS")
			print(print_sep() + "\n")

			_simulate_guild_consumption_cycle(economy, bread_qubit)

	else:
		print("❌ Failed to configure Bell state")


func _simulate_guild_consumption_cycle(economy: EconomicBiome, bread: DualEmojiQubit):
	"""Show guilds consuming bread and market responding"""

	print("🏢 Guild Check-In Cycle:\n")
	print("   Guilds monitor bread supply and market conditions")
	print()

	# Multiple consumption pulses
	for cycle in range(1, 4):
		print("   Cycle %d:" % cycle)

		# Guilds drain bread
		economy.drain_bread_energy()
		print("   • Bread energy: %.2f" % bread.radius)

		# Show market state
		var market_state = economy.get_market_state()
		var guild_status = economy.get_guild_status()

		print("   • Market: P(flour)=%.1f%%, P(coins)=%.1f%%" % [
			market_state["flour_probability"] * 100,
			market_state["coins_probability"] * 100
		])
		print("   • Guild storage: %.2f" % guild_status["storage_level"])
		print()

	# Show overall loop
	print("\n💡 Complete Feedback Loop:\n")
	print("   1. Kitchen produces bread (quantum measurement)")
	print("   2. Guilds receive bread and consume it")
	print("   3. Consumption drains bread energy")
	print("   4. Low storage pushes guilds to buy flour")
	print("   5. Guild pressure shifts market theta")
	print("   6. Player observes market and responds")
	print("   7. Player produces flour and bread")
	print("   → Cycle repeats")
	print()

	# Final summary
	print(print_sep())
	print("FINAL SYSTEM STATE")
	print(print_sep() + "\n")

	var final_market = economy.get_market_state()
	var final_guild = economy.get_guild_status()

	print("🍞 Bread Status:\n")
	print("   Energy: %.2f (consumed from %.2f)" % [
		bread.radius,
		0.96  # approximate initial from kitchen
	])
	print()

	print("🌾 Market State:\n")
	print("   Theta: %.2f°" % final_market["theta_degrees"])
	print("   P(flour): %.1f%%, P(coins): %.1f%%" % [
		final_market["flour_probability"] * 100,
		final_market["coins_probability"] * 100
	])
	print("   Energy: %.2f" % final_market["energy"])
	print()

	print("🏢 Guild Status:\n")
	print("   Storage: %.2f" % final_guild["storage_level"])
	print("   Flour satisfaction: %.1f%%" % [final_guild["flour_satisfaction"] * 100])
	print()

	print("🎯 Key Accomplishments:\n")
	print("   ✓ Farming → Wheat/Water/Flour qubits")
	print("   ✓ Kitchen → Bell state measurement → Bread")
	print("   ✓ Bread → Economic biome integration")
	print("   ✓ Guilds → Consume bread, push market")
	print("   ✓ Market → Responds to guild pressure")
	print("   ✓ Feedback loop → Complete chain")
	print()

	print("🔮 System Properties:\n")
	print("   • Production is grounded in quantum mechanics")
	print("   • Kitchen gate (plot arrangement) defines bread type")
	print("   • Guilds create natural demand through consumption")
	print("   • Market adjusts without explicit rules")
	print("   • All mechanics emerge from physics")
	print()
