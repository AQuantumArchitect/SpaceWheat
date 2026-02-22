#!/usr/bin/env godot-script
## Simple test to verify FarmView and QuantumInstrument load without errors.
## After the QuantumInstrument refactor, FarmInputHandler is gone.
## Keyboard adapter is now QuantumInstrumentInput; game mechanics API is QuantumInstrument.
extends SceneTree

func _initialize():
	print("\n" + "=".repeat(70))
	print("Testing FarmView Loading...")
	print("=".repeat(70))

	# Try loading FarmView
	print("\n1. Attempting to load FarmView.gd...")
	var FarmView = preload("res://UI/FarmView.gd")
	if FarmView:
		print("   PASS: FarmView class loaded successfully")
	else:
		print("   FAIL: FarmView class failed to load")
		quit(1)
		return

	# Try loading core UI components
	print("\n2. Attempting to load keyboard components...")
	var ToolSelectionRow = preload("res://UI/Panels/ToolSelectionRow.gd")
	var ActionPreviewRow = preload("res://UI/Panels/ActionPreviewRow.gd")
	var OverlayManager = preload("res://UI/Managers/OverlayManager.gd")

	if ToolSelectionRow and ActionPreviewRow and OverlayManager:
		print("   PASS: All keyboard components loaded successfully")
	else:
		print("   FAIL: Some components failed to load")
		quit(1)
		return

	# Try loading core game mechanics layer (QuantumInstrument refactor)
	print("\n3. Attempting to load FarmView dependencies...")
	var Farm = preload("res://Core/Farm.gd")
	var QuantumInstrumentInput = preload("res://UI/Core/QuantumInstrumentInput.gd")
	var QuantumInstrument = preload("res://Core/Instrumentation/QuantumInstrument.gd")

	if not Farm:
		print("   FAIL: Core/Farm.gd failed to load")
		quit(1)
		return
	print("   PASS: Farm loaded")

	if not QuantumInstrumentInput:
		print("   FAIL: UI/Core/QuantumInstrumentInput.gd failed to load")
		quit(1)
		return
	print("   PASS: QuantumInstrumentInput (keyboard adapter) loaded")

	if not QuantumInstrument:
		print("   FAIL: Core/Instrumentation/QuantumInstrument.gd failed to load")
		quit(1)
		return
	print("   PASS: QuantumInstrument (game mechanics API) loaded")

	# Verify QuantumInstrument can be instantiated (extends RefCounted)
	print("\n4. Verifying QuantumInstrument instantiation...")
	var instrument = QuantumInstrument.new()
	if not instrument:
		print("   FAIL: QuantumInstrument.new() returned null")
		quit(1)
		return
	if not instrument.has_method("action_explore"):
		print("   FAIL: QuantumInstrument missing action_explore() method")
		quit(1)
		return
	if not instrument.has_method("probe_cycle"):
		print("   FAIL: QuantumInstrument missing probe_cycle() method")
		quit(1)
		return
	print("   PASS: QuantumInstrument instantiated with correct API")

	print("\n" + "=".repeat(70))
	print("SUCCESS: All components loaded without parse errors!")
	print("=".repeat(70))

	quit(0)
