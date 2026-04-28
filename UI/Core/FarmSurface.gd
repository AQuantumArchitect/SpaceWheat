class_name FarmSurface
extends Node

## FarmSurface - Snapshot contract for the live farm instrument.
##
## The farm is the live center, not an overlay. This node is a headless
## Surface-shaped participant that mirrors the farm's current plane/frame/focus
## and registers with SurfaceRegistry so Z (dynamic legend) and headless
## consumers can observe the live instrument through the same contract as any
## other surface (`02_farm_instrument_surface_specifics.md`).
##
## Usage:
##   var farm_surface = FarmSurface.new()
##   farm_surface.bind(instrument, active_biome_manager)
##   add_child(farm_surface)
##   farm_surface.mount()   # register with SurfaceRegistry
##   # ...
##   farm_surface.unmount() # unregister when another surface becomes primary
##
## The farm surface is always eligible to be the active surface. When an
## overlay is pushed (B, N, V, C, M, Z, X) it becomes the topmost registered
## surface and takes precedence; FarmSurface remains mounted beneath it.

const PlaneRegistryRef := preload("res://Core/GameState/PlaneRegistry.gd")

# =============================================================================
# SIGNALS
# =============================================================================

signal snapshot_changed(snapshot: Dictionary)

# =============================================================================
# CONTRACT FIELDS
# =============================================================================

const SURFACE_ID := "farm"

var plane_id: String = PlaneRegistryRef.PLANE_PROBE
var frame_id: String = PlaneRegistryRef.FRAME_EXPLORE
var context_id: String = ""  ## active biome name
var object_focus: Dictionary = {"id": null, "type": null}

# =============================================================================
# STATE
# =============================================================================

var _instrument = null  ## QuantumInstrument
var _active_biome_mgr: Node = null
var _tool_input: Node = null
var _mounted: bool = false

# =============================================================================
# PUBLIC API
# =============================================================================

func bind(instrument, active_biome_mgr: Node) -> void:
	"""Wire to live instrument + active biome manager."""
	_instrument = instrument
	_active_biome_mgr = active_biome_mgr
	if _active_biome_mgr and _active_biome_mgr.has_signal("active_biome_changed"):
		if not _active_biome_mgr.active_biome_changed.is_connected(_on_active_biome_changed):
			_active_biome_mgr.active_biome_changed.connect(_on_active_biome_changed)
	_refresh_context()


func bind_tool_input(tool_input: Node) -> void:
	_tool_input = tool_input
	if _tool_input and _tool_input.has_method("get_current_frame"):
		_sync_from_frame(_tool_input.get_current_frame())
	elif _tool_input and _tool_input.has_method("get_current_tool_group"):
		_sync_from_tool_group(_tool_input.get_current_tool_group())
	if _tool_input and _tool_input.has_signal("frame_changed"):
		if not _tool_input.frame_changed.is_connected(_on_frame_changed):
			_tool_input.frame_changed.connect(_on_frame_changed)
	elif _tool_input and _tool_input.has_signal("tool_group_changed"):
		if not _tool_input.tool_group_changed.is_connected(_on_tool_group_changed):
			_tool_input.tool_group_changed.connect(_on_tool_group_changed)


func mount() -> void:
	if _mounted:
		return
	_mounted = true
	var registry := _surface_registry()
	if registry:
		registry.register(self)
	_emit_snapshot()


func unmount() -> void:
	if not _mounted:
		return
	_mounted = false
	var registry := _surface_registry()
	if registry:
		registry.unregister(self)


func set_plane(new_plane_id: String) -> void:
	if new_plane_id == plane_id or not PlaneRegistryRef.PLANES.has(new_plane_id):
		return
	plane_id = new_plane_id
	var frames: Array = PlaneRegistryRef.get_frames(plane_id)
	if not frames.has(frame_id):
		frame_id = frames[0] if not frames.is_empty() else ""
	_emit_snapshot()


