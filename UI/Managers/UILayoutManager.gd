class_name UILayoutManager
extends Node

## UILayoutManager - Parametric layout system for responsive UI scaling
## Central source of truth for all position, size, and scaling calculations
## Handles viewport resizing, breakpoints, and touch vs mouse adaptation

# Preload GridConfig (Phase 5)

# Base resolution for design (all proportions calculated from this)
const BASE_RESOLUTION = Vector2(960, 540)  # Static viewport base resolution

# Layout proportions (percentages of viewport)
## 7.4%, from 6% (casing 2026-08-25) then again when the strip DOCKED into the
## bezel the same day. The band holds three things now: the chassis's top
## BEZEL_INNER_INSET, which the seated panel gives up entirely, then the casing's
## own free edge, then the counter glyphs. At 6% there was no room for the first
## of those, so the glyphs sat on the molding. This is the band growing to fit
## its own contents, NOT padding added below it (the owner ruled that out on
## 08-25: "don't move the resource bar down any extra").
const TOP_BAR_HEIGHT_PERCENT = 0.074
const PLAY_AREA_PERCENT = 0.665           # 66.5% of viewport height (quantum graph center)
var plots_row_height_percent: float = 0.15  # Dynamic: 15% base (recalculated from GridConfig grid height)
const ACTIONS_ROW_HEIGHT_PERCENT = 0.125  # 12.5% action buttons row

# Margins and spacing (as percentages)
const PLAY_AREA_MARGIN_PERCENT = 0.05   # 5% margin inside play area
const PANEL_SPACING_PERCENT = 0.01      # 1% spacing between panels

# Overlay sizing constants (consolidated from scattered hardcoded values)
const OVERLAY_WIDTH_PERCENT = 0.55      # 55% of viewport width
const OVERLAY_HEIGHT_PERCENT = 0.7      # 70% of viewport height
const OVERLAY_MIN_WIDTH = 500           # Minimum width in pixels
const OVERLAY_MIN_HEIGHT = 400          # Minimum height in pixels
const OVERLAY_MAX_WIDTH = 800           # Maximum width in pixels
const OVERLAY_MAX_HEIGHT = 600          # Maximum height in pixels
const OVERLAY_SMALL_WIDTH_PERCENT = 0.42
const OVERLAY_SMALL_HEIGHT_PERCENT = 0.56
const OVERLAY_SMALL_MIN_WIDTH = 360
const OVERLAY_SMALL_MIN_HEIGHT = 280
const OVERLAY_SMALL_MAX_WIDTH = 620
const OVERLAY_SMALL_MAX_HEIGHT = 460
const OVERLAY_LARGE_WIDTH_PERCENT = 0.72
const OVERLAY_LARGE_HEIGHT_PERCENT = 0.82
const OVERLAY_LARGE_MIN_WIDTH = 620
const OVERLAY_LARGE_MIN_HEIGHT = 460
const OVERLAY_LARGE_MAX_WIDTH = 940
const OVERLAY_LARGE_MAX_HEIGHT = 760

# Action bar constants (consolidated from ActionBarManager)
const ACTION_ROW_HEIGHT_PERCENT = 0.10  # 10% of viewport height
const ACTION_ROW_MIN_HEIGHT = 55        # Minimum height in pixels
const ACTION_ROW_MAX_PERCENT = 0.40     # Max 40% of viewport for both rows combined

# Component constants
const TOP_STRIP_GAP_BASE = 4.0
const TOP_STRIP_SIDE_INSET_BASE = 200.0
const QUANTUM_INDICATOR_WIDTH_BASE = 200.0
const QUANTUM_INDICATOR_HEIGHT_BASE = 40.0
## The time bar's band. It was a 14px hairline when it was pure scaffold
## (2026-08-25); it carries the transport controls now (owner ask: "the time
## controls need to start getting integrated into the timebar"), so the band
## has to be tall enough for one row of compact chips — 38px at the 540p
## reference plus breathing room — and ClockSpeedRow left the top chip strip
## to live here, which is the SAME move that un-crowded the top-right corner.
const TIME_BAR_HEIGHT_BASE = 48.0

# Current viewport dimensions (updated on resize)
var viewport_size: Vector2
var scale_factor: float = 1.0
var is_touch_device: bool = false
var grid_config: GridConfig = null  # Grid configuration (Phase 5)

