extends Node2D

## Simple Visual Debugger for Tomato Conspiracy Network
## Shows 12 nodes as circles with energy-based colors and entanglement connections

# Preload the network class
const TomatoConspiracyNetwork = preload("res://Core/QuantumSubstrate/TomatoConspiracyNetwork.gd")

var network: TomatoConspiracyNetwork

# Visual settings
const NODE_RADIUS = 30.0
const FONT_SIZE = 14
var node_positions: Dictionary = {}  # node_id -> Vector2

# Colors
const COLOR_LOW_ENERGY = Color(0.2, 0.5, 0.2)   # Dark green
const COLOR_HIGH_ENERGY = Color(1.0, 0.3, 0.3)  # Bright red
const COLOR_CONNECTION = Color(0.5, 0.5, 0.8, 0.3)


func _ready():
	# Create network
	network = TomatoConspiracyNetwork.new()
	add_child(network)

	# Position nodes in a circle
	_layout_nodes_circular()

	# Start evolution
	set_process(true)


func _layout_nodes_circular():
	"""Arrange 12 nodes in a circle"""
	var center = Vector2(400, 300)
	var radius = 200.0
	var node_ids = network.nodes.keys()

	for i in range(node_ids.size()):
		var angle = (float(i) / node_ids.size()) * TAU
		var pos = center + Vector2(cos(angle), sin(angle)) * radius
		node_positions[node_ids[i]] = pos


func _process(delta):
	queue_redraw()


func _draw():
	if not network or network.nodes.is_empty():
		return

	# Draw entanglement connections first (behind nodes)
	_draw_connections()

	# Draw nodes
	_draw_nodes()

	# Draw stats
	_draw_stats()


func _draw_connections():
	"""Draw lines between entangled nodes"""
	for conn in network.connections:
		var from_id = conn["from"]
		var to_id = conn["to"]
		var strength = conn["strength"]

		var pos_a = node_positions.get(from_id, Vector2.ZERO)
		var pos_b = node_positions.get(to_id, Vector2.ZERO)

		if pos_a != Vector2.ZERO and pos_b != Vector2.ZERO:
			var thickness = strength * 3.0
			draw_line(pos_a, pos_b, COLOR_CONNECTION, thickness)


func _draw_nodes():
	"""Draw each node as a colored circle with emoji"""
	for node_id in network.nodes.keys():
		var node = network.nodes[node_id]
		var pos = node_positions.get(node_id, Vector2.ZERO)

		if pos == Vector2.ZERO:
			continue

		# Color based on energy
		var energy_normalized = clamp(node.energy / 5.0, 0.0, 1.0)
		var color = COLOR_LOW_ENERGY.lerp(COLOR_HIGH_ENERGY, energy_normalized)

		# Draw circle
		draw_circle(pos, NODE_RADIUS, color)
		draw_arc(pos, NODE_RADIUS, 0, TAU, 32, Color.WHITE, 2.0)

		# Draw node ID text
		var text = node.node_id.substr(0, 4)  # Abbreviated
		_draw_text_centered(text, pos, Color.WHITE)

		# Draw energy value below
		var energy_text = "%.2f" % node.energy
		_draw_text_centered(energy_text, pos + Vector2(0, 20), Color.WHITE)


func _draw_stats():
	"""Draw network statistics"""
	var stats_pos = Vector2(20, 30)
	var line_height = 20

	# Total energy
	var total_energy = network.get_total_energy()
	_draw_text("Total Energy: %.3f" % total_energy, stats_pos, Color.WHITE)

	# Active conspiracies
	var active_count = network.active_conspiracies.size()
	_draw_text("Active Conspiracies: %d" % active_count, stats_pos + Vector2(0, line_height), Color.YELLOW)

	# List active conspiracies
	var y_offset = line_height * 2
	for conspiracy in network.active_conspiracies.keys():
		if network.active_conspiracies[conspiracy]:
			_draw_text("  🔴 %s" % conspiracy, stats_pos + Vector2(0, y_offset), Color.RED)
			y_offset += line_height


func _draw_text(text: String, pos: Vector2, color: Color):
	"""Draw text at position"""
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


func _draw_text_centered(text: String, pos: Vector2, color: Color):
	"""Draw centered text"""
	var text_size = ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, FONT_SIZE)
	var text_pos = pos - Vector2(text_size.x / 2, -text_size.y / 2)
	draw_string(ThemeDB.fallback_font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)
