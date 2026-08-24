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

	# EVERY row gets the layout manager, and gets it BEFORE add_child (the
	# scale is copied once in _ready → _rebuild_buttons). Only the menu row
	# received it for months, so at 720p the menu chips rendered 1.5× the size
	# of everything else — half of what made the top strip read as mucky.
	tool_selection_row = ToolSelectionRow.new()
	tool_selection_row.name = "ToolSelectionRow"
	if layout_manager:
		tool_selection_row.set_layout_manager(layout_manager)
	parent.add_child(tool_selection_row)

	# Sub-mode chips sit one band below, directly under the hats they annotate.
	# Added AFTER the tool row so it wins the pick in any overlap (GUI picking
	# is tree order, not z_index).
	mode_selection_row = _ModeSelectionRow.new()
	mode_selection_row.name = "ModeSelectionRow"
	if layout_manager:
		mode_selection_row.set_layout_manager(layout_manager)
	parent.add_child(mode_selection_row)

	# Clock chips ride the second band's right corner (the biome bar that used
	# to hold a third band died 2026-08-24 — the field's portal rail is the
	# mouse biome door now).
	clock_speed_row = _ClockSpeedRow.new()
	clock_speed_row.name = "ClockSpeedRow"
	if layout_manager:
		clock_speed_row.set_layout_manager(layout_manager)
	parent.add_child(clock_speed_row)

	menu_selection_row = MenuSelectionRow.new()
	menu_selection_row.name = "MenuSelectionRow"
	if layout_manager:
		menu_selection_row.set_layout_manager(layout_manager)
	parent.add_child(menu_selection_row)

	action_preview_row = ActionPreviewRow.new()
	action_preview_row.name = "ActionPreviewRow"
	if layout_manager:
		action_preview_row.set_layout_manager(layout_manager)
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


## Layout: top → bottom (two bands since 2026-08-24 — was three + biome bar)
##   top idx 0: tool (4-0 hats, LEFT) + menu (ZXCVBNM surface ring, RIGHT)
##   top idx 1: mode (under the hats, LEFT) + clock (right corner, inset past
##              the contract corner; TYUIOP biomes = the field's portal rail
##              + keyboard ring now)
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
	# Band 0 LEFT — level with the menu chips (owner ask 2026-08-24: "those two
	# information sets on the same vertical level"; band 0's left half sat
	# empty since the hats lived a band lower). Hats hug the LEFT (HBoxContainer
	# default), menus hug the RIGHT — they cannot collide (@1280, both clusters
	# at scale 1.5: ≈519px + ≈594px < 1260px usable).
	_position_top_row(tool_selection_row, 0)


func _position_mode_row() -> void:
	# Band 1 LEFT — directly UNDER the hats the mode chips annotate (they used
	# to sit far right of the hat band; under the active hat reads closer).
	# Left-aligned via ModeSelectionRow's own alignment, so the contract-corner
	# inset is unnecessary — the cluster can't reach the right edge.
	_position_top_row(mode_selection_row, 1)


func _position_clock_row() -> void:
	# Band 1 RIGHT — the strip is two bands now (was three + the biome bar).
	# Right-aligned, clear of the pinned contract corner (ContractChip +
	# ActFilament) which also starts at this band's height.
	_position_top_row(clock_speed_row, 1)
	if clock_speed_row:
		clock_speed_row.offset_right = -CONTRACT_CORNER_INSET


func _position_menu_row() -> void:
	_position_top_row(menu_selection_row, 0)


func _position_action_row() -> void:
	# QERF action chips at the very bottom — not part of the cylinder.
	_position_row_at_index(action_preview_row, 0)


## The vertical strip the HUD leaves free, in global screen coords: (top_y, bottom_y).
##
## This manager owns every row that boxes the play space, so it is the only thing that
## can answer honestly. The 3D field centres on THIS rather than on
## UILayoutManager.play_area_rect: that rect models the 2D rack's layout — while the
## real top chrome is the resource strip plus two stacked selection bands (~26% at
## 720p; it was three bands + a mismatched strip height when centring on the model
## put the cloud ~180px too high, with orbs behind the then-biome tabs and the bottom
## third of the screen empty — #520).
func get_free_band() -> Vector2:
	var layer: Control = action_preview_row.get_parent() if action_preview_row else null
	if layer == null or not is_instance_valid(layer):
		return Vector2.ZERO
	var band := layer.get_global_rect()
	var top := band.position.y
	var bottom := band.end.y
	for row in [menu_selection_row, tool_selection_row, mode_selection_row,
			clock_speed_row]:
		if row != null and is_instance_valid(row) and row.visible:
			top = maxf(top, row.get_global_rect().end.y)
	if action_preview_row != null and is_instance_valid(action_preview_row) and action_preview_row.visible:
		bottom = minf(bottom, action_preview_row.get_global_rect().position.y)
	return Vector2(top, bottom)


func get_tool_row() -> Control:
	return tool_selection_row


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
