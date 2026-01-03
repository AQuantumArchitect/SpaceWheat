# Current Implementation: Forest Biome (Problematic)

## Overview
The Forest biome attempts to model a predator-prey ecosystem using quantum organisms. However, the current implementation spawns **individual agent instances**, leading to population explosion.

---

## Current Architecture

### QuantumOrganism Class
```gdscript
class QuantumOrganism extends Node:
    icon: String                  # "🐺", "🐰", etc.
    organism_type: String         # "predator", "herbivore"
    qubit: DualEmojiQubit         # Quantum state

    # Survival parameters
    escape_agility: float = 0.1
    hunting_pursuit: float = 0.15
    reproduction_threshold: float = 0.7

    # Game state
    alive: bool = true
    age: float = 0.0
    offspring_created: int = 0
```

Each organism is a **separate Node instance** with its own:
- Qubit state (theta, phi, radius)
- Behavioral parameters
- Life cycle tracking

---

## Current Behavior Loop

### Initialization
```gdscript
# Add organisms to a patch
forest_biome.add_organism(Vector2i(0, 0), "🐺")  # Creates Wolf instance
forest_biome.add_organism(Vector2i(1, 0), "🐰")  # Creates Rabbit instance
forest_biome.add_organism(Vector2i(2, 0), "🐭")  # Creates Mouse instance
```

### Update Loop (Every Frame)
```gdscript
func _update_quantum_organisms(patch, delta):
    var organisms_dict = patch.get_meta("organisms")  # {"🐰": Organism, "🐭": Organism, ...}

    for org in organisms_dict.values():
        org.update(delta, nearby_organisms, available_food, predators_nearby)
```

### Organism Update Logic
```gdscript
func QuantumOrganism.update(delta, nearby_organisms, available_food, predators_nearby):
    # 1. Base metabolism (hunger)
    qubit.radius *= (1.0 - hunger_decay_rate * delta)

    # 2. Survival instinct (flee from predators)
    if organism_type == "herbivore":
        _survival_instinct(delta, predators_nearby)
        _reproduction_instinct(available_food)
        _eat_food(available_food, delta)

    # 3. Hunting instinct (chase prey)
    elif organism_type == "predator":
        _hunting_instinct(delta, nearby_organisms)

    # 4. Death check
    if qubit.radius < starvation_threshold:
        alive = false
```

### Reproduction Logic (THE PROBLEM)
```gdscript
func _reproduction_instinct(available_food):
    var is_healthy = qubit.radius > reproduction_threshold  # r > 0.7
    var is_safe = abs(qubit.theta - PI/2) < 0.5              # Near neutral theta
    var has_food = available_food > 1.0

    if is_healthy and is_safe and has_food:
        offspring_created += 1
        # Parent creates offspring spec, patch spawns new QuantumOrganism instance
```

Then in the update loop:
```gdscript
# Handle reproduction - create offspring
if org.offspring_created > 0:
    for i in range(org.offspring_created):
        var spec = org.get_offspring_spec()
        var baby = QuantumOrganism.new(spec["icon"], spec["type"])
        baby.qubit.radius = spec["health"]
        var unique_key = spec["icon"] + "_" + str(randi())
        organisms_dict[unique_key] = baby  # ADD NEW ORGANISM INSTANCE
    org.offspring_created = 0
```

---

## The Population Explosion Problem

### Timeline
```
t=0s:   Start with 1 mouse (🐭)
        mouse.radius = 0.5

t=5s:   Mouse eats food
        mouse.radius = 0.75 (above reproduction_threshold)
        Spawn baby_mouse_1

t=10s:  Original mouse reproduces again
        Spawn baby_mouse_2
        baby_mouse_1 is now old enough to reproduce
        Spawn baby_mouse_3

t=15s:  4 mice all reproducing
        Spawn 4 more babies

t=20s:  8 mice all reproducing
        Spawn 8 more babies

t=60s:  Population: 100+ mice
```

**Exponential growth** because:
1. Each mouse is a separate instance
2. Healthy mice reproduce every ~5 seconds
3. Babies grow quickly and start reproducing
4. No carrying capacity limits

---

## Current Visualization Output

From test logs:
```
🌲 Forest: 4 nodes (organisms)
   👶 🐭 reproduces! (created offspring #1)
   👶 🐰 reproduces! (created offspring #1)
      🌱 Spawned 🐭_932369244 (🐭/🌾)
      🌱 Spawned 🐰_3761242001 (🐰/🌱)
   👶 🐰 reproduces! (created offspring #1)
      🌱 Spawned 🐰_3747983186 (🐰/🌱)
```

Each organism gets a unique instance ID, leading to:
- **Memory overhead:** Hundreds of Node instances
- **Visual clutter:** 100 bubbles on screen
- **Conceptual mismatch:** We want to express "mouse-ness" not "100 individual mice"

---

## What's Conceptually Wrong

The current implementation treats organisms as **literal agents** in a micro-simulation, like:
- NetLogo agent-based models
- Cellular automata
- Conway's Game of Life

But SpaceWheat is supposed to be a **conceptual/platonic** representation where:
- One qubit = one concept/archetype
- Population dynamics encoded in qubit properties
- No discrete birth/death events

---

## Comparison to BioticFlux

| Aspect | BioticFlux (Works) | Forest (Broken) |
|--------|-------------------|-----------------|
| **Entity count** | 1 sun, N crops | 1 wolf → 100 wolves |
| **Spawning** | Player plants | Auto-reproduction |
| **Energy** | Grows from sun | Grows from food |
| **Scaling** | Linear (N crops) | Exponential (2^N organisms) |
| **Concept** | "Wheat field" | "Wolf pack" |
| **Qubit role** | State of crop | State of individual |

The BioticFlux model has N independent crops, each evolving separately but following the same physics.

The Forest model tries to simulate a population but uses individual instances instead of aggregate state.

---

## Why Individual Instances Seemed Reasonable

Initial reasoning:
1. Predator-prey needs interaction between entities
2. Each organism has its own quantum state (theta, phi)
3. Food web topology requires tracking relationships

But this conflates:
- **Simulation granularity** (how many entities to track)
- **Quantum representation** (how to encode population state)

A single qubit can represent **collective state** without needing individual instances.
