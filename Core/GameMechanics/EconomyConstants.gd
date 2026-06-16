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

## Boltzmann market temperature (kT) for the E = −kT·log p scarcity law
## (EnergyPricing). The single dimensional anchor for every reward/price/cost —
## it replaced the old QUANTUM_CLASSICAL_RATIO. MARKET_TEMPERATURE_BASE is the
## cold-biome floor; a biome's effective kT rises with its mixedness (entropy)
## by ENTROPY_GAIN. Both are overridable via FarmVariableGraph JSONL
## (tuning.market_temperature, tuning.market_temperature_entropy_gain) so the
## Biome Lab can sweep them empirically.
const MARKET_TEMPERATURE_BASE: float = 10.0
const MARKET_TEMPERATURE_ENTROPY_GAIN: float = 1.0

## Reality Midwife token emoji (display + economy tracking)
const MIDWIFE_EMOJI: String = "🍼"

# Reap season cost progression (Fibonacci)
const REAP_COST_SEQUENCE: Array[int] = [1, 1, 2, 3, 5, 8, 13, 21]

## ===========================================
## ACTION / GATE / ROTATION COSTS — DATA, not code
## ===========================================
## Every FIXED cost now lives in the canonical Core/Config/FarmVariableGraph/default.jsonl
## (action_costs.* and gate_costs.*), loaded at boot and read via FarmEconomy's
## get_overridden_action_cost / get_overridden_gate_cost. There is deliberately NO static
## cost table here — code holds only the DYNAMIC cost formulas below (inject / remove_icon /
## spark / lindblad), whose cost depends on runtime context. One source of truth, no
## code-default fallback fighting the JSONL.

## Icon injection dynamic costs
const ICON_INJECTION_SOUTH_COST: int = 13
const ICON_INJECTION_SPROUT_COST: Dictionary = {"🌱": 5}

## Icon removal dynamic costs (wolf base + 3 of each pole emoji)
const ICON_REMOVAL_WOLF_COST: int = 13
const ICON_REMOVAL_POLE_COST: int = 3

## Lindblad axis-aware costs (Merchant networking — drain/transfer/pump as
## faction-contract abstraction; basket/handshake/scroll mark the social
## instrument, pole emojis are the resource swung in the deal).
const LINDBLAD_PUMP_SCROLL_COST: int = 4   # 📜 tribute contract
const LINDBLAD_PUMP_NORTH_COST: int = 21   # north pole resource staked in pact
const LINDBLAD_DRAIN_BASKET_COST: int = 4  # 🧺 village-basket treaty
const LINDBLAD_DRAIN_SOUTH_COST: int = 8   # south pole emoji extracted by treaty

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
	# Get conversion rate, allowing save-driven economy variable overrides.
	var fallback = QUANTUM_TO_CREDITS
	if economy and economy.has_method("get_economy_variable"):
		var value = float(economy.get_economy_variable("quantum_to_credits", fallback))
		if value > 0.0:
			return value
	return fallback


static func get_max_biome_qubits(economy = null) -> int:
	# Get max biome qubit cap, allowing save-driven economy variable overrides.
	var fallback = MAX_BIOME_QUBITS
	if economy and economy.has_method("get_economy_variable"):
		var value = int(economy.get_economy_variable("max_biome_qubits", fallback))
		if value > 0:
			return value
	return fallback


static func quantum_to_credits(probability: float, economy = null) -> int:
	# Convert quantum probability to emoji-credits
	return int(probability * get_quantum_to_credits(economy))


static func get_icon_injection_cost(south_emoji: String) -> Dictionary:
	# Get cost dictionary for icon injection.

	# Cost = 4 of south-pole emoji + 10 sprouts (🌱) - scaled for 1:1 quantum mass economy
	# Returns dictionary of {emoji: amount} for costs.

	# Args:
	# south_emoji: The south pole emoji of the pair being injected
	if south_emoji == "":
		return ICON_INJECTION_SPROUT_COST.duplicate()

	var cost = ICON_INJECTION_SPROUT_COST.duplicate()
	cost[south_emoji] = ICON_INJECTION_SOUTH_COST
	return cost


