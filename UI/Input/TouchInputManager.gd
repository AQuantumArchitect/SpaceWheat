extends Node

## TouchInputManager - Unified Touch/Mouse Input Manager for SpaceWheat
## Registered as autoload singleton - access globally via TouchInputManager
## Handles tap, swipe, and drag gestures - mouse and touch unified
## Designed for Godot 4 with clean, minimal complexity

# Gesture detection thresholds (following iOS HIG and Material Design)
const TAP_MAX_DURATION: float = 0.3      # 300ms max for tap
const TAP_MAX_MOVEMENT: float = 30.0     # 30px max movement for tap (matches swipe threshold, no dead zone)
const SWIPE_MIN_DISTANCE: float = 30.0   # 30px minimum swipe distance

# Signals for game systems to connect to
signal tap_detected(position: Vector2)
signal swipe_detected(start_pos: Vector2, end_pos: Vector2, direction: Vector2)
signal drag_started(position: Vector2)
signal drag_moved(position: Vector2)
signal drag_ended(start_pos: Vector2, end_pos: Vector2)

# Single touch tracking (simplified - no multi-touch)
var touch_start_pos: Vector2 = Vector2.ZERO
var touch_current_pos: Vector2 = Vector2.ZERO
var touch_start_time: float = 0.0
var is_touching: bool = false

# PHASE 2 FIX: Spatial hit testing - track if current tap was consumed
var current_tap_consumed: bool = false

# Logging
var _verbose = null


func _ready():
	_verbose = InstrumentLocator.resolve_verbose_config(self)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_handle_touch_start(event.position)
		else:
			_handle_touch_end(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_handle_touch_start(event.position)
		else:
			_handle_touch_end(event.position)

	# Track drag motion while touching
	if is_touching:
		if event is InputEventMouseMotion:
			touch_current_pos = event.position
			drag_moved.emit(event.position)
		elif event is InputEventScreenDrag:
			touch_current_pos = event.position
			drag_moved.emit(event.position)


func _handle_touch_start(position: Vector2) -> void:
	"""Unified touch/mouse start handler."""
	touch_start_pos = position
	touch_current_pos = position
	touch_start_time = Time.get_ticks_msec() / 1000.0
	is_touching = true
	drag_started.emit(position)


func _handle_touch_end(end_pos: Vector2) -> void:
	"""Unified touch/mouse end handler with gesture classification."""
	if not is_touching:
		return

	var duration = (Time.get_ticks_msec() / 1000.0) - touch_start_time
	var distance = touch_start_pos.distance_to(end_pos)

	if distance < TAP_MAX_MOVEMENT and duration < TAP_MAX_DURATION:
		current_tap_consumed = false
		tap_detected.emit(end_pos)
	elif distance >= SWIPE_MIN_DISTANCE:
		var direction = (end_pos - touch_start_pos).normalized()
		swipe_detected.emit(touch_start_pos, end_pos, direction)

	drag_ended.emit(touch_start_pos, end_pos)
	is_touching = false


func is_touch_active() -> bool:
	return is_touching


func get_current_touch_position() -> Vector2:
	if is_touching:
		return touch_current_pos
	return Vector2.ZERO


# PHASE 2 FIX: Spatial hit testing helpers

func consume_current_tap() -> void:
	"""Mark the current tap as consumed (handled by a specific system)

	Call this from tap_detected signal handlers to prevent other handlers
	from also processing the same tap. Implements spatial hierarchy.
	"""
	current_tap_consumed = true


func is_current_tap_consumed() -> bool:
	"""Check if the current tap was already consumed by another handler

	Returns:
		true if tap was consumed, false if still available to handle
	"""
	return current_tap_consumed
const InstrumentLocator = preload("res://Core/Instrumentation/InstrumentLocator.gd")
