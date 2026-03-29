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
const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")
const FactionStateMatcher = preload("res://Core/QuantumSubstrate/FactionStateMatcher.gd")
const FactionDatabase = preload("res://Core/Quests/FactionDatabaseV2.gd")
const QuestStateProjectionService = preload("res://Core/Quests/QuestStateProjectionService.gd")

# Logging
@onready var _verbose = get_node("/root/VerboseConfig")

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
signal vocabulary_learned(emoji: String, faction: String)
signal vocabulary_pair_learned(north: String, south: String, faction: String)

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
var _state_projection: QuestStateProjectionService = QuestStateProjectionService.new()

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

func _physics_process(delta: float) -> void:
	var t0 = Time.get_ticks_usec()
	"""Update quest progress for non-delivery quests"""
	if current_biome == null:
		return
	if _state_projection:
		_state_projection.observe_biome(current_biome, delta)

	for quest in active_quests.values():
		# Skip quests already ready to claim
		if quest.get("status") == "ready":
			continue
		if _state_projection and quest.get("state_predicates", []) is Array:
			var predicates = quest.get("state_predicates", [])
			if _state_projection.evaluate_all(predicates):
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
	"""Inject economy dependency"""
	economy = econ

func connect_to_faction_manager(fm: Node) -> void:
	"""Inject faction manager dependency"""
	faction_manager = fm

func connect_to_biome(biome: Node) -> void:
	"""Inject biome dependency for quest tracking"""
	current_biome = biome


func _get_gsm():
	"""Get GameStateManager singleton safely (supports headless tests)."""
	var tree = get_tree()
	if tree and tree.root:
		return tree.root.get_node_or_null("/root/GameStateManager")
	return null


func _get_player_vocab_emojis() -> Array:
	"""Get player-known emojis (farm-owned preferred)."""
	var gsm = _get_gsm()
	if gsm and gsm.has_method("get_player_vocab_emojis"):
		return gsm.get_player_vocab_emojis()
	return []


func _discover_vocab_pair(north: String, south: String) -> bool:
	"""Grant a vocab pair to the player (farm-owned preferred).

	Returns true if vocabulary was newly discovered, false if already known.
	"""
	var gsm = _get_gsm()
	if gsm and "active_farm" in gsm and gsm.active_farm and gsm.active_farm.has_method("discover_pair"):
		return gsm.active_farm.discover_pair(north, south)
	elif gsm and gsm.has_method("discover_pair"):
		return gsm.discover_pair(north, south)
	return false


func _grant_resource_rewards(reward, faction_name: String) -> Dictionary:
	"""Grant resource rewards to economy and return granted payload."""
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
	"""Grant vocabulary rewards and emit discovery signals."""
	if reward == null:
		return

	# Paired vocabulary is preferred (north/south axis)
	for pair in reward.learned_pairs:
		var north = pair.get("north", "")
		var south = pair.get("south", "")
		if north == "" or south == "":
			continue
		var was_new = _discover_vocab_pair(north, south)
		if was_new:
			vocabulary_pair_learned.emit(north, south, faction_name)
			vocabulary_learned.emit(north, faction_name)
			vocabulary_learned.emit(south, faction_name)
			if _verbose:
				_verbose.info("quest", "📖", "%s taught you: %s/%s axis" % [faction_name, north, south])
		else:
			if _verbose:
				_verbose.debug("quest", "📖", "%s tried to teach %s/%s but you already know it" % [faction_name, north, south])


func _build_reward_payload(reward, granted_resources: Dictionary) -> Dictionary:
	"""Convert reward object to plain dictionary for UI/signals."""
	var payload: Dictionary = {
		"resource_rewards": granted_resources.duplicate(true),
		"learned_vocabulary": [],
		"learned_pairs": [],
		"bonus_multiplier": 1.0,
		"money_amount": 0
	}
	if reward == null:
		return payload
	payload["learned_vocabulary"] = reward.learned_vocabulary.duplicate()
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
	"""Stamp status, timestamp, and emit offer signal. Called at end of all offer paths."""
	quest["status"] = "offered"
	quest["offered_at"] = Time.get_ticks_msec()
	quest_offered.emit(quest)


