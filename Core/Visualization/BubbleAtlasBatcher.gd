class_name BubbleAtlasBatcher
extends RefCounted

# Shared constants

## Bubble Atlas Batcher - GPU-Accelerated Bubble Rendering
##
## PRE-RENDERS grayscale geometric templates (circles, rings) to a texture atlas
## at startup, then batches all bubble draw calls into ONE RenderingServer call
## per frame using per-vertex color modulation.
##
## Performance impact:
##   Before: ~200 triangles per bubble via CPU (C++ triangulation)
##   After:  ~18 triangles per bubble via GPU atlas (2 triangles per layer)
##
## Usage:
##   var batcher = BubbleAtlasBatcher.new()
##   batcher.build_atlas()  # Call once at startup
##
##   # Each frame:
##   batcher.begin(canvas_item)
##   batcher.add_circle_layer("circle_100", pos, radius, color)
##   batcher.add_arc_layer(pos, radius, from_angle, to_angle, color)
##   batcher.flush()

# Atlas configuration
const ATLAS_WIDTH: int = 1024
const ATLAS_HEIGHT: int = 256
const CELL_SIZE: int = 128  # Each template cell is 128x128
const SMALL_CELL_SIZE: int = 64  # For small templates like highlight

# Template definitions: [name, cell_index, radius_factor, is_ring, thickness]
# radius_factor: What fraction of cell_size/2 the radius should be
# For rings: inner_radius = radius - thickness/2
const TEMPLATES: Array = [
	["circle_100", 0, 1.0, false, 0.0],    # Main bubble body (full cell)
	["circle_110", 1, 1.0, false, 0.0],    # Dark background layer
	["circle_160", 2, 1.0, false, 0.0],    # Mid glow layer (soft edge)
	["circle_220", 3, 1.0, false, 0.0],    # Outer glow layer (very soft)
	["circle_050", 4, 1.0, false, 0.0],    # Glossy highlight (half size cell)
	["ring_thin", 5, 0.9, true, 2.5],      # Outline ring, 2.5px width
	["ring_data", 6, 0.9, true, 2.0],      # Purity/probability rings, 2.0px width
	["ring_thick", 7, 0.9, true, 4.0],     # Uncertainty ring, thicker
	["wedge_gradient", 8, 1.0, false, 0.0],  # Triangular gradient (40° wide) for season broadcast
	["spin_spiral", 9, 1.0, false, 0.0],     # Rotating internal pattern for spin illusion
]

# Season constants - imported from shared source
const SEASON_ANGLES = VisualizationConstants.SEASON_ANGLES
const SEASON_COLORS = VisualizationConstants.SEASON_COLORS

# Atlas texture (generated at startup)
var _atlas_texture: ImageTexture = null
var _atlas_image: Image = null

# Template name → UV rect mapping (normalized 0-1 coordinates)
var _template_uvs: Dictionary = {}

# Current canvas item we're drawing to
var _canvas_item: RID = RID()

# Batch data (single texture = single batch!)
var _points: PackedVector2Array = PackedVector2Array()
var _uvs: PackedVector2Array = PackedVector2Array()
var _colors: PackedColorArray = PackedColorArray()

# Arc geometry (dynamic, but batched together)
var _arc_points: PackedVector2Array = PackedVector2Array()
var _arc_colors: PackedColorArray = PackedColorArray()


func _log_debug(message: String) -> void:
	VerboseHelper.debug("viz", "atlas", message)

# Capacity tracking to avoid frequent reallocations
var _last_vertex_count: int = 0
var _last_arc_count: int = 0

# Empty arrays for RenderingServer call
var _empty_bones := PackedInt32Array()
var _empty_weights := PackedFloat32Array()

# Pre-allocated indices arrays (reused each frame to avoid GDScript loop)
var _indices: PackedInt32Array = PackedInt32Array()
var _arc_indices: PackedInt32Array = PackedInt32Array()
var _max_indices_size: int = 0
var _max_arc_indices_size: int = 0

# Stats
var _layer_count: int = 0
var _arc_count: int = 0
var _draw_calls: int = 0
var _atlas_built: bool = false

# Graphics quality settings - layer toggles
var draw_glow_layers: bool = true
var draw_data_rings: bool = true
var enable_spin_pattern: bool = true
var enable_season_wedges: bool = true

