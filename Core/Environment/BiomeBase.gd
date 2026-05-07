class_name BiomeBase
extends Node

const _PC = preload("res://Core/Config/PhysicsConfig.gd")
const InstrumentLocator = preload("res://Core/Instrumentation/InstrumentLocator.gd")
const VerboseHelper = preload("res://Core/Config/VerboseHelper.gd")

# Access autoloads safely (avoids compile-time errors)
@onready var _icon_registry = InstrumentLocator.resolve_icon_registry(self)
@onready var _verbose = InstrumentLocator.resolve_verbose_config(self)

## Abstract base class for all biomes (Model C - Unified QuantumComputer)
##
## Model C: Biome owns ONE canonical quantum state (QuantumComputer).
## Plots are hardware attachments (RegisterIds) that reference it.
## No per-plot independent quantum states.
##
## Architecture: Composition with Facade
## BiomeBase delegates to 7 composable components while maintaining
## the same public API for backward compatibility with subclasses.

# Component imports
const FactionBiomeMap = preload("res://Core/Biomes/FactionBiomeMap.gd")
const BiomeResourceRegistry = preload("res://Core/Environment/Components/BiomeResourceRegistry.gd")
const BiomeBellGateTracker = preload("res://Core/Environment/Components/BiomeBellGateTracker.gd")
const BiomeQuantumObserver = preload("res://Core/Environment/Components/BiomeQuantumObserver.gd")
const BiomeGateOperations = preload("res://Core/Environment/Components/BiomeGateOperations.gd")
const BiomeQuantumSystemBuilder = preload("res://Core/Environment/Components/BiomeQuantumSystemBuilder.gd")
const BiomeDensityMatrixMutator = preload("res://Core/Environment/Components/BiomeDensityMatrixMutator.gd")
const QuantumVizCache = preload("res://Core/Visualization/QuantumVizCache.gd")

# Core imports
const QuantumComputer = preload("res://Core/QuantumSubstrate/QuantumComputer.gd")
# QuantumGateLibrary - moved to BiomeGateOperations component
const BiomeUtilities = preload("res://Core/Environment/BiomeUtilities.gd")
const BiomeTimeTracker = preload("res://Core/Environment/BiomeTimeTracker.gd")
const BiomeDynamicsTracker = preload("res://Core/QuantumSubstrate/BiomeDynamicsTracker.gd")
# Icon - accessed via _icon_registry autoload
const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
# DensityMatrix - accessed via quantum_computer

# ============================================================================
# COMPONENT INSTANCES
# ============================================================================

var _resource_registry: BiomeResourceRegistry
var _bell_gate_tracker: BiomeBellGateTracker
var _quantum_observer: BiomeQuantumObserver
var _gate_operations: BiomeGateOperations
var _system_builder: BiomeQuantumSystemBuilder
var _density_mutator: BiomeDensityMatrixMutator
var viz_cache: QuantumVizCache = QuantumVizCache.new()
var icons: Dictionary = {}  # Effective icons for this biome (registry + overrides)
var icon_overrides: Dictionary = {}  # Per-biome icon overrides (never global)

# ============================================================================
# CORE STATE (remains in BiomeBase)
# ============================================================================

# Common infrastructure
var time_tracker: BiomeTimeTracker = BiomeTimeTracker.new()
var dynamics_tracker: BiomeDynamicsTracker = null
var grid = null  # Injected FarmGrid reference

# Central quantum state manager for this biome (ONLY source of truth)
var quantum_computer = null  # QuantumComputer type

# Visual Properties for QuantumForceGraph rendering
var visual_color: Color = Color(0.5, 0.5, 0.5, 0.3)
var visual_label: String = ""
var visual_center_offset: Vector2 = Vector2.ZERO
var visual_circle_radius: float = 150.0
var visual_enabled: bool = true
var visual_oval_width: float = 300.0
var visual_oval_height: float = 185.0

# Signals - common interface for all biomes
signal qubit_measured(position: Vector2i, outcome: String)
signal coupling_updated(emoji_a: String, emoji_b: String, strength: float)
signal bell_gate_created(positions: Array)
signal resource_registered(emoji: String, is_producible: bool, is_consumable: bool)

# Initialization guards
var _is_initialized: bool = false
var _qc_recovery_attempted: bool = false
var _qc_missing_warned: bool = false

# Performance: Control quantum evolution frequency
var quantum_evolution_accumulator: float = 0.0
var quantum_evolution_timestep: float = _PC.PHRAME_DT  # Physics update rate
var quantum_evolution_enabled: bool = true

# Sim-speed: sim-seconds advanced per wall-second.
# Controls how fast the world evolves relative to real time.
# Day/night wall-time = driver_period / quantum_time_scale.
# Default sourced from BalanceConfig.physics.quantum_time_scale.
# See PhysicsConfig for the full derivation.
var quantum_time_scale: float = 0.5  # Overwritten in _ready from BalanceConfig

# Max sim-time per Euler substep (numerical accuracy vs cost).
# At 0.05, a typical phrame is ONE substep (cheapest).
# Reduce if evolution becomes unstable (oscillations, trace divergence).
# See PhysicsConfig.MAX_SUBSTEP_DT for the global default.
var max_evolution_dt: float = _PC.MAX_SUBSTEP_DT

