class_name BiomeEvolutionBatcher
extends RefCounted

## BiomeEvolutionBatcher - native batched evolution for all biomes
##
## Batched lookahead mode (single C++ call for all biomes × N steps)
##
## Performance Optimization: Skip evolution for biomes with no bound terminals
## ("Out of sight, out of mind" - don't evolve unpopulated biomes)

const BiomeDeterministicStepperClass = preload("res://Core/Environment/BiomeDeterministicStepper.gd")

func _log(level: String, category: String, emoji: String, message: String) -> void:
	VerboseHelper.log(level, category, emoji, message)

func _log_debug(message: String) -> void:
	_log("debug", "biome", "batch", message)


const _PC = preload("res://Core/Config/PhysicsConfig.gd")

# Configuration
const EVOLUTION_INTERVAL = _PC.PHRAME_DT  # Phrame rate (see PhysicsConfig)

# Lookahead configuration (Stage 2)
const ENABLE_LOOKAHEAD = true   # C++ batched lookahead: fills per-biome position buffers consumed by QuantumForceGraph.
const LOOKAHEAD_STEPS = 13  # 13 phrames × PHRAME_DT = ~2.2s lookahead (Fib[6])
const LOOKAHEAD_DT = _PC.PHRAME_DT  # Time per phrame (see PhysicsConfig)
const MAX_SUBSTEP_DT = _PC.MAX_SUBSTEP_DT  # Numerical stability limit
const MIN_BUFFER_STEPS = 3
const TARGET_BUFFER_STEPS = LOOKAHEAD_STEPS
const MAX_BUFFER_STEPS = LOOKAHEAD_STEPS * 2

# Phase-shadow LNN configuration (disabled by default to avoid boot-time stalls)
var use_phase_lnn: bool = false  # Enable LNN phase modulation in C++ engine
const LNN_HIDDEN_DIVISOR = 4  # hidden_size = dim / LNN_HIDDEN_DIVISOR

# State
var biomes: Array = []  # All registered biomes
var evolution_accumulator: float = 0.0

# TerminalPool reference for bound terminal checks
var terminal_pool = null
var farm_ref = null

# Stage 2: Lookahead engine and buffers
var lookahead_engine = null  # EvolutionBackend (NativeBackend wraps the C++ MultiBiomeLookaheadEngine)
var lookahead_enabled: bool = false
var lookahead_accumulator: float = 0.0
var _lookahead_init_started: bool = false

# Runtime toggles (env-driven)
var _disable_lookahead_env: bool = false
var _disable_mi_env: bool = false
var _disable_force_env: bool = false
var _headless_env: bool = false
var _packet_pacing_delay_ms: int = 0
var _max_packet_steps: int = FIB_SEQUENCE[FIB_SEQUENCE.size() - 1]

class BiomeLookaheadBuffer:
	var frames: Array = []  # Array[PackedFloat64Array]
	var cursor: int = 0
	var latest_mi: PackedFloat64Array = PackedFloat64Array()
	var mi_steps: Array = []  # Array[PackedFloat64Array]
	var bloch_steps: Array = []  # Array[PackedFloat64Array]
	var purity_steps: Array = []  # Array[float]
	var positions: Array = []  # Array[PackedVector2Array]
	var metadata: Dictionary = {}
	var couplings: Dictionary = {}
	var icon_map: Dictionary = {}

	func clear() -> void:
		frames.clear()
		cursor = 0
		latest_mi = PackedFloat64Array()
		mi_steps.clear()
		bloch_steps.clear()
		purity_steps.clear()
		positions.clear()
		metadata.clear()
		couplings.clear()
		icon_map.clear()


var _lookahead_buffers: Dictionary = {}  # biome_name -> BiomeLookaheadBuffer
var _deterministic_stepper = null

# Native engine biome ID tracking (fixes index mismatch on unregister)
# Maps biome_name -> engine_biome_id for correct result distribution
var _biome_engine_ids: Dictionary = {}  # biome_name -> int (engine biome ID)
var _engine_id_to_biome: Dictionary = {}  # engine_id -> biome_name (reverse lookup)
var _biome_engine_dims: Dictionary = {}  # biome_name -> int (registered dimension)
var biome_last_good_rho: Dictionary = {}  # biome_name -> PackedFloat64Array
var biome_last_good_bloch: Dictionary = {}  # biome_name -> PackedFloat64Array
var biome_last_good_purity: Dictionary = {}  # biome_name -> float
var biome_dirty: Dictionary = {}  # biome_name -> bool (buffer invalidated)
var biome_pending_reregister: Dictionary = {}  # biome_name -> bool
## The physics_signature the C++ engine's H/L copy was (re)registered FROM, per biome.
## The engine holds its own copy of the operators; this records which build it came from
## so drift between the live builders and the engine's copy can be DETECTED (signature
## mismatch) rather than relying on a caller remembering to mark_for_reregister.
var _biome_registered_signature: Dictionary = {}  # biome_name -> String

# Signal for user action (invalidates lookahead)
signal user_action_detected

# Signal emitted when a biome has its 10-step lookahead buffers primed and is ready
signal biome_ready(biome_name: String)

# Pending biomes waiting for native engine to be ready
var _pending_biomes: Array = []

# Biome oval centers (world-space) pushed from QuantumForceGraph via update_biome_center().
# Stored here so they can be re-applied once deferred native engine initialization finishes.
var _biome_centers_cache: Dictionary = {}  # biome_name -> Vector2
var _engine_ready: bool = false

# Runtime activity ledger
var _active_biome_names: Dictionary = {}  # biome_name -> true
var _activity_refresh_needed: bool = true
var _activity_poll_accumulator: float = 0.0
const ACTIVITY_POLL_INTERVAL: float = 1.0

# === ADAPTIVE FIBONACCI BATCHING ===
# Two-state machine: RECOVERY (ramp up) and COAST (maintain)
# RECOVERY: Buffer low → Fibonacci batch sizes (1,1,2,3,5,8...) to recover quickly
# COAST: Buffer healthy → fixed batch size for lazy maintenance

enum BufferState { RECOVERY, COAST }

const FIB_SEQUENCE: Array[int] = [1, 1, 2, 3, 5, 8, 13, 21]  # Fibonacci packet sizes (in phrames)
const INITIAL_BIOME_FIB_INDEX: int = 6  # Fib[6] = 13, matching LOOKAHEAD_STEPS.
const BATCH_TIME_SMOOTHING: float = 0.3  # EMA smoothing

# === PER-BIOME ADAPTIVE STATE (Self-Balancing) ===
# Each biome independently tracks its own RECOVERY/COAST state and Fibonacci index
var biome_buffer_states: Dictionary = {}  # biome_name -> BufferState (RECOVERY/COAST)
var biome_fib_indices: Dictionary = {}    # biome_name -> int (Fibonacci index)
var biome_emergency_refill: Dictionary = {}  # biome_name -> bool (hit depth=0)
var biome_last_escalation_time: Dictionary = {}  # biome_name -> float (msec timestamp of last fib increment)

# === Runtime packet scheduler ===
var biome_paused: Dictionary = {}         # biome_name -> bool (no peeked terminals, skip evolution)
var biome_manual_paused: Dictionary = {}  # biome_name -> bool (explicit user/debug pause)
var biome_evolution_counts: Dictionary = {}  # biome_name -> int (cumulative evolution steps, for music ghost timer)
var _degenerate_warned_at: Dictionary = {}   # biome_name -> last warn time_ms (throttle: one warning per 5s per biome)
var _packet_queue: Array = []             # Pending synchronous native packet requests
var _active_packet_request: Dictionary = {}

# Physics frame guard (prevents duplicate calls in same frame)
var _last_physics_frame: int = -1

# Emergency rescue: Time-based starvation detection (Tier 1 - Tactical)
const EMERGENCY_RESCUE_STEPS = 5           # Small packet: 5 phrames
const EMERGENCY_SAFETY_MARGIN = 1.5        # Trigger when buffer_time < batch_time × 1.5
const EMERGENCY_CRITICAL_DEPTH = 2          # Only rescue when biome is critically low (<= 2 phrames)
const EMERGENCY_COOLDOWN_MS = 600           # Prevent rescue-loop lock-in (global packet cooldown)
const EMERGENCY_LOG_INTERVAL_MS = 5000      # Throttle repetitive starvation logs per-biome
var _last_emergency_packet_time_ms: int = 0
var _rescue_starving_state: Dictionary = {}  # biome_name -> bool
var _rescue_last_log_ms: Dictionary = {}  # biome_name -> int
var _rescue_suppressed_logs: Dictionary = {}  # biome_name -> int

# Statistics
var total_evolutions: int = 0
var last_batch_time_ms: float = 0.0
var lookahead_refills: int = 0
const LOOKAHEAD_INIT_TIMEOUT_MS = 3000

# Physics FPS tracking
var _physics_frame_count: int = 0
var _physics_fps_start_time: int = 0
var physics_frames_per_second: float = 0.0
var slices_consumed_per_second: float = 0.0  # total across all active biomes
var active_biome_count: int = 0              # non-paused biomes in last window
var _slices_consumed_count: int = 0          # accumulator for current window
var fps_window_last_ms: int = 0              # wall-clock ms of last window close

# Runtime pacing and stall watchdog
var _max_phrame_hz_cap: float = 0.0
var _min_phrame_interval_ms: float = 0.0
var _last_phrame_wall_ms: int = 0
var _throttled_phrame_skips: int = 0
var _packet_started_at_ms: int = 0
var _packet_completed_at_ms: int = 0
var _watchdog_last_log_ms: int = 0
var _watchdog_stall_warnings: int = 0
const WATCHDOG_LOG_INTERVAL_MS: int = 2000
const WATCHDOG_STALL_MS: int = 5000    # 5s before first stall warning (was 12s)
const WATCHDOG_FALLBACK_THRESHOLD: int = 2  # 2 warnings × 2s interval = ~9s to fallback (was 3 × 12s)

# Diagnostics
var _evolution_tick_count: int = 0

# Frame timing
var _avg_batch_time_ms: float = 10.0
var _avg_frame_time_ms: float = 16.67
var _last_frame_time: int = 0


func _notification(what: int) -> void:
	# Handle cleanup when object is freed.
	if what == NOTIFICATION_PREDELETE:
		if lookahead_engine and is_instance_valid(lookahead_engine):
			lookahead_engine = null


func _cleanup_lookahead_engine() -> void:
	# Clean up C++ lookahead engine to prevent memory leaks.
	#
	# Call this explicitly before destroying the batcher, or let _notification handle it.
	# GDExtension objects are automatically freed when unreferenced.
	if lookahead_engine and is_instance_valid(lookahead_engine):
		lookahead_engine = null


func abort_for_quit() -> void:
	# Fast shutdown path for application exit: disable new work and free C++ engine.
	#
	# The MultiBiomeLookaheadEngine destructor has no background workers to join,
	# so freeing immediately is safe and avoids ObjectDB leak warnings at exit.
	_teardown_runtime_state()


func cleanup() -> void:
	# Explicit teardown for farm/session shutdown.
	_teardown_runtime_state()


func _teardown_runtime_state() -> void:
	lookahead_enabled = false
	_engine_ready = false
	_lookahead_init_started = false

	_disconnect_runtime_activity_signals()

	_cleanup_lookahead_engine()

	biomes.clear()
	_pending_biomes.clear()
	_packet_queue.clear()
	_active_packet_request.clear()

	_lookahead_buffers.clear()
	_active_biome_names.clear()
	_biome_centers_cache.clear()
	_biome_engine_ids.clear()
	_engine_id_to_biome.clear()
	_biome_engine_dims.clear()
	biome_last_good_rho.clear()
	biome_last_good_bloch.clear()
	biome_last_good_purity.clear()
	biome_dirty.clear()
	biome_pending_reregister.clear()
	_biome_registered_signature.clear()

	biome_buffer_states.clear()
	biome_fib_indices.clear()
	biome_emergency_refill.clear()
	biome_last_escalation_time.clear()
	biome_paused.clear()
	biome_manual_paused.clear()
	biome_evolution_counts.clear()
	_rescue_starving_state.clear()
	_rescue_last_log_ms.clear()
	_rescue_suppressed_logs.clear()
	_activity_refresh_needed = true
	_activity_poll_accumulator = 0.0
	_last_phrame_wall_ms = 0
	_throttled_phrame_skips = 0
	_packet_started_at_ms = 0
	_packet_completed_at_ms = 0

	terminal_pool = null
	farm_ref = null
	if _deterministic_stepper and _deterministic_stepper.has_method("bind_batcher"):
		_deterministic_stepper.bind_batcher(null)
	_deterministic_stepper = null


func initialize(biome_array: Array, p_terminal_pool = null, p_farm = null):
	# Initialize batcher with all farm biomes.
	#
	# Args:
	# biome_array: Array of BiomeBase instances
	# p_terminal_pool: Optional TerminalPool for bound terminal optimization
	# p_farm: Optional Farm reference for infrastructure-aware evolution checks
	_disconnect_runtime_activity_signals()
	terminal_pool = p_terminal_pool
	farm_ref = p_farm
	if _deterministic_stepper == null:
		_deterministic_stepper = BiomeDeterministicStepperClass.new(self)
	else:
		_deterministic_stepper.bind_batcher(self)

	# Resolve runtime flags once per session — all via the single RuntimeEnv authority
	# (which owns the headless-guard: RIG_* flags are honored only headless, so a HEADED
	# rig runs the player's exact physics — lookahead + MI + force).
	_headless_env = RuntimeEnv.is_headless()
	_disable_lookahead_env = RuntimeEnv.disable_lookahead()
	_disable_mi_env = RuntimeEnv.disable_mi()
	_disable_force_env = RuntimeEnv.disable_force()
	_packet_pacing_delay_ms = max(0, RuntimeEnv.env_int("SW_PACKET_PACING_DELAY_MS", 0))
	_max_packet_steps = max(1, RuntimeEnv.env_int("SW_MAX_PACKET_STEPS", FIB_SEQUENCE[FIB_SEQUENCE.size() - 1]))
	# Godot already drives Farm._physics_process at PhysicsConfig.PHYSICS_TICKS_HZ.
	# A second wall-clock phrame cap drops jittery 99ms physics ticks and lowers PhHz.
	var default_hz = 0.0
	_max_phrame_hz_cap = max(0.0, RuntimeEnv.env_float("SW_MAX_PHRAME_HZ", default_hz))
	if _max_phrame_hz_cap > 0.0:
		_min_phrame_interval_ms = 1000.0 / _max_phrame_hz_cap
	else:
		_min_phrame_interval_ms = 0.0

	# Filter valid biomes (not null, has quantum computer)
	biomes = biome_array.filter(func(b):
		return b != null and b.quantum_computer != null
	)
	for biome in biomes:
		var biome_name = _get_biome_name(biome)
		_initialize_biome_runtime_state(biome_name, true)

	_connect_runtime_activity_signals()
	_refresh_runtime_activity(true)

	_log_debug("BiomeEvolutionBatcher: Registered %d biomes for batch evolution" % biomes.size())

	# The C++ backend is the CANONICAL evolver — always set it up when the native lib is
	# available, INDEPENDENT of the lookahead-buffering flag. `_disable_lookahead_env` now
	# gates ONLY the live N-phrame BUFFERING (applied via `lookahead_enabled` below); the
	# backend still evolves time-skip (the deterministic stepper's native cycle) and the
	# direct live step. The mixed-dim crash that originally forced this flag is fixed
	# (Phase 2), so "re-enable when fixed" (per 🟢.sh) is satisfied.
	if ENABLE_LOOKAHEAD:
		_setup_lookahead_engine()
	if _disable_lookahead_env:
		_log_debug("  Lookahead BUFFERING disabled by env flag — backend still evolves (time-skip + direct).")

	if lookahead_enabled:
		_log_debug("  Mode: C++ batched lookahead (%d phrames × %.1fs = %.1fs buffer)" % [
			LOOKAHEAD_STEPS, LOOKAHEAD_DT, LOOKAHEAD_STEPS * LOOKAHEAD_DT
		])
	else:
		_log_debug("  Mode: Waiting for C++ engine initialization")

	if terminal_pool:
		_log_debug("  Optimization: Skip evolution for biomes with no bound terminals")


func _connect_runtime_activity_signals() -> void:
	if terminal_pool:
		if terminal_pool.has_signal("terminal_bound"):
			InstrumentLocator._safe_connect(terminal_pool.terminal_bound, _on_terminal_pool_terminal_bound)
		if terminal_pool.has_signal("terminal_unbound"):
			InstrumentLocator._safe_connect(terminal_pool.terminal_unbound, _on_terminal_pool_terminal_unbound)
		if terminal_pool.has_signal("terminal_measured"):
			InstrumentLocator._safe_connect(terminal_pool.terminal_measured, _on_terminal_pool_terminal_measured)