# Quality presets
enum GraphicsQuality { LOW, MEDIUM, HIGH }
var current_quality: GraphicsQuality = GraphicsQuality.HIGH


func set_graphics_quality(quality: GraphicsQuality) -> void:
	# Configure visual layers based on quality preset.

	# LOW:    Minimal layers for max FPS (37-50 FPS on llvmpipe)
	# - Core bubble + border + emoji only
	# - No glows, rings, spin, or wedges

	# MEDIUM: Balanced visuals (20-27 FPS on llvmpipe)
	# - Core bubble + border + emoji
	# - Berry phase glow (1 circle)
	# - Spin pattern (subtle internal spiral)
	# - No data rings or season wedges

	# HIGH:   Full visual fidelity (12-18 FPS on llvmpipe, 60+ on GPU)
	# - All layers enabled
	# - Berry phase glow
	# - Spin pattern
	# - Season wedges (phi broadcast)
	# - Data rings (purity, uncertainty)
	current_quality = quality

	match quality:
		GraphicsQuality.LOW:
			draw_glow_layers = false
			draw_data_rings = false
			enable_spin_pattern = false
			enable_season_wedges = false
			_log_debug("[BubbleAtlasBatcher] Graphics: LOW (minimal layers, max FPS)")

		GraphicsQuality.MEDIUM:
			draw_glow_layers = true   # Berry phase glow
			draw_data_rings = false
			enable_spin_pattern = true
			enable_season_wedges = false
			_log_debug("[BubbleAtlasBatcher] Graphics: MEDIUM (glow + spin, no rings/wedges)")

		GraphicsQuality.HIGH:
			draw_glow_layers = true
			draw_data_rings = true
			enable_spin_pattern = true
			enable_season_wedges = true
			_log_debug("[BubbleAtlasBatcher] Graphics: HIGH (all layers)")


# Arc configuration
const ARC_SEGMENTS: int = 24  # Segments for full circle arc

func _ensure_indices_capacity(size: int) -> void:
	# Ensure pre-allocated indices array is large enough.
	if size <= _max_indices_size:
		return
	# Grow with headroom to avoid frequent reallocations
	var new_size = maxi(size, _max_indices_size * 2)
	new_size = maxi(new_size, 2048)  # Minimum reasonable size
	_indices.resize(new_size)
	# Fill new indices (only need to fill newly allocated portion)
	for i in range(_max_indices_size, new_size):
		_indices[i] = i
	_max_indices_size = new_size


func _ensure_arc_indices_capacity(size: int) -> void:
	# Ensure pre-allocated arc indices array is large enough.
	if size <= _max_arc_indices_size:
		return
	var new_size = maxi(size, _max_arc_indices_size * 2)
	new_size = maxi(new_size, 2048)
	_arc_indices.resize(new_size)
	for i in range(_max_arc_indices_size, new_size):
		_arc_indices[i] = i
	_max_arc_indices_size = new_size


func _init():
	# Pre-allocate typical capacity
	var typical_verts = 2048
	var typical_arc_verts = 4096

	# Pre-allocate indices array (avoids slow GDScript loop in flush())
	_ensure_indices_capacity(typical_verts)
	_ensure_arc_indices_capacity(typical_arc_verts)


