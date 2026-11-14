class_name ActFilament
extends PanelContainer

## ActFilament — the objective PORTAL: the game's ONE live ask.
##
## Face law: one readable line (the live ACCEPTED ask). Chapter and "Next"
## live on the Arc. This chip is a tracker. Tap opens a menu only when the
## ask is a fill/claim verb (Commitments). Field work is a label — the
## spotlight names the control. Hides until a quest is accepted.
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
const _GUIDE_FADE = preload("res://Core/Campaign/GuideFade.gd")

const ACCENT := UIStyleFactory.COLOR_ACCENT_GOLD
const POLL_S := 0.5
## The persistent tier's border — HintToast's importance-3 gold, so a gold
## toast landing directly above the banner reads as the same family of card.
const BORDER_GOLD := Color(1.0, 0.82, 0.2, 0.95)
const BANNER_WIDTH := float(UIStyleFactory.TOAST_WIDTH)  # toasts' own width
const BANNER_HEIGHT := 56.0   # one 14px ask + toast 12px margins. Chapter / Next live on Arc.
## Room for the small "[E] more about this" line under the ask. Only claimed
## while the ask has something to open (the toast stack above reserves it).
const HINT_EXTRA := 16.0
const HINT_TEXT := "[E] more about this"
const HINT_COLOR := Color(1.0, 0.82, 0.2, 0.6)
var _overlay_manager: Node = null
var _box: VBoxContainer = null
var _label: Label = null
var _more_label: Label = null    # the small gold "[E] more about this" line
var _detail_label: Label = null  # the opened detail (E pauses and shows it)
var _more_text: String = ""
var _expanded: bool = false
var _accum: float = 0.0
var _text: String = ""
var _ladder: ClickLadder = ClickLadder.new()


## Signature kept for RuntimeMount's existing wiring; the quest manager and
## farm are resolved by UIProgression (one authority), so only the overlay
## manager is retained (tap → Commitments when the ask is a fill).
func setup(_quest_manager: Node, _farm: Node, overlay_manager: Node) -> void:
	add_to_group("objective_chrome")
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
	clip_contents = true  # a long objective crops at the card edge, never bleeds
	add_theme_stylebox_override("panel", UIStyleFactory.create_toast_style(BORDER_GOLD))
	if _box == null:
		# PanelContainer lays out exactly one child inside its content margins.
		_box = VBoxContainer.new()
		_box.name = "BannerLines"
		_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box.add_theme_constant_override("separation", 2)
		add_child(_box)
	if _label == null:
		_label = Label.new()
		_label.name = "ObjectiveLabel"
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 14)
		_label.add_theme_color_override("font_color", ACCENT)
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_box.add_child(_label)
	if _more_label == null:
		_more_label = Label.new()
		_more_label.name = "MoreLabel"
		_more_label.text = HINT_TEXT
		_more_label.add_theme_font_size_override("font_size", 11)
		_more_label.add_theme_color_override("font_color", HINT_COLOR)
		_more_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_more_label.visible = false
		_box.add_child(_more_label)
	if _detail_label == null:
		_detail_label = Label.new()
		_detail_label.name = "DetailLabel"
		_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_label.add_theme_font_size_override("font_size", 12)
		_detail_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 1.0))
		_detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_detail_label.visible = false
		_box.add_child(_detail_label)
	_ladder.has_detail = false
	_ladder.has_scoot = false
	_apply_banner_home()
	_refresh()


func force_refresh() -> void:
	_accum = 0.0
	_refresh()


func _process(delta: float) -> void:
	_accum += delta
	if _accum >= POLL_S:
		_accum = 0.0
		_refresh()


## True when the live ask has something to open. Cosmetic: reads only.
func has_more() -> bool:
	return visible and _more_text != ""


func is_expanded() -> bool:
	return _expanded


## Open the detail card (the caller pauses the sim). Never accepts anything.
func expand_more() -> bool:
	if _expanded or not has_more():
		return false
	_expanded = true
	_apply_more_visuals()
	return true


func collapse_more() -> void:
	if not _expanded:
		return
	_expanded = false
	_apply_more_visuals()


