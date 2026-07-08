class_name QuantumEdgeRenderer
extends RefCounted

## Metro-line edge renderer (Mini-Metro pass, 2026-07-07).
##
## The default view draws exactly TWO line classes between stations:
##
##  1. METRO LINES — Hamiltonian couplings. The biome's permanent transit map:
##     one clean line per coupled qubit pair, colored from the global metro
##     palette, width ∝ tanh(|J|/J_ref) (J_ref = biome median, data-relative),
##     with small dots flowing along each line at coupling speed. H is static
##     per biome (icons own it), so pairs are cached and refreshed slowly.
##
##  2. MI OVERLAY — live correlations. White-hot lines that only appear when
##     mutual information rises above a soft ramp; entangled stations visibly
##     link, independent ones stay unconnected. Explicit Bell-pair lines render
##     in the same style with the accent gold.
##
## Deep-physics webs (Lindblad flow arrows, entanglement-cluster hulls) draw
## ONLY while the B microscope is open (ctx.show_inspection_layers) — the
## default view stays a readable map. Deleted outright: plot tethers (stations
## sit ON their plots now — a tether is a self-loop), the disabled coherence
## web, and the food-web knot orbits.
##
## Reveal-on-touch: a line draws only when BOTH endpoint stations are visible —
## edges must not leak the shape of an unexplored field.

## MI web cache: [{node_a, node_b, color, width}] — MI moves at phrame rate,
## positions read live each frame.
var _mi_pair_cache: Array = []
var _mi_cache_frame: int = -1000
const MI_CACHE_STRIDE: int = 6      # Rebuild every 6 frames ≈ 10 Hz at 60 fps

## Metro-line cache: {biome_name -> [{q_a, q_b, width, speed, color}]}.
## Qubit-pair topology from viz_cache H couplings (both poles resolve to their
## qubit; multiple emoji couplings between the same qubit pair aggregate).
var _metro_cache: Dictionary = {}
var _metro_cache_frame: int = -1000
const METRO_CACHE_STRIDE: int = 300  # ~5 s — H only moves on icon incorporation

## Lindblad cache (inspection-only): {biome_name -> [{src, tgt, rate, color}]}
var _lindblad_cache: Dictionary = {}
var _lindblad_cache_frame: int = -1000
const LINDBLAD_CACHE_STRIDE: int = 60


func draw(graph: Node2D, ctx: Dictionary) -> void:
	# Back to front: permanent map, then live correlations, then Bell pairs.
	_draw_metro_lines(graph, ctx)
	_draw_mutual_information_web(graph, ctx)
	_draw_entanglement_lines(graph, ctx)

	if ctx.get("show_inspection_layers", false):
		_draw_lindblad_flow_arrows(graph, ctx)
		_draw_entanglement_clusters(graph, ctx)


# ============================================================================
# METRO LINES — Hamiltonian couplings as the permanent transit map
# ============================================================================

func _draw_metro_lines(graph: Node2D, ctx: Dictionary) -> void:
	var quantum_nodes = ctx.get("quantum_nodes", [])
	var biomes = ctx.get("biomes", {})
	var active_biome = ctx.get("active_biome", "")
	var batcher = ctx.get("geometry_batcher")
	var time: float = ctx.get("time_accumulator", 0.0)

	var current_frame = Engine.get_process_frames()
	if current_frame - _metro_cache_frame >= METRO_CACHE_STRIDE:
		_rebuild_metro_cache(biomes)
		_metro_cache_frame = current_frame

	# register_id → node, per biome (O(n), per frame — nodes move).
	var stations_by_biome: Dictionary = {}
	for node in quantum_nodes:
		if node.register_id < 0 or node.biome_name == "":
			continue
		if not stations_by_biome.has(node.biome_name):
			stations_by_biome[node.biome_name] = {}
		stations_by_biome[node.biome_name][node.register_id] = node

	for biome_name in _metro_cache:
		var stations: Dictionary = stations_by_biome.get(biome_name, {})
		if stations.is_empty():
			continue
		var is_front: bool = (biome_name == active_biome or active_biome == "")
		var line_alpha: float = 0.85 if is_front else 0.22
		for pair in _metro_cache[biome_name]:
			var node_a = stations.get(pair.q_a)
			var node_b = stations.get(pair.q_b)
			if node_a == null or node_b == null:
				continue
			# Never leak unexplored structure: both stations must be revealed.
			if not node_a.visible or not node_b.visible:
				continue
			# Parallel tracks: plot-strip stations are nearly collinear, so each
			# line rides its own small perpendicular offset (like side-by-side
			# metro tracks) instead of stacking into one unreadable stripe.
			var dir: Vector2 = (node_b.position - node_a.position).normalized()
			var track: Vector2 = dir.orthogonal() * pair.track_offset
			var a: Vector2 = node_a.position + track
			var b: Vector2 = node_b.position + track
			var color: Color = pair.color
			color.a = line_alpha
			if batcher:
				batcher.add_line(a, b, color, pair.width)
			else:
				graph.draw_line(a, b, color, pair.width, true)

			# Flow dots — coupling speed made visible (active biome only).
			if is_front:
				var dot_color: Color = pair.color
				dot_color.a = 0.95
				var phase: float = fmod(time * 0.15 * pair.speed + pair.phase, 1.0)
				for k in range(2):
					var t := fmod(phase + 0.5 * float(k), 1.0)
					var p: Vector2 = a.lerp(b, t)
					if batcher:
						batcher.add_circle(p, 2.2, dot_color)
					else:
						graph.draw_circle(p, 2.2, dot_color)


