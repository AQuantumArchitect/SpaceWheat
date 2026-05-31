class_name FarmView
extends "res://UI/Core/OverlayBase.gd"

## FarmView — sentinel marker for the "play" position on the surface ring.
##
## Lives permanently at the bottom of the overlay stack. Never consumes input
## (handle_input returns false) so gameplay keys fall through to
## QuantumInstrumentInput._unhandled_input() as normal. Never hides the farm.
##
## A very high overlay_tier (100) ensures push() never closes it when real
## overlays are pushed above — they always land on top, not in its place.

func _init() -> void:
	overlay_name = "play"
	overlay_tier = 100  # Above Z_TIER_SYSTEM (18); push() never closes this


func _build_panel() -> void:
	pass  # FarmView renders nothing — skip all panel/dimmer/container construction


func handle_input(_event: InputEvent) -> bool:
	return false  # Always pass through — QII owns gameplay keys via _unhandled_input


func activate() -> void:
	is_active = true
	_on_activated()
	overlay_opened.emit()
	# Omit: visible = true — farm rendering is always on


func deactivate() -> void:
	is_active = false
	_on_deactivated()
	overlay_closed.emit()
	# Omit: visible = false — farm must never hide
