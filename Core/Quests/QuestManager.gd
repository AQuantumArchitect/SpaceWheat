class_name QuestManager
extends Node

## Quest lifecycle management
## Handles offer → accept → complete/fail flow
## Integrates with FarmEconomy for resource checking

# Quest system dependency
const QuestGenerator = preload("res://Core/Quests/QuestGenerator.gd")
const QuestTheming = preload("res://Core/Quests/QuestTheming.gd")
const QuestTypes = preload("res://Core/Quests/QuestTypes.gd")
const QuestRewards = preload("res://Core/Quests/QuestRewards.gd")
const QuestMath = preload("res://Core/Quests/QuestMath.gd")
const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")
const FactionStateMatcher = preload("res://Core/QuantumSubstrate/FactionStateMatcher.gd")
const QuestStateProjectionService = preload("res://Core/Quests/QuestStateProjectionService.gd")
const PolicyGraph = preload("res://Core/AI/PolicyGraph.gd")
const InstrumentLocator = preload("res://Core/Instrumentation/InstrumentLocator.gd")

# Logging
@onready var _verbose = InstrumentLocator.resolve_verbose_config(self)

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
signal offer_locked(quest_id: int)
signal offer_unlocked(quest_id: int)
signal icon_learned(north: String, south: String, faction: String)

# =============================================================================
# STATE
# =============================================================================

var active_quests: Dictionary = {}  # quest_id -> quest_data (status: "active" or "ready")
var locked_offers: Dictionary = {}  # quest_id -> quest_data (status: "locked", persists across offer cycles)
var completed_quests: Array = []
var failed_quests: Array = []
var next_quest_id: int = 0

# Quest timers
var quest_timers: Dictionary = {}  # quest_id -> Timer

# References (set via dependency injection)
var economy: Node = null
var faction_manager: Node = null
var current_biome: Node = null  # For tracking non-delivery quest progress
var _biome_offer_counts: Dictionary = {}
var _non_native_resonance_factor: float = 0.8  # from biome_economics.non_native_resonance_factor
var _biome_config: Dictionary = {}  # Resolved biome_economics from PolicyGraph — passed to QuestTheming resonance gate
var _state_projection: QuestStateProjectionService = QuestStateProjectionService.new()
var _story_flags: Array = []    # All flag definitions loaded from story_flags.json
var _unfired_flags: Array = []  # Subset not yet in farm.story_flags_fired

# =============================================================================
# CONFIGURATION
# =============================================================================

const MAX_ACTIVE_QUESTS: int = 5
const MAX_LOCKED_OFFERS: int = 3
const QUEST_OFFER_COOLDOWN: float = 30.0  # Seconds between new quest offers
const AUTO_FAIL_ON_RESOURCE_SHORTAGE: bool = true

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	set_physics_process(true)  # Enable for quest tracking
	_load_story_flags()

func _physics_process(delta: float) -> void:
	var t0 = Time.get_ticks_usec()
	# Update quest progress for non-delivery quests
	if current_biome == null:
		return
	if _state_projection:
		_state_projection.observe_biome(current_biome, delta)
	_evaluate_story_flags()

	for quest in active_quests.values():
		# Skip quests already ready to claim
		if quest.get("status") == "ready":
			continue
		if _state_projection and quest.get("state_predicates", []) is Array:
			var predicates = quest.get("state_predicates", [])
			var pred_score := _state_projection.evaluate_all(predicates)
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
			QuestTypes.Type.STEER_TO_ATTRACTOR:
				_update_steer_to_attractor_quest(quest, delta)
			QuestTypes.Type.HEAL_ATTRACTOR:
				_update_heal_attractor_quest(quest, delta)
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
	# Re-inject arc quests for flags that already fired (restores LEDGER after save/load).
	for flag in _story_flags:
		var flag_id := str(flag.get("id", ""))
		if not farm.story_flags_fired.has(flag_id):
			continue
		var arc_quest = flag.get("arc_quest")
		if not (arc_quest is Dictionary) or arc_quest.is_empty():
			continue
		# Only re-inject if not already present (check by source_flag).
		var already: bool = false
		for existing in locked_offers.values():
			if str(existing.get("source_flag", "")) == flag_id:
				already = true
				break
		if not already:
			inject_arc_quest(flag_id, arc_quest)