# Calculated layout dimensions (updated when viewport resizes)
var top_bar_height: float
var play_area_rect: Rect2  # x, y, width, height (quantum graph area)
var play_area_inner_rect: Rect2  # After applying margins
var plots_row_rect: Rect2  # PCB-style component placement row
var actions_row_rect: Rect2  # Action buttons row


func _log_debug(message: String) -> void:
	VerboseHelper.debug("ui", "layout", message)

# Breakpoint-based scaling
enum ScaleBreakpoint { MOBILE, HD, FHD, QHD, UHD_4K }
var current_breakpoint: ScaleBreakpoint

# Signals
signal layout_changed(new_layout: Dictionary)
signal input_mode_changed(is_touch: bool)


func _ready():
	# Detect input mode
	_detect_input_mode()

	# Connect to viewport resize signal
	get_viewport().size_changed.connect(_on_viewport_resize)

	# Initial layout calculation
	_on_viewport_resize()


func _detect_input_mode():
	# Detect if device supports touch input
	is_touch_device = RuntimeEnv.is_touch()

	# Additional detection for HTML5 export
	if OS.get_name() == "HTML5":
		# For web, check user agent
		is_touch_device = is_touch_device or _detect_mobile_browser()

	_log_debug("UILayoutManager: Input mode detected - %s" % ("TOUCH" if is_touch_device else "MOUSE"))
	input_mode_changed.emit(is_touch_device)


func _detect_mobile_browser() -> bool:
	# Check if running in mobile browser (HTML5 export)
	if OS.get_name() != "HTML5":
		return false

	# Note: JavaScript.eval requires careful handling
	# For now, rely on OS.has_touchscreen_ui_hint()
	return false


func inject_grid_config(config: GridConfig) -> void:
	# Inject GridConfig for dynamic layout sizing (Phase 5)
	if not config:
		push_error("UILayoutManager: Attempted to inject null GridConfig!")
		return

	grid_config = config
	_recalculate_layout_percentages()
	_log_debug("💉 GridConfig injected into UILayoutManager")


func _recalculate_layout_percentages() -> void:
	# Recalculate layout percentages based on grid height (Phase 5)
	if not grid_config:
		return

	# Base: 15% per row, with 10% spacing multiplier
	var base_per_row = 0.15
	var spacing_multiplier = 1.1
	plots_row_height_percent = base_per_row * grid_config.grid_height * spacing_multiplier

	# Cap at 35% max (don't let plots dominate screen)
	plots_row_height_percent = min(plots_row_height_percent, 0.35)

	_log_debug("📐 Plots row height recalculated: %.1f%% (grid: %d rows)" %
		[plots_row_height_percent * 100, grid_config.grid_height])


func _on_viewport_resize():
	# Called when viewport size changes
	viewport_size = get_viewport().get_visible_rect().size  # Logical viewport (960×540 with canvas_items)
	_calculate_scale_factor()
	_calculate_layout_dimensions()
	_emit_layout_change()


func _calculate_scale_factor():
	# Calculate scale factor and determine breakpoint
	var width_scale = viewport_size.x / BASE_RESOLUTION.x
	var height_scale = viewport_size.y / BASE_RESOLUTION.y
	var raw_scale = min(width_scale, height_scale)

	# Snap to breakpoints for consistent experience
	if raw_scale >= 1.8:
		scale_factor = 2.0
		current_breakpoint = ScaleBreakpoint.UHD_4K
	elif raw_scale >= 1.25:
		scale_factor = 1.5
		current_breakpoint = ScaleBreakpoint.QHD
	elif raw_scale >= 0.9:
		scale_factor = 1.0
		current_breakpoint = ScaleBreakpoint.FHD
	elif raw_scale >= 0.6:
		scale_factor = 0.75
		current_breakpoint = ScaleBreakpoint.HD
	else:
		scale_factor = 0.6
		current_breakpoint = ScaleBreakpoint.MOBILE

	# On touch devices, never scale down below 1.0 for readability
	if is_touch_device and scale_factor < 1.0:
		scale_factor = 1.0

	_log_debug("UILayoutManager: Viewport=%s, Scale=%.2f×, Breakpoint=%s" % [
		viewport_size, scale_factor, ScaleBreakpoint.keys()[current_breakpoint]
	])


