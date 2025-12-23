#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: Market Qubit Measurement System
##
## Demonstrates:
## 1. Market in quantum superposition (🌾,💰)
## 2. MEASUREMENT collapses market to classical state
## 3. Exchange rate determined by collapse outcome
## 4. Trading injects supply, moves theta
## 5. Next measurement has different probabilities

const MarketQubit = preload("res://Core/GameMechanics/MarketQubit.gd")

var market: MarketQubit

func _initialize():
	print("\n" + print_line("=", 80))
	print("🔬 MARKET QUBIT MEASUREMENT TEST")
	print("Quantum Market: (🌾 flour, 💰 coins) → Classical Trading")
	print(print_line("=", 80) + "\n")

	market = MarketQubit.new()

	_test_measurement_without_collapse()
	_test_single_trade()
	_test_market_dynamics()
	_test_boom_bust_cycle()

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


func _test_measurement_without_collapse():
	print(print_sep())
	print("TEST 1: MEASUREMENT PROBABILITIES (No Collapse Yet)")
	print(print_sep() + "\n")

	print("📊 Market starts in balanced superposition (θ = π/2):\n")

	var probs = market.get_measurement_probabilities()
	print("  Probability(flour abundant): %.1f%%" % [probs["flour"] * 100])
	print("  Probability(coins abundant): %.1f%%" % [probs["coins"] * 100])
	print("  Theta: %.2f rad (%.0f°)" % [probs["theta"], probs["theta"] * 180 / PI])
	print("  Market Energy (radius): %.2f\n" % probs["energy"])

	print("📈 Exchange Rate Expectations (for 100 flour):\n")

	var rates = market.get_exchange_rate_for_flour(100)
	print("  Best case (coins measured):  100 flour → %d credits" % rates["best_case"])
	print("  Expected value:             100 flour → %d credits" % rates["expected_credits"])
	print("  Worst case (flour measured): 100 flour → %d credits" % rates["worst_case"])
	print()


func _test_single_trade():
	print(print_sep())
	print("TEST 2: SINGLE TRADE (Measurement → Collapse → Exchange)")
	print(print_sep() + "\n")

	print("📍 Scenario: Player has 100 flour, wants to sell\n")

	# Before trade: show what COULD happen
	print("⚡ BEFORE TRADE:\n")
	var probs_before = market.get_measurement_probabilities()
	print("  Market state: P(flour)=%.1f%%, P(coins)=%.1f%%" % [
		probs_before["flour"] * 100,
		probs_before["coins"] * 100
	])

	var rates_before = market.get_exchange_rate_for_flour(100)
	print("  Range: %d - %d credits per flour\n" % [
		rates_before["worst_case_rate"],
		rates_before["best_case_rate"]
	])

	# Execute trade
	print("⚙️  EXECUTING TRADE:\n")
	var result = market.trade_flour_for_coins(100)

	print("\n✓ TRADE RESULT:\n")
	print("  Measurement collapsed to: %s state" % result["measurement"])
	print("  Exchange rate achieved: %d credits/flour" % result["rate_achieved"])
	print("  Total credits received: %d" % result["credits_received"])
	print("  P(flour) was: %.1f%%" % [result["flour_probability"] * 100])
	print()

	# After trade: show how market moved
	print("⚡ AFTER TRADE:\n")
	var probs_after = market.get_measurement_probabilities()
	print("  Market theta moved: %.2f → %.2f rad" % [
		probs_before["theta"],
		probs_after["theta"]
	])
	print("  Market state now: P(flour)=%.1f%%, P(coins)=%.1f%%" % [
		probs_after["flour"] * 100,
		probs_after["coins"] * 100
	])
	print("  Energy: %.2f → %.2f" % [probs_before["energy"], probs_after["energy"]])
	print()

	print("💡 INSIGHT: Selling flour pushed market toward coins-abundant!\n")