func _disconnect_runtime_activity_signals() -> void:
	if terminal_pool:
		if terminal_pool.has_signal("terminal_bound"):
			InstrumentLocator._safe_disconnect(terminal_pool.terminal_bound, _on_terminal_pool_terminal_bound)
		if terminal_pool.has_signal("terminal_unbound"):
			InstrumentLocator._safe_disconnect(terminal_pool.terminal_unbound, _on_terminal_pool_terminal_unbound)
		if terminal_pool.has_signal("terminal_measured"):
			InstrumentLocator._safe_disconnect(terminal_pool.terminal_measured, _on_terminal_pool_terminal_measured)


func _on_terminal_pool_terminal_bound(terminal: RefCounted, _register_id: int) -> void:
	_mark_biome_activity_dirty(terminal.bound_biome_name if terminal else "")


func _on_terminal_pool_terminal_unbound(terminal: RefCounted) -> void:
	_mark_biome_activity_dirty(terminal.bound_biome_name if terminal else "")


func _on_terminal_pool_terminal_measured(terminal: RefCounted, _outcome: String) -> void:
	_mark_biome_activity_dirty(terminal.bound_biome_name if terminal else "")


func _mark_biome_activity_dirty(_biome_name: String = "") -> void:
	_activity_refresh_needed = true


func _refresh_runtime_activity(force: bool = false) -> void:
	if not force and not _activity_refresh_needed:
		return

	var next_active: Dictionary = {}
	for biome in biomes:
		if not _is_valid_biome(biome):
			continue
		var biome_name = _get_biome_name(biome)
		var has_activity = not biome_manual_paused.get(biome_name, false)
		has_activity = has_activity and biome.quantum_evolution_enabled and not biome.evolution_paused
		if has_activity:
			has_activity = _biome_has_bound_terminals(biome, true)
		if has_activity:
			next_active[biome_name] = true

		var was_paused = biome_paused.get(biome_name, false)
		var paused_now = not has_activity
		biome_paused[biome_name] = paused_now

		if was_paused != paused_now:
			if has_activity:
				_log_debug("[BiomeEvolution] %s: RESUMED (terminal bound)" % biome_name)
			else:
				_log_debug("[BiomeEvolution] %s: PAUSED (no bound terminals)" % biome_name)

	_active_biome_names = next_active
	_activity_refresh_needed = false
	_activity_poll_accumulator = 0.0


func register_biome(biome) -> void:
	# Register a biome with the batcher for evolution tracking.
	#
	# TERMINOLOGY: register_biome() adds biome to evolution tracking.
	# The batcher then "enrolls" it in the native engine (internal detail).
	# Registering also transfers _process ownership from the biome to this
	# batcher, so callers do not need to remember a second process-state ritual.
	#
	# IDEMPOTENT: Safe to call multiple times. If biome is already registered,
	# this method reasserts batch ownership and returns.
	#
	# If native engine isn't ready yet, queues the biome for later registration.
	# Biome is only 'ready' after its 10-step lookahead buffers are primed.
	if not _is_valid_biome(biome):
		return

	var biome_name = _get_biome_name(biome)
	if biomes.has(biome):
		_claim_batched_evolution(biome)
		_log("debug", "batcher", "ℹ️", "Biome '%s' already registered (idempotent)" % biome_name)
		return

	biomes.append(biome)
	_claim_batched_evolution(biome)

	# Initialize per-biome buffered native output (empty until primed)
	var lookahead_buffer = _ensure_lookahead_buffer(biome_name)
	lookahead_buffer.clear()
	_sync_biome_structure_payload(biome)

	_initialize_biome_runtime_state(biome_name, true)
	_mark_biome_activity_dirty(biome_name)

	# If native engine is ready, register and prime immediately
	if _engine_ready and lookahead_engine:
		_register_and_prime_biome(biome)
	else:
		# Queue for later - native engine still initializing
		_pending_biomes.append(biome)
		_log_debug("BiomeEvolutionBatcher: Queued biome '%s' (waiting for native engine)" % biome_name)


func unregister_biome(biome) -> void:
	# Unregister a biome from the batcher (lightweight cleanup).
	#
	# NOTE: The native engine doesn't support unregistration, so engine biome IDs
	# accumulate. This method only removes the biome from batcher tracking.
	# The engine will receive empty rhos for unregistered biomes and skip them.
	#
	# Args:
	# biome: The biome to unregister
	if not biome:
		return

	var biome_name = _get_biome_name(biome)

	# Remove from biomes array
	var idx = biomes.find(biome)
	if idx >= 0:
		biomes.remove_at(idx)

	# Clean up per-biome runtime state.
	_erase_lookahead_buffer(biome_name)
	_active_biome_names.erase(biome_name)
	_biome_engine_dims.erase(biome_name)
	_erase_biome_runtime_state(biome_name)
	_mark_biome_activity_dirty(biome_name)

	# NOTE: We do NOT remove from _biome_engine_ids or _engine_id_to_biome
	# because the native engine still has this biome registered.
	# The mapping is needed to correctly skip this biome during result processing.

	_log_debug("BiomeEvolutionBatcher: Unregistered biome '%s' from batcher (engine id retained)" % biome_name)
	_release_batched_evolution(biome)


func _claim_batched_evolution(biome) -> void:
	if not biome:
		return
	biome.set_meta("batched_evolution", true)
	if biome.has_method("set_process"):
		biome.set_process(false)


func _release_batched_evolution(biome) -> void:
	if not biome:
		return
	biome.set_meta("batched_evolution", false)


func _initialize_biome_runtime_state(biome_name: String, assume_paused: bool) -> void:
	if biome_name == "":
		return

	biome_buffer_states[biome_name] = BufferState.RECOVERY
	biome_fib_indices[biome_name] = INITIAL_BIOME_FIB_INDEX
	biome_emergency_refill[biome_name] = false
	biome_last_escalation_time[biome_name] = 0.0
	biome_dirty[biome_name] = false
	biome_pending_reregister[biome_name] = false
	biome_manual_paused[biome_name] = false
	biome_paused[biome_name] = assume_paused
	biome_evolution_counts[biome_name] = 0
	_rescue_starving_state[biome_name] = false
	_rescue_last_log_ms[biome_name] = 0
	_rescue_suppressed_logs[biome_name] = 0


func _erase_biome_runtime_state(biome_name: String) -> void:
	if biome_name == "":
		return

	biome_last_good_rho.erase(biome_name)
	biome_last_good_bloch.erase(biome_name)
	biome_last_good_purity.erase(biome_name)
	biome_dirty.erase(biome_name)
	biome_pending_reregister.erase(biome_name)
	biome_buffer_states.erase(biome_name)
	biome_fib_indices.erase(biome_name)
	biome_emergency_refill.erase(biome_name)
	biome_last_escalation_time.erase(biome_name)
	biome_paused.erase(biome_name)
	biome_manual_paused.erase(biome_name)
	biome_evolution_counts.erase(biome_name)
	_rescue_starving_state.erase(biome_name)
	_rescue_last_log_ms.erase(biome_name)
	_rescue_suppressed_logs.erase(biome_name)
	if _deterministic_stepper:
		_deterministic_stepper.reset_stride_carry(biome_name)


func _register_native_biome(biome) -> int:
	# Register one biome with the native engine and sync its structural payload.
	if not lookahead_engine or not _is_valid_biome(biome):
		return -1

	var qc = biome.quantum_computer
	var dim = qc.register_map.dim()
	var num_qubits = qc.register_map.num_qubits
	var H_packed = qc.hamiltonian._to_packed() if qc.hamiltonian else PackedFloat64Array()

	var lindblad_triplets: Array = []
	for L in qc.lindblad_operators:
		if L:
			lindblad_triplets.append(_matrix_to_triplets(L))

	var biome_id = lookahead_engine.register_biome(dim, H_packed, lindblad_triplets, num_qubits)
	if biome_id < 0:
		return biome_id

	var biome_name = _get_biome_name(biome)
	_biome_engine_ids[biome_name] = biome_id
	_engine_id_to_biome[biome_id] = biome_name
	_biome_engine_dims[biome_name] = dim
	# Record the physics fingerprint this engine copy was built from (drift anchor).
	_biome_registered_signature[biome_name] = str(qc.physics_signature)
	_sync_biome_structure_payload(biome, biome_id)

	# Wire the coherent generator switch into the C++ engine (two-axis isolation). The
	# dissipative switch is implicit: L operators are only built/registered when dissipation
	# is on. Together these make all four physics quadrants correct through the native engine.
	if lookahead_engine.has_method("set_biome_coherent"):
		lookahead_engine.set_biome_coherent(biome_id, BalanceConfig.coherent_enabled())

	if use_phase_lnn and lookahead_engine.has_method("enable_biome_lnn"):
		var hidden_size = max(4, dim / LNN_HIDDEN_DIVISOR)
		lookahead_engine.enable_biome_lnn(biome_id, hidden_size)

	return biome_id


func _register_and_prime_biome(biome) -> void:
	# Register a single biome with native engine and prime its buffers.
	#
	# If the biome is already registered with the engine (e.g., by TestBootManager),
	# skips engine registration and just primes the buffers.
	if not lookahead_engine or not _is_valid_biome(biome):
		return

	var qc = biome.quantum_computer
	var dim = qc.register_map.dim()
	var _num_qubits = qc.register_map.num_qubits
	var biome_name = _get_biome_name(biome)

	# Check if biome is already registered with engine (by TestBootManager or other caller)
	var biome_id = _biome_engine_ids.get(biome_name, -1)

	if biome_id >= 0:
		var engine_dim = _biome_engine_dims.get(biome_name, dim)
		if engine_dim != dim:
			biome_pending_reregister[biome_name] = true
			_log("warn", "batcher", "⚠️", "%s: engine dim %d != qc dim %d, scheduling re-register" % [
				biome_name, engine_dim, dim
			])
			return
		_biome_engine_dims[biome_name] = dim

	if biome_id < 0:
		biome_id = _register_native_biome(biome)

	if biome_id >= 0:
		_sync_biome_structure_payload(biome, biome_id)

	lookahead_enabled = (lookahead_engine.get_biome_count() > 0) and not _disable_lookahead_env
	lookahead_accumulator = LOOKAHEAD_DT * LOOKAHEAD_STEPS

	# Apply cached biome center (set by update_layout before or after engine init)
	if biome_id >= 0 and lookahead_engine.has_method("set_biome_center"):
		var cached_center = _biome_centers_cache.get(biome_name, Vector2.ZERO)
		if cached_center != Vector2.ZERO:
			lookahead_engine.set_biome_center(biome_id, cached_center)

	# Prime the biome's 10-step lookahead buffers
	if lookahead_enabled and biome_id >= 0:
		_prime_single_biome(biome, biome_id)
		biome_dirty[biome_name] = false
		_log_debug("BiomeEvolutionBatcher: Registered biome '%s' (native id=%d, primed)" % [biome_name, biome_id])
		biome_ready.emit(biome_name)
	else:
		push_warning("BiomeEvolutionBatcher: Native registration failed for '%s'. Biome will remain stalled until the C++ engine is available." % biome_name)


func _setup_lookahead_engine():
	# Set up the evolution backend (NativeBackend → C++ MultiBiomeLookaheadEngine) if available.
	if NativeBackend.native_available():
		call_deferred("_create_lookahead_engine_deferred")
		return

	# Engine not yet available - wait up to timeout before reporting stalled native init.
	if not _lookahead_init_started:
		_lookahead_init_started = true
		call_deferred("_await_lookahead_engine")


func _await_lookahead_engine() -> void:
	var tree = Engine.get_main_loop()
	if not tree or not tree is SceneTree:
		push_warning("[BiomeEvolutionBatcher] No SceneTree — cannot initialize the C++ lookahead engine.")
		_lookahead_init_started = false
		return

	var start_ms = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ms < LOOKAHEAD_INIT_TIMEOUT_MS:
		if NativeBackend.native_available():
			_create_lookahead_engine_deferred()
			_lookahead_init_started = false
			return
		await tree.process_frame

	push_warning("[BiomeEvolutionBatcher] Timeout waiting for the C++ lookahead engine. Evolution remains stalled.")
	_lookahead_init_started = false


func _create_lookahead_engine_deferred() -> void:
	# Acquire the evolution backend through the abstraction (NativeBackend wraps the C++
	# engine; Web/Torch backends drop in here later). The batcher drives it through the
	# EvolutionBackend contract — duck-typed, so existing lookahead_engine.* calls forward.
	lookahead_engine = EvolutionBackend.create()
	if not lookahead_engine:
		push_warning("[BiomeEvolutionBatcher] No evolution backend available. Evolution remains stalled.")
		return
	if _disable_mi_env and lookahead_engine.has_method("set_enable_mi"):
		lookahead_engine.set_enable_mi(false)
	if _disable_force_env and lookahead_engine.has_method("set_enable_force"):
		lookahead_engine.set_enable_force(false)
	if lookahead_engine.has_method("set_pacing_delay_ms"):
		lookahead_engine.set_pacing_delay_ms(_packet_pacing_delay_ms)

	_log_debug("  MultiBiomeLookaheadEngine: Engine created, processing pending biomes...")

	# Process any biomes that were queued while waiting for engine
	var biomes_to_register = _pending_biomes.duplicate()
	_pending_biomes.clear()

	# Also include any biomes already in the biomes array (from initialize())
	for biome in biomes:
		if not biomes_to_register.has(biome):
			biomes_to_register.append(biome)

	var start_ms = Time.get_ticks_msec()
	var registered_biomes: Array = []

	# Register each biome with the native engine
	for biome in biomes_to_register:
		if Time.get_ticks_msec() - start_ms > LOOKAHEAD_INIT_TIMEOUT_MS:
			push_warning("[BiomeEvolutionBatcher] C++ engine init timed out during registration. Evolution remains stalled.")
			lookahead_engine = null
			lookahead_enabled = false
			_engine_ready = false
			return

		if not _is_valid_biome(biome):
			continue

		var biome_name = _get_biome_name(biome)
		var biome_id = _register_native_biome(biome)

		# Initialize per-biome native output buffer
		var lookahead_buffer = _ensure_lookahead_buffer(biome_name)
		lookahead_buffer.clear()
		_sync_biome_structure_payload(biome, biome_id)
		biome_dirty[biome_name] = false
		biome_pending_reregister[biome_name] = false

		if biome_id >= 0:
			registered_biomes.append(biome)

	# Mark engine as ready BEFORE priming (so new biomes can register immediately).
	# _engine_ready = backend present & registered (drives native time-skip);
	# lookahead_enabled = live N-phrame BUFFERING (gated by the env flag, separately).
	_engine_ready = true
	lookahead_enabled = (lookahead_engine.get_biome_count() > 0) and not _disable_lookahead_env
	lookahead_accumulator = LOOKAHEAD_DT * LOOKAHEAD_STEPS

	# Apply any oval centers that QuantumForceGraph pushed before the engine was ready.
	_flush_cached_biome_centers()

	# Prime all registered biomes at once using batched evolution
	if lookahead_enabled and not registered_biomes.is_empty():
		_prime_all_biomes_native(registered_biomes)

	# Log final status
	var lnn_count = 0
	if use_phase_lnn and lookahead_engine.has_method("is_lnn_enabled"):
		for i in range(lookahead_engine.get_biome_count()):
			if lookahead_engine.is_lnn_enabled(i):
				lnn_count += 1

	if lookahead_enabled:
		_log_debug("  ✓ Lookahead engine ACTIVATED - native batched evolution")
		_log_debug("  MultiBiomeLookaheadEngine: %d biomes registered, %d with LNN" % [
			lookahead_engine.get_biome_count(), lnn_count
		])
	else:
		_log_debug("  MultiBiomeLookaheadEngine: No biomes registered")