func build_atlas() -> bool:
	# Pre-render all geometric templates to a GPU texture atlas.

	# Call this ONCE at startup.

	# Returns:
	# true if atlas was built successfully
	var start_time = Time.get_ticks_msec()

	# Create atlas image (RGBA8 for transparency)
	_atlas_image = Image.create(ATLAS_WIDTH, ATLAS_HEIGHT, false, Image.FORMAT_RGBA8)
	_atlas_image.fill(Color(0, 0, 0, 0))  # Transparent background

	# Render each template to its cell
	for template_def in TEMPLATES:
		var template_name: String = template_def[0]
		var cell_index: int = template_def[1]
		var radius_factor: float = template_def[2]
		var is_ring: bool = template_def[3]
		var thickness: float = template_def[4]

		# Calculate cell position (wrap to second row if needed)
		# Atlas is 1024x256, cells are 128x128, so 8 cells per row, 2 rows
		var cells_per_row = ATLAS_WIDTH / CELL_SIZE  # 8
		var cell_x = (cell_index % cells_per_row) * CELL_SIZE
		var cell_y = (cell_index / cells_per_row) * CELL_SIZE

		# Determine actual cell size (smaller for highlight template)
		var actual_cell_size = CELL_SIZE
		if template_name == "circle_050":
			actual_cell_size = SMALL_CELL_SIZE

		# Render template to image
		var template_img = _render_template(template_name, actual_cell_size, radius_factor, is_ring, thickness)
		if template_img:
			# Blit to atlas
			var src_rect = Rect2i(0, 0, actual_cell_size, actual_cell_size)
			_atlas_image.blit_rect(template_img, src_rect, Vector2i(cell_x, cell_y))

		# Store UV coordinates (normalized 0-1)
		var uv_x = float(cell_x) / float(ATLAS_WIDTH)
		var uv_y = float(cell_y) / float(ATLAS_HEIGHT)
		var uv_w = float(actual_cell_size) / float(ATLAS_WIDTH)
		var uv_h = float(actual_cell_size) / float(ATLAS_HEIGHT)

		_template_uvs[template_name] = Rect2(uv_x, uv_y, uv_w, uv_h)

	# Create GPU texture from atlas image
	_atlas_texture = ImageTexture.create_from_image(_atlas_image)
	_atlas_built = true

	var elapsed = Time.get_ticks_msec() - start_time
	_log_debug("[BubbleAtlasBatcher] Atlas built: %dx%d (%d templates) in %dms" % [
		ATLAS_WIDTH, ATLAS_HEIGHT, _template_uvs.size(), elapsed
	])

	return true


