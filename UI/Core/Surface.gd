class_name Surface
extends "res://UI/Core/OverlayBase.gd"

## Surface - Base class for refactored surface overlays.
##
## Extends OverlayBase with the shared conceptual UI contract described in
## `llm_inbox/spacewheat_surface_refactor/spacewheat_surface_specifics_v2_md_bundle/`.
##
## Every surface exposes a stable snapshot:
##   { surface_id, frame_id, context_id, object_focus, visible_data,
##     available_actions, transitions }
##
## This contract is shared between the human UI and headless players.
##
## Subclasses fill in:
##   - surface_id (one of "farm", "B", "N", "V", "C", "M", "Z", "X")
##   - frame_ids  (ordered page list; current page lives in frame_id)
##   - get_visible_data() -> Dictionary
##   - get_available_actions() -> Array[Dictionary]
##   - get_transitions() -> Array[Dictionary]
##
## Key bindings (post-refactor):
##   - `[` / `]`  — cycle frame_ids (universal tab cycle; handled by PlayerShell
##     when a surface is open). Surfaces may override `cycle_frame()` if they
##     paginate within a single frame.
##   - `,` / `.`  — cycle top-level menu overlays (PlayerShell).
##   - TYUI...    — direct-jump to a specific frame, if the surface wires them
##   - Q / E / R  — surface-specific verb actions
##   - F          — optional 4th verb on the current item, parallel to Q/E/R.
##                  Use only when an overlay legitimately needs a 4th mode
##                  (rare; default empty). NEVER pagination, NEVER frame
##                  cycling — that's `[`/`]` and `,`/`.`.
##   - `'`        — Select / clear all (gameplay; reserved for surfaces that
##                  expose a "select all" affordance — see project memory).
##
## Contract: `cycle_frame(step)` is the canonical frame-cycle entry point.
## Key bindings call it; subclasses may call it programmatically. Subclasses
## reacting to frame changes override `_on_frame_changed(new, prev)`.

# =============================================================================
# CONTRACT FIELDS
# =============================================================================

## Stable surface identifier. One of: farm | B | N | V | C | M | Z | X
@export var surface_id: String = ""

## Ordered list of page/frame ids for this surface. TYUIOP direct-jump maps
## index-for-index onto this list; `[` / `]` cycle through the rest.
@export var frame_ids: Array[String] = []

## Currently mounted frame. Must be an entry of frame_ids, or empty.
@export var frame_id: String = ""

## Current context (biome id, page id, filter id, active surface id, ...).
## Meaning is surface-specific; see per-surface spec.
@export var context_id: String = ""

## Current object focus inside this surface.
## {"id": String|null, "type": String|null}
var object_focus: Dictionary = {"id": null, "type": null}

# =============================================================================
# SIGNALS
# =============================================================================

signal frame_changed(new_frame_id: String, prev_frame_id: String)
signal context_changed(new_context_id: String, prev_context_id: String)
signal object_focus_changed(new_focus: Dictionary, prev_focus: Dictionary)
signal snapshot_changed(snapshot: Dictionary)

# =============================================================================
# SNAPSHOT CONTRACT
# =============================================================================

## Full surface snapshot in the canonical shape.
## Subclasses should rarely override this; override the smaller hooks instead.
func get_snapshot() -> Dictionary:
	return {
		"surface_id": surface_id,
		"frame_id": frame_id,
		"context_id": context_id,
		"object_focus": object_focus.duplicate(true),
		"visible_data": get_visible_data(),
		"available_actions": get_available_actions(),
		"transitions": get_transitions(),
	}


## Surface-specific visible payload (matrix rows, offer list, biome graph, ...).
## Override in subclass.
func get_visible_data() -> Dictionary:
	return {}


## Shared page metric helpers for overlays that expose TYUIOP pages.
func get_page_index() -> int:
	if frame_ids.is_empty():
		return 1
	return maxi(0, frame_ids.find(frame_id)) + 1


func get_page_count() -> int:
	return frame_ids.size()


## Shared chrome payload for surface snapshots.
## Subclasses can pass selected_index/label plus a concise hint and extra keys.
func build_surface_visible_data(
		frame_label: String,
		sel_index: int = -1,
		selected_label: String = "",
		surface_hint: String = "",
		extra: Dictionary = {}) -> Dictionary:
	var payload := {
		"frame_id": frame_id,
		"frame_label": frame_label if frame_label != "" else frame_id,
		"page_index": get_page_index(),
		"page_count": get_page_count(),
		"selected_index": sel_index,
		"selected_label": selected_label,
		"surface_hint": surface_hint,
	}
	for key in extra.keys():
		payload[key] = extra[key]
	return payload


