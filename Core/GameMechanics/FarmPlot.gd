class_name FarmPlot
extends BasePlot

## FarmPlot - Player-interactive plots in the farm grid
## Base class for all plots the player can apply tools to
## Handles quantum evolution, entanglement, and generic plot mechanics
## Subclasses: WheatPlot (crops with constraints)

const PhaseConstraint = preload("res://Core/GameMechanics/PhaseConstraint.gd")

# Plot type
enum PlotType { WHEAT, TOMATO, MUSHROOM, MILL, MARKET, KITCHEN, ENERGY_TAP }
@export var plot_type: PlotType = PlotType.WHEAT

# Phase constraint (for plots that restrict Bloch sphere movement)
var phase_constraint: PhaseConstraint = null

# Quantum evolution parameters (can be overridden by subclasses)
var theta_drift_rate: float = 0.1
var theta_entangled_target: float = PI / 2.0  # Target for entangled (superposition)
var theta_isolated_target: float = 0.0  # Target for isolated (certain state)

# Harvest bonuses (for crops)
var entanglement_bonus: float = 0.20  # +20% yield per entangled neighbor
var berry_phase_bonus: float = 0.05  # +5% yield per replant cycle
var observer_penalty: float = 0.10  # -10% final yield if measured

# Energy tap configuration (only used if plot_type == ENERGY_TAP)
var tap_target_emoji: String = ""        # What emoji to tap (🌾, 💧, 👥, etc.)
var tap_theta: float = 3.0 * PI / 4.0   # Tap position: near south pole
var tap_phi: float = PI / 4.0            # Tap position: 45° off axis
var tap_accumulated_resource: float = 0.0  # Energy accumulated
var tap_base_rate: float = 0.5           # Base drain rate


## Initialization


func _init():
	super._init()
	# FarmPlot-specific initialization (subclasses will override this)
	plot_type = PlotType.WHEAT  # Default plot type


## Helper Functions


func get_plot_emojis() -> Dictionary:
	"""Get the dual-emoji pair for this plot type"""
	match plot_type:
		PlotType.WHEAT:
			return {"north": "🌾", "south": "👥"}  # Wheat ↔ Labor
		PlotType.TOMATO:
			return {"north": "🍅", "south": "🍝"}  # Tomato ↔ Sauce
		PlotType.MUSHROOM:
			return {"north": "🍄", "south": "🍂"}  # Mushroom ↔ Detritus
		PlotType.MILL:
			return {"north": "🏭", "south": "💨"}  # Mill ↔ Flour
		PlotType.MARKET:
			return {"north": "🏪", "south": "💰"}  # Market ↔ Credits
		PlotType.KITCHEN:
			return {"north": "🍳", "south": "🍞"}  # Kitchen ↔ Bread
		PlotType.ENERGY_TAP:
			return {"north": "🚰", "south": "⚡"}  # Energy Tap ↔ Power
		_:
			return {"north": "?", "south": "?"}


func get_semantic_emoji() -> String:
	"""Get the dominant emoji based on quantum state"""
	if not is_planted or not quantum_state:
		var emojis = get_plot_emojis()
		return emojis["north"]  # Default to north emoji

	return quantum_state.get_semantic_state()


## Growth & Evolution


func grow(delta: float, biome = null, territory_manager = null, icon_network = null, conspiracy_network = null) -> float:
	"""Evolve quantum state with energy growth from biome"""
	if not is_planted or not quantum_state:
		return 0.0

	# Let biome handle quantum evolution
	if biome and biome.has_method("_evolve_quantum_substrate"):
		biome._evolve_quantum_substrate(delta)

	# Apply phase constraints if any
	if phase_constraint:
		phase_constraint.apply(quantum_state)

	return 0.0


## Entanglement


func add_entanglement(other_plot_id: String, strength: float) -> void:
	"""Add entanglement with another plot"""
	if entangled_plots.size() < MAX_ENTANGLEMENTS:
		entangled_plots[other_plot_id] = strength


func clear_entanglement() -> void:
	"""Clear all entanglement relationships"""
	entangled_plots.clear()


func get_entanglement_count() -> int:
	"""Get number of entangled plots"""
	return entangled_plots.size()
