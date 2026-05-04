class_name WheatPlot
extends "res://Core/GameMechanics/FarmPlot.gd"

## WheatPlot - wheat crop. Growth is handled by BiomeBase quantum evolution;
## harvest yields are computed in BasePlot.harvest() using purity.
## Only handles: 🌾 (Natural Growth) ↔ 👥 (Labor) states


func _init():
	super._init()
	plot_type_name = "wheat"
	theta_drift_rate = 0.1
	theta_entangled_target = PI / 2.0
	theta_isolated_target = PI / 4.0


## Override to ensure wheat-specific emojis


func get_plot_emojis() -> Dictionary:
	# Wheat always has 🌾 ↔ 👥
	return {"north": "🌾", "south": "👥"}
