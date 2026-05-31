class_name BatchedBubbleRenderer
extends RefCounted

# Shared constants
const VerboseConfig = preload("res://Core/Config/VerboseConfig.gd")

## Batched Bubble Renderer - Atlas Production Path
##
## BubbleAtlasBatcher is the one live bubble body renderer. The old native C++
## triangulation tier is not registered, and the old immediate GDScript bubble
## renderer was removed from this production coordinator.

# Atlas renderer (GPU texture batching - fastest)
# Note: Untyped to avoid circular dependency with BubbleAtlasBatcher.gd load order
var _bubble_atlas_batcher = null
var _use_atlas: bool = false
var _warned_missing_bubble_atlas: bool = false
var _warned_missing_sun_bubble_atlas: bool = false

# Emoji draw queue (emojis can't be batched - separate pass)
var _emoji_queue: Array = []

# Emoji batcher for reduced draw calls (group by texture)
var _emoji_batcher: EmojiAtlasBatcher = null

# Shadow influence cache (computed once per frame)
var _shadow_influences: Dictionary = {}  # node_instance_id → {tint: Color, strength: float}
var _shadow_compute_enabled: bool = false

# Season constants - imported from shared source
const SEASON_ANGLES = VisualizationConstants.SEASON_ANGLES
const SEASON_COLORS = VisualizationConstants.SEASON_COLORS


func _init():
	VerboseHelper.debug("viz", "bubble", "Initializing bubble atlas renderer")
	_emoji_batcher = EmojiAtlasBatcher.new()


func set_emoji_atlas_batcher(atlas_batcher: EmojiAtlasBatcher) -> void:
	# Set a pre-built emoji atlas batcher for GPU-accelerated emoji rendering.

	# Call this after building the atlas during boot to enable fast batched drawing.
	if atlas_batcher and atlas_batcher._atlas_built:
		_emoji_batcher = atlas_batcher
		VerboseHelper.debug("viz", "bubble", "Using pre-built emoji atlas (%d emojis)" % atlas_batcher._emoji_uvs.size())


func set_bubble_atlas_batcher(atlas_batcher) -> void:
	# Set a pre-built bubble atlas batcher for GPU-accelerated bubble rendering.

	# Call this after building the atlas during boot to enable fast batched drawing.
	if atlas_batcher and atlas_batcher.is_atlas_built():
		_bubble_atlas_batcher = atlas_batcher
		_use_atlas = true
		VerboseHelper.debug("viz", "bubble", "Using pre-built bubble atlas")


func is_atlas_enabled() -> bool:
	# Check if GPU atlas bubble renderer is being used.
	return _use_atlas


func draw(graph: Node2D, ctx: Dictionary) -> void:
	# Draw all quantum bubbles.

	# Args:
	# graph: The QuantumForceGraph node (for drawing calls)
	# ctx: Context with {quantum_nodes, biomes, time_accumulator, terminal_pool, etc.}
	# Check for pre-built bubble atlas in context (first-time setup)
	var bubble_atlas = ctx.get("bubble_atlas_batcher")
	if bubble_atlas and bubble_atlas != _bubble_atlas_batcher and bubble_atlas.is_atlas_built():
		set_bubble_atlas_batcher(bubble_atlas)

	# Pass the geometry batcher to the emoji batcher for batched bubble rendering.
	var geometry_batcher = ctx.get("geometry_batcher")
	if geometry_batcher and _emoji_batcher and _emoji_batcher._geometry_batcher != geometry_batcher:
		_emoji_batcher.set_geometry_batcher(geometry_batcher)

	if not _use_atlas or not _bubble_atlas_batcher:
		if not _warned_missing_bubble_atlas:
			VerboseHelper.warn("viz", "bubble", "Bubble atlas unavailable; skipping bubble body pass")
			_warned_missing_bubble_atlas = true
		return

	_draw_with_atlas(graph, ctx)


