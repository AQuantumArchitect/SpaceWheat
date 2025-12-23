class_name ImperialPlotMidnight
extends ImperialPlot

## Imperial Plot Midnight - Nighttime Quantum Lock
##
## Variant that locks qubits near the |1⟩ state (theta ≈ π-0.01)
## Represents the night cycle of imperial authority, showing the "south" emoji


func _init(wheat_plot_ref: WheatPlot, id: String, pos: Vector2i):
	super._init(wheat_plot_ref, id, pos, PI - 0.01)  # Lock near |1⟩


func get_dominant_emoji() -> String:
	"""Get the south emoji (nighttime state)"""
	if wheat_plot:
		return wheat_plot.get_plot_emojis()["south"]
	return "🌙"


func get_state_description() -> String:
	"""Return readable description of midnight state"""
	if wheat_plot:
		return "Imperial Midnight: %s (Nighttime Lock)" % wheat_plot.get_plot_emojis()["south"]
	return "Imperial Midnight: Nighttime Quantum Lock"
