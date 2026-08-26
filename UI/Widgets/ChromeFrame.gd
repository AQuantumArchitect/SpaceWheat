class_name ChromeFrame
extends Control

## ChromeFrame — decorative dressing around the whole game viewport.
## Border-weight pass (2026-08-24, owner ask: "approaching brass picture frame
## or clockwork machinery"): a soft edge vignette that settles the field into
## the window, then a beveled BRASS MOLDING — several thin concentric strokes
## stepping dark→bright→mid→dark, which reads as a raised picture-frame edge —
## plus a small rivet ornament at each corner (the "clockwork" read).
##
## Pure _draw(), NO child nodes, mouse_filter IGNORE: a decorative node that
## can never eat a click (the codebase's worst failure class — see
## PlayerShell/SelectionButtonRow/ActionPreviewRow's mouse-filter warnings).
## Absolute z 55: above the action bars (effective ~30) and INFO overlays
## (~51-53), below MODAL/SYSTEM overlays (54-60 — a menu covering a hairline
## is correct), the QERF row (60), the contract corner (130) and toasts (140).
## Never a row — ActionBarManager.get_free_band() (#520) is untouched by
## design: this node has no band and reserves no space.
##
## Every ring of the molding still draws at the reserved 1px width
## (create_trim_style/draw_trim's own hard-coded set_border_width_all(1)) — the
## bolder read comes from LAYERING rings into a bevel, not from widening any
## single stroke past what 2px (toast importance) / 3px (would-fire) mean
## elsewhere in the HUD.

## Molding rings, outer → inner: the stepping dark→bright→mid→dark is what
## reads as a bevel rather than a flat line.
const MOLD_OUTER_INSET := 4.0
## Four layered 1px rings — the bevel that reads "brass picture frame" without
## widening any single stroke past the reserved 1px (2px/3px are state cues).
## The tone sequence lives in UIStyleFactory.casing_ring_color now, with every
## other casing's, so the whole HUD re-skins from one place.
const MOLD_RING_COUNT := 4

## Corner rivets: a small circle plus radiating ticks (the "clockwork" read),
## centered inside the molding band.
const RIVET_INSET := 9.0
const RIVET_RADIUS := 4.0
const RIVET_TICK_LEN := 6.0
const RIVET_TICK_COUNT := 6

## Edge vignette: translucent ink fading to nothing over VIGNETTE_DEPTH px.
## One-constant removable — zero VIGNETTE_ALPHA and only the molding stays.
const VIGNETTE_DEPTH := 56.0
const VIGNETTE_ALPHA := 0.14
const VIGNETTE_INK := Color(0.03, 0.04, 0.06)


func _ready() -> void:
	name = "ChromeFrame"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_as_relative = false
	z_index = 55
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_draw_vignette()
	_draw_molding()
	_draw_corner_rivet(Vector2(RIVET_INSET, RIVET_INSET))
	_draw_corner_rivet(Vector2(size.x - RIVET_INSET, RIVET_INSET))
	_draw_corner_rivet(Vector2(RIVET_INSET, size.y - RIVET_INSET))
	_draw_corner_rivet(Vector2(size.x - RIVET_INSET, size.y - RIVET_INSET))


func _draw_molding() -> void:
	# The molding IS a casing — the bevel this frame wants is exactly what
	# draw_casing draws in BRASS tone, and routing through it fixed a bug this
	# loop carried: every ring used the same corner radius, so the inner rings'
	# corners were never concentric with the outer ones. Unfilled: the frame
	# must not dim the viewport it surrounds.
	UIStyleFactory.draw_casing(self, Rect2(Vector2(MOLD_OUTER_INSET, MOLD_OUTER_INSET),
		size - Vector2(MOLD_OUTER_INSET, MOLD_OUTER_INSET) * 2.0),
		UIStyleFactory.CasingTone.BRASS, MOLD_RING_COUNT, false)


func _draw_corner_rivet(center: Vector2) -> void:
	draw_circle(center, RIVET_RADIUS, UIStyleFactory.COLOR_BRASS_SHADOW)
	draw_arc(center, RIVET_RADIUS, 0.0, TAU, 12, UIStyleFactory.COLOR_BRASS_HIGHLIGHT, 1.0, true)
	for i in range(RIVET_TICK_COUNT):
		var ang := TAU * float(i) / float(RIVET_TICK_COUNT)
		var dir := Vector2(cos(ang), sin(ang))
		draw_line(center + dir * RIVET_RADIUS, center + dir * (RIVET_RADIUS + RIVET_TICK_LEN),
			UIStyleFactory.COLOR_BRASS_MID, 1.0, true)


func _draw_vignette() -> void:
	if VIGNETTE_ALPHA <= 0.0:
		return
	var d := minf(VIGNETTE_DEPTH, minf(size.x, size.y) * 0.25)
	var outer := Color(VIGNETTE_INK, VIGNETTE_ALPHA)
	var inner := Color(VIGNETTE_INK, 0.0)
	var w := size.x
	var h := size.y
	# Four edge quads, outer edge tinted → inner edge clear; the corners
	# overlap two quads and read a touch darker, which is the vignette shape.
	_edge_quad(Vector2(0, 0), Vector2(w, 0), Vector2(w, d), Vector2(0, d), outer, inner)
	_edge_quad(Vector2(0, h), Vector2(w, h), Vector2(w, h - d), Vector2(0, h - d), outer, inner)
	_edge_quad(Vector2(0, 0), Vector2(0, h), Vector2(d, h), Vector2(d, 0), outer, inner)
	_edge_quad(Vector2(w, 0), Vector2(w, h), Vector2(w - d, h), Vector2(w - d, 0), outer, inner)


func _edge_quad(a: Vector2, b: Vector2, c: Vector2, d2: Vector2,
		outer: Color, inner: Color) -> void:
	# a,b on the screen edge (outer tint); c,d2 inward (clear).
	draw_polygon(PackedVector2Array([a, b, c, d2]),
		PackedColorArray([outer, outer, inner, inner]))
