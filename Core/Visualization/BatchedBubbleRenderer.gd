class_name BatchedBubbleRenderer
extends RefCounted

# Shared constants
const VerboseConfig = preload("res://Core/Config/VerboseConfig.gd")

## Batched Bubble Renderer — STATION coordinator (Mini-Metro pass, 2026-07-07)
##
## Feeds BubbleAtlasBatcher.draw_station per node, then draws pole glyphs via
## the emoji atlas. Per-station encoding lives in draw_station (disc + ripeness
## ring + phase dot); this file owns data resolution (viz snapshot → station
## params) and the SOFT dual-glyph pass:
##   both pole glyphs render, sized/faded continuously by dominance d = p0−p1 —
##   at even superposition both sit mid-size side by side; at certainty the
##   dominant glyph is full-size centred and the minor fades out entirely.
##   NO p² alpha: a rare (valuable!) pole is exactly the one you must see.
##
## The old O(n²) shadow-influence pass and the phi-hue body color are deleted.

var _bubble_atlas_batcher = null
var _use_atlas: bool = false
var _warned_missing_bubble_atlas: bool = false
var _warned_missing_sun_bubble_atlas: bool = false

# Emoji draw queue (separate texture pass after the bubble-body flush)
var _emoji_queue: Array = []

var _emoji_batcher: EmojiAtlasBatcher = null


func _init():
	VerboseHelper.debug("viz", "bubble", "Initializing bubble atlas renderer")
	_emoji_batcher = EmojiAtlasBatcher.new()


func set_emoji_atlas_batcher(atlas_batcher: EmojiAtlasBatcher) -> void:
	if atlas_batcher and atlas_batcher._atlas_built:
		_emoji_batcher = atlas_batcher
		VerboseHelper.debug("viz", "bubble", "Using pre-built emoji atlas (%d emojis)" % atlas_batcher._emoji_uvs.size())


func set_bubble_atlas_batcher(atlas_batcher) -> void:
	if atlas_batcher and atlas_batcher.is_atlas_built():
		_bubble_atlas_batcher = atlas_batcher
		_use_atlas = true
		VerboseHelper.debug("viz", "bubble", "Using pre-built bubble atlas")


func is_atlas_enabled() -> bool:
	return _use_atlas


func draw(graph: Node2D, ctx: Dictionary) -> void:
	# Draw all quantum stations.
	var bubble_atlas = ctx.get("bubble_atlas_batcher")
	if bubble_atlas and bubble_atlas != _bubble_atlas_batcher and bubble_atlas.is_atlas_built():
		set_bubble_atlas_batcher(bubble_atlas)

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
	# The celestial station: same draw_station path, gold-ringed via is_celestial.
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
	var theme: Dictionary = BiomeVisualTheme.get_theme(sun_qubit_node.biome_name)
	var p0: float = sun_qubit_node.p_north
	var p1: float = sun_qubit_node.p_south

	_bubble_atlas_batcher.begin(graph.get_canvas_item())
	_bubble_atlas_batcher.draw_station(
		sun_qubit_node.position, sun_qubit_node.radius, anim_scale, anim_alpha,
		theme, VisualizationConstants.ripeness(p0, p1),
		sun_qubit_node.phi_raw, clampf(sun_qubit_node.coherence * 2.0, 0.0, 1.0),
		false, true, ctx.get("time_accumulator", 0.0))
	_bubble_atlas_batcher.flush()

	if _emoji_batcher:
		_emoji_batcher.begin(graph.get_canvas_item())
		_queue_station_glyphs_direct(
			sun_qubit_node.position, sun_qubit_node.radius,
			sun_qubit_node.emoji_north, sun_qubit_node.emoji_south,
			p0, p1, false, anim_alpha)
		_emoji_batcher.flush()
		_emoji_batcher.flush_text_fallbacks(graph)


var _perf_loop_us: int = 0
var _perf_flush_us: int = 0
var _perf_emoji_us: int = 0
var _perf_frame_count: int = 0