func _prime_all_biomes_native(biomes_to_prime: Array) -> void:
	# Prime all biomes at once using batched native evolution.
	#
	# This fills the N-phrame lookahead buffers for all biomes in one batched call,
	# then emits biome_ready for each biome.
	if not lookahead_engine or biomes_to_prime.is_empty():
		return

	_log_debug("  Priming %d biomes with %d-phrame lookahead..." % [biomes_to_prime.size(), LOOKAHEAD_STEPS])

	# Collect density matrices in ENGINE-ID ORDER. The native engine maps biome_rhos[id]
	# → m_engines[id] by index, so the array MUST be ordered by registration id, not by
	# the biomes_to_prime list order — otherwise a biome's ρ lands on another biome's engine
	# (wrong dimension → skipped/garbage). Non-primed / unregistered slots get an empty ρ
	# (the engine skips empties). Mirrors the emergency/hybrid-refill paths.
	var prime_by_name: Dictionary = {}
	for biome in biomes_to_prime:
		prime_by_name[_get_biome_name(biome)] = biome
	var engine_count: int = lookahead_engine.get_biome_count()
	var biome_rhos: Array = []
	for engine_id in range(engine_count):
		var biome_name: String = _engine_id_to_biome.get(engine_id, "")
		var pb = prime_by_name.get(biome_name, null)
		var qc = pb.quantum_computer if pb else null
		if qc and qc.density_matrix:
			biome_rhos.append(qc.density_matrix._to_packed())
		else:
			biome_rhos.append(PackedFloat64Array())  # not in this prime batch → skip

	var actual_dt = _get_packet_dt_for_biomes(biomes_to_prime)

	# Batched evolution: all biomes × LOOKAHEAD_STEPS in one native call
	# Pass actual_dt as BOTH dt and max_dt (no subcycling, max_dt is the timestep)
	var evo_result = lookahead_engine.evolve_all_lookahead(
		biome_rhos, LOOKAHEAD_STEPS, actual_dt, actual_dt
	)

	# Unpack results into per-biome buffers
	var results = evo_result.get("results", [])
	var bloch_steps = evo_result.get("bloch_steps", [])
	var purity_steps = evo_result.get("purity_steps", [])
	var mi_steps = evo_result.get("mi_steps", [])
	var evo_position_steps = evo_result.get("position_steps", [])

	# Distribute results by ENGINE-ID (results[id] came from m_engines[id]). Only the
	# biomes actually in this prime batch get their buffers filled.
	for i in range(engine_count):
		var biome_name: String = _engine_id_to_biome.get(i, "")
		var biome = prime_by_name.get(biome_name, null)
		if biome == null:
			continue
		var lookahead_buffer = _ensure_lookahead_buffer(biome_name)

		# Fill buffers with evolution results
		if i < results.size():
			lookahead_buffer.frames = results[i]
		if i < bloch_steps.size():
			lookahead_buffer.bloch_steps = bloch_steps[i]
		if i < purity_steps.size():
			lookahead_buffer.purity_steps = purity_steps[i]
		if i < mi_steps.size():
			lookahead_buffer.mi_steps = mi_steps[i]
			lookahead_buffer.latest_mi = mi_steps[i][mi_steps[i].size() - 1] if not mi_steps[i].is_empty() else PackedFloat64Array()
		if i < evo_position_steps.size():
			lookahead_buffer.positions = evo_position_steps[i]

		# Reset cursor to start
		lookahead_buffer.cursor = 0

		# Update viz_cache from first phrame
		if biome.viz_cache and not lookahead_buffer.frames.is_empty():
			_apply_buffered_step(biome, false)

		# Emit ready signal - this biome now has its N phrames buffered!
		biome_ready.emit(biome_name)

	lookahead_refills += 1
	_log_debug("  ✓ All biomes primed and ready!")


func _matrix_to_triplets(mat) -> PackedFloat64Array:
	# Convert ComplexMatrix to triplet format for native engine.
	var triplets = PackedFloat64Array()
	var n = mat.n
	var threshold = 1e-15

	for i in range(n):
		for j in range(n):
			var c = mat.get_element(i, j)
			if abs(c.re) > threshold or abs(c.im) > threshold:
				triplets.append(float(i))
				triplets.append(float(j))
				triplets.append(c.re)
				triplets.append(c.im)

	return triplets


func _get_biome_evolution_dt(biome) -> float:
	if biome and "max_evolution_dt" in biome:
		return maxf(0.000001, float(biome.max_evolution_dt))
	return LOOKAHEAD_DT


func _get_packet_dt_for_biomes(packet_biomes: Array) -> float:
	var actual_dt := INF
	for biome in packet_biomes:
		if _is_valid_biome(biome):
			actual_dt = minf(actual_dt, _get_biome_evolution_dt(biome))
	return LOOKAHEAD_DT if actual_dt == INF else actual_dt


func _get_packet_dt_for_active_flags(active_flags_arr: Array) -> float:
	var actual_dt := INF
	for engine_id in range(active_flags_arr.size()):
		if not bool(active_flags_arr[engine_id]):
			continue
		var biome_name = _engine_id_to_biome.get(engine_id, "")
		var biome = _get_biome_by_name(biome_name)
		if _is_valid_biome(biome):
			actual_dt = minf(actual_dt, _get_biome_evolution_dt(biome))
	return LOOKAHEAD_DT if actual_dt == INF else actual_dt


func _build_metadata_payload(biome) -> Dictionary:
	# Build structural metadata payload from the biome's register map.
	if not biome or not biome.quantum_computer or not biome.quantum_computer.register_map:
		return {}
	var qc = biome.quantum_computer  # Cache reference
	var register_map = qc.register_map
	var payload: Dictionary = {}
	payload["num_qubits"] = register_map.num_qubits
	payload["axes"] = register_map.axes.duplicate(true) if "axes" in register_map else {}
	var emoji_to_qubit: Dictionary = {}
	var emoji_to_pole: Dictionary = {}
	var emoji_list: Array = []
	for emoji in register_map.coordinates.keys():
		var coord = register_map.coordinates[emoji]
		emoji_to_qubit[emoji] = coord.get("qubit", -1)
		emoji_to_pole[emoji] = coord.get("pole", -1)
		emoji_list.append(emoji)
	payload["emoji_to_qubit"] = emoji_to_qubit
	payload["emoji_to_pole"] = emoji_to_pole
	payload["emoji_list"] = emoji_list
	return payload


func _get_coupling_payload_from_viz_cache(biome) -> Dictionary:
	# Get coupling payload from biome's viz_cache (already populated from icons).
	#
	# Returns: {
	# "self_energies": {emoji: base_self_energy, ...},
	# "self_energy_drivers": {emoji: {type, frequency, phase, amplitude}, ...},
	# "hamiltonian": {emoji_a: {emoji_b: coupling_strength, ...}, ...},
	# "lindblad": {emoji_a: {emoji_b: rate, ...}, ...}
	# }
	# Combined validation: check all requirements at once
	if not biome or not biome.viz_cache or not biome.quantum_computer or not biome.quantum_computer.register_map:
		return {}

	# viz_cache already has Hamiltonian/Lindblad data from icon metadata
	# Extract it by querying all emojis
	var self_energies: Dictionary = {}
	var self_energy_drivers: Dictionary = biome.viz_cache.get_self_energy_drivers()
	var hamiltonian_couplings: Dictionary = {}
	var lindblad_outgoing: Dictionary = {}
	var sink_fluxes: Dictionary = {}

	var qc = biome.quantum_computer
	var register_map = qc.register_map

	for emoji in register_map.coordinates.keys():
		self_energies[emoji] = biome.viz_cache.get_self_energy(emoji)
		hamiltonian_couplings[emoji] = biome.viz_cache.get_hamiltonian_couplings(emoji)
		var outgoing = biome.viz_cache.get_lindblad_outgoing(emoji)
		lindblad_outgoing[emoji] = outgoing
		var total_rate = 0.0
		if outgoing is Dictionary:
			for target in outgoing.keys():
				total_rate += absf(float(outgoing.get(target, 0.0)))
		if total_rate > 0.0:
			sink_fluxes[emoji] = total_rate

	return {
		"self_energies": self_energies,
		"self_energy_drivers": self_energy_drivers,
		"hamiltonian": hamiltonian_couplings,
		"lindblad": lindblad_outgoing,
		"sink_fluxes": sink_fluxes
	}


func _build_biome_structure_payload(biome) -> Dictionary:
	# Build the immutable structural payload owned by the biome/viz surface.
	return {
		"metadata": _build_metadata_payload(biome),
		"couplings": _get_coupling_payload_from_viz_cache(biome),
	}


func _sync_biome_structure_payload(biome, biome_id: int = -1) -> Dictionary:
	# Project biome-owned structure into the local buffer and native engine.
	if not _is_valid_biome(biome):
		return {}

	var biome_name = _get_biome_name(biome)
	var payload = _build_biome_structure_payload(biome)
	var metadata: Dictionary = payload.get("metadata", {})
	var couplings: Dictionary = payload.get("couplings", {})

	var lookahead_buffer = _ensure_lookahead_buffer(biome_name)
	lookahead_buffer.metadata = metadata
	lookahead_buffer.couplings = couplings

	if biome_id >= 0 and lookahead_engine:
		if lookahead_engine.has_method("set_biome_metadata"):
			lookahead_engine.set_biome_metadata(biome_id, metadata)
		if lookahead_engine.has_method("set_biome_couplings"):
			lookahead_engine.set_biome_couplings(biome_id, couplings)

	return payload


var _first_tick_logged: bool = false

func physics_process(delta: float):
	# Called at PhysicsConfig.PHYSICS_TICKS_HZ by physics loop (from Farm._physics_process()).
	# GUARD: Prevent duplicate calls in same physics frame
	var current_physics_frame = Engine.get_physics_frames()
	if current_physics_frame == _last_physics_frame:
		push_warning("BiomeEvolutionBatcher: physics_process() called TWICE in physics frame %d! Ignoring duplicate." % current_physics_frame)
		return
	_last_physics_frame = current_physics_frame

	if biomes.is_empty():
		return

	# One-time diagnostic: confirm C++ lookahead status
	if not _first_tick_logged:
		_first_tick_logged = true
		if lookahead_enabled:
			_log_debug("[BiomeEvolutionBatcher] C++ LOOKAHEAD ACTIVE: %d-phrame buffer (%.1fs @ %dHz)" % [
				LOOKAHEAD_STEPS, LOOKAHEAD_STEPS * LOOKAHEAD_DT, _PC.PHRAME_HZ
			])
		elif not _engine_ready:
			_log_debug("[BiomeEvolutionBatcher] C++ lookahead awaiting engine initialization")
		else:
			push_warning("[BiomeEvolutionBatcher] C++ lookahead NOT active. Evolution will stall until engine initializes.")

	if lookahead_enabled:
		# Live buffering on: consume the N-phrame buffer + refill via the backend.
		_physics_process_lookahead(delta)
	elif _engine_ready and _deterministic_stepper:
		# Buffering off but the backend is present: evolve directly through the C++ backend,
		# one phrame this tick (no N-phrame buffer). This replaces the old no-op "GDScript
		# fallback" — GDScript quantum compute is deprecated; the machinery always evolves.
		_deterministic_stepper.run_time_skip_cycles(1, delta)
	# else: backend not ready yet — biomes wait for engine init (no GDScript compute).


func _physics_process_lookahead(delta: float):
	# Lookahead mode: consume buffered phrames and run synchronous native packets.
	#
	# Terminology:
	# - tick = visual frame (60 FPS from _process)
	# - phrame = physics/evolution frame (PhysicsConfig.PHRAME_HZ)
	# - packet = C++ batch result containing N phrames
	#
	# Key: Refill check runs at phrame rate (consumption).
	# Track frame timing (for diagnostics only, not control logic)
	var now_ms = Time.get_ticks_msec()
	var tick_now_ms = now_ms
	if _last_frame_time > 0:
		var frame_delta_ms = now_ms - _last_frame_time
		_avg_frame_time_ms = _smooth_metric(_avg_frame_time_ms, float(frame_delta_ms))
	_last_frame_time = now_ms

	# Handle pending re-registrations when safe (no in-flight packets)
	if lookahead_enabled:
		_process_pending_reregisters()

	_poll_runtime_activity(delta)

	if _any_active_biomes():
		for biome in biomes:
			if biome and biome.time_tracker and not biome_paused.get(_get_biome_name(biome), true):
				biome.time_tracker.update(delta)
	elif _packet_queue.is_empty() and _active_packet_request.is_empty():
		evolution_accumulator = min(evolution_accumulator, EVOLUTION_INTERVAL)
		_run_batcher_watchdog(tick_now_ms)
		return

	# === CONSUMPTION AND REFILL CYCLE (phrames) ===
	# Advance buffer cursors at phrame rate (physics/evolution frames)
	evolution_accumulator += delta
	tick_now_ms = Time.get_ticks_msec()

	if evolution_accumulator >= EVOLUTION_INTERVAL:
		if _can_consume_phrame(tick_now_ms):
			evolution_accumulator -= EVOLUTION_INTERVAL  # Subtract, don't reset (preserves fractional delta)
			_last_phrame_wall_ms = tick_now_ms

			_track_physics_fps()

			# CONSUME: Advance all buffer cursors (1 phrame per biome)
			_advance_all_buffers()

			# Update per-biome buffer states (self-balancing Fibonacci)
			for biome in biomes:
				if _is_valid_biome(biome):
					var biome_name = _get_biome_name(biome)
					_update_biome_buffer_state(biome_name)

			# Queue one native packet that evolves only biomes that need refill.
			if lookahead_enabled and _packet_queue.is_empty():
				_trigger_hybrid_refill()
		else:
			# Keep accumulator bounded while throttled to avoid huge catch-up bursts.
			evolution_accumulator = min(evolution_accumulator, EVOLUTION_INTERVAL * 2.0)
			_throttled_phrame_skips += 1

	# === PACKET PROCESSING (per physics frame) ===
	# Process one queued native packet synchronously.
	if lookahead_enabled and not _packet_queue.is_empty():
		_process_next_packet()
	_run_batcher_watchdog(tick_now_ms)


# =============================================================================
# HELPER FUNCTIONS - DRY pattern extraction
# =============================================================================

class BiomeBufferState:
	# Encapsulates buffer state for a single biome.
	var biome_name: String
	var buffer: Array
	var cursor: int
	var depth: int
	var is_empty: bool

	func _init(name: String, buf: Array, cur: int):
		biome_name = name
		buffer = buf
		cursor = cur
		depth = buffer.size() - cursor
		is_empty = depth <= 0


func _ensure_lookahead_buffer(biome_name: String):
	var existing = _lookahead_buffers.get(biome_name, null)
	if existing != null:
		return existing
	var created = BiomeLookaheadBuffer.new()
	_lookahead_buffers[biome_name] = created
	return created


func _get_lookahead_buffer(biome_name: String):
	return _lookahead_buffers.get(biome_name, null)


func _erase_lookahead_buffer(biome_name: String) -> void:
	_lookahead_buffers.erase(biome_name)


func _is_valid_biome(biome) -> bool:
	# Check if biome has quantum computer (standard null check).
	return biome != null and is_instance_valid(biome) and biome.quantum_computer != null


func _get_biome_name(biome) -> String:
	# Get biome name with fallback to biome.name.
	if biome == null:
		return ""
	# If biome is a String, return it directly
	if typeof(biome) == TYPE_STRING:
		return biome
	# If biome is an object, check for get_biome_type() method
	if typeof(biome) == TYPE_OBJECT and biome.has_method("get_biome_type"):
		return biome.get_biome_type()
	# Fallback to .name property
	return biome.name if "name" in biome else str(biome)


func _get_biome_buffer_state(biome) -> BiomeBufferState:
	# Get buffer state for a single biome (centralized buffer access).
	#
	# Eliminates redundant pattern: lookahead buffer frames + cursor lookups.
	var biome_name = _get_biome_name(biome)
	var lookahead_buffer = _get_lookahead_buffer(biome_name)
	var buffer = lookahead_buffer.frames if lookahead_buffer else []
	var cursor = lookahead_buffer.cursor if lookahead_buffer else 0
	return BiomeBufferState.new(biome_name, buffer, cursor)


func _get_minimum_buffer_depth() -> int:
	# Get minimum buffer depth across all active biomes.
	#
	# Returns the smallest depth to ensure no biome starves.
	# Fixes Issue #2: Previously only checked first biome.
	if biomes.is_empty():
		return 0
	if _active_biome_names.is_empty():
		return LOOKAHEAD_STEPS

	var min_depth = 999999  # Start with large number
	for biome in biomes:
		if not _is_valid_biome(biome):
			continue
		var biome_name = _get_biome_name(biome)
		if not _active_biome_names.has(biome_name):
			continue

		var state = _get_biome_buffer_state(biome)
		if state.depth < min_depth:
			min_depth = state.depth

	return min_depth if min_depth < 999999 else LOOKAHEAD_STEPS


func _create_frozen_buffer(rho_packed: PackedFloat64Array, steps: int) -> Array:
	# Create buffer filled with frozen state (repeated current density matrix).
	#
	# Eliminates redundant loop in 3 locations.
	var frozen_steps: Array = []
	frozen_steps.resize(steps)
	for i in range(steps):
		frozen_steps[i] = rho_packed
	return frozen_steps


func _smooth_metric(current: float, new_value: float, alpha: float = BATCH_TIME_SMOOTHING) -> float:
	# Exponential moving average smoothing.
	#
	# Eliminates redundant lerpf(x, y, BATCH_TIME_SMOOTHING) pattern in 2 locations.
	return lerpf(current, new_value, alpha)


# === PER-BIOME HELPERS (Option A) ===

