class_name RegisterMap
extends RefCounted

## RegisterMap: Translates emoji labels to qubit coordinates
##
## This is the critical translation layer between:
##   - IconRegistry (global physics): HOW emojis interact
##   - QuantumComputer (local hardware): WHERE emojis live in Hilbert space
##
## DUPLICATE EMOJIS ARE LEGAL (owner ruling): the same emoji may label poles on
## several qubits — a shared pole label is just degeneracy; ρ and the evolution
## are qubit-indexed and never cared. Addressing model:
##   - `axes` (qubit → {north, south}) is the SOURCE OF TRUTH. plot_idx ≡
##     register_id ≡ qubit index stays inviolate.
##   - `coordinates` (emoji → {qubit, pole}) is the PRIMARY single-answer lookup:
##     the instance on the LOWEST qubit index wins. All legacy single-answer
##     callers (`has`/`qubit`/`pole`) keep working with this stable semantic.
##   - `all_coordinates_for(emoji)` returns EVERY instance, for surfaces that
##     must see degeneracy (physics builders, populations, market marginals).
##
## Example:
##   coordinates["🔥"] = {qubit: 0, pole: NORTH}  # Fire is |0⟩ on qubit 0
##   coordinates["❄️"] = {qubit: 0, pole: SOUTH}  # Cold is |1⟩ on qubit 0

const NORTH = 0  # |0⟩ state
const SOUTH = 1  # |1⟩ state

## Primary single-answer lookup: emoji → coordinate of the FIRST instance
## (lowest qubit index). Keys are the set of distinct emojis in the register.
## {
##   "🔥": {"qubit": 0, "pole": NORTH},
##   "❄️": {"qubit": 0, "pole": SOUTH},
##   ...
## }
var coordinates: Dictionary = {}

## Multi-answer lookup: emoji → Array[{qubit, pole}] of EVERY instance,
## ordered by qubit index. Same key set as `coordinates`.
var _all_coords: Dictionary = {}

## Source of truth: qubit → {north: emoji, south: emoji}
## {
##   0: {"north": "🔥", "south": "❄️"},
##   1: {"north": "💧", "south": "🏜️"},
##   ...
## }
var axes: Dictionary = {}

## Number of qubits registered
var num_qubits: int = 0
var _verbose: bool = OS.get_environment("REGISTERMAP_VERBOSE") == "1"


func clear() -> void:
	coordinates.clear()
	_all_coords.clear()
	axes.clear()
	num_qubits = 0


func register_axis(qubit_index: int, north_emoji: String, south_emoji: String) -> void:
	# Register a qubit axis with its pole labels.
	#
	# Duplicate emojis across qubits are legal (degenerate labels). Registering
	# an index that already exists REDEFINES that axis.

	# Args:
	# qubit_index: Qubit number (0, 1, 2, ...)
	# north_emoji: Label for |0⟩ state
	# south_emoji: Label for |1⟩ state

	# Validate orthogonality — the two poles of ONE qubit must still differ.
	assert(north_emoji != south_emoji,
		"Qubit %d: poles must differ! Got '%s' for both" % [qubit_index, north_emoji])

	axes[qubit_index] = {"north": north_emoji, "south": south_emoji}
	num_qubits = max(num_qubits, qubit_index + 1)
	_rebuild_lookups()

	if _verbose:
		print("Qubit %d: |0>=%s |1>=%s" % [qubit_index, north_emoji, south_emoji])


func remove_qubit(qubit_index: int) -> bool:
	# Remove one qubit axis and shift higher indices down by one, keeping the
	# plot_idx ≡ register_id contract contiguous. Duplicate-safe: only THIS
	# instance's coordinates disappear; other instances of the same emoji stay.
	if not axes.has(qubit_index):
		return false
	var new_axes: Dictionary = {}
	for q in axes.keys():
		if q == qubit_index:
			continue
		new_axes[q - 1 if q > qubit_index else q] = axes[q]
	axes = new_axes
	num_qubits = max(num_qubits - 1, 0)
	_rebuild_lookups()
	return true


func _rebuild_lookups() -> void:
	# Derive both lookup dicts from `axes` (the single source of truth).
	# Primary = lowest qubit index instance; deterministic and stable.
	coordinates.clear()
	_all_coords.clear()
	var qubit_keys: Array = axes.keys()
	qubit_keys.sort()
	for q in qubit_keys:
		var ax: Dictionary = axes[q]
		_index_instance(str(ax.get("north", "")), int(q), NORTH)
		_index_instance(str(ax.get("south", "")), int(q), SOUTH)


