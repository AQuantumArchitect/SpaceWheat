class_name FarmGrid
extends Node

## FarmGrid - Routing surface for plots, terminals, registers, and biome ownership
##
## This delegates to focused components:
## - GridPlotManager: Plot lifecycle and queries
## - BiomeRoutingManager: Multi-biome registry and routing
## - EntanglementManager: Quantum entanglement operations

# Access autoload safely (avoids compile-time errors)
@onready var _verbose = get_node_or_null("/root/VerboseConfig")

# ═══════════════════════════════════════════════════════════════════════════════
# SIGNALS (unchanged API)
# ═══════════════════════════════════════════════════════════════════════════════

# Internal signals (for FarmGrid-level operations)
signal entanglement_created(from: Vector2i, to: Vector2i)
signal entanglement_removed(from: Vector2i, to: Vector2i)

# Generic signals for visualization and biome updates
signal plot_changed(grid_pos: Vector2i, change_type: String, details: Dictionary)
signal visualization_changed()

# ═══════════════════════════════════════════════════════════════════════════════
# COMPONENT PRELOADS
# ═══════════════════════════════════════════════════════════════════════════════



# ═══════════════════════════════════════════════════════════════════════════════
# COMPONENTS (internal)
# ═══════════════════════════════════════════════════════════════════════════════

var _plot_manager: GridPlotManager
var _biome_routing: BiomeRoutingManager
var _entanglement: EntanglementManager

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION & STATE
# ═══════════════════════════════════════════════════════════════════════════════

# Grid configuration
@export var grid_width: int = 5
@export var grid_height: int = 5

# External references (injected by Farm.gd)
var farm_economy = null
var terminal_pool = null

# ═══════════════════════════════════════════════════════════════════════════════
# FACADE ACCESSORS
# ═══════════════════════════════════════════════════════════════════════════════

var plots: Dictionary:
	get:
		return _plot_manager.plots if _plot_manager else {}

var biomes: Dictionary:
	get:
		return _biome_routing.biomes if _biome_routing else {}

var plot_biome_assignments: Dictionary:
	get:
		return _biome_routing.plot_biome_assignments if _biome_routing else {}

var entangled_pairs: Array:
	get:
		return _entanglement.entangled_pairs if _entanglement else []

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


func resize_grid(new_width: int, new_height: int) -> void:
	# Resize grid dimensions and update internal managers (expansion only).
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

	# Wire component dependencies
	_entanglement.set_dependencies(_plot_manager, _biome_routing)

	# Forward signals from components
	_entanglement.entanglement_created.connect(func(a, b): entanglement_created.emit(a, b))
	_entanglement.entanglement_removed.connect(func(a, b): entanglement_removed.emit(a, b))

	# Pre-initialize all plots
	_plot_manager.initialize_all_plots()

	if _biome_routing.is_biomes_empty():
		_verbose.info("farm", "ℹ️", "No biomes registered")

	set_process(true)


func _process(delta):
	if _biome_routing.is_biomes_empty():
		return

	# Grow all planted plots
	for grid_pos in _plot_manager.plots.keys():
		var plot = _plot_manager.plots[grid_pos]
		if plot.is_active():
			var plot_biome = _biome_routing.get_biome_for_plot(grid_pos)
			plot.grow(delta, plot_biome)


# ═══════════════════════════════════════════════════════════════════════════════
# MULTI-BIOME REGISTRY (delegates to BiomeRoutingManager)
# ═══════════════════════════════════════════════════════════════════════════════

func register_biome(biome_name: String, biome_instance) -> void:
	# Register a biome in the grid's biome registry
	_biome_routing.register_biome(biome_name, biome_instance)


func unregister_biome(biome_name: String) -> void:
	# Unregister a biome and clear its routing assignments.
	_biome_routing.unregister_biome(biome_name)


func has_biome(biome_name: String) -> bool:
	return _biome_routing.has_biome(biome_name)


func get_biome(biome_name: String):
	return _biome_routing.get_biome(biome_name)


func get_biome_names() -> Array:
	return _biome_routing.get_biome_names()


func get_all_biomes() -> Dictionary:
	return _biome_routing.get_all_biomes()


func get_all_plots() -> Dictionary:
	return _plot_manager.plots if _plot_manager else {}


func get_plot_biome_assignments() -> Dictionary:
	return _biome_routing.get_plot_biome_assignments()


func has_biomes() -> bool:
	return not _biome_routing.is_biomes_empty()


func get_biome_count() -> int:
	return _biome_routing.biomes.size()


func get_primary_biome():
	var names = get_biome_names()
	if names.is_empty():
		return null
	return get_biome(names[0])


