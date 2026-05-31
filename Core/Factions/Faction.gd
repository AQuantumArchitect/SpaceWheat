class_name Faction
extends RefCounted

const AlignmentGraphCls = preload("res://Core/Alignment/AlignmentGraph.gd")

## Faction: A closed dynamical system over 3-7 signature emojis
##
## Factions define coupling terms between their signature emojis ONLY.
## An emoji can belong to multiple factions.
## Icons are built by collecting ALL contributions from ALL factions.
##
## Example: 🍂 belongs to both Verdant Pulse and Mycelial Web
##   → The 🍂 Icon gets hamiltonian_couplings from BOTH factions (additive)
##
## Contested emojis like 👥 will have many coupling terms from many factions.
## This is where gameplay tension emerges.

## ========================================
## Identity
## ========================================

var name: String = ""
var description: String = ""
var domain: String = ""
var ring: String = "center"  # "center", "second", "third", "outer"
var motto: String = ""

## The atoms (emojis) this faction physically touches (3-7 ideal, no duplicates).
## Vocabulary note: this is a *cloud* (set of atoms), NOT a "signature" (set of icons).
var cloud: Array = []

## 12-bit axial tag in conceptual space (see data/faction_lore.json axial_spine).
## Axes: Random/Deterministic, Material/Mystical, Common/Elite, Local/Cosmic,
## Instant/Eternal, Physical/Mental, Crystalline/Fluid, Direct/Subtle,
## Consumptive/Providing, Monochrome/Prismatic, Emergent/Imposed, Scattered/Focused.
##
## `bits` is the *initial corner* — load-time configuration. The live axial
## stance lives on `alignment` (an AlignmentGraph initialized at |bits⟩⟨bits|).
## Consumers should read via `get_axial_bits()` so future evolution shows up.
var bits: PackedByteArray = PackedByteArray()

## Live 12-qubit alignment substrate. At load time this is the corner state
## |bits⟩⟨bits|; future phases will let it rotate / mix under settlement and
## inter-faction dynamics. See Core/Alignment/AlignmentGraph.gd. Affinity
## with another faction = overlap(self.alignment, other.alignment).
var alignment = null

## ========================================
## Alignment Couplings (Parametric Effects)
## ========================================

## Alignment couplings: how emoji responds to presence of other emojis
## {emoji: {observable_emoji: float}}
## Positive = enhanced when observable is high (☀️ helps 🌾 grow)
## Negative = suppressed when observable is high (☀️ hurts 🍄)
##
## These create "alignment" effects where growth rates scale with
## the probability of the observable. When P(☀️) is high AND 🌾 is
## trying to grow, the growth is enhanced.
##
## Note: observable_emoji can be OUTSIDE signature (cross-faction alignment)
var alignment_couplings: Dictionary = {}

## ========================================
## Metadata
## ========================================

## Tags for organization
var tags: Array = []

## ========================================
## Authority Tree (data layer — no gating yet)
## ========================================

## Hats (archetype frames) this faction has invested in. Frame_id constants
## live in Core/GameState/ToolConfig.gd FRAME_IDS. An attached player may
## only switch to hats this faction has invested in (gating lands later).
## The Demos has all 7 by default, matching the current "everyone can do
## everything" runtime.
var invested_hats: Array = []

## Per-faction governance of TYUIOP biome slots. Maps slot_key (T/Y/U/I/O/P)
## → biome_name. An attached player may only switch to biomes their faction
## governs (gating lands later). The Demos governs all currently-unlocked
## biome slots in the current runtime.
var governing_biome_slots: Dictionary = {}

## Authored neighborhoods — (biome, signature) pairs this faction has
## explicitly configured. Each entry: {biome: String, signature: [{name, pole_0, pole_1}]}.
## When compose_neighborhood encounters one of these biomes, it uses the
## authored signature instead of running the inducer.
var neighborhoods: Array = []

## ========================================
## Methods
## ========================================

## Check if this faction speaks an emoji (i.e., the emoji is in its cloud).
func speaks(emoji: String) -> bool:
	return emoji in cloud


## Canonical axial-bits accessor. Reads through the AlignmentGraph so future
## evolution surfaces correctly; falls back to raw `bits` only when the
## substrate hasn't been built (e.g. partial fixture without 12 bits authored).
func get_axial_bits() -> PackedByteArray:
	if alignment != null:
		return alignment.principal_bits()
	return bits


