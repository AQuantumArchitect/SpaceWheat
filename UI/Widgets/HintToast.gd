class_name HintToast
extends PanelContainer

## HintToast — small corner pop-up for ephemeral player-facing dialogue.
## Universal grammar: E pauses decay (halts decoherence). F FOLLOWS a live
## toast into its named menu (ClickLadder home) and the card stays put so
## its text rides through the overlay. F dismisses only when there is no
## home, or the home is already open. Multiple toasts stack vertically;
## the topmost is the active target for E/F. Importance 1=blue, 2=teal, 3=gold.
##
## Mouse grammar (2026-09-09): ClickLadder. Notifications are a TRACKER + a
## LINK — body clicks climb home → scoot. DETAIL is refused: the how and the
## story body live in the menu the tap opens (Arc / Story / board / Atlas).
## ✕ is always pure-dismiss (positional test only — children stay
## MOUSE_FILTER_IGNORE so the hover grammar is untouched).
## Hovering pauses decay; leaving restarts a fresh hold. Gold (importance ≥ 3)
## toasts PERSIST until explicitly dismissed — story beats were fading before
## a playtester could read them, and the keyboard dismissal (E/F) is dead
## exactly when bursts happen (the Ace hat owns both keys during reap).
##
## A routeless toast with no detail still flattens on the first body click.

const FADE_IN_SEC := 0.18
const HOLD_SEC := 4.5
const FADE_OUT_SEC := 0.6
const FLATTEN_SEC := 0.15

## Importance at or above which a toast never auto-fades: it waits for a
## click, an F (when the hat leaves F free), or stack-overflow eviction.
const PERSIST_IMPORTANCE := 3

const COLOR_PANEL := UIStyleFactory.COLOR_TOAST_PANEL
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
var _detail: String = ""
var _expanded: bool = false
var _bump_count: int = 1
var _on_tap: Callable = Callable()
var _on_scoot: Callable = Callable()
var _ladder: ClickLadder = ClickLadder.new()
## Route/path key this toast climbs toward. Arriving at that home flattens it.
var home_key: String = ""


func _init() -> void:
	# A stable name so click-driving harnesses (mouse_seat clickables) can
	# address a toast as "HintToast" instead of an anonymous @PanelContainer@.
	name = "HintToast"
	# The panel takes the mouse (children stay IGNORE so it receives every
	# event over the whole toast — the biggest possible dismiss target).
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(UIStyleFactory.TOAST_WIDTH, 0)
	modulate = Color(1, 1, 1, 0)

	# ONE recipe, shared with ActFilament's objective banner — the two sit in
	# the same bottom-right column, so their form has to move together.
	_style = UIStyleFactory.create_toast_style(BORDER_COLORS[1])
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


func show_text(bbcode: String, importance: int = 1, path: String = "", on_tap: Callable = Callable(), detail: String = "", on_scoot: Callable = Callable(), home_name: String = "the Arc") -> void:
	_raw_bbcode = bbcode
	_detail = ""  # HUD toasts never reprint the menu. Callers that pass
	              # detail are ignored — tap opens the home instead.
	_expanded = false
	_persistent = importance >= PERSIST_IMPORTANCE
	_on_tap = on_tap
	_on_scoot = on_scoot
	_ladder = ClickLadder.new()
	_ladder.has_detail = false
	_ladder.has_home = _on_tap.is_valid()
	_ladder.has_scoot = _on_scoot.is_valid()
	_ladder.home_name = home_name if home_name != "" else "the Arc"
	_ladder.home_key = ClickLadder.key_for_home(_ladder.home_name)
	if _label:
		_label.text = _face_text()
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


func _follow_cue() -> String:
	# Keyboard F is the toast-follow key (PlayerShell intercepts it) when
	# the field is up. While a menu is open, name the home's own key —
	# Market F is "—" (wave 16 literalist).
	if not (_ladder.has_home and _ladder.rung != ClickLadder.Rung.HOME):
		return ""
	if _overlay_is_open():
		var k := str(_ladder.home_key).strip_edges().to_upper()
		if k == "":
			k = ClickLadder.key_for_home(_ladder.home_name)
		if k != "":
			return "[%s] opens %s" % [k, _ladder.home_name]
	# Wave 19: do not print [F] opens Arc while Ace F is Explore.
	if not owns_f():
		return ""
	return "[F] opens %s" % _ladder.home_name