static func get_lindblad_injection_cost(action: String = ActionIds.LINDBLAD_PUMP, context: Dictionary = {}) -> Dictionary:
	# Get axis-aware Lindblad costs (Merchant networking frame).

	# Pump (tribute contract):  4 📜 + 21 north-pole emoji
	# Drain (village treaty):   4 🧺 + 8 south-pole emoji
	# Transfer (brokered deal): 2 🤝 + 13 source emoji + 8 destination emoji
	var normalized_action = normalize_action_id(action)
	var cost: Dictionary = {}
	if normalized_action == ActionIds.LINDBLAD_DRAIN:
		# Drain (discharge south): flat 🧺 social fee + surprisal drive cost in the
		# south pole (EnergyPricing.drive_units via context); flat fallback otherwise.
		cost["🧺"] = LINDBLAD_DRAIN_BASKET_COST
		var south_emoji = str(context.get("south_emoji", ""))
		if south_emoji != "":
			cost[south_emoji] = int(context.get("drive_units", LINDBLAD_DRAIN_SOUTH_COST))
		return cost

	# Pump (charge north): flat 📜 social fee + surprisal drive cost in the north
	# pole (EnergyPricing.drive_units via context); flat fallback otherwise.
	cost["📜"] = LINDBLAD_PUMP_SCROLL_COST
	var north_emoji = str(context.get("north_emoji", ""))
	if north_emoji != "":
		cost[north_emoji] = int(context.get("drive_units", LINDBLAD_PUMP_NORTH_COST))
	return cost


static func get_spark_cost(action: String, context: Dictionary = {}) -> Dictionary:
	# Get cost for a Spark pole-shift: 1× the pole emoji being shifted toward.

	# spark_north → 1× north_emoji
	# spark_south → 1× south_emoji
	# Either pole: cost = surprisal of the target being driven (EnergyPricing
	# .drive_units via context.drive_units). Forcing an improbable pole costs more;
	# falls back to the flat SPARK_POLE_COST if no drive_units supplied.
	var normalized_action = normalize_action_id(action)
	if normalized_action == ActionIds.SPARK_NORTH:
		var north = str(context.get("north_emoji", ""))
		if north != "":
			return {north: int(context.get("drive_units", SPARK_POLE_COST))}
		return {}
	if normalized_action == ActionIds.SPARK_SOUTH:
		var south = str(context.get("south_emoji", ""))
		if south != "":
			return {south: int(context.get("drive_units", SPARK_POLE_COST))}
		return {}
	return {}


static func get_icon_removal_cost(north_emoji: String = "", south_emoji: String = "") -> Dictionary:
	# Get cost for removing a icon.

	# Base: 13 🐺 + 3 of each pole emoji (when known).
	var cost = {"🐺": ICON_REMOVAL_WOLF_COST}
	if north_emoji != "":
		cost[north_emoji] = ICON_REMOVAL_POLE_COST
	if south_emoji != "" and south_emoji != north_emoji:
		cost[south_emoji] = ICON_REMOVAL_POLE_COST
	return cost


static func can_afford(economy, costs: Dictionary) -> bool:
	# Check if economy can afford the given costs
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
	# Spend resources from economy. Returns true if successful.
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
	# Check affordability for a cost dictionary without spending.

	# Returns: {ok: bool, cost: Dictionary, message?: String}
	if costs.is_empty():
		return {"ok": true, "cost": costs}
	if not economy:
		return {"ok": false, "cost": costs, "message": "Economy not available"}
	if not can_afford(economy, costs):
		return {"ok": false, "cost": costs, "message": "Insufficient resources"}
	return {"ok": true, "cost": costs}


