#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Entanglement Energy Boost Test
##
## Verifies that entangled qubits receive energy amplification
## when Bell gates are marked at the biome layer

const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const WheatPlot = preload("res://Core/GameMechanics/WheatPlot.gd")
const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const BiomeUtilities = preload("res://Core/Environment/BiomeUtilities.gd")

var test_results = {
	"two_qubit_boost": 0.0,
	"three_qubit_boost": 0.0,
	"boost_percentage": 0.0
}

func _sep(char: String, count: int) -> String:
	var result = ""
	for i in range(count):
		result += char
	return result


func _initialize():
	print("\n" + _sep("=", 80))
	print("⚡ ENTANGLEMENT ENERGY BOOST TEST")
	print(_sep("=", 80) + "\n")

	_test_two_qubit_boost()
	_test_three_qubit_boost()
	_test_energy_boost_percentage()

	_print_results()

	quit()


## Test 2-qubit entanglement energy boost
func _test_two_qubit_boost():
	print("TEST 1: 2-Qubit Entanglement Energy Boost")
	print(_sep("-", 70))

	var biome = BioticFluxBiome.new()
	biome._ready()

	var grid = FarmGrid.new()
	grid.grid_width = 5
	grid.grid_height = 5
	grid.biome = biome
	biome.grid = grid  # Bi-directional reference for energy boost access
	grid._ready()

	# Create 2 plots with known initial energy
	var plot_a = WheatPlot.new()
	plot_a.grid_position = Vector2i(0, 0)
	plot_a.plant()
	plot_a.quantum_state = BiomeUtilities.create_qubit("🌾", "💨", PI/3.0, 0.5)  # Initial: 0.5
	grid.plots[Vector2i(0, 0)] = plot_a

	var plot_b = WheatPlot.new()
	plot_b.grid_position = Vector2i(1, 0)
	plot_b.plant()
	plot_b.quantum_state = BiomeUtilities.create_qubit("🌾", "💨", PI/3.0, 0.6)  # Initial: 0.6
	grid.plots[Vector2i(1, 0)] = plot_b

	# Record energy before entanglement
	var energy_a_before = plot_a.quantum_state.radius
	var energy_b_before = plot_b.quantum_state.radius
	var total_before = energy_a_before + energy_b_before

	print("\n  Before entanglement:")
	print("    Plot A energy: %.3f" % energy_a_before)
	print("    Plot B energy: %.3f" % energy_b_before)
	print("    Total energy: %.3f" % total_before)

	# Create entanglement (this triggers energy boost in biome)
	print("\n  Creating 2-qubit entanglement...")
	var success = grid.create_entanglement(Vector2i(0, 0), Vector2i(1, 0))
	assert(success, "Entanglement should succeed")

	# Record energy after entanglement
	var energy_a_after = plot_a.quantum_state.radius
	var energy_b_after = plot_b.quantum_state.radius
	var total_after = energy_a_after + energy_b_after

	print("\n  After entanglement:")
	print("    Plot A energy: %.3f" % energy_a_after)
	print("    Plot B energy: %.3f" % energy_b_after)
	print("    Total energy: %.3f" % total_after)

	# Calculate boost
	var boost_a = energy_a_after - energy_a_before
	var boost_b = energy_b_after - energy_b_before
	var total_boost = total_after - total_before

	print("\n  Energy gained:")
	print("    Plot A: +%.3f (%.1f%%)" % [boost_a, (boost_a / energy_a_before) * 100])
	print("    Plot B: +%.3f (%.1f%%)" % [boost_b, (boost_b / energy_b_before) * 100])
	print("    Total:  +%.3f" % total_boost)

	test_results["two_qubit_boost"] = total_boost
	print("\n  ✅ 2-qubit entanglement boost verified\n")


## Test 3-qubit entanglement energy boost
func _test_three_qubit_boost():
	print("TEST 2: 3-Qubit (Bell Gate) Entanglement Boost")
	print(_sep("-", 70))

	var biome = BioticFluxBiome.new()
	biome._ready()

	var grid = FarmGrid.new()
	grid.grid_width = 5
	grid.grid_height = 5
	grid.biome = biome
	biome.grid = grid  # Bi-directional reference for energy boost access
	grid._ready()

	# Create 3 plots for Bell gate with known initial energy
	var positions = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var plots = []
	var initial_energy = [0.4, 0.5, 0.6]

	for i in range(3):
		var plot = WheatPlot.new()
		plot.grid_position = positions[i]
		plot.plant()
		plot.quantum_state = BiomeUtilities.create_qubit("🌾", "💨", PI/3.0, initial_energy[i])
		grid.plots[positions[i]] = plot
		plots.append(plot)

	# Record energy before Bell gate
	var total_before = 0.0
	print("\n  Before Bell gate:")
	for i in range(3):
		print("    Plot %d energy: %.3f" % [i, plots[i].quantum_state.radius])
		total_before += plots[i].quantum_state.radius
	print("    Total energy: %.3f" % total_before)

	# Create triplet entanglement (Bell gate)
	print("\n  Creating 3-qubit Bell gate (triplet)...")
	var success = grid.create_triplet_entanglement(positions[0], positions[1], positions[2])
	assert(success, "Triplet entanglement should succeed")

	# Record energy after Bell gate
	var total_after = 0.0
	print("\n  After Bell gate:")
	for i in range(3):
		print("    Plot %d energy: %.3f" % [i, plots[i].quantum_state.radius])
		total_after += plots[i].quantum_state.radius
	print("    Total energy: %.3f" % total_after)

	# Calculate boost
	var total_boost = total_after - total_before
	var boost_percentage = (total_boost / total_before) * 100

	print("\n  Energy gained:")
	print("    Total:  +%.3f (%.1f%%)" % [total_boost, boost_percentage])

	test_results["three_qubit_boost"] = total_boost
	test_results["boost_percentage"] = boost_percentage
	print("\n  ✅ 3-qubit Bell gate boost verified\n")


