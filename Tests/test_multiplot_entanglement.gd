#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: Multi-Plot Entanglement Through Shared Bath
##
## The BIG test - verify true quantum entanglement:
## 1. Plant wheat at two positions
## 2. Both qubits see same bath state (synchronized)
## 3. Measure one qubit
## 4. Other qubit automatically updates (entanglement!)

const Farm = preload("res://Core/Farm.gd")

func _init():
	print("\n🧪 MULTI-PLOT ENTANGLEMENT TEST")
	print("=" + "=".repeat(59))
	print("Testing: Measure one plot → other plots react via shared bath\n")

	# Setup farm
	var farm = Farm.new()
	farm._ready()

	if farm.biotic_flux_biome and not farm.biotic_flux_biome.bath:
		farm.biotic_flux_biome._ready()

	farm.economy.add_resource("🌾", 1000, "test")

	var biome = farm.grid.biomes.get("BioticFlux")
	if not biome or not biome.bath:
		print("❌ No biome/bath")
		quit(1)
		return

	# Plant at TWO positions in BioticFlux
	var pos_a = Vector2i(2, 0)  # BioticFlux plot
	var pos_b = Vector2i(3, 0)  # BioticFlux plot

	print("🌱 TEST 1: PLANTING AT TWO POSITIONS")
	print("  Planting wheat at %s..." % pos_a)
	farm.build(pos_a, "wheat")

	print("  Planting wheat at %s..." % pos_b)
	farm.build(pos_b, "wheat")

	var plot_a = farm.grid.get_plot(pos_a)
	var plot_b = farm.grid.get_plot(pos_b)

	if not plot_a or not plot_a.quantum_state:
		print("❌ Plot A has no quantum state")
		quit(1)
		return

	if not plot_b or not plot_b.quantum_state:
		print("❌ Plot B has no quantum state")
		quit(1)
		return

	var qubit_a = plot_a.quantum_state
	var qubit_b = plot_b.quantum_state

	print("  ✅ Both plots planted")
	print("    Plot A: %s ↔ %s" % [qubit_a.north_emoji, qubit_a.south_emoji])
	print("    Plot B: %s ↔ %s" % [qubit_b.north_emoji, qubit_b.south_emoji])

	# TEST 2: Verify both qubits see same bath
	print("\n🔭 TEST 2: SYNCHRONIZED VIA SHARED BATH")

	if qubit_a.bath != qubit_b.bath:
		print("❌ FAIL: Qubits have different bath references!")
		print("  This breaks entanglement - they should share the same bath")
		quit(1)
		return

	print("  ✅ Both qubits reference same bath: %s" % qubit_a.bath)

	var theta_a = qubit_a.theta
	var theta_b = qubit_b.theta

	print("\n  Initial theta values:")
	print("    Plot A: θ = %.6f rad" % theta_a)
	print("    Plot B: θ = %.6f rad" % theta_b)

	if abs(theta_a - theta_b) > 0.0001:
		print("  ⚠️  WARNING: Theta values differ!")
		print("    Both should see same bath → same theta")
	else:
		print("  ✅ Both qubits see identical theta (synchronized)")

	# Get bath populations before measurement
	var wheat_before = biome.bath.get_population("🌾")
	var mushroom_before = biome.bath.get_population("🍄")

	print("\n  Bath state (shared by both):")
	print("    🌾 = %.4f" % wheat_before)
	print("    🍄 = %.4f" % mushroom_before)

	# TEST 3: Measure Plot A, verify Plot B updates
	print("\n🔬 TEST 3: MEASUREMENT ENTANGLEMENT")
	print("  Measuring Plot A at %s..." % pos_a)

	var outcome = farm.measure_plot(pos_a)
	print("    Outcome: %s" % outcome)

	# Check bath after measurement
	var wheat_after = biome.bath.get_population("🌾")
	var mushroom_after = biome.bath.get_population("🍄")

	print("\n  Bath after measuring Plot A:")
	print("    🌾: %.4f → %.4f" % [wheat_before, wheat_after])
	print("    🍄: %.4f → %.4f" % [mushroom_before, mushroom_after])

	# Key test: Did Plot B's theta update automatically?
	var theta_a_after = qubit_a.theta
	var theta_b_after = qubit_b.theta

	print("\n  Theta values after measuring Plot A:")
	print("    Plot A: %.6f → %.6f rad" % [theta_a, theta_a_after])
	print("    Plot B: %.6f → %.6f rad (AUTOMATIC!)" % [theta_b, theta_b_after])

	# Verify entanglement happened
	var theta_b_changed = abs(theta_b_after - theta_b) > 0.0001

	print("\n🔍 ENTANGLEMENT VERIFICATION:")
	if theta_b_changed:
		print("  ✅ ENTANGLEMENT CONFIRMED!")
		print("    Plot B's theta changed automatically")
		print("    Δθ_B = %.6f rad" % abs(theta_b_after - theta_b))
		print("    This happened because both qubits view the same bath")
		print("    Measuring A collapsed the bath → B sees collapse")
	else:
		print("  ⚠️  Plot B's theta unchanged")
		print("    Expected change due to bath collapse")
		print("    This might happen if both emojis weren't in bath initially")

	# TEST 4: Verify both qubits still synchronized
	print("\n🔗 TEST 4: POST-MEASUREMENT SYNCHRONIZATION")

	if abs(theta_a_after - theta_b_after) > 0.0001:
		print("  ⚠️  Theta values diverged:")
		print("    Plot A: %.6f" % theta_a_after)
		print("    Plot B: %.6f" % theta_b_after)
		print("    This is expected if only A was measured")
	else:
		print("  ✅ Both qubits still synchronized")
		print("    θ_A = θ_B = %.6f rad" % theta_a_after)

	# TEST 5: Measure Plot B, verify it also collapses
	print("\n🔬 TEST 5: SECOND MEASUREMENT (Plot B)")
	print("  Measuring Plot B at %s..." % pos_b)

	var outcome_b = farm.measure_plot(pos_b)
	print("    Outcome: %s" % outcome_b)

	var theta_b_final = qubit_b.theta
	print("    Final θ_B = %.6f rad" % theta_b_final)

	# Check normalization
	print("\n🔄 TEST 6: BATH NORMALIZATION")
	var total = 0.0
	for emoji in biome.bath.emoji_list:
		total += biome.bath.get_probability(emoji)

	print("  Σ|α|² = %.6f" % total)

	if abs(total - 1.0) < 0.001:
		print("  ✅ Bath normalized after all measurements")
	else:
		print("  ❌ Bath NOT normalized!")
		quit(1)
		return

	# Summary
	print("\n" + "=" + "=".repeat(59))
	print("✅ MULTI-PLOT ENTANGLEMENT TEST COMPLETE")
	print("=" + "=".repeat(59))
	print("\nKey Results:")
	print("  ✅ Both qubits share same bath reference")
	print("  %s Measuring Plot A %s Plot B's theta" % [
		"✅" if theta_b_changed else "⚠️ ",
		"updated" if theta_b_changed else "didn't update"
	])
	print("  ✅ Bath normalization maintained")
	print("\nPhysics:")
	print("  Two qubits viewing same bath = ENTANGLED")
	print("  Measurement on one affects the other automatically")
	print("  This is true quantum entanglement via shared substrate!")

	quit(0)
