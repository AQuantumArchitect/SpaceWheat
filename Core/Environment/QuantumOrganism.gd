class_name QuantumOrganism
extends Node

## Quantum Organism: Predator or Prey in Bloch Sphere Coherence Game
##
## Each organism is a full DualEmojiQubit with behavioral instincts:
## - PREDATORS: Drive theta toward prey (coherence seeking)
## - PREY: Drive theta away from predators (coherence fleeing)
##         + Survive on food + Reproduce when safe/well-fed
##
## Theta represents behavioral state on Bloch sphere:
##   theta = 0: Pure predatory/alert state
##   theta = π/2: Neutral/balanced
##   theta = π: Pure prey/submissive state
##
## Radius = energy/health (consumed by: reproduction, stress, hunger)
## Phi = phase coupling to environment (unused for now)

const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

## Organism identity
var icon: String            # "🐺", "🐰", "🦅", etc.
var organism_type: String   # "predator", "herbivore", "apex"

## Quantum state
var qubit: DualEmojiQubit   # Full (icon, companion) dual-emoji

## Behavioral parameters (now using pure emoji graph topology)
## Relationships are stored in qubit.entanglement_graph instead of string arrays:
##   🍴 = Predation (this organism hunts)
##   🏃 = Escape (this organism flees from)
##   🌱 = Consumption (this organism feeds on)
##   💧 = Production (this organism produces)
##   👶 = Reproduction (this organism creates offspring)

## Survival instinct parameters
var escape_agility: float = 0.1           # How fast prey theta escapes (radians/step)
var hunting_pursuit: float = 0.15         # How fast predator theta chases (radians/step)
var coherence_strike_threshold: float = 0.3  # Theta difference for successful predation
var stress_energy_cost: float = 0.05      # Energy spent escaping

## Reproductive instinct parameters
var reproduction_threshold: float = 0.7   # Minimum radius + food to reproduce
var reproduction_energy_cost: float = 0.3 # Energy spent creating offspring
var reproduction_offspring_count: int = 2 # How many babies created
var reproduction_offspring_health: float = 0.25 # Starting radius of babies

## Resource/survival parameters
var food_energy_gained: float = 0.15      # Energy from eating food
var hunger_decay_rate: float = 0.01       # Energy loss per tick (base metabolism)
var starvation_threshold: float = 0.1     # Below this, death

## Game state
var alive: bool = true
var age: float = 0.0
var offspring_created: int = 0
var food_consumed: float = 0.0
var predation_events: int = 0
var escapes: int = 0


func _init(icon_str: String, org_type: String, emoji1: String = "", emoji2: String = ""):
	"""Initialize quantum organism"""
	icon = icon_str

	# Auto-detect organism type from icon if not provided
	if org_type == "":
		org_type = _detect_organism_type(icon_str)
	organism_type = org_type

	# Create quantum state
	if emoji1 == "":
		# Auto-pair based on organism type
		emoji1 = icon_str
		emoji2 = _get_companion_emoji(org_type)

	qubit = DualEmojiQubit.new(emoji1, emoji2, PI / 2.0)  # Start balanced
	qubit.phi = 0.0
	qubit.radius = 0.5  # Start at medium health

	# Set up predator/prey relationships
	_setup_relationships()


func _detect_organism_type(emoji: String) -> String:
	"""Auto-detect organism type from emoji"""
	match emoji:
		"🐺", "🦅", "🐦", "🐱", "🦊":
			return "predator"
		"🐰", "🐭", "🐛", "🦔":
			return "herbivore"
		_:
			return ""


func _get_companion_emoji(org_type: String) -> String:
	"""Get paired emoji for organism type"""
	match org_type:
		"predator":
			match icon:
				"🐺": return "💧"  # Wolf ↔ Water
				"🦅": return "🌬️"  # Eagle ↔ Wind
				"🐱": return "👁️"  # Cat ↔ Eyes
				_: return "⚡"
		"herbivore":
			match icon:
				"🐰": return "🌱"  # Rabbit ↔ Seedling
				"🐛": return "🍃"  # Caterpillar ↔ Leaf
				"🐭": return "🌾"  # Mouse ↔ Grain
				_: return "🌿"
		_:
			return "💚"


