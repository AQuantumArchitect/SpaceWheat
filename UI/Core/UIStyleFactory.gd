class_name UIStyleFactory
extends RefCounted

## UIStyleFactory - Centralized UI styling to eliminate duplication
##
## Usage:
##   var panel_style = UIStyleFactory.create_panel_style()
##   var button = UIStyleFactory.create_styled_button("Click Me", Color.GREEN)
##
## All overlays and panels should use these methods instead of creating
## StyleBoxFlat instances directly.

# =============================================================================
# COLOR CONSTANTS (Single Source of Truth)
# =============================================================================

## Standard overlay background colors
const COLOR_PANEL_BG = Color(0.08, 0.10, 0.14, 0.95)
const COLOR_PANEL_BORDER = Color(0.3, 0.4, 0.5, 0.8)
const COLOR_HUD_BG = Color(0.08, 0.10, 0.18, 0.92)
const COLOR_MODAL_DIMMER = Color(0.0, 0.0, 0.0, 0.7)

## State-based slot/card colors
const COLOR_SLOT_EMPTY = Color(0.15, 0.15, 0.15, 0.9)
const COLOR_SLOT_ACTIVE = Color(0.2, 0.3, 0.5, 0.9)
const COLOR_SLOT_READY = Color(0.2, 0.5, 0.2, 0.95)

## Alignment-based colors (for quest offers)
const COLOR_ALIGN_HIGH = Color(0.2, 0.4, 0.2, 0.8)    # Green (>70%)
const COLOR_ALIGN_MED = Color(0.3, 0.3, 0.2, 0.8)     # Neutral (50-70%)
const COLOR_ALIGN_LOW = Color(0.4, 0.3, 0.2, 0.8)     # Orange (30-50%)
const COLOR_ALIGN_VERY_LOW = Color(0.4, 0.2, 0.2, 0.8) # Red (<30%)

## Text colors
const COLOR_TEXT_TITLE = Color(0.9, 0.95, 1.0)
const COLOR_TEXT_SUBTITLE = Color(0.6, 0.7, 0.8)
const COLOR_TEXT_MUTED = Color(0.5, 0.6, 0.7)
const COLOR_TEXT_HIGHLIGHT = Color(1.0, 0.9, 0.3)  # Gold

## Selection highlight
const COLOR_SELECTION = Color(1.0, 0.9, 0.0)

## The global accent gold + shared chip ink, promoted from per-widget literals
## (dressing pass 2026-08-24: the same two values were hand-copied across
## SelectionButtonRow, ActionPreviewRow, ContractChip, ActFilament,
## FloatingRewardLayer and FpsDisplay — one spelling now).
const COLOR_ACCENT_GOLD = Color(1.0, 0.8, 0.3)
const COLOR_CHIP_BG = Color(0.07, 0.08, 0.10, 0.60)

## Quiet trim vocabulary (dressing pass 2026-08-24). Deliberately a whisper —
## the Apple-minimal pass (2026-07-08) removed loud borders on purpose, and
## trim must never fight the reserved state grammars: gold 0.95α = selection/
## attention, green 3px = would-fire, blue/teal/gold 1-2px = toast importance.
const COLOR_TRIM_INK = Color(0.06, 0.07, 0.09, 0.55)   # ResourcePanel's ink, promoted
const COLOR_TRIM_LINE = Color(0.42, 0.52, 0.65, 0.38)  # muted steel hairline
const COLOR_TRIM_GOLD = Color(1.0, 0.8, 0.3, 0.10)     # accent gold at whisper alpha
const TRIM_RADIUS = 8

## Brass molding palette (border-weight pass 2026-08-24 — owner ask: "approaching
## brass picture frame or clockwork machinery"). Deliberately a THIRD palette,
## not a reuse of COLOR_ACCENT_GOLD: accent gold is reserved for "look here"
## selection cues (chip underlines, spotlight pulses), and the frame's brass must
## never compete with that meaning. Each stroke that uses these still draws at
## the reserved 1px width (create_trim_style/draw_trim) — the bolder read comes
## from layering several strokes into a bevel, never from widening any one of
## them past what 2px (toast importance) / 3px (would-fire) already mean.
const COLOR_BRASS_HIGHLIGHT = Color(0.95, 0.80, 0.45, 0.9)
const COLOR_BRASS_MID = Color(0.72, 0.55, 0.25, 0.85)
const COLOR_BRASS_SHADOW = Color(0.28, 0.19, 0.08, 0.9)