# Observation stride: phrames consumed per physics tick (playback speed)
# 0 = locked (no advancement), 1 = normal, 2+ = fast forward
var observation_stride: int = 1

# BUILD mode pause
var evolution_paused: bool = false

# ============================================================================
# FACADE PROPERTY ACCESSORS (for backward compatibility)
# ============================================================================

# Forward property access to components for backward compatibility
var bell_gates: Array:
	get: return _bell_gate_tracker.bell_gates if _bell_gate_tracker else []
	set(v): if _bell_gate_tracker: _bell_gate_tracker.bell_gates = v

var producible_emojis: Array[String]:
	get: return _resource_registry.producible_emojis if _resource_registry else []
	set(v): if _resource_registry: _resource_registry.producible_emojis = v

var consumable_emojis: Array[String]:
	get: return _resource_registry.consumable_emojis if _resource_registry else []
	set(v): if _resource_registry: _resource_registry.consumable_emojis = v

var emoji_pairings: Dictionary:
	get: return _resource_registry.emoji_pairings if _resource_registry else {}
	set(v): if _resource_registry: _resource_registry.emoji_pairings = v

var planting_capabilities: Array:
	get: return _resource_registry.planting_capabilities if _resource_registry else []
	set(v): if _resource_registry: _resource_registry.planting_capabilities = v

# ============================================================================
# INITIALIZATION
# ============================================================================

func _verbose_log(level: String, category: String, emoji: String, message: String) -> void:
	# Safely log to VerboseConfig if available
	var logger = InstrumentLocator.resolve_verbose_config(self)
	if not logger:
		return
	match level:
		"debug": logger.debug(category, emoji, message)
		"info": logger.info(category, emoji, message)
		"warn": logger.warn(category, emoji, message)
		"error": logger.error(category, emoji, message)


func _ready() -> void:
	# Initialize biome - called by Godot when node enters scene tree
	if _is_initialized:
		return
	_is_initialized = true

	# Initialize components
	_resource_registry = BiomeResourceRegistry.new()
	_bell_gate_tracker = BiomeBellGateTracker.new()
	_quantum_observer = BiomeQuantumObserver.new()
	_gate_operations = BiomeGateOperations.new()
	_system_builder = BiomeQuantumSystemBuilder.new()
	_density_mutator = BiomeDensityMatrixMutator.new()

	# Forward signals from components FIRST (before _initialize_bath emits signals)
	_bell_gate_tracker.bell_gate_created.connect(_on_bell_gate_created)
	_resource_registry.resource_registered.connect(_on_resource_registered)
	_system_builder.coupling_updated.connect(_on_coupling_updated)

	# Initialize biome-specific quantum computer via virtual method
	_initialize_bath()
	_seed_viz_metadata()

	# Wire component dependencies AFTER _initialize_bath() creates the real quantum_computer
	if quantum_computer:
		_quantum_observer.set_quantum_computer(quantum_computer)
		_quantum_observer.set_viz_cache(viz_cache)
		_density_mutator.set_quantum_computer(quantum_computer)

	# Attractor tracking disabled (semantic layer stripped)

	# Processing will be enabled by BootManager
	set_process(false)


func _exit_tree() -> void:
	# Break RefCounted cycles when biome is removed from the farm.
	set_process(false)
	icons.clear()
	icon_overrides.clear()
	grid = null

	if dynamics_tracker:
		dynamics_tracker.clear_history()
	dynamics_tracker = null

	if _bell_gate_tracker:
		_bell_gate_tracker.clear()
	if _resource_registry and _resource_registry.has_method("clear"):
		_resource_registry.clear()
	if _quantum_observer and _quantum_observer.has_method("set_quantum_computer"):
		_quantum_observer.set_quantum_computer(null)
	if _density_mutator and _density_mutator.has_method("set_quantum_computer"):
		_density_mutator.set_quantum_computer(null)
	if _gate_operations and _gate_operations.has_method("set_dependencies"):
		_gate_operations.set_dependencies(null, null, null, null)
	if _system_builder and _system_builder.has_method("set_dependencies"):
		_system_builder.set_dependencies(null, null)
	if viz_cache:
		viz_cache.clear()
		viz_cache.clear_metadata()

	if quantum_computer and quantum_computer.has_method("clear"):
		quantum_computer.clear()
	quantum_computer = null

	_resource_registry = null
	_bell_gate_tracker = null
	_quantum_observer = null
	_gate_operations = null
	_system_builder = null
	_density_mutator = null
	viz_cache = null
	time_tracker = null


func _wire_component_dependencies() -> void:
	# Wire dependencies for components that need IconAtlas (call after _ready)
	_system_builder.set_dependencies(quantum_computer, _resource_registry)
	_gate_operations.set_dependencies(quantum_computer, null, _bell_gate_tracker, time_tracker)
	_gate_operations.set_verbose_log_callback(_verbose_log)


func _get_atom_registry():
	# Refresh IconAtlas reference on demand.
	if _icon_registry and is_instance_valid(_icon_registry):
		return _icon_registry
	_icon_registry = InstrumentLocator.resolve_icon_registry_main_loop()
	return _icon_registry


func _get_base_icon(emoji: String):
	# Get Icon from global registry (no overrides).
	var reg = _get_atom_registry()
	return reg.get_atom(emoji) if reg else null