func _get_biome_depth(biome_name: String) -> int:
	# Get buffer depth for a SINGLE biome (not minimum across all).
	#
	# Used by per-biome refill logic to check each biome independently.
	var lookahead_buffer = _get_lookahead_buffer(biome_name)
	var buffer = lookahead_buffer.frames if lookahead_buffer else []
	var cursor = lookahead_buffer.cursor if lookahead_buffer else 0
	return buffer.size() - cursor


func _get_biome_buffer_time_ms(biome_name: String) -> float:
	var depth = _get_biome_depth(biome_name)
	return depth * EVOLUTION_INTERVAL * 1000.0


func _get_biome_rho_status(biome_name: String, biome) -> Dictionary:
	var status = {
		"valid": false,
		"rho": PackedFloat64Array(),
		"dim": 0,
		"engine_dim": _biome_engine_dims.get(biome_name, -1),
		"reason": "unknown"
	}
	if biome == null or not is_instance_valid(biome):
		status.reason = "biome_invalid"
		return status
	if not biome.quantum_computer:
		status.reason = "no_qc"
		return status

	var qc = biome.quantum_computer
	if qc.register_map == null:
		status.reason = "no_register_map"
		return status

	var dim = qc.register_map.dim()
	status.dim = dim
	if dim <= 0:
		status.reason = "dim_zero"
		return status
	if qc.density_matrix == null:
		status.reason = "no_rho"
		return status

	var rho_packed = qc.density_matrix._to_packed()
	status.rho = rho_packed
	if rho_packed.is_empty():
		status.reason = "empty_rho"
		return status

	# Guard: zero-trace or NaN density matrices (can occur after probe_cycle measurement)
	# will SIGABRT in the C++ engine. Detect and rebuild as mixed state.
	# NOTE: Cannot use _reinitialize_mixed_state() + _to_packed() here because
	# set_element() clears _packed_cache but not _native_backend, causing _to_packed()
	# to return stale zero-trace native data. Instead, build the packed array directly
	# and call _from_packed() to sync both _packed_cache and native backend.
	if dim > 0 and rho_packed.size() >= dim * dim * 2:
		var trace = 0.0
		for i in range(dim):
			trace += rho_packed[i * (dim + 1) * 2]
		if is_nan(trace) or trace < 1e-10:
			var now_ms := Time.get_ticks_msec()
			if now_ms - _degenerate_warned_at.get(biome_name, 0) > 5000:
				_degenerate_warned_at[biome_name] = now_ms
				push_warning("BiomeEvolutionBatcher: degenerate rho for '%s' (tr=%.6f), reinitializing to mixed state" % [biome_name, trace])
			var fresh_packed = PackedFloat64Array()
			fresh_packed.resize(dim * dim * 2)
			var diag_val = 1.0 / float(dim)
			for i in range(dim):
				fresh_packed[i * (dim + 1) * 2] = diag_val
			qc.density_matrix._from_packed(fresh_packed, dim)
			rho_packed = fresh_packed
			status.rho = rho_packed

	var engine_dim = status.engine_dim
	if engine_dim >= 0 and engine_dim != dim:
		status.reason = "engine_dim_mismatch"
		biome_pending_reregister[biome_name] = true
		return status

	status.valid = true
	status.reason = "ok"
	biome_last_good_rho[biome_name] = rho_packed
	return status


func _process_pending_reregisters() -> void:
	if lookahead_engine == null:
		return
	if not _active_packet_request.is_empty() or not _packet_queue.is_empty():
		return

	# Catch SILENT drift: if a biome's live operators were rebuilt (new physics_signature)
	# without anyone flagging it, the engine's copy is stale. Comparing signatures flags it
	# here, so the C++ copy can't diverge from the builders unnoticed.
	_flag_drifted_engine_signatures()

	if biome_pending_reregister.is_empty():
		return

	var pending_names = biome_pending_reregister.keys()
	for biome_name in pending_names:
		if biome_pending_reregister.get(biome_name, false):
			_reregister_biome_by_name(biome_name)


## Flag any registered biome whose LIVE physics signature no longer matches the one its
## C++ engine copy was registered from. This is the traceability check that makes the
## "silent twin" impossible: the engine's H/L copy is provably either in sync or flagged
## to re-sync — drift never goes unnoticed just because a mutator forgot to mark dirty.
func _flag_drifted_engine_signatures() -> void:
	for biome_name in _biome_engine_ids.keys():
		if int(_biome_engine_ids.get(biome_name, -1)) < 0:
			continue
		if biome_pending_reregister.get(biome_name, false):
			continue  # already queued
		var biome = _get_biome_by_name(biome_name)
		if not _is_valid_biome(biome) or not biome.quantum_computer:
			continue
		var live_sig: String = str(biome.quantum_computer.physics_signature)
		var reg_sig: String = str(_biome_registered_signature.get(biome_name, ""))
		if live_sig == "" or reg_sig == "":
			continue  # not enough info to assert drift
		if live_sig != reg_sig:
			_log("warn", "REREGISTER", "🧭", "%s: engine physics drift (live signature != registered) — flushing the stale C++ copy" % biome_name)
			biome_pending_reregister[biome_name] = true


func _reregister_biome_by_name(biome_name: String) -> void:
	var biome = _get_biome_by_name(biome_name)
	if not _is_valid_biome(biome):
		biome_pending_reregister.erase(biome_name)
		return

	var old_id = _biome_engine_ids.get(biome_name, -1)
	var qc = biome.quantum_computer

	# IN-PLACE replace (stable id) — the canonical path for runtime H/L changes. Appending a
	# fresh engine would orphan the old slot and break the rho-slot ↔ engine-id mapping, so
	# the rho would keep being evolved by the STALE engine (the bug that made a runtime
	# dissipation-ON switch not actually apply L). Replacing at the same id keeps everything
	# consistent: run_native_biome_cycle reads _biome_engine_ids[name] → the updated engine.
	if old_id >= 0 and lookahead_engine and lookahead_engine.has_method("reregister_biome") and qc and qc.register_map:
		_log("info", "REREGISTER", "🔁", "%s: re-registering in place (id=%d, H/L mutation flushed)" % [biome_name, old_id])
		var dim = qc.register_map.dim()
		var num_qubits = qc.register_map.num_qubits
		var H_packed = qc.hamiltonian._to_packed() if qc.hamiltonian else PackedFloat64Array()
		var lindblad_triplets: Array = []
		for L in qc.lindblad_operators:
			if L:
				lindblad_triplets.append(_matrix_to_triplets(L))
		if lookahead_engine.reregister_biome(old_id, dim, H_packed, lindblad_triplets, num_qubits):
			_biome_engine_dims[biome_name] = dim
			_biome_registered_signature[biome_name] = str(qc.physics_signature)
			_sync_biome_structure_payload(biome, old_id)
			if lookahead_engine.has_method("set_biome_coherent"):
				lookahead_engine.set_biome_coherent(old_id, BalanceConfig.coherent_enabled())
			invalidate_biome_buffer(biome_name)
			biome_dirty[biome_name] = false
			biome_pending_reregister.erase(biome_name)
			return
		_log("warn", "REREGISTER", "⚠️", "%s: in-place re-register failed — falling back to append path." % biome_name)

	# Fallback (no prior id, or backend lacks reregister): orphan old slot + append fresh.
	_log("info", "REREGISTER", "🔁", "%s: re-registering (append path)" % biome_name)
	if old_id >= 0:
		_engine_id_to_biome[old_id] = ""
	_biome_engine_ids[biome_name] = -1
	_biome_engine_dims.erase(biome_name)
	_register_and_prime_biome(biome)

	biome_dirty[biome_name] = false
	biome_pending_reregister.erase(biome_name)


func _get_biome_by_name(biome_name: String):
	# Find biome object by name. Returns null if not found.
	for biome in biomes:
		if _get_biome_name(biome) == biome_name:
			return biome
	return null


func _update_biome_pause_states():
	# Refresh the cached activity ledger on demand.
	_refresh_runtime_activity()


func _poll_runtime_activity(delta: float) -> void:
	# Event-driven activity ledger with a slow integrity poll for infra changes.
	if _activity_refresh_needed:
		_refresh_runtime_activity()
		return
	_activity_poll_accumulator += delta
	if _activity_poll_accumulator >= ACTIVITY_POLL_INTERVAL:
		_refresh_runtime_activity(true)


func _should_trigger_biome_refill(biome_name: String, _depth: int, rho_valid: bool = true) -> bool:
	# Check if a SINGLE biome needs refill (time-based thresholds).
	#
	# Decouples refill thresholds from batch size to avoid starvation lock-in.
	# Check if biome is paused (no bubbles)
	if biome_paused.get(biome_name, false):
		return false  # Don't refill paused biomes

	# Don't evolve if rho is invalid
	if not rho_valid:
		return false

	# Invalidation should force a refill even if buffer is still full
	if biome_dirty.get(biome_name, false):
		return true

	var buffer_time_ms = _get_biome_buffer_time_ms(biome_name)
	var min_buffer_ms = MIN_BUFFER_STEPS * EVOLUTION_INTERVAL * 1000.0
	return buffer_time_ms < min_buffer_ms


func _update_biome_buffer_state(biome_name: String) -> void:
	# Update RECOVERY/COAST state for a SINGLE biome based on its buffer depth.
	#
	# Each biome independently tracks its own state and Fibonacci index.
	# Uses time-based thresholds (decoupled from batch size):
	# - STARVATION: buffer_time < MIN_BUFFER_MS → fib up (escalate)
	# - COAST: buffer_time > MAX_BUFFER_MS → fib down (de-escalate)
	# - STABLE: MIN ≤ buffer_time ≤ MAX → maintain
	if biome_paused.get(biome_name, true):
		return

	var biome = _get_biome_by_name(biome_name)
	var status = _get_biome_rho_status(biome_name, biome)
	if not status.valid:
		return

	var buffer_time_ms = _get_biome_buffer_time_ms(biome_name)
	var prev_state = biome_buffer_states.get(biome_name, BufferState.RECOVERY)
	var fib_index = biome_fib_indices.get(biome_name, INITIAL_BIOME_FIB_INDEX)
	var min_buffer_ms = MIN_BUFFER_STEPS * EVOLUTION_INTERVAL * 1000.0
	var max_buffer_ms = MAX_BUFFER_STEPS * EVOLUTION_INTERVAL * 1000.0

	# STARVATION: buffer_time too low or buffer invalidated → escalate
	if biome_dirty.get(biome_name, false) or buffer_time_ms < min_buffer_ms:
		biome_buffer_states[biome_name] = BufferState.RECOVERY
		if buffer_time_ms <= 0.0:
			biome_emergency_refill[biome_name] = true

		# Escalate fib_index with 500ms cooldown
		# Allows multiple escalations during startup, but prevents tick-by-tick spam
		var now_ms = Time.get_ticks_msec()
		var last_escalation = biome_last_escalation_time.get(biome_name, 0.0)
		var time_since_last = now_ms - last_escalation

		# Escalate if: transitioning from COAST, OR 500ms cooldown elapsed while in RECOVERY
		if prev_state == BufferState.COAST or time_since_last > 500:
			var new_fib = mini(fib_index + 1, FIB_SEQUENCE.size() - 1)
			if new_fib != fib_index:
				biome_fib_indices[biome_name] = new_fib
				biome_last_escalation_time[biome_name] = now_ms
				_log("info", "STATE", "📈", "%s: STARVATION (buffer=%.0fms < %.0fms), fib %d→%d" % [
					biome_name, buffer_time_ms, min_buffer_ms, fib_index, new_fib
				])

	# COAST: buffer healthy — mark state but do NOT de-escalate.
	# De-escalation caused fib oscillation: emergency frames pushed buffer past
	# MAX_BUFFER_STEPS → coast → fib-1 → smaller batch → starvation → fib+1 → repeat.
	# C++ batches are cheap — let fib grow to max and stay there.
	elif buffer_time_ms > max_buffer_ms:
		biome_buffer_states[biome_name] = BufferState.COAST
		biome_emergency_refill[biome_name] = false

	# STABLE ZONE: MIN ≤ buffer_time ≤ MAX
	# Keep current state and fib_index (no change)


# === HYBRID GLOBAL PACKET WITH PER-BIOME BUFFER TRACKING ===

func _check_starving_by_time() -> Array:
	# TIER 1: Detect biomes that will starve before next packet completes (time-based).
	#
	# Starvation = buffer_time < batch_compute_time × safety_margin
	#
	# Where:
	# - buffer_time = depth × EVOLUTION_INTERVAL (ms of game time buffered)
	# - batch_compute_time = max(last_batch_time_ms, _avg_batch_time_ms)
	# - safety_margin = 1.5 (need 1.5x buffer to be safe)
	#
	# Example:
	# - depth = 2 frames → buffer_time = 200ms
	# - last_batch = 150ms → need 150ms × 1.5 = 225ms
	# - 200ms < 225ms → STARVING!
	#
	# This is adaptive to actual C++ performance - if C++ slows down,
	# we detect starvation earlier.
	var starving: Array = []

	# Use max of last and average for conservative estimate
	var batch_time = max(last_batch_time_ms, _avg_batch_time_ms)
	if batch_time < 1.0:
		return starving  # No timing data yet

	var threshold_time = batch_time * EMERGENCY_SAFETY_MARGIN
	var now_ms = Time.get_ticks_msec()

	for biome in biomes:
		if not _is_valid_biome(biome):
			continue

		var biome_name = _get_biome_name(biome)
		# Paused biomes don't consume buffers, so they can't starve.
		if biome_paused.get(biome_name, false):
			continue

		var status = _get_biome_rho_status(biome_name, biome)
		if not status.valid:
			continue
		var depth = _get_biome_depth(biome_name)
		var buffer_time_ms = depth * EVOLUTION_INTERVAL * 1000.0  # Convert to ms

		# Emergency rescue is for CRITICAL depletion only.
		# Non-critical low buffers are handled by regular hybrid refill.
		var is_starving = depth <= EMERGENCY_CRITICAL_DEPTH and buffer_time_ms < threshold_time
		if is_starving:
			starving.append(biome_name)

			var was_starving = bool(_rescue_starving_state.get(biome_name, false))
			var last_log_ms = int(_rescue_last_log_ms.get(biome_name, 0))
			var should_log = (not was_starving) or (now_ms - last_log_ms >= EMERGENCY_LOG_INTERVAL_MS)
			if should_log:
				var suppressed = int(_rescue_suppressed_logs.get(biome_name, 0))
				var suffix = ""
				if suppressed > 0:
					suffix = " (suppressed=%d)" % suppressed
				# Use INFO for recurring rescue state to avoid expensive push_warning backtraces.
				_log("info", "RESCUE", "🚨",
					"%s: CRITICAL depth=%d, buffer=%dms < %dms (%.1fx batch)%s" %
					[biome_name, depth, buffer_time_ms, threshold_time, EMERGENCY_SAFETY_MARGIN, suffix])
				_rescue_last_log_ms[biome_name] = now_ms
				_rescue_suppressed_logs[biome_name] = 0
			else:
				_rescue_suppressed_logs[biome_name] = int(_rescue_suppressed_logs.get(biome_name, 0)) + 1
			_rescue_starving_state[biome_name] = true
		elif bool(_rescue_starving_state.get(biome_name, false)):
			var suppressed_recovery = int(_rescue_suppressed_logs.get(biome_name, 0))
			var recovery_suffix = ""
			if suppressed_recovery > 0:
				recovery_suffix = " (suppressed=%d)" % suppressed_recovery
			_log("info", "RESCUE", "✅",
				"%s: RECOVERED depth=%d, buffer=%dms >= %dms%s" %
				[biome_name, depth, buffer_time_ms, threshold_time, recovery_suffix])
			_rescue_starving_state[biome_name] = false
			_rescue_suppressed_logs[biome_name] = 0

	return starving


