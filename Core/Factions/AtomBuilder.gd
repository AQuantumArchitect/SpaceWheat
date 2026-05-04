class_name AtomBuilder
extends RefCounted

## AtomBuilder: Assembles per-emoji physics objects (atoms) from faction contributions.
##
## Factions define the emoji web — self-energies, couplings, Lindblad terms —
## at the individual emoji level. AtomBuilder merges all faction contributions
## for a given emoji into a single physics object (Icon carrying atom data).
##
## These per-emoji atom objects are the building blocks. The player-facing Icon
## concept is a named emoji PAIR (pole_0 / pole_1) defined in biomes.json.
## The rabi_coupling field on the resulting object records the symmetric
## coupling between that emoji and its paired pole (set by BiomeBuilder after
## the JSONL profile is applied — it IS the axis heartbeat).
##
## Usage:
##   var atoms = AtomBuilder.build_atoms_for_factions(biome_factions)
##   # returns Dictionary[emoji] → Icon (per-emoji physics atom)

const Faction = preload("res://Core/Factions/Faction.gd")
const FactionRegistry = preload("res://Core/Factions/FactionRegistry.gd")
const Biome = preload("res://Core/Biomes/Biome.gd")
const BiomeRegistry = preload("res://Core/Biomes/BiomeRegistry.gd")
const IconScript = preload("res://Core/QuantumSubstrate/Icon.gd")

## ── Faction Hamiltonian normalization + standings ─────────────────────────────
## Canonical source: HamiltonianConfig.gd (single source of truth)
const HamiltonianConfig = preload("res://Core/Config/HamiltonianConfig.gd")
const FACTION_DIRECTION_NORMALIZATION: bool = HamiltonianConfig.FACTION_DIRECTION_NORMALIZATION

# Cached registry instance for biome presets
static var _registry: FactionRegistry = null

## Get or create registry instance
static func _get_registry() -> FactionRegistry:
	if _registry == null:
		_registry = FactionRegistry.new()
	return _registry

## Helper to get factions by names from registry
static func _get_factions_by_names(names: Array) -> Array:
	var registry = _get_registry()
	var factions: Array = []
	for name in names:
		var faction = registry.get_by_name(name)
		if faction:
			factions.append(faction)
		else:
			push_warning("AtomBuilder: Faction not found: %s" % name)
	return factions

#region Pre-Indexed Faction Lookup (Performance Optimization)

## Pre-computed index: emoji → [factions that speak it]
## Avoids O(N) faction scan for each emoji → O(1) dictionary lookup
static var _emoji_to_factions: Dictionary = {}
static var _index_built: bool = false

## Build the emoji → factions index (call once before building atoms)
static func build_faction_index(factions: Array) -> void:
	_emoji_to_factions.clear()

	for faction in factions:
		for emoji in faction.get_all_emojis():
			if not _emoji_to_factions.has(emoji):
				_emoji_to_factions[emoji] = []
			_emoji_to_factions[emoji].append(faction)

	_index_built = true

## Get factions that speak a given emoji (O(1) lookup)
static func get_factions_for_emoji(emoji: String) -> Array:
	if not _index_built:
		return []
	return _emoji_to_factions.get(emoji, [])

## Check if index is built
static func is_index_built() -> bool:
	return _index_built

## Clear the index (for testing or biome switching)
static func clear_faction_index() -> void:
	_emoji_to_factions.clear()
	_index_built = false

#endregion

## Build atom objects for all emojis across given factions
static func build_atoms_for_factions(factions: Array):
	# Build index if not already built (enables O(1) faction lookup)
	if not _index_built:
		build_faction_index(factions)

	# Get all unique emojis from the index
	var all_emojis = _emoji_to_factions.keys()

	# Build atom for each emoji using indexed factions
	var atoms: Array = []
	for emoji in all_emojis:
		var atom = build_atom_indexed(emoji)
		if atom != null:
			atoms.append(atom)

	return atoms

