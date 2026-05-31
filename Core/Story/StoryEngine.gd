extends Node

## StoryEngine — the substrate that runs the narrative graph in the background.
##
## Owns: StoryGraph, TrajectoryLog, SocialiteCluster.
## Subscribes to: QuestManager story-flag firing (via on_flag_fired hook).
## Exposes: express_icon_on_chatter() for QERF expression on a chatter line.
##
## Attention model: density on substrate, ui_focus cursor in UI.
##   Q  withdraw — shifts density away from chatter's topic node.
##   R  reinforce — shifts density toward chatter's topic node.
##   F  harmonize — lossless; no density change; records intent.
##   E  express — strong reinforce + full trajectory record.

const StoryGraph := preload("res://Core/Story/StoryGraph.gd")
const StorySeedLoader := preload("res://Core/Story/StorySeedLoader.gd")
const TrajectoryLog := preload("res://Core/Story/TrajectoryLog.gd")
const SocialiteCluster := preload("res://Core/Story/SocialiteCluster.gd")

# Tunables (per plan §Open Questions defaults)
const TICK_HZ: float = 1.0                 # substrate tick rate
const MASS_SHIFT_ON_REINFORCE: float = 0.08  # density mass moved per Q/R press
const MASS_SHIFT_ON_MEASURE: float = 0.6    # density collapse on E

# Story conversation composition constants.
const CONV_ALPHA_TOPIC: float = 1.0
const CONV_BETA_SPEAKER: float = 1.5
const CONV_GAMMA_PLAYER: float = 0.6
const CONV_EPSILON_RECENT_ACTION: float = 0.8
const CONV_VOCAB_FLOOR: float = 0.05
const CONV_TRANSITION_FLOOR: float = 0.02

var graph = null         # StoryGraph
var trajectory = null    # TrajectoryLog (named "trajectory" to avoid shadowing log())
var cluster = null       # SocialiteCluster

var _tick_accum: float = 0.0
var _verbose

var _farm = null
var _quest_manager = null

# Phase 2: rolling memory of player Icon-hat emoji touches.
# Each entry: {emoji: String, until_tick: int} — drops off after N ticks.
var _recent_player_actions: Array = []
var _recent_player_emojis: Array = []   # rebuilt from _recent_player_actions
const RECENT_ACTION_LIFETIME_TICKS: int = 30  # ~30 seconds at 1Hz

signal chatter_emitted(speaker: String, faction: String, line: String, topic_node: String)
signal trajectory_advanced(from_node: String, to_node: String, edge_id: String)
signal density_shifted(node_id: String, new_weight: float)
signal substrate_ready()


func _ready() -> void:
	add_to_group("story_engine")
	_verbose = get_node_or_null("/root/VerboseConfig")
	# Substrate is session-scope: graph + socialite cluster are populated by
	# WorldBuilder.stage_core_systems via start_for_session(), not at autoload boot.
	# Until then _process is a no-op (graph == null).


func start_for_session() -> void:
	# Build the story substrate for an active session. Idempotent across soft
	# restarts — reset() clears state, then this re-populates.
	if graph != null and cluster != null:
		return
	graph = StorySeedLoader.load_default()
	trajectory = TrajectoryLog.new()
	cluster = SocialiteCluster.new()
	cluster.populate(graph, 6)  # 6 seed socialites: Demos + 5 NPC factions
	if _verbose:
		_verbose.info("story", "📖", "StoryEngine ready — %d nodes, %d edges, %d socialites" % [
			graph.nodes.size(), graph.edges.size(), cluster.size()
		])
	substrate_ready.emit()


func reset() -> void:
	# Called by GameStateManager._reset_runtime_singletons() between sessions.
	graph = null
	trajectory = null
	cluster = null
	_tick_accum = 0.0


func _process(delta: float) -> void:
	if graph == null or cluster == null:
		return
	_tick_accum += delta
	var period := 1.0 / TICK_HZ
	if _tick_accum < period:
		return
	_tick_accum = 0.0
	_tick_substrate()


