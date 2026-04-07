class_name FarmEconomy
extends Node

## Farm Economy - Unified Emoji-Credits System
## ALL resources are "emoji-credits" stored in a single dictionary
## Conversion rates defined in EconomyConstants.gd
## Example: 50 wheat = 500 🌾-credits

const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")
const QuestRewards = preload("res://Core/Quests/QuestRewards.gd")
const InstrumentLocator = preload("res://Core/Instrumentation/InstrumentLocator.gd")

@onready var _verbose = InstrumentLocator.resolve_verbose_config(self)

signal resource_changed(emoji: String, new_amount: int)
signal resource_mutated(emoji: String, delta: float, reason: String, new_amount: float)
signal purchase_failed(reason: String)

## Canonical emoji registry: see config/emoji_registry.json

var emoji_credits: Dictionary = {}
var total_wheat_harvested: int = 0
var imperium_icon = null
var resource_mutation_log: Array = []
var _economy_overrides: Dictionary = {}
var _balance_profile_id: String = "default"
var _economy_variables: Dictionary = {
	"quantum_to_credits": EconomyConstants.QUANTUM_TO_CREDITS,
	"max_biome_qubits": EconomyConstants.MAX_BIOME_QUBITS
}

const MAX_RESOURCE_MUTATION_LOG: int = 400


func _ready():
	if _verbose: _verbose.info("economy", "⚛️", "Emoji-Credits Economy ready (quantum mass = credits, 1:1 mapping)")


func _print_resources():
	var output = ""
	var q2c = _q2c()
	for emoji in emoji_credits:
		var quantum_units = emoji_credits[emoji] / q2c
		output += "%s: %d  " % [emoji, quantum_units]
	if _verbose: _verbose.debug("economy", "📊", output)


## ============================================================================
## UNIFIED API - Primary methods for all resource operations
## ============================================================================

func add_resource(emoji: String, credits_amount, reason: String = "") -> void:
	"""Add emoji-credits to any resource

	Note: Vocabulary bonus now applied in action phase (ProbeActions).
	This keeps bonus calculation transparent and trackable at the source.
	"""
	if not emoji_credits.has(emoji):
		emoji_credits[emoji] = 0

	# No multiplier here - bonuses applied in action phase
	var final_amount = int(credits_amount)

	emoji_credits[emoji] += final_amount
	_emit_resource_change(emoji)
	_record_resource_mutation(emoji, float(final_amount), reason)

	var quantum_units = final_amount / _q2c()
	if reason != "":
		if _verbose: _verbose.info("economy", "+", "%d %s-credits (%d units) from %s" % [final_amount, emoji, quantum_units, reason])


func _get_vocabulary_purity_multiplier(emoji: String) -> float:
	"""Get purity multiplier for vocabulary match.

	If emoji is in player's vocabulary: 2x multiplier, squared = 4.0x bonus
	Otherwise: 1.0x (no bonus, but still allowed)
	"""
	var gsm = InstrumentLocator.resolve_game_state_manager(self)
	if not gsm:
		return 1.0


	var is_in_vocabulary = false

	# Prefer centralized vocabulary resolution when available
	if gsm.has_method("get_player_vocab_emojis"):
		var known_emojis = gsm.get_player_vocab_emojis()
		is_in_vocabulary = emoji in known_emojis

	# Purity bonus: 2x before squaring = 4x total
	if is_in_vocabulary:
		return 2.0 * 2.0  # Squared multiplier
	else:
		return 1.0  # Always allow, just no bonus


func _resource_allowed_by_iconmap(emoji: String) -> bool:
	"""Only allow gains for emojis present in the current IconMap vocabulary."""
	var gsm = InstrumentLocator.resolve_game_state_manager(self)
	if not gsm or not gsm.has_method("get_active_farm"):
		return true
	var farm = gsm.get_active_farm()
	if not farm or not ("biome_evolution_batcher" in farm):
		return true
	var batcher = farm.biome_evolution_batcher
	if not batcher or not batcher.has_method("get_global_icon_map"):
		return true
	var icon_map = batcher.get_global_icon_map()
	if icon_map.is_empty():
		return true
	var by_emoji = icon_map.get("by_emoji", {})
	return by_emoji.has(emoji)