# =============================================================================
# OVERLAY INTERACTION PALETTE (single source for tab/item/card chrome)
# =============================================================================

## Navigation chrome — tabs and item lists (identical across all overlay files)
const COLOR_TAB_ACTIVE  = COLOR_TEXT_HIGHLIGHT   ## Color(1.0, 0.9, 0.3) — gold active state
const COLOR_TAB_IDLE    = Color(0.6, 0.7, 0.85, 0.85)
const COLOR_ITEM_IDLE   = Color(0.75, 0.82, 0.92, 0.9)
const COLOR_ITEM_EMPTY  = Color(0.45, 0.5, 0.6, 0.75)
const COLOR_KEY_CHIP    = Color(0.55, 0.85, 1.0, 0.95)
const COLOR_VALUE       = Color(0.95, 0.95, 0.8, 1.0)
const COLOR_VERB_ACTIVE = Color(0.95, 0.75, 0.35, 1.0)

## Card/panel chrome — identical across BiomeInspector, MapMeta, QubitAtlas
const COLOR_CARD_BG            = Color(0.12, 0.14, 0.18, 0.9)
const COLOR_CARD_BORDER        = Color(0.25, 0.35, 0.45, 0.6)
const COLOR_CARD_BORDER_ACTIVE = Color(0.92, 0.85, 0.42, 0.95)

## Quantum axis bars — identical in BiomeInspector and QubitAtlas
const COLOR_BAR_BG    = Color(0.15, 0.15, 0.2, 0.8)
const COLOR_BAR_NORTH = Color(0.3, 0.55, 0.85, 0.9)
const COLOR_BAR_SOUTH = Color(0.85, 0.4, 0.25, 0.9)

## General overlay text — shared body copy and muted/hint text
const COLOR_HEADER = Color(0.88, 0.93, 0.98)       ## section/card header text (near-white blue)
const COLOR_BODY   = Color(0.72, 0.8, 0.9)         ## standard overlay body text
const COLOR_MUTED  = Color(0.55, 0.6, 0.7, 0.85)  ## hint/secondary text (identical RGB in 6 files)


# =============================================================================
# SPACING CONSTANTS
# =============================================================================

const VBOX_SPACING_TIGHT = 4     # Dense content
const VBOX_SPACING_NORMAL = 8    # Standard
const VBOX_SPACING_RELAXED = 12  # Overlays
const VBOX_SPACING_LOOSE = 16    # Modals

const HBOX_SPACING_TIGHT = 4
const HBOX_SPACING_NORMAL = 8
const HBOX_SPACING_RELAXED = 16


# =============================================================================
# PANEL STYLES
# =============================================================================