func _tick_substrate() -> void:
	# Push refs the cluster needs to pick biomes + read shared registry.
	cluster.shared_registry = _resolve_shared_registry()
	cluster.farm = InstrumentLocator.resolve_active_farm(self)
	# Trajectory still records player-action emoji touches (not used for chatter
	# bias anymore; player effects ride real biome physics now).
	_decay_recent_player_actions()
	# Each tick: each socialite picks a biome and emits a basis-state measurement.
	var events: Array = cluster.tick(graph)
	for ev in events:
		if ev.get("kind", "") == "chatter":
			chatter_emitted.emit(
				str(ev.get("speaker", "")),
				str(ev.get("faction", "")),
				str(ev.get("line", "")),
				str(ev.get("topic_node", ""))
			)
		elif ev.get("kind", "") == "step":
			trajectory.record_socialite_step(
				str(ev.get("speaker", "")),
				str(ev.get("from_node", "")),
				str(ev.get("to_node", "")),
				str(ev.get("faction", ""))
			)


# =============================================================================
# QUESTMANAGER FIRING HOOK
# =============================================================================

## Called by QuestManager.connect_to_farm() — wires the arc lifecycle into StoryEngine.
## Safe to call multiple times; signals are connected only once.
func connect_to_farm_and_quests(farm, quest_manager) -> void:
	_farm = farm
	_quest_manager = quest_manager
	if not quest_manager.story_flag_fired.is_connected(_on_story_flag_fired):
		quest_manager.story_flag_fired.connect(_on_story_flag_fired)
	if not quest_manager.quest_completed.is_connected(_on_arc_quest_completed):
		quest_manager.quest_completed.connect(_on_arc_quest_completed)
	_restore_arc_quests_after_load()


## Receive a fired story flag: append beat, apply standing grants, offer arc quest,
## then collapse density. This is the arc-lifecycle side of what QuestManager used to own.
func _on_story_flag_fired(flag_id: String, flag_data: Dictionary) -> void:
	# Beat text (conditional based on Village atoms when conditional_beat is set)
	var beat := _resolve_arc_beat(flag_data)
	# Story log
	if _farm != null:
		_farm.story_log.append({
			"id": flag_id,
			"act": int(flag_data.get("act", 0)),
			"display_name": str(flag_data.get("display_name", flag_id)),
			"arc_beat": beat,
			"fired_at": Engine.get_physics_frames(),
		})
	# Standing grants
	var grants: Dictionary = flag_data.get("standing_grants", {})
	if _farm != null and not grants.is_empty():
		for faction_name in grants:
			_farm.apply_standing_deltas(faction_name, grants[faction_name])
	# Arc quest — offer the live quest payload directly when the flag defines one.
	var arc_quest = flag_data.get("arc_quest")
	if arc_quest is Dictionary and not arc_quest.is_empty() and _quest_manager != null:
		_quest_manager.offer_story_quest(arc_quest.duplicate(), flag_id)
	# Density collapse + trajectory (existing method)
	on_flag_fired(flag_id)


func _resolve_arc_beat(flag_data: Dictionary) -> String:
	var conditional: Array = flag_data.get("conditional_beat", [])
	if conditional.is_empty():
		return str(flag_data.get("arc_beat", ""))
	if _farm != null and _farm.grid != null:
		var biome = _farm.grid.get_biome("Village")
		if biome != null and biome.get("quantum_computer"):
			var reg = biome.quantum_computer.get("register_map")
			if reg != null:
				for entry in conditional:
					var atom := str(entry.get("atom", ""))
					if atom != "" and reg.coordinates.has(atom):
						return str(entry.get("text", ""))
	return str(flag_data.get("arc_beat", ""))


## When any quest completes, check if it was an arc quest and advance graph density forward.
func _on_arc_quest_completed(quest_id: int, _rewards: Dictionary) -> void:
	if _quest_manager == null or graph == null:
		return
	var source_flag := ""
	for q in _quest_manager.completed_quests:
		if int(q.get("id", -1)) == quest_id:
			source_flag = str(q.get("source_flag", ""))
			break
	if source_flag == "" or not graph.nodes.has(source_flag):
		return
	var successors: Array = graph.outgoing.get(source_flag, [])
	if successors.is_empty():
		return
	var shift := 0.15 / float(successors.size())
	for edge_id in successors:
		var edge = graph.edges.get(edge_id)
		if edge != null:
			graph.shift_mass(source_flag, edge.to_node, shift)
	graph.renormalize()
	density_shifted.emit(source_flag, graph.density.get(source_flag, 0.0))