func remove_resource(emoji: String, credits_amount, reason: String = "") -> bool:
	"""Remove emoji-credits from a resource. Returns false if insufficient. Supports float amounts."""
	if not can_afford_resource(emoji, credits_amount):
		purchase_failed.emit("Not enough %s! Need %.2f, have %.2f" % [emoji, credits_amount, get_resource(emoji)])
		return false

	emoji_credits[emoji] -= credits_amount
	_emit_resource_change(emoji)
	_record_resource_mutation(emoji, -float(credits_amount), reason)

	var quantum_units = credits_amount / _q2c()
	if reason != "":
		if _verbose: _verbose.info("economy", "-", "%.2f %s-credits (%.2f units) for %s" % [credits_amount, emoji, quantum_units, reason])
	return true


func set_resource(emoji: String, credits_amount, reason: String = "") -> void:
	"""Set emoji-credits directly (bypasses gain gate). Supports float amounts."""
	if not emoji_credits.has(emoji):
		emoji_credits[emoji] = 0
	var before = float(emoji_credits[emoji])
	emoji_credits[emoji] = max(0, credits_amount)
	_emit_resource_change(emoji)
	_record_resource_mutation(emoji, float(emoji_credits[emoji]) - before, reason if reason != "" else "set_resource")
	if reason != "":
		if _verbose: _verbose.info("economy", "=", "%.2f %s-credits from %s" % [credits_amount, emoji, reason])


func get_resource(emoji: String):
	"""Get emoji-credits for any resource (supports float amounts)"""
	return emoji_credits.get(emoji, 0)


func get_resource_units(emoji: String) -> int:
	"""Get resource in quantum units (credits / 10)"""
	return get_resource(emoji) / _q2c()


func get_all_resources() -> Dictionary:
	"""Get all emoji-credits as dictionary. Returns copy to prevent mutation."""
	return emoji_credits.duplicate()


func can_afford_resource(emoji: String, credits_amount) -> bool:
	"""Check if player has enough emoji-credits (supports float amounts)"""
	return get_resource(emoji) >= credits_amount


func can_afford_cost(cost: Dictionary) -> bool:
	"""Check if player can afford a multi-resource cost

	cost format: {"🌾": 10, "👥": 5} meaning 10 wheat-credits + 5 labor-credits
	"""
	for emoji in cost.keys():
		if not can_afford_resource(emoji, cost[emoji]):
			return false
	return true


func spend_cost(cost: Dictionary, reason: String = "") -> bool:
	"""Spend a multi-resource cost. Atomic: all or nothing."""
	if not can_afford_cost(cost):
		var missing = _get_missing_resources(cost)
		purchase_failed.emit("Cannot afford: " + missing)
		return false

	for emoji in cost.keys():
		emoji_credits[emoji] -= cost[emoji]
		_emit_resource_change(emoji)
		_record_resource_mutation(emoji, -float(cost[emoji]), reason if reason != "" else "spend_cost")

	if reason != "":
		if _verbose: _verbose.info("economy", "💸", "Spent %s on %s" % [_format_cost(cost), reason])
	return true


func receive_pop_yield(emoji: String, quantum_energy: float, reason: String = "pop") -> int:
	"""Convert quantum energy from pop to emoji-credits

	1 quantum energy = 1 credit (direct mass mapping)
	Returns: number of credits added
	"""
	var credits_amount = int(quantum_energy * _q2c())
	add_resource(emoji, credits_amount, reason)
	return credits_amount


func _emit_resource_change(emoji: String) -> void:
	"""Emit universal resource_changed signal"""
	var amount = emoji_credits.get(emoji, 0)
	resource_changed.emit(emoji, amount)


