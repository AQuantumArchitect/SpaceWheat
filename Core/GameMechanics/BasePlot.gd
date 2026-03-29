class_name BasePlot
extends Resource

## BasePlot - Thin grid cell with delegating properties
##
## Architecture: Register → Terminal → (thin Plot) → Visualization
##
## When a terminal (instrument probe) is attached, delegating properties
## read from it directly. Without a terminal, fallback fields are used
## (headless mode / bind_to_register without a terminal).
##
## Terminal is the primary data source when attached:
##   plot.bound_register_id → terminal.bound_register_id (if terminal) else fallback
##   plot.is_measured → terminal.is_measured (if terminal) else fallback
##
## Infrastructure (theta_frozen, lindblad_*, persistent_gates) delegates to
## register_infrastructure via QuantumComputer (unchanged).

const VerboseHelper = preload("res://Core/Config/VerboseHelper.gd")

func _log(level: String, category: String, emoji: String, message: String) -> void:
	VerboseHelper.log(level, category, emoji, message)

# Signals removed: growth_complete (unused), state_collapsed (unused)

# ============================================================================
# IDENTITY (kept on plot)
# ============================================================================

@export var plot_id: String = ""
@export var grid_position: Vector2i = Vector2i.ZERO

# ============================================================================
# REGISTER BINDING (delegates to terminal when attached, else uses fallback fields)
# ============================================================================

## Terminal reference (instrument probe attached to this plot — primary data source)
var terminal = null

## Fallback fields (used by headless mode / bind_to_register without a terminal)
var _bound_register_id: int = -1
var _bound_biome_name: String = ""
var _north_emoji: String = ""
var _south_emoji: String = ""
var _is_measured: bool = false
var _measured_outcome: String = ""
var _measured_probability: float = 0.0

## Delegating properties: terminal takes priority when present
var bound_register_id: int:
	get: return terminal.bound_register_id if terminal else _bound_register_id
	set(value): _bound_register_id = value
var bound_biome_name: String:
	get: return terminal.bound_biome_name if terminal else _bound_biome_name
	set(value): _bound_biome_name = value
var north_emoji: String:
	get: return terminal.north_emoji if terminal else _north_emoji
	set(value): _north_emoji = value
var south_emoji: String:
	get: return terminal.south_emoji if terminal else _south_emoji
	set(value): _south_emoji = value
var is_measured: bool:
	get: return terminal.is_measured if terminal else _is_measured
	set(value): _is_measured = value
var measured_outcome: String:
	get: return terminal.measured_outcome if terminal else _measured_outcome
	set(value): _measured_outcome = value
var measured_probability: float:
	get: return terminal.measured_probability if terminal else _measured_probability
	set(value): _measured_probability = value

## Cached biome Node (resolved from bound_biome_name)
var _cached_biome = null

# ============================================================================
# INFRASTRUCTURE (computed from register_infrastructure — survives harvest/replant)
# ============================================================================

## theta_frozen: delegates to register_infrastructure
var theta_frozen: bool:
	get: return _get_infra_field("theta_frozen", false)
	set(value): _set_infra_field("theta_frozen", value)

# Positional — NOT per-register
@export var replant_cycles: int = 0

# Entanglement tracking (updated via parent_biome quantum computer)
var entangled_plots: Dictionary = {}  # plot_id -> strength
const MAX_ENTANGLEMENTS = 3

## persistent_gates: delegates to register_infrastructure
var persistent_gates: Array[Dictionary]:
	get:
		var raw = _get_infra_field("persistent_gates", [])
		var typed: Array[Dictionary] = []
		for g in raw:
			typed.append(g)
		return typed
	set(value): _set_infra_field("persistent_gates", value)

## Lindblad computed properties — delegate to register_infrastructure
var lindblad_pump_active: bool:
	get: return _get_infra_field("lindblad_pump_active", false)
	set(value): _set_infra_field("lindblad_pump_active", value)

var lindblad_drain_active: bool:
	get: return _get_infra_field("lindblad_drain_active", false)
	set(value): _set_infra_field("lindblad_drain_active", value)

var lindblad_pump_rate: float:
	get: return _get_infra_field("lindblad_pump_rate", 0.5)
	set(value): _set_infra_field("lindblad_pump_rate", value)

var lindblad_drain_rate: float:
	get: return _get_infra_field("lindblad_drain_rate", 0.5)
	set(value): _set_infra_field("lindblad_drain_rate", value)