## On reconnect after save/load: re-offer arc quests for already-fired flags
## whose quests aren't yet in the quest manager (e.g. player dismissed or never saw them).
func _restore_arc_quests_after_load() -> void:
	if _farm == null or _quest_manager == null:
		return
	for flag_id in _farm.story_flags_fired:
		if _quest_manager.has_quest_for_flag(flag_id):
			continue
		# Find the raw flag data from QuestManager's loaded flags
		for flag_data in _quest_manager._story_flags:
			if str(flag_data.get("id", "")) != flag_id:
				continue
			var arc_quest = flag_data.get("arc_quest")
			if arc_quest is Dictionary and not arc_quest.is_empty():
				_quest_manager.offer_story_quest(arc_quest.duplicate(), flag_id)
			break


## Called by QuestManager._fire_story_flag(). Records system-driven advances
## into the trajectory log so we have a unified path through graph state.
func on_flag_fired(flag_id: String) -> void:
	if graph == null or flag_id == "":
		return
	if not graph.nodes.has(flag_id):
		# New flag we don't know about (added since seed load) — fail soft.
		return
	# Bias density toward the just-fired node (system collapse).
	var prev_focus: String = graph.argmax_node()
	for nid in graph.density.keys():
		if nid != flag_id:
			graph.shift_mass(nid, flag_id, float(graph.density[nid]) * MASS_SHIFT_ON_MEASURE)
	graph.renormalize()
	trajectory.record_system_advance(prev_focus, flag_id, "")
	trajectory_advanced.emit(prev_focus, flag_id, "")
	density_shifted.emit(flag_id, graph.density.get(flag_id, 0.0))


# =============================================================================
# UI HELPERS
# =============================================================================

## Default UI focus: argmax of density.
func default_ui_focus() -> String:
	if graph == null:
		return ""
	return graph.argmax_node()


# =============================================================================
# STORY COMPOSITION
# =============================================================================

## Canonical story conversation composer.
## Returns { initial: {emoji -> weight}, transitions: {emoji -> {next -> weight}} }.
static func compose_socialite_voice(
	speaker_faction_name: String,
	topic_node,
	registry,
	player_icons: Array = [],
	recent_player_actions: Array = []
) -> Dictionary:
	var initial: Dictionary = {}
	var transitions: Dictionary = {}

	var speaker_faction = null
	if registry != null and registry.has_method("get_by_name"):
		speaker_faction = registry.get_by_name(speaker_faction_name)

	if speaker_faction != null:
		_apply_faction_voice(speaker_faction, CONV_BETA_SPEAKER, initial, transitions)

	if topic_node != null:
		_apply_topic_charge(topic_node, registry, CONV_ALPHA_TOPIC, initial, transitions)

	if not player_icons.is_empty():
		_apply_player_icons(player_icons, CONV_GAMMA_PLAYER, initial, transitions)

	if not recent_player_actions.is_empty():
		_apply_recent_player_actions(recent_player_actions, CONV_EPSILON_RECENT_ACTION, initial, transitions)

	for emoji in initial:
		if float(initial[emoji]) < CONV_VOCAB_FLOOR:
			initial[emoji] = CONV_VOCAB_FLOOR

	return {"initial": initial, "transitions": transitions}


static func _apply_faction_voice(faction, weight: float, initial: Dictionary, transitions: Dictionary) -> void:
	var cloud: Array = faction.cloud if "cloud" in faction and faction.cloud is Array else []
	var icon_registry = _get_icon_registry()
	var physics: Dictionary = {}
	if icon_registry != null and icon_registry.has_method("get_signature_physics") and not cloud.is_empty():
		physics = icon_registry.get_signature_physics(cloud)
	var sig: Array = physics.get("sig", cloud)
	var self_energies: Dictionary = physics.get("self_energies", {})
	var hamiltonian: Dictionary = physics.get("hamiltonian", {})

	for emoji in sig:
		var se: float = float(self_energies.get(emoji, 0.0))
		var w: float = weight * (0.3 + abs(se))
		initial[emoji] = float(initial.get(emoji, 0.0)) + w

	for source in hamiltonian:
		var row: Dictionary = hamiltonian[source]
		if not transitions.has(source):
			transitions[source] = {}
		for target in row:
			var mag: float = _coupling_magnitude(row[target])
			var existing: float = float(transitions[source].get(target, 0.0))
			transitions[source][target] = existing + weight * (CONV_TRANSITION_FLOOR + mag)


