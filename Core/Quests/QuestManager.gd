class_name QuestManager
extends Node

## Quest lifecycle management
## Handles offer → accept → complete/fail flow
## Integrates with FarmEconomy for resource checking

# Quest system dependency

# Logging
@onready var _verbose = get_node_or_null("/root/VerboseConfig")

# =============================================================================
# SIGNALS
# =============================================================================

signal quest_offered(quest_data: Dictionary)
signal quest_accepted(quest_id: int)
signal quest_ready_to_claim(quest_id: int)  # Non-delivery quest conditions met, awaiting player claim
signal quest_completed(quest_id: int, rewards: Dictionary)
signal quest_failed(quest_id: int, reason: String)
signal quest_expired(quest_id: int)
signal active_quests_changed()
signal icon_learned(north: String, south: String, faction: String)
signal story_flag_fired(flag_id: String, flag_data: Dictionary)

# =============================================================================
# STATE
# =============================================================================

var active_quests: Dictionary = {}  # quest_id -> quest_data (status: "active" or "ready")
var story_offers: Dictionary = {}  # quest_id -> quest_data (story arc offers pending acknowledgement)
var completed_quests: Array = []
var failed_quests: Array = []
var next_quest_id: int = 0
var _announced_offers: Dictionary = {}  # quest_id -> true; dedup for quest_offered emit

# Quest timers
var quest_timers: Dictionary = {}  # quest_id -> Timer

# References (set via dependency injection)
var economy: Node = null
var faction_manager: Node = null
var current_biome: Node = null  # For tracking non-delivery quest progress
var _state_projection: QuestStateProjectionService = QuestStateProjectionService.new()
var _story_flags: Array = []    # All flag definitions loaded from story_flags.json
var _unfired_flags: Array = []  # Subset not yet in farm.story_flags_fired
var _tutorial_steps: Array = [] # Act-0 onboarding chain (tutorial_arc.json), linked into a chain

# =============================================================================
# CONFIGURATION
# =============================================================================

const MAX_ACTIVE_QUESTS: int = 5
const QUEST_OFFER_COOLDOWN: float = 30.0  # Seconds between new quest offers
const AUTO_FAIL_ON_RESOURCE_SHORTAGE: bool = true

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	set_physics_process(true)  # Enable for quest tracking
	_load_story_flags()
	_load_tutorial_arc()

func _physics_process(delta: float) -> void:
	var t0 = Time.get_ticks_usec()
	# Story flags don't require a biome — evaluate unconditionally.
	_evaluate_story_flags()
	# Non-delivery quest progress tracking requires a live biome reference.
	if current_biome == null:
		return
	if _state_projection:
		_state_projection.observe_biome(current_biome, delta)

	for quest in active_quests.values():
		# Skip quests already ready to claim
		if quest.get("status") == "ready":
			continue
		var qpreds = quest.get("state_predicates", [])
		if qpreds is Array and not qpreds.is_empty():
			var pred_score := _evaluate_quest_state_predicates(qpreds)
			quest["predicate_score"] = pred_score
			if pred_score >= QuestStateProjectionService.COMPLETION_THRESHOLD:
				var quest_id = int(quest.get("id", -1))
				if quest_id >= 0:
					mark_quest_ready(quest_id, "state_predicates")
					continue

		var quest_type = quest.get("type", QuestTypes.Type.DELIVERY)

		# Only track quest types that need continuous monitoring
		if not QuestTypes.requires_tracking(quest_type):
			continue

		match quest_type:
			QuestTypes.Type.SHAPE_ACHIEVE:
				_update_shape_achieve_quest(quest, delta)
			QuestTypes.Type.SHAPE_MAINTAIN:
				_update_shape_maintain_quest(quest, delta)
			QuestTypes.Type.EVOLUTION:
				_update_evolution_quest(quest, delta)
			QuestTypes.Type.ENTANGLEMENT:
				_update_entanglement_quest(quest, delta)
			# Quantum mechanics quest types
			QuestTypes.Type.ACHIEVE_EIGENSTATE:
				_update_achieve_eigenstate_quest(quest, delta)
			QuestTypes.Type.MAINTAIN_COHERENCE:
				_update_maintain_coherence_quest(quest, delta)
			QuestTypes.Type.INDUCE_BELL_STATE:
				_update_induce_bell_state_quest(quest, delta)
			QuestTypes.Type.PREVENT_DECOHERENCE:
				_update_prevent_decoherence_quest(quest, delta)
			QuestTypes.Type.COLLAPSE_DELIBERATELY:
				_update_collapse_deliberately_quest(quest, delta)
	var t1 = Time.get_ticks_usec()
	if Engine.get_physics_frames() % 60 == 0:
		if _verbose:
			_verbose.trace("quest", "⏱️", "QuestManager Physics Trace: Total %d us" % [t1 - t0])

func connect_to_economy(econ: Node) -> void:
	# Inject economy dependency
	economy = econ

func connect_to_faction_manager(fm: Node) -> void:
	# Inject faction manager dependency
	faction_manager = fm

func connect_to_biome(biome: Node) -> void:
	# Inject biome dependency for quest tracking
	current_biome = biome


func connect_to_farm(farm: Node) -> void:
	_refresh_unfired_flags(farm)
	maybe_start_tutorial(farm)
	var story_engine = get_node_or_null("/root/StoryEngine")
	if story_engine != null and story_engine.has_method("connect_to_farm_and_quests"):
		story_engine.connect_to_farm_and_quests(farm, self)


# =============================================================================
# STORY FLAGS
# =============================================================================

func _load_story_flags() -> void:
	var path := "res://Core/Quests/data/story_flags.json"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("QuestManager: story_flags.json not found at %s" % path)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Array:
		_story_flags = parsed
	else:
		push_warning("QuestManager: story_flags.json root is not an Array")


func _refresh_unfired_flags(farm) -> void:
	if farm == null or not ("story_flags_fired" in farm):
		_unfired_flags = _story_flags.duplicate()
		return
	_unfired_flags = []
	for flag in _story_flags:
		if not farm.story_flags_fired.has(str(flag.get("id", ""))):
			_unfired_flags.append(flag)


