class_name TimeBar
extends Control

## TimeBar — the full-width timeline strip under the resource bar.
##
## Scaffolded inert 2026-08-25 ("get the UI set up for it during this pass" —
## not the mechanics). Same day, second pass: the transport controls moved IN.
## The ⏪ ⏸ ⏩ chips (ClockSpeedRow, positioned into this band by
## ActionBarManager) now ride the track's left end, which is both the owner's
## ask — "the time controls need to start getting integrated into the timebar"
## — and what un-crowded the top-right corner, since the clock chips used to
## own a whole top band up there.
##
## What is still SCAFFOLD: the track itself. The ticks are evenly spaced
## chrome, not real keyframes, and the gold "now" head is pinned to the right
## end rather than tracking a cursor. Nothing here reads or writes sim time —
## when the real scrubber lands, THAT is the moment to wire input, and the
## first honest change is `_ticks_for()` answering from history instead of
## from a constant.
##
## Pure _draw(), NO child nodes, mouse_filter IGNORE — same contract as
## ChromeFrame: this node can never eat a click. The chips that sit on the
## track are their own Controls with their own hitboxes, parented elsewhere.

const TRACK_COLOR := UIStyleFactory.COLOR_TRIM_LINE
const TICK_COLOR := Color(UIStyleFactory.COLOR_TRIM_LINE, 0.22)
const NOW_MARKER_COLOR := UIStyleFactory.COLOR_ACCENT_GOLD
const NOW_MARKER_RADIUS := 3.0
## Spacing between tick marks, in px — a regular beat that reads as "this is a
## timeline," not as data. Real keyframes replace them later.
const TICK_SPACING := 44.0
const TICK_HEIGHT := 4.0
## Clearance between the casing's inner ring and the track it frames.
const TRACK_INSET := 10.0
## How far in from the right edge the "now" head sits. The future is off the
## right end of the strip; the past runs left.
const NOW_MARKER_INSET := 8.0


func _ready() -> void:
	name = "TimeBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	# A DOCKED PANEL, seated between the chassis's two side rails: left and
	# right meet the bezel and carry no line, top and bottom face open space and
	# do. Square corners throughout, because no corner here is a free-to-free
	# meeting — that squareness IS the "locked" read the owner asked for.
	# It boxes the transport chips too: ClockSpeedRow declines its own tray for
	# exactly this reason.
	UIStyleFactory.draw_casing(self, Rect2(Vector2.ZERO, size),
		UIStyleFactory.CasingTone.STEEL, 2, true,
		UIStyleFactory.CasingEdge.TOP | UIStyleFactory.CasingEdge.BOTTOM)
	var mid_y := roundf(size.y * 0.5)
	var track_left := TRACK_INSET
	var track_right := size.x - TRACK_INSET
	if track_right <= track_left:
		return
	draw_line(Vector2(track_left, mid_y), Vector2(track_right, mid_y), TRACK_COLOR, 1.0, true)
	var x := track_left + TICK_SPACING
	while x < track_right - NOW_MARKER_INSET:
		draw_line(Vector2(x, mid_y - TICK_HEIGHT), Vector2(x, mid_y + TICK_HEIGHT),
			TICK_COLOR, 1.0, true)
		x += TICK_SPACING
	var now_x := track_right - NOW_MARKER_INSET
	draw_circle(Vector2(now_x, mid_y), NOW_MARKER_RADIUS, Color(NOW_MARKER_COLOR, 0.9))