## Build atom using pre-indexed factions (O(1) lookup per emoji)
static func build_atom_indexed(emoji: String):
	var factions = get_factions_for_emoji(emoji)
	if factions.is_empty():
		return null
	return _build_atom_from_factions(emoji, factions)

## Build a single atom by merging all faction contributions (legacy interface)
## Prefer build_atom_indexed() when index is built for better performance
static func build_atom(emoji: String, factions: Array):
	# Use indexed version if available and factions match
	if _index_built:
		var indexed_factions = get_factions_for_emoji(emoji)
		if not indexed_factions.is_empty():
			return _build_atom_from_factions(emoji, indexed_factions)
	# Fallback to scanning factions
	return _build_atom_from_factions(emoji, factions)

## Internal: Build atom from known contributing factions (no speaks() check needed)
static func _build_atom_from_factions(emoji: String, faction_list: Array):
	var atom = IconScript.new()
	atom.emoji = emoji
	atom.display_name = emoji  # Default, can be overridden

	var contributing_factions: Array[String] = []

	# Gated lindblad needs special handling - collect all gates
	var all_gated: Array = []

	# Iterate only factions that speak this emoji (already filtered by index)
	for faction in faction_list:
		contributing_factions.append(faction.name)
		var contribution = faction.get_icon_contribution(emoji)

		# Merge self_energy (additive)
		atom.self_energy += contribution.get("self_energy", 0.0)

		# Merge hamiltonian_couplings (additive per target)
		# Note: Values can be float (real) or Vector2 (complex: x=real, y=imag)
		var h_couplings = contribution.get("hamiltonian_couplings", {})
		for target in h_couplings:
			var current = atom.hamiltonian_couplings.get(target, null)
			var incoming = h_couplings[target]
			atom.hamiltonian_couplings[target] = _add_hamiltonian_values(current, incoming)

		# Merge alignment_couplings → energy_couplings (additive per observable)
		var align = contribution.get("alignment_couplings", {})
		for observable in align:
			var current = atom.energy_couplings.get(observable, 0.0)
			atom.energy_couplings[observable] = current + align[observable]

		# Merge driver (take first driver found)
		var driver = contribution.get("driver", {})
		if driver.has("type") and atom.self_energy_driver == "":
			atom.self_energy_driver = driver.get("type", "")
			atom.driver_frequency = driver.get("freq", 0.0)
			atom.driver_phase = driver.get("phase", 0.0)
			atom.driver_amplitude = driver.get("amp", 1.0)

	# Store measurement behavior (first faction wins)
	var measurement = {}
	for faction in faction_list:
		var mb = faction.get_icon_contribution(emoji).get("measurement_behavior", {})
		if mb.size() > 0 and measurement.size() == 0:
			measurement = mb
	if measurement.size() > 0:
		atom.set_meta("measurement_behavior", measurement)

	# Set description based on contributing factions
	if contributing_factions.size() == 0:
		atom.description = "An unaffiliated element"
	elif contributing_factions.size() == 1:
		atom.description = "Speaks for the %s" % contributing_factions[0]
	else:
		atom.description = "Contested by: %s" % ", ".join(contributing_factions)

	# Set tags
	atom.tags = _make_tags(contributing_factions)

	# Set special flags
	atom.is_driver = atom.self_energy_driver != ""
	atom.is_eternal = atom.decay_rate == 0.0 and atom.is_driver

	return atom

## Helper to create typed tag array
static func _make_tags(faction_names: Array[String]) -> Array[String]:
	var tags: Array[String] = []
	for name in faction_names:
		tags.append(name.to_lower().replace(" ", "_"))
	return tags