func offer_quest(faction: Dictionary, biome_name: String, resources: Array) -> Dictionary:
	"""Generate and offer a new quest

	Returns:
		Quest data with unique ID, or empty dict if offer failed
	"""
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
	"""Generate and offer emoji-only quest"""
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
	"""Generate quest using emergent faction x biome multiplication

	This is the quantum approach: faction state-shape preferences are
	matched against biome quantum observables to generate quests.
	Respects player vocabulary for resource constraints!
	"""

	if active_quests.size() >= MAX_ACTIVE_QUESTS:
		return {}

	# Get player vocabulary for filtering
	var player_vocab = _get_player_vocab_emojis()
	var bias_emojis = _get_simulated_vocab_emojis(biome)

	# Generate via abstract machinery + theming (with vocabulary constraint!)
	var quest = QuestTheming.generate_quest(faction, biome, player_vocab, bias_emojis, self.economy)

	# Check for vocabulary mismatch error
	if quest.is_empty() or quest.has("error"):
		return {}  # Faction inaccessible - no vocabulary overlap
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


func _annotate_quest_context(quest: Dictionary, biome_name: String) -> Dictionary:
	return _annotate_quest_context_with_vocab(quest, biome_name, _get_player_vocab_emojis())


func _annotate_quest_context_with_vocab(quest: Dictionary, biome_name: String, known: Array) -> Dictionary:
	if not quest:
		return quest
	var biome_new = _track_biome_offer(biome_name)
	quest["biome_new"] = biome_new
	var north = quest.get("reward_vocab_north", "")
	var south = quest.get("reward_vocab_south", "")
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
	"""Generate quests from ALL factions for current biome state

	Called when player opens quest overlay. Returns array of quest offers
	from all factions, each with alignment score based on biome state.
	Respects player vocabulary - inaccessible factions are filtered out.
	Locked offers are prepended (persist across cycles).
	"""
	var quests = []

	# Locked offers come first (persist across cycles)
	for quest in locked_offers.values():
		quests.append(quest)

	# Pre-compute shared data ONCE for all 89 factions:
	# - player_vocab: was fetched 3× per faction (generate, validate, annotate) = 267 GSM walks
	# - observables: O(dim²) coherence calc, same bath for every faction
	# - icon_map: GSM→farm→batcher tree walk, same result every time
	var player_vocab = _get_player_vocab_emojis()
	var bias_emojis = _get_simulated_vocab_emojis(biome)
	var cached_obs = FactionStateMatcher.extract_observables(biome)
	var cached_icon_map = QuestTheming._get_icon_map_payload(biome)
	var biome_name = biome.biome_name if biome and biome.get("biome_name") else "Unknown"
	var now_ms = Time.get_ticks_msec()

	for faction in FactionDatabase.ALL_FACTIONS:
		var quest = QuestTheming.generate_quest(
			faction, biome, player_vocab, bias_emojis, self.economy,
			cached_obs, cached_icon_map)

		if quest.is_empty() or quest.has("error"):
			continue
		if not _is_valid_offer_with_vocab(quest, player_vocab):
			continue

		quest["id"] = next_quest_id
		next_quest_id += 1
		quest["biome"] = biome_name
		quest["status"] = "offered"
		quest["offered_at"] = now_ms

		quest["body"] = QuestTheming.generate_display_text(quest)
		quest = _annotate_quest_context_with_vocab(quest, biome_name, player_vocab)

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
	"""Reject broken offers (delivery with no resource/qty, north duplicate)."""
	return _is_valid_offer_with_vocab(quest, _get_player_vocab_emojis())


func _is_valid_offer_with_vocab(quest: Dictionary, player_vocab: Array) -> bool:
	"""Reject broken offers using pre-fetched player vocab (avoids GSM walk)."""
	if quest.is_empty():
		return false
	var quest_type = quest.get("type", QuestTypes.Type.DELIVERY)
	if quest_type == QuestTypes.Type.DELIVERY:
		var resource = quest.get("resource", "")
		var quantity = quest.get("quantity", 0)
		if resource == "" or quantity <= 0:
			return false

	var north = quest.get("reward_vocab_north", "")
	var south = quest.get("reward_vocab_south", "")
	var has_vocab_pair = (north != "" and south != "")
	var has_no_vocab = (north == "" and south == "")
	if not has_vocab_pair and not has_no_vocab:
		return false
	if has_vocab_pair and north in player_vocab:
		return false
	return true


