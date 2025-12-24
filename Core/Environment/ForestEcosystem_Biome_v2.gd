class_name ForestEcosystemBiomeV2
extends "res://Core/Environment/BiomeBase.gd"

## Quantum Forest Ecosystem - Version 2
##
## NEW ARCHITECTURE: Bloch sphere geometry IS the ecological state
## No separate Markov chains - all dynamics live in the potential landscape
##
## Ecological states emerge as minima of effective potential V(θ, environment)
##
## θ ∈ [0°, 45°]      → Bare ground (🏜️) - potential minimum
## θ ∈ [45°, 90°]     → Seedling (🌱) - potential minimum
## θ ∈ [90°, 135°]    → Sapling (🌿) - potential minimum
## θ ∈ [135°, 180°]   → Mature forest (🌲) - potential minimum
##
## Transitions emerge from:
## 1. Slow environmental changes shift minima positions
## 2. Fast Bloch sphere relaxation toward minima (attractor dynamics)
## 3. Noise allows jumps between adjacent minima
## 4. Bifurcations at critical environmental points create/destroy minima

const BiomePlot = preload("res://Core/GameMechanics/BiomePlot.gd")
const QuantumOrganism = preload("res://Core/Environment/QuantumOrganism.gd")

## Weather and season qubits (same as before)
var weather_qubit: DualEmojiQubit
var season_qubit: DualEmojiQubit

## Patch collection
var patches: Dictionary = {}  # Vector2i → BiomePlot
var grid_width: int = 0
var grid_height: int = 0

## Resource tracking
var total_water_harvested: float = 0.0
var total_apples_harvested: float = 0.0
var total_eggs_harvested: float = 0.0

## Organism definitions
var organism_definitions: Dictionary = {
	"🐺": {"name": "Wolf", "produces": "💧", "eats": ["🐰", "🐭"], "level": "carnivore"},
	"🦅": {"name": "Eagle", "produces": "🌬️", "eats": ["🐦", "🐰", "🐭"], "level": "apex"},
	"🐦": {"name": "Bird", "produces": "🥚", "eats": ["🐛"], "level": "carnivore"},
	"🐱": {"name": "Cat", "produces": "🐱", "eats": ["🐭", "🐰"], "level": "carnivore"},
	"🐰": {"name": "Rabbit", "produces": "🌱", "eats": ["🌱"], "level": "herbivore"},
	"🐛": {"name": "Caterpillar", "produces": "🐛", "eats": ["🌱"], "level": "herbivore"},
	"🐭": {"name": "Mouse", "produces": "🐭", "eats": ["🌱"], "level": "herbivore"}
}

## Potential landscape parameters
## V(θ, env) = A(env)·cos(θ) + B(env)·cos(2θ) + C(env)·cos(4θ)
## These control where minima appear

var potential_params = {
	"A_base": 0.5,    # Bare state preference (decreases with water)
	"B_base": 0.3,    # Seedling-sapling oscillation (increases with water)
	"C_base": 0.2,    # Fine structure (growth-dependent)
	"friction": 0.5,  # Fast relaxation toward minima
	"noise_amplitude": 0.05  # Quantum uncertainty / stochastic hopping
}

## Bifurcation thresholds - at these environmental points, minima appear/disappear
var bifurcation_thresholds = {
	"water_seedling_bifurcation": 0.3,  # Water needed for seedling to exist
	"water_sapling_bifurcation": 0.5,   # Water needed for sapling minimum
	"sun_mature_bifurcation": 0.4,      # Sun needed for mature forest to exist
	"predation_crash_threshold": 3.0    # Predator count that destabilizes forest
}


func _init(width: int = 6, height: int = 1):
	"""Initialize dimensions"""
	grid_width = width
	grid_height = height


func _ready():
	"""Initialize forest ecosystem"""
	super._ready()

	# Guard against double-init
	if weather_qubit != null:
		if OS.get_environment("VERBOSE_FOREST") == "1":
			print("⚠️ ForestEcosystemBiomeV2._ready() called multiple times, skipping")
		return

	# Initialize weather qubits
	weather_qubit = BiomeUtilities.create_qubit("🌬️", "💧", PI / 2.0)
	weather_qubit.radius = 1.0

	season_qubit = BiomeUtilities.create_qubit("☀️", "🌧️", PI / 2.0)
	season_qubit.radius = 1.0

	# Initialize patches
	for x in range(grid_width):
		for y in range(grid_height):
			var pos = Vector2i(x, y)
			patches[pos] = _create_patch(pos)

	print("🌲 ForestEcosystem V2 initialized (%dx%d) - Bloch sphere native dynamics" % [grid_width, grid_height])

	# Visual properties
	visual_color = Color(0.3, 0.7, 0.3, 0.3)
	visual_label = "🌲 Forest V2"
	visual_center_offset = Vector2(0.8, -0.7)
	visual_oval_width = 350.0
	visual_oval_height = 216.0