## Story-flag firing threshold: _evaluate_flag_predicates() must reach this.
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
			var phase := biome.quantum_computer.berry_register.get_consumed_phase()
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
			var marginal := biome.quantum_computer.get_marginal(qubit, pole)
			return QuestMath.soft_gate(marginal, float(pred.get("value", 0.0)))
		"signature_size_gte":
			return QuestMath.soft_gate(float(farm.known_pairs.size()), float(pred.get("value", 0)), 2.0)
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
			var trend := biome.predict_purity(steps) - biome.get_purity()
			return QuestMath.soft_gate(trend, 0.01, 0.02)
		_:
			return 0.0


func _fire_story_flag(flag: Dictionary, farm) -> void:
	var flag_id := str(flag.get("id", ""))
	if flag_id == "" or farm.story_flags_fired.has(flag_id):
		return

	# Resolve arc beat (flag 6 has conditional_beat based on which atoms are present)
	var beat := _resolve_arc_beat(flag, farm)

	# Write to farm
	farm.story_flags_fired[flag_id] = Engine.get_physics_frames()
	farm.story_log.append({
		"id": flag_id,
		"act": int(flag.get("act", 0)),
		"display_name": str(flag.get("display_name", flag_id)),
		"arc_beat": beat,
		"fired_at": Engine.get_physics_frames(),
	})

	# Standing grants
	var grants: Dictionary = flag.get("standing_grants", {})
	for faction_name in grants:
		farm.apply_standing_deltas(faction_name, grants[faction_name])

	# Arc quest injection (stub: adds to locked_offers as a non-expiring quest)
	var arc_quest = flag.get("arc_quest")
	if arc_quest is Dictionary and not arc_quest.is_empty():
		inject_arc_quest(flag_id, arc_quest)

	# Remove from unfired list
	_unfired_flags.erase(flag)

	# Notify StoryEngine substrate (records system advance into trajectory log,
	# biases density toward the just-fired node).
	var story_engine = get_node_or_null("/root/StoryEngine")
	if story_engine != null and story_engine.has_method("on_flag_fired"):
		story_engine.on_flag_fired(flag_id)

	if _verbose:
		_verbose.info("quest", "📖", "Story flag fired: %s (act %d)" % [flag_id, int(flag.get("act", 0))])


func _resolve_arc_beat(flag: Dictionary, farm) -> String:
	var conditional: Array = flag.get("conditional_beat", [])
	if conditional.is_empty():
		return str(flag.get("arc_beat", ""))
	# Check Village atoms to find matching condition
	if farm.grid != null:
		var biome = farm.grid.get_biome("Village")
		if biome != null and biome.get("quantum_computer"):
			var reg = biome.quantum_computer.get("register_map")
			if reg != null:
				for entry in conditional:
					var atom := str(entry.get("atom", ""))
					if atom != "" and reg.coordinates.has(atom):
						return str(entry.get("text", ""))
	return str(flag.get("arc_beat", ""))


