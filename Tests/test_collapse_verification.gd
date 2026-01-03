#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: Verify True Collapse
## Use two emojis that are BOTH in the bath to see real collapse

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

func _init():
	print("\n🧪 TRUE COLLAPSE VERIFICATION")
	print("=" + "=".repeat(49))

	# Create biome with bath
	var biome = BioticFluxBiome.new()
	biome._ready()

	if not biome.bath:
		print("❌ No bath!")
		quit(1)
		return

	print("✓ Bath initialized")
	print("  Emojis: %s" % str(biome.bath.emoji_list))

	# Create qubit with TWO emojis that are in the bath
	# BioticFlux has: ☀ 🌙 🌾 🍄 💀 🍂
	# Let's use 🌾 (wheat) and 🍄 (mushroom)

	print("\n🔭 Creating projection: 🌾 ↔ 🍄")
	var qubit = biome.create_projection(Vector2i(0, 0), "🌾", "🍄")

	if not qubit or not qubit.bath:
		print("❌ Failed to create projection")
		quit(1)
		return

	print("  ✓ Projection created")

	# Check initial populations
	var wheat_before = biome.bath.get_population("🌾")
	var mushroom_before = biome.bath.get_population("🍄")
	var theta_before = qubit.theta

	print("\n📊 BEFORE MEASUREMENT:")
	print("  🌾 = %.4f (%.1f%%)" % [wheat_before, wheat_before * 100])
	print("  🍄 = %.4f (%.1f%%)" % [mushroom_before, mushroom_before * 100])
	print("  θ = %.4f rad (%.1f°)" % [theta_before, rad_to_deg(theta_before)])
	print("  P(🌾) = %.4f" % qubit.get_north_probability())
	print("  P(🍄) = %.4f" % qubit.get_south_probability())

	# MEASURE
	print("\n🔬 MEASURING...")
	var outcome = qubit.measure()
	print("  Outcome: %s" % outcome)

	# Check after measurement
	var wheat_after = biome.bath.get_population("🌾")
	var mushroom_after = biome.bath.get_population("🍄")
	var theta_after = qubit.theta

	print("\n📊 AFTER MEASUREMENT:")
	print("  🌾 = %.4f → %.4f (Δ = %.4f)" % [wheat_before, wheat_after, wheat_after - wheat_before])
	print("  🍄 = %.4f → %.4f (Δ = %.4f)" % [mushroom_before, mushroom_after, mushroom_after - mushroom_before])
	print("  θ = %.4f → %.4f rad" % [theta_before, theta_after])

	# Verify collapse happened
	print("\n🔍 COLLAPSE VERIFICATION:")

	var collapsed = false
	if outcome == "🌾":
		# Measured wheat - mushroom should go to ~0
		if mushroom_after < 0.01 and abs(mushroom_before - mushroom_after) > 0.01:
			print("  ✅ Collapse confirmed: 🍄 → 0")
			collapsed = true
		else:
			print("  ⚠️  🍄: %.4f → %.4f (expected to collapse)" % [mushroom_before, mushroom_after])
	else:
		# Measured mushroom - wheat should go to ~0
		if wheat_after < 0.01 and abs(wheat_before - wheat_after) > 0.01:
			print("  ✅ Collapse confirmed: 🌾 → 0")
			collapsed = true
		else:
			print("  ⚠️  🌾: %.4f → %.4f (expected to collapse)" % [wheat_before, wheat_after])

	# Check other emojis rescaled
	print("\n📈 OTHER EMOJI RESCALING:")
	print("  Bath should renormalize - other emojis scale up")

	var sun_before = 0.25  # Initial from biome init
	var sun_after = biome.bath.get_population("☀")
	print("  ☀ (sun): ~%.4f → %.4f" % [sun_before, sun_after])

	if sun_after > sun_before:
		print("  ✅ Other emojis rescaled up")

	# Check normalization
	var total = 0.0
	for emoji in biome.bath.emoji_list:
		total += biome.bath.get_probability(emoji)

	print("\n🔄 NORMALIZATION CHECK:")
	print("  Σ|α|² = %.6f" % total)

	if abs(total - 1.0) < 0.001:
		print("  ✅ Bath normalized")
	else:
		print("  ❌ Bath NOT normalized! (expected 1.0)")
		quit(1)
		return

	# Summary
	print("\n" + "=" + "=".repeat(49))
	if collapsed:
		print("✅ TRUE COLLAPSE VERIFIED!")
		print("  - Measurement outcome: %s" % outcome)
		print("  - Non-measured emoji collapsed to ~0")
		print("  - Other emojis rescaled")
		print("  - Bath remains normalized")
	else:
		print("⚠️  COLLAPSE UNCLEAR")
		print("  Populations didn't change as expected")
	print("=" + "=".repeat(49))

	quit(0 if collapsed else 1)
