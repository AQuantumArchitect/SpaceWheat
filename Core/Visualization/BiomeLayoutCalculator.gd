class_name BiomeLayoutCalculator
extends RefCounted

## Biome Layout Calculator
##
## Central authority for computing visual positions from:
## - Viewport size (screen resolution)
## - Biome visual configs (relative offsets and oval dimensions)
## - Node parametric coordinates (biome_name, t, ring)
##
## This separates simulation (biome quantum states) from visualization (positions).
## Biomes define WHERE they want to appear (relative hints).
## This calculator computes WHERE they actually appear (absolute positions).

# Cached computation results
var biome_ovals: Dictionary = {}  # biome_name → {center, semi_a, semi_b, color, label}
var viewport_size: Vector2 = Vector2(1280, 720)
var graph_center: Vector2 = Vector2(640, 360)
var graph_radius: float = 250.0

# Reference scale (biome oval dimensions are defined relative to this)
const BASE_REFERENCE_RADIUS = 300.0


func compute_layout(biomes: Dictionary, new_viewport_size: Vector2) -> Dictionary:
	"""Compute all biome ovals from configs and viewport size

	Args:
		biomes: Dictionary of biome_name → BiomeBase instances
		new_viewport_size: Current viewport dimensions

	Returns:
		Dictionary of biome_name → oval config
	"""
	# CRITICAL: Separate actual viewport size from layout reference size
	# - Actual viewport determines CENTER position AND positioning radius (where to draw)
	# - Reference size determines SCALE (how big to draw)
	var actual_viewport = new_viewport_size
	var reference_size = new_viewport_size

	# For tiny viewports (headless mode), use reference size for scaling
	# but still center on the actual viewport
	if new_viewport_size.x < 200 or new_viewport_size.y < 200:
		reference_size = Vector2(1280, 720)

	viewport_size = reference_size
	graph_center = actual_viewport / 2.0  # Use ACTUAL viewport center!
	var actual_radius = min(actual_viewport.x, actual_viewport.y) * 0.35  # Positioning radius
	graph_radius = min(reference_size.x, reference_size.y) * 0.35  # Scaling radius (for dimensions)

	biome_ovals.clear()

	for biome_name in biomes:
		var biome = biomes[biome_name]
		if not biome:
			continue

		var config = biome.get_visual_config() if biome.has_method("get_visual_config") else {}

		# Extract config values with defaults
		var center_offset = config.get("center_offset", Vector2.ZERO)
		var oval_width = config.get("oval_width", 200.0)
		var oval_height = config.get("oval_height", 125.0)
		var color = config.get("color", Color(0.5, 0.5, 0.5, 0.3))
		var label = config.get("label", biome_name)

		# Convert relative offset to absolute center using ACTUAL radius (keeps ovals on screen)
		var center = graph_center + center_offset * actual_radius

		# Scale oval dimensions using reference radius (prevents tiny ovals in headless mode)
		var scale = graph_radius / BASE_REFERENCE_RADIUS
		var semi_a = oval_width * scale / 2.0  # Horizontal semi-axis
		var semi_b = oval_height * scale / 2.0  # Vertical semi-axis

		# DEBUG: Show oval calculation
		print("🟢 BiomeLayoutCalculator: Biome '%s'" % biome_name)
		print("   center_offset=%s, oval_width=%.1f, scale=%.3f" % [
			center_offset, oval_width, scale
		])
		print("   Calculated center: (%.1f, %.1f)" % [center.x, center.y])
		print("   graph_center=%s, graph_radius=%.1f" % [graph_center, graph_radius])

		biome_ovals[biome_name] = {
			"center": center,
			"semi_a": semi_a,
			"semi_b": semi_b,
			"color": color,
			"label": label,
			"center_offset": center_offset,  # Keep original for debugging
		}

	# Handle TestBiomes - position at plot grid location with small circles
	for biome_name in biomes:
		var biome = biomes[biome_name]
		if biome_name.begins_with("TestBiome_"):
			# Get plot position from TestBiome
			var plot_pos = biome.plot_position

			# Calculate screen position (simple grid layout)
			var grid_x = plot_pos.x * 100 + 50  # 100px spacing
			var grid_y = plot_pos.y * 100 + 50
			var screen_pos = Vector2(grid_x, grid_y)

			# Create small oval config (no scaling - TestBiomes are always small)
			biome_ovals[biome_name] = {
				"center": screen_pos,
				"semi_a": biome.visual_oval_width / 2.0,
				"semi_b": biome.visual_oval_height / 2.0,
				"color": biome.visual_color,
				"label": ""  # No label for test biomes
			}

	return biome_ovals