## Load the Act-0 onboarding chain and link each step to unlock the next (linear chain via
## chain_unlocks; dicts are references, so the nesting is built in one pass).
func _load_tutorial_arc() -> void:
	var path := "res://Core/Quests/data/tutorial_arc.json"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("QuestManager: tutorial_arc.json not found at %s" % path)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	var steps: Array = []
	if parsed is Dictionary and parsed.get("steps", null) is Array:
		steps = parsed["steps"]
	elif parsed is Array:
		steps = parsed
	for i in steps.size():
		steps[i]["chain_unlocks"] = [steps[i + 1]] if i + 1 < steps.size() else []
	_tutorial_steps = steps


## Offer the first Act-0 quest on a fresh game. Gated by a persisted marker in story_flags_fired
## ("tutorial_seen") so it never re-offers on a loaded save. Completing each step unlocks the next
## via _process_chain_unlocks. New games start with this empty; the marker survives save/load.
func maybe_start_tutorial(farm) -> void:
	if farm == null or _tutorial_steps.is_empty():
		return
	if not ("story_flags_fired" in farm):
		return
	if farm.story_flags_fired.has("tutorial_seen"):
		return
	farm.story_flags_fired["tutorial_seen"] = Engine.get_physics_frames()
	offer_tutorial_quest(_tutorial_steps[0])


## Story-flag firing threshold. Firing is governed by the SAME soft continuous geometry the
## Arc tab displays: a flag fires when smooth_and over its predicates' soft_gate scores reaches
## this value. (Replaces the old hard per-predicate firing path — soft continuous geometry is
## always >>> hard rules. A consequence: wide-width predicates fire at high confidence, a touch
## past their nominal threshold; this constant is the single dial for earlier/later firing.)
const FLAG_FIRE_THRESHOLD: float = 0.85


func _evaluate_story_flags() -> void:
	if _unfired_flags.is_empty():
		return
	var farm = _get_active_farm()
	if farm == null:
		return
	for flag in _unfired_flags.duplicate():
		var predicates = flag.get("predicates", [])
		if _evaluate_flag_predicates(predicates, farm) >= FLAG_FIRE_THRESHOLD:
			_fire_story_flag(flag, farm)


func _evaluate_flag_predicates(predicates: Array, farm) -> float:
	## Returns a continuous confidence score in [0, 1].
	## Empty list → 0.0 so that flags with no predicates never auto-fire.
	if predicates.is_empty():
		return 0.0
	var scores: Array = []
	for pred in predicates:
		if not (pred is Dictionary):
			return 0.0
		scores.append(_check_flag_predicate(pred, farm))
	return QuestMath.smooth_and(scores)


## Predicate types handled by _check_flag_predicate (state-outcome vocabulary). Quest completion
## (below) accepts these PLUS the QuestStateProjectionService observable/action vocabulary, so the
## tutorial + arc + market quests all draw from one unified predicate language.
const FLAG_PREDICATE_TYPES := [
	"story_flag_set", "biome_evolving", "berry_consumed_count_gte", "berry_total_phase_gte",
	"standing_gte", "biome_state_gte", "signature_size_gte", "atom_count_gte", "atom_in_biome",
	"biome_attractor_emoji_gte", "biome_eigenvalue_gap_gte", "biome_purity_trending",
]


## Unified per-predicate score for QUEST completion: flag-vocabulary predicates (state outcomes)
## resolve via _check_flag_predicate; everything else via the state-projection service (observables
## + recorded action history). Soft continuous geometry throughout.
func _quest_predicate_score(pred: Dictionary, farm) -> float:
	var t := str(pred.get("type", ""))
	if t in FLAG_PREDICATE_TYPES:
		return _check_flag_predicate(pred, farm) if farm != null else 0.0
	if _state_projection:
		return _state_projection.evaluate_predicate(pred)
	return 0.0


## smooth_and over a quest's state_predicates using the unified vocabulary. Empty → 0.0.
func _evaluate_quest_state_predicates(predicates: Array) -> float:
	if predicates.is_empty():
		return 0.0
	var farm = _get_active_farm()
	var scores: Array = []
	for pred in predicates:
		if not (pred is Dictionary):
			return 0.0
		scores.append(_quest_predicate_score(pred, farm))
	return QuestMath.smooth_and(scores)


