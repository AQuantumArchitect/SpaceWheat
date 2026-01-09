class_name FactionManager
extends Node

## FactionManager - Central hub for faction relationships and contracts
## Tracks reputation, manages contracts, handles faction interactions

# Preload dependencies
const Faction = preload("res://Core/GameMechanics/Faction.gd")
const FactionContract = preload("res://Core/GameMechanics/FactionContract.gd")

signal reputation_changed(faction_id: String, new_reputation: int, change: int)
signal contract_offered(contract: FactionContract)
signal contract_completed(contract: FactionContract, rewards: Dictionary)
signal contract_failed(contract: FactionContract, penalties: Dictionary)
signal faction_relationship_changed(faction_id: String, relationship: String)  # "allied", "neutral", "hostile"

# Faction database
var factions: Dictionary = {}  # faction_id -> Faction

# Reputation tracking
var reputation: Dictionary = {}  # faction_id -> int (reputation score)

# Contract management
var active_contracts: Array[FactionContract] = []
var completed_contracts: Array[FactionContract] = []
var available_contracts: Array[FactionContract] = []

# Contract generation settings
var contract_refresh_timer: float = 0.0
var contract_refresh_interval: float = 60.0  # Seconds between new contract offers

# Reputation thresholds for relationship status
const REP_HOSTILE_THRESHOLD = -50
const REP_NEUTRAL_THRESHOLD = 0
const REP_FRIENDLY_THRESHOLD = 50
const REP_ALLIED_THRESHOLD = 100


func _ready():
	# Initialize factions
	_initialize_factions()

	# Initialize reputation (all start at 0)
	for faction_id in factions.keys():
		reputation[faction_id] = 0

	# Generate initial starter contracts
	_generate_starter_contracts()

	print("🏛️ FactionManager initialized with %d factions" % factions.size())


func _process(delta):
	# Update active contracts
	for contract in active_contracts:
		contract.update(delta)

	# Refresh available contracts periodically
	contract_refresh_timer += delta
	if contract_refresh_timer >= contract_refresh_interval:
		contract_refresh_timer = 0.0
		_refresh_available_contracts()


## Faction initialization

func _initialize_factions():
	"""Load all factions into the system"""
	# Core factions (from Layer 1 implementation)
	factions["granary_guilds"] = Faction.create_granary_guilds()
	factions["yeast_prophets"] = Faction.create_yeast_prophets()
	factions["carrion_throne"] = Faction.create_carrion_throne()
	factions["house_of_thorns"] = Faction.create_house_of_thorns()
	factions["laughing_court"] = Faction.create_laughing_court()

	# TODO: Add remaining 27 factions from the 32-faction system


func get_faction(faction_id: String) -> Faction:
	"""Get faction by ID"""
	return factions.get(faction_id)


func get_all_factions() -> Array:
	"""Get all registered factions"""
	return factions.values()


## Reputation system

func get_reputation(faction_id: String) -> int:
	"""Get current reputation with a faction"""
	return reputation.get(faction_id, 0)


func add_reputation(faction_id: String, amount: int, reason: String = ""):
	"""Add (or subtract) reputation with a faction"""
	var current = get_reputation(faction_id)
	var new_reputation = current + amount

	reputation[faction_id] = new_reputation

	print("📊 Reputation with %s: %d → %d (%+d) [%s]" % [
		faction_id,
		current,
		new_reputation,
		amount,
		reason
	])

	reputation_changed.emit(faction_id, new_reputation, amount)

	# Check for relationship status changes
	_check_relationship_change(faction_id, current, new_reputation)

	# Handle cascade effects (allied/rival factions)
	_apply_reputation_cascade(faction_id, amount)


func get_relationship_status(faction_id: String) -> String:
	"""Get relationship status: hostile, neutral, friendly, or allied"""
	var rep = get_reputation(faction_id)

	if rep >= REP_ALLIED_THRESHOLD:
		return "allied"
	elif rep >= REP_FRIENDLY_THRESHOLD:
		return "friendly"
	elif rep >= REP_NEUTRAL_THRESHOLD:
		return "neutral"
	else:
		return "hostile"


func _check_relationship_change(faction_id: String, old_rep: int, new_rep: int):
	"""Check if relationship status changed and emit signal"""
	var old_status = _rep_to_status(old_rep)
	var new_status = _rep_to_status(new_rep)

	if old_status != new_status:
		print("🤝 Relationship with %s changed: %s → %s" % [faction_id, old_status, new_status])
		faction_relationship_changed.emit(faction_id, new_status)


func _rep_to_status(rep: int) -> String:
	"""Convert reputation value to status string"""
	if rep >= REP_ALLIED_THRESHOLD:
		return "allied"
	elif rep >= REP_FRIENDLY_THRESHOLD:
		return "friendly"
	elif rep >= REP_NEUTRAL_THRESHOLD:
		return "neutral"
	else:
		return "hostile"