func get_biome_observables(biome) -> Dictionary:
	"""Get current biome quantum observables for UI display"""
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
	if gsm and "active_farm" in gsm and gsm.active_farm and "biome_evolution_batcher" in gsm.active_farm:
		var batcher = gsm.active_farm.biome_evolution_batcher
		if batcher and batcher.has_method("get_global_icon_map"):
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
	"""Accept an offered quest

	Args:
		quest_data: Quest with "id" field

	Returns:
		true if accepted, false if invalid
	"""
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
	"""Check if player has resources to complete quest

	Returns:
		true if quest can be completed with current resources
	"""
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
	"""Stamp completion fields, move quest to completed list, emit signals."""
	quest["status"] = "completed"
	quest["completed_at"] = Time.get_ticks_msec()
	quest["reward"] = reward
	active_quests.erase(quest_id)
	completed_quests.append(quest)
	_stop_quest_timer(quest_id)
	quest_completed.emit(quest_id, _build_reward_payload(reward, granted_resources))
	active_quests_changed.emit()


func complete_quest(quest_id: int) -> bool:
	"""Complete an active quest

	Deducts required resources and grants rewards (including vocabulary!)

	Returns:
		true if completed successfully
	"""
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

	# Generate rewards (vocabulary only)
	var player_vocab = _get_player_vocab_emojis()
	var reward = QuestRewards.generate_reward(quest, null, player_vocab)

	var faction_name = quest.get("faction", "Unknown")
	var granted_resources = _grant_resource_rewards(reward, faction_name)
	_grant_vocabulary_rewards(reward, faction_name)

	_finalize_quest_completion(quest_id, quest, reward, granted_resources)
	return true


func complete_or_claim(quest_id: int) -> bool:
	"""Complete delivery quests or claim ready non-delivery quests."""
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
	"""Fail an active quest

	Args:
		quest_id: Quest to fail
		reason: Why it failed (timeout, player_action, resource_shortage)
	"""
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

	quest_failed.emit(quest_id, reason)
	active_quests_changed.emit()

# =============================================================================
# QUEST READY/CLAIM (Non-delivery quests)
# =============================================================================

func mark_quest_ready(quest_id: int, completion_reason: String = "conditions_met") -> void:
	"""Mark a non-delivery quest as ready to claim (conditions met)

	The quest stays in active_quests but with status="ready".
	Player must press Claim to receive rewards.
	"""
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
	"""Claim rewards for a ready non-delivery quest

	Returns:
		true if claimed successfully
	"""
	if not active_quests.has(quest_id):
		push_error("Cannot claim quest %d: not active" % quest_id)
		return false

	var quest = active_quests[quest_id]

	# Must be in ready state
	if quest.get("status") != "ready":
		push_warning("Cannot claim quest %d: not ready (status=%s)" % [quest_id, quest.get("status", "?")])
		return false

	# Generate and grant rewards
	var player_vocab = _get_player_vocab_emojis()
	var reward = QuestRewards.generate_reward(quest, null, player_vocab)
	var faction_name = quest.get("faction", "Unknown")
	var granted_resources = _grant_resource_rewards(reward, faction_name)
	_grant_vocabulary_rewards(reward, faction_name)

	_finalize_quest_completion(quest_id, quest, reward, granted_resources)
	return true


func reject_quest(quest_id: int) -> void:
	"""Reject a ready quest without claiming rewards

	Used when player doesn't want the rewards from a completed non-delivery quest.
	"""
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
	"""Check if a quest is ready to claim"""
	if not active_quests.has(quest_id):
		return false
	return active_quests[quest_id].get("status") == "ready"

# =============================================================================
# QUEST TIMERS
# =============================================================================

func _start_quest_timer(quest_id: int, duration: float) -> void:
	"""Start countdown timer for quest"""
	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(_on_quest_timeout.bind(quest_id))

	add_child(timer)
	quest_timers[quest_id] = timer
	timer.start()

