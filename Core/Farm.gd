class_name Farm
extends Node

# Access autoloads safely (avoids compile-time errors)
@onready var _icon_registry = InstrumentLocator.resolve_icon_registry(self)
@onready var _verbose = InstrumentLocator.resolve_verbose_config(self)

## Farm - Pure simulation manager for quantum wheat farming
## Owns all game systems and handles all game logic
## Emits signals when state changes (no UI dependencies)

# System preloads
# Grid configuration (Phase 2)
const GridConfig = preload("res://Core/GameState/GridConfig.gd")
const PlotConfig = preload("res://Core/GameState/PlotConfig.gd")
const KeyboardLayoutConfig = preload("res://Core/GameState/KeyboardLayoutConfig.gd")
const InputBindingRegistry = preload("res://UI/Core/InputBindingRegistry.gd")
const PhysicsConfig = preload("res://Core/Config/PhysicsConfig.gd")
const GridSentinel = preload("res://Core/GameState/GridSentinel.gd")

const FarmGrid = preload("res://Core/GameMechanics/FarmGrid.gd")
const FarmPlot = preload("res://Core/GameMechanics/FarmPlot.gd")
const FarmEconomy = preload("res://Core/GameMechanics/FarmEconomy.gd")
const EconomyConstants = preload("res://Core/GameMechanics/EconomyConstants.gd")
const ActionCostRuntime = preload("res://Core/GameMechanics/ActionCostRuntime.gd")
const BalanceService = preload("res://Core/GameMechanics/BalanceService.gd")
const TerminalPoolClass = preload("res://Core/GameMechanics/TerminalPool.gd")
const BiomeEvolutionBatcherClass = preload("res://Core/Environment/BiomeEvolutionBatcher.gd")
const GameState = preload("res://Core/GameState/GameState.gd")
const VocabularyEvolution = preload("res://Core/QuantumSubstrate/VocabularyEvolution.gd")
const BiomeDiscoveryForecastService = preload("res://Core/Gameplay/BiomeDiscoveryForecastService.gd")
const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")
const InstrumentLocator = preload("res://Core/Instrumentation/InstrumentLocator.gd")
const VerboseHelper = preload("res://Core/Config/VerboseHelper.gd")

# Icon system moved to faction-based IconRegistry (no preload needed)

# Core simulation systems
var grid: FarmGrid
var economy  # FarmEconomy type
var _loaded_biome_count: int = 0  # Track how many biomes loaded successfully
var vocabulary_evolution: VocabularyEvolution  # Vocabulary evolution system
var known_pairs: Array = []  # Player vocabulary pairs (canonical, farm-owned)
var reap_count: int = 0  # Number of global seasonal reaps completed
var grid_config: GridConfig = null  # Single source of truth for grid layout
var _bootstrap_pool: TerminalPoolClass = null  # Created at boot, transferred to instrument via set_instrument()
var instrument = null  # QuantumInstrument (set via set_instrument() after boot)
## terminal_pool: canonical runtime pool surface. Uses the instrument pool once attached,
## otherwise the bootstrap pool during early boot.
var terminal_pool: TerminalPoolClass:
	get: return instrument.terminal_pool if instrument and instrument.terminal_pool else _bootstrap_pool
var biome_evolution_batcher: BiomeEvolutionBatcherClass = null  # Batched quantum evolution

# Icon system now managed by faction-based IconRegistry (deprecated variables removed)

# PERFORMANCE: Cached mushroom count (avoid O(n) iteration every frame)
var _cached_mushroom_count: int = 0
var _mushroom_count_dirty: bool = true  # Set true when plots change


func _log_debug(message: String) -> void:
	VerboseHelper.debug("farm", "farm", message)


func invalidate_mushroom_cache() -> void:
	"""Call when plots are planted/harvested to recalculate mushroom count on next frame"""
	_mushroom_count_dirty = true


func _get_gsm():
	return InstrumentLocator.resolve_game_state_manager(self)


func _get_player_vocab():
	return InstrumentLocator.resolve_player_vocabulary(self)


func _get_active_biome_manager():
	return InstrumentLocator.resolve_active_biome_manager(self)


func _get_icon_registry_autoload():
	return InstrumentLocator.resolve_icon_registry(self)


func _exit_tree() -> void:
	"""Release runtime-only refs so session shutdown does not orphan the batcher graph."""
	if biome_evolution_batcher and biome_evolution_batcher.has_method("cleanup"):
		biome_evolution_batcher.cleanup()
	biome_evolution_batcher = null
	instrument = null
	_bootstrap_pool = null


func set_instrument(inst) -> void:
	"""Transfer bootstrap terminal pool to instrument and store reference."""
	instrument = inst
	inst.terminal_pool = _bootstrap_pool


func _finalize_biome_evolution_batcher() -> void:
	"""Finalize batched biome evolution setup after all biomes are loaded.

	The batcher was created before biome loading and biomes were registered
	during BootManager.load_biome(). The batcher owns biome process state; this
	finalizer only verifies every loaded biome reached that single owner.
	"""
	if not biome_evolution_batcher:
		push_warning("Farm: Batcher not initialized - cannot finalize")
		return

	var registered_count = 0
	for biome_name in grid.get_biome_names():
		var biome = grid.get_biome(biome_name)
		if biome:
			biome_evolution_batcher.register_biome(biome)
			registered_count += 1

	_log_debug("Farm: Biome evolution batcher finalized (%d biomes verified)" % registered_count)


# Configuration

# Biome availability (may fail to load if icon dependencies are missing)
var biome_enabled: bool = false

# Dynamic grid sizing
const DEFAULT_PLOTS_PER_BIOME = 4
const MAX_PLOTS_PER_BIOME = 7  # J K L ; ' H G
const LINDBLAD_TIMESCALE_BASE_DT = 0.02
const LINDBLAD_TIMESCALE_CAP = 4096.0
const RAINBOW_DRAIN_MODE_DEFAULT = false
const CORE_BIOMES: Array[String] = ["StarterForest", "Village"]

# Dynamic row mappings (built from explored biome order)
var biome_row_map: Dictionary = {}  # biome_name -> row index
var row_biome_map: Dictionary = {}  # row index -> biome_name
var lindblad_rainbow_accumulators: Dictionary = {}  # emoji -> fractional credits remainder

# Special gather actions (not plantable, not buildings)
const GATHER_ACTIONS = {
	"forest_harvest": {
		"cost": {},  # Free - gather natural detritus from forest
		"yields": {"🍂": 5},  # Collect 5 detritus (leaf litter, deadwood)
		"biome_required": "Forest"  # Only works in Forest biome
	}
}

# Signals - emitted when game state changes (no UI callbacks needed)
signal state_changed(state_data: Dictionary)
signal action_result(action: String, success: bool, message: String)
signal action_rejected(action: String, position: Vector2i, reason: String)  # For visual/audio feedback
signal grid_resized(new_config)  # Emitted when grid dimensions change

# ═══════════════════════════════════════════════════════════════════════════════
# TERMINAL LIFECYCLE SIGNALS (EXPLORE/MEASURE/POP actions)
# These trigger bubble visualization in QuantumForceGraph
# ═══════════════════════════════════════════════════════════════════════════════

## Emitted when EXPLORE binds a terminal to a quantum register
signal terminal_bound(grid_position: Vector2i, terminal_id: String, emoji_pair: Dictionary)

## Emitted when MEASURE collapses the terminal's quantum state
signal terminal_measured(grid_position: Vector2i, terminal_id: String, outcome: String, probability: float)

## Emitted when POP releases the terminal back to pool
signal terminal_released(grid_position: Vector2i, terminal_id: String, credits_earned: int)

## Emitted when a biome is loaded dynamically (for visualization updates)
signal biome_loaded(biome_name: String, biome_ref)

## Emitted BEFORE a biome is removed (for cascading cleanup)
signal biome_removed(biome_name: String)

