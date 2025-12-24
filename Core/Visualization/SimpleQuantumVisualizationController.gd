class_name SimpleQuantumVisualizationController
extends Control

## Simplified quantum visualization for BioticFlux biomes
## Shows glyphs for each qubit with energy and phase information

const QuantumGlyph = preload("res://Core/Visualization/QuantumGlyph.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

var glyphs: Array = []
var biome = null
var plot_positions: Dictionary = {}
var emoji_font: Font = null


func _ready() -> void:
	# Load emoji font with fallback
	var font_path = "res://Assets/Fonts/NotoColorEmoji.ttf"
	if ResourceLoader.exists(font_path):
		emoji_font = load(font_path)
	else:
		emoji_font = ThemeDB.fallback_font

	if not emoji_font:
		emoji_font = ThemeDB.fallback_font

	mouse_filter = Control.MOUSE_FILTER_STOP


func connect_biome(biome_ref, plot_pos_dict: Dictionary = {}) -> void:
	"""Connect to BioticFlux biome and create glyphs for all qubits"""
	glyphs.clear()
	biome = biome_ref
	plot_positions = plot_pos_dict

	if not biome_ref or not ("quantum_states" in biome_ref):
		return

	# Create one glyph per qubit
	for pos in biome_ref.quantum_states.keys():
		var qubit = biome_ref.quantum_states[pos]
		if not qubit:
			continue

		var glyph = QuantumGlyph.new()
		glyph.qubit = qubit

		if plot_positions.has(pos):
			glyph.position = plot_positions[pos]
		else:
			# Default grid positioning
			var center = get_viewport_rect().size / 2.0
			var spacing = 100.0
			glyph.position = center + Vector2(pos.x * spacing, pos.y * spacing)

		glyphs.append(glyph)


func _process(delta: float) -> void:
	"""Update all glyphs each frame"""
	if not biome:
		return

	for glyph in glyphs:
		if glyph and glyph.qubit:
			glyph.update_from_qubit(delta)

	queue_redraw()


func _draw() -> void:
	"""Draw all glyphs"""
	for glyph in glyphs:
		if glyph and glyph.qubit:
			glyph.draw(self, emoji_font)