func _setup_relationships():
	"""Configure emoji topology graph (pure emoji relationships)"""
	match icon:
		"🐺":  # Wolf
			qubit.add_graph_edge("🍴", "🐰")  # Hunts rabbit
			qubit.add_graph_edge("🍴", "🐭")  # Hunts mouse
			qubit.add_graph_edge("🍴", "🐻")  # Hunts bear
			qubit.add_graph_edge("💧", "☀️")  # Produces water
			organism_type = "predator"

		"🦅":  # Eagle
			qubit.add_graph_edge("🍴", "🐦")  # Hunts bird
			qubit.add_graph_edge("🍴", "🐭")  # Hunts mouse
			qubit.add_graph_edge("🍴", "🐰")  # Hunts rabbit
			qubit.add_graph_edge("💧", "🌬️")  # Produces wind
			organism_type = "apex"

		"🐦":  # Bird
			qubit.add_graph_edge("🍴", "🐛")  # Hunts caterpillar
			qubit.add_graph_edge("💧", "🥚")  # Produces eggs
			organism_type = "predator"

		"🐱":  # Cat
			qubit.add_graph_edge("🍴", "🐭")  # Hunts mouse
			qubit.add_graph_edge("🍴", "🐰")  # Hunts rabbit
			organism_type = "predator"

		"🐰":  # Rabbit
			qubit.add_graph_edge("🏃", "🐺")  # Flees wolf
			qubit.add_graph_edge("🏃", "🦅")  # Flees eagle
			qubit.add_graph_edge("🏃", "🐱")  # Flees cat
			qubit.add_graph_edge("🌱", "🌿")  # Eats seedlings
			qubit.add_graph_edge("🌱", "🌲")  # Eats saplings
			qubit.add_graph_edge("👶", "🐰")  # Reproduces
			organism_type = "herbivore"

		"🐛":  # Caterpillar
			qubit.add_graph_edge("🏃", "🐦")  # Flees bird
			qubit.add_graph_edge("🌱", "🌿")  # Eats leaves
			qubit.add_graph_edge("🌱", "🍃")  # Eats leaves
			organism_type = "herbivore"

		"🐭":  # Mouse
			qubit.add_graph_edge("🏃", "🐺")  # Flees wolf
			qubit.add_graph_edge("🏃", "🦅")  # Flees eagle
			qubit.add_graph_edge("🏃", "🐱")  # Flees cat
			qubit.add_graph_edge("🌱", "🌾")  # Eats grain
			qubit.add_graph_edge("🌱", "🌱")  # Eats seedling
			organism_type = "herbivore"


func update(delta: float, nearby_organisms: Array, available_food: float, predators_nearby: Array):
	"""
	Update organism state each tick

	Inputs:
	- delta: time step
	- nearby_organisms: other organisms in patch (for coherence calculations)
	- available_food: total food energy in patch
	- predators_nearby: predators hunting this organism
	"""
	if not alive:
		return

	age += delta

	# Base metabolism (always costs energy)
	_apply_hunger(delta)

	# If prey: survival instinct
	if organism_type == "herbivore":
		_survival_instinct(delta, predators_nearby)
		_reproduction_instinct(available_food)
		_eat_food(available_food, delta)

	# If predator: hunt prey
	elif organism_type in ["predator", "apex"]:
		_hunting_instinct(delta, nearby_organisms)

	# Death check
	if qubit.radius < starvation_threshold:
		alive = false


func _apply_hunger(delta: float):
	"""Base metabolism - organism loses energy over time"""
	qubit.radius *= (1.0 - hunger_decay_rate * delta)


func _survival_instinct(delta: float, predators_nearby: Array):
	"""
	PREY BEHAVIOR: Flee from predators using graph topology

	Mechanism: Theta evasion on Bloch sphere
	- When predator near: drive theta away from their theta
	- Each escape attempt costs energy (stress)
	- Uses emoji graph to check which organisms are predators (🏃 = flees from)
	"""
	if predators_nearby.is_empty():
		# No danger - theta drifts toward neutral (relaxed)
		qubit.theta = lerp(qubit.theta, PI / 2.0, 0.02)
		return

	# Predators nearby! Execute escape maneuvers
	for predator in predators_nearby:
		if predator == null or not predator.has_method("get_qubit"):
			continue

		# Check graph: do I flee from this predator? (🏃 = flees from)
		if not qubit.has_graph_edge("🏃", predator.icon):
			continue  # Not my predator

		var predator_qubit = predator.get_qubit()
		var theta_diff = predator_qubit.theta - qubit.theta

		# Check if predator is achieving coherence (about to catch us!)
		if abs(theta_diff) < coherence_strike_threshold:
			# PANIC! Emergency theta jump away
			qubit.theta += sign(theta_diff) * escape_agility * 2.0
			qubit.radius *= (1.0 - stress_energy_cost)  # Escape costs energy
			escapes += 1
			print("   🏃 %s escapes from %s! (theta jump)" % [icon, predator.icon])
		else:
			# Gradual theta evasion away from predator
			qubit.theta -= sign(theta_diff) * escape_agility * delta

	# Keep theta in bounds
	qubit.theta = fmod(qubit.theta, TAU)