func _queue_emergency_packet(starving_biomes: Array) -> void:
	# Queue small PRIORITY packet for starving biomes only (Tier 1 rescue).
	#
	# This packet:
	# - Is small (5 frames = 500ms buffer)
	# - Processes only starving biomes (via active_flags)
	# - Queued with push_front() for priority
	# - Takes ~30-50ms C++ time (fast!)
	#
	# This is tactical rescue - Fibonacci escalation (Tier 2) handles
	# strategic capacity adjustment.
	if not lookahead_engine:
		return
	var now_ms = Time.get_ticks_msec()
	if now_ms - _last_emergency_packet_time_ms < EMERGENCY_COOLDOWN_MS:
		_log("trace", "RESCUE", "⏳", "Emergency cooldown active (%dms)" % [
			EMERGENCY_COOLDOWN_MS - (now_ms - _last_emergency_packet_time_ms)
		])
		return

	var biome_rhos: Array = []
	var active_flags_arr: Array = []
	var rescued_count = 0

	# Build packet with only starving biomes active
	for engine_id in range(lookahead_engine.get_biome_count()):
		var biome_name = _engine_id_to_biome.get(engine_id, "")

		if biome_name == "" or biome_name not in starving_biomes:
			# Skip non-starving biomes (empty = skip calculation)
			biome_rhos.append(PackedFloat64Array())
			active_flags_arr.append(false)
			continue

		# Include starving biome (only if rho valid)
		var biome = _get_biome_by_name(biome_name)
		if biome and _is_valid_biome(biome):
			var status = _get_biome_rho_status(biome_name, biome)
			biome_rhos.append(status.rho)
			active_flags_arr.append(status.valid)
			if status.valid:
				rescued_count += 1
		else:
			biome_rhos.append(PackedFloat64Array())
			active_flags_arr.append(false)

	if rescued_count == 0:
		return  # No valid starving biomes

	# Create emergency packet
	var packet = {
		"biome_rhos": biome_rhos,
		"active_flags": active_flags_arr,
		"num_steps": EMERGENCY_RESCUE_STEPS,  # Small: 5 frames (consistent field name)
		"is_emergency": true,
	}

	# PRIORITY: Push to front of queue
	_packet_queue.push_front(packet)
	_last_emergency_packet_time_ms = now_ms

	_log("info", "RESCUE", "🚑",
		"Emergency packet queued: %d biomes, %d frames (~%.0fms)" %
		[rescued_count, EMERGENCY_RESCUE_STEPS, last_batch_time_ms * 0.3])


func _trigger_hybrid_refill():
	# Hybrid approach: ONE global packet with per-biome active_flags.
	#
	# Each biome tracks its own buffer depth independently.
	# When ANY biome needs refill, queue ONE packet that evolves only
	# the biomes that need it (via active_flags).
	#
	# Benefits:
	# - Single C++ call (no worker coordination)
	# - Per-biome buffer invalidation (independent depths)
	# - Efficient (frozen biomes don't evolve)
	#
	# EMERGENCY RESCUE (Tier 1 - Tactical):
	# Before queuing normal packet, check if any biomes are starving based on
	# time (buffer_time < batch_time). If so, prepend small emergency packet.
	# Update pause states (check for peeked terminals)
	_update_biome_pause_states()
	if _active_biome_names.is_empty():
		return

	# TIER 1: Check for time-based starvation (emergency rescue)
	var starving_biomes = _check_starving_by_time()
	if not starving_biomes.is_empty():
		_queue_emergency_packet(starving_biomes)

	# TIER 2: Check which biomes need regular refill
	var needs_refill = false
	var min_depth = 999999

	for biome in biomes:
		if not _is_valid_biome(biome):
			continue
		var biome_name = _get_biome_name(biome)
		var depth = _get_biome_depth(biome_name)
		var status = _get_biome_rho_status(biome_name, biome)

		# Track minimum depth across all active biomes
		if depth < min_depth:
			min_depth = depth

		# Check if this biome needs refill
		if _should_trigger_biome_refill(biome_name, depth, status.valid):
			needs_refill = true

	# Only queue packet if at least one biome needs refill
	if needs_refill:
		_queue_hybrid_packet()


func _queue_hybrid_packet():
	# Queue ONE global packet with per-biome active_flags and batch sizes.
	#
	# Each biome independently determines:
	# - Whether it needs refill (active_flag)
	# - Its own Fibonacci batch size (self-balancing)
	#
	# C++ evolves all active biomes for MAX(batch_sizes).
	# Merge saves only needed steps per biome.
	#
	# IMPORTANT: Arrays are built in ENGINE_ID ORDER (not biomes array order)
	# to ensure correct mapping during merge. Uses _engine_id_to_biome for
	# consistent ordering across packet queue/complete cycle.
	# Get engine biome count for proper array sizing
	var engine_biome_count = lookahead_engine.get_biome_count() if lookahead_engine else 0
	if engine_biome_count == 0:
		return

	# Build lookup of active biomes for fast access
	var active_biome_lookup: Dictionary = {}
	for biome in biomes:
		if _is_valid_biome(biome):
			var biome_name = _get_biome_name(biome)
			active_biome_lookup[biome_name] = biome

	# Build active_flags and collect rhos in ENGINE_ID ORDER (critical!)
	var biome_rhos: Array = []
	var active_flags_arr: Array = []
	var max_batch_size = 0

	for engine_id in range(engine_biome_count):
		var biome_name = _engine_id_to_biome.get(engine_id, "")

		# Biome not in batcher or invalid engine mapping - skip calculation
		if biome_name == "" or not active_biome_lookup.has(biome_name):
			biome_rhos.append(PackedFloat64Array())
			active_flags_arr.append(false)
			continue

		var biome = active_biome_lookup[biome_name]
		if not _is_valid_biome(biome):
			biome_rhos.append(PackedFloat64Array())
			active_flags_arr.append(false)
			continue

		var depth = _get_biome_depth(biome_name)
		var status = _get_biome_rho_status(biome_name, biome)

		# Determine if this biome should evolve.
		var should_evolve = status.valid and _should_trigger_biome_refill(biome_name, depth, status.valid)

		# C++ evolves ALL non-empty rhos regardless of active_flags; active_flags
		# only gates the GDScript merge.
		if should_evolve:
			biome_rhos.append(status.rho)
		else:
			biome_rhos.append(PackedFloat64Array())
		active_flags_arr.append(should_evolve)

		# Track max batch size.
		if should_evolve:
			var biome_fib_index = biome_fib_indices.get(biome_name, INITIAL_BIOME_FIB_INDEX)
			var biome_batch = FIB_SEQUENCE[mini(biome_fib_index, FIB_SEQUENCE.size() - 1)]
			if biome_batch > max_batch_size:
				max_batch_size = biome_batch

	# Use max batch size (some biomes may "overcook" but this avoids C++ API changes)
	if max_batch_size == 0:
		max_batch_size = FIB_SEQUENCE[INITIAL_BIOME_FIB_INDEX]

	# Validate: don't queue packet if ALL biomes are inactive (no work to do)
	var active_count = active_flags_arr.count(true)
	if active_count == 0:
		_log("trace", "REFILL", "⏭️", "Skipping packet - all biomes inactive")
		return

	# Queue ONE global packet with active_flags.
	max_batch_size = mini(max_batch_size, _max_packet_steps)
	_queue_adaptive_packet(biome_rhos, active_flags_arr, max_batch_size)

	# Log which biomes are being evolved (with their individual batch sizes)
	_log("trace", "REFILL", "🔄", "Global packet: batch=%d (max), %d/%d biomes active (engine_count=%d)" % [
		max_batch_size, active_count, biomes.size(), engine_biome_count
	])


## Force the C++ lookahead engine to re-register this biome on the next refill,
## picking up the current GDScript H + L. Call after any in-place mutation of
## `qc.hamiltonian` or `qc.lindblad_operators` that does NOT change dim — those
## mutations are otherwise invisible to the C++ twin (which only auto-detects
## dim mismatches at BiomeEvolutionBatcher.gd:629).
func mark_for_reregister(biome_name: String) -> void:
	if biome_name == "":
		return
	biome_pending_reregister[biome_name] = true
	if not lookahead_enabled:
		# Pending flag will sit until lookahead activates. Surface this so the
		# caller knows their H/L mutation may not propagate to the C++ engine
		# until the next refill (which won't happen in bench/headless modes).
		_log("warn", "REREGISTER", "⚠️", "%s: marked for re-register but lookahead disabled — will sit pending" % biome_name)
	invalidate_biome_buffer(biome_name)


func invalidate_biome_buffer(biome_name: String):
	# Invalidate buffer for a SINGLE biome (player action).
	#
	# Clears:
	# - Pending packets in queue (purge)
	# - Current buffer contents
	# - Force positions
	#
	# Does NOT affect other biomes (per-biome independence).
	# Hybrid system: ONE global packet, per-biome buffers
	# Just clear this biome's buffers - next packet will refill it

	# Clear buffers for this biome only (other biomes unaffected!)
	var lookahead_buffer = _ensure_lookahead_buffer(biome_name)
	lookahead_buffer.frames = []
	lookahead_buffer.mi_steps = []
	lookahead_buffer.bloch_steps = []
	lookahead_buffer.purity_steps = []
	lookahead_buffer.positions = []
	lookahead_buffer.cursor = 0
	lookahead_buffer.latest_mi = PackedFloat64Array()
	biome_dirty[biome_name] = true

	# Re-prime this biome from current state (frozen 13 phrames)
	var biome = _get_biome_by_name(biome_name)
	if biome:
		_prime_single_biome_frozen(biome)

	_log("info", "INVALIDATE", "🔄", "%s: buffer cleared, re-primed with %d frozen phrames" % [
		biome_name, LOOKAHEAD_STEPS
	])
	_log("info", "INVALIDATE", "📦", "Next packet will refill %s (active_flag=true)" % biome_name)


func decimate_biome_buffer(biome_name: String, decimation_factor: int) -> int:
	# Decimate buffer when coarsening granularity (keep every Nth frame).
	#
	# When dt doubles (2x coarser), existing frames are still valid but oversampled.
	# Instead of full invalidation, keep every 2nd frame to preserve computed work.
	#
	# Args:
	# biome_name: Biome to decimate
	# decimation_factor: Keep every Nth frame (2 for 2x coarsening)
	#
	# Returns:
	# New buffer depth after decimation
	var lookahead_buffer = _get_lookahead_buffer(biome_name)
	if lookahead_buffer == null:
		return 0
	if decimation_factor < 2:
		return lookahead_buffer.frames.size()

	# Decimate all 6 buffers in lockstep (from cursor position, not start)
	var cursor = lookahead_buffer.cursor
	var frames = lookahead_buffer.frames
	var mi = lookahead_buffer.mi_steps
	var bloch = lookahead_buffer.bloch_steps
	var purity = lookahead_buffer.purity_steps
	var positions = lookahead_buffer.positions

	# Slice from cursor (unconsumed) then decimate
	var unconsumed_frames = frames.slice(cursor) if cursor < frames.size() else []
	var unconsumed_mi = mi.slice(cursor) if cursor < mi.size() else []
	var unconsumed_bloch = bloch.slice(cursor) if cursor < bloch.size() else []
	var unconsumed_purity = purity.slice(cursor) if cursor < purity.size() else []
	var unconsumed_positions = positions.slice(cursor) if cursor < positions.size() else []

	# Decimate: keep every Nth frame
	lookahead_buffer.frames = _decimate_array(unconsumed_frames, decimation_factor)
	lookahead_buffer.mi_steps = _decimate_array(unconsumed_mi, decimation_factor)
	lookahead_buffer.bloch_steps = _decimate_array(unconsumed_bloch, decimation_factor)
	lookahead_buffer.purity_steps = _decimate_array(unconsumed_purity, decimation_factor)
	lookahead_buffer.positions = _decimate_array(unconsumed_positions, decimation_factor)
	lookahead_buffer.cursor = 0  # Reset cursor (we sliced unconsumed)

	var new_depth = lookahead_buffer.frames.size()
	_log("info", "DECIMATE", "✂️", "%s: kept every %d frames → depth=%d" % [
		biome_name, decimation_factor, new_depth
	])
	return new_depth


func _decimate_array(arr: Array, factor: int) -> Array:
	# Keep every factor-th element: [0, factor, 2*factor, ...]
	if arr.is_empty() or factor < 2:
		return arr
	var decimated: Array = []
	for i in range(0, arr.size(), factor):
		decimated.append(arr[i])
	return decimated


func _prime_single_biome_frozen(biome):
	# Prime a single biome with frozen buffers (for invalidation recovery).
	if not _is_valid_biome(biome):
		return

	var qc = biome.quantum_computer
	var biome_name = _get_biome_name(biome)
	# Skip calculation if no valid state (empty = skip)
	var rho_packed = qc.density_matrix._to_packed() if qc.density_matrix else PackedFloat64Array()
	if rho_packed.is_empty():
		var last_good = biome_last_good_rho.get(biome_name, PackedFloat64Array())
		if last_good.is_empty():
			_log("warn", "INVALIDATE", "⚠️", "%s: cannot prime frozen buffer (empty rho)" % biome_name)
			return
		rho_packed = last_good

	# Fill with frozen current state
	var lookahead_buffer = _ensure_lookahead_buffer(biome_name)
	lookahead_buffer.frames = _create_frozen_buffer(rho_packed, LOOKAHEAD_STEPS)
	lookahead_buffer.cursor = 0

	# Export current Bloch and purity
	var bloch_packet = qc.export_bloch_packet() if qc.has_method("export_bloch_packet") else biome_last_good_bloch.get(biome_name, PackedFloat64Array())
	var purity = qc.get_purity() if qc.has_method("get_purity") else biome_last_good_purity.get(biome_name, 1.0)
	if bloch_packet.size() > 0:
		biome_last_good_bloch[biome_name] = bloch_packet
	biome_last_good_purity[biome_name] = purity

	lookahead_buffer.bloch_steps = _create_frozen_buffer(bloch_packet, LOOKAHEAD_STEPS)

	var frozen_purity: Array = []
	frozen_purity.resize(LOOKAHEAD_STEPS)
	for i in range(LOOKAHEAD_STEPS):
		frozen_purity[i] = purity
	lookahead_buffer.purity_steps = frozen_purity

	lookahead_buffer.mi_steps = []
	lookahead_buffer.latest_mi = PackedFloat64Array()
	lookahead_buffer.positions = []


func _advance_all_buffers():
	# Advance buffer cursors and update quantum computers with current state.
	#
	# Skips paused biomes (no peeked terminals) to save computation.
	var advanced: int = 0
	for biome in biomes:
		if not _is_valid_biome(biome):
			continue

		var biome_name = _get_biome_name(biome)

		# Skip paused biomes (no bubbles to render)
		if biome_paused.get(biome_name, false):
			continue

		# Observation stride: 0=locked, 1=normal, 2+=fast forward
		var stride: int = biome.observation_stride if "observation_stride" in biome else 1
		if stride <= 0:
			continue  # Locked — no advancement

		if stride > 1:
			# Fast-forward: advance cursor by (stride-1) without applying, then apply final
			var lookahead_buffer = _get_lookahead_buffer(biome_name)
			var buf = lookahead_buffer.bloch_steps if lookahead_buffer else []
			var cursor = lookahead_buffer.cursor if lookahead_buffer else 0
			var skip_count = mini(stride - 1, buf.size() - cursor - 1)
			if skip_count > 0:
				# Berry walk stays faithful through fast-forward: integrate the
				# skipped slices too (see BerryPhaseRegister.integrate_step —
				# immediate no-op when nothing is tracked in this biome).
				var qc = biome.quantum_computer if "quantum_computer" in biome else null
				if qc != null and qc.berry_register != null:
					var nq: int = int(lookahead_buffer.metadata.get("num_qubits", 0))
					if nq > 0:
						for s in range(skip_count):
							qc.berry_register.integrate_step(buf[cursor + s], nq)
				lookahead_buffer.cursor = cursor + skip_count

		var had_data := _get_biome_depth(biome_name) > 0
		_apply_buffered_step(biome)
		if had_data:
			advanced += 1

	_slices_consumed_count += advanced
	active_biome_count = advanced  # last-phrame snapshot; stable between phrames
	total_evolutions += advanced


