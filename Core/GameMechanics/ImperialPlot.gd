class_name ImperialPlot
extends PlotBase

## Imperial Plot - Quantum State Lock Container
##
## Represents plots that freeze the Bloch sphere at a fixed theta value,
## effectively locking quantum evolution. The locked state can be flipped
## between north and south emoji states to produce stable output.
##
## ARCHITECTURE RATIONALE:
## - QuantumBehavior.FIXED: Completely locked quantum state
## - Theta is locked to a specific value (0.01 or π-0.01)
## - Used to create stable quantum outputs from dual-emoji inputs
## - Can flip between north (theta ≈ 0) and south (theta ≈ π) states
##
## CURRENT STATE: Frozen Bloch sphere at specified theta
## FUTURE STATE: Could add phase manipulation, entanglement breaking

const WheatPlot = preload("res://Core/GameMechanics/WheatPlot.gd")

# Reference to the underlying quantum plot
var wheat_plot: WheatPlot = null

# Lock parameters
var locked_theta: float = 0.01  # Near |0⟩ state by default
var is_locked: bool = true


func _init(wheat_plot_ref: WheatPlot, id: String, pos: Vector2i, theta: float = 0.01):
	super._init(id, pos)
	wheat_plot = wheat_plot_ref
	plot_type = 3  # PlotType.IMPERIAL
	quantum_behavior = 2  # QuantumBehavior.FIXED
	locked_theta = theta


func lock_theta(theta: float) -> void:
	"""Lock the theta value and freeze quantum evolution"""
	locked_theta = clamp(theta, 0.01, PI - 0.01)
	is_locked = true


func get_locked_theta() -> float:
	"""Get the currently locked theta value"""
	return locked_theta


func flip_bits() -> void:
	"""Flip the quantum state between north and south emojis

	Switches from theta ≈ 0.01 to theta ≈ π-0.01 or vice versa
	"""
	if locked_theta < PI / 2.0:
		# Currently near |0⟩, flip to near |1⟩
		locked_theta = PI - 0.01
	else:
		# Currently near |1⟩, flip to near |0⟩
		locked_theta = 0.01


func get_plot_emojis() -> Dictionary:
	"""Return north/south emojis based on locked state"""
	if wheat_plot:
		var emojis = wheat_plot.get_plot_emojis()
		# Return based on which pole we're locked to
		if locked_theta < PI / 2.0:
			# Locked near |0⟩ - return north emoji
			return {"north": emojis["north"], "south": emojis["north"]}
		else:
			# Locked near |1⟩ - return south emoji
			return {"south": emojis["south"], "north": emojis["south"]}
	return {"north": "🔒", "south": "🔒"}


func get_dominant_emoji() -> String:
	"""Get the emoji matching the locked quantum state"""
	if wheat_plot:
		var emojis = wheat_plot.get_plot_emojis()
		if locked_theta < PI / 2.0:
			return emojis["north"]
		else:
			return emojis["south"]
	return "🔒"


func get_state_description() -> String:
	"""Return readable description of imperial plot state"""
	var state_name = "North State" if locked_theta < PI / 2.0 else "South State"
	var theta_display = "%.2f rad" % locked_theta
	if wheat_plot:
		return "Imperial Plot: %s (θ=%s, Frozen)" % [state_name, theta_display]
	return "Imperial Plot: %s (Quantum Locked)" % state_name