func _rebuild_alignment_from_bits() -> void:
	if bits.size() != AlignmentGraphCls.AXIS_COUNT:
		alignment = null
		return
	alignment = AlignmentGraphCls.from_corner(bits)

## Get all atoms (emojis) in this faction's cloud.
func get_all_emojis() -> Array:
	return cloud.duplicate()

## Returns true if this faction has invested in the named hat (frame_id from
## ToolConfig.FRAME_IDS). Read-only authority-tree query; gating not yet wired.
func has_invested_hat(frame_id: String) -> bool:
	return frame_id in invested_hats


## Returns the biome name this faction governs at the given TYUIOP slot key,
## or "" if not governed. Read-only authority-tree query; gating not yet wired.
func biome_at_slot(slot_key: String) -> String:
	return String(governing_biome_slots.get(slot_key, ""))


## Validate that the cloud contains no empty or duplicate atoms.
func validate() -> bool:
	var valid = true

	var seen_cloud: Dictionary = {}
	for emoji in cloud:
		var key := str(emoji)
		if key == "":
			push_error("Faction %s: cloud contains an empty emoji entry" % name)
			valid = false
			continue
		if seen_cloud.has(key):
			push_error("Faction %s: cloud contains duplicate emoji %s" % [name, key])
			valid = false
			continue
		seen_cloud[key] = true

	return valid

## Get this faction's contribution to a specific Icon
func get_icon_contribution(emoji: String) -> Dictionary:
	if not speaks(emoji):
		return {}

	# H/self-energy/drivers/measurement_behavior live in icons.json via
	# IconRegistry — not on factions. Faction-side parametric input is just
	# alignment_couplings (cross-emoji story modulation).
	return {
		"faction": name,
		"alignment_couplings": alignment_couplings.get(emoji, {}),
	}

## Debug representation
func _to_string() -> String:
	return "Faction<%s>[%s](%d atoms)" % [name, ring, cloud.size()]


## ========================================
## Serialization (JSON Data-Driven Support)
## ========================================

## Convert faction to dictionary for JSON export
func to_dict() -> Dictionary:
	var data: Dictionary = {
		"name": name,
		"description": description,
		"ring": ring,
		"cloud": cloud,
		"tags": tags,
	}

	if not alignment_couplings.is_empty():
		data["alignment_couplings"] = alignment_couplings

	return data


## Load faction from dictionary (JSON import)
func load_from_dict(data: Dictionary) -> void:
	name = _coerce_string(data.get("name", ""))
	description = _coerce_string(data.get("description", ""))
	domain = _coerce_string(data.get("domain", ""))
	ring = _coerce_string(data.get("ring", "center"), "center")
	motto = _coerce_string(data.get("motto", ""))
	# Normalize variation selectors so "⚙️" and "⚙" resolve to the same key.
	cloud = EmojiUtil.normalize_array(_coerce_string_array(data.get("cloud", [])))
	tags = _coerce_string_array(data.get("tags", []))
	var raw_bits = data.get("bits", [])
	bits = PackedByteArray()
	if raw_bits is Array:
		for b in raw_bits:
			bits.append(1 if int(b) != 0 else 0)
	_rebuild_alignment_from_bits()

	alignment_couplings = EmojiUtil.normalize_nested_keys(data.get("alignment_couplings", {}))

	invested_hats = _coerce_string_array(data.get("invested_hats", []))
	governing_biome_slots = data.get("governing_biome_slots", {}) if data.get("governing_biome_slots") is Dictionary else {}
	neighborhoods = data.get("neighborhoods", []) if data.get("neighborhoods") is Array else []


func _coerce_string(value, default_value: String = "") -> String:
	if value == null:
		return default_value
	return str(value)


func _coerce_string_array(value) -> Array:
	if value is Array:
		return value
	if value is String:
		# Treat single-string signatures/tags as a single entry.
		# Avoid splitting into codepoints (emoji graphemes can be multi-codepoint).
		return [value]
	return []


## Create faction from dictionary (static factory)
static func from_dict(data: Dictionary) -> Faction:
	# Can't use class_name in static func, must load script explicitly
	var faction = load("res://Core/Factions/Faction.gd").new()
	faction.load_from_dict(data)
	return faction
