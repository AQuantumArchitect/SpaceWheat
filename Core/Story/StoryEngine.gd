extends Node

## StoryEngine — the substrate that runs the narrative graph in the background.
##
## Owns: StoryGraph, TrajectoryLog, SocialiteCluster.
## Subscribes to: QuestManager story-flag firing (via on_flag_fired hook).
## Exposes: apply_player_action() for QERF×123×GHJKL; routing from Z surface.
##
## Plan §LOCKED:
##   - Hybrid attention model: density on substrate, ui_focus cursor in UI.
##   - QERF semantics: Q withdraw (lossless), R reinforce (lossless),
##     F harmonize (rotate phase, lossless), E measure (collapses).
##   - Only E advances the trajectory; Q/R/F are lossless influence.

const StoryGraph := preload("res://Core/Story/StoryGraph.gd")
const StoryNode := preload("res://Core/Story/StoryNode.gd")
const StoryEdge := preload("res://Core/Story/StoryEdge.gd")
const StorySeedLoader := preload("res://Core/Story/StorySeedLoader.gd")
const TrajectoryLog := preload("res://Core/Story/TrajectoryLog.gd")
const SocialiteCluster := preload("res://Core/Story/SocialiteCluster.gd")
const EmojiSequenceGenerator := preload("res://Core/Story/EmojiSequenceGenerator.gd")
const InstrumentLocator := preload("res://Core/Instrumentation/InstrumentLocator.gd")

# Tunables (per plan §Open Questions defaults)
const TICK_HZ: float = 1.0                 # substrate tick rate
const ATTENTION_DELTA: float = 0.05         # Q/R per-press
const PHASE_DELTA: float = PI / 6.0         # F per-press
const MASS_SHIFT_ON_REINFORCE: float = 0.08  # density mass moved per Q/R press
const MASS_SHIFT_ON_MEASURE: float = 0.6    # density collapse on E

var graph = null         # StoryGraph
var trajectory = null    # TrajectoryLog (named "trajectory" to avoid shadowing log())
var cluster = null       # SocialiteCluster

var _tick_accum: float = 0.0
var _verbose

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
	_verbose = InstrumentLocator.resolve_verbose_config(self)
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
# PLAYER ACTION ROUTER
# =============================================================================

## Apply a QERF×123×GHJKL; expression to a selected edge.
##
##   icon_idx: 0/1/2 — which Icon slot (player vocab pair)
##   verb: "Q"/"E"/"R"/"F"
##   edge_id: id of selected edge in current focused node
##
## Returns a result dict for UI feedback.
func apply_player_action(icon_idx: int, verb: String, edge_id: String) -> Dictionary:
	if graph == null:
		return {"success": false, "error": "no_graph"}
	var edge = graph.get_edge(edge_id)
	if edge == null:
		return {"success": false, "error": "no_edge"}

	match verb:
		"Q":
			edge.attention -= ATTENTION_DELTA
			# Lossless: pull a sliver of mass back from to_node toward from_node.
			graph.shift_mass(edge.to_node, edge.from_node, MASS_SHIFT_ON_REINFORCE * 0.5)
			graph.renormalize()
			density_shifted.emit(edge.to_node, graph.density.get(edge.to_node, 0.0))
			trajectory.record_player_action(edge.from_node, edge.from_node, edge.id, icon_idx, "Q")
			return {"success": true, "verb": "Q", "edge": edge.id, "attention": edge.attention}

		"R":
			edge.attention += ATTENTION_DELTA
			# Lossless: nudge mass from_node → to_node.
			graph.shift_mass(edge.from_node, edge.to_node, MASS_SHIFT_ON_REINFORCE)
			graph.renormalize()
			density_shifted.emit(edge.to_node, graph.density.get(edge.to_node, 0.0))
			trajectory.record_player_action(edge.from_node, edge.to_node, edge.id, icon_idx, "R")
			return {"success": true, "verb": "R", "edge": edge.id, "attention": edge.attention}

		"F":
			# Harmonize: rotate phase toward chosen Icon's axis without measuring.
			edge.phase += PHASE_DELTA
			edge.icon_axis = icon_idx
			trajectory.record_player_action(edge.from_node, edge.from_node, edge.id, icon_idx, "F")
			return {"success": true, "verb": "F", "edge": edge.id, "phase": edge.phase, "icon_axis": icon_idx}

		"E":
			# Measure: collapse → advance trajectory to to_node.
			# Marks edge fired; shifts density hard.
			edge.fired = true
			graph.shift_mass(edge.from_node, edge.to_node, MASS_SHIFT_ON_MEASURE)
			graph.renormalize()
			trajectory.record_player_action(edge.from_node, edge.to_node, edge.id, icon_idx, "E")
			trajectory_advanced.emit(edge.from_node, edge.to_node, edge.id)
			density_shifted.emit(edge.to_node, graph.density.get(edge.to_node, 0.0))
			return {"success": true, "verb": "E", "edge": edge.id, "advanced_to": edge.to_node}

		_:
			return {"success": false, "error": "unknown_verb", "verb": verb}


# =============================================================================
# QUESTMANAGER FIRING HOOK
# =============================================================================

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
# PLAYER ICONS (the player faction's 3 active expression slots)
# =============================================================================

