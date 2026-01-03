class_name VennZoneCalculator
extends RefCounted

## Parametric Venn Diagram Zone Calculator
## Mathematically defines overlapping ellipse regions for biome visualization

# Zone types
enum Zone { LEFT_ONLY, OVERLAP, RIGHT_ONLY }

# Ellipse parameters (in screen coordinates)
var left_center: Vector2
var right_center: Vector2
var semi_axis_x: float  # Horizontal semi-axis (a)
var semi_axis_y: float  # Vertical semi-axis (b)

# Derived values (calculated once)
var x_midpoint: float          # x where ellipses intersect
var overlap_half_width: float  # Half-width of overlap lens at center
var has_overlap: bool          # Whether ellipses actually overlap


func _init(left_cx: float, right_cx: float, center_y: float, a: float, b: float):
	"""Initialize with two horizontal ellipses of equal size

	Args:
		left_cx: X-center of left ellipse
		right_cx: X-center of right ellipse
		center_y: Y-center (same for both)
		a: Horizontal semi-axis
		b: Vertical semi-axis
	"""
	left_center = Vector2(left_cx, center_y)
	right_center = Vector2(right_cx, center_y)
	semi_axis_x = a
	semi_axis_y = b

	_calculate_intersection()


func _calculate_intersection():
	"""Calculate where the two ellipses intersect

	For two ellipses:
		(x - cx1)²/a² + (y - cy)²/b² = 1
		(x - cx2)²/a² + (y - cy)²/b² = 1

	Intersection x-coordinate: x_mid = (cx1 + cx2) / 2
	"""
	x_midpoint = (left_center.x + right_center.x) / 2.0

	# Check if ellipses overlap
	var center_distance = right_center.x - left_center.x
	has_overlap = center_distance < 2.0 * semi_axis_x

	if has_overlap:
		# Calculate overlap lens width at y = center_y
		# At x_mid, distance from each center is |center_distance / 2|
		# For ellipse: (dx/a)² + (dy/b)² = 1
		# At x_mid: dx = center_distance / 2
		# So: dy² = b² * (1 - (dx/a)²)
		var dx = center_distance / 2.0
		var dx_normalized = dx / semi_axis_x
		if dx_normalized < 1.0:
			# y-extent of overlap at x_midpoint
			var dy_squared = semi_axis_y * semi_axis_y * (1.0 - dx_normalized * dx_normalized)
			overlap_half_width = sqrt(dy_squared)
		else:
			overlap_half_width = 0.0
	else:
		overlap_half_width = 0.0


func is_in_ellipse(point: Vector2, center: Vector2) -> bool:
	"""Check if point is inside an ellipse"""
	var dx = point.x - center.x
	var dy = point.y - center.y
	var normalized_dist = (dx * dx) / (semi_axis_x * semi_axis_x) + \
						  (dy * dy) / (semi_axis_y * semi_axis_y)
	return normalized_dist <= 1.0


func get_zone(point: Vector2) -> Zone:
	"""Determine which zone a point belongs to"""
	var in_left = is_in_ellipse(point, left_center)
	var in_right = is_in_ellipse(point, right_center)

	if in_left and in_right:
		return Zone.OVERLAP
	elif in_left:
		return Zone.LEFT_ONLY
	elif in_right:
		return Zone.RIGHT_ONLY
	else:
		return Zone.LEFT_ONLY  # Default fallback


func get_parametric_point(zone: Zone, t: float, ring: float = 0.5) -> Vector2:
	"""Get a point within a zone using parametric coordinates

	Args:
		zone: Which zone to place the point in
		t: Angular parameter [0, 1] mapping to angle around the zone
		ring: Radial parameter [0, 1] where 0=center, 1=edge

	Returns:
		Screen coordinate within the specified zone
	"""
	match zone:
		Zone.LEFT_ONLY:
			return _get_left_only_point(t, ring)
		Zone.OVERLAP:
			return _get_overlap_point(t, ring)
		Zone.RIGHT_ONLY:
			return _get_right_only_point(t, ring)
	return left_center  # Fallback


func _get_left_only_point(t: float, ring: float) -> Vector2:
	"""Get point in left-only region (crescent shape)

	Uses the left side of the left ellipse, avoiding overlap zone
	"""
	# Angular position: map t to left semicircle plus some of right
	# Range: PI/2 to 3PI/2 for full left side, plus some inward
	var angle = PI / 2.0 + t * PI  # Left semicircle

	# Radial distance with ring scaling
	var r = ring * 0.8 + 0.1  # Keep away from edge

	# Offset toward left to avoid overlap
	var offset_x = -semi_axis_x * 0.2 if has_overlap else 0.0

	return Vector2(
		left_center.x + offset_x + cos(angle) * semi_axis_x * r,
		left_center.y + sin(angle) * semi_axis_y * r
	)


