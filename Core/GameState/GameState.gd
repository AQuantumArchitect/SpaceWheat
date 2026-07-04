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
@export var scenario_id: String = "new_game_easy"
@export var save_timestamp: int = 0  # Unix timestamp
@export var game_time: float = 0.0  # Total playtime
@export var quantum_time_scale: float = 0.5  # Simulation speed multiplier (0.001-16.0) - Half real-time so day/night cycle is ~50s
@export var observation_stride: int = 1  # Observation stride (0=locked, 1=normal, 2+=fast forward)
# max_evolution_dt removed — derived from BiomeCharacteristics continuity sweep, not player state
@export var save_version: int = 3  # v3 (Phase III): adds player_alignment (12-qubit AlignmentGraph); v1/v2 reinitialize the substrate to |+⟩^⊗12
@export var advanced_mode_enabled: bool = false  # Enables advanced workbench controls in UI/tools

## Grid Dimensions (for variable-sized farms)
@export var grid_width: int = 0
@export var grid_height: int = 0

## Economy - Complete emoji credits dictionary (saves ALL resources)
## Format: {"emoji": credits_amount, ...}
@export var all_emoji_credits: Dictionary = {}
@export var tributes_paid: int = 0
@export var tributes_failed: int = 0

## Known Icons - persisted copy of the player's signature (canonical in Farm)
## Each icon is {north: String, south: String}
## These are the actual plantable qubit axes the player has learned
## Starter icon: 🌾/👥 (wheat/people - the farming foundation)
@export var known_icons: Array = [
	{"north": "🌾", "south": "👥"}
]

## Active icon slots — 3 indices into known_icons. The player faction's active
## expression voice. Defaults to [0,1,2]; clamped to known_icons size on load.
## Tunable via Z surface Self tab icon picker.
@export var active_icon_slots: Array = [0, 1, 2]

## DERIVED: known_emojis is computed from known_icons.
## Live code should not write this field directly. Use get_known_emojis() for reads.
@export var known_emojis: Array = []

## IconMap Snapshot (tooling cache; NOT canonical gameplay authority)
## Allows bash/automation to read a compact emoji-weight view without parsing runtime state.
## Structure:
## {
##   "by_emoji": {"🌾": 1.0, "👥": 0.5, ...},
##   "total": float,
##   "steps": int
## }
@export var atom_map_snapshot: Dictionary = {}
@export var atom_map_snapshot_source: String = ""  # "batcher_global" | "derived_from_icons"
@export var atom_map_snapshot_time: int = 0

## Runtime controller policy state (headless/UI automation brain memory)
@export var policy_state: Dictionary = {}
@export var policy_graph_path: String = "res://Core/Config/PolicyGraph/default.jsonl"
@export var policy_graph_jsonl: Array[String] = []

## Balance profile state (shared between headless and UI)
@export var balance_profile_id: String = "default"
@export var balance_workbench_config: Dictionary = {}
@export var farm_variable_graph_path: String = "res://Core/Config/FarmVariableGraph/default.jsonl"  # Optional source path used to seed this state.
@export var farm_variable_graph_jsonl: Array[String] = []  # Canonical tunable parameter graph rows.
# Transient seed only: the runtime source is FarmEconomy (loaded from default.jsonl) and this
# is overwritten by the runtime mirror at serialize time. Derived from the single BalanceConfig
# spec (no re-hardcoded literal) and re-seeded by ensure_balance_workbench_defaults().
@export var economy_variables: Dictionary = BalanceConfig.DEFAULTS.get("economy_variables", {}).duplicate(true)
@export var reap_count: int = 0

## FactionDensityMatrix serialization: {faction_name: float} summing to 1.0.
## Empty dict → farm re-initializes uniform on load.
@export var faction_density: Dictionary = {}

## Majorana bridge bank (BridgeRegister.to_dict): live nonlocal 2×2 registers
## spanning biome pairs + lifetime counters (What Connects). Empty dict → no
## bridges; additive field, older saves load clean.
@export var bridges: Dictionary = {}

## Story flags and narrative log (v3+). story_flags_fired maps flag_id → phrame_index.
## story_log is an ordered Array of fired-flag entries shown in the Z/Y Story tab.
## Both are empty on new saves (no flags fired yet).
@export var story_flags_fired: Dictionary = {}
@export var story_log: Array = []