func get_biome_oval(biome_name: String) -> Dictionary:
	"""Get cached oval config for a biome"""
	return biome_ovals.get(biome_name, {})


func get_parametric_position(biome_name: String, t: float, ring: float) -> Vector2:
	"""Convert parametric coordinates to absolute screen position

	Args:
		biome_name: Which biome's oval to use
		t: Angular parameter [0, 1] → angle around oval
		ring: Radial parameter [0, 1] → distance from center (0=center, 1=edge)

	Returns:
		Absolute screen position within the biome's oval
	"""
	var oval = biome_ovals.get(biome_name, {})
	if oval.is_empty():
		return graph_center  # Fallback to center

	var center = oval.get("center", graph_center)
	var semi_a = oval.get("semi_a", 100.0)
	var semi_b = oval.get("semi_b", 60.0)

	# Convert t to angle
	var angle = t * TAU

	# Ring 0 = center, Ring 1 = edge (but we keep slightly inside edge)
	var r = ring * 0.85 + 0.05  # Range [0.05, 0.9] to stay inside oval

	return Vector2(
		center.x + cos(angle) * semi_a * r,
		center.y + sin(angle) * semi_b * r
	)


func update_node_positions(nodes: Array) -> void:
	"""Update all node anchors from their parametric coordinates

	Args:
		nodes: Array of QuantumNode instances with biome_name, parametric_t, parametric_ring
	"""
	for node in nodes:
		if not node:
			continue

		var biome_name = node.biome_name if "biome_name" in node else ""
		if biome_name.is_empty():
			continue

		var t = node.parametric_t if "parametric_t" in node else 0.5
		var ring = node.parametric_ring if "parametric_ring" in node else 0.5

		var new_anchor = get_parametric_position(biome_name, t, ring)

		# Update anchor and snap position (for immediate response to layout changes)
		var old_anchor = node.classical_anchor
		node.classical_anchor = new_anchor

		# Move position by the same delta (keeps node near its anchor)
		var anchor_delta = new_anchor - old_anchor
		node.position += anchor_delta

		# Clear velocity to prevent overshoot
		node.velocity = Vector2.ZERO


func distribute_nodes_in_biome(biome_name: String, count: int, seed_offset: int = 0) -> Array:
	"""Generate evenly distributed parametric positions for nodes in a biome

	Uses golden angle distribution for even spread.

	Args:
		biome_name: Which biome to distribute in
		count: Number of positions to generate
		seed_offset: Offset for reproducible placement

	Returns:
		Array of {t: float, ring: float} parametric coordinates
	"""
	var positions: Array = []

	for i in range(count):
		# Golden angle distribution for even spread
		var golden_angle = PI * (3.0 - sqrt(5.0))  # ~137.5 degrees
		var t = fmod((i + seed_offset) * golden_angle / TAU, 1.0)

		# Radial rings - spread from inner to outer
		var ring = 0.2 + (float(i) / max(count - 1, 1)) * 0.6  # Range [0.2, 0.8]

		positions.append({"t": t, "ring": ring})

	return positions


func is_point_in_biome(point: Vector2, biome_name: String) -> bool:
	"""Check if a screen point is inside a biome's oval"""
	var oval = biome_ovals.get(biome_name, {})
	if oval.is_empty():
		return false

	var center = oval.get("center", Vector2.ZERO)
	var semi_a = oval.get("semi_a", 1.0)
	var semi_b = oval.get("semi_b", 1.0)

	var dx = point.x - center.x
	var dy = point.y - center.y

	# Ellipse equation: (dx/a)² + (dy/b)² <= 1
	var normalized_dist = (dx * dx) / (semi_a * semi_a) + (dy * dy) / (semi_b * semi_b)
	return normalized_dist <= 1.0


func get_biomes_at_point(point: Vector2) -> Array:
	"""Get all biomes whose ovals contain a screen point (for overlap detection)"""
	var result: Array = []
	for biome_name in biome_ovals:
		if is_point_in_biome(point, biome_name):
			result.append(biome_name)
	return result


func debug_info() -> String:
	"""Return debug string with current layout state"""
	var lines: Array = ["BiomeLayoutCalculator:"]
	lines.append("  viewport=%s center=%s radius=%.0f" % [viewport_size, graph_center, graph_radius])

	for biome_name in biome_ovals:
		var oval = biome_ovals[biome_name]
		lines.append("  %s: center=%s a=%.0f b=%.0f" % [
			biome_name,
			oval.get("center", Vector2.ZERO),
			oval.get("semi_a", 0),
			oval.get("semi_b", 0)
		])

	return "\n".join(lines)
