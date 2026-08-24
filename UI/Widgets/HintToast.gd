class_name HintToast
extends PanelContainer

## HintToast — small corner pop-up for ephemeral player-facing dialogue.
## Universal grammar: E pauses decay (halts decoherence), F flattens (collapse
## and dismiss). Multiple toasts stack vertically; the topmost is the active
## target for E/F. Importance 1=blue, 2=teal, 3=gold.
##
## Mouse grammar (2026-08-17): the whole panel is a click target — click to
## dismiss. Hovering pauses decay; leaving restarts a fresh hold. Gold
## (importance ≥ 3) toasts PERSIST until explicitly dismissed — story beats
## were fading before a playtester could read them, and the keyboard
## dismissal (E/F) is dead exactly when bursts happen (the Ace hat owns both
## keys during reap).
##
## Routed toasts (2026-08-24): a toast that names a destination ("tap here")
## can carry an on_tap Callable — a body click travels there AND dismisses;
## the ✕ corner becomes the pure-dismiss hitbox (positional test only — every
## child keeps MOUSE_FILTER_IGNORE so the hover grammar is untouched). A
## routeless toast keeps the whole-panel click-to-dismiss exactly as before.

const FADE_IN_SEC := 0.18
const HOLD_SEC := 4.5
const FADE_OUT_SEC := 0.6
const FLATTEN_SEC := 0.15

## Importance at or above which a toast never auto-fades: it waits for a
## click, an F (when the hat leaves F free), or stack-overflow eviction.
const PERSIST_IMPORTANCE := 3

const COLOR_PANEL := Color(0.08, 0.10, 0.16, 0.92)
const COLOR_TEXT := Color(0.92, 0.95, 1.0, 1.0)
const COLOR_PATH := Color(0.7, 0.85, 0.95, 0.7)

## Border color keyed by importance: 1=blue, 2=teal, 3=gold.
const BORDER_COLORS := {
	1: Color(0.55, 0.85, 1.0, 0.85),
	2: Color(0.3, 0.95, 0.75, 0.9),
	3: Color(1.0, 0.82, 0.2, 0.95),
}

var _label: RichTextLabel = null
var _path_label: Label = null
var _close_label: Label = null
var _tween: Tween = null
var _style: StyleBoxFlat = null
var _paused: bool = false
var _persistent: bool = false
var _hovering: bool = false
var _raw_bbcode: String = ""
var _bump_count: int = 1
var _on_tap: Callable = Callable()


func _init() -> void:
	# The panel takes the mouse (children stay IGNORE so it receives every
	# event over the whole toast — the biggest possible dismiss target).
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(280, 0)
	modulate = Color(1, 1, 1, 0)

	_style = StyleBoxFlat.new()
	_style.bg_color = COLOR_PANEL
	_style.border_color = BORDER_COLORS[1]
	_style.set_border_width_all(1)
	_style.set_corner_radius_all(8)
	_style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", _style)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hbox)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.add_theme_color_override("default_color", COLOR_TEXT)
	_label.add_theme_font_size_override("normal_font_size", 13)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_label)

	_path_label = Label.new()
	_path_label.add_theme_font_size_override("font_size", 11)
	_path_label.add_theme_color_override("font_color", COLOR_PATH)
	_path_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_path_label.visible = false
	_path_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_path_label)

	# The "little ✕" — visual invitation only; the whole panel is the hitbox.
	_close_label = Label.new()
	_close_label.text = "✕"
	_close_label.add_theme_font_size_override("font_size", 11)
	_close_label.add_theme_color_override("font_color", COLOR_PATH)
	_close_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_close_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_close_label)

	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func show_text(bbcode: String, importance: int = 1, path: String = "", on_tap: Callable = Callable()) -> void:
	_raw_bbcode = bbcode
	_persistent = importance >= PERSIST_IMPORTANCE
	_on_tap = on_tap
	if _label:
		_label.text = bbcode
	if _style:
		_style.border_color = BORDER_COLORS.get(importance, BORDER_COLORS[1])
		_style.set_border_width_all(2 if importance >= 3 else 1)
	if _path_label:
		if path != "":
			_path_label.text = "[%s]" % path
			_path_label.visible = true
		else:
			_path_label.visible = false
	_run_lifecycle()


## True when this toast never auto-fades (gold story beats). The spawner's
## overflow eviction prefers non-persistent victims.
func is_persistent() -> bool:
	return _persistent


## Same message fired again while this toast is live: fold it in instead of
## stacking a duplicate. Restarts the hold and appends a ×N tally.
func matches(bbcode: String) -> bool:
	return bbcode == _raw_bbcode


func bump() -> void:
	_bump_count += 1
	if _label:
		_label.text = "%s  [color=#aac]×%d[/color]" % [_raw_bbcode, _bump_count]
	if not _paused and not _hovering:
		_run_lifecycle()


## E pressed — halt decoherence; toast stops fading.
func pause_decay() -> void:
	if _paused:
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
	modulate.a = 1.0
	_paused = true


## F pressed (or the toast clicked) — collapse and dismiss now.
func flatten() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, FLATTEN_SEC)
	_tween.tween_callback(queue_free)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		# Routed toast: the body travels, the ✕ corner just dismisses. The
		# rect test keeps children on MOUSE_FILTER_IGNORE (hover grammar).
		var on_close := _close_label != null \
				and _close_label.get_global_rect().has_point(event.global_position)
		if _on_tap.is_valid() and not on_close:
			_on_tap.call()
		flatten()


func _on_mouse_entered() -> void:
	# Hover = read-in-peace: kill the decay without engaging the keyboard-E
	# pause latch (that latch has its own un-pause grammar).
	_hovering = true
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
	modulate.a = 1.0


func _on_mouse_exited() -> void:
	_hovering = false
	# Leaving restarts a FULL fresh hold — generous and simple. The keyboard
	# pause latch outranks it; persistent toasts just stay.
	if not _paused:
		_run_lifecycle()


func _run_lifecycle() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	if _persistent:
		# Gold story beats wait to be read: fade in and stand until a click,
		# an F, or stack-overflow eviction. No interval, no fade-out.
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_SEC)
		return
	# Reading-time hold: ~15 chars/sec over the parsed (bbcode-stripped) text,
	# floored at the classic 4.5s, capped at 12s. E still pauses indefinitely.
	var chars: int = _label.get_parsed_text().length() if _label else 0
	var hold: float = clampf(float(chars) / 15.0, HOLD_SEC, 12.0)
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_SEC)
	_tween.tween_interval(hold)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_SEC)
	_tween.tween_callback(queue_free)
