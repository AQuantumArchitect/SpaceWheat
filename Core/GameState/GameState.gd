class_name GameState
extends Resource

## Game State - Complete snapshot of game state for save/load
## Refactored for Farm/Biome/Qubit architecture
## All game state must be serializable (no Node references!)
##
## PERSISTED:
##  - Economy: All resource inventories, tribute counts
##  - Plots: Position, type, planted state, measurement state, entanglement
##  - Goals: Progress and completion
##  - Icons: Activation levels
##  - Time: Biome elapsed time + sun/moon phase
##  - Quantum state: Complete biome_state tree (sun qubit, icons, emoji qubits)
##
## NOT PERSISTED (regenerated each load):
##  - Conspiracy network (dynamic)
##  - UI/visual state

## Meta
@export var scenario_id: String = "default"
@export var save_timestamp: int = 0  # Unix timestamp
@export var game_time: float = 0.0  # Total playtime
@export var quantum_time_scale: float = 0.03125  # Simulation speed multiplier (0.001-16.0) - Start 4x slower for observation
@export var observation_stride: int = 1  # Observation stride (0=locked, 1=normal, 2+=fast forward)
@export var max_evolution_dt: float = 0.02  # Euler substep size for Lindblad evolution (resolution)
@export var save_version: int = 1  # Phase 4: Save format version (increment when format changes)
@export var advanced_mode_enabled: bool = false  # Enables advanced workbench controls in UI/tools

## Grid Dimensions (for variable-sized farms)
@export var grid_width: int = 0
@export var grid_height: int = 0

## Economy - Complete emoji credits dictionary (saves ALL resources)
## Format: {"emoji": credits_amount, ...}
@export var all_emoji_credits: Dictionary = {}
@export var tributes_paid: int = 0
@export var tributes_failed: int = 0

## Known Pairs - persisted copy of player vocabulary (canonical in Farm)
## Each pair is {north: String, south: String}
## These are the actual plantable qubit axes the player has learned
## Starter pair: 🌾/👥 (wheat/people - the farming foundation)
@export var known_pairs: Array = [
	{"north": "🌾", "south": "👥"}
]

## DERIVED: known_emojis is computed from known_pairs (for backward compatibility)
## Use get_known_emojis() to access the derived list
## This field is still exported for save file compatibility with old saves
@export var known_emojis: Array = []

## Player Vocabulary Quantum Computer data (for biome affinity calculations)
## Serialized data from PlayerVocabulary autoload
@export var player_vocab_data: Dictionary = {}

## IconMap Snapshot (tooling cache; NOT canonical gameplay authority)
## Allows bash/automation to read a compact emoji-weight view without parsing runtime state.
## Structure:
## {
##   "by_emoji": {"🌾": 1.0, "👥": 0.5, ...},
##   "total": float,
##   "steps": int
## }
@export var icon_map_snapshot: Dictionary = {}
@export var icon_map_snapshot_source: String = ""  # "batcher_global" | "derived_from_pairs"
@export var icon_map_snapshot_time: int = 0

## Balance profile state (shared between headless and UI)
@export var balance_profile_id: String = "default"
@export var balance_overrides: Dictionary = {}
@export var balance_workbench_config: Dictionary = {}
@export var economy_variables: Dictionary = {
	"quantum_to_credits": 1.0,
	"max_biome_qubits": 12
}
@export var reap_count: int = 0

## Unlocked Biomes - Start with StarterForest and Village, unlock more through exploration
@export var unlocked_biomes: Array[String] = ["StarterForest", "Village"]

## Pool of unexplored biomes (assigned to UIOP slots dynamically)
## These are available but not yet assigned to keyboard slots
@export var unexplored_biome_pool: Array[String] = ["BioticFlux", "StellarForges", "FungalNetworks", "VolcanicWorlds"]

## Active biome in the observation spindle when save was captured
@export var active_biome_name: String = "StarterForest"

## Selection State (player's configured multi-select for batch operations)
## Array of Vector2i positions of selected/checked plots
## Allows saving complex selection configurations before executing actions
@export var selected_plot_positions: Array = []  # Array of Vector2i


## Get known emojis (derived from known_pairs)
## This is the canonical way to get the player's vocabulary
func get_known_emojis() -> Array:
	var emojis = []
	for pair in known_pairs:
		var north = pair.get("north", "")
		var south = pair.get("south", "")
		if north and north not in emojis:
			emojis.append(north)
		if south and south not in emojis:
			emojis.append(south)
	return emojis


## Get the pair containing a given emoji (returns null if not found)
func get_pair_for_emoji(emoji: String) -> Variant:
	for pair in known_pairs:
		if pair.get("north", "") == emoji or pair.get("south", "") == emoji:
			return pair
	return null

## Quest Board - Multi-Page Memory System
@export var quest_pages: Dictionary = {}
# Structure: {
#   0: [slot0_dict, slot1_dict, slot2_dict, slot3_dict],
#   1: [slot0_dict, slot1_dict, slot2_dict, slot3_dict],
#   ...
# }
# Each slot_dict: {quest_id, offered_quest, faction, is_locked, state}