static func _apply_topic_charge(topic_node, registry, weight: float, initial: Dictionary, transitions: Dictionary) -> void:
	var charge: Dictionary = topic_node.faction_charge() if topic_node.has_method("faction_charge") else {}
	for faction_name in charge:
		var c: float = float(charge[faction_name])
		if c <= 0.0 or registry == null:
			continue
		var f = registry.get_by_name(faction_name)
		if f == null:
			continue
		for emoji in f.cloud:
			initial[emoji] = float(initial.get(emoji, 0.0)) + weight * c * 0.5
		for source in f.cloud:
			if not transitions.has(source):
				transitions[source] = {}
			for target in f.cloud:
				if source == target:
					continue
				var existing: float = float(transitions[source].get(target, 0.0))
				transitions[source][target] = existing + weight * c * CONV_TRANSITION_FLOOR


static func _apply_player_icons(player_icons: Array, weight: float, initial: Dictionary, transitions: Dictionary) -> void:
	for icon in player_icons:
		var north: String = str(icon.get("north", ""))
		var south: String = str(icon.get("south", ""))
		if north != "":
			initial[north] = float(initial.get(north, 0.0)) + weight * 0.5
		if south != "":
			initial[south] = float(initial.get(south, 0.0)) + weight * 0.5
		if north != "" and south != "":
			if not transitions.has(north):
				transitions[north] = {}
			if not transitions.has(south):
				transitions[south] = {}
			transitions[north][south] = float(transitions[north].get(south, 0.0)) + weight * 0.6
			transitions[south][north] = float(transitions[south].get(north, 0.0)) + weight * 0.6


static func _apply_recent_player_actions(recent: Array, weight: float, initial: Dictionary, transitions: Dictionary) -> void:
	for emoji in recent:
		var e := str(emoji)
		if e == "":
			continue
		initial[e] = float(initial.get(e, 0.0)) + weight * 0.7
		if not transitions.has(e):
			transitions[e] = {}
		transitions[e][e] = float(transitions[e].get(e, 0.0)) + weight * 0.2


static func _get_icon_registry():
	var ml := Engine.get_main_loop()
	var local_registry = ml.root.get_node_or_null("/root/IconRegistry") if ml and ml.root else null
	if local_registry and local_registry.has_method("rebuild_from_icons"):
		local_registry.rebuild_from_icons()
	return local_registry


static func _coupling_magnitude(value) -> float:
	if value is Vector2:
		return value.length()
	if value is Array and value.size() == 2:
		var real: float = float(value[0])
		var imag: float = float(value[1])
		return sqrt(real * real + imag * imag)
	return abs(float(value))


# =============================================================================
# PLAYER ICONS (the player faction's 3 active expression slots)
# =============================================================================

## Resolve player's 3 active icons via active_icon_slots → known_icons[index].
## Falls back to the first 3 known icons if slot state is missing/invalid.
func _resolve_player_icons() -> Array:
	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm == null or not farm.has_method("get_known_icons"):
		return []
	var icons: Array = farm.get_known_icons()
	if icons.is_empty():
		return []
	var slots: Array = []
	if "active_icon_slots" in farm:
		slots = farm.active_icon_slots
	if slots.is_empty():
		return icons.slice(0, mini(3, icons.size()))
	var resolved: Array = []
	for slot_idx in slots:
		var i := int(slot_idx)
		if i >= 0 and i < icons.size():
			resolved.append(icons[i])
	if resolved.is_empty():
		resolved = icons.slice(0, mini(3, icons.size()))
	return resolved


## Resolve farm-owned shared FactionRegistry.
func _resolve_shared_registry():
	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm == null or farm.faction_density == null:
		return null
	if farm.faction_density.has_method("get_registry"):
		return farm.faction_density.get_registry()
	return null


# =============================================================================
# H BACK-PROPAGATION (player Z-Story QERF → player icon physics)
# =============================================================================

## Player's pinned faction name. Empty string means StoryEngine is being
## called before _farm is wired (early boot / tests) or the pin field is
## empty — callers must handle that. Source of truth is GameState; this
## function never re-authors a default.
func _get_player_faction_name() -> String:
	if _farm == null or not _farm.has_method("get_pinned_faction_name"):
		return ""
	return _farm.get_pinned_faction_name()

