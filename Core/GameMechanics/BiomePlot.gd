class_name BiomePlot
extends "res://Core/GameMechanics/BasePlot.gd"

## BiomePlot - Internal biome entities
## Used for items managed by the biome system
## Not selectable by player, not in farm grid
## Examples: transformation nodes, market qubits, guild resources

# Biome plot type
enum BiomePlotType { TRANSFORMATION_NODE, MARKET_QUBIT, GUILD_RESOURCE, ENVIRONMENT }
@export var biome_plot_type: BiomePlotType = BiomePlotType.TRANSFORMATION_NODE


func _init(type: BiomePlotType = BiomePlotType.TRANSFORMATION_NODE):
	super._init()
	biome_plot_type = type


## Biome-Specific Behavior


func get_biome_plot_type_name() -> String:
	"""Get name of this biome plot type"""
	match biome_plot_type:
		BiomePlotType.TRANSFORMATION_NODE:
			return "Transformation Node"
		BiomePlotType.MARKET_QUBIT:
			return "Market Qubit"
		BiomePlotType.GUILD_RESOURCE:
			return "Guild Resource"
		BiomePlotType.ENVIRONMENT:
			return "Environment"
		_:
			return "Biome Plot"


func get_biome_emoji() -> String:
	"""Get emoji for this biome plot"""
	match biome_plot_type:
		BiomePlotType.TRANSFORMATION_NODE:
			return "⚗️"  # Alchemy/transformation
		BiomePlotType.MARKET_QUBIT:
			return "💰"  # Market/trading
		BiomePlotType.GUILD_RESOURCE:
			return "👥"  # People/guild
		BiomePlotType.ENVIRONMENT:
			return "🌍"  # Environment
		_:
			return "?"


## Prevent player interaction


func plant(labor_input = 0.0, wheat_input = 0.0, target_biome = null):
	"""Biome plots are not planted by players"""
	print("⚠️ Cannot plant on biome plot: %s" % get_biome_plot_type_name())


func harvest() -> Dictionary:
	"""Biome plots are not harvested by players"""
	return {"success": false, "reason": "Cannot harvest biome plot"}


func add_entanglement(other_plot_id: String, strength: float) -> void:
	"""Biome plots handle entanglement internally"""
	pass  # Let biome handle this
