class_name BiomeBuilder
extends RefCounted


## BiomeBuilder: Builds neighborhood quantum systems from a bare biome plus
## a neighborhood loadout.
##
## Architecture (neighborhood):
##   faction.icons (via IconRegistry) → _resolve_neighborhood_loadout()
##                         ↓
##              IconRegistry.get_icon_physics_by_pair()  ← icons.json
##                         ↓
##              Icon.from_pair_physics(name, p0, p1, physics, cloud)
##                         ↓
##              build_operators_from_icons()  →  H + L
##
## H comes from icons.json (self_energy, rabi, hamiltonian_couplings).
## L comes from the biome's atom_components dict (per-pole Lindblad terms).
## Factions are identified via the neighborhood loadout; admission is read-only
## (market/UI).
##
## Bare biomes with no neighborhood loadout (e.g. _orphan_lindblads) boot as
## data-store nodes with no quantum system — valid, silent, no evolution.
##
## Faction standings affect operators *outside* H (action weights, market lattice),
## not icon-derived H itself. Icons.json is the sole authority for coherent dynamics.


## ── Faction Hamiltonian normalization + standings ─────────────────────────────
## Canonical source: HamiltonianConfig.gd (single source of truth)
const FACTION_DIRECTION_NORMALIZATION: bool = HamiltonianConfig.FACTION_DIRECTION_NORMALIZATION

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
	# 2. Reads biome.emojis as the atom basis (a cloud of atoms — qubit axes are
	#    grouped from the NEIGHBORHOOD's induced icons, not from emoji order)
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

	# 1. Load bare biome from registry
	var biome_registry = BiomeRegistry.get_shared()
	var biome_def = biome_registry.get_by_name(biome_name)

	if not biome_def:
		result.error = "Biome '%s' not found in BiomeRegistry" % biome_name
		return result

	# Delegate to build_from_spec (single biome-centric path)
	return build_from_spec(biome_def, parent_node, options)


## Build a neighborhood loadout onto a bare biome.
## The bare biome provides terrain / dissipation / discovery metadata while the
## faction contributes the icon loadout that becomes live in the neighborhood.
static func build_neighborhood_loadout(
	bare_biome_def,
	faction_name: String,
	parent_node: Node,
	options: Dictionary = {}
) -> Dictionary:
	var build_options = options.duplicate()
	if faction_name != "":
		build_options["neighborhood_faction"] = faction_name
	return build_from_spec(bare_biome_def, parent_node, build_options)


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

	var build_options = options.duplicate()
	var neighborhood_loadout = _resolve_neighborhood_loadout(biome_def, build_options)
	var neighborhood_icons: Array = neighborhood_loadout.get("icons", [])
	var neighborhood_faction: String = str(build_options.get("neighborhood_faction", ""))
	var emoji_pairs: Array = []

	if neighborhood_icons.is_empty():
		# No neighborhood loadout (e.g. _orphan_lindblads data store). Valid node,
		# no quantum system.
		var data_biome = DynamicBiome.new()
		data_biome.set_biome_type(biome_name)
		data_biome.name = biome_name
		data_biome.quantum_computer = null
		data_biome.icons = {}
		data_biome.set_meta("icons", {})
		if neighborhood_faction != "":
			data_biome.set_meta("neighborhood_faction", neighborhood_faction)
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

	for bi in neighborhood_icons:
		emoji_pairs.append({"north": bi.pole_0, "south": bi.pole_1})
	build_options["neighborhood_icons"] = neighborhood_icons

	# Build quantum system (H + L)
	var atom_components: Dictionary = _spec_get(biome_def, "atom_components", {})
	# Per-biome thermodynamic regime (What Fades seam, docs/OPEN_CAMPAIGN.md):
	# "open" = wet country (dissipative while the world is sealed),
	# "closed" = inviolable enclave (unitary even after the door opens),
	# "" = inherit the global switches.
	build_options["regime"] = str(_spec_get(biome_def, "regime", ""))
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

	# Store icons for viz_cache coupling data. IconRegistry remains canonical;
	# this dict is a per-biome cache keyed by emoji.
	biome.icons = icons
	biome.set_meta("icons", icons)
	if neighborhood_faction != "":
		biome.set_meta("neighborhood_faction", neighborhood_faction)

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
	var viz_cache_script = load("res://Core/Visualization/QuantumVizCache.gd")
	biome.viz_cache = viz_cache_script.new()
	biome.viz_cache.update_metadata_from_payload(viz_metadata)

	# Seed viz_cache with coupling data from icons
	if biome.has_method("_seed_viz_couplings"):
		biome._seed_viz_couplings()

	# Apply optimal evolution granularity from characteristics
	BiomeCharacteristics.apply_to_biome(biome)
	result.icons = biome.icons

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
static func _build_viz_metadata(emoji_pairs: Array, _biome_def) -> Dictionary:
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
		var north: String = str(pair.get("north", ""))
		var south: String = str(pair.get("south", ""))
		metadata.axes[i] = {"north": north, "south": south}
		# Duplicate emojis are legal: FIRST instance wins the single-answer maps,
		# matching RegisterMap's primary (lowest-qubit) lookup semantics; per-qubit
		# truth lives in `axes`. emoji_list holds distinct emojis, like the
		# register_map.coordinates-driven payload builders.
		if not metadata.emoji_to_qubit.has(north):
			metadata.emoji_to_qubit[north] = i
			metadata.emoji_to_pole[north] = 0
			metadata.emoji_list.append(north)
		if not metadata.emoji_to_qubit.has(south):
			metadata.emoji_to_qubit[south] = i
			metadata.emoji_to_pole[south] = 1
			metadata.emoji_list.append(south)

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

	# Initialize components (same order as BiomeBase._ready())
	biome._resource_registry = BiomeResourceRegistry.new()
	biome._bell_gate_tracker = BiomeBellGateTracker.new()
	biome._quantum_observer = BiomeQuantumObserver.new()
	biome._gate_operations = BiomeGateOperations.new()
	biome._system_builder = BiomeQuantumSystemBuilder.new()

	# Wire quantum_computer to components that need it
	if quantum_computer:
		biome._quantum_observer.set_quantum_computer(quantum_computer)

	# Set flag to prevent double-initialization in _ready()
	biome._is_initialized = true


