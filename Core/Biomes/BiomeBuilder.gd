class_name BiomeBuilder
extends RefCounted

const InstrumentLocator = preload("res://Core/Instrumentation/InstrumentLocator.gd")
const VerboseHelper = preload("res://Core/Config/VerboseHelper.gd")

## BiomeBuilder: Builds biome quantum systems from the icon-cloud format.
##
## Architecture (icon-cloud):
##   biome.icons[]  →  _build_biome_icon_list()
##                         ↓
##              IconLexicon.get_icon_physics_by_pair()  ← icons.json
##                         ↓
##              BiomeIcon.from_lexicon(name, p0, p1, physics, cloud)
##                         ↓
##              build_operators_from_icons()  →  H + L
##
## H comes from icons.json (self_energy, rabi, hamiltonian_couplings).
## L comes from the biome's icon cloud dicts (per-pole Lindblad terms).
## Factions are identified via icons; admission is read-only (market/UI).
##
## Biomes with no icons[] (e.g. _orphan_lindblads) boot as data-store
## nodes with no quantum system — valid, silent, no evolution.
##
## Faction standing → H tuning is stubbed; see rebuild_icons_for_standings().

const IconLexicon = preload("res://Core/Factions/IconLexicon.gd")
const BiomeIcon = preload("res://Core/QuantumSubstrate/BiomeIcon.gd")
const FactionRegistry = preload("res://Core/Factions/FactionRegistry.gd")
const BiomeRegistry = preload("res://Core/Biomes/BiomeRegistry.gd")
const BiomeCharacteristics = preload("res://Core/Biomes/BiomeCharacteristics.gd")
const QuantumComputer = preload("res://Core/QuantumSubstrate/QuantumComputer.gd")
const LindbladBuilder = preload("res://Core/QuantumSubstrate/LindbladBuilder.gd")
const BiomeQuantumSystemBuilder = preload("res://Core/Environment/Components/BiomeQuantumSystemBuilder.gd")
const DynamicBiome = preload("res://Core/Environment/DynamicBiome.gd")

## ── Faction Hamiltonian normalization + standings ─────────────────────────────
## Canonical source: HamiltonianConfig.gd (single source of truth)
const HamiltonianConfig = preload("res://Core/Config/HamiltonianConfig.gd")
const FACTION_DIRECTION_NORMALIZATION: bool = HamiltonianConfig.FACTION_DIRECTION_NORMALIZATION

## Singleton instances (lazy-loaded)
static var _faction_registry: FactionRegistry = null
static var _biome_registry: BiomeRegistry = null
static var _icon_registry = null  # Autoload reference
## Get or create FactionRegistry
static func _get_faction_registry() -> FactionRegistry:
	if _faction_registry == null:
		_faction_registry = FactionRegistry.new()
	return _faction_registry


## Get or create BiomeRegistry
static func _get_biome_registry() -> BiomeRegistry:
	if _biome_registry == null:
		_biome_registry = BiomeRegistry.get_shared()
	return _biome_registry


## Get EmojiPhysicsRegistry autoload
static func _get_atom_registry():
	if _icon_registry == null:
		_icon_registry = InstrumentLocator.resolve_icon_registry_main_loop()
	return _icon_registry


## ============================================================================
## UNIFIED BIOME CONSTRUCTION FROM REGISTRY
## ============================================================================

## Build complete biome from BiomeRegistry (JSON-driven)
## This is the NEW unified entry point for all contexts:
## - BootManager (game boot)
## - TestBootManager (test harness)
## - Dynamic biome toggle (runtime)
static func build_from_registry(
	biome_name: String,
	parent_node: Node,
	options: Dictionary = {}
) -> Dictionary:
	# Build a complete DynamicBiome from BiomeRegistry.

	# This method:
	# 1. Loads biome definition from BiomeRegistry
	# 2. Extracts emoji pairs from biome.emojis
	# 3. Builds Lindblad spec from biome.atom_components
	# 4. Calls build_biome_quantum_system() to create QuantumComputer
	# 5. Creates DynamicBiome node with viz_cache
	# 6. Adds biome to parent_node

	# Args:
	# biome_name: Name of biome in BiomeRegistry (e.g., "StarterForest")
	# parent_node: Node to add biome as child
	# options: Optional parameters {
	# faction_standings: Dictionary (faction_name -> weight),
	# skip_tree_add: bool (don't add to parent_node),
	# }

	# Returns:
	# {
	# success: bool,
	# biome_node: DynamicBiome (if success),
	# quantum_computer: QuantumComputer (if success),
	# icons: Dictionary (emoji -> Icon),
	# error: String (if failure)
	# }
	var result = {
		"success": false,
		"biome_node": null,
		"quantum_computer": null,
		"icons": {},
		"error": ""
	}

	# 1. Load biome from registry
	var biome_registry = _get_biome_registry()
	var biome_def = biome_registry.get_by_name(biome_name)

	if not biome_def:
		result.error = "Biome '%s' not found in BiomeRegistry" % biome_name
		return result

	# Delegate to build_from_spec (single biome-centric path)
	return build_from_spec(biome_def, parent_node, options)