var lindblad_drain_accumulator: float:
	get: return _get_infra_field("lindblad_drain_accumulator", 0.0)
	set(value): _set_infra_field("lindblad_drain_accumulator", value)


func _init():
	plot_id = "plot_%d" % randi()


# ============================================================================
# REGISTER ACCESSORS (read from BasePlot state - NEW architecture)
# ============================================================================

func get_register_id() -> int:
	return bound_register_id

func get_biome_name() -> String:
	return bound_biome_name

func is_active() -> bool:
	return bound_register_id >= 0 and bound_biome_name != ""

func has_terminal() -> bool:
	return terminal != null and terminal.is_bound

func get_north_emoji() -> String:
	return north_emoji

func get_south_emoji() -> String:
	return south_emoji

func get_is_measured() -> bool:
	return is_measured

func get_measured_outcome() -> String:
	return measured_outcome

func get_measured_probability() -> float:
	return measured_probability

# ============================================================================
# REGISTER BINDING METHODS (simulation layer - headless compatible)
# ============================================================================

func attach_terminal(t) -> void:
	"""Attach a terminal probe to this plot. Delegating properties auto-switch to reading from it."""
	terminal = t
	_cached_biome = null


func detach_terminal() -> void:
	"""Detach terminal probe. Delegating properties fall back to stored fields."""
	terminal = null
	_cached_biome = null


func bind_to_register(register_id: int, biome_name: String, emoji_pair: Dictionary) -> void:
	"""Bind this plot to a quantum register (headless / fallback path).

	Sets fallback fields directly. When a terminal is attached, delegating
	properties read from the terminal instead (terminal takes priority).
	"""
	_bound_register_id = register_id
	_bound_biome_name = biome_name
	_north_emoji = emoji_pair.get("north", "")
	_south_emoji = emoji_pair.get("south", "")
	_is_measured = false
	_measured_outcome = ""
	_measured_probability = 0.0
	_cached_biome = null


func unbind_register() -> void:
	"""Unbind this plot from its register and detach terminal."""
	terminal = null
	_bound_register_id = -1
	_bound_biome_name = ""
	_north_emoji = ""
	_south_emoji = ""
	_is_measured = false
	_measured_outcome = ""
	_measured_probability = 0.0
	_cached_biome = null


func mark_measured(outcome: String, probability: float) -> void:
	"""Mark this plot as measured (fallback fields — terminal.mark_measured is preferred)."""
	_is_measured = true
	_measured_outcome = outcome
	_measured_probability = probability


# ============================================================================
# BIOME RESOLUTION (cached from terminal binding)
# ============================================================================

func _resolve_biome():
	"""Resolve biome Node from bound_biome_name."""
	if _cached_biome:
		return _cached_biome
	if bound_biome_name == "":
		return null
	var tree = Engine.get_main_loop()
	if tree and tree is SceneTree:
		var abm = tree.root.get_node_or_null("/root/ActiveBiomeManager")
		if abm and abm.has_method("get_biome_by_name"):
			_cached_biome = abm.get_biome_by_name(bound_biome_name)
			return _cached_biome
		# Fallback: try farm grid lookup
		var farm = tree.root.get_node_or_null("Farm")
		if farm and farm.grid:
			_cached_biome = farm.grid.get_biome(bound_biome_name)
			return _cached_biome
	return null


func _resolve_quantum_computer():
	var biome = _resolve_biome()
	if biome and "quantum_computer" in biome and biome.quantum_computer:
		return biome.quantum_computer
	return null


func _get_infra_field(field: String, default = null):
	if bound_register_id < 0:
		return default
	var qc = _resolve_quantum_computer()
	if not qc: return default
	return qc.get_register_infra_field(bound_register_id, field, default)


func _set_infra_field(field: String, value) -> void:
	if bound_register_id < 0: return
	var qc = _resolve_quantum_computer()
	if not qc: return
	qc.set_register_infra_field(bound_register_id, field, value)

# ============================================================================
# COMPUTED PROPERTIES
# ============================================================================

## parent_biome: Computed property for convenient biome access
var parent_biome:
	get:
		return _resolve_biome()
	set(value):
		_cached_biome = value  # Allow explicit set for caching

# ============================================================================
# QUANTUM STATE ACCESS (Computed from Register → Biome's Quantum Computer)
# ============================================================================

## Get basis labels for this plot's measurement basis
func get_basis_labels() -> Array[String]:
	return [get_north_emoji(), get_south_emoji()]

