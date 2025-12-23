#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Simplified test for classical resources UI integration

const FarmUIState = preload("res://Core/GameState/FarmUIState.gd")

func _initialize():
	print("🧪 Testing classical resources UI integration (simplified)...\n")

	# Test 1: FarmUIState has credits and flour fields
	print("Test 1: FarmUIState has credits and flour fields")
	var ui_state = FarmUIState.new()
	assert(ui_state.wheat == 100, "Default wheat should be 100")
	assert(ui_state.credits == 50, "Default credits should be 50")
	assert(ui_state.flour == 0, "Default flour should be 0")
	print("  ✅ Fields initialized correctly\n")

	# Test 2: Manual update
	print("Test 2: Manual update of credits and flour")
	ui_state.credits = 100
	ui_state.flour = 8
	assert(ui_state.credits == 100, "Credits should be 100")
	assert(ui_state.flour == 8, "Flour should be 8")
	print("  ✅ Manual update works\n")

	# Test 3: Signals exist (by checking signal list)
	print("Test 3: Signals exist in FarmUIState")
	var signals = ui_state.get_signal_list()
	var has_credits_signal = false
	var has_flour_signal = false

	for sig in signals:
		if sig.name == "credits_changed":
			has_credits_signal = true
		if sig.name == "flour_changed":
			has_flour_signal = true

	assert(has_credits_signal, "credits_changed signal should exist")
	assert(has_flour_signal, "flour_changed signal should exist")
	print("  ✅ Signals defined correctly\n")

	var sep = ""
	for i in range(70):
		sep += "="

	print(sep)
	print("✅ ALL TESTS PASSED - Classical Resources Fields & Signals Working!")
	print(sep)

	quit()