func draw_sun_qubit(graph: Node2D, ctx: Dictionary) -> void:
	# Draw the top-layer sun qubit as a dedicated celestial bubble.
	#
	# This stays separate from the normal bubble pass so it can be layered
	# above the geometry batch without becoming a second bubble ontology.
	var sun_qubit_node = ctx.get("sun_qubit_node")
	if not sun_qubit_node or not sun_qubit_node.visible:
		return

	var bubble_atlas = ctx.get("bubble_atlas_batcher")
	if bubble_atlas and bubble_atlas != _bubble_atlas_batcher and bubble_atlas.is_atlas_built():
		set_bubble_atlas_batcher(bubble_atlas)

	var geometry_batcher = ctx.get("geometry_batcher")
	if geometry_batcher and _emoji_batcher and _emoji_batcher._geometry_batcher != geometry_batcher:
		_emoji_batcher.set_geometry_batcher(geometry_batcher)

	if not _use_atlas or not _bubble_atlas_batcher:
		if not _warned_missing_sun_bubble_atlas:
			VerboseHelper.warn("viz", "bubble", "Bubble atlas unavailable; skipping sun qubit pass")
			_warned_missing_sun_bubble_atlas = true
		return

	var anim_scale: float = sun_qubit_node.visual_scale if sun_qubit_node.visual_scale > 0.0 else 1.0
	var anim_alpha: float = sun_qubit_node.visual_alpha if sun_qubit_node.visual_alpha > 0.0 else 1.0
	var base_color: Color = sun_qubit_node.color
	if base_color == Color(0, 0, 0, 0):
		base_color = Color(1.0, 0.88, 0.34, 1.0)

	var p_north: float = sun_qubit_node.emoji_north_opacity
	var p_south: float = sun_qubit_node.emoji_south_opacity
	var global_prob: float = clampf(p_north + p_south, 0.0, 1.0)

	_bubble_atlas_batcher.begin(graph.get_canvas_item())
	_bubble_atlas_batcher.draw_bubble(
		sun_qubit_node.position,
		sun_qubit_node.radius,
		anim_scale,
		anim_alpha,
		base_color,
		ctx.get("time_accumulator", 0.0),
		false,
		true,
		global_prob,
		p_north,
		p_south,
		0.0,
		0.0,
		sun_qubit_node.phi_raw,
		sun_qubit_node.season_projections,
		sun_qubit_node.coherence,
		sun_qubit_node.purity,
		{},
		sun_qubit_node.berry_phase
	)
	_bubble_atlas_batcher.flush()

	if _emoji_batcher:
		_emoji_batcher.begin(graph.get_canvas_item())
		var size = Vector2(int(sun_qubit_node.radius * 1.32), int(sun_qubit_node.radius * 1.32))
		if sun_qubit_node.emoji_south != "" and p_south > 0.01:
			_emoji_batcher.add_emoji_by_name(sun_qubit_node.position, size, sun_qubit_node.emoji_south, Color(1, 1, 1, p_south))
		if sun_qubit_node.emoji_north != "" and p_north > 0.01:
			_emoji_batcher.add_emoji_by_name(sun_qubit_node.position, size, sun_qubit_node.emoji_north, Color(1, 1, 1, p_north))
		_emoji_batcher.flush()
		_emoji_batcher.flush_text_fallbacks(graph)


var _perf_loop_us: int = 0
var _perf_flush_us: int = 0
var _perf_emoji_us: int = 0
var _perf_frame_count: int = 0

