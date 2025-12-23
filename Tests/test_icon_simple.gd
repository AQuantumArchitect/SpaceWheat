#!/usr/bin/env -S godot -s --headless
extends SceneTree

## Minimal Icon test - just verify BioticFluxIcon loads

func _ready() -> void:
	print("\n=== Testing BioticFluxIcon Load ===\n")

	# Test: Load BioticFluxIcon directly
	print("Loading BioticFluxIcon...")
	var script = load("res://Core/Icons/BioticFluxIcon.gd")

	if script == null:
		print("❌ FAILED to load script")
		quit()
		return

	print("✓ BioticFluxIcon.gd loaded")

	# Try to create instance
	print("Creating instance...")
	var icon = script.new()

	if icon == null:
		print("❌ FAILED to create instance")
		quit()
		return

	print("✓ BioticFluxIcon instance created")

	# Test activation
	print("Testing activation...")
	icon.set_activation(0.5)
	var activation = icon.get_activation()
	print("✓ Activation set to %.2f" % activation)

	# Check temperature method exists
	if icon.has_method("get_effective_temperature"):
		var temp = icon.get_effective_temperature()
		print("✓ Temperature at 50%% activation: %.1fK" % temp)
	else:
		print("❌ Missing get_effective_temperature method")
		quit()
		return

	print("\n✅ SUCCESS: BioticFluxIcon loads and works!")
	quit()