func _record_resource_mutation(emoji: String, delta: float, reason: String) -> void:
	var new_amount = float(emoji_credits.get(emoji, 0))
	resource_mutated.emit(emoji, delta, reason, new_amount)
	var row = {
		"time_ms": Time.get_ticks_msec(),
		"emoji": emoji,
		"delta": delta,
		"reason": reason,
		"new_amount": new_amount,
	}
	resource_mutation_log.append(row)
	if resource_mutation_log.size() > MAX_RESOURCE_MUTATION_LOG:
		resource_mutation_log.pop_front()


func get_recent_resource_mutations(limit: int = 40) -> Array:
	var n = clampi(limit, 1, MAX_RESOURCE_MUTATION_LOG)
	var start = max(0, resource_mutation_log.size() - n)
	return resource_mutation_log.slice(start)


func _get_missing_resources(cost: Dictionary) -> String:
	var missing = []
	for emoji in cost.keys():
		var have = get_resource(emoji)
		var need = cost[emoji]
		if have < need:
			missing.append("%d more %s" % [(need - have) / _q2c(), emoji])
	return ", ".join(missing)


func _format_cost(cost: Dictionary) -> String:
	var parts = []
	for emoji in cost.keys():
		parts.append("%d %s" % [cost[emoji], emoji])
	return ", ".join(parts)


## ============================================================================
## ECONOMY OVERRIDES (from world state configs)
## ============================================================================

func apply_economy_overrides(config: Dictionary) -> Dictionary:
	"""Store economy overrides from a world state config.

	config may contain keys: action_costs, gate_costs, quest_rewards, production, economy_variables.
	Returns a summary of what was applied.
	"""
	_economy_overrides = config.duplicate(true)
	_balance_profile_id = str(_economy_overrides.get("profile_id", "default"))
	_economy_variables = {
		"quantum_to_credits": EconomyConstants.QUANTUM_TO_CREDITS,
		"max_biome_qubits": EconomyConstants.MAX_BIOME_QUBITS
	}
	var applied: Dictionary = {}
	for key in ["action_costs", "gate_costs", "quest_rewards", "production", "economy_variables"]:
		if _economy_overrides.has(key) and _economy_overrides[key] is Dictionary:
			applied[key] = _economy_overrides[key].size()
	var incoming_vars = _economy_overrides.get("economy_variables", {})
	if incoming_vars is Dictionary and not incoming_vars.is_empty():
		_economy_variables = _economy_variables.duplicate(true)
		for key in incoming_vars.keys():
			_economy_variables[str(key)] = incoming_vars[key]

	var quest_tuning = _economy_overrides.get("quest_rewards", {})
	if quest_tuning is Dictionary:
		QuestRewards.set_reward_tuning_overrides(quest_tuning)
	else:
		QuestRewards.reset_reward_tuning()
	if _verbose:
		_verbose.info("economy", "⚙", "Economy overrides applied: %s (profile=%s)" % [str(applied), _balance_profile_id])
	return applied


func get_economy_overrides() -> Dictionary:
	return _economy_overrides


func get_balance_profile_id() -> String:
	return _balance_profile_id


func get_economy_variables() -> Dictionary:
	return _economy_variables.duplicate(true)


func get_economy_variable(name: String, default_value = null):
	if _economy_variables.has(name):
		return _economy_variables[name]
	return default_value


func get_overridden_action_cost(action: String, context: Dictionary = {}) -> Dictionary:
	"""Get action cost, checking overrides first, then EconomyConstants."""
	var normalized_action = EconomyConstants.normalize_action_id(action)
	var overrides = _economy_overrides.get("action_costs", {})
	if overrides is Dictionary and overrides.has(normalized_action):
		var cost = overrides[normalized_action]
		if cost is Dictionary:
			return cost
	return EconomyConstants.get_action_cost(normalized_action, context)