## Get purity from parent biome's quantum computer
func get_purity() -> float:
	"""Query purity from parent biome's quantum computer."""
	if not is_active():
		return 0.0
	var biome = _resolve_biome()
	if not biome or not biome.viz_cache:
		return 0.0
	var purity = biome.viz_cache.get_purity()
	return purity if purity >= 0.0 else 0.0

## Get coherence from parent biome's quantum computer
func get_coherence() -> float:
	"""Query coherence from parent biome's quantum computer."""
	if not is_active():
		return 0.0
	var biome = _resolve_biome()
	if not biome or not biome.viz_cache:
		return 0.0
	var q = biome.viz_cache.get_qubit(get_north_emoji())
	if q < 0:
		return 0.0
	var bloch = biome.viz_cache.get_bloch(q)
	if bloch.is_empty():
		return 0.0
	var x = bloch.get("x", 0.0)
	var y = bloch.get("y", 0.0)
	return 0.5 * sqrt(x * x + y * y)

## Get mass (probability in subspace)
func get_mass() -> float:
	"""Get probability mass in measurement basis subspace."""
	if not is_active():
		return 0.0
	var biome = _resolve_biome()
	if not biome or not biome.viz_cache:
		return 0.0
	var q = biome.viz_cache.get_qubit(get_north_emoji())
	if q < 0:
		return 0.0
	var snap = biome.viz_cache.get_snapshot(q)
	if snap.is_empty():
		return 0.0
	var p_north = snap.get("p0", 0.5)
	var p_south = snap.get("p1", 0.5)
	return p_north + p_south

## Core Methods

func get_dominant_emoji() -> String:
	"""Get the current outcome emoji (measured or dominant basis state)."""
	if get_is_measured() and get_measured_outcome() != "":
		return get_measured_outcome()
	return get_north_emoji() if (randf() < 0.5) else get_south_emoji()


func get_plot_emojis() -> Dictionary:
	"""Get the dual-emoji pair for this plot.

	Reads from BasePlot fields (Register→Plot architecture).
	Falls back to biome capabilities or empty dict.
	"""
	if is_active():
		return {"north": north_emoji, "south": south_emoji}

	var biome = _resolve_biome()
	if biome and biome.has_method("get_plantable_capabilities"):
		var type_name = get("plot_type_name")
		if type_name:
			for cap in biome.get_plantable_capabilities():
				if cap.plant_type == type_name:
					return cap.emoji_pair

	return {"north": get_north_emoji(), "south": get_south_emoji()}




func reset() -> void:
	"""Reset plot to initial state.
	NOTE: Infrastructure (gates, lindblad, etc.) lives on register_infrastructure
	and naturally survives harvest/replant."""
	unbind_register()
	_cached_biome = null
	entangled_plots.clear()


func remove_entanglement(partner_id: String) -> void:
	"""Remove entanglement with a specific plot.
	Called when breaking entanglement or when partner plot is harvested."""
	if entangled_plots.has(partner_id):
		entangled_plots.erase(partner_id)


# ============================================================================
# PERSISTENT GATE INFRASTRUCTURE
# ============================================================================

func add_persistent_gate(gate_type: String, linked_plots: Array[Vector2i] = []) -> void:
	"""Add a persistent gate to this plot. Gates survive harvest/replant."""
	if bound_register_id < 0: return
	var qc = _resolve_quantum_computer()
	if not qc: return
	qc.add_persistent_gate_to_register(bound_register_id, gate_type, [])
	_log("debug", "farm", "🔧", "Added persistent gate '%s' to plot %s (linked: %d plots)" % [gate_type, grid_position, linked_plots.size()])


func clear_persistent_gates() -> void:
	"""Remove ALL persistent gate infrastructure from this plot."""
	var count = persistent_gates.size()
	_set_infra_field("persistent_gates", [])
	if count > 0:
		_log("debug", "farm", "🔧", "Cleared %d persistent gates from plot %s" % [count, grid_position])


func has_active_gate(gate_type: String) -> bool:
	"""Check if this plot has an active gate of the specified type."""
	for gate in persistent_gates:
		if gate.get("type", "") == gate_type and gate.get("active", false):
			return true
	return false


func get_active_gates() -> Array[Dictionary]:
	"""Get all active persistent gates on this plot."""
	var active: Array[Dictionary] = []
	for gate in persistent_gates:
		if gate.get("active", false):
			active.append(gate)
	return active
