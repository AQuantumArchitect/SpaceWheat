#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: Bath-First Inject/Drain Functionality
##
## Verifies:
## 1. Bath boost_amplitude() increases population
## 2. Bath drain_amplitude() decreases population
## 3. Bath remains normalized after operations
## 4. Energy is correctly derived from theta (sin²(θ/2))

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")

func _init():
	print("🧪 BATH-FIRST INJECT/DRAIN TEST\n")

	# Create biome with bath
	var biome = BioticFluxBiome.new()
	biome._ready()

	if not biome.bath:
		print("❌ FAIL: Biome has no bath!")
		quit(1)
		return

	print("✓ Biome initialized with bath")
	print("  Bath has %d emojis" % biome.bath.emoji_list.size())

	# Check initial populations
	print("\n📊 Initial Bath Populations:")
	for emoji in ["🌾", "🍄", "👥"]:
		if biome.bath.emoji_to_index.has(emoji):
			var pop = biome.bath.get_population(emoji)
			print("  %s: %.4f" % [emoji, pop])

	# TEST 1: Inject energy (boost amplitude)
	print("\n🔼 TEST 1: INJECT ENERGY (boost 🌾 by 0.1)")
	var wheat_before = biome.bath.get_population("🌾")
	biome.bath.boost_amplitude("🌾", 0.1)
	var wheat_after = biome.bath.get_population("🌾")

	print("  🌾 before: %.4f" % wheat_before)
	print("  🌾 after:  %.4f" % wheat_after)
	print("  Change: %.4f" % (wheat_after - wheat_before))

	if wheat_after > wheat_before:
		print("  ✅ PASS: Wheat population increased")
	else:
		print("  ❌ FAIL: Wheat population did not increase!")
		quit(1)
		return

	# TEST 2: Drain energy
	print("\n🔽 TEST 2: DRAIN ENERGY (drain 🌾 by 0.05)")
	var wheat_before_drain = biome.bath.get_population("🌾")
	var drained = biome.bath.drain_amplitude("🌾", 0.05)
	var wheat_after_drain = biome.bath.get_population("🌾")

	print("  🌾 before: %.4f" % wheat_before_drain)
	print("  🌾 after:  %.4f" % wheat_after_drain)
	print("  Drained: %.4f" % drained)
	print("  Change: %.4f" % (wheat_after_drain - wheat_before_drain))

	if wheat_after_drain < wheat_before_drain and drained > 0:
		print("  ✅ PASS: Wheat population decreased, energy drained")
	else:
		print("  ❌ FAIL: Drain did not work correctly!")
		quit(1)
		return

	# TEST 3: Verify normalization (sum = 1.0)
	print("\n🔄 TEST 3: VERIFY NORMALIZATION")
	var total = 0.0
	for emoji in biome.bath.emoji_list:
		total += biome.bath.get_probability(emoji)

	print("  Total population: %.6f" % total)

	if abs(total - 1.0) < 0.0001:
		print("  ✅ PASS: Bath is normalized (sum ≈ 1.0)")
	else:
		print("  ❌ FAIL: Bath not normalized! (sum = %.6f)" % total)
		quit(1)
		return

	# TEST 4: Create projection and verify energy derives from theta
	print("\n📐 TEST 4: ENERGY DERIVED FROM THETA")
	var projection = biome.create_projection(Vector2i(0, 0), "🌾", "🍄")

	if not projection:
		print("  ❌ FAIL: Could not create projection!")
		quit(1)
		return

	print("  Created projection 🌾↔🍄")
	print("  Theta: %.4f" % projection.theta)
	print("  Computed energy (sin²(θ/2)): %.4f" % projection.energy)
	print("  South probability: %.4f" % projection.get_south_probability())

	if abs(projection.energy - projection.get_south_probability()) < 0.0001:
		print("  ✅ PASS: Energy correctly derived from theta")
	else:
		print("  ❌ FAIL: Energy mismatch!")
		quit(1)
		return

	print("\n" + "=".repeat(50))
	print("✅ ALL TESTS PASSED")
	print("=".repeat(50))
	quit(0)