func _apply_buffered_step(biome, apply_post: bool = true) -> void:
	# Apply current buffered state to a single biome and update viz_cache.
	if not _is_valid_biome(biome):
		return

	var state = _get_biome_buffer_state(biome)
	var biome_name = state.biome_name
	var lookahead_buffer = _get_lookahead_buffer(biome_name)
	var buffer = state.buffer
	var cursor = state.cursor

	if lookahead_buffer == null or cursor >= buffer.size():
		if lookahead_buffer != null and not biome_paused.get(biome_name, false):
			_log_debug("[BUFFER_UNDERRUN] %s cursor=%d buf=%d" % [biome_name, cursor, buffer.size()])
		return

	# Update density matrix from buffer
	var rho_packed = buffer[cursor]
	var qc = biome.quantum_computer  # Cache reference (accessed multiple times below)
	var dim = qc.register_map.dim()
	qc.load_packed_state(rho_packed, dim, true)

	var metadata_payload = lookahead_buffer.metadata
	var num_qubits = metadata_payload.get("num_qubits", 0)

	if num_qubits > 0:
		# Update MI cache for force graph (per-step)
		var mi_steps = lookahead_buffer.mi_steps
		if cursor < mi_steps.size():
			var mi_step = mi_steps[cursor]
			biome.viz_cache.update_mi_values(mi_step, num_qubits)
			if not mi_step.is_empty():
				qc._cached_mi_values = mi_step
		elif not lookahead_buffer.latest_mi.is_empty():
			var mi_cached = lookahead_buffer.latest_mi
			if mi_cached is PackedFloat64Array and not mi_cached.is_empty():
				biome.viz_cache.update_mi_values(mi_cached, num_qubits)

		# Update visualization cache from precomputed lookahead packets
		var bloch_steps = lookahead_buffer.bloch_steps
		if cursor < bloch_steps.size():
			var bloch_packet = bloch_steps[cursor]
			# Berry walk: path-integrate geometric phase on the sim-side register.
			# This is the live integration seam (with the stride-skip loop in
			# _advance_all_buffers) — no-op unless qubits are tracked here.
			if qc.berry_register != null:
				qc.berry_register.integrate_step(bloch_packet, num_qubits)
			if bloch_packet.size() > 0 and Engine.get_process_frames() % 120 == 0:
				_log("debug", "test", "🧬", "Updating bloch for %s: packet size=%d, num_qubits=%d" % [
					biome_name, bloch_packet.size(), num_qubits
				])
			biome.viz_cache.update_from_bloch_packet(bloch_packet, num_qubits)
		elif Engine.get_process_frames() % 120 == 0:
			_log("debug", "test", "⚠️", "No bloch data for %s (cursor=%d, buffer size=%d)" % [
				biome_name, cursor, bloch_steps.size()
			])
		var purity_steps = lookahead_buffer.purity_steps
		if cursor < purity_steps.size():
			# C++ compute_purity now returns Tr(ρ²)/Tr(ρ)² (already normalized).
			# GDScript qc.get_purity() also normalizes. No correction needed.
			biome.viz_cache.update_purity(purity_steps[cursor])
		if metadata_payload:
			biome.viz_cache.update_metadata_from_payload(metadata_payload)
		var coupling_payload = lookahead_buffer.couplings
		if coupling_payload:
			biome.viz_cache.update_couplings_from_payload(coupling_payload)
		var icon_map_payload = _decorate_icon_map_payload_with_flow(
			biome_name,
			biome,
			lookahead_buffer.icon_map
		)
		lookahead_buffer.icon_map = icon_map_payload
		if icon_map_payload:
			biome.viz_cache.update_icon_map(icon_map_payload)

	lookahead_buffer.cursor = cursor + 1

	# Increment cumulative evolution count (for music ghost timer sync)
	biome_evolution_counts[biome_name] = biome_evolution_counts.get(biome_name, 0) + 1

	if apply_post and biome.quantum_evolution_enabled and not biome.evolution_paused:
		_post_evolution_update(biome)


func prime_lookahead_buffers() -> void:
	# Prime lookahead buffers immediately so viz_cache has payload before UI.
	if not lookahead_enabled:
		return
	_refresh_runtime_activity(true)
	if not _any_active_biomes():
		_prime_frozen_buffers_only()
	for biome in biomes:
		_apply_buffered_step(biome, false)


func _prime_single_biome(biome, biome_id: int) -> void:
	# Prime buffers for a single biome using native engine (fast).
	if not lookahead_enabled or not lookahead_engine:
		return
	if not _is_valid_biome(biome):
		return
	if biome_id < 0:
		return

	var biome_name = _get_biome_name(biome)
	# NEVER send empty rho to C++ (crashes on unpack)
	var qc = biome.quantum_computer
	var rho: PackedFloat64Array
	if qc.density_matrix:
		rho = qc.density_matrix._to_packed()
	else:
		# Return early if no valid state - can't prime
		_log("warn", "biome", "⚠️", "Cannot prime '%s' - density_matrix is null" % biome_name)
		return
	var actual_dt = _get_biome_evolution_dt(biome)
	var result = lookahead_engine.evolve_single_biome(
		biome_id, rho, LOOKAHEAD_STEPS, actual_dt, actual_dt
	)

	var lookahead_buffer = _ensure_lookahead_buffer(biome_name)
	lookahead_buffer.frames = result.get("results", [])
	lookahead_buffer.cursor = 0
	lookahead_buffer.mi_steps = result.get("mi_steps", [])
	lookahead_buffer.latest_mi = result.get("mi", PackedFloat64Array())
	lookahead_buffer.bloch_steps = result.get("bloch_steps", [])
	lookahead_buffer.purity_steps = result.get("purity_steps", [])
	lookahead_buffer.positions = result.get("position_steps", [])
	lookahead_buffer.metadata = result.get("metadata", lookahead_buffer.metadata)
	lookahead_buffer.couplings = result.get("couplings", lookahead_buffer.couplings)
	lookahead_buffer.icon_map = _decorate_icon_map_payload_with_flow(
		biome_name,
		biome,
		result.get("icon_map", lookahead_buffer.icon_map)
	)

	_apply_buffered_step(biome, false)


func get_global_icon_map() -> Dictionary:
	# Aggregate IconMap payloads across all biomes (resource vocabulary).
	var by_emoji: Dictionary = {}
	var sink_flux_by_emoji: Dictionary = {}
	var total = 0.0
	var sink_flux_total = 0.0
	var steps = 0
	var biome_count = 0

	for biome_name in _lookahead_buffers.keys():
		var lookahead_buffer = _lookahead_buffers.get(biome_name, null)
		var payload = lookahead_buffer.icon_map if lookahead_buffer else {}
		if payload.is_empty():
			continue
		if payload.has("steps"):
			steps = max(steps, int(payload.get("steps", 0)))
		var local = payload.get("by_emoji", {})
		if local.is_empty():
			continue
		biome_count += 1
		for emoji in local.keys():
			var weight = float(local[emoji])
			by_emoji[emoji] = by_emoji.get(emoji, 0.0) + weight
		var sink_fluxes = payload.get("sink_fluxes", {})
		if sink_fluxes is Dictionary and not sink_fluxes.is_empty():
			for emoji in sink_fluxes.keys():
				var flux = maxf(0.0, float(sink_fluxes.get(emoji, 0.0)))
				if flux <= 0.0:
					continue
				sink_flux_by_emoji[emoji] = sink_flux_by_emoji.get(emoji, 0.0) + flux

	var emojis: Array = by_emoji.keys()
	emojis.sort_custom(func(a, b): return by_emoji[a] > by_emoji[b])

	var weights = PackedFloat64Array()
	weights.resize(emojis.size())
	for i in range(emojis.size()):
		var emoji = emojis[i]
		var weight = float(by_emoji[emoji])
		weights[i] = weight
		total += weight
	for emoji in sink_flux_by_emoji.keys():
		sink_flux_total += maxf(0.0, float(sink_flux_by_emoji.get(emoji, 0.0)))

	return {
		"emojis": emojis,
		"weights": weights,
		"by_emoji": by_emoji,
		"sink_fluxes": sink_flux_by_emoji,
		"sink_flux_total": sink_flux_total,
		"steps": steps,
		"total": total,
		"num_biomes": biome_count
	}


func _decorate_icon_map_payload_with_flow(biome_name: String, biome, payload: Dictionary) -> Dictionary:
	# Attach sink-flux rates + live sink flux snapshot to IconMap payload.
	var out = payload.duplicate(true) if payload is Dictionary else {}

	var rates = get_biome_sink_flux_rates(biome_name)
	if rates is Dictionary and not rates.is_empty():
		out["sink_flux_rates"] = rates

	var sink_fluxes: Dictionary = {}
	if _is_valid_biome(biome) and biome.quantum_computer and biome.quantum_computer.has_method("get_all_sink_fluxes"):
		sink_fluxes = biome.quantum_computer.get_all_sink_fluxes()
	if sink_fluxes is Dictionary:
		var cleaned: Dictionary = {}
		var total = 0.0
		for emoji in sink_fluxes.keys():
			var flux = maxf(0.0, float(sink_fluxes.get(emoji, 0.0)))
			if flux <= 0.0:
				continue
			cleaned[emoji] = flux
			total += flux
		if not cleaned.is_empty():
			out["sink_fluxes"] = cleaned
			out["sink_flux_total"] = total
		else:
			out.erase("sink_fluxes")
			out.erase("sink_flux_total")

	return out


func _build_probability_map_from_icon_payload(payload: Dictionary) -> Dictionary:
	# Normalize IconMap exposure weights into a probability map (sum = 1 when non-empty).
	if payload.is_empty():
		return {
			"emojis": [],
			"weights": PackedFloat64Array(),
			"by_emoji": {},
			"total": 0.0,
			"source_total": 0.0,
			"steps": 0
		}

	var by_emoji_raw = payload.get("by_emoji", {})
	if not (by_emoji_raw is Dictionary) or by_emoji_raw.is_empty():
		return {
			"emojis": [],
			"weights": PackedFloat64Array(),
			"by_emoji": {},
			"total": 0.0,
			"source_total": 0.0,
			"steps": int(payload.get("steps", 0))
		}

	var source_total = maxf(0.0, float(payload.get("total", 0.0)))
	if source_total <= 0.0:
		for emoji in by_emoji_raw.keys():
			source_total += maxf(0.0, float(by_emoji_raw.get(emoji, 0.0)))

	if source_total <= 0.0:
		return {
			"emojis": [],
			"weights": PackedFloat64Array(),
			"by_emoji": {},
			"total": 0.0,
			"source_total": 0.0,
			"steps": int(payload.get("steps", 0))
		}

	var by_emoji: Dictionary = {}
	var emojis: Array = by_emoji_raw.keys()
	for emoji in emojis:
		by_emoji[emoji] = maxf(0.0, float(by_emoji_raw.get(emoji, 0.0))) / source_total
	emojis.sort_custom(func(a, b): return float(by_emoji.get(a, 0.0)) > float(by_emoji.get(b, 0.0)))

	var weights = PackedFloat64Array()
	weights.resize(emojis.size())
	var total = 0.0
	for i in range(emojis.size()):
		var emoji = emojis[i]
		var prob = float(by_emoji.get(emoji, 0.0))
		weights[i] = prob
		total += prob

	return {
		"emojis": emojis,
		"weights": weights,
		"by_emoji": by_emoji,
		"total": total,
		"source_total": source_total,
		"steps": int(payload.get("steps", 0)),
		"source": "icon_map"
	}


func _build_probability_map_from_populations(by_emoji_raw: Dictionary) -> Dictionary:
	# Build probability map from live quantum populations when IconMap payload is missing.
	if by_emoji_raw.is_empty():
		return {
			"emojis": [],
			"weights": PackedFloat64Array(),
			"by_emoji": {},
			"total": 0.0,
			"source_total": 0.0,
			"steps": 1,
			"source": "qc_populations"
		}

	var source_total = 0.0
	for emoji in by_emoji_raw.keys():
		source_total += maxf(0.0, float(by_emoji_raw.get(emoji, 0.0)))
	if source_total <= 0.0:
		return {
			"emojis": [],
			"weights": PackedFloat64Array(),
			"by_emoji": {},
			"total": 0.0,
			"source_total": 0.0,
			"steps": 1,
			"source": "qc_populations"
		}

	var by_emoji: Dictionary = {}
	var emojis: Array = by_emoji_raw.keys()
	for emoji in emojis:
		by_emoji[emoji] = maxf(0.0, float(by_emoji_raw.get(emoji, 0.0))) / source_total
	emojis.sort_custom(func(a, b): return float(by_emoji.get(a, 0.0)) > float(by_emoji.get(b, 0.0)))

	var weights = PackedFloat64Array()
	weights.resize(emojis.size())
	var total = 0.0
	for i in range(emojis.size()):
		var emoji = emojis[i]
		var prob = float(by_emoji.get(emoji, 0.0))
		weights[i] = prob
		total += prob

	return {
		"emojis": emojis,
		"weights": weights,
		"by_emoji": by_emoji,
		"total": total,
		"source_total": source_total,
		"steps": 1,
		"source": "qc_populations"
	}


func get_global_probability_map() -> Dictionary:
	# Return normalized global probability map derived from IconMap exposure data.
	var icon_map = get_global_icon_map()
	var out = _build_probability_map_from_icon_payload(icon_map)
	if float(out.get("total", 0.0)) <= 0.0:
		var populations: Dictionary = {}
		for biome in biomes:
			if not _is_valid_biome(biome) or not biome.quantum_computer:
				continue
			if biome.quantum_computer.has_method("get_all_populations"):
				var local = biome.quantum_computer.get_all_populations()
				for emoji in local.keys():
					populations[emoji] = float(populations.get(emoji, 0.0)) + maxf(0.0, float(local.get(emoji, 0.0)))
		out = _build_probability_map_from_populations(populations)
	out["num_biomes"] = int(icon_map.get("num_biomes", 0))
	return out


func get_biome_icon_map(biome_name: String) -> Dictionary:
	# Return IconMap payload for a single biome (or empty dict if unavailable).
	if biome_name == "":
		return {}
	var lookahead_buffer = _get_lookahead_buffer(biome_name)
	var payload = lookahead_buffer.icon_map if lookahead_buffer else {}
	if payload is Dictionary:
		return payload.duplicate(true)
	return {}


func get_biome_sink_flux_rates(biome_name: String) -> Dictionary:
	# Return per-emoji sink flux rates for a biome from coupling payloads.
	if biome_name == "":
		return {}
	var lookahead_buffer = _get_lookahead_buffer(biome_name)
	var payload = lookahead_buffer.couplings if lookahead_buffer else {}
	if not (payload is Dictionary):
		return {}
	var sink_fluxes = payload.get("sink_fluxes", {})
	if sink_fluxes is Dictionary:
		return sink_fluxes.duplicate(true)
	return {}


func get_biome_probability_map(biome_name: String) -> Dictionary:
	# Return normalized probability map for a single biome.
	if biome_name == "":
		return {}
	var payload = get_biome_icon_map(biome_name)
	var out = _build_probability_map_from_icon_payload(payload)
	if float(out.get("total", 0.0)) > 0.0:
		return out
	for biome in biomes:
		if not _is_valid_biome(biome):
			continue
		if _get_biome_name(biome) != biome_name:
			continue
		if biome.quantum_computer and biome.quantum_computer.has_method("get_all_populations"):
			return _build_probability_map_from_populations(biome.quantum_computer.get_all_populations())
		break
	return out


func run_additional_cycles(cycles: int, biome_names: Array = []) -> Dictionary:
	if _deterministic_stepper == null:
		return {"success": false, "error": "no_stepper", "evolved_steps": 0}
	return _deterministic_stepper.run_additional_cycles(cycles, biome_names)


func run_time_skip_cycles(cycles: int, dt: float = LOOKAHEAD_DT, biome_names: Array = []) -> Dictionary:
	if _deterministic_stepper == null:
		return {"success": false, "error": "no_stepper", "evolved_steps": 0}
	# Propagate any pending operator changes (gate inject, mode switch, icon learn) to the
	# C++ backend BEFORE evolving. Without this, the time-skip / buffering-off path leaves
	# the C++ engine with stale H/L (the silent twin) — only the live buffering refill
	# processed re-registers before. Now the canonical native path picks them up too.
	_process_pending_reregisters()
	return _deterministic_stepper.run_time_skip_cycles(cycles, dt, biome_names)


func reset_stride_carry(biome_name: String = "") -> void:
	if _deterministic_stepper == null:
		return
	_deterministic_stepper.reset_stride_carry(biome_name)


func _quantum_shapes_valid(qc) -> bool:
	if not qc or not qc.register_map:
		return false
	var dim = int(qc.register_map.dim())
	if dim <= 0:
		return false
	if not qc.density_matrix or int(qc.density_matrix.n) != dim:
		return false
	if qc.hamiltonian and int(qc.hamiltonian.n) != dim:
		return false
	var lindblad_ops = qc.lindblad_operators if "lindblad_operators" in qc else []
	for L in lindblad_ops:
		if L and int(L.n) != dim:
			return false
	return true


func _ensure_biome_quantum_shapes(biome) -> bool:
	# Prevent native matrix-dimension asserts by validating/repairing QC shapes.
	if not _is_valid_biome(biome):
		return false
	var qc = biome.quantum_computer
	if _quantum_shapes_valid(qc):
		return true

	var biome_name = _get_biome_name(biome)
	_log("warn", "quantum", "🧯", "%s: shape mismatch detected before evolve; attempting repair" % biome_name)

	# First pass: ensure density matrix matches current register_map dimension.
	if qc and qc.register_map:
		var target_dim = int(qc.register_map.dim())
		if target_dim > 0 and (not qc.density_matrix or int(qc.density_matrix.n) != target_dim):
			if qc.has_method("initialize_uniform_superposition"):
				qc.initialize_uniform_superposition()

	# Second pass: rebuild biome operators from current register_map.
	if biome.has_method("rebuild_quantum_operators"):
		biome.rebuild_quantum_operators()

	if _quantum_shapes_valid(qc):
		_log("info", "quantum", "✅", "%s: repaired QC shapes; evolution resumed" % biome_name)
		return true

	_log("error", "quantum", "🛑", "%s: QC shape repair failed; skipping evolve cycle" % biome_name)
	return false


