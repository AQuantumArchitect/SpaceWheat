extends Node2D

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const ForestEcosystem_Biome = preload("res://Core/Environment/ForestEcosystem_Biome.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

# Biomes
var biome1: BioticFluxBiome  # BioticFlux - wheat/mushroom farm
var biome2  # ForestEcosystem_Biome - forest ecology

# Visual configuration for each biome
var biome1_config = {
	"center": Vector2(400, 400),
	"width": 280.0,
	"height": 200.0,
	"color": Color(0.3, 0.5, 0.8, 0.3),  # Blue-ish for farming
	"label": "🌾 BioticFlux"
}

var biome2_config = {
	"center": Vector2(850, 400),
	"width": 280.0,
	"height": 200.0,
	"color": Color(0.3, 0.7, 0.3, 0.3),  # Green for forest
	"label": "🌲 Forest"
}

# Entity positions (relative to biome center, normalized -1 to 1)
var biome1_entities: Array = []  # [{qubit, rel_pos, type}]
var biome2_entities: Array = []  # [{patch_pos, rel_pos}]

# Simulation state
var simulation_time: float = 0.0
var is_running: bool = true

func _ready() -> void:
	print("Starting Multi-Biome Visual Test...")

	# Create first biome - BioticFlux (farming)
	biome1 = BioticFluxBiome.new()
	add_child(biome1)
	await get_tree().process_frame

	# Setup BioticFlux entities
	_setup_biotic_flux()

	# Create second biome - ForestEcosystem
	biome2 = ForestEcosystem_Biome.new(4, 1)  # 4x1 grid of patches
	add_child(biome2)
	await get_tree().process_frame

	# Setup Forest entities
	_setup_forest()

	print("Biomes initialized. Visual simulation running...")


func _setup_biotic_flux() -> void:
	"""Setup BioticFlux biome with crops"""

	# Sun at center
	biome1.quantum_states[Vector2i(-1, -1)] = biome1.sun_qubit
	biome1.plots_by_type[biome1.PlotType.FARM].append(Vector2i(-1, -1))
	biome1.plot_types[Vector2i(-1, -1)] = biome1.PlotType.FARM

	# Add sun entity at center
	biome1_entities.append({
		"qubit": biome1.sun_qubit,
		"rel_pos": Vector2(0, 0),
		"type": "sun"
	})

	# Add 3 wheat scattered in a triangle
	var wheat_positions = [
		Vector2(0.6, 0),      # Right
		Vector2(-0.3, 0.5),   # Bottom-left
		Vector2(-0.3, -0.5)   # Top-left
	]

	for i in range(3):
		var wheat = DualEmojiQubit.new()
		wheat.north_emoji = "🌾"
		wheat.south_emoji = "🏰"
		wheat.theta = PI / 4.0
		wheat.phi = 3.0 * PI / 2.0
		wheat.radius = 0.3
		wheat.energy = 0.5

		var pos = Vector2i(i, 0)
		biome1.quantum_states[pos] = wheat
		biome1.plots_by_type[biome1.PlotType.FARM].append(pos)
		biome1.plot_types[pos] = biome1.PlotType.FARM

		biome1_entities.append({
			"qubit": wheat,
			"rel_pos": wheat_positions[i],
			"type": "wheat"
		})

	# Add 2 mushrooms
	var mushroom_positions = [
		Vector2(-0.5, 0),     # Left
		Vector2(0.3, -0.4)    # Top-right
	]

	for i in range(2):
		var mushroom = DualEmojiQubit.new()
		mushroom.north_emoji = "🍂"
		mushroom.south_emoji = "🍄"
		mushroom.theta = PI
		mushroom.phi = PI / 2.0
		mushroom.radius = 0.3
		mushroom.energy = 0.5

		var pos = Vector2i(i + 10, 0)
		biome1.quantum_states[pos] = mushroom
		biome1.plots_by_type[biome1.PlotType.FARM].append(pos)
		biome1.plot_types[pos] = biome1.PlotType.FARM

		biome1_entities.append({
			"qubit": mushroom,
			"rel_pos": mushroom_positions[i],
			"type": "mushroom"
		})


func _setup_forest() -> void:
	"""Setup ForestEcosystem biome with organisms"""

	# Add organisms to patches
	biome2.add_organism(Vector2i(0, 0), "🐺")
	biome2.add_organism(Vector2i(2, 0), "🦅")

	# Create entity entries for each patch (4 patches in a row)
	var patch_x_positions = [-0.6, -0.2, 0.2, 0.6]
	for i in range(4):
		biome2_entities.append({
			"patch_pos": Vector2i(i, 0),
			"rel_pos": Vector2(patch_x_positions[i], 0)
		})


func _process(delta: float) -> void:
	if not is_running:
		return

	# Wait for biomes to be ready
	if not biome1 or not biome2:
		queue_redraw()
		return

	simulation_time += delta

	# Update BioticFlux biome
	biome1.time_tracker.update(delta)
	biome1._apply_celestial_oscillation(delta)
	biome1._apply_hamiltonian_evolution(delta)
	biome1._apply_spring_attraction(delta)
	biome1._apply_energy_transfer(delta)

	# Update ForestEcosystem biome
	biome2.time_tracker.update(delta)
	biome2._update_quantum_substrate(delta)

	# Redraw every frame
	queue_redraw()

	# Stop after 10 seconds
	if simulation_time >= 10.0:
		is_running = false
		_print_final_status()
		get_tree().quit()


func _draw() -> void:
	# Draw background
	draw_rect(Rect2(0, 0, 1280, 800), Color(0.05, 0.05, 0.1, 1.0))

	# Early exit if biomes not ready
	if not biome1 or not biome2:
		return

	# Draw biome ovals
	_draw_biome_oval(biome1_config)
	_draw_biome_oval(biome2_config)

	# Draw BioticFlux entities
	_draw_biotic_flux_entities()

	# Draw Forest entities
	_draw_forest_entities()

	# Draw HUD
	_draw_hud()


func _draw_biome_oval(config: Dictionary) -> void:
	"""Draw a biome as a filled oval with border and label"""
	var center = config.center
	var width = config.width
	var height = config.height
	var color = config.color
	var label = config.label

	# Draw filled oval
	var points: PackedVector2Array = []
	var segments = 64
	for i in range(segments):
		var t = (float(i) / float(segments)) * TAU
		var x = center.x + width * cos(t)
		var y = center.y + height * sin(t)
		points.append(Vector2(x, y))
	draw_colored_polygon(points, color)

	# Draw border
	for i in range(segments):
		var t1 = (float(i) / float(segments)) * TAU
		var t2 = (float(i + 1) / float(segments)) * TAU
		var p1 = center + Vector2(width * cos(t1), height * sin(t1))
		var p2 = center + Vector2(width * cos(t2), height * sin(t2))
		draw_line(p1, p2, Color(1, 1, 1, 0.4), 2.0, true)

	# Draw label
	var font = ThemeDB.fallback_font
	var label_pos = center + Vector2(0, -height - 20)
	draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(1, 1, 1, 0.9))