# ═══════════════════════════════════════════════════════════════════════════════
# Plot-facing visualization signals
# These remain intentional because the player-facing UI is plot-oriented even
# though the simulation/runtime path is terminal-oriented underneath.
# ═══════════════════════════════════════════════════════════════════════════════

signal plot_measured(position: Vector2i, outcome: String)

# ═══════════════════════════════════════════════════════════════════════════════
# OTHER SIGNALS
# ═══════════════════════════════════════════════════════════════════════════════

signal plots_entangled(pos1: Vector2i, pos2: Vector2i, bell_state: String)


# ═══════════════════════════════════════════════════════════════════════════════
# CENTRAL SIGNAL EMISSION (DRY Architecture)
# All action→signal mapping in ONE place. UI handlers call this instead of
# emitting signals directly. This ensures headless and headed modes behave
# identically, and tests can trigger visualization by calling this method.
# ═══════════════════════════════════════════════════════════════════════════════

func emit_action_signal(action: String, result: Dictionary, grid_pos: Vector2i = GridSentinel.INVALID_POSITION) -> void:
	"""Central hub for action→signal emission.

	Simulation layer (ProbeActions) returns result dictionaries.
	This method translates those results into appropriate Farm signals.
	Visualization layer observes these signals to update display.

	Args:
		action: Action name ("explore", "measure", "pop", "reap", "build")
		result: Dictionary returned by ProbeActions (must have "success" key)
		grid_pos: Grid position for the action (used by most signals)
	"""
	if not result.get("success", false):
		return  # Only emit signals on successful actions

	match action:
		"explore":
			var terminal = result.get("terminal")
			if terminal:
				# Set grid_position on terminal if not already set
				if "grid_position" in terminal and grid_pos != GridSentinel.INVALID_POSITION:
					terminal.grid_position = grid_pos
				terminal_bound.emit(grid_pos, terminal.terminal_id, result.get("emoji_pair", {}))

		"measure":
			var terminal = result.get("terminal")
			var terminal_id = terminal.terminal_id if terminal else result.get("terminal_id", "")
			if grid_pos != GridSentinel.INVALID_POSITION and grid:
				var plot = grid.get_plot(grid_pos)
				if plot and plot.has_method("remember_measurement"):
					var north = terminal.north_emoji if terminal else ""
					var south = terminal.south_emoji if terminal else ""
					plot.remember_measurement(
						result.get("outcome", ""),
						result.get("probability", result.get("recorded_probability", 0.0)),
						north,
						south
					)
			terminal_measured.emit(grid_pos, terminal_id,
				result.get("outcome", ""), result.get("probability", 0.0))

		"pop":
			terminal_released.emit(grid_pos, result.get("terminal_id", ""),
				int(result.get("credits", 0)))

		"reap":
			var harvest_results = result.get("harvest_results", [])
			if harvest_results is Array and not harvest_results.is_empty():
				for harvest in harvest_results:
					var h_pos = harvest.get("grid_position", GridSentinel.INVALID_POSITION)
					var tid = harvest.get("terminal_id", "")
					var h_credits = int(harvest.get("total_credits", harvest.get("credits", 0)))
					if h_pos != GridSentinel.INVALID_POSITION and tid != "":
						terminal_released.emit(h_pos, tid, h_credits)

		"clear_all":
			# Handle array of harvest/clear results
			var harvest_results = result.get("harvest_results", result.get("terminals", []))
			for harvest in harvest_results:
				var h_pos = harvest.get("grid_position", GridSentinel.INVALID_POSITION)
				var tid = harvest.get("terminal_id", "")
				if h_pos == GridSentinel.INVALID_POSITION and harvest is Object and "grid_position" in harvest:
					h_pos = harvest.grid_position
				if tid == "" and harvest is Object and "terminal_id" in harvest:
					tid = harvest.terminal_id
				if h_pos != GridSentinel.INVALID_POSITION and tid != "":
					terminal_released.emit(h_pos, tid, int(harvest.get("total_credits", 0)))


func _ready():
	# Ensure IconRegistry exists in headless/script harnesses that do not build the
	# full autoload stack through the normal project boot path.
	_ensure_iconregistry()

	# Create core systems
	economy = FarmEconomy.new()
	add_child(economy)

	# Start with a zero-size bootstrap grid and expand once real biomes load.
	grid_config = GridConfig.new()
	grid_config.grid_width = 0
	grid_config.grid_height = 0
	grid = FarmGrid.new(grid_config.grid_width, grid_config.grid_height)
	add_child(grid)

	# Create bootstrap terminal pool; transferred to the instrument once attached.
	var total_plots = grid_config.grid_width * grid_config.grid_height
	_bootstrap_pool = TerminalPoolClass.new(total_plots)
	if grid:
		grid.set_terminal_pool(_bootstrap_pool)

	# Create biome evolution batcher BEFORE loading biomes
	# This allows BootManager.load_biome() to register each biome as it loads
	biome_evolution_batcher = BiomeEvolutionBatcherClass.new()
	biome_evolution_batcher.initialize([], _bootstrap_pool, self)  # Initialize with empty array, biomes register individually

	# Create environmental simulations (six biomes for multi-biome support)
	# UNIFIED LOADING: All biomes go through BootManager.load_biome() for consistency
	# This ensures: script load → grid register → batcher register → operator rebuild
	biome_enabled = false
	_loaded_biome_count = 0

	# Load only unlocked biomes (initially just StarterForest and Village)
	# Other biomes are loaded dynamically when explored via 4E action
	var observation_frame = InstrumentLocator.resolve_observation_frame(self)
	var unlocked_biomes = ["StarterForest", "Village"]  # Default
	if observation_frame and observation_frame.has_method("get_explored_biomes"):
		unlocked_biomes = observation_frame.get_explored_biomes()
	elif observation_frame and observation_frame.has_method("get_unlocked_biomes"):
		unlocked_biomes = observation_frame.get_unlocked_biomes()

	# Load unlocked biomes through unified BootManager.load_biome()
	var boot_manager = InstrumentLocator.resolve_root_node(self, "/root/BootManager")
	for biome_name in unlocked_biomes:
		if boot_manager and boot_manager.has_method("load_biome"):
			var result = boot_manager.load_biome(biome_name, self)
			if result.get("success", false):
				_loaded_biome_count += 1
			else:
				_verbose.warn("boot", "⚠️", "Failed to load biome '%s': %s" % [biome_name, result.get("message", "unknown error")])

	# Enable biome features if at least one biome loaded
	if _loaded_biome_count > 0:
		biome_enabled = true
		_log_debug("Farm: %d biomes loaded successfully (via unified BootManager.load_biome)" % _loaded_biome_count)
	else:
		biome_enabled = false
		push_error("Farm: no biomes loaded - aborting boot")
		return

	# NOTE: Operator rebuild now handled by BootManager in Stage 3A
	# This ensures deterministic ordering: IconRegistry ready → rebuild operators → verify biomes

	# Icon system now managed by faction-based IconRegistry

	# Grid already created (empty) - resize after biomes load
	refresh_grid_for_biomes()

	# Validate grid configuration now that biomes are loaded
	if grid_config.grid_width > 0 and grid_config.grid_height > 0:
		var validation = grid_config.validate()
		if not validation.success:
			push_error("GridConfig validation failed:")
			for error in validation.errors:
				push_error("  - %s" % error)
			return

	# Persist grid dimensions into GameState (source of truth for saves)
	var gsm = _get_gsm()
	if gsm and gsm.current_state:
		gsm.current_state.grid_width = grid_config.grid_width
		gsm.current_state.grid_height = grid_config.grid_height

	# PERFORMANCE: Connect grid signals to invalidate mushroom cache
	grid.plot_planted.connect(func(_pos): invalidate_mushroom_cache())
	terminal_released.connect(func(_pos, _terminal_id, _credits): invalidate_mushroom_cache())

	# Connect economy to grid for mill/market/kitchen flour & bread processing
	grid.farm_economy = economy

	# Note: StellarForges doesn't have direct economy connection (no trading)

	# NOTE: Biomes are already wired to grid by BootManager.load_biome()
	# (No additional registration needed here - unified path handles it)

	# Register grid as metadata for UI systems
	set_meta("grid", grid)

	# Configure plot-to-biome assignments from GridConfig (biomes × plots)
	# Row ordering matches BIOME_ORDER (StarterForest=0, Village=1, then unlocked biomes)
	if biome_enabled and grid and grid.has_method("assign_plot_to_biome"):
		for pos in grid_config.biome_assignments:
			var biome_name = grid_config.biome_assignments[pos]
			grid.assign_plot_to_biome(pos, biome_name)

	# Get persistent vocabulary evolution from GameStateManager
	# The vocabulary persists across farms/biomes and travels with the player
	# Safe access for headless mode where get_tree() may return null
	var game_state_mgr = _get_gsm()
	if game_state_mgr and game_state_mgr.has_method("get_vocabulary_evolution"):
		vocabulary_evolution = game_state_mgr.get_vocabulary_evolution()
	else:
		# Fallback: create local vocabulary if GameStateManager not available
		# This happens in test/standalone scenarios
		var VocabularyEvolution = preload("res://Core/QuantumSubstrate/VocabularyEvolution.gd")
		vocabulary_evolution = VocabularyEvolution.new()
		add_child(vocabulary_evolution)

	# Initialize farm-owned vocabulary (canonical player vocab)
	_ensure_vocabulary_initialized()

	# Inject vocabulary reference into grid for tap validation
	if grid:
		grid.vocabulary_evolution = vocabulary_evolution

	# Finalize biome evolution batcher setup
	# (Batcher was created before biome loading, biomes registered during load)
	# Now disable individual biome _process() to prevent double evolution
	_finalize_biome_evolution_batcher()
	if _verbose:
		_verbose.info("boot", "🧭", "Farm _ready checkpoint: after batcher finalization")

	# Connect economy signals to canonical farm state propagation only.
	var economy_signals = ["wheat_changed", "credits_changed", "flour_changed", "flower_changed", "labor_changed"]
	for sig_name in economy_signals:
		if economy.has_signal(sig_name):
			economy.connect(sig_name, _on_economy_changed)