func _draw_with_atlas(graph: Node2D, ctx: Dictionary) -> void:
	var t0 = Time.get_ticks_usec()

	var emoji_atlas = ctx.get("emoji_atlas_batcher")
	if emoji_atlas and emoji_atlas != _emoji_batcher and emoji_atlas._atlas_built:
		set_emoji_atlas_batcher(emoji_atlas)

	var quantum_nodes = ctx.get("quantum_nodes", [])
	var biomes = ctx.get("biomes", {})
	var time_accumulator = ctx.get("time_accumulator", 0.0)
	var terminal_pool = ctx.get("terminal_pool")
	var batcher = ctx.get("biome_evolution_batcher", null)

	_emoji_queue.clear()
	_bubble_atlas_batcher.begin(graph.get_canvas_item())

	var theme_by_biome: Dictionary = {}

	for node in quantum_nodes:
		if not node.visible:
			continue
		if not node.plot and node.emoji_north.is_empty():
			continue

		var anim_scale = node.visual_scale
		var anim_alpha = node.visual_alpha
		if anim_scale <= 0.0:
			continue

		var is_measured = _is_node_measured(node, terminal_pool)

		# Resolve the freshest state: interpolated lookahead snapshot when the
		# batcher has one (smooth 60fps phase rotation), else the node's own
		# last-applied snapshot values. All reads stay inside the viz contract.
		var p0: float = node.p_north
		var p1: float = node.p_south
		var phi: float = node.phi_raw
		var coherence: float = clampf(node.coherence * 2.0, 0.0, 1.0)  # node stores r_xy·0.5
		if batcher and batcher.lookahead_enabled and node.register_id >= 0 and not is_measured:
			var snap = batcher.get_interpolated_snapshot(node.biome_name, node.register_id)
			if not snap.is_empty():
				var mass: float = maxf(float(snap.get("p0", 0.5)) + float(snap.get("p1", 0.5)), 1e-6)
				p0 = clampf(float(snap.get("p0", 0.5)) / mass, 0.0, 1.0)
				p1 = 1.0 - p0
				phi = snap.get("phi", phi)
				coherence = clampf(float(snap.get("r_xy", coherence)), 0.0, 1.0)

		var theme: Dictionary
		if theme_by_biome.has(node.biome_name):
			theme = theme_by_biome[node.biome_name]
		else:
			theme = BiomeVisualTheme.get_theme(node.biome_name)
			theme_by_biome[node.biome_name] = theme

		var station_radius: float = node.radius * node.depth_scale

		_bubble_atlas_batcher.draw_station(
			node.position, station_radius, anim_scale, anim_alpha,
			theme, VisualizationConstants.ripeness(p0, p1),
			phi, coherence, is_measured, false, time_accumulator)

		_emoji_queue.append({
			"position": node.position,
			"radius": station_radius,
			"emoji_north": node.emoji_north,
			"emoji_south": node.emoji_south,
			"p_north": p0,
			"p_south": p1,
			"is_measured": is_measured,
			"anim_alpha": anim_alpha,
		})

	var t1 = Time.get_ticks_usec()

	# Flush bubble atlas (ONE or TWO draw calls for all stations)
	_bubble_atlas_batcher.flush()

	var t2 = Time.get_ticks_usec()

	_draw_emoji_pass(graph)

	var t3 = Time.get_ticks_usec()

	_perf_loop_us += (t1 - t0)
	_perf_flush_us += (t2 - t1)
	_perf_emoji_us += (t3 - t2)
	_perf_frame_count += 1

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
	# Soft dual-glyph pass — see class doc. One atlas flush for all glyphs.
	if not _emoji_batcher:
		return

	_emoji_batcher.begin(graph.get_canvas_item())

	for emoji_data in _emoji_queue:
		_queue_station_glyphs_direct(
			emoji_data["position"], emoji_data["radius"],
			emoji_data["emoji_north"], emoji_data["emoji_south"],
			emoji_data["p_north"], emoji_data["p_south"],
			emoji_data["is_measured"], emoji_data["anim_alpha"])

	_emoji_batcher.flush()
	_emoji_batcher.flush_text_fallbacks(graph)


