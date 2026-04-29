class_name IconBuilder
extends RefCounted

## IconBuilder: Assembles per-emoji physics objects from faction contributions.
##
## Factions define the emoji web — self-energies, couplings, Lindblad terms —
## at the individual emoji level. IconBuilder merges all faction contributions
## for a given emoji into a single physics object (also called Icon internally).
##
## These per-emoji objects are the building blocks. The player-facing Icon
## concept is a named emoji PAIR (pole_0 / pole_1) defined in biomes.json.
## The rabi_coupling field on the resulting object records the symmetric
## coupling between that emoji and its paired pole (set by BiomeBuilder after
## the JSONL profile is applied — it IS the axis heartbeat).
##
## Usage:
##   var icons = IconBuilder.build_icons_for_factions(biome_factions)
##   # returns Dictionary[emoji] → Icon (per-emoji physics object)

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
			push_warning("IconBuilder: Faction not found: %s" % name)
	return factions

#region Pre-Indexed Faction Lookup (Performance Optimization)

## Pre-computed index: emoji → [factions that speak it]
## Avoids O(N) faction scan for each emoji → O(1) dictionary lookup
static var _emoji_to_factions: Dictionary = {}
static var _index_built: bool = false

## Build the emoji → factions index (call once before building icons)
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

## Build Icons for all emojis across given factions
static func build_icons_for_factions(factions: Array):
	# Build index if not already built (enables O(1) faction lookup)
	if not _index_built:
		build_faction_index(factions)

	# Get all unique emojis from the index
	var all_emojis = _emoji_to_factions.keys()

	# Build Icon for each emoji using indexed factions
	var icons: Array = []
	for emoji in all_emojis:
		var icon = build_icon_indexed(emoji)
		if icon != null:
			icons.append(icon)

	return icons

## Build Icon using pre-indexed factions (O(1) lookup per emoji)
static func build_icon_indexed(emoji: String):
	var factions = get_factions_for_emoji(emoji)
	if factions.is_empty():
		return null
	return _build_icon_from_factions(emoji, factions)

## Build a single Icon by merging all faction contributions (legacy interface)
## Prefer build_icon_indexed() when index is built for better performance
static func build_icon(emoji: String, factions: Array) :
	# Use indexed version if available and factions match
	if _index_built:
		var indexed_factions = get_factions_for_emoji(emoji)
		if not indexed_factions.is_empty():
			return _build_icon_from_factions(emoji, indexed_factions)
	# Fallback to scanning factions
	return _build_icon_from_factions(emoji, factions)