func _draw_with_atlas(graph: Node2D, ctx: Dictionary) -> void:
	# Draw all bubbles using GPU texture atlas batching.

	# This is the fastest path - pre-rendered templates + per-vertex color modulation.
	var t0 = Time.get_ticks_usec()

	# Check for pre-built emoji atlas in context
	var emoji_atlas = ctx.get("emoji_atlas_batcher")
	if emoji_atlas and emoji_atlas != _emoji_batcher and emoji_atlas._atlas_built:
		set_emoji_atlas_batcher(emoji_atlas)

	var quantum_nodes = ctx.get("quantum_nodes", [])
	var biomes = ctx.get("biomes", {})
	var time_accumulator = ctx.get("time_accumulator", 0.0)
	var terminal_pool = ctx.get("terminal_pool")
	var batcher = ctx.get("biome_evolution_batcher", null)

	# Compute shadow influences once per frame (O(n²) but n is small)
	if _shadow_compute_enabled:
		_compute_shadow_influences(quantum_nodes, biomes)

	_emoji_queue.clear()
	_bubble_atlas_batcher.begin(graph.get_canvas_item())

	for node in quantum_nodes:
		if not node.visible:
			continue
		if not node.plot and node.emoji_north.is_empty():
			continue

		# FAST PATH: Get interpolated phi for smooth wedge rotation
		# Avoids expensive full update_from_quantum_state() call
		var interpolated_phi = node.phi_raw
		var interpolated_coherence = node.coherence
		var biome = biomes.get(node.biome_name) if node.biome_name != "" else null
		if batcher and batcher.lookahead_enabled and biome and biome.viz_cache:
			var qubit_idx = biome.viz_cache.get_qubit(node.emoji_north)
			if qubit_idx >= 0:
				var snap = batcher.get_interpolated_snapshot(node.biome_name, qubit_idx)
				if not snap.is_empty():
					interpolated_phi = snap.get("phi", node.phi_raw)
					var r_xy = snap.get("r_xy", 0.0)
					interpolated_coherence = r_xy * 0.5
					# Update season projections from interpolated phi
					for i in range(3):
						var angle_diff = interpolated_phi - node.SEASON_ANGLES[i]
						node.season_projections[i] = (1.0 + cos(angle_diff)) * 0.5 * interpolated_coherence

		# Get bubble parameters
		var anim_scale = node.visual_scale
		var anim_alpha = node.visual_alpha
		if anim_scale <= 0.0:
			continue

		var is_measured = _is_node_measured(node, terminal_pool)
		var is_celestial = false  # Regular bubbles, not sun

		# Get probability data
		var global_prob = 0.0
		var p_north = 0.0
		var p_south = 0.0
		var sink_flux = 0.0

		p_north = node.emoji_north_opacity
		p_south = node.emoji_south_opacity
		global_prob = clampf(p_north + p_south, 0.0, 1.0)

		# Get shadow influence for this node (computed earlier this frame)
		var shadow_influence = _shadow_influences.get(node.get_instance_id(), {})

		# Compute phi-driven color from season projections
		var phi_color = _compute_phi_color(node)
		# Blend phi color with original (70% phi, 30% original for stability)
		var base_color = phi_color.lerp(node.color, 0.3)

		# Draw bubble with all visual layers (including spinning wedges)
		# Use interpolated phi/coherence for smooth 60fps wedge rotation
		_bubble_atlas_batcher.draw_bubble(
			node.position,
			node.radius,
			anim_scale,
			anim_alpha,
			base_color,  # Phi-driven color
			time_accumulator,
			is_measured,
			is_celestial,
			global_prob,
			p_north,
			p_south,
			sink_flux,
			0.0,
			interpolated_phi,
			node.season_projections,
			interpolated_coherence,
			node.purity,
			shadow_influence,
			node.berry_phase  # Berry phase drives glow intensity
		)

		# Queue emoji for drawing
		_emoji_queue.append({
			"position": node.position,
			"radius": node.radius,
			"emoji_north": node.emoji_north,
			"emoji_south": node.emoji_south,
			"emoji_north_opacity": node.emoji_north_opacity,
			"emoji_south_opacity": node.emoji_south_opacity,
			"is_celestial": false
		})

	var t1 = Time.get_ticks_usec()

	# Flush bubble atlas (ONE or TWO draw calls for all bubbles!)
	_bubble_atlas_batcher.flush()

	var t2 = Time.get_ticks_usec()

	# Draw emojis (batched via GPU atlas when available)
	_draw_emoji_pass(graph)

	var t3 = Time.get_ticks_usec()

	# Accumulate timing
	_perf_loop_us += (t1 - t0)
	_perf_flush_us += (t2 - t1)
	_perf_emoji_us += (t3 - t2)
	_perf_frame_count += 1

	# Report every 120 frames
	if _perf_frame_count >= 120:
		var loop_ms = _perf_loop_us / 1000.0 / _perf_frame_count
		var flush_ms = _perf_flush_us / 1000.0 / _perf_frame_count
		var emoji_ms = _perf_emoji_us / 1000.0 / _perf_frame_count
		var total_ms = loop_ms + flush_ms + emoji_ms
		if VerboseConfig.safe_allows("perf_hud", VerboseConfig.LogLevel.DEBUG):
			VerboseHelper.debug("perf_hud", "bubble", "loop=%.2fms flush=%.2fms emoji=%.2fms total=%.2fms" % [
				loop_ms, flush_ms, emoji_ms, total_ms
			])
		_perf_loop_us = 0
		_perf_flush_us = 0
		_perf_emoji_us = 0
		_perf_frame_count = 0


