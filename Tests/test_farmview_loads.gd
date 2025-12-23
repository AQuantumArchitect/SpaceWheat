#!/usr/bin/env godot-script
## Simple test to verify FarmView loads without errors
extends Node

func _ready():
	print("\n" + "="*70)
	print("🧪 Testing FarmView Loading...")
	print("="*70)

	# Try loading FarmView
	print("\n1️⃣  Attempting to load FarmView.gd...")
	var FarmView = preload("res://UI/FarmView.gd")
	if FarmView:
		print("   ✅ FarmView class loaded successfully")
	else:
		print("   ❌ FarmView class failed to load")
		get_tree().quit(1)
		return

	# Try loading all the components
	print("\n2️⃣  Attempting to load keyboard components...")
	var ToolSelectionRow = preload("res://UI/Panels/ToolSelectionRow.gd")
	var ActionPreviewRow = preload("res://UI/Panels/ActionPreviewRow.gd")
	var KeyboardHintButton = preload("res://UI/Panels/KeyboardHintButton.gd")
	var OverlayManager = preload("res://UI/Managers/OverlayManager.gd")

	if ToolSelectionRow and ActionPreviewRow and KeyboardHintButton and OverlayManager:
		print("   ✅ All keyboard components loaded successfully")
	else:
		print("   ❌ Some components failed to load")
		get_tree().quit(1)
		return

	# Try loading all dependencies
	print("\n3️⃣  Attempting to load FarmView dependencies...")
	var Farm = preload("res://Core/Farm.gd")
	var FarmInputHandler = preload("res://UI/FarmInputHandler.gd")
	var UILayoutManager = preload("res://UI/Managers/UILayoutManager.gd")

	if Farm and FarmInputHandler and UILayoutManager:
		print("   ✅ All FarmView dependencies loaded successfully")
	else:
		print("   ❌ Some dependencies failed to load")
		get_tree().quit(1)
		return

	print("\n" + "="*70)
	print("✅ SUCCESS: All components loaded without parse errors!")
	print("="*70 + "\n")

	get_tree().quit(0)