## Build complete biome from a Biome spec (Biome object or dict-like)
static func build_from_spec(
	biome_def,
	parent_node: Node,
	options: Dictionary = {}
) -> Dictionary:
	# Build a complete DynamicBiome from a Biome specification.
	var result = {
		"success": false,
		"biome_node": null,
		"quantum_computer": null,
		"icons": {},
		"error": ""
	}

	if not biome_def:
		result.error = "Biome spec is null"
		return result

	var biome_name = _spec_get(biome_def, "name", "")
	if biome_name == "":
		result.error = "Biome spec missing name"
		return result

	# Detect icon-cloud biome (new format) vs. emojis-based biome (legacy format)
	var build_options = options.duplicate()
	var emoji_pairs: Array = []
	if _is_icon_cloud_biome(biome_def):
		var biome_icons = _build_biome_icon_list(biome_def)
		if biome_icons.is_empty():
			result.error = "Icon-cloud biome '%s' has no icons" % biome_name
			return result
		build_options["biome_icons"] = biome_icons
		# Derive emoji_pairs from icon poles for viz_metadata
		for bi in biome_icons:
			emoji_pairs.append({"north": bi.pole_0, "south": bi.pole_1})
	else:
		# No icons[] (e.g. _orphan_lindblads data store). Valid node, no quantum system.
		var data_biome = DynamicBiome.new()
		data_biome.set_biome_type(biome_name)
		data_biome.name = biome_name
		data_biome.quantum_computer = null
		data_biome.icons = {}
		data_biome.icon_overrides = {}
		data_biome.set_meta("icons", {})
		data_biome.set_meta("biome_def", biome_def)
		var _pl = _spec_get(biome_def, "plot_layout", [])
		if _pl is Array and not _pl.is_empty():
			data_biome.set_meta("plot_layout", _pl)
		var _vc = _spec_get(biome_def, "visual_config", {})
		if not _vc.is_empty():
			var _ca = _vc.get("color", [])
			if _ca is Array and _ca.size() >= 4:
				data_biome.visual_color = Color(_ca[0], _ca[1], _ca[2], _ca[3])
			var _lbl = _vc.get("label", "")
			if _lbl != "":
				data_biome.visual_label = _lbl
		_initialize_biome_components(data_biome, null)
		if not options.get("skip_tree_add", false) and parent_node:
			parent_node.add_child(data_biome)
		result.success = true
		result.biome_node = data_biome
		return result

	# Build quantum system (H + L)
	var atom_components: Dictionary = _spec_get(biome_def, "atom_components", {})
	var faction_standings = build_options.get("faction_standings", {})
	var quantum_result = build_biome_quantum_system(
		biome_name,
		emoji_pairs,
		faction_standings,
		atom_components,
		build_options
	)

	if not quantum_result.success:
		result.error = quantum_result.error
		return result

	var qc = quantum_result.quantum_computer
	var icons = quantum_result.icons

	# Create DynamicBiome node
	var biome = DynamicBiome.new()
	biome.set_biome_type(biome_name)
	biome.name = biome_name
	biome.quantum_computer = qc

	# Store icons for viz_cache coupling data and per-biome overrides
	biome.icons = icons
	biome.icon_overrides = icons.duplicate(true)
	biome.set_meta("icons", icons)

	# Store biome definition for later reference
	biome.set_meta("biome_def", biome_def)
	var plot_layout = _spec_get(biome_def, "plot_layout", [])
	if plot_layout and plot_layout is Array and plot_layout.size() > 0:
		biome.set_meta("plot_layout", plot_layout)

	# Apply visual config from biome definition
	var visual_config = _spec_get(biome_def, "visual_config", {})
	if not visual_config.is_empty():
		var color_arr = visual_config.get("color", [])
		if color_arr is Array and color_arr.size() >= 4:
			biome.visual_color = Color(color_arr[0], color_arr[1], color_arr[2], color_arr[3])
		var label = visual_config.get("label", "")
		if label != "":
			biome.visual_label = label
		var offset_arr = visual_config.get("center_offset", [])
		if offset_arr is Array and offset_arr.size() >= 2:
			biome.visual_center_offset = Vector2(offset_arr[0], offset_arr[1])
		var oval_w = visual_config.get("oval_width", 0.0)
		if oval_w > 0.0:
			biome.visual_oval_width = oval_w
		var oval_h = visual_config.get("oval_height", 0.0)
		if oval_h > 0.0:
			biome.visual_oval_height = oval_h

	# Initialize components manually (before tree add)
	_initialize_biome_components(biome, qc)

	# Create viz_cache with metadata (emoji_pairs derived above covers both paths)
	var viz_metadata = _build_viz_metadata(emoji_pairs, biome_def)
	var QuantumVizCache = load("res://Core/Visualization/QuantumVizCache.gd")
	biome.viz_cache = QuantumVizCache.new()
	biome.viz_cache.update_metadata_from_payload(viz_metadata)

	# Seed viz_cache with coupling data from icons
	if biome.has_method("_seed_viz_couplings"):
		biome._seed_viz_couplings()

	# Apply optimal evolution granularity from characteristics
	BiomeCharacteristics.apply_to_biome(biome)

	# Add to tree (unless skip_tree_add)
	if not options.get("skip_tree_add", false) and parent_node:
		parent_node.add_child(biome)

	result.success = true
	result.biome_node = biome
	result.quantum_computer = qc
	result.icons = icons
	return result