func inject_arc_quest(flag_id: String, quest_def: Dictionary) -> void:
	# Add a non-expiring arc quest from a story flag definition.
	if quest_def.is_empty():
		return
	# If the arc quest is a STEER_TO_ATTRACTOR, enrich it with live attractor data
	# so the target emoji and body text reflect the biome's current physics.
	if str(quest_def.get("type", "")) == "STEER_TO_ATTRACTOR":
		var farm = _get_active_farm()
		if farm and farm.grid:
			var biome_name := str(quest_def.get("biome", ""))
			var biome = farm.grid.get_biome(biome_name) if biome_name != "" else null
			if biome and biome.has_method("get_attractor_state"):
				var attractor: Dictionary = biome.get_attractor_state()
				var top_emoji: String = attractor.get("emojis", [""])[0] if attractor.get("emojis", []).size() > 0 else ""
				if top_emoji != "":
					quest_def = quest_def.duplicate()
					quest_def["target_emoji"] = top_emoji
					quest_def["snapshot_attractor"] = attractor
					if not quest_def.has("body") or quest_def["body"] == "":
						quest_def["body"] = "The %s is finding its shape: %s. Help it settle." % [biome_name, top_emoji]
	var quest_id := next_quest_id
	next_quest_id += 1
	var quest := {
		"id": quest_id,
		"category": "ARC",
		"type": quest_def.get("type", "DELIVER"),
		"body": str(quest_def.get("body", "")),
		"hint": str(quest_def.get("hint", "")),
		"source_flag": flag_id,
		"status": "locked",
		"expires": false,
	}
	locked_offers[quest_id] = quest
	offer_locked.emit(quest_id)


func _get_gsm():
	return InstrumentLocator.resolve_game_state_manager(self)


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


func _discover_vocab_pair(north: String, south: String) -> bool:
	# Grant an icon to the player (farm-owned preferred).

	# Returns true if signature was newly discovered, false if already known.
	var gsm = _get_gsm()
	var active_farm = gsm.get_active_farm() if gsm and gsm.has_method("get_active_farm") else null
	if active_farm and active_farm.has_method("discover_pair"):
		return active_farm.discover_pair(north, south)
	elif gsm and gsm.player_progress:
		return gsm.player_progress.discover_pair(north, south)
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


func _grant_vocabulary_rewards(reward, faction_name: String) -> void:
	# Grant icon rewards and emit discovery signals.
	if reward == null:
		return

	# Paired signature is preferred (north/south axis)
	for pair in reward.learned_pairs:
		var north = pair.get("north", "")
		var south = pair.get("south", "")
		if north == "" or south == "":
			continue
		var was_new = _discover_vocab_pair(north, south)
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


func _get_simulated_vocab_emojis(biome: Node) -> Array:
	if not biome or not biome.has_method("get"):
		return []
	var qc = biome.get("quantum_computer")
	if not qc or not qc.has_method("get"):
		return []
	var rm = qc.get("register_map")
	if not rm:
		return []
	var coords = rm.get("coordinates") if rm.has_method("get") else null
	if coords is Dictionary:
		return coords.keys()
	return []

# =============================================================================
# QUEST OFFERING
# =============================================================================

func _stamp_offered_quest(quest: Dictionary) -> void:
	# Stamp status, timestamp, and emit offer signal. Called at end of all offer paths.
	quest["status"] = "offered"
	quest["offered_at"] = Time.get_ticks_msec()
	quest_offered.emit(quest)


func offer_quest(faction: Dictionary, biome_name: String, resources: Array) -> Dictionary:
	# Generate and offer a new quest

	# Returns:
	# Quest data with unique ID, or empty dict if offer failed
	if active_quests.size() >= MAX_ACTIVE_QUESTS:
		push_warning("Cannot offer quest: max active quests reached (%d)" % MAX_ACTIVE_QUESTS)
		return {}

	# Generate quest
	var quest = QuestGenerator.generate_quest(faction, biome_name, resources)
	if quest.is_empty():
		return {}
	if not _is_valid_offer(quest):
		return {}

	quest = _annotate_quest_context(quest, biome_name)

	# Assign unique ID
	quest["id"] = next_quest_id
	next_quest_id += 1

	_stamp_offered_quest(quest)
	return quest