## Internal: Build Icon from known contributing factions (no speaks() check needed)
static func _build_icon_from_factions(emoji: String, faction_list: Array) :
	var icon = IconScript.new()
	icon.emoji = emoji
	icon.display_name = emoji  # Default, can be overridden

	var contributing_factions: Array[String] = []

	# Gated lindblad needs special handling - collect all gates
	var all_gated: Array = []

	# Bell-activated features: collect from all factions
	var all_bell_features: Array = []

	# Decoherence coupling: additive across factions
	var total_decoherence: float = 0.0

	# Iterate only factions that speak this emoji (already filtered by index)
	for faction in faction_list:
		contributing_factions.append(faction.name)
		var contribution = faction.get_icon_contribution(emoji)
		
		# Merge self_energy (additive)
		icon.self_energy += contribution.get("self_energy", 0.0)
		
		# Merge hamiltonian_couplings (additive per target)
		# Note: Values can be float (real) or Vector2 (complex: x=real, y=imag)
		var h_couplings = contribution.get("hamiltonian_couplings", {})
		for target in h_couplings:
			var current = icon.hamiltonian_couplings.get(target, null)
			var incoming = h_couplings[target]
			icon.hamiltonian_couplings[target] = _add_hamiltonian_values(current, incoming)
		
		# Collect bell_activated_features
		var bell = contribution.get("bell_activated_features", {})
		if bell.size() > 0:
			all_bell_features.append({
				"faction": faction.name,
				"features": bell.duplicate(true)  # Deep copy
			})

		# Merge decoherence_coupling (additive)
		var decoh = contribution.get("decoherence_coupling", 0.0)
		total_decoherence += decoh

		# Merge alignment_couplings → energy_couplings (additive per observable)
		var align = contribution.get("alignment_couplings", {})
		for observable in align:
			var current = icon.energy_couplings.get(observable, 0.0)
			icon.energy_couplings[observable] = current + align[observable]
		
		# Merge decay (take highest rate, prefer first target)
		var decay = contribution.get("decay", {})
		if decay.has("rate"):
			if icon.decay_rate < decay.get("rate", 0.0):
				icon.decay_rate = decay.get("rate", 0.0)
				icon.decay_target = decay.get("target", "🍂")
		
		# Merge driver (take first driver found)
		var driver = contribution.get("driver", {})
		if driver.has("type") and icon.self_energy_driver == "":
			icon.self_energy_driver = driver.get("type", "")
			icon.driver_frequency = driver.get("freq", 0.0)
			icon.driver_phase = driver.get("phase", 0.0)
			icon.driver_amplitude = driver.get("amp", 1.0)
	
	# Store bell_activated_features as metadata
	# Format: Array of {faction: String, features: {latent_lindblad, latent_hamiltonian, description}}
	if all_bell_features.size() > 0:
		icon.set_meta("bell_activated_features", all_bell_features)

	# Store decoherence_coupling as metadata (affects T2 time)
	# Value: float (positive = increases decoherence, negative = decreases)
	if abs(total_decoherence) > 0.001:
		icon.set_meta("decoherence_coupling", total_decoherence)

	# Store measurement behavior (first faction wins)
	var measurement = {}
	for faction in faction_list:
		var mb = faction.get_icon_contribution(emoji).get("measurement_behavior", {})
		if mb.size() > 0 and measurement.size() == 0:
			measurement = mb
	if measurement.size() > 0:
		icon.set_meta("measurement_behavior", measurement)
	
	# Set description based on contributing factions
	if contributing_factions.size() == 0:
		# This emoji has no faction contributions - orphan Icon
		icon.description = "An unaffiliated element"
	elif contributing_factions.size() == 1:
		icon.description = "Speaks for the %s" % contributing_factions[0]
	else:
		icon.description = "Contested by: %s" % ", ".join(contributing_factions)
	
	# Set tags
	icon.tags = _make_tags(contributing_factions)
	
	# Set special flags
	icon.is_driver = icon.self_energy_driver != ""
	icon.is_eternal = icon.decay_rate == 0.0 and icon.is_driver
	
	return icon

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
	push_warning("IconBuilder: unexpected hamiltonian types: %s, %s" % [typeof(current), typeof(incoming)])
	return incoming

## ========================================
## Cross-Faction Coupling Injection
## ========================================

## Add cross-faction couplings for shared emojis
## This is where biome-specific dynamics emerge
static func inject_cross_faction_couplings(icons: Dictionary, couplings: Array) -> void:
	## couplings format: [{source: "🌾", target: "💨", type: "lindblad_out", rate: 0.08}]
	
	for coupling in couplings:
		var source_emoji = coupling.get("source", "")
		var target_emoji = coupling.get("target", "")
		var coupling_type = coupling.get("type", "")
		var value = coupling.get("rate", coupling.get("coupling", 0.0))
		
		if not icons.has(source_emoji):
			push_warning("Cross-faction coupling: source %s not found" % source_emoji)
			continue
		
		var icon = icons[source_emoji]
		
		match coupling_type:
			"hamiltonian":
				var current = icon.hamiltonian_couplings.get(target_emoji, null)
				icon.hamiltonian_couplings[target_emoji] = _add_hamiltonian_values(current, value)
			"lindblad_out":
				var current = icon.lindblad_outgoing.get(target_emoji, 0.0)
				icon.lindblad_outgoing[target_emoji] = current + value
			"lindblad_in":
				var current = icon.lindblad_incoming.get(target_emoji, 0.0)
				icon.lindblad_incoming[target_emoji] = current + value
			_:
				push_warning("Unknown coupling type: %s" % coupling_type)

## ========================================
## Biome Composition
## ========================================

## Build complete Icon set for a biome from faction list
static func build_biome_icons(factions: Array, cross_couplings: Array = []) -> Dictionary:
	## Returns Dictionary[emoji] → Icon
	
	var icons_array = build_icons_for_factions(factions)
	
	# Convert to dictionary for easier lookup
	var icons: Dictionary = {}
	for icon in icons_array:
		icons[icon.emoji] = icon
	
	# Inject cross-faction couplings
	if cross_couplings.size() > 0:
		inject_cross_faction_couplings(icons, cross_couplings)
	
	return icons

## ========================================
## Debug Utilities
## ========================================