func _check_flag_predicate(pred: Dictionary, farm) -> float:
	## Returns a continuous confidence score in [0, 1] for each predicate type.
	## Structural predicates (flag set, biome exists) return 1.0 or 0.0 exactly.
	## Physics predicates use soft_gate so partial progress is visible.
	var kind := str(pred.get("type", ""))
	match kind:
		"story_flag_set":
			return 1.0 if farm.story_flags_fired.has(str(pred.get("id", ""))) else 0.0
		"biome_evolving":
			if farm.grid == null:
				return 0.0
			var biome = farm.grid.get_biome(str(pred.get("biome", "")))
			return 1.0 if (biome != null and biome.get("quantum_computer") != null) else 0.0
		"berry_consumed_count_gte":
			if farm.grid == null:
				return 0.0
			var biome = farm.grid.get_biome(str(pred.get("biome", "")))
			if biome == null or biome.get("quantum_computer") == null:
				return 0.0
			var count := float(biome.quantum_computer.berry_register.get_consumed_count())
			return QuestMath.soft_gate(count, float(pred.get("value", 0)), 1.5)
		"berry_total_phase_gte":
			if farm.grid == null:
				return 0.0
			var biome = farm.grid.get_biome(str(pred.get("biome", "")))
			if biome == null or biome.get("quantum_computer") == null:
				return 0.0
			var phase: float = biome.quantum_computer.berry_register.get_consumed_phase()
			return QuestMath.soft_gate(phase, float(pred.get("value", 0.0)), 0.1)
		"standing_gte":
			var standing = farm.faction_standings.get(str(pred.get("faction", "")))
			if standing == null:
				return 0.0
			var channel: String = str(pred.get("channel", "trust"))
			var current := float(standing.to_dict().get(channel, 0.0))
			return QuestMath.soft_gate(current, float(pred.get("value", 0.0)))
		"biome_state_gte":
			if farm.grid == null:
				return 0.0
			var biome = farm.grid.get_biome(str(pred.get("biome", "")))
			if biome == null or biome.get("quantum_computer") == null:
				return 0.0
			var atom := str(pred.get("atom", ""))
			var reg = biome.quantum_computer.register_map
			if reg == null or not reg.coordinates.has(atom):
				return 0.0
			var coord: Dictionary = reg.coordinates[atom]
			var qubit := int(coord.get("qubit", -1))
			var pole := int(coord.get("pole", 0))
			if qubit < 0:
				return 0.0
			var snap: Dictionary = biome.viz_cache.get_snapshot(qubit)
			var marginal: float = float(snap.get("p1" if pole == 1 else "p0", 0.0))
			return QuestMath.soft_gate(marginal, float(pred.get("value", 0.0)))
		"signature_size_gte":
			return QuestMath.soft_gate(float(farm.known_icons.size()), float(pred.get("value", 0)), 2.0)
		"atom_count_gte":
			if farm.grid == null:
				return 0.0
			var biome = farm.grid.get_biome(str(pred.get("biome", "")))
			if biome == null or biome.get("quantum_computer") == null:
				return 0.0
			var count := float(biome.quantum_computer.register_map.coordinates.size())
			return QuestMath.soft_gate(count, float(pred.get("value", 0)), 1.5)
		"atom_in_biome":
			if farm.grid == null:
				return 0.0
			var biome = farm.grid.get_biome(str(pred.get("biome", "")))
			if biome == null or biome.get("quantum_computer") == null:
				return 0.0
			return 1.0 if biome.quantum_computer.register_map.coordinates.has(str(pred.get("atom", ""))) else 0.0
		"biome_attractor_emoji_gte":
			if farm.grid == null:
				return 0.0
			var biome = farm.grid.get_biome(str(pred.get("biome", "")))
			if biome == null or not biome.has_method("get_attractor_state"):
				return 0.0
			var attractor: Dictionary = biome.get_attractor_state()
			return QuestMath.soft_gate(attractor.get(str(pred.get("emoji", "")), 0.0),
					float(pred.get("value", 0.5)))
		"biome_eigenvalue_gap_gte":
			if farm.grid == null:
				return 0.0
			var biome = farm.grid.get_biome(str(pred.get("biome", "")))
			if biome == null or not biome.has_method("get_attractor_state"):
				return 0.0
			var attractor: Dictionary = biome.get_attractor_state()
			return QuestMath.soft_gate(attractor.get("eigenvalue_gap", 0.0),
					float(pred.get("value", 0.15)), 0.02)
		"biome_purity_trending":
			if farm.grid == null:
				return 0.0
			var biome = farm.grid.get_biome(str(pred.get("biome", "")))
			if biome == null or not biome.has_method("predict_purity"):
				return 0.0
			var steps := int(pred.get("steps", 5))
			# Score proportional to how strongly purity is trending upward.
			# Requires a ~1% positive trend to score 0.5; flat = ~0.4.
			var trend: float = biome.predict_purity(steps) - biome.get_purity()
			return QuestMath.soft_gate(trend, 0.01, 0.02)
		_:
			return 0.0


## Public: all loaded story flags (for Arc tab and tooling).
func get_all_story_flags() -> Array:
	return _story_flags


## Public: score a single predicate against the active farm. Score is in [0,1];
## ≥ FLAG_FIRE_THRESHOLD on combined `smooth_and` over a flag's predicates is
## what triggers a fire. Used by C-surface Arc tab to show progress.
func evaluate_predicate_score(pred: Dictionary) -> float:
	var farm = _get_active_farm()
	if farm == null or not (pred is Dictionary):
		return 0.0
	return _check_flag_predicate(pred, farm)


## Public: combined `smooth_and` score for a whole flag's predicates.
func evaluate_flag_score(flag: Dictionary) -> float:
	var farm = _get_active_farm()
	if farm == null:
		return 0.0
	var preds = flag.get("predicates", [])
	if not (preds is Array):
		return 0.0
	return _evaluate_flag_predicates(preds, farm)


func _fire_story_flag(flag: Dictionary, farm) -> void:
	var flag_id := str(flag.get("id", ""))
	if flag_id == "" or farm.story_flags_fired.has(flag_id):
		return

	# Record the fired frame — all downstream (beat, grants, quest, density) handled by StoryEngine.
	farm.story_flags_fired[flag_id] = Engine.get_physics_frames()

	# Remove from unfired list before emitting so predicate evaluation sees the flag as fired.
	_unfired_flags.erase(flag)

	story_flag_fired.emit(flag_id, flag)

	if _verbose:
		_verbose.info("quest", "📖", "Story flag fired: %s (act %d)" % [flag_id, int(flag.get("act", 0))])


## Non-expiring offer injected by StoryEngine when a story flag fires.
## All fields from quest_def are merged in; caller owns enrichment (attractor snap, etc.).
func offer_story_quest(quest_def: Dictionary, source_flag: String) -> int:
	if quest_def.is_empty():
		return -1
	var quest_id := next_quest_id
	next_quest_id += 1
	var q := QuestPipeline.from_story_def(quest_def, source_flag, quest_id)
	story_offers[quest_id] = q
	if not _announced_offers.has(quest_id):
		_announced_offers[quest_id] = true
		quest_offered.emit(q)
	return quest_id


## Offer a tutorial-chain quest (Act-0 onboarding). Parallel to offer_story_quest; routes through
## the pipeline's tutorial source. Used by _process_chain_unlocks for linear tutorial progression.
func offer_tutorial_quest(quest_def: Dictionary) -> int:
	if quest_def.is_empty():
		return -1
	var quest_id := next_quest_id
	next_quest_id += 1
	var q := QuestPipeline.from_tutorial_def(quest_def, quest_id)
	story_offers[quest_id] = q
	if not _announced_offers.has(quest_id):
		_announced_offers[quest_id] = true
		quest_offered.emit(q)
	return quest_id


## True if any story or active quest has source_flag == flag_id (for save/load restore check).
func has_quest_for_flag(flag_id: String) -> bool:
	for q in story_offers.values():
		if q.get("source_flag") == flag_id:
			return true
	for q in active_quests.values():
		if q.get("source_flag") == flag_id:
			return true
	return false