func _ensure_icon_override(emoji: String):
	# Return biome-local icon override for emoji if it exists.
	return icon_overrides.get(emoji)


func _get_or_clone_icon(emoji: String):
	# Return a biome-local icon, cloning from registry when available.
	if icon_overrides.has(emoji):
		return icon_overrides[emoji]
	var base_icon = _get_base_icon(emoji)
	if base_icon:
		var clone = base_icon.duplicate(true)
		icon_overrides[emoji] = clone
		return clone
	return _ensure_icon_override(emoji)


func _resolve_icon_for_emoji(emoji: String, create_if_missing: bool = false):
	# Resolve effective icon (override > registry). Optionally create local fallback.
	if icon_overrides.has(emoji):
		return icon_overrides[emoji]
	var base_icon = _get_base_icon(emoji)
	if base_icon:
		return base_icon
	if create_if_missing:
		return _ensure_icon_override(emoji)
	return null


func _refresh_effective_icons() -> Dictionary:
	# Rebuild effective icon set for this biome.
	icons = {}
	if not quantum_computer or not quantum_computer.register_map:
		return icons
	for emoji in quantum_computer.register_map.coordinates.keys():
		var icon = _resolve_icon_for_emoji(emoji, true)
		if icon:
			icons[emoji] = icon
	return icons


func get_effective_icons() -> Dictionary:
	# Public accessor for the biome's effective icon set.
	return _refresh_effective_icons()


func _seed_viz_metadata() -> void:
	# Seed viz_cache metadata from register_map when lookahead is disabled.
	if not viz_cache or not quantum_computer or not quantum_computer.register_map:
		return
	if viz_cache.has_metadata():
		return
	var register_map = quantum_computer.register_map
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
	viz_cache.update_metadata_from_payload(payload)

	# Also seed coupling data from icons
	_seed_viz_couplings()


func _seed_viz_couplings() -> void:
	# Seed viz_cache coupling data from icon registry.
	if not viz_cache:
		VerboseHelper.debug("biome", "viz", "_seed_viz_couplings: No viz_cache")
		return

	# Check for icons as property (set by BiomeBuilder) or metadata
	var icons = _refresh_effective_icons()
	if icons.is_empty() and has_meta("icons"):
		icons = get_meta("icons")
		self.icons = icons

	if not icons or icons.is_empty():
		VerboseHelper.debug("biome", "viz", "_seed_viz_couplings: No icons found (property or metadata)")
		return

	VerboseHelper.debug("biome", "viz", "_seed_viz_couplings: Found %d icons" % icons.size())
	var self_energies: Dictionary = {}
	var self_energy_drivers: Dictionary = {}
	var hamiltonian_couplings: Dictionary = {}
	var lindblad_outgoing: Dictionary = {}

	# Extract Hamiltonian/Lindblad visual structure from each icon
	for emoji in icons:
		var icon = icons[emoji]
		if not icon:
			continue

		# Hamiltonian diagonal: the emoji's intrinsic/base frequency.
		if "self_energy" in icon:
			self_energies[emoji] = icon.self_energy
		if "self_energy_driver" in icon and icon.self_energy_driver != "":
			self_energy_drivers[emoji] = {
				"type": icon.self_energy_driver,
				"frequency": icon.driver_frequency if "driver_frequency" in icon else 0.0,
				"phase": icon.driver_phase if "driver_phase" in icon else 0.0,
				"amplitude": icon.driver_amplitude if "driver_amplitude" in icon else 1.0,
			}

		# Hamiltonian couplings
		if "hamiltonian_couplings" in icon:
			hamiltonian_couplings[emoji] = icon.hamiltonian_couplings.duplicate()

		# Lindblad outgoing rates
		if "lindblad_outgoing" in icon:
			lindblad_outgoing[emoji] = icon.lindblad_outgoing.duplicate()

	# Update viz_cache with coupling payload
	var payload = {
		"self_energies": self_energies,
		"self_energy_drivers": self_energy_drivers,
		"hamiltonian": hamiltonian_couplings,
		"lindblad": lindblad_outgoing
	}

	var total_h_couplings = 0
	for emoji in hamiltonian_couplings:
		total_h_couplings += hamiltonian_couplings[emoji].size()

	VerboseHelper.debug("biome", "viz", "_seed_viz_couplings: Populated %d H-couplings into viz_cache" % total_h_couplings)

	viz_cache.update_couplings_from_payload(payload)


# ============================================================================
# SIGNAL FORWARDING (from components to BiomeBase)
# ============================================================================

func _on_bell_gate_created(positions: Array) -> void:
	bell_gate_created.emit(positions)

func _on_resource_registered(emoji: String, is_producible: bool, is_consumable: bool) -> void:
	resource_registered.emit(emoji, is_producible, is_consumable)

func _on_coupling_updated(emoji_a: String, emoji_b: String, strength: float) -> void:
	coupling_updated.emit(emoji_a, emoji_b, strength)


# ============================================================================
# MAIN PROCESS LOOP
# ============================================================================