func _create_patch(position: Vector2i) -> BiomePlot:
	"""Create patch with Bloch sphere as state space and initial organisms"""
	var plot = BiomePlot.new(BiomePlot.BiomePlotType.ENVIRONMENT)
	plot.plot_id = "forest_v2_patch_%d_%d" % [position.x, position.y]
	plot.grid_position = position
	plot.parent_biome = self

	# State qubit: θ IS the ecological state position
	# θ=0° → bare, θ=45° → seedling, θ=90° → sapling, θ=180° → mature
	var state_qubit = DualEmojiQubit.new("🏜️", "🌲", PI / 4.0)  # Start in seedling region
	state_qubit.radius = 0.5  # Medium coherence
	state_qubit.phi = 0.0
	plot.quantum_state = state_qubit

	# Store metadata and organisms
	var organisms = {}  # icon_str → Array[QuantumOrganism]
	plot.set_meta("organisms", organisms)
	plot.set_meta("last_water_level", 0.5)
	plot.set_meta("last_predation_level", 0.0)
	plot.set_meta("total_organisms", 0)
	plot.set_meta("apex_predator_count", 0)
	plot.set_meta("predator_count", 0)
	plot.set_meta("herbivore_count", 0)
	plot.set_meta("water_produced", 0.0)
	plot.set_meta("wind_produced", 0.0)

	# Initialize ecosystem with starter organisms
	_initialize_patch_organisms(plot, position)

	return plot


func _initialize_patch_organisms(patch: BiomePlot, position: Vector2i):
	"""Populate patch with initial organisms"""
	var organisms = patch.get_meta("organisms")

	# Herbivores (rabbits, mice, caterpillars)
	_add_organism_to_patch(patch, "🐰", "herbivore", 2)  # 2 rabbits
	_add_organism_to_patch(patch, "🐭", "herbivore", 3)  # 3 mice
	_add_organism_to_patch(patch, "🐛", "herbivore", 1)  # 1 caterpillar

	# Carnivores (birds, cats)
	_add_organism_to_patch(patch, "🐦", "predator", 1)   # 1 bird
	_add_organism_to_patch(patch, "🐱", "predator", 1)   # 1 cat

	# Apex predators (wolves, eagles)
	_add_organism_to_patch(patch, "🐺", "predator", 1)   # 1 wolf
	_add_organism_to_patch(patch, "🦅", "apex", 1)       # 1 eagle

	_update_patch_organism_counts(patch)


func _add_organism_to_patch(patch: BiomePlot, icon: String, org_type: String, count: int):
	"""Add multiple organisms of a type to a patch"""
	var organisms = patch.get_meta("organisms")

	if not icon in organisms:
		organisms[icon] = []

	for i in range(count):
		var organism = QuantumOrganism.new(icon, org_type)
		organisms[icon].append(organism)


func _update_patch_organism_counts(patch: BiomePlot):
	"""Recalculate organism count summaries"""
	var organisms = patch.get_meta("organisms")
	var apex_count = 0
	var pred_count = 0
	var herb_count = 0
	var total_count = 0

	for icon in organisms.keys():
		var org_list = organisms[icon]
		# Filter to alive organisms
		var alive_count = org_list.filter(func(o): return o.alive).size()

		if icon in ["🐺", "🦅"]:
			apex_count += alive_count
		elif icon in ["🐦", "🐱"]:
			pred_count += alive_count
		elif icon in ["🐰", "🐭", "🐛"]:
			herb_count += alive_count

		total_count += alive_count

	patch.set_meta("apex_predator_count", apex_count)
	patch.set_meta("predator_count", pred_count)
	patch.set_meta("herbivore_count", herb_count)
	patch.set_meta("total_organisms", total_count)


func _update_quantum_substrate(dt: float) -> void:
	"""Update weather and all patches"""
	_update_weather()

	# Update each patch with potential-landscape dynamics
	for pos in patches.keys():
		_update_patch_with_potential(pos, dt)


func _update_weather():
	"""Simple free rotation for weather and season"""
	weather_qubit.theta += 0.01  # Slow rotation
	if weather_qubit.theta > TAU:
		weather_qubit.theta = 0.0

	season_qubit.theta += 0.005  # Even slower season
	if season_qubit.theta > TAU:
		season_qubit.theta = 0.0


