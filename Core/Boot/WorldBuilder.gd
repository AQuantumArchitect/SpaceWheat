class_name WorldBuilder
extends RefCounted

## Materializes the simulation world from a hydrated GameState.
##
## Owns:
## - Initial biome loading loop (boot_initial_biomes)
## - Single-biome load path used at boot AND runtime (load_biome — called by Farm.discover_biome)
## - Operator rebuild decisions and execution
## - Lookahead buffer priming
## - Quantum instrument creation
## - Simulation start
## - BIOME_ORDER sync to ActiveBiomeManager / ObservationFrame
##
## Pure builder; no view-side concerns. BootManager owns orchestration; WorldBuilder owns materialization.


var _biome_registry  # Shared with SessionLoader
var _verbose         # Injected from BootManager (VerboseConfig)


func _init(biome_registry, verbose) -> void:
	_biome_registry = biome_registry
	_verbose = verbose


func biome_operators_look_valid(biome) -> bool:
	if not biome:
		return false
	var qc = biome.get("quantum_computer")
	if not qc:
		return false
	var h = qc.get("hamiltonian")
	if not h:
		return false
	if h.has_method("dimension") and int(h.dimension()) <= 0:
		return false
	return true


func should_rebuild_biome_operators(farm: Node) -> bool:
	if RuntimeEnv.force_operator_rebuild():
		return true
	if RuntimeEnv.skip_operator_rebuild():
		return false
	if not farm or not farm.grid or not farm.grid.has_biomes():
		return false
	for biome_name in farm.grid.get_biome_names():
		var biome = farm.grid.get_biome(biome_name)
		if not biome_operators_look_valid(biome):
			return true
	return false


func boot_initial_biomes(farm: Node, state, session_loader) -> Dictionary:
	if not farm:
		return {"success": false, "error": "farm_null", "message": "Farm not provided"}
	if not state:
		return {"success": false, "error": "state_null", "message": "GameState not provided"}
	if not farm.get("grid") or not farm.get("grid_config"):
		return {"success": false, "error": "farm_uninitialized", "message": "Farm core systems not initialized"}

	var resolve_result: Dictionary = session_loader.resolve_initial_biome_names(state)
	if not bool(resolve_result.get("success", false)):
		return resolve_result
	var biome_names: Array[String] = resolve_result.get("biomes", [])

	var active_biome := str(state.active_biome_name) if "active_biome_name" in state else ""
	if active_biome == "":
		return {"success": false, "error": "active_biome_empty", "message": "GameState.active_biome_name is empty"}
	if active_biome not in biome_names:
		return {
			"success": false,
			"error": "active_biome_not_loaded",
			"message": "Active biome '%s' is not in unlocked_biomes" % active_biome
		}

	var loaded: Array[String] = []
	var failures: Array[String] = []
	for biome_name in biome_names:
		var result = load_biome(biome_name, farm)
		if result.get("success", false):
			loaded.append(biome_name)
		else:
			failures.append("%s: %s" % [biome_name, result.get("message", "unknown error")])

	if not failures.is_empty():
		return {
			"success": false,
			"error": "load_failed",
			"message": "Initial biome load failed (%s)" % "; ".join(failures)
		}

	sync_biome_progression_autoloads(state)
	_verbose.info("boot", "✓", "Initial biomes loaded: %s" % ", ".join(loaded))
	return {
		"success": true,
		"loaded": loaded,
	}


