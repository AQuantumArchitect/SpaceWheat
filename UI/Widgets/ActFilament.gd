class_name ActFilament
extends PanelContainer

## ActFilament — the objective PORTAL: the game's ONE live objective plus the
## next door behind it, ambient in the contract corner (phase-2 funnel).
##
## It used to draw the nearest unfired flag's soft-gate score, but that read
## "Act 1 91%" everywhere (five rounds of blind playtesters never found the
## live objective). Now it projects UIProgression.objective_text() — the same
## authority the locked-input redirect toast speaks — as plain screen text
## (a Label), so headless seats read the objective off screen_text too.
## Under it, a muted "Next:" line names the nearest reachable unfired beat
## (UIProgression.next_objective_title) — the owner's ask (2026-08-17): the
## objectives were "tucked away and you'd have to know to go hunt" — so the
## portal shows where the road goes, not just where your feet are.
## Hides only when there is genuinely nothing to point at (no active quest
## AND no pending offer — the earned endgame quiet); it serves all 8 acts.
## Tap lands directly on the Arc tab (X → I in one touch —
## OverlayManager.open_controls_on_arc), the mouse door the parity audits
## kept flagging.
##
## Purely cosmetic (anti-gating law) — reads, never writes.
##
## FORM (2026-08-25, owner ask): "the objective and the toast should have a
## pleasant harmony in form … maybe the stable objective hint can be a stable
## toast looking item?" So it IS one: a PanelContainer wearing
## UIStyleFactory.create_toast_style — the same ink, radius and padding every
## HintToast wears, gold-bordered because gold is the persistent tier. It sits
## at the bottom of the same bottom-right column the toasts stack up from, and
## reads as the one card in that column that never fades.

const UIProgression = preload("res://UI/Core/UIProgression.gd")

const ACCENT := UIStyleFactory.COLOR_ACCENT_GOLD
const ACT_MUTED := Color(0.78, 0.72, 0.45, 0.9)
const NEXT_MUTED := Color(0.65, 0.62, 0.52, 0.85)
const POLL_S := 0.5
## The persistent tier's border — HintToast's importance-3 gold, so a gold
## toast landing directly above the banner reads as the same family of card.
const BORDER_GOLD := Color(1.0, 0.82, 0.2, 0.95)
const BANNER_WIDTH := float(UIStyleFactory.TOAST_WIDTH)  # toasts' own width
const BANNER_HEIGHT := 92.0   # act line + wrapped objective + the Next line,
                              # plus the toast form's 12px content margins —
                              # the old 72 clipped the Next line off its own box.
var _overlay_manager: Node = null
var _box: VBoxContainer = null
var _label: Label = null
var _act_label: Label = null
var _next_label: Label = null
var _accum: float = 0.0
var _text: String = ""
var _act_text: String = ""
var _next_text: String = ""