func _rebuild_metro_cache(biomes: Dictionary) -> void:
	_metro_cache.clear()
	for biome_name in biomes:
		var biome = biomes[biome_name]
		if not biome or not biome.viz_cache or not biome.viz_cache.has_metadata():
			continue
		var vc = biome.viz_cache
		var theme: Dictionary = BiomeVisualTheme.get_theme(biome_name)
		var palette: Array = theme.get("line_palette", [Color.WHITE])

		# Aggregate emoji→emoji couplings up to qubit pairs (an icon IS a qubit
		# axis — intra-qubit couplings are the station itself, not a line).
		var strength_by_pair: Dictionary = {}  # Vector2i(min,max) -> max |J|
		for emoji in vc.get_emojis():
			var q_src: int = vc.get_qubit(emoji)
			if q_src < 0:
				continue
			var couplings: Dictionary = vc.get_hamiltonian_couplings(emoji)
			for target_emoji in couplings:
				var q_tgt: int = vc.get_qubit(target_emoji)
				if q_tgt < 0 or q_tgt == q_src:
					continue
				var mag := _coupling_magnitude(couplings[target_emoji])
				if mag < 0.001:
					continue
				var key := Vector2i(mini(q_src, q_tgt), maxi(q_src, q_tgt))
				strength_by_pair[key] = maxf(float(strength_by_pair.get(key, 0.0)), mag)

		if strength_by_pair.is_empty():
			continue

		# Data-relative width/speed: J_ref = median |J| in this biome.
		var mags: Array = strength_by_pair.values()
		mags.sort()
		var j_ref: float = maxf(float(mags[mags.size() / 2]), 1e-6)

		var pairs: Array = []
		var idx := 0
		for key in strength_by_pair:
			var rel: float = float(strength_by_pair[key]) / j_ref
			pairs.append({
				"q_a": key.x,
				"q_b": key.y,
				"width": 1.5 + 3.0 * tanh(rel),
				"speed": rel,
				"phase": float(idx) * 0.37,  # desync dots across lines
				"color": palette[idx % palette.size()],
				"track_offset": float((idx % 5) - 2) * 4.0,
			})
			idx += 1
		_metro_cache[biome_name] = pairs


func _coupling_magnitude(value) -> float:
	if value is float or value is int:
		return absf(float(value))
	if value is Vector2:
		return value.length()
	if value is Complex:
		return value.abs()
	if value is String and value.is_valid_float():
		return absf(value.to_float())
	return 0.0


# ============================================================================
# MI OVERLAY — live correlations
# ============================================================================

func _draw_mutual_information_web(graph: Node2D, ctx: Dictionary) -> void:
	# Soft ramp: nothing below MI 0.05, full presence by 0.25 — independent
	# stations stay unconnected, entangled ones visibly link up.
	var quantum_nodes = ctx.get("quantum_nodes", [])
	var biomes = ctx.get("biomes", {})
	var active_biome = ctx.get("active_biome", "")
	var batcher = ctx.get("geometry_batcher")

	var current_frame = Engine.get_process_frames()
	if current_frame - _mi_cache_frame >= MI_CACHE_STRIDE:
		_rebuild_mi_pair_cache(quantum_nodes, biomes, active_biome)
		_mi_cache_frame = current_frame

	for pair in _mi_pair_cache:
		var node_a = pair.node_a
		var node_b = pair.node_b
		if not is_instance_valid(node_a) or not is_instance_valid(node_b):
			continue
		if not node_a.visible or not node_b.visible:
			continue
		if batcher:
			batcher.add_line(node_a.position, node_b.position, pair.color, pair.width)
		else:
			graph.draw_line(node_a.position, node_b.position, pair.color, pair.width, true)