func set_frame(new_frame_id: String) -> void:
	if new_frame_id == frame_id:
		return
	frame_id = new_frame_id
	_emit_snapshot()


func cycle_frame(step: int = 1) -> void:
	var next := PlaneRegistryRef.cycle_frame(plane_id, frame_id, step)
	if next != "":
		set_frame(next)


func set_object_focus(id, type) -> void:
	if id == object_focus.get("id") and type == object_focus.get("type"):
		return
	object_focus = {"id": id, "type": type}
	_emit_snapshot()


# =============================================================================
# SNAPSHOT
# =============================================================================

func get_snapshot() -> Dictionary:
	return {
		"surface_id": SURFACE_ID,
		"frame_id": frame_id,
		"context_id": context_id,
		"plane_id": plane_id,
		"object_focus": object_focus.duplicate(true),
		"visible_data": _get_visible_data(),
		"available_actions": get_available_actions(),
		"transitions": get_transitions(),
	}


func get_available_actions() -> Array:
	var actions: Array = PlaneRegistryRef.get_actions(plane_id, frame_id)
	# F: change frame within plane
	actions.append({
		"action_id": "f",
		"family": "change_frame",
		"target_type": null,
		"enabled": true,
		"cost": {},
		"label": "Cycle Frame",
		"action": "cycle_frame",
	})
	return actions


func get_transitions() -> Array:
	return [
		{"surface_id": "B", "reason": "inspect local terminal / build lens"},
		{"surface_id": "N", "reason": "biome state readout"},
		{"surface_id": "V", "reason": "symbol atlas"},
		{"surface_id": "C", "reason": "curate offers"},
		{"surface_id": "M", "reason": "global map / meta"},
	]


# =============================================================================
# INTERNAL
# =============================================================================

func _get_visible_data() -> Dictionary:
	var plane_def: Dictionary = PlaneRegistryRef.get_plane(plane_id)
	return {
		"active_biome_id": context_id,
		"plane": {
			"id": plane_id,
			"label": plane_def.get("label", plane_id),
			"frames": plane_def.get("frames", []),
		},
		"frame": {
			"id": frame_id,
			"label": PlaneRegistryRef.frame_label(frame_id),
		},
	}


func _sync_from_frame(frame_name: String) -> void:
	var new_plane: String = PlaneRegistryRef.plane_id_from_frame(frame_name)
	if new_plane != "":
		plane_id = new_plane
		var frames: Array = PlaneRegistryRef.get_frames(plane_id)
		if not frames.has(frame_id):
			frame_id = frames[0] if not frames.is_empty() else ""


func _sync_from_tool_group(group: int) -> void:
	"""Legacy int-keyed entry point — translates via PlaneRegistry's int map."""
	var new_plane: String = PlaneRegistryRef.plane_id_from_tool_group(group)
	if new_plane != "":
		plane_id = new_plane
		var frames: Array = PlaneRegistryRef.get_frames(plane_id)
		if not frames.has(frame_id):
			frame_id = frames[0] if not frames.is_empty() else ""


func _refresh_context() -> void:
	if _active_biome_mgr:
		context_id = _active_biome_mgr.get_active_biome()
	elif _instrument and "current_biome" in _instrument:
		context_id = _instrument.current_biome


func _on_active_biome_changed(new_biome: String, _old_biome: String) -> void:
	context_id = new_biome
	_emit_snapshot()


func _on_frame_changed(frame_name: String) -> void:
	_sync_from_frame(frame_name)
	_emit_snapshot()


func _on_tool_group_changed(group: int) -> void:
	_sync_from_tool_group(group)
	_emit_snapshot()


func _emit_snapshot() -> void:
	if not _mounted:
		return
	snapshot_changed.emit(get_snapshot())


func _surface_registry() -> Node:
	var root := get_tree().root if is_inside_tree() else null
	if root and root.has_node("SurfaceRegistry"):
		return root.get_node("SurfaceRegistry")
	return null