func _index_instance(emoji: String, qubit_index: int, pole_value: int) -> void:
	if emoji == "":
		return
	var coord := {"qubit": qubit_index, "pole": pole_value}
	if not coordinates.has(emoji):
		coordinates[emoji] = coord
	if not _all_coords.has(emoji):
		_all_coords[emoji] = []
	_all_coords[emoji].append(coord)


func has(emoji: String) -> bool:
	# Check if emoji is registered (on at least one qubit).
	return coordinates.has(emoji)


func qubit(emoji: String) -> int:
	# Get qubit index for emoji's PRIMARY instance (lowest qubit), or -1.
	return coordinates.get(emoji, {}).get("qubit", -1)


func pole(emoji: String) -> int:
	# Get pole (0=NORTH, 1=SOUTH) for emoji's PRIMARY instance, or -1.
	return coordinates.get(emoji, {}).get("pole", -1)


func all_coordinates_for(emoji: String) -> Array:
	# EVERY instance of this emoji: Array[{qubit: int, pole: int}], ordered by
	# qubit index. Empty array if unregistered. Treat as READ-ONLY (internal
	# storage returned directly for hot-path speed).
	return _all_coords.get(emoji, [])


func instance_count(emoji: String) -> int:
	return _all_coords.get(emoji, []).size()


func qubits_for(emoji: String) -> Array:
	# All qubit indices carrying this emoji (either pole), ordered.
	var out: Array = []
	for coord in _all_coords.get(emoji, []):
		out.append(coord["qubit"])
	return out


func qubits_with_axis(north_emoji: String, south_emoji: String) -> Array:
	# All qubit indices whose axis is EXACTLY (north_emoji, south_emoji),
	# ordered. This is how physics builders map one icon onto every degenerate
	# instance of its axis.
	var out: Array = []
	for coord in _all_coords.get(north_emoji, []):
		if int(coord["pole"]) != NORTH:
			continue
		var q: int = int(coord["qubit"])
		var ax: Dictionary = axes.get(q, {})
		if str(ax.get("south", "")) == south_emoji:
			out.append(q)
	return out


func axis(qubit_index: int) -> Dictionary:
	# Get {north: emoji, south: emoji} for qubit.
	return axes.get(qubit_index, {})


func dim() -> int:
	# Hilbert space dimension (2^num_qubits).
	return 1 << num_qubits


## Deterministic signature of the emoji→qubit→pole layout. This is a real INPUT to
## HamiltonianBuilder.build_from_icons (an icon whose poles aren't in this map is
## skipped, contributing nothing), so it must be part of any operator-cache key —
## otherwise an H baked under one register layout can be served under another.
## Ordered by qubit index so the string is stable across runs. Duplicate axes
## appear once per qubit, so degeneracy is part of the fingerprint.
func signature() -> String:
	var parts: PackedStringArray = []
	for q in range(num_qubits):
		var ax: Dictionary = axes.get(q, {})
		parts.append("%d:%s|%s" % [q, str(ax.get("north", "")), str(ax.get("south", ""))])
	return ";".join(parts)


func basis_to_emojis(index: int) -> Array[String]:
	# Convert basis state index to array of emojis.

	# Example (3 qubits):
	# basis_to_emojis(0) → ["🔥", "💧", "💨"]  # |000⟩
	# basis_to_emojis(7) → ["❄️", "🏜️", "🌾"]  # |111⟩
	var result: Array[String] = []

	# Bounds check
	if index < 0 or index >= dim():
		return result  # Return empty array for invalid index

	for q in range(num_qubits):
		# Extract bit at position q
		# For qubit 0 (leftmost), shift by (num_qubits - 1 - 0)
		# For qubit 2 (rightmost), shift by (num_qubits - 1 - 2) = 0
		var shift = num_qubits - 1 - q
		var bit = (index >> shift) & 1

		var ax = axes[q]
		result.append(ax["north"] if bit == 0 else ax["south"])

	return result


func emojis_to_basis(emojis: Array[String]) -> int:
	# Convert array of emojis to basis state index.

	# Example (3 qubits):
	# emojis_to_basis(["🔥", "💧", "💨"]) → 0  # |000⟩
	# emojis_to_basis(["❄️", "🏜️", "🌾"]) → 7  # |111⟩
	var index = 0

	for q in range(num_qubits):
		var ax = axes[q]
		var emoji = emojis[q]

		if emoji == ax["south"]:
			# Set bit to 1
			var shift = num_qubits - 1 - q
			index |= (1 << shift)

	return index


func _to_string() -> String:
	# Debug representation.
	var s = "RegisterMap(%d qubits, %dD):\n" % [num_qubits, dim()]

	for q in range(num_qubits):
		var ax = axes[q]
		s += "  Qubit %d: |0⟩=%s |1⟩=%s\n" % [q, ax["north"], ax["south"]]

	return s
