class_name ImperialPlotNoon
extends ImperialPlot

## Imperial Plot Noon - Daytime Quantum Lock
##
## Variant that locks qubits near the |0⟩ state (theta ≈ 0.01)
## Represents the day cycle of imperial authority, showing the "north" emoji


func _init(wheat_plot_ref: WheatPlot, id: String, pos: Vector2i):
	super._init(wheat_plot_ref, id, pos, 0.01)  # Lock near |0⟩


func get_dominant_emoji() -> String:
	"""Get the north emoji (daytime state)"""
	if wheat_plot:
		return wheat_plot.get_plot_emojis()["north"]
	return "☀️"


func get_state_description() -> String:
	"""Return readable description of noon state"""
	if wheat_plot:
		return "Imperial Noon: %s (Daytime Lock)" % wheat_plot.get_plot_emojis()["north"]
	return "Imperial Noon: Daytime Quantum Lock"