# Tunables for back-propagation magnitude.
const BACK_PROP_ALIGNMENT_DELTA: float = 0.04   # Q/R per-press: alignment_couplings
const BACK_PROP_PHASE_DELTA: float = PI / 8.0    # F per-press: phase shift
const BACK_PROP_EXPRESS_MULTIPLIER: float = 2.5  # E commits stronger shift than Q/R/F

## Express the active icon onto a chatter line. Mutates the player faction
## (The Demos) in the runtime FactionRegistry — never touches data/*.json.
##
##   icon_idx:       0/1/2 — which active icon slot
##   verb:           "Q"/"R"/"F"/"E"
##   chatter_emojis: Array[String] — the emoji sequence the player is responding to
##   chatter_faction: String — which faction said it (for trajectory record)
##
## Q (Withdraw):  alignment_couplings[icon_emoji][chatter_emoji] -= δ  (cross-signature)
## R (Reinforce): alignment_couplings[icon_emoji][chatter_emoji] += δ
## F (Harmonize): icon atom couplings gain phase; the shared atom registry is mutated,
## not faction-level physics shards.
## E (Express):   stronger Q+R+F combo, plus persistent trajectory record + density nudge
func express_icon_on_chatter(icon_idx: int, verb: String, chatter_emojis: Array, chatter_faction: String = "", chatter_topic_node: String = "") -> Dictionary:
	var registry = _resolve_shared_registry()
	if registry == null:
		return {"success": false, "error": "no_registry"}
	var faction = registry.get_by_name(_get_player_faction_name())
	if faction == null:
		return {"success": false, "error": "no_player_faction"}

	# Resolve the active icon's two emojis.
	var icons: Array = _resolve_player_icons()
	if icon_idx < 0 or icon_idx >= icons.size():
		return {"success": false, "error": "no_icon"}
	var icon: Dictionary = icons[icon_idx]
	var icon_emojis: Array = []
	if str(icon.get("north", "")) != "":
		icon_emojis.append(str(icon.get("north", "")))
	if str(icon.get("south", "")) != "":
		icon_emojis.append(str(icon.get("south", "")))
	if icon_emojis.is_empty() or chatter_emojis.is_empty():
		return {"success": false, "error": "empty_args"}

	var multiplier: float = BACK_PROP_EXPRESS_MULTIPLIER if verb == "E" else 1.0

	match verb:
		"Q":
			_mutate_alignment(faction, icon_emojis, chatter_emojis, -BACK_PROP_ALIGNMENT_DELTA)
		"R":
			_mutate_alignment(faction, icon_emojis, chatter_emojis, BACK_PROP_ALIGNMENT_DELTA)
		"F":
			_rotate_phase_within_signature(icon_emojis, BACK_PROP_PHASE_DELTA)
		"E":
			_mutate_alignment(faction, icon_emojis, chatter_emojis, BACK_PROP_ALIGNMENT_DELTA * multiplier)
			_rotate_phase_within_signature(icon_emojis, BACK_PROP_PHASE_DELTA * 0.5)
		_:
			return {"success": false, "error": "unknown_verb"}

	# Density shift: redirect narrative attention based on the chatter's topic node.
	# This is the real feedback — density modulates socialite chattiness via topic_activity.
	# Q = withdraw attention from this topic; R/E = focus attention here; F = lossless.
	if chatter_topic_node != "" and graph != null and graph.density.has(chatter_topic_node):
		var argmax: String = graph.argmax_node()
		match verb:
			"Q":
				graph.shift_mass(chatter_topic_node, argmax, MASS_SHIFT_ON_REINFORCE)
			"R":
				graph.shift_mass(argmax, chatter_topic_node, MASS_SHIFT_ON_REINFORCE)
			"E":
				graph.shift_mass(argmax, chatter_topic_node, MASS_SHIFT_ON_REINFORCE * BACK_PROP_EXPRESS_MULTIPLIER)
			"F":
				pass  # lossless — no attention change

	# Trajectory record (always).
	if trajectory != null:
		trajectory.record({
			"from_node": graph.argmax_node() if graph != null else "",
			"to_node": graph.argmax_node() if graph != null else "",
			"edge_id": "",
			"action_signature": {
				"kind": "express",
				"verb": verb,
				"icon_idx": icon_idx,
				"icon_emojis": icon_emojis,
				"chatter_emojis": chatter_emojis,
				"target_faction": chatter_faction,
			},
			"speaker": "player_faction",
			"icon_idx": icon_idx,
			"verb": verb,
			"phrame": Engine.get_physics_frames(),
		})

	# Also feed the recent_player_emojis term so NPCs react fast.
	for e in chatter_emojis:
		var s := str(e)
		if s != "":
			_recent_player_actions.append({
				"emoji": s,
				"until_tick": _ticks_now() + RECENT_ACTION_LIFETIME_TICKS,
				"kind": "express",
			})

	return {
		"success": true,
		"verb": verb,
		"icon_emojis": icon_emojis,
		"chatter_emojis": chatter_emojis,
		"target_faction": chatter_faction,
	}