func offer_emoji_quest(faction: Dictionary, biome_name: String, resources: Array) -> Dictionary:
	# Generate and offer emoji-only quest
	if active_quests.size() >= MAX_ACTIVE_QUESTS:
		return {}

	var quest = QuestGenerator.generate_emoji_quest(faction, biome_name, resources)
	if quest.is_empty():
		return {}
	if not _is_valid_offer(quest):
		return {}

	quest["id"] = next_quest_id
	next_quest_id += 1
	_stamp_offered_quest(quest)
	return quest

# =============================================================================
# EMERGENT QUEST OFFERING (Quantum x Faction)
# =============================================================================

func offer_quest_emergent(faction: Dictionary, biome) -> Dictionary:
	# Generate quest using emergent faction x biome multiplication

	# This is the quantum approach: faction state-shape preferences are
	# matched against biome quantum observables to generate quests.
	# Respects player signature for resource constraints!

	if active_quests.size() >= MAX_ACTIVE_QUESTS:
		return {}

	# Get player signature for filtering
	var player_vocab = _get_signature_emojis()
	var bias_emojis = _get_simulated_vocab_emojis(biome)

	# Opportunistically offer a STEER_TO_ATTRACTOR quest if the biome has a stable attractor.
	# This surfaces physics-guided quests alongside the standard faction-vocabulary quests.
	var attractor_quest := _maybe_offer_attractor_quest(faction, biome)
	if not attractor_quest.is_empty() and _is_valid_offer(attractor_quest):
		attractor_quest["id"] = next_quest_id
		next_quest_id += 1
		attractor_quest["biome"] = biome.biome_name if biome and biome.get("biome_name") else "Unknown"
		_stamp_offered_quest(attractor_quest)
		# Fall through: still generate a regular quest too (both can coexist)

	# Rarely (~1-in-6 chance), offer a HEAL_ATTRACTOR quest instead: perturb the biome
	# and challenge the player to restore it.  Low probability keeps it dramatic.
	if randi() % 6 == 0:
		var heal_quest := _maybe_offer_heal_quest(faction, biome)
		if not heal_quest.is_empty() and _is_valid_offer(heal_quest):
			heal_quest["id"] = next_quest_id
			next_quest_id += 1
			heal_quest["biome"] = biome.biome_name if biome and biome.get("biome_name") else "Unknown"
			_stamp_offered_quest(heal_quest)

	# Generate via abstract machinery + theming (with signature constraint!)
	var quest = QuestTheming.generate_quest(faction, biome, player_vocab, bias_emojis, self.economy, null, null, _biome_config)

	# Check for signature mismatch error
	if quest.is_empty() or quest.has("error"):
		return {}  # Faction inaccessible - no signature overlap
	if not _is_valid_offer(quest):
		return {}

	var biome_name = biome.biome_name if biome and biome.get("biome_name") else ""
	quest = _annotate_quest_context(quest, biome_name)

	# Assign ID and metadata
	quest["id"] = next_quest_id
	next_quest_id += 1
	quest["biome"] = biome.biome_name if biome and biome.get("biome_name") else "Unknown"

	# Generate display text
	quest["body"] = QuestTheming.generate_display_text(quest)
	if quest.time_limit > 0:
		quest["full_text"] = "%s wants: %s in %ds" % [quest.faction, quest.body, int(quest.time_limit)]
	else:
		quest["full_text"] = "%s wants: %s" % [quest.faction, quest.body]

	_stamp_offered_quest(quest)
	return quest


