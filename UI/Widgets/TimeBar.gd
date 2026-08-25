class_name TimeBar
extends Control

## TimeBar — an INERT full-width placeholder for a future history-scrubber
## (2026-08-25, owner ask: "get the UI set up for it during this pass" — not
## the mechanics, just the space). Sits between the resource strip and the
## first top chip band; a thin track across the whole width with a small
## marker near the right edge standing in for "now."
##
## Pure _draw(), NO child nodes, mouse_filter IGNORE — same contract as
## ChromeFrame: a decorative node that can never eat a click. When the real
## scrubber lands, THAT is the moment to deliberately wire real input
## handling — never fake interactivity here first.

const TRACK_COLOR := UIStyleFactory.COLOR_TRIM_LINE
const NOW_MARKER_COLOR := UIStyleFactory.COLOR_ACCENT_GOLD
const NOW_MARKER_RADIUS := 3.0
## Fraction of the track's width where the "now" marker sits (right end).
const NOW_MARKER_FRACTION := 0.96


func _ready() -> void:
	name = "TimeBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var mid_y := size.y * 0.5
	draw_line(Vector2(0.0, mid_y), Vector2(size.x, mid_y), TRACK_COLOR, 1.0, true)
	var now_x := size.x * NOW_MARKER_FRACTION
	draw_circle(Vector2(now_x, mid_y), NOW_MARKER_RADIUS, Color(NOW_MARKER_COLOR, 0.9))
