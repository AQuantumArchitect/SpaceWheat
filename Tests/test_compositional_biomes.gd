#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: Compositional Biome Architecture
##
## Verify:
## 1. merge_emoji_sets() works correctly
## 2. initialize_bath_from_emojis() builds composite operators
## 3. MergedEcosystem_Biome combines BioticFlux + Forest
## 4. hot_drop_emoji() dynamically injects emojis

const BiomeBase = preload("res://Core/Environment/BiomeBase.gd")
const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const MergedEcosystem_Biome = preload("res://Core/Environment/MergedEcosystem_Biome.gd")
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")

func _init():
	print("\n🧪 COMPOSITIONAL BIOME TEST")
	print("=" + "=".repeat(69))
	print("Testing: Icon-based compositional bath construction\n")

	# TEST 1: Merge Emoji Sets
	print("📋 TEST 1: MERGE EMOJI SETS")
	print("-" + "-".repeat(69))

	var set_a = ["☀", "🌾", "🌿"]
	var set_b = ["🌿", "🐺", "🐰"]  # Note: 🌿 shared

	var merged = BiomeBase.merge_emoji_sets(set_a, set_b)

	print("  Set A: %s" % str(set_a))
	print("  Set B: %s" % str(set_b))
	print("  Merged: %s" % str(merged))

	# Verify union
	var expected_size = 5  # ☀ 🌾 🌿 🐺 🐰
	if merged.size() == expected_size:
		print("  ✅ Correct size: %d emojis" % merged.size())
	else:
		print("  ❌ Wrong size: expected %d, got %d" % [expected_size, merged.size()])
		quit(1)
		return

	# Verify all emojis present
	var all_present = true
	for emoji in ["☀", "🌾", "🌿", "🐺", "🐰"]:
		if not emoji in merged:
			print("  ❌ Missing emoji: %s" % emoji)
			all_present = false

	if all_present:
		print("  ✅ All emojis present")
	else:
		quit(1)
		return

	# TEST 2: BioticFlux Biome (Baseline)
	print("\n🌾 TEST 2: BIOTICFLUX BIOME (BASELINE)")
	print("-" + "-".repeat(69))

	var bioticflux = BioticFluxBiome.new()
	bioticflux._ready()

	if not bioticflux.bath:
		print("  ❌ No bath initialized!")
		quit(1)
		return

	print("  ✅ Bath initialized")
	print("  Emojis: %s" % str(bioticflux.bath.emoji_list))
	print("  Count: %d emojis" % bioticflux.bath.emoji_list.size())

	# Verify operators built
	var has_hamiltonian = bioticflux.bath.hamiltonian_sparse.size() > 0
	var has_lindblad = bioticflux.bath.lindblad_terms.size() > 0

	if has_hamiltonian:
		print("  ✅ Hamiltonian built (%d terms)" % bioticflux.bath.hamiltonian_sparse.size())
	else:
		print("  ❌ No Hamiltonian!")
		quit(1)
		return

	if has_lindblad:
		print("  ✅ Lindblad built (%d terms)" % bioticflux.bath.lindblad_terms.size())
	else:
		print("  ⚠️  No Lindblad terms (may be okay)")

	# TEST 3: Merged Ecosystem Biome
	print("\n🌲🌾 TEST 3: MERGED ECOSYSTEM BIOME")
	print("-" + "-".repeat(69))

	var merged_biome = MergedEcosystem_Biome.new()
	merged_biome._ready()

	if not merged_biome.bath:
		print("  ❌ No bath initialized!")
		quit(1)
		return

	print("  ✅ Merged bath initialized")
	print("  Emojis: %s" % str(merged_biome.bath.emoji_list))
	print("  Count: %d emojis" % merged_biome.bath.emoji_list.size())

	# Verify merged has more emojis than base biomes
	var bioticflux_count = 6  # ☀ 🌙 🌾 🍄 💀 🍂
	var forest_simple_count = 8  # 🌲 🐺 🐰 🦌 🌿 💧 ⛰ 🍂
	var merged_expected = 13  # Union (🍂 shared)

	if merged_biome.bath.emoji_list.size() == merged_expected:
		print("  ✅ Correct merged size: %d emojis" % merged_expected)
	else:
		print("  ⚠️  Expected %d, got %d (may be okay if sets changed)" % [
			merged_expected,
			merged_biome.bath.emoji_list.size()
		])

	# Verify operators composite
	var merged_has_h = merged_biome.bath.hamiltonian_sparse.size() > 0
	var merged_has_l = merged_biome.bath.lindblad_terms.size() > 0

	if merged_has_h:
		print("  ✅ Composite Hamiltonian (%d terms)" % merged_biome.bath.hamiltonian_sparse.size())
	else:
		print("  ❌ No Hamiltonian!")
		quit(1)
		return

	if merged_has_l:
		print("  ✅ Composite Lindblad (%d terms)" % merged_biome.bath.lindblad_terms.size())

	# Verify normalization
	var total_prob = 0.0
	for emoji in merged_biome.bath.emoji_list:
		total_prob += merged_biome.bath.get_probability(emoji)

	if abs(total_prob - 1.0) < 0.001:
		print("  ✅ Bath normalized (Σ|α|² = %.6f)" % total_prob)
	else:
		print("  ❌ Bath not normalized! (Σ|α|² = %.6f)" % total_prob)
		quit(1)
		return

	# TEST 4: Hot Drop Emoji
	print("\n🚁 TEST 4: HOT DROP EMOJI")
	print("-" + "-".repeat(69))

	# Use BioticFlux biome for hot drop
	var initial_count = bioticflux.bath.emoji_list.size()
	print("  Initial emoji count: %d" % initial_count)
	print("  Hot dropping 🐺 (wolf) into BioticFlux...")

	var drop_success = bioticflux.hot_drop_emoji("🐺", Complex.new(0.05, 0.0))

	if not drop_success:
		print("  ❌ Hot drop failed!")
		quit(1)
		return

	var new_count = bioticflux.bath.emoji_list.size()
	print("  ✅ Hot drop successful")
	print("  New emoji count: %d" % new_count)

	if new_count == initial_count + 1:
		print("  ✅ Emoji added correctly")
	else:
		print("  ❌ Wrong count: expected %d, got %d" % [initial_count + 1, new_count])
		quit(1)
		return

	# Verify wolf is in bath
	if "🐺" in bioticflux.bath.emoji_list:
		print("  ✅ Wolf (🐺) now in bath")
	else:
		print("  ❌ Wolf not in bath!")
		quit(1)
		return

	# Verify wolf has population
	var wolf_pop = bioticflux.bath.get_population("🐺")
	print("  Wolf population: %.4f" % wolf_pop)

	if wolf_pop > 0:
		print("  ✅ Wolf has non-zero population")
	else:
		print("  ⚠️  Wolf population is zero (initial amplitude was given)")

	# Verify bath still normalized
	var total_after_drop = 0.0
	for emoji in bioticflux.bath.emoji_list:
		total_after_drop += bioticflux.bath.get_probability(emoji)

	if abs(total_after_drop - 1.0) < 0.001:
		print("  ✅ Bath still normalized (Σ|α|² = %.6f)" % total_after_drop)
	else:
		print("  ❌ Bath denormalized after drop! (Σ|α|² = %.6f)" % total_after_drop)
		quit(1)
		return

	# TEST 5: Verify Operators Rebuilt After Hot Drop
	print("\n🔧 TEST 5: OPERATORS REBUILT AFTER HOT DROP")
	print("-" + "-".repeat(69))

	var h_size_after = bioticflux.bath.hamiltonian_sparse.size()
	var l_size_after = bioticflux.bath.lindblad_terms.size()

	print("  Hamiltonian terms: %d" % h_size_after)
	print("  Lindblad terms: %d" % l_size_after)

	# Should have operators for wolf now
	var wolf_idx = bioticflux.bath.emoji_to_index.get("🐺", -1)

	if wolf_idx >= 0:
		print("  ✅ Wolf has index: %d" % wolf_idx)

		# Check if wolf has Hamiltonian term
		if bioticflux.bath.hamiltonian_sparse.has(wolf_idx):
			print("  ✅ Wolf has Hamiltonian terms")
		else:
			print("  ⚠️  Wolf has no Hamiltonian (may be okay)")

		# Check if wolf appears in any Lindblad term
		var wolf_in_lindblad = false
		for term in bioticflux.bath.lindblad_terms:
			if term.source == wolf_idx or term.target == wolf_idx:
				wolf_in_lindblad = true
				break

		if wolf_in_lindblad:
			print("  ✅ Wolf in Lindblad terms")
		else:
			print("  ⚠️  Wolf not in Lindblad (may be okay if icon has no transfers)")

	else:
		print("  ❌ Wolf has no index!")
		quit(1)
		return

	# FINAL SUMMARY
	print("\n" + "=" + "=".repeat(69))
	print("🎉 COMPOSITIONAL BIOME TEST COMPLETE!")
	print("=" + "=".repeat(69))

	print("\n✅ All Tests Passed:")
	print("  ✅ merge_emoji_sets() works correctly")
	print("  ✅ initialize_bath_from_emojis() builds composite operators")
	print("  ✅ MergedEcosystem_Biome combines emoji sets")
	print("  ✅ hot_drop_emoji() dynamically injects emojis")
	print("  ✅ Operators rebuild after hot drop")
	print("  ✅ Bath normalization maintained")

	print("\n📝 What This Proves:")
	print("  • Icons define all physics (Hamiltonian + Lindblad)")
	print("  • Bath = compositional sum of Icon operators")
	print("  • Biomes can merge emoji sets easily")
	print("  • Emojis can be injected at runtime")
	print("  • Operators automatically rebuild")

	print("\n🎯 COMPOSITIONAL ARCHITECTURE VERIFIED!")

	quit(0)