## ============================================================================
## VOCABULARY (FARM-OWNED)
## ============================================================================

func _ensure_vocabulary_initialized() -> void:
	"""Ensure farm has a valid starting vocabulary."""
	if known_pairs.is_empty():
		set_known_pairs([{"north": "🌾", "south": "👥"}], true, false)
	else:
		_sync_player_vocabulary(false)


func get_known_pairs() -> Array:
	"""Return player-known vocab pairs (canonical)."""
	return known_pairs.duplicate(true)


func get_reap_count() -> int:
	return max(0, reap_count)


func set_reap_count(value: int) -> void:
	reap_count = max(0, value)


func get_known_emojis() -> Array:
	"""Return unique emojis from known vocab pairs."""
	return GameState.derive_known_emojis_from_pairs(known_pairs)


func set_known_pairs(pairs: Array, sync_player_vocab: bool = true, reset_player_vocab: bool = false) -> void:
	"""Replace known vocab pairs with sanitized list."""
	var filtered: Array = []
	var seen: Dictionary = {}
	for pair in pairs:
		if not (pair is Dictionary):
			continue
		var north = pair.get("north", "")
		var south = pair.get("south", "")
		if north == "" or south == "" or north == south:
			continue
		var key = "%s|%s" % [north, south]
		if seen.has(key):
			continue
		seen[key] = true
		filtered.append({"north": north, "south": south})

	if filtered.is_empty():
		filtered = [{"north": "🌾", "south": "👥"}]

	known_pairs = filtered
	if sync_player_vocab:
		_sync_player_vocabulary(reset_player_vocab)
	_sync_current_state_vocab()


func discover_pair(north: String, south: String) -> bool:
	"""Learn a new vocab pair (farm-owned source of truth)."""
	if north == "" or south == "" or north == south:
		return false

	# Check if exact pair already exists
	for pair in known_pairs:
		if pair.get("north", "") == north and pair.get("south", "") == south:
			return false  # Already known

	# North must be new; south may repeat across pairs.
	for pair in known_pairs:
		var existing_north = pair.get("north", "")
		var existing_south = pair.get("south", "")
		if north == existing_north or north == existing_south:
			# North already known (as north or south) - can't add overlapping north
			return false

	known_pairs.append({"north": north, "south": south})
	# Incremental sync: only push the new pair (was O(n²): full _sync_player_vocabulary on every discovery)
	var player_vocab = _get_player_vocab()
	if player_vocab and player_vocab.has_method("learn_vocab_pair"):
		player_vocab.learn_vocab_pair(north, south)
	_sync_current_state_vocab()
	return true


func get_pair_for_emoji(emoji: String) -> Variant:
	"""Return the vocab pair containing an emoji (or null)."""
	for pair in known_pairs:
		if pair.get("north", "") == emoji or pair.get("south", "") == emoji:
			return pair
	return null


func _sync_player_vocabulary(reset_first: bool) -> void:
	"""Keep PlayerVocabulary QC in sync with farm-owned vocabulary."""
	var player_vocab = _get_player_vocab()
	if not player_vocab:
		return
	if reset_first and player_vocab.has_method("reset"):
		player_vocab.reset()
	for pair in known_pairs:
		var north = pair.get("north", "")
		var south = pair.get("south", "")
		if north != "" and south != "":
			if player_vocab.has_method("learn_vocab_pair"):
				player_vocab.learn_vocab_pair(north, south)


func _sync_current_state_vocab() -> void:
	"""Mirror canonical farm vocabulary into the active GameState when present."""
	var gsm = _get_gsm()
	if gsm and "current_state" in gsm and gsm.current_state:
		gsm.current_state.known_pairs = get_known_pairs()


## Rebuild quantum operators after biomes have initialized
func rebuild_all_biome_operators() -> void:
	"""Rebuild quantum operators for all biomes

	Called by BootManager in Stage 3A after IconRegistry is confirmed ready.
	This ensures all biomes have complete Hamiltonian and Lindblad operators
	even if they initialized before IconRegistry loaded all icons.
	"""
	if not biome_enabled:
		return

	_verbose.info("boot", "🔧", "Rebuilding operators for loaded biomes...")
	for biome_name in grid.get_biome_names():
		var biome = grid.get_biome(biome_name)
		if biome and biome.has_method("rebuild_quantum_operators"):
			biome.rebuild_quantum_operators()
	_verbose.info("boot", "✓", "Loaded biome operators rebuilt")


## Called by BootManager in Stage 3A to finalize setup before simulation starts
func finalize_setup() -> void:
	"""Finalize farm setup after all basic initialization.

	Called by BootManager.boot() after biomes are loaded and verified.
	Quantum verification already happened in BootManager.load_biome().
	"""
	_verbose.info("boot", "✓", "Farm setup finalized (%d biomes active)" % _loaded_biome_count)


## Called by BootManager in Stage 3D to enable simulation processing
func enable_simulation() -> void:
	"""Enable the farm simulation to start processing quantum evolution.

	Called by BootManager.boot() after UI is initialized.
	This enables _process() to evolve quantum states in biomes.
	"""
	set_process(true)
	set_physics_process(true)

	# Enable biome processing (only for non-batched biomes)
	# Batched biomes stay disabled - BiomeEvolutionBatcher handles their updates
	if biome_enabled and grid:
		for biome_name in grid.get_biome_names():
			var biome = grid.get_biome(biome_name)
			if biome and not biome.get_meta("batched_evolution", false):
				biome.set_process(true)
		if _verbose:
			_verbose.info("boot", "✓", "All biome processing enabled (batched biomes use BiomeEvolutionBatcher)")

	if _verbose:
		_verbose.info("boot", "✓", "Farm simulation process enabled")