static func commit_cost(costs: Dictionary, economy, reason: String = "") -> bool:
	# Spend a preflighted cost dictionary.
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
	# Get cost dictionary for an action.

	# Args:
	# action: Action name (explore, measure, reap, discover_biome, inject_icon, lindblad_pump, lindblad_drain)
	# context: Optional context for dynamic costs (e.g., {south_emoji: "🌾"})

	# Returns:
	# Dictionary of {emoji: amount} costs
	#
	# Inventory costs are REAL in both systems — spending resources is the game (only the
	# QUANTUM state never depletes; it's unitary, r=1). The escape from the resource spiral
	# is the vocabulary-reward multiplier (knowing an icon boosts its harvest), not free
	# actions. Costs are tunable via the FarmVariableGraph board.
	var normalized_action = normalize_action_id(action)
	if normalized_action == ActionIds.INJECT_ICON:
		return get_icon_injection_cost(context.get("south_emoji", ""))
	if normalized_action == "remove_icon":
		# Always dynamic: get_icon_removal_cost("","") returns the base, context adds poles.
		return get_icon_removal_cost(context.get("north_emoji", ""), context.get("south_emoji", ""))
	if normalized_action in [ActionIds.LINDBLAD_PUMP, ActionIds.LINDBLAD_DRAIN]:
		return get_lindblad_injection_cost(normalized_action, context)
	if normalized_action in [ActionIds.SPARK_NORTH, ActionIds.SPARK_SOUTH]:
		return get_spark_cost(normalized_action, context)
	# Static costs are DATA — they live ONLY in the canonical FarmVariableGraph JSONL
	# (read via FarmEconomy.get_overridden_action_cost). This function returns only the
	# DYNAMIC/computed costs above; everything else is honestly {} here — no code-default
	# table fighting the JSONL.
	return {}


static func get_gate_cost(gate_name: String) -> Dictionary:
	# Get cost dictionary for a quantum gate.

	# Args:
	# gate_name: Gate name (pauli_x, pauli_y, pauli_z, hadamard, s_gate, t_gate, cnot, cz, swap)

	# Returns:
	# Dictionary of {emoji: amount} costs — gate costs are DATA, sourced ONLY from the
	# canonical JSONL via FarmEconomy.get_overridden_gate_cost. No code-default here.
	return {}


static func preflight_action(action: String, economy, context: Dictionary = {}) -> Dictionary:
	# Check affordability for an action without spending.
	var normalized_action = normalize_action_id(action)
	var cost: Dictionary
	if economy and economy.has_method("get_overridden_action_cost"):
		cost = economy.get_overridden_action_cost(normalized_action, context)
	else:
		cost = get_action_cost(normalized_action, context)
	return preflight_cost(cost, economy)


static func preflight_gate(gate_name: String, economy) -> Dictionary:
	# Check affordability for a quantum gate without spending.
	var cost: Dictionary
	if economy and economy.has_method("get_overridden_gate_cost"):
		cost = economy.get_overridden_gate_cost(gate_name)
	else:
		cost = get_gate_cost(gate_name)
	return preflight_cost(cost, economy)


static func commit_action(action: String, economy, context: Dictionary = {}, reason: String = "") -> bool:
	# Spend cost for an action after success.
	var normalized_action = normalize_action_id(action)
	var cost: Dictionary
	if economy and economy.has_method("get_overridden_action_cost"):
		cost = economy.get_overridden_action_cost(normalized_action, context)
	else:
		cost = get_action_cost(normalized_action, context)
	var spend_reason = reason if reason != "" else normalized_action
	return commit_cost(cost, economy, spend_reason)


static func commit_gate(gate_name: String, economy, reason: String = "") -> bool:
	# Spend cost for a quantum gate after success.
	var cost: Dictionary
	if economy and economy.has_method("get_overridden_gate_cost"):
		cost = economy.get_overridden_gate_cost(gate_name)
	else:
		cost = get_gate_cost(gate_name)
	var spend_reason = reason if reason != "" else gate_name
	return commit_cost(cost, economy, spend_reason)


static func normalize_action_id(action: String) -> String:
	return ActionIds.normalize_action(action)
