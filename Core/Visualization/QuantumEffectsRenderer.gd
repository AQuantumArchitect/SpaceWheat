class_name QuantumEffectsRenderer
extends RefCounted

## Quantum Effects Renderer
##
## Draws visual effects with mathematical basis:
##
## KEEP (Mathematical/Game Physics):
## - Strange attractor: Chaotic dynamics in 4D phase space
## - Icon auras: Field influence gradients
## - Icon influence forces: Attractor basins
## - Entanglement particles: Flowing along Bell pair lines
## - Life cycle effects: Spawns, deaths, coherence strikes
##
## REMOVED (No Math Basis):
## - Icon particles: Random spawn with no physics meaning


func draw(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw visual effects.

	Args:
	    graph: The QuantumForceGraph node
	    ctx: Context dictionary
	"""
	_draw_strange_attractor(graph, ctx)
	_draw_energy_transfer_forces(graph, ctx)
	_draw_particles(graph, ctx)
	_draw_life_cycle_effects(graph, ctx)

	# NOTE: Icon auras disabled - causes visual artifacts
	# _draw_icon_auras(graph, ctx)


func update_particles(delta: float, ctx: Dictionary) -> void:
	"""Update particle systems."""
	_update_entanglement_particles(delta, ctx)
	# NOTE: Icon particles REMOVED - no mathematical basis


func _draw_strange_attractor(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw the agricultural-political strange attractor.

	Visualizes the 4D political season cycle as a 2D trajectory.
	Real dynamical systems math: chaotic attractors in phase space.
	"""
	var imperium_icon = ctx.get("imperium_icon")
	var center_position = ctx.get("center_position", Vector2.ZERO)
	var batcher = ctx.get("geometry_batcher")

	if not imperium_icon:
		return

	if not imperium_icon.has_method("get_attractor_history"):
		return

	var history = imperium_icon.get_attractor_history()
	if history.is_empty():
		return

	var attractor_color = Color(0.7, 0.6, 0.2, 0.4)
	var attractor_offset = center_position + Vector2(200, 200)

	# Draw trajectory trail
	for i in range(1, history.size()):
		var prev_snapshot = history[i - 1]
		var curr_snapshot = history[i]

		var prev_2d = imperium_icon.project_4d_to_2d(prev_snapshot)
		var curr_2d = imperium_icon.project_4d_to_2d(curr_snapshot)

		var prev_pos = attractor_offset + prev_2d
		var curr_pos = attractor_offset + curr_2d

		var fade = float(i) / float(history.size())
		var line_color = attractor_color
		line_color.a = fade * 0.5

		if batcher:
			batcher.add_line(prev_pos, curr_pos, line_color, 2.0)
		else:
			graph.draw_line(prev_pos, curr_pos, line_color, 2.0, true)

	# Current position
	if history.size() > 0:
		var current = history[history.size() - 1]
		var current_2d = imperium_icon.project_4d_to_2d(current)
		var current_pos = attractor_offset + current_2d

		if batcher:
			batcher.add_circle(current_pos, 5.0, Color(1.0, 0.8, 0.3, 0.8))
			batcher.add_circle(current_pos, 3.0, Color(1.0, 0.9, 0.5, 1.0))
		else:
			graph.draw_circle(current_pos, 5.0, Color(1.0, 0.8, 0.3, 0.8))
			graph.draw_circle(current_pos, 3.0, Color(1.0, 0.9, 0.5, 1.0))

	# Label (still use direct draw for text - not batched)
	var label_pos = attractor_offset + Vector2(-80, -90)
	var label_color = Color(0.8, 0.7, 0.3, 0.7)
	var font = ThemeDB.fallback_font
	var season = imperium_icon.get_political_season() if imperium_icon.has_method("get_political_season") else ""
	graph.draw_string(font, label_pos, "Political Season", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, label_color)
	if season != "":
		graph.draw_string(font, label_pos + Vector2(0, 16), season, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, label_color.lightened(0.2))


func _draw_energy_transfer_forces(_graph: Node2D, _ctx: Dictionary) -> void:
	"""Draw energy transfer forces from sun (Lindbladian evolution).

	TODO: Port to Model C. Previously read qubit.theta from Model B quantum_state
	objects. In Model C, theta lives in the density matrix on QuantumComputer.
	Needs: extract Bloch angles from density matrix diagonal for each register.
	"""
	pass


func _draw_icon_influence_forces(_graph: Node2D, _ctx: Dictionary) -> void:
	"""Draw spring attraction forces toward icon stable points.

	TODO: Port to Model C. Previously read qubit.theta from Model B quantum_state
	objects. In Model C, per-register Bloch angles live in the density matrix.
	"""
	pass


func _draw_particles(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw entanglement particles flowing along Bell pair lines."""
	var entanglement_particles = ctx.get("entanglement_particles", [])
	var batcher = ctx.get("geometry_batcher")

	for particle in entanglement_particles:
		var life_ratio = particle.life / particle.get("max_life", 1.0)
		var alpha = clamp(life_ratio, 0.0, 1.0)

		# Outer glow
		var glow_color = particle.color
		glow_color.a = alpha * 0.4

		# Core
		var core_color = Color.WHITE
		core_color.a = alpha * 0.9

		if batcher:
			batcher.add_circle(particle.position, particle.size * 2.0, glow_color)
			batcher.add_circle(particle.position, particle.size, core_color)
		else:
			graph.draw_circle(particle.position, particle.size * 2.0, glow_color)
			graph.draw_circle(particle.position, particle.size, core_color)


func _draw_life_cycle_effects(graph: Node2D, ctx: Dictionary) -> void:
	"""Draw life cycle effects: spawns, deaths, coherence strikes."""
	var life_cycle_effects = ctx.get("life_cycle_effects", {})
	var batcher = ctx.get("geometry_batcher")
	var font = ThemeDB.fallback_font

	# Spawn effects
	for effect in life_cycle_effects.get("spawns", []):
		var pos = effect.get("position", Vector2.ZERO)
		var t = effect.get("time", 0.0)
		var color = effect.get("color", Color.GREEN)

		var duration = 1.0
		var progress = clamp(t / duration, 0.0, 1.0)
		var alpha = 1.0 - progress

		var ring_radius = 10.0 + progress * 50.0
		var ring_color = color
		ring_color.a = alpha * 0.6

		var glow_color = color.lightened(0.3)
		glow_color.a = alpha * 0.4

		if batcher:
			batcher.add_arc(pos, ring_radius, 0, TAU, 3.0, ring_color)
			batcher.add_circle(pos, ring_radius * 0.5, glow_color)
		else:
			graph.draw_arc(pos, ring_radius, 0, TAU, 32, ring_color, 3.0, true)
			graph.draw_circle(pos, ring_radius * 0.5, glow_color)

		for i in range(4):
			var angle = (t * 3.0 + i * TAU / 4.0)
			var sparkle_pos = pos + Vector2(cos(angle), sin(angle)) * ring_radius * 0.7
			var sparkle_color = Color.WHITE
			sparkle_color.a = alpha * 0.8
			if batcher:
				batcher.add_circle(sparkle_pos, 3.0 * (1.0 - progress), sparkle_color)
			else:
				graph.draw_circle(sparkle_pos, 3.0 * (1.0 - progress), sparkle_color)

	# Death effects
	for effect in life_cycle_effects.get("deaths", []):
		var pos = effect.get("position", Vector2.ZERO)
		var t = effect.get("time", 0.0)
		var icon = effect.get("icon", "💀")

		var duration = 1.0
		var progress = clamp(t / duration, 0.0, 1.0)
		var alpha = 1.0 - progress

		var ghost_pos = pos + Vector2(0, -progress * 30.0)
		var emoji_alpha = alpha * 0.8

		# Try SVG glyph, fallback to emoji text (safe autoload access) - not batched
		var texture: Texture2D = null
		var visual_asset_registry = graph.get_node_or_null("/root/VisualAssetRegistry")
		if visual_asset_registry and visual_asset_registry.has_method("get_texture"):
			texture = visual_asset_registry.get_texture(icon)

		if texture:
			var glyph_size = Vector2(28.8, 28.8)  # 24 * 1.2
			var glyph_pos = ghost_pos - glyph_size / 2.0
			graph.draw_texture_rect(texture, Rect2(glyph_pos, glyph_size), false, Color(1, 1, 1, emoji_alpha))
		else:
			graph.draw_string(font, ghost_pos, icon, HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color(1, 1, 1, emoji_alpha))

		for i in range(6):
			var angle = i * TAU / 6.0 + t * 2.0
			var dist = progress * 40.0
			var particle_pos = pos + Vector2(cos(angle), sin(angle) - progress) * dist
			var particle_color = Color(0.5, 0.5, 0.5, alpha * 0.5)
			if batcher:
				batcher.add_circle(particle_pos, 2.0 * (1.0 - progress), particle_color)
			else:
				graph.draw_circle(particle_pos, 2.0 * (1.0 - progress), particle_color)

	# Coherence strike effects
	for effect in life_cycle_effects.get("strikes", []):
		var from_pos = effect.get("from", Vector2.ZERO)
		var to_pos = effect.get("to", Vector2.ZERO)
		var t = effect.get("time", 0.0)

		var duration = 0.5
		var progress = clamp(t / duration, 0.0, 1.0)
		var alpha = 1.0 - progress

		var flash_color = Color(1.0, 0.95, 0.5, alpha)
		var direction = (to_pos - from_pos).normalized()
		var distance = from_pos.distance_to(to_pos)
		var perp = direction.rotated(PI / 2.0)

		var segments = 5
		var prev_point = from_pos
		for i in range(segments):
			var t_seg = float(i + 1) / float(segments)
			var base_point = from_pos.lerp(to_pos, t_seg)
			var offset = 0.0 if i == segments - 1 else (randf() - 0.5) * 20.0
			var point = base_point + perp * offset

			var glow = flash_color
			glow.a = alpha * 0.3
			if batcher:
				batcher.add_line(prev_point, point, glow, 8.0)
				batcher.add_line(prev_point, point, flash_color, 3.0)
			else:
				graph.draw_line(prev_point, point, glow, 8.0, true)
				graph.draw_line(prev_point, point, flash_color, 3.0, true)

			prev_point = point

		var impact_size = 20.0 * (1.0 - progress)
		var impact_color = flash_color
		impact_color.a = alpha * 0.6
		if batcher:
			batcher.add_circle(to_pos, impact_size, impact_color)
		else:
			graph.draw_circle(to_pos, impact_size, impact_color)


func _update_entanglement_particles(delta: float, ctx: Dictionary) -> void:
	"""Update entanglement particles."""
	var entanglement_particles = ctx.get("entanglement_particles", [])
	var quantum_nodes = ctx.get("quantum_nodes", [])
	var node_by_plot_id = ctx.get("node_by_plot_id", {})
	var particle_life = ctx.get("particle_life", 1.5)
	var particle_speed = ctx.get("particle_speed", 80.0)
	var particle_size = ctx.get("particle_size", 3.0)

	# Update existing particles
	for i in range(entanglement_particles.size() - 1, -1, -1):
		var particle = entanglement_particles[i]
		particle.life -= delta
		particle.position += particle.velocity * delta

		if particle.life <= 0.0:
			entanglement_particles.remove_at(i)

	# Spawn new particles
	var spawn_rate = 3.0

	for node in quantum_nodes:
		if not node.plot:
			continue

		for partner_id in node.plot.entangled_plots.keys():
			var partner_node = node_by_plot_id.get(partner_id)
			if not partner_node or node.plot_id > partner_id:
				continue

			if randf() < spawn_rate * delta:
				var start_pos = node.position
				var end_pos = partner_node.position
				var progress = randf()
				var pos = start_pos.lerp(end_pos, progress)
				var direction = (end_pos - start_pos).normalized()

				var particle = {
					"position": pos,
					"velocity": direction * particle_speed,
					"life": particle_life,
					"max_life": particle_life,
					"color": Color(0.3, 0.95, 1.0),
					"size": particle_size
				}

				entanglement_particles.append(particle)
