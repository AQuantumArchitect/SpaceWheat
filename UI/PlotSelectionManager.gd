## PlotSelectionManager.gd
## Manages multi-plot selection state for batch operations
##
## Features:
## - Toggle plots on/off in selection
## - Save/restore selection state (for ] key undo)
## - Query selection state
## - Persistent selection until explicitly deselected

class_name PlotSelectionManager
extends RefCounted

## Currently selected plots
var selected_plots: Array[Vector2i] = []

## Previous selection state (for ] key restoration)
var previous_state: Array[Vector2i] = []

## Signal emitted when selection changes
signal selection_changed(selected_plots: Array[Vector2i], count: int)


## Toggle a plot's selection state
## Returns: true if plot is now selected, false if deselected
func toggle_plot(pos: Vector2i) -> bool:
	if pos in selected_plots:
		# Remove from selection
		selected_plots.erase(pos)
		emit_signal("selection_changed", selected_plots.duplicate(), selected_plots.size())
		return false
	else:
		# Add to selection
		selected_plots.append(pos)
		emit_signal("selection_changed", selected_plots.duplicate(), selected_plots.size())
		return true


## Check if a plot is currently selected
func is_selected(pos: Vector2i) -> bool:
	return pos in selected_plots


## Get copy of all selected plots
func get_selected() -> Array[Vector2i]:
	return selected_plots.duplicate()


## Get number of selected plots
func get_count() -> int:
	return selected_plots.size()


## Save current selection to previous_state (for [ key restoration)
func save_state() -> void:
	previous_state = selected_plots.duplicate()
	print("💾 Selection saved: %d plots" % previous_state.size())


## Deselect all plots
func clear_selection() -> void:
	if selected_plots.is_empty():
		return

	selected_plots.clear()
	emit_signal("selection_changed", selected_plots.duplicate(), 0)
	print("❌ All plots deselected")


## Restore selection from previous_state
func restore_state() -> void:
	if previous_state.is_empty():
		print("⚠️  No previous selection to restore")
		return

	selected_plots = previous_state.duplicate()
	emit_signal("selection_changed", selected_plots.duplicate(), selected_plots.size())
	print("↩️  Selection restored: %d plots" % selected_plots.size())


## Get index of a plot in selection (for ordered operations)
## Returns -1 if not selected
func get_index(pos: Vector2i) -> int:
	return selected_plots.find(pos)


## Select specific plots (replaces current selection)
## Used for saved/loaded selection states
func set_selection(positions: Array[Vector2i]) -> void:
	selected_plots = positions.duplicate()
	emit_signal("selection_changed", selected_plots.duplicate(), selected_plots.size())
	print("🎯 Selection set: %d plots" % selected_plots.size())


## Debug output
func _to_string() -> String:
	if selected_plots.is_empty():
		return "PlotSelectionManager: 0 plots selected"

	var positions_str = ", ".join(selected_plots.map(func(p): return "[%d,%d]" % [p.x, p.y]))
	return "PlotSelectionManager: %d plots selected: %s" % [selected_plots.size(), positions_str]