func _biome_has_bound_terminals(biome, include_persistent_infra: bool = false) -> bool:
	# Check if a biome has any bound terminals (planted plots).
	if not terminal_pool:
		return true

	if terminal_pool.has_method("get_terminals_in_biome"):
		var biome_name = _get_biome_name(biome)  # Use helper with proper type checking
		if terminal_pool.get_terminals_in_biome(biome_name).size() > 0:
			return true
		if include_persistent_infra:
			return _biome_has_persistent_lindblad_channels(biome)
		return false

	if include_persistent_infra:
		return _biome_has_persistent_lindblad_channels(biome)
	return false


func _biome_has_persistent_lindblad_channels(biome) -> bool:
	# Treat persistent Lindblad channels as active biome infrastructure.
	#
	# This keeps drain/pump infrastructure meaningful even when no terminals are bound.
	if not farm_ref or not ("grid" in farm_ref) or not farm_ref.grid:
		return false
	if not ("plot_biome_assignments" in farm_ref.grid):
		return false

	var biome_name = _get_biome_name(biome)
	for pos in farm_ref.grid.get_plot_biome_assignments().keys():
		if str(farm_ref.grid.get_plot_biome_assignment(pos)) != str(biome_name):
			continue
		var plot = farm_ref.grid.get_plot(pos)
		if not plot:
			continue
		if plot.lindblad_pump_active or plot.lindblad_drain_active:
			return true
	return false


# === PUBLIC API: Per-Biome Control ===

func pause_biome(biome_name: String):
	# Manually pause a biome (stop evolution, no refills).
	#
	# Useful for debugging or performance optimization.
	biome_manual_paused[biome_name] = true
	biome_paused[biome_name] = true
	_active_biome_names.erase(biome_name)
	_log("info", "CONTROL", "⏸️", "%s: manually paused" % biome_name)


func resume_biome(biome_name: String):
	# Manually resume a paused biome (allow evolution and refills).
	biome_manual_paused[biome_name] = false
	_mark_biome_activity_dirty(biome_name)
	_log("info", "CONTROL", "▶️", "%s: manually resumed" % biome_name)


func is_biome_paused(biome_name: String) -> bool:
	# Check if a biome is currently paused.
	return biome_paused.get(biome_name, false) or biome_manual_paused.get(biome_name, false)


func get_biome_evolution_count(biome_name: String) -> int:
	# Get cumulative evolution step count for a biome.
	#
	# Used by MusicManager for ghost timer sync - music position advances
	# with evolution steps, not wall-clock time.
	return biome_evolution_counts.get(biome_name, 0)


func get_biome_diagnostics(biome_name: String) -> Dictionary:
	# Get detailed diagnostics for a SINGLE biome.
	#
	# Returns:
	# - depth: Current buffer depth (unconsumed phrames)
	# - paused: Whether biome is paused (no evolution)
	# - queue_size: Number of pending global packets
	# - active_packet: Whether the currently executing packet targets this biome
	return {
		"biome_name": biome_name,
		"depth": _get_biome_depth(biome_name),
		"paused": is_biome_paused(biome_name),
		"queue_size": _packet_queue.size(),
		"active_packet": _packet_request_targets_biome(_active_packet_request, biome_name),
	}


func get_all_biome_diagnostics() -> Dictionary:
	# Get diagnostics for ALL biomes (per-biome status).
	#
	# Returns dictionary: biome_name -> diagnostics
	var diagnostics: Dictionary = {}
	for biome in biomes:
		if _is_valid_biome(biome):
			var biome_name = _get_biome_name(biome)
			diagnostics[biome_name] = get_biome_diagnostics(biome_name)
	return diagnostics


func _packet_request_targets_biome(packet_request: Dictionary, biome_name: String) -> bool:
	if packet_request.is_empty():
		return false
	var engine_id = _biome_engine_ids.get(biome_name, -1)
	if engine_id < 0:
		return false
	var active_flags = packet_request.get("active_flags", [])
	return engine_id < active_flags.size() and bool(active_flags[engine_id])


func _any_active_biomes() -> bool:
	return not _active_biome_names.is_empty()


func has_runtime_active_biomes() -> bool:
	return _any_active_biomes()


func is_runtime_dormant() -> bool:
	return _active_biome_names.is_empty() and _packet_queue.is_empty() and _active_packet_request.is_empty()


func _prime_frozen_buffers_only(biome_rhos: Array = []) -> void:
	# Fill lookahead buffers with frozen current states (no native compute).
	#
	# Uses QC.export_bloch_packet() to populate buffers with current state.
	# Data flows through the standard railway: buffers → _apply_buffered_step → viz_cache → UI
	for i in range(biomes.size()):
		var biome = biomes[i]
		if not _is_valid_biome(biome):
			continue

		var qc = biome.quantum_computer
		var rho = PackedFloat64Array()
		if i < biome_rhos.size() and biome_rhos[i] is PackedFloat64Array:
			rho = biome_rhos[i]
		if rho.is_empty():
			# Skip calculation if no valid state
			rho = qc.density_matrix._to_packed() if qc.density_matrix else PackedFloat64Array()

		var biome_name = _get_biome_name(biome)

		# Export current state via QC's standard interface
		var bloch_packet = qc.export_bloch_packet()
		var purity = qc.get_purity()

		# Fill buffers with frozen (repeated) values using helper
		var lookahead_buffer = _ensure_lookahead_buffer(biome_name)
		lookahead_buffer.frames = _create_frozen_buffer(rho, LOOKAHEAD_STEPS)
		lookahead_buffer.cursor = 0
		lookahead_buffer.bloch_steps = _create_frozen_buffer(bloch_packet, LOOKAHEAD_STEPS)
		# Purity buffer is Array[float], not Array[PackedFloat64Array]
		var frozen_purity: Array = []
		frozen_purity.resize(LOOKAHEAD_STEPS)
		for step_idx in range(LOOKAHEAD_STEPS):
			frozen_purity[step_idx] = purity
		lookahead_buffer.purity_steps = frozen_purity
		lookahead_buffer.latest_mi = PackedFloat64Array()
		lookahead_buffer.mi_steps = []
		_sync_biome_structure_payload(biome)
		lookahead_buffer.icon_map = {}


func _post_evolution_update(biome):
	# Apply biome-specific post-evolution updates.
	# Semantic drift + attractor tracking removed (semantic layer stripped)

	if biome.dynamics_tracker and biome.has_method("_track_dynamics"):
		biome._track_dynamics()

	match biome.get_biome_type():
		"FungalNetworks":
			if biome.has_method("_update_colony_dominance"):
				biome._update_colony_dominance()
		"VolcanicWorlds":
			if biome.has_method("_update_eruption_state"):
				biome._update_eruption_state()


func signal_user_action():
	# Called when user takes an action that may invalidate lookahead.
	#
	# Triggers immediate refill of affected biome's buffer.
	if lookahead_enabled:
		# Force immediate refill on next physics tick
		lookahead_accumulator = LOOKAHEAD_DT * LOOKAHEAD_STEPS
		_mark_biome_activity_dirty()
		user_action_detected.emit()


func get_buffered_state(biome_name: String) -> PackedFloat64Array:
	# Get current buffered quantum state for a biome.
	#
	# Used by visualization to read buffered native output instead of live state.
	var lookahead_buffer = _get_lookahead_buffer(biome_name)
	var buffer = lookahead_buffer.frames if lookahead_buffer else []
	var cursor = lookahead_buffer.cursor if lookahead_buffer else 0

	if cursor < buffer.size():
		return buffer[cursor]

	return PackedFloat64Array()


func get_buffered_state_offset(biome_name: String, offset: int) -> PackedFloat64Array:
	# Get buffered quantum state at an offset from the current cursor.
	#
	# Args:
	# biome_name: Biome identifier
	# offset: 0 = current, 1 = next frame, etc.
	var lookahead_buffer = _get_lookahead_buffer(biome_name)
	var buffer = lookahead_buffer.frames if lookahead_buffer else []
	if buffer.is_empty():
		return PackedFloat64Array()

	var cursor = lookahead_buffer.cursor if lookahead_buffer else 0
	var target = clampi(cursor + offset, 0, buffer.size() - 1)
	return buffer[target]


func get_buffered_mi(biome_name: String) -> PackedFloat64Array:
	# Get cached mutual information for force graph.
	var lookahead_buffer = _get_lookahead_buffer(biome_name)
	return lookahead_buffer.latest_mi if lookahead_buffer else PackedFloat64Array()


func get_viz_snapshot(biome_name: String, register_id: int, offset: int = 0) -> Dictionary:
	# Get visualization snapshot for a register at a lookahead offset.
	#
	# Returns a dictionary compatible with QuantumVizCache.get_snapshot():
	# {p0, p1, r_xy, phi, theta, purity}
	if register_id < 0:
		return {}
	var lookahead_buffer = _get_lookahead_buffer(biome_name)
	var bloch_steps = lookahead_buffer.bloch_steps if lookahead_buffer else []
	if bloch_steps.is_empty():
		return {}
	var cursor = lookahead_buffer.cursor if lookahead_buffer else 0
	var idx = clampi(cursor + offset, 0, bloch_steps.size() - 1)
	var packed = bloch_steps[idx]
	var base = register_id * 8
	if packed.is_empty() or packed.size() < base + 8:
		return {}

	var p0 = packed[base + 0]
	var p1 = packed[base + 1]
	var x = packed[base + 2]
	var y = packed[base + 3]
	var theta = packed[base + 6]
	var phi = packed[base + 7]
	var r_xy = clampf(sqrt(x * x + y * y), 0.0, 1.0)

	var purity = -1.0
	var purity_steps = lookahead_buffer.purity_steps if lookahead_buffer else []
	if not purity_steps.is_empty() and idx < purity_steps.size():
		purity = purity_steps[idx]

	return {
		"p0": p0,
		"p1": p1,
		"r_xy": r_xy,
		"phi": phi,
		"theta": theta,
		"purity": purity
	}


func get_stats() -> Dictionary:
	# Get performance statistics for monitoring.
	return {
		"biomes": biomes.size(),
		"evolution_interval": EVOLUTION_INTERVAL,
		"total_evolutions": total_evolutions,
		"last_batch_time_ms": last_batch_time_ms,
		"lookahead_enabled": lookahead_enabled,
		"lookahead_refills": lookahead_refills,
		"lookahead_steps": LOOKAHEAD_STEPS,
	}


# =============================================================================
# VISUAL INTERPOLATION LAYER
# =============================================================================
# Phrames update at PhysicsConfig.PHRAME_HZ, visual ticks render at 60fps.
# These methods provide smooth interpolation between phrames.

func get_interpolation_factor() -> float:
	# Get interpolation factor t in [0, 1] for smooth visual rendering.
	#
	# t=0.0: At the current phrame (evolution frame)
	# t=1.0: About to advance to next phrame
	#
	# Visual layer should call this each tick (60 FPS) and use it to interpolate
	# between get_viz_snapshot(biome, reg, 0) and get_viz_snapshot(biome, reg, 1).
	if not lookahead_enabled:
		return 0.0
	return clampf(evolution_accumulator / EVOLUTION_INTERVAL, 0.0, 1.0)


func get_interpolated_snapshot(biome_name: String, register_id: int) -> Dictionary:
	# Get interpolated visualization snapshot for smooth 60fps tick rendering.
	#
	# Interpolates between current phrame and next phrame based on
	# time elapsed since last phrame consumption.
	#
	# Returns: {p0, p1, r_xy, phi, purity, t} where t is the interpolation factor
	var t = get_interpolation_factor()

	# Get current and next frame snapshots
	var curr = get_viz_snapshot(biome_name, register_id, 0)
	var next = get_viz_snapshot(biome_name, register_id, 1)

	# If either is empty, return the non-empty one or empty
	if curr.is_empty():
		return next
	if next.is_empty():
		return curr

	# Interpolate all values
	return {
		"p0": lerpf(curr.get("p0", 0.5), next.get("p0", 0.5), t),
		"p1": lerpf(curr.get("p1", 0.5), next.get("p1", 0.5), t),
		"r_xy": lerpf(curr.get("r_xy", 0.0), next.get("r_xy", 0.0), t),
		"theta": lerpf(curr.get("theta", PI / 2.0), next.get("theta", PI / 2.0), t),
		"phi": _lerp_angle(curr.get("phi", 0.0), next.get("phi", 0.0), t),
		"purity": lerpf(curr.get("purity", 1.0), next.get("purity", 1.0), t),
		"t": t
	}


func update_biome_center(biome_name: String, center: Vector2) -> void:
	# Push the biome's visual oval center to the C++ ForceGraphEngine.
	#
	# Call this after layout changes (viewport resize, active biome switch) so that purity-radial
	# and phase-angular forces are anchored to the correct screen position.
	#
	# Always caches the center so it can be re-applied once deferred engine initialization finishes.
	_biome_centers_cache[biome_name] = center
	if not lookahead_engine:
		return
	var biome_id: int = _biome_engine_ids.get(biome_name, -1)
	if biome_id < 0:
		return
	if lookahead_engine.has_method("set_biome_center"):
		lookahead_engine.set_biome_center(biome_id, center)


func _flush_cached_biome_centers() -> void:
	# Apply every cached biome center to the native engine.
	#
	# Called after deferred engine initialization, and after any biome registration that
	# assigns a new engine biome_id, so the force graph anchors to the correct oval centers
	# from the first evolved frame (not the default (960,540)).
	if not lookahead_engine or not lookahead_engine.has_method("set_biome_center"):
		return
	for biome_name in _biome_centers_cache:
		var biome_id: int = _biome_engine_ids.get(biome_name, -1)
		if biome_id >= 0:
			lookahead_engine.set_biome_center(biome_id, _biome_centers_cache[biome_name])


func get_interpolated_force_positions(biome_name: String) -> PackedVector2Array:
	# Get interpolated force positions for smooth 60fps rendering.
	#
	# Returns interpolated positions between current phrame (t=0) and next phrame (t=1).
	var t = get_interpolation_factor()
	var lookahead_buffer = _get_lookahead_buffer(biome_name)
	var cursor = lookahead_buffer.cursor if lookahead_buffer else 0
	var positions = lookahead_buffer.positions if lookahead_buffer else []

	if positions.is_empty() or cursor >= positions.size():
		return PackedVector2Array()

	# Get current and next positions
	var curr_positions = positions[cursor] if cursor < positions.size() else PackedVector2Array()
	var next_positions = positions[cursor + 1] if (cursor + 1) < positions.size() else curr_positions

	# Interpolate each position
	var result = PackedVector2Array()
	var num_nodes = mini(curr_positions.size(), next_positions.size())
	result.resize(num_nodes)

	for i in range(num_nodes):
		result[i] = curr_positions[i].lerp(next_positions[i], t)

	return result


func get_force_positions(biome_name: String, lookahead: int = 0) -> PackedVector2Array:
	# Get force positions for a biome at cursor + lookahead offset.
	#
	# Args:
	# biome_name: Name of the biome
	# lookahead: Offset from cursor (0 = current, 1 = next, etc.)
	#
	# Returns: PackedVector2Array of node positions
	var lookahead_buffer = _get_lookahead_buffer(biome_name)
	var cursor = lookahead_buffer.cursor if lookahead_buffer else 0
	var positions = lookahead_buffer.positions if lookahead_buffer else []

	var index = cursor + lookahead
	if index >= 0 and index < positions.size():
		return positions[index]
	return PackedVector2Array()


func get_buffer_cursor(biome_name: String) -> int:
	var lookahead_buffer = _get_lookahead_buffer(biome_name)
	return lookahead_buffer.cursor if lookahead_buffer else 0


func get_buffer_depth(biome_name: String) -> int:
	return _get_biome_depth(biome_name)


func _lerp_angle(a: float, b: float, t: float) -> float:
	# Interpolate angles handling wraparound at 2*PI.
	var diff = fmod(b - a + 3.0 * PI, TAU) - PI
	return a + diff * t


func _track_physics_fps() -> void:
	# Track phrame rate (evolution consumption, separate from visual 60 FPS ticks).
	_physics_frame_count += 1
	_evolution_tick_count += 1

	# Initialize timer on first call
	if _physics_fps_start_time == 0:
		_physics_fps_start_time = Time.get_ticks_msec()

	# Update FPS every second (1000ms)
	var now = Time.get_ticks_msec()
	var elapsed = now - _physics_fps_start_time
	if elapsed >= 1000:
		physics_frames_per_second = (_physics_frame_count * 1000.0) / elapsed
		slices_consumed_per_second = (_slices_consumed_count * 1000.0) / elapsed
		fps_window_last_ms = now
		_physics_frame_count = 0
		_slices_consumed_count = 0
		_physics_fps_start_time = now


func _can_consume_phrame(now_ms: int) -> bool:
	# Optional wall-clock pacing guard to cap runaway phrame consumption.
	if _min_phrame_interval_ms <= 0.0:
		return true
	if _last_phrame_wall_ms <= 0:
		return true
	return float(now_ms - _last_phrame_wall_ms) >= _min_phrame_interval_ms