func _draw_emoji_pass(graph: Node2D) -> void:
	# Draw all emojis using GPU-batched atlas rendering.

	# When atlas is built: ONE draw call for all emojis (fast!)
	# Fallback: Text rendering for emojis not in atlas (slow but works)
	if not _emoji_batcher:
		return

	_emoji_batcher.begin(graph.get_canvas_item())

	for emoji_data in _emoji_queue:
		var pos = emoji_data["position"]
		var radius = emoji_data["radius"]
		var is_celestial = emoji_data["is_celestial"]
		var font_size = int(radius * (1.1 if is_celestial else 1.0))
		var size = Vector2(font_size, font_size) * 1.2

		# South emoji (behind) - draw first for correct z-order
		var emoji_south = emoji_data["emoji_south"]
		var south_opacity = emoji_data["emoji_south_opacity"]
		if emoji_south != "" and south_opacity > 0.01:
			# Use atlas-based rendering (fast path)
			_emoji_batcher.add_emoji_by_name(pos, size, emoji_south, Color(1, 1, 1, south_opacity))

		# North emoji (front)
		var emoji_north = emoji_data["emoji_north"]
		var north_opacity = emoji_data["emoji_north_opacity"]
		if emoji_north != "" and north_opacity > 0.01:
			# Use atlas-based rendering (fast path)
			_emoji_batcher.add_emoji_by_name(pos, size, emoji_north, Color(1, 1, 1, north_opacity))

	# Flush batched atlas emojis (ONE DRAW CALL!)
	_emoji_batcher.flush()

	# Flush any text fallbacks (emojis not in atlas)
	_emoji_batcher.flush_text_fallbacks(graph)


func _is_node_measured(node, _terminal_pool) -> bool:
	# Check if node has been measured.
	if not node:
		return false
	if node.plot != null and node.plot.is_measured:
		return true
	if node.terminal and node.terminal.is_measured:
		return true
	return false


func _compute_shadow_influences(nodes: Array, biomes: Dictionary) -> void:
	# Compute shadow influences for all nodes (O(n²) but n is small ~24).

	# When bubble B is in bubble A's dominant wedge direction AND they have
	# Hamiltonian coupling, B's wedges get tinted toward A's dominant season.
	_shadow_influences.clear()

	var node_count = nodes.size()
	if node_count < 2:
		return

	# Build lookup for fast node access
	var visible_nodes = []
	for node in nodes:
		if node.visible and node.coherence > 0.05:
			visible_nodes.append(node)

	var n = visible_nodes.size()
	if n < 2:
		return

	# For each node B, accumulate influences from all nodes A
	for node_b in visible_nodes:
		var accumulated_tint = Color.WHITE
		var accumulated_strength = 0.0

		for node_a in visible_nodes:
			if node_a == node_b:
				continue

			# Skip if A has weak coherence (no clear season)
			if node_a.coherence < 0.1:
				continue

			# Get A's season projections
			var proj_a = node_a.season_projections
			if proj_a.size() < 3:
				continue

			# Find A's dominant season
			var dominant_idx = 0
			var dominant_intensity = proj_a[0]
			for i in range(1, 3):
				if proj_a[i] > dominant_intensity:
					dominant_idx = i
					dominant_intensity = proj_a[i]

			# Skip if dominant season is weak
			if dominant_intensity < 0.15:
				continue

			# A's wedge angle = season angle + phi rotation
			var wedge_angle = SEASON_ANGLES[dominant_idx] + node_a.phi_raw

			# Vector from A to B
			var a_to_b = node_b.position - node_a.position
			var dist = a_to_b.length()

			# Skip if too far (max influence distance 300px)
			if dist > 300.0 or dist < 1.0:
				continue

			var angle_to_b = a_to_b.angle()

			# Check if B is within A's wedge cone (30° half-angle)
			var angle_diff = _wrap_angle(wedge_angle - angle_to_b)
			var wedge_half_angle = PI / 6.0  # 30 degrees

			if absf(angle_diff) > wedge_half_angle:
				continue

			# Get coupling strength from biome viz_cache
			var coupling = 0.0
			if node_a.biome_name != "" and biomes.has(node_a.biome_name):
				var biome = biomes[node_a.biome_name]
				if biome and biome.viz_cache:
					var couplings = biome.viz_cache.get_hamiltonian_couplings(node_a.emoji_north)
					coupling = couplings.get(node_b.emoji_north, 0.0)

			# Skip if no coupling
			if coupling < 0.01:
				continue

			# Compute influence strength
			var distance_factor = 1.0 - clampf(dist / 300.0, 0.0, 1.0)
			var angle_factor = 1.0 - absf(angle_diff) / wedge_half_angle
			var strength = coupling * distance_factor * angle_factor * dominant_intensity

			# Accumulate weighted tint
			var season_color = SEASON_COLORS[dominant_idx]
			accumulated_tint = accumulated_tint.lerp(season_color, strength * 0.4)
			accumulated_strength = minf(accumulated_strength + strength, 1.0)

		# Store influence for this node
		if accumulated_strength > 0.05:
			_shadow_influences[node_b.get_instance_id()] = {
				"tint": accumulated_tint,
				"strength": accumulated_strength
			}


