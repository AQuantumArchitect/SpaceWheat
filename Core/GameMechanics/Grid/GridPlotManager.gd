class_name GridPlotManager
extends RefCounted

## GridPlotManager - Plot lifecycle and basic queries
##
## Extracted from FarmGrid.gd as part of decomposition.
## Handles plot creation, lookup, validity checks, and neighbor queries.

const FarmPlot = preload("res://Core/GameMechanics/FarmPlot.gd")

# Grid configuration
var grid_width: int = 5
var grid_height: int = 5

# Plot storage
var plots: Dictionary = {}  # Vector2i -> FarmPlot (or subclasses)

# External references (injected)
var faction_territory_manager = null
var _verbose = null


func _init(width: int = 5, height: int = 5):
	grid_width = width
	grid_height = height


func set_verbose(verbose_ref) -> void:
	"""Set verbose logger reference."""
	_verbose = verbose_ref


func initialize_all_plots() -> void:
	"""Pre-initialize all plots in the grid for headless testing compatibility.
	Without this, the plots dictionary is only populated on-demand via get_plot(),
	causing tests that check plots.size() to fail."""
	for y in range(grid_height):
		for x in range(grid_width):
			var pos = Vector2i(x, y)
			if not plots.has(pos):
				var plot = FarmPlot.new()
				plot.plot_id = "plot_%d_%d" % [x, y]
				plot.grid_position = pos
				plots[pos] = plot
				if faction_territory_manager:
					faction_territory_manager.register_plot(pos)


func get_plot(position: Vector2i) -> FarmPlot:
	"""Get or create plot at position (returns FarmPlot or subclass)"""
	if not is_valid_position(position):
		return null

	if not plots.has(position):
		var plot = FarmPlot.new()
		plot.plot_id = "plot_%d_%d" % [position.x, position.y]
		plot.grid_position = position
		plots[position] = plot

		# Register with faction territory manager
		if faction_territory_manager:
			faction_territory_manager.register_plot(position)

	return plots[position]


func is_valid_position(position: Vector2i) -> bool:
	"""Check if position is within grid bounds"""
	return (position.x >= 0 and position.x < grid_width and
			position.y >= 0 and position.y < grid_height)


func find_plot_by_id(plot_id: String) -> Vector2i:
	"""Find grid position of a plot by its ID"""
	for y in range(grid_height):
		for x in range(grid_width):
			var pos = Vector2i(x, y)
			var plot = get_plot(pos)
			if plot and plot.plot_id == plot_id:
				return pos
	return Vector2i(-1, -1)


func get_plot_by_id(plot_id: String) -> FarmPlot:
	"""Get plot directly by ID (convenience wrapper for cluster operations)"""
	var pos = find_plot_by_id(plot_id)
	if pos != Vector2i(-1, -1):
		return get_plot(pos)
	return null


func is_plot_empty(position: Vector2i) -> bool:
	"""Check if plot is empty (not planted)"""
	var plot = get_plot(position)
	return plot != null and not plot.is_planted


func is_plot_mature(position: Vector2i) -> bool:
	"""Check if plot has planted wheat (quantum-only: instant full size)"""
	var plot = get_plot(position)
	return plot != null and plot.is_planted


func get_neighbors(position: Vector2i) -> Array[Vector2i]:
	"""Get valid neighbor positions (4-directional)"""
	var neighbors: Array[Vector2i] = []

	var directions = [
		Vector2i(0, -1),  # Up
		Vector2i(1, 0),   # Right
		Vector2i(0, 1),   # Down
		Vector2i(-1, 0)   # Left
	]

	for dir in directions:
		var neighbor_pos = position + dir
		if is_valid_position(neighbor_pos):
			neighbors.append(neighbor_pos)

	return neighbors


func get_all_planted_positions() -> Array[Vector2i]:
	"""Get positions of all planted plots"""
	var planted: Array[Vector2i] = []
	for position in plots.keys():
		if plots[position].is_planted:
			planted.append(position)
	return planted


func get_all_mature_positions() -> Array[Vector2i]:
	"""Get positions of all mature plots"""
	var mature: Array[Vector2i] = []
	for position in plots.keys():
		if plots[position].is_planted:  # Quantum-only: all planted plots are "mature"
			mature.append(position)
	return mature


func get_grid_stats() -> Dictionary:
	"""Get current grid statistics"""
	var planted_count = 0
	var mature_count = 0
	var entanglement_count = 0

	for plot in plots.values():
		if plot.is_planted:
			planted_count += 1
			mature_count += 1  # Quantum-only: all planted = mature
		entanglement_count += plot.get_entanglement_count()

	# Each entanglement is counted twice (bidirectional)
	entanglement_count /= 2

	return {
		"total_plots": plots.size(),
		"planted": planted_count,
		"mature": mature_count,
		"entanglements": entanglement_count
	}


func print_grid_state() -> void:
	"""Debug: Print current grid state"""
	if _verbose:
		_verbose.debug("farm", "=", "FARM GRID STATE")
		var stats = get_grid_stats()
		_verbose.debug("farm", "📊", "Plots: %d | Planted: %d | Mature: %d | Entangled: %d" % [
			stats["total_plots"],
			stats["planted"],
			stats["mature"],
			stats["entanglements"]
		])

		for y in range(grid_height):
			var row = ""
			for x in range(grid_width):
				var pos = Vector2i(x, y)
				var plot = plots.get(pos)

				if plot == null or not plot.is_planted:
					row += "[ ]"
				else:
					# Quantum-only: all planted plots shown as [M]
					row += "[M]"

			_verbose.debug("farm", "🌾", row)

		_verbose.debug("farm", "=", "Grid state complete")