func _process(delta: float):
	# Visual updates only - runs at 60+ FPS independent of quantum simulation
	var t0 = Time.get_ticks_usec()
	# Process grid UI updates (mills, markets, kitchens, etc.)
	if grid:
		grid._process(delta)
	var t1 = Time.get_ticks_usec()

	# Handle passive composting (visual effects)
	_process_mushroom_composting(delta)
	var t2 = Time.get_ticks_usec()

	if Engine.get_process_frames() % 60 == 0:
		# Use 'trace' category (WARN by default, only shown if explicitly enabled at DEBUG level)
		if _verbose:
			_verbose.debug("trace", "🚜", "Farm Process Trace: Total %d us (Grid: %d, Compost: %d)" % [t2 - t0, t1 - t0, t2 - t1])


func _physics_process(delta: float) -> void:
	"""Physics simulation - runs at fixed 20Hz"""
	# BATCHED QUANTUM EVOLUTION (moved here for visual/physics separation)
	# Runs at fixed 20Hz, independent of visual framerate (60+ FPS)
	if biome_evolution_batcher:
		biome_evolution_batcher.physics_process(delta)

	# Lindblad pump/drain effects
	_process_lindblad_effects(delta)


func time_skip_phrames(phrames: int, delta: float = PhysicsConfig.PHRAME_DT) -> Dictionary:
	"""Advance farm physics/evolution synchronously for deterministic headless rig control."""
	var steps = max(0, int(phrames))
	var dt = max(0.000001, float(delta))
	var debug_time_skip = OS.get_environment("RIG_DEBUG_TIMESKIP").to_lower() in ["1", "true", "yes", "on"]
	var skip_lindblad = OS.get_environment("RIG_TIME_SKIP_SKIP_LINDBLAD").to_lower() in ["1", "true", "yes", "on"]
	if steps <= 0:
		return {"ok": true, "phrames": 0, "delta": dt}

	if debug_time_skip:
		_log_debug("[TIME_SKIP] begin steps=%d dt=%.6f skip_lindblad=%s" % [steps, dt, str(skip_lindblad)])

	var evolved_steps = 0
	var skipped_steps = 0
	if biome_evolution_batcher and biome_evolution_batcher.has_method("run_time_skip_cycles"):
		var direct_result = biome_evolution_batcher.run_time_skip_cycles(steps, dt)
		evolved_steps = int(direct_result.get("evolved_steps", 0))
		skipped_steps = int(direct_result.get("skipped_biomes", 0))
		if debug_time_skip:
			_log_debug("[TIME_SKIP] direct_result=%s" % str(direct_result))
	elif biome_evolution_batcher and biome_evolution_batcher.has_method("run_additional_cycles"):
		var batch_result = biome_evolution_batcher.run_additional_cycles(steps)
		evolved_steps = int(batch_result.get("evolved_steps", 0))
		skipped_steps = int(batch_result.get("skipped_due_empty_buffer", 0))
		if debug_time_skip:
			_log_debug("[TIME_SKIP] additional_cycles_result=%s" % str(batch_result))
	else:
		for _i in range(steps):
			if biome_evolution_batcher:
				biome_evolution_batcher.physics_process(dt)
				evolved_steps += 1

	# Lindblad accumulation is farm-level and should track skipped phrames as well.
	if not skip_lindblad:
		if debug_time_skip:
			_log_debug("[TIME_SKIP] applying_lindblad_effects steps=%d" % steps)
		for _i in range(steps):
			_process_lindblad_effects(dt)
	else:
		if debug_time_skip:
			_log_debug("[TIME_SKIP] lindblad_effects_skipped")

	if debug_time_skip:
		_log_debug("[TIME_SKIP] end evolved=%d skipped=%d" % [evolved_steps, skipped_steps])

	return {
		"ok": true,
		"phrames": steps,
		"delta": dt,
		"evolved_steps": evolved_steps,
		"skipped_steps": skipped_steps
	}


func _process_lindblad_effects(delta: float) -> void:
	"""Apply persistent Lindblad pump/drain effects from Tool 2."""
	if not grid:
		return

	if not grid or grid.get_plot_count() == 0:
		return
	var rainbow_mode = _is_rainbow_drain_mode()
	var processed_structural_flux: Dictionary = {}
	var harvestable_drain_biomes: Dictionary = {}

	for pos in grid.get_plot_positions():
		var plot = grid.get_plot(pos)
		if not plot:
			continue
		if not plot.lindblad_pump_active and not plot.lindblad_drain_active:
			continue

		var biome = grid.get_biome_for_plot(pos)
		if not biome or not biome.quantum_computer:
			continue
		var effective_delta = _get_lindblad_effective_delta_for_biome(biome, delta)
		if effective_delta <= 0.0:
			continue
		var biome_name = biome.get_biome_type()
		if biome_name != "" and not processed_structural_flux.has(biome_name):
			_accumulate_sink_flux_from_biome_rates(biome_name, biome, effective_delta)
			processed_structural_flux[biome_name] = true

		var pair = _get_lindblad_pair_for_plot(plot, pos)
		if pair.is_empty():
			continue

		if plot.lindblad_pump_active:
			var target = pair.get("north", "")
			if target != "":
				biome.quantum_computer.apply_drive(target, plot.lindblad_pump_rate, effective_delta)

		if plot.lindblad_drain_active:
			var north = pair.get("north", "")
			var south = pair.get("south", "")
			var axis_emoji = north if north != "" else south
			if axis_emoji != "" and biome.quantum_computer.register_map.has(axis_emoji):
				var sample_emoji = north if north != "" and biome.quantum_computer.register_map.has(north) else axis_emoji
				var before_pop = biome.quantum_computer.get_population(sample_emoji)
				var before_flux = 0.0
				if biome.quantum_computer.has_method("get_sink_flux"):
					before_flux = float(biome.quantum_computer.get_sink_flux(axis_emoji))

				var qubit_idx = biome.quantum_computer.register_map.qubit(axis_emoji)
				biome.quantum_computer.apply_decay(qubit_idx, plot.lindblad_drain_rate, effective_delta)

				var can_harvest = _is_plot_drain_harvest_visible(plot)
				if rainbow_mode:
					if can_harvest and biome_name != "":
						harvestable_drain_biomes[biome_name] = biome
				elif can_harvest:
					var drained_probability = 0.0
					if biome.quantum_computer.has_method("get_sink_flux"):
						var after_flux = float(biome.quantum_computer.get_sink_flux(axis_emoji))
						drained_probability = max(0.0, after_flux - before_flux)
						if drained_probability > 0.0 and biome.quantum_computer.has_method("consume_sink_flux"):
							drained_probability = float(biome.quantum_computer.consume_sink_flux(axis_emoji, drained_probability))
					if drained_probability <= 0.0:
						var after_pop = biome.quantum_computer.get_population(sample_emoji)
						drained_probability = max(0.0, before_pop - after_pop)
					if drained_probability <= 0.0:
						drained_probability = max(0.0, before_pop) * plot.lindblad_drain_rate * effective_delta
					_accumulate_lindblad_harvest(plot, axis_emoji, drained_probability)

	if rainbow_mode and not harvestable_drain_biomes.is_empty():
		_harvest_rainbow_sink_flux(harvestable_drain_biomes)


func _get_lindblad_effective_delta_for_biome(biome, frame_delta: float) -> float:
	"""Scale Lindblad timestep by biome timescale controls (stride + resolution)."""
	var base_delta = maxf(0.0, float(frame_delta))
	if base_delta <= 0.0:
		return 0.0
	if not biome:
		return base_delta

	var stride = 1
	if "observation_stride" in biome:
		stride = max(0, int(biome.observation_stride))
	if stride <= 0:
		return 0.0

	var dt_scale = 1.0
	if "max_evolution_dt" in biome:
		var max_dt = maxf(0.000001, float(biome.max_evolution_dt))
		dt_scale = max_dt / LINDBLAD_TIMESCALE_BASE_DT

	var multiplier = clampf(float(stride) * dt_scale, 0.0, LINDBLAD_TIMESCALE_CAP)
	return base_delta * multiplier