func _wrap_angle(angle: float) -> float:
	# Wrap angle to [-PI, PI] range.
	while angle > PI:
		angle -= TAU
	while angle < -PI:
		angle += TAU
	return angle


func get_emoji_stats() -> Dictionary:
	# Get emoji batching statistics for performance monitoring.
	if _emoji_batcher:
		return _emoji_batcher.get_stats()
	return {"emoji_count": 0, "draw_calls": 0, "unique_textures": 0, "savings": 0}


func get_bubble_stats() -> Dictionary:
	# Get bubble batching statistics for performance monitoring.
	if _bubble_atlas_batcher:
		return _bubble_atlas_batcher.get_stats()
	return {"layer_count": 0, "arc_count": 0, "draw_calls": 0, "templates": 0}


func is_native_enabled() -> bool:
	# Compatibility query. Native bubble renderer is no longer a live tier.
	return false


func is_shadow_compute_enabled() -> bool:
	# Check if shadow influence computation is enabled.
	return _shadow_compute_enabled


func set_shadow_compute_enabled(enabled: bool) -> void:
	# Enable or disable shadow influence computation.

	# When enabled: O(n²) GDScript computation per frame (disabled by default).
	# Shadow influence tints wedges based on angular coupling between bubbles.

	# Args:
	# enabled: True to enable shadow influence, False to disable
	_shadow_compute_enabled = enabled
	if not enabled:
		_shadow_influences.clear()
	VerboseHelper.debug("viz", "shadow", "Bubble shadow compute %s" % ("enabled" if enabled else "disabled"))


func get_renderer_type() -> String:
	# Get the current active renderer type.
	if _use_atlas:
		return "atlas"
	return "unavailable"


func _compute_phi_color(node) -> Color:
	# Compute bubble interior color driven by phi and season projections.

	# Blends the three season colors (Red/Green/Blue at 0°/120°/240°)
	# based on how strongly phi projects onto each season basis.

	# Args:
	# node: QuantumNode with season_projections array

	# Returns:
	# Color blended from season projections (defaults to neutral gray if no data)
	var projections: Array = node.season_projections
	if projections.size() < 3:
		# No season data - return neutral gray
		return Color(0.5, 0.5, 0.5)

	var r_proj = projections[0]
	var g_proj = projections[1]
	var b_proj = projections[2]

	# Blend season colors weighted by projections
	var blended_color = (
		VisualizationConstants.SEASON_COLORS[0] * r_proj +
		VisualizationConstants.SEASON_COLORS[1] * g_proj +
		VisualizationConstants.SEASON_COLORS[2] * b_proj
	)

	# Normalize by total projection
	var total_proj = r_proj + g_proj + b_proj
	if total_proj > 0.01:
		blended_color = blended_color / total_proj
	else:
		# No projections - default to neutral
		blended_color = Color(0.5, 0.5, 0.5)

	return blended_color


func compact_buffer() -> void:
	# Compatibility no-op: atlas renderer owns its own buffers.
	pass


func release_resources() -> void:
	# Release renderer-owned atlases and queues.
	if _emoji_batcher and _emoji_batcher.has_method("release_resources"):
		_emoji_batcher.release_resources()
	if _bubble_atlas_batcher and _bubble_atlas_batcher.has_method("release_resources"):
		_bubble_atlas_batcher.release_resources()
	_emoji_queue.clear()
	_shadow_influences.clear()
	_bubble_atlas_batcher = null
	_emoji_batcher = null
	_use_atlas = false
	_warned_missing_bubble_atlas = false
