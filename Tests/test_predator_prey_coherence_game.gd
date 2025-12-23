#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test: Predator-Prey Coherence Game on Bloch Sphere
##
## Demonstrates:
## 1. Wolf (🐺, 💧) hunts rabbit (🐰, 🌱) via theta coherence
## 2. Rabbit survival instinct: flee from wolf theta
## 3. Rabbit reproduction instinct: breed when safe + well-fed
## 4. Complete quantum behavioral game on Bloch sphere

const QuantumOrganism = preload("res://Core/Environment/QuantumOrganism.gd")

var wolf: QuantumOrganism
var rabbit: QuantumOrganism
var rabbit_pop: Array[QuantumOrganism] = []

var simulation_time: float = 0.0
var food_available: float = 5.0  # Plant energy in patch

func _initialize():
	print("\n" + print_line("=", 80))
	print("🐺🐰 PREDATOR-PREY COHERENCE GAME (Bloch Sphere)")
	print("Wolf theta chases Rabbit theta | Rabbit survival & reproduction instincts")
	print(print_line("=", 80) + "\n")

	_phase_1_initial_setup()
	_phase_2_chase_and_escape()
	_phase_3_reproduction()
	_phase_4_population_dynamics()

	print(print_line("=", 80))
	print("✅ COHERENCE GAME TEST COMPLETE")
	print(print_line("=", 80) + "\n")

	quit()


func print_line(char: String, count: int) -> String:
	var line = ""
	for i in range(count):
		line += char
	return line


func print_sep() -> String:
	var line = ""
	for i in range(80):
		line += "─"
	return line


func _phase_1_initial_setup():
	"""Phase 1: Create organisms and show initial quantum states"""
	print(print_sep())
	print("PHASE 1: QUANTUM ORGANISMS CREATED")
	print(print_sep() + "\n")

	# Create wolf (predator)
	wolf = QuantumOrganism.new("🐺", "predator", "🐺", "💧")
	wolf.qubit.theta = 0.0  # Alert hunting state
	wolf.qubit.radius = 0.8  # Well-fed

	# Create rabbit (prey)
	rabbit = QuantumOrganism.new("🐰", "herbivore", "🐰", "🌱")
	rabbit.qubit.theta = PI  # Submissive fleeing state
	rabbit.qubit.radius = 0.6  # Moderate health

	rabbit_pop.append(rabbit)

	print("🐺 Wolf created:")
	print("   State: (🐺, 💧) on Bloch sphere")
	print("   Theta: %.2f rad (0° = hunting alert)" % wolf.qubit.theta)
	print("   Health: %.2f (well-fed)" % wolf.qubit.radius)
	print("   Instinct: Chase prey theta toward coherence")
	print()

	print("🐰 Rabbit created:")
	print("   State: (🐰, 🌱) on Bloch sphere")
	print("   Theta: %.2f rad (180° = fleeing panic)" % rabbit.qubit.theta)
	print("   Health: %.2f (moderate)" % rabbit.qubit.radius)
	print("   Instincts: Flee from predator + survive + reproduce")
	print()

	print("🌱 Food available: %.1f energy" % food_available)
	print()


func _phase_2_chase_and_escape():
	"""Phase 2: Bloch sphere chase - wolf hunts, rabbit escapes"""
	print(print_sep())
	print("PHASE 2: CHASE & ESCAPE (Theta coherence game)")
	print(print_sep() + "\n")

	print("Wolf hunting theta: 0.0° (alert)")
	print("Rabbit fleeing theta: 180.0° (panic)")
	print("Coherence threshold: %.2f radians" % rabbit.coherence_strike_threshold)
	print()

	# Run 10 chase cycles
	for cycle in range(1, 6):
		print("Cycle %d:" % cycle)
		print("  Before:")
		print("    Wolf theta:   %.2f° | Health: %.2f%%" % [
			wolf.qubit.theta * 180.0 / PI,
			wolf.qubit.radius * 100
		])
		print("    Rabbit theta: %.2f° | Health: %.2f%%" % [
			rabbit.qubit.theta * 180.0 / PI,
			rabbit.qubit.radius * 100
		])

		var theta_diff = abs(wolf.qubit.theta - rabbit.qubit.theta)
		print("    Theta diff: %.2f° (threshold: %.2f°)" % [
			theta_diff * 180.0 / PI,
			rabbit.coherence_strike_threshold * 180.0 / PI
		])
		print()

		# Simulate one chase cycle
		for i in range(5):
			# Wolf hunts
			wolf.update(0.1, [rabbit] as Array, 0.0, [])

			# Rabbit flees
			rabbit.update(0.1, [], 0.0, [wolf] as Array)

			# Food regenerates slowly
			food_available = min(5.0, food_available + 0.05)

			if not rabbit.alive:
				break

		if not rabbit.alive:
			print("  🐰 RABBIT CAUGHT! (Coherence achieved)")
			print()
			break

		print("  After:")
		print("    Wolf theta:   %.2f°" % [wolf.qubit.theta * 180.0 / PI])
		print("    Rabbit theta: %.2f°" % [rabbit.qubit.theta * 180.0 / PI])
		print()

	print("📊 Chase Result:")
	if rabbit.alive:
		print("   ✓ Rabbit escaped!")
		print("   • Rabbit escapes: %d" % rabbit.escapes)
		print("   • Health dropped: %.2f → %.2f" % [0.6, rabbit.qubit.radius])
	else:
		print("   ✗ Wolf caught rabbit!")
		print("   • Wolf gained energy: %.2f" % wolf.qubit.radius)
	print()


