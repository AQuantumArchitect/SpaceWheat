class_name GridConfig
extends Resource

## GridConfig - Single source of truth for grid layout and configuration
## Replaces scattered hardcoded grid dimensions across 5+ files
## Provides validation to catch configuration errors early

# Preload config classes

@export var grid_width: int = 6
@export var grid_height: int = 2
@export var plots: Array[PlotConfig] = []
@export var keyboard_layout: KeyboardLayoutConfig = null
@export var biome_assignments: Dictionary = {}  # Vector2i → biome_name


## Validate entire grid configuration for consistency
## Returns dict with "success" bool and optional "errors" array
func validate() -> Dictionary:
	var errors = []

	# Validate dimensions
	if grid_width <= 0 or grid_height <= 0:
		errors.append("Invalid grid dimensions: %dx%d (must be positive)" % [grid_width, grid_height])
		return {"success": false, "errors": errors}

	# Validate plot count
	var _expected_plot_count = grid_width * grid_height
	var active_plots = plots.filter(func(p): return p.is_active).size()
	VerboseHelper.info("farm", "grid", "GridConfig validation: %d/%d plots active" % [active_plots, plots.size()])

	# Validate plot positions
	var position_set = {}
	for plot in plots:
		if position_set.has(plot.position):
			errors.append("Duplicate plot at position %s" % plot.position)
		position_set[plot.position] = true

		if not is_position_valid(plot.position):
			errors.append("Plot at %s outside grid bounds (%dx%d)" % [plot.position, grid_width, grid_height])

	# Validate keyboard layout exists
	if not keyboard_layout:
		errors.append("KeyboardLayoutConfig not set")
		return {"success": false, "errors": errors}

	# Validate keyboard mappings point to active plots
	for action in keyboard_layout.get_all_actions():
		var pos = keyboard_layout.get_position_for_action(action)

		if pos == GridSentinel.INVALID_POSITION:
			errors.append("Invalid position for keyboard action %s" % action)
			continue

		var plot = get_plot_at(pos)
		if not plot or not plot.is_active:
			errors.append("Keyboard action %s maps to inactive plot %s" % [action, pos])

	# Validate position_to_label consistency
	for pos in keyboard_layout.position_to_label.keys():
		if not is_position_valid(pos):
			errors.append("Keyboard label position %s outside grid bounds" % pos)

	return {"success": errors.is_empty(), "errors": errors}


func is_position_valid(pos: Vector2i) -> bool:
	# Check if position is within grid bounds
	return pos.x >= 0 and pos.x < grid_width and pos.y >= 0 and pos.y < grid_height


func has_active_plot_at(pos: Vector2i) -> bool:
	# Check if there's an active plot at this position
	var plot = get_plot_at(pos)
	return plot != null and plot.is_active


func get_plot_at(pos: Vector2i):
	# Get PlotConfig for a position (returns null if no plot or inactive)
	for plot in plots:
		if plot.position == pos:
			return plot
	return null


func get_all_active_plots() -> Array[PlotConfig]:
	# Get all active plots in grid order
	var active = plots.filter(func(p): return p.is_active)
	# Sort by position: y-major (rows), then x-major (columns)
	active.sort_custom(func(a, b):
		if a.position.y != b.position.y:
			return a.position.y < b.position.y
		return a.position.x < b.position.x
	)
	return active


func get_biome_for_plot(pos: Vector2i) -> String:
	# Get biome name assigned to a plot position
	return biome_assignments.get(pos, "")


func print_summary() -> void:
	# Print human-readable summary of configuration
	VerboseHelper.info("farm", "grid", "GridConfig Summary")
	VerboseHelper.info("farm", "grid", "Grid size: %dx%d (%d total plots)" % [grid_width, grid_height, grid_width * grid_height])
	VerboseHelper.info("farm", "grid", "Keyboard Layout:")

	# Group by row
	var by_row = {}
	for action in keyboard_layout.get_all_actions():
		var pos = keyboard_layout.get_position_for_action(action)
		var label = keyboard_layout.get_label_for_position(pos)
		if not by_row.has(pos.y):
			by_row[pos.y] = []
		by_row[pos.y].append({"action": action, "pos": pos, "label": label})

	var row_keys = by_row.keys() as Array
	row_keys.sort()
	for row in row_keys:
		var row_items = by_row[row]
		row_items.sort_custom(func(a, b): return a.pos.x < b.pos.x)
		var labels = row_items.map(func(item): return item.label).join("/")
		VerboseHelper.info("farm", "grid", "Row %d: %s" % [row, labels])

	VerboseHelper.info("farm", "grid", "Plot Assignments:")
	var plot_summary = {}
	for plot in get_all_active_plots():
		var biome = get_biome_for_plot(plot.position)
		if not plot_summary.has(biome):
			plot_summary[biome] = []
		plot_summary[biome].append(plot.keyboard_label)

	var biome_keys = plot_summary.keys() as Array
	biome_keys.sort()
	for biome in biome_keys:
		var labels = plot_summary[biome] as Array
		labels.sort()
		VerboseHelper.info("farm", "grid", "%s: %s" % [biome, ", ".join(labels)])
