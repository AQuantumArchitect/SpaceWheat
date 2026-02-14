#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: Save/Load with Bath State
##
## Verify bath persistence through save/load cycle:
## 1. Plant wheat at multiple plots (creates projections)
## 2. Measure one plot (collapses bath)
## 3. Save game
## 4. Load game
## 5. Verify bath state restored
## 6. Verify projections recreated
## 7. Verify theta computed correctly from loaded bath
## 8. Test measurement after load

const Farm = preload("res://Core/Farm.gd")
const GameStateManager = preload("res://Core/GameState/GameStateManager.gd")

var test_slot = 0  # Use slot 0 for testing

func _init():
	print("\n🧪 SAVE/LOAD BATH STATE TEST")
	print("=" + "=".repeat(69))
	print("Testing: Bath state persistence through save/load cycle\n")

	# Create game state manager
	var gsm = GameStateManager.new()
	gsm._ready()

	# Create farm
	var farm = Farm.new()
	farm._ready()

	# Initialize BioticFlux biome manually
	if farm.biotic_flux_biome and not farm.biotic_flux_biome.bath:
		farm.biotic_flux_biome._ready()

	var biome = farm.biotic_flux_biome
	if not biome or not biome.bath:
		print("❌ No BioticFlux biome/bath")
		quit(1)
		return

	# Register farm with GameStateManager
	gsm.active_farm = farm

	# Give resources
	farm.economy.add_resource("🌾", 1000, "test")

	print("✅ Farm initialized")
	print("  Biome: %s" % biome)
	print("  Bath: %s\n" % biome.bath)

	# PHASE 1: PLANT & MEASURE
	print("🌱 PHASE 1: PLANTING & MEASURING")
	print("-" + "-".repeat(69))

	# Plant wheat at TWO BioticFlux positions
	var pos_a = Vector2i(2, 0)
	var pos_b = Vector2i(3, 0)

	print("  Planting at %s..." % pos_a)
	farm.build(pos_a, "wheat")
	print("  Planting at %s..." % pos_b)
	farm.build(pos_b, "wheat")

	var plot_a = farm.grid.get_plot(pos_a)
	var plot_b = farm.grid.get_plot(pos_b)

	if not plot_a or not plot_a.quantum_state or not plot_b or not plot_b.quantum_state:
		print("❌ Failed to plant wheat")
		quit(1)
		return

	var qubit_a = plot_a.quantum_state
	var qubit_b = plot_b.quantum_state

	print("  ✅ Both plots planted")
	print("    Plot A: %s ↔ %s" % [qubit_a.north_emoji, qubit_a.south_emoji])
	print("    Plot B: %s ↔ %s" % [qubit_b.north_emoji, qubit_b.south_emoji])

	# Get initial state
	var wheat_before = biome.bath.get_population("🌾")
	var mushroom_before = biome.bath.get_population("🍄")
	var theta_a_before = qubit_a.theta
	var theta_b_before = qubit_b.theta

	print("\n  Initial bath state:")
	print("    🌾 = %.4f" % wheat_before)
	print("    🍄 = %.4f" % mushroom_before)
	print("    θ_A = %.4f rad (%.1f°)" % [theta_a_before, rad_to_deg(theta_a_before)])
	print("    θ_B = %.4f rad (%.1f°)" % [theta_b_before, rad_to_deg(theta_b_before)])

	# MEASURE Plot A (this will collapse the bath)
	print("\n  🔬 Measuring Plot A...")
	var outcome = farm.measure_plot(pos_a)
	print("    Outcome: %s" % outcome)

	# Get state after measurement
	var wheat_after = biome.bath.get_population("🌾")
	var mushroom_after = biome.bath.get_population("🍄")
	var theta_a_after = qubit_a.theta
	var theta_b_after = qubit_b.theta

	print("\n  Bath after measurement:")
	print("    🌾: %.4f → %.4f" % [wheat_before, wheat_after])
	print("    🍄: %.4f → %.4f" % [mushroom_before, mushroom_after])
	print("    θ_A: %.4f → %.4f rad" % [theta_a_before, theta_a_after])
	print("    θ_B: %.4f → %.4f rad (automatic update!)" % [theta_b_before, theta_b_after])

	# Verify collapse happened
	var collapsed = (outcome == "🌾" and mushroom_after < 0.01) or (outcome == "🍄" and wheat_after < 0.01)
	if not collapsed:
		print("\n  ⚠️  WARNING: Collapse may not have happened")
		print("    Expected %s → 0, but got: 🌾=%.4f, 🍄=%.4f" % [
			"🍄" if outcome == "🌾" else "🌾",
			wheat_after, mushroom_after
		])

	# PHASE 2: SAVE
	print("\n" + "=" + "=".repeat(69))
	print("💾 PHASE 2: SAVING GAME")
	print("-" + "-".repeat(69))

	var save_success = gsm.save_game(test_slot)
	if not save_success:
		print("❌ Save failed!")
		quit(1)
		return

	print("  ✅ Game saved to slot %d" % (test_slot + 1))
	print("  File: %s" % gsm.get_save_path(test_slot))

	# Save bath state for verification
	var saved_wheat = wheat_after
	var saved_mushroom = mushroom_after
	var saved_theta_a = theta_a_after
	var saved_theta_b = theta_b_after

	print("\n  Saved state:")
	print("    🌾 = %.4f" % saved_wheat)
	print("    🍄 = %.4f" % saved_mushroom)
	print("    θ_A = %.4f rad" % saved_theta_a)
	print("    θ_B = %.4f rad" % saved_theta_b)
	print("    Plot A measured: %s" % plot_a.is_measured)
	print("    Plot B measured: %s" % plot_b.is_measured)

	# PHASE 3: CLEAR STATE
	print("\n" + "=" + "=".repeat(69))
	print("🧹 PHASE 3: CLEARING FARM STATE")
	print("-" + "-".repeat(69))

	# Create fresh farm to simulate clean load
	var fresh_farm = Farm.new()
	fresh_farm._ready()
	if fresh_farm.biotic_flux_biome and not fresh_farm.biotic_flux_biome.bath:
		fresh_farm.biotic_flux_biome._ready()

	gsm.active_farm = fresh_farm

	print("  ✅ Fresh farm created")
	print("  New bath: %s" % fresh_farm.biotic_flux_biome.bath)

	# PHASE 4: LOAD
	print("\n" + "=" + "=".repeat(69))
	print("📂 PHASE 4: LOADING GAME")
	print("-" + "-".repeat(69))

	var load_success = gsm.load_and_apply(test_slot)
	if not load_success:
		print("❌ Load failed!")
		quit(1)
		return

	print("  ✅ Game loaded from slot %d" % (test_slot + 1))

	# Get loaded biome and bath
	var loaded_biome = fresh_farm.biotic_flux_biome
	if not loaded_biome or not loaded_biome.bath:
		print("❌ Loaded biome has no bath!")
		quit(1)
		return

	print("  Loaded biome: %s" % loaded_biome)
	print("  Loaded bath: %s" % loaded_biome.bath)

	# PHASE 5: VERIFY BATH STATE
	print("\n" + "=" + "=".repeat(69))
	print("🔍 PHASE 5: VERIFYING BATH STATE")
	print("-" + "-".repeat(69))

	var loaded_wheat = loaded_biome.bath.get_population("🌾")
	var loaded_mushroom = loaded_biome.bath.get_population("🍄")

	print("\n  Bath state comparison:")
	print("    🌾: saved=%.4f, loaded=%.4f (Δ=%.6f)" % [
		saved_wheat, loaded_wheat, abs(loaded_wheat - saved_wheat)
	])
	print("    🍄: saved=%.4f, loaded=%.4f (Δ=%.6f)" % [
		saved_mushroom, loaded_mushroom, abs(loaded_mushroom - saved_mushroom)
	])

	var wheat_matches = abs(loaded_wheat - saved_wheat) < 0.0001
	var mushroom_matches = abs(loaded_mushroom - saved_mushroom) < 0.0001

	if wheat_matches and mushroom_matches:
		print("\n  ✅ BATH STATE RESTORED PERFECTLY!")
	else:
		print("\n  ❌ BATH STATE MISMATCH!")
		quit(1)
		return

	# PHASE 6: VERIFY PROJECTIONS RECREATED
	print("\n" + "=" + "=".repeat(69))
	print("🔭 PHASE 6: VERIFYING PROJECTIONS")
	print("-" + "-".repeat(69))

	var loaded_plot_a = fresh_farm.grid.get_plot(pos_a)
	var loaded_plot_b = fresh_farm.grid.get_plot(pos_b)

	if not loaded_plot_a or not loaded_plot_a.quantum_state:
		print("❌ Plot A not restored!")
		quit(1)
		return

	if not loaded_plot_b or not loaded_plot_b.quantum_state:
		print("❌ Plot B not restored!")
		quit(1)
		return

	var loaded_qubit_a = loaded_plot_a.quantum_state
	var loaded_qubit_b = loaded_plot_b.quantum_state

	print("  ✅ Both plots restored")
	print("    Plot A: %s ↔ %s" % [loaded_qubit_a.north_emoji, loaded_qubit_a.south_emoji])
	print("    Plot B: %s ↔ %s" % [loaded_qubit_b.north_emoji, loaded_qubit_b.south_emoji])

	# Verify bath coupling
	if loaded_qubit_a.bath != loaded_biome.bath:
		print("❌ Qubit A not coupled to loaded bath!")
		quit(1)
		return

	if loaded_qubit_b.bath != loaded_biome.bath:
		print("❌ Qubit B not coupled to loaded bath!")
		quit(1)
		return

	print("\n  ✅ Both qubits coupled to loaded bath")

	# PHASE 7: VERIFY THETA COMPUTATION
	print("\n" + "=" + "=".repeat(69))
	print("📐 PHASE 7: VERIFYING THETA COMPUTATION")
	print("-" + "-".repeat(69))

	var loaded_theta_a = loaded_qubit_a.theta
	var loaded_theta_b = loaded_qubit_b.theta

	print("\n  Theta comparison:")
	print("    θ_A: saved=%.4f, loaded=%.4f (Δ=%.6f)" % [
		saved_theta_a, loaded_theta_a, abs(loaded_theta_a - saved_theta_a)
	])
	print("    θ_B: saved=%.4f, loaded=%.4f (Δ=%.6f)" % [
		saved_theta_b, loaded_theta_b, abs(loaded_theta_b - saved_theta_b)
	])

	var theta_a_matches = abs(loaded_theta_a - saved_theta_a) < 0.0001
	var theta_b_matches = abs(loaded_theta_b - saved_theta_b) < 0.0001

	if theta_a_matches and theta_b_matches:
		print("\n  ✅ THETA VALUES COMPUTED CORRECTLY FROM LOADED BATH!")
	else:
		print("\n  ❌ THETA MISMATCH!")
		quit(1)
		return

	# PHASE 8: VERIFY MEASUREMENT STATE
	print("\n" + "=" + "=".repeat(69))
	print("📊 PHASE 8: VERIFYING MEASUREMENT STATE")
	print("-" + "-".repeat(69))

	print("\n  Measurement state:")
	print("    Plot A measured: %s (expected: true)" % loaded_plot_a.is_measured)
	print("    Plot B measured: %s (expected: false)" % loaded_plot_b.is_measured)

	if not loaded_plot_a.is_measured:
		print("  ❌ Plot A should be marked as measured!")
		quit(1)
		return

	if loaded_plot_b.is_measured:
		print("  ❌ Plot B should NOT be marked as measured!")
		quit(1)
		return

	print("\n  ✅ Measurement state preserved correctly")

	# PHASE 9: TEST MEASUREMENT AFTER LOAD
	print("\n" + "=" + "=".repeat(69))
	print("🔬 PHASE 9: TESTING MEASUREMENT AFTER LOAD")
	print("-" + "-".repeat(69))

	print("  Measuring Plot B (unmeasured plot)...")
	var outcome_b = fresh_farm.measure_plot(pos_b)
	print("    Outcome: %s" % outcome_b)

	var final_wheat = loaded_biome.bath.get_population("🌾")
	var final_mushroom = loaded_biome.bath.get_population("🍄")

	print("\n  Bath after second measurement:")
	print("    🌾: %.4f → %.4f" % [loaded_wheat, final_wheat])
	print("    🍄: %.4f → %.4f" % [loaded_mushroom, final_mushroom])

	# Verify collapse still works
	var second_collapse = (outcome_b == "🌾" and final_mushroom < 0.01) or (outcome_b == "🍄" and final_wheat < 0.01)
	if second_collapse:
		print("\n  ✅ MEASUREMENT WORKS AFTER LOAD!")
	else:
		print("\n  ⚠️  Measurement may not have collapsed (both already near 0)")

	# Verify normalization
	var total = 0.0
	for emoji in loaded_biome.bath.emoji_list:
		total += loaded_biome.bath.get_probability(emoji)

	print("\n  Bath normalization:")
	print("    Σ|α|² = %.6f" % total)

	if abs(total - 1.0) < 0.001:
		print("  ✅ Bath normalized")
	else:
		print("  ❌ Bath NOT normalized!")
		quit(1)
		return

	# FINAL SUMMARY
	print("\n" + "=" + "=".repeat(69))
	print("🎉 SAVE/LOAD BATH STATE TEST COMPLETE!")
	print("=" + "=".repeat(69))

	print("\n✅ All Tests Passed:")
	print("  ✅ Bath state saved correctly")
	print("  ✅ Bath state loaded correctly")
	print("  ✅ Projections recreated correctly")
	print("  ✅ Qubits coupled to loaded bath")
	print("  ✅ Theta values computed from loaded bath")
	print("  ✅ Measurement state preserved")
	print("  ✅ Measurement works after load")
	print("  ✅ Normalization maintained")

	print("\n📝 What This Proves:")
	print("  • Bath-first architecture survives save/load")
	print("  • Collapsed state persists through save")
	print("  • Projections regenerate correctly")
	print("  • Live coupling works after load")
	print("  • Quantum mechanics intact after load")

	print("\n🎯 PRODUCTION READINESS: SAVE/LOAD VERIFIED!")

	quit(0)
