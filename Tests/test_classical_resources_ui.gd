#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test classical resources (credits, flour) display in UI

const FarmUIState = preload("res://Core/GameState/FarmUIState.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")

func _initialize():
	print("🧪 Testing classical resources UI integration...\n")

	# Test 1: FarmUIState has credits and flour fields
	print("Test 1: FarmUIState has credits and flour fields")
	var ui_state = FarmUIState.new()
	assert(ui_state.wheat == 100, "Default wheat should be 100")
	assert(ui_state.credits == 50, "Default credits should be 50")
	assert(ui_state.flour == 0, "Default flour should be 0")
	print("  ✅ Fields initialized correctly\n")

	# Test 2: Economy update propagates to ui_state
	print("Test 2: Economy update propagates to ui_state")
	var economy = FarmEconomy.new()
	economy.wheat_inventory = 150
	economy.credits = 100
	economy.flour_inventory = 8

	ui_state.update_economy(economy)
	assert(ui_state.wheat == 150, "Wheat should be 150 after update")
	assert(ui_state.credits == 100, "Credits should be 100 after update")
	assert(ui_state.flour == 8, "Flour should be 8 after update")
	print("  ✅ Economy update propagates correctly\n")

	# Test 3: Credits changed signal emitted
	print("Test 3: Credits changed signal emitted")
	var credits_signal_received = false
	var received_credits = 0
	ui_state.credits_changed.connect(func(amt):
		credits_signal_received = true
		received_credits = amt
		print("    DEBUG: credits_changed signal received with amount %d" % amt)
	)

	print("  DEBUG: Current credits before update: %d" % ui_state.credits)
	economy.credits = 200
	print("  DEBUG: Setting economy.credits to 200")
	ui_state.update_economy(economy)
	print("  DEBUG: Credits after update: %d, signal received: %s" % [ui_state.credits, credits_signal_received])

	assert(credits_signal_received, "Credits changed signal should emit")
	assert(received_credits == 200, "Signal should pass correct credits amount")
	print("  ✅ Credits signal emitted correctly\n")

	# Test 4: Flour changed signal emitted
	print("Test 4: Flour changed signal emitted")
	var flour_signal_received = false
	var received_flour = 0
	ui_state.flour_changed.connect(func(amt):
		flour_signal_received = true
		received_flour = amt
	)

	economy.flour_inventory = 16
	ui_state.update_economy(economy)
	assert(flour_signal_received, "Flour changed signal should emit")
	assert(received_flour == 16, "Signal should pass correct flour amount")
	print("  ✅ Flour signal emitted correctly\n")

	# Test 5: No signal emitted if value unchanged
	print("Test 5: No signal emitted if value unchanged")
	credits_signal_received = false
	flour_signal_received = false

	economy.credits = 200  # Same value
	economy.flour_inventory = 16  # Same value
	ui_state.update_economy(economy)
	assert(!credits_signal_received, "Signal should not emit for unchanged credits")
	assert(!flour_signal_received, "Signal should not emit for unchanged flour")
	print("  ✅ Signals correctly suppress unchanged values\n")

	var sep = ""
	for i in range(70):
		sep += "="

	print(sep)
	print("✅ ALL TESTS PASSED - Classical Resources UI Integration Working!")
	print(sep)

	quit()
