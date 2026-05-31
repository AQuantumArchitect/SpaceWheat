class_name BiomeRoutingManager
extends RefCounted


## BiomeRoutingManager - Multi-biome registry and quantum computer routing
##
## Extracted from FarmGrid.gd as part of decomposition.
## Handles biome registration, plot-to-biome assignment, and quantum computer access.

# Multi-biome registry
var biomes: Dictionary = {}  # String → BiomeBase (registry of all biomes)
var plot_biome_assignments: Dictionary = {}  # Vector2i → String (plot position → biome name)

# Terminal pool for terminal-based register lookup when plot.terminal is absent.
var terminal_pool = null

# Plot manager for plot-based register lookups
var _plot_manager = null

# External references
var _verbose = null


func set_verbose(verbose_ref) -> void:
	# Set verbose logger reference.
	_verbose = verbose_ref


func set_terminal_pool(pool) -> void:
	# Inject TerminalPool for register resolution.
	terminal_pool = pool


func set_plot_manager(pm) -> void:
	# Inject GridPlotManager for plot-based register lookups.
	_plot_manager = pm


func register_biome(biome_name: String, biome_instance) -> void:
	# Register a biome in the grid's biome registry

	# Called by Farm._ready() during initialization.
	# Enables the grid to route plot operations to the correct biome.
	if not biome_name or not biome_instance:
		push_error("Cannot register biome: invalid name or instance")
		return

	biomes[biome_name] = biome_instance
	if _verbose:
		_verbose.info("biome", "📍", "Biome registered: %s" % biome_name)


func unregister_biome(biome_name: String) -> void:
	# Remove a biome from the registry and clear all of its plot assignments.
	if biome_name == "":
		return

	biomes.erase(biome_name)

	var to_clear: Array[Vector2i] = []
	for key in plot_biome_assignments.keys():
		if str(plot_biome_assignments.get(key, "")) != biome_name:
			continue
		if key is Vector2i:
			to_clear.append(key)
		elif key is Vector2:
			to_clear.append(Vector2i(int((key as Vector2).x), int((key as Vector2).y)))

	for pos in to_clear:
		plot_biome_assignments.erase(pos)

	if _verbose:
		_verbose.info("biome", "🧹", "Biome unregistered: %s" % biome_name)


func assign_plot_to_biome(position: Vector2i, biome_name: String) -> bool:
	# Assign a specific plot to a biome (graceful - skips unregistered biomes)

	# Called by Farm._ready() during initialization.
	# Configures which biome manages each plot's quantum evolution.

	# Returns true if assigned, false if biome not registered (deferred).
	# Graceful handling: unregistered biomes are skipped without error,
	# allowing plots to be assigned retroactively when biomes are explored.
	if not biomes.has(biome_name):
		# GRACEFUL: Biome may be locked/not-yet-loaded - defer assignment
		return false

	plot_biome_assignments[position] = biome_name
	return true


func get_biome_for_plot(position: Vector2i):
	# Get the biome responsible for a specific plot

	# Returns the biome instance for the given plot position.
	# Check if plot has explicit assignment
	if plot_biome_assignments.has(position):
		var biome_name = plot_biome_assignments[position]
		if biomes.has(biome_name):
			return biomes[biome_name]

	return null


func get_biome_id_for_plot(position: Vector2i) -> String:
	# Get the biome ID (name) for a plot position.
	return plot_biome_assignments.get(position, "")


func has_biome(biome_name: String) -> bool:
	return biomes.has(biome_name)


func get_biome(biome_name: String):
	return biomes.get(biome_name, null)


func get_biome_names() -> Array:
	var names = biomes.keys()
	names.sort()
	return names


func get_plot_biome_assignments() -> Dictionary:
	return plot_biome_assignments


func set_plot_biome_assignment(position: Vector2i, biome_name: String) -> bool:
	if biome_name == "":
		clear_plot_biome_assignment(position)
		return true
	if not biomes.has(biome_name):
		return false
	plot_biome_assignments[position] = biome_name
	return true


func clear_plot_biome_assignment(position: Vector2i) -> void:
	plot_biome_assignments.erase(position)


func get_plot_positions_for_biome(biome_name: String) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for key in plot_biome_assignments.keys():
		if str(plot_biome_assignments.get(key, "")) != biome_name:
			continue
		if key is Vector2i:
			positions.append(key)
		elif key is Vector2:
			positions.append(Vector2i(int((key as Vector2).x), int((key as Vector2).y)))
	positions.sort_custom(func(a, b) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)
	return positions


func get_register_for_plot(position: Vector2i) -> int:
	# Get the RegisterId for a plot.

	# Returns: Register ID (int) if plot is planted, -1 if not found
	if _plot_manager:
		var plot = _plot_manager.get_plot(position)
		if plot and plot.is_active():
			return plot.bound_register_id
	return -1


func get_plot_for_register(register_id: int) -> Vector2i:
	# Reverse lookup: find the grid position bound to a register ID.

	# Returns: Grid position if found, GridSentinel.INVALID_POSITION if not found
	if _plot_manager:
		for pos in _plot_manager.plots.keys():
			var plot = _plot_manager.plots[pos]
			if plot.is_active() and plot.bound_register_id == register_id:
				return pos
	return GridSentinel.INVALID_POSITION


func is_biomes_empty() -> bool:
	# Check if no biomes are registered.
	return biomes.is_empty()


func get_all_biomes() -> Dictionary:
	# Get all registered biomes.
	return biomes
