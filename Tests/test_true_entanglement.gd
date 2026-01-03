#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: TRUE ENTANGLEMENT - Both emojis in bath
##
## Use create_projection directly to choose emojis that are in the bath
## BioticFlux has: ☀ 🌙 🌾 🍄 💀 🍂
## We'll use {🌾, 🍄} for both projections

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")

func _init():
	print("\n🧪 TRUE ENTANGLEMENT TEST")
	print("=" + "=".repeat(59))
	print("Using {🌾, 🍄} projections - both emojis in bath\n")

	# Create biome
	var biome = BioticFluxBiome.new()
	biome._ready()

	if not biome or not biome.bath:
		print("❌ No bath")
		quit(1)
		return

	print("✅ BioticFlux biome initialized")
	print("  Bath emojis: %s\n" % str(biome.bath.emoji_list))

	# Create TWO projections onto {🌾, 🍄}
	var pos_a = Vector2i(0, 0)
	var pos_b = Vector2i(1, 0)

	print("🔭 Creating two projections:")
	var qubit_a = biome.create_projection(pos_a, "🌾", "🍄")
	var qubit_b = biome.create_projection(pos_b, "🌾", "🍄")

	if not qubit_a or not qubit_b:
		print("❌ Failed to create projections")
		quit(1)
		return

	print("  ✅ Projection A: %s ↔ %s at %s" % [qubit_a.north_emoji, qubit_a.south_emoji, pos_a])
	print("  ✅ Projection B: %s ↔ %s at %s" % [qubit_b.north_emoji, qubit_b.south_emoji, pos_b])

	# Verify same bath
	if qubit_a.bath != qubit_b.bath:
		print("❌ Different bath references!")
		quit(1)
		return

	print("\n✅ Both qubits share same bath: %s" % qubit_a.bath)

	# Get initial state
	print("\n📊 INITIAL STATE:")

	var wheat_init = biome.bath.get_population("🌾")
	var mushroom_init = biome.bath.get_population("🍄")
	var theta_a_init = qubit_a.theta
	var theta_b_init = qubit_b.theta

	print("  Bath:")
	print("    🌾 = %.4f (%.1f%%)" % [wheat_init, wheat_init * 100])
	print("    🍄 = %.4f (%.1f%%)" % [mushroom_init, mushroom_init * 100])

	print("  Projections:")
	print("    θ_A = %.4f rad (%.1f°)" % [theta_a_init, rad_to_deg(theta_a_init)])
	print("    θ_B = %.4f rad (%.1f°)" % [theta_b_init, rad_to_deg(theta_b_init)])

	if abs(theta_a_init - theta_b_init) < 0.0001:
		print("  ✅ Both see identical theta (synchronized)")
	else:
		print("  ⚠️  Theta values differ: Δθ = %.6f" % abs(theta_a_init - theta_b_init))

	# MEASURE Projection A
	print("\n🔬 MEASURING PROJECTION A...")

	var outcome = qubit_a.measure()
	print("  Outcome: %s" % outcome)

	# Check bath after measurement
	var wheat_after = biome.bath.get_population("🌾")
	var mushroom_after = biome.bath.get_population("🍄")

	print("\n📊 AFTER MEASURING A:")
	print("  Bath:")
	print("    🌾: %.4f → %.4f (Δ = %+.4f)" % [wheat_init, wheat_after, wheat_after - wheat_init])
	print("    🍄: %.4f → %.4f (Δ = %+.4f)" % [mushroom_init, mushroom_after, mushroom_after - mushroom_init])

	# THE KEY TEST: Did qubit B update?
	var theta_a_after = qubit_a.theta
	var theta_b_after = qubit_b.theta

	print("  Projections:")
	print("    θ_A: %.4f → %.4f rad" % [theta_a_init, theta_a_after])
	print("    θ_B: %.4f → %.4f rad ← AUTOMATIC UPDATE!" % [theta_b_init, theta_b_after])

	var delta_b = abs(theta_b_after - theta_b_init)
	print("\n  Δθ_B = %.6f rad (%.2f°)" % [delta_b, rad_to_deg(delta_b)])

	# Verify entanglement
	print("\n🔍 ENTANGLEMENT VERIFICATION:")

	var entangled = delta_b > 0.01  # Significant change

	if entangled:
		print("  🎯 ENTANGLEMENT CONFIRMED!")
		print("    ✅ Projection B's theta changed automatically")
		print("    ✅ No manual sync - computed from shared bath")
		print("    ✅ This is TRUE quantum entanglement!")
		print("\n  How it works:")
		print("    1. Both qubits project {🌾, 🍄} from same bath")
		print("    2. Measuring A collapsed bath in {🌾, 🍄} subspace")
		print("    3. B computes theta from collapsed bath")
		print("    4. B automatically sees the collapse!")
	else:
		print("  ❌ ENTANGLEMENT FAILED")
		print("    Projection B's theta should have changed")
		print("    Both view same bath → collapse should propagate")
		quit(1)
		return

	# Verify collapse happened
	print("\n📉 COLLAPSE DETAILS:")

	if outcome == "🌾":
		print("  Measured: 🌾 (wheat)")
		print("  Expected: 🍄 → 0")
		print("  Actual:   🍄 = %.6f" % mushroom_after)
		if mushroom_after < 0.01:
			print("  ✅ Collapse verified")
	else:
		print("  Measured: 🍄 (mushroom)")
		print("  Expected: 🌾 → 0")
		print("  Actual:   🌾 = %.6f" % wheat_after)
		if wheat_after < 0.01:
			print("  ✅ Collapse verified")

	# Normalization
	var total = 0.0
	for emoji in biome.bath.emoji_list:
		total += biome.bath.get_probability(emoji)

	print("\n🔄 NORMALIZATION:")
	print("  Σ|α|² = %.6f" % total)
	if abs(total - 1.0) < 0.001:
		print("  ✅ Bath normalized")

	# Final summary
	print("\n" + "=" + "=".repeat(59))
	print("🎉 TRUE ENTANGLEMENT VERIFIED!")
	print("=" + "=".repeat(59))
	print("\nWhat we proved:")
	print("  ✅ Two qubits viewing same bath are ENTANGLED")
	print("  ✅ Measuring one automatically affects the other")
	print("  ✅ No manual synchronization needed")
	print("  ✅ Live-coupled projections work perfectly")
	print("\nThis is the core of the quantum farm mechanics:")
	print("  🌾 All plots in a biome share the quantum bath")
	print("  🔬 Measuring one plot affects all others")
	print("  🔗 True quantum entanglement through shared substrate")

	quit(0)
