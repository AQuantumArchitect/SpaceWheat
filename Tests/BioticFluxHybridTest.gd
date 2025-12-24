extends Node

## Test: Hybrid crops (wheat + mushroom) with probability-weighted energy transfer
## Shows how energy grows based on superposition state

const QuantumVisualizationController = preload("res://Core/Visualization/QuantumVisualizationController.gd")
const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

var biome = null
var visualization: QuantumVisualizationController = null
var frame_count: int = 0

var pure_wheat_pos: Vector2i = Vector2i(-2, 0)      # Pure wheat: θ=0
var hybrid_50_50_pos: Vector2i = Vector2i(0, 0)     # 50/50: θ=π/2
var pure_mushroom_pos: Vector2i = Vector2i(2, 0)    # Pure mushroom: θ=π


func _ready() -> void:
	var sep = "=================================================================================="
	print("\n" + sep)
	print("BIOTIC FLUX HYBRID CROP TEST - Superposition Energy Transfer")
	print("Compare energy growth in pure wheat vs hybrid vs pure mushroom")
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

	# Plant test crops
	print("\n🌾 Planting test crops...")
	_plant_pure_wheat(pure_wheat_pos)
	_plant_hybrid_50_50(hybrid_50_50_pos)
	_plant_pure_mushroom(pure_mushroom_pos)
	print("   ✓ Pure wheat: θ = 0.0 (100% wheat, 0% mushroom)")
	print("   ✓ Hybrid 50/50: θ = π/2 (50% wheat, 50% mushroom)")
	print("   ✓ Pure mushroom: θ = π (0% wheat, 100% mushroom)")

	# Create visualization
	print("\n📊 Creating quantum visualization...")
	visualization = QuantumVisualizationController.new()
	visualization.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(visualization)

	var plot_positions = _get_plot_positions()
	visualization.connect_to_biome(biome, plot_positions)
	print("   ✓ Visualization connected")

	print("\n⚡ HYBRID CROP ENERGY FORMULA")
	print("   Pure crop: energy_rate = base × cos²(θ_self/2) × cos²((θ-θ_sun)/2) × influence")
	print("   Hybrid crop: BOTH wheat and mushroom rates apply simultaneously!")
	print("")
	print("   P(wheat) = cos²(θ/2)      - probability of being in wheat state")
	print("   P(mushroom) = sin²(θ/2)   - probability of being in mushroom state")
	print("")
	print("   wheat_rate = base × cos²(θ/2) × alignment × wheat_influence")
	print("   mushroom_rate = base × sin²(θ/2) × alignment × mushroom_influence")
	print("")
	print("   hybrid_total = wheat_rate + mushroom_rate")
	print("")
	print("   At θ=0 (pure wheat):\n" +
	      "   - wheat_prob = 1.0, mushroom_prob = 0.0\n" +
	      "   - wheat contributes 100%, mushroom contributes 0%\n" +
	      "   - slower growth (wheat_influence = 0.15)\n")
	print("   At θ=π/2 (balanced):\n" +
	      "   - wheat_prob = 0.5, mushroom_prob = 0.5\n" +
	      "   - both contribute 50% each\n" +
	      "   - hybrid gets 0.5×wheat + 0.5×mushroom effect\n")
	print("   At θ=π (pure mushroom):\n" +
	      "   - wheat_prob = 0.0, mushroom_prob = 1.0\n" +
	      "   - mushroom contributes 100%, wheat contributes 0%\n" +
	      "   - faster growth (mushroom_influence = 0.983) BUT sun damage high\n")


func _plant_pure_wheat(pos: Vector2i) -> void:
	"""Pure wheat: θ = 0.0 (north pole = 🌾)"""
	var wheat = DualEmojiQubit.new()
	wheat.north_emoji = "🌾"
	wheat.south_emoji = "🌾"  # Starts at north
	wheat.theta = 0.0
	wheat.phi = randf() * TAU
	wheat.radius = 0.3
	wheat.energy = 0.3

	biome.quantum_states[pos] = wheat
	biome.plots_by_type[biome.PlotType.FARM].append(pos)
	biome.plot_types[pos] = biome.PlotType.FARM


