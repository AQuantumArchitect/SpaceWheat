class_name WheatPlot
extends "res://Core/GameMechanics/FarmPlot.gd"

## WheatPlot - Wheat crop with quantum constraints (Model B)
## Specialized FarmPlot that adds wheat-specific quantum evolution
## Only handles: 🌾 (Natural Growth) ↔ 👥 (Labor) states

# Wheat-specific quantum parameters
var wheat_theta_stable: float = PI / 4.0  # Stable point for wheat growth
var wheat_spring_constant: float = 0.5    # Spring attraction strength

# Icon network references (for spring attraction)
var wheat_icon = null  # Icon that wheat is attracted to
var mushroom_icon = null  # Icon that competes with wheat
var icon_network = null  # Reference to icon network


func _init():
	super._init()
	plot_type = PlotType.WHEAT  # Always wheat
	theta_drift_rate = 0.1
	theta_entangled_target = PI / 2.0  # Entangled qubits stay uncertain
	theta_isolated_target = PI / 4.0   # Isolated wheat drifts toward growth


## Model B: Wheat growth is handled by BiomeBase quantum evolution
# Legacy methods grow_wheat() and harvest_wheat() removed in Model B refactor
# All quantum state management is done through parent_biome.quantum_computer
# Harvest yields are computed in BasePlot.harvest() using purity


## Override to ensure wheat-specific emojis


func get_plot_emojis() -> Dictionary:
	"""Wheat always has 🌾 ↔ 👥"""
	return {"north": "🌾", "south": "👥"}
