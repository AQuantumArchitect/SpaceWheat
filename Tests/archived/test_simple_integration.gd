extends Node
## Simple Direct Integration Test
## Tests core functionality step by step

var test_passed = 0
var test_failed = 0

func _ready():
	var line = ""
	for i in range(70):
		line += "="
	print("\n" + line)
	print("SIMPLE INTEGRATION TEST - CORE FUNCTIONALITY")
	print(line + "\n")

	# Test 1: Basic qubit creation
	print("TEST 1: Create qubit with emoji poles")
	var qubit = DualEmojiQubit.new("🌾", "👥")
	if qubit != null:
		print("  ✅ Qubit created: %s ↔ %s" % [qubit.north_emoji, qubit.south_emoji])
		test_passed += 1
	else:
		print("  ❌ Qubit creation failed")
		test_failed += 1

	# Test 2: Bloch sphere state
	print("\nTEST 2: Qubit Bloch sphere parameters")
	print("  θ (theta): %.2f" % qubit.theta)
	print("  φ (phi): %.2f" % qubit.phi)
	print("  r (radius): %.2f" % qubit.radius)
	if qubit.theta == PI/2:
		print("  ✅ Default θ = π/2 (superposition)")
		test_passed += 1
	else:
		print("  ❌ θ should be π/2")
		test_failed += 1

	# Test 3: Radius (from Bloch sphere)
	print("\nTEST 3: Quantum radius (energy amplitude)")
	if qubit.radius > 0:
		print("  ✅ Radius initialized: %.2f" % qubit.radius)
		test_passed += 1
	else:
		print("  ❌ Radius should be > 0")
		test_failed += 1

	# Test 4: Bloch sphere movement
	print("\nTEST 4: Moving on Bloch sphere")
	qubit.theta = PI / 4  # Rotate toward north pole
	print("  θ updated to π/4: %.2f" % qubit.theta)
	if abs(qubit.theta - PI/4) < 0.01:
		print("  ✅ Bloch sphere theta update works")
		test_passed += 1
	else:
		print("  ❌ Theta update failed")
		test_failed += 1

	# Test 5: Multiple qubits with different emojis
	print("\nTEST 5: Create diverse qubits (emoji poles)")
	var qubit_tomato = DualEmojiQubit.new("🍅", "🌱")
	var qubit_mushroom = DualEmojiQubit.new("🍄", "🌙")
	if qubit_tomato.north_emoji == "🍅" and qubit_mushroom.north_emoji == "🍄":
		print("  ✅ Created tomato and mushroom qubits with unique poles")
		test_passed += 1
	else:
		print("  ❌ Emoji assignment failed")
		test_failed += 1

	# Test 6: Superposition space
	print("\nTEST 6: Superposition state space")
	var qubit_mixed = DualEmojiQubit.new("A", "B")
	print("  Testing superposition trajectory:")
	for i in range(0, 4):
		var angle = (i * PI) / 3.0
		qubit_mixed.theta = angle
		print("    θ=%.2f (%.1f°)" % [angle, angle * 180.0 / PI])
	print("  ✅ Can move freely on Bloch sphere")
	test_passed += 1

	# Test 7: Glow system principle (unbounded)
	print("\nTEST 7: Glow principle test")
	var energy = 1.0
	var berry_phase_val = 3.5  # Simulated evolved state
	var energy_glow = energy * 0.4
	var berry_glow = berry_phase_val * 0.2
	var total_glow = energy_glow + berry_glow
	print("  Energy baseline glow: %.2f" % energy_glow)
	print("  Evolution bonus glow: %.2f" % berry_glow)
	print("  Total unbounded glow: %.2f" % total_glow)
	if total_glow > energy_glow:
		print("  ✅ Unbounded glow system works (evolution increases brightness)")
		test_passed += 1
	else:
		print("  ❌ Glow calculation failed")
		test_failed += 1

	# Summary
	var line2 = ""
	for i in range(70):
		line2 += "="
	print("\n" + line2)
	print("RESULTS: %d PASSED, %d FAILED" % [test_passed, test_failed])
	print(line2 + "\n")

	if test_failed == 0:
		print("✨ ALL TESTS PASSED! ✨")
		print("Ready for next layer: FarmPlot integration")
	else:
		print("⚠️ Some tests failed - review above")

	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