func _accumulate_sink_flux_from_biome_rates(biome_name: String, biome, dt: float) -> void:
	if dt <= 0.0 or not biome or not biome.quantum_computer:
		return
	if not biome.quantum_computer.has_method("accumulate_sink_flux_from_rates"):
		return
	if not biome_evolution_batcher or not biome_evolution_batcher.has_method("get_biome_sink_flux_rates"):
		return
	var sink_rates = biome_evolution_batcher.get_biome_sink_flux_rates(biome_name)
	if sink_rates is Dictionary and not sink_rates.is_empty():
		biome.quantum_computer.accumulate_sink_flux_from_rates(sink_rates, dt)


func _is_plot_drain_harvest_visible(plot) -> bool:
	if not plot:
		return false
	if plot.has_method("_get_infra_field"):
		return bool(plot._get_infra_field("lindblad_harvest_visible", false))
	return false


func _is_rainbow_drain_mode() -> bool:
	var raw = OS.get_environment("SW_RAINBOW_DRAIN_MODE").strip_edges().to_lower()
	if raw == "":
		return RAINBOW_DRAIN_MODE_DEFAULT
	return raw in ["1", "true", "yes", "on"]


func _harvest_rainbow_sink_flux(active_drain_biomes: Dictionary) -> void:
	if not economy:
		return
	for biome_name in active_drain_biomes.keys():
		var biome = active_drain_biomes[biome_name]
		if not biome or not biome.quantum_computer or not biome.quantum_computer.has_method("get_all_sink_fluxes"):
			continue
		var fluxes = biome.quantum_computer.get_all_sink_fluxes()
		if not (fluxes is Dictionary) or fluxes.is_empty():
			continue
		for emoji in fluxes.keys():
			var requested = maxf(0.0, float(fluxes.get(emoji, 0.0)))
			if requested <= 0.0:
				continue
			var consumed = requested
			if biome.quantum_computer.has_method("consume_sink_flux"):
				consumed = float(biome.quantum_computer.consume_sink_flux(str(emoji), requested))
			if consumed <= 0.0:
				continue
			var q2c = EconomyConstants.get_quantum_to_credits(economy)
			var credits = consumed * q2c
			var accum = float(lindblad_rainbow_accumulators.get(emoji, 0.0)) + credits
			var whole = int(accum)
			if whole > 0:
				economy.add_resource(str(emoji), whole, "lindblad_rainbow")
				accum -= whole
			lindblad_rainbow_accumulators[emoji] = maxf(0.0, accum)


func _accumulate_lindblad_harvest(plot, emoji: String, drained_probability: float) -> void:
	if not economy or emoji == "":
		return

	var q2c = EconomyConstants.get_quantum_to_credits(economy)
	var credits = max(0.0, drained_probability) * q2c
	if credits <= 0.0:
		return

	plot.lindblad_drain_accumulator += credits
	if _verbose and Engine.get_process_frames() % 120 == 0:
		_verbose.debug("lindblad", "⏱", "accumulator %s=%.6f" % [emoji, plot.lindblad_drain_accumulator])
	var whole_credits = int(plot.lindblad_drain_accumulator)
	if whole_credits <= 0:
		return

	plot.lindblad_drain_accumulator -= whole_credits
	economy.add_resource(emoji, whole_credits, "lindblad_drain")


func _get_lindblad_pair_for_plot(plot, _pos: Vector2i) -> Dictionary:
	"""Resolve emoji pair for a plot (delegates to terminal when attached)."""
	if plot and plot.is_active():
		return plot.get_plot_emojis()
	return {}


func _process_mushroom_composting(delta: float):
	"""Passive composting: converts detritus → mushrooms based on planted mushroom count

	Composting rate scales with number of planted mushrooms
	Ratio: 2 detritus → 1 mushroom
	"""
	if not economy or not grid:
		return

	# PERFORMANCE: Use cached mushroom count instead of iterating every frame
	if _mushroom_count_dirty:
		_cached_mushroom_count = 0
		for y in range(grid.grid_height):
			for x in range(grid.grid_width):
				var plot = grid.get_plot(Vector2i(x, y))
				if plot and plot.is_active() and plot.plot_type_name == "mushroom":
					_cached_mushroom_count += 1
		_mushroom_count_dirty = false

	if _cached_mushroom_count == 0:
		return  # No composting without mushrooms

	# Only compost if we have detritus
	var detritus_amount = economy.get_resource("🍂")
	if detritus_amount <= 0:
		return

	# Composting parameters
	const COMPOSTING_RATE = 1.0  # 1 detritus per second per mushroom
	const COMPOSTING_RATIO = 0.5  # 2 detritus → 1 mushroom

	# Calculate composting power (scales with mushroom count)
	var activation = min(1.0, float(_cached_mushroom_count) / 4.0)  # Full power at 4 mushrooms
	var detritus_per_frame = COMPOSTING_RATE * activation * delta

	# Accumulate fractional detritus
	if not has_meta("composting_accumulator"):
		set_meta("composting_accumulator", 0.0)

	var accumulator = get_meta("composting_accumulator") + detritus_per_frame

	# Only convert when we've accumulated at least 2 detritus (makes 1 mushroom)
	if accumulator < 2.0:
		set_meta("composting_accumulator", accumulator)
		return

	# Convert accumulated detritus → mushrooms at 2:1 ratio
	var detritus_to_convert = int(accumulator)
	var mushrooms_produced = int(detritus_to_convert * COMPOSTING_RATIO)

	if mushrooms_produced > 0:
		var detritus_consumed = mushrooms_produced * 2  # 2 detritus per mushroom

		# Perform the conversion
		if economy.remove_resource("🍂", detritus_consumed, "composting"):
			economy.add_resource("🍄", mushrooms_produced, "composting")
			# Reset accumulator, keeping remainder
			set_meta("composting_accumulator", accumulator - detritus_consumed)

			_verbose.debug("economy", "🍄", "Composting: %d 🍂 → %d 🍄 (%.1f%% activation, %d mushrooms planted)" % [detritus_consumed, mushrooms_produced, activation * 100, _cached_mushroom_count])
		else:
			# Conversion failed, keep accumulator for next frame
			set_meta("composting_accumulator", accumulator)


## GRID CONFIGURATION (Phase 2 → Single-Biome View → Quantum Instrument)
##
## NEW ARCHITECTURE: Each biome has N independent plots (dynamic).
## Only one biome visible at a time.
## Homerow keys select plots within the current biome.
##
## Grid dimensions are derived from:
##   width  = max plot count across loadable biomes (min 5)
##   height = number of explored biomes loaded into the farm

