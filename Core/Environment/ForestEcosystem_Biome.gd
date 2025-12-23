class_name ForestEcosystem_Biome
extends BiomeBase

## Quantum Forest Ecosystem Biome
##
## A complete predator-prey ecosystem modeled as quantum state transitions.
## Uses Markov chains for ecological succession and population dynamics.
##
## All organisms and states are quantum icons (dual-emoji qubits).
## No classical energy tracking - pure quantum superpositions.
##
## Food Web:
##   🌱🌿🌲 (Producers)
##   ↓
##   🐰🐛🐭 (Herbivores)
##   ↓
##   🐦🐱🐺 (Carnivores)
##   ↓
##   🦅 (Apex)
##
## Resources:
##   🐺 Wolf → 💧 Water
##   🦅 Eagle → 🌬️ Wind
##   🐦 Bird → 🥚 Eggs
##   🌲 Forest → 🍎 Apples

## Ecological state enum
enum EcologicalState {
	BARE_GROUND,      # 🏜️
	SEEDLING,         # 🌱
	SAPLING,          # 🌿
	MATURE_FOREST,    # 🌲
	DEAD_FOREST       # ☠️
}

## Grid of patches
var patches: Dictionary = {}  # Vector2i → EcosystemPatch (stored as dict for now)
var grid_width: int = 0
var grid_height: int = 0

## Global weather state (quantum)
var weather_qubit: DualEmojiQubit  # (🌬️ wind, 💧 water)
var season_qubit: DualEmojiQubit   # (☀️ sun, 🌧️ rain)

## Update period for ecosystem simulation
var update_period: float = 1.0

## Resource tracking
var total_water_harvested: float = 0.0
var total_apples_harvested: float = 0.0
var total_eggs_harvested: float = 0.0

## Organism definitions (icons and what they produce/eat)
var organism_definitions: Dictionary = {
	"🐺": {"name": "Wolf", "produces": "💧", "eats": ["🐰", "🐭"], "level": "carnivore"},
	"🦅": {"name": "Eagle", "produces": "🌬️", "eats": ["🐦", "🐰", "🐭"], "level": "apex"},
	"🐦": {"name": "Bird", "produces": "🥚", "eats": ["🐛"], "level": "carnivore"},
	"🐱": {"name": "Cat", "produces": "🐱", "eats": ["🐭", "🐰"], "level": "carnivore"},
	"🐰": {"name": "Rabbit", "produces": "🌱", "eats": ["🌱"], "level": "herbivore"},
	"🐛": {"name": "Caterpillar", "produces": "🐛", "eats": ["🌱"], "level": "herbivore"},
	"🐭": {"name": "Mouse", "produces": "🐭", "eats": ["🌱"], "level": "herbivore"}
}


func _init(width: int = 6, height: int = 1):
	"""Backward compatibility: Set grid dimensions before _ready()"""
	grid_width = width
	grid_height = height


func _ready():
	"""Initialize forest ecosystem with grid of patches"""
	super._ready()
	# Create weather qubits
	weather_qubit = BiomeUtilities.create_qubit("🌬️", "💧", PI / 2.0)
	weather_qubit.radius = 1.0

	season_qubit = BiomeUtilities.create_qubit("☀️", "🌧️", PI / 2.0)
	season_qubit.radius = 1.0

	# Use defaults if not set by _init()
	if grid_width == 0:
		grid_width = 6
	if grid_height == 0:
		grid_height = 1

	# Initialize patches
	for x in range(grid_width):
		for y in range(grid_height):
			var pos = Vector2i(x, y)
			patches[pos] = _create_patch(pos)

	print("🌲 Forest Ecosystem initialized (%dx%d)" % [grid_width, grid_height])


func _update_quantum_substrate(dt: float) -> void:
	"""Override parent: Update weather and all patches"""
	# Update weather
	_update_weather()

	# Update all patches
	for pos in patches.keys():
		_update_patch(pos, dt)


func _create_patch(position: Vector2i) -> Dictionary:
	"""Create ecosystem patch with Markov transition graph"""
	var patch = {
		"position": position,
		"state": EcologicalState.BARE_GROUND,
		"state_qubit": DualEmojiQubit.new("🏜️", "🌱", PI / 2.0),
		"organisms": {},  # icon → QuantumOrganism
		"time_in_state": 0.0
	}
	patch["state_qubit"].radius = 0.1  # Bare ground has low energy
	patch["state_qubit"].phi = 0.0

	# Initialize Markov transition graph (🔄 = can transition to)
	patch["state_qubit"].add_graph_edge("🔄", "🌱")  # Bare → Seedling

	return patch




func _update_weather():
	"""Simulate weather changes"""
	# Slow oscillation between wind and water
	weather_qubit.theta += 0.01
	if weather_qubit.theta > TAU:
		weather_qubit.theta = 0.0

	# Seasonal oscillation
	season_qubit.theta += 0.005
	if season_qubit.theta > TAU:
		season_qubit.theta = 0.0


