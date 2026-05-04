extends Node

## SurfaceRegistry (autoload)
##
## Tracks the currently mounted Surface and broadcasts snapshots.
##
## Drives:
##   - Z (dynamic legend) — reads the active surface's snapshot to render help
##   - Headless snapshot bus — bots subscribe to `snapshot_changed` to observe
##     any surface they are on, via one uniform channel
##
## Surface subclasses register themselves on activate() and unregister on
## deactivate(). No coupling with OverlayStackManager — a Surface is "mounted"
## whenever its activate() has fired and deactivate() hasn't.
##
## Usage from a Surface:
##   func _on_activated():
##       super._on_activated()
##       SurfaceRegistry.register(self)
##   func _on_deactivated():
##       super._on_deactivated()
##       SurfaceRegistry.unregister(self)
##
## (The Surface base class does this automatically.)

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted whenever the active surface changes (mount, swap, unmount).
## `surface` is the new active Surface, or null if nothing is mounted.
signal active_surface_changed(surface)

## Emitted whenever the active surface's snapshot changes.
## Includes the full snapshot dictionary.
signal snapshot_changed(snapshot: Dictionary)

# =============================================================================
# STATE
# =============================================================================

var _mounted_surfaces: Array = []  ## Stack of Surface instances, topmost = active
var _current_snapshot: Dictionary = {}

# =============================================================================
# PUBLIC API
# =============================================================================

func register(surface) -> void:
	# Register a Surface as mounted. Topmost registration is the active one.
	if surface == null:
		return
	if surface in _mounted_surfaces:
		_mounted_surfaces.erase(surface)
	_mounted_surfaces.append(surface)
	_connect_surface(surface)
	_broadcast_active()


func unregister(surface) -> void:
	# Unregister a Surface. If it was active, the next-most-recent becomes active.
	if surface == null:
		return
	_disconnect_surface(surface)
	_mounted_surfaces.erase(surface)
	_broadcast_active()


func get_active_surface():
	# Return the currently active Surface, or null if none is mounted.
	if _mounted_surfaces.is_empty():
		return null
	return _mounted_surfaces[-1]


func get_topmost_excluding(exclude_surface):
	# Return the topmost mounted Surface other than `exclude_surface`.
	# Z uses this to read the surface it is currently legending for.
	if _mounted_surfaces.is_empty():
		return null
	for i in range(_mounted_surfaces.size() - 1, -1, -1):
		var s = _mounted_surfaces[i]
		if s != exclude_surface:
			return s
	return null


func get_snapshot_beneath(exclude_surface) -> Dictionary:
	# Return the snapshot of the topmost Surface other than `exclude_surface`.
	var s = get_topmost_excluding(exclude_surface)
	if s and s.has_method("get_snapshot"):
		return s.get_snapshot()
	return {}


func get_active_snapshot() -> Dictionary:
	# Return the current active surface's snapshot (duplicate). Empty if none.
	return _current_snapshot.duplicate(true)


func get_active_snapshot_json() -> String:
	# Serialized snapshot for headless consumers.
	return JSON.stringify(_current_snapshot)


func is_mounted(surface) -> bool:
	return surface in _mounted_surfaces


# =============================================================================
# HEADLESS ACTION DISPATCH
# =============================================================================

## Dispatch an action to the currently active surface. Headless entry point.
## `action_id` is one of the ids listed in `available_actions`
## (typically "q", "e", "r", "f", or a surface-specific id).
## Returns true if the action was dispatched.
func dispatch_action(action_id: String, _args: Dictionary = {}) -> bool:
	var active = get_active_surface()
	if active == null:
		return false
	match action_id:
		"q":
			if active.has_method("_on_action_q"):
				active._on_action_q()
				return true
		"e":
			if active.has_method("_on_action_e"):
				active._on_action_e()
				return true
		"r":
			if active.has_method("_on_action_r"):
				active._on_action_r()
				return true
		"f":
			# F = optional 4th verb. Surfaces that bind it override _on_action_f.
			# The legacy `_on_change_frame` fallback has been removed — F is
			# never pagination.
			if active.has_method("_on_action_f"):
				active._on_action_f()
				return true
	# Surface-specific action: look for `_on_action_<id>` or `dispatch_action`
	var custom := "_on_action_" + action_id
	if active.has_method(custom):
		active.call(custom)
		return true
	if active.has_method("dispatch_action"):
		return active.dispatch_action(action_id, _args)
	return false


# =============================================================================
# INTERNAL
# =============================================================================

func _connect_surface(surface) -> void:
	if surface.has_signal("snapshot_changed") and not surface.snapshot_changed.is_connected(_on_surface_snapshot_changed):
		surface.snapshot_changed.connect(_on_surface_snapshot_changed.bind(surface))


func _disconnect_surface(surface) -> void:
	if surface.has_signal("snapshot_changed") and surface.snapshot_changed.is_connected(_on_surface_snapshot_changed):
		surface.snapshot_changed.disconnect(_on_surface_snapshot_changed)


func _on_surface_snapshot_changed(snapshot: Dictionary, surface) -> void:
	# Only propagate snapshots from the currently active surface.
	if surface != get_active_surface():
		return
	_current_snapshot = snapshot.duplicate(true)
	snapshot_changed.emit(_current_snapshot)


func _broadcast_active() -> void:
	var active = get_active_surface()
	if active and active.has_method("get_snapshot"):
		_current_snapshot = active.get_snapshot()
	else:
		_current_snapshot = {}
	active_surface_changed.emit(active)
	snapshot_changed.emit(_current_snapshot)