func _create_grid_config() -> GridConfig:
	"""Create grid configuration - single source of truth for layout

	Quantum Instrument Layout: dynamic grid
	  width  = max plot count across loadable biomes (min 5)
	  height = explored biomes count

	Keyboard layout:
	  Homerow keys map to columns 0..N-1 (N=grid_width)
	"""
	var config = GridConfig.new()
	var explored_biomes = _get_loaded_biomes_in_order()
	if explored_biomes.is_empty():
		return null
	var grid_width = _get_max_biome_plot_count(explored_biomes)
	var grid_height = explored_biomes.size()
	config.grid_width = grid_width
	config.grid_height = grid_height

	# Build dynamic row maps based on explored biome order
	_rebuild_biome_row_maps(explored_biomes)

	# Create keyboard layout configuration
	var keyboard = KeyboardLayoutConfig.new()
	var homerow_keys = InputBindingRegistry.get_plot_keys()

	# Homerow → positions 0..N-1 (within active biome, y determined at runtime)
	var neutral_keys = []
	for i in range(grid_width):
		var key_label = homerow_keys[i] if i < homerow_keys.size() else str(i + 1)
		neutral_keys.append(key_label)
		var pos = Vector2i(i, 0)  # Default to y=0, remapped at runtime
		keyboard.action_to_position["plot_neutral_" + str(i)] = pos
		keyboard.position_to_label[pos] = key_label.to_upper()
		# Also add labels for other biome rows (same x position, different y)
		for biome_row in range(1, grid_height):
			keyboard.position_to_label[Vector2i(i, biome_row)] = key_label.to_upper()

	config.keyboard_layout = keyboard

	# =========================================================================
	# PLOT CONFIGURATIONS - N plots per biome, dynamic total
	# Each biome has independent quantum state and plots
	# =========================================================================

	for biome_name in explored_biomes:
		var biome_row = biome_row_map[biome_name]
		for i in range(grid_width):
			var plot = PlotConfig.new()
			plot.position = Vector2i(i, biome_row)
			plot.is_active = true
			plot.keyboard_label = neutral_keys[i].to_upper()
			plot.input_action = "plot_neutral_" + str(i)
			plot.biome_name = biome_name
			config.plots.append(plot)

			# Set up biome assignment
			config.biome_assignments[Vector2i(i, biome_row)] = biome_name

	return config


func _get_explored_biomes() -> Array[String]:
	"""Get explored biomes (preferred terminology)."""
	var observation_frame = InstrumentLocator.resolve_observation_frame(self)
	if observation_frame and observation_frame.has_method("get_explored_biomes"):
		return observation_frame.get_explored_biomes()
	if observation_frame and observation_frame.has_method("get_unlocked_biomes"):
		return observation_frame.get_unlocked_biomes()
	var gsm = _get_gsm()
	if gsm and gsm.current_state and "unlocked_biomes" in gsm.current_state:
		return gsm.current_state.unlocked_biomes
	return ["StarterForest", "Village"]


func _get_loaded_biomes_in_order() -> Array[String]:
	"""Return explored biomes filtered to those currently loaded (in order)."""
	var explored = _get_explored_biomes()
	var loaded: Array[String] = []
	for biome_name in explored:
		if _is_biome_loaded(biome_name):
			loaded.append(biome_name)
	return loaded


func _is_biome_loaded(biome_name: String) -> bool:
	"""Check if a biome instance is loaded on this Farm."""
	return grid != null and grid.get_biome(biome_name) != null


func _get_loadable_biomes() -> Array[String]:
	"""Get loadable biomes (icon build succeeded)."""
	var observation_frame = InstrumentLocator.resolve_observation_frame(self)
	if observation_frame and observation_frame.has_method("get_loadable_biomes"):
		return observation_frame.get_loadable_biomes()
	# Fallback to explored list if loadable list not available
	return _get_explored_biomes()


func _get_max_biome_plot_count(biome_names: Array[String]) -> int:
	"""Compute max plot count across biome layouts (fallback to DEFAULT_PLOTS_PER_BIOME)."""
	var max_count = 0
	for name in biome_names:
		var biome = _get_loaded_biome_ref(name)
		if biome and biome.quantum_computer and biome.quantum_computer.register_map:
			var count = biome.quantum_computer.register_map.num_qubits
			if count > max_count:
				max_count = count
			continue
		# Fallback: use biome registry plot_layout if biome not loaded yet
		var biome_registry = load("res://Core/Biomes/BiomeRegistry.gd").new()
		var biome_data = biome_registry.get_by_name(name)
		if biome_data and "plot_layout" in biome_data:
			var count2 = biome_data.plot_layout.size()
			if count2 > max_count:
				max_count = count2
	if max_count <= 0:
		max_count = DEFAULT_PLOTS_PER_BIOME
	return min(max_count, MAX_PLOTS_PER_BIOME)


func _get_loaded_biome_ref(biome_name: String):
	return grid.get_biome(biome_name) if grid else null


func _clear_loaded_biome_ref(biome_name: String) -> void:
	var meta_name = biome_name.to_lower() + "_biome"
	if has_meta(meta_name):
		remove_meta(meta_name)


func _release_terminals_in_biome(biome_name: String) -> void:
	if not terminal_pool:
		return

	var terminals_to_release: Array = []
	for terminal in terminal_pool.get_all_terminals():
		if not terminal:
			continue
		var terminal_biome = str(terminal.bound_biome_name if terminal.bound_biome_name != "" else terminal.measured_biome_name)
		if terminal_biome == biome_name:
			terminals_to_release.append(terminal)

	for terminal in terminals_to_release:
		if terminal_pool.has_method("release_terminal"):
			terminal_pool.release_terminal(terminal)
		else:
			terminal_pool.unbind_terminal(terminal)


func _liquidate_biome_resources(biome_name: String, biome) -> Dictionary:
	var out := {
		"flux_totals": {},
		"icon_totals": {},
		"total_flux_credits": 0,
		"total_icon_credits": 0,
		"total_credits": 0
	}
	if not biome or not biome.quantum_computer or not economy:
		return out

	var flux_to_credits = float(BalanceService.get_tuning_value(self, "flux_to_credits", 1.0))
	var removal_base_yield = float(BalanceService.get_tuning_value(self, "reap_base_yield", 50.0)) * 0.5
	var qc = biome.quantum_computer

	var fluxes: Dictionary = qc.get_all_sink_fluxes() if qc.has_method("get_all_sink_fluxes") else {}
	for emoji in fluxes.keys():
		var raw_flux = float(fluxes.get(emoji, 0.0))
		var credits = int(raw_flux * flux_to_credits)
		if credits <= 0:
			continue
		economy.add_resource(str(emoji), credits, "remove_biome_flux")
		out["flux_totals"][emoji] = int(out["flux_totals"].get(emoji, 0)) + credits
		out["total_flux_credits"] = int(out["total_flux_credits"]) + credits
	if qc.has_method("reset_sink_flux"):
		qc.reset_sink_flux()

	var mass_map = ProbeActions._resolve_mass_map_for_biome(biome)
	var by_emoji: Dictionary = mass_map.get("by_emoji", {})
	var total_mass = float(mass_map.get("total", 0.0))
	if total_mass > 0.0:
		for emoji in by_emoji.keys():
			var mass = float(by_emoji.get(emoji, 0.0))
			if mass <= 0.0:
				continue
			var mass_fraction = mass / total_mass
			var purity = ProbeActions._resolve_emoji_purity(biome, str(emoji))
			var credits = int(mass_fraction * removal_base_yield * maxf(purity, 0.25))
			if credits <= 0:
				continue
			economy.add_resource(str(emoji), credits, "remove_biome_iconmap")
			out["icon_totals"][emoji] = int(out["icon_totals"].get(emoji, 0)) + credits
			out["total_icon_credits"] = int(out["total_icon_credits"]) + credits

	out["total_credits"] = int(out["total_flux_credits"]) + int(out["total_icon_credits"])
	out["biome_name"] = biome_name
	return out


func _rebuild_biome_row_maps(biome_list: Array[String]) -> void:
	"""Rebuild row mappings based on explored biome order."""
	biome_row_map.clear()
	row_biome_map.clear()
	for i in range(biome_list.size()):
		var biome_name = biome_list[i]
		biome_row_map[biome_name] = i
		row_biome_map[i] = biome_name