func _get_right_only_point(t: float, ring: float) -> Vector2:
	"""Get point in right-only region (crescent shape)"""
	# Angular position: right semicircle
	var angle = -PI / 2.0 + t * PI  # Right semicircle

	var r = ring * 0.8 + 0.1

	# Offset toward right to avoid overlap
	var offset_x = semi_axis_x * 0.2 if has_overlap else 0.0

	return Vector2(
		right_center.x + offset_x + cos(angle) * semi_axis_x * r,
		right_center.y + sin(angle) * semi_axis_y * r
	)


func _get_overlap_point(t: float, ring: float) -> Vector2:
	"""Get point in overlap region (lens/vesica piscis shape)

	The overlap is bounded by both ellipse curves.
	We parameterize as vertical slices within the lens.
	"""
	if not has_overlap:
		# No overlap - return midpoint
		return Vector2(x_midpoint, left_center.y)

	# Angular position within the lens
	var angle = -PI / 2.0 + t * PI  # -90° to +90° (vertical spread)

	# Calculate the x-extent of overlap at this y-position
	var y_offset = sin(angle) * overlap_half_width * ring
	var y = left_center.y + y_offset

	# At this y, find the x-bounds of the overlap
	# Both ellipses: (x - cx)²/a² + (y - cy)²/b² = 1
	# Solve for x: x = cx ± a * sqrt(1 - (y - cy)²/b²)
	var dy = y - left_center.y
	var dy_norm_sq = (dy * dy) / (semi_axis_y * semi_axis_y)

	if dy_norm_sq >= 1.0:
		return Vector2(x_midpoint, y)

	var x_extent = semi_axis_x * sqrt(1.0 - dy_norm_sq)

	# Left ellipse right edge at this y
	var left_right_edge = left_center.x + x_extent
	# Right ellipse left edge at this y
	var right_left_edge = right_center.x - x_extent

	# Overlap x-range is between these
	var overlap_left = right_left_edge
	var overlap_right = left_right_edge

	if overlap_left >= overlap_right:
		return Vector2(x_midpoint, y)

	# Place point within overlap, biased by ring parameter
	var x = lerp(overlap_left, overlap_right, 0.5)  # Center of overlap

	return Vector2(x, y)


func get_zone_bounds(zone: Zone) -> Dictionary:
	"""Get the bounding box of a zone

	Returns: {min_x, max_x, min_y, max_y}
	"""
	match zone:
		Zone.LEFT_ONLY:
			return {
				"min_x": left_center.x - semi_axis_x,
				"max_x": x_midpoint if has_overlap else left_center.x + semi_axis_x,
				"min_y": left_center.y - semi_axis_y,
				"max_y": left_center.y + semi_axis_y
			}
		Zone.OVERLAP:
			if not has_overlap:
				return {"min_x": x_midpoint, "max_x": x_midpoint,
						"min_y": left_center.y, "max_y": left_center.y}
			return {
				"min_x": right_center.x - semi_axis_x,
				"max_x": left_center.x + semi_axis_x,
				"min_y": left_center.y - overlap_half_width,
				"max_y": left_center.y + overlap_half_width
			}
		Zone.RIGHT_ONLY:
			return {
				"min_x": x_midpoint if has_overlap else right_center.x - semi_axis_x,
				"max_x": right_center.x + semi_axis_x,
				"min_y": right_center.y - semi_axis_y,
				"max_y": right_center.y + semi_axis_y
			}
	return {}


func distribute_points_in_zone(zone: Zone, count: int, seed_offset: int = 0) -> Array:
	"""Distribute points evenly within a zone using parametric placement

	Args:
		zone: Target zone
		count: Number of points
		seed_offset: Offset for reproducible placement

	Returns:
		Array of Vector2 positions
	"""
	var points: Array = []

	for i in range(count):
		# Golden angle distribution for even spread
		var golden_angle = PI * (3.0 - sqrt(5.0))  # ~137.5°
		var t = fmod((i + seed_offset) * golden_angle / TAU, 1.0)

		# Radial rings - spread from center outward
		var ring = 0.3 + (float(i) / max(count - 1, 1)) * 0.5

		points.append(get_parametric_point(zone, t, ring))

	return points


func debug_info() -> String:
	"""Return debug information about the Venn zones"""
	var sep = abs(right_center.x - left_center.x)
	return "VennZones: centers=(%.1f, %.1f) sep=%.1f a=%.1f b=%.1f overlap=%s width=%.1f" % [
		left_center.x, right_center.x, sep,
		semi_axis_x, semi_axis_y,
		"yes" if has_overlap else "no",
		overlap_half_width * 2.0 if has_overlap else 0.0
	]