func _calculate_layout_dimensions():
	# Calculate all layout dimensions based on current viewport and scale factor
	# Recalculate if grid config changed
	if grid_config:
		_recalculate_layout_percentages()

	# Top bar (anchored to top, full width)
	top_bar_height = viewport_size.y * TOP_BAR_HEIGHT_PERCENT

	# Play area (center section between top and bottom rows)
	var play_area_y = top_bar_height
	var play_area_height = viewport_size.y * PLAY_AREA_PERCENT
	play_area_rect = Rect2(0, play_area_y, viewport_size.x, play_area_height)

	# Play area inner rect (after applying margins)
	var margin = play_area_rect.size.length() * PLAY_AREA_MARGIN_PERCENT
	play_area_inner_rect = Rect2(
		play_area_rect.position + Vector2(margin, margin),
		play_area_rect.size - Vector2(margin * 2, margin * 2)
	)

	# Plots row (PCB-style component placement) - below play area - DYNAMIC HEIGHT
	var plots_row_height = viewport_size.y * plots_row_height_percent
	var plots_row_y = play_area_y + play_area_height
	plots_row_rect = Rect2(0, plots_row_y, viewport_size.x, plots_row_height)

	# Actions row - below plots row
	var actions_row_height = viewport_size.y * ACTIONS_ROW_HEIGHT_PERCENT
	var actions_row_y = plots_row_y + plots_row_height
	actions_row_rect = Rect2(0, actions_row_y, viewport_size.x, actions_row_height)

	# DEBUG: Verify layout fits within viewport
	_log_debug("📐 Layout breakdown (parametric):")
	_log_debug("  Top bar: %.1fpx (0%% to %d%%)" % [top_bar_height, int(TOP_BAR_HEIGHT_PERCENT * 100)])
	_log_debug("  Play area: %.1fpx (%d%% to %d%%)" % [play_area_height, int(TOP_BAR_HEIGHT_PERCENT * 100), int((TOP_BAR_HEIGHT_PERCENT + PLAY_AREA_PERCENT) * 100)])
	_log_debug("  Plots row: %.1fpx (%d%% to %d%%)" % [plots_row_height, int((TOP_BAR_HEIGHT_PERCENT + PLAY_AREA_PERCENT) * 100), int((TOP_BAR_HEIGHT_PERCENT + PLAY_AREA_PERCENT + plots_row_height_percent) * 100)])
	_log_debug("  Actions row: %.1fpx (%d%% to 100%%)" % [actions_row_height, int((TOP_BAR_HEIGHT_PERCENT + PLAY_AREA_PERCENT + plots_row_height_percent) * 100)])
	_log_debug("  Total: %.1fpx (should equal viewport height: %.1fpx)" % [top_bar_height + play_area_height + plots_row_height + actions_row_height, viewport_size.y])


func _emit_layout_change():
	# Emit layout change signal with complete layout data
	layout_changed.emit({
		"viewport_size": viewport_size,
		"scale_factor": scale_factor,
		"top_bar_height": top_bar_height,
		"play_area": play_area_rect,
		"play_area_inner": play_area_inner_rect,
		"plots_row": plots_row_rect,
		"actions_row": actions_row_rect,
		"breakpoint": current_breakpoint
	})


## Public API: Position Calculation Functions

func get_scaled_size(base_size: Vector2) -> Vector2:
	# Scale a size vector by current scale factor
	return base_size * scale_factor


func h(base_px_540: float) -> float:
	# Normalize a height token from 540px design space to current viewport.
	return viewport_size.y * (base_px_540 / BASE_RESOLUTION.y)


func w(base_px_960: float) -> float:
	# Normalize a width token from 960px design space to current viewport.
	return viewport_size.x * (base_px_960 / BASE_RESOLUTION.x)


func inset(base_px: float) -> float:
	# Scale inset/margin tokens using the smaller axis for consistent density.
	var by_width = w(base_px)
	var by_height = h(base_px)
	return min(by_width, by_height)


func get_scaled_font_size(base_size: int) -> int:
	# Scale font size with cap at 1.5× to maintain readability

	# Args:
	# base_size: Base font size in pixels (at 1920×1080)

	# Returns:
	# Scaled font size, capped at 1.5× to prevent text overflow
	var font_scale = min(scale_factor, 1.5)
	return int(base_size * font_scale)


