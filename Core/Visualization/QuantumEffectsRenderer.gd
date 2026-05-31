class_name QuantumEffectsRenderer
extends RefCounted

## Quantum Effects Renderer
##
## Draws visual effects:
## - Entanglement particles: Flowing along Bell pair lines
## - Life cycle effects: Deaths, coherence strikes


func draw(graph: Node2D, ctx: Dictionary) -> void:
	# Draw visual effects.

	# Args:
	# graph: The QuantumForceGraph node
	# ctx: Context dictionary
	_draw_particles(graph, ctx)
	_draw_life_cycle_effects(graph, ctx)


func update_particles(delta: float, ctx: Dictionary) -> void:
	# Update particle systems.
	_update_entanglement_particles(delta, ctx)


func _draw_particles(graph: Node2D, ctx: Dictionary) -> void:
	# Draw entanglement particles flowing along Bell pair lines.
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
	# Draw life cycle effects: deaths, coherence strikes.
	var life_cycle_effects = ctx.get("life_cycle_effects", {})
	var batcher = ctx.get("geometry_batcher")
	var font = ThemeDB.fallback_font

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
		var _distance = from_pos.distance_to(to_pos)
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
	# Update entanglement particles.
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