func _maybe_offer_attractor_quest(faction: Dictionary, biome) -> Dictionary:
	# Offer a STEER_TO_ATTRACTOR quest when the biome has a stable, strong attractor.
	# Called opportunistically from offer_quest_emergent; returns {} if conditions not met.
	if not biome or not biome.has_method("get_attractor_state"):
		return {}
	var attractor: Dictionary = biome.get_attractor_state()
	if attractor.is_empty():
		return {}
	var dominant_ev: float = attractor.get("dominant_eigenvalue", 0.0)
	var gap: float = attractor.get("eigenvalue_gap", 0.0)
	# Soft gate: offer probability rises smoothly as attractor strengthens.
	# Below combined score of 0.5 the offer is suppressed — too weak to aim at.
	var offer_gate := QuestMath.smooth_and([
		QuestMath.soft_gate(dominant_ev, 0.6, 0.05),
		QuestMath.soft_gate(gap, 0.08, 0.02),
	])
	if offer_gate < 0.5:
		return {}
	var emojis: Array = attractor.get("emojis", [])
	if emojis.is_empty():
		return {}
	var top_emoji: String = emojis[0]
	var biome_name: String = biome.biome_name if biome.get("biome_name") else "biome"
	var quest := {
		"type": QuestTypes.Type.STEER_TO_ATTRACTOR,
		"faction": faction.get("name", "Unknown"),
		"faction_emoji": "".join(faction.get("sig", []).slice(0, 3)),
		"target_emoji": top_emoji,
		"target_attractor_prob": 0.55,
		"target_gap": 0.10,
		"target_purity": 0.75,
		"snapshot_attractor": attractor,
		"body": "The %s is reaching for %s. Help it complete the loop." % [biome_name, top_emoji],
		"hint": "Guide the biome's dominant state — high purity and a strong attractor both matter.",
		"reward_multiplier": 1.5 + clampf(gap, 0.0, 0.5),
		"time_limit": -1.0,
		"expires": false,
	}
	return quest


func _annotate_quest_context(quest: Dictionary, biome_name: String) -> Dictionary:
	return _annotate_quest_context_with_vocab(quest, biome_name, _get_signature_emojis())


func _annotate_quest_context_with_vocab(quest: Dictionary, biome_name: String, known: Array) -> Dictionary:
	if not quest:
		return quest
	var biome_new = _track_biome_offer(biome_name)
	quest["biome_new"] = biome_new
	var north = quest.get("reward_north", "")
	var south = quest.get("reward_south", "")
	quest["contains_new_vocab"] = not (north in known and south in known)
	quest["biome_name"] = biome_name
	_apply_market_projection(quest)
	return quest


func _track_biome_offer(biome_name: String) -> bool:
	if biome_name == "":
		return false
	var count = int(_biome_offer_counts.get(biome_name, 0))
	var is_new = count < 1
	_biome_offer_counts[biome_name] = count + 1
	return is_new


func offer_all_faction_quests(biome) -> Array:
	# Generate quests for the current biome.

	# Quests come from the native ContractMarket: it reads the current mythos
	# substrate (faction density, principal mode, biome native factions, player
	# economy) and proposes bids that QuestManager wraps into the lifecycle.

	# Locked offers are prepended (persist across cycles).
	var quests: Array = []
	for quest in locked_offers.values():
		quests.append(quest)

	var now_ms: int = Time.get_ticks_msec()
	for quest in _offer_from_contract_market(biome):
		quest["id"] = next_quest_id
		next_quest_id += 1
		quest["offered_at"] = now_ms
		quests.append(quest)
	return quests


func record_quantum_action(action_name: String, payload: Dictionary = {}) -> void:
	if not _state_projection:
		return
	_state_projection.record_action(action_name, payload)


func get_state_projection_snapshot() -> Dictionary:
	if not _state_projection:
		return {}
	return _state_projection.get_snapshot()


func _is_valid_offer(quest: Dictionary) -> bool:
	# Reject broken offers (delivery with no resource/qty, north duplicate).
	return _is_valid_offer_with_vocab(quest, _get_signature_emojis())


func _is_valid_offer_with_vocab(quest: Dictionary, player_vocab: Array) -> bool:
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
	var has_vocab_pair = (north != "" and south != "")
	var has_no_vocab = (north == "" and south == "")
	if not has_vocab_pair and not has_no_vocab:
		return false
	if has_vocab_pair and north in player_vocab:
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
	# quantity is already in credits (10-150 range from QuestTheming)
	var player_amount = economy.get_resource(required_emoji)
	return player_amount >= required_qty

