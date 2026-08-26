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
	# Hats moved to the bottom stack 2026-08-24 (owner ask: "close to the
	# actions"), centered directly above QERF.
	tool_selection_row = ToolSelectionRow.new()
	tool_selection_row.name = "ToolSelectionRow"
	if layout_manager:
		tool_selection_row.set_layout_manager(layout_manager)
	parent.add_child(tool_selection_row)

	# Sub-mode chips share the SAME band as the hats now (a fixed right-hand
	# dock, see _position_mode_row) rather than a band of their own — the move
	# to the bottom stays height-neutral-ish (one new band, not two). Added
	# AFTER the tool row so it wins the pick in any overlap (GUI picking is
	# tree order, not z_index).
	mode_selection_row = _ModeSelectionRow.new()
	mode_selection_row.name = "ModeSelectionRow"
	if layout_manager:
		mode_selection_row.set_layout_manager(layout_manager)
	parent.add_child(mode_selection_row)

	# Clock chips ride the top strip's remaining band, right corner (the biome
	# bar that used to hold a third top band died 2026-08-24 — the field's
	# portal rail is the mouse biome door now).
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

	# The QERF dock deliberately does NOT take the layout manager: its labels
	# are PROSE (verb + cost + teaching hint), and at scale 1.5 the words
	# truncate ("[Q] Extract (Mass Extr…") — screenshot pass 2026-08-24. The
	# top rows are emoji glyphs and scale cleanly; the dock's words outrank
	# its chip size.
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


## Layout: top → bottom (re-banded 2026-08-24: hats+mode moved to the bottom,
## "close to the actions" — owner ask; was top idx 0)
##   top idx 0: menu (ZXCVBNM surface ring, RIGHT — left half now empty
##              transparent space, not a styled box: SelectionButtonRow's
##              dressing tray only ever hugs its own chip hull, never the full
##              band, so an empty half reads as open space, not the old muck)
##   [TimeBar band — not a chip band: the timeline strip PlayerShell owns.
##              ClockSpeedRow (⏪ ⏸ ⏩) rides its LEFT end, positioned by
##              _position_clock_row below. TYUIOP biomes = the field's portal
##              rail + keyboard ring.]
##   [open farm view / game space — PlotTile cyan border is plot selection UI]
##   bottom  1: tool (4-0 hats, CENTERED) + mode (its sub-modes, fixed
##              right-hand dock inside the SAME band — ClockSpeedRow's
##              fixed-inset technique, not a second band, so the move costs
##              the field only one band's height, not two)
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
	# 20px, not 10 (border-weight pass 2026-08-25): the brass molding's inner
	# ring reaches MOLD_INNER_INSET (14.5px) — a 10px margin sat content
	# INSIDE the frame's ornament band, not just near it.
	row.offset_left = 20
	row.offset_right = -20
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
	# + get_time_bar_height(): the new full-width TimeBar placeholder sits
	# between the resource strip and this row (2026-08-25) — every top-row
	# offset must clear it or the time bar silently paints under band 0.
	var top_offset = layout_manager.get_resource_bar_height() + layout_manager.get_time_bar_height()
	row.offset_top = top_offset + float(idx) * row_h
	row.offset_bottom = top_offset + float(idx + 1) * row_h
	row.offset_left = 20
	row.offset_right = -20
	row.custom_minimum_size = Vector2(0, row_h)


## Fixed width of the mode row's carved-out dock inside the shared hat band
## (ClockSpeedRow's fixed-inset technique, not a second band). Comfortably
## fits mode's 2-3 compact chips; the centered hat cluster tops out ~360px, so
## even at 1280px width both clusters keep clear margin.
const MODE_DOCK_WIDTH := 220.0


func _position_tool_row() -> void:
	# Bottom band, one above QERF — "close to the actions" (owner ask
	# 2026-08-24). Centered, not edge-hugging: "aesthetically settled between
	# the circular center [field] and the action bar."
	_position_row_at_index(tool_selection_row, 1)
	if tool_selection_row:
		tool_selection_row.alignment = BoxContainer.ALIGNMENT_CENTER


func _position_mode_row() -> void:
	# SAME band as the hats (idx 1) — a fixed right-hand dock carved out of
	# that band, not a band of its own, so hats+mode together cost the field
	# only one band's height. ModeSelectionRow's own ALIGNMENT_BEGIN hugs the
	# left edge of THIS narrow box, reading as "just past the hats" without
	# ever reaching into the centered hat cluster.
	_position_row_at_index(mode_selection_row, 1)
	if mode_selection_row and mode_selection_row.get_parent():
		# Derive from the PARENT's width, not the row's own `size` — after
		# _position_row_at_index the row's rect is anchor-driven and may not
		# have re-measured synchronously, but the parent (ActionBarLayer,
		# already validated inside_tree with size > 0) is stable.
		var parent_w: float = mode_selection_row.get_parent().size.x
		mode_selection_row.offset_left = parent_w - 20.0 - MODE_DOCK_WIDTH
		mode_selection_row.offset_right = -20.0


func _position_clock_row() -> void:
	# NOT a top chip band any more: the transport sits ON the TimeBar's track,
	# left end (2026-08-25, owner ask "the time controls need to start getting
	# integrated into the timebar"). PlayerShell positions the strip itself
	# from the same two layout-manager getters, so both stay pinned to one
	# band even when the viewport re-scales.
	if not clock_speed_row:
		return
	var parent = clock_speed_row.get_parent()
	if not parent or parent.size.x <= 0:
		return
	clock_speed_row.set("layout_mode", 1)  # Control.LayoutMode.ANCHORS
	clock_speed_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var band_top: float = layout_manager.get_resource_bar_height()
	var band_h: float = layout_manager.get_time_bar_height()
	# Inset inside the band: SelectionButtonRow's dressing tray hugs its chip
	# hull with a little overhang, and at band height exactly it bled up into
	# the resource strip's own framed box directly above.
	const TRACK_INSET := 5.0
	clock_speed_row.offset_top = band_top + TRACK_INSET
	clock_speed_row.offset_bottom = band_top + band_h - TRACK_INSET
	clock_speed_row.offset_left = 20
	clock_speed_row.offset_right = -20
	clock_speed_row.custom_minimum_size = Vector2(0, band_h - 2.0 * TRACK_INSET)


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
	# Top rows: only the menu band is a chip band up here now (hats + their
	# sub-modes moved to the bottom stack 2026-08-24; the clock chips moved
	# onto the TimeBar's track 2026-08-25, and that strip sits ABOVE the menu
	# band, so the menu row's bottom edge already speaks for all of it).
	for row in [menu_selection_row]:
		if row != null and is_instance_valid(row) and row.visible:
			top = maxf(top, row.get_global_rect().end.y)
	# Bottom stack: QERF and the hat/mode band both eat into the free band
	# from below — take whichever visible row sits highest.
	for row in [action_preview_row, tool_selection_row, mode_selection_row]:
		if row != null and is_instance_valid(row) and row.visible:
			bottom = minf(bottom, row.get_global_rect().position.y)
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