func _stop_quest_timer(quest_id: int) -> void:
	"""Stop and remove quest timer"""
	if quest_timers.has(quest_id):
		var timer = quest_timers[quest_id]
		timer.stop()
		timer.queue_free()
		quest_timers.erase(quest_id)

func _on_quest_timeout(quest_id: int) -> void:
	"""Handle quest timer expiration"""
	if active_quests.has(quest_id):
		fail_quest(quest_id, "timeout")
		quest_expired.emit(quest_id)

func get_quest_time_remaining(quest_id: int) -> float:
	"""Get seconds remaining on quest timer

	Returns:
		-1 if no time limit or timer not found
	"""
	if not quest_timers.has(quest_id):
		return -1.0

	return quest_timers[quest_id].time_left

# =============================================================================
# QUEST TYPE TRACKING (non-delivery quests)
# =============================================================================

func _update_shape_achieve_quest(quest: Dictionary, delta: float) -> void:
	"""Track SHAPE_ACHIEVE quest: reach target observable value once

	Quest format:
	  observable: "purity" | "entropy" | "coherence"
	  target: float (0.0-1.0)
	  comparison: ">" | "<" (defaults to ">")
	  reward_multiplier: float
	"""
	var observable_name = quest.get("observable", "purity")
	var target_value = quest.get("target", 0.7)
	var comparison = quest.get("comparison", ">")

	# Get current biome observables
	var obs = get_biome_observables(current_biome)
	var current_value = obs.get(observable_name, 0.0)

	# Check if target reached (respecting comparison operator)
	var target_met = false
	if comparison == "<":
		target_met = current_value <= target_value
	else:  # ">" or default
		target_met = current_value >= target_value

	if target_met:
		# Mark quest as ready to claim (player must press Claim)
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "target_achieved")


func _update_shape_maintain_quest(quest: Dictionary, delta: float) -> void:
	"""Track SHAPE_MAINTAIN quest: hold observable at target for duration

	Quest format:
	  observable: "purity" | "entropy" | "coherence"
	  target: float (0.0-1.0)
	  comparison: ">" | "<" (defaults to ">")
	  duration: float (seconds to maintain)
	  elapsed: float (time maintained so far)
	  reward_multiplier: float
	"""
	var observable_name = quest.get("observable", "purity")
	var target_value = quest.get("target", 0.7)
	var comparison = quest.get("comparison", ">")
	var required_duration = quest.get("duration", 30.0)

	# Get current biome observables
	var obs = get_biome_observables(current_biome)
	var current_value = obs.get(observable_name, 0.0)

	# Check if currently at target (respecting comparison operator)
	var target_met = false
	if comparison == "<":
		target_met = current_value <= target_value
	else:  # ">" or default
		target_met = current_value >= target_value

	if target_met:
		# Increment elapsed time
		quest["elapsed"] = quest.get("elapsed", 0.0) + delta

		# Check if maintained long enough
		if quest["elapsed"] >= required_duration:
			# Auto-complete quest!
			var quest_id = quest.get("id", -1)
			if quest_id >= 0:
				mark_quest_ready(quest_id, "maintained_duration")
	else:
		# Reset timer if dropped outside target
		quest["elapsed"] = 0.0


func _update_evolution_quest(quest: Dictionary, delta: float) -> void:
	"""Track EVOLUTION quest: change observable by delta amount

	Quest format:
	  observable: "purity" | "entropy" | "coherence"
	  delta: float (amount to change)
	  direction: "increase" | "decrease"
	  initial_value: float (set when quest starts)
	  reward_multiplier: float
	"""
	var observable_name = quest.get("observable", "purity")
	var required_delta = quest.get("delta", 0.2)
	var direction = quest.get("direction", "increase")

	# Get current biome observables
	var obs = get_biome_observables(current_biome)
	var current_value = obs.get(observable_name, 0.0)

	# Initialize starting value if first update
	if quest.get("initial_value") == null:
		quest["initial_value"] = current_value
		return

	var initial_value = quest["initial_value"]
	var actual_change = current_value - initial_value

	# Check if target delta achieved
	var target_met = false
	if direction == "increase":
		target_met = actual_change >= required_delta
	else:  # decrease
		target_met = actual_change <= -required_delta

	if target_met:
		# Auto-complete quest!
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "evolution_achieved")