func _apply_reputation_cascade(faction_id: String, amount: int):
	"""Apply reputation changes to allied/rival factions"""
	var faction = get_faction(faction_id)
	if not faction:
		return

	# Helping a faction's allies improves reputation with them (smaller amount)
	for ally_id in faction.allied_factions:
		if factions.has(ally_id):
			var cascade_amount = int(amount * 0.3)  # 30% of original change
			add_reputation(ally_id, cascade_amount, "allied with %s" % faction_id)

	# Helping a faction's rivals damages reputation with them
	for rival_id in faction.rival_factions:
		if factions.has(rival_id):
			var cascade_amount = int(amount * -0.5)  # -50% of original change
			add_reputation(rival_id, cascade_amount, "rival to %s" % faction_id)


## Contract system

func get_available_contracts() -> Array[FactionContract]:
	"""Get list of contracts player can accept"""
	return available_contracts


func get_active_contracts() -> Array[FactionContract]:
	"""Get list of contracts player is currently working on"""
	return active_contracts


func accept_contract(contract: FactionContract) -> bool:
	"""Accept an available contract"""
	if not available_contracts.has(contract):
		push_error("Contract not available")
		return false

	# Check if player meets requirements (reputation, etc.)
	var faction = get_faction(contract.faction_id)
	if not faction:
		push_error("Faction not found: %s" % contract.faction_id)
		return false

	# Check reputation requirement
	var min_rep = -50  # Hostile factions won't offer contracts
	if get_reputation(contract.faction_id) < min_rep:
		print("⚠️ Reputation too low with %s to accept contract" % contract.faction_id)
		return false

	# Accept contract
	available_contracts.erase(contract)
	active_contracts.append(contract)
	contract.activate()

	print("📜 Accepted contract: %s from %s" % [contract.contract_title, faction.faction_name])
	return true


func _auto_accept_contract(contract: FactionContract):
	"""Auto-accept a contract (used for generated contracts)"""
	if not contract:
		return

	# Add directly to active contracts (skip available_contracts queue)
	active_contracts.append(contract)
	contract.activate()

	var faction = get_faction(contract.faction_id)
	var faction_name = faction.faction_name if faction else contract.faction_id
	print("📜 Auto-accepted contract: %s from %s" % [contract.contract_title, faction_name])

	# Emit signal so UI can update
	contract_offered.emit(contract)


func check_contract_completion(contract: FactionContract, player_state: Dictionary) -> bool:
	"""Check if a contract is complete and handle rewards/penalties"""
	if not contract.is_active:
		return false

	if contract.evaluate_completion(player_state):
		_complete_contract(contract)
		return true
	else:
		return false


func _complete_contract(contract: FactionContract):
	"""Handle contract completion"""
	contract.complete()
	active_contracts.erase(contract)
	completed_contracts.append(contract)

	# Grant rewards
	var rewards = {
		"credits": contract.reward_credits,
		"reputation": contract.reward_reputation,
		"unlock": contract.reward_unlock
	}

	# Add reputation
	add_reputation(contract.faction_id, contract.reward_reputation, "contract completed")

	contract_completed.emit(contract, rewards)
	print("💰 Contract rewards: +%d credits, +%d reputation" % [rewards.credits, rewards.reputation])


func _fail_contract(contract: FactionContract):
	"""Handle contract failure"""
	contract.fail()
	active_contracts.erase(contract)

	# Apply penalties
	var penalties = {
		"credits": contract.penalty_credits,
		"reputation": contract.penalty_reputation,
		"icon_shift": contract.penalty_icon_shift
	}

	# Subtract reputation
	add_reputation(contract.faction_id, contract.penalty_reputation, "contract failed")

	contract_failed.emit(contract, penalties)


## Contract generation

func _generate_starter_contracts():
	"""Generate initial tutorial-level contracts (auto-accepted)"""
	# Granary Guilds starter contract
	var harvest_contract = FactionContract.create_starter_harvest_contract("granary_guilds")
	_auto_accept_contract(harvest_contract)

	# Yeast Prophets conspiracy research
	var conspiracy_contract = FactionContract.create_conspiracy_discovery_contract(
		"yeast_prophets",
		"mycelial_internet"
	)
	_auto_accept_contract(conspiracy_contract)

	# Carrion Throne quota
	var quota_contract = FactionContract.create_imperial_quota_contract("carrion_throne")
	_auto_accept_contract(quota_contract)

	print("📜 Generated and auto-accepted %d starter contracts" % active_contracts.size())