static func debug_print_icon(icon) -> void:
	print("\n=== Icon: %s (%s) ===" % [icon.emoji, icon.display_name])
	print("  Description: %s" % icon.description)
	print("  Self-energy: %.3f" % icon.self_energy)
	
	if icon.self_energy_driver != "":
		print("  Driver: %s (%.3f Hz, phase=%.2f, amp=%.2f)" % [
			icon.self_energy_driver, icon.driver_frequency,
			icon.driver_phase, icon.driver_amplitude])
	
	if icon.hamiltonian_couplings.size() > 0:
		print("  Hamiltonian couplings:")
		for target in icon.hamiltonian_couplings:
			var val = icon.hamiltonian_couplings[target]
			if val is Vector2:
				print("    → %s: %.3f + %.3fi (complex)" % [target, val.x, val.y])
			else:
				print("    → %s: %.3f" % [target, val])
	
	# Show measurement behavior
	if icon.has_meta("measurement_behavior"):
		var mb = icon.get_meta("measurement_behavior")
		if mb.get("inverts", false):
			print("  🔮 MEASUREMENT INVERTS → opposite pole of axis (quantum mask)")

	# Show bell-activated features
	if icon.has_meta("bell_activated_features"):
		var bell = icon.get_meta("bell_activated_features")
		print("  🔔 BELL-ACTIVATED (dormant until entangled):")
		for entry in bell:
			var desc = entry.features.get("description", "no description")
			print("    [%s]: %s" % [entry.faction, desc])
			if entry.features.has("latent_lindblad"):
				print("      latent_lindblad: %s" % str(entry.features.latent_lindblad))
			if entry.features.has("latent_hamiltonian"):
				print("      latent_hamiltonian: %s" % str(entry.features.latent_hamiltonian))

	# Show decoherence coupling
	if icon.has_meta("decoherence_coupling"):
		var decoh = icon.get_meta("decoherence_coupling")
		var effect = "INCREASES decoherence (lower T2)" if decoh > 0 else "DECREASES decoherence (higher T2)"
		print("  🌡️ Decoherence coupling: %.3f (%s)" % [decoh, effect])

	if icon.energy_couplings.size() > 0:
		print("  Alignment (energy) couplings:")
		for observable in icon.energy_couplings:
			var val = icon.energy_couplings[observable]
			var sign = "+" if val >= 0 else ""
			print("    ~ %s: %s%.3f" % [observable, sign, val])
	
	if icon.decay_rate > 0:
		print("  Decay: %.3f → %s" % [icon.decay_rate, icon.decay_target])
	
	print("  Tags: %s" % icon.tags)
	print("  Flags: driver=%s, eternal=%s" % [icon.is_driver, icon.is_eternal])

static func debug_print_biome(icons: Dictionary) -> void:
	print("\n========== Biome Icons ==========")
	print("Total: %d icons" % icons.size())
	
	for emoji in icons:
		debug_print_icon(icons[emoji])
	
	print("==================================\n")


## ========================================
## BIOME-AWARE ICON BUILDING (New Architecture)
## ========================================

## Build icons for a biome with faction overlays weighted by standing
## This is the new entry point for building icons: biome + (faction × standing)
static func build_biome_with_factions(
	biome_name: String,
	faction_standings: Dictionary = {}
) -> Dictionary:
	## Args:
	##   biome_name: Biome to build for
	##   faction_standings: {faction_name: standing_float} where 0.0=muted, 1.0=full strength
	##
	## Returns:
	##   Dictionary[emoji] -> Icon (complete icon set for the biome)

	var biome_registry = BiomeRegistry.new()
	var biome = biome_registry.get_by_name(biome_name)
	if not biome:
		push_error("IconBuilder: Biome not found: %s" % biome_name)
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
	var icons: Dictionary = {}
	for emoji in all_emojis:
		var biome_component = biome.get_atom_component(emoji)
		var faction_factions = get_factions_for_emoji(emoji)

		var icon = _build_icon_from_biome_and_factions(
			emoji, biome_component, faction_factions, faction_standings, faction_norms
		)

		if icon:
			icons[emoji] = icon

	# Apply biome cross-couplings
	if biome.cross_couplings.size() > 0:
		inject_cross_faction_couplings(icons, biome.cross_couplings)

	return icons


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