func _update_entanglement_quest(quest: Dictionary, delta: float) -> void:
	"""Track ENTANGLEMENT quest: create coherence above target

	Quest format:
	  target_coherence: float (0.0-1.0)
	  reward_multiplier: float
	"""
	var target_coherence = quest.get("target_coherence", 0.6)

	# Get current biome observables
	var obs = get_biome_observables(current_biome)
	var current_coherence = obs.get("coherence", 0.0)

	# Check if target reached
	if current_coherence >= target_coherence:
		# Auto-complete quest!
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "entanglement_created")


func _update_achieve_eigenstate_quest(quest: Dictionary, delta: float) -> void:
	"""Track ACHIEVE_EIGENSTATE quest: reach dominant eigenstate (high purity)

	Quest format:
	  target_purity: float (0.85-0.98, prophecy-derived)
	  prophecy_text: String (display text from ProphecyEngine)
	  target_emojis: Array (emojis that should dominate)
	  reward_multiplier: float (2.0-5.0 based on stability)
	"""
	var target_purity = quest.get("target_purity", 0.95)

	# Get current biome observables
	var obs = get_biome_observables(current_biome)
	var current_purity = obs.get("purity", 0.0)

	# Check if eigenstate achieved (high purity = system in eigenstate)
	if current_purity >= target_purity:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "eigenstate_achieved")


func _update_maintain_coherence_quest(quest: Dictionary, delta: float) -> void:
	"""Track MAINTAIN_COHERENCE quest: keep coherence above threshold for duration

	Quest format:
	  target_coherence: float (0.3-0.7)
	  duration: float (seconds to maintain)
	  elapsed: float (time maintained so far, auto-managed)
	  reward_multiplier: float
	"""
	var target_coherence = quest.get("target_coherence", 0.5)
	var required_duration = quest.get("duration", 30.0)

	# Get current biome observables
	var obs = get_biome_observables(current_biome)
	var current_coherence = obs.get("coherence", 0.0)

	if current_coherence >= target_coherence:
		# Increment elapsed time
		quest["elapsed"] = quest.get("elapsed", 0.0) + delta

		# Check if maintained long enough
		if quest["elapsed"] >= required_duration:
			var quest_id = quest.get("id", -1)
			if quest_id >= 0:
				mark_quest_ready(quest_id, "coherence_maintained")
	else:
		# Reset timer if coherence drops
		quest["elapsed"] = 0.0


func _update_induce_bell_state_quest(quest: Dictionary, delta: float) -> void:
	"""Track INDUCE_BELL_STATE quest: create entanglement between specific pair

	Quest format:
	  target_pair: Array[String, String] (two emojis to entangle)
	  threshold: float (0.5-0.9 coherence magnitude)
	  reward_multiplier: float
	"""
	var target_pair = quest.get("target_pair", [])
	var threshold = quest.get("threshold", 0.7)

	if target_pair.size() < 2:
		return  # Invalid quest

	# Get quantum_computer from biome to check specific coherence
	if not current_biome or not current_biome.quantum_computer:
		return

	var qc = current_biome.quantum_computer

	# Check coherence between the specific pair
	var emoji_a = target_pair[0]
	var emoji_b = target_pair[1]

	# Try to get coherence via quantum_computer
	var coherence = 0.0
	if qc.has_method("get_coherence"):
		var coh = qc.get_coherence(emoji_a, emoji_b)
		coherence = coh.abs() if coh else 0.0

	if coherence >= threshold:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "bell_state_achieved")