## Per-faction multi-channel standings (v2). Empty dict → all zero on load.
## Format: {faction_name: {trust, debt, attention, access, legitimacy, entanglement}}
## See Core/Factions/FactionStanding.gd for the channel semantics.
## v1 saves leave this empty; consumers must tolerate absence.
@export var faction_standings: Dictionary = {}

## Player AlignmentGraph serialization (v3). Empty dict → farm re-initializes to
## |+⟩^⊗12 (uniform superposition; player has no preferred axial pole yet).
## Format: AlignmentGraph.to_dict() output ({version, axis_count, weights, kets}).
@export var player_alignment: Dictionary = {}

## Faction the player is currently attached to. Default scenario pins to
## "The Demos"; other scenarios may pin to a different faction; free play
## (no scenario) leaves this as "The Demos" unless the player detaches via
## the Z surface. Empty string = detached (no faction is being mutated by
## player trade).
@export var player_faction_name: String = "The Demos"

## Unlocked Biomes - loaded exactly from save/scenario state.
@export var unlocked_biomes: Array[String] = []

## Pool of unexplored biomes (assigned to active TYUIOP spindle slots dynamically)
## These are available but not yet assigned to keyboard slots
@export var unexplored_biome_pool: Array[String] = ["BioticFlux", "StellarForges", "FungalNetworks", "VolcanicWorlds"]

## Active biome in the observation spindle when save was captured
@export var active_biome_name: String = ""

## Selection State (player's configured multi-select for batch operations)
## Array of Vector2i positions of selected/checked plots
## Allows saving complex selection configurations before executing actions
@export var selected_plot_positions: Array = []  # Array of Vector2i


static func derive_known_emojis_from_icons(icons: Array) -> Array:
	var emojis: Array = []
	for icon in icons:
		if not (icon is Dictionary):
			continue
		var north = str(icon.get("north", ""))
		var south = str(icon.get("south", ""))
		if north != "" and north not in emojis:
			emojis.append(north)
		if south != "" and south not in emojis:
			emojis.append(south)
	return emojis


## Get known emojis (derived from known_icons).
func get_known_emojis() -> Array:
	return derive_known_emojis_from_icons(known_icons)


## Get the icon containing a given emoji (returns null if not found)
func get_icon_for_emoji(emoji: String) -> Variant:
	for icon in known_icons:
		if icon.get("north", "") == emoji or icon.get("south", "") == emoji:
			return icon
	return null


func get_known_icons() -> Array:
	return known_icons


func _set(property: StringName, value) -> bool:
	if property == "known_icons":
		known_icons = _normalize_known_icons(value)
		return true
	return false


func _get(property: StringName):
	if property == "known_icons":
		return known_icons
	return null


static func _normalize_known_icons(raw) -> Array:
	var out: Array = []
	if raw is Array:
		for icon in raw:
			if not (icon is Dictionary):
				continue
			var north = str(icon.get("north", ""))
			var south = str(icon.get("south", ""))
			if north == "" or south == "" or north == south:
				continue
			out.append({"north": north, "south": south})
	if out.is_empty():
		return [{"north": "🌾", "south": "👥"}]
	return out

## Quest Board - Multi-Page Memory System
@export var quest_pages: Dictionary = {}
# Structure: {
#   0: [slot0_dict, slot1_dict, slot2_dict, slot3_dict],
#   1: [slot0_dict, slot1_dict, slot2_dict, slot3_dict],
#   ...
# }
# Each slot_dict: {quest_id, offered_quest, faction, state}

@export var quest_board_current_page: int = 0

## Plots - Array of serialized plot states (from FarmGrid)
@export var plots: Array[Dictionary] = []
# Each plot dictionary contains:
#   position: Vector2i - Grid coordinates (x, y)
#   type_name: String - plot type ("wheat", "mushroom", etc.)
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

func _init():
	save_timestamp = int(Time.get_unix_time_from_system())
	ensure_balance_workbench_defaults()
	ensure_policy_state_defaults()


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
	# Get human-readable save name
	var time = Time.get_datetime_dict_from_unix_time(save_timestamp)
	return "%02d/%02d/%04d %02d:%02d" % [
		time.month, time.day, time.year,
		time.hour, time.minute
	]


const BALANCE_SCHEMA_VERSION: int = 2

func set_balance_config_value(path: Array, value: Variant) -> void:
	if path.is_empty():
		return
	if not (balance_workbench_config is Dictionary):
		balance_workbench_config = {}
	var node := balance_workbench_config
	for i in range(path.size() - 1):
		var key = path[i]
		if typeof(node.get(key)) != TYPE_DICTIONARY:
			node[key] = {}
		node = node[key]
	node[path[-1]] = value


