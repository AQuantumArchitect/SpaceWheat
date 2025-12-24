class_name NetworkInfoPanel
extends PanelContainer

## Network Info Panel
## Displays conspiracy network statistics when overlay is visible

# Conspiracy network reference
var conspiracy_network = null

# UI elements
var stats_container: VBoxContainer
var total_energy_label: Label
var active_conspiracies_label: Label
var hottest_node_label: Label
var title_label: Label

# Visual styling
const PANEL_BG_COLOR = Color(0.1, 0.1, 0.15, 0.9)
const TEXT_COLOR = Color(0.9, 0.9, 1.0, 1.0)
const ACCENT_COLOR = Color(0.5, 0.8, 1.0, 1.0)


func _ready():
	# Set panel style
	_setup_style()

	# Create UI layout
	stats_container = VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 8)
	add_child(stats_container)

	# Title
	title_label = Label.new()
	title_label.text = "📊 NETWORK STATUS"
	title_label.add_theme_color_override("font_color", ACCENT_COLOR)
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_container.add_child(title_label)

	# Add separator
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 4)
	stats_container.add_child(separator)

	# Total energy stat
	total_energy_label = Label.new()
	total_energy_label.add_theme_color_override("font_color", TEXT_COLOR)
	total_energy_label.add_theme_font_size_override("font_size", 14)
	stats_container.add_child(total_energy_label)

	# Active conspiracies stat
	active_conspiracies_label = Label.new()
	active_conspiracies_label.add_theme_color_override("font_color", TEXT_COLOR)
	active_conspiracies_label.add_theme_font_size_override("font_size", 14)
	stats_container.add_child(active_conspiracies_label)

	# Hottest node stat
	hottest_node_label = Label.new()
	hottest_node_label.add_theme_color_override("font_color", TEXT_COLOR)
	hottest_node_label.add_theme_font_size_override("font_size", 14)
	stats_container.add_child(hottest_node_label)

	# Set initial size
	custom_minimum_size = Vector2(280, 140)

	# Update stats
	_update_stats()


func _setup_style():
	"""Configure panel appearance"""
	# Create StyleBoxFlat for background
	var style = StyleBoxFlat.new()
	style.bg_color = PANEL_BG_COLOR
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = ACCENT_COLOR
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12
	style.content_margin_top = 12
	style.content_margin_right = 12
	style.content_margin_bottom = 12

	add_theme_stylebox_override("panel", style)


func _process(_delta: float):
	"""Update stats every frame"""
	if visible and conspiracy_network:
		_update_stats()


func _update_stats():
	"""Update all network statistics"""
	if not conspiracy_network or not total_energy_label:
		return

	# Calculate total network energy
	var total_energy = 0.0
	for node_id in conspiracy_network.nodes.keys():
		var node = conspiracy_network.nodes[node_id]
		total_energy += node.energy

	# Count active conspiracies and total conspiracies
	var active_count = 0
	var total_count = 0
	for conspiracy_id in conspiracy_network.active_conspiracies.keys():
		total_count += 1
		if conspiracy_network.active_conspiracies[conspiracy_id]:
			active_count += 1

	# Find hottest node (highest theta = most "southern" on Bloch sphere)
	var hottest_node_id = ""
	var max_theta = 0.0
	for node_id in conspiracy_network.nodes.keys():
		var node = conspiracy_network.nodes[node_id]
		if node.theta > max_theta:
			max_theta = node.theta
			hottest_node_id = node_id

	# Get hottest node emoji
	var hottest_emoji = ""
	if hottest_node_id != "":
		var node = conspiracy_network.nodes[hottest_node_id]
		hottest_emoji = node.emoji_transform.split("→")[1] if "→" in node.emoji_transform else node.emoji_transform

	# Update labels
	total_energy_label.text = "⚡ Total Energy: %.1f" % total_energy
	active_conspiracies_label.text = "🔴 Active: %d / %d" % [active_count, total_count]
	hottest_node_label.text = "🔥 Hottest: %s %s (θ=%.2f)" % [hottest_emoji, hottest_node_id, max_theta]


func set_conspiracy_network(network):
	"""Set the conspiracy network to monitor"""
	conspiracy_network = network
	_update_stats()
