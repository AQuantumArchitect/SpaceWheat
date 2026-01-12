extends PanelContainer

## Attractor Personality Panel
## Displays the strange attractor personality for each active biome

const StrangeAttractorAnalyzer = preload("res://Core/QuantumSubstrate/StrangeAttractorAnalyzer.gd")

# UI References (created dynamically)
var biome_labels: Dictionary = {}  # biome_name -> Label

# Update frequency
var update_timer: float = 0.0
var update_interval: float = 1.0  # Update every 1 second

# Farm reference (injected)
var farm = null


func _ready():
	# Set panel style
	custom_minimum_size = Vector2(300, 200)

	# Create container
	var vbox = VBoxContainer.new()
	add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "🌀 Attractor Personalities"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Info label (instructions)
	var info = Label.new()
	info.text = "Semantic topology of each biome:"
	info.add_theme_font_size_override("font_size", 12)
	info.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(info)

	# Biome entries will be added dynamically


func set_farm(farm_ref):
	"""Inject farm reference to access biomes"""
	farm = farm_ref


func _process(dt: float):
	"""Update personality display"""
	update_timer += dt

	if update_timer >= update_interval:
		update_timer = 0.0
		_update_display()


func _update_display():
	"""Update personality labels for all biomes"""
	if not farm:
		return

	# Get all active biomes from farm
	var biomes = _get_active_biomes()

	for biome in biomes:
		var biome_name = biome.get_biome_type()

		# Create label if doesn't exist
		if not biome_labels.has(biome_name):
			_create_biome_label(biome_name)

		# Update label
		var label = biome_labels[biome_name]
		if biome.attractor_analyzer:
			var signature = biome.attractor_analyzer.get_signature()
			var personality = signature.get("personality", "unknown")

			if personality == "unknown" or signature.get("status") == "insufficient_data":
				label.text = "  %s: Collecting data..." % biome_name
				label.modulate = Color.GRAY
			else:
				var emoji = StrangeAttractorAnalyzer.get_personality_emoji(personality)
				var color = StrangeAttractorAnalyzer.get_personality_color(personality)
				var description = StrangeAttractorAnalyzer.get_personality_description(personality)

				label.text = "  %s %s: %s" % [emoji, biome_name, personality.capitalize()]
				label.modulate = color
				label.tooltip_text = "%s\n\nMetrics:\n• Lyapunov: %.3f\n• Spread: %.3f\n• Periodicity: %.3f\n• Points: %d" % [
					description,
					signature.get("lyapunov_exponent", 0.0),
					signature.get("spread", 0.0),
					signature.get("periodicity", 0.0),
					signature.get("trajectory_length", 0)
				]
		else:
			label.text = "  %s: No analyzer" % biome_name
			label.modulate = Color.GRAY


func _create_biome_label(biome_name: String):
	"""Create a new label for a biome"""
	var label = Label.new()
	label.text = "  %s: Initializing..." % biome_name
	label.add_theme_font_size_override("font_size", 14)

	# Add to container (find VBoxContainer)
	var vbox = get_child(0) as VBoxContainer
	if vbox:
		vbox.add_child(label)

	biome_labels[biome_name] = label


func _get_active_biomes() -> Array:
	"""Get all active biomes from farm"""
	var biomes: Array = []

	if not farm:
		return biomes

	# Check if farm has biomes dictionary (multi-biome support)
	if "biomes" in farm and farm.biomes and not farm.biomes.is_empty():
		for biome_name in farm.biomes:
			var biome = farm.biomes[biome_name]
			if biome:
				biomes.append(biome)

	# Fallback: single biome (legacy)
	elif "biome" in farm and farm.biome:
		biomes.append(farm.biome)

	return biomes