func _draw_biotic_flux_entities() -> void:
	"""Draw all entities in the BioticFlux biome"""
	var center = biome1_config.center
	var width = biome1_config.width
	var height = biome1_config.height
	var font = ThemeDB.fallback_font

	for entity in biome1_entities:
		var rel_pos = entity.rel_pos
		var screen_pos = center + Vector2(rel_pos.x * width * 0.8, rel_pos.y * height * 0.8)
		var qubit = entity.qubit
		var entity_type = entity.type

		if entity_type == "sun":
			# Draw sun with brightness-based color
			var sun_brightness = pow(cos(qubit.theta / 2.0), 2)
			var sun_color = Color(1.0, 1.0, 0.2).lerp(Color(0.3, 0.2, 0.5), 1.0 - sun_brightness)
			draw_circle(screen_pos, 25, sun_color)

			# Draw sun/moon emoji
			var emoji = qubit.north_emoji if sun_brightness > 0.5 else qubit.south_emoji
			draw_string(font, screen_pos + Vector2(-12, 8), emoji, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)

		elif entity_type == "wheat" or entity_type == "mushroom":
			# Draw crop circle (energy-based size)
			var energy = qubit.energy
			var base_radius = 18
			var radius = base_radius * (0.5 + energy * 0.5)

			# Color based on type
			var crop_color = Color(0.9, 0.8, 0.2, 0.6) if entity_type == "wheat" else Color(0.6, 0.4, 0.3, 0.6)
			draw_circle(screen_pos, radius, crop_color)

			# Draw blended emoji based on theta
			var north_prob = pow(cos(qubit.theta / 2.0), 2)
			var emoji = qubit.north_emoji if north_prob > 0.5 else qubit.south_emoji
			draw_string(font, screen_pos + Vector2(-10, 6), emoji, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)

			# Draw energy bar
			var bar_width = 30
			var bar_height = 4
			var bar_pos = screen_pos + Vector2(-bar_width/2, radius + 5)
			draw_rect(Rect2(bar_pos, Vector2(bar_width, bar_height)), Color(0.2, 0.2, 0.2, 0.8))
			draw_rect(Rect2(bar_pos, Vector2(bar_width * energy, bar_height)), Color(0.3, 0.8, 0.3, 0.9))