func _update_patch(position: Vector2i, delta: float):
	"""Update a single patch: ecology + quantum organisms"""
	var patch = patches[position]

	patch["time_in_state"] += delta

	# Step 1: Apply ecological succession (Markov transition)
	_apply_ecological_transition(patch)

	# Step 2: Quantum organism dynamics (predation, survival, reproduction)
	_update_quantum_organisms(patch, delta)

	# Step 3: Update patch qubit state
	_update_patch_qubit(patch)


func _update_quantum_organisms(patch: Dictionary, delta: float):
	"""Update all organisms in patch using quantum mechanics and graph topology"""
	var organisms_list = []
	var predators_list = []

	# Collect organisms and identify predators
	for icon in patch["organisms"].keys():
		var org = patch["organisms"][icon]
		if org.alive:
			organisms_list.append(org)
			# Check if this organism hunts others (has 🍴 edges)
			if org.qubit.get_graph_targets("🍴").size() > 0:
				predators_list.append(org)

	# Update each organism
	for org in organisms_list:
		if not org.alive:
			continue

		# Find predators that hunt THIS organism
		var my_predators = []
		for pred in predators_list:
			if pred.qubit.has_graph_edge("🍴", org.icon):
				my_predators.append(pred)

		# Quantum update: survival instinct, hunting, reproduction, eating
		var available_food = _get_patch_food_energy(patch)
		org.update(delta, organisms_list, available_food, my_predators)

		# Handle reproduction - create offspring
		if org.offspring_created > 0:
			for i in range(org.offspring_created):
				var spec = org.get_offspring_spec()
				var baby = QuantumOrganism.new(spec["icon"], spec["type"])
				baby.qubit.radius = spec["health"]
				# Use unique key for multiple organisms of same type
				var unique_key = spec["icon"] + "_" + str(randi())
				patch["organisms"][unique_key] = baby
			org.offspring_created = 0

	# Remove dead organisms
	var dead_icons = []
	for icon in patch["organisms"].keys():
		if not patch["organisms"][icon].alive:
			dead_icons.append(icon)
	for icon in dead_icons:
		patch["organisms"].erase(icon)


func _get_patch_food_energy(patch: Dictionary) -> float:
	"""Calculate available food energy based on ecological state"""
	match patch["state"]:
		EcologicalState.SEEDLING:
			return 2.0
		EcologicalState.SAPLING:
			return 4.0
		EcologicalState.MATURE_FOREST:
			return 8.0
		_:
			return 0.0


func _apply_ecological_transition(patch: Dictionary):
	"""Markov chain transition based on current state"""
	var current_state = patch["state"]
	var organisms = patch["organisms"]
	var wind_prob = sin(weather_qubit.theta / 2.0) ** 2
	var water_prob = cos(weather_qubit.theta / 2.0) ** 2
	var sun_prob = sin(season_qubit.theta / 2.0) ** 2

	# Determine transition probabilities
	var transition_prob = 0.0

	match current_state:
		EcologicalState.BARE_GROUND:
			# Bare → Seedling requires wind + water
			transition_prob = wind_prob * water_prob * 0.7
			if randf() < transition_prob:
				patch["state"] = EcologicalState.SEEDLING
				patch["time_in_state"] = 0.0
				print("🏜️ → 🌱 Seedling sprouted at %s" % patch["position"])

		EcologicalState.SEEDLING:
			# Seedling → Sapling requires survival + growth
			var base_prob = 0.3
			if organisms.has("🐺"):  # Wolf eats rabbits
				base_prob = 0.4
			if organisms.has("🦅"):  # Eagle eats herbivores
				base_prob = 0.35
			if water_prob > 0.6:
				base_prob += 0.1

			transition_prob = base_prob
			if randf() < transition_prob:
				patch["state"] = EcologicalState.SAPLING
				patch["time_in_state"] = 0.0
				print("🌱 → 🌿 Sapling grown at %s" % patch["position"])

			# Could also die from herbivores
			if organisms.has("🐰") and randf() < 0.1:
				patch["state"] = EcologicalState.BARE_GROUND
				patch["time_in_state"] = 0.0
				print("🌱 → 🏜️ Eaten by rabbits at %s" % patch["position"])

		EcologicalState.SAPLING:
			# Sapling → Mature Forest
			transition_prob = 0.2 + (water_prob * 0.1) + (sun_prob * 0.05)
			if randf() < transition_prob:
				patch["state"] = EcologicalState.MATURE_FOREST
				patch["time_in_state"] = 0.0
				print("🌿 → 🌲 Mature forest at %s" % patch["position"])

		EcologicalState.MATURE_FOREST:
			# Forest can die (rare)
			transition_prob = 0.02  # Background death rate
			if (1.0 - water_prob) > 0.8:  # Drought
				transition_prob = 0.1
			if randf() < transition_prob:
				patch["state"] = EcologicalState.BARE_GROUND
				patch["time_in_state"] = 0.0
				print("🌲 → 🏜️ Forest died at %s" % patch["position"])

	# Update Markov transition graph to reflect new state
	_update_patch_transition_graph(patch)




