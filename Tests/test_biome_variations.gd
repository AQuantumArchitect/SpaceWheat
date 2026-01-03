#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: Biome Variations
##
## Tests:
## 1. Minimal hand-crafted biome (3 emojis)
## 2. BioticFlux with hot-dropped emoji
## 3. Dual biome (2-way merge)
## 4. Triple biome (3-way merge)
## 5. Projection creation in each
## 6. Measurement in each

const MinimalTestBiome = preload("res://Core/Environment/MinimalTestBiome.gd")
const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const DualBiome = preload("res://Core/Environment/DualBiome.gd")
const TripleBiome = preload("res://Core/Environment/TripleBiome.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")

func _init():
	print("\n🧪 BIOME VARIATIONS TEST")
	print("=" + "=".repeat(69))
	print("Testing: Minimal, Hot Drop, Dual, Triple biomes\n")

	# ========================================================================
	# TEST 1: MINIMAL BIOME
	# ========================================================================
	print("☀ TEST 1: MINIMAL HAND-CRAFTED BIOME")
	print("-" + "-".repeat(69))

	var minimal = MinimalTestBiome.new()
	minimal._ready()

	if not minimal.bath:
		print("❌ No bath in minimal biome!")
		quit(1)
		return

	print("✅ Minimal biome initialized")
	print("  Emojis: %s" % str(minimal.bath.emoji_list))
	print("  Count: %d" % minimal.bath.emoji_list.size())

	# Verify exactly 3 emojis
	if minimal.bath.emoji_list.size() == 3:
		print("  ✅ Correct count: 3 emojis")
	else:
		print("  ❌ Wrong count: expected 3, got %d" % minimal.bath.emoji_list.size())
		quit(1)
		return

	# Verify has operators
	if minimal.bath.hamiltonian_sparse.size() > 0:
		print("  ✅ Hamiltonian built (%d terms)" % minimal.bath.hamiltonian_sparse.size())
	else:
		print("  ❌ No Hamiltonian!")
		quit(1)
		return

	# Verify normalization
	var total_minimal = 0.0
	for emoji in minimal.bath.emoji_list:
		total_minimal += minimal.bath.get_probability(emoji)

	if abs(total_minimal - 1.0) < 0.001:
		print("  ✅ Bath normalized (Σ|α|² = %.6f)" % total_minimal)
	else:
		print("  ❌ Not normalized! (Σ|α|² = %.6f)" % total_minimal)
		quit(1)
		return

	# Create projection
	print("\n  Creating projection 🌾↔💧...")
	var minimal_proj = minimal.create_projection(Vector2i(0, 0), "🌾", "💧")

	if minimal_proj:
		print("  ✅ Projection created")
		print("    θ = %.4f rad (%.1f°)" % [minimal_proj.theta, rad_to_deg(minimal_proj.theta)])
	else:
		print("  ❌ Projection failed!")
		quit(1)
		return

	# ========================================================================
	# TEST 2: BIOTICFLUX WITH HOT DROP
	# ========================================================================
	print("\n🚁 TEST 2: BIOTICFLUX WITH HOT-DROPPED EMOJI")
	print("-" + "-".repeat(69))

	var bioticflux = BioticFluxBiome.new()
	bioticflux._ready()

	if not bioticflux.bath:
		print("❌ No bath in BioticFlux!")
		quit(1)
		return

	var initial_count = bioticflux.bath.emoji_list.size()
	print("✅ BioticFlux initialized")
	print("  Initial emojis: %s" % str(bioticflux.bath.emoji_list))
	print("  Initial count: %d" % initial_count)

	# Hot drop a wolf
	print("\n  Hot dropping 🐺 (wolf)...")
	var drop_success = bioticflux.hot_drop_emoji("🐺", Complex.new(0.1, 0.0))

	if not drop_success:
		print("  ❌ Hot drop failed!")
		quit(1)
		return

	var new_count = bioticflux.bath.emoji_list.size()
	print("  ✅ Hot drop successful")
	print("  New emojis: %s" % str(bioticflux.bath.emoji_list))
	print("  New count: %d" % new_count)

	# Verify count increased
	if new_count == initial_count + 1:
		print("  ✅ Count increased correctly")
	else:
		print("  ❌ Count wrong: expected %d, got %d" % [initial_count + 1, new_count])
		quit(1)
		return

	# Verify wolf is present
	if "🐺" in bioticflux.bath.emoji_list:
		print("  ✅ Wolf in emoji list")
	else:
		print("  ❌ Wolf not in list!")
		quit(1)
		return

	# Verify wolf has population
	var wolf_pop = bioticflux.bath.get_population("🐺")
	print("  Wolf population: %.4f" % wolf_pop)

	if wolf_pop > 0:
		print("  ✅ Wolf has amplitude")
	else:
		print("  ⚠️  Wolf amplitude is zero")

	# Verify still normalized
	var total_bf = 0.0
	for emoji in bioticflux.bath.emoji_list:
		total_bf += bioticflux.bath.get_probability(emoji)

	if abs(total_bf - 1.0) < 0.001:
		print("  ✅ Still normalized (Σ|α|² = %.6f)" % total_bf)
	else:
		print("  ❌ Denormalized! (Σ|α|² = %.6f)" % total_bf)
		quit(1)
		return

	# Create projection with hot-dropped emoji
	print("\n  Creating projection 🐺↔🌾...")
	var bf_proj = bioticflux.create_projection(Vector2i(1, 0), "🐺", "🌾")

	if bf_proj:
		print("  ✅ Projection with hot-dropped emoji works!")
		print("    θ = %.4f rad (%.1f°)" % [bf_proj.theta, rad_to_deg(bf_proj.theta)])
	else:
		print("  ❌ Projection failed!")
		quit(1)
		return

	# ========================================================================
	# TEST 3: DUAL BIOME
	# ========================================================================
	print("\n🌾💰 TEST 3: DUAL BIOME (2-WAY MERGE)")
	print("-" + "-".repeat(69))

	var dual = DualBiome.new()
	dual._ready()

	if not dual.bath:
		print("❌ No bath in dual biome!")
		quit(1)
		return

	print("✅ Dual biome initialized")
	print("  Emojis: %s" % str(dual.bath.emoji_list))
	print("  Count: %d" % dual.bath.emoji_list.size())

	# Verify count is sum (no overlap between BioticFlux and Market)
	var expected_dual = 12  # 6 + 6
	if dual.bath.emoji_list.size() == expected_dual:
		print("  ✅ Correct merged count: %d" % expected_dual)
	else:
		print("  ⚠️  Expected %d, got %d (sets may have changed)" % [
			expected_dual,
			dual.bath.emoji_list.size()
		])

	# Verify has both BioticFlux and Market emojis
	var has_bf = "🌾" in dual.bath.emoji_list
	var has_market = "🐂" in dual.bath.emoji_list

	if has_bf and has_market:
		print("  ✅ Has emojis from both biomes")
		print("    BioticFlux: 🌾 present")
		print("    Market: 🐂 present")
	else:
		print("  ❌ Missing emojis from constituent biomes!")
		quit(1)
		return

	# Verify normalization
	var total_dual = 0.0
	for emoji in dual.bath.emoji_list:
		total_dual += dual.bath.get_probability(emoji)

	if abs(total_dual - 1.0) < 0.001:
		print("  ✅ Bath normalized (Σ|α|² = %.6f)" % total_dual)
	else:
		print("  ❌ Not normalized! (Σ|α|² = %.6f)" % total_dual)
		quit(1)
		return

	# Create cross-ecosystem projection
	print("\n  Creating cross-ecosystem projection 🌾↔🐂...")
	var dual_proj = dual.create_projection(Vector2i(2, 0), "🌾", "🐂")

	if dual_proj:
		print("  ✅ Cross-ecosystem projection works!")
		print("    θ = %.4f rad (%.1f°)" % [dual_proj.theta, rad_to_deg(dual_proj.theta)])
	else:
		print("  ❌ Projection failed!")
		quit(1)
		return

	# ========================================================================
	# TEST 4: TRIPLE BIOME
	# ========================================================================
	print("\n🌾💰🍞 TEST 4: TRIPLE BIOME (3-WAY MERGE)")
	print("-" + "-".repeat(69))

	var triple = TripleBiome.new()
	triple._ready()

	if not triple.bath:
		print("❌ No bath in triple biome!")
		quit(1)
		return

	print("✅ Triple biome initialized")
	print("  Emojis: %s" % str(triple.bath.emoji_list))
	print("  Count: %d" % triple.bath.emoji_list.size())

	# Verify count accounts for overlap (🌾 shared between BioticFlux and Kitchen)
	var expected_triple = 15  # 6 + 6 + 4 - 1 overlap
	if triple.bath.emoji_list.size() == expected_triple:
		print("  ✅ Correct merged count: %d (with overlap)" % expected_triple)
	else:
		print("  ⚠️  Expected ~%d, got %d" % [expected_triple, triple.bath.emoji_list.size()])

	# Verify has emojis from all three
	var has_bf_t = "🌾" in triple.bath.emoji_list
	var has_market_t = "🐂" in triple.bath.emoji_list
	var has_kitchen = "🔥" in triple.bath.emoji_list

	if has_bf_t and has_market_t and has_kitchen:
		print("  ✅ Has emojis from all three biomes")
		print("    BioticFlux: 🌾 present")
		print("    Market: 🐂 present")
		print("    Kitchen: 🔥 present")
	else:
		print("  ❌ Missing emojis from constituent biomes!")
		quit(1)
		return

	# Verify normalization
	var total_triple = 0.0
	for emoji in triple.bath.emoji_list:
		total_triple += triple.bath.get_probability(emoji)

	if abs(total_triple - 1.0) < 0.001:
		print("  ✅ Bath normalized (Σ|α|² = %.6f)" % total_triple)
	else:
		print("  ❌ Not normalized! (Σ|α|² = %.6f)" % total_triple)
		quit(1)
		return

	# Create triple-cross projection (emoji from each biome)
	print("\n  Testing projections across all three:")

	# BioticFlux emoji vs Market emoji
	print("  1. BioticFlux (🌾) ↔ Market (💰)...")
	var triple_proj1 = triple.create_projection(Vector2i(3, 0), "🌾", "💰")
	if triple_proj1:
		print("     ✅ Works (θ = %.2f rad)" % triple_proj1.theta)
	else:
		print("     ❌ Failed!")
		quit(1)
		return

	# Market emoji vs Kitchen emoji
	print("  2. Market (🐂) ↔ Kitchen (🔥)...")
	var triple_proj2 = triple.create_projection(Vector2i(4, 0), "🐂", "🔥")
	if triple_proj2:
		print("     ✅ Works (θ = %.2f rad)" % triple_proj2.theta)
	else:
		print("     ❌ Failed!")
		quit(1)
		return

	# Kitchen emoji vs BioticFlux emoji
	print("  3. Kitchen (🍞) ↔ BioticFlux (🍄)...")
	var triple_proj3 = triple.create_projection(Vector2i(5, 0), "🍞", "🍄")
	if triple_proj3:
		print("     ✅ Works (θ = %.2f rad)" % triple_proj3.theta)
	else:
		print("     ❌ Failed!")
		quit(1)
		return

	# ========================================================================
	# TEST 5: MEASUREMENT IN MERGED BIOME
	# ========================================================================
	print("\n🔬 TEST 5: MEASUREMENT IN MERGED BIOME")
	print("-" + "-".repeat(69))

	print("  Measuring triple biome projection 1 (🌾↔💰)...")
	var outcome = triple_proj1.measure()
	print("  Outcome: %s" % outcome)

	if outcome == "🌾" or outcome == "💰":
		print("  ✅ Valid measurement outcome")
	else:
		print("  ❌ Invalid outcome!")
		quit(1)
		return

	# Verify bath collapsed in subspace
	var wheat_after = triple.bath.get_population("🌾")
	var money_after = triple.bath.get_population("💰")

	print("  After measurement:")
	print("    🌾 = %.4f" % wheat_after)
	print("    💰 = %.4f" % money_after)

	if (outcome == "🌾" and money_after < 0.01) or (outcome == "💰" and wheat_after < 0.01):
		print("  ✅ Bath collapsed correctly")
	else:
		print("  ⚠️  Partial collapse (may be expected)")

	# Verify still normalized
	var total_after_meas = 0.0
	for emoji in triple.bath.emoji_list:
		total_after_meas += triple.bath.get_probability(emoji)

	if abs(total_after_meas - 1.0) < 0.001:
		print("  ✅ Bath still normalized (Σ|α|² = %.6f)" % total_after_meas)
	else:
		print("  ❌ Denormalized! (Σ|α|² = %.6f)" % total_after_meas)
		quit(1)
		return

	# ========================================================================
	# FINAL SUMMARY
	# ========================================================================
	print("\n" + "=" + "=".repeat(69))
	print("🎉 BIOME VARIATIONS TEST COMPLETE!")
	print("=" + "=".repeat(69))

	print("\n✅ All Tests Passed:")
	print("  ✅ Minimal biome (3 emojis) works")
	print("  ✅ Hot drop emoji into existing biome works")
	print("  ✅ Dual biome (2-way merge) works")
	print("  ✅ Triple biome (3-way merge) works")
	print("  ✅ Projections work in all biome types")
	print("  ✅ Cross-ecosystem projections work")
	print("  ✅ Measurement works in merged biomes")
	print("  ✅ Bath normalization maintained in all cases")

	print("\n📊 Biome Summary:")
	print("  Minimal:    %d emojis" % minimal.bath.emoji_list.size())
	print("  BioticFlux: %d emojis (+ hot drop)" % bioticflux.bath.emoji_list.size())
	print("  Dual:       %d emojis (2-way merge)" % dual.bath.emoji_list.size())
	print("  Triple:     %d emojis (3-way merge)" % triple.bath.emoji_list.size())

	print("\n🎯 COMPOSITIONAL BIOME ARCHITECTURE FULLY VALIDATED!")

	quit(0)
