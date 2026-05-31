class_name QuantumInfraRenderer
extends RefCounted

## Quantum Infrastructure Renderer
##
## Draws persistent gate infrastructure at PLOT positions:
## - Bell gates: Gold/amber two-node connection
## - Cluster gates: Multi-node web with central hub
## - Bell gate ghosts: Historical entanglement traces


func draw(graph: Node2D, ctx: Dictionary) -> void:
	# Draw gate infrastructure.

	# Args:
	# graph: The QuantumForceGraph node
	# ctx: Context dictionary
	_draw_persistent_gate_infrastructure(graph, ctx)
	_draw_bell_gate_ghosts(graph, ctx)


func _draw_persistent_gate_infrastructure(graph: Node2D, ctx: Dictionary) -> void:
	# Draw persistent gate infrastructure at PLOT positions.
	var farm_grid = ctx.get("farm_grid")
	var all_plot_positions = ctx.get("all_plot_positions", {})
	var quantum_nodes_by_grid_pos = ctx.get("quantum_nodes_by_grid_pos", {})
	var graph_radius = ctx.get("graph_radius", 300.0)
	var batcher = ctx.get("geometry_batcher")

	if not farm_grid:
		return

	var drawn_gates = {}

	# Parametric sizing
	var base_width = graph_radius * 0.008
	var max_width = graph_radius * 0.02
	var corner_radius = graph_radius * 0.025

	for grid_pos in farm_grid.get_plot_positions():
		var plot = farm_grid.get_plot(grid_pos)
		if not plot:
			continue

		var active_gates = plot.get_active_gates() if plot.has_method("get_active_gates") else []

		for gate in active_gates:
			var gate_type = gate.get("type", "")
			var linked_plots: Array = gate.get("linked_plots", [])

			if linked_plots.is_empty():
				continue

			var sorted_positions = linked_plots.duplicate()
			sorted_positions.sort()
			var gate_key = "%s_%s" % [gate_type, str(sorted_positions)]

			if drawn_gates.has(gate_key):
				continue
			drawn_gates[gate_key] = true

			var plot_positions: Array[Vector2] = []
			for pos in linked_plots:
				if all_plot_positions.has(pos):
					plot_positions.append(all_plot_positions[pos])
				elif quantum_nodes_by_grid_pos.has(pos):
					plot_positions.append(quantum_nodes_by_grid_pos[pos].classical_anchor)

			if plot_positions.size() < 2:
				continue

			match gate_type:
				"bell":
					_draw_bell_gate_infrastructure(graph, plot_positions, base_width, max_width, corner_radius, batcher)
				"cluster":
					_draw_cluster_gate_infrastructure(graph, plot_positions, base_width, max_width, corner_radius, batcher)
				_:
					_draw_bell_gate_infrastructure(graph, plot_positions, base_width, max_width, corner_radius, batcher)


func _draw_bell_gate_infrastructure(graph: Node2D, positions: Array[Vector2], base_width: float, max_width: float, corner_radius: float, batcher = null) -> void:
	# Draw Bell gate infrastructure (2-node connection).
	if positions.size() < 2:
		return

	var p1 = positions[0]
	var p2 = positions[1]

	var infra_color = Color(1.0, 0.75, 0.2)
	var infra_glow = Color(1.0, 0.85, 0.4)

	var line_width = base_width + max_width * 0.5

	# Glow layer
	var glow_color = infra_glow
	glow_color.a = 0.3

	# Core line
	var core_color = infra_color
	core_color.a = 0.85

	if batcher:
		batcher.add_line(p1, p2, glow_color, line_width * 2.5)
		batcher.add_line(p1, p2, core_color, line_width)
	else:
		graph.draw_line(p1, p2, glow_color, line_width * 2.5, true)
		graph.draw_line(p1, p2, core_color, line_width, true)

	# Corner connectors
	_draw_gate_corner_connector(graph, p1, corner_radius, infra_color, batcher)
	_draw_gate_corner_connector(graph, p2, corner_radius, infra_color, batcher)


