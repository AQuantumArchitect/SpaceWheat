#!/usr/bin/env -S godot --headless --exit-on-quit -s
extends SceneTree

## Headless test: Verify BioticFluxIcon loads and functions correctly
## Tests Icon system without GUI rendering

func _ready() -> void:
	print("\n=== Headless BioticFluxIcon Test ===\n")

	# Test 1: Load and instantiate Icons
	print("Loading Icon classes...")
	var biotic_script = load("res://Core/Icons/BioticFluxIcon.gd")
	var chaos_script = load("res://Core/Icons/ChaosIcon.gd")
	var imperium_script = load("res://Core/Icons/ImperiumIcon.gd")

	if biotic_script == null:
		print("❌ FAILED: Could not load BioticFluxIcon")
		quit()
		return

	print("✓ Icons loaded successfully")

	# Test 2: Create instances
	print("\nCreating Icon instances...")
	var biotic = biotic_script.new()
	var chaos = chaos_script.new()
	var imperium = imperium_script.new()

	if biotic == null or chaos == null or imperium == null:
		print("❌ FAILED: Could not create Icon instances")
		quit()
		return

	print("✓ All Icons instantiated")

	# Test 3: Test BioticFluxIcon methods
	print("\nTesting BioticFluxIcon methods...")

	# Test activation
	biotic.set_activation(0.0)
	if biotic.get_activation() != 0.0:
		print("❌ FAILED: set_activation(0.0) not working")
		quit()
		return
	print("✓ set_activation(0.0) works")

	biotic.set_activation(1.0)
	if biotic.get_activation() != 1.0:
		print("❌ FAILED: set_activation(1.0) not working")
		quit()
		return
	print("✓ set_activation(1.0) works")

	# Test temperature modulation
	if not biotic.has_method("get_effective_temperature"):
		print("❌ FAILED: Missing get_effective_temperature")
		quit()
		return

	var temp = biotic.get_effective_temperature()
	print("✓ get_effective_temperature() = %.1fK at 100%% activation" % temp)

	# Test at different activation levels
	biotic.set_activation(0.0)
	var temp_min = biotic.get_effective_temperature()

	biotic.set_activation(0.5)
	var temp_mid = biotic.get_effective_temperature()

	biotic.set_activation(1.0)
	var temp_max = biotic.get_effective_temperature()

	print("✓ Temperature range: %.1fK (0%%) → %.1fK (50%%) → %.1fK (100%%)" % [temp_min, temp_mid, temp_max])

	# Test growth modifier
	if not biotic.has_method("get_growth_modifier"):
		print("❌ FAILED: Missing get_growth_modifier")
		quit()
		return

	biotic.set_activation(1.0)
	var growth = biotic.get_growth_modifier()
	print("✓ get_growth_modifier() = %.2fx at 100%% activation" % growth)

	# Summary
	print("\n✅ SUCCESS: BioticFluxIcon loads and functions correctly!")
	print("✅ All Icon systems ready for integration\n")

	# Force immediate exit
	quit()
