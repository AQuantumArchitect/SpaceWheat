extends Node

## BootManager — orchestrator for the boot sequence.
##
## Available globally as autoload singleton. Owns top-level boot ordering, awaits, and
## signal emission. Delegates the actual work to three RefCounted helpers:
##   - SessionLoader: state hydration / biome name resolution / loadability checks
##   - WorldBuilder:  Farm/biome materialization, operator rebuild, simulation start
##   - RuntimeMount:  visualization, UI mount, music check
##
## Public API surface: reset(), boot_session(), boot_runtime(),
## boot_initial_biomes(), load_biome(), plus signals
## core_systems_ready / visualization_ready / ui_ready / game_ready.

@onready var _verbose = get_node_or_null("/root/VerboseConfig")
const PerfOptimizer = preload("res://Core/Settings/PerformanceOptimizer.gd")

signal core_systems_ready
signal visualization_ready
signal ui_ready
signal game_ready

var _core_booted: bool = false
var _ui_booted: bool = false
var _booted: bool = false  # Full boot (core + UI)
var _simulation_booted: bool = false
var is_ready: bool = false  # Public flag for checking boot completion
var _boot_start_ms: int = 0

# Registries for O(1) lookups
var _biome_registry = null  # BiomeRegistry (lazy-loaded)

# Helpers (constructed in _ready)
var _session_loader: SessionLoader
var _world_builder: WorldBuilder
var _runtime_mount: RuntimeMount


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		pass  # Cleanup handled by individual components


## The native quantum engine (quantum_matrix GDExtension) is the ONLY physics
## authority — there is no GDScript understudy. A build without it must refuse
## to run rather than limp (or silently freeze). ClassDB check, not assert():
## asserts are stripped from release exports.
const REQUIRED_NATIVE_CLASSES: Array[String] = [
	"QuantumMatrixNative",       # matrix algebra (Eigen)
	"QuantumEvolutionEngine",    # per-biome evolution kernel (exact-unitary + Lindblad)
	"MultiBiomeLookaheadEngine", # batched lookahead across biomes
	"QuantumMythosEngine",       # faction density matrix ops
]


## Autoload singleton - ready to use as global
func _ready() -> void:
	for cls in REQUIRED_NATIVE_CLASSES:
		if not ClassDB.class_exists(cls):
			var msg := "FATAL: native class %s missing — the quantum_matrix GDExtension did not load. The game cannot run without its native engine (dev: cd native && make)." % cls
			push_error(msg)
			printerr(msg)
			if DisplayServer.get_name() != "headless":
				OS.alert("SpaceWheat's native quantum engine failed to load.\nThe install is broken or the platform is unsupported.\n\nMissing: %s" % cls, "SpaceWheat — cannot start")
			get_tree().quit(1)
			return

	_verbose.info("boot", "🔧", "BootManager autoload ready")

	# Optimize performance based on detected hardware
	PerfOptimizer.optimize_for_platform()

	# Pre-load BiomeRegistry for fast lookups
	_biome_registry = BiomeRegistry.new()
	_verbose.debug("boot", "📚", "BiomeRegistry initialized (%d biomes)" % _biome_registry.get_all().size())

	# Construct helpers
	_session_loader = SessionLoader.new(_biome_registry)
	_world_builder = WorldBuilder.new(_biome_registry, _verbose)
	_runtime_mount = RuntimeMount.new(_verbose)


func reset() -> void:
	# Reset all boot flags so a new session can boot cleanly.
	# Called by GameStateManager._reset_runtime_singletons() between sessions.
	_core_booted = false
	_ui_booted = false
	_booted = false
	_simulation_booted = false
	is_ready = false
	_boot_start_ms = 0


func _mark_boot_start_if_needed() -> void:
	if _boot_start_ms == 0:
		_boot_start_ms = Time.get_ticks_msec()