## Helper to add hamiltonian values that may be float or Vector2 (complex)
## float + float → float, Vector2 + Vector2 → Vector2, mixed → Vector2
static func _add_hamiltonian_values(current, incoming):
	if current == null:
		return incoming
	# Both floats
	if current is float and incoming is float:
		return current + incoming
	# Both Vector2
	if current is Vector2 and incoming is Vector2:
		return current + incoming
	# Mixed: convert float to Vector2(float, 0) and add
	if current is float:
		return Vector2(current, 0.0) + incoming
	if incoming is float:
		return current + Vector2(incoming, 0.0)
	# Fallback (shouldn't happen)
	push_warning("AtomBuilder: unexpected hamiltonian types: %s, %s" % [typeof(current), typeof(incoming)])
	return incoming

## ========================================
## Cross-Faction Coupling Injection
## ========================================

## Add cross-faction couplings for shared emojis
static func inject_cross_faction_couplings(atoms: Dictionary, couplings: Array) -> void:
	## couplings format: [{source: "🌾", target: "💨", type: "lindblad_out", rate: 0.08}]

	for coupling in couplings:
		var source_emoji = coupling.get("source", "")
		var target_emoji = coupling.get("target", "")
		var coupling_type = coupling.get("type", "")
		var value = coupling.get("rate", coupling.get("coupling", 0.0))

		if not atoms.has(source_emoji):
			push_warning("Cross-faction coupling: source %s not found" % source_emoji)
			continue

		var atom = atoms[source_emoji]

		match coupling_type:
			"hamiltonian":
				var current = atom.hamiltonian_couplings.get(target_emoji, null)
				atom.hamiltonian_couplings[target_emoji] = _add_hamiltonian_values(current, value)
			"lindblad_out":
				var current = atom.lindblad_outgoing.get(target_emoji, 0.0)
				atom.lindblad_outgoing[target_emoji] = current + value
			"lindblad_in":
				var current = atom.lindblad_incoming.get(target_emoji, 0.0)
				atom.lindblad_incoming[target_emoji] = current + value
			_:
				push_warning("Unknown coupling type: %s" % coupling_type)

## ========================================
## Biome Composition
## ========================================

## Build complete atom set for a biome from faction list
static func build_biome_atoms(factions: Array, cross_couplings: Array = []) -> Dictionary:
	## Returns Dictionary[emoji] → Icon (atom physics object)

	var atoms_array = build_atoms_for_factions(factions)

	# Convert to dictionary for easier lookup
	var atoms: Dictionary = {}
	for atom in atoms_array:
		atoms[atom.emoji] = atom

	# Inject cross-faction couplings
	if cross_couplings.size() > 0:
		inject_cross_faction_couplings(atoms, cross_couplings)

	return atoms

## ========================================
## Debug Utilities
## ========================================

static func debug_print_atom(atom) -> void:
	print("\n=== Atom: %s (%s) ===" % [atom.emoji, atom.display_name])
	print("  Description: %s" % atom.description)
	print("  Self-energy: %.3f" % atom.self_energy)

	if atom.self_energy_driver != "":
		print("  Driver: %s (%.3f Hz, phase=%.2f, amp=%.2f)" % [
			atom.self_energy_driver, atom.driver_frequency,
			atom.driver_phase, atom.driver_amplitude])

	if atom.hamiltonian_couplings.size() > 0:
		print("  Hamiltonian couplings:")
		for target in atom.hamiltonian_couplings:
			var val = atom.hamiltonian_couplings[target]
			if val is Vector2:
				print("    → %s: %.3f + %.3fi (complex)" % [target, val.x, val.y])
			else:
				print("    → %s: %.3f" % [target, val])

	# Show measurement behavior
	if atom.has_meta("measurement_behavior"):
		var mb = atom.get_meta("measurement_behavior")
		if mb.get("inverts", false):
			print("  🔮 MEASUREMENT INVERTS → opposite pole of axis (quantum mask)")

	if atom.energy_couplings.size() > 0:
		print("  Alignment (energy) couplings:")
		for observable in atom.energy_couplings:
			var val = atom.energy_couplings[observable]
			var sign = "+" if val >= 0 else ""
			print("    ~ %s: %s%.3f" % [observable, sign, val])

	if atom.decay_rate > 0:
		print("  Decay: %.3f → %s" % [atom.decay_rate, atom.decay_target])

	print("  Tags: %s" % atom.tags)
	print("  Flags: driver=%s, eternal=%s" % [atom.is_driver, atom.is_eternal])