func _update_prevent_decoherence_quest(quest: Dictionary, delta: float) -> void:
	"""Track PREVENT_DECOHERENCE quest: don't let purity drop below threshold

	Quest format:
	  min_purity: float (0.4-0.7)
	  duration: float (seconds to survive)
	  elapsed: float (time survived so far)
	  reward_multiplier: float
	"""
	var min_purity = quest.get("min_purity", 0.5)
	var required_duration = quest.get("duration", 60.0)

	# Get current biome observables
	var obs = get_biome_observables(current_biome)
	var current_purity = obs.get("purity", 0.0)

	if current_purity >= min_purity:
		# Still above threshold, increment elapsed time
		quest["elapsed"] = quest.get("elapsed", 0.0) + delta

		# Check if survived long enough
		if quest["elapsed"] >= required_duration:
			var quest_id = quest.get("id", -1)
			if quest_id >= 0:
				mark_quest_ready(quest_id, "decoherence_prevented")
	else:
		# Purity dropped too low - fail the quest!
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			fail_quest(quest_id, "decoherence_occurred")


func _update_collapse_deliberately_quest(quest: Dictionary, delta: float) -> void:
	"""Track COLLAPSE_DELIBERATELY quest: measure to lock in specific state

	Quest format:
	  target_emoji: String (emoji to collapse into)
	  target_probability: float (required probability after collapse)
	  has_collapsed: bool (tracks if player triggered measurement)
	  reward_multiplier: float

	Note: Player must use measurement/observation tool on target emoji.
	This function checks if the state has been collapsed to target.
	"""
	var target_emoji = quest.get("target_emoji", "")
	var target_probability = quest.get("target_probability", 0.8)

	if target_emoji.is_empty():
		return

	# Get quantum_computer from biome
	if not current_biome or not current_biome.quantum_computer:
		return

	var qc = current_biome.quantum_computer

	# Check probability of target emoji
	var probability = 0.0
	if qc.has_method("get_population"):
		probability = qc.get_population(target_emoji)

	# Also check purity - high purity + high probability = collapsed state
	var purity = qc.get_purity() if qc.has_method("get_purity") else 0.0

	# Quest completes when: high purity AND target emoji dominates
	if probability >= target_probability and purity >= 0.8:
		var quest_id = quest.get("id", -1)
		if quest_id >= 0:
			mark_quest_ready(quest_id, "state_collapsed")


# =============================================================================
# QUERY FUNCTIONS
# =============================================================================

func get_active_quest_count() -> int:
	"""Get number of active quests"""
	return active_quests.size()

func get_active_quests() -> Array:
	"""Get all active quests as array"""
	return active_quests.values()

# =============================================================================
# QUEST LOCKING (pin offers across cycles)
# =============================================================================

func lock_offer(quest_data: Dictionary) -> bool:
	"""Lock an offered quest so it persists across offer cycles.
	Returns false if at capacity, missing id, or already locked/active."""
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
	"""Release a locked offer (it disappears)."""
	if not locked_offers.has(quest_id):
		return false
	locked_offers.erase(quest_id)
	offer_unlocked.emit(quest_id)
	return true


func get_locked_offers() -> Array:
	"""Return all currently locked offers."""
	return locked_offers.values()


func accept_locked_offer(quest_id: int) -> bool:
	"""Accept a locked offer — moves it from locked → active."""
	if not locked_offers.has(quest_id):
		return false
	var quest = locked_offers[quest_id]
	locked_offers.erase(quest_id)
	return accept_quest(quest)


func get_quest_by_id(quest_id: int) -> Dictionary:
	"""Get quest data by ID (active quests only)"""
	return active_quests.get(quest_id, {})

func has_active_quest_for_faction(faction_name: String) -> bool:
	"""Check if there's an active quest from this faction"""
	for quest in active_quests.values():
		if quest.get("faction", "") == faction_name:
			return true
	return false

func get_completed_quest_count() -> int:
	"""Get total completed quests"""
	return completed_quests.size()

func get_failed_quest_count() -> int:
	"""Get total failed quests"""
	return failed_quests.size()

# =============================================================================
# DEBUG / TESTING
# =============================================================================

func clear_all_quests() -> void:
	"""Clear all quest data (testing only)"""
	for quest_id in quest_timers.keys():
		_stop_quest_timer(quest_id)

	active_quests.clear()
	locked_offers.clear()
	completed_quests.clear()
	failed_quests.clear()
	next_quest_id = 0
	active_quests_changed.emit()

func print_quest_status() -> void:
	"""Print current quest state"""
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
	"""Test quest manager with sample quest"""
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
