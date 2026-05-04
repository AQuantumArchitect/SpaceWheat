class_name FarmPlot
extends "res://Core/GameMechanics/BasePlot.gd"

## FarmPlot - Player-interactive plots in the farm grid
## Base class for all plots the player can apply tools to
## Handles quantum evolution, entanglement, and generic plot mechanics
## Subclasses: WheatPlot (crops with constraints)

# Plot type (string-based, data-driven)
@export var plot_type_name: String = "wheat"

# Quantum evolution parameters (can be overridden by subclasses)
var theta_drift_rate: float = 0.1
var theta_entangled_target: float = PI / 2.0  # Target for entangled (superposition)
var theta_isolated_target: float = 0.0  # Target for isolated (certain state)

# Harvest bonuses (for crops)
var entanglement_bonus: float = 0.20  # +20% yield per entangled neighbor
var berry_phase_bonus: float = 0.05  # +5% yield per replant cycle
var observer_penalty: float = 0.10  # -10% final yield if measured

## Initialization


func _init():
	super._init()
	# FarmPlot-specific initialization (subclasses will override this)
	plot_type_name = "wheat"  # String-based type (data-driven)


## Helper Functions


func get_plot_emojis() -> Dictionary:
	# Get the dual-emoji pair for this plot type

	# PHASE 5 (PARAMETRIC): Queries parent biome for emoji pair via plot_type_name.
	# Delegates to BasePlot.get_plot_emojis() which queries biome capabilities.

	# OLD (Hard-Coded): Match statement on PlotType enum
	# NEW (Parametric): Query biome.get_plantable_capabilities() for plot_type_name
	# PARAMETRIC: Delegate to BasePlot which queries parent biome
	return super.get_plot_emojis()


func get_semantic_emoji() -> String:
	# Get the dominant emoji based on quantum state.
	if not is_active():
		var emojis = get_plot_emojis()
		return emojis.get("north", "")

	var outcome = get_measured_outcome()
	if outcome != "":
		return outcome
	return get_basis_labels()[0]


## Growth & Evolution


func grow(_delta: float, _biome = null) -> float:
	# Quantum evolution is handled by the parent biome's quantum computer;
	# this method exists only as a per-frame hook for future plot logic.
	return 0.0


## Entanglement


func add_entanglement(other_plot_id: String, strength: float) -> void:
	# Add entanglement with another plot
	if entangled_plots.size() < MAX_ENTANGLEMENTS:
		entangled_plots[other_plot_id] = strength


func clear_entanglement() -> void:
	# Clear all entanglement relationships
	entangled_plots.clear()


func get_entanglement_count() -> int:
	# Get number of entangled plots
	return entangled_plots.size()