func _apply_more_visuals() -> void:
	if _more_label != null:
		_more_label.visible = has_more() and not _expanded
	if _detail_label != null:
		_detail_label.visible = _expanded
		_detail_label.text = _more_text if _expanded else ""
	if _expanded:
		# Grow upward from the bottom edge, as tall as the text needs.
		clip_contents = false
		grow_vertical = Control.GROW_DIRECTION_BEGIN
	else:
		clip_contents = true
	_apply_rung_visuals()


func _refresh() -> void:
	var obj := UIProgression.objective_text()
	# Hint fading (GuideFade): past the tutorial the banner waits for the
	# player to stall before it speaks. Headless seats keep it always on.
	if obj != "" and not _GUIDE_FADE.speaks(UIProgression._quest_manager(), UIProgression._active_farm()):
		obj = ""
	var more := UIProgression.objective_more() if obj != "" else ""
	if obj == _text and (obj != "") == visible and more == _more_text:
		return
	if obj != _text:
		_ladder.reset()
		_expanded = false
	_text = obj
	_more_text = more
	if more == "":
		_expanded = false
	if obj == "":
		_expanded = false
		visible = false  # nothing to point at (no quest, no offer, no story yet)
		queue_redraw()
		return
	visible = true
	if _label != null:
		_label.text = obj
	_apply_banner_home()
	_apply_more_visuals()
	queue_redraw()


func _banner_height() -> float:
	return BANNER_HEIGHT + (HINT_EXTRA if _more_text != "" else 0.0)


func _apply_rung_visuals() -> void:
	custom_minimum_size = Vector2(BANNER_WIDTH, _banner_height())
	if anchor_top >= 1.0:
		offset_top = offset_bottom - _banner_height()
	else:
		offset_bottom = offset_top + _banner_height()
	var obj := _text
	if not _ladder.has_home:
		tooltip_text = ("Now: %s" % obj) if obj != "" else ""
	elif _ladder.rung == ClickLadder.Rung.FACE:
		var cue := ClickLadder.tap_home(_ladder.home_name)
		tooltip_text = ("Now: %s\n%s" % [obj, cue]) if obj != "" else cue
	else:
		tooltip_text = ClickLadder.TAP_AGAIN_SCOOT


func _apply_banner_home() -> void:
	var home := UIProgression.banner_home()
	_ladder.has_home = home != ""
	_ladder.has_scoot = false
	if home == "commitments":
		_ladder.home_name = "the board"
		_ladder.home_key = "C"
	else:
		_ladder.home_name = "the Arc"
		_ladder.home_key = ""
	# Visible banner always STOP — a label-only ask used to IGNORE and
	# leak taps through to the menu drawn behind this column.
	if visible and _text != "":
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND if _ladder.has_home else Control.CURSOR_ARROW
		)
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_ARROW


func _open_banner_home() -> void:
	if _overlay_manager == null:
		return
	var home := UIProgression.banner_home()
	if home == "commitments" and _overlay_manager.has_method("open_board_on_commitments"):
		_overlay_manager.open_board_on_commitments()
		return
	if home == "arc" and _overlay_manager.has_method("open_controls_on_arc"):
		_overlay_manager.open_controls_on_arc()


func _gui_input(event: InputEvent) -> void:
	if not ((event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed)):
		return
	accept_event()
	if is_inside_tree():
		get_viewport().set_input_as_handled()
	# Mouse parity with E: the small line opens (or closes) the detail.
	if _more_label != null and has_more() and event is InputEventMouseButton \
			and (_expanded or _more_label.get_global_rect().has_point(event.global_position)):
		_toggle_more_via_shell()
		return
	if not _ladder.has_home:
		return
	var action := _ladder.next_action()
	_ladder.commit(action)
	match action:
		"home":
			_open_banner_home()
			_apply_rung_visuals()
		_:
			_ladder.reset()
			_apply_rung_visuals()


func _toggle_more_via_shell() -> void:
	if not is_inside_tree():
		return
	var shells := get_tree().get_nodes_in_group("player_shell")
	if not shells.is_empty() and shells[0].has_method("toggle_objective_more"):
		shells[0].toggle_objective_more()


# (No _draw: the toast form's StyleBoxFlat paints the card now — one recipe
# shared with HintToast instead of a hand-rolled 35%-black rect that could
# drift away from the toasts stacked directly above it.)