@export var quest_board_current_page: int = 0

## DEPRECATED: Old single-page storage (kept for migration)
@export var quest_slots: Array = [null, null, null, null]
# Each slot dictionary contains:
#   quest_id: int - ID of active quest (if active)
#   offered_quest: Dictionary - Quest data (if offered but not accepted)
#   is_locked: bool - Locked slot won't auto-refresh
#   state: int - SlotState enum (EMPTY=0, OFFERED=1, ACTIVE=2, READY=3, LOCKED=4)

## Plots - Array of serialized plot states (from FarmGrid)
@export var plots: Array[Dictionary] = []
# Each plot dictionary contains:
#   position: Vector2i - Grid coordinates (x, y)
#   type_name: String - plot type ("wheat", "mushroom", "energy_tap", etc.)
#   is_planted: bool - Currently has an active crop
#   has_been_measured: bool - Quantum state has been collapsed
#   theta_frozen: bool - Measurement locked the theta value (stops Hamiltonian drift)
#   entangled_with: Array[Vector2i] - Positions of entangled plots (bidirectional)
#   persistent_gates: Array[Dictionary] - Persistent gate infrastructure (survives harvest)
#       Each gate: {type: String, active: bool, linked_plots: Array[Vector2i]}
#       Types: "bell_phi_plus", "cluster", "measure_trigger"
#
# NOTE: Quantum state details (theta, phi, radius, energy, berry_phase) are NOT persisted.
#       They regenerate when plots are planted from the biome environment.
#       This avoids serialization complexity while maintaining deterministic behavior.

## Icons
@export var biotic_activation: float = 0.0
@export var chaos_activation: float = 0.0
@export var imperium_activation: float = 0.0

## Contracts
@export var active_contracts: Array[Dictionary] = []
# Each contract: {title, description, reward, requirements, faction}

## Phase 2: Multi-Biome Architecture
## Each biome has its own quantum state, independent evolution
@export var biome_states: Dictionary = {}
# Structure: biome_name → biome_state_dict
# {
#   "BioticFlux": {
#     "time_elapsed": float,
#     "sun_qubit": {theta, phi, radius, energy},
#     "wheat_icon": {theta, phi, radius, energy},
#     "mushroom_icon": {theta, phi, radius, energy},
#     "quantum_states": [{position, theta, phi, radius, energy, north_emoji, south_emoji}, ...],
#
#     # Phase 5.1: Gate infrastructure (entanglement gates persist across saves)
#     "bell_gates": [[Vector2i, ...], ...],  # Array of position arrays (pairs, triplets, clusters)
#     # Example: [[Vector2i(0,0), Vector2i(1,0)], [Vector2i(2,0), Vector2i(3,0), Vector2i(4,0)]]
#     # First is a pair gate, second is a triplet gate
#
#     # Phase 3: Bath-first mode support
#     "use_bath_mode": bool,  # True if biome uses QuantumBath
#     "bath_state": {  # Only if use_bath_mode=true
#       "emojis": [String, ...],  # Emoji basis
#       "amplitudes": {"emoji": {real: float, imag: float}, ...},
#       "bath_time": float
#     },
#     "active_projections": [  # Only if use_bath_mode=true
#       {"position": Vector2i, "north": String, "south": String},
#       ...
#     ]
#   },
#   "Market": {...},
#   "Forest": {...},
#   "Kitchen": {...}
# }

## Phase 2: Plot-to-Biome Assignments
## Maps each plot position to its assigned biome
@export var plot_biome_assignments: Dictionary = {}
# Structure: String(Vector2i) → biome_name
# Example: "(0, 0)" → "Market", "(2, 0)" → "BioticFlux"

## Vocabulary Evolution State (NEW - PERSISTED)
## Complete state snapshot from VocabularyEvolution.serialize()
@export var vocabulary_state: Dictionary = {}
# Structure:
# {
#   "discovered_vocabulary": [...],
#   "evolving_qubits": [...],
#   "parameters": {mutation_pressure, max_qubits, cannibalism_threshold, maturity_threshold},
#   "statistics": {total_spawned, total_cannibalized, time_elapsed}
# }


func _init():
	# Initialize with default values
	scenario_id = "default"
	save_timestamp = Time.get_unix_time_from_system()
	game_time = 0.0

	# Initialize empty plot grid (default 6x1, customizable per farm)
	plots.clear()
	for y in range(grid_height):
		for x in range(grid_width):
			plots.append({
				"position": Vector2i(x, y),
				"type_name": "wheat",
				"is_planted": false,
				"has_been_measured": false,
				"theta_frozen": false,
				"entangled_with": [],
				"persistent_gates": [],
				"lindblad_pump_active": false,
				"lindblad_drain_active": false,
				"lindblad_pump_rate": 0.5,
				"lindblad_drain_rate": 0.5
			})

	# Initialize typed arrays properly (Godot 4 requirement)
	active_contracts.clear()

	# Player vocabulary is initialized in the @export default above
	# 🌾 (Wheat) and 👥 (People) are the starter emojis
	# These match faction signatures and seed initial faction conversations
	ensure_balance_workbench_defaults()


