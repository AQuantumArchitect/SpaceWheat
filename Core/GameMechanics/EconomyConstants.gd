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
	"discover_biome": {"🦅": 21}, # Scout new biome
	"remove_biome": {"💀": 34},  # Cull biome: pay skulls, then liquidate the biome's live state
	"remove_vocabulary": {"🐺": 13}, # Remove signature base cost (N+S pole costs added dynamically)
	"lindblad_pump": {"📜": 4},   # Socialite tribute contract; +north pole emoji added dynamically
	"lindblad_drain": {"🧺": 4},  # Socialite treaty / village basket; +south pole emoji added dynamically
	"spark_north": {},            # Spark pole shift — cost is 1× north pole emoji, added dynamically
	"spark_south": {}             # Spark pole shift — cost is 1× south pole emoji, added dynamically
	# icon_injection and remove_vocabulary are dynamic - use get_action_cost()
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
	"s_gate": {"🌀": 1},         # Vortex - π/2 phase rotation
	"t_gate": {"🌿": 1},         # Herb - π/8 phase

	# Two-qubit gates - entanglement and control
	"cnot": {"🍄": 1},           # Mushroom - entanglement (mycelial networks)
	"cz": {"🦌": 1},             # Deer - controlled-phase
	"swap": {"⚖": 1},           # Scales - equal exchange (village commerce, 1-hop via 💰)
}

## ===========================================
## UNITARY ROTATION COSTS
## ===========================================
## Continuous Bloch sphere rotations (Group 1). One cost per click.

const ROTATION_COSTS: Dictionary = {
	"rotate_up":   {"⛰": 1},    # Mountain - ascending/north pole (1-hop via ☀/Celestial Archons)
	"rotate_down": {"🏜": 1},    # Desert - descending/south pole (1-hop via ❄/Hearth Keepers)
}

## ===========================================
## GATE-MODE ACTION COSTS
## ===========================================
## Gate-mode instrument actions (inspect, remove_gates). Not per-gate costs.

const GATE_ACTION_COSTS: Dictionary = {
	"inspect":      {"🔬": 1},   # Microscope - observe entanglement (1-hop via ⚙/Rocketwright)
	"remove_gates": {"⚔": 1},   # Sword - break bonds (1-hop via 🔥/Children of the Ember)
}

## Icon injection dynamic costs
const ICON_INJECTION_SOUTH_COST: int = 13
const ICON_INJECTION_SPROUT_COST: Dictionary = {"🌱": 5}

## Icon removal dynamic costs (wolf base + 3 of each pole emoji)
const ICON_REMOVAL_WOLF_COST: int = 13
const ICON_REMOVAL_POLE_COST: int = 3

## Lindblad axis-aware costs (Socialite networking — drain/transfer/pump as
## faction-contract abstraction; basket/handshake/scroll mark the social
## instrument, pole emojis are the resource swung in the deal).
const LINDBLAD_PUMP_SCROLL_COST: int = 4   # 📜 tribute contract
const LINDBLAD_PUMP_NORTH_COST: int = 21   # north pole resource staked in pact
const LINDBLAD_DRAIN_BASKET_COST: int = 4  # 🧺 village-basket treaty
const LINDBLAD_DRAIN_SOUTH_COST: int = 8   # south pole emoji extracted by treaty
const LINDBLAD_TRANSFER_HANDSHAKE_COST: int = 2  # 🤝 brokered exchange
const LINDBLAD_TRANSFER_SOURCE_COST: int = 13    # source (north) emoji
const LINDBLAD_TRANSFER_DRAIN_COST: int = 8      # destination (south) emoji

## Transitional aliases for older cost names still used by some callers/tests.
const LINDBLAD_DRAIN_GEAR_COST: int = LINDBLAD_DRAIN_BASKET_COST
const LINDBLAD_PUMP_WIND_COST: int = LINDBLAD_PUMP_SCROLL_COST
const LINDBLAD_PUMP_SPARK_COST: int = SPARK_POLE_COST

## Spark pole-shift cost: just the pole emoji itself (no fee).
const SPARK_POLE_COST: int = 1

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
	"""Get cost dictionary for signature injection.

	Cost = 4 of south-pole emoji + 10 sprouts (🌱) - scaled for 1:1 quantum mass economy
	Returns dictionary of {emoji: amount} for costs.

	Args:
		south_emoji: The south pole emoji of the pair being injected
	"""
	if south_emoji == "":
		return ICON_INJECTION_SPROUT_COST.duplicate()

	var cost = ICON_INJECTION_SPROUT_COST.duplicate()
	cost[south_emoji] = ICON_INJECTION_SOUTH_COST
	return cost


