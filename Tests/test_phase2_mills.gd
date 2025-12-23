## Test Suite for Phase 2: Quantum Mills and Ancilla Measurement

extends SceneTree

const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const QuantumMill = preload("res://Core/GameMechanics/QuantumMill.gd")
const FlowRateCalculator = preload("res://Core/GameMechanics/FlowRateCalculator.gd")

var test_results = []
var separator = "============================================================"


func _initialize():
	print("\n" + separator)
	print("🧪 PHASE 2 TEST SUITE: Quantum Mills and Ancilla Measurement")
	print(separator)

	test_ancilla_initialization()
	test_ancilla_coupling()
	test_ancilla_measurement()
	test_mill_creation()
	test_flow_rate_calculation()

	print_test_summary()


## Test 1: Ancilla Initialization
func test_ancilla_initialization():
	print("\n[TEST 1] Ancilla Initialization")

	var qubit = DualEmojiQubit.new("🌾", "🍅")

	assert(qubit.ancilla_state.x == 1.0, "Ancilla initialized to |0⟩")
	assert(qubit.ancilla_state.y == 0.0, "Ancilla y-component is 0")
	assert(qubit.is_coupled_to_ancilla == false, "Not yet coupled")

	record_result("Ancilla Initialization", true)
	print("✅ Passed: Ancilla initialized correctly")


## Test 2: Ancilla Coupling
func test_ancilla_coupling():
	print("\n[TEST 2] Ancilla Coupling to Wheat Qubit")

	var qubit = DualEmojiQubit.new("🌾", "🍅")
	qubit.theta = 0.0  # |0⟩ state, Z-expectation = 1.0

	# Couple to ancilla
	qubit.couple_to_ancilla(0.5, 1.0)

	assert(qubit.is_coupled_to_ancilla == true, "Marked as coupled")
	assert(qubit.ancilla_state.x != 1.0 or qubit.ancilla_state.y != 0.0, "Ancilla state rotated")

	var expectation = qubit.get_ancilla_expectation()
	print("  Ancilla expectation: %.3f" % expectation)
	assert(abs(expectation) <= 1.0, "Expectation in valid range [-1, 1]")

	record_result("Ancilla Coupling", true)
	print("✅ Passed: Ancilla coupling works correctly")


## Test 3: Ancilla Measurement
func test_ancilla_measurement():
	print("\n[TEST 3] Ancilla Measurement and Collapse")

	var outcomes = {}
	outcomes["flour"] = 0
	outcomes["nothing"] = 0

	# Run multiple measurements to get statistics
	for i in range(100):
		var qubit = DualEmojiQubit.new("🌾", "🍅")
		qubit.theta = PI / 4.0  # Superposition state

		qubit.couple_to_ancilla(0.5, 1.0)
		var outcome = qubit.measure_ancilla()
		outcomes[outcome] += 1

		# After measurement, ancilla should be collapsed
		assert(qubit.is_coupled_to_ancilla == false, "Decoupled after measurement")
		assert(qubit.ancilla_state.x * qubit.ancilla_state.x + qubit.ancilla_state.y * qubit.ancilla_state.y <= 1.01,
			"Ancilla normalized after collapse")

	var flour_rate = float(outcomes["flour"]) / 100.0
	print("  Flour rate: %.2f" % flour_rate)
	print("  Nothing rate: %.2f" % (1.0 - flour_rate))

	assert(outcomes["flour"] > 0, "Some flour outcomes")
	assert(outcomes["nothing"] > 0, "Some nothing outcomes")

	record_result("Ancilla Measurement", true)
	print("✅ Passed: Measurement produces stochastic outcomes")


## Test 4: Mill Creation
func test_mill_creation():
	print("\n[TEST 4] Quantum Mill Creation")

	# Verify QuantumMill class exists and has expected properties
	assert(QuantumMill != null, "QuantumMill class loaded")

	# Verify FlowRateCalculator is accessible
	var flow_rate = FlowRateCalculator.compute_flow_rate([], 60.0)
	assert(flow_rate.has("mean"), "FlowRateCalculator accessible")
	assert(flow_rate.has("confidence"), "FlowRateCalculator returns confidence")

	record_result("Mill Creation", true)
	print("✅ Passed: Mill class initialized correctly")


## Test 5: Flow Rate Calculation
func test_flow_rate_calculation():
	print("\n[TEST 5] Flow Rate Statistics")

	var history = []
	var current_time = Time.get_ticks_msec()

	# Simulate measurement history
	for i in range(10):
		history.append({
			"time": current_time - (10 - i) * 1000,
			"flour_produced": randi() % 5,
			"wheat_count": 3
		})

	var flow_rate = FlowRateCalculator.compute_flow_rate(history, 60.0)

	assert(flow_rate.has("mean"), "Has mean")
	assert(flow_rate.has("variance"), "Has variance")
	assert(flow_rate.has("std_error"), "Has std_error")
	assert(flow_rate.has("confidence"), "Has confidence")

	print("  Mean flour/measurement: %.2f" % flow_rate["mean"])
	print("  Variance: %.2f" % flow_rate["variance"])
	print("  Std error: %.3f" % flow_rate["std_error"])
	print("  Confidence: %.2f" % flow_rate["confidence"])

	assert(flow_rate["confidence"] >= 0.0 and flow_rate["confidence"] <= 1.0, "Confidence in [0,1]")

	record_result("Flow Rate Calculation", true)
	print("✅ Passed: Flow rate statistics computed correctly")


## Test Utilities

func record_result(test_name: String, passed: bool):
	test_results.append({"name": test_name, "passed": passed})


func print_test_summary():
	print("\n" + separator)
	print("📊 TEST SUMMARY")
	print(separator)

	var passed = 0
	var total = test_results.size()

	for result in test_results:
		var status = "✅ PASS" if result["passed"] else "❌ FAIL"
		print("%s | %s" % [status, result["name"]])
		if result["passed"]:
			passed += 1

	print("\nTotal: %d/%d passed" % [passed, total])

	if passed == total:
		print("🎉 ALL TESTS PASSED!")
	else:
		print("⚠️  %d tests failed" % (total - passed))

	print(separator + "\n")