## Convenience method to create state for a specific grid size
static func create_for_grid(width: int, height: int):
	var resource = Resource.new()
	resource.set_script(load("res://Core/GameState/GameState.gd"))
	var state = resource as GameState
	state.grid_width = width
	state.grid_height = height

	# Reinitialize plots for the given grid size
	state.plots.clear()
	for y in range(height):
		for x in range(width):
			state.plots.append({
				"position": Vector2i(x, y),
				"type_name": "wheat",
				"is_planted": false,
				"has_been_measured": false,
				"theta_frozen": false,
				"entangled_with": [],
				"persistent_gates": [],
				"lindblad_pump_active": false,
				"lindblad_drain_active": false,
				"lindblad_pump_rate": 0.5,
				"lindblad_drain_rate": 0.5
			})

	return state


func get_save_display_name() -> String:
	"""Get human-readable save name"""
	var time = Time.get_datetime_dict_from_unix_time(save_timestamp)
	return "%02d/%02d/%04d %02d:%02d" % [
		time.month, time.day, time.year,
		time.hour, time.minute
	]


func ensure_balance_workbench_defaults() -> void:
	var defaults = _default_balance_workbench_config()
	if not (balance_workbench_config is Dictionary):
		balance_workbench_config = {}
	if balance_workbench_config.is_empty():
		balance_workbench_config = defaults
	else:
		if not balance_workbench_config.has("profile_id"):
			balance_workbench_config["profile_id"] = defaults.get("profile_id", "default")
		if not balance_workbench_config.has("display_name"):
			balance_workbench_config["display_name"] = defaults.get("display_name", "Default Runtime Balance")
		var tuning = balance_workbench_config.get("tuning", {})
		if not (tuning is Dictionary):
			tuning = {}
		for key in defaults.get("tuning", {}).keys():
			if not tuning.has(key):
				tuning[key] = defaults["tuning"][key]
		balance_workbench_config["tuning"] = tuning
		var roi_notes = balance_workbench_config.get("action_roi_notes", {})
		if not (roi_notes is Dictionary):
			roi_notes = {}
		for key in defaults.get("action_roi_notes", {}).keys():
			if not roi_notes.has(key):
				roi_notes[key] = defaults["action_roi_notes"][key]
		balance_workbench_config["action_roi_notes"] = roi_notes
		var quest_notes = balance_workbench_config.get("quest_reward_notes", {})
		if not (quest_notes is Dictionary):
			quest_notes = {}
		for key in defaults.get("quest_reward_notes", {}).keys():
			if not quest_notes.has(key):
				quest_notes[key] = defaults["quest_reward_notes"][key]
		balance_workbench_config["quest_reward_notes"] = quest_notes

	if balance_profile_id == "":
		balance_profile_id = str(balance_workbench_config.get("profile_id", "default"))
	if not (balance_overrides is Dictionary):
		balance_overrides = {}
	if not (economy_variables is Dictionary):
		economy_variables = {}
	for key in ["quantum_to_credits", "max_biome_qubits"]:
		if not economy_variables.has(key):
			economy_variables[key] = defaults.get("economy_variables", {}).get(key, 1.0 if key == "quantum_to_credits" else 12)


func _default_balance_workbench_config() -> Dictionary:
	return {
		"profile_id": "default",
		"display_name": "Default Runtime Balance",
		"tuning": {
			"pop_base_yield_scale": 100.0,
			"reap_base_yield": 50.0,
			"reap_evolution_cycles": 13,
			"flux_to_credits": 1.0,
			"reap_cost_sequence": [1, 1, 2, 3, 5, 8, 13, 21],
			"reap_starting_tokens": 6
		},
		"economy_variables": {
			"quantum_to_credits": 1.0,
			"max_biome_qubits": 12
		},
		"action_roi_notes": {
			"explore": "Unlocks one terminal cycle; prerequisite for measure/pop.",
			"measure": "Collapses state and unlocks deterministic harvest paths.",
			"pop": "Single terminal payoff from measured outcome, driven by icon-map mass and purity.",
			"reap": "Season change: fast-forward, collect sink flux, and broad harvest across active biomes.",
			"harvest_all": "Legacy alias path for reap.",
			"explore_biome": "Long-term expansion unlock; increases future terminal surface area.",
			"inject_vocabulary": "Converts known pairs into biome terminals and new learning options.",
			"remove_vocabulary": "Emergency rollback action; expensive by design.",
			"lindblad_pump": "Raises local population/energy; setup cost for stronger harvest curves.",
			"lindblad_drain": "Removes unstable population; useful for stabilizing noisy plots.",
			"quest_reroll": "Short-horizon quest quality control.",
			"quest_lock": "Preserves high-value quest offers for later claim timing."
		},
		"quest_reward_notes": {
			"resource_reward_base_ratio": "Global scaler on quest resource payout budget.",
			"resource_reward_min_total": "Lower clamp for total payout.",
			"resource_reward_max_total": "Upper clamp for total payout.",
			"resource_reward_min_per_emoji": "Floor per resource emoji in split payouts."
		}
	}