static func debug_print_biome_atoms(atoms: Dictionary) -> void:
	print("\n========== Biome Atoms ==========")
	print("Total: %d atoms" % atoms.size())

	for emoji in atoms:
		debug_print_atom(atoms[emoji])

	print("=================================\n")


## ========================================
## BIOME-AWARE ATOM BUILDING
## ========================================

## Build atoms for a biome with faction overlays weighted by standing
static func build_biome_atoms_with_factions(
	biome_name: String,
	faction_standings: Dictionary = {}
) -> Dictionary:
	## Args:
	##   biome_name: Biome to build for
	##   faction_standings: {faction_name: standing_float} where 0.0=muted, 1.0=full strength
	##
	## Returns:
	##   Dictionary[emoji] → Icon (per-emoji physics atom)

	var biome_registry = BiomeRegistry.get_shared()
	var biome = biome_registry.get_by_name(biome_name)
	if not biome:
		push_error("AtomBuilder: Biome not found: %s" % biome_name)
		return {}

	var faction_registry = _get_registry()

	# Get emojis from biome
	var all_emojis = biome.get_all_emojis()

	# Build index: emoji → factions (from factions.json)
	var faction_list = faction_registry.get_all()
	build_faction_index(faction_list)

	# Pre-pass: Frobenius norm of each faction's H contribution across all biome emojis.
	var faction_norms: Dictionary = {}
	if FACTION_DIRECTION_NORMALIZATION:
		faction_norms = _compute_faction_h_norms(faction_list, all_emojis)

	# Build each emoji: biome_component + (direction-normalized faction_contributions × standing)
	var atoms: Dictionary = {}
	for emoji in all_emojis:
		var biome_component = biome.get_atom_component(emoji)
		var faction_factions = get_factions_for_emoji(emoji)

		var atom = _build_atom_from_biome_and_factions(
			emoji, biome_component, faction_factions, faction_standings, faction_norms
		)

		if atom:
			atoms[emoji] = atom

	# Apply biome cross-couplings
	if biome.cross_couplings.size() > 0:
		inject_cross_faction_couplings(atoms, biome.cross_couplings)

	return atoms


## Compute Frobenius norm of each faction's H contribution to these emojis.
## Canonical implementation — BiomeBuilder delegates here.
static func _compute_faction_h_norms(factions: Array, emojis: Array) -> Dictionary:
	var norms: Dictionary = {}
	for faction in factions:
		var norm_sq: float = 0.0
		for emoji in emojis:
			if not faction.speaks(emoji):
				continue
			var contribution = faction.get_icon_contribution(emoji)
			var se: float = contribution.get("self_energy", 0.0)
			norm_sq += se * se
			var h = contribution.get("hamiltonian_couplings", {})
			for val in h.values():
				var v: float = val.length() if val is Vector2 else float(val)
				norm_sq += v * v
		if norm_sq > 0.0:
			norms[faction.name] = sqrt(norm_sq)
	return norms