func _boot_elapsed_ms() -> int:
	if _boot_start_ms == 0:
		return 0
	return Time.get_ticks_msec() - _boot_start_ms


func _boot_timing(message: String) -> void:
	_verbose.info("boot", "⏱", "T+%dms %s" % [_boot_elapsed_ms(), message])


## Canonical boot entrypoint.
## Accepts a normalized boot request dictionary and an optional farm parent.
## Public boot forms are handled directly by boot_session() and boot_runtime().
func boot_session(request: Dictionary = {}, farm_parent: Node = null) -> Node:
	# Boot core systems and ensure Farm exists (no UI).
	if not (request is Dictionary):
		push_error("BootManager.boot_session expects a Dictionary boot request")
		return null
	var boot_request := SaveStore.normalize_boot_request(request)
	var request_slot := int(boot_request.get("slot", -1))
	var request_scenario := str(boot_request.get("scenario_id", SaveStore.DEFAULT_SCENARIO_ID))
	var request_headless := bool(boot_request.get("headless", false))

	var gsm = get_node_or_null("/root/GameStateManager")
	if _core_booted:
		return gsm.get_active_farm() if gsm and gsm.has_method("get_active_farm") else null

	_mark_boot_start_if_needed()
	_verbose.info("boot", "🚀", "======================================================================")
	_verbose.info("boot", "🚀", "BOOT SESSION STARTING")
	_verbose.info("boot", "🚀", "======================================================================")
	_boot_timing("boot_session start")

	if not gsm:
		push_warning("BootManager: GameStateManager not found")
		return null

	var farm = await gsm.session_lifecycle.start_session(request_slot, request_scenario, true, farm_parent, false)
	if not farm:
		push_warning("BootManager: Farm not available after start_session")
		return null
	_boot_timing("session started")

	var biome_boot = boot_initial_biomes(farm, gsm.current_state)
	if not bool(biome_boot.get("success", false)):
		push_warning("BootManager: initial biome boot failed: %s" % biome_boot.get("message", "unknown error"))
		return null
	_boot_timing("initial biomes loaded")

	if farm.has_method("finalize_initial_biome_boot") and not farm.finalize_initial_biome_boot():
		push_warning("BootManager: Farm initial biome finalization failed")
		return null
	_boot_timing("farm biome boot finalized")

	# session_lifecycle is the canonical boot-finalizer: it applies state THEN
	# emits farm_ready. Bypassing it (calling apply_state_to_game directly)
	# would skip the signal and leave FarmView un-refreshed.
	await gsm.session_lifecycle.complete_session_boot(farm)
	_boot_timing("session state applied")

	# Stage 3A: Core Systems
	_world_builder.stage_core_systems(farm)
	_boot_timing("core systems initialized")
	core_systems_ready.emit()

	# Core gameplay API must exist even without UI so headless runners and exports
	# can drive real actions through the same surface as the player.
	_world_builder.ensure_quantum_instrument(farm)
	_boot_timing("instrument ready")

	# Stage 3D: Start Simulation
	# Headless and non-GameRoot boots need the simulation immediately.
	# GameRoot-based boots defer this until UI is mounted so physics does not race
	# the headed bootstrap and emit lookahead warnings while the view stack is still
	# coming online.
	if request_headless or farm_parent == null:
		_start_simulation(farm)

	_core_booted = true

	# Headless or no UI expected → finalize boot here
	if request_headless:
		_booted = true
		is_ready = true
		_verbose.info("boot", "✅", "BOOT COMPLETE (headless) - GAME READY")
		_boot_timing("headless game ready")
		game_ready.emit()

	return farm


func boot_initial_biomes(farm: Node, state = null) -> Dictionary:
	# Delegates to WorldBuilder; kept as public API for orchestration callers.
	return _world_builder.boot_initial_biomes(farm, state, _session_loader)