func _run_batcher_watchdog(now_ms: int) -> void:
	# Emit low-rate health metrics and detect starvation in the packet pipeline.
	if _active_biome_names.is_empty() and _packet_queue.is_empty() and _active_packet_request.is_empty():
		_watchdog_stall_warnings = 0
		_watchdog_last_log_ms = now_ms
		return
	if _watchdog_last_log_ms <= 0:
		_watchdog_last_log_ms = now_ms
		return
	if now_ms - _watchdog_last_log_ms < WATCHDOG_LOG_INTERVAL_MS:
		return

	var queued_packets = _packet_queue.size()
	var packet_active = not _active_packet_request.is_empty()
	var min_depth = _get_minimum_buffer_depth()
	if min_depth <= 0 and _packet_completed_at_ms > 0 and (now_ms - _packet_completed_at_ms) > WATCHDOG_STALL_MS * WATCHDOG_FALLBACK_THRESHOLD:
		# Buffer empty for extended period even though packets are being scheduled.
		# At that point the native refill path is effectively starved.
		_watchdog_stall_warnings += 1
		_log("warn", "batcher", "stall", "Buffer starved: depth=0 for %dms, active_packet=%s (warning %d/%d)" % [
			now_ms - _packet_completed_at_ms,
			str(packet_active),
			_watchdog_stall_warnings,
			WATCHDOG_FALLBACK_THRESHOLD
		])
		if _watchdog_stall_warnings >= WATCHDOG_FALLBACK_THRESHOLD:
			push_warning("[BiomeEvolutionBatcher] Buffer empty %dms. Retrying the native packet pipeline." % [
				now_ms - _packet_completed_at_ms])
			_watchdog_stall_warnings = 0
	else:
		# Healthy tick — only reset if buffer is actually filling
		if min_depth > 1:
			_watchdog_stall_warnings = 0
		_log("debug", "batcher", "perf", "pfps=%.2f queue=%d active_packet=%s depth=%d throttled=%d avg_batch=%.1fms" % [
			physics_frames_per_second,
			queued_packets,
			str(packet_active),
			min_depth,
			_throttled_phrame_skips,
			_avg_batch_time_ms
		])
	_throttled_phrame_skips = 0
	_watchdog_last_log_ms = now_ms


func _get_effective_fib_index() -> int:
	var max_fib := INITIAL_BIOME_FIB_INDEX
	for biome_name in biome_fib_indices.keys():
		if not is_biome_paused(str(biome_name)):
			max_fib = maxi(max_fib, int(biome_fib_indices.get(biome_name, INITIAL_BIOME_FIB_INDEX)))
	return max_fib


func _get_effective_batch_size() -> int:
	var fib_index = mini(_get_effective_fib_index(), FIB_SEQUENCE.size() - 1)
	return FIB_SEQUENCE[fib_index]


func _get_effective_buffer_state_name() -> String:
	for biome_name in biome_buffer_states.keys():
		if is_biome_paused(str(biome_name)):
			continue
		if biome_buffer_states.get(biome_name, BufferState.RECOVERY) == BufferState.RECOVERY:
			return "RECOVERY"
	return "COAST"


func _has_emergency_refill() -> bool:
	for biome_name in biome_emergency_refill.keys():
		if bool(biome_emergency_refill.get(biome_name, false)):
			return true
	return false


func get_batching_diagnostics() -> Dictionary:
	# Get detailed diagnostics for batching verification.
	var first_biome_name = ""
	var cursor = -1
	var buffer_size = 0
	var t = get_interpolation_factor()

	if biomes.size() > 0 and biomes[0]:
		first_biome_name = biomes[0].get_biome_type()
		var lookahead_buffer = _get_lookahead_buffer(first_biome_name)
		cursor = lookahead_buffer.cursor if lookahead_buffer else -1
		var buffer = lookahead_buffer.frames if lookahead_buffer else []
		buffer_size = buffer.size()

	var fib_index = _get_effective_fib_index()
	var adaptive_batch_size = _get_effective_batch_size()

	return {
		"lookahead_enabled": lookahead_enabled,
		"evolution_tick": _evolution_tick_count,
		"refill_count": lookahead_refills,
		"buffer_cursor": cursor,
		"buffer_size": buffer_size,
		"buffer_depth": buffer_size - max(0, cursor),
		"interpolation_t": t,
		"evolution_accumulator": evolution_accumulator,
		"lookahead_accumulator": lookahead_accumulator,
		"batch_queue_size": _packet_queue.size(),
		# Aggregate view of the per-biome Fibonacci state.
		"buffer_state": _get_effective_buffer_state_name(),
		"fib_index": fib_index,
		"adaptive_batch_size": adaptive_batch_size,
	}


func reset_performance_metrics() -> void:
	# Reset rolling timing counters so a new profiling phase starts cleanly.
	last_batch_time_ms = 0.0
	_avg_batch_time_ms = 10.0
	_avg_frame_time_ms = 16.67
	_packet_started_at_ms = 0
	_packet_completed_at_ms = 0
	_watchdog_stall_warnings = 0
	_throttled_phrame_skips = 0
	for biome_name in biome_emergency_refill.keys():
		biome_emergency_refill[biome_name] = false


func get_performance_metrics() -> Dictionary:
	# Get C++ task timing metrics for profiling.
	# Calculate buffer depth
	var buffer_depth = _get_minimum_buffer_depth()
	var buffer_coverage_ms = buffer_depth * LOOKAHEAD_DT * 1000.0  # ms of coverage

	var adaptive_batch_size = _get_effective_batch_size()
	var coast_target = adaptive_batch_size * 2
	var refill_threshold_ms = coast_target * 2 * LOOKAHEAD_DT * 1000.0

	var total_biomes_paused = 0
	for biome_name in biome_paused.keys():
		if is_biome_paused(biome_name):
			total_biomes_paused += 1

	return {
		# Timing
		"last_batch_time_ms": last_batch_time_ms,
		"avg_batch_time_ms": _avg_batch_time_ms,
		"avg_frame_time_ms": _avg_frame_time_ms,
		# Adaptive Fibonacci Batching
		"buffer_state": _get_effective_buffer_state_name(),
		"fib_index": _get_effective_fib_index(),
		"adaptive_batch_size": adaptive_batch_size,
		"batch_size": adaptive_batch_size,  # Alias for VisualBubbleTest
		"batches_per_refill": 1,  # Always 1 in adaptive mode (variable size per batch)
		"coast_target": coast_target,
		"emergency_refill": _has_emergency_refill(),
		"refill_threshold_ms": refill_threshold_ms,
		"biomes_total": biomes.size(),
		"biomes_paused": total_biomes_paused,
		"biomes_active": biomes.size() - total_biomes_paused,
		"active_packet": not _active_packet_request.is_empty(),
		"packets_pending": _packet_queue.size(),
		"watchdog_stall_warnings": _watchdog_stall_warnings,
		"phrame_cap_hz": _max_phrame_hz_cap,
		"min_phrame_interval_ms": _min_phrame_interval_ms,
		"packet_pacing_delay_ms": _packet_pacing_delay_ms,
		"max_packet_steps": _max_packet_steps,
		"packet_started_ms_ago": Time.get_ticks_msec() - _packet_started_at_ms if _packet_started_at_ms > 0 else -1,
		"packet_completed_ms_ago": Time.get_ticks_msec() - _packet_completed_at_ms if _packet_completed_at_ms > 0 else -1,
		# Buffer state (minimum across all biomes)
		"buffer_depth": buffer_depth,
		"buffer_coverage_ms": buffer_coverage_ms,
		# Per-Biome Diagnostics
		"per_biome": get_all_biome_diagnostics(),
		# Stats
		"total_evolutions": total_evolutions,
		"refill_count": lookahead_refills,
		"physics_fps": physics_frames_per_second,
	}


# ============================================================================
# LOOKAHEAD PACKETS - synchronous native packet queue
# ============================================================================

func _queue_adaptive_packet(biome_rhos: Array, active_flags_arr: Array, packet_size: int) -> void:
	# Queue a SINGLE C++ packet with adaptive size (Fibonacci-based).
	#
	# Terminology:
	# - phrame = physics/evolution frame (PhysicsConfig.PHRAME_HZ)
	# - packet = C++ batch result containing N phrames
	#
	# IMPORTANT: active_flags_arr is stored in the packet request so merge uses
	# the same engine-id ordering that was queued.
	if biome_rhos.is_empty():
		return

	# Defense-in-depth: skip empty / zero-trace rhos before the native call. The C++ engine
	# now validates dimensions internally (Phase 2 guards in QuantumEvolutionEngine /
	# MultiBiomeLookaheadEngine), so this is no longer the sole safety net — but catching
	# degenerate states here keeps results clean and avoids needless native round-trips.
	for i in range(mini(biome_rhos.size(), active_flags_arr.size())):
		if not active_flags_arr[i]:
			continue
		var rho = biome_rhos[i]
		if rho.is_empty():
			var biome_name = _engine_id_to_biome.get(i, "unknown")
			push_error("BiomeEvolutionBatcher: Active biome '%s' (engine_id=%d) has empty rho! Marking inactive." % [biome_name, i])
			active_flags_arr[i] = false
			continue
		# Also guard zero-trace rhos: C++ crashes on degenerate density matrices
		var dim_i = _biome_engine_dims.get(_engine_id_to_biome.get(i, ""), -1)
		if dim_i > 0 and rho.size() >= dim_i * dim_i * 2:
			var trace = 0.0
			for k in range(dim_i):
				trace += rho[k * (dim_i + 1) * 2]
			if trace < 1e-10:
				var biome_name = _engine_id_to_biome.get(i, "unknown")
				push_warning("BiomeEvolutionBatcher: Active biome '%s' has zero-trace rho. Marking inactive for this packet." % biome_name)
				active_flags_arr[i] = false

	# Queue SINGLE packet with adaptive phrame count
	# active_flags stored IN packet request for correct merge behavior
	var packet_request = {
		"num_steps": packet_size,  # Number of phrames to compute
		"biome_rhos": biome_rhos,
		"active_flags": active_flags_arr,  # Engine-id order
	}
	_packet_queue.append(packet_request)


func _process_next_packet() -> void:
	# Run the next queued native packet synchronously on the main thread.
	if _packet_queue.is_empty():
		return

	_active_packet_request = _packet_queue.pop_front()
	_packet_started_at_ms = Time.get_ticks_msec()
	var result = _compute_packet(_active_packet_request)
	_merge_packet_result(_active_packet_request, result)
	_active_packet_request.clear()
	_packet_started_at_ms = 0
	_packet_completed_at_ms = Time.get_ticks_msec()


func _compute_packet(packet_req: Dictionary) -> Dictionary:
	# Compute one native lookahead packet.
	var biome_rhos = packet_req["biome_rhos"]
	var num_phrames = packet_req["num_steps"]  # Number of phrames (evolution frames) to compute

	var actual_dt = _get_packet_dt_for_active_flags(packet_req.get("active_flags", []))

	var packet_start = Time.get_ticks_usec()
	var result = lookahead_engine.evolve_all_lookahead(
		biome_rhos, num_phrames, actual_dt, actual_dt
	)
	var packet_end = Time.get_ticks_usec()

	# Error handling: check if result is valid
	if result == null or not result is Dictionary:
		push_error("BiomeEvolutionBatcher: Native packet failed - C++ returned invalid result!")
		return {
			"batch_time_us": packet_end - packet_start,
			"error": true,
			"results": [],
			"mi_steps": [],
			"bloch_steps": [],
			"purity_steps": []
		}

	# Add metadata to result
	result["batch_time_us"] = packet_end - packet_start
	result["error"] = false

	return result


func _merge_packet_result(packet_request: Dictionary, result: Dictionary) -> void:
	# Merge one native packet result into the per-biome lookahead buffers.
	var packet_time_ms = result.get("batch_time_us", 0) / 1000.0
	var has_error = result.get("error", false)

	if has_error:
		push_error("BiomeEvolutionBatcher: Native packet completed with errors - skipping merge")
		_packet_queue.clear()
		return

	_avg_batch_time_ms = _smooth_metric(_avg_batch_time_ms, packet_time_ms)
	last_batch_time_ms = packet_time_ms

	var depth_before = _get_minimum_buffer_depth()

	# Build lookup of active biomes (those still in batcher.biomes)
	var active_biome_lookup: Dictionary = {}
	for biome in biomes:
		if _is_valid_biome(biome):
			var biome_name = _get_biome_name(biome)
			active_biome_lookup[biome_name] = biome

	# Get engine biome count for proper result array sizing
	var engine_biome_count = lookahead_engine.get_biome_count() if lookahead_engine else 0

	var results = result.get("results", [])
	var mi_steps = result.get("mi_steps", [])
	var bloch_steps = result.get("bloch_steps", [])
	var purity_steps = result.get("purity_steps", [])
	var position_steps = result.get("position_steps", [])
	var packet_active_flags = packet_request.get("active_flags", [])

	# Distribute to phrame buffers - ONLY for biomes still in batcher.biomes!
	for engine_id in range(engine_biome_count):
		var biome_name = _engine_id_to_biome.get(engine_id, "")
		if biome_name == "":
			continue

		# Skip biomes that have been unregistered from batcher
		if not active_biome_lookup.has(biome_name):
			continue

		var biome = active_biome_lookup[biome_name]
		if not _is_valid_biome(biome):
			continue

		# PHASE 1 FIX: Handle engine_id >= packet_active_flags.size()
		# This happens when a new biome was registered AFTER this packet was queued.
		# DON'T TOUCH its buffer - it wasn't part of this packet's evolution.
		if engine_id >= packet_active_flags.size():
			# New biome added after packet queued - leave existing buffer intact
			# It will be primed separately or included in the next packet
			continue

		# Check if this biome was marked active in the refill request
		if packet_active_flags[engine_id]:
			var lookahead_buffer = _ensure_lookahead_buffer(biome_name)
			var unconsumed_frames = lookahead_buffer.frames.slice(lookahead_buffer.cursor) if lookahead_buffer.cursor < lookahead_buffer.frames.size() else []
			var unconsumed_mi = lookahead_buffer.mi_steps.slice(lookahead_buffer.cursor) if lookahead_buffer.cursor < lookahead_buffer.mi_steps.size() else []
			var unconsumed_bloch = lookahead_buffer.bloch_steps.slice(lookahead_buffer.cursor) if lookahead_buffer.cursor < lookahead_buffer.bloch_steps.size() else []
			var unconsumed_purity = lookahead_buffer.purity_steps.slice(lookahead_buffer.cursor) if lookahead_buffer.cursor < lookahead_buffer.purity_steps.size() else []
			var unconsumed_positions = lookahead_buffer.positions.slice(lookahead_buffer.cursor) if lookahead_buffer.cursor < lookahead_buffer.positions.size() else []

			unconsumed_frames.append_array(results[engine_id] if engine_id < results.size() else [])
			lookahead_buffer.frames = unconsumed_frames
			lookahead_buffer.cursor = 0

			var merged_mi_steps = mi_steps[engine_id] if engine_id < mi_steps.size() else []
			unconsumed_mi.append_array(merged_mi_steps)
			lookahead_buffer.mi_steps = unconsumed_mi
			if not merged_mi_steps.is_empty():
				lookahead_buffer.latest_mi = merged_mi_steps[merged_mi_steps.size() - 1]

			unconsumed_bloch.append_array(bloch_steps[engine_id] if engine_id < bloch_steps.size() else [])
			lookahead_buffer.bloch_steps = unconsumed_bloch

			unconsumed_purity.append_array(purity_steps[engine_id] if engine_id < purity_steps.size() else [])
			lookahead_buffer.purity_steps = unconsumed_purity

			unconsumed_positions.append_array(position_steps[engine_id] if engine_id < position_steps.size() else [])
			lookahead_buffer.positions = unconsumed_positions
			biome_dirty[biome_name] = false
		else:
			# PHASE 2 FIX: Only create frozen buffer if buffer is empty
			# If buffer has unconsumed frames, preserve them (don't overwrite with frozen)
			# This prevents data loss when biomes temporarily become "inactive"
			var current_depth = _get_biome_depth(biome_name)
			if current_depth <= 0:
				# Buffer empty/depleted - prime full frozen payload (rho + bloch + purity)
				# to prevent nodes from dropping into LIFELESS/frozen force mode.
				_prime_single_biome_frozen(biome)
			# else: Keep existing buffer intact (has unconsumed frames)

	lookahead_refills += 1
	var depth_after = _get_minimum_buffer_depth()
	var _num_steps = packet_request.get("num_steps", 0)
	var is_emergency = packet_request.get("is_emergency", false)
	var _pkt_type = "EMERGENCY" if is_emergency else "BATCH"

	_log("trace", "PACKET", "✓", "Complete: %.1fms, depth %d→%d, state=%s" % [
		packet_time_ms, depth_before, depth_after, _get_effective_buffer_state_name()
	])