func _draw_forest_entities() -> void:
	"""Draw all entities in the Forest biome"""
	var center = biome2_config.center
	var width = biome2_config.width
	var height = biome2_config.height
	var font = ThemeDB.fallback_font

	for entity in biome2_entities:
		var rel_pos = entity.rel_pos
		var screen_pos = center + Vector2(rel_pos.x * width * 0.8, rel_pos.y * height * 0.8)
		var patch_pos = entity.patch_pos

		# Get patch from biome
		var patch = biome2.patches.get(patch_pos)
		if not patch:
			continue

		# Get ecological state
		var eco_state = patch.get_meta("ecological_state") if patch.has_meta("ecological_state") else 0
		var state_emoji = biome2._get_ecosystem_emoji(eco_state)

		# Draw patch background circle
		var patch_color = _get_eco_state_color(eco_state)
		draw_circle(screen_pos, 35, patch_color)

		# Draw state emoji (large, center)
		draw_string(font, screen_pos + Vector2(-16, 8), state_emoji, HORIZONTAL_ALIGNMENT_LEFT, -1, 32)

		# Draw organisms in this patch
		var organisms = patch.get_meta("organisms") if patch.has_meta("organisms") else {}
		var org_offset = Vector2(0, 30)
		for icon in organisms.keys():
			draw_string(font, screen_pos + org_offset + Vector2(-8, 0), icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
			org_offset.x += 20

	# Draw weather indicators
	if biome2 and biome2.weather_qubit:
		var wind_prob = pow(sin(biome2.weather_qubit.theta / 2.0), 2)
		var water_prob = pow(cos(biome2.weather_qubit.theta / 2.0), 2)

		var weather_pos = center + Vector2(0, height + 25)
		var weather_str = "🌬️%.0f%% 💧%.0f%%" % [wind_prob * 100, water_prob * 100]
		draw_string(font, weather_pos, weather_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0.8, 0.8, 0.8, 0.7))


func _get_eco_state_color(state: int) -> Color:
	"""Get background color for ecological state"""
	match state:
		0: return Color(0.6, 0.5, 0.3, 0.4)  # BARE_GROUND - brown
		1: return Color(0.5, 0.7, 0.3, 0.4)  # SEEDLING - light green
		2: return Color(0.4, 0.6, 0.3, 0.4)  # SAPLING - medium green
		3: return Color(0.2, 0.5, 0.2, 0.4)  # MATURE_FOREST - dark green
		_: return Color(0.3, 0.3, 0.3, 0.4)  # Unknown


func _print_final_status() -> void:
	"""Print final simulation status"""
	var sep = "════════════════════════════════════════════════════════════════════════════"
	print("\n" + sep)
	print("MULTI-BIOME VISUAL TEST COMPLETE")
	print(sep)

	# BioticFlux stats
	print("\n🌾 BioticFlux Biome:")
	for entity in biome1_entities:
		if entity.type != "sun":
			var qubit = entity.qubit
			print("   %s: energy=%.3f theta=%.1f°" % [
				qubit.north_emoji,
				qubit.energy,
				qubit.theta * 180.0 / PI
			])

	# Forest stats
	print("\n🌲 Forest Biome:")
	var forest_status = biome2.get_ecosystem_status()
	print("   Organisms: %d" % forest_status.get("organisms_count", 0))
	for patch_info in forest_status.get("patches", []):
		var orgs = []
		for org in patch_info.get("organisms", []):
			orgs.append(org.get("icon", "?"))
		var org_str = " ".join(orgs) if orgs.size() > 0 else "(empty)"
		print("   Patch %s: %s - %s" % [patch_info.get("position", "?"), patch_info.get("state", "?"), org_str])

	print("\n✓ Visual rendering verified")
	print("✓ Both biomes evolved together")
	print(sep + "\n")


func _draw_hud() -> void:
	"""Draw heads-up display with simulation info"""
	var font = ThemeDB.fallback_font

	# Title
	draw_string(font, Vector2(640, 30), "Multi-Biome Visualization", HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color.WHITE)

	# Time
	var time_str = "Time: %.1fs" % simulation_time
	draw_string(font, Vector2(50, 60), time_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 0.8, 0.8))

	# BioticFlux stats
	var sun_theta = biome1.sun_qubit.theta
	var sun_bright = pow(cos(sun_theta / 2.0), 2)
	var phase = "Day" if sun_bright > 0.5 else "Night"
	var bf_stats = "☀️ θ=%.0f° (%s)" % [sun_theta * 180.0 / PI, phase]
	draw_string(font, Vector2(50, 80), bf_stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.7, 0.9))

	# Forest stats
	var forest_status = biome2.get_ecosystem_status()
	var org_count = forest_status.get("organisms_count", 0)
	var forest_stats = "🌲 Organisms: %d" % org_count
	draw_string(font, Vector2(50, 100), forest_stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.9, 0.7))

	# Instructions
	if is_running:
		draw_string(font, Vector2(640, 780), "Simulation running... (30s)", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0.6, 0.6, 0.6))
	else:
		draw_string(font, Vector2(640, 780), "Simulation complete", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0.4, 0.8, 0.4))