func get_overridden_gate_cost(gate_name: String) -> Dictionary:
	"""Get gate cost, checking overrides first, then EconomyConstants."""
	var overrides = _economy_overrides.get("gate_costs", {})
	if overrides is Dictionary and overrides.has(gate_name):
		var cost = overrides[gate_name]
		if cost is Dictionary:
			return cost
	return EconomyConstants.get_gate_cost(gate_name)


func get_action_cost(action: String, context: Dictionary = {}) -> Dictionary:
	"""Canonical runtime action-cost lookup (overrides + defaults)."""
	return get_overridden_action_cost(action, context)


func get_gate_cost(gate_name: String) -> Dictionary:
	"""Canonical runtime gate-cost lookup (overrides + defaults)."""
	return get_overridden_gate_cost(gate_name)


func preflight_action(action: String, context: Dictionary = {}) -> Dictionary:
	"""Affordability check for an action using effective runtime costs."""
	return EconomyConstants.preflight_cost(get_action_cost(action, context), self)


func commit_action(action: String, context: Dictionary = {}, reason: String = "") -> bool:
	"""Spend action cost using effective runtime costs."""
	var normalized_action = EconomyConstants.normalize_action_id(action)
	var spend_reason = reason if reason != "" else normalized_action
	return EconomyConstants.commit_cost(get_action_cost(normalized_action, context), self, spend_reason)


func preflight_gate(gate_name: String) -> Dictionary:
	"""Affordability check for a gate using effective runtime costs."""
	return EconomyConstants.preflight_cost(get_gate_cost(gate_name), self)


func commit_gate(gate_name: String, reason: String = "") -> bool:
	"""Spend gate cost using effective runtime costs."""
	var spend_reason = reason if reason != "" else gate_name
	return EconomyConstants.commit_cost(get_gate_cost(gate_name), self, spend_reason)


func preflight_cost(cost: Dictionary) -> Dictionary:
	"""Affordability check for an arbitrary cost dictionary."""
	return EconomyConstants.preflight_cost(cost, self)


func commit_cost(cost: Dictionary, reason: String = "") -> bool:
	"""Spend an arbitrary cost dictionary."""
	return EconomyConstants.commit_cost(cost, self, reason)


func get_max_biome_qubits() -> int:
	return int(get_economy_variable("max_biome_qubits", EconomyConstants.MAX_BIOME_QUBITS))


func get_quantum_to_credits_value() -> float:
	return float(get_economy_variable("quantum_to_credits", EconomyConstants.QUANTUM_TO_CREDITS))


## ============================================================================
## QUOTA SYSTEM
## ============================================================================

func can_fulfill_quota(wheat_required: int) -> bool:
	return get_resource_units("🌾") >= wheat_required

func fulfill_quota(wheat_required: int) -> bool:
	if not can_fulfill_quota(wheat_required):
		return false
	return remove_resource("🌾", wheat_required * _q2c(), "quota")


## ============================================================================
## STATS
## ============================================================================

func get_stats() -> Dictionary:
	"""Get economic statistics"""
	return {
		# Statistics
		"total_wheat_harvested": total_wheat_harvested,
		# All resources as emoji-credits
		"emoji_credits": emoji_credits.duplicate()
	}


func reset_harvest_counter():
	"""Reset harvest counter (called when contract completes)"""
	total_wheat_harvested = 0
	if _verbose: _verbose.debug("economy", "📊", "Harvest counter reset")


func print_stats():
	"""Debug: Print economic stats (uses if _verbose: _verbose.debug)"""
	if _verbose: _verbose.debug("economy", "📊", "=== FARM ECONOMY (Emoji-Credits) ===")
	for emoji in emoji_credits:
		var credits_val = emoji_credits[emoji]
		var units = credits_val / _q2c()
		if _verbose: _verbose.debug("economy", "  ", "%s: %d units (%d credits)" % [emoji, units, credits_val])
	if _verbose: _verbose.debug("economy", "📊", "Total wheat harvested: %d" % total_wheat_harvested)


func _q2c() -> float:
	return get_quantum_to_credits_value()
