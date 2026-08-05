class_name ActFilament
extends Control

## ActFilament — the objective banner: the game's ONE live objective, ambient
## in the contract corner (phase-2 funnel).
##
## It used to draw the nearest unfired flag's soft-gate score, but that read
## "Act 1 91%" everywhere (five rounds of blind playtesters never found the
## live objective). Now it projects UIProgression.objective_text() — the same
## authority the locked-input redirect toast speaks — as plain screen text
## (a Label), so headless seats read the objective off screen_text too.
## Hides only when there is genuinely nothing to point at (no active quest
## AND no pending offer — the earned endgame quiet); it serves all 8 acts.
## Tap opens X (playthrough → Arc).
##
## Purely cosmetic (anti-gating law) — reads, never writes.

const UIProgression = preload("res://UI/Core/UIProgression.gd")

const ACCENT := Color(1.0, 0.8, 0.3)
const POLL_S := 0.5
const BANNER_WIDTH := 190.0
const BANNER_HEIGHT := 44.0
const TEXT_PAD := 8.0   # inner padding so the wrapped line clears the banner edges

var _overlay_manager: Node = null
var _label: Label = null
var _accum: float = 0.0
var _text: String = ""


## Signature kept for RuntimeMount's existing wiring; the quest manager and
## farm are resolved by UIProgression (one authority), so only the overlay
## manager is retained (tap → X).
func setup(_quest_manager: Node, _farm: Node, overlay_manager: Node) -> void:
	_overlay_manager = overlay_manager
	custom_minimum_size = Vector2(BANNER_WIDTH, BANNER_HEIGHT)
	# RuntimeMount anchors us top-right and sets offset_top/left/right; claim
	# the vertical room the wrapped objective line needs.
	offset_bottom = offset_top + BANNER_HEIGHT
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _label == null:
		_label = Label.new()
		_label.name = "ObjectiveLabel"
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_label.add_theme_font_size_override("font_size", 11)
		_label.add_theme_color_override("font_color", ACCENT)
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# A definite width floor so AUTOWRAP always has a real budget. Without it the label
		# computes its wrap width before the full-rect anchor propagates the parent's 190px,
		# collapses to ~1 char, and renders the objective vertically (one glyph per line).
		_label.custom_minimum_size = Vector2(BANNER_WIDTH - TEXT_PAD, 0.0)
		add_child(_label)
		_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_refresh()


func _process(delta: float) -> void:
	_accum += delta
	if _accum >= POLL_S:
		_accum = 0.0
		_refresh()


func _refresh() -> void:
	var obj := UIProgression.objective_text()
	if obj == _text and (obj != "") == visible:
		return
	_text = obj
	if obj == "":
		visible = false  # nothing to point at (no quest, no offer)
		queue_redraw()
		return
	visible = true
	if _label != null:
		_label.text = obj
	tooltip_text = "Now: %s\nTap for the Arc" % obj
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed):
		if _overlay_manager != null and _overlay_manager.has_method("toggle_overlay"):
			_overlay_manager.toggle_overlay("controls")
			accept_event()


func _draw() -> void:
	# A quiet dark backing so the gold line stays legible over the field.
	if _text != "":
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.35))