func _finalize_quest_completion(quest_id: int, quest: Dictionary, reward, granted_resources: Dictionary) -> void:
	# Stamp completion fields, move quest to completed list, emit signals.
	quest["status"] = "completed"
	quest["completed_at"] = Time.get_ticks_msec()
	quest["reward"] = reward
	active_quests.erase(quest_id)
	completed_quests.append(quest)
	_stop_quest_timer(quest_id)
	quest_completed.emit(quest_id, _build_reward_payload(reward, granted_resources))
	active_quests_changed.emit()


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

	if not economy.remove_resource(required_emoji, required_qty, "quest_completion"):
		var player_has = economy.get_resource(required_emoji)
		push_error("Failed to deduct resources for quest %d: need %d %s, have %d" % [quest_id, required_qty, required_emoji, player_has])
		return false

	var faction_name = str(quest.get("faction", "Unknown"))

	# Resource reward: route through MarketLattice.exercise for substrate-derived
	# 1/p × QC_RATIO reward. Falls back to fixed QuestRewards path if no market
	# connection (biome not live, headless rig, etc.).
	var granted_resources: Dictionary = {}
	var lat = _get_farm_market_lattice()
	if lat != null:
		lat.synthesize_and_exercise(required_emoji, faction_name)
		# synthesize_and_exercise already deposited the reward into economy
	else:
		var player_vocab = _get_signature_emojis()
		var reward_fallback = QuestRewards.generate_reward(quest, null, player_vocab)
		granted_resources = _grant_resource_rewards(reward_fallback, faction_name)

	# Vocabulary and standing always go through their own paths.
	var player_vocab2 = _get_signature_emojis()
	var reward = QuestRewards.generate_reward(quest, null, player_vocab2)
	_grant_vocabulary_rewards(reward, faction_name)
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


func _offer_from_contract_market(biome) -> Array:
	# Delegate offer generation to the native ContractMarket substrate.
	# Returns pre-stamped quest dicts (sans id/offered_at — caller fills those).
	var farm = _get_gsm().get_active_farm()
	return farm._ensure_contract_market().propose_offers(biome, 2)

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
	var player_vocab = _get_signature_emojis()
	var reward = QuestRewards.generate_reward(quest, null, player_vocab)
	var faction_name = quest.get("faction", "Unknown")
	var granted_resources = _grant_resource_rewards(reward, faction_name)
	_grant_vocabulary_rewards(reward, faction_name)
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

func _update_shape_achieve_quest(quest: Dictionary, delta: float) -> void:
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
	var progress := QuestMath.soft_gate(quest["elapsed"], required_duration * 0.9,
			required_duration * 0.05)
	quest["progress"] = progress
	if progress >= 0.9:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "maintained_duration")


func _update_evolution_quest(quest: Dictionary, delta: float) -> void:
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
	var progress := QuestMath.soft_gate(signed_change, required_delta)
	quest["progress"] = progress
	if progress >= 0.9:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "evolution_achieved")


func _update_entanglement_quest(quest: Dictionary, delta: float) -> void:
	var target_coherence := float(quest.get("target_coherence", 0.6))

	var obs = get_biome_observables(current_biome)
	var current_coherence := float(obs.get("coherence", 0.0))
	if not _is_known_observable_value(current_coherence):
		return

	var progress := QuestMath.soft_gate(current_coherence, target_coherence)
	quest["progress"] = progress
	if progress >= 0.9:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "entanglement_created")


func _update_achieve_eigenstate_quest(quest: Dictionary, delta: float) -> void:
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
	var progress := QuestMath.smooth_and([purity_score, attractor_score])
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
	var progress := QuestMath.soft_gate(quest["elapsed"], required_duration * 0.9,
			required_duration * 0.05)
	quest["progress"] = progress
	if progress >= 0.9:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "coherence_maintained")