func _process(delta: float) -> void:
	if not _is_initialized:
		return

	# Check if batched evolution is enabled (BiomeEvolutionBatcher handles evolution)
	if get_meta("batched_evolution", false):
		# Batcher handles quantum evolution
		# Only update time tracker here for UI and drift mechanics
		time_tracker.update(delta)
		return

	if quantum_evolution_enabled:
		quantum_evolution_accumulator += delta
		if quantum_evolution_accumulator >= quantum_evolution_timestep:
			var t0 = Time.get_ticks_usec()
			# Apply quantum_time_scale to slow down/speed up simulation
			var actual_dt = quantum_evolution_accumulator * quantum_time_scale
			quantum_evolution_accumulator = 0.0

			if _ensure_quantum_computer():
				_update_quantum_substrate(actual_dt)
				var t1 = Time.get_ticks_usec()
				if Engine.get_process_frames() % 60 == 0:
					_verbose.trace("biome", "⏱️", "Biome %s Substrate Update: %d us" % [name, t1 - t0])
				
				if not dynamics_tracker:
					dynamics_tracker = BiomeDynamicsTracker.new()
				if dynamics_tracker:
					_track_dynamics()


func _ensure_quantum_computer() -> bool:
	# Ensure quantum_computer exists
	if quantum_computer:
		_qc_recovery_attempted = false
		_qc_missing_warned = false
		return true

	if not _qc_recovery_attempted:
		_qc_recovery_attempted = true
		quantum_computer = QuantumComputer.new(get_biome_type())
		_initialize_bath()

	if not quantum_computer and not _qc_missing_warned:
		push_warning("Biome %s has no quantum_computer" % get_biome_type())
		_qc_missing_warned = true

	return quantum_computer != null


func _update_quantum_substrate(dt: float) -> void:
	# Evolve quantum substrate. Override in subclasses for custom post-evolution logic.
	if quantum_computer:
		quantum_computer.evolve(dt, max_evolution_dt)


func get_drift_status() -> Dictionary:
	# Drift removed — returns inactive stub for any UI that still queries.
	return {"active": false, "intensity": 0.0, "status_text": ""}


# ============================================================================
# EVOLUTION CONTROL
# ============================================================================

func set_evolution_paused(paused: bool) -> void:
	if evolution_paused == paused:
		return
	evolution_paused = paused
	if paused:
		VerboseHelper.info("biome", "pause", "%s: Quantum evolution PAUSED (BUILD mode)" % get_biome_type())
	else:
		VerboseHelper.info("biome", "pause", "%s: Quantum evolution RESUMED (PLAY mode)" % get_biome_type())


func is_evolution_paused() -> bool:
	return evolution_paused


# ============================================================================
# FACADE: Resource Registry Methods
# ============================================================================

func register_resource(emoji: String, is_producible: bool = true, is_consumable: bool = false) -> void:
	_resource_registry.register_resource(emoji, is_producible, is_consumable)

func register_emoji_pair(north: String, south: String) -> void:
	_resource_registry.register_emoji_pair(north, south)

func register_planting_capability(north: String, south: String, plant_type: String,
                                   cost: Dictionary, display_name: String = "",
                                   exclusive: bool = false) -> void:
	_resource_registry.register_planting_capability(north, south, plant_type, cost, display_name, exclusive)

func get_plantable_capabilities() -> Array:
	return _resource_registry.get_plantable_capabilities()

func get_planting_cost(plant_type: String) -> Dictionary:
	return _resource_registry.get_planting_cost(plant_type)

func supports_plant_type(plant_type: String) -> bool:
	return _resource_registry.supports_plant_type(plant_type)

func get_producible_emojis() -> Array[String]:
	return _resource_registry.get_producible_emojis()

func get_consumable_emojis() -> Array[String]:
	return _resource_registry.get_consumable_emojis()

func get_emoji_pairings() -> Dictionary:
	return _resource_registry.get_emoji_pairings()

func can_produce(emoji: String) -> bool:
	return _resource_registry.can_produce(emoji)

func can_consume(emoji: String) -> bool:
	return _resource_registry.can_consume(emoji)

func supports_emoji_pair(north: String, south: String) -> bool:
	return _resource_registry.supports_emoji_pair(north, south, quantum_computer)

func get_harvestable_emojis() -> Array[String]:
	return _resource_registry.get_harvestable_emojis()


# ============================================================================
# FACADE: Bell Gate Tracker Methods
# ============================================================================

func mark_bell_gate(positions: Array) -> void:
	_bell_gate_tracker.mark_bell_gate(positions)

func get_bell_gate(index: int) -> Array:
	return _bell_gate_tracker.get_bell_gate(index)

func get_all_bell_gates() -> Array:
	return _bell_gate_tracker.get_all_bell_gates()

func get_bell_gates_of_size(size: int) -> Array:
	return _bell_gate_tracker.get_bell_gates_of_size(size)

func get_triplet_bell_gates() -> Array:
	return _bell_gate_tracker.get_triplet_bell_gates()

func get_pair_bell_gates() -> Array:
	return _bell_gate_tracker.get_pair_bell_gates()

func has_bell_gates() -> bool:
	return _bell_gate_tracker.has_bell_gates()

func bell_gate_count() -> int:
	return _bell_gate_tracker.bell_gate_count()


# ============================================================================
# FACADE: Quantum Observer Methods
# ============================================================================

func get_observable_theta(north: String, south: String) -> float:
	var bloch = _get_bloch_for_pair(north, south)
	return bloch.get("theta", 0.0) if not bloch.is_empty() else 0.0