## Internal: Build a single atom from biome component + weighted faction contributions
static func _build_atom_from_biome_and_factions(
	emoji: String,
	biome_component: Dictionary,
	faction_list: Array,
	faction_standings: Dictionary,
	faction_norms: Dictionary = {}
) -> IconScript:
	## Start with biome component, then additively merge faction contributions
	## Each faction is weighted by its standing (0.0 = ignored, 1.0 = full strength)

	var atom = IconScript.new()
	atom.emoji = emoji
	atom.display_name = emoji

	# Initialize from biome component
	atom.self_energy = biome_component.get("self_energy", 0.0)

	var biome_h_couplings = biome_component.get("hamiltonian", {})
	for target in biome_h_couplings:
		var current = atom.hamiltonian_couplings.get(target, null)
		var incoming = biome_h_couplings[target]
		atom.hamiltonian_couplings[target] = _add_hamiltonian_values(current, incoming)

	var biome_l_out = biome_component.get("lindblad_outgoing", {})
	for target in biome_l_out:
		var current = atom.lindblad_outgoing.get(target, 0.0)
		atom.lindblad_outgoing[target] = current + biome_l_out[target]

	var biome_l_in = biome_component.get("lindblad_incoming", {})
	for source in biome_l_in:
		var current = atom.lindblad_incoming.get(source, 0.0)
		atom.lindblad_incoming[source] = current + biome_l_in[source]

	# Biome decay (if any)
	var biome_decay = biome_component.get("decay", {})
	if biome_decay.has("rate"):
		atom.decay_rate = biome_decay.get("rate", 0.0)
		atom.decay_target = biome_decay.get("target", "🍂")

	var contributing_sources: Array[String] = ["biome"]

	# Merge faction contributions with standing weights
	var all_gated: Array = []

	for faction in faction_list:
		var standing: float = faction_standings.get(faction.name, 1.0)
		if standing <= 0.0:
			continue

		# Frobenius normalization: unit rotation axis vote per faction.
		var h_norm: float = 1.0
		if not faction_norms.is_empty():
			if not faction_norms.has(faction.name):
				continue  # No H contribution to this biome — skip
			h_norm = faction_norms[faction.name]

		var weight: float = standing / h_norm

		contributing_sources.append(faction.name)
		var contribution = faction.get_icon_contribution(emoji)

		# H terms: direction-normalized (weight = standing / h_norm)
		atom.self_energy += contribution.get("self_energy", 0.0) * weight

		var h_couplings = contribution.get("hamiltonian_couplings", {})
		for target in h_couplings:
			var current = atom.hamiltonian_couplings.get(target, null)
			var incoming = h_couplings[target]
			if incoming is Vector2:
				incoming = Vector2(incoming.x * weight, incoming.y * weight)
			else:
				incoming = incoming * weight
			atom.hamiltonian_couplings[target] = _add_hamiltonian_values(current, incoming)

		# Merge alignment_couplings (weighted)
		var align = contribution.get("alignment_couplings", {})
		for observable in align:
			var current = atom.energy_couplings.get(observable, 0.0)
			atom.energy_couplings[observable] = current + (align[observable] * standing)

		# Merge driver (take first driver found)
		var driver = contribution.get("driver", {})
		if driver.has("type") and atom.self_energy_driver == "":
			atom.self_energy_driver = driver.get("type", "")
			atom.driver_frequency = driver.get("freq", 0.0)
			atom.driver_phase = driver.get("phase", 0.0)
			atom.driver_amplitude = driver.get("amp", 1.0) * standing

	# Store measurement behavior (first faction wins)
	var measurement = {}
	for faction in faction_list:
		var mb = faction.get_icon_contribution(emoji).get("measurement_behavior", {})
		if mb.size() > 0 and measurement.size() == 0:
			measurement = mb
	if measurement.size() > 0:
		atom.set_meta("measurement_behavior", measurement)

	# Set description based on contributing sources
	if contributing_sources.size() == 1:
		atom.description = "Biome foundation: %s" % emoji
	else:
		atom.description = "Biome + factions: %s" % ", ".join(contributing_sources)

	# Set tags
	atom.tags = _make_tags(contributing_sources)

	# Set special flags
	atom.is_driver = atom.self_energy_driver != ""
	atom.is_eternal = atom.decay_rate == 0.0 and atom.is_driver

	return atom
