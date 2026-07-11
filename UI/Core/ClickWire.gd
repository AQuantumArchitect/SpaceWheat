class_name ClickWire
extends RefCounted

## ClickWire — one-line mouse parity for keyboard-first chrome.
##
## Every overlay renders tabs and selectable rows as Labels/containers, which
## default to MOUSE_FILTER_IGNORE — so five surfaces shipped keyboard-only by
## accident (playtest 3 audit). Wiring a click is always the same three lines;
## this is THE one place they live. The callable fires on left-button RELEASE
## (the same edge the EscapeMenu/QuestBoard handlers use).
##
## Usage:
##   ClickWire.attach(label, func(): set_frame("story"))
##   ClickWire.attach(row, _select.bind(i))


static func attach(ctrl: Control, on_click: Callable) -> void:
	if ctrl == null:
		return
	ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	ctrl.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ctrl.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton \
				and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			ctrl.accept_event()
			on_click.call()
	)
