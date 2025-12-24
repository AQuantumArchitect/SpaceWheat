extends Node

## Test: Energy tap system - drain energy from crops using cos² coupling
## Demonstrates energy harvesting mechanics for resource extraction

const QuantumVisualizationController = preload("res://Core/Visualization/QuantumVisualizationController.gd")
const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

var biome = null
var visualization: QuantumVisualizationController = null
var frame_count: int = 0

# Crop positions
var wheat_pos: Vector2i = Vector2i(-2, 0)
var tap_pos: Vector2i = Vector2i(0, 0)      # Energy tap
var wheat_pos_2: Vector2i = Vector2i(2, 0)

# Energy tap state
var accumulated_energy: float = 0.0
var tap_target_emoji: String = "🌾"  # What we're tapping
var tap_theta: float = 0.0            # Optimal phase for tapping (align with wheat)
var tap_base_rate: float = 0.5        # How fast we drain


func _ready() -> void:
	var sep = "=================================================================================="
	print("\n" + sep)
	print("BIOTIC FLUX ENERGY TAP TEST - Quantum Energy Harvesting")
	print("Drain energy from wheat using cos² phase coupling")
	print(sep + "\n")

	# Create container
	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)

	# Create BioticFluxBiome
	print("🌍 Creating BioticFluxBiome...")
	biome = BioticFluxBiome.new()
	add_child(biome)
	await get_tree().process_frame
	print("   ✓ BioticFluxBiome initialized")

	# Plant wheat and create tap
	print("\n🌾 Setting up energy harvest scenario...")
	_plant_wheat(wheat_pos)
	_plant_wheat(wheat_pos_2)
	_create_tap(tap_pos)
	print("   ✓ Planted wheat at two locations")
	print("   ✓ Created energy tap at center")

	# Create visualization
	print("\n📊 Creating quantum visualization...")
	visualization = QuantumVisualizationController.new()
	visualization.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(visualization)

	var plot_positions = _get_plot_positions()
	visualization.connect_to_biome_simple(biome, plot_positions)
	print("   ✓ Visualization connected")

	print("\n⚡ ENERGY TAP MECHANICS")
	print("   Energy tap drains from target emoji using quantum coupling:")
	print("")
	print("   transfer_rate = tap_base_rate × amplitude × alignment")
	print("")
	print("   amplitude = cos²(target_theta / 2)")
	print("     - How 'target-like' the qubit is (at north pole = 1.0, at south = 0.0)")
	print("")
	print("   alignment = cos²((qubit_theta - tap_theta) / 2)")
	print("     - Phase match between tap point and qubit")
	print("     - Maximum at tap_theta = 0 (aligned with wheat)")
	print("")
	print("   tap_base_rate = %.1f - base drain rate" % tap_base_rate)
	print("")
	print("   Watch for:")
	print("   ✓ Tap accumulates energy from nearby wheat")
	print("   ✓ Energy drain scales with phase alignment")
	print("   ✓ Wheat still grows despite being tapped (if icon alignment strong)")
	print("   ✓ Tap position (theta=0) optimally aligned with wheat")


func _plant_wheat(pos: Vector2i) -> void:
	"""Create a wheat crop"""
	var wheat = DualEmojiQubit.new()
	wheat.north_emoji = "🌾"
	wheat.south_emoji = "💧"
	wheat.theta = 0.0  # Start at wheat state
	wheat.phi = randf() * TAU
	wheat.radius = 0.3
	wheat.energy = 0.3

	biome.quantum_states[pos] = wheat
	biome.plots_by_type[biome.PlotType.FARM].append(pos)
	biome.plot_types[pos] = biome.PlotType.FARM