func get_observable_phi(north: String, south: String) -> float:
	var bloch = _get_bloch_for_pair(north, south)
	return bloch.get("phi", 0.0) if not bloch.is_empty() else 0.0

func get_observable_coherence(north: String, south: String) -> float:
	var bloch = _get_bloch_for_pair(north, south)
	if bloch.is_empty():
		return 0.0
	var x = bloch.get("x", 0.0)
	var y = bloch.get("y", 0.0)
	return 0.5 * sqrt(x * x + y * y)

func get_observable_radius(north: String, south: String) -> float:
	var bloch = _get_bloch_for_pair(north, south)
	return bloch.get("r", 0.0) if not bloch.is_empty() else 0.0

func get_observable_amplitude(emoji: String) -> float:
	var prob = get_emoji_probability(emoji)
	return sqrt(maxf(prob, 0.0))

func get_observable_phase(emoji: String) -> float:
	var bloch = _get_bloch_for_emoji(emoji)
	return bloch.get("phi", 0.0) if not bloch.is_empty() else 0.0

func get_emoji_probability(emoji: String) -> float:
	if not viz_cache:
		return -1.0
	var q = viz_cache.get_qubit(emoji)
	var pole = viz_cache.get_pole(emoji)
	if q < 0 or pole < 0:
		return -1.0
	var snap = viz_cache.get_snapshot(q)
	if snap.is_empty():
		return -1.0
	var prob = snap.get("p0", -1.0) if pole == 0 else snap.get("p1", -1.0)
	return clampf(prob, 0.0, 1.0) if prob >= 0.0 else -1.0

func get_emoji_coherence(north_emoji: String, south_emoji: String):
	var bloch = _get_bloch_for_pair(north_emoji, south_emoji)
	if bloch.is_empty():
		return 0.0
	var x = bloch.get("x", 0.0)
	var y = bloch.get("y", 0.0)
	return 0.5 * sqrt(x * x + y * y)

func get_purity() -> float:
	if viz_cache:
		var purity = viz_cache.get_purity()
		if purity >= 0.0:
			return purity
	# Fallback: return 0.0 when evolution disabled
	# Formula is amount * (1 + purity), so 0.0 gives base amount with no bonus
	return 0.0


func get_attractor_state() -> Dictionary:
	# The dominant eigenstate of the current density matrix — the pure state
	# this biome is "trying to become" given its Hamiltonian and Lindblad dynamics.
	# Returns {emoji: probability, ..., dominant_eigenvalue, eigenvalue_gap, emojis}.
	if quantum_computer and quantum_computer.has_method("get_attractor_state"):
		return quantum_computer.get_attractor_state()
	return {}


func predict_population(emoji: String, steps_ahead: int) -> float:
	# Return the expected population of an emoji N evolution steps from now.
	# Reads from the lookahead buffer — no additional C++ computation needed.
	# steps_ahead: 0 = current frame, 1–13 = up to LOOKAHEAD_STEPS ahead.
	# Returns -1.0 if the emoji is unknown or the lookahead buffer is empty.
	if not viz_cache:
		return -1.0
	var qubit := viz_cache.get_qubit(emoji)
	var pole := viz_cache.get_pole(emoji)
	if qubit < 0 or pole < 0:
		return -1.0
	var farm = InstrumentLocator.resolve_active_farm(self)
	if not farm or not farm.biome_evolution_batcher:
		# Fallback: return current population when batcher unavailable
		return get_emoji_probability(emoji)
	var snap: Dictionary = farm.biome_evolution_batcher.get_viz_snapshot(
			get_biome_type(), qubit, steps_ahead)
	if snap.is_empty():
		return get_emoji_probability(emoji)
	return snap.get("p0", 0.5) if pole == 0 else snap.get("p1", 0.5)


func predict_purity(steps_ahead: int) -> float:
	# Return the expected purity N evolution steps from now.
	# Returns current purity if lookahead is unavailable.
	var farm = InstrumentLocator.resolve_active_farm(self)
	if not farm or not farm.biome_evolution_batcher:
		return get_purity()
	var snap: Dictionary = farm.biome_evolution_batcher.get_viz_snapshot(
			get_biome_type(), 0, steps_ahead)
	if snap.is_empty():
		return get_purity()
	var p: float = snap.get("purity", -1.0)
	return p if p >= 0.0 else get_purity()


func get_icon_map() -> Dictionary:
	if not viz_cache:
		return {}
	return viz_cache.get_icon_map()


func get_icon_probability(emoji: String, normalized: bool = true) -> float:
	if not viz_cache:
		return 0.0
	return viz_cache.get_icon_map_probability(emoji, normalized)


## Phase VI: market activity decoheres the biome via this single entry point.
## Wraps qc.drain_qubit with the universal η cap. Returns drain diagnostics.
##
## The biome's intrinsic Hamiltonian + Lindbladian dynamics restore coherence
## between events; biomes with net drain > pump die forever. That's the
## emergent gameplay loop the design celebrates.
func apply_atomic_drain(emoji: String, pole: int, eta: float) -> Dictionary:
	const HamiltonianConfig = preload("res://Core/Config/HamiltonianConfig.gd")
	if quantum_computer == null or not quantum_computer.has(emoji):
		return {"drained": 0.0, "error": "no_qubit"}
	var qubit_idx: int = quantum_computer.qubit(emoji)
	var pre_marginal: float = quantum_computer.get_marginal(qubit_idx, pole)
	var capped_eta: float = clampf(eta, 0.0, HamiltonianConfig.ETA_HARD_CAP)
	if capped_eta <= 0.0:
		return {"drained": 0.0, "qubit_idx": qubit_idx, "pre": pre_marginal, "post": pre_marginal}
	quantum_computer.drain_qubit(qubit_idx, pole, capped_eta)
	var post_marginal: float = quantum_computer.get_marginal(qubit_idx, pole)
	return {
		"drained": pre_marginal - post_marginal,
		"qubit_idx": qubit_idx,
		"pre": pre_marginal,
		"post": post_marginal,
		"eta": capped_eta,
	}