func _update_patch_transition_graph(patch: Dictionary):
	"""Update Markov transition graph based on current ecological state (pure emoji topology)"""
	var state_qubit = patch["state_qubit"]
	# Clear old transitions
	state_qubit.entanglement_graph.clear()

	# Build transition graph based on current state (🔄 = can transition to)
	match patch["state"]:
		EcologicalState.BARE_GROUND:
			state_qubit.add_graph_edge("🔄", "🌱")  # Can become seedling

		EcologicalState.SEEDLING:
			state_qubit.add_graph_edge("🔄", "🌿")  # Can become sapling
			state_qubit.add_graph_edge("🔄", "🏜️")  # Can be eaten (back to bare)

		EcologicalState.SAPLING:
			state_qubit.add_graph_edge("🔄", "🌲")  # Can become forest
			state_qubit.add_graph_edge("🔄", "🌱")  # Can regress under stress

		EcologicalState.MATURE_FOREST:
			state_qubit.add_graph_edge("🔄", "🏜️")  # Can die (fire/disease)
			state_qubit.add_graph_edge("💧", "🍎")  # Produces apples
			state_qubit.add_graph_edge("💧", "☀️")  # Produces energy


func _update_patch_qubit(patch: Dictionary):
	"""Update the patch's state qubit to reflect ecological state"""
	match patch["state"]:
		EcologicalState.BARE_GROUND:
			patch["state_qubit"].radius = 0.1
		EcologicalState.SEEDLING:
			patch["state_qubit"].radius = 0.3
		EcologicalState.SAPLING:
			patch["state_qubit"].radius = 0.6
		EcologicalState.MATURE_FOREST:
			patch["state_qubit"].radius = 0.9
		EcologicalState.DEAD_FOREST:
			patch["state_qubit"].radius = 0.0


func add_organism(position: Vector2i, organism_icon: String) -> bool:
	"""Add a quantum organism to a patch"""
	if not patches.has(position):
		return false

	var patch = patches[position]

	# Create QuantumOrganism instead of bare qubit
	# This gives us full behavioral instincts and graph topology
	var organism = QuantumOrganism.new(organism_icon, "")  # Auto-detects type
	organism.qubit.radius = 0.5  # Start at medium strength

	patch["organisms"][organism_icon] = organism
	print("➕ Added %s at %s" % [organism_icon, position])
	return true


func get_biome_type() -> String:
	"""Return biome type identifier"""
	return "ForestEcosystem"


func harvest_water(position: Vector2i = Vector2i(-1, -1)) -> DualEmojiQubit:
	"""
	Harvest water from wolves in a patch.
	If position is (-1,-1), harvest from first patch with wolves.
	"""
	var target_patch = null

	if position != Vector2i(-1, -1):
		target_patch = patches.get(position)
	else:
		# Find patch with wolves
		for pos in patches.keys():
			if patches[pos]["organisms"].has("🐺"):
				target_patch = patches[pos]
				break

	if not target_patch or not target_patch["organisms"].has("🐺"):
		return null

	var wolf = target_patch["organisms"]["🐺"]
	var water_amount = wolf.radius * 0.3

	var water_qubit = BiomeUtilities.create_qubit("💧", "☀️", PI / 2.0)
	water_qubit.radius = water_amount

	total_water_harvested += water_amount

	print("💧 Harvested %.2f water from wolf at %s" % [water_amount, target_patch["position"]])
	return water_qubit


func get_ecosystem_status() -> Dictionary:
	"""Get current state of all patches"""
	var status = {
		"patches": [],
		"organisms_count": 0,
		"weather": {
			"wind_prob": sin(weather_qubit.theta / 2.0) ** 2,
			"water_prob": cos(weather_qubit.theta / 2.0) ** 2,
			"sun_prob": sin(season_qubit.theta / 2.0) ** 2
		},
		"total_water_harvested": total_water_harvested,
		"simulation_time": time_tracker.time_elapsed
	}

	for pos in patches.keys():
		var patch = patches[pos]
		var organism_list = []
		for icon in patch["organisms"].keys():
			organism_list.append({
				"icon": icon,
				"strength": patch["organisms"][icon].radius
			})

		status["patches"].append({
			"position": pos,
			"state": EcologicalState.keys()[patch["state"]],
			"organisms": organism_list
		})
		status["organisms_count"] += organism_list.size()

	return status


func get_state_name(state: int) -> String:
	"""Get readable name for ecological state"""
	match state:
		EcologicalState.BARE_GROUND:
			return "Bare Ground (🏜️)"
		EcologicalState.SEEDLING:
			return "Seedling (🌱)"
		EcologicalState.SAPLING:
			return "Sapling (🌿)"
		EcologicalState.MATURE_FOREST:
			return "Mature Forest (🌲)"
		EcologicalState.DEAD_FOREST:
			return "Dead Forest (☠️)"
		_:
			return "Unknown"


func _reset_custom() -> void:
	"""Override parent: Reset ecosystem to initial state"""
	patches.clear()
	total_water_harvested = 0.0
	total_apples_harvested = 0.0
	total_eggs_harvested = 0.0

	for x in range(grid_width):
		for y in range(grid_height):
			var pos = Vector2i(x, y)
			patches[pos] = _create_patch(pos)

	print("🌲 Forest Ecosystem reset")