## Signature kept for RuntimeMount's existing wiring; the quest manager and
## farm are resolved by UIProgression (one authority), so only the overlay
## manager is retained (tap → Arc).
func setup(_quest_manager: Node, _farm: Node, overlay_manager: Node) -> void:
	_overlay_manager = overlay_manager
	custom_minimum_size = Vector2(BANNER_WIDTH, BANNER_HEIGHT)
	# RuntimeMount anchors us to a screen corner and sets left/right plus
	# whichever vertical offset is the FIXED edge for that corner (offset_top
	# when top-anchored, offset_bottom when bottom-anchored — bottom-RIGHT
	# since 2026-08-25: bottom-left put the column straight over the field's
	# portal rail). Derive the other vertical offset from whichever one is
	# fixed, so the banner claims BANNER_HEIGHT of room in either corner.
	if anchor_top >= 1.0:
		offset_top = offset_bottom - BANNER_HEIGHT
	else:
		offset_bottom = offset_top + BANNER_HEIGHT
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND  # tap opens the Arc
	clip_contents = true  # a long objective crops at the card edge, never bleeds
	add_theme_stylebox_override("panel", UIStyleFactory.create_toast_style(BORDER_GOLD))
	if _box == null:
		# PanelContainer lays out exactly one child inside its content margins,
		# so the three lines ride a VBox — no hand-placed offsets to go stale
		# when the card's padding or width changes.
		_box = VBoxContainer.new()
		_box.name = "BannerLines"
		_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box.add_theme_constant_override("separation", 2)
		add_child(_box)
	if _act_label == null:
		# The ambient campaign position: "Act 5 · Chapter IV — …", always on
		# screen for the whole run (the acts were invisible before this line).
		_act_label = Label.new()
		_act_label.name = "ActLabel"
		_act_label.add_theme_font_size_override("font_size", 9)
		_act_label.add_theme_color_override("font_color", ACT_MUTED)
		_act_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_act_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_box.add_child(_act_label)
	if _label == null:
		_label = Label.new()
		_label.name = "ObjectiveLabel"
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_label.add_theme_font_size_override("font_size", 11)
		_label.add_theme_color_override("font_color", ACCENT)
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_box.add_child(_label)
	if _next_label == null:
		# "Next: The Village Stirs" — the road ahead, one door, muted. Reads
		# from the same frontier rule the Arc tab sorts by; tap for the rest.
		_next_label = Label.new()
		_next_label.name = "NextLabel"
		_next_label.add_theme_font_size_override("font_size", 9)
		_next_label.add_theme_color_override("font_color", NEXT_MUTED)
		_next_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_next_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_box.add_child(_next_label)
	_refresh()


func _process(delta: float) -> void:
	_accum += delta
	if _accum >= POLL_S:
		_accum = 0.0
		_refresh()


func _refresh() -> void:
	var obj := UIProgression.objective_text()
	var act_line := _act_line_now()
	var next_line := _next_line_now()
	if obj == _text and act_line == _act_text and next_line == _next_text \
			and (obj != "" or act_line != "") == visible:
		return
	_text = obj
	_act_text = act_line
	_next_text = next_line
	if obj == "" and act_line == "":
		visible = false  # nothing to point at (no quest, no offer, no story yet)
		queue_redraw()
		return
	visible = true
	if _act_label != null:
		_act_label.text = act_line
	if _label != null:
		_label.text = obj
	if _next_label != null:
		_next_label.text = next_line
		_next_label.visible = next_line != ""
	tooltip_text = ("Now: %s\nTap for the Arc" % obj) if obj != "" else "Tap for the Arc"
	queue_redraw()


## "Act 5 · Chapter IV — The Empire & The Escape", "" before the story starts.
func _act_line_now() -> String:
	var qm := UIProgression._quest_manager()
	var gsm := get_node_or_null("/root/GameStateManager")
	var farm = gsm.get_active_farm() if (gsm and gsm.has_method("get_active_farm")) else null
	if qm == null or farm == null or not ("story_flags_fired" in farm) \
			or not qm.has_method("get_all_story_flags"):
		return ""
	if farm.story_flags_fired.is_empty():
		return ""
	var act := StoryAtlas.current_act(farm.story_flags_fired, qm.get_all_story_flags())
	return "Act %d · %s" % [act, StoryAtlas.chapter_for_act(act)]


## "Next: <nearest reachable unfired beat>", "" when nothing is ahead. Skipped
## when it would just repeat the live objective's own beat name.
func _next_line_now() -> String:
	var title := UIProgression.next_objective_title()
	if title == "":
		return ""
	return "Next: %s" % title


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed):
		if _overlay_manager != null and _overlay_manager.has_method("open_controls_on_arc"):
			_overlay_manager.open_controls_on_arc()
			accept_event()
		elif _overlay_manager != null and _overlay_manager.has_method("toggle_overlay"):
			_overlay_manager.toggle_overlay("controls")
			accept_event()


# (No _draw: the toast form's StyleBoxFlat paints the card now — one recipe
# shared with HintToast instead of a hand-rolled 35%-black rect that could
# drift away from the toasts stacked directly above it.)
