class_name EconomyConstants
extends RefCounted

## ===========================================
## UNIFIED ECONOMIC CONSTANTS
## ===========================================
## Single source of truth for all economic values.
## No universal currency - all resources are [emoji]-credits.

## ===========================================
## QUANTUM ↔ CLASSICAL CONVERSION
## ===========================================

## Base conversion rate: 1 quantum probability unit = X emoji-credits
const QUANTUM_TO_CREDITS: float = 10.0

## Reality Midwife token emoji (display + economy tracking)
const MIDWIFE_EMOJI: String = "🍼"

## Reality Midwife token cost for harvest-all action (in emoji-credits)
const MIDWIFE_ACTION_COST: int = 1

## Drain factor: fraction of probability removed during MEASURE
const DRAIN_FACTOR: float = 0.5

## ===========================================
## PRODUCTION EFFICIENCY
## ===========================================

const MILL_EFFICIENCY: float = 0.8    # 10 wheat → 8 flour + 40 💰
const KITCHEN_EFFICIENCY: float = 0.6 # 5 flour → 3 bread

## ===========================================
## BUILD MODE COSTS
## ===========================================

## Cost to inject new vocabulary (in 💰-credits)
## ~2 quest rewards = 1 new word
const VOCAB_INJECTION_BASE_COST: int = 150

## Hard cap on biome qubits (enforced by actions, not by the quantum computer)
const MAX_BIOME_QUBITS: int = 12

## Planting costs (emoji → cost in 💰-credits)
const PLANTING_COSTS: Dictionary = {
	"🌾": 10,   # wheat - basic
	"🌻": 15,   # sunflower
	"🍄": 20,   # mushroom
	"🔥": 50,   # fire - dangerous
	"⚡": 50,   # energy - volatile
}

const DEFAULT_PLANTING_COST: int = 25

## ===========================================
## PLANT TYPE → EMOJI PAIR MAPPING
## ===========================================
## Central registry for all plant types and their quantum axes.
## Used for dynamic capability creation in BUILD mode.

const PLANT_TYPE_EMOJIS: Dictionary = {
	"wheat": {"north": "🌾", "south": "🍄"},
	"mushroom": {"north": "🍄", "south": "🌾"},
	"tomato": {"north": "🍅", "south": "🌿"},
	"vegetation": {"north": "🌿", "south": "🍂"},
	"rabbit": {"north": "🐇", "south": "🐺"},
	"wolf": {"north": "🐺", "south": "🐇"},
	"fire": {"north": "🔥", "south": "❄️"},
	"water": {"north": "💧", "south": "🏜️"},
	"flour": {"north": "💨", "south": "🌾"},
	"bread": {"north": "🍞", "south": "💨"},
	"bull": {"north": "🐂", "south": "🐻"},
	"bear": {"north": "🐻", "south": "🐂"},
	"money": {"north": "💰", "south": "💳"},
	"credit": {"north": "💳", "south": "💰"},
	"sun": {"north": "☀", "south": "🌙"},
	"moon": {"north": "🌙", "south": "☀"},
}

## ===========================================
## CONVERSION FUNCTIONS
## ===========================================

static func quantum_to_credits(probability: float) -> int:
	"""Convert quantum probability to emoji-credits"""
	return int(probability * QUANTUM_TO_CREDITS)


static func get_planting_cost(emoji: String) -> int:
	"""Get cost in 💰-credits to plant a specific emoji"""
	return PLANTING_COSTS.get(emoji, DEFAULT_PLANTING_COST)


static func get_plant_type_emojis(plant_type: String) -> Dictionary:
	"""Get emoji pair for a plant type.

	Returns {"north": emoji, "south": emoji} or empty dict if not found.
	"""
	return PLANT_TYPE_EMOJIS.get(plant_type, {})


static func get_vocab_injection_cost(emoji: String) -> Dictionary:
	"""Get cost dictionary for vocabulary injection.

	Cost is paid in the south-pole emoji resource.
	Returns dictionary of {emoji: amount} for costs.
	"""
	if emoji == "":
		return {}
	return {emoji: 100}


static func can_afford(economy, costs: Dictionary) -> bool:
	"""Check if economy can afford the given costs"""
	if not economy:
		return false
	if economy.has_method("can_afford_cost"):
		return economy.can_afford_cost(costs)
	if economy.has_method("can_afford_resource"):
		for emoji in costs:
			var amount = costs[emoji]
			if not economy.can_afford_resource(emoji, amount):
				return false
		return true
	return false


static func spend(economy, costs: Dictionary, reason: String = "purchase") -> bool:
	"""Spend resources from economy. Returns true if successful."""
	if not can_afford(economy, costs):
		return false
	if economy.has_method("spend_cost"):
		return economy.spend_cost(costs, reason)
	if economy.has_method("spend_resource"):
		for emoji in costs:
			var amount = costs[emoji]
			economy.spend_resource(emoji, amount, reason)
		return true
	return false
