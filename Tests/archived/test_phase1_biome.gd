## Test Suite for Phase 1: Biome System
## Tests temperature, sun/moon cycle, and decoherence rates

extends SceneTree

const Biome = preload("res://Core/Environment/Biome.gd")

var test_results = []
var biome: Biome = null
var separator = "============================================================"

func _initialize():
	print("\n" + separator)
	print("🧪 PHASE 1 TEST SUITE: Biome System")
	print(separator)

	biome = BioticFluxBiome.new()

	test_biome_initialization()
	test_sun_moon_cycle()
	test_temperature_variation()
	test_decoherence_rates()
	test_energy_strength()

	print_test_summary()


## Test 1: Biome Initialization
func test_biome_initialization():
	print("\n[TEST 1] Biome Initialization")

	assert(biome != null, "Biome instance created")
	assert(biome.sun_moon_phase == 0.0, "Sun/moon phase starts at 0")
	assert(biome.sun_moon_period == 20.0, "Sun/moon period is 20 seconds")
	assert(biome.base_temperature == 300.0, "Base temperature is 300K")
	assert(biome.is_currently_sun() == true, "Starts in sun phase")

	record_result("Biome Initialization", true)
	print("✅ Passed: Biome initialized correctly")


## Test 2: Sun/Moon Cycle
func test_sun_moon_cycle():
	print("\n[TEST 2] Sun/Moon Cycle Evolution")

	var initial_phase = biome.sun_moon_phase
	var initial_sun = biome.is_currently_sun()

	# Simulate 5 seconds of evolution
	for i in range(5):
		biome._process(1.0)

	var phase_after = biome.sun_moon_phase
	var expected_phase = initial_phase + (TAU / 20.0) * 5.0

	assert(phase_after > initial_phase, "Phase advances over time")
	assert(abs(phase_after - expected_phase) < 0.01, "Phase matches expected value")
	assert(biome.is_currently_sun() == initial_sun, "Still in sun phase after 5s")

	# Simulate 10 seconds (halfway through cycle)
	for i in range(10):
		biome._process(1.0)

	assert(biome.is_currently_sun() == false, "Transitioned to moon phase")

	record_result("Sun/Moon Cycle", true)
	print("✅ Passed: Sun/moon cycle evolution correct")


## Test 3: Temperature Variation
func test_temperature_variation():
	print("\n[TEST 3] Temperature Parametric Variation")

	biome.sun_moon_phase = 0.0  # Noon (peak energy)
	biome._update_temperature_from_cycle()
	var temp_noon = biome.base_temperature

	biome.sun_moon_phase = PI / 2.0  # Dawn/dusk (minimum energy)
	biome._update_temperature_from_cycle()
	var temp_dawn = biome.base_temperature

	biome.sun_moon_phase = PI  # Midnight (peak energy)
	biome._update_temperature_from_cycle()
	var temp_midnight = biome.base_temperature

	print("  Noon temp: %.1fK" % temp_noon)
	print("  Dawn temp: %.1fK" % temp_dawn)
	print("  Midnight temp: %.1fK" % temp_midnight)

	assert(temp_noon > temp_dawn, "Noon hotter than dawn")
	assert(temp_midnight > temp_dawn, "Midnight hotter than dawn")
	assert(abs(temp_noon - temp_midnight) < 1.0, "Noon and midnight similar temps")

	record_result("Temperature Variation", true)
	print("✅ Passed: Temperature varies with sun/moon cycle")


## Test 4: Decoherence Rates
func test_decoherence_rates():
	print("\n[TEST 4] Decoherence Rates (T1/T2)")

	var pos = Vector2i(0, 0)

	# At baseline temperature (300K)
	biome.base_temperature = 300.0
	var T1_baseline = biome.get_T1_rate(pos)
	var T2_baseline = biome.get_T2_rate(pos)

	print("  T1 rate (300K): %.6f" % T1_baseline)
	print("  T2 rate (300K): %.6f" % T2_baseline)

	# At hot temperature (500K)
	biome.base_temperature = 500.0
	var T1_hot = biome.get_T1_rate(pos)
	var T2_hot = biome.get_T2_rate(pos)

	print("  T1 rate (500K): %.6f" % T1_hot)
	print("  T2 rate (500K): %.6f" % T2_hot)

	# At cold temperature (100K)
	biome.base_temperature = 100.0
	var T1_cold = biome.get_T1_rate(pos)
	var T2_cold = biome.get_T2_rate(pos)

	print("  T1 rate (100K): %.6f" % T1_cold)
	print("  T2 rate (100K): %.6f" % T2_cold)

	assert(T1_hot > T1_baseline, "Hotter = higher T1 rate")
	assert(T1_cold < T1_baseline, "Colder = lower T1 rate")
	assert(T2_hot > T2_baseline, "Hotter = higher T2 rate")
	assert(T2_cold < T2_baseline, "Colder = lower T2 rate")

	record_result("Decoherence Rates", true)
	print("✅ Passed: T1/T2 rates scale with temperature")


## Test 5: Energy Strength
func test_energy_strength():
	print("\n[TEST 5] Energy Strength")

	biome.sun_moon_phase = 0.0  # Noon (peak)
	var energy_noon = biome.get_energy_strength()

	biome.sun_moon_phase = PI / 2.0  # Dawn (low)
	var energy_dawn = biome.get_energy_strength()

	biome.sun_moon_phase = PI  # Midnight (peak)
	var energy_midnight = biome.get_energy_strength()

	print("  Energy (noon): %.2f" % energy_noon)
	print("  Energy (dawn): %.2f" % energy_dawn)
	print("  Energy (midnight): %.2f" % energy_midnight)

	assert(energy_noon > 0.9, "Noon energy near max")
	assert(energy_midnight > 0.9, "Midnight energy near max")
	assert(energy_dawn < 0.1, "Dawn energy near min")

	record_result("Energy Strength", true)
	print("✅ Passed: Energy strength follows cycle")


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
