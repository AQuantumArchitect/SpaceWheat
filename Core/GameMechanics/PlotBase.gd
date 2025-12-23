class_name PlotBase
extends RefCounted

## Base class for all plot types (Farm, Biome, Celestial)
## Provides common quantum state and position management

# Core quantum properties
var quantum_state: Node = null  # DualEmojiQubit or similar
var has_been_measured: bool = false
var plot_id: String = ""
var grid_position: Vector2i = Vector2i.ZERO

# Position in world
var position: Vector2 = Vector2.ZERO

# Type identifier
enum PlotType {
	FARM,      # Plantable farm plots (wheat, tomato, mushroom)
	BIOME,     # Biome measurement plots (temperature, energy, phase)
	CELESTIAL, # Fixed quantum plots (sun/moon)
	IMPERIAL   # Imperial plots that freeze Bloch sphere (noon/midnight variants)
}
var plot_type: PlotType = PlotType.FARM

# Quantum force behavior - determines visualization and movement physics
# This enum defines how quantum balloons behave in the visualization space
enum QuantumBehavior {
	# Farm plots: Balloons float and can move based on force-directed graph layout
	# Used for: Plantable crops (wheat, mushroom, tomato)
	# Future: Will support force-directed graph positioning with spring physics
	# Visualization: Balloons float above plots, connected by entanglement edges
	FLOATING,

	# Biome plots: Fixed hover directly over measurement location
	# Used for: Environmental measurement points (temperature, energy, phase)
	# Current: Fixed position, no movement
	# Future: Could add hover animation and measurement field visualization
	# Visualization: Hovers at fixed height above measurement point
	HOVERING,

	# Celestial plots: Completely immobile, no forces applied
	# Used for: Celestial bodies (sun/moon) and other fixed quantum systems
	# Current: Fixed position and rotation locked
	# Future: Could add orbital mechanics and rotation animation
	# Visualization: Locked position, no interactive forces
	FIXED
}
var quantum_behavior: QuantumBehavior = QuantumBehavior.FLOATING


func _init(id: String, pos: Vector2i):
	plot_id = id
	grid_position = pos


func get_plot_emojis() -> Dictionary:
	"""Return north and south emojis for this plot - override in subclasses"""
	return {"north": "❓", "south": "❓"}


func get_dominant_emoji() -> String:
	"""Get the dominant emoji when plot is measured - override in subclasses"""
	var emojis = get_plot_emojis()
	return emojis["north"]


func get_state_description() -> String:
	"""Get readable description of plot state - override in subclasses"""
	return "Unknown plot state"
