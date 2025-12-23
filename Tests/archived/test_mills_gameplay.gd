## test_mills_gameplay.gd - Test mill gameplay integration
## Simulates: Mill placement, wheat coupling, measurement, flour production

extends Node

const QuantumMill = preload("res://Core/GameMechanics/QuantumMill.gd")
const FlowRateCalculator = preload("res://Core/GameMechanics/FlowRateCalculator.gd")
const WheatPlot = preload("res://Core/GameMechanics/WheatPlot.gd")
const Biome = preload("res://Core/Environment/Biome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

var passed: int = 0
var failed: int = 0

func _ready():
	print("\n========================================")
	print("MILLS GAMEPLAY INTEGRATION TESTS")
	print("========================================")

	test_mill_creation()
	test_wheat_coupling_to_mill()
	test_measurement_stochasticity()
	test_flour_production_accumulation()
	test_flow_rate_statistics()
	test_measurement_collapses_wheat()

	print("\n========================================")
	var result = "RESULTS: " + str(passed) + " PASSED, " + str(failed) + " FAILED"
	print(result)
	print("========================================\n")

	if failed == 0:
		print("OK ALL MILLS TESTS PASSED!")
	else:
		print("SOME TESTS FAILED")

	get_tree().quit()


func test_mill_creation():
	print("\n[TEST 1] Mill Creation")

	var mill = QuantumMill.new()
	mill.grid_position = Vector2i(2, 2)
	mill.coupling_strength = 0.5
	mill.measurement_interval = 1.0

	assert_equal(mill.grid_position, Vector2i(2, 2), "Mill position set")
	assert_equal(mill.coupling_strength, 0.5, "Coupling strength set")
	assert_equal(mill.total_measurements, 0, "Measurements initialized to 0")
	assert_equal(mill.flour_outcomes, 0, "Flour outcomes initialized to 0")
	assert_true(mill.entangled_wheat.is_empty(), "Entangled wheat list empty initially")

	print("  Mill creation successful")


func test_wheat_coupling_to_mill():
	print("\n[TEST 2] Wheat Coupling to Mill")

	var biome = BioticFluxBiome.new()

	var wheat_plots = []
	for i in range(3):
		var plot = WheatPlot.new()
		plot.quantum_state = DualEmojiQubit.new()
		plot.quantum_state.theta = PI / 2.0
		plot.quantum_state.phi = 0.0
		plot.has_been_measured = false
		wheat_plots.append(plot)

	var mill = QuantumMill.new()
	mill.set_entangled_wheat(wheat_plots)

	assert_equal(mill.entangled_wheat.size(), 3, "Mill linked to 3 wheat plots")

	for plot in wheat_plots:
		plot.quantum_state.couple_to_ancilla(0.5, 1.0)
		assert_true(plot.quantum_state.is_coupled_to_ancilla, "Wheat coupled to ancilla")

	print("  Wheat coupling successful")


func test_measurement_stochasticity():
	print("\n[TEST 3] Measurement Stochasticity")

	var biome = BioticFluxBiome.new()

	var wheat_plots = []
	for i in range(10):
		var plot = WheatPlot.new()
		plot.quantum_state = DualEmojiQubit.new()
		plot.quantum_state.theta = PI / 2.0
		plot.quantum_state.phi = 0.0
		plot.has_been_measured = false
		wheat_plots.append(plot)

	var mill = QuantumMill.new()
	mill.set_entangled_wheat(wheat_plots)
	mill.biome = biome

	var total_flour = 0
	var measurement_count = 0

	for cycle in range(5):
		mill.perform_quantum_measurement()
		total_flour += mill.measurement_history[-1]["flour_produced"]
		measurement_count += 1

	assert_true(total_flour > 0, "Got at least some flour outcomes")
	assert_true(total_flour < 50, "Not all measurements produced flour")

	var msg = "Stochasticity verified: flour=" + str(total_flour) + " cycles=" + str(measurement_count)
	print("  " + msg)


func test_flour_production_accumulation():
	print("\n[TEST 4] Flour Production Accumulation")

	var biome = BioticFluxBiome.new()

	var wheat_plots = []
	for i in range(5):
		var plot = WheatPlot.new()
		plot.quantum_state = DualEmojiQubit.new()
		plot.quantum_state.theta = PI / 2.0
		plot.quantum_state.phi = 0.0
		plot.has_been_measured = false
		wheat_plots.append(plot)

	var mill = QuantumMill.new()
	mill.set_entangled_wheat(wheat_plots)
	mill.biome = biome

	var initial_flour = mill.flour_outcomes
	var initial_measurements = mill.total_measurements

	for i in range(3):
		mill.perform_quantum_measurement()

	assert_equal(mill.total_measurements, initial_measurements + 3, "Measurement count incremented")
	assert_true(mill.flour_outcomes >= initial_flour, "Flour outcomes accumulated")
	assert_equal(mill.measurement_history.size(), 3, "Measurement history has 3 entries")

	var msg = "Flour accumulation: outcomes=" + str(mill.flour_outcomes) + " measurements=" + str(mill.total_measurements)
	print("  " + msg)


func test_flow_rate_statistics():
	print("\n[TEST 5] Flow Rate Statistics")

	var biome = BioticFluxBiome.new()

	var wheat_plots = []
	for i in range(10):
		var plot = WheatPlot.new()
		plot.quantum_state = DualEmojiQubit.new()
		plot.quantum_state.theta = PI / 2.0
		plot.quantum_state.phi = 0.0
		plot.has_been_measured = false
		wheat_plots.append(plot)

	var mill = QuantumMill.new()
	mill.set_entangled_wheat(wheat_plots)
	mill.biome = biome

	for i in range(10):
		mill.perform_quantum_measurement()

	var flow_rate = mill.get_flow_rate()

	assert_true(flow_rate.has("mean"), "Flow rate has mean")
	assert_true(flow_rate.has("variance"), "Flow rate has variance")
	assert_true(flow_rate.has("std_error"), "Flow rate has std_error")
	assert_true(flow_rate.has("confidence"), "Flow rate has confidence")
	assert_true(flow_rate["mean"] >= 0.0, "Mean is non-negative")
	assert_true(flow_rate["confidence"] > 0.0, "Confidence is positive")
	assert_true(flow_rate["confidence"] <= 1.0, "Confidence is bounded")

	print("  Flow rate statistics computed successfully")


func test_measurement_collapses_wheat():
	print("\n[TEST 6] Measurement Collapse Visual")

	var biome = BioticFluxBiome.new()

	var wheat_plots = []
	for i in range(3):
		var plot = WheatPlot.new()
		plot.quantum_state = DualEmojiQubit.new()
		plot.quantum_state.theta = PI / 2.0
		plot.quantum_state.phi = PI / 4.0
		plot.has_been_measured = false
		wheat_plots.append(plot)

	var mill = QuantumMill.new()
	mill.set_entangled_wheat(wheat_plots)
	mill.biome = biome

	for plot in wheat_plots:
		assert_equal(plot.has_been_measured, false, "Wheat not measured initially")
		assert_true(plot.quantum_state.theta > 0.1 and plot.quantum_state.theta < PI - 0.1, "Wheat in superposition")

	mill.perform_quantum_measurement()

	for i in range(wheat_plots.size()):
		var plot = wheat_plots[i]
		assert_true(plot.has_been_measured, "Wheat marked as measured")
		var at_north = abs(plot.quantum_state.theta) < 0.01
		var at_south = abs(plot.quantum_state.theta - PI) < 0.01
		var collapsed = at_north or at_south
		assert_true(collapsed, "Wheat collapsed to pole")
		assert_equal(plot.quantum_state.phi, 0.0, "Phase reset to 0")

	print("  Measurement collapse verified")


func assert_true(condition: bool, message: String):
	if condition:
		passed += 1
		print("    PASS " + message)
	else:
		failed += 1
		print("    FAIL " + message)

func assert_equal(actual, expected, message: String):
	if actual == expected:
		passed += 1
		print("    PASS " + message)
	else:
		failed += 1
		var msg = "FAIL " + message + " (got " + str(actual) + ", expected " + str(expected) + ")"
		print("    " + msg)
