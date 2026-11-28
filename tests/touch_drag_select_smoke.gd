extends "res://tests/smoke_test_base.gd"

## Touch drag-select on the 2D plot rack (#145). Synthesizes InputEventScreenTouch
## / InputEventScreenDrag and feeds them to PlotGridDisplay._input directly.

class StubVerbose:
	extends Node
	func debug(_a = null, _b = null, _c = null) -> void: pass
	func info(_a = null, _b = null, _c = null) -> void: pass
	func warn(_a = null, _b = null, _c = null) -> void: pass
	func error(_a = null, _b = null, _c = null) -> void: pass
	func trace(_a = null, _b = null, _c = null) -> void: pass


class StubTile:
	extends Control
	var checked: bool = false
	func set_checkbox_selected(v: bool) -> void:
		checked = v


func _init() -> void:
	call_deferred("_run")


func _touch(pressed: bool, pos: Vector2, idx: int = 0) -> InputEventScreenTouch:
	var ev := InputEventScreenTouch.new()
	ev.index = idx
	ev.pressed = pressed
	ev.position = pos
	return ev


func _drag(pos: Vector2, idx: int = 0) -> InputEventScreenDrag:
	var ev := InputEventScreenDrag.new()
	ev.index = idx
	ev.position = pos
	return ev


func _run() -> void:
	print("\n=== Touch drag-select smoke ===")
	var vb := StubVerbose.new()
	vb.name = "VerboseConfig"
	root.add_child(vb)
	var grid = load("res://UI/PlotGridDisplay.gd").new()
	root.add_child(grid)
	# Three 100px tiles in a row, 20px gaps: x 0-100, 120-220, 240-340.
	for i in 3:
		var t := StubTile.new()
		t.position = Vector2(i * 120, 0)
		t.size = Vector2(100, 100)
		grid.add_child(t)
		grid.tiles[Vector2i(i, 0)] = t
	await process_frame

	# Multi-select: press tile 0, swipe across tile 1 into tile 2.
	grid._input(_touch(true, Vector2(50, 50)))
	_check(grid.is_dragging, "press on a tile starts tracking")
	grid._input(_drag(Vector2(130, 50)))
	grid._input(_drag(Vector2(280, 50)))
	_check(grid.drag_plots.size() == 3, "drag across 3 tiles fills drag_plots",
		str(grid.drag_plots.keys()))
	grid._input(_touch(false, Vector2(280, 50)))
	_check(grid.selected_plots.size() == 3, "release selects all three plots")
	_check(not grid.is_dragging, "drag ended")

	# Tap: finger wobbles over the tile gap but stays under the tap threshold.
	grid.selected_plots.clear()
	grid._input(_touch(true, Vector2(95, 50)))
	grid._input(_drag(Vector2(110, 50)))
	grid._input(_drag(Vector2(122, 50)))  # 27px: still a tap
	_check(grid.drag_plots.size() == 1, "sub-threshold motion adds no plots")
	grid._input(_touch(false, Vector2(122, 50)))
	_check(grid.selected_plots.is_empty(), "tap selects nothing through the drag path")

	# Second finger ignored while the first is down.
	grid._input(_touch(true, Vector2(50, 50), 0))
	grid._input(_touch(true, Vector2(250, 50), 1))
	grid._input(_drag(Vector2(260, 50), 1))
	_check(grid.drag_plots.size() == 1, "second finger does not extend the drag")
	grid._input(_touch(false, Vector2(50, 50), 0))

	# Press off any tile: no tracking.
	grid._input(_touch(true, Vector2(500, 500)))
	_check(not grid.is_dragging, "press outside tiles starts nothing")
	grid._input(_touch(false, Vector2(500, 500)))

	# Hidden rack (3D mode): no drag.
	grid.selected_plots.clear()
	grid.visible = false
	grid._input(_touch(true, Vector2(50, 50)))
	grid._input(_drag(Vector2(280, 50)))
	grid._input(_touch(false, Vector2(280, 50)))
	_check(not grid.is_dragging and grid.selected_plots.is_empty(),
		"hidden rack ignores touch drags")

	_finish("Touch drag-select smoke")
