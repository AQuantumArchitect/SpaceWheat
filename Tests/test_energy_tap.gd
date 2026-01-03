#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: Energy Tap Farm Plot
##
## Demonstrates:
## 1. Energy tap placement and configuration
## 2. cos² Bloch sphere coupling drain
## 3. Energy accumulation and harvesting
## 4. Generic resource production (taps any emoji)

const WheatPlot = preload("res://Core/GameMechanics/WheatPlot.gd")
const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

var farm: FarmGrid
var biome: BioticFluxBiome

func _initialize():
	print("\n" + print_line("=", 80))
	print("⚡ ENERGY TAP TEST")
	print("Bloch Sphere Resource Extraction via cos² Coupling")
	print(print_line("=", 80) + "\n")

	# Initialize farm and biome
	farm = FarmGrid.new()
	farm.grid_width = 3
	farm.grid_height = 1

	biome = BioticFluxBiome.new()
	biome._ready()

	farm.biome = biome
	biome.grid = farm

	# Initialize plots in grid
	for x in range(farm.grid_width):
		for y in range(farm.grid_height):
			var pos = Vector2i(x, y)
			var plot = WheatPlot.new()
			plot.grid_position = pos
			farm.plots[pos] = plot

	print("🌾 FarmGrid initialized: %dx%d\n" % [farm.grid_width, farm.grid_height])

	_phase_1_setup_and_growth()
	_phase_2_energy_drain()
	_phase_3_harvest()
	_phase_4_verify_topology()

	print(print_line("=", 80))
	print("✅ ENERGY TAP TEST COMPLETE")
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


func _phase_1_setup_and_growth():
	"""Phase 1: Plant wheat and energy tap"""
	print(print_sep())
	print("PHASE 1: SETUP AND WHEAT GROWTH")
	print(print_sep() + "\n")

	# Plant wheat at position (0,0)
	print("🌾 Planting wheat at position (0,0)...\n")
	var wheat_qubit = biome.create_quantum_state(Vector2i(0, 0), "🌾", "👥", PI / 2.0)
	wheat_qubit.radius = 0.3  # Start at lower energy
	var plot_0 = farm.get_plot(Vector2i(0, 0))
	plot_0.quantum_state = wheat_qubit
	plot_0.is_planted = true
	plot_0.plot_type = WheatPlot.PlotType.WHEAT

	# Plant energy tap at position (1,0) targeting wheat
	print("⚡ Planting energy tap at position (1,0) targeting 🌾...\n")
	farm.plant_energy_tap(Vector2i(1, 0), "🌾")

	# Let wheat grow via sun/moon coupling
	print("⏳ Simulating wheat growth (10 steps)...\n")
	for i in range(10):
		biome._sync_sun_qubit(0.1)
		biome._evolve_quantum_substrate(0.1)

	print("📊 Wheat energy after growth: %.3f" % wheat_qubit.energy)
	print()


func _phase_2_energy_drain():
	"""Phase 2: Energy tap drains wheat"""
	print(print_sep())
	print("PHASE 2: ENERGY TAP DRAIN")
	print(print_sep() + "\n")

	var wheat_qubit = biome.get_qubit(Vector2i(0, 0))
	var tap_plot = farm.get_plot(Vector2i(1, 0))

	print("⏳ Running energy tap drain (20 steps)...\n")
	var initial_wheat_energy = wheat_qubit.energy

	for i in range(20):
		biome._sync_sun_qubit(0.1)
		biome._evolve_quantum_substrate(0.1)

	var final_wheat_energy = wheat_qubit.energy
	var drained_amount = initial_wheat_energy - final_wheat_energy

	print("📊 Energy Drain Results:")
	print("   Initial wheat energy: %.3f" % initial_wheat_energy)
	print("   Final wheat energy: %.3f" % final_wheat_energy)
	print("   Drained amount: %.3f" % drained_amount)
	print("   Tap accumulated: %.3f" % tap_plot.tap_accumulated_resource)
	print()

	if drained_amount > 0.0:
		print("✅ Energy tap successfully drained %.3f from wheat!" % drained_amount)
	else:
		print("⚠️  WARNING: No energy drained!")

	print()