func _rebuild_mi_pair_cache(quantum_nodes: Array, biomes: Dictionary, active_biome: String) -> void:
	_mi_pair_cache.clear()

	var nodes_by_biome: Dictionary = {}
	for node in quantum_nodes:
		if not node.visible or node.register_id < 0:
			continue
		var biome_name = node.biome_name
		if biome_name == "":
			continue
		if active_biome != "" and biome_name != active_biome:
			continue
		if not nodes_by_biome.has(biome_name):
			nodes_by_biome[biome_name] = []
		nodes_by_biome[biome_name].append(node)

	for biome_name in nodes_by_biome:
		var biome = biomes.get(biome_name)
		if not biome or not biome.viz_cache:
			continue
		var biome_nodes = nodes_by_biome[biome_name]
		for i in range(biome_nodes.size()):
			for j in range(i + 1, biome_nodes.size()):
				var node_a = biome_nodes[i]
				var node_b = biome_nodes[j]
				var mi: float = biome.viz_cache.get_mutual_information(
						node_a.register_id, node_b.register_id)
				var presence := clampf((mi - 0.05) / 0.20, 0.0, 1.0)
				if presence <= 0.0:
					continue
				_mi_pair_cache.append({
					"node_a": node_a,
					"node_b": node_b,
					"color": Color(0.95, 0.97, 1.0, 0.65 * presence),
					"width": 1.0 + 3.0 * tanh(mi),
				})


# ============================================================================
# EXPLICIT BELL-PAIR LINES (gate-created entanglement, accent gold)
# ============================================================================

func _draw_entanglement_lines(graph: Node2D, ctx: Dictionary) -> void:
	var quantum_nodes = ctx.get("quantum_nodes", [])
	var node_by_plot_id = ctx.get("node_by_plot_id", {})
	var batcher = ctx.get("geometry_batcher")
	const GOLD := Color(1.0, 0.8, 0.3)

	var drawn_pairs = {}
	for node in quantum_nodes:
		if not node.visible or not node.plot:
			continue
		for partner_id in node.plot.entangled_plots.keys():
			var partner_node = node_by_plot_id.get(partner_id)
			if not partner_node or not partner_node.visible:
				continue
			var ids = [node.plot_id, partner_id]
			ids.sort()
			var pair_key = "%s_%s" % [ids[0], ids[1]]
			if drawn_pairs.has(pair_key):
				continue
			drawn_pairs[pair_key] = true

			var strength: float = float(node.plot.entangled_plots.get(partner_id, 0.5))
			var width: float = 1.5 + strength * 3.0
			var color := Color(GOLD.r, GOLD.g, GOLD.b, 0.5 + 0.45 * strength)
			var mid = (node.position + partner_node.position) / 2.0
			if batcher:
				batcher.add_line(node.position, partner_node.position, color, width)
				batcher.add_circle(mid, 3.0 + strength * 2.0, color)
			else:
				graph.draw_line(node.position, partner_node.position, color, width, true)
				graph.draw_circle(mid, 3.0 + strength * 2.0, color)


# ============================================================================
# INSPECTION LAYERS — drawn only while the B microscope is open
# ============================================================================

func _draw_lindblad_flow_arrows(graph: Node2D, ctx: Dictionary) -> void:
	# Curved arrows showing dissipative transfer (open-regime biomes).
	var quantum_nodes = ctx.get("quantum_nodes", [])
	var biomes = ctx.get("biomes", {})
	var active_biome = ctx.get("active_biome", "")
	var layout_calculator = ctx.get("layout_calculator")
	var batcher = ctx.get("geometry_batcher")

	var current_frame = Engine.get_process_frames()
	if current_frame - _lindblad_cache_frame >= LINDBLAD_CACHE_STRIDE:
		_rebuild_lindblad_cache(biomes, active_biome)
		_lindblad_cache_frame = current_frame

	for biome_name in _lindblad_cache:
		var emoji_positions: Dictionary = {}
		var biome_center: Vector2 = Vector2.ZERO
		if layout_calculator:
			var oval = layout_calculator.get_biome_oval(biome_name)
			biome_center = oval.get("center", Vector2.ZERO)
		for node in quantum_nodes:
			if node.biome_name == biome_name and node.emoji_north != "":
				emoji_positions[node.emoji_north] = node.position

		for pair in _lindblad_cache[biome_name]:
			var source_pos = emoji_positions.get(pair.src, biome_center)
			var target_pos = emoji_positions.get(pair.tgt, Vector2.ZERO)
			if target_pos == Vector2.ZERO:
				continue
			_draw_flow_arrow(graph, source_pos, target_pos, pair.rate, pair.color, batcher)