func _get_gsm():
	return get_node_or_null("/root/GameStateManager")


func _get_active_farm():
	var gsm = _get_gsm()
	if gsm and gsm.has_method("get_active_farm"):
		return gsm.get_active_farm()
	return null


func _get_signature_emojis() -> Array:
	# Get player-known emojis (farm-owned preferred).
	var gsm = _get_gsm()
	if gsm and gsm.player_progress:
		return gsm.player_progress.get_signature_emojis()
	return []


func _discover_icon(north: String, south: String) -> bool:
	# Grant an icon to the player (farm-owned preferred).

	# Returns true if signature was newly discovered, false if already known.
	var gsm = _get_gsm()
	var active_farm = gsm.get_active_farm() if gsm and gsm.has_method("get_active_farm") else null
	if active_farm and active_farm.has_method("discover_icon"):
		return active_farm.discover_icon(north, south)
	elif gsm and gsm.player_progress:
		return gsm.player_progress.discover_icon(north, south)
	return false


func _grant_resource_rewards(reward, faction_name: String) -> Dictionary:
	# Grant resource rewards to economy and return granted payload.
	var granted: Dictionary = {}
	if reward == null:
		return granted
	var rewards = reward.resource_rewards
	if not (rewards is Dictionary) or rewards.is_empty():
		return granted
	if economy == null:
		push_warning("QuestManager: economy not connected, cannot grant resource rewards")
		return granted

	var source = "quest_reward:%s" % faction_name.replace(" ", "_").to_lower()
	for emoji in rewards.keys():
		var amount = int(rewards.get(emoji, 0))
		if amount <= 0:
			continue
		economy.add_resource(emoji, amount, source)
		granted[emoji] = amount

	return granted


func _grant_icon_rewards(reward, faction_name: String) -> void:
	# Grant icon rewards and emit discovery signals.
	if reward == null:
		return

	# Paired signature is preferred (north/south axis)
	for pair in reward.learned_pairs:
		var north = pair.get("north", "")
		var south = pair.get("south", "")
		if north == "" or south == "":
			continue
		var was_new = _discover_icon(north, south)
		if was_new:
			icon_learned.emit(north, south, faction_name)
			if _verbose:
				_verbose.info("quest", "📖", "%s taught you: %s/%s axis" % [faction_name, north, south])
		else:
			if _verbose:
				_verbose.debug("quest", "📖", "%s tried to teach %s/%s but you already know it" % [faction_name, north, south])


func _build_reward_payload(reward, granted_resources: Dictionary) -> Dictionary:
	# Convert reward object to plain dictionary for UI/signals.
	var payload: Dictionary = {
		"resource_rewards": granted_resources.duplicate(true),
		"learned_emojis": [],
		"learned_pairs": [],
		"bonus_multiplier": 1.0,
		"money_amount": 0
	}
	if reward == null:
		return payload
	payload["learned_emojis"] = reward.learned_emojis.duplicate()
	payload["learned_pairs"] = reward.learned_pairs.duplicate(true)
	payload["bonus_multiplier"] = reward.bonus_multiplier
	payload["money_amount"] = reward.money_amount
	return payload


func offer_all_faction_quests(biome) -> Array:
	# Generate quests for the current biome.

	# Quests come from the canonical MarketLattice: it reads the current mythos
	# substrate (faction density, principal mode, biome admitted factions,
	# player economy) and proposes bids that QuestManager wraps into the lifecycle.

	var quests: Array = []

	var now_ms: int = Time.get_ticks_msec()
	var player_icons := _get_signature_emojis()
	var seen_pairs: Dictionary = {}
	for quest in _offer_from_market_lattice(biome):
		if not _is_valid_offer_with_icons(quest, player_icons):
			continue
		var pk: String = "%s|%s" % [quest.get("reward_north", ""), quest.get("reward_south", "")]
		if pk != "|" and seen_pairs.has(pk):
			continue
		seen_pairs[pk] = true
		quest["id"] = next_quest_id
		next_quest_id += 1
		quest["offered_at"] = now_ms
		quests.append(quest)
		if not _announced_offers.has(quest["id"]):
			_announced_offers[quest["id"]] = true
			quest_offered.emit(quest)

	# One physics-derived quantum quest alongside the deliveries — teaches reading/steering the
	# state (closed-safe: targets coherence, which is steerable; never purity). Deterministic.
	if not quests.is_empty():
		var obs := get_biome_observables(biome)
		var coh := float(obs.get("coherence", 0.0))
		var fac := str(quests[0].get("faction", ""))
		var bn := str(quests[0].get("biome_name", quests[0].get("biome", "")))
		var qq := QuestPipeline.suggest_quantum_quest(bn, fac, coh, next_quest_id)
		if not qq.is_empty():
			next_quest_id += 1
			qq["offered_at"] = now_ms
			quests.append(qq)
			if not _announced_offers.has(qq["id"]):
				_announced_offers[qq["id"]] = true
				quest_offered.emit(qq)
	return quests


func record_quantum_action(action_name: String, payload: Dictionary = {}) -> void:
	if not _state_projection:
		return
	_state_projection.record_action(action_name, payload)


func get_state_projection_snapshot() -> Dictionary:
	if not _state_projection:
		return {}
	return _state_projection.get_snapshot()


func _is_valid_offer_with_icons(quest: Dictionary, player_icons: Array) -> bool:
	# Reject broken offers using pre-fetched player signature (avoids GSM walk).
	if quest.is_empty():
		return false
	var quest_type = quest.get("type", QuestTypes.Type.DELIVERY)
	if quest_type == QuestTypes.Type.DELIVERY:
		var resource = quest.get("resource", "")
		var quantity = quest.get("quantity", 0)
		if resource == "" or quantity <= 0:
			return false

	var north = quest.get("reward_north", "")
	var south = quest.get("reward_south", "")
	var has_icon_axis = (north != "" and south != "")
	var has_no_icon = (north == "" and south == "")
	if not has_icon_axis and not has_no_icon:
		return false
	if has_icon_axis and (north in player_icons or south in player_icons):
		return false
	return true