## Canonical runtime/UI mount entrypoint.
func boot_runtime(farm: Node, shell: Node, quantum_viz: Node = null) -> void:
	# Boot visualization + UI after core is ready.

	if _ui_booted:
		return
	if not farm:
		push_warning("BootManager: boot_runtime called with null farm")
		return
	if not shell:
		push_warning("BootManager: boot_runtime called with null shell")
		return

	_mark_boot_start_if_needed()
	_verbose.info("boot", "🚀", "======================================================================")
	_verbose.info("boot", "🚀", "BOOT RUNTIME STARTING")
	_verbose.info("boot", "🚀", "======================================================================")
	_boot_timing("boot_runtime start")

	# Stage 3B: Visualization
	_runtime_mount.stage_visualization(farm, quantum_viz)
	_boot_timing("visualization initialized")
	visualization_ready.emit()

	# Stage 3C: UI (async - must await to ensure QuantumInstrumentInput is created)
	_runtime_mount.stage_ui(farm, shell, quantum_viz, _world_builder)
	_boot_timing("ui initialized")
	ui_ready.emit()

	_ui_booted = true

	if not _simulation_booted:
		_start_simulation(farm)

	if _core_booted:
		# Stage 3E: Music (cherry on top - after all UI is ready)
		_runtime_mount.stage_music()

		_booted = true
		is_ready = true  # Set flag before emitting signal
		_verbose.info("boot", "✅", "======================================================================")
		_verbose.info("boot", "✅", "BOOT SEQUENCE COMPLETE - GAME READY")
		_verbose.info("boot", "✅", "======================================================================")
		_boot_timing("full game ready")
		game_ready.emit()


func _start_simulation(farm: Node) -> void:
	if _simulation_booted or not farm:
		return
	_world_builder.stage_start_simulation(farm)
	_simulation_booted = true
	_boot_timing("simulation started")


## ============================================================================
## UNIFIED BIOME LOADING - Used by both boot and lazy-load paths
## ============================================================================
##
## Public delegator. Called by:
## - BootManager.boot_initial_biomes() during boot (via WorldBuilder)
## - Farm.discover_biome() at runtime (discover_biome action)

func load_biome(biome_name: String, farm: Node) -> Dictionary:
	return _world_builder.load_biome(biome_name, farm)


func stage_core_systems_for(farm) -> void:
	# Public seam for path-based loads (SaveLoadCoordinator._attach_state_to_
	# fresh_farm): shutdown_session resets the story substrate (StoryEngine
	# graph → null), and that lane bypasses the full boot — without re-staging,
	# every loaded save played on with "Story substrate not ready" (marathon #2
	# lost six legs to it). Idempotent: start_for_session no-ops when built.
	if _world_builder == null:
		return
	_world_builder.stage_core_systems(farm)
	_world_builder.ensure_quantum_instrument(farm)
	# Re-wire the quest⇄story lifecycle for the loaded farm — ALL THREE binds
	# PlayerShell does when the UI attaches (PlayerShell.gd:744-751), not just
	# the farm ref. Without connect_to_economy the restored quests evaluate
	# and settle against the PREVIOUS farm's dead economy: progress bars
	# frozen at 0%, deliveries refused with sufficient funds (marathons #2/#7).
	# All idempotent — signals guard, restore skips existing quests.
	var qm = farm.get("quest_manager") if farm else null
	if qm != null:
		var econ = farm.get("economy")
		if econ != null and qm.has_method("connect_to_economy"):
			qm.connect_to_economy(econ)
		if qm.has_method("connect_to_biome"):
			var abm = get_node_or_null("/root/ActiveBiomeManager")
			var active_name: String = str(abm.get_active_biome()) if (abm and abm.has_method("get_active_biome")) else ""
			var biome = farm.grid.get_biome(active_name) if (farm.get("grid") != null and active_name != "") else null
			if biome != null:
				qm.connect_to_biome(biome)
		if qm.has_method("connect_to_farm"):
			qm.connect_to_farm(farm)