func _overlay_is_open() -> bool:
	var ml := Engine.get_main_loop()
	if not (ml is SceneTree):
		return false
	var shells := (ml as SceneTree).get_nodes_in_group("player_shell")
	if shells.is_empty():
		return false
	var shell = shells[0]
	if shell == null or not ("overlay_stack" in shell) or shell.overlay_stack == null:
		return false
	return shell.overlay_stack.has_method("is_empty") and not bool(shell.overlay_stack.is_empty())


func _face_text() -> String:
	var cue := _follow_cue()
	if cue == "":
		cue = _ladder.prompt()
	if cue == "":
		return _raw_bbcode
	return "%s\n[color=#aac]%s[/color]" % [_raw_bbcode, cue]


func is_expanded() -> bool:
	return _expanded


func expand() -> void:
	if _expanded or _detail == "":
		return
	_expanded = true
	_persistent = true
	_refresh_body()
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
	modulate.a = 1.0


func _refresh_body() -> void:
	if _label == null:
		return
	var cue := _follow_cue()
	if cue == "":
		cue = _ladder.prompt()
	var cue_line := ("\n[color=#aac]%s[/color]" % cue) if cue != "" else ""
	if _expanded and _detail != "":
		_label.text = "%s\n\n%s%s" % [_raw_bbcode, _detail, cue_line]
	elif cue != "":
		_label.text = "%s\n[color=#aac]%s[/color]" % [_raw_bbcode, cue]
	else:
		_label.text = _raw_bbcode


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


## True only when F would open this toast's named menu. Refusal toasts
## ("F explores first") have no home — Ace F must still Explore
## (wave 12 earnest: any live toast ate F and the first plot never woke).
func owns_f() -> bool:
	# Wave 16: Market F is "—" and OverlayBase ate F before follow
	# (`[F] opens Self` vs `nothing on F here`). While a menu is up, F is
	# that menu's verb — the toast names the home's own key instead.
	if _overlay_is_open():
		return false
	# Wave 19: Arc toast [F] vs Ace [F] Explore on an unbound 🌱 plot.
	# Field Explore wins; follow can wait. Do not steal the expedition.
	var UIProgression = load("res://UI/Core/UIProgression.gd")
	if UIProgression != null and UIProgression.ace_f_would_explore():
		return false
	return _ladder.has_home and _ladder.rung != ClickLadder.Rung.HOME


## Ace F chip must match the intercept (wave 13: [F] opens the Arc vs
## [F] Fast-Fwd). Do not change what F fires — PlayerShell already follows.
func f_chip_label() -> String:
	if not owns_f():
		return ""
	var n := str(_ladder.home_name).strip_edges()
	if n.to_lower().begins_with("the "):
		n = n.substr(4)
	if n == "":
		return "Arc"
	return n[0].to_upper() + n.substr(1)


## Keyboard F — open this toast's home and KEEP the card. The literalist
## walks the menu with the side text still in view. Does not accept, fill,
## or apply a gate; it only opens the advertised surface. Dismisses when
## there is no home left to open.
func follow() -> void:
	if owns_f():
		_ladder.commit("home")
		if _on_tap.is_valid():
			_on_tap.call()
		_persistent = true
		_refresh_body()
		return
	flatten()


## F pressed with nothing to follow, or the ✕ — collapse and dismiss now.
func flatten() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, FLATTEN_SEC)
	_tween.tween_callback(queue_free)


func _on_gui_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed)
	if not tapped:
		return
	accept_event()
	if is_inside_tree():
		get_viewport().set_input_as_handled()
	# Routed toast: the body travels, the ✕ corner just dismisses. The
	# rect test keeps children on MOUSE_FILTER_IGNORE (hover grammar).
	var on_close := _close_label != null \
			and event is InputEventMouseButton \
			and _close_label.get_global_rect().has_point(event.global_position)
	if on_close:
		flatten()
		return
	# ClickLadder: home → scoot. A routeless toast flattens. DETAIL is
	# never a rung on a notification.
	var action := _ladder.next_action()
	_ladder.commit(action)
	match action:
		"expand":
			expand()
		"home":
			if _on_tap.is_valid():
				_on_tap.call()
			if not _ladder.has_scoot:
				flatten()
			else:
				_persistent = true
				_refresh_body()
		"scoot":
			if _on_scoot.is_valid():
				_on_scoot.call()
			flatten()
		_:
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
