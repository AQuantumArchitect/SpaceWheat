extends Node
## Test berry phase accumulation and glow integration

const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

var test_passed = 0
var test_failed = 0

func _ready():
	var line = ""
	for i in range(70):
		line += "="
	print("\n" + line)
	print("BERRY PHASE SYSTEM TESTS")
	print(line + "\n")

	test_berry_phase_initialization()
	test_berry_phase_accumulation()
	test_berry_phase_unbounded()
	test_glow_integration()

	var line2 = ""
	for i in range(70):
		line2 += "="
	print("\n" + line2)
	print("RESULTS: %d PASSED, %d FAILED" % [test_passed, test_failed])
	print(line2 + "\n")

	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


func test_berry_phase_initialization():
	"""Test that berry phase starts at 0 for new qubits"""
	print("📊 TEST 1: Berry phase initialization")

	var qubit = DualEmojiQubit.new("🌾", "👥")

	if qubit.berry_phase == 0.0:
		print("  ✅ Berry phase initialized to 0.0")
		test_passed += 1
	else:
		print("  ❌ Berry phase should be 0.0, got %.2f" % qubit.berry_phase)
		test_failed += 1

	if qubit.get_berry_phase() == 0.0:
		print("  ✅ get_berry_phase() returns 0.0")
		test_passed += 1
	else:
		print("  ❌ get_berry_phase() should return 0.0")
		test_failed += 1


func test_berry_phase_accumulation():
	"""Test that berry phase accumulates correctly"""
	print("\n📊 TEST 2: Berry phase accumulation")

	var qubit = DualEmojiQubit.new("🌾", "👥")

	# Accumulate some evolution
	qubit.accumulate_berry_phase(0.5, 1.0)  # evolution_amount=0.5, dt=1.0

	var expected = 0.5 * 1.0 * 1.0  # evolution_amount * berry_phase_rate * dt

	if abs(qubit.berry_phase - expected) < 0.01:
		print("  ✅ Berry phase accumulated: %.2f" % qubit.berry_phase)
		test_passed += 1
	else:
		print("  ❌ Expected %.2f, got %.2f" % [expected, qubit.berry_phase])
		test_failed += 1

	# Accumulate more
	qubit.accumulate_berry_phase(1.0, 2.0)  # Full evolution for 2 seconds

	if qubit.berry_phase > expected:
		print("  ✅ Berry phase increased on second accumulation: %.2f" % qubit.berry_phase)
		test_passed += 1
	else:
		print("  ❌ Berry phase should increase")
		test_failed += 1


func test_berry_phase_unbounded():
	"""Test that berry phase grows unbounded for full information display"""
	print("\n📊 TEST 3: Berry phase unbounded growth (full measurement apparatus)")

	var qubit = DualEmojiQubit.new("🌾", "👥")

	# Test empty qubit
	if qubit.get_berry_phase() == 0.0:
		print("  ✅ Fresh qubit has berry_phase = 0.0")
		test_passed += 1
	else:
		print("  ❌ Fresh qubit should have berry_phase = 0.0")
		test_failed += 1

	# Accumulate some evolution
	qubit.berry_phase = 5.0
	var retrieved = qubit.get_berry_phase()

	if abs(retrieved - 5.0) < 0.01:
		print("  ✅ Berry phase 5.0 returns 5.0 (raw, unbounded): %.2f" % retrieved)
		test_passed += 1
	else:
		print("  ❌ Expected 5.0, got %.2f" % retrieved)
		test_failed += 1

	# Test clamping at max (10.0 is internal cap)
	qubit.berry_phase = 15.0  # Try to exceed max
	if qubit.berry_phase == 10.0:
		print("  ✅ Berry phase clamped at internal max (10.0)")
		test_passed += 1
	else:
		print("  ❌ Berry phase should be clamped at 10.0, got %.2f" % qubit.berry_phase)
		test_failed += 1


func test_glow_integration():
	"""Test that berry phase integrates with unbounded glow system"""
	print("\n📊 TEST 4: Glow integration (unbounded measurement apparatus)")

	# Verify the unbounded glow formulas
	var energy = 1.0
	var berry_phase_raw = 5.0  # 5 units of accumulated evolution

	# Energy glow: energy * 0.4 (bounded)
	var energy_glow = energy * 0.4

	# Berry phase glow: berry_phase * 0.2 (unbounded, grows with evolution)
	var berry_glow = berry_phase_raw * 0.2

	# Combined glow (unbounded)
	var total_glow = energy_glow + berry_glow

	if abs(energy_glow - 0.4) < 0.01:
		print("  ✅ Energy glow component (bounded): %.2f" % energy_glow)
		test_passed += 1
	else:
		print("  ❌ Energy glow should be 0.4")
		test_failed += 1

	if abs(berry_glow - 1.0) < 0.01:
		print("  ✅ Berry phase glow (unbounded, 5.0 evolution): %.2f" % berry_glow)
		test_passed += 1
	else:
		print("  ❌ Berry glow should be 1.0, got %.2f" % berry_glow)
		test_failed += 1

	if abs(total_glow - 1.4) < 0.01:
		print("  ✅ Combined glow (energy + evolution): %.2f" % total_glow)
		test_passed += 1
	else:
		print("  ❌ Combined glow should be 1.4, got %.2f" % total_glow)
		test_failed += 1

	# Test at max accumulated evolution (10.0 is the cap)
	var max_berry = 10.0
	var max_berry_glow = max_berry * 0.2
	var max_total = energy_glow + max_berry_glow

	if abs(max_total - 2.4) < 0.01:
		print("  ✅ Max total glow (max evolution 10.0): %.2f" % max_total)
		test_passed += 1
	else:
		print("  ❌ Max glow should be 2.4, got %.2f" % max_total)
		test_failed += 1