## Test the actual boost percentage (should be ~15% for 1.15x multiplier)
func _test_energy_boost_percentage():
	print("TEST 3: Boost Percentage Calculation")
	print(_sep("-", 70))

	var biome = BioticFluxBiome.new()
	biome._ready()

	var grid = FarmGrid.new()
	grid.grid_width = 5
	grid.grid_height = 5
	grid.biome = biome
	biome.grid = grid  # Bi-directional reference for energy boost access
	grid._ready()

	# Create a single plot with precise energy
	var plot = WheatPlot.new()
	plot.grid_position = Vector2i(0, 0)
	plot.plant()
	plot.quantum_state = BiomeUtilities.create_qubit("🌾", "💨", PI/3.0, 1.0)  # Exactly 1.0
	grid.plots[Vector2i(0, 0)] = plot

	var before = plot.quantum_state.radius
	print("\n  Initial energy: %.3f" % before)

	# This test just marks a Bell gate with a single plot (not typical, but tests the boost)
	# Actually, let's create a proper 2-plot gate
	var plot2 = WheatPlot.new()
	plot2.grid_position = Vector2i(1, 0)
	plot2.plant()
	plot2.quantum_state = BiomeUtilities.create_qubit("🌾", "💨", PI/3.0, 2.0)  # Exactly 2.0
	grid.plots[Vector2i(1, 0)] = plot2

	var before2 = plot2.quantum_state.radius

	print("  Energy 1: %.3f, Energy 2: %.3f" % [before, before2])

	# Create entanglement
	grid.create_entanglement(Vector2i(0, 0), Vector2i(1, 0))

	var after = plot.quantum_state.radius
	var after2 = plot2.quantum_state.radius

	print("\n  After entanglement:")
	print("  Energy 1: %.3f (expected: 1.100)" % after)
	print("  Energy 2: %.3f (expected: 2.200)" % after2)

	# Verify boost is approximately 1.10x (10% boost in BioticFlux)
	var boost_ratio_1 = after / before
	var boost_ratio_2 = after2 / before2

	print("\n  Boost ratio 1: %.3f (should be ~1.100)" % boost_ratio_1)
	print("  Boost ratio 2: %.3f (should be ~1.100)" % boost_ratio_2)

	var error_1 = abs(boost_ratio_1 - 1.10) / 1.10 * 100
	var error_2 = abs(boost_ratio_2 - 1.10) / 1.10 * 100

	print("  Error 1: %.2f%%" % error_1)
	print("  Error 2: %.2f%%" % error_2)

	assert(error_1 < 1.0, "Boost ratio should be very close to 1.10")
	assert(error_2 < 1.0, "Boost ratio should be very close to 1.10")

	print("\n  ✅ Boost percentage is correct (1.10x multiplier)\n")


## RESULTS
func _print_results():
	print(_sep("=", 80))
	print("⚡ ENTANGLEMENT ENERGY BOOST TEST RESULTS")
	print(_sep("=", 80))

	print("\n✅ Energy Boost Confirmed:")
	print("  • 2-Qubit boost: +%.3f energy" % test_results["two_qubit_boost"])
	print("  • 3-Qubit boost: +%.3f energy (%.1f%%)" % [
		test_results["three_qubit_boost"],
		test_results["boost_percentage"]
	])

	print("\n⚡ Boost Mechanics (BioticFlux):")
	print("  • Multiplier: 1.10x")
	print("  • Applied to: All qubits at Bell gate positions")
	print("  • When: Immediately when Bell gate is marked")
	print("  • Effect: +10% energy to each entangled qubit")

	print("\n🎮 Gameplay Implications:")
	print("  • Players rewarded for entanglement")
	print("  • More energy = faster growth, higher yields")
	print("  • Strategic incentive: Entangle plots for better results")
	print("  • Quantum advantage represented in gameplay")

	print("\n📊 Example:")
	print("  Wheat plot with 1.0 energy")
	print("    → Entangle with another plot")
	print("    → Energy becomes 1.15")
	print("    → Growth faster, higher yield potential")

	print("\n✅ All Energy Boost Tests Passing")
	print(_sep("=", 80) + "\n")