func get_perimeter_position(index: int, total: int) -> Vector2:
	# Calculate position for plot tiles around play area perimeter

	# Distributes items evenly around the inner rectangular boundary of play area.
	# Starts at top-left corner and goes: top → right → bottom → left

	# Args:
	# index: Which item this is (0 to total-1)
	# total: Total number of items to distribute

	# Returns:
	# Position for this item in play area coordinates
	var inner_rect = play_area_inner_rect
	var perimeter_length = (inner_rect.size.x + inner_rect.size.y) * 2
	var segment_length = perimeter_length / total
	var distance = index * segment_length

	# Distribute around rectangle perimeter (top, right, bottom, left)
	if distance < inner_rect.size.x:
		# Top edge (left to right)
		return Vector2(inner_rect.position.x + distance, inner_rect.position.y)
	elif distance < inner_rect.size.x + inner_rect.size.y:
		# Right edge (top to bottom)
		var offset = distance - inner_rect.size.x
		return Vector2(inner_rect.position.x + inner_rect.size.x, inner_rect.position.y + offset)
	elif distance < inner_rect.size.x * 2 + inner_rect.size.y:
		# Bottom edge (right to left)
		var offset = distance - (inner_rect.size.x + inner_rect.size.y)
		return Vector2(inner_rect.position.x + inner_rect.size.x - offset, inner_rect.position.y + inner_rect.size.y)
	else:
		# Left edge (bottom to top)
		var offset = distance - (inner_rect.size.x * 2 + inner_rect.size.y)
		return Vector2(inner_rect.position.x, inner_rect.position.y + inner_rect.size.y - offset)


func get_play_area_center() -> Vector2:
	# Get center point of play area (for quantum graph positioning)
	return play_area_rect.position + play_area_rect.size / 2


func anchor_to_corner(corner: String, offset: Vector2) -> Vector2:
	# Position element relative to screen corner with scaled offset

	# Args:
	# corner: One of "top_left", "top_right", "bottom_left", "bottom_right"
	# offset: Offset from corner (will be scaled by scale_factor)

	# Returns:
	# Absolute screen position for the element
	var scaled_offset = offset * scale_factor
	match corner:
		"top_left":
			return scaled_offset
		"top_right":
			return Vector2(viewport_size.x - scaled_offset.x, scaled_offset.y)
		"bottom_left":
			return Vector2(scaled_offset.x, viewport_size.y - scaled_offset.y)
		"bottom_right":
			return viewport_size - scaled_offset
		_:
			push_error("UILayoutManager: Invalid corner '%s'" % corner)
			return Vector2.ZERO


func anchor_to_edge(edge: String, offset_from_edge: float, position_along_edge: float) -> Vector2:
	# Position element along screen edge

	# Args:
	# edge: One of "top", "right", "bottom", "left"
	# offset_from_edge: Distance from edge (will be scaled)
	# position_along_edge: 0.0-1.0 position along the edge (0=start, 1=end)

	# Returns:
	# Absolute screen position for the element
	var scaled_offset = offset_from_edge * scale_factor
	match edge:
		"top":
			return Vector2(viewport_size.x * position_along_edge, scaled_offset)
		"right":
			return Vector2(viewport_size.x - scaled_offset, viewport_size.y * position_along_edge)
		"bottom":
			return Vector2(viewport_size.x * position_along_edge, viewport_size.y - scaled_offset)
		"left":
			return Vector2(scaled_offset, viewport_size.y * position_along_edge)
		_:
			push_error("UILayoutManager: Invalid edge '%s'" % edge)
			return Vector2.ZERO


func get_debug_info() -> Dictionary:
	# Return debug information about current layout state
	return {
		"viewport_size": viewport_size,
		"scale_factor": scale_factor,
		"breakpoint": ScaleBreakpoint.keys()[current_breakpoint],
		"is_touch": is_touch_device,
		"top_bar_height": top_bar_height,
		"play_area_size": play_area_rect.size,
		"play_area_inner_size": play_area_inner_rect.size,
		"plots_row_size": plots_row_rect.size,
		"actions_row_size": actions_row_rect.size,
	}


## Overlay and Action Bar Sizing API
## Consolidated from scattered hardcoded values across UI components

func get_overlay_size() -> Vector2:
	# Default overlay size alias for medium modals.
	return get_modal_size("medium")


