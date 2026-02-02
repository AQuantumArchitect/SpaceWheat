class_name GeometryBatcher
extends RefCounted

## Geometry Batcher - Unified Draw Call Batching for Untextured Geometry
##
## Batches all untextured geometry (lines, circles, arcs, polygons) into a
## SINGLE RenderingServer.canvas_item_add_triangle_array() call per frame.
##
## Performance impact:
##   Before: 300-500 draw calls from QuantumEdgeRenderer, QuantumEffectsRenderer,
##           QuantumRegionRenderer, QuantumInfraRenderer
##   After:  1 draw call for all untextured geometry
##
## Usage:
##   var batcher = GeometryBatcher.new()
##
##   # Each frame:
##   batcher.begin(get_canvas_item())
##   batcher.add_line(from, to, color, width)
##   batcher.add_circle(pos, radius, color)
##   batcher.add_arc(pos, radius, from_angle, to_angle, width, color)
##   batcher.add_polygon(points, color)
##   batcher.flush()

# Batch data
var _canvas_item: RID = RID()
var _points: PackedVector2Array = PackedVector2Array()
var _colors: PackedColorArray = PackedColorArray()

# Configuration
const CIRCLE_SEGMENTS: int = 16
const ARC_SEGMENTS: int = 24

# Stats
var _primitive_count: int = 0
var _draw_calls: int = 0
var _debug_printed_begin: bool = false
var _debug_printed_add: bool = false


func _init():
	# Pre-allocate typical capacity (500 primitives × ~12 verts average)
	var typical_verts = 500 * 12
	_points.resize(typical_verts)
	_colors.resize(typical_verts)
	_points.clear()
	_colors.clear()


func begin(canvas_item: RID) -> void:
	"""Begin a new batch frame.

	Args:
		canvas_item: The canvas item RID to draw to (from get_canvas_item())
	"""
	_canvas_item = canvas_item
	_points.clear()
	_colors.clear()
	_primitive_count = 0
	_draw_calls = 0

	# Debug: print once to confirm begin() is called
	if not _debug_printed_begin:
		print("[GeometryBatcher] begin() called with canvas_item: %s" % canvas_item)
		_debug_printed_begin = true


func flush() -> void:
	"""Submit all batched geometry to RenderingServer in ONE draw call."""
	if _points.size() == 0:
		return

	if not _canvas_item.is_valid():
		return

	var indices = PackedInt32Array()
	indices.resize(_points.size())
	for i in range(_points.size()):
		indices[i] = i

	RenderingServer.canvas_item_add_triangle_array(
		_canvas_item,
		indices,
		_points,
		_colors,
		PackedVector2Array(),  # No UVs for solid color
		PackedInt32Array(),    # No bones
		PackedFloat32Array()   # No weights
	)
	_draw_calls = 1


func add_line(from: Vector2, to: Vector2, color: Color, width: float = 1.0) -> void:
	"""Add a line as a quad (2 triangles).

	Args:
		from: Start position
		to: End position
		color: Line color
		width: Line width in pixels
	"""
	if not _debug_printed_add:
		print("[GeometryBatcher] add_line() called!")
		_debug_printed_add = true

	if color.a < 0.01:
		return

	var delta = to - from
	if delta.length_squared() < 0.01:
		return

	var dir = delta.normalized()
	var perp = Vector2(-dir.y, dir.x) * width * 0.5

	var p0 = from - perp
	var p1 = from + perp
	var p2 = to + perp
	var p3 = to - perp

	# Triangle 1: p0, p1, p2
	_points.append(p0); _colors.append(color)
	_points.append(p1); _colors.append(color)
	_points.append(p2); _colors.append(color)

	# Triangle 2: p0, p2, p3
	_points.append(p0); _colors.append(color)
	_points.append(p2); _colors.append(color)
	_points.append(p3); _colors.append(color)

	_primitive_count += 1


func add_dashed_line(from: Vector2, to: Vector2, color: Color, width: float,
					  dash: float, gap: float) -> void:
	"""Add a dashed line.

	Args:
		from: Start position
		to: End position
		color: Line color
		width: Line width in pixels
		dash: Dash length in pixels
		gap: Gap length in pixels
	"""
	if color.a < 0.01:
		return

	var delta = to - from
	var distance = delta.length()
	if distance < 0.01:
		return

	var direction = delta / distance
	var current = 0.0

	while current < distance:
		var dash_start = from + direction * current
		var dash_end = from + direction * minf(current + dash, distance)
		add_line(dash_start, dash_end, color, width)
		current += dash + gap


