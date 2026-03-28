class_name FarmGrid
extends Node

## FarmGrid - Orchestrator for farm grid management (Decomposed)
##
## This is a FACADE that delegates to focused components:
## - GridPlotManager: Plot lifecycle and queries
## - BiomeRoutingManager: Multi-biome registry and routing
## - EntanglementManager: Quantum entanglement operations
## - PlantingManager: (removed) legacy planting system
## - HarvestMeasurementManager: Harvest and measurement operations
##
## FarmGrid is now primarily the routing surface where plots, terminals,
## registers, and biome ownership meet.

# Access autoload safely (avoids compile-time errors)
@onready var _verbose = get_node("/root/VerboseConfig")

# ═══════════════════════════════════════════════════════════════════════════════
# SIGNALS (unchanged API)
# ═══════════════════════════════════════════════════════════════════════════════

# Internal signals (for FarmGrid-level operations)
signal plot_planted(position: Vector2i)
signal plot_harvested(position: Vector2i, yield_data: Dictionary)

signal entanglement_created(from: Vector2i, to: Vector2i)
signal entanglement_removed(from: Vector2i, to: Vector2i)

# Generic signals for visualization and biome updates
signal plot_changed(position: Vector2i, change_type: String, details: Dictionary)
signal visualization_changed()

# ═══════════════════════════════════════════════════════════════════════════════
# COMPONENT PRELOADS
# ═══════════════════════════════════════════════════════════════════════════════

const GridPlotManager = preload("res://Core/GameMechanics/Grid/GridPlotManager.gd")
const BiomeRoutingManager = preload("res://Core/GameMechanics/Grid/BiomeRoutingManager.gd")
const EntanglementManager = preload("res://Core/GameMechanics/Grid/EntanglementManager.gd")
const HarvestMeasurementManager = preload("res://Core/GameMechanics/Grid/HarvestMeasurementManager.gd")

const FarmPlot = preload("res://Core/GameMechanics/FarmPlot.gd")
const Icon = preload("res://Core/QuantumSubstrate/Icon.gd")

# ═══════════════════════════════════════════════════════════════════════════════
# COMPONENTS (internal)
# ═══════════════════════════════════════════════════════════════════════════════

var _plot_manager: GridPlotManager
var _biome_routing: BiomeRoutingManager
var _entanglement: EntanglementManager
var _harvest: HarvestMeasurementManager

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION & STATE (preserved for backward compatibility)
# ═══════════════════════════════════════════════════════════════════════════════

# Grid configuration
@export var grid_width: int = 5
@export var grid_height: int = 5

# External references (injected by Farm.gd)
var conspiracy_network = null
var faction_territory_manager = null
var farm_economy = null
var vocabulary_evolution = null
var terminal_pool = null

# Environmental parameters
var base_temperature: float = 20.0
var active_icons: Array = []
var icon_scopes: Dictionary = {}  # Icon → Array[String]

# ═══════════════════════════════════════════════════════════════════════════════
# FACADE ACCESSORS (for direct access when needed)
# ═══════════════════════════════════════════════════════════════════════════════

## Direct access to plots dictionary (for backward compatibility)
var plots: Dictionary:
	get:
		return _plot_manager.plots if _plot_manager else {}

## Direct access to biomes dictionary
var biomes: Dictionary:
	get:
		return _biome_routing.biomes if _biome_routing else {}

## Direct access to plot_biome_assignments
var plot_biome_assignments: Dictionary:
	get:
		return _biome_routing.plot_biome_assignments if _biome_routing else {}

## Direct access to entangled_pairs
var entangled_pairs: Array:
	get:
		return _entanglement.entangled_pairs if _entanglement else []

## Direct access to entangled_clusters
var entangled_clusters: Array:
	get:
		return _entanglement.entangled_clusters if _entanglement else []

# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _init(width: int = 6, height: int = 4):
	# Set dimensions BEFORE creating GridPlotManager
	grid_width = width
	grid_height = height

	# Create components EARLY so they're available before _ready()
	# This fixes initialization order issues where Farm._ready() calls
	# register_biome() before FarmGrid._ready() runs.
	_plot_manager = GridPlotManager.new(grid_width, grid_height)
	_biome_routing = BiomeRoutingManager.new()
	_entanglement = EntanglementManager.new()
	_harvest = HarvestMeasurementManager.new()