# Cross-signature mutation: alignment_couplings[icon_e][chatter_e] += δ.
# Both keys and values are free-form per the loader; we don't enforce signature
# membership here because neighborhoods (player faction = The Demos) often
# have empty `signature` arrays — alignment couplings are the de-facto vocab.
func _mutate_alignment(faction, icon_emojis: Array, chatter_emojis: Array, delta: float) -> void:
	for ie in icon_emojis:
		var key := str(ie)
		if key == "":
			continue
		if not faction.alignment_couplings.has(key):
			faction.alignment_couplings[key] = {}
		for ce in chatter_emojis:
			var ce_str := str(ce)
			if ce_str == "" or ce_str == key:
				continue
			var existing: float = float(faction.alignment_couplings[key].get(ce_str, 0.0))
			faction.alignment_couplings[key][ce_str] = clampf(existing + delta, -1.0, 1.0)


# =============================================================================
# CONTRACT EXERCISE → PLAYER FACTION AFFINITY ROTATION
# =============================================================================
# Per design: contract fulfilment is the substrate of inter-faction interaction.
# When a contract exercises, the player faction's AlignmentGraph is mixed
# (Lindblad jump) toward the seller faction's posture. Player → seller only;
# the seller is unchanged. Rate scales with contract.cost_amount.
#
# Standings (6-channel) are NOT touched here — those stay quest-driven.

const ALIGNMENT_BASE_RATE: float = 0.02       # baseline jump per exercise (cost_amount=0)
const ALIGNMENT_COST_RATE_PER_UNIT: float = 0.005  # additional rate per cost unit
const ALIGNMENT_MAX_RATE: float = 0.12        # hard cap per exercise


## Called by MarketLattice.exercise() on successful exercise.
func on_contract_exercised(seller_faction_name: String, cost_amount: float = 0.0,
		resource_emoji: String = "", biome_name: String = "") -> Dictionary:
	var player_faction_name := _get_player_faction_name()
	if seller_faction_name == "" or seller_faction_name == player_faction_name:
		return {"success": false, "error": "no_seller_or_self"}
	var registry = _resolve_shared_registry()
	if registry == null:
		return {"success": false, "error": "no_registry"}
	var seller_faction = registry.get_by_name(seller_faction_name)
	if seller_faction == null or seller_faction.alignment == null:
		return {"success": false, "error": "no_seller_affinity"}
	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm == null or not farm.has_method("apply_player_trade_alignment"):
		return {"success": false, "error": "no_farm"}
	var rate: float = clampf(
		ALIGNMENT_BASE_RATE + ALIGNMENT_COST_RATE_PER_UNIT * cost_amount,
		0.0, ALIGNMENT_MAX_RATE
	)
	# Routed through Farm: always tugs Farm.player_alignment; also tugs the
	# pinned faction's affinity iff the player is attached.
	farm.apply_player_trade_alignment(seller_faction.alignment, rate)
	if trajectory != null:
		trajectory.record({
			"from_node": graph.argmax_node() if graph != null else "",
			"to_node": graph.argmax_node() if graph != null else "",
			"edge_id": "",
			"action_signature": {
				"kind": "contract_exercise",
				"seller_faction": seller_faction_name,
				"resource": resource_emoji,
				"biome": biome_name,
				"cost_amount": cost_amount,
				"rate": rate,
			},
			"speaker": "player_faction",
			"icon_idx": -1,
			"verb": "",
			"phrame": Engine.get_physics_frames(),
		})
	return {"success": true, "seller": seller_faction_name, "rate": rate}