func _test_market_dynamics():
	print(print_sep())
	print("TEST 3: MARKET DYNAMICS (Multiple Measurements)")
	print(print_sep() + "\n")

	# Reset to fresh market
	market.reset_to_balanced()

	print("📍 Scenario: Measure market 10 times without trading\n")
	print("Measurement │ Outcome │ P(flour) │ Would Collapse Suggests")
	print(print_line("─", 78))

	var flour_count = 0
	var coins_count = 0

	for i in range(10):
		var outcome = market.measure_market()

		var probs = market.get_measurement_probabilities()
		var flour_prob = probs["flour"]

		if outcome == "flour":
			flour_count += 1
		else:
			coins_count += 1

		print("     %d        │  %-6s │  %.1f%%   │ Abundance: %s" % [
			i + 1,
			outcome,
			flour_prob * 100,
			outcome.to_upper()
		])

	print()
	print("Summary: %d flour, %d coins out of 10 measurements" % [flour_count, coins_count])
	print("Expected: ~5 of each (balanced market)")
	print()


func _test_boom_bust_cycle():
	print(print_sep())
	print("TEST 4: BOOM/BUST CYCLE (Market Movements)")
	print(print_sep() + "\n")

	# Reset
	market.reset_to_balanced()

	print("📍 Scenario: Watch market boom/bust cycle\n")
	print("Step │ Action             │ Theta  │ P(flour) │ P(coins) │ Rate for 50🌾")
	print(print_line("─", 80))

	# Initial state
	var state = market.get_market_state()
	var initial_theta = state["theta"]
	var initial_flour = state["flour_probability"]
	var initial_coins = state["coins_probability"]

	var rate = market.get_exchange_rate_for_flour(50)
	print("  0   │ Market balanced    │ %.2f   │  %.1f%%   │  %.1f%%   │ ~%d credits" % [
		initial_theta,
		initial_flour * 100,
		initial_coins * 100,
		rate["expected_credits"] / 50
	])

	# BOOM: Mill injects lots of flour
	print("\n🏭 BOOM: Mill produces 200 flour...")
	market.inject_flour_from_mill(200)

	state = market.get_market_state()
	rate = market.get_exchange_rate_for_flour(50)
	print("  1   │ Mill injected 200🌾│ %.2f   │  %.1f%%   │  %.1f%%   │ ~%d credits (↓)" % [
		state["theta"],
		state["flour_probability"] * 100,
		state["coins_probability"] * 100,
		rate["expected_credits"] / 50
	])

	# TRADING: Players sell flour
	print("\n💰 TRADING: Players sell 150 flour...")
	for i in range(3):
		market.trade_flour_for_coins(50)

	state = market.get_market_state()
	rate = market.get_exchange_rate_for_flour(50)
	print("  2   │ Sold 150 flour     │ %.2f   │  %.1f%%   │  %.1f%%   │ ~%d credits (↑)" % [
		state["theta"],
		state["flour_probability"] * 100,
		state["coins_probability"] * 100,
		rate["expected_credits"] / 50
	])

	# RECOVERY: Coins still abundant, but trading swung market
	print("\n📊 OBSERVATION: Self-correcting market!\n")
	print("  • Mill injection → flour cheap")
	print("  • Players sell flour → coins flood in")
	print("  • Trading overcorrects → coins now cheap")
	print("  • Next measurement will lean toward flour abundance again")
	print("  • Cycle repeats: boom → bust → boom\n")

	print("💡 MECHANISM: Exchange rate (sin²/cos²) IS the market signal!")
	print()


func print_state_vector(state: Dictionary):
	print("  Theta: %.2f (%.0f°)" % [state["theta"], state["theta"] * 180 / PI])
	print("  P(flour): %.1f%%" % [state["flour_probability"] * 100])
	print("  P(coins): %.1f%%" % [state["coins_probability"] * 100])
	print("  Energy: %.2f" % state["energy"])