func _rebuild_lindblad_cache(biomes: Dictionary, active_biome: String) -> void:
	_lindblad_cache.clear()
	for biome_name in biomes:
		if active_biome != "" and biome_name != active_biome:
			continue
		var biome = biomes[biome_name]
		if not biome or not biome.viz_cache or not biome.viz_cache.has_metadata():
			continue
		var pairs: Array = []
		for emoji in biome.viz_cache.get_emojis():
			var outgoing = biome.viz_cache.get_lindblad_outgoing(emoji)
			for target_emoji in outgoing:
				var rate = outgoing[target_emoji]
				if rate < 0.001:
					continue
				pairs.append({
					"src": emoji,
					"tgt": target_emoji,
					"rate": rate,
					"color": Color(1.0, 0.5, 0.2, 0.5)
				})
		if not pairs.is_empty():
			_lindblad_cache[biome_name] = pairs


func _draw_flow_arrow(graph: Node2D, from_pos: Vector2, to_pos: Vector2, rate: float, color: Color, batcher = null) -> void:
	var direction = (to_pos - from_pos).normalized()
	var distance = from_pos.distance_to(to_pos)
	if distance < 30.0:
		return

	var perp = direction.rotated(PI / 2.0)
	var control = from_pos.lerp(to_pos, 0.5) + perp * distance * 0.2
	var arrow_width = clampf(rate * 3.0 + 1.0, 1.0, 4.0)

	var segments = 12
	var prev_point = from_pos
	for i in range(1, segments + 1):
		var t = float(i) / float(segments)
		var p = (1 - t) * (1 - t) * from_pos + 2 * (1 - t) * t * control + t * t * to_pos
		if batcher:
			batcher.add_line(prev_point, p, color, arrow_width)
		else:
			graph.draw_line(prev_point, p, color, arrow_width, true)
		prev_point = p

	var arrow_size = 8.0
	var arrow_tip = to_pos - direction * 15.0
	var arrow_left = arrow_tip - direction * arrow_size + perp * arrow_size * 0.5
	var arrow_right = arrow_tip - direction * arrow_size - perp * arrow_size * 0.5
	var arrow_color = color
	arrow_color.a = color.a * 1.2
	if batcher:
		batcher.add_colored_polygon([arrow_tip, arrow_left, arrow_right], arrow_color)
	else:
		graph.draw_colored_polygon([arrow_tip, arrow_left, arrow_right], arrow_color)


func _draw_entanglement_clusters(graph: Node2D, ctx: Dictionary) -> void:
	# Convex-hull-ish ring glow around multi-body entangled groups.
	var quantum_nodes = ctx.get("quantum_nodes", [])
	var node_by_plot_id = ctx.get("node_by_plot_id", {})
	var batcher = ctx.get("geometry_batcher")

	if quantum_nodes.is_empty():
		return

	var adjacency: Dictionary = {}
	for node in quantum_nodes:
		if not node.plot:
			continue
		adjacency[node.plot_id] = node.plot.entangled_plots.keys()

	var visited: Dictionary = {}
	var clusters: Array = []
	for node in quantum_nodes:
		if not node.plot or visited.has(node.plot_id):
			continue
		var cluster: Array = []
		var queue: Array = [node.plot_id]
		while not queue.is_empty():
			var current = queue.pop_front()
			if visited.has(current):
				continue
			visited[current] = true
			cluster.append(current)
			for neighbor in adjacency.get(current, []):
				if not visited.has(neighbor):
					queue.append(neighbor)
		if cluster.size() > 1:
			clusters.append(cluster)

	for cluster in clusters:
		if cluster.size() < 2:
			continue
		var positions: Array[Vector2] = []
		for plot_id in cluster:
			var node = node_by_plot_id.get(plot_id)
			if node:
				positions.append(node.position)
		if positions.size() < 2:
			continue

		var centroid = Vector2.ZERO
		for pos in positions:
			centroid += pos
		centroid /= positions.size()

		var max_dist = 0.0
		for pos in positions:
			max_dist = max(max_dist, centroid.distance_to(pos))

		var cluster_color = Color(0.2, 0.9, 1.0, 0.1)
		for ring in range(3):
			var ring_radius = max_dist * (0.8 + float(ring) * 0.3)
			var ring_color = cluster_color
			ring_color.a = cluster_color.a * (1.0 - float(ring) * 0.3)
			if batcher:
				batcher.add_arc(centroid, ring_radius, 0, TAU, 2.0, ring_color)
			else:
				graph.draw_arc(centroid, ring_radius, 0, TAU, 32, ring_color, 2.0, true)