## INTERNAL: Safe spec getter (Biome object or Dictionary)
static func _spec_get(spec, key: String, default_value = null):
	if spec == null:
		return default_value
	if spec is Dictionary:
		return spec.get(key, default_value)
	if spec.has_method("get"):
		var value = spec.get(key)
		return value if value != null else default_value
	return default_value


## INTERNAL: Build viz_cache metadata from emoji pairs
static func _build_viz_metadata(emoji_pairs: Array, biome_def) -> Dictionary:
	# Create visualization metadata for QuantumVizCache.

	# Returns metadata dict with axes, emoji mappings, and emoji list.
	var metadata = {
		"num_qubits": emoji_pairs.size(),
		"axes": {},
		"emoji_to_qubit": {},
		"emoji_to_pole": {},
		"emoji_list": []
	}

	for i in range(emoji_pairs.size()):
		var pair = emoji_pairs[i]
		metadata.axes[i] = {"north": pair.north, "south": pair.south}
		metadata.emoji_to_qubit[pair.north] = i
		metadata.emoji_to_qubit[pair.south] = i
		metadata.emoji_to_pole[pair.north] = 0
		metadata.emoji_to_pole[pair.south] = 1
		metadata.emoji_list.append(pair.north)
		metadata.emoji_list.append(pair.south)

	return metadata


## INTERNAL: Initialize BiomeBase components manually (before tree add)
static func _initialize_biome_components(biome, quantum_computer) -> void:
	# Initialize BiomeBase component instances.

	# This is normally done in BiomeBase._ready(), but when building biomes
	# that might not immediately enter the tree, we need to initialize
	# components manually to avoid null reference errors.

	# IDEMPOTENCY: Sets _is_initialized flag to prevent double-initialization
	# when the node later enters the tree and _ready() is called.

	# Args:
	# biome: DynamicBiome or BiomeBase instance
	# quantum_computer: QuantumComputer to wire to components
	# Skip if already initialized
	if biome.get("_is_initialized"):
		return

	# Load component classes
	const BiomeResourceRegistry = preload("res://Core/Environment/Components/BiomeResourceRegistry.gd")
	const BiomeBellGateTracker = preload("res://Core/Environment/Components/BiomeBellGateTracker.gd")
	const BiomeQuantumObserver = preload("res://Core/Environment/Components/BiomeQuantumObserver.gd")
	const BiomeGateOperations = preload("res://Core/Environment/Components/BiomeGateOperations.gd")
	const BiomeQuantumSystemBuilder = preload("res://Core/Environment/Components/BiomeQuantumSystemBuilder.gd")
	const BiomeDensityMatrixMutator = preload("res://Core/Environment/Components/BiomeDensityMatrixMutator.gd")

	# Initialize components (same order as BiomeBase._ready())
	biome._resource_registry = BiomeResourceRegistry.new()
	biome._bell_gate_tracker = BiomeBellGateTracker.new()
	biome._quantum_observer = BiomeQuantumObserver.new()
	biome._gate_operations = BiomeGateOperations.new()
	biome._system_builder = BiomeQuantumSystemBuilder.new()
	biome._density_mutator = BiomeDensityMatrixMutator.new()

	# Wire quantum_computer to components that need it
	if quantum_computer:
		biome._quantum_observer.set_quantum_computer(quantum_computer)
		biome._density_mutator.set_quantum_computer(quantum_computer)

	# Set flag to prevent double-initialization in _ready()
	biome._is_initialized = true


