class_name ConspiracyNetworkOverlay
extends Node2D

## Visualizes complete quantum space: Icons, conspiracy network nodes, and farm qubits
## Shows entanglement, Icon influence, and quantum relationships
## Press N to toggle visibility

# Import dependencies
const TomatoConspiracyNetwork = preload("res://Core/QuantumSubstrate/TomatoConspiracyNetwork.gd")
const TomatoNode = preload("res://Core/QuantumSubstrate/TomatoNode.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

var conspiracy_network: TomatoConspiracyNetwork
var icons: Dictionary = {}  # icon_name -> Icon reference (biotic, chaos, imperium)
var farm_grid = null  # Reference to farm grid for qubit positions
var node_sprites: Dictionary = {}  # node_id -> Node2D (conspiracy nodes + Icons + qubits)
var connection_lines: Array = []  # Array of Line2D

# Force-directed graph simulation
var node_positions: Dictionary = {}  # node_id -> Vector2
var node_velocities: Dictionary = {}  # node_id -> Vector2
var node_types: Dictionary = {}  # node_id -> "conspiracy" | "icon" | "qubit"

# Visual parameters
const BASE_NODE_SIZE = 50.0
const ENERGY_GLOW_SCALE = 2.0
const CONNECTION_BASE_WIDTH = 3.0
const REPULSION_STRENGTH = 5000.0
const ATTRACTION_STRENGTH = 0.05
const DAMPING = 0.85
const CENTER_GRAVITY = 0.02

# Layout bounds (adjusted to avoid overlapping resource bar at top)
# Resource bar height is ~60-80px, so start visualization below that
var center: Vector2 = Vector2(400, 380)  # Moved down to avoid top resource bar
var bounds_radius: float = 220.0


func _ready():
	if not conspiracy_network:
		print("⚠️ ConspiracyNetworkOverlay: No conspiracy_network assigned")
		return

	_init_node_positions()
	_create_visual_elements()
	print("📊 ConspiracyNetworkOverlay ready with %d conspiracy nodes, %d icons, %d qubits" % [
		conspiracy_network.nodes.size(),
		icons.size(),
		farm_grid.grid_width * farm_grid.grid_width if farm_grid else 0
	])


func _init_node_positions():
	"""Initialize nodes in concentric circular layout

	Layout:
	- Center (radius ~40): 3 Icon nodes (Biotic, Chaos, Carrion)
	- Inner ring (radius ~120): 12 Conspiracy nodes
	- Outer ring (radius ~200): Farm qubits (wheat, mushroom, tomato plots)
	"""

	# 1. ICONS - at center, forming a triangle
	var icon_names = ["biotic", "chaos", "imperium"]
	var icon_count = 0
	for icon_name in icon_names:
		if icons.has(icon_name):
			var angle = (icon_count / 3.0) * TAU
			var radius = 40.0
			var node_id = "icon_" + icon_name
			node_positions[node_id] = center + Vector2(cos(angle), sin(angle)) * radius
			node_velocities[node_id] = Vector2.ZERO
			node_types[node_id] = "icon"
			icon_count += 1

	# 2. CONSPIRACY NODES - inner ring
	var conspiracy_node_ids = conspiracy_network.nodes.keys()
	var conspiracy_count = conspiracy_node_ids.size()
	for i in range(conspiracy_count):
		var node_id = conspiracy_node_ids[i]
		var angle = (i / float(conspiracy_count)) * TAU
		var radius = bounds_radius * 0.5  # Inner ring at 50% of bounds
		node_positions[node_id] = center + Vector2(cos(angle), sin(angle)) * radius
		node_velocities[node_id] = Vector2.ZERO
		node_types[node_id] = "conspiracy"

	# 3. QUBITS - outer ring (if farm_grid available)
	if farm_grid:
		var qubit_positions = []
		for y in range(farm_grid.grid_height):
			for x in range(farm_grid.grid_width):
				var plot = farm_grid.get_plot(Vector2i(x, y))
				if plot and plot.is_planted:
					qubit_positions.append(Vector2i(x, y))

		var qubit_count = qubit_positions.size()
		for i in range(qubit_count):
			var pos = qubit_positions[i]
			var node_id = "qubit_%d_%d" % [pos.x, pos.y]
			var angle = (i / float(max(1, qubit_count))) * TAU
			var radius = bounds_radius * 0.85  # Outer ring
			node_positions[node_id] = center + Vector2(cos(angle), sin(angle)) * radius
			node_velocities[node_id] = Vector2.ZERO
			node_types[node_id] = "qubit"


func _create_visual_elements():
	"""Create sprites and lines for visualization"""
	# First create connection lines (behind nodes)

	# 1. Conspiracy network connections (inner ring)
	for conn in conspiracy_network.connections:
		var line = Line2D.new()
		line.width = CONNECTION_BASE_WIDTH
		line.default_color = Color(0.5, 0.5, 0.5, 0.5)
		line.antialiased = true
		line.z_index = -1
		add_child(line)
		connection_lines.append({
			"line": line,
			"from_id": conn["from"],
			"to_id": conn["to"],
			"strength": conn["strength"]
		})

	# 2. Icon to conspiracy node connections (Icons influence solar node)
	for icon_name in icons.keys():
		var icon_node_id = "icon_" + icon_name
		var line = Line2D.new()
		line.width = 2.0
		line.default_color = Color(0.6, 0.8, 0.6, 0.4)  # Green tint for Icon influence
		line.antialiased = true
		line.z_index = -1
		add_child(line)
		connection_lines.append({
			"line": line,
			"from_id": icon_node_id,
			"to_id": "solar",  # Connect to solar node
			"strength": 1.0,
			"connection_type": "icon_influence"
		})

	# 3. Create Icon node sprites (central core)
	for icon_name in icons.keys():
		var icon_node_id = "icon_" + icon_name
		var node_visual = _create_icon_visual(icon_name, icons[icon_name])
		add_child(node_visual)
		node_sprites[icon_node_id] = node_visual

	# 4. Create conspiracy node sprites (inner ring)
	for node_id in conspiracy_network.nodes.keys():
		var node = conspiracy_network.nodes[node_id]
		var node_visual = _create_conspiracy_node_visual(node_id, node)
		add_child(node_visual)
		node_sprites[node_id] = node_visual

	# 5. Create qubit node sprites (outer ring)
	if farm_grid:
		for y in range(farm_grid.grid_height):
			for x in range(farm_grid.grid_width):
				var plot = farm_grid.get_plot(Vector2i(x, y))
				if plot and plot.is_planted:
					var node_id = "qubit_%d_%d" % [x, y]
					var node_visual = _create_qubit_visual(node_id, plot)
					add_child(node_visual)
					node_sprites[node_id] = node_visual


func _create_icon_visual(icon_name: String, icon) -> Node2D:
	"""Create visual representation for an Icon (central core nodes)"""
	var container = Node2D.new()
	container.name = "Icon_" + icon_name

	# Icon emoji as large label
	var emoji_map = {
		"biotic": "🌾",
		"chaos": "🍅",
		"imperium": "🏰"
	}
	var emoji = emoji_map.get(icon_name, "❓")

	var label = Label.new()
	label.text = emoji
	label.add_theme_font_size_override("font_size", 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(label)

	# Glow background
	var bg = Sprite2D.new()
	var glow_texture = _create_circle_texture(BASE_NODE_SIZE * 1.5)
	bg.texture = glow_texture
	var color = Color(0.8, 0.6, 1.0, 0.5)  # Purple glow for Icons
	if icon_name == "biotic":
		color = Color(0.3, 1.0, 0.3, 0.6)  # Green for Biotic
	elif icon_name == "chaos":
		color = Color(1.0, 0.3, 0.3, 0.6)  # Red for Chaos
	bg.self_modulate = color
	container.add_child(bg)
	bg.z_index = -1

	return container


func _create_conspiracy_node_visual(node_id: String, node: TomatoNode) -> Node2D:
	"""Create visual representation for a conspiracy node"""
	var container = Node2D.new()
	container.name = "Node_" + node_id

	# Background circle
	var circle = Sprite2D.new()
	circle.name = "Circle"
	var circle_texture = _create_circle_texture(BASE_NODE_SIZE)
	circle.texture = circle_texture
	container.add_child(circle)

	# Glow layer
	var glow = Sprite2D.new()
	glow.name = "Glow"
	glow.texture = circle_texture
	glow.modulate = Color(1.0, 1.0, 1.0, 0.3)
	glow.z_index = -1
	container.add_child(glow)

	# Label with emoji
	var label = Label.new()
	label.name = "Label"
	label.text = node.emoji_transform
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-20, -15)
	label.add_theme_font_size_override("font_size", 20)
	container.add_child(label)

	# Small energy indicator
	var energy_label = Label.new()
	energy_label.name = "EnergyLabel"
	energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy_label.position = Vector2(-15, 20)
	energy_label.add_theme_font_size_override("font_size", 10)
	energy_label.modulate = Color(0.8, 0.8, 0.8)
	container.add_child(energy_label)

	container.position = node_positions[node_id]
	return container


func _create_qubit_visual(node_id: String, plot) -> Node2D:
	"""Create visual representation for a qubit (farm plot)"""
	var container = Node2D.new()
	container.name = "Qubit_" + node_id

	# Small circle background
	var circle = Sprite2D.new()
	var circle_texture = _create_circle_texture(BASE_NODE_SIZE * 0.6)
	circle.texture = circle_texture
	circle.modulate = Color(0.5, 0.5, 0.7, 0.7)  # Light blue for qubits
	container.add_child(circle)

	# Emoji label - show primary emoji
	var label = Label.new()
	label.text = plot.get_dominant_emoji()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	container.add_child(label)

	# Position indicator (show grid position)
	var pos_label = Label.new()
	pos_label.text = "(%d,%d)" % [plot.grid_position.x, plot.grid_position.y]
	pos_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pos_label.position = Vector2(0, 15)
	pos_label.add_theme_font_size_override("font_size", 8)
	pos_label.modulate = Color(0.7, 0.7, 0.7)
	container.add_child(pos_label)

	container.position = node_positions[node_id]
	return container


func _create_circle_texture(size: float) -> ImageTexture:
	"""Create a simple circular texture"""
	var img = Image.create(int(size), int(size), false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)

	var radius = size / 2.0
	var center_point = Vector2(radius, radius)

	for x in range(int(size)):
		for y in range(int(size)):
			var dist = Vector2(x, y).distance_to(center_point)
			if dist < radius:
				var alpha = 1.0 - (dist / radius) * 0.3
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	return ImageTexture.create_from_image(img)


func _process(dt: float):
	if not visible or not conspiracy_network:
		return

	# Update force-directed graph positions
	_apply_forces(dt)

	# Update visual states from network data
	_update_node_visuals()

	# Update connection lines
	_update_connection_lines()


func _apply_forces(dt: float):
	"""Force-directed graph simulation"""
	var forces: Dictionary = {}
	for node_id in node_positions.keys():
		forces[node_id] = Vector2.ZERO

	# Repulsion between all nodes (push apart)
	for node_a in node_positions.keys():
		for node_b in node_positions.keys():
			if node_a == node_b:
				continue
			var delta = node_positions[node_a] - node_positions[node_b]
			var dist = delta.length()
			if dist < 1.0:
				dist = 1.0
			var repulsion = delta.normalized() * REPULSION_STRENGTH / (dist * dist)
			forces[node_a] += repulsion

	# Attraction along connections (pull together)
	for conn in conspiracy_network.connections:
		var from_id = conn["from"]
		var to_id = conn["to"]
		var delta = node_positions[to_id] - node_positions[from_id]
		var dist = delta.length()
		var attraction = delta.normalized() * dist * ATTRACTION_STRENGTH * conn["strength"]
		forces[from_id] += attraction
		forces[to_id] -= attraction

	# Gravity toward center (prevent drift)
	for node_id in node_positions.keys():
		var to_center = center - node_positions[node_id]
		var dist = to_center.length()
		if dist > bounds_radius:
			forces[node_id] += to_center.normalized() * (dist - bounds_radius) * CENTER_GRAVITY * 100.0
		else:
			forces[node_id] += to_center * CENTER_GRAVITY

	# Apply forces with velocity integration
	for node_id in node_positions.keys():
		node_velocities[node_id] += forces[node_id] * dt
		node_velocities[node_id] *= DAMPING
		node_positions[node_id] += node_velocities[node_id] * dt


func _update_node_visuals():
	"""Update node appearance based on network state"""
	for node_id in node_sprites.keys():
		var container = node_sprites[node_id]
		var node_type = node_types.get(node_id, "unknown")

		# Update position
		container.position = node_positions[node_id]

		# Handle different node types
		if node_type == "conspiracy":
			# CONSPIRACY NODES - update from network data
			var node = conspiracy_network.nodes[node_id]

			# Update size based on energy (max energy is 8.0)
			var energy_scale = 1.0 + clamp(node.energy / 8.0, 0.0, 1.0) * ENERGY_GLOW_SCALE
			container.scale = Vector2.ONE * energy_scale

			# Update color based on theta (temperature)
			var color = _get_temperature_color(node.theta)

			# Special visual for solar node (sun/moon cycle!)
			if node_id == "solar":
				var is_sun = conspiracy_network.is_currently_sun()
				if is_sun:
					# Sun phase: bright yellow/orange glow
					color = Color(1.0, 0.9, 0.3, 1.0)
				else:
					# Moon phase: cool blue/purple glow
					color = Color(0.4, 0.5, 0.9, 1.0)

			var circle = container.get_node("Circle")
			circle.modulate = color

			# Update glow
			var glow = container.get_node("Glow")
			var glow_intensity = clamp(node.energy / 3.0, 0.0, 1.0)
			glow.scale = Vector2.ONE * (1.5 + glow_intensity)
			glow.modulate = Color(color.r, color.g, color.b, glow_intensity * 0.5)

			# Update emoji label (for sun/moon transitions!)
			var label = container.get_node("Label")
			label.text = node.emoji_transform

			# Update energy label
			var energy_label = container.get_node("EnergyLabel")
			energy_label.text = "E:%.1f" % node.energy

		elif node_type == "icon":
			# ICON NODES - static display with activation pulse
			container.scale = Vector2.ONE * 1.0  # Icons stay at normal size
			# TODO: Could add activation glow based on icon.active_strength

		elif node_type == "qubit":
			# QUBIT NODES - subtle pulse based on coherence
			container.scale = Vector2.ONE * 0.9  # Qubits stay small
			# Could pulse based on quantum_state.radius


func _update_connection_lines():
	"""Update connection line appearance"""
	for conn_data in connection_lines:
		var line = conn_data["line"]
		var from_id = conn_data["from_id"]
		var to_id = conn_data["to_id"]
		var strength = conn_data["strength"]
		var connection_type = conn_data.get("connection_type", "conspiracy")

		# Check if both nodes exist in positions (skip if not)
		if not node_positions.has(from_id) or not node_positions.has(to_id):
			continue

		# Set line endpoints
		line.clear_points()
		line.add_point(node_positions[from_id])
		line.add_point(node_positions[to_id])

		# Line width based on connection strength
		line.width = CONNECTION_BASE_WIDTH * strength

		# Line color based on connection type
		if connection_type == "icon_influence":
			# Icon influence connections are static green
			line.default_color = Color(0.6, 0.8, 0.6, 0.4)
		else:
			# Conspiracy connections show energy flow
			var from_node = conspiracy_network.nodes[from_id]
			var to_node = conspiracy_network.nodes[to_id]
			var energy_delta = to_node.energy - from_node.energy
			var flow_color = _get_flow_color(energy_delta)
			line.default_color = flow_color


func _get_temperature_color(theta: float) -> Color:
	"""Map theta to temperature color (blue -> white -> red)"""
	var normalized = theta / PI  # 0 to 1

	if normalized < 0.5:
		# Blue to white
		var t = normalized * 2.0
		return Color(0.4, 0.6, 1.0).lerp(Color(1.0, 1.0, 1.0), t)
	else:
		# White to red
		var t = (normalized - 0.5) * 2.0
		return Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.3, 0.3), t)


func _get_flow_color(energy_delta: float) -> Color:
	"""Color based on energy flow direction and magnitude"""
	var intensity = clamp(abs(energy_delta) / 2.0, 0.0, 1.0)

	if energy_delta > 0:
		# Energy flowing TO target (blue)
		return Color(0.3, 0.5, 1.0, 0.4 + intensity * 0.4)
	else:
		# Energy flowing FROM target (red)
		return Color(1.0, 0.3, 0.3, 0.4 + intensity * 0.4)


func toggle_visibility():
	"""Toggle overlay on/off"""
	visible = !visible
	print("📊 Network overlay: %s" % ("VISIBLE" if visible else "HIDDEN"))