func resize_grid(new_width: int, new_height: int) -> void:
	"""Resize grid dimensions and update internal managers (expansion only)."""
	if new_width <= 0 or new_height <= 0:
		push_error("FarmGrid.resize_grid(): invalid size %dx%d" % [new_width, new_height])
		return
	if new_width == grid_width and new_height == grid_height:
		return

	grid_width = new_width
	grid_height = new_height

	if _plot_manager:
		_plot_manager.grid_width = new_width
		_plot_manager.grid_height = new_height
		_plot_manager.initialize_all_plots()

	if _verbose:
		_verbose.info("farm", "📐", "FarmGrid resized: %dx%d (%d plots)" % [
			grid_width, grid_height, grid_width * grid_height
		])


func _ready():
	_verbose.info("farm", "🌾", "FarmGrid initialized: %dx%d = %d plots" % [grid_width, grid_height, grid_width * grid_height])

	# Wire verbose logger to all components (requires @onready _verbose)
	_plot_manager.set_verbose(_verbose)
	_biome_routing.set_verbose(_verbose)
	_biome_routing.set_plot_manager(_plot_manager)
	if terminal_pool:
		_biome_routing.set_terminal_pool(terminal_pool)
	_entanglement.set_verbose(_verbose)
	_harvest.set_verbose(_verbose)

	# Wire component dependencies
	_entanglement.set_dependencies(_plot_manager, _biome_routing)
	_harvest.set_dependencies(_plot_manager, _biome_routing, farm_economy, _entanglement, terminal_pool, null)

	# Wire external references
	_plot_manager.faction_territory_manager = faction_territory_manager

	# Forward signals from components
	_entanglement.entanglement_created.connect(func(a, b): entanglement_created.emit(a, b))
	_entanglement.entanglement_removed.connect(func(a, b): entanglement_removed.emit(a, b))

	_harvest.plot_harvested.connect(func(pos, data): plot_harvested.emit(pos, data))
	_harvest.plot_changed.connect(func(pos, t, d): plot_changed.emit(pos, t, d))
	_harvest.visualization_changed.connect(func(): visualization_changed.emit())

	# Pre-initialize all plots
	_plot_manager.initialize_all_plots()

	if _biome_routing.is_biomes_empty():
		_verbose.info("farm", "ℹ️", "No biomes registered")

	set_process(true)


func _process(delta):
	if _biome_routing.is_biomes_empty():
		return

	# Build icon_network for growth modifiers
	var icon_network = _build_icon_network()

	# Grow all planted plots
	for position in _plot_manager.plots.keys():
		var plot = _plot_manager.plots[position]
		if plot.is_active():
			var plot_biome = _biome_routing.get_biome_for_plot(position)
			plot.grow(delta, plot_biome, faction_territory_manager, icon_network, conspiracy_network)


# ═══════════════════════════════════════════════════════════════════════════════
# MULTI-BIOME REGISTRY (delegates to BiomeRoutingManager)
# ═══════════════════════════════════════════════════════════════════════════════

func register_biome(biome_name: String, biome_instance) -> void:
	"""Register a biome in the grid's biome registry"""
	_biome_routing.register_biome(biome_name, biome_instance)


func assign_plot_to_biome(position: Vector2i, biome_name: String) -> bool:
	"""Assign a specific plot to a biome (graceful - skips unregistered biomes)

	Returns true if assigned, false if biome not registered or invalid position.
	"""
	if not _plot_manager.is_valid_position(position):
		push_error("Cannot assign plot at invalid position: %s" % position)
		return false
	return _biome_routing.assign_plot_to_biome(position, biome_name)


func set_terminal_pool(pool) -> void:
	"""Inject TerminalPool for terminal-based register resolution."""
	terminal_pool = pool
	if _biome_routing:
		_biome_routing.set_terminal_pool(pool)
	if _harvest:
		_harvest.set_dependencies(_plot_manager, _biome_routing, farm_economy, _entanglement, terminal_pool, null)


func get_biome_for_plot(position: Vector2i):
	"""Get the biome responsible for a specific plot"""
	return _biome_routing.get_biome_for_plot(position)


# ═══════════════════════════════════════════════════════════════════════════════
# PLOT MANAGEMENT (delegates to GridPlotManager)
# ═══════════════════════════════════════════════════════════════════════════════

func get_plot(position: Vector2i) -> FarmPlot:
	"""Get or create plot at position"""
	return _plot_manager.get_plot(position)


func is_valid_position(position: Vector2i) -> bool:
	"""Check if position is within grid bounds"""
	return _plot_manager.is_valid_position(position)