func _phase_3_reproduction():
	"""Phase 3: Rabbit reproduction with safety + food"""
	print(print_sep())
	print("PHASE 3: RABBIT REPRODUCTION (Safe + Well-fed)")
	print(print_sep() + "\n")

	# Reset for clean test
	wolf.qubit.theta = 0.0
	rabbit.alive = true
	rabbit.qubit.radius = 0.8  # Well-fed
	rabbit.qubit.theta = PI / 2.0  # Neutral (safe)
	food_available = 5.0

	print("Setup:")
	print("   Wolf theta: 0.0° (hunting)")
	print("   Rabbit theta: 90.0° (neutral/safe)")
	print("   Rabbit health: 80% (well-fed)")
	print("   Food available: 5.0 (abundant)")
	print()

	print("Simulation: Rabbit reproduces under safe conditions")
	print()

	for cycle in range(1, 4):
		print("Cycle %d:" % cycle)
		print("  Rabbit health: %.1f%%" % [rabbit.qubit.radius * 100])
		print("  Rabbit theta: %.1f° (1=relaxed, 180=panicked)" % [rabbit.qubit.theta * 180.0 / PI])
		print("  Wolf nearby (theta=0°)")
		print()

		# Rabbit feeds and reproduces
		rabbit.update(0.5, [], food_available, [])

		if rabbit.offspring_created > 0:
			print("  👶 Baby rabbit born!")
			print("     Parent cost: 30% health")
			print("     Baby health: 25%")
			print()
			var spec = rabbit.get_offspring_spec()
			var baby = QuantumOrganism.new(spec["icon"], spec["type"])
			baby.qubit.radius = spec["health"]
			rabbit_pop.append(baby)
			rabbit.offspring_created = 0

	print("📊 Reproduction Result:")
	print("   Rabbits created: %d (including parent)" % rabbit_pop.size())
	print("   Parent health: %.1f%%" % [rabbit.qubit.radius * 100])
	print("   Food consumed: %.2f energy" % rabbit.food_consumed)
	print()


func _phase_4_population_dynamics():
	"""Phase 4: Complete predator-prey population cycle"""
	print(print_sep())
	print("PHASE 4: POPULATION DYNAMICS (Predator-Prey Cycle)")
	print(print_sep() + "\n")

	# Reset with multiple rabbits
	wolf.qubit.radius = 0.8
	wolf.qubit.theta = 0.0
	wolf.predation_events = 0

	rabbit_pop.clear()
	for i in range(3):
		var r = QuantumOrganism.new("🐰", "herbivore")
		r.qubit.radius = 0.5 + (i * 0.1)
		r.qubit.theta = PI / 2.0 + randf_range(-0.3, 0.3)
		rabbit_pop.append(r)

	food_available = 8.0

	print("Initial state:")
	print("   Wolf: health=80%, theta=0° (hunting)")
	print("   Rabbits: 3 individuals, avg health=60%")
	print("   Food: 8.0 energy")
	print()

	# Run population dynamics
	var generation = 0
	var max_cycles = 15

	for cycle in range(1, max_cycles + 1):
		generation += 1
		print("Cycle %d:" % cycle)

		# Wolf hunts
		for rabbit in rabbit_pop:
			if rabbit.alive:
				wolf.update(0.2, [rabbit] as Array, 0.0, [])

		# Rabbits survive and reproduce
		var alive_before = rabbit_pop.filter(func(r): return r.alive).size()

		for rabbit in rabbit_pop:
			if rabbit.alive:
				rabbit.update(0.2, [], food_available, [wolf] as Array)

		var alive_after = rabbit_pop.filter(func(r): return r.alive).size()

		# Reproduction creates new rabbits
		var new_rabbits = []
		for rabbit in rabbit_pop:
			if rabbit.alive and rabbit.offspring_created > 0:
				for i in range(rabbit.reproduction_offspring_count):
					var spec = rabbit.get_offspring_spec()
					var baby = QuantumOrganism.new(spec["icon"], spec["type"])
					baby.qubit.radius = spec["health"]
					new_rabbits.append(baby)
				rabbit.offspring_created = 0  # Reset counter

		rabbit_pop.append_array(new_rabbits)

		# Food regenerates
		food_available = min(8.0, food_available + 0.5)

		# Status report every 3 cycles
		if cycle % 3 == 0:
			var alive_count = rabbit_pop.filter(func(r): return r.alive).size()
			var avg_health = 0.0
			if alive_count > 0:
				for r in rabbit_pop:
					if r.alive:
						avg_health += r.qubit.radius
				avg_health /= alive_count

			print("  🐺 Wolf: %.1f%% health, %d predations" % [wolf.qubit.radius * 100, wolf.predation_events])
			print("  🐰 Rabbits: %d alive, avg health %.1f%%" % [alive_count, avg_health * 100])
			print("  🌱 Food: %.1f energy" % food_available)
			print()

		if alive_after == 0 and new_rabbits.size() == 0:
			print("  ☠️  All rabbits extinct!")
			break

	print("📊 Population Dynamics Result:")
	var final_rabbit_count = rabbit_pop.filter(func(r): return r.alive).size()
	print("   Final rabbit population: %d" % final_rabbit_count)
	print("   Wolf predation events: %d" % wolf.predation_events)
	print("   Total rabbits created: %d" % rabbit_pop.size())
	print()

	print("🔬 Quantum Mechanics at Work:")
	print("   • Theta coherence = predator-prey interaction strength")
	print("   • Radius (energy) = health, hunger, reproduction cost")
	print("   • Population oscillations emerge naturally")
	print("   • No scripted rules - pure quantum dynamics")
	print()