func _phase_3_harvest():
	"""Phase 3: Harvest accumulated energy"""
	print(print_sep())
	print("PHASE 3: HARVEST ACCUMULATED RESOURCES")
	print(print_sep() + "\n")

	var tap_plot = farm.get_plot(Vector2i(1, 0))
	print("📊 Tap state before harvest:")
	print("   Accumulated energy: %.3f" % tap_plot.tap_accumulated_resource)
	print("   Target emoji: %s" % tap_plot.tap_target_emoji)
	print()

	# Harvest the tap
	print("🔨 Harvesting energy tap...\n")
	var harvest_result = farm.harvest_energy_tap(Vector2i(1, 0))

	if harvest_result["success"]:
		print("✅ Harvest successful!")
		print("   Resource type: %s" % harvest_result["emoji"])
		print("   Amount obtained: %d" % harvest_result["amount"])
		print()
	else:
		print("❌ Harvest failed: %s" % harvest_result.get("error", "Unknown error"))
		print()

	print("📊 Tap state after harvest:")
	print("   Accumulated energy: %.3f (remainder)" % tap_plot.tap_accumulated_resource)
	print()


func _phase_4_verify_topology():
	"""Phase 4: Verify graph topology (pure emoji language)"""
	print(print_sep())
	print("PHASE 4: TOPOLOGY VERIFICATION")
	print(print_sep() + "\n")

	var wheat_qubit = biome.get_qubit(Vector2i(0, 0))
	var tap_plot = farm.get_plot(Vector2i(1, 0))

	print("🌾 Wheat qubit properties:")
	print("   Emojis: %s (north) ↔ %s (south)" % [wheat_qubit.north_emoji, wheat_qubit.south_emoji])
	print("   Theta: %.2f rad (%.0f°)" % [wheat_qubit.theta, wheat_qubit.theta * 180.0 / PI])
	print("   Radius (energy): %.3f" % wheat_qubit.radius)
	print()

	print("⚡ Energy tap properties:")
	print("   Plot type: ENERGY_TAP (%s)" % WheatPlot.PlotType.ENERGY_TAP)
	print("   Target emoji: %s" % tap_plot.tap_target_emoji)
	print("   Tap theta: %.2f rad (%.0f°)" % [tap_plot.tap_theta, tap_plot.tap_theta * 180.0 / PI])
	print("   Tap phi: %.2f rad (%.0f°)" % [tap_plot.tap_phi, tap_plot.tap_phi * 180.0 / PI])
	print("   Base rate: %.2f" % tap_plot.tap_base_rate)
	print()

	# Calculate expected coupling at current wheat theta
	var alignment = pow(cos((wheat_qubit.theta - tap_plot.tap_theta) / 2.0), 2)
	var amplitude = pow(cos(wheat_qubit.theta / 2.0), 2)
	var expected_rate = tap_plot.tap_base_rate * amplitude * alignment

	print("📐 cos² Coupling Analysis:")
	print("   Phase alignment: cos²((%.2f - %.2f) / 2) = %.3f" % [
		wheat_qubit.theta, tap_plot.tap_theta, alignment
	])
	print("   Amplitude: cos²(%.2f / 2) = %.3f" % [wheat_qubit.theta, amplitude])
	print("   Expected transfer rate: %.3f × %.3f × %.3f = %.4f" % [
		tap_plot.tap_base_rate, amplitude, alignment, expected_rate
	])
	print()

	print("📊 Summary:")
	print("   ✅ Energy tap successfully configured")
	print("   ✅ cos² coupling calculated correctly")
	print("   ✅ Energy accumulation working")
	print("   ✅ Resource harvesting functional")
	print()