func refresh_grid_for_biomes() -> bool:
	"""Rebuild grid_config and resize grid/terminal_pool when real biomes are loaded."""
	var new_config = _create_grid_config()
	if not new_config:
		push_error("Farm.refresh_grid_for_biomes(): no loaded biomes available")
		return false

	var resized = false
	if not grid_config or new_config.grid_width != grid_config.grid_width or new_config.grid_height != grid_config.grid_height:
		resized = true

	grid_config = new_config

	if resized and grid:
		if grid.has_method("resize_grid"):
			grid.resize_grid(grid_config.grid_width, grid_config.grid_height)
		else:
			grid.grid_width = grid_config.grid_width
			grid.grid_height = grid_config.grid_height

		# Ensure plots exist for new positions
		for plot_cfg in grid_config.get_all_active_plots():
			grid.get_plot(plot_cfg.position)

		# Resize terminal pool to match new grid size
		if terminal_pool:
			terminal_pool.resize(grid_config.grid_width * grid_config.grid_height)

	# Re-assign plot-to-biome mappings (safe even if unchanged)
	if grid and grid.has_method("assign_plot_to_biome"):
		for pos in grid_config.biome_assignments:
			grid.assign_plot_to_biome(pos, grid_config.biome_assignments[pos])

	# Persist dimensions into GameState if available
	var gsm = _get_gsm()
	if gsm and gsm.current_state:
		gsm.current_state.grid_width = grid_config.grid_width
		gsm.current_state.grid_height = grid_config.grid_height

	if resized:
		grid_resized.emit(grid_config)

	return resized


func get_biome_row(biome_name: String) -> int:
	"""Get the row (y-coordinate) for a biome"""
	return biome_row_map.get(biome_name, 0)


func get_biome_for_row(row: int) -> String:
	"""Get the biome name for a row (y-coordinate)"""
	return row_biome_map.get(row, "")


func get_biomes() -> Array:
	"""Get all loaded biomes for testing/diagnostics."""
	if not grid:
		return []
	var result: Array = []
	for biome_name in grid.get_biome_names():
		var biome = grid.get_biome(biome_name)
		if biome:
			result.append(biome)
	return result


func get_plot_position_for_active_biome(plot_index: int) -> Vector2i:
	"""Convert plot index (0-3) to full position using active biome

	Used by input handling to map plot keys to the correct biome's plots.
	Now uses ObservationFrame as the source of truth for active biome.
	"""
	# Clamp plot_index to valid range (0..grid_width-1)
	var max_index = grid_config.grid_width - 1 if grid_config else 3
	plot_index = clampi(plot_index, 0, max_index)

	# Try ObservationFrame first, fall back to ActiveBiomeManager
	var observation_frame = InstrumentLocator.resolve_observation_frame(self)
	var active_biome = "BioticFlux"
	if observation_frame:
		active_biome = observation_frame.get_neutral_biome()
	else:
		var biome_mgr = _get_active_biome_manager()
		if biome_mgr:
			active_biome = biome_mgr.get_active_biome()

	var biome_row = get_biome_row(active_biome)
	return Vector2i(plot_index, biome_row)


## Public API - Game Operations

func can_discover_biome() -> Dictionary:
	"""Check if a new biome can be explored (slots + availability)."""
	var observation_frame = InstrumentLocator.resolve_observation_frame(self)
	if not observation_frame:
		return {"ok": false, "message": "ObservationFrame not available"}

	var biome_mgr = _get_active_biome_manager()
	if not biome_mgr:
		return {"ok": false, "message": "ActiveBiomeManager not available"}
	if biome_mgr.has_method("has_open_biome_slot") and not biome_mgr.has_open_biome_slot():
		return {"ok": false, "message": "Biome slots full"}

	var unexplored = observation_frame.get_unexplored_biomes()
	if unexplored.is_empty():
		return {"ok": false, "message": "All biomes already explored!"}

	var cost_gate = ActionCostRuntime.preflight_action(economy, "discover_biome")
	if not cost_gate.get("ok", true):
		return {"ok": false, "message": "Insufficient resources"}

	return {"ok": true, "unexplored": unexplored}


func can_remove_biome() -> Dictionary:
	"""Check if the current active biome can be liquidated and removed."""
	var observation_frame = InstrumentLocator.resolve_observation_frame(self)
	if not observation_frame:
		return {"ok": false, "message": "ObservationFrame not available"}

	var biome_mgr = _get_active_biome_manager()
	if not biome_mgr:
		return {"ok": false, "message": "ActiveBiomeManager not available"}

	var biome_name = str(biome_mgr.get_active_biome())
	if biome_name == "":
		return {"ok": false, "message": "No active biome"}
	if biome_name in CORE_BIOMES:
		return {"ok": false, "message": "Starter biomes cannot be removed"}
	if observation_frame.get_unlocked_biomes().size() <= CORE_BIOMES.size():
		return {"ok": false, "message": "Need at least one removable biome unlocked"}

	var biome = _get_loaded_biome_ref(biome_name)
	if not biome:
		return {"ok": false, "message": "Biome is not loaded"}

	return {"ok": true, "biome_name": biome_name}

func discover_biome() -> Dictionary:
	"""Explore and unlock a random new biome (4E action)

	Returns:
		Dictionary with:
			- success: bool
			- biome_name: String (if successful)
			- message: String (error or success message)
	"""
	_log_debug("🗺️ discover_biome() called!")

	var gate = can_discover_biome()
	if not gate.get("ok", false):
		var msg = gate.get("message", "Biome exploration blocked")
		_log_debug("❌ %s" % msg)
		return {"success": false, "blocked": true, "message": msg}

	var observation_frame = InstrumentLocator.resolve_observation_frame(self)
	if not observation_frame:
		_log_debug("❌ ObservationFrame not found")
		return {"success": false, "message": "ObservationFrame not available"}

	# Get unexplored biomes
	var unexplored = gate.get("unexplored", observation_frame.get_unexplored_biomes())
	_log_debug("🗺️ Unexplored biomes: %s" % str(unexplored))

	if unexplored.is_empty():
		_log_debug("❌ All biomes already explored")
		return {"success": false, "message": "All biomes already explored!"}

	var weights = BiomeDiscoveryForecastService.compute_weights(self, unexplored)
	var new_biome = BiomeDiscoveryForecastService.weighted_random_pick(unexplored, weights)
	_log_debug("🗺️ Selected biome: %s (weighted discovery)" % new_biome)

	# Unlock it
	var unlocked = observation_frame.unlock_biome(new_biome)
	if not unlocked:
		_log_debug("❌ Failed to unlock biome")
		return {"success": false, "message": "Failed to unlock biome"}
	_log_debug("✅ Biome unlocked successfully")

	# Expand grid to accommodate newly explored biome
	refresh_grid_for_biomes()

	# Load the new biome
	_log_debug("🗺️ Loading biome dynamically...")
	var biome_loaded = _load_biome_dynamically(new_biome)
	if not biome_loaded:
		_log_debug("❌ Biome failed to load")
		return {"success": false, "biome_name": new_biome, "message": "Biome unlocked but failed to load"}
	_log_debug("✅ Biome loaded successfully")

	# Sync with ActiveBiomeManager
	var biome_manager = _get_active_biome_manager()
	if biome_manager:
		biome_manager.set_biome_order(observation_frame.get_unlocked_biomes())
		_log_debug("✅ Synced with ActiveBiomeManager")

	# Switch to the new biome
	if biome_manager:
		var direction = 1  # Slide right (new biome appears)
		biome_manager.set_active_biome(new_biome, direction)
		_log_debug("✅ Switched to new biome: %s" % new_biome)

	if economy and not ActionCostRuntime.commit_action(economy, "discover_biome"):
		return {"success": false, "biome_name": new_biome, "message": "Explore biome failed: unable to spend cost."}

	_log_debug("🗺️ Exploration complete: %s" % new_biome)
	return {"success": true, "biome_name": new_biome, "message": "Discovered %s!" % new_biome}