func get_register_emoji_pair(register_id: int) -> Dictionary:
	if not viz_cache:
		return {}
	return viz_cache.get_axis(register_id)

func get_coherence_with_other_registers(register_id: int) -> float:
	if not viz_cache or viz_cache.get_num_qubits() <= 1:
		return 0.0
	var max_mi = 0.0
	var n = viz_cache.get_num_qubits()
	for i in range(n):
		if i == register_id:
			continue
		var mi = viz_cache.get_mutual_information(register_id, i)
		if mi > max_mi:
			max_mi = mi
	return max_mi


# ============================================================================
# FACADE: Plot Register Manager Methods
# ============================================================================

## Get register probability for a specific register ID
func get_register_probability(register_id: int) -> float:
	if _quantum_observer and _quantum_observer.has_method("get_register_probability"):
		return float(_quantum_observer.get_register_probability(register_id))
	return -1.0

## Get all unbound register IDs (available for new terminal binding)
func get_unbound_registers(terminal_pool = null) -> Array[int]:
	# Get all register IDs not currently bound to a terminal.
	if not viz_cache:
		return []
	var num_qubits = viz_cache.get_num_qubits()
	var unbound: Array[int] = []
	var biome_name = get_biome_type()

	for reg_id in range(num_qubits):
		if not terminal_pool or not terminal_pool.is_register_bound(reg_id, biome_name):
			unbound.append(reg_id)

	return unbound

## Get probability distribution over all unbound registers
func get_register_probabilities(terminal_pool = null) -> Dictionary:
	# Get probability distribution for weighted register selection.
	var probs: Dictionary = {}
	var unbound = get_unbound_registers(terminal_pool)

	for reg_id in unbound:
		var prob = get_register_probability(reg_id)
		if prob >= 0.0:
			probs[reg_id] = prob

	return probs

## Get total number of registers in this biome
func get_total_register_count() -> int:
	if not viz_cache:
		return 0
	return viz_cache.get_num_qubits()

## Get registers not currently bound to any terminal (V2 Architecture)
func get_available_registers(terminal_pool) -> Array[int]:
	# Get unbound registers for EXPLORE action.
	return get_unbound_registers(terminal_pool)


func _get_bloch_for_emoji(emoji: String) -> Dictionary:
	if not viz_cache:
		return {}
	var q = viz_cache.get_qubit(emoji)
	if q < 0:
		return {}
	return viz_cache.get_bloch(q)


func _get_bloch_for_pair(north: String, south: String) -> Dictionary:
	if not viz_cache:
		return {}
	var q = viz_cache.get_qubit(north)
	if q < 0:
		q = viz_cache.get_qubit(south)
	if q < 0:
		return {}
	return viz_cache.get_bloch(q)


# ============================================================================
# FACADE: Gate Operations Methods
# ============================================================================

func apply_gate_1q(position: Vector2i, gate_name: String) -> bool:
	_wire_component_dependencies()
	return _gate_operations.apply_gate_1q(position, gate_name)

func apply_gate_2q(position_a: Vector2i, position_b: Vector2i, gate_name: String) -> bool:
	_wire_component_dependencies()
	return _gate_operations.apply_gate_2q(position_a, position_b, gate_name)

func entangle_plots(position_a: Vector2i, position_b: Vector2i) -> bool:
	_wire_component_dependencies()
	return _gate_operations.entangle_plots(position_a, position_b)

func create_cluster_state(positions: Array[Vector2i]) -> bool:
	_wire_component_dependencies()
	return _gate_operations.create_cluster_state(positions)

func batch_entangle(positions: Array[Vector2i]) -> bool:
	_wire_component_dependencies()
	return _gate_operations.batch_entangle(positions)

func set_measurement_trigger(trigger_pos: Vector2i, target_positions: Array[Vector2i]) -> bool:
	_wire_component_dependencies()
	return _gate_operations.set_measurement_trigger(trigger_pos, target_positions)

func remove_entanglement(pos_a: Vector2i, pos_b: Vector2i) -> bool:
	_wire_component_dependencies()
	return _gate_operations.remove_entanglement(pos_a, pos_b)

func batch_measure_plots(position: Vector2i) -> Dictionary:
	_wire_component_dependencies()
	return _gate_operations.batch_measure_plots(position, func(pos, outcome): qubit_measured.emit(pos, outcome))


# ============================================================================
# FACADE: Quantum System Builder Methods
# ============================================================================

