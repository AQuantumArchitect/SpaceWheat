class_name ClickWire
extends RefCounted

## ClickWire — one-line mouse parity for keyboard-first chrome.
##
## Every overlay renders tabs and selectable rows as Labels/containers, which
## default to MOUSE_FILTER_IGNORE — so five surfaces shipped keyboard-only by
## accident (playtest 3 audit). Wiring a click is always the same three lines;
## this is THE one place they live. The callable fires on primary-pointer RELEASE (left button or finger)
## (the same edge the EscapeMenu/QuestBoard handlers use).
##
## Usage:
##   ClickWire.attach(label, func(): set_frame("story"))
##   ClickWire.attach(row, _select.bind(i))


## Primary-pointer helpers: a left-button mouse edge OR a finger touch edge.
## With emulate_mouse_from_touch on (project.godot sets it), one tap arrives as
## BOTH an emulated mouse event and the raw ScreenTouch, in the same frame at
## the same spot; the second is swallowed so a tap fires exactly once.
static var _last_edge_frame: int = -1
static var _last_edge_pressed: bool = false
static var _last_edge_pos: Vector2 = Vector2.INF


static func is_primary_edge(event: InputEvent, pressed: bool) -> bool:
	var pos: Vector2
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT or event.pressed != pressed:
			return false
		pos = event.position
	elif event is InputEventScreenTouch:
		if event.pressed != pressed:
			return false
		pos = event.position
	else:
		return false
	var frame := Engine.get_process_frames()
	if frame == _last_edge_frame and pressed == _last_edge_pressed \
			and pos.distance_to(_last_edge_pos) < 2.0:
		return false
	_last_edge_frame = frame
	_last_edge_pressed = pressed
	_last_edge_pos = pos
	return true


## True on a primary-pointer RELEASE (left mouse button up, or finger lifted).
static func is_release(event: InputEvent) -> bool:
	return is_primary_edge(event, false)


## True on a primary-pointer PRESS (left mouse button down, or finger down).
static func is_press(event: InputEvent) -> bool:
	return is_primary_edge(event, true)


static func attach(ctrl: Control, on_click: Callable) -> void:
	if ctrl == null:
		return
	ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	ctrl.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ctrl.gui_input.connect(func(event: InputEvent) -> void:
		if is_release(event):
			ctrl.accept_event()
			on_click.call()
	)