func _plant_hybrid_50_50(pos: Vector2i) -> void:
	"""Hybrid at 50/50 superposition: θ = π/2"""
	var hybrid = DualEmojiQubit.new()
	hybrid.north_emoji = "🌾"
	hybrid.south_emoji = "🍄"
	hybrid.theta = PI / 2.0  # Perfect superposition
	hybrid.phi = randf() * TAU
	hybrid.radius = 0.3
	hybrid.energy = 0.3

	biome.quantum_states[pos] = hybrid
	biome.plots_by_type[biome.PlotType.FARM].append(pos)
	biome.plot_types[pos] = biome.PlotType.FARM


func _plant_pure_mushroom(pos: Vector2i) -> void:
	"""Pure mushroom: θ = π (south pole = 🍄)"""
	var mushroom = DualEmojiQubit.new()
	mushroom.north_emoji = "🍄"
	mushroom.south_emoji = "🍄"  # Starts at south
	mushroom.theta = PI
	mushroom.phi = randf() * TAU
	mushroom.radius = 0.3
	mushroom.energy = 0.3

	biome.quantum_states[pos] = mushroom
	biome.plots_by_type[biome.PlotType.FARM].append(pos)
	biome.plot_types[pos] = biome.PlotType.FARM


func _get_plot_positions() -> Dictionary:
	"""Get screen positions for crops"""
	var positions = {}
	var viewport_size = get_tree().get_root().get_viewport_rect().size
	var center = viewport_size / 2.0
	var spacing = 150.0

	positions[pure_wheat_pos] = center + Vector2(-spacing, 0)
	positions[hybrid_50_50_pos] = center + Vector2(0, 0)
	positions[pure_mushroom_pos] = center + Vector2(spacing, 0)

	return positions


func _process(delta: float) -> void:
	frame_count += 1

	if frame_count % 60 == 0:
		_print_hybrid_comparison()


func _print_hybrid_comparison() -> void:
	"""Compare energy growth across all three crop types"""
	if not biome:
		return

	var elapsed = frame_count / 60.0
	var sun_phase = "☀️" if biome.is_currently_sun() else "🌙"
	var sun_intensity = pow(cos(biome.sun_qubit.theta / 2.0), 2)

	print("⏱️  [%.1fs] %s (intensity: %.3f)" % [elapsed, sun_phase, sun_intensity])

	# Sample each crop type
	var wheat_q = biome.quantum_states.get(pure_wheat_pos)
	var hybrid_q = biome.quantum_states.get(hybrid_50_50_pos)
	var mushroom_q = biome.quantum_states.get(pure_mushroom_pos)

	if wheat_q:
		var wheat_prob = pow(cos(wheat_q.theta / 2.0), 2)
		var wheat_align = pow(cos((wheat_q.theta - biome.sun_qubit.theta) / 2.0), 2)
		print("   🌾 Pure Wheat (θ=0):")
		print("      Energy: %.3f | Alignment: %.3f | Growth: wheat%.0f%%" % [
			wheat_q.energy, wheat_align, wheat_prob * 100
		])

	if hybrid_q:
		var wheat_prob = pow(cos(hybrid_q.theta / 2.0), 2)
		var mush_prob = pow(sin(hybrid_q.theta / 2.0), 2)
		var hybrid_align = pow(cos((hybrid_q.theta - biome.sun_qubit.theta) / 2.0), 2)
		print("   🌾🍄 Hybrid (θ=π/2):")
		print("      Energy: %.3f | Alignment: %.3f | Growth: wheat%.0f%% + mush%.0f%%" % [
			hybrid_q.energy, hybrid_align, wheat_prob * 100, mush_prob * 100
		])

	if mushroom_q:
		var mush_prob = pow(sin(mushroom_q.theta / 2.0), 2)
		var mush_align = pow(cos((mushroom_q.theta - biome.sun_qubit.theta) / 2.0), 2)
		print("   🍄 Pure Mushroom (θ=π):")
		print("      Energy: %.3f | Alignment: %.3f | Growth: mush%.0f%%" % [
			mushroom_q.energy, mush_align, mush_prob * 100
		])

		# Show sun damage to mushroom
		var sun_damage = 0.01 * sun_intensity
		print("      Sun damage rate: %.4f/sec" % sun_damage)

	print()


func _exit_tree() -> void:
	var sep = "=================================================================================="
	print("\n" + sep)
	print("Hybrid Crop Test Complete")
	print("Compare the energy curves:")
	print("- Pure wheat: slow steady growth (influence=0.15)")
	print("- Hybrid: intermediate (0.5×wheat + 0.5×mushroom)")
	print("- Pure mushroom: fast growth (influence=0.983) but sun damage high")
	print(sep + "\n")