func get_biome_observables(biome) -> Dictionary:
	# Get current biome quantum observables for UI display
	var obs = FactionStateMatcher.extract_observables(null, biome)

	return {
		"purity": obs.purity,
		"entropy": obs.entropy,
		"coherence": obs.coherence,
		"distribution_shape": obs.distribution_shape,
		"scale": obs.scale,
		"dynamics": obs.dynamics,
		"description": FactionStateMatcher.describe_observables(obs),
	}


func _get_global_icon_map() -> Dictionary:
	var gsm = _get_gsm()
	var active_farm = gsm.get_active_farm() if gsm and gsm.has_method("get_active_farm") else null
	if active_farm and "biome_evolution_batcher" in active_farm:
		var batcher = active_farm.biome_evolution_batcher
		if batcher:
			var icon_map = batcher.get_global_icon_map()
			if icon_map is Dictionary:
				return icon_map
	return {}


func _apply_market_projection(quest: Dictionary) -> void:
	if quest.is_empty():
		return
	var icon_map = _get_global_icon_map()
	var projection = QuestRewards.compute_market_projection(quest, icon_map)
	if projection.is_empty():
		return
	quest["market_projection"] = projection

# =============================================================================
# QUEST ACCEPTANCE
# =============================================================================

func accept_quest(quest_data: Dictionary) -> bool:
	# Accept an offered quest

	# Args:
	# quest_data: Quest with "id" field

	# Returns:
	# true if accepted, false if invalid
	if not quest_data.has("id"):
		push_error("Cannot accept quest: missing ID")
		return false

	var quest_id = quest_data["id"]

	if active_quests.has(quest_id):
		push_warning("Quest %d already active" % quest_id)
		return false
	if story_offers.has(quest_id):
		story_offers.erase(quest_id)

	# Update status
	quest_data["status"] = "active"
	quest_data["accepted_at"] = Time.get_ticks_msec()

	# Store
	active_quests[quest_id] = quest_data

	# Start timer if quest has time limit
	if quest_data.get("time_limit", -1) > 0:
		_start_quest_timer(quest_id, quest_data["time_limit"])

	quest_accepted.emit(quest_id)
	active_quests_changed.emit()
	return true

# =============================================================================
# QUEST COMPLETION
# =============================================================================

func check_quest_completion(quest_id: int) -> bool:
	# Check if player has resources to complete quest

	# Returns:
	# true if quest can be completed with current resources
	if not active_quests.has(quest_id):
		return false

	var quest = active_quests[quest_id]
	var required_emoji = quest.get("resource", "")
	var required_qty = quest.get("quantity", 0)

	if required_emoji.is_empty() or required_qty <= 0:
		return false

	if economy == null:
		push_warning("QuestManager: economy not connected, cannot check resources")
		return false

	# Check if player has enough resources
	# quantity is already in credits.
	var player_amount = economy.get_resource(required_emoji)
	return player_amount >= required_qty

func _finalize_quest_completion(quest_id: int, quest: Dictionary, reward, granted_resources: Dictionary) -> void:
	# Stamp completion fields, move quest to completed list, emit signals.
	quest["status"] = "completed"
	quest["completed_at"] = Time.get_ticks_msec()
	quest["reward"] = reward
	quest["reward_payload"] = _build_reward_payload(reward, granted_resources)
	active_quests.erase(quest_id)
	completed_quests.append(quest)
	_stop_quest_timer(quest_id)
	quest_completed.emit(quest_id, _build_reward_payload(reward, granted_resources))
	active_quests_changed.emit()
	_process_chain_unlocks(quest)
	_process_chain_branch(quest)


## On completion, offer any quests this one unlocks (linear tutorial chains, arc continuations).
## chain_unlocks is an Array of quest spec dicts; each spec's "source" routes it (tutorial default).
func _process_chain_unlocks(quest: Dictionary) -> void:
	var unlocks = quest.get("chain_unlocks", [])
	if not (unlocks is Array):
		return
	for spec in unlocks:
		if not (spec is Dictionary) or spec.is_empty():
			continue
		_offer_chain_spec(spec, quest)


## Faction-siding branch: pick the branch whose condition scores HIGHEST (soft continuous
## geometry — the player's standing/state picks the path), and offer its unlock. chain_branch is
## [{when: <predicate>, unlock: <quest spec>}]. Only branches if the best score clears 0.5.
func _process_chain_branch(quest: Dictionary) -> void:
	var branches = quest.get("chain_branch", [])
	if not (branches is Array) or branches.is_empty():
		return
	var farm = _get_active_farm()
	var best_score := -1.0
	var best_unlock = null
	for br in branches:
		if not (br is Dictionary):
			continue
		var cond = br.get("when", {})
		var score := _quest_predicate_score(cond, farm) if cond is Dictionary else 0.0
		if score > best_score:
			best_score = score
			best_unlock = br.get("unlock", null)
	if best_unlock is Dictionary and not best_unlock.is_empty() and best_score >= 0.5:
		_offer_chain_spec(best_unlock, quest)


## Offer a chain/branch spec, routing by its "source" (tutorial default, story explicit).
func _offer_chain_spec(spec: Dictionary, parent_quest: Dictionary) -> void:
	var src := str(spec.get("source", Quest.SOURCE_TUTORIAL))
	if src == Quest.SOURCE_STORY:
		offer_story_quest(spec, str(parent_quest.get("source_flag", "")))
	else:
		offer_tutorial_quest(spec)