## Licensed actions for the current focus/frame.
## Each entry: { action_id, family, target_type, enabled, cost }
## Default implementation derives Q/E/R/F from action_labels; override for richer data.
func get_available_actions() -> Array:
	var actions: Array = []
	for key in ["Q", "E", "R", "F"]:
		var label: String = action_labels.get(key, "")
		if label.is_empty():
			continue
		actions.append({
			"action_id": key.to_lower(),
			"family": "action",
			"target_type": null,
			"enabled": true,
			"cost": {},
			"label": label,
		})
	return actions


## Legal surface transitions (e.g. "to M from C after commit").
## Each entry: { surface_id, reason }
func get_transitions() -> Array:
	return []


# =============================================================================
# FRAME / CONTEXT / FOCUS MUTATION
# =============================================================================

## Set current frame and emit signals. No-op if frame_id is already current.
func set_frame(new_frame_id: String) -> void:
	if new_frame_id == frame_id:
		return
	var prev := frame_id
	frame_id = new_frame_id
	_on_frame_changed(new_frame_id, prev)
	frame_changed.emit(new_frame_id, prev)
	_emit_snapshot()


## Advance to next frame in frame_ids (wraps). No-op if frame_ids is empty.
func cycle_frame(step: int = 1) -> void:
	if frame_ids.is_empty():
		return
	var idx := frame_ids.find(frame_id)
	if idx < 0:
		idx = 0
	var n := frame_ids.size()
	var next := frame_ids[posmod(idx + step, n)]
	set_frame(next)


func set_context(new_context_id: String) -> void:
	if new_context_id == context_id:
		return
	var prev := context_id
	context_id = new_context_id
	_on_context_changed(new_context_id, prev)
	context_changed.emit(new_context_id, prev)
	_emit_snapshot()


func set_object_focus(id, type) -> void:
	var new_focus := {"id": id, "type": type}
	if new_focus.get("id") == object_focus.get("id") and new_focus.get("type") == object_focus.get("type"):
		return
	var prev := object_focus.duplicate(true)
	object_focus = new_focus
	_on_object_focus_changed(new_focus, prev)
	object_focus_changed.emit(new_focus, prev)
	_emit_snapshot()


func clear_object_focus() -> void:
	set_object_focus(null, null)


# =============================================================================
# HOOKS FOR SUBCLASSES
# =============================================================================

func _on_frame_changed(_new_frame_id: String, _prev_frame_id: String) -> void:
	pass


func _on_context_changed(_new_context_id: String, _prev_context_id: String) -> void:
	pass


func _on_object_focus_changed(_new_focus: Dictionary, _prev_focus: Dictionary) -> void:
	pass


# =============================================================================
# OVERLAYBASE OVERRIDES
# =============================================================================

## F is the optional 4th verb on the current item, parallel to Q/E/R.
## Override `_on_action_f` only when an overlay legitimately needs more
## than 3 verbs. Frame cycling is `[` / `]` (PlayerShell.cycle_active_surface_frame).
## The old `_on_change_frame()` hook is gone; call `cycle_frame(±1)` directly
## if you need to programmatically advance a frame.


# =============================================================================
# TYUIOP DIRECT-JUMP TO FRAMES
# =============================================================================

## Default unhandled-key handler: TYUIOP direct-jump to the frame at that
## index (biome-row keycodes come from InputBindingRegistry, the shared ring
## source). Surfaces with more than 6 pages fall back to `[ ]` cycling for the
## rest. Subclasses that override this should call `super._on_unhandled_key`
## first to preserve the direct-jump behavior, then handle their own keys.
func _on_unhandled_key(keycode: int, _event: InputEvent) -> bool:
	var idx: int = InputBindingRegistry.biome_index_for_keycode(keycode)
	if idx >= 0 and idx < frame_ids.size():
		set_frame(frame_ids[idx])
		return true
	return false


## Emit an initial snapshot when the surface activates and register with the
## SurfaceRegistry autoload so Z / headless consumers can track it.
func _on_activated() -> void:
	if Engine.has_singleton("SurfaceRegistry") or _has_surface_registry_autoload():
		_surface_registry().register(self)
	_emit_snapshot()


func _on_deactivated() -> void:
	if _has_surface_registry_autoload():
		_surface_registry().unregister(self)


func _has_surface_registry_autoload() -> bool:
	var root := get_tree().root if is_inside_tree() else null
	return root != null and root.has_node("SurfaceRegistry")


func _surface_registry() -> Node:
	return get_tree().root.get_node("SurfaceRegistry")


# =============================================================================
# INTERNAL
# =============================================================================

func _emit_snapshot() -> void:
	if not is_active:
		return
	snapshot_changed.emit(get_snapshot())
