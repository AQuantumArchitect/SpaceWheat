class_name CelestialPlot
extends "res://Core/GameMechanics/BasePlot.gd"

## CelestialPlot - Immutable celestial objects
## Used for sun/moon qubits that cannot be modified by player
## Not selectable in farm grid
##
## PROPERTIES:
## - Do NOT evolve under biome physics (Hamiltonian, spring, energy transfer, dissipation)
## - Do NOT participate in force-directed graph forces
## - Act as anchors/drivers for all other quantum states
## - Immune to player actions (plant/harvest/entangle)

# Celestial type
enum CelestialType { SUN, MOON }
@export var celestial_type: CelestialType = CelestialType.SUN

# Immutability enforcement
var is_immutable: bool = true
var is_force_immune: bool = true  # Skip in force-directed graph visualization


func _init(type: CelestialType = CelestialType.SUN):
	super._init()
	celestial_type = type
	is_immutable = true


## Celestial Behavior


func get_celestial_emoji() -> String:
	"""Get emoji for this celestial object"""
	match celestial_type:
		CelestialType.SUN:
			return "☀️"
		CelestialType.MOON:
			return "🌙"
		_:
			return "?"


func get_celestial_name() -> String:
	"""Get name of this celestial object"""
	match celestial_type:
		CelestialType.SUN:
			return "Sun"
		CelestialType.MOON:
			return "Moon"
		_:
			return "Celestial"


## Prevent modification


func plant(labor_input = 0.0, wheat_input = 0.0, target_biome = null):
	"""Celestial objects cannot be planted"""
	print("⚠️ Cannot plant on celestial object: %s" % get_celestial_name())


func harvest() -> Dictionary:
	"""Celestial objects cannot be harvested"""
	return {"success": false, "reason": "Cannot harvest celestial object"}


func add_entanglement(other_plot_id: String, strength: float) -> void:
	"""Celestial objects cannot be entangled"""
	pass  # Silently ignore