func complete_quest(quest_id: int) -> bool:
	# Complete an active quest

	# Deducts required resources and grants rewards (including icon!)

	# Returns:
	# true if completed successfully
	if not active_quests.has(quest_id):
		push_error("Cannot complete quest %d: not active" % quest_id)
		return false

	var quest = active_quests[quest_id]
	var required_emoji = str(quest.get("resource", ""))
	var required_qty = int(quest.get("quantity", 0))
	if required_emoji.is_empty() or required_qty <= 0:
		push_warning("Cannot complete quest %d: invalid delivery target" % quest_id)
		return false

	if economy == null:
		push_warning("QuestManager: economy not connected, cannot complete quest")
		return false

	# Fast resource check to avoid extra dictionary churn in tight rig loops.
	if economy.get_resource(required_emoji) < required_qty:
		push_warning("Cannot complete quest %d: insufficient resources" % quest_id)
		return false

	var faction_name = str(quest.get("faction", "Unknown"))

	# Resource reward: route through the live MarketLattice only.
	# If the lattice is unavailable, fail loudly and do not mutate the quest.
	var granted_resources: Dictionary = {}
	var lat = _get_farm_market_lattice()
	if lat == null or not lat.has_method("synthesize_and_exercise"):
		push_error("QuestManager: market lattice required for quest completion")
		return false

	var exer: Dictionary = lat.synthesize_and_exercise(required_emoji, faction_name)
	if not exer.get("ok", false):
		push_error("QuestManager: market lattice exercise failed for quest %d: %s" % [
			quest_id,
			str(exer.get("error", "unknown"))
		])
		return false

	if not economy.remove_resource(required_emoji, required_qty, "quest_completion"):
		var player_has = economy.get_resource(required_emoji)
		push_error("Failed to deduct resources for quest %d: need %d %s, have %d" % [quest_id, required_qty, required_emoji, player_has])
		return false

	var out_emoji: String = str(exer.get("outcome", required_emoji))
	granted_resources[out_emoji] = int(exer.get("classical_reward", 0))

	# Vocabulary and standing always go through their own paths.
	var player_icons2 = _get_signature_emojis()
	var reward = QuestRewards.generate_reward(quest, null, player_icons2)
	_grant_icon_rewards(reward, faction_name)
	_apply_standing_deltas(faction_name, reward.standing_deltas if reward else {})

	_finalize_quest_completion(quest_id, quest, reward, granted_resources)
	return true


func complete_or_claim(quest_id: int) -> bool:
	# Complete delivery quests or claim ready non-delivery quests.
	if not active_quests.has(quest_id):
		return false
	var quest = active_quests[quest_id]
	var quest_type = quest.get("type", QuestTypes.Type.DELIVERY)
	if quest_type == QuestTypes.Type.DELIVERY:
		return complete_quest(quest_id)
	# Non-delivery: must be ready
	if quest.get("status", "") == "ready":
		return claim_quest(quest_id)
	return false

# =============================================================================
# QUEST FAILURE
# =============================================================================

func fail_quest(quest_id: int, reason: String = "player_action") -> void:
	# Fail an active quest

	# Args:
	# quest_id: Quest to fail
	# reason: Why it failed (timeout, player_action, resource_shortage)
	if not active_quests.has(quest_id):
		return

	var quest = active_quests[quest_id]
	quest["status"] = "failed"
	quest["failed_at"] = Time.get_ticks_msec()
	quest["failure_reason"] = reason

	# Move to failed list
	active_quests.erase(quest_id)
	failed_quests.append(quest)

	# Stop timer
	_stop_quest_timer(quest_id)

	# Apply faction standing penalties for failure
	var fname: String = quest.get("faction", "")
	if fname != "":
		var failure_deltas: Dictionary = QuestRewards._standing_deltas_for_quest(quest, false)
		_apply_standing_deltas(fname, failure_deltas)

	quest_failed.emit(quest_id, reason)
	active_quests_changed.emit()


func _get_farm_market_lattice():
	var gsm = _get_gsm()
	var farm = gsm.get_active_farm() if gsm and gsm.has_method("get_active_farm") else null
	if farm == null:
		return null
	return farm.get_market_lattice() if farm.has_method("get_market_lattice") else null


func _apply_standing_deltas(faction_name: String, deltas: Dictionary) -> void:
	# Forward per-channel reputation deltas to the active Farm.
	# No-op if Farm or faction unavailable.
	if faction_name == "" or deltas == null or deltas.is_empty():
		return
	var gsm = _get_gsm()
	var farm = gsm.get_active_farm() if gsm and gsm.has_method("get_active_farm") else null
	if farm and farm.has_method("apply_standing_deltas"):
		farm.apply_standing_deltas(faction_name, deltas)


func _offer_from_market_lattice(biome) -> Array:
	# Delegate offer generation to the canonical MarketLattice substrate.
	# Returns pre-stamped quest dicts (sans id/offered_at — caller fills those).
	var gsm = _get_gsm()
	var farm = gsm.get_active_farm() if gsm and gsm.has_method("get_active_farm") else null
	if farm == null or not farm.has_method("get_market_lattice"):
		return []
	var lattice = farm.get_market_lattice()
	if lattice == null:
		return []
	# propose_offers returns MarketContract RefCounted objects; the pipeline projects each into
	# a canonical delivery quest (incl. the icon-pair vocab reward derivation).
	var contracts = lattice.propose_offers(biome, 196)
	var quests: Array = []
	for c in contracts:
		var quest := QuestPipeline.from_market_contract(c, biome)
		if not quest.is_empty():
			quests.append(quest)
	return quests

# =============================================================================
# QUEST READY/CLAIM (Non-delivery quests)
# =============================================================================

func mark_quest_ready(quest_id: int, completion_reason: String = "conditions_met") -> void:
	# Mark a non-delivery quest as ready to claim (conditions met)

	# The quest stays in active_quests but with status="ready".
	# Player must press Claim to receive rewards.
	if not active_quests.has(quest_id):
		return

	var quest = active_quests[quest_id]

	# Don't re-mark if already ready
	if quest.get("status") == "ready":
		return

	quest["status"] = "ready"
	quest["ready_at"] = Time.get_ticks_msec()
	quest["completion_reason"] = completion_reason

	quest_ready_to_claim.emit(quest_id)
	active_quests_changed.emit()


func claim_quest(quest_id: int) -> bool:
	# Claim rewards for a ready non-delivery quest

	# Returns:
	# true if claimed successfully
	if not active_quests.has(quest_id):
		push_error("Cannot claim quest %d: not active" % quest_id)
		return false

	var quest = active_quests[quest_id]

	# Must be in ready state
	if quest.get("status") != "ready":
		push_warning("Cannot claim quest %d: not ready (status=%s)" % [quest_id, quest.get("status", "?")])
		return false

	# Generate and grant rewards
	var player_icons = _get_signature_emojis()
	var reward = QuestRewards.generate_reward(quest, null, player_icons)
	var faction_name = quest.get("faction", "Unknown")
	var granted_resources = _grant_resource_rewards(reward, faction_name)
	_grant_icon_rewards(reward, faction_name)
	_apply_standing_deltas(faction_name, reward.standing_deltas if reward else {})

	_finalize_quest_completion(quest_id, quest, reward, granted_resources)
	return true


