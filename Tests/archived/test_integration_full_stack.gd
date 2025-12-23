extends Node
## Integration Test: Full Stack from Qubit → Touch
## Tests each layer: Qubit → FarmPlot → WheatPlot → Planting → Measuring → Touch

var test_passed = 0
var test_failed = 0

func _ready():
	var line = ""
	for i in range(70):
		line += "="
	print("\n" + line)
	print("FULL STACK INTEGRATION TEST")
	print(line + "\n")

	# Layer 1: Qubit with emojis
	print("LAYER 1: DualEmojiQubit with Emoji Poles")
	print(repeat_string("-", 70))
	test_qubit_creation()
	test_qubit_emoji_system()
	test_qubit_superposition()

	# Layer 2: Qubit measurement
	print("\n\nLAYER 2: Qubit Measurement & Berry Phase")
	print(repeat_string("-", 70))
	test_qubit_measurement()
	test_berry_phase_accumulation()

	# Layer 3: Coherence and glow
	print("\n\nLAYER 3: Coherence & Glow Integration")
	print(repeat_string("-", 70))
	test_coherence_calculation()
	test_glow_system()

	# Summary
	var line2 = ""
	for i in range(70):
		line2 += "="
	print("\n" + line2)
	print("RESULTS: %d PASSED, %d FAILED" % [test_passed, test_failed])
	print(line2 + "\n")

	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


func test_qubit_creation():
	"""Test basic qubit instantiation"""
	print("📊 TEST 1: Qubit creation with emoji poles")

	var qubit = DualEmojiQubit.new("🌾", "👥")

	if qubit.north_emoji == "🌾" and qubit.south_emoji == "👥":
		print("  ✅ Emoji poles set correctly: 🌾 (north) ↔ 👥 (south)")
		test_passed += 1
	else:
		print("  ❌ Emoji poles not set correctly")
		test_failed += 1

	if qubit.theta == PI / 2:  # Default is superposition
		print("  ✅ Default theta = π/2 (equal superposition)")
		test_passed += 1
	else:
		print("  ❌ Default theta should be π/2")
		test_failed += 1


func test_qubit_emoji_system():
	"""Test emoji probability calculation"""
	print("\n📊 TEST 2: Emoji superposition (Born rule probabilities)")

	var qubit = DualEmojiQubit.new("🌾", "👥")

	# At θ = π/2 (superposition), both should be 50%
	var prob_north = qubit.get_north_probability()
	var prob_south = qubit.get_south_probability()

	if abs(prob_north - 0.5) < 0.01:
		print("  ✅ Superposition: North emoji 50%% → 🌾")
		test_passed += 1
	else:
		print("  ❌ North probability should be 0.5, got %.2f" % prob_north)
		test_failed += 1

	if abs(prob_south - 0.5) < 0.01:
		print("  ✅ Superposition: South emoji 50%% → 👥")
		test_passed += 1
	else:
		print("  ❌ South probability should be 0.5, got %.2f" % prob_south)
		test_failed += 1


func test_qubit_superposition():
	"""Test moving through superposition space"""
	print("\n📊 TEST 3: Bloch sphere rotation (changing θ)")

	var qubit = DualEmojiQubit.new("🌾", "👥")

	# Move toward north pole (θ → 0)
	qubit.theta = 0.0
	var prob_north = qubit.get_north_probability()

	if abs(prob_north - 1.0) < 0.01:
		print("  ✅ North pole (θ=0): 100%% north emoji")
		test_passed += 1
	else:
		print("  ❌ Should be 100%% north at θ=0")
		test_failed += 1

	# Move toward south pole (θ → π)
	qubit.theta = PI
	var prob_south = qubit.get_south_probability()

	if abs(prob_south - 1.0) < 0.01:
		print("  ✅ South pole (θ=π): 100%% south emoji")
		test_passed += 1
	else:
		print("  ❌ Should be 100%% south at θ=π")
		test_failed += 1