## Build complete quantum system for a biome
## INVARIANT: Can be called at boot OR during gameplay (same logic)
static func build_biome_quantum_system(
	biome_name: String,
	emoji_pairs: Array,  # [{north: String, south: String}]
	faction_standings: Dictionary = {},  # {faction_name: weight (0.0-1.0)}
	atom_components: Dictionary = {},
	options: Dictionary = {}
) -> Dictionary:
	# Build a complete quantum system for a biome.

	# This is the UNIFIED entry point for both boot-time and live rebuilds.

	# Args:
	# biome_name: Name of the biome (e.g. "StarterForest")
	# emoji_pairs: Qubit axes [(north, south)] defining the quantum registers
	# faction_standings: Faction weights (for reputation-based icon building)
	# lindblad_spec: Biome-specific dissipation rules (pumps, drains, gated)
	# options: {icon_patch_fn: Callable} optional biome-local icon tweaks

	# Returns:
	# {
	# success: bool,
	# quantum_computer: QuantumComputer,
	# icons: Dictionary,  # emoji -> Icon
	# hamiltonian: ComplexMatrix,
	# lindblad_operators: Array,
	# error: String (if failure)
	# }
	var result = {
		"success": false,
		"quantum_computer": null,
		"icons": {},
		"hamiltonian": null,
		"lindblad_operators": [],
		"error": ""
	}
	
	# 1. Create QuantumComputer with register map
	var qc = QuantumComputer.new(biome_name)
	var sys_builder = BiomeQuantumSystemBuilder.new()
	sys_builder.quantum_computer = qc

	var biome_icons: Array = options.get("biome_icons", [])

	# ── Icon-cloud path ───────────────────────────────────────────────────────
	for i in range(biome_icons.size()):
		var bi = biome_icons[i]
		qc.allocate_axis(i, bi.pole_0, bi.pole_1)
	VerboseHelper.info("biome", "build", "Icon-cloud: %d icons for %s" % [biome_icons.size(), biome_name])
	sys_builder.build_operators_from_icons(biome_name, biome_icons)
	result.icons = {}

	result.hamiltonian = qc.hamiltonian
	result.lindblad_operators = qc.lindblad_operators
	VerboseHelper.info("biome", "build", "Built Hamiltonian (%dx%d)" % [
		qc.hamiltonian.n if qc.hamiltonian else 0,
		qc.hamiltonian.n if qc.hamiltonian else 0
	])
	VerboseHelper.info("biome", "build", "Built %d Lindblad operators" % [
		qc.lindblad_operators.size()
	])

	# Initialize to ground state (gives correct ecological populations at t=0)
	qc.initialize_ground_state()

	result.success = true
	result.quantum_computer = qc
	return result


## Rebuild H when faction standings change.
## TODO: Redesign for icon-cloud — H weighting by player-faction affinity not yet implemented.
## Stubbed until the new mechanism is settled (see design discussion).
static func rebuild_icons_for_standings(
	_register_map,
	_faction_standings: Dictionary
) -> Dictionary:
	push_warning("BiomeBuilder.rebuild_icons_for_standings: stubbed — faction H tuning not yet implemented for icon-cloud path")
	return {}


## Get VerboseConfig singleton (safe access)
static func _get_verbose_config():
	return InstrumentLocator.resolve_verbose_config_main_loop()


## INTERNAL: True if this biome uses the icon-cloud format.
## An icon-cloud biome defines its register via icons[] alone — no emojis[] list.
## Stripping emojis[] from a biome IS the migration signal; no extra flag needed.
static func _is_icon_cloud_biome(biome_def) -> bool:
	var icons = _spec_get(biome_def, "icons", [])
	if icons.is_empty():
		return false
	# emojis[] non-empty = still on legacy path (not yet migrated)
	var emojis = _spec_get(biome_def, "emojis", null)
	if emojis != null and not (emojis is Array and (emojis as Array).is_empty()):
		return false
	return true


## INTERNAL: Build Array[BiomeIcon] from a biome's icons[] with cloud fields.
## Physics is looked up from icons.json via IconLexicon by (pole_0, pole_1) pair.
static func _build_biome_icon_list(biome_def) -> Array:
	var lexicon := IconLexicon.new()
	var out: Array = []
	for entry in _spec_get(biome_def, "icons", []):
		if not (entry is Dictionary):
			continue
		var p0 := str(entry.get("pole_0", ""))
		var p1 := str(entry.get("pole_1", ""))
		if p0 == "" or p1 == "":
			continue
		var physics := lexicon.get_icon_physics_by_pair(p0, p1)
		var cloud: Dictionary = entry.get("cloud", {})
		var iname := str(entry.get("name", p0))
		out.append(BiomeIcon.from_lexicon(iname, p0, p1, physics, cloud, 1.0))
	return out