func expand_quantum_system(north_emoji: String, south_emoji: String) -> Dictionary:
	_wire_component_dependencies()
	# Ensure biome-local icons exist before expansion (no global mutations)
	_ensure_icon_override(north_emoji)
	_ensure_icon_override(south_emoji)
	var result = _system_builder.expand_quantum_system(north_emoji, south_emoji)
	if result.get("success", false):
		_refresh_effective_icons()
	return result


## Add an atom pair to this biome's canonical state, then grow the substrate.
##
## Per the emoji-graph-spaghetti vision (biomes.json is mutable canonical):
## this writes the new atoms into the live Biome instance via BiomeRegistry,
## then calls expand_quantum_system to allocate the qubit axis. The atoms-
## native LindbladBuilder.build_from_atoms path picks up any primed terms
## whose endpoints are now in basis on the next substrate rebuild — so an
## emoji like 🗑 dropped into MarketDistrict automatically lights up every
## term that was authored with 🗑 as source or target.
##
## Returns the same dict shape as expand_quantum_system; adds a `canonical`
## key indicating whether the canonical mutation took effect.
func add_atom_pair(north_emoji: String, south_emoji: String, icon_name: String = "") -> Dictionary:
	var biome_name = get_biome_type()
	var registry = load("res://Core/Biomes/BiomeRegistry.gd").new()
	var canonical_ok: bool = registry.add_atom_pair_to_biome(biome_name, north_emoji, south_emoji, icon_name)
	# expand_quantum_system handles the substrate allocation + operator rebuild;
	# even if canonical mutation was a no-op (already in basis), the substrate
	# call surfaces the canonical error to the caller via its own success flag.
	var result = expand_quantum_system(north_emoji, south_emoji)
	result["canonical"] = canonical_ok
	return result

func inject_coupling(emoji_a: String, emoji_b: String, strength: float) -> Dictionary:
	_wire_component_dependencies()
	return _system_builder.inject_coupling(emoji_a, emoji_b, strength)


# ============================================================================
# FACADE: Density Matrix Mutator Methods
# ============================================================================

func collapse_register(register_id: int, is_north: bool) -> void:
	_density_mutator.collapse_register(register_id, is_north)

func drain_register_probability(register_id: int, is_north: bool, drain_factor: float) -> void:
	_density_mutator.drain_register_probability(register_id, is_north, drain_factor)


# ============================================================================
# QUANTUM OPERATIONS
# ============================================================================

func boost_coupling(emoji: String, target_emoji: String, factor: float = 1.5) -> bool:
	var result = inject_coupling(emoji, target_emoji, factor)
	return result.get("success", false)


# ============================================================================
# BATH INITIALIZATION (Virtual - Override in subclasses)
# ============================================================================

func _initialize_bath() -> void:
	# Override in subclasses to set up the quantum computer.
	pass

func rebuild_quantum_operators() -> void:
	# Rebuild Hamiltonian operators (call after IconAtlas is ready)
	if quantum_computer:
		_rebuild_quantum_operators_impl()

func _rebuild_quantum_operators_impl() -> void:
	# TODO: Faction standing → H rebuild not yet implemented for icon-cloud path.
	# Stubbed pending redesign (faction affinity weighting of icon H terms).
	# See BiomeBuilder.rebuild_icons_for_standings() for the hook point.
	pass


func _project_faction_standings_to_scalars() -> Dictionary:
	# Read the active farm's FactionStanding records and project the 6 channels
	# to a single scalar per faction. Empty dict means 'no standings yet' —
	# IconBuilder treats absent factions as neutral weight (1.0).
	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm == null:
		_verbose_log("debug", "biome", "🪶", "rebuild: no active farm yet — neutral standings")
		return {}
	if farm.faction_standings == null or farm.faction_standings.is_empty():
		return {}
	var out: Dictionary = {}
	for fname in farm.faction_standings:
		var standing = farm.faction_standings[fname]
		if standing == null:
			continue
		assert(standing.has_method("scalar"),
			"FactionStanding for '%s' missing scalar() — record schema corrupted" % fname)
		out[str(fname)] = float(standing.scalar())
	return out


# ============================================================================
# FACTION AFFINITY (Phase 2 prep)
# ============================================================================

var _admitted_factions_cache = null  # Array or null; invalidated on rebuild
var _faction_affinity_cache = null   # AffinityGraph or null; invalidated on rebuild


func get_admitted_factions() -> Array:
	## Cached list of faction names admitted to this biome via the faction-signature
	## gate. Equivalent to FactionBiomeMap.factions_for_biome_by_signature(self) but
	## cached per biome and invalidated whenever the Hamiltonian is rebuilt.
	if _admitted_factions_cache != null:
		return _admitted_factions_cache
	_admitted_factions_cache = FactionBiomeMap.factions_for_biome_by_signature(self)
	return _admitted_factions_cache


