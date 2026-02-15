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

## Base conversion rate: 1 quantum mass = 1 classical credit (direct mapping)
## IconMap mass (accumulated probability over ~13 steps) maps directly to credits
const QUANTUM_TO_CREDITS: float = 1.0

## Reality Midwife token emoji (display + economy tracking)
const MIDWIFE_EMOJI: String = "🍼"

# Removed: MIDWIFE_ACTION_COST (never used)

## Drain factor: fraction of probability removed during MEASURE
const DRAIN_FACTOR: float = 0.5

## Vocabulary purity multipliers (unknown vocab now penalized)
const KNOWN_VOCAB_PURITY_MULTIPLIER: float = 4.0
const UNKNOWN_VOCAB_PURITY_MULTIPLIER: float = 0.5

## ===========================================
## ACTION COSTS (Classical Resources as Sink)
## ===========================================
## All costs are in raw credits (the numbers stored in emoji_credits).
## Unified table: action_name → cost dictionary

const ACTION_COSTS: Dictionary = {
	"explore": {"🍞": 1},       # Send probe
	"measure": {"❄️": 1},       # Measure (3E) - cold/ice
	"reap": {"👥": 1},          # Claim harvest (labor)
	"harvest_all": {"🍼": 1},   # End of turn harvest (costs 1 Reality Midwife token)
	"quest_reroll": {"🐇": 1},   # Reroll quest slot
	"quest_lock": {"🌲": 1},     # Lock quest slot
	"explore_biome": {"🦅": 4}, # Scout new biome (reduced for 1:1 quantum mass economy)
	"remove_vocabulary": {"🐺": 20}, # Remove vocabulary: penalize with wolf cost
	"lindblad_pump": {"⚡": 8},  # Lindblad pump operator (reduced for 1:1 economy)
	"lindblad_drain": {"⚡": 8}  # Lindblad drain operator (reduced for 1:1 economy)
	# vocab_injection is dynamic - use get_action_cost()
}

## ===========================================
## QUANTUM GATE COSTS
## ===========================================
## All quantum gate operations cost resources from starter biomes.
## Costs are in emoji-credits (1 emoji = base cost).

const GATE_COSTS: Dictionary = {
	# Pauli gates - fundamental bit/phase flips
	"pauli_x": {"☀": 1},        # Sun - bit flip (most common)
	"pauli_y": {"🌙": 1},        # Moon - bit+phase flip
	"pauli_z": {"🍂": 1},        # Detritus - phase flip only

	# Other single-qubit gates
	"hadamard": {"🔥": 1},       # Fire - superposition
	"s_gate": {"🌱": 1},         # Sprout - phase rotation
	"t_gate": {"🌿": 1},         # Herb - π/8 phase

	# Two-qubit gates - entanglement and control
	"cnot": {"🍄": 1},           # Mushroom - entanglement (mycelial networks)
	"cz": {"🦌": 1},             # Deer - controlled-phase
	"swap": {"🐺": 1},           # Wolf - swap qubits
}

## Vocab injection dynamic costs (LOWERED to 4 for 1:1 quantum mass economy)
const VOCAB_INJECTION_SOUTH_COST: int = 4
const VOCAB_INJECTION_SPROUT_COST: Dictionary = {"🌱": 10}

## Lindblad injection costs (pump/drain operators)
const LINDBLAD_INJECTION_BASE_COST: int = 8  # Base cost for Lindblad operations (reduced for 1:1 economy)
const LINDBLAD_INJECTION_RESOURCE_COST: Dictionary = {"⚡": 1}  # Energy emoji for quantum operations

# Removed: old VOCAB_INJECTION_BASE_COST (never used)

## Hard cap on biome qubits (enforced by actions, not by the quantum computer)
const MAX_BIOME_QUBITS: int = 12

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


static func get_vocab_injection_cost(south_emoji: String) -> Dictionary:
	"""Get cost dictionary for vocabulary injection.

	Cost = 4 of south-pole emoji + 10 sprouts (🌱) - scaled for 1:1 quantum mass economy
	Returns dictionary of {emoji: amount} for costs.

	Args:
		south_emoji: The south pole emoji of the pair being injected
	"""
	if south_emoji == "":
		return VOCAB_INJECTION_SPROUT_COST.duplicate()

	var cost = VOCAB_INJECTION_SPROUT_COST.duplicate()
	cost[south_emoji] = VOCAB_INJECTION_SOUTH_COST
	return cost


