class_name Faction
extends RefCounted

const AffinityGraphCls = preload("res://Core/Affinity/AffinityGraph.gd")

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

## The ONLY emojis this faction speaks (3-7 ideal)
var signature: Array = []

## 12-bit axial tag in conceptual space (see data/faction_lore.json axial_spine).
## Axes: Random/Deterministic, Material/Mystical, Common/Elite, Local/Cosmic,
## Instant/Eternal, Physical/Mental, Crystalline/Fluid, Direct/Subtle,
## Consumptive/Providing, Monochrome/Prismatic, Emergent/Imposed, Scattered/Focused.
##
## `bits` is the *initial corner* — load-time configuration. The live axial
## stance lives on `affinity` (an AffinityGraph initialized at |bits⟩⟨bits|).
## Consumers should read via `get_axial_bits()` so future evolution shows up.
var bits: PackedByteArray = PackedByteArray()

## Live 12-qubit affinity substrate. At load time this is the corner state
## |bits⟩⟨bits|; future phases will let it rotate / mix under settlement and
## inter-faction dynamics. See Core/Affinity/AffinityGraph.gd.
var affinity = null

## ========================================
## Hamiltonian Terms (Unitary Evolution)
## ========================================

## Self-energies for signature emojis
## {emoji: float}
var self_energies: Dictionary = {}

## Hamiltonian couplings WITHIN signature
## {source_emoji: {target_emoji: float}}
## Both source and target MUST be in signature
var hamiltonian: Dictionary = {}

## Driver configuration for time-dependent self-energy
## {emoji: {type: "cosine"|"sine"|"pulse", freq: float, phase: float, amp: float}}
var drivers: Dictionary = {}


## Measurement behavior: how this emoji responds to measurement/observation
## {emoji: {inverts: bool}}
## If inverts=true, measuring this emoji collapses to the OPPOSITE pole of its axis
## Example: On axis (🧤, 🗑), measuring 🧤 → collapses to 🗑
##          On axis (🧤, 💀), measuring 🧤 → collapses to 💀
## Use to "sneak mass" into a basis state - the refugee appears as its opposite
## This is a quantum mask: measurement reveals what's hidden beneath
var measurement_behavior: Dictionary = {}

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
## Methods
## ========================================

## Check if this faction speaks an emoji
func speaks(emoji: String) -> bool:
	return emoji in signature


## Canonical axial-bits accessor. Reads through the AffinityGraph so future
## evolution surfaces correctly; falls back to raw `bits` only when the
## substrate hasn't been built yet (e.g. mid-load from legacy saves).
func get_axial_bits() -> PackedByteArray:
	if affinity != null:
		return affinity.principal_bits()
	return bits


func _rebuild_affinity_from_bits() -> void:
	if bits.size() != AffinityGraphCls.AXIS_COUNT:
		# Defer; load_from_dict for legacy/partial data may leave this empty.
		affinity = null
		return
	affinity = AffinityGraphCls.from_corner(bits)

## Get all emojis this faction contributes to.
## Factions are Hamiltonian-only; the signature is the full set.
func get_all_emojis() -> Array:
	return signature.duplicate()

## Validate that all couplings stay within signature
func validate() -> bool:
	var valid = true
	
	# Check hamiltonian couplings
	for source in hamiltonian:
		if source not in signature:
			push_error("Faction %s: hamiltonian source %s not in signature" % [name, source])
			valid = false
		for target in hamiltonian[source]:
			if target not in signature:
				push_error("Faction %s: hamiltonian target %s not in signature" % [name, target])
				valid = false
	
	return valid

## Get this faction's contribution to a specific Icon
func get_icon_contribution(emoji: String) -> Dictionary:
	if not speaks(emoji):
		return {}

	var contribution = {
		"faction": name,
		"self_energy": self_energies.get(emoji, 0.0),
		"hamiltonian_couplings": hamiltonian.get(emoji, {}),
		"driver": drivers.get(emoji, {}),
		"alignment_couplings": alignment_couplings.get(emoji, {}),
		"measurement_behavior": measurement_behavior.get(emoji, {}),
	}

	return contribution

## Debug representation
func _to_string() -> String:
	return "Faction<%s>[%s](%d emojis)" % [name, ring, signature.size()]


## ========================================
## Serialization (JSON Data-Driven Support)
## ========================================

## Convert faction to dictionary for JSON export
func to_dict() -> Dictionary:
	var data: Dictionary = {
		"name": name,
		"description": description,
		"ring": ring,
		"signature": signature,
		"tags": tags,
	}

	# Only include non-empty fields
	if not self_energies.is_empty():
		data["self_energies"] = self_energies

	if not hamiltonian.is_empty():
		# Convert Vector2 to [real, imag] arrays for JSON
		data["hamiltonian"] = _serialize_hamiltonian(hamiltonian)

	if not drivers.is_empty():
		data["drivers"] = drivers

	if not measurement_behavior.is_empty():
		data["measurement_behavior"] = measurement_behavior

	if not alignment_couplings.is_empty():
		data["alignment_couplings"] = alignment_couplings

	return data


## Load faction from dictionary (JSON import)
func load_from_dict(data: Dictionary) -> void:
	name = data.get("name", "")
	description = data.get("description", "")
	domain = data.get("domain", "")
	ring = data.get("ring", "center")
	motto = data.get("motto", "")
	# Normalize variation selectors so "⚙️" and "⚙" resolve to the same key
	signature = EmojiUtil.normalize_array(_coerce_string_array(data.get("signature", data.get("sig", []))))
	tags = _coerce_string_array(data.get("tags", []))
	var raw_bits = data.get("bits", [])
	bits = PackedByteArray()
	if raw_bits is Array:
		for b in raw_bits:
			bits.append(1 if int(b) != 0 else 0)
	_rebuild_affinity_from_bits()

	self_energies = EmojiUtil.normalize_keys(data.get("self_energies", {}))

	# Convert [real, imag] arrays back to Vector2, normalize emoji keys
	hamiltonian = _deserialize_hamiltonian(EmojiUtil.normalize_nested_keys(data.get("hamiltonian", {})))

	drivers = EmojiUtil.normalize_keys(data.get("drivers", {}))
	measurement_behavior = EmojiUtil.normalize_keys(data.get("measurement_behavior", {}))
	alignment_couplings = EmojiUtil.normalize_nested_keys(data.get("alignment_couplings", {}))


func _coerce_string_array(value) -> Array:
	if value is Array:
		return value
	if value is String:
		# Treat single-string signatures/tags as a single entry.
		# Avoid splitting into codepoints (emoji graphemes can be multi-codepoint).
		return [value]
	return []


## Helper: Serialize hamiltonian (convert Vector2 to [real, imag])
func _serialize_hamiltonian(h: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for source in h:
		result[source] = {}
		for target in h[source]:
			var value = h[source][target]
			if value is Vector2:
				result[source][target] = [value.x, value.y]
			else:
				result[source][target] = value
	return result


## Helper: Deserialize hamiltonian (convert [real, imag] to Vector2)
func _deserialize_hamiltonian(h: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for source in h:
		result[source] = {}
		for target in h[source]:
			var value = h[source][target]
			if value is Array and value.size() == 2:
				result[source][target] = Vector2(value[0], value[1])
			else:
				result[source][target] = value
	return result


## Create faction from dictionary (static factory)
static func from_dict(data: Dictionary) -> Faction:
	# Can't use class_name in static func, must load script explicitly
	var faction = load("res://Core/Factions/Faction.gd").new()
	faction.load_from_dict(data)
	return faction