## Resolve player's 3 active icons via active_icon_slots → known_pairs[index].
## Falls back to the first 3 known pairs if slot state is missing/invalid.
func _resolve_player_icons() -> Array:
	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm == null or not farm.has_method("get_known_pairs"):
		return []
	var pairs: Array = farm.get_known_pairs()
	if pairs.is_empty():
		return []
	var slots: Array = []
	if "active_icon_slots" in farm:
		slots = farm.active_icon_slots
	if slots.is_empty():
		return pairs.slice(0, mini(3, pairs.size()))
	var icons: Array = []
	for slot_idx in slots:
		var i := int(slot_idx)
		if i >= 0 and i < pairs.size():
			icons.append(pairs[i])
	if icons.is_empty():
		icons = pairs.slice(0, mini(3, pairs.size()))
	return icons


## Resolve farm-owned shared FactionRegistry.
func _resolve_shared_registry():
	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm == null or farm.faction_density == null:
		return null
	if farm.faction_density.has_method("get_registry"):
		return farm.faction_density.get_registry()
	return null


# =============================================================================
# H BACK-PROPAGATION (player Z-Story QERF → player faction Hamiltonian)
# =============================================================================

const PLAYER_FACTION_NAME := "The Demos"

# Tunables for back-propagation magnitude.
const BACK_PROP_ALIGNMENT_DELTA: float = 0.04   # Q/R per-press: alignment_couplings
const BACK_PROP_PHASE_DELTA: float = PI / 8.0    # F per-press: hamiltonian imag part
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
## F (Harmonize): hamiltonian[icon_emoji_within_signature][icon_partner].y += phase_δ (in-signature only)
## E (Express):   stronger Q+R+F combo, plus persistent trajectory record + density nudge
func express_icon_on_chatter(icon_idx: int, verb: String, chatter_emojis: Array, chatter_faction: String = "") -> Dictionary:
	var registry = _resolve_shared_registry()
	if registry == null:
		return {"success": false, "error": "no_registry"}
	var faction = registry.get_by_name(PLAYER_FACTION_NAME)
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
			_rotate_phase_within_signature(faction, icon_emojis, BACK_PROP_PHASE_DELTA)
		"E":
			# Express: combo + commit + trajectory record.
			_mutate_alignment(faction, icon_emojis, chatter_emojis, BACK_PROP_ALIGNMENT_DELTA * multiplier)
			_rotate_phase_within_signature(faction, icon_emojis, BACK_PROP_PHASE_DELTA * 0.5)
		_:
			return {"success": false, "error": "unknown_verb"}

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
# membership here because faction biomes (player faction = The Demos) often
# have empty `signature` arrays — the hamiltonian's keys are the de-facto vocab.
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
# When a contract exercises, the player faction's AffinityGraph is mixed
# (Lindblad jump) toward the seller faction's posture. Player → seller only;
# the seller is unchanged. Rate scales with contract.cost_amount.
#
# Standings (6-channel) are NOT touched here — those stay quest-driven.

const AFFINITY_BASE_RATE: float = 0.02       # baseline jump per exercise (cost_amount=0)
const AFFINITY_COST_RATE_PER_UNIT: float = 0.005  # additional rate per cost unit
const AFFINITY_MAX_RATE: float = 0.12        # hard cap per exercise


## Called by MarketLattice.exercise() on successful exercise.
func on_contract_exercised(seller_faction_name: String, cost_amount: float = 0.0,
		resource_emoji: String = "", biome_name: String = "") -> Dictionary:
	if seller_faction_name == "" or seller_faction_name == PLAYER_FACTION_NAME:
		return {"success": false, "error": "no_seller_or_self"}
	var registry = _resolve_shared_registry()
	if registry == null:
		return {"success": false, "error": "no_registry"}
	var player_faction = registry.get_by_name(PLAYER_FACTION_NAME)
	var seller_faction = registry.get_by_name(seller_faction_name)
	if player_faction == null or seller_faction == null:
		return {"success": false, "error": "faction_not_found"}
	if player_faction.affinity == null or seller_faction.affinity == null:
		return {"success": false, "error": "no_affinity_graph"}
	var rate: float = clampf(
		AFFINITY_BASE_RATE + AFFINITY_COST_RATE_PER_UNIT * cost_amount,
		0.0, AFFINITY_MAX_RATE
	)
	player_faction.affinity.lindblad_jump_toward(seller_faction.affinity, rate)
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


# Phase rotation: rotate the imaginary part of any internal hamiltonian
# coupling involving any of the icon's emojis (clamped to ±1). Operates on
# whatever keys are actually present in faction.hamiltonian.
func _rotate_phase_within_signature(faction, icon_emojis: Array, phase_delta: float) -> void:
	for ie in icon_emojis:
		var key := str(ie)
		if key == "" or not faction.hamiltonian.has(key):
			continue
		for partner in faction.hamiltonian[key]:
			var v = faction.hamiltonian[key][partner]
			if v is Vector2:
				faction.hamiltonian[key][partner] = Vector2(v.x, clampf(v.y + phase_delta, -1.0, 1.0))


# =============================================================================
# PHASE 2: PLAYER ACTION MEMORY (Icon-hat → conversation Hamiltonian)
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
	return int(Engine.get_physics_frames() / 60)


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