func add_circle(center: Vector2, radius: float, color: Color) -> void:
	"""Add a filled circle using triangle fan.

	Args:
		center: Circle center
		radius: Circle radius
		color: Fill color
	"""
	if color.a < 0.01:
		return

	if radius < 0.5:
		return

	# Adjust segments based on radius for quality/performance balance
	var segs = clampi(int(CIRCLE_SEGMENTS * radius / 20.0), 8, 32)

	for i in range(segs):
		var a1 = TAU * float(i) / float(segs)
		var a2 = TAU * float(i + 1) / float(segs)

		_points.append(center); _colors.append(color)
		_points.append(center + Vector2(cos(a1), sin(a1)) * radius); _colors.append(color)
		_points.append(center + Vector2(cos(a2), sin(a2)) * radius); _colors.append(color)

	_primitive_count += 1


func add_arc(center: Vector2, radius: float, from_angle: float, to_angle: float,
			 width: float, color: Color) -> void:
	"""Add an arc (ring segment) using triangle strip.

	Args:
		center: Arc center
		radius: Arc radius (center of stroke)
		from_angle: Start angle in radians
		to_angle: End angle in radians
		width: Stroke width in pixels
		color: Arc color
	"""
	if color.a < 0.01:
		return

	if radius < 0.5 or width < 0.5:
		return

	var inner = maxf(0.0, radius - width * 0.5)
	var outer = radius + width * 0.5

	var span = to_angle - from_angle
	if absf(span) < 0.01:
		return

	var segs = maxi(8, int(absf(span) * ARC_SEGMENTS / TAU))

	for i in range(segs):
		var t1 = float(i) / float(segs)
		var t2 = float(i + 1) / float(segs)
		var a1 = from_angle + span * t1
		var a2 = from_angle + span * t2

		var cos1 = cos(a1)
		var sin1 = sin(a1)
		var cos2 = cos(a2)
		var sin2 = sin(a2)

		var i1 = center + Vector2(cos1, sin1) * inner
		var o1 = center + Vector2(cos1, sin1) * outer
		var i2 = center + Vector2(cos2, sin2) * inner
		var o2 = center + Vector2(cos2, sin2) * outer

		# Triangle 1: i1, o1, i2
		_points.append(i1); _colors.append(color)
		_points.append(o1); _colors.append(color)
		_points.append(i2); _colors.append(color)

		# Triangle 2: i2, o1, o2
		_points.append(i2); _colors.append(color)
		_points.append(o1); _colors.append(color)
		_points.append(o2); _colors.append(color)

	_primitive_count += 1


func add_polygon(points: PackedVector2Array, color: Color) -> void:
	"""Add a filled polygon using fan triangulation from vertex 0.

	Args:
		points: Polygon vertices (must be convex for correct results)
		color: Fill color
	"""
	if color.a < 0.01:
		return

	if points.size() < 3:
		return

	# Fan triangulation from vertex 0
	for i in range(1, points.size() - 1):
		_points.append(points[0]); _colors.append(color)
		_points.append(points[i]); _colors.append(color)
		_points.append(points[i + 1]); _colors.append(color)

	_primitive_count += 1


func add_colored_polygon(points: Array, color: Color) -> void:
	"""Add a filled polygon from Array (convenience wrapper).

	Args:
		points: Array of Vector2 vertices
		color: Fill color
	"""
	if points.size() < 3:
		return

	var packed = PackedVector2Array()
	for p in points:
		packed.append(p)
	add_polygon(packed, color)


func add_quadratic_bezier(from: Vector2, control: Vector2, to: Vector2,
						  color: Color, width: float, segments: int = 12) -> void:
	"""Add a quadratic bezier curve as line segments.

	Args:
		from: Start point
		control: Control point
		to: End point
		color: Curve color
		width: Line width
		segments: Number of segments to approximate curve
	"""
	if color.a < 0.01:
		return

	var prev_point = from
	for i in range(1, segments + 1):
		var t = float(i) / float(segments)
		# Quadratic bezier: B(t) = (1-t)²P0 + 2(1-t)tP1 + t²P2
		var one_minus_t = 1.0 - t
		var point = one_minus_t * one_minus_t * from + \
					2.0 * one_minus_t * t * control + \
					t * t * to
		add_line(prev_point, point, color, width)
		prev_point = point


func get_stats() -> Dictionary:
	"""Get batching statistics for performance monitoring."""
	return {
		"primitive_count": _primitive_count,
		"vertex_count": _points.size(),
		"triangle_count": _points.size() / 3,
		"draw_calls": _draw_calls,
	}