static func create_card_style(
	bg_color: Color = COLOR_CARD_BG,
	border_color: Color = COLOR_CARD_BORDER,
	corner_radius: int = 6,
	content_margin: int = 8
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(corner_radius)
	style.set_content_margin_all(content_margin)
	return style


## The TOAST FORM — one recipe, shared by every card that speaks to the player
## from a screen corner (HintToast, ActFilament's objective banner).
##
## Owner ask 2026-08-25: "the objective and the toast should have a pleasant
## harmony in form … maybe the stable objective hint can be a stable toast
## looking item?" The harmony is structural, not eyeballed — the banner and the
## toasts now stack in one column drawn from ONE stylebox recipe, so a tweak to
## the corner radius or the panel ink moves both together and they cannot drift
## back apart. Border color carries the only difference that means anything:
## importance for a toast, accent gold for the always-there objective.
const COLOR_TOAST_PANEL = Color(0.08, 0.10, 0.16, 0.92)
const TOAST_CORNER_RADIUS = 8
const TOAST_CONTENT_MARGIN = 12
const TOAST_WIDTH = 280


static func create_toast_style(border_color: Color, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_TOAST_PANEL
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(TOAST_CORNER_RADIUS)
	style.set_content_margin_all(TOAST_CONTENT_MARGIN)
	return style


static func create_panel_style(
	bg_color: Color = COLOR_PANEL_BG,
	border_color: Color = COLOR_PANEL_BORDER,
	border_width: int = 2,
	corner_radius: int = 12,
	content_margin: int = 16
) -> StyleBoxFlat:
	# # Create a standard panel StyleBoxFlat.

	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.set_content_margin_all(content_margin)
	return style


static func create_trim_style(
	ink: Color = COLOR_TRIM_INK,
	line: Color = COLOR_TRIM_LINE,
	radius: int = TRIM_RADIUS,
	draw_ink: bool = true
) -> StyleBoxFlat:
	# 1px hairline + optional translucent backing ink. Width is ALWAYS 1 —
	# 2px and 3px are reserved state cues (HintToast importance, would-fire).
	var style := StyleBoxFlat.new()
	style.draw_center = draw_ink
	style.bg_color = ink
	style.border_color = line
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style


static func draw_trim(ci: CanvasItem, rect: Rect2,
		ink: Color = COLOR_TRIM_INK, line: Color = COLOR_TRIM_LINE,
		radius: int = TRIM_RADIUS, draw_ink: bool = true) -> void:
	# For widgets that paint in _draw() (ResourcePanel/ActionPreviewRow idiom)
	# rather than carrying a Panel child — zero picking risk. Cheap: _draw only
	# runs on queue_redraw (these widgets fire it on resize, not per frame).
	ci.draw_style_box(create_trim_style(ink, line, radius, draw_ink), rect)


# =============================================================================
# CASING — the one bounding box every HUD region wears
# =============================================================================

## Owner ask 2026-08-25: "the trims and boundaries are a little messy … I'd
## like most everything in bounding boxes, just to give some structure that
## might later be replaced with a custom UI casing."
##
## That last clause is the whole design. Before this there were FOUR spellings
## of the same bevelled box — ResourcePanel outset a brass ghost by +3 at
## radius+2, ActionPreviewRow inset one by -3 at radius-2, ChromeFrame lerped N
## rings at a CONSTANT radius (so its inner rings' corners never nested
## properly), and SelectionButtonRow/FpsDisplay drew a single bare stroke — and
## a fifth region, the TimeBar, had no box at all. Swapping any of that for a
## drawn casing later would have meant finding all five.
##
## Now: one function, one geometry. A casing is `rings` concentric strokes
## stepping INWARD from `rect` by CASING_RING_STEP each, with the corner radius
## shrinking in step so every ring's corner is truly concentric. The innermost
## ring carries the backing ink; the outer rings are ghosts. Replacing this
## body with a NinePatchRect blit re-skins the entire HUD at once.
const CASING_RING_STEP := 3.0
const CASING_RADIUS := TRIM_RADIUS

## THE CHASSIS. The viewport molding (ChromeFrame) is the bezel every docked
## panel seats into, so both sides read its geometry from HERE rather than each
## keeping its own copy — the whole docking system is the claim that a panel
## edge and the bezel's inner ring land on the SAME line, and two constants
## that have to agree will not stay agreeing.
const BEZEL_OUTER_INSET := 4.0
const BEZEL_RING_COUNT := 4
const BEZEL_INNER_INSET := BEZEL_OUTER_INSET + CASING_RING_STEP * float(BEZEL_RING_COUNT - 1)

## Tones name a casing's job, not its color, so the palette can move under them.
##   STEEL — the default HUD region (resource strip, chip trays, the timeline)
##   BRASS — an edge the frame itself owns (ChromeFrame's molding rings)
enum CasingTone { STEEL, BRASS }

## Which edges of a casing are FREE — drawn, rounded, facing open space. The
## rest are DOCKED: they meet the bezel, so they carry no line of their own and
## their corners go square. Owner ruling 2026-08-25, after spotting that the
## trim overlapped the frame top and bottom but not the sides: "embrace the
## overlap as a type of locked system." A seated panel does not wear its own
## frame on the edges the chassis already holds — the bezel's inner ring IS
## that edge — and it reads square where it seats and round where it doesn't.
enum CasingEdge { NONE = 0, TOP = 1, RIGHT = 2, BOTTOM = 4, LEFT = 8, ALL = 15 }


static func casing_ring_color(tone: int, ring: int, ring_count: int) -> Color:
	if tone == CasingTone.BRASS:
		# Bevel: shadow outside, highlight, mid, shadow innermost — the read
		# that made the frame "approaching brass picture frame or clockwork".
		var bevel := [COLOR_BRASS_SHADOW, COLOR_BRASS_HIGHLIGHT, COLOR_BRASS_MID, COLOR_BRASS_SHADOW]
		return bevel[mini(ring, bevel.size() - 1)]
	# STEEL: a brass shadow ghost outside the steel hairline, which is what
	# ResourcePanel's double-stroke already looked like — promoted to the rule.
	return COLOR_TRIM_LINE if ring == ring_count - 1 else COLOR_BRASS_SHADOW


static func _casing_ring_style(line: Color, radius: int, filled: bool,
		free_edges: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = filled
	style.bg_color = COLOR_TRIM_INK
	style.border_color = line
	style.anti_aliasing = true
	# Width is ALWAYS 1 on a free edge and 0 on a docked one — 2px and 3px stay
	# reserved state cues (HintToast importance, would-fire).
	style.set_border_width(SIDE_TOP, 1 if (free_edges & CasingEdge.TOP) != 0 else 0)
	style.set_border_width(SIDE_RIGHT, 1 if (free_edges & CasingEdge.RIGHT) != 0 else 0)
	style.set_border_width(SIDE_BOTTOM, 1 if (free_edges & CasingEdge.BOTTOM) != 0 else 0)
	style.set_border_width(SIDE_LEFT, 1 if (free_edges & CasingEdge.LEFT) != 0 else 0)
	# A corner is rounded only where two FREE edges meet. One docked edge is
	# enough to square it: that corner is a joint, not a silhouette.
	style.set_corner_radius(CORNER_TOP_LEFT,
		radius if _edges_free(free_edges, CasingEdge.TOP | CasingEdge.LEFT) else 0)
	style.set_corner_radius(CORNER_TOP_RIGHT,
		radius if _edges_free(free_edges, CasingEdge.TOP | CasingEdge.RIGHT) else 0)
	style.set_corner_radius(CORNER_BOTTOM_RIGHT,
		radius if _edges_free(free_edges, CasingEdge.BOTTOM | CasingEdge.RIGHT) else 0)
	style.set_corner_radius(CORNER_BOTTOM_LEFT,
		radius if _edges_free(free_edges, CasingEdge.BOTTOM | CasingEdge.LEFT) else 0)
	return style


static func _edges_free(free_edges: int, pair: int) -> bool:
	return (free_edges & pair) == pair


## Draw a casing. `filled` backs the innermost ring with COLOR_TRIM_INK; pass
## false for a region that must not dim what it frames (the viewport molding).
## `free_edges` is the docking mask — see CasingEdge.
static func draw_casing(ci: CanvasItem, rect: Rect2, tone: int = CasingTone.STEEL,
		rings: int = 2, filled: bool = true, free_edges: int = CasingEdge.ALL) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var n := maxi(rings, 1)
	for i in range(n):
		var step := CASING_RING_STEP * float(i)
		var r := rect.grow(-step)
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			return
		var innermost := i == n - 1
		# Radius shrinks with the inset so corners stay concentric — the bug
		# ChromeFrame carried in its own copy of this loop.
		var radius := maxi(int(round(CASING_RADIUS - step)), 2)
		ci.draw_style_box(
			_casing_ring_style(casing_ring_color(tone, i, n), radius,
				filled and innermost, free_edges), r)


static func create_slot_style(
	bg_color: Color = COLOR_SLOT_EMPTY,
	border_color: Color = Color(0.5, 0.5, 0.5, 0.6),
	border_width: int = 3,
	corner_radius: int = 6,
	content_margin_h: int = 8,
	content_margin_v: int = 4
) -> StyleBoxFlat:
	# # Create a card/slot StyleBoxFlat (smaller margins, subtle border).

	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = content_margin_h
	style.content_margin_right = content_margin_h
	style.content_margin_top = content_margin_v
	style.content_margin_bottom = content_margin_v
	return style


static func create_selection_style(base_style: StyleBoxFlat, selection_color: Color = COLOR_SELECTION) -> StyleBoxFlat:
	# # Create a copy of a style with selection highlight border.

	var style = base_style.duplicate()
	style.border_color = selection_color
	style.border_width_left = 5
	style.border_width_right = 5
	style.border_width_top = 5
	style.border_width_bottom = 5
	return style


# =============================================================================
# BUTTON STYLES
# =============================================================================

static func create_button_style_normal(bg_color: Color) -> StyleBoxFlat:
	# # Create normal button state style.

	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = Color(0.7, 0.7, 0.7, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


static func create_button_style_hover(bg_color: Color) -> StyleBoxFlat:
	# # Create hover button state style (lightened, expanded).

	var style = StyleBoxFlat.new()
	style.bg_color = bg_color.lightened(0.2)
	style.border_color = Color(0.9, 0.9, 0.9, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


static func create_button_style_pressed(bg_color: Color) -> StyleBoxFlat:
	# # Create pressed button state style (darkened).

	var style = StyleBoxFlat.new()
	style.bg_color = bg_color.darkened(0.2)
	style.border_color = Color(0.5, 0.5, 0.5, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


static func create_styled_button(
	text: String,
	bg_color: Color,
	min_size: Vector2 = Vector2(300, 36),
	font_size: int = 16
) -> Button:
	# # Create a fully-styled button with normal/hover/pressed states.

	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.add_theme_font_size_override("font_size", font_size)

	btn.add_theme_stylebox_override("normal", create_button_style_normal(bg_color))
	btn.add_theme_stylebox_override("hover", create_button_style_hover(bg_color))
	btn.add_theme_stylebox_override("pressed", create_button_style_pressed(bg_color))

	return btn


# =============================================================================
# LABEL HELPERS
# =============================================================================

static func create_title_label(
	text: String,
	font_size: int = 20,
	color: Color = COLOR_TEXT_TITLE
) -> Label:
	# # Create a styled title label.

	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


static func create_subtitle_label(
	text: String,
	font_size: int = 14,
	color: Color = COLOR_TEXT_SUBTITLE
) -> Label:
	# # Create a styled subtitle label.

	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


static func create_muted_label(
	text: String,
	font_size: int = 12,
	color: Color = COLOR_TEXT_MUTED
) -> Label:
	# # Create a muted/hint label.

	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


# =============================================================================
# COLOR HELPERS
# =============================================================================

static func get_alignment_color(alignment: float) -> Color:
	# # Get background color based on alignment score (0.0 - 1.0).

	if alignment > 0.7:
		return COLOR_ALIGN_HIGH
	elif alignment > 0.5:
		return COLOR_ALIGN_MED
	elif alignment > 0.3:
		return COLOR_ALIGN_LOW
	else:
		return COLOR_ALIGN_VERY_LOW


static func get_alignment_text_color(alignment: float) -> Color:
	# # Get text color based on alignment score.

	if alignment > 0.7:
		return Color(0.5, 1.0, 0.5)  # Bright green
	elif alignment > 0.5:
		return Color(1.0, 1.0, 0.7)  # Light yellow
	elif alignment > 0.3:
		return Color(1.0, 0.7, 0.5)  # Orange
	else:
		return Color(1.0, 0.5, 0.5)  # Light red


# =============================================================================
# CONTAINER HELPERS
# =============================================================================

static func create_vbox(separation: int = VBOX_SPACING_NORMAL) -> VBoxContainer:
	# # Create VBoxContainer with standard separation.

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", separation)
	return vbox


static func create_hbox(separation: int = HBOX_SPACING_NORMAL) -> HBoxContainer:
	# # Create HBoxContainer with standard separation.

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", separation)
	return hbox


# =============================================================================
# MODAL HELPERS
# =============================================================================

static func create_modal_dimmer(color: Color = COLOR_MODAL_DIMMER) -> ColorRect:
	# # Create a full-screen dimmer background for modal dialogs.

	var dimmer = ColorRect.new()
	dimmer.color = color
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.layout_mode = 1
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	return dimmer


static func create_centered_panel(
	panel_size: Vector2,
	bg_color: Color = COLOR_PANEL_BG,
	border_color: Color = COLOR_PANEL_BORDER
) -> PanelContainer:
	# # Create a centered panel container for modal dialogs.
		# Args:
	# # panel_size: Size of the panel (width, height)
		# bg_color: Background color
		# border_color: Border color

	var panel = PanelContainer.new()
	panel.custom_minimum_size = panel_size
	panel.add_theme_stylebox_override("panel", create_panel_style(bg_color, border_color))

	# Center anchors
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5

	# Offset to center
	panel.offset_left = -panel_size.x / 2
	panel.offset_right = panel_size.x / 2
	panel.offset_top = -panel_size.y / 2
	panel.offset_bottom = panel_size.y / 2
	panel.layout_mode = 1

	return panel


# =============================================================================
# SELECTION HELPERS
# =============================================================================

static func apply_selection_border(
	control: Control,
	selected: bool,
	selection_color: Color = COLOR_SELECTION,
	border_width: int = 4
) -> void:
	# Apply or remove selection border from a control.
	# Works with controls that have a StyleBoxFlat "normal" or "panel" override.

	var style: StyleBoxFlat = null

	# Try to get existing style
	if control is Button:
		style = control.get_theme_stylebox("normal") as StyleBoxFlat
	elif control is PanelContainer:
		style = control.get_theme_stylebox("panel") as StyleBoxFlat

	if not style:
		return

	if selected:
		style.border_color = selection_color
		style.set_border_width_all(border_width)
	else:
		style.border_color = Color(0.5, 0.5, 0.5, 0.6)
		style.set_border_width_all(2)


static func apply_selection_modulate(
	control: Control,
	selected: bool,
	highlight_color: Color = Color(1.3, 1.3, 1.0)
) -> void:
	# # Apply or remove selection highlight via modulate.
		# Simpler alternative to border-based selection.

	if selected:
		control.modulate = highlight_color
	else:
		control.modulate = Color.WHITE


# =============================================================================
# MENU BUTTON HELPERS
# =============================================================================

static func create_menu_button(
	text: String,
	bg_color: Color,
	min_size: Vector2 = Vector2(300, 50),
	font_size: int = 20
) -> Button:
	# # Create a menu-style button (larger than standard buttons).

	return create_styled_button(text, bg_color, min_size, font_size)


# =============================================================================
# HUD HELPERS (shared between SimStatsOverlay, InspectorOverlay, etc.)
# =============================================================================

static func create_hud_label(text: String, color: Color, font_size: int = 0) -> Label:
	# # Create a HUD label (expand-fill, left-aligned). Pass font_size=0 to skip override.

	var label = Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_color_override("font_color", color)
	label.text = text
	if font_size > 0:
		label.add_theme_font_size_override("font_size", font_size)
	return label


static func create_hud_separator() -> HSeparator:
	# # Create a subtle HUD separator line.

	var sep = HSeparator.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.4, 0.4, 0.3)
	sep.add_theme_stylebox_override("separator", style)
	return sep


static func get_speed_fraction(speed: float) -> String:
	# # Convert a decimal time-scale value to a human-readable fraction string.

	var lookup = {
		0.03125: "1/32",
		0.0625: "1/16",
		0.125: "1/8",
		0.25: "1/4",
		0.5: "1/2",
		1.0: "1",
		2.0: "2",
		4.0: "4",
		8.0: "8",
		16.0: "16"
	}
	for key in lookup.keys():
		if abs(speed - key) < 1e-4:
			return lookup[key]
	return ""


static func get_physics_fps_from_farm(farm_node) -> float:
	# # Get physics frames-per-second from a farm's biome_evolution_batcher.

	if not farm_node:
		return 0.0
	if "biome_evolution_batcher" in farm_node:
		var batcher = farm_node.biome_evolution_batcher
		if batcher and "physics_frames_per_second" in batcher:
			return batcher.physics_frames_per_second
	return 0.0


static func get_simulation_speed(farm_node) -> float:
	# # Get quantum time scale from the first available biome.

	if farm_node and "grid" in farm_node and farm_node.grid:
		for biome in farm_node.grid.get_all_biomes().values():
			if not biome:
				continue
			if "quantum_time_scale" in biome:
				return biome.quantum_time_scale
			if biome.has_method("get_quantum_time_scale"):
				return biome.get_quantum_time_scale()
	if farm_node and "quantum_time_scale" in farm_node:
		return farm_node.quantum_time_scale
	return 1.0


static func create_slot_button(
	text: String,
	bg_color: Color = COLOR_SLOT_EMPTY,
	min_size: Vector2 = Vector2(550, 80),
	font_size: int = 18
) -> Button:
	# # Create a slot-style button for save slots, quest slots, etc.

	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.add_theme_font_size_override("font_size", font_size)

	var style_normal = create_slot_style(bg_color)
	btn.add_theme_stylebox_override("normal", style_normal)

	var style_hover = create_slot_style(bg_color.lightened(0.15))
	btn.add_theme_stylebox_override("hover", style_hover)

	var style_pressed = create_slot_style(bg_color.darkened(0.15))
	btn.add_theme_stylebox_override("pressed", style_pressed)

	return btn


# =============================================================================
# SECTION / STAT BAR HELPERS
# =============================================================================

static func create_section_header(
	text: String,
	font_size: int = 13,
	color: Color = COLOR_TEXT_SUBTITLE
) -> Label:
	# # Create a left-aligned section header label.

	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


static func create_stat_bar(
	label_text: String,
	value: float,
	color: Color,
	label_width: int = 55,
	bar_width: int = 100,
	bar_height: int = 14,
	font_size: int = 12
) -> HBoxContainer:
	# # Create a compact labeled progress bar for stats.
		# Returns HBox: [Label] [ColorRect bg > ColorRect fill] [Label percent]

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	# Label
	var label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size.x = label_width
	label.add_theme_font_size_override("font_size", font_size)
	hbox.add_child(label)

	# Bar background
	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0.2, 0.2, 0.2)
	bar_bg.custom_minimum_size = Vector2(bar_width, bar_height)
	hbox.add_child(bar_bg)

	# Bar fill (child of background)
	var bar_fill = ColorRect.new()
	bar_fill.color = color
	bar_fill.name = "Fill"
	bar_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	bar_fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar_bg.add_child(bar_fill)

	# Percentage label
	var pct_label = Label.new()
	pct_label.name = "Percent"
	pct_label.text = "%d%%" % int(value * 100)
	pct_label.custom_minimum_size.x = 35
	pct_label.add_theme_font_size_override("font_size", font_size)
	hbox.add_child(pct_label)

	return hbox


static func update_stat_bar(bar: HBoxContainer, value: float) -> void:
	# # Update a stat bar's fill width and percentage text.

	if not bar or bar.get_child_count() < 3:
		return

	var bar_bg = bar.get_child(1)
	var pct_label = bar.get_child(2)

	# Update fill width
	var fill = bar_bg.get_node_or_null("Fill")
	if fill:
		fill.custom_minimum_size.x = bar_bg.size.x * clamp(value, 0.0, 1.0)

	# Update percentage text
	if pct_label and pct_label is Label:
		pct_label.text = "%d%%" % int(value * 100)


# =============================================================================
# HUD SCAFFOLD
# =============================================================================

static func create_hud_scaffold(
	bg_color: Color = COLOR_HUD_BG,
	border_color: Color = COLOR_PANEL_BORDER,
	padding: int = 8,
	separation: int = 4,
	corner_radius: int = 6
) -> Dictionary:
	# # Create the standard HUD scaffold: PanelContainer > MarginContainer > VBoxContainer.
		# Returns {"panel": PanelContainer, "margin": MarginContainer, "vbox": VBoxContainer}

	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = bg_color
	panel_style.set_border_width_all(2)
	panel_style.border_color = border_color
	panel_style.set_corner_radius_all(corner_radius)
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", padding)
	margin.add_theme_constant_override("margin_top", padding)
	margin.add_theme_constant_override("margin_right", padding)
	margin.add_theme_constant_override("margin_bottom", padding)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", separation)

	margin.add_child(vbox)
	panel.add_child(margin)

	return {"panel": panel, "margin": margin, "vbox": vbox}


static func get_slice_rate_from_farm(farm_node) -> Dictionary:
	if not farm_node or not ("biome_evolution_batcher" in farm_node):
		return {"slices": 0.0, "biomes": 0}
	var batcher = farm_node.biome_evolution_batcher
	if not batcher:
		return {"slices": 0.0, "biomes": 0}
	var phz: float = 0.0
	if "physics_frames_per_second" in batcher:
		phz = float(batcher.physics_frames_per_second)
	var biome_count: int = 0
	if farm_node.has_method("get_all_biomes"):
		biome_count = farm_node.get_all_biomes().size()
	return {"slices": phz, "biomes": biome_count}


static func get_step_dt_per_biome(_farm_node) -> Dictionary:
	return {}