static func get_lindblad_injection_cost(action: String = ActionIds.LINDBLAD_PUMP, context: Dictionary = {}) -> Dictionary:
	"""Get axis-aware Lindblad costs (Socialite networking frame).

	Pump (tribute contract):  4 📜 + 21 north-pole emoji
	Drain (village treaty):   4 🧺 + 8 south-pole emoji
	Transfer (brokered deal): 2 🤝 + 13 source emoji + 8 destination emoji
	"""
	var normalized_action = normalize_action_id(action)
	var cost: Dictionary = {}
	if normalized_action == ActionIds.LINDBLAD_DRAIN:
		cost["🧺"] = LINDBLAD_DRAIN_BASKET_COST
		var south_emoji = str(context.get("south_emoji", ""))
		if south_emoji != "":
			cost[south_emoji] = LINDBLAD_DRAIN_SOUTH_COST
		return cost

	# Transfer: 2 🤝 + 13× source (north) + 8× destination (south)
	if normalized_action == "lindblad_transfer":
		var north = str(context.get("north_emoji", ""))
		var south = str(context.get("south_emoji", ""))
		cost["🤝"] = LINDBLAD_TRANSFER_HANDSHAKE_COST
		if north != "":
			cost[north] = LINDBLAD_TRANSFER_SOURCE_COST
		if south != "" and south != north:
			cost[south] = LINDBLAD_TRANSFER_DRAIN_COST
		return cost

	# Pump: 4 📜 + 21 north-pole emoji
	cost["📜"] = LINDBLAD_PUMP_SCROLL_COST
	var north_emoji = str(context.get("north_emoji", ""))
	if north_emoji != "":
		cost[north_emoji] = LINDBLAD_PUMP_NORTH_COST
	return cost


static func get_spark_cost(action: String, context: Dictionary = {}) -> Dictionary:
	"""Get cost for a Spark pole-shift: 1× the pole emoji being shifted toward.

	spark_north → 1× north_emoji
	spark_south → 1× south_emoji
	"""
	var normalized_action = normalize_action_id(action)
	if normalized_action == ActionIds.SPARK_NORTH:
		var north = str(context.get("north_emoji", ""))
		if north != "":
			return {north: SPARK_POLE_COST}
		return {}
	if normalized_action == ActionIds.SPARK_SOUTH:
		var south = str(context.get("south_emoji", ""))
		if south != "":
			return {south: SPARK_POLE_COST}
		return {}
	return {}


static func get_vocab_removal_cost(north_emoji: String = "", south_emoji: String = "") -> Dictionary:
	"""Get cost for removing a icon.

	Base: 13 🐺 + 3 of each pole emoji (when known).
	"""
	var cost = {"🐺": ICON_REMOVAL_WOLF_COST}
	if north_emoji != "":
		cost[north_emoji] = ICON_REMOVAL_POLE_COST
	if south_emoji != "" and south_emoji != north_emoji:
		cost[south_emoji] = ICON_REMOVAL_POLE_COST
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
	if normalized_action == "remove_vocabulary" and (context.has("north_emoji") or context.has("south_emoji")):
		return get_vocab_removal_cost(context.get("north_emoji", ""), context.get("south_emoji", ""))
	if normalized_action in [ActionIds.LINDBLAD_PUMP, ActionIds.LINDBLAD_DRAIN, "lindblad_transfer"]:
		return get_lindblad_injection_cost(normalized_action, context)
	if normalized_action in [ActionIds.SPARK_NORTH, ActionIds.SPARK_SOUTH]:
		return get_spark_cost(normalized_action, context)
	if ACTION_COSTS.has(normalized_action):
		return ACTION_COSTS[normalized_action]
	if GATE_COSTS.has(normalized_action):
		return GATE_COSTS[normalized_action]
	if ROTATION_COSTS.has(normalized_action):
		return ROTATION_COSTS[normalized_action]
	if GATE_ACTION_COSTS.has(normalized_action):
		return GATE_ACTION_COSTS[normalized_action]
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