func _refresh_available_contracts():
	"""Generate new contracts based on faction relationships and player progress (auto-accepted)"""
	# Don't flood player with contracts
	if active_contracts.size() >= 5:
		return

	# Generate contracts from factions player has positive reputation with
	for faction_id in factions.keys():
		var faction = factions[faction_id]
		var rep = get_reputation(faction_id)

		# Chance to offer contract based on faction frequency and reputation
		var chance = faction.contract_frequency
		if rep >= REP_FRIENDLY_THRESHOLD:
			chance *= 2.0  # Friendly factions offer more contracts
		elif rep < REP_NEUTRAL_THRESHOLD:
			chance *= 0.3  # Hostile factions offer fewer

		if randf() < chance * 0.1:  # 10% base chance per refresh
			var contract = _generate_contract_for_faction(faction_id)
			if contract:
				_auto_accept_contract(contract)


func _generate_contract_for_faction(faction_id: String) -> FactionContract:
	"""Generate an appropriate contract for a specific faction"""
	var faction = get_faction(faction_id)
	if not faction:
		return null

	# Choose contract type based on faction archetype
	match faction.archetype:
		"guild", "imperial":
			# Guilds and imperials want harvest quotas
			if faction.enforces_purity:
				return FactionContract.create_purity_contract(faction_id)
			else:
				return FactionContract.create_starter_harvest_contract(faction_id)

		"mystic":
			# Mystics want conspiracy research
			var conspiracies = ["mycelial_internet", "observer_effect", "agricultural_enlightenment"]
			var random_conspiracy = conspiracies[randi() % conspiracies.size()]
			return FactionContract.create_conspiracy_discovery_contract(faction_id, random_conspiracy)

		"militant":
			# Militants want topological defense
			var jones_requirement = randf_range(5.0, 15.0)
			return FactionContract.create_topological_defense_contract(faction_id, jones_requirement)

		"horror":
			# Horror factions want chaos and sabotage
			return FactionContract.create_chaos_sabotage_contract(faction_id)

		_:
			# Default to harvest quota
			return FactionContract.create_starter_harvest_contract(faction_id)


## Player state helpers

func get_player_state_for_contract_evaluation(farm_view: Node) -> Dictionary:
	"""Build player state dictionary for contract evaluation"""
	var state = {}

	# Get wheat harvested from economy
	if farm_view.has_node("FarmEconomy") or farm_view.get("economy"):
		var economy = farm_view.get("economy")
		state["wheat_harvested"] = economy.total_wheat_harvested
	else:
		state["wheat_harvested"] = 0

	# Count active tomato plots in farm grid
	if farm_view.has_node("FarmGrid") or farm_view.get("farm_grid"):
		var farm_grid = farm_view.get("farm_grid")
		state["active_tomato_plots"] = _count_tomato_plots(farm_grid)

		# Get topology data from analyzer
		if farm_grid.get("topology_analyzer"):
			var analyzer = farm_grid.topology_analyzer
			state["current_jones_polynomial"] = analyzer.get_current_jones_polynomial()
			state["topological_protection_level"] = analyzer.get_current_protection_level()
		else:
			state["current_jones_polynomial"] = 0.0
			state["topological_protection_level"] = 0
	else:
		state["active_tomato_plots"] = 0
		state["current_jones_polynomial"] = 0.0
		state["topological_protection_level"] = 0

	# DEPRECATED: Conspiracy data (tomato conspiracy system removed)
	# if farm_view.has_node("TomatoConspiracyNetwork") or farm_view.get("conspiracy_network"):
	# 	var conspiracy_network = farm_view.get("conspiracy_network")
	# 	state["discovered_conspiracies"] = conspiracy_network.get_discovered_conspiracies() if conspiracy_network.has_method("get_discovered_conspiracies") else []
	# 	state["active_conspiracies_count"] = conspiracy_network.get_active_conspiracy_count() if conspiracy_network.has_method("get_active_conspiracy_count") else 0
	# else:
	state["discovered_conspiracies"] = []
	state["active_conspiracies_count"] = 0

	# Get Icon influence data
	if farm_view.get("chaos_icon"):
		var chaos_icon = farm_view.chaos_icon
		state["chaos_icon_influence"] = chaos_icon.active_strength
	else:
		state["chaos_icon_influence"] = 0.0

	return state


func _count_tomato_plots(farm_grid: Node) -> int:
	"""Count number of active tomato plots (for contamination checks)"""
	var tomato_count = 0

	# Check if farm_grid has the plots property
	if not "plots" in farm_grid:
		return 0

	var plots = farm_grid.plots
	for pos in plots:
		var plot = plots[pos]
		# Check if plot has has_tomato property
		if "has_tomato" in plot and plot.has_tomato:
			tomato_count += 1

	return tomato_count
