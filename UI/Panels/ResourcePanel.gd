class_name ResourcePanel
extends HBoxContainer

## ResourcePanel - Displays game resources dynamically
## Top bar showing wheat currency, dynamic resources (sorted by amount)
## Phase 3: Simplified for keyboard-first UI (removed redundant quick-action buttons)
## Supports arbitrary resources via emoji keys - no hardcoding needed!

# Layout manager reference (for dynamic scaling)
var layout_manager: Node  # Will be UILayoutManager instance

# Special labels (always shown)
var wheat_label: Label
var credits_label: Label  # 💵 Classical economy currency
var flour_label: Label  # 💨 Intermediate product for production chain
var sun_moon_label: Label
var biome_label: Label  # 🌍 Temperature/Biome info
var tribute_timer_label: Label

# Dynamic resource containers - keyed by emoji
var resource_containers: Dictionary = {}  # emoji -> {container: HBoxContainer, label: Label}
var resources_hbox: HBoxContainer  # Container for all dynamic resources


func _ready():
	_create_ui()


func set_layout_manager(manager: Node):
	"""Set the layout manager reference for dynamic scaling"""
	layout_manager = manager


func _create_ui():
	# Get scale factor from layout manager (or default to 1.0 if not set)
	var scale_factor = layout_manager.scale_factor if layout_manager else 1.0
	var icon_font_size = layout_manager.get_scaled_font_size(24) if layout_manager else 24
	var label_font_size = layout_manager.get_scaled_font_size(20) if layout_manager else 20
	var small_font_size = layout_manager.get_scaled_font_size(18) if layout_manager else 18
	var button_font_size = layout_manager.get_scaled_font_size(16) if layout_manager else 16

	var main_spacing = int(20 * scale_factor)
	var resource_spacing = int(15 * scale_factor)
	var button_spacing = int(10 * scale_factor)

	add_theme_constant_override("separation", main_spacing)

	# LEFT: Wheat currency + dynamic resources
	resources_hbox = HBoxContainer.new()
	resources_hbox.add_theme_constant_override("separation", resource_spacing)

	# Wheat (primary currency - always shown, special handling)
	var wheat_container = HBoxContainer.new()
	var wheat_icon = Label.new()
	wheat_icon.text = "🌾"
	wheat_icon.add_theme_font_size_override("font_size", icon_font_size)
	wheat_container.add_child(wheat_icon)
	wheat_label = Label.new()
	wheat_label.text = "100"
	wheat_label.add_theme_font_size_override("font_size", label_font_size)
	wheat_container.add_child(wheat_label)
	resources_hbox.add_child(wheat_container)

	# Credits (classical economy - always shown after wheat)
	var credits_container = HBoxContainer.new()
	var credits_icon = Label.new()
	credits_icon.text = "💵"
	credits_icon.add_theme_font_size_override("font_size", icon_font_size)
	credits_container.add_child(credits_icon)
	credits_label = Label.new()
	credits_label.text = "50"
	credits_label.add_theme_font_size_override("font_size", label_font_size)
	credits_container.add_child(credits_label)
	resources_hbox.add_child(credits_container)

	# Flour (intermediate product - always shown after credits)
	var flour_container = HBoxContainer.new()
	var flour_icon = Label.new()
	flour_icon.text = "💨"
	flour_icon.add_theme_font_size_override("font_size", icon_font_size)
	flour_container.add_child(flour_icon)
	flour_label = Label.new()
	flour_label.text = "0"
	flour_label.add_theme_font_size_override("font_size", label_font_size)
	flour_container.add_child(flour_label)
	resources_hbox.add_child(flour_container)

	# Note: Sun/Moon and Biome info moved to BiomeInfoDisplay in farm area
	# These labels are kept for backward compatibility but not displayed

	add_child(resources_hbox)


## Public API - Update Methods