func get_faction_affinity():
	## AffinityGraph built from the corner states of factions admitted to this
	## biome via the faction-signature gate. Returns null when no factions are
	## admitted or the registry is unavailable.
	##
	## Used by Phase 2 attunement: player_affinity.overlap(biome.get_faction_affinity())
	## equals 1.0 when the player's 12-qubit substrate matches the biome's faction field.
	if _faction_affinity_cache != null:
		return _faction_affinity_cache
	const AffinityGraph = preload("res://Core/Affinity/AffinityGraph.gd")
	const FactionRegistry = preload("res://Core/Factions/FactionRegistry.gd")
	var native: Array = get_admitted_factions()
	if native.is_empty():
		return null
	var registry = null
	var farm = InstrumentLocator.resolve_active_farm(self)
	if farm != null and "faction_density" in farm and farm.faction_density != null and farm.faction_density.has_method("get_registry"):
		registry = farm.faction_density.get_registry()
	if registry == null:
		registry = FactionRegistry.new()
	var g = AffinityGraph.from_uniform_superposition()
	var weight: float = 1.0 / float(native.size())
	for fname in native:
		var f = registry.get_by_name(str(fname))
		if f == null or not ("bits" in f):
			continue
		var corner = AffinityGraph.from_corner(f.bits)
		g.lindblad_jump_toward(corner, weight)  # modifies g in-place (void return)
	_faction_affinity_cache = g
	return g


# ============================================================================
# STATUS & DEBUG
# ============================================================================

func get_status() -> Dictionary:
	var quantum_size = 0
	if quantum_computer and quantum_computer.register_map:
		quantum_size = quantum_computer.register_map.num_qubits
	return BiomeUtilities.create_status_dict({
		"type": get_biome_type(),
		"qubits": quantum_size,
		"time": time_tracker.time_elapsed,
		"cycles": time_tracker.cycle_count
	})

func get_biome_type() -> String:
	return "Base"

func get_visual_config() -> Dictionary:
	return {
		"color": visual_color,
		"label": visual_label if visual_label != "" else get_biome_type(),
		"center_offset": visual_center_offset,
		"circle_radius": visual_circle_radius,
		"oval_width": visual_oval_width,
		"oval_height": visual_oval_height,
		"enabled": visual_enabled
	}

func render_biome_content(graph: Node2D, center: Vector2, radius: float) -> void:
	pass

func get_plot_positions_in_oval(plot_count: int, center: Vector2, viewport_scale: float = 1.0) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if plot_count == 0:
		return positions

	var semi_a = (visual_oval_width * viewport_scale) / 2.0
	var semi_b = (visual_oval_height * viewport_scale) / 2.0
	var rings = max(1, ceil(sqrt(float(plot_count) / 3.0)))
	var plots_per_ring = []
	var remaining = plot_count

	for ring_idx in range(rings):
		var plots_in_ring = int(ceil(float(remaining) / float(rings - ring_idx)))
		plots_per_ring.append(plots_in_ring)
		remaining -= plots_in_ring

	var ring_idx = 0
	for num_plots in plots_per_ring:
		var scale = 0.3 + (0.6 * float(ring_idx) / float(max(1, rings - 1)))
		for plot_in_ring in range(num_plots):
			var t = (float(plot_in_ring) / float(num_plots)) * TAU
			var x = center.x + semi_a * cos(t) * scale
			var y = center.y + semi_b * sin(t) * scale
			positions.append(Vector2(x, y))
		ring_idx += 1

	positions.sort_custom(func(a, b): return a.x < b.x)
	return positions


# ============================================================================
# DYNAMICS TRACKING
# ============================================================================

func _track_dynamics() -> void:
	if not quantum_computer or not dynamics_tracker:
		return
	var purity = quantum_computer.get_purity() if quantum_computer.has_method("get_purity") else -1.0
	var entropy = _calculate_quantum_entropy()
	var coherence = _calculate_quantum_coherence()
	dynamics_tracker.add_snapshot({"purity": purity, "entropy": entropy, "coherence": coherence})

func _calculate_quantum_entropy() -> float:
	if not quantum_computer or not quantum_computer.density_matrix:
		return -1.0
	var purity = quantum_computer.get_purity() if quantum_computer.has_method("get_purity") else -1.0
	var dim = quantum_computer.density_matrix.dimension() if quantum_computer.density_matrix.has_method("dimension") else 1
	if purity < 0.0:
		return -1.0
	if purity <= 0 or dim <= 1:
		return 0.0
	var max_entropy = log(dim)
	if max_entropy <= 0:
		return 0.0
	return clamp(-log(purity) / max_entropy, 0.0, 1.0)

func _calculate_quantum_coherence() -> float:
	if not quantum_computer or not quantum_computer.density_matrix:
		return 0.0
	var dm = quantum_computer.density_matrix
	var dim = dm.dimension() if dm.has_method("dimension") else 0
	if dim < 2:
		return 0.0
	var mat = dm.get_matrix() if dm.has_method("get_matrix") else null
	if not mat:
		return 0.0
	var total = 0.0
	for i in range(dim):
		for j in range(dim):
			if i != j:
				var element = mat.get_element(i, j)
				if element:
					total += element.re * element.re + element.im * element.im
	var max_coherence = float(dim * (dim - 1))
	return clamp(total / max_coherence, 0.0, 1.0) if max_coherence > 0 else 0.0


# ============================================================================
# RESET & LIFECYCLE
# ============================================================================

func reset() -> void:
	if quantum_computer:
		quantum_computer.clear()
	if _bell_gate_tracker:
		_bell_gate_tracker.clear()
	time_tracker.reset()
	if dynamics_tracker:
		dynamics_tracker.clear_history()


# ============================================================================
# VECTOR HARVEST OPERATIONS
# ============================================================================

func harvest_all_plots() -> Array:
	return []


# NOTE: Energy tap system removed (2026-01) - was half-disabled and confusing
# Use plot-based quantum measurement + economy credits instead