func _update_patch_with_potential(position: Vector2i, dt: float):
	"""Update patch using potential landscape dynamics"""
	var patch = patches[position]
	var state_qubit = patch.quantum_state
	if not state_qubit:
		return

	# SLOW LAYER: Environmental state
	var water_available = weather_qubit.water_probability()  # 0→1
	var sun_available = season_qubit.sun_probability()       # 0→1
	var predation_pressure = _count_predators(position)      # 0→N

	# Store for later use
	patch.set_meta("last_water_level", water_available)
	patch.set_meta("last_predation_level", predation_pressure)

	# MEDIUM LAYER: Compute effective potential V(θ, environment)
	var V_params = _compute_potential_params(water_available, sun_available, predation_pressure)

	# FAST LAYER: Gradient descent on potential + noise
	var gradient = _compute_potential_gradient(state_qubit.theta, V_params)
	var noise = randf_normal(0.0, potential_params["noise_amplitude"])

	# dθ/dt = -friction * dV/dθ + noise
	var theta_delta = (-potential_params["friction"] * gradient + noise) * dt
	state_qubit.theta += theta_delta

	# Normalize theta to [0, 2π]
	while state_qubit.theta < 0:
		state_qubit.theta += TAU
	while state_qubit.theta >= TAU:
		state_qubit.theta -= TAU

	# Update radius based on coherence (mature forests stay coherent)
	_update_patch_coherence(patch, state_qubit.theta, predation_pressure)

	# Update organisms in patch (they couple to theta)
	_update_quantum_organisms(patch, dt)

	# Update visualization
	_update_patch_radius_from_state(patch, state_qubit.theta)


func _compute_potential_params(water: float, sun: float, predation: float) -> Dictionary:
	"""Compute V(θ) = A·cos(θ) + B·cos(2θ) + C·cos(4θ)"""

	# A coefficient: Bare state (decreases when water available)
	var A = potential_params["A_base"] * (1.0 - water * 0.7)

	# B coefficient: Seedling-sapling oscillation
	# Grows when water available
	var B = potential_params["B_base"] * water

	# C coefficient: Fine structure for mature forest
	# Needs both water and sun
	var C = potential_params["C_base"] * water * sun

	# BIFURCATION EFFECTS
	# At critical water level, seedling minimum appears
	if water < bifurcation_thresholds["water_seedling_bifurcation"]:
		B = 0.0  # No seedling attractor when too dry
		A += 0.2  # Bare state becomes stronger

	# At higher water, sapling becomes available
	if water > bifurcation_thresholds["water_sapling_bifurcation"]:
		C += 0.3  # Sapling structure becomes stronger

	# Predation destabilizes high-theta states (mature forests)
	if predation > bifurcation_thresholds["predation_crash_threshold"]:
		C *= (1.0 - 0.5 * (predation - bifurcation_thresholds["predation_crash_threshold"]))
		A += 0.2  # Bare state more attractive

	return {
		"A": A,
		"B": B,
		"C": C,
		"water": water,
		"sun": sun,
		"predation": predation
	}


func _compute_potential_gradient(theta: float, V_params: Dictionary) -> float:
	"""dV/dθ where V(θ) = A·cos(θ) + B·cos(2θ) + C·cos(4θ)"""

	var A = V_params["A"]
	var B = V_params["B"]
	var C = V_params["C"]

	# dV/dθ = -A·sin(θ) - 2B·sin(2θ) - 4C·sin(4θ)
	var gradient = (-A * sin(theta) - 2.0 * B * sin(2.0 * theta) - 4.0 * C * sin(4.0 * theta))

	return gradient


func _update_patch_coherence(patch: BiomePlot, theta: float, predation: float):
	"""Update radius based on state and environmental stress"""
	var state_qubit = patch.quantum_state

	# Base coherence from ecological state
	# Mature forests (high theta) are more coherent
	var state_based_radius = 0.3 + 0.7 * (sin(theta / 2.0) ** 2)

	# Predation reduces coherence
	var predation_penalty = 1.0 - 0.2 * predation

	# Combine
	state_qubit.radius = state_based_radius * predation_penalty
	state_qubit.radius = clamp(state_qubit.radius, 0.0, 1.0)


func _update_patch_radius_from_state(patch: BiomePlot, theta: float):
	"""Update radius to reflect ecological state progression"""
	var state_qubit = patch.quantum_state

	# Map theta regions to expected radius
	# Bare: low, Seedling: medium, Sapling: medium-high, Mature: high
	var expected_radius = 0.0

	if theta < PI / 4.0:  # Bare region
		expected_radius = 0.15
	elif theta < PI / 2.0:  # Seedling region
		expected_radius = 0.35
	elif theta < 3.0 * PI / 4.0:  # Sapling region
		expected_radius = 0.65
	else:  # Mature region
		expected_radius = 0.9

	# Smoothly update toward expected (not instant)
	state_qubit.radius = lerp(state_qubit.radius, expected_radius, 0.1)