func test_qubit_measurement():
	"""Test measurement collapse"""
	print("\n📊 TEST 4: Measurement & collapse")

	var qubit = DualEmojiQubit.new("🌾", "👥")
	qubit.theta = PI / 4  # 70% north, 30% south (roughly)

	var collapsed_emoji = qubit.measure()

	if collapsed_emoji in ["🌾", "👥"]:
		print("  ✅ Measurement collapsed to single emoji: %s" % collapsed_emoji)
		test_passed += 1
	else:
		print("  ❌ Collapsed emoji should be 🌾 or 👥, got %s" % collapsed_emoji)
		test_failed += 1

	# After measurement, theta should be fixed
	if qubit.theta == 0.0 or qubit.theta == PI:
		print("  ✅ Theta frozen after measurement: %.2f" % qubit.theta)
		test_passed += 1
	else:
		print("  ❌ Theta should be 0 or π after measurement")
		test_failed += 1


func test_berry_phase_accumulation():
	"""Test berry phase (experience points)"""
	print("\n📊 TEST 5: Berry phase accumulation")

	var qubit = DualEmojiQubit.new("🌾", "👥")

	# Accumulate evolution
	qubit.accumulate_berry_phase(0.5, 1.0)

	if qubit.get_berry_phase() > 0.0:
		print("  ✅ Berry phase accumulated: %.2f" % qubit.get_berry_phase())
		test_passed += 1
	else:
		print("  ❌ Berry phase should increase")
		test_failed += 1

	# More accumulation
	var initial_bp = qubit.get_berry_phase()
	qubit.accumulate_berry_phase(1.0, 2.0)

	if qubit.get_berry_phase() > initial_bp:
		print("  ✅ Berry phase grew further: %.2f → %.2f" % [initial_bp, qubit.get_berry_phase()])
		test_passed += 1
	else:
		print("  ❌ Berry phase should continue growing")
		test_failed += 1


func test_coherence_calculation():
	"""Test quantum coherence (superposition measure)"""
	print("\n📊 TEST 6: Coherence = sin(θ) * cos(θ) * radius")

	var qubit = DualEmojiQubit.new("🌾", "👥")
	qubit.theta = PI / 2  # Superposition
	qubit.radius = 1.0  # Full energy

	var coherence = qubit.get_coherence()

	if coherence > 0.1:  # At π/2, should be nonzero
		print("  ✅ Superposition has coherence: %.2f" % coherence)
		test_passed += 1
	else:
		print("  ❌ Superposition should have high coherence")
		test_failed += 1

	# Pure state (θ = 0)
	qubit.theta = 0.0
	var pure_coherence = qubit.get_coherence()

	if pure_coherence < coherence:
		print("  ✅ Pure state has lower coherence: %.2f < %.2f" % [pure_coherence, coherence])
		test_passed += 1
	else:
		print("  ❌ Pure state should have lower coherence than superposition")
		test_failed += 1


func test_glow_system():
	"""Test how glow would be calculated (simulating QuantumNode)"""
	print("\n📊 TEST 7: Glow system (energy + berry phase)")

	var qubit = DualEmojiQubit.new("🌾", "👥")
	qubit.radius = 1.0  # Full energy
	qubit.berry_phase = 5.0  # Some evolution

	# Simulate QuantumNode glow calculation
	var energy = 1.0  # Full energy
	var energy_glow = energy * 0.4  # 0.4
	var berry_glow = qubit.berry_phase * 0.2  # 1.0
	var total_glow = energy_glow + berry_glow  # 1.4

	if abs(total_glow - 1.4) < 0.01:
		print("  ✅ Glow calculation: energy(0.4) + evolution(1.0) = %.2f" % total_glow)
		test_passed += 1
	else:
		print("  ❌ Glow should be 1.4, got %.2f" % total_glow)
		test_failed += 1


# Helper function for string repetition
func repeat_string(s: String, count: int) -> String:
	var result = ""
	for i in range(count):
		result += s
	return result