func _draw_cluster_gate_infrastructure(graph: Node2D, positions: Array[Vector2], base_width: float, max_width: float, corner_radius: float, batcher = null) -> void:
	# Draw Cluster gate infrastructure (N-node web).
	if positions.size() < 2:
		return

	# Calculate center hub
	var hub = Vector2.ZERO
	for pos in positions:
		hub += pos
	hub /= positions.size()

	var cluster_color = Color(0.7, 0.4, 1.0)
	var cluster_glow = Color(0.85, 0.6, 1.0)

	var line_width = base_width + max_width * 0.3

	# Draw spokes
	for pos in positions:
		var glow_color = cluster_glow
		glow_color.a = 0.25

		var core_color = cluster_color
		core_color.a = 0.8

		if batcher:
			batcher.add_line(hub, pos, glow_color, line_width * 2.0)
			batcher.add_line(hub, pos, core_color, line_width)
		else:
			graph.draw_line(hub, pos, glow_color, line_width * 2.0, true)
			graph.draw_line(hub, pos, core_color, line_width, true)

		_draw_gate_corner_connector(graph, pos, corner_radius, cluster_color, batcher)

	# Central hub
	var hub_size = corner_radius * 1.5
	var hub_glow = cluster_glow
	hub_glow.a = 0.4

	var hub_core = cluster_color
	hub_core.a = 0.9

	var bright = Color.WHITE
	bright.a = 0.6

	if batcher:
		batcher.add_circle(hub, hub_size * 1.5, hub_glow)
		batcher.add_circle(hub, hub_size, hub_core)
		batcher.add_circle(hub, hub_size * 0.4, bright)
	else:
		graph.draw_circle(hub, hub_size * 1.5, hub_glow)
		graph.draw_circle(hub, hub_size, hub_core)
		graph.draw_circle(hub, hub_size * 0.4, bright)


func _draw_gate_corner_connector(graph: Node2D, pos: Vector2, radius: float, color: Color, batcher = null) -> void:
	# Draw corner connector at a plot position.
	var size = radius

	var glow = color
	glow.a = 0.3

	var core = color
	core.a = 0.9

	var highlight = Color.WHITE
	highlight.a = 0.5

	if batcher:
		batcher.add_circle(pos, size * 1.8, glow)
		batcher.add_circle(pos, size, core)
		batcher.add_circle(pos, size * 0.5, highlight)
	else:
		graph.draw_circle(pos, size * 1.8, glow)
		graph.draw_circle(pos, size, core)
		graph.draw_circle(pos, size * 0.5, highlight)


func _draw_bell_gate_ghosts(graph: Node2D, ctx: Dictionary) -> void:
	# Draw fading ghost lines for historical Bell gate entanglements.
	var biomes = ctx.get("biomes", {})
	var active_biome = ctx.get("active_biome", "")
	var all_plot_positions = ctx.get("all_plot_positions", {})
	var quantum_nodes_by_grid_pos = ctx.get("quantum_nodes_by_grid_pos", {})
	var batcher = ctx.get("geometry_batcher")

	for biome_name in biomes:
		if active_biome != "" and biome_name != active_biome:
			continue

		var biome = biomes[biome_name]
		if not biome or not "bell_gates" in biome:
			continue

		var bell_gates = biome.bell_gates if "bell_gates" in biome else []
		if bell_gates.is_empty():
			continue

		var ghost_color = Color(1.0, 0.8, 0.3, 0.15)

		for gate in bell_gates:
			if gate.size() < 2:
				continue

			var positions: Array[Vector2] = []
			for pos in gate:
				if all_plot_positions.has(pos):
					positions.append(all_plot_positions[pos])
				elif quantum_nodes_by_grid_pos.has(pos):
					positions.append(quantum_nodes_by_grid_pos[pos].position)

			if positions.size() < 2:
				continue

			# Draw ghost line (dashed)
			var start = positions[0]
			var end = positions[1]

			if batcher:
				batcher.add_dashed_line(start, end, ghost_color, 1.5, 12.0, 8.0)
			else:
				var direction = (end - start).normalized()
				var distance = start.distance_to(end)

				var dash_length = 12.0
				var gap_length = 8.0
				var current = 0.0

				while current < distance:
					var dash_start = start + direction * current
					var dash_end = start + direction * min(current + dash_length, distance)
					graph.draw_line(dash_start, dash_end, ghost_color, 1.5, true)
					current += dash_length + gap_length