func _get_ecological_state_label(theta: float) -> String:
	"""Return emoji representing which state region theta is in"""
	if theta < PI / 4.0:
		return "🏜️"
	elif theta < PI / 2.0:
		return "🌱"
	elif theta < 3.0 * PI / 4.0:
		return "🌿"
	else:
		return "🌲"


func _update_quantum_organisms(patch: BiomePlot, dt: float):
	"""Update organisms in patch with full food web dynamics"""
	var organisms = patch.get_meta("organisms") if patch.has_meta("organisms") else {}
	if organisms.is_empty():
		return

	var theta = patch.quantum_state.theta if patch.quantum_state else PI / 4.0

	# Determine food availability from ecological state
	var plant_food = 0.0
	if theta < PI / 4.0:  # Bare
		plant_food = 0.0
	elif theta < PI / 2.0:  # Seedling
		plant_food = 2.0
	elif theta < 3.0 * PI / 4.0:  # Sapling
		plant_food = 5.0
	else:  # Mature
		plant_food = 10.0

	# Collect all organisms (alive and dead for tracking)
	var herbivores = []
	var predators = []
	var apex_predators = []

	for icon in organisms.keys():
		var org_list = organisms[icon]
		for org in org_list:
			if not org.alive:
				continue

			if icon in ["🐰", "🐭", "🐛"]:
				herbivores.append(org)
			elif icon in ["🐦", "🐱"]:
				predators.append(org)
			elif icon in ["🐺", "🦅"]:
				apex_predators.append(org)

	# Update herbivores (eat plants, flee from predators)
	for herbivore in herbivores:
		herbivore.update(dt, [], plant_food, predators + apex_predators)
		plant_food -= 0.1 * dt  # Grazing reduces available food

	# Update predators (hunt herbivores)
	for predator in predators:
		predator.update(dt, herbivores, 0.0, apex_predators)

	# Update apex predators (hunt everything)
	for apex in apex_predators:
		apex.update(dt, predators + herbivores, 0.0, [])

	# Handle reproduction - create new organisms
	var offspring_to_add = {}
	for icon in organisms.keys():
		var org_list = organisms[icon]
		for org in org_list:
			if org.alive and org.offspring_created > 0:
				# Mark that we created offspring
				if icon not in offspring_to_add:
					offspring_to_add[icon] = 0
				offspring_to_add[icon] += 1

	# Add offspring to population
	for icon in offspring_to_add.keys():
		var org_type = organisms[icon][0].organism_type if not organisms[icon].is_empty() else "herbivore"
		_add_organism_to_patch(patch, icon, org_type, offspring_to_add[icon])

	# Track predation pressure on forest
	var total_predators = predators.size() + apex_predators.size()
	var herbivore_pressure = herbivores.size()

	# Update patch metadata
	_update_patch_organism_counts(patch)
	patch.set_meta("last_predation_level", float(total_predators))

	# Heavy herbivory slows forest growth
	if herbivore_pressure > plant_food:
		patch.quantum_state.theta -= 0.05 * dt  # Overgrazing slows growth

	# Apex predators affect forest through predation pressure bifurcation
	# (handled in _compute_potential_params)

	# Track resource production
	var water_produced = 0.0
	var wind_produced = 0.0

	for wolf in apex_predators:
		if wolf.icon == "🐺":
			water_produced += 0.1 * dt
	for eagle in apex_predators:
		if eagle.icon == "🦅":
			wind_produced += 0.1 * dt

	patch.set_meta("water_produced", patch.get_meta("water_produced") + water_produced)
	patch.set_meta("wind_produced", patch.get_meta("wind_produced") + wind_produced)


func _count_predators(position: Vector2i) -> float:
	"""Count all predator organisms (including apex) in this patch"""
	var patch = patches.get(position)
	if not patch:
		return 0.0

	var apex_count = patch.get_meta("apex_predator_count") if patch.has_meta("apex_predator_count") else 0
	var pred_count = patch.get_meta("predator_count") if patch.has_meta("predator_count") else 0

	return float(apex_count + pred_count)


func get_biome_type() -> String:
	"""Return biome type"""
	return "ForestEcosystemV2"


## Helper function to create the visualization
func _initialize_visual_elements():
	"""Initialize QuantumForceGraph elements"""
	if not grid:
		return

	# Add forest qubits to graph
	for pos in patches.keys():
		var patch = patches[pos]
		if patch.quantum_state:
			var qubit = patch.quantum_state
			grid.add_qubit(qubit, visual_label + " patch %d,%d" % [pos.x, pos.y])
