class_name FactionContract
extends Resource

## FactionContract - Represents a quest/contract from a faction
## Players complete contracts to earn rewards and reputation

# Contract identity
@export var contract_id: String = ""
@export var faction_id: String = ""  # Which faction issued this contract
@export var contract_title: String = ""
@export var contract_description: String = ""

# Contract type determines evaluation logic
@export var contract_type: String = "harvest_quota"  # Types: harvest_quota, conspiracy_research, topological_defense, purity_delivery, chaos_containment

# Requirements (what player must do)
@export var requirements: Dictionary = {}
# Examples:
# harvest_quota: {"wheat_amount": 50, "allow_tomato_contamination": false}
# conspiracy_research: {"conspiracy_name": "mycelial_internet"}
# topological_defense: {"min_jones_polynomial": 15.0}
# purity_delivery: {"wheat_amount": 20, "max_chaos_influence": 0.1}

# Rewards (what player gets on success)
@export var reward_credits: int = 0
@export var reward_reputation: int = 10
@export var reward_unlock: String = ""  # Unlocks special items/proofs/biomes

# Penalties (what happens on failure)
@export var penalty_credits: int = 0
@export var penalty_reputation: int = -5
@export var penalty_icon_shift: Dictionary = {}  # e.g., {"chaos": +0.2}

# Contract state
@export var is_active: bool = false
@export var is_completed: bool = false
@export var is_failed: bool = false
@export var time_limit: float = -1.0  # Seconds, -1 = no limit
@export var time_remaining: float = -1.0

# Difficulty rating
@export var difficulty: int = 1  # 1-5 scale


func _init(id: String = ""):
	contract_id = id if id != "" else _generate_contract_id()


static func _generate_contract_id() -> String:
	"""Generate unique contract ID"""
	return "contract_%d" % Time.get_ticks_msec()


## Contract evaluation methods

func evaluate_completion(player_state: Dictionary) -> bool:
	"""Check if player has completed contract requirements"""
	match contract_type:
		"harvest_quota":
			return _evaluate_harvest_quota(player_state)
		"conspiracy_research":
			return _evaluate_conspiracy_research(player_state)
		"topological_defense":
			return _evaluate_topological_defense(player_state)
		"purity_delivery":
			return _evaluate_purity_delivery(player_state)
		"chaos_containment":
			return _evaluate_chaos_containment(player_state)
		_:
			push_error("Unknown contract type: %s" % contract_type)
			return false


func _evaluate_harvest_quota(player_state: Dictionary) -> bool:
	"""Evaluate harvest quota contracts"""
	var required_amount = requirements.get("wheat_amount", 0)
	var harvested = player_state.get("wheat_harvested", 0)
	var allow_contamination = requirements.get("allow_tomato_contamination", true)

	if harvested < required_amount:
		return false

	if not allow_contamination:
		var tomato_plots = player_state.get("active_tomato_plots", 0)
		if tomato_plots > 0:
			return false  # Contamination detected!

	return true


func _evaluate_conspiracy_research(player_state: Dictionary) -> bool:
	"""Evaluate conspiracy discovery contracts"""
	var required_conspiracy = requirements.get("conspiracy_name", "")
	var discovered = player_state.get("discovered_conspiracies", [])
	return discovered.has(required_conspiracy)


func _evaluate_topological_defense(player_state: Dictionary) -> bool:
	"""Evaluate topological knot-building contracts"""
	var min_jones = requirements.get("min_jones_polynomial", 0.0)
	var current_jones = player_state.get("current_jones_polynomial", 0.0)
	return current_jones >= min_jones


func _evaluate_purity_delivery(player_state: Dictionary) -> bool:
	"""Evaluate contracts requiring pure wheat with low chaos"""
	var required_wheat = requirements.get("wheat_amount", 0)
	var max_chaos = requirements.get("max_chaos_influence", 0.5)

	var harvested = player_state.get("wheat_harvested", 0)
	var chaos_influence = player_state.get("chaos_icon_influence", 0.0)

	return harvested >= required_wheat and chaos_influence <= max_chaos


func _evaluate_chaos_containment(player_state: Dictionary) -> bool:
	"""Evaluate contracts requiring containment of chaos outbreaks"""
	var max_active_conspiracies = requirements.get("max_active_conspiracies", 3)
	var min_protection = requirements.get("min_topological_protection", 5)

	var active_conspiracies = player_state.get("active_conspiracies_count", 0)
	var protection = player_state.get("topological_protection_level", 0)

	return active_conspiracies <= max_active_conspiracies and protection >= min_protection


## Contract lifecycle

func activate():
	"""Start the contract"""
	is_active = true
	is_completed = false
	is_failed = false
	if time_limit > 0:
		time_remaining = time_limit
	print("📜 Contract activated: %s" % contract_title)


func complete():
	"""Mark contract as successfully completed"""
	is_active = false
	is_completed = true
	is_failed = false
	print("✅ Contract completed: %s (+%d credits, +%d rep)" % [contract_title, reward_credits, reward_reputation])