func reject_quest(quest_id: int) -> void:
	# Reject a ready quest without claiming rewards

	# Used when player doesn't want the rewards from a completed non-delivery quest.
	if not active_quests.has(quest_id):
		return

	var quest = active_quests[quest_id]

	# Must be in ready state to reject
	if quest.get("status") != "ready":
		push_warning("Cannot reject quest %d: not ready" % quest_id)
		return

	quest["status"] = "rejected"
	quest["rejected_at"] = Time.get_ticks_msec()

	# Move to failed list (rejected = voluntary failure)
	active_quests.erase(quest_id)
	failed_quests.append(quest)

	_stop_quest_timer(quest_id)

	quest_failed.emit(quest_id, "rejected")
	active_quests_changed.emit()


func is_quest_ready(quest_id: int) -> bool:
	# Check if a quest is ready to claim
	if not active_quests.has(quest_id):
		return false
	return active_quests[quest_id].get("status") == "ready"

# =============================================================================
# QUEST TIMERS
# =============================================================================

func _start_quest_timer(quest_id: int, duration: float) -> void:
	# Start countdown timer for quest
	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(_on_quest_timeout.bind(quest_id))

	add_child(timer)
	quest_timers[quest_id] = timer
	timer.start()

func _stop_quest_timer(quest_id: int) -> void:
	# Stop and remove quest timer
	if quest_timers.has(quest_id):
		var timer = quest_timers[quest_id]
		timer.stop()
		timer.queue_free()
		quest_timers.erase(quest_id)

func _on_quest_timeout(quest_id: int) -> void:
	# Handle quest timer expiration
	if active_quests.has(quest_id):
		fail_quest(quest_id, "timeout")
		quest_expired.emit(quest_id)

func get_quest_time_remaining(quest_id: int) -> float:
	# Get seconds remaining on quest timer

	# Returns:
	# -1 if no time limit or timer not found
	if not quest_timers.has(quest_id):
		return -1.0

	return quest_timers[quest_id].time_left

# =============================================================================
# QUEST TYPE TRACKING (non-delivery quests)
# =============================================================================

func _update_shape_achieve_quest(quest: Dictionary, _delta: float) -> void:
	var observable_name = quest.get("observable", "purity")
	var target_value := float(quest.get("target", 0.7))
	var comparison = quest.get("comparison", ">")

	var obs = get_biome_observables(current_biome)
	var current_value := float(obs.get(observable_name, 0.0))
	if not _is_known_observable_value(current_value):
		return

	var progress: float
	if comparison == "<":
		progress = QuestMath.soft_gate_inv(current_value, target_value)
	else:
		progress = QuestMath.soft_gate(current_value, target_value)
	quest["progress"] = progress
	if progress >= 0.9:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "target_achieved")


func _update_shape_maintain_quest(quest: Dictionary, delta: float) -> void:
	var observable_name = quest.get("observable", "purity")
	var target_value := float(quest.get("target", 0.7))
	var comparison = quest.get("comparison", ">")
	var required_duration := float(quest.get("duration", 30.0))

	var obs = get_biome_observables(current_biome)
	var current_value := float(obs.get(observable_name, 0.0))
	if not _is_known_observable_value(current_value):
		return

	var gate: float
	if comparison == "<":
		gate = QuestMath.soft_gate_inv(current_value, target_value)
	else:
		gate = QuestMath.soft_gate(current_value, target_value)

	# Accumulate when on-target; drain at equal rate when off-target.
	# Being "at the threshold" (gate=0.5) nets positive but slowly.
	quest["elapsed"] = QuestMath.smooth_accumulate(
			quest.get("elapsed", 0.0), gate, delta, 1.0)
	var progress: float = QuestMath.soft_gate(quest["elapsed"], required_duration * 0.9,
			required_duration * 0.05)
	quest["progress"] = progress
	if progress >= 0.9:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "maintained_duration")


func _update_evolution_quest(quest: Dictionary, _delta: float) -> void:
	var observable_name = quest.get("observable", "purity")
	var required_delta := float(quest.get("delta", 0.2))
	var direction = quest.get("direction", "increase")

	var obs = get_biome_observables(current_biome)
	var current_value := float(obs.get(observable_name, 0.0))
	if not _is_known_observable_value(current_value):
		return

	if quest.get("initial_value") == null:
		quest["initial_value"] = current_value
		return

	var actual_change := current_value - float(quest["initial_value"])
	var signed_change := actual_change if direction == "increase" else -actual_change
	var progress: float = QuestMath.soft_gate(signed_change, required_delta)
	quest["progress"] = progress
	if progress >= 0.9:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "evolution_achieved")


func _update_entanglement_quest(quest: Dictionary, _delta: float) -> void:
	var target_coherence := float(quest.get("target_coherence", 0.6))

	var obs = get_biome_observables(current_biome)
	var current_coherence := float(obs.get("coherence", 0.0))
	if not _is_known_observable_value(current_coherence):
		return

	var progress: float = QuestMath.soft_gate(current_coherence, target_coherence)
	quest["progress"] = progress
	if progress >= 0.9:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "entanglement_created")


func _update_achieve_eigenstate_quest(quest: Dictionary, _delta: float) -> void:
	var target_purity := float(quest.get("target_purity", 0.95))

	var obs = get_biome_observables(current_biome)
	var current_purity := float(obs.get("purity", 0.0))
	if not _is_known_observable_value(current_purity):
		return

	var purity_score := QuestMath.soft_gate(current_purity, target_purity)
	var attractor_score := 1.0
	var target_emoji: String = quest.get("target_emoji", "")
	if target_emoji != "" and current_biome and current_biome.has_method("get_attractor_state"):
		var attractor: Dictionary = current_biome.get_attractor_state()
		attractor_score = QuestMath.soft_gate(attractor.get(target_emoji, 0.0), 0.45, 0.05)
	var progress: float = QuestMath.smooth_and([purity_score, attractor_score])
	quest["progress"] = progress
	if progress >= 0.9:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "eigenstate_achieved")