func _find_plot_by_id(plot_id: String) -> Vector2i:
	"""Find grid position of a plot by its ID"""
	return _plot_manager.find_plot_by_id(plot_id)


func is_plot_empty(position: Vector2i) -> bool:
	"""Check if plot is empty (not planted)"""
	return _plot_manager.is_plot_empty(position)


func is_plot_mature(position: Vector2i) -> bool:
	"""Check if plot has planted wheat"""
	return _plot_manager.is_plot_mature(position)


func get_neighbors(position: Vector2i) -> Array[Vector2i]:
	"""Get valid neighbor positions (4-directional)"""
	return _plot_manager.get_neighbors(position)


func get_all_planted_positions() -> Array[Vector2i]:
	"""Get positions of all planted plots"""
	return _plot_manager.get_all_planted_positions()


func get_all_mature_positions() -> Array[Vector2i]:
	"""Get positions of all mature plots"""
	return _plot_manager.get_all_mature_positions()


func get_grid_stats() -> Dictionary:
	"""Get current grid statistics"""
	return _plot_manager.get_grid_stats()


func print_grid_state():
	"""Debug: Print current grid state"""
	_plot_manager.print_grid_state()


# ═══════════════════════════════════════════════════════════════════════════════
# HARVEST & MEASUREMENT (delegates to HarvestMeasurementManager)
# ═══════════════════════════════════════════════════════════════════════════════

func harvest_wheat(position: Vector2i) -> Dictionary:
	"""Harvest wheat at position"""
	# Ensure economy is wired
	if farm_economy and not _harvest._economy:
		_harvest.set_dependencies(_plot_manager, _biome_routing, farm_economy, _entanglement, terminal_pool, null)
	elif terminal_pool and not _harvest._terminal_pool:
		_harvest.set_dependencies(_plot_manager, _biome_routing, farm_economy, _entanglement, terminal_pool, null)
	return _harvest.harvest_wheat(position)


func measure_plot(position: Vector2i) -> String:
	"""Measure quantum state (observer effect)"""
	return _harvest.measure_plot(position)


# ═══════════════════════════════════════════════════════════════════════════════
# ENTANGLEMENT (delegates to EntanglementManager)
# ═══════════════════════════════════════════════════════════════════════════════

func create_entanglement(pos_a: Vector2i, pos_b: Vector2i, bell_type: String = "phi_plus") -> bool:
	"""Create entanglement between two plots"""
	var result = _entanglement.create_entanglement(pos_a, pos_b, bell_type)
	if result:
		plot_changed.emit(pos_a, "entangled", {"partner": pos_b})
		plot_changed.emit(pos_b, "entangled", {"partner": pos_a})
		visualization_changed.emit()
	return result


func create_triplet_entanglement(pos_a: Vector2i, pos_b: Vector2i, pos_c: Vector2i) -> bool:
	"""Create triple entanglement (3-qubit Bell state)"""
	return _entanglement.create_triplet_entanglement(pos_a, pos_b, pos_c)


func remove_entanglement(pos_a: Vector2i, pos_b: Vector2i):
	"""Remove entanglement between two plots"""
	_entanglement.remove_entanglement(pos_a, pos_b)


func are_plots_entangled(pos_a: Vector2i, pos_b: Vector2i) -> bool:
	"""Check if two plots are entangled"""
	return _entanglement.are_plots_entangled(pos_a, pos_b)


# ═══════════════════════════════════════════════════════════════════════════════
# ICON MANAGEMENT (kept in FarmGrid)
# ═══════════════════════════════════════════════════════════════════════════════

func _build_icon_network() -> Dictionary:
	"""Build icon_network dictionary from active_icons array"""
	var icon_network = {}

	for icon in active_icons:
		if icon.icon_emoji == "🌾":  # Biotic Flux
			icon_network["biotic"] = icon
		elif icon.icon_emoji == "🍅":  # Chaos Vortex
			icon_network["chaos"] = icon
		elif icon.icon_emoji == "🏰":  # Imperium/Carrion Throne
			icon_network["imperium"] = icon

	return icon_network


# ═══════════════════════════════════════════════════════════════════════════════
# REGISTER MANAGEMENT (terminal-based)
# ═══════════════════════════════════════════════════════════════════════════════

func get_register_for_plot(position: Vector2i) -> int:
	"""Get the RegisterId for a plot via terminal binding."""
	return _biome_routing.get_register_for_plot(position)
