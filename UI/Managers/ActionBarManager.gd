class_name ActionBarManager
extends RefCounted

## ActionBarManager - Creates and manages the bottom action toolbars
##
## This manager creates ToolSelectionRow and ActionPreviewRow directly in
## ActionBarLayer. NO REPARENTING - nodes are created in their final parent.
##
## Layout: Delegates sizing to UILayoutManager for consistent responsive behavior.

const InstrumentLocator = preload("res://Core/Instrumentation/InstrumentLocator.gd")
const VerboseHelper = preload("res://Core/Config/VerboseHelper.gd")
const ToolSelectionRow = preload("res://UI/Widgets/ToolSelectionRow.gd")
const ActionPreviewRow = preload("res://UI/Widgets/ActionPreviewRow.gd")
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")

var tool_selection_row: Control = null
var action_preview_row: Control = null
var layout_manager: Node = null  # UILayoutManager reference for responsive sizing


func set_layout_manager(manager: Node) -> void:
	"""Set the UILayoutManager reference for responsive sizing.

	Args:
		manager: UILayoutManager instance
	"""
	layout_manager = manager
	if layout_manager and layout_manager.has_signal("layout_changed"):
		InstrumentLocator.safe_connect(layout_manager.layout_changed, _on_layout_changed)


func _on_layout_changed(_data: Dictionary) -> void:
	"""Handle layout_changed signal from UILayoutManager.

	Repositions action bars when viewport or scale changes.
	"""
	if tool_selection_row and tool_selection_row.is_inside_tree():
		_position_tool_row()
	if action_preview_row and action_preview_row.is_inside_tree():
		_position_action_row()


func create_action_bars(parent: Control) -> void:
	"""Create action bars directly in parent (ActionBarLayer)

	Args:
		parent: The ActionBarLayer Control node

	GODOT 4 APPROACH: Connect to parent's resized signal for proper layout timing
	"""
	if not parent:
		push_error("ActionBarManager: parent is null!")
		return

	if not parent.is_inside_tree():
		push_error("ActionBarManager: parent not in scene tree!")
		return
	if not layout_manager or not layout_manager.has_method("get_action_row_height"):
		push_error("ActionBarManager: UILayoutManager is required before creating action bars")
		return

	# Create ToolSelectionRow (1-6 buttons)
	tool_selection_row = ToolSelectionRow.new()
	if not tool_selection_row:
		push_error("ActionBarManager: Failed to create ToolSelectionRow!")
		return
	tool_selection_row.name = "ToolSelectionRow"
	parent.add_child(tool_selection_row)

	# Create ActionPreviewRow (QERF buttons)
	action_preview_row = ActionPreviewRow.new()
	if not action_preview_row:
		push_error("ActionBarManager: Failed to create ActionPreviewRow!")
		return
	action_preview_row.name = "ActionPreviewRow"
	parent.add_child(action_preview_row)

	# GODOT 4 BEST PRACTICE: Connect to parent's resized signal
	# This is the CORRECT way to handle anchor-based positioning
	InstrumentLocator.safe_connect(parent.resized, _on_parent_resized)

	# Also position immediately in case parent already has size
	_on_parent_resized()

	# Initialize action bars to show current frame from ToolConfig (single source of truth)
	var initial_frame := ToolConfig.get_current_frame()
	select_frame(initial_frame)
	VerboseHelper.debug("ui", "toolbar", "ActionBarManager initialized with frame %s" % initial_frame)


func _on_parent_resized() -> void:
	"""Called when ActionBarLayer is resized - positions action bars"""
	if tool_selection_row and tool_selection_row.is_inside_tree():
		_position_tool_row()
	if action_preview_row and action_preview_row.is_inside_tree():
		_position_action_row()


func _position_tool_row() -> void:
	"""Position ToolSelectionRow at bottom, above ActionPreviewRow"""
	if not tool_selection_row:
		return

	var parent = tool_selection_row.get_parent()
	if not parent or parent.size.x <= 0:
		# Parent not sized yet, skip (will be called again on resize)
		return

	# GODOT 4: Set layout_mode first (1 = anchors, 2 = container child)
	tool_selection_row.layout_mode = 1

	# Use anchors for bottom-wide positioning
	tool_selection_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)

	# RESPONSIVE: Delegate sizing to UILayoutManager (single source of truth)
	var action_row_height = layout_manager.get_action_row_height()
	var tool_row_height = action_row_height

	# Position tool row above action row (reduced margins for more button space)
	tool_selection_row.offset_top = -(action_row_height + tool_row_height)
	tool_selection_row.offset_bottom = -action_row_height
	tool_selection_row.offset_left = 10
	tool_selection_row.offset_right = -10

	# Ensure proper sizing
	tool_selection_row.custom_minimum_size = Vector2(0, tool_row_height)


func _position_action_row() -> void:
	"""Position ActionPreviewRow at the very bottom"""
	if not action_preview_row:
		return

	var parent = action_preview_row.get_parent()
	if not parent or parent.size.x <= 0:
		# Parent not sized yet, skip (will be called again on resize)
		return

	# GODOT 4: Set layout_mode first (1 = anchors, 2 = container child)
	action_preview_row.layout_mode = 1

	# Use anchors for bottom-wide positioning
	action_preview_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)

	# RESPONSIVE: Delegate sizing to UILayoutManager (single source of truth)
	var action_row_height = layout_manager.get_action_row_height()

	# Position at very bottom (reduced margins for more button space)
	action_preview_row.offset_top = -action_row_height
	action_preview_row.offset_bottom = 0
	action_preview_row.offset_left = 10
	action_preview_row.offset_right = -10

	# Ensure proper sizing
	action_preview_row.custom_minimum_size = Vector2(0, action_row_height)


func get_tool_row() -> Control:
	return tool_selection_row


func get_action_row() -> Control:
	return action_preview_row


func select_frame(frame_name: String) -> void:
	"""Update archetype frame selection display."""
	if tool_selection_row and tool_selection_row.has_method("select_frame"):
		tool_selection_row.select_frame(frame_name)


func select_tool(_tool_num: int) -> void:
	pass  # Retired — call select_frame(String) directly.

func render_action_projection(projection: Dictionary) -> void:
	"""Render the projected Q/E/R/F action state."""
	if action_preview_row and action_preview_row.has_method("render_projection"):
		action_preview_row.render_projection(projection)
	else:
		push_error("ActionBarManager: action_preview_row is null or doesn't have render_projection method!")