func assign_plot_to_biome(grid_pos: Vector2i, biome_name: String) -> bool:
	# Assign a specific plot to a biome (graceful - skips unregistered biomes)

	# Returns true if assigned, false if biome not registered or invalid grid_pos.
	if not _plot_manager.is_valid_position(grid_pos):
		push_error("Cannot assign plot at invalid grid_pos: %s" % grid_pos)
		return false
	return _biome_routing.assign_plot_to_biome(grid_pos, biome_name)


func set_terminal_pool(pool) -> void:
	# Inject TerminalPool for terminal-based register resolution.
	terminal_pool = pool
	if _biome_routing:
		_biome_routing.set_terminal_pool(pool)


func get_biome_for_plot(grid_pos: Vector2i):
	# Get the biome responsible for a specific plot
	return _biome_routing.get_biome_for_plot(grid_pos)


func get_plot_biome_assignment(grid_pos: Vector2i) -> String:
	return _biome_routing.get_biome_id_for_plot(grid_pos)


func get_plot_positions_for_biome(biome_name: String) -> Array[Vector2i]:
	return _biome_routing.get_plot_positions_for_biome(biome_name)


func set_plot_biome_assignment(grid_pos: Vector2i, biome_name: String) -> bool:
	return _biome_routing.set_plot_biome_assignment(grid_pos, biome_name)


func clear_plot_biome_assignment(grid_pos: Vector2i) -> void:
	_biome_routing.clear_plot_biome_assignment(grid_pos)


# ═══════════════════════════════════════════════════════════════════════════════
# PLOT MANAGEMENT (delegates to GridPlotManager)
# ═══════════════════════════════════════════════════════════════════════════════

func get_plot(grid_pos: Vector2i) -> FarmPlot:
	# Get or create plot at grid_pos
	return _plot_manager.get_plot(grid_pos)


func get_plot_positions() -> Array:
	return _plot_manager.plots.keys()


func get_plot_count() -> int:
	return _plot_manager.plots.size()


func is_valid_position(grid_pos: Vector2i) -> bool:
	# Check if grid_pos is within grid bounds
	return _plot_manager.is_valid_position(grid_pos)


func _find_plot_by_id(plot_id: String) -> Vector2i:
	# Find grid grid_pos of a plot by its ID
	return _plot_manager.find_plot_by_id(plot_id)


func is_plot_empty(grid_pos: Vector2i) -> bool:
	# Check if plot is empty (not planted)
	return _plot_manager.is_plot_empty(grid_pos)


func is_plot_mature(grid_pos: Vector2i) -> bool:
	# Check if plot has planted wheat
	return _plot_manager.is_plot_mature(grid_pos)


func get_neighbors(grid_pos: Vector2i) -> Array[Vector2i]:
	# Get valid neighbor positions (4-directional)
	return _plot_manager.get_neighbors(grid_pos)


func get_all_planted_positions() -> Array[Vector2i]:
	# Get positions of all planted plots
	return _plot_manager.get_all_planted_positions()


func get_all_mature_positions() -> Array[Vector2i]:
	# Get positions of all mature plots
	return _plot_manager.get_all_mature_positions()


func get_grid_stats() -> Dictionary:
	# Get current grid statistics
	return _plot_manager.get_grid_stats()


func print_grid_state():
	# Debug: Print current grid state
	_plot_manager.print_grid_state()


# ═══════════════════════════════════════════════════════════════════════════════
# ENTANGLEMENT (delegates to EntanglementManager)
# ═══════════════════════════════════════════════════════════════════════════════

func create_entanglement(pos_a: Vector2i, pos_b: Vector2i, bell_type: String = "phi_plus") -> bool:
	# Create entanglement between two plots
	var result = _entanglement.create_entanglement(pos_a, pos_b, bell_type)
	if result:
		plot_changed.emit(pos_a, "entangled", {"partner": pos_b})
		plot_changed.emit(pos_b, "entangled", {"partner": pos_a})
		visualization_changed.emit()
	return result


func create_triplet_entanglement(pos_a: Vector2i, pos_b: Vector2i, pos_c: Vector2i) -> bool:
	# Create triple entanglement (3-qubit Bell state)
	return _entanglement.create_triplet_entanglement(pos_a, pos_b, pos_c)


func remove_entanglement(pos_a: Vector2i, pos_b: Vector2i):
	# Remove entanglement between two plots
	_entanglement.remove_entanglement(pos_a, pos_b)


func are_plots_entangled(pos_a: Vector2i, pos_b: Vector2i) -> bool:
	# Check if two plots are entangled
	return _entanglement.are_plots_entangled(pos_a, pos_b)


# ═══════════════════════════════════════════════════════════════════════════════
# REGISTER MANAGEMENT (terminal-based)
# ═══════════════════════════════════════════════════════════════════════════════

func get_register_for_plot(grid_pos: Vector2i) -> int:
	# Get the RegisterId for a plot via terminal binding.
	return _biome_routing.get_register_for_plot(grid_pos)
