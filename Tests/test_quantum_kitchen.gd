#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: Quantum Kitchen with Triple Bell State Measurement
##
## Demonstrates:
## 1. Creating three input qubits (wheat, water, flour)
## 2. Arranging them in Bell state configurations
## 3. Kitchen detecting the state pattern
## 4. Kitchen measuring triplet and producing bread
## 5. Bread qubit entangled with input resources

const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")
const QuantumKitchen_Biome = preload("res://Core/Environment/QuantumKitchen_Biome.gd")

var kitchen: QuantumKitchen_Biome

func _initialize():
	print("\n" + print_line("=", 80))
	print("🍳 QUANTUM KITCHEN: TRIPLE BELL STATE TO BREAD")
	print("Plot Arrangement (Gate Action) → Measurement → Bread Production")
	print(print_line("=", 80) + "\n")

	kitchen = QuantumKitchen_BioticFluxBiome.new()

	# Test multiple Bell state configurations
	_test_ghz_horizontal()
	_test_ghz_vertical()
	_test_w_state()

	print(print_line("=", 80))
	print("✅ QUANTUM KITCHEN TEST COMPLETE")
	print(print_line("=", 80) + "\n")

	quit()


func print_line(char: String, count: int) -> String:
	var line = ""
	for i in range(count):
		line += char
	return line


func print_sep() -> String:
	var line = ""
	for i in range(80):
		line += "─"
	return line


func _test_ghz_horizontal():
	"""Test GHZ state with horizontal arrangement"""
	print(print_sep())
	print("TEST 1: GHZ STATE (HORIZONTAL)")
	print(print_sep() + "\n")

	# Create input qubits with good energy
	var wheat = DualEmojiQubit.new("🌾", "💼", PI / 2.0)
	wheat.radius = 0.8
	wheat.phi = 0.0

	var water = DualEmojiQubit.new("💧", "☀️", PI / 2.0)
	water.radius = 0.6
	water.phi = 0.0

	var flour = DualEmojiQubit.new("🌾", "💼", PI / 3.0)  # Slightly off-balance
	flour.radius = 0.7
	flour.phi = 0.0

	print("📊 Input Qubits:\n")
	print("   Wheat: theta=90°, energy=0.80")
	print("   Water: theta=90°, energy=0.60")
	print("   Flour: theta=60°, energy=0.70")
	print()

	# Set inputs
	kitchen.set_input_qubits(wheat, water, flour)

	# Configure Bell state: horizontal arrangement
	# Positions: (0,0), (1,0), (2,0) - three in a row
	print("📐 Plot Arrangement:\n")
	print("   Wheat at (0,0)")
	print("   Water at (1,0)")
	print("   Flour at (2,0)")
	print("   Pattern: Horizontal line (---)")
	print()

	var positions = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var is_valid = kitchen.configure_bell_state(positions)
	print()

	if is_valid:
		print("✅ Valid GHZ state detected!\n")
		_produce_bread_cycle(kitchen)
	else:
		print("❌ Failed to detect Bell state\n")


func _test_ghz_vertical():
	"""Test GHZ state with vertical arrangement"""
	print(print_sep())
	print("TEST 2: GHZ STATE (VERTICAL)")
	print(print_sep() + "\n")

	# Reset kitchen with new inputs
	var wheat = DualEmojiQubit.new("🌾", "💼", PI / 2.0)
	wheat.radius = 0.9
	wheat.phi = 0.0

	var water = DualEmojiQubit.new("💧", "☀️", PI / 2.0)
	water.radius = 0.7
	water.phi = 0.0

	var flour = DualEmojiQubit.new("🌾", "💼", PI / 2.0)
	flour.radius = 0.8
	flour.phi = 0.0

	print("📊 Input Qubits:\n")
	print("   Wheat: theta=90°, energy=0.90")
	print("   Water: theta=90°, energy=0.70")
	print("   Flour: theta=90°, energy=0.80")
	print()

	kitchen.set_input_qubits(wheat, water, flour)

	# Vertical arrangement
	print("📐 Plot Arrangement:\n")
	print("   Wheat at (0,0)")
	print("   Water at (0,1)")
	print("   Flour at (0,2)")
	print("   Pattern: Vertical line (|)")
	print()

	var positions = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
	var is_valid = kitchen.configure_bell_state(positions)
	print()

	if is_valid:
		print("✅ Valid GHZ state detected!\n")
		_produce_bread_cycle(kitchen)
	else:
		print("❌ Failed to detect Bell state\n")