func fail():
	"""Mark contract as failed"""
	is_active = false
	is_completed = false
	is_failed = true
	print("❌ Contract failed: %s (-%d credits, -%d rep)" % [contract_title, penalty_credits, abs(penalty_reputation)])


func update(delta: float):
	"""Update contract state (for timed contracts)"""
	if is_active and time_limit > 0:
		time_remaining -= delta
		if time_remaining <= 0:
			fail()


## Contract factory methods

static func create_starter_harvest_contract(faction_id: String) -> FactionContract:
	"""Create a simple harvest quota contract (tutorial level)"""
	var contract = new()
	contract.faction_id = faction_id
	contract.contract_title = "Basic Wheat Delivery"
	contract.contract_description = "Deliver 20 units of wheat. Simple and straightforward."
	contract.contract_type = "harvest_quota"
	contract.requirements = {
		"wheat_amount": 20,
		"allow_tomato_contamination": true
	}
	contract.reward_credits = 100
	contract.reward_reputation = 15
	contract.difficulty = 1
	return contract


static func create_purity_contract(faction_id: String) -> FactionContract:
	"""Create a contract requiring pure wheat (no tomatoes)"""
	var contract = new()
	contract.faction_id = faction_id
	contract.contract_title = "Pure Wheat Delivery"
	contract.contract_description = "Deliver 50 units of PURE wheat. NO tomato contamination allowed! The Granary Guilds demand quality."
	contract.contract_type = "harvest_quota"
	contract.requirements = {
		"wheat_amount": 50,
		"allow_tomato_contamination": false
	}
	contract.reward_credits = 200
	contract.reward_reputation = 25
	contract.reward_unlock = "deterministic_growth_modifier"
	contract.penalty_reputation = -20
	contract.difficulty = 2
	return contract


static func create_conspiracy_discovery_contract(faction_id: String, conspiracy_name: String) -> FactionContract:
	"""Create a contract requiring conspiracy discovery"""
	var contract = new()
	contract.faction_id = faction_id
	contract.contract_title = "Conspiracy Research: %s" % conspiracy_name.capitalize()
	contract.contract_description = "Discover the '%s' conspiracy through experimentation. The Yeast Prophets believe chaos holds wisdom." % conspiracy_name
	contract.contract_type = "conspiracy_research"
	contract.requirements = {
		"conspiracy_name": conspiracy_name
	}
	contract.reward_credits = 150
	contract.reward_reputation = 20
	contract.reward_unlock = "fermentation_proof_sequence"
	contract.difficulty = 3
	return contract


static func create_topological_defense_contract(faction_id: String, min_jones: float) -> FactionContract:
	"""Create a contract requiring topological knot construction"""
	var contract = new()
	contract.faction_id = faction_id
	contract.contract_title = "Construct Topological Defense"
	contract.contract_description = "Build an entanglement network with Jones polynomial ≥ %.1f to protect against chaos outbreaks." % min_jones
	contract.contract_type = "topological_defense"
	contract.requirements = {
		"min_jones_polynomial": min_jones
	}
	contract.reward_credits = 300
	contract.reward_reputation = 30
	contract.reward_unlock = "knot_architect_achievement"
	contract.difficulty = 4
	return contract


static func create_chaos_sabotage_contract(faction_id: String) -> FactionContract:
	"""Create a contract requiring sabotage through chaos (from House of Thorns)"""
	var contract = new()
	contract.faction_id = faction_id
	contract.contract_title = "Subtle Sabotage"
	contract.contract_description = "Activate conspiracies to disrupt Carrion Throne wheat shipments. Maintain plausible deniability (Chaos influence < 70%)."
	contract.contract_type = "chaos_containment"
	contract.requirements = {
		"max_active_conspiracies": 10,  # Must have many conspiracies
		"min_topological_protection": 3  # But must contain them
	}
	contract.reward_credits = 500
	contract.reward_reputation = 40
	contract.reward_unlock = "subtle_poison_tomato"
	contract.penalty_reputation = -50  # If caught, huge penalty
	contract.penalty_icon_shift = {"imperium": 0.3}  # Imperium becomes hostile
	contract.difficulty = 5
	return contract


static func create_imperial_quota_contract(faction_id: String) -> FactionContract:
	"""Create a standard Carrion Throne quota contract"""
	var contract = new()
	contract.faction_id = faction_id
	contract.contract_title = "Imperial Wheat Quota"
	contract.contract_description = "The Carrion Throne demands 100 units of wheat within 300 seconds. Failure is... discouraged."
	contract.contract_type = "purity_delivery"
	contract.requirements = {
		"wheat_amount": 100,
		"max_chaos_influence": 0.2
	}
	contract.reward_credits = 400
	contract.reward_reputation = 35
	contract.penalty_credits = 100  # They fine you for failure
	contract.penalty_reputation = -30
	contract.time_limit = 300.0  # 5 minutes
	contract.difficulty = 3
	return contract