static func get_lindblad_injection_cost() -> Dictionary:
	"""Get cost dictionary for Lindblad operator injection (pump/drain).

	Cost = 8 ⚡ (energy) - scaled for 1:1 quantum mass economy
	Returns dictionary of {emoji: amount} for costs.
	"""
	var cost = LINDBLAD_INJECTION_RESOURCE_COST.duplicate()
	for emoji in cost.keys():
		cost[emoji] = LINDBLAD_INJECTION_BASE_COST
	return cost


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


static func preflight_cost(costs: Dictionary, economy) -> Dictionary:
	"""Check affordability for a cost dictionary without spending.

	Returns: {ok: bool, cost: Dictionary, message?: String}
	"""
	if costs.is_empty():
		return {"ok": true, "cost": costs}
	if not economy:
		return {"ok": false, "cost": costs, "message": "Economy not available"}
	if not can_afford(economy, costs):
		return {"ok": false, "cost": costs, "message": "Insufficient resources"}
	return {"ok": true, "cost": costs}


static func commit_cost(costs: Dictionary, economy, reason: String = "") -> bool:
	"""Spend a preflighted cost dictionary."""
	if costs.is_empty():
		return true
	if not economy:
		return false
	var spend_reason = reason if reason != "" else "action"
	return spend(economy, costs, spend_reason)


## ===========================================
## UNIFIED ACTION COST API
## ===========================================

static func get_action_cost(action: String, context: Dictionary = {}) -> Dictionary:
	"""Get cost dictionary for an action.

	Args:
		action: Action name (explore, measure, reap, explore_biome, vocab_injection, lindblad_pump, lindblad_drain)
		context: Optional context for dynamic costs (e.g., {south_emoji: "🌾"})

	Returns:
		Dictionary of {emoji: amount} costs
	"""
	if action == "vocab_injection":
		return get_vocab_injection_cost(context.get("south_emoji", ""))
	if action == "lindblad_pump" or action == "lindblad_drain":
		return get_lindblad_injection_cost()
	return ACTION_COSTS.get(action, {})


static func get_gate_cost(gate_name: String) -> Dictionary:
	"""Get cost dictionary for a quantum gate.

	Args:
		gate_name: Gate name (pauli_x, pauli_y, pauli_z, hadamard, s_gate, t_gate, cnot, cz, swap)

	Returns:
		Dictionary of {emoji: amount} costs
	"""
	return GATE_COSTS.get(gate_name, {})


static func preflight_action(action: String, economy, context: Dictionary = {}) -> Dictionary:
	"""Check affordability for an action without spending."""
	var cost: Dictionary
	if economy and economy.has_method("get_overridden_action_cost"):
		cost = economy.get_overridden_action_cost(action, context)
	else:
		cost = get_action_cost(action, context)
	return preflight_cost(cost, economy)


static func preflight_gate(gate_name: String, economy) -> Dictionary:
	"""Check affordability for a quantum gate without spending."""
	var cost: Dictionary
	if economy and economy.has_method("get_overridden_gate_cost"):
		cost = economy.get_overridden_gate_cost(gate_name)
	else:
		cost = get_gate_cost(gate_name)
	return preflight_cost(cost, economy)


static func commit_action(action: String, economy, context: Dictionary = {}) -> bool:
	"""Spend cost for an action after success."""
	var cost: Dictionary
	if economy and economy.has_method("get_overridden_action_cost"):
		cost = economy.get_overridden_action_cost(action, context)
	else:
		cost = get_action_cost(action, context)
	return commit_cost(cost, economy, action)


static func commit_gate(gate_name: String, economy) -> bool:
	"""Spend cost for a quantum gate after success."""
	var cost: Dictionary
	if economy and economy.has_method("get_overridden_gate_cost"):
		cost = economy.get_overridden_gate_cost(gate_name)
	else:
		cost = get_gate_cost(gate_name)
	return commit_cost(cost, economy, gate_name)