func _reproduction_instinct(available_food: float):
	"""
	PREY BEHAVIOR: Reproduce when safe and well-fed

	Triggers:
	- Radius > reproduction_threshold (healthy)
	- Available food > some amount (safe environment)
	- Not under immediate stress (theta near neutral)

	Effect: Creates offspring organism (returned separately)
	"""
	# Check conditions for reproduction
	var is_healthy = qubit.radius > reproduction_threshold
	var is_safe = abs(qubit.theta - PI / 2.0) < 0.5  # Near neutral theta (not scared)
	var has_food = available_food > 1.0  # Enough food in environment

	if is_healthy and is_safe and has_food:
		# Reproduce!
		offspring_created += 1
		qubit.radius -= reproduction_energy_cost
		print("   👶 %s reproduces! (created offspring #%d)" % [icon, offspring_created])


func _eat_food(available_food: float, delta: float):
	"""
	PREY BEHAVIOR: Eat available plants/food using graph topology

	Herbivores gain energy from eating food sources
	- Uses emoji graph to check if organism eats plants (🌱 = consumption)
	"""
	# Check if we have any 🌱 edges (feeding relationships)
	var food_targets = qubit.get_graph_targets("🌱")
	if food_targets.is_empty():
		return  # Not a herbivore

	if available_food > 0.1:
		var food_eaten = min(available_food, food_energy_gained * delta)
		qubit.radius = min(1.0, qubit.radius + food_eaten)
		food_consumed += food_eaten


func _hunting_instinct(delta: float, nearby_organisms: Array):
	"""
	PREDATOR BEHAVIOR: Chase and hunt prey using graph topology

	Mechanism: Theta pursuit on Bloch sphere
	- Drive theta toward prey theta (seek coherence)
	- When coherence achieved: successful predation
	- Uses emoji graph to check if organism is valid prey
	"""
	for prey in nearby_organisms:
		if prey == null or not prey.has_method("get_qubit"):
			continue

		# Check graph: do I hunt this organism? (🍴 = hunts)
		if not qubit.has_graph_edge("🍴", prey.icon):
			continue  # Not my prey

		var prey_qubit = prey.get_qubit()
		var theta_diff = prey_qubit.theta - qubit.theta

		# Chase prey theta
		qubit.theta += hunting_pursuit * delta * sign(theta_diff)

		# Check for coherence strike (successful predation)
		if abs(theta_diff) < coherence_strike_threshold:
			# CAUGHT PREY!
			var prey_energy = prey_qubit.radius * 0.5  # Get half their energy
			qubit.radius = min(1.0, qubit.radius + prey_energy)
			predation_events += 1
			prey.be_eaten()  # Mark prey as dead
			print("   🍽️  %s catches %s! (coherence strike)" % [icon, prey.icon])

	# Hunting doesn't require active pursuit if no prey found
	# Theta drifts toward alert state
	if nearby_organisms.is_empty():
		qubit.theta = lerp(qubit.theta, 0.0, 0.01)


func get_offspring_spec() -> Dictionary:
	"""Get specification for creating an offspring (let caller instantiate)"""
	return {
		"icon": icon,
		"type": organism_type,
		"health": reproduction_offspring_health
	}


func be_eaten():
	"""Organism is caught by predator - dies immediately"""
	alive = false
	print("   ☠️  %s is eaten!" % icon)


func get_qubit() -> DualEmojiQubit:
	"""Get quantum state"""
	return qubit


func get_status() -> Dictionary:
	"""Get organism state for display"""
	return {
		"icon": icon,
		"type": organism_type,
		"alive": alive,
		"health": qubit.radius,
		"theta": qubit.theta,
		"theta_degrees": qubit.theta * 180.0 / PI,
		"age": age,
		"offspring": offspring_created,
		"food_consumed": food_consumed,
		"predation_events": predation_events,
		"escapes": escapes
	}