func _update_induce_bell_state_quest(quest: Dictionary, delta: float) -> void:
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

	var progress := QuestMath.soft_gate(coherence, threshold)
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
	var progress := QuestMath.soft_gate(quest["elapsed"], required_duration * 0.9,
			required_duration * 0.05)
	quest["progress"] = progress
	if progress >= 0.9:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "decoherence_prevented")


func _update_collapse_deliberately_quest(quest: Dictionary, delta: float) -> void:
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

	var purity := qc.get_purity() if qc.has_method("get_purity") else 0.0

	var prob_score := QuestMath.soft_gate(probability, target_probability)
	var purity_score := QuestMath.soft_gate(purity, 0.8)
	var progress := QuestMath.smooth_and([prob_score, purity_score])
	quest["progress"] = progress
	if progress >= 0.9:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "state_collapsed")


func _update_steer_to_attractor_quest(quest: Dictionary, _delta: float) -> void:
	if not current_biome or not current_biome.has_method("get_attractor_state"):
		return
	var attractor: Dictionary = current_biome.get_attractor_state()
	if attractor.is_empty():
		return
	var emoji: String = quest.get("target_emoji", "")
	var progress := QuestMath.smooth_and([
		QuestMath.soft_gate(attractor.get(emoji, 0.0),
				float(quest.get("target_attractor_prob", 0.55))),
		QuestMath.soft_gate(attractor.get("eigenvalue_gap", 0.0),
				float(quest.get("target_gap", 0.10)), 0.02),
		QuestMath.soft_gate(current_biome.get_purity(),
				float(quest.get("target_purity", 0.75))),
	])
	quest["progress"] = progress
	if progress >= 0.9:
		mark_quest_ready(quest.get("id", -1), "attractor_achieved")


func _update_heal_attractor_quest(quest: Dictionary, _delta: float) -> void:
	if not current_biome or not current_biome.has_method("get_attractor_state"):
		return
	var attractor: Dictionary = current_biome.get_attractor_state()
	if attractor.is_empty():
		return
	var emoji: String = quest.get("target_emoji", "")
	var progress := QuestMath.smooth_and([
		QuestMath.soft_gate(attractor.get(emoji, 0.0),
				float(quest.get("target_attractor_prob", 0.50))),
		QuestMath.soft_gate(attractor.get("eigenvalue_gap", 0.0),
				float(quest.get("target_gap", 0.10)), 0.02),
		QuestMath.soft_gate(current_biome.get_purity(),
				float(quest.get("target_purity", 0.70))),
	])
	quest["progress"] = progress
	if progress >= 0.9:
		mark_quest_ready(quest.get("id", -1), "attractor_healed")