func ensure_balance_workbench_defaults() -> bool:
	var defaults = _default_balance_workbench_config()
	if not (balance_workbench_config is Dictionary):
		balance_workbench_config = {}
	if balance_workbench_config.is_empty():
		balance_workbench_config = defaults
		return true
	var saved_version = int(balance_workbench_config.get("balance_schema_version", 0))
	var migrating = saved_version < BALANCE_SCHEMA_VERSION
	if not balance_workbench_config.has("profile_id"):
		balance_workbench_config["profile_id"] = defaults.get("profile_id", "default")
	if not balance_workbench_config.has("display_name"):
		balance_workbench_config["display_name"] = defaults.get("display_name", "Default Runtime Balance")
	var tuning = balance_workbench_config.get("tuning", {})
	if not (tuning is Dictionary):
		tuning = {}
	for key in defaults.get("tuning", {}).keys():
		if migrating or not tuning.has(key):
			tuning[key] = defaults["tuning"][key]
	balance_workbench_config["tuning"] = tuning
	balance_workbench_config["balance_schema_version"] = BALANCE_SCHEMA_VERSION
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
	if not (economy_variables is Dictionary):
		economy_variables = {}
	for key in ["quantum_to_credits", "max_biome_qubits"]:
		if not economy_variables.has(key):
			economy_variables[key] = defaults.get("economy_variables", {}).get(key, BalanceConfig.DEFAULTS["economy_variables"][key])
	return migrating


func ensure_policy_state_defaults() -> void:
	if not (policy_state is Dictionary):
		policy_state = {}
	if not policy_state.has("version"):
		policy_state["version"] = 1
	if not policy_state.has("profile"):
		policy_state["profile"] = "default"
	if not policy_state.has("step_count"):
		policy_state["step_count"] = 0
	# UCB-specific defaults — skip if quantum_register policy is active
	if str(policy_state.get("policy_type", "")) != "quantum_register":
		if not policy_state.has("epsilon"):
			policy_state["epsilon"] = 0.18
		if not policy_state.has("ucb_scale"):
			policy_state["ucb_scale"] = 1.10
		if not policy_state.has("action_stats"):
			policy_state["action_stats"] = {}
	if not (policy_graph_jsonl is Array):
		policy_graph_jsonl = []
	if policy_graph_path == "":
		policy_graph_path = "res://Core/Config/PolicyGraph/default.jsonl"


func _default_balance_workbench_config() -> Dictionary:
	return {
		"balance_schema_version": BALANCE_SCHEMA_VERSION,
		"profile_id": "default",
		"display_name": "Default Runtime Balance",
		# Numeric tuning + economy_variables are NOT hardcoded here — they derive from
		# BalanceConfig.DEFAULTS (built from the single TUNABLES spec, mirrored in
		# default.jsonl), so there is no third copy to drift out of sync.
		"tuning": BalanceConfig.DEFAULTS.get("tuning", {}).duplicate(true),
		"economy_variables": BalanceConfig.DEFAULTS.get("economy_variables", {}).duplicate(true),
		"action_roi_notes": {
			"explore": "Unlocks one terminal cycle; prerequisite for measure/pop.",
			"measure": "Collapses state and unlocks deterministic harvest paths.",
			"pop": "Single terminal payoff from measured outcome, driven by icon-map mass and purity.",
			"reap": "Season change: fast-forward, collect sink flux, and broad harvest across active biomes.",
			"discover_biome": "Long-term expansion unlock; increases future terminal surface area.",
			"remove_biome": "Liquidates one non-core biome from its live quantum state and frees the slot.",
			"inject_icon": "Converts known icons into biome terminals and new learning options.",
			"remove_icon": "Emergency rollback action; expensive by design.",
			"lindblad_pump": "Raises local population/energy; setup cost for stronger harvest curves.",
			"lindblad_drain": "Removes unstable population; useful for stabilizing noisy plots.",
			"quest_reroll": "Short-horizon quest quality control."
		},
		"quest_reward_notes": {
			"resource_reward_base_ratio": "Global scaler on quest resource payout budget.",
			"resource_reward_min_total": "Lower clamp for total payout.",
			"resource_reward_max_total": "Upper clamp for total payout.",
			"resource_reward_min_per_emoji": "Floor per resource emoji in split payouts."
		}
	}
