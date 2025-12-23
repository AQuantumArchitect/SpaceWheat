#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Production Chain Test: Wheat → Mill → Flour → Market → Credits
## Demonstrates the complete economy flow

const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")

var economy: FarmEconomy

func _initialize():
	print("\n" + print_line(70))
	print("🌾 PRODUCTION CHAIN TEST: Wheat → Flour → Credits")
	print(print_line(70) + "\n")

	economy = FarmEconomy.new()

	print("📦 Starting State:")
	print("  Wheat: " + str(economy.wheat_inventory))
	print("  Flour: " + str(economy.flour_inventory))
	print("  Credits: " + str(economy.credits) + "\n")

	test_mill_processing()
	test_market_selling()
	test_full_chain()

	print("\n" + print_line(70))
	print("✅ PRODUCTION CHAIN TEST COMPLETE")
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


func test_mill_processing():
	print("\n" + print_sep())
	print("TEST 1: MILL PROCESSING (Wheat → Flour + Credits)")
	print(print_sep())

	print("\n📍 Starting state:")
	print("  Wheat: " + str(economy.wheat_inventory))
	print("  Flour: " + str(economy.flour_inventory))
	print("  Credits: " + str(economy.credits))

	# Mill 50 wheat
	print("\n📍 Milling 50 wheat...")
	var mill_result = economy.process_wheat_to_flour(50)

	print("\n✓ Mill result:")
	print("  Success: " + str(mill_result["success"]))
	print("  Wheat used: " + str(mill_result["wheat_used"]))
	print("  Flour produced: " + str(mill_result["flour_produced"]))
	print("  Credits earned: " + str(mill_result["credits_earned"]))

	print("\n📍 After milling:")
	print("  Wheat: " + str(economy.wheat_inventory) + " (was 100, milled 50)")
	print("  Flour: " + str(economy.flour_inventory) + " (50 wheat * 0.8 = 40)")
	print("  Credits: " + str(economy.credits) + " (started 50, +200 from mill = 250)")

	# Verify math
	var expected_flour = 40
	var expected_credits = 50 + 200  # 5 credits per flour * 40 flour
	var success = (economy.flour_inventory == expected_flour and economy.credits == expected_credits)

	if success:
		print("\n✅ MILL TEST PASSED")
	else:
		print("\n❌ MILL TEST FAILED")
		print("  Expected: flour=" + str(expected_flour) + ", credits=" + str(expected_credits))
		print("  Got: flour=" + str(economy.flour_inventory) + ", credits=" + str(economy.credits))


func test_market_selling():
	print("\n\n" + print_sep())
	print("TEST 2: MARKET SELLING (Flour → Credits)")
	print(print_sep())

	print("\n📍 Starting state:")
	print("  Flour: " + str(economy.flour_inventory))
	print("  Credits: " + str(economy.credits))

	# Sell 20 flour
	print("\n📍 Selling 20 flour at market...")
	var market_result = economy.sell_flour_at_market(20)

	print("\n✓ Market result:")
	print("  Success: " + str(market_result["success"]))
	print("  Flour sold: " + str(market_result["flour_sold"]))
	print("  Credits received: " + str(market_result["credits_received"]))
	print("  Market margin (20%): " + str(market_result["market_margin"]))

	# Market math: 20 flour * 100 = 2000 gross, 20% = 400 to market, 1600 to farmer
	var gross = 20 * 100
	var market_cut = int(gross * 0.20)
	var farmer_cut = gross - market_cut

	print("\n📍 Market price calculation:")
	print("  Flour price: 100 credits per unit")
	print("  Gross sale: 20 * 100 = " + str(gross))
	print("  Market margin (20%): " + str(market_cut))
	print("  Farmer receives: " + str(farmer_cut))

	print("\n📍 After selling:")
	print("  Flour: " + str(economy.flour_inventory) + " (was 40, sold 20)")
	print("  Credits: " + str(economy.credits) + " (was 250, +1600 from sale = 1850)")

	var success = (economy.flour_inventory == 20 and economy.credits == 1850)

	if success:
		print("\n✅ MARKET TEST PASSED")
	else:
		print("\n❌ MARKET TEST FAILED")
		print("  Expected: flour=20, credits=1850")
		print("  Got: flour=" + str(economy.flour_inventory) + ", credits=" + str(economy.credits))


func test_full_chain():
	print("\n\n" + print_sep())
	print("TEST 3: FULL PRODUCTION CHAIN (Wheat → Flour → Market → Credits)")
	print(print_sep())

	# Start fresh
	economy.wheat_inventory = 100
	economy.flour_inventory = 0
	economy.credits = 50

	print("\n📍 Starting state:")
	print("  Wheat: " + str(economy.wheat_inventory))
	print("  Flour: " + str(economy.flour_inventory))
	print("  Credits: " + str(economy.credits))

	print("\n📍 STEP 1: Harvest 100 wheat (already in inventory)")
	print("  Wheat: " + str(economy.wheat_inventory))

	print("\n📍 STEP 2: Mill 100 wheat → 80 flour + 400 credits")
	var mill_result = economy.process_wheat_to_flour(100)
	print("  Wheat: " + str(economy.wheat_inventory))
	print("  Flour: " + str(economy.flour_inventory))
	print("  Credits: " + str(economy.credits))

	print("\n📍 STEP 3: Sell 80 flour → 6400 credits")
	var market_result = economy.sell_flour_at_market(80)
	print("  Flour: " + str(economy.flour_inventory))
	print("  Credits: " + str(economy.credits))

	print("\n📍 FULL CHAIN SUMMARY:")
	print("  100 wheat → 80 flour (20% loss in milling)")
	print("  80 flour → 6400 credits")
	print("  Processing bonus: 400 credits")
	print("  Total credits earned: " + str(economy.credits - 50))
	print("  Final state: " + str(economy.wheat_inventory) + " wheat, 0 flour, " + str(economy.credits) + " credits")

	var final_credits = 50 + 400 + 6400  # Starting + mill bonus + market sale
	var success = (economy.wheat_inventory == 0 and economy.flour_inventory == 0 and economy.credits == final_credits)

	if success:
		print("\n✅ FULL CHAIN TEST PASSED")
		print("Economy is no longer cosmetic! Wheat → Credits flow is complete.")
	else:
		print("\n❌ FULL CHAIN TEST FAILED")
		print("  Expected: wheat=0, flour=0, credits=" + str(final_credits))
		print("  Got: wheat=" + str(economy.wheat_inventory) + ", flour=" + str(economy.flour_inventory) + ", credits=" + str(economy.credits))


func print_observation():
	print("\n\n" + print_line(70))
	print("💡 KEY OBSERVATION")
	print(print_line(70))
	print("""
The production chain FIXES the economy dead zone!

Before: Wheat → Harvest → Inventory (dead end)
After:  Wheat → Mill → Flour → Market → Credits

Economic flow:
1. Harvest quantum wheat from plots
2. Mill wheat into flour (80% efficiency, processing labor bonus)
3. Sell flour at market (market takes 20% margin)
4. Get classical credits to manage economy

This means:
- Credits now come from production, not arbitrary
- Players must choose: harvest more or mill faster
- Market prices create strategic decisions
- Next: Tributes can now meaningfully drain credits!
- Later: (🌾,💰) hybrid can sell directly to market for bonus

The game economy is now ALIVE.
""")