func _test_w_state():
	"""Test W state with L-shape arrangement"""
	print(print_sep())
	print("TEST 3: W STATE (L-SHAPE)")
	print(print_sep() + "\n")

	# Reset kitchen with new inputs
	var wheat = DualEmojiQubit.new("🌾", "💼", PI / 3.0)
	wheat.radius = 0.75
	wheat.phi = 0.0

	var water = DualEmojiQubit.new("💧", "☀️", PI / 2.0)
	water.radius = 0.65
	water.phi = 0.0

	var flour = DualEmojiQubit.new("🌾", "💼", PI / 2.0)
	flour.radius = 0.85
	flour.phi = 0.0

	print("📊 Input Qubits:\n")
	print("   Wheat: theta=60°, energy=0.75")
	print("   Water: theta=90°, energy=0.65")
	print("   Flour: theta=90°, energy=0.85")
	print()

	kitchen.set_input_qubits(wheat, water, flour)

	# L-shape arrangement
	print("📐 Plot Arrangement:\n")
	print("   Wheat at (0,0)")
	print("   Water at (0,1)")
	print("   Flour at (1,1)")
	print("   Pattern: L-shape (W state - robust to loss)")
	print()

	var positions = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]
	var is_valid = kitchen.configure_bell_state(positions)
	print()

	if is_valid:
		print("✅ Valid W state detected!\n")
		_produce_bread_cycle(kitchen)
	else:
		print("❌ Failed to detect Bell state\n")


func _produce_bread_cycle(kitchen: QuantumKitchen_Biome):
	"""Execute a bread production cycle"""

	if not kitchen.can_produce_bread():
		print("⚠️  Kitchen not ready for bread production")
		print()
		return

	# Produce bread
	var bread = kitchen.produce_bread()

	if bread:
		print("✨ BREAD PRODUCTION SUCCESSFUL!")
		print()

		# Show final status
		var status = kitchen.get_kitchen_status()
		print("🍳 Kitchen Status After Production:\n")
		print("   Wheat remaining: %.2f" % status["wheat_energy"])
		print("   Water remaining: %.2f" % status["water_energy"])
		print("   Flour remaining: %.2f" % status["flour_energy"])
		print("   Bread produced: %.2f" % status["bread_energy"])
		print("   Total bread ever: %.2f" % status["total_produced"])
		print("   Measurement count: %d" % status["measurement_count"])
		print()

		print("🍞 Bread Qubit Properties:\n")
		print("   Energy (radius): %.2f" % bread.radius)
		print("   State (theta): %.2f rad (%.0f°)" % [
			bread.theta,
			bread.theta * 180.0 / PI
		])
		print()
	else:
		print("❌ Bread production failed")
		print()


func print_summary():
	"""Print final summary"""
	print(print_sep())
	print("KITCHEN SUMMARY")
	print(print_sep() + "\n")

	var status = kitchen.get_kitchen_status()

	print("📊 Final Kitchen State:\n")
	print("   Bell state configured: %s" % status["bell_state"])
	print("   Bell state strength: %.1f%%" % [status["bell_strength"] * 100])
	print("   Ready for production: %s" % ("Yes" if status["can_produce"] else "No"))
	print("   Total bread produced: %.2f" % status["total_produced"])
	print("   Measurements performed: %d" % status["measurement_count"])
	print()

	print("💡 Key Insights:\n")
	print("   1. Bell states are defined by plot spatial arrangement (gate action)")
	print("   2. Different arrangements create different bread properties")
	print("   3. Kitchen measures triplet, collapses inputs, produces bread")
	print("   4. Bread is entangled with resources that created it")
	print("   5. Bell state type determines bread qubit initial theta")
	print()