func update_resources(wheat: int, credits: int = 0, flour: int = 0, resources: Dictionary = {}):
	"""Update resource displays dynamically

	Args:
		wheat: Current wheat amount (primary currency)
		credits: Current credits amount (classical economy currency)
		flour: Current flour amount (intermediate product)
		resources: Dictionary of {emoji: amount} sorted by amount descending
			Example: {"👥": 3, "💨": 1, "🌻": 0, "🏰": 2}
	"""
	# Update primary currencies
	wheat_label.text = str(wheat)
	credits_label.text = str(credits)
	flour_label.text = str(flour)

	# Remove resources no longer present
	for emoji in resource_containers.keys():
		if not resources.has(emoji):
			resource_containers[emoji].container.queue_free()
			resource_containers.erase(emoji)

	# Sort resources by amount (descending) and add/update displays
	var sorted_resources = resources.keys()
	sorted_resources.sort_custom(func(a, b): return resources[a] > resources[b])

	for emoji in sorted_resources:
		var amount = resources[emoji]
		if amount <= 0:
			# Hide if zero or remove
			if resource_containers.has(emoji):
				resource_containers[emoji].container.visible = false
			continue

		if not resource_containers.has(emoji):
			# Create new resource container
			_create_resource_container(emoji)

		# Update amount and visibility
		var container_data = resource_containers[emoji]
		container_data.label.text = str(amount)
		container_data.container.visible = true


func update_credits(new_amount: int) -> void:
	"""Update credits display when signal received"""
	credits_label.text = str(new_amount)


func update_flour(new_amount: int) -> void:
	"""Update flour display when signal received"""
	flour_label.text = str(new_amount)


func _create_resource_container(emoji: String) -> void:
	"""Create a new resource container for an emoji with dynamic font sizing"""
	var icon_font_size = layout_manager.get_scaled_font_size(24) if layout_manager else 24
	var label_font_size = layout_manager.get_scaled_font_size(20) if layout_manager else 20

	var container = HBoxContainer.new()
	var icon = Label.new()
	icon.text = emoji
	icon.add_theme_font_size_override("font_size", icon_font_size)
	container.add_child(icon)

	var label = Label.new()
	label.text = "0"
	label.add_theme_font_size_override("font_size", label_font_size)
	container.add_child(label)

	# Insert before tribute timer (keep tribute timer at end)
	var insert_position = resources_hbox.get_child_count() - 2  # Before tribute icon/timer
	resources_hbox.add_child(container)
	resources_hbox.move_child(container, insert_position)

	resource_containers[emoji] = {"container": container, "label": label}


func update_sun_moon(is_sun: bool, time_remaining: float):
	"""Update sun/moon cycle display"""
	if is_sun:
		sun_moon_label.text = "☀️ Sun"
		sun_moon_label.modulate = Color(1.0, 0.9, 0.5)  # Golden
	else:
		sun_moon_label.text = "🌙 Moon"
		sun_moon_label.modulate = Color(0.7, 0.7, 1.0)  # Bluish

	# Add timer if space available
	if sun_moon_label.text.length() < 20:
		sun_moon_label.text += " (%.0fs)" % time_remaining


func update_biome_info(temperature: float, energy_strength: float = -1.0):
	"""Update biome display (temperature and energy level)

	Args:
		temperature: Current biome temperature (Kelvin)
		energy_strength: Energy level 0.0-1.0 (optional, for color coding)
	"""
	biome_label.text = "🌍 %.0fK" % temperature

	# Color code based on temperature
	if temperature < 250.0:
		biome_label.modulate = Color(0.5, 0.8, 1.0)  # Cool blue
	elif temperature < 300.0:
		biome_label.modulate = Color(0.8, 1.0, 0.8)  # Cool green
	elif temperature < 350.0:
		biome_label.modulate = Color(1.0, 1.0, 0.7)  # Warm yellow
	else:
		biome_label.modulate = Color(1.0, 0.8, 0.5)  # Hot orange


func update_tribute_timer(seconds: float, warn_level: int = 0):
	"""Update tribute timer display

	warn_level:
	  0 = normal (yellow)
	  1 = warning (orange)
	  2 = critical (red)
	"""
	tribute_timer_label.text = "%.0fs" % seconds

	match warn_level:
		0:  # Normal
			tribute_timer_label.modulate = Color(1.0, 1.0, 0.7)
		1:  # Warning
			tribute_timer_label.modulate = Color(1.0, 0.7, 0.3)
		2:  # Critical
			tribute_timer_label.modulate = Color(1.0, 0.3, 0.3)