func _update_maintain_coherence_quest(quest: Dictionary, delta: float) -> void:
	var target_coherence := float(quest.get("target_coherence", 0.5))
	var required_duration := float(quest.get("duration", 30.0))

	var obs = get_biome_observables(current_biome)
	var current_coherence := float(obs.get("coherence", 0.0))
	if not _is_known_observable_value(current_coherence):
		return

	var gate := QuestMath.soft_gate(current_coherence, target_coherence)
	quest["elapsed"] = QuestMath.smooth_accumulate(
			quest.get("elapsed", 0.0), gate, delta, 1.0)
	var progress: float = QuestMath.soft_gate(quest["elapsed"], required_duration * 0.9,
			required_duration * 0.05)
	quest["progress"] = progress
	if progress >= 0.9:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "coherence_maintained")


func _update_induce_bell_state_quest(quest: Dictionary, _delta: float) -> void:
	var target_pair = quest.get("target_pair", [])
	var threshold := float(quest.get("threshold", 0.7))

	if target_pair.size() < 2:
		return

	if not current_biome or not current_biome.quantum_computer:
		return

	var qc = current_biome.quantum_computer
	var coherence := 0.0
	if qc.has_method("get_coherence"):
		var coh = qc.get_coherence(target_pair[0], target_pair[1])
		coherence = coh.abs() if coh else 0.0

	var progress: float = QuestMath.soft_gate(coherence, threshold)
	quest["progress"] = progress
	if progress >= 0.9:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "bell_state_achieved")


func _update_prevent_decoherence_quest(quest: Dictionary, delta: float) -> void:
	# Track PREVENT_DECOHERENCE: accumulate survival time above min_purity.
	# Dropping below does NOT instantly fail — instead the elapsed bank drains
	# at 2× speed, so a purity crash costs twice the time it took to earn.
	# This removes the cliff edge while preserving the urgency.
	var min_purity := float(quest.get("min_purity", 0.5))
	var required_duration := float(quest.get("duration", 60.0))

	var obs = get_biome_observables(current_biome)
	var current_purity := float(obs.get("purity", 0.0))

	var gate := QuestMath.soft_gate(current_purity, min_purity)
	quest["elapsed"] = QuestMath.smooth_accumulate(
			quest.get("elapsed", 0.0), gate, delta, 2.0)
	var progress: float = QuestMath.soft_gate(quest["elapsed"], required_duration * 0.9,
			required_duration * 0.05)
	quest["progress"] = progress
	if progress >= 0.9:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "decoherence_prevented")


func _update_collapse_deliberately_quest(quest: Dictionary, _delta: float) -> void:
	var target_emoji = quest.get("target_emoji", "")
	var target_probability := float(quest.get("target_probability", 0.8))

	if target_emoji.is_empty():
		return

	if not current_biome or not current_biome.quantum_computer:
		return

	var qc = current_biome.quantum_computer
	var probability := 0.0
	if qc.has_method("get_population"):
		probability = qc.get_population(target_emoji)

	var purity: float = float(qc.get_purity()) if qc.has_method("get_purity") else 0.0

	var prob_score := QuestMath.soft_gate(probability, target_probability)
	var purity_score := QuestMath.soft_gate(purity, 0.8)
	var progress: float = QuestMath.smooth_and([prob_score, purity_score])
	quest["progress"] = progress
	if progress >= 0.9:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "state_collapsed")


# =============================================================================
# QUERY FUNCTIONS
# =============================================================================

func get_active_quest_count() -> int:
	# Get number of active quests
	return active_quests.size()


func _is_known_observable_value(value: float) -> bool:
	return value >= 0.0

func get_active_quests() -> Array:
	# Get all active quests as array
	return active_quests.values()


func get_story_offers() -> Array:
	# Get all pending story arc offers.
	return story_offers.values()


func dismiss_story_offer(quest_id: int) -> bool:
	# Remove a pending story arc offer from the current board view.
	if not story_offers.has(quest_id):
		return false
	story_offers.erase(quest_id)
	return true

func get_quest_by_id(quest_id: int) -> Dictionary:
	# Get quest data by ID (active quests first, then pending story offers).
	if active_quests.has(quest_id):
		return active_quests.get(quest_id, {})
	if story_offers.has(quest_id):
		return story_offers.get(quest_id, {})
	return {}

func has_active_quest_for_faction(faction_name: String) -> bool:
	# Check if there's an active quest from this faction
	for quest in active_quests.values():
		if quest.get("faction", "") == faction_name:
			return true
	return false

func get_completed_quest_count() -> int:
	# Get total completed quests
	return completed_quests.size()

func get_failed_quest_count() -> int:
	# Get total failed quests
	return failed_quests.size()

# =============================================================================
# DEBUG / TESTING
# =============================================================================

func clear_all_quests() -> void:
	# Clear all quest data (testing only)
	for quest_id in quest_timers.keys():
		_stop_quest_timer(quest_id)

	active_quests.clear()
	story_offers.clear()
	completed_quests.clear()
	failed_quests.clear()
	next_quest_id = 0
	_announced_offers.clear()
	active_quests_changed.emit()

func print_quest_status() -> void:
	# Print current quest state
	print("🗂️ Quest Manager Status:")
	print("  Active: %d" % active_quests.size())
	print("  Completed: %d" % completed_quests.size())
	print("  Failed: %d" % failed_quests.size())

	if active_quests.size() > 0:
		print("\n  Active Quests:")
		for quest_id in active_quests.keys():
			var quest = active_quests[quest_id]
			var time_left = get_quest_time_remaining(quest_id)
			var time_str = "∞" if time_left < 0 else "%ds" % int(time_left)
			print("    #%d: %s - %s (%s)" % [
				quest_id,
				quest.get("faction", "Unknown"),
				quest.get("body", quest.get("display", "???")),
				time_str
			])

static func test_quest_lifecycle() -> void:
	# Lifecycle smoke removed with the old offer surface.
	print("🧪 QuestManager lifecycle smoke retired; use live lattice tests instead.")
