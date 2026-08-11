class_name ActionBarManager
extends RefCounted

## ActionBarManager - Creates and manages the bottom action toolbars
##
## This coordinator creates ToolSelectionRow and ActionPreviewRow directly in
## ActionBarLayer. NO REPARENTING - nodes are created in their final parent.
##
## Layout: Delegates sizing to UILayoutManager for consistent responsive behavior.

const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")

## preload, not the bare class_name: a freshly added class_name is invisible
## until Godot re-imports, and this file must parse on a cold checkout.
const _ModeSelectionRow = preload("res://UI/Widgets/ModeSelectionRow.gd")
const _ClockSpeedRow = preload("res://UI/Widgets/ClockSpeedRow.gd")

var tool_selection_row: Control = null
var mode_selection_row: Control = null
var biome_selection_row: Control = null
var clock_speed_row: Control = null
var menu_selection_row: Control = null
var action_preview_row: Control = null
var layout_manager: Node = null  # UILayoutManager reference for responsive sizing


func set_layout_manager(layout_mgr: Node) -> void:
	# Set the UILayoutManager reference for responsive sizing.
	#
	# Args:
	# layout_mgr: UILayoutManager instance
	layout_manager = layout_mgr
	if layout_manager and layout_manager.has_signal("layout_changed"):
		InstrumentLocator._safe_connect(layout_manager.layout_changed, _on_layout_changed)


func _on_layout_changed(_data: Dictionary) -> void:
	# Handle layout_changed signal from UILayoutManager.
	#
	# Repositions action bars when viewport or scale changes.
	_reposition_all_rows()


func _reposition_all_rows() -> void:
	if tool_selection_row and tool_selection_row.is_inside_tree():
		_position_tool_row()
	if mode_selection_row and mode_selection_row.is_inside_tree():
		_position_mode_row()
	if biome_selection_row and biome_selection_row.is_inside_tree():
		_position_biome_row()
	if clock_speed_row and clock_speed_row.is_inside_tree():
		_position_clock_row()
	if menu_selection_row and menu_selection_row.is_inside_tree():
		_position_menu_row()
	if action_preview_row and action_preview_row.is_inside_tree():
		_position_action_row()


func create_action_bars(parent: Control) -> void:
	# Create action bars directly in parent (ActionBarLayer)
	#
	# Args:
	# parent: The ActionBarLayer Control node
	#
	# GODOT 4 APPROACH: Connect to parent's resized signal for proper layout timing
	if not parent:
		push_error("ActionBarManager: parent is null!")
		return

	if not parent.is_inside_tree():
		push_error("ActionBarManager: parent not in scene tree!")
		return
	if not layout_manager or not layout_manager.has_method("get_action_row_height"):
		push_error("ActionBarManager: UILayoutManager is required before creating action bars")
		return

	tool_selection_row = ToolSelectionRow.new()
	tool_selection_row.name = "ToolSelectionRow"
	parent.add_child(tool_selection_row)

	# Sub-mode chips ride the hat band, right-aligned. Added AFTER the tool row
	# so it wins the pick in any overlap (GUI picking is tree order, not
	# z_index) — though _position_tool_row also insets the hats so they cannot
	# reach this cluster in the first place.
	mode_selection_row = _ModeSelectionRow.new()
	mode_selection_row.name = "ModeSelectionRow"
	parent.add_child(mode_selection_row)

	biome_selection_row = BiomeSelectionRow.new()
	biome_selection_row.name = "BiomeSelectionRow"
	parent.add_child(biome_selection_row)

	# Clock chips ride the biome band's right corner (the hat band's right
	# corner already belongs to ModeSelectionRow). Added AFTER the biome row so
	# it wins the pick in any overlap — GUI picking is tree order, not z_index.
	clock_speed_row = _ClockSpeedRow.new()
	clock_speed_row.name = "ClockSpeedRow"
	parent.add_child(clock_speed_row)

	menu_selection_row = MenuSelectionRow.new()
	menu_selection_row.name = "MenuSelectionRow"
	if layout_manager:
		menu_selection_row.set_layout_manager(layout_manager)
	parent.add_child(menu_selection_row)

	action_preview_row = ActionPreviewRow.new()
	action_preview_row.name = "ActionPreviewRow"
	parent.add_child(action_preview_row)

	# GODOT 4 BEST PRACTICE: Connect to parent's resized signal
	# This is the CORRECT way to handle anchor-based positioning
	InstrumentLocator._safe_connect(parent.resized, _on_parent_resized)

	# Also position immediately in case parent already has size
	_on_parent_resized()

	# Initialize action bars to show current frame from ToolConfig (single source of truth)
	var initial_frame := ToolConfig.get_current_frame()
	select_frame(initial_frame)
	VerboseHelper.debug("ui", "toolbar", "ActionBarManager initialized with frame %s" % initial_frame)


