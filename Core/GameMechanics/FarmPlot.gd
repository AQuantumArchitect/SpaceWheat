class_name FarmPlot
extends PlotBase

## Farm Plot Wrapper - Force Graph Behavior Container
##
## Represents plantable farm crops (wheat, tomato, mushroom) with quantum balloons
## that float above the plots in the play area.
##
## ARCHITECTURE RATIONALE:
## This wrapper exists to enable future force-directed graph behaviors:
## - QuantumBehavior.FLOATING: Balloons that respond to quantum forces
## - Future: Add force calculations based on entanglement topology
## - Future: Spring physics connecting entangled qubits
## - Future: Repulsion from non-entangled qubits
## - Future: Connect to conspiracy network for additional forces
##
## CURRENT STATE: Minimal wrapper, delegates all logic to WheatPlot
## FUTURE STATE: Will contain force-directed positioning and animation logic

const WheatPlot = preload("res://Core/GameMechanics/WheatPlot.gd")

# Reference to the underlying wheat plot data
var wheat_plot: WheatPlot = null

# Farm-specific properties
var is_planted: bool = false


func _init(wheat_plot_ref: WheatPlot, id: String, pos: Vector2i):
	super._init(id, pos)
	wheat_plot = wheat_plot_ref
	plot_type = 0  # PlotType.FARM
	quantum_behavior = 0  # QuantumBehavior.FLOATING


func get_plot_emojis() -> Dictionary:
	"""Delegate to underlying wheat plot"""
	if wheat_plot:
		return wheat_plot.get_plot_emojis()
	return {"north": "🌾", "south": "👥"}


func get_dominant_emoji() -> String:
	"""Delegate to underlying wheat plot"""
	if wheat_plot:
		return wheat_plot.get_dominant_emoji()
	return "🌾"


func get_state_description() -> String:
	"""Delegate to underlying wheat plot"""
	if wheat_plot:
		return wheat_plot.get_state_description()
	return "Empty farm plot"