func _render_template(template_name: String, cell_size: int, radius_factor: float, is_ring: bool, thickness: float) -> Image:
	# Render a single geometric template to an Image.

	# Creates grayscale/white shapes with anti-aliased edges.
	# Color modulation is applied per-vertex at draw time.
	# Special templates with custom rendering
	if template_name == "wedge_gradient":
		return _render_wedge_template(cell_size)
	elif template_name == "spin_spiral":
		return _render_spin_spiral_template(cell_size)

	var img = Image.create(cell_size, cell_size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var center = Vector2(cell_size / 2.0, cell_size / 2.0)
	var base_radius = (cell_size / 2.0 - 4.0) * radius_factor  # 4px margin for AA

	# Determine softness based on template type
	var edge_softness = 2.0  # Default anti-alias width

	# Special soft edges for glow templates
	if template_name == "circle_160":
		edge_softness = 16.0  # Very soft for mid glow
	elif template_name == "circle_220":
		edge_softness = 24.0  # Very soft for outer glow
	elif template_name == "circle_050":
		edge_softness = 3.0  # Slightly softer for highlight

	for y in range(cell_size):
		for x in range(cell_size):
			var pos = Vector2(x + 0.5, y + 0.5)  # Sample at pixel center
			var dist = pos.distance_to(center)
			var alpha = 0.0

			if is_ring:
				# Ring shape: visible between inner and outer radius
				var inner_radius = base_radius - thickness
				var outer_radius = base_radius + thickness

				if dist >= inner_radius and dist <= outer_radius:
					# Distance from ring center
					var ring_dist = absf(dist - base_radius)
					alpha = 1.0 - smoothstep(0.0, thickness, ring_dist)
			else:
				# Filled circle with soft edge
				if dist < base_radius:
					alpha = 1.0
				elif dist < base_radius + edge_softness:
					# Smooth falloff
					alpha = 1.0 - smoothstep(base_radius, base_radius + edge_softness, dist)

			if alpha > 0.001:
				# White template - color applied via vertex colors
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	return img


func _render_wedge_template(cell_size: int) -> Image:
	# Render a triangular gradient wedge for season broadcast.

	# The wedge:
	# - Points upward (0° = up, will be rotated at draw time)
	# - Inner radius = 0.5 (starts at bubble edge when scaled)
	# - Outer radius = 1.0 (extends to 2× bubble radius)
	# - Angular span = 40° (20° each side)
	# - Gradient: alpha 1.0 at inner → 0.0 at outer
	# - Soft angular falloff at edges
	var img = Image.create(cell_size, cell_size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var center = Vector2(cell_size / 2.0, cell_size / 2.0)
	var max_radius = cell_size / 2.0 - 2.0  # Small margin for AA

	# Wedge parameters
	var inner_radius_ratio = 0.3  # Start at 30% of cell radius
	var outer_radius_ratio = 1.0  # Extend to full cell radius
	var half_angle = deg_to_rad(20.0)  # 40° total width

	for y in range(cell_size):
		for x in range(cell_size):
			var pos = Vector2(x + 0.5, y + 0.5)
			var to_pixel = pos - center
			var dist = to_pixel.length()
			var pixel_angle = to_pixel.angle()

			# Wedge points upward (negative Y = -PI/2)
			# Normalize angle relative to up direction
			var angle_from_up = _wrap_angle(pixel_angle + PI / 2.0)

			# Check if within angular span
			var angle_factor = 1.0 - smoothstep(half_angle * 0.7, half_angle, absf(angle_from_up))
			if angle_factor < 0.001:
				continue

			# Check if within radial span
			var normalized_dist = dist / max_radius
			if normalized_dist < inner_radius_ratio or normalized_dist > outer_radius_ratio:
				continue

			# Radial gradient: full alpha at inner, zero at outer
			var radial_t = (normalized_dist - inner_radius_ratio) / (outer_radius_ratio - inner_radius_ratio)
			var radial_alpha = 1.0 - smoothstep(0.0, 1.0, radial_t)

			# Combine angular and radial factors
			var alpha = radial_alpha * angle_factor

			if alpha > 0.001:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	return img


func _render_spin_spiral_template(cell_size: int) -> Image:
	# Render a subtle spiral pattern for spinning illusion.

	# Creates radial lines with slight spiral twist that, when rotated,
	# create the illusion of a spinning disk.
	var img = Image.create(cell_size, cell_size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var center = Vector2(cell_size / 2.0, cell_size / 2.0)
	var max_radius = cell_size / 2.0 - 4.0

	# Spiral parameters
	var num_arms = 6  # Number of spiral arms
	var twist_amount = 0.3  # How much the arms twist (radians per unit radius)
	var arm_width = 0.15  # Width of each arm in radians

	for y in range(cell_size):
		for x in range(cell_size):
			var pos = Vector2(x + 0.5, y + 0.5)
			var to_pixel = pos - center
			var dist = to_pixel.length()
			var pixel_angle = to_pixel.angle()

			if dist < 2.0 or dist > max_radius:
				continue

			# Spiral twist: angle increases with distance
			var twisted_angle = pixel_angle - twist_amount * (dist / max_radius)

			# Calculate proximity to nearest arm
			var arm_angle = fmod(twisted_angle * num_arms / TAU + 1000.0, 1.0)  # 0 to 1
			var dist_to_arm = absf(arm_angle - 0.5)  # Distance to arm center (0.5)
			if dist_to_arm > 0.5:
				dist_to_arm = 1.0 - dist_to_arm

			# Soft falloff from arm center
			var arm_factor = 1.0 - smoothstep(0.0, arm_width, dist_to_arm)

			# Radial fade: stronger in center, fading at edges
			var radial_factor = 1.0 - smoothstep(0.3, 1.0, dist / max_radius)

			var alpha = arm_factor * radial_factor * 0.6  # Max 60% opacity

			if alpha > 0.001:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	return img


func _wrap_angle(angle: float) -> float:
	# Wrap angle to [-PI, PI] range.
	while angle > PI:
		angle -= TAU
	while angle < -PI:
		angle += TAU
	return angle


func smoothstep(edge0: float, edge1: float, x: float) -> float:
	# Smooth interpolation between edges.
	var t = clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func begin(canvas_item: RID) -> void:
	# Begin a new batch frame.

	# Args:
	# canvas_item: The canvas item RID to draw to (from get_canvas_item())
	_canvas_item = canvas_item
	_points.clear()
	_uvs.clear()
	_colors.clear()
	_arc_points.clear()
	_arc_colors.clear()
	_layer_count = 0
	_arc_count = 0
	_draw_calls = 0


func add_circle_layer(template: String, pos: Vector2, radius: float, color: Color) -> void:
	# Add a circle layer using pre-rendered atlas template.

	# Args:
	# template: Template name (e.g., "circle_100", "circle_160")
	# pos: Center position in screen space
	# radius: Desired radius in pixels
	# color: Color to modulate (applied via per-vertex colors)
	if not _template_uvs.has(template):
		push_warning("[BubbleAtlasBatcher] Unknown template: %s" % template)
		return

	if color.a < 0.01:
		return  # Skip nearly invisible layers

	if radius < 0.5:
		return  # Skip tiny circles

	var uv_rect: Rect2 = _template_uvs[template]
	_add_quad_to_batch(pos, radius, uv_rect, color)
	_layer_count += 1


func _add_quad_to_batch(center: Vector2, radius: float, uv_rect: Rect2, color: Color) -> void:
	# Add a textured quad to the batch arrays.

	# Creates 2 triangles (6 vertices) for the quad.
	var half_size = Vector2(radius, radius)

	# Quad corners
	var tl = center - half_size
	var corner_tr = center + Vector2(half_size.x, -half_size.y)
	var bl = center + Vector2(-half_size.x, half_size.y)
	var br = center + half_size

	# UV coordinates from atlas rect
	var uv_tl = Vector2(uv_rect.position.x, uv_rect.position.y)
	var uv_tr = Vector2(uv_rect.position.x + uv_rect.size.x, uv_rect.position.y)
	var uv_bl = Vector2(uv_rect.position.x, uv_rect.position.y + uv_rect.size.y)
	var uv_br = Vector2(uv_rect.position.x + uv_rect.size.x, uv_rect.position.y + uv_rect.size.y)

	# Triangle 1: tl, corner_tr, br
	_points.append(tl); _uvs.append(uv_tl); _colors.append(color)
	_points.append(corner_tr); _uvs.append(uv_tr); _colors.append(color)
	_points.append(br); _uvs.append(uv_br); _colors.append(color)

	# Triangle 2: tl, br, bl
	_points.append(tl); _uvs.append(uv_tl); _colors.append(color)
	_points.append(br); _uvs.append(uv_br); _colors.append(color)
	_points.append(bl); _uvs.append(uv_bl); _colors.append(color)


func add_rotated_quad(template: String, center: Vector2, radius: float,
					  rotation: float, color: Color) -> void:
	# Add a rotated textured quad using pre-rendered atlas template.

	# Rotates the quad corners around the center while keeping UV mapping fixed.
	# This allows the wedge template to be drawn at any angle without multiple atlas entries.

	# Args:
	# template: Template name (e.g., "wedge_gradient")
	# center: Center position in screen space
	# radius: Desired radius in pixels (half the quad size)
	# rotation: Rotation angle in radians
	# color: Color to modulate (applied via per-vertex colors)
	if not _template_uvs.has(template):
		push_warning("[BubbleAtlasBatcher] Unknown template: %s" % template)
		return

	if color.a < 0.01:
		return  # Skip nearly invisible layers

	if radius < 0.5:
		return  # Skip tiny quads

	var uv_rect: Rect2 = _template_uvs[template]

	# Pre-compute rotation
	var cos_r = cos(rotation)
	var sin_r = sin(rotation)

	# Unrotated quad corners (relative to center)
	var half = radius
	var offsets = [
		Vector2(-half, -half),  # top-left
		Vector2(half, -half),   # top-right
		Vector2(-half, half),   # bottom-left
		Vector2(half, half)     # bottom-right
	]

	# Rotate each offset around center
	var rotated = []
	for offset in offsets:
		var rotated_offset = Vector2(
			offset.x * cos_r - offset.y * sin_r,
			offset.x * sin_r + offset.y * cos_r
		)
		rotated.append(center + rotated_offset)

	var tl = rotated[0]
	var corner_tr = rotated[1]
	var bl = rotated[2]
	var br = rotated[3]

	# UV coordinates from atlas rect (NOT rotated - texture stays fixed)
	var uv_tl = Vector2(uv_rect.position.x, uv_rect.position.y)
	var uv_tr = Vector2(uv_rect.position.x + uv_rect.size.x, uv_rect.position.y)
	var uv_bl = Vector2(uv_rect.position.x, uv_rect.position.y + uv_rect.size.y)
	var uv_br = Vector2(uv_rect.position.x + uv_rect.size.x, uv_rect.position.y + uv_rect.size.y)

	# Triangle 1: tl, corner_tr, br
	_points.append(tl); _uvs.append(uv_tl); _colors.append(color)
	_points.append(corner_tr); _uvs.append(uv_tr); _colors.append(color)
	_points.append(br); _uvs.append(uv_br); _colors.append(color)

	# Triangle 2: tl, br, bl
	_points.append(tl); _uvs.append(uv_tl); _colors.append(color)
	_points.append(br); _uvs.append(uv_br); _colors.append(color)
	_points.append(bl); _uvs.append(uv_bl); _colors.append(color)

	_layer_count += 1


func add_arc_layer(pos: Vector2, radius: float, from_angle: float, to_angle: float, width: float, color: Color) -> void:
	# Add an arc layer using dynamic geometry (batched).

	# For variable-angle arcs that can't be pre-rendered.
	if color.a < 0.01:
		return

	if radius < 0.5 or width < 0.5:
		return

	var inner_radius = radius - width * 0.5
	var outer_radius = radius + width * 0.5
	if inner_radius < 0:
		inner_radius = 0

	var angle_span = to_angle - from_angle
	if absf(angle_span) < 0.01:
		return

	# Calculate segments based on arc length
	var segments = maxi(8, int(absf(angle_span) * ARC_SEGMENTS / TAU))

	for i in range(segments):
		var t1 = float(i) / float(segments)
		var t2 = float(i + 1) / float(segments)

		var a1 = from_angle + angle_span * t1
		var a2 = from_angle + angle_span * t2

		var cos1 = cos(a1)
		var sin1 = sin(a1)
		var cos2 = cos(a2)
		var sin2 = sin(a2)

		var inner1 = pos + Vector2(cos1 * inner_radius, sin1 * inner_radius)
		var outer1 = pos + Vector2(cos1 * outer_radius, sin1 * outer_radius)
		var inner2 = pos + Vector2(cos2 * inner_radius, sin2 * inner_radius)
		var outer2 = pos + Vector2(cos2 * outer_radius, sin2 * outer_radius)

		# Triangle 1: inner1, outer1, inner2
		_arc_points.append(inner1)
		_arc_points.append(outer1)
		_arc_points.append(inner2)
		_arc_colors.append(color)
		_arc_colors.append(color)
		_arc_colors.append(color)

		# Triangle 2: inner2, outer1, outer2
		_arc_points.append(inner2)
		_arc_points.append(outer1)
		_arc_points.append(outer2)
		_arc_colors.append(color)
		_arc_colors.append(color)
		_arc_colors.append(color)

	_arc_count += 1


func add_filled_arc(pos: Vector2, radius: float, from_angle: float, to_angle: float, color: Color) -> void:
	# Add a filled arc (pie slice) using dynamic geometry.
	if color.a < 0.01:
		return

	if radius < 0.5:
		return

	var angle_span = to_angle - from_angle
	if absf(angle_span) < 0.01:
		return

	var segments = maxi(8, int(absf(angle_span) * ARC_SEGMENTS / TAU))

	for i in range(segments):
		var t1 = float(i) / float(segments)
		var t2 = float(i + 1) / float(segments)

		var a1 = from_angle + angle_span * t1
		var a2 = from_angle + angle_span * t2

		var p1 = pos + Vector2(cos(a1), sin(a1)) * radius
		var p2 = pos + Vector2(cos(a2), sin(a2)) * radius

		# Triangle: center, p1, p2 (fan triangulation)
		_arc_points.append(pos)
		_arc_points.append(p1)
		_arc_points.append(p2)
		_arc_colors.append(color)
		_arc_colors.append(color)
		_arc_colors.append(color)

	_arc_count += 1


func flush() -> void:
	# Submit all batched draws to RenderingServer.

	# ONE draw call for textured quads (atlas), ONE for arcs (untextured).
	# Uses pre-allocated indices arrays to avoid slow GDScript loops.
	if not _canvas_item.is_valid():
		return

	# Track counts for pre-allocation next frame
	_last_vertex_count = _points.size()
	_last_arc_count = _arc_points.size()

	# Draw atlas-textured geometry (circles from templates)
	var point_count = _points.size()
	if point_count > 0 and _atlas_texture:
		# Ensure indices array is large enough
		_ensure_indices_capacity(point_count)

		# Submit with indices slice
		RenderingServer.canvas_item_add_triangle_array(
			_canvas_item,
			_indices.slice(0, point_count),
			_points,
			_colors,
			_uvs,
			_empty_bones,
			_empty_weights,
			_atlas_texture.get_rid()
		)
		_draw_calls += 1

	# Draw untextured arc geometry
	var arc_count = _arc_points.size()
	if arc_count > 0:
		_ensure_arc_indices_capacity(arc_count)

		RenderingServer.canvas_item_add_triangle_array(
			_canvas_item,
			_arc_indices.slice(0, arc_count),
			_arc_points,
			_arc_colors,
			PackedVector2Array(),  # No UVs for solid color
			_empty_bones,
			_empty_weights
			# No texture RID = solid color triangles
		)
		_draw_calls += 1


func is_atlas_built() -> bool:
	# Check if atlas is ready for use.
	return _atlas_built


func get_atlas_texture() -> ImageTexture:
	# Get the atlas texture (for debugging/visualization).
	return _atlas_texture


func release_resources() -> void:
	# Release atlas texture and batched draw state before shutdown.
	_canvas_item = RID()
	_points.clear()
	_uvs.clear()
	_colors.clear()
	_arc_points.clear()
	_arc_colors.clear()
	_template_uvs.clear()
	_atlas_texture = null
	_atlas_image = null
	_atlas_built = false


func get_stats() -> Dictionary:
	# Get batching statistics for performance monitoring.
	var total_verts = _last_vertex_count + _last_arc_count
	return {
		"layer_count": _layer_count,
		"arc_count": _arc_count,
		"draw_calls": _draw_calls,
		"templates": _template_uvs.size(),
		"atlas_size": Vector2i(ATLAS_WIDTH, ATLAS_HEIGHT),
		"vertex_count": total_verts,
		"triangle_count": total_verts / 3,
	}


# =============================================================================
# HIGH-LEVEL BUBBLE DRAWING API
# =============================================================================
# These methods mirror the C++ batched_bubble_renderer.cpp visual layers
# for direct use. Call these instead of low-level add_circle_layer().

func draw_station(pos: Vector2, base_radius: float, anim_scale: float, anim_alpha: float,
				  theme: Dictionary, ripeness: float, phi: float, coherence: float,
				  is_measured: bool, is_celestial: bool, time: float,
				  frame_chi: float = NAN,
				  fiber_gamma: float = NAN,
				  fiber_closed: bool = false,
				  stay_home: bool = false) -> void:
	# Mini-Metro STATION (2026-07-07). Replaces the 10-layer bubble (glows,
	# gloss, season wedges, spin spiral, uncertainty/purity rings, sink
	# particles — all deleted). Max three signals per station:
	#   disc — identity: flat paper on the zone's dark field (ink-inverted when
	#          measured; the glyph is drawn by the emoji pass on top)
	#   ring — PAYOFF / MIXEDNESS: expected pop payoff H(p)/ln2 in the global
	#          accent gold (NOT Berry Ω — that lives on the plot-tile violet
	#          arc). Filling clockwise from 12 o'clock; measured = pinned full
	#          + the established cyan double ring (a bankable readout — pop me)
	#   dot  — PHASE: a small ink dot riding the ring at angle phi,
	#          alpha = coherence (r_xy ∈ [0,1]) — phase visibly rotates,
	#          decoherence visibly fades
	#   dial — GAUGE FRAME (opt-in; NAN = off): four faint tick marks rotated
	#          by the plot's chosen local convention χ. Turning the compass
	#          rotates the FACE; the phase dot (physics) stays put — the
	#          What Turns II lesson, drawn. Gated by UIProgression
	#          ("gauge_overlay") at the caller; this layer only renders what
	#          it is handed.
	if anim_scale <= 0.0 or anim_alpha <= 0.0:
		return
	var r := base_radius * anim_scale
	var paper: Color = theme.get("paper", Color(0.95, 0.95, 0.92))
	var ink: Color = theme.get("ink", Color(0.08, 0.09, 0.1))
	var accent: Color = theme.get("accent", Color(1.0, 0.8, 0.3))

	# — Disc —
	var fill := ink if is_measured else paper
	fill.a = anim_alpha
	add_circle_layer("circle_100", pos, r, fill)

	# — Outline —
	if is_measured:
		add_arc_layer(pos, r * 1.08, 0, TAU, 4.0, Color(0.0, 1.0, 1.0, 0.95 * anim_alpha))
		add_arc_layer(pos, r * 1.00, 0, TAU, 2.0, Color(1.0, 1.0, 1.0, 0.9 * anim_alpha))
	else:
		var outline: Color
		if is_celestial:
			outline = Color(1.0, 0.9, 0.35, 0.95 * anim_alpha)
		else:
			outline = Color(ink.r, ink.g, ink.b, 0.9 * anim_alpha)
		add_arc_layer(pos, r * 1.02, 0, TAU, 2.0, outline)

	# — Ripeness ring —
	var f := clampf(ripeness, 0.0, 1.0)
	var ring_r := r * 1.18
	if is_measured:
		add_arc_layer(pos, ring_r, 0, TAU, 3.0,
				Color(accent.r, accent.g, accent.b, 0.95 * anim_alpha))
	elif f > 0.02:
		add_arc_layer(pos, ring_r, 0, TAU, 1.5,
				Color(accent.r, accent.g, accent.b, 0.15 * anim_alpha))
		var f4 := f * f * f * f
		var w := 2.0 + 2.5 * f4 * (0.5 + 0.5 * sin(TAU * 0.8 * time))
		add_arc_layer(pos, ring_r, -PI / 2.0, -PI / 2.0 + TAU * f, w,
				Color(accent.r, accent.g, accent.b, (0.55 + 0.4 * f) * anim_alpha))

	# — Phase dot —
	if not is_measured and coherence > 0.02:
		var dot_alpha := clampf(coherence, 0.0, 1.0) * anim_alpha
		var dot_color := Color(1.0, 0.9, 0.35, dot_alpha) if is_celestial \
				else Color(ink.r, ink.g, ink.b, dot_alpha)
		add_circle_layer("circle_100", pos + Vector2.from_angle(phi) * ring_r, 3.0, dot_color)

	# — Gauge dial —
	if not is_nan(frame_chi) and not is_measured:
		var tick_r := ring_r * 0.88
		for k in range(4):
			var ang := frame_chi + float(k) * TAU / 4.0
			# The χ tick (k = 0) is the dial's zero marker — brighter and
			# longer, so a quarter-turn of convention is legible at a glance.
			var is_zero := k == 0
			var half_span := 0.10 if is_zero else 0.055
			var tick_alpha := (0.55 if is_zero else 0.3) * anim_alpha
			add_arc_layer(pos, tick_r, ang - half_span, ang + half_span,
					3.0 if is_zero else 2.0, Color(ink.r, ink.g, ink.b, tick_alpha))

	# — Fiber ticks (What Turns I): seed at 0, live end at γ = Ω/2.
	# Only drawn for tracked / frozen stations (caller passes a real gamma).
	# Leave the physics phase-dot (φ) alone.
	if not is_nan(fiber_gamma) and not is_measured:
		var fiber_r := ring_r * 1.30
		var seed_ang := -PI / 2.0
		var live_ang := seed_ang + fiber_gamma
		var fiber_col := Color(0.55, 0.25, 0.75, 0.85 * anim_alpha)
		if fiber_closed:
			add_arc_layer(pos, fiber_r, 0.0, TAU, 2.0, Color(0.55, 0.25, 0.75, 0.55 * anim_alpha))
		else:
			var gap := wrapf(fiber_gamma, 0.0, TAU)
			if gap > 0.02:
				add_arc_layer(pos, fiber_r, seed_ang, seed_ang + gap, 2.0, fiber_col)
		add_circle_layer("circle_100", pos + Vector2.from_angle(seed_ang) * fiber_r, 2.5, fiber_col)
		add_circle_layer("circle_100", pos + Vector2.from_angle(live_ang) * fiber_r, 2.5, fiber_col)

	if stay_home and not is_measured:
		var home_col := Color(0.2, 0.55, 0.35, 0.9 * anim_alpha)
		add_circle_layer("circle_100", pos + Vector2(0, -ring_r * 1.48), 3.5, home_col)
