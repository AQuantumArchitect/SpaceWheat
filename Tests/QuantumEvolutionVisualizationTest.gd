extends Node

## Test: Watch quantum glyphs evolve as biome changes
## Shows real-time visualization of Hamiltonian evolution

const QuantumGlyph = preload("res://Core/Visualization/QuantumGlyph.gd")
const QuantumVisualizationController = preload("res://Core/Visualization/QuantumVisualizationController.gd")
const ForestBiome = preload("res://Core/Environment/ForestEcosystem_Biome_v3_quantum_field.gd")

var biome = null
var visualization: QuantumVisualizationController = null
var canvas: Control = null
var frame_count: int = 0
var last_print_time: float = 0.0


func _ready() -> void:
	var sep = "=================================================================================="
	print("\n" + sep)
	print("QUANTUM EVOLUTION VISUALIZATION TEST")
	print("Watch glyphs change as biome quantum states evolve via Hamiltonian")
	print(sep + "\n")

	# Create container
	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)

	# Create biome
	print("🌲 Creating ForestEcosystem_Biome_v3...")
	biome = ForestBiome.new()
	add_child(biome)
	await get_tree().process_frame
	print("   ✓ Biome initialized")
	print("   ✓ Patches: %d" % biome.patches.size())

	# Create visualization overlay
	print("\n📊 Creating quantum visualization...")
	visualization = QuantumVisualizationController.new()
	visualization.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(visualization)

	# Connect biome to visualization
	visualization.connect_to_biome(biome, {})
	print("   ✓ Visualization connected to biome")
	print("   ✓ Glyphs created: %d" % visualization.glyphs.size())
	print("   ✓ Edges created: %d" % visualization.edges.size())

	print("\n📈 WATCHING EVOLUTION...")
	print("   North emoji opacity = plant occupation / 10")
	print("   South emoji opacity = water occupation / 10")
	print("   Ring thickness = coherence level")
	print("   Ring color = phase evolution")
	print("   Berry bar = accumulated evolution")
	print("\n   Watch for emoji fading/brightening as populations change!\n")


func _process(delta: float) -> void:
	frame_count += 1

	# Print evolution stats every 60 frames (1 second at 60 FPS)
	if frame_count % 60 == 0:
		_print_evolution_state()


func _print_evolution_state() -> void:
	"""Print current state of first patch"""
	if not biome or not visualization:
		return

	var first_patch_pos = biome.patches.keys()[0] if biome.patches.size() > 0 else Vector2i.ZERO
	var occupation_numbers = biome.get_occupation_numbers(first_patch_pos)

	if occupation_numbers.is_empty():
		return

	var elapsed = frame_count / 60.0

	print("⏱️  [%.1fs]" % elapsed)
	print("   🌾 Plant:      %.2f → emoji brightness %.0f%%" % [
		occupation_numbers.get("plant", 0.0),
		pow(cos(occupation_numbers.get("plant", 5.0) / 10.0 * PI / 2.0), 2.0) * 100
	])
	print("   💧 Water:      %.2f → emoji brightness %.0f%%" % [
		occupation_numbers.get("water", 0.0),
		pow(sin(occupation_numbers.get("plant", 5.0) / 10.0 * PI / 2.0), 2.0) * 100
	])
	print("   🐰 Herbivore:  %.2f" % occupation_numbers.get("herbivore", 0.0))
	print("   🐺 Predator:   %.2f" % occupation_numbers.get("predator", 0.0))

	# Show glyph state if available
	if visualization.glyphs.size() > 0:
		var glyph = visualization.glyphs[0]
		if glyph and glyph.qubit:
			print("   🎨 Glyph [0]:")
			print("      θ = %.3f rad (%.0f°)" % [glyph.qubit.theta, glyph.qubit.theta * 180 / PI])
			print("      φ = %.3f rad" % glyph.qubit.phi)
			print("      North opacity: %.0f%%" % (glyph.north_opacity * 100))
			print("      South opacity: %.0f%%" % (glyph.south_opacity * 100))
	print()


func _exit_tree() -> void:
	var sep = "=================================================================================="
	print("\n" + sep)
	print("Test complete. Watch the glyphs on screen - they should be changing!")
	print(sep + "\n")