func _create_tap(pos: Vector2i) -> void:
	"""Create an energy tap - a special qubit that drains from others"""
	var tap = DualEmojiQubit.new()
	tap.north_emoji = "⚡"
	tap.south_emoji = "⚡"
	tap.theta = tap_theta  # Aligned with target
	tap.phi = 0.0
	tap.radius = 0.5
	tap.energy = 0.0  # Starts empty

	# Mark as special (though not strictly necessary for test)
	biome.quantum_states[pos] = tap
	biome.plots_by_type[biome.PlotType.NATIVE].append(pos)
	biome.plot_types[pos] = biome.PlotType.NATIVE


func _get_plot_positions() -> Dictionary:
	"""Get screen positions for visualization"""
	var positions = {}
	var viewport_size = Vector2(1920, 1080)  # Fixed viewport size
	var center = viewport_size / 2.0
	var spacing = 150.0

	positions[wheat_pos] = center + Vector2(-spacing, 0)
	positions[tap_pos] = center + Vector2(0, 0)
	positions[wheat_pos_2] = center + Vector2(spacing, 0)

	return positions


func _process(delta: float) -> void:
	frame_count += 1

	# Simulate energy tap every frame
	_simulate_energy_tap(delta)

	if frame_count % 60 == 0:
		_print_tap_state()


func _simulate_energy_tap(dt: float) -> void:
	"""Simulate energy draining from wheat to tap"""
	var wheat1 = biome.quantum_states.get(wheat_pos)
	var wheat2 = biome.quantum_states.get(wheat_pos_2)
	var tap = biome.quantum_states.get(tap_pos)

	if not tap:
		return

	# Drain from each wheat
	for wheat in [wheat1, wheat2]:
		if not wheat or wheat.energy < 0.01:
			continue

		# Calculate coupling (same formula as in BiomeBase)
		var amplitude = pow(cos(wheat.theta / 2.0), 2)
		var alignment = pow(cos((wheat.theta - tap_theta) / 2.0), 2)
		var transfer_rate = tap_base_rate * amplitude * alignment

		# Drain energy (limit to 10% per frame)
		var drained = min(transfer_rate * dt, wheat.energy * 0.1)
		wheat.grow_energy(-drained, dt)
		accumulated_energy += drained

		# Sync radius
		wheat.radius = wheat.energy


func _print_tap_state() -> void:
	"""Print energy tap status"""
	if not biome:
		return

	var elapsed = frame_count / 60.0
	var wheat1 = biome.quantum_states.get(wheat_pos)
	var wheat2 = biome.quantum_states.get(wheat_pos_2)

	if not wheat1 or not wheat2:
		return

	# Calculate couplings
	var amp1 = pow(cos(wheat1.theta / 2.0), 2)
	var align1 = pow(cos((wheat1.theta - tap_theta) / 2.0), 2)
	var rate1 = tap_base_rate * amp1 * align1

	var amp2 = pow(cos(wheat2.theta / 2.0), 2)
	var align2 = pow(cos((wheat2.theta - tap_theta) / 2.0), 2)
	var rate2 = tap_base_rate * amp2 * align2

	print("⏱️  [%.1fs] Energy Tap Status" % elapsed)
	print("   🌾 Wheat 1 (left):")
	print("      Energy: %.3f | Amplitude: %.3f | Alignment: %.3f" % [wheat1.energy, amp1, align1])
	print("      Transfer rate: %.4f/sec" % rate1)
	print("   🌾 Wheat 2 (right):")
	print("      Energy: %.3f | Amplitude: %.3f | Alignment: %.3f" % [wheat2.energy, amp2, align2])
	print("      Transfer rate: %.4f/sec" % rate2)
	print("   ⚡ Accumulated energy in tap: %.3f" % accumulated_energy)
	print("   📊 Total transfer rate: %.4f/sec" % (rate1 + rate2))
	print()


func _exit_tree() -> void:
	var sep = "=================================================================================="
	print("\n" + sep)
	print("Energy Tap Test Complete")
	print("Energy successfully transferred using quantum phase coupling")
	print("Transfer rate = tap_rate × cos²(θ/2) × cos²((θ-φ)/2)")
	print(sep + "\n")