func _queue_station_glyphs_direct(pos: Vector2, radius: float,
		emoji_north: String, emoji_south: String,
		p0: float, p1: float, is_measured: bool, anim_alpha: float) -> void:
	# Continuous dominance encoding (soft geometry — no thresholds, no snap):
	#   d = p0 − p1 ∈ [−1, 1]
	#   dominant glyph: scale 0.7→1.0, centred as |d|→1
	#   minor glyph:    scale 0.7→0.4, fades out as |d|→1
	# At d=0 both glyphs sit mid-size on opposite shoulders — superposition is
	# visibly TWO things at once; a measured station shows only its outcome.
	var base_size := radius * 1.2

	if is_measured:
		# Outcome glyph only (apply_measured_visual pins p to 1/0).
		var outcome := emoji_north if p0 >= p1 else emoji_south
		if outcome != "":
			_emoji_batcher.add_emoji_by_name(pos, Vector2(base_size, base_size),
					outcome, Color(1, 1, 1, anim_alpha))
		return

	var d := clampf(p0 - p1, -1.0, 1.0)
	var ad := absf(d)
	var offset := radius * 0.34 * (1.0 - ad)  # shoulders at superposition, centre at certainty

	var north_scale := 0.7 + 0.3 * clampf(d, 0.0, 1.0) - 0.3 * clampf(-d, 0.0, 1.0)
	var south_scale := 0.7 + 0.3 * clampf(-d, 0.0, 1.0) - 0.3 * clampf(d, 0.0, 1.0)
	var north_alpha := clampf(2.0 * p0, 0.0, 1.0) * anim_alpha
	var south_alpha := clampf(2.0 * p1, 0.0, 1.0) * anim_alpha

	# Draw the minor glyph first so the dominant stays on top when they overlap.
	var north_first := p0 < p1
	for pass_i in range(2):
		var draw_north := (pass_i == 0) == north_first
		if draw_north:
			if emoji_north != "" and north_alpha > 0.02:
				var sz := base_size * north_scale
				_emoji_batcher.add_emoji_by_name(pos + Vector2(-offset, -offset * 0.4),
						Vector2(sz, sz), emoji_north, Color(1, 1, 1, north_alpha))
		else:
			if emoji_south != "" and south_alpha > 0.02:
				var sz2 := base_size * south_scale
				_emoji_batcher.add_emoji_by_name(pos + Vector2(offset, offset * 0.4),
						Vector2(sz2, sz2), emoji_south, Color(1, 1, 1, south_alpha))


func _is_node_measured(node, _terminal_pool) -> bool:
	if not node:
		return false
	if node.plot != null and node.plot.is_measured:
		return true
	if node.terminal and node.terminal.is_measured:
		return true
	return false


func get_emoji_stats() -> Dictionary:
	if _emoji_batcher:
		return _emoji_batcher.get_stats()
	return {"emoji_count": 0, "draw_calls": 0, "unique_textures": 0, "savings": 0}


func get_bubble_stats() -> Dictionary:
	if _bubble_atlas_batcher:
		return _bubble_atlas_batcher.get_stats()
	return {"layer_count": 0, "arc_count": 0, "draw_calls": 0, "templates": 0}


func is_native_enabled() -> bool:
	# Compatibility query. Native bubble renderer is no longer a live tier.
	return false


func get_renderer_type() -> String:
	if _use_atlas:
		return "atlas"
	return "unavailable"


func compact_buffer() -> void:
	# Compatibility no-op: atlas renderer owns its own buffers.
	pass


func release_resources() -> void:
	if _emoji_batcher and _emoji_batcher.has_method("release_resources"):
		_emoji_batcher.release_resources()
	if _bubble_atlas_batcher and _bubble_atlas_batcher.has_method("release_resources"):
		_bubble_atlas_batcher.release_resources()
	_emoji_queue.clear()
	_bubble_atlas_batcher = null
	_emoji_batcher = null
	_use_atlas = false
	_warned_missing_bubble_atlas = false
