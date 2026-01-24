class_name BiomeResourceRegistry
extends RefCounted

## Resource and Planting Capability Management Component
##
## Extracted from BiomeBase to handle:
## - Producible/consumable emoji registration
## - Emoji pairings (north/south quantum axes)
## - Planting capabilities with costs and metadata

# Signals
signal resource_registered(emoji: String, is_producible: bool, is_consumable: bool)

# Planting Capability inner class
class PlantingCapability:
	"""Defines a plantable emoji pair with costs and metadata

	This makes the planting system parametric - biomes define what can be planted
	instead of hard-coding plant types across multiple files.
	"""
	var emoji_pair: Dictionary  # {"north": "...", "south": "..."}
	var plant_type: String      # "wheat" (for routing/identification)
	var cost: Dictionary        # {"...": 1} - emoji -> credits cost
	var display_name: String    # "Wheat" (UI labels)
	var requires_biome: bool    # true if only plantable in this biome

# Resource Registration State
var producible_emojis: Array[String] = []  # Emojis this biome can produce via harvest
var consumable_emojis: Array[String] = []  # Emojis this biome can consume via costs
var emoji_pairings: Dictionary = {}        # North <-> South emoji pairs for quantum states
var planting_capabilities: Array[PlantingCapability] = []  # Registered plant types

## Environmental icons that exist in bath but cannot be harvested from plots
## These are observable influences (sun/moon cycles, weather) not farm products
const ENVIRONMENTAL_ICONS = ["☀", "☀️", "🌙", "🌑", "💧", "🌊", "🔥", "⚡", "🌬️"]


# ============================================================================
# Resource Registration
# ============================================================================

func register_resource(emoji: String, is_producible: bool = true, is_consumable: bool = false) -> void:
	"""Register an emoji as a resource this biome works with

	Called during biome initialization to declare what resources
	can be harvested from or spent in this biome.

	Args:
		emoji: The emoji string (e.g., "...", "...", "...")
		is_producible: Can this biome produce this resource via harvest?
		is_consumable: Does this biome accept this resource as cost?
	"""
	if is_producible and emoji not in producible_emojis:
		producible_emojis.append(emoji)

	if is_consumable and emoji not in consumable_emojis:
		consumable_emojis.append(emoji)

	resource_registered.emit(emoji, is_producible, is_consumable)


func register_emoji_pair(north: String, south: String) -> void:
	"""Register a quantum emoji pairing (north pole <-> south pole)

	This defines what emojis can appear when measuring quantum states
	in this biome. Both emojis are automatically registered as producible.

	Args:
		north: North pole emoji (e.g., "...")
		south: South pole emoji (e.g., "...")
	"""
	emoji_pairings[north] = south
	emoji_pairings[south] = north

	# Both ends of the pairing can be produced
	register_resource(north, true, false)
	register_resource(south, true, false)


func register_planting_capability(north: String, south: String, plant_type: String,
                                   cost: Dictionary, display_name: String = "",
                                   exclusive: bool = false) -> void:
	"""Register a plantable emoji pair with costs and metadata (Parametric System)

	This makes the planting system parametric - biomes define what can be planted
	instead of hard-coding plant types. Tools query these capabilities dynamically.

	Args:
		north: North pole emoji (e.g., "...")
		south: South pole emoji (e.g., "...")
		plant_type: Type identifier (e.g., "wheat") for routing/identification
		cost: Dictionary of emoji -> credits required to plant (e.g., {"...": 1})
		display_name: UI label (defaults to capitalized plant_type if empty)
		exclusive: If true, only plantable in this biome (e.g., Forest wolves)
	"""
	var cap = PlantingCapability.new()
	cap.emoji_pair = {"north": north, "south": south}
	cap.plant_type = plant_type
	cap.cost = cost
	cap.display_name = display_name if display_name != "" else plant_type.capitalize()
	cap.requires_biome = exclusive
	planting_capabilities.append(cap)

	# Register cost emojis as consumable
	for emoji in cost.keys():
		if emoji not in consumable_emojis:
			register_resource(emoji, false, true)


