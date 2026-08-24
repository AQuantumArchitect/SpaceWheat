class_name ChromeFrame
extends Control

## ChromeFrame — decorative dressing around the whole game viewport
## (dressing pass 2026-08-24): a soft edge vignette that settles the field
## into the window, then a 1px steel hairline with an inner gold whisper.
##
## Pure _draw(), NO child nodes, mouse_filter IGNORE: a decorative node that
## can never eat a click (the codebase's worst failure class — see
## PlayerShell/SelectionButtonRow/ActionPreviewRow's mouse-filter warnings).
## Absolute z 55: above the action bars (effective ~30) and INFO overlays
## (~51-53), below MODAL/SYSTEM overlays (54-60 — a menu covering a hairline
## is correct), the QERF row (60), the contract corner (130) and toasts (140).
## Never a row — ActionBarManager.get_free_band() (#520) is untouched by
## design: this node has no band and reserves no space.

const EDGE_INSET := 3.0
const GOLD_INSET := 5.0
## Edge vignette: translucent ink fading to nothing over VIGNETTE_DEPTH px.
## One-constant removable — zero VIGNETTE_ALPHA and only the hairlines stay.
const VIGNETTE_DEPTH := 64.0
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
	var steel := Rect2(Vector2(EDGE_INSET, EDGE_INSET),
		size - Vector2(EDGE_INSET, EDGE_INSET) * 2.0)
	var gold := Rect2(Vector2(GOLD_INSET, GOLD_INSET),
		size - Vector2(GOLD_INSET, GOLD_INSET) * 2.0)
	if steel.size.x <= 0.0 or steel.size.y <= 0.0:
		return
	UIStyleFactory.draw_trim(self, steel, Color(),
		UIStyleFactory.COLOR_TRIM_LINE, UIStyleFactory.TRIM_RADIUS, false)
	UIStyleFactory.draw_trim(self, gold, Color(),
		UIStyleFactory.COLOR_TRIM_GOLD, UIStyleFactory.TRIM_RADIUS - 1, false)


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