## Internal: Build a single icon from biome component + weighted faction contributions
static func _build_icon_from_biome_and_factions(
	emoji: String,
	biome_component: Dictionary,
	faction_list: Array,
	faction_standings: Dictionary,
	faction_norms: Dictionary = {}
) -> IconScript:
	## Start with biome component, then addively merge faction contributions
	## Each faction is weighted by its standing (0.0 = ignored, 1.0 = full strength)

	var icon = IconScript.new()
	icon.emoji = emoji
	icon.display_name = emoji

	# Initialize from biome component
	icon.self_energy = biome_component.get("self_energy", 0.0)

	var biome_h_couplings = biome_component.get("hamiltonian", {})
	for target in biome_h_couplings:
		var current = icon.hamiltonian_couplings.get(target, null)
		var incoming = biome_h_couplings[target]
		icon.hamiltonian_couplings[target] = _add_hamiltonian_values(current, incoming)

	var biome_l_out = biome_component.get("lindblad_outgoing", {})
	for target in biome_l_out:
		var current = icon.lindblad_outgoing.get(target, 0.0)
		icon.lindblad_outgoing[target] = current + biome_l_out[target]

	var biome_l_in = biome_component.get("lindblad_incoming", {})
	for source in biome_l_in:
		var current = icon.lindblad_incoming.get(source, 0.0)
		icon.lindblad_incoming[source] = current + biome_l_in[source]

	# Biome decay (if any)
	var biome_decay = biome_component.get("decay", {})
	if biome_decay.has("rate"):
		icon.decay_rate = biome_decay.get("rate", 0.0)
		icon.decay_target = biome_decay.get("target", "🍂")

	var contributing_sources: Array[String] = ["biome"]

	# Merge faction contributions with standing weights
	var all_gated: Array = []
	var all_bell_features: Array = []
	var total_decoherence: float = 0.0

	for faction in faction_list:
		# Default 1.0 means full participation; FactionStanding integration may
		# pass faction_standings = {name: scalar()} where 0 silences a faction.
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
		icon.self_energy += contribution.get("self_energy", 0.0) * weight

		var h_couplings = contribution.get("hamiltonian_couplings", {})
		for target in h_couplings:
			var current = icon.hamiltonian_couplings.get(target, null)
			var incoming = h_couplings[target]
			if incoming is Vector2:
				incoming = Vector2(incoming.x * weight, incoming.y * weight)
			else:
				incoming = incoming * weight
			icon.hamiltonian_couplings[target] = _add_hamiltonian_values(current, incoming)

		# Collect bell_activated_features
		var bell = contribution.get("bell_activated_features", {})
		if bell.size() > 0:
			all_bell_features.append({
				"faction": faction.name,
				"standing": standing,
				"features": bell.duplicate(true)
			})

		# Merge decoherence_coupling (weighted by standing, not H-normalized)
		var decoh = contribution.get("decoherence_coupling", 0.0)
		total_decoherence += decoh * standing

		# Merge alignment_couplings (weighted)
		var align = contribution.get("alignment_couplings", {})
		for observable in align:
			var current = icon.energy_couplings.get(observable, 0.0)
			icon.energy_couplings[observable] = current + (align[observable] * standing)

		# Merge decay (take highest rate weighted by standing, prefer first target)
		var decay = contribution.get("decay", {})
		if decay.has("rate"):
			var weighted_rate = decay.get("rate", 0.0) * standing
			if icon.decay_rate < weighted_rate:
				icon.decay_rate = weighted_rate
				icon.decay_target = decay.get("target", "🍂")

		# Merge driver (take first driver found)
		var driver = contribution.get("driver", {})
		if driver.has("type") and icon.self_energy_driver == "":
			icon.self_energy_driver = driver.get("type", "")
			icon.driver_frequency = driver.get("freq", 0.0)
			icon.driver_phase = driver.get("phase", 0.0)
			icon.driver_amplitude = driver.get("amp", 1.0) * standing

	# Store metadata
	if all_bell_features.size() > 0:
		icon.set_meta("bell_activated_features", all_bell_features)

	if abs(total_decoherence) > 0.001:
		icon.set_meta("decoherence_coupling", total_decoherence)

	# Store measurement behavior (first faction wins)
	var measurement = {}
	for faction in faction_list:
		var mb = faction.get_icon_contribution(emoji).get("measurement_behavior", {})
		if mb.size() > 0 and measurement.size() == 0:
			measurement = mb
	if measurement.size() > 0:
		icon.set_meta("measurement_behavior", measurement)

	# Set description based on contributing sources
	if contributing_sources.size() == 1:
		icon.description = "Biome foundation: %s" % emoji
	else:
		icon.description = "Biome + factions: %s" % ", ".join(contributing_sources)

	# Set tags
	icon.tags = _make_tags(contributing_sources)

	# Set special flags
	icon.is_driver = icon.self_energy_driver != ""
	icon.is_eternal = icon.decay_rate == 0.0 and icon.is_driver

	return icon