# ============================================================================
# Query Methods
# ============================================================================

func get_plantable_capabilities() -> Array[PlantingCapability]:
	"""Get all plantable capabilities for this biome

	Tools query this to generate dynamic plant menus based on biome context.
	Returns Array of PlantingCapability objects with emoji pairs, costs, names.
	"""
	return planting_capabilities


func get_planting_cost(plant_type: String) -> Dictionary:
	"""Get planting cost for a specific plant type

	Args:
		plant_type: Plant identifier (e.g., "wheat", "mushroom")

	Returns:
		Dictionary of emoji -> credits cost, or {} if not plantable
	"""
	for cap in planting_capabilities:
		if cap.plant_type == plant_type:
			return cap.cost
	return {}  # Not plantable in this biome


func supports_plant_type(plant_type: String) -> bool:
	"""Check if this biome supports planting a specific type

	Args:
		plant_type: Plant identifier (e.g., "wheat", "mushroom")

	Returns:
		true if plantable, false otherwise
	"""
	for cap in planting_capabilities:
		if cap.plant_type == plant_type:
			return true
	return false


func get_producible_emojis() -> Array[String]:
	"""Get all emojis this biome can produce"""
	return producible_emojis


func get_consumable_emojis() -> Array[String]:
	"""Get all emojis this biome accepts as cost"""
	return consumable_emojis


func get_emoji_pairings() -> Dictionary:
	"""Get all north/south emoji pairings for this biome"""
	return emoji_pairings.duplicate()


func can_produce(emoji: String) -> bool:
	"""Check if this biome can produce the given emoji"""
	return emoji in producible_emojis


func can_consume(emoji: String) -> bool:
	"""Check if this biome accepts the given emoji as cost"""
	return emoji in consumable_emojis


func supports_emoji_pair(north: String, south: String, quantum_computer = null) -> bool:
	"""Check if this biome supports a north/south emoji pair for quantum states.

	Checks both emoji_pairings (registered pairs) and quantum_computer register_map.

	Args:
		north: North pole emoji
		south: South pole emoji
		quantum_computer: Optional QuantumComputer to check register_map

	Returns:
		true if biome can handle this pairing, false otherwise
	"""
	# Check registered pairings
	if emoji_pairings.has(north) and emoji_pairings[north] == south:
		return true

	# Check quantum_computer register_map
	if quantum_computer and quantum_computer.has_method("has_emoji"):
		if quantum_computer.has_emoji(north) and quantum_computer.has_emoji(south):
			return true

	return false


func get_harvestable_emojis() -> Array[String]:
	"""Get only emojis that can be harvested from plots

	Filters out environmental icons (sun, moon, water, fire) that affect
	quantum evolution but cannot be obtained through farming.

	Used by quest generation to ensure quests only request farmable resources.

	Returns:
		Array of emoji strings that can be obtained via planting/measuring/harvesting
	"""
	var harvestable: Array[String] = []

	for emoji in producible_emojis:
		if not emoji in ENVIRONMENTAL_ICONS:
			harvestable.append(emoji)

	return harvestable


# ============================================================================
# State Management
# ============================================================================

func clear() -> void:
	"""Clear all registered resources and capabilities"""
	producible_emojis.clear()
	consumable_emojis.clear()
	emoji_pairings.clear()
	planting_capabilities.clear()


func add_emoji_pair_to_producible(north_emoji: String, south_emoji: String) -> void:
	"""Add emoji pair to producible list (used during quantum system expansion)"""
	if north_emoji not in producible_emojis:
		producible_emojis.append(north_emoji)
	if south_emoji not in producible_emojis:
		producible_emojis.append(south_emoji)
	emoji_pairings[north_emoji] = south_emoji
	emoji_pairings[south_emoji] = north_emoji