func get_modal_size(mode: String = "medium") -> Vector2:
	# Get modal size by semantic mode.

	# Modes:
	# - small: compact system menu
	# - medium: standard info overlay
	# - large: content-heavy overlay
	match mode:
		"small":
			return Vector2(
				clampf(viewport_size.x * OVERLAY_SMALL_WIDTH_PERCENT, OVERLAY_SMALL_MIN_WIDTH, OVERLAY_SMALL_MAX_WIDTH),
				clampf(viewport_size.y * OVERLAY_SMALL_HEIGHT_PERCENT, OVERLAY_SMALL_MIN_HEIGHT, OVERLAY_SMALL_MAX_HEIGHT)
			)
		"large":
			return Vector2(
				clampf(viewport_size.x * OVERLAY_LARGE_WIDTH_PERCENT, OVERLAY_LARGE_MIN_WIDTH, OVERLAY_LARGE_MAX_WIDTH),
				clampf(viewport_size.y * OVERLAY_LARGE_HEIGHT_PERCENT, OVERLAY_LARGE_MIN_HEIGHT, OVERLAY_LARGE_MAX_HEIGHT)
			)
		_:
			return Vector2(
				clampf(viewport_size.x * OVERLAY_WIDTH_PERCENT, OVERLAY_MIN_WIDTH, OVERLAY_MAX_WIDTH),
				clampf(viewport_size.y * OVERLAY_HEIGHT_PERCENT, OVERLAY_MIN_HEIGHT, OVERLAY_MAX_HEIGHT)
			)


func center_overlay(overlay: Control, size: Vector2 = Vector2.ZERO) -> void:
	# Center an overlay in the viewport using anchor-based positioning.

	# Args:
	# overlay: The Control node to center
	# size: Optional size override. If Vector2.ZERO, uses get_overlay_size()
	var actual_size = size if size != Vector2.ZERO else get_overlay_size()

	# Set anchors to center
	overlay.anchor_left = 0.5
	overlay.anchor_right = 0.5
	overlay.anchor_top = 0.5
	overlay.anchor_bottom = 0.5

	# Center the overlay around the anchor point
	overlay.offset_left = -actual_size.x / 2
	overlay.offset_right = actual_size.x / 2
	overlay.offset_top = -actual_size.y / 2
	overlay.offset_bottom = actual_size.y / 2

	# Ensure it grows from center
	overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	overlay.grow_vertical = Control.GROW_DIRECTION_BOTH


func get_action_row_height() -> float:
	# Calculate responsive action row height.

	# Returns:
	# Height in pixels, based on 13% of viewport height,
	# clamped to min 55px and max 20% of viewport (so 2 rows = 40% max).
	var row_h = max(ACTION_ROW_MIN_HEIGHT, viewport_size.y * ACTION_ROW_HEIGHT_PERCENT)

	# Clamp so both rows don't exceed 40% of viewport
	if row_h * 2 > viewport_size.y * ACTION_ROW_MAX_PERCENT:
		row_h = viewport_size.y * ACTION_ROW_MAX_PERCENT / 2

	return row_h


func get_resource_bar_height() -> float:
	# Height of the top resource strip — the SAME 6% FarmUI actually draws
	# (_apply_parametric_sizing). Two authorities used to disagree here (h(50)
	# ≈ 9.3% vs the drawn 6%), leaving a ~23px band of dead air between the
	# strip and the first chip row at 720p.
	return viewport_size.y * TOP_BAR_HEIGHT_PERCENT


func get_top_strip_gap() -> float:
	# Vertical gap between top resource strip and overlayed top controls.
	return h(TOP_STRIP_GAP_BASE)


func get_time_bar_height() -> float:
	# Height of the TimeBar placeholder strip (2026-08-25) — a thin, inert
	# full-width band reserved for a future history-scrubber, sitting between
	# the resource strip and the first top chip band. Every top-row offset
	# that starts from get_resource_bar_height() must also add this, or the
	# time bar silently paints under band 0.
	return h(TIME_BAR_HEIGHT_BASE)




func get_top_strip_side_inset() -> float:
	# Left/right safe inset for top strip controls.
	return w(TOP_STRIP_SIDE_INSET_BASE)


func get_quantum_indicator_size() -> Vector2:
	# Preferred size for the quantum mode indicator.
	return Vector2(w(QUANTUM_INDICATOR_WIDTH_BASE), h(QUANTUM_INDICATOR_HEIGHT_BASE))


## Utility Methods (DRY consolidation)

func get_viewport_size() -> Vector2:
	# Get current viewport size.

	# Use this instead of get_viewport().get_visible_rect().size for consistent access.
	# This value is automatically updated when the viewport resizes.
	return viewport_size


func get_plots_row_center() -> Vector2:
	# Get center point of plots row (for grid placement).
	return plots_row_rect.position + plots_row_rect.size / 2