func _on_parent_resized() -> void:
	# Called when ActionBarLayer is resized - positions action bars
	_reposition_all_rows()


## Layout: top → bottom
##   top idx 0: menu  (ZXCVBNM — surface ring, below resource bar)
##   top idx 1: tool  (4-0 hats)
##   top idx 2: biome (TYUIOP)
##   [open farm view / game space — PlotTile cyan border is plot selection UI]
##   bottom  0: action (QERF — not a selection ring)
func _position_row_at_index(row: Control, idx: int) -> void:
	if not row:
		return
	var parent = row.get_parent()
	if not parent or parent.size.x <= 0:
		return
	row.set("layout_mode", 1)  # Control.LayoutMode.ANCHORS (enum not exposed to GDScript)
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	var row_h = layout_manager.get_action_row_height()
	row.offset_top = -float(idx + 1) * row_h
	row.offset_bottom = -float(idx) * row_h
	row.offset_left = 10
	row.offset_right = -10
	row.custom_minimum_size = Vector2(0, row_h)


func _position_top_row(row: Control, idx: int) -> void:
	if not row:
		return
	var parent = row.get_parent()
	if not parent or parent.size.x <= 0:
		return
	row.set("layout_mode", 1)  # Control.LayoutMode.ANCHORS (enum not exposed to GDScript)
	row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var row_h = layout_manager.get_action_row_height()
	var top_offset = layout_manager.get_resource_bar_height()
	row.offset_top = top_offset + float(idx) * row_h
	row.offset_bottom = top_offset + float(idx + 1) * row_h
	row.offset_left = 10
	row.offset_right = -10
	row.custom_minimum_size = Vector2(0, row_h)


## Right-edge inset that clears the pinned contract corner (ContractChip +
## ActFilament). Shared by the biome row and the sub-mode row.
const CONTRACT_CORNER_INSET := 210.0


func _position_tool_row() -> void:
	# Hats hug the LEFT (HBoxContainer default), so they never reach the
	# right-aligned mode cluster — no inset needed here.
	_position_top_row(tool_selection_row, 1)


func _position_mode_row() -> void:
	# Same band as the hats (top idx 1), right-aligned — costs no vertical
	# space and sits beside the hat it belongs to.
	_position_top_row(mode_selection_row, 1)
	# The contract corner (ContractChip + ActFilament, ~190px) owns the top
	# right. Inset past it or the mode chips draw straight over the act banner
	# — the same squeeze _position_biome_row already applies one band down.
	if mode_selection_row:
		mode_selection_row.offset_right = -CONTRACT_CORNER_INSET


func _position_biome_row() -> void:
	_position_top_row(biome_selection_row, 2)
	# The contract corner (ContractChip + ActFilament, top-right, ~190px wide)
	# shares this band — inset the biome row's right edge so its chips never
	# slide under the pinned contracts (playtest 2: "ugly overlap with the
	# biome bar... fixed by squeezing the biome bar in more").
	if biome_selection_row:
		biome_selection_row.offset_right = -CONTRACT_CORNER_INSET


func _position_clock_row() -> void:
	# Same band as the biome tabs (top idx 2), right-aligned — the hat band's
	# right corner is already the mode cluster's, and two right-aligned clusters
	# on one row collide on a narrow window.
	_position_top_row(clock_speed_row, 2)
	# Clear the pinned contract corner, exactly like the biome row it shares the
	# band with. The biome chips hug the LEFT, so they cannot reach this cluster.
	if clock_speed_row:
		clock_speed_row.offset_right = -CONTRACT_CORNER_INSET


func _position_menu_row() -> void:
	_position_top_row(menu_selection_row, 0)


func _position_action_row() -> void:
	# QERF action chips at the very bottom — not part of the cylinder.
	_position_row_at_index(action_preview_row, 0)


func get_tool_row() -> Control:
	return tool_selection_row


func get_biome_row() -> Control:
	return biome_selection_row


func get_menu_row() -> Control:
	return menu_selection_row


func get_action_row() -> Control:
	return action_preview_row


func select_frame(frame_name: String) -> void:
	if tool_selection_row:
		tool_selection_row.select_frame(frame_name)
	# The mode chips belong to whichever hat is active, so they follow it.
	if mode_selection_row:
		mode_selection_row.show_frame(frame_name)


func get_mode_row() -> Control:
	return mode_selection_row


func get_clock_row() -> Control:
	return clock_speed_row


func render_action_projection(projection: Dictionary) -> void:
	if action_preview_row:
		action_preview_row.render_projection(projection)
