class_name BiomePlot
extends PlotBase

## Biome Plot Wrapper - Environmental Measurement Container
##
## Represents measurement points in the quantum farm that measure local environmental
## properties (temperature, energy, phase). These plots don't have floating balloons,
## instead they hover directly over the measurement location.
##
## ARCHITECTURE RATIONALE:
## - QuantumBehavior.HOVERING: Fixed hover over measurement location
## - Measures biome properties at specific grid points
## - No movement or force-directed behavior
## - Could be extended with visualization feedback
##
## CURRENT STATE: Wrapper that reads biome state and displays measurements
## FUTURE STATE: Could add hover animation and measurement field visualization
## FUTURE STATE: Could visualize gradients between measurement points

# Reference to the biome environment
var biome: Node = null

# Measurement data
var temperature: float = 300.0
var energy: float = 0.0
var phase: float = 0.0


func _init(biome_ref: Node, id: String, pos: Vector2i):
	super._init(id, pos)
	biome = biome_ref
	plot_type = 1  # PlotType.BIOME
	quantum_behavior = 1  # QuantumBehavior.HOVERING


func get_plot_emojis() -> Dictionary:
	"""Return measurement emojis for this biome"""
	if biome:
		var is_sun = biome.is_currently_sun() if biome.has_method("is_currently_sun") else false
		return {
			"north": "☀️" if is_sun else "🌙",
			"south": "🌡️"
		}
	return {"north": "❓", "south": "❓"}


func get_dominant_emoji() -> String:
	"""Get the dominant emoji for this biome measurement"""
	if biome:
		var is_sun = biome.is_currently_sun() if biome.has_method("is_currently_sun") else false
		return "☀️" if is_sun else "🌙"
	return "❓"


func get_state_description() -> String:
	"""Return readable description of biome state"""
	if not biome:
		return "Disconnected biome"
	var temp_str = "%.0fK" % temperature
	return "Biome: %s | Energy: %.2f" % [temp_str, energy]