# Phase rotation: rotate the imaginary part of any internal atom coupling
# involving any of the icon's emojis (clamped to ±1). Operates on the shared
# IconRegistry singleton so the live session sees the phase shift.
func _rotate_phase_within_signature(icon_emojis: Array, phase_delta: float) -> void:
	var icon_registry = _resolve_icon_registry()
	if icon_registry == null or not icon_registry.has_method("rotate_phase_for_emojis"):
		return
	icon_registry.rotate_phase_for_emojis(icon_emojis, phase_delta)


func _resolve_icon_registry():
	var local_registry = get_node_or_null("/root/IconRegistry")
	if local_registry.has_method("rebuild_from_icons"):
		local_registry.rebuild_from_icons()
	return local_registry


# =============================================================================
# PHASE 2: PLAYER ACTION MEMORY (Icon-hat → conversation substrate)
# =============================================================================

## Called by Icon-hat actions (inject/remove/incorporate/Berry-ripe).
## Records the touched emojis with a lifetime tick stamp; the cluster reads
## the decayed list each tick.
func note_player_action(emojis: Array, kind: String = "icon") -> void:
	var now: int = _ticks_now()
	for e in emojis:
		var emoji := str(e)
		if emoji == "":
			continue
		_recent_player_actions.append({
			"emoji": emoji,
			"until_tick": now + RECENT_ACTION_LIFETIME_TICKS,
			"kind": kind,
		})
	# Also record into trajectory for unified observation (Phase 2 §integration).
	if trajectory != null:
		trajectory.record({
			"from_node": graph.argmax_node() if graph != null else "",
			"to_node": graph.argmax_node() if graph != null else "",
			"edge_id": "",
			"action_signature": {"kind": kind, "emojis": emojis},
			"speaker": "player_faction",
			"icon_idx": -1,
			"verb": "",
			"phrame": Engine.get_physics_frames(),
		})


## Called by LindbladHandler when a Merchant-hat action installs the inverse
## persistent flag on TheDemos. Records the cross-biome transfer in the
## trajectory log so the substrate has a unified history of player moves.
##
## payload shape:
##   {kind: "merchant_drain"|"merchant_pump", emoji: String, target_biome: String, rate: float}
func note_market_action(payload: Dictionary) -> void:
	if trajectory == null:
		return
	var emoji := str(payload.get("emoji", ""))
	if emoji != "":
		_recent_player_actions.append({
			"emoji": emoji,
			"until_tick": _ticks_now() + RECENT_ACTION_LIFETIME_TICKS,
			"kind": str(payload.get("kind", "merchant")),
		})
	trajectory.record({
		"from_node": graph.argmax_node() if graph != null else "",
		"to_node": graph.argmax_node() if graph != null else "",
		"edge_id": "",
		"action_signature": payload.duplicate(true),
		"speaker": "player_faction",
		"icon_idx": -1,
		"verb": "",
		"phrame": Engine.get_physics_frames(),
	})


## Drop expired action records, refresh _recent_player_emojis.
func _decay_recent_player_actions() -> void:
	if _recent_player_actions.is_empty():
		_recent_player_emojis = []
		return
	var now: int = _ticks_now()
	var alive: Array = []
	var emojis: Array = []
	for rec in _recent_player_actions:
		if int(rec.get("until_tick", 0)) > now:
			alive.append(rec)
			var e := str(rec.get("emoji", ""))
			if e != "" and e not in emojis:
				emojis.append(e)
	_recent_player_actions = alive
	_recent_player_emojis = emojis


func _ticks_now() -> int:
	# Substrate ticks at 1 Hz; phrame_index/60 is a close proxy.
	return int(float(Engine.get_physics_frames()) / 60.0)


# =============================================================================
# Special-case Demos voice emitters (inventory ticker, Berry ripeness ticker)
# REMOVED. The Demos socialite is now part of the regular cluster and surfaces
# its voice via the same biome-measurement mechanism every other faction uses.
# Player faction state — inventory, Berry tracking, contract effects, market
# moves — all flow through real biome physics now and are sampled, not injected.


## Recent chatter (last n events as structured lines for Z to render).
func recent_chatter(n: int = 5) -> Array:
	if cluster == null:
		return []
	return cluster.recent_chatter(n)
