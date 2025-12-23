class_name CelestialPlot
extends PlotBase

## Celestial Plot Wrapper - Immutable Quantum State Container
##
## Represents fixed quantum states (sun/moon) that drive the farming system.
## These plots are completely fixed in position with no movement.
## They are part of the quantum system but subject to no forces or animation.
##
## ARCHITECTURE RATIONALE:
## - QuantumBehavior.FIXED: Completely immobile celestial bodies
## - Sun/moon qubits are immutable anchors that drive other quantum evolution
## - No force-directed movement or interactive forces
## - Could be extended with visual representation
##
## CURRENT STATE: Fixed representation of celestial quantum states
## FUTURE STATE: Could add rotation animation matching sun/moon cycle
## FUTURE STATE: Could add gravitational influence on floating plots

const WheatPlot = preload("res://Core/GameMechanics/WheatPlot.gd")

# Reference to the celestial body quantum state
var wheat_plot: WheatPlot = null

# Celestial type indicators
var is_sun: bool = true

# Reference to biome for phase data
var biome: Node = null


func _init(wheat_plot_ref: WheatPlot, id: String, pos: Vector2i, sun_type: bool = true):
	super._init(id, pos)
	wheat_plot = wheat_plot_ref
	is_sun = sun_type
	plot_type = 2  # PlotType.CELESTIAL
	quantum_behavior = 2  # QuantumBehavior.FIXED


func set_biome(biome_ref: Node):
	"""Set reference to biome for phase synchronization"""
	biome = biome_ref


func get_plot_emojis() -> Dictionary:
	"""Return sun or moon emojis"""
	var celestial_emoji = "☀️" if is_sun else "🌙"
	return {"north": celestial_emoji, "south": celestial_emoji}


func get_dominant_emoji() -> String:
	"""Get the celestial emoji"""
	return "☀️" if is_sun else "🌙"


func get_state_description() -> String:
	"""Return readable description of celestial state"""
	var body_name = "Sun" if is_sun else "Moon"
	if wheat_plot:
		return "%s (Quantum Locked, Energy: %.2f)" % [body_name, wheat_plot.energy]
	return "%s (Fixed Celestial Body)" % body_name