## Build complete quantum system for a biome
## INVARIANT: Can be called at boot OR during gameplay (same logic)
static func build_biome_quantum_system(
	biome_name: String,
	_emoji_pairs: Array,  # [{north: String, south: String}]
	_faction_standings: Dictionary = {},  # {faction_name: weight (0.0-1.0)}
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
	# Regime BEFORE operator build + ground init, so both honor the biome's
	# thermodynamic country (wet → Lindblad operators + thermal init).
	qc.regime_override = str(options.get("regime", ""))
	var sys_builder = BiomeQuantumSystemBuilder.new()
	sys_builder.quantum_computer = qc

	var neighborhood_icons: Array = options.get("neighborhood_icons", [])

	# ── Neighborhood-loadout path ─────────────────────────────────────────────
	for i in range(neighborhood_icons.size()):
		var bi = neighborhood_icons[i]
		qc.allocate_axis(i, bi.pole_0, bi.pole_1)
	VerboseHelper.info("biome", "build", "Neighborhood loadout: %d icons for %s" % [neighborhood_icons.size(), biome_name])
	sys_builder.build_operators_from_icons(biome_name, neighborhood_icons, atom_components)
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


## Get VerboseConfig singleton (safe access)
static func _get_verbose_config():
	var ml := Engine.get_main_loop()
	return ml.root.get_node_or_null("/root/VerboseConfig") if ml and ml.root else null


## INTERNAL: Build Array[Icon] from a neighborhood's loadout.
## Physics is looked up from icons.json via IconRegistry by (pole_0, pole_1) pair.
## Lindblad/decay live on the biome's atom_components, not on icons.
##
## Post-§9-cutover: icons derive from `native_factions` via `Biome.get_neighborhood_icons()`.
static func _build_neighborhood_icon_list(biome_def) -> Array:
	if biome_def != null and biome_def.has_method("get_neighborhood_icons"):
		return _materialize_icon_list(biome_def.get_neighborhood_icons())
	return []


## INTERNAL: Build Array[Icon] from an explicit array of pair-shaped entries
## ({name, pole_0, pole_1}). Used by both the data-side path and the induced
## neighborhood path (options["neighborhood_icons"]).
static func _materialize_icon_list(entries: Array) -> Array:
	var lexicon = (Engine.get_main_loop().root.get_node_or_null("/root/IconRegistry") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	var out: Array = []
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var p0 := str(entry.get("pole_0", ""))
		var p1 := str(entry.get("pole_1", ""))
		if p0 == "" or p1 == "":
			continue
		var physics: Dictionary = lexicon.get_icon_physics_by_pair(p0, p1)
		var iname := str(entry.get("name", p0))
		out.append(Icon.from_pair_physics(iname, p0, p1, physics, 1.0))
	return out


## Resolve the icons a NEIGHBORHOOD installs over this biome. (Icons are a
## neighborhood/faction concern — the biome itself owns only atoms + L.)
##
## Caller-provided `options["neighborhood_icons"]` (Array of {name,pole_0,pole_1})
## takes precedence — that's the path used by IconLoadoutInducer to place a
## neighborhood over a bare biome without mutating biome data.
##
## Otherwise: infer from `native_factions` via `get_neighborhood_icons()`.
static func _resolve_neighborhood_loadout(biome_def, options: Dictionary = {}) -> Dictionary:
	var override = options.get("neighborhood_icons", [])
	if override is Array and not (override as Array).is_empty():
		return {
			"icons": _materialize_icon_list(override),
			"source": "neighborhood",
		}
	return {
		"icons": _build_neighborhood_icon_list(biome_def),
		"source": "biome",
	}
