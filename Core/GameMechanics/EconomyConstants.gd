class_name EconomyConstants
extends RefCounted
const ActionIds = preload("res://Core/GameMechanics/ActionIds.gd")

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

# Reap season cost progression (Fibonacci)
const REAP_COST_SEQUENCE: Array[int] = [1, 1, 2, 3, 5, 8, 13, 21]

## ===========================================
## ACTION COSTS (Classical Resources as Sink)
## ===========================================
## All costs are in raw credits (the numbers stored in emoji_credits).
## Unified table: action_name → cost dictionary

const ACTION_COSTS: Dictionary = {
	"explore": {"🍞": 1},       # Send probe
	"measure": {"❄️": 1},       # Measure (3E) - cold/ice
	"pop": {"👥": 1},           # Targeted terminal extraction
	"reap": {MIDWIFE_EMOJI: 1}, # Seasonal reap (actual cost resolved by sequence)
	"quest_reroll": {"🐇": 1},   # Reroll quest slot
	"quest_lock": {"🌲": 1},     # Lock quest slot
	"discover_biome": {"🦅": 4}, # Scout new biome (reduced for 1:1 quantum mass economy)
	"remove_vocabulary": {"🐺": 20}, # Remove vocabulary: penalize with wolf cost
	"lindblad_pump": {"🌱": 8},  # Axis-aware dynamic cost adds north emoji
	"lindblad_drain": {"⚙": 2}  # Axis-aware dynamic cost adds south emoji
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
const VOCAB_INJECTION_BASE_COST: int = VOCAB_INJECTION_SOUTH_COST  # Deprecated compatibility alias

## Lindblad axis-aware costs
const LINDBLAD_PUMP_SPROUT_COST: int = 8
const LINDBLAD_PUMP_NORTH_COST: int = 32
const LINDBLAD_DRAIN_GEAR_COST: int = 2
const LINDBLAD_DRAIN_SOUTH_COST: int = 8

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

static func get_quantum_to_credits(economy = null) -> float:
	"""Get conversion rate, allowing save-driven economy variable overrides."""
	var fallback = QUANTUM_TO_CREDITS
	if economy and economy.has_method("get_economy_variable"):
		var value = float(economy.get_economy_variable("quantum_to_credits", fallback))
		if value > 0.0:
			return value
	return fallback


static func get_max_biome_qubits(economy = null) -> int:
	"""Get max biome qubit cap, allowing save-driven economy variable overrides."""
	var fallback = MAX_BIOME_QUBITS
	if economy and economy.has_method("get_economy_variable"):
		var value = int(economy.get_economy_variable("max_biome_qubits", fallback))
		if value > 0:
			return value
	return fallback


static func quantum_to_credits(probability: float, economy = null) -> int:
	"""Convert quantum probability to emoji-credits"""
	return int(probability * get_quantum_to_credits(economy))


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


static func get_lindblad_injection_cost(action: String = ActionIds.LINDBLAD_PUMP, context: Dictionary = {}) -> Dictionary:
	"""Get axis-aware Lindblad costs.

	Pump: 8 🌱 + 32 north-pole emoji
	Drain: 2 ⚙ + 8 south-pole emoji
	"""
	var normalized_action = normalize_action_id(action)
	var cost: Dictionary = {}
	if normalized_action == ActionIds.LINDBLAD_DRAIN:
		cost["⚙"] = LINDBLAD_DRAIN_GEAR_COST
		var south_emoji = str(context.get("south_emoji", ""))
		if south_emoji != "":
			cost[south_emoji] = LINDBLAD_DRAIN_SOUTH_COST
		return cost

	cost["🌱"] = LINDBLAD_PUMP_SPROUT_COST
	var north_emoji = str(context.get("north_emoji", ""))
	if north_emoji != "":
		cost[north_emoji] = LINDBLAD_PUMP_NORTH_COST
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
		action: Action name (explore, measure, reap, discover_biome, inject_vocabulary, lindblad_pump, lindblad_drain)
		context: Optional context for dynamic costs (e.g., {south_emoji: "🌾"})

	Returns:
		Dictionary of {emoji: amount} costs
	"""
	var normalized_action = normalize_action_id(action)
	if normalized_action == ActionIds.INJECT_VOCAB:
		return get_vocab_injection_cost(context.get("south_emoji", ""))
	if normalized_action == ActionIds.LINDBLAD_PUMP or normalized_action == ActionIds.LINDBLAD_DRAIN:
		return get_lindblad_injection_cost(normalized_action, context)
	if ACTION_COSTS.has(normalized_action):
		return ACTION_COSTS[normalized_action]
	if GATE_COSTS.has(normalized_action):
		return GATE_COSTS[normalized_action]
	return {}


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
	var normalized_action = normalize_action_id(action)
	var cost: Dictionary
	if economy and economy.has_method("get_overridden_action_cost"):
		cost = economy.get_overridden_action_cost(normalized_action, context)
	else:
		cost = get_action_cost(normalized_action, context)
	return preflight_cost(cost, economy)


static func preflight_gate(gate_name: String, economy) -> Dictionary:
	"""Check affordability for a quantum gate without spending."""
	var cost: Dictionary
	if economy and economy.has_method("get_overridden_gate_cost"):
		cost = economy.get_overridden_gate_cost(gate_name)
	else:
		cost = get_gate_cost(gate_name)
	return preflight_cost(cost, economy)


static func commit_action(action: String, economy, context: Dictionary = {}, reason: String = "") -> bool:
	"""Spend cost for an action after success."""
	var normalized_action = normalize_action_id(action)
	var cost: Dictionary
	if economy and economy.has_method("get_overridden_action_cost"):
		cost = economy.get_overridden_action_cost(normalized_action, context)
	else:
		cost = get_action_cost(normalized_action, context)
	var spend_reason = reason if reason != "" else normalized_action
	return commit_cost(cost, economy, spend_reason)


static func commit_gate(gate_name: String, economy, reason: String = "") -> bool:
	"""Spend cost for a quantum gate after success."""
	var cost: Dictionary
	if economy and economy.has_method("get_overridden_gate_cost"):
		cost = economy.get_overridden_gate_cost(gate_name)
	else:
		cost = get_gate_cost(gate_name)
	var spend_reason = reason if reason != "" else gate_name
	return commit_cost(cost, economy, spend_reason)


static func normalize_action_id(action: String) -> String:
	return ActionIds.normalize_action(action)
