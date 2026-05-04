extends RefCounted

## ConversationHamiltonian — composes the per-socialite transition weight matrix.
##
## Plan §LOCKED:
##   H_conv = α·H_topic + β·H_speaker_voice + γ·H_player_signature
##          + δ·H_resonance + ε·H_recent_player_action
##
## Phase 1 fills the first three; H_resonance is a simple all-pairs-of-cluster
## emojis bonus; H_recent_player_action is wired in Phase 2 (placeholder dict
## here — pass empty {} until Icon-hat events flow into the trajectory).
##
## OUTPUT: per call, returns a dict
##   { initial: { emoji → weight },              # initial emoji distribution
##     transitions: { emoji → { next_emoji → weight } } }
## Weights are not normalized — caller normalizes when sampling.

const FactionRegistry := preload("res://Core/Factions/FactionRegistry.gd")

# Coefficients (Plan §QERF locking)
const ALPHA_TOPIC: float = 1.0
const BETA_SPEAKER: float = 1.5
const GAMMA_PLAYER: float = 0.6
const DELTA_RESONANCE: float = 0.4
const EPSILON_RECENT_ACTION: float = 0.8

# Defaults / floors
const VOCAB_FLOOR: float = 0.05      # minimum weight on any emoji a faction speaks
const TRANSITION_FLOOR: float = 0.02 # minimum off-diagonal coupling


## Build the transition matrix and initial distribution for one socialite at one topic node.
##
##   speaker_faction_name: socialite's faction (e.g. "Hearth Keepers")
##   topic_node: a StoryNode (the focused/topic node) — may be null
##   registry: a FactionRegistry instance (cached on caller)
##   player_icons: Array of {north, south} player vocab pairs
##   recent_player_actions: Array[String] of emojis recently touched by player Icon-hat
##                          (empty in Phase 1; populated in Phase 2)
static func build_for_socialite(
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

	# 1. H_speaker_voice — speaker's signature dominates.
	if speaker_faction != null:
		_apply_faction_voice(speaker_faction, BETA_SPEAKER, initial, transitions)

	# 2. H_topic — topic node's standing_grants pull factions into the mix.
	if topic_node != null:
		_apply_topic_charge(topic_node, registry, ALPHA_TOPIC, initial, transitions)

	# 3. H_player_signature — player's incorporated icons add bias.
	if not player_icons.is_empty():
		_apply_player_icons(player_icons, GAMMA_PLAYER, initial, transitions)

	# 4. H_recent_player_action — Phase 2: NPCs witness player Icon-hat moves.
	if not recent_player_actions.is_empty():
		_apply_recent_player_actions(recent_player_actions, EPSILON_RECENT_ACTION, initial, transitions)

	# 5. Floors so any emoji in the bag has *some* chance.
	for emoji in initial:
		if float(initial[emoji]) < VOCAB_FLOOR:
			initial[emoji] = VOCAB_FLOOR

	return {"initial": initial, "transitions": transitions}


# =============================================================================
# COMPONENT BUILDERS
# =============================================================================

static func _apply_faction_voice(faction, weight: float, initial: Dictionary, transitions: Dictionary) -> void:
	# Diagonal: self-energy → initial bias.
	for emoji in faction.signature:
		var se: float = float(faction.self_energies.get(emoji, 0.0))
		var w: float = weight * (0.3 + abs(se))   # baseline + self-energy contribution
		initial[emoji] = float(initial.get(emoji, 0.0)) + w

	# Off-diagonal: hamiltonian couplings → transitions.
	# faction.hamiltonian: {source → {target → Vector2(real, imag)}}
	for source in faction.hamiltonian:
		var row: Dictionary = faction.hamiltonian[source]
		if not transitions.has(source):
			transitions[source] = {}
		for target in row:
			var v = row[target]
			var mag: float = 0.0
			if v is Vector2:
				mag = v.length()
			else:
				mag = abs(float(v))
			var existing: float = float(transitions[source].get(target, 0.0))
			transitions[source][target] = existing + weight * (TRANSITION_FLOOR + mag)


static func _apply_topic_charge(topic_node, registry, weight: float, initial: Dictionary, transitions: Dictionary) -> void:
	# Topic node has standing_grants {faction_name: {channel: float}}.
	# Use that as a measure of which factions care; pull a fraction of their
	# signature into this socialite's bag.
	var charge: Dictionary = topic_node.faction_charge() if topic_node.has_method("faction_charge") else {}
	for faction_name in charge:
		var c: float = float(charge[faction_name])
		if c <= 0.0 or registry == null:
			continue
		var f = registry.get_by_name(faction_name)
		if f == null:
			continue
		# Each emoji of the granted faction gets a topic boost proportional to charge.
		for emoji in f.signature:
			initial[emoji] = float(initial.get(emoji, 0.0)) + weight * c * 0.5
		# Plus a thin coupling boost between the granted faction's signature pairs.
		for source in f.signature:
			if not transitions.has(source):
				transitions[source] = {}
			for target in f.signature:
				if source == target:
					continue
				var existing: float = float(transitions[source].get(target, 0.0))
				transitions[source][target] = existing + weight * c * TRANSITION_FLOOR


static func _apply_player_icons(player_icons: Array, weight: float, initial: Dictionary, transitions: Dictionary) -> void:
	# Each icon pair {north, south} adds bias to both emojis and a coupling between them.
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
	# Phase 2: emojis the player just touched via Icon-hat get amplified, with
	# decay applied by the caller (recent list is already trimmed/decayed).
	for emoji in recent:
		var e := str(emoji)
		if e == "":
			continue
		initial[e] = float(initial.get(e, 0.0)) + weight * 0.7