func sync_biome_progression_autoloads(state) -> void:
	var loaded: Array[String] = state.unlocked_biomes.duplicate()
	var active_biome := str(state.active_biome_name)

	# RefCounted has no Node scope; resolve via main loop where available.
	# ObservationFrame is the single authority for biome order (slop-patrol
	# Tier 3); its biome_order_changed signal fans out to ActiveBiomeManager.
	var observation_frame = (Engine.get_main_loop().root.get_node_or_null("/root/ObservationFrame") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if observation_frame:
		if observation_frame.has_method("set_biome_order"):
			observation_frame.set_biome_order(loaded)
		if observation_frame.has_method("set_neutral_biome"):
			observation_frame.set_neutral_biome(active_biome)

	var active_biome_manager = (Engine.get_main_loop().root.get_node_or_null("/root/ActiveBiomeManager") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if active_biome_manager:
		if active_biome_manager.has_method("set_biome_order"):
			# Idempotent: the mirror applies locally and only writes back to
			# the authority if it has diverged (covers partial headless boots
			# and the window before ABM's deferred signal connect).
			active_biome_manager.set_biome_order(loaded)
		if active_biome_manager.has_method("set_active_biome"):
			active_biome_manager.set_active_biome(active_biome)


func stage_core_systems(farm: Node) -> void:
	# Stage 3A: verify components, rebuild operators if needed, prime lookahead.
	_verbose.info("boot", "📍", "Stage 3A: Core Systems")

	# Verify required components (hard failures - these are critical)
	assert(farm != null, "Farm is null!")
	assert(farm.grid != null, "Farm.grid is null!")

	# Boot requires at least one real biome runtime.
	var has_biomes = farm.grid.has_biomes()
	assert(has_biomes, "BootManager: no biomes loaded - boot aborted")

	# Verify IconRegistry is available and fully loaded
	var icon_registry = (Engine.get_main_loop().root.get_node_or_null("/root/IconRegistry") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	assert(icon_registry != null, "IconRegistry not found! Autoloads not initialized.")

	# Wait for IconRegistry to finish loading if needed
	if icon_registry.atoms.size() == 0:
		push_warning("IconRegistry not fully loaded yet, waiting...")
		# RefCounted can't await get_tree(); rely on caller having allowed a frame to elapse.
		# In practice the registry initializes via autoload _ready before BootManager runs.

	_verbose.info("boot", "✓", "IconRegistry ready (%d icons)" % icon_registry.atoms.size())

	# CRITICAL: Rebuild biome quantum operators now that IconRegistry is guaranteed ready.
	# Biomes may have initialized before IconRegistry loaded all icons.
	if has_biomes:
		if should_rebuild_biome_operators(farm):
			_verbose.info("boot", "🔧", "Rebuilding biome quantum operators...")
			if farm.has_method("rebuild_all_biome_operators"):
				farm.rebuild_all_biome_operators()
			else:
				# Fallback: rebuild each biome directly
				for biome_name in farm.grid.get_biome_names():
					var biome = farm.grid.get_biome(biome_name)
					if biome and biome.has_method("rebuild_quantum_operators"):
						biome.rebuild_quantum_operators()
			_verbose.info("boot", "✓", "All biome operators rebuilt")
		else:
			_verbose.info("boot", "✓", "Biome quantum operators already valid; skipping rebuild")

		# Verify all biomes initialized correctly
		for biome_name in farm.grid.get_biome_names():
			var biome = farm.grid.get_biome(biome_name)
			if not biome:
				_verbose.warn("boot", "⚠️", "Biome '%s' is null - skipping" % biome_name)
				continue
			if not biome.quantum_computer:
				_verbose.warn("boot", "⚠️", "Biome '%s' has no quantum_computer after rebuild" % biome_name)
				continue
			_verbose.info("boot", "✓", "Biome '%s' verified" % biome_name)
	else:
		_verbose.info("boot", "⏭️", "Skipping biome operations (no biomes)")

	# Any additional farm finalization
	if farm.has_method("finalize_setup"):
		farm.finalize_setup()

	# Prime lookahead buffers so viz_cache is populated before visualization starts.
	if ("biome_evolution_batcher" in farm) and farm.biome_evolution_batcher:
		if farm.biome_evolution_batcher.has_method("prime_lookahead_buffers"):
			farm.biome_evolution_batcher.prime_lookahead_buffers()
			_verbose.info("boot", "✓", "Lookahead buffers primed")
			if farm.biome_evolution_batcher.lookahead_enabled:
				_verbose.info(
					"boot",
					"✓",
					"Native lookahead active: %d biomes, %d-phrame buffer" % [
						farm.biome_evolution_batcher.biomes.size(),
						farm.biome_evolution_batcher.LOOKAHEAD_STEPS,
					]
				)

	# NOTE: Music moved to Stage 3E - runs after all UI is ready

	# Story substrate: session-scope, populated here rather than at autoload boot.
	var story_engine = (Engine.get_main_loop().root.get_node_or_null("/root/StoryEngine") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if story_engine and story_engine.has_method("start_for_session"):
		story_engine.start_for_session()

	_verbose.info("boot", "✓", "Core systems ready")


func stage_start_simulation(farm: Node) -> void:
	# Stage 3D: Start simulation (core runs even without UI)
	_verbose.info("boot", "📍", "Stage 3D: Start Simulation")

	# Enable farm processing
	farm.set_process(true)
	if farm.has_method("enable_simulation"):
		farm.enable_simulation()
	_verbose.info("boot", "✓", "Farm simulation enabled")

	# Enable input processing (done separately to avoid input during boot)
	_verbose.info("boot", "✓", "Input system enabled")
	_verbose.info("boot", "✓", "Ready to accept player input")

	# The Gallery: attach an attract reel iff one was requested (SW_REEL env
	# or --reel=path user arg). Any input exits the reel to live play.
	ReelRunner.maybe_attach(farm)

	# The Gallery: postcards — F12 captures the view with a physics watermark
	# strip in the pixels + a sidecar certificate (user://postcards/).
	PostcardCapture.maybe_attach(farm)

	# The signpost: one toast naming the doors. Without it the tutorial can sit
	# unseen on the quest board — nothing else tells a new player to press C.
	var shell = InstrumentLocator.resolve_player_shell(farm)
	if shell != null and shell.has_method("show_hint"):
		shell.show_hint("🌾 the forest is asleep — the top chips open the doors: 📋 quests [C] · 📖 guide [X] · 🕸 network [N] · 🗺 map [M]", 2, "")


func ensure_quantum_instrument(farm: Node):
	# Create the core gameplay instrument once and share it with UI surfaces later.
	if not farm:
		return null
	if "instrument" in farm and farm.instrument:
		return farm.instrument
	var QuantumInstrumentClass = load("res://Core/Instrumentation/QuantumInstrument.gd")
	var instrument = QuantumInstrumentClass.new()
	instrument.setup(farm)
	farm.set_instrument(instrument)
	return instrument


## Unified biome loading - single source of truth for boot AND runtime (Farm.discover_biome).
## Order: 1. Load script & instantiate, 2. Register with grid, 3. Assign plots,
##        4. Rebuild quantum operators, 5. Register with batcher, 6. Emit signals.
func load_biome(biome_name: String, farm: Node) -> Dictionary:
	# ====== PRE-CONDITION CHECKS ======
	if not farm:
		return {"success": false, "error": "farm_null", "message": "Farm not provided"}
	if not farm.grid:
		return {"success": false, "error": "grid_null", "message": "Farm.grid not initialized"}
	if not farm.grid_config:
		return {"success": false, "error": "grid_config_null", "message": "Farm.grid_config not initialized"}

	# ====== CHECK IF ALREADY LOADED ======
	if farm.grid.has_biome(biome_name):
		var existing_biome = farm.grid.get_biome(biome_name)
		if existing_biome:
			if "_loaded_biome_count" in farm:
				farm._loaded_biome_count = farm.grid.get_biome_names().size()
			_verbose.debug("boot", "ℹ️", "Biome '%s' already loaded (idempotent)" % biome_name)
			return {
				"success": true,
				"biome_name": biome_name,
				"biome_ref": existing_biome,
				"already_loaded": true
			}

	# ====== STEP 1: LOAD & INSTANTIATE FROM REGISTRY ======
	var biome = null
	var result = BiomeBuilder.build_from_registry(biome_name, farm.grid, {"skip_tree_add": true})

	if result.success:
		biome = result.biome_node
		_verbose.debug("boot", "🔧", "Built '%s' from BiomeRegistry" % biome_name)
	else:
		_verbose.error("boot", "❌", "BiomeBuilder failed: %s" % result.error)

	if not biome:
		_verbose.error("boot", "❌", "Failed to load biome: %s" % biome_name)
		return {"success": false, "error": "load_failed", "message": "Could not load biome for '%s'" % biome_name}

	# Registry-built biomes are created off-tree. They still need a real owner so
	# _exit_tree() runs and the runtime graph is released on session shutdown.
	if biome.get_parent() == null:
		farm.add_child(biome)
		_verbose.debug("boot", "🌱", "Attached '%s' to Farm scene tree" % biome_name)

	# ====== STEP 2: REGISTER WITH GRID ======
	farm.grid.register_biome(biome_name, biome)
	biome.grid = farm.grid
	_verbose.debug("boot", "✓", "Registered '%s' with grid" % biome_name)

	# ====== STEP 2.5: UPDATE GRID CONFIG ======
	if farm.has_method("refresh_grid_for_biomes"):
		farm.refresh_grid_for_biomes()
		_verbose.debug("boot", "📐", "Grid refreshed for loaded biomes")

	# ====== STEP 3: ASSIGN PLOTS FROM GridConfig ======
	if farm.grid and farm.grid_config and farm.grid.has_method("assign_plot_to_biome"):
		for pos in farm.grid_config.biome_assignments:
			if farm.grid_config.biome_assignments[pos] == biome_name:
				farm.grid.assign_plot_to_biome(pos, biome_name)
	_verbose.debug("boot", "✓", "Assigned plots for '%s'" % biome_name)

	# ====== STEP 4: STORE METADATA ======
	farm.set_meta(biome_name.to_lower() + "_biome", biome)

	# ====== STEP 5: REBUILD OPERATORS ======
	# CRITICAL: Must happen BEFORE batcher registration.
	# IconRegistry should be ready by this point (checked in Stage 3A).
	var icon_registry = (Engine.get_main_loop().root.get_node_or_null("/root/IconRegistry") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if icon_registry and biome.has_method("rebuild_quantum_operators"):
		biome.rebuild_quantum_operators()
		_verbose.debug("boot", "✓", "Rebuilt operators for '%s'" % biome_name)
	elif not icon_registry:
		_verbose.warn("boot", "⚠️", "IconRegistry not available for '%s'" % biome_name)

	# Verify quantum substrate is actually populated. Neighborhood biomes (any biome
	# whose spec has a neighborhood icon loadout) MUST end up with a non-null QC
	# and Hamiltonian — otherwise they tick on a dead substrate and the parallel
	# lookahead engine replays stale physics. Empty L is OK only when the biome
	# has no atom_components.
	var spec = biome.get_meta("biome_def", null)
	var spec_icons: Array = []
	var atoms: Dictionary = {}
	if spec != null:
		if spec is Dictionary:
			atoms = spec.get("atom_components", {})
		else:
			if spec.has_method("get_neighborhood_icons"):
				spec_icons = spec.get_neighborhood_icons()
			if "atom_components" in spec and spec.atom_components is Dictionary:
				atoms = spec.atom_components
	var has_icons: bool = spec_icons is Array and not (spec_icons as Array).is_empty()
	if has_icons:
		if not biome.quantum_computer or not biome.quantum_computer.hamiltonian:
			push_error("Biome '%s' built with icons[] but has no Hamiltonian — silent dead-substrate drift" % biome_name)
		elif biome.quantum_computer.hamiltonian.has_method("frobenius_norm") and biome.quantum_computer.hamiltonian.frobenius_norm() < 1e-9:
			# A non-null but all-zero H is just as dead — U(t)=I, nothing evolves,
			# Berry phase never ripens, the whole progression loop stalls. This is
			# exactly the failure a poisoned operator cache produced; flag it loudly
			# rather than ticking forever on an inert substrate.
			push_error("Biome '%s' built with icons[] but Hamiltonian is all-zero — dead-substrate (likely a poisoned operator cache)" % biome_name)
		else:
			# In a closed biome no Lindblad operators are built — empty L is the
			# intended state, not drift. Only flag the open-regime invariant
			# (per-biome: wet country must have its operators; What Fades seam).
			var has_atoms: bool = atoms is Dictionary and not (atoms as Dictionary).is_empty()
			if has_atoms and biome.quantum_computer.is_open_here() and biome.quantum_computer.lindblad_operators.is_empty():
				push_error("Biome '%s' is OPEN with atom_components but zero Lindblad operators built" % biome_name)
	elif not biome.quantum_computer:
		# Data-store biome with no icons — null QC is expected, no warning.
		pass

	# ====== STEP 6: REGISTER WITH BATCHER ======
	if farm.biome_evolution_batcher and farm.biome_evolution_batcher.has_method("register_biome"):
		farm.biome_evolution_batcher.register_biome(biome)
		_verbose.debug("boot", "✓", "Registered '%s' with batcher" % biome_name)
	else:
		_verbose.warn("boot", "⚠️", "Batcher not available for '%s'" % biome_name)

	# ====== STEP 7: EMIT SIGNALS ======
	if farm.has_signal("biome_loaded"):
		farm.biome_loaded.emit(biome_name, biome)

	if "_loaded_biome_count" in farm:
		farm._loaded_biome_count = farm.grid.get_biome_names().size()

	_verbose.info("boot", "✓", "Biome loaded: %s" % biome_name)
	return {
		"success": true,
		"biome_name": biome_name,
		"biome_ref": biome,
		"already_loaded": false
	}