func _maybe_offer_heal_quest(faction: Dictionary, biome) -> Dictionary:
	# Perturb the biome and offer a HEAL_ATTRACTOR quest to fix it.
	# Only fires when the biome has a strong, readable attractor — we need a
	# concrete target for the player to aim at after the perturbation lands.
	if not biome or not biome.has_method("get_attractor_state"):
		return {}
	var attractor: Dictionary = biome.get_attractor_state()
	if attractor.is_empty():
		return {}
	var dominant_ev: float = attractor.get("dominant_eigenvalue", 0.0)
	var gap: float = attractor.get("eigenvalue_gap", 0.0)
	# Require a very confident attractor before perturbing — the target must be
	# unambiguous or the healing quest becomes impossible.  Soft gate so biomes
	# approaching the threshold have a chance rather than a cliff edge.
	var offer_gate := QuestMath.smooth_and([
		QuestMath.soft_gate(dominant_ev, 0.65, 0.04),
		QuestMath.soft_gate(gap, 0.10, 0.02),
	])
	if offer_gate < 0.6:
		return {}
	var emojis: Array = attractor.get("emojis", [])
	if emojis.is_empty():
		return {}
	var top_emoji: String = emojis[0]
	var biome_name: String = biome.biome_name if biome.get("biome_name") else "biome"

	# Apply the perturbation — this physically modifies the quantum state.
	# The quest is now live: the player must restore what was just scattered.
	var qc = biome.get("quantum_computer")
	if qc == null or not qc.has_method("apply_perturbation"):
		return {}
	var perturb_result: Dictionary = qc.apply_perturbation(0.85)
	if perturb_result.is_empty():
		return {}

	var quest := {
		"type": QuestTypes.Type.HEAL_ATTRACTOR,
		"faction": faction.get("name", "Unknown"),
		"faction_emoji": "".join(faction.get("sig", []).slice(0, 3)),
		"target_emoji": top_emoji,
		"target_attractor_prob": 0.50,
		"target_gap": 0.10,
		"target_purity": 0.70,
		"snapshot_attractor": attractor,
		"perturbation_strength": 0.85,
		"body": "The %s was scattered — %s dispersed. Help it remember itself." % [biome_name, top_emoji],
		"hint": "The Hamiltonian remembers. Feed it, wait, or gate it back.",
		"reward_multiplier": 2.0 + clampf(gap, 0.0, 0.5),
		"time_limit": -1.0,
		"expires": false,
	}
	return quest


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

# =============================================================================
# QUEST LOCKING (pin offers across cycles)
# =============================================================================

func lock_offer(quest_data: Dictionary) -> bool:
	# Lock an offered quest so it persists across offer cycles.
	# Returns false if at capacity, missing id, or already locked/active.
	if locked_offers.size() >= MAX_LOCKED_OFFERS:
		return false
	if not quest_data.has("id"):
		return false
	var quest_id = int(quest_data["id"])
	if locked_offers.has(quest_id) or active_quests.has(quest_id):
		return false
	quest_data["status"] = "locked"
	quest_data["locked_at"] = Time.get_ticks_msec()
	locked_offers[quest_id] = quest_data
	offer_locked.emit(quest_id)
	return true


func unlock_offer(quest_id: int) -> bool:
	# Release a locked offer (it disappears).
	if not locked_offers.has(quest_id):
		return false
	locked_offers.erase(quest_id)
	offer_unlocked.emit(quest_id)
	return true


func get_locked_offers() -> Array:
	# Return all currently locked offers.
	return locked_offers.values()


func accept_locked_offer(quest_id: int) -> bool:
	# Accept a locked offer — moves it from locked → active.
	if not locked_offers.has(quest_id):
		return false
	var quest = locked_offers[quest_id]
	locked_offers.erase(quest_id)
	return accept_quest(quest)


func get_quest_by_id(quest_id: int) -> Dictionary:
	# Get quest data by ID (active quests only)
	return active_quests.get(quest_id, {})

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
	locked_offers.clear()
	completed_quests.clear()
	failed_quests.clear()
	next_quest_id = 0
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
	# Test quest manager with sample quest
	print("🧪 Testing QuestManager lifecycle...")

	var QuestManagerClass = load("res://Core/Quests/QuestManager.gd")
	var manager = QuestManagerClass.new()

	# Mock economy
	var mock_economy = Node.new()
	mock_economy.set_script(load("res://Core/GameMechanics/FarmEconomy.gd"))
	manager.connect_to_economy(mock_economy)

	# Create test faction
	var faction = {
		"name": "Millwright's Union",
		"bits": [1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1],
		"emoji": "🌾⚙️🏭"
	}

	# Offer quest
	var quest = manager.offer_quest(faction, "BioticFlux", ["🌾", "🍄"])
	print("✓ Quest offered: ID %d" % quest["id"])

	# Accept quest
	var accepted = manager.accept_quest(quest)
	print("✓ Quest accepted: %s" % str(accepted))

	# Check status
	manager.print_quest_status()

	print("\n✅ QuestManager test complete")