func remove_biome() -> Dictionary:
	"""Liquidate the active biome from its live quantum state, then unregister it."""
	var gate = can_remove_biome()
	if not gate.get("ok", false):
		return {
			"success": false,
			"blocked": true,
			"message": gate.get("message", "Biome removal blocked")
		}

	var biome_name := str(gate.get("biome_name", ""))
	var biome = _get_loaded_biome_ref(biome_name)
	if not biome:
		return {"success": false, "message": "Biome is not loaded"}

	var liquidation = _liquidate_biome_resources(biome_name, biome)
	_release_terminals_in_biome(biome_name)

	var observation_frame = InstrumentLocator.resolve_observation_frame(self)
	var old_order: Array[String] = observation_frame.get_unlocked_biomes() if observation_frame else []
	var removed_index := old_order.find(biome_name)
	var successor := ""
	for candidate in old_order:
		var candidate_name := str(candidate)
		if candidate_name != biome_name:
			successor = candidate_name
			break
	if removed_index > 0 and removed_index - 1 < old_order.size():
		successor = str(old_order[removed_index - 1])

	if observation_frame and not observation_frame.lock_biome(biome_name):
		return {"success": false, "message": "Failed to remove biome from observation frame"}

	biome_removed.emit(biome_name)

	if biome_evolution_batcher and biome_evolution_batcher.has_method("unregister_biome"):
		biome_evolution_batcher.unregister_biome(biome)

	if grid and grid.has_method("unregister_biome"):
		grid.unregister_biome(biome_name)

	_clear_loaded_biome_ref(biome_name)
	_loaded_biome_count = maxi(0, _loaded_biome_count - 1)

	if is_instance_valid(biome):
		biome.queue_free()

	refresh_grid_for_biomes()

	var biome_manager = _get_active_biome_manager()
	if biome_manager and observation_frame:
		biome_manager.set_biome_order(observation_frame.get_unlocked_biomes())
		if successor != "":
			biome_manager.set_active_biome(successor, -1)

	_emit_state_changed()

	return {
		"success": true,
		"biome_name": biome_name,
		"next_biome": successor,
		"liquidation": liquidation,
		"message": "Removed %s" % biome_name
	}


func compute_discovery_forecast() -> Dictionary:
	"""Compatibility facade over the discovery forecast service."""
	return BiomeDiscoveryForecastService.compute_forecast(self)


func _load_biome_dynamically(biome_name: String) -> bool:
	"""Load a biome at runtime via unified BootManager.load_biome().

	This delegates to BootManager to ensure consistent loading sequence:
	1. Load & instantiate
	2. Register with grid
	3. Assign plots
	4. Rebuild operators (CRITICAL: before batcher registration)
	5. Register with batcher
	6. Emit signals

	Idempotent: if already loaded, returns true without re-initializing.
	"""
	var boot_manager = InstrumentLocator.resolve_root_node(self, "/root/BootManager")
	if not boot_manager:
		push_error("BootManager not found")
		return false

	# Ensure grid is sized for the newly explored biome
	refresh_grid_for_biomes()

	var result = boot_manager.load_biome(biome_name, self)
	if not result.get("success", false):
		var error = result.get("message", "Unknown error")
		push_error("Failed to load biome '%s': %s" % [biome_name, error])
		return false

	# Print success message
	var already = result.get("already_loaded", false)
	if not already:
		_log_debug("🗺️ Dynamically loaded and registered biome: %s" % biome_name)


	return true

func entangle_plots(pos1: Vector2i, pos2: Vector2i, bell_state: String = "phi_plus") -> bool:
	"""Create entanglement between two plots with specified Bell state

	Args:
		pos1: Grid position of first plot
		pos2: Grid position of second plot
		bell_state: "phi_plus" (same correlation), "psi_plus" (opposite correlation)

	Returns:
		bool: True if successful, False if failed

	Emits: plots_entangled signal on success
	"""
	if not grid:
		action_result.emit("entangle", false, "Farm grid not initialized")
		return false

	# Verify both plots exist and are planted
	var plot1 = grid.get_plot(pos1)
	var plot2 = grid.get_plot(pos2)

	if not plot1 or not plot1.is_active():
		action_result.emit("entangle", false, "First plot must be planted!")
		return false

	if not plot2 or not plot2.is_active():
		action_result.emit("entangle", false, "Second plot must be planted!")
		return false

	# Create the entanglement in the grid
	var result = grid.create_entanglement(pos1, pos2, bell_state)

	if result:
		# Emit entanglement signal
		plots_entangled.emit(pos1, pos2, bell_state)
		_emit_state_changed()

		var state_name = "same correlation (Φ+)" if bell_state == "phi_plus" else "opposite correlation (Ψ+)"
		action_result.emit("entangle", true, "🔗 Entangled %s ↔ %s (%s)" % [pos1, pos2, state_name])
		return true
	else:
		action_result.emit("entangle", false, "Failed to create entanglement")
		return false

func get_plot(position: Vector2i):
	"""Get plot at given grid position (returns FarmPlot or subclass)"""
	if grid:
		return grid.get_plot(position)
	return null


func get_state() -> Dictionary:
	"""Get complete game state snapshot for serialization"""
	if not grid or not economy:
		return {}

	var state = {
		"economy": economy.get_all_resources(),
		"plots": []
	}

	# Collect all plot states
	for y in range(grid.grid_height):
		for x in range(grid.grid_width):
			var pos = Vector2i(x, y)
			var plot = grid.get_plot(pos)
			if plot:
				state["plots"].append({
					"position": pos,
					"is_planted": plot.is_active(),
					"emoji": plot.get_semantic_emoji() if plot.is_active() else ""
				})

	return state


## Private Helpers - Biome Access

func _get_plot_biome(pos: Vector2i):
	"""Get biome for plot position. Returns null if biomes disabled or not found."""
	if grid:
		return grid.get_biome_for_plot(pos)
	return null


func _ensure_iconregistry() -> void:
	"""Ensure IconRegistry exists in harnesses that bypass normal autoload boot.

	In normal gameplay: IconRegistry is autoload at /root/IconRegistry
	In script/headless harnesses: create a local root child if needed
	"""
	var icon_registry = _get_icon_registry_autoload()
	if icon_registry:
		# Already exists (normal game mode)
		return

	# Harness mode: create IconRegistry on demand
	var IconRegistryScript = load("res://Core/QuantumSubstrate/IconRegistry.gd")
	if not IconRegistryScript:
		push_error("Failed to load IconRegistry.gd!")
		return

	icon_registry = IconRegistryScript.new()
	icon_registry.name = "IconRegistry"
	# Use get_tree() if available, otherwise just initialize locally
	var tree = get_tree()
	if tree and tree.root:
		tree.root.add_child(icon_registry)
		icon_registry._ready()  # Trigger initialization
		if _verbose:
			_verbose.info("test", "✓", "Test mode: IconRegistry initialized with %d icons" % icon_registry.icons.size())
	else:
		# Headless mode without scene tree - just initialize locally
		icon_registry._ready()
		if _verbose:
			_verbose.info("test", "✓", "Headless mode: IconRegistry initialized with %d icons" % icon_registry.icons.size())


## Private Helpers - Resource & Economy Management
## Now uses FarmEconomy's unified emoji-credits API

func _can_afford_cost(cost: Dictionary) -> bool:
	"""Check if player can afford emoji-credits cost."""
	return economy.can_afford_cost(cost)


func _get_missing_resources(cost: Dictionary) -> String:
	"""Get human-readable list of missing resources."""
	var missing = []
	for emoji in cost.keys():
		var need = cost[emoji]
		var have = economy.get_resource(emoji)
		if have < need:
			var shortfall = (need - have) / EconomyConstants.get_quantum_to_credits(economy)
			missing.append("%d more %s" % [shortfall, emoji])
	return ", ".join(missing)


func _spend_resources(cost: Dictionary, action: String) -> void:
	"""Deduct emoji-credits from economy."""
	economy.spend_cost(cost, action)


func _refund_resources(cost: Dictionary) -> void:
	"""Return emoji-credits to player (failed operation)."""
	for emoji in cost.keys():
		economy.add_resource(emoji, cost[emoji], "refund")


func _emit_state_changed() -> void:
	"""Emit state_changed signal with current game state"""
	state_changed.emit(get_state())


func _on_economy_changed(_value) -> void:
	"""Handle economy signal"""
	_emit_state_changed()
