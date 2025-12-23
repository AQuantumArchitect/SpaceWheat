# 🌲 Quantum Forest Ecosystem Biome Design

## Vision

A complete **predator-prey ecosystem** modeled as **quantum state transitions** using Markov chains.

No classical energy tracking - everything is **quantum icons in superposition**, representing ecological states and organisms.

```
Forest Plot State Machine (Markov Chain):

Bare Ground (🏜️)
    ↓ (wind, rain, seed)
Seedling (🌱)
    ↓ (growth, nutrients)
Sapling (🌿)
    ↓ (maturation)
Mature Forest (🌲)
    ↓ (wildfire, disease)
    ↓ (back to bare)

Organisms within each state:
- 🐺 Wolf (produces 💧 water)
- 🦅 Eagle (produces 🌬️ wind)
- 🐦 Bird (produces 🥚 egg)
- 🐰 Rabbit (eaten by wolf/eagle)
- 🐛 Caterpillar (eats seedling, eaten by bird)
- 🐱 Cat (eaten by wolf/eagle)
- 🐭 Mouse (eaten by cat/eagle)
```

---

## Quantum Food Web

### Organism Icons

```
Producers:
🌱 Seedling → Energy source
🌿 Sapling → More energy
🌲 Forest → Maximum energy
🍎 Apple → Food from forest

Weather:
🌬️ Wind → Fertilizes, disperses seeds
💧 Water → Growth enabler
☀️ Sun → Growth energy
🌧️ Rain → Water source

Primary Consumers:
🐰 Rabbit (eats seedling)
🐛 Caterpillar (eats leaves)
🐭 Mouse (eats seeds)

Secondary Consumers:
🐦 Bird (eats caterpillar, lays egg 🥚)
🐱 Cat (eats mouse/rabbit)
🐺 Wolf (eats rabbit/deer, produces 💧)

Apex Predators:
🦅 Eagle (eats bird/rabbit/mouse)
🐺 Wolf (apex in this ecosystem)

Environmental:
🏔️ Mountain/Landform (affects forest growth)
⚡ Lightning (wildfire trigger)
```

### Markov Transition Matrix

Each plot has a state and transitions based on:
1. Current ecological state
2. Organisms present
3. Weather/environmental factors
4. Predator-prey dynamics

**Example: Seedling State**

```
Seedling (🌱)
    P(stay seedling) = 0.6        # Slow growth
    P(→ sapling)     = 0.3        # Conditions right
    P(→ bare)        = 0.1        # Eaten by rabbits

If wolf present:
    P(→ sapling)     = 0.4        # Wolf eats rabbits, seedling survives
    P(→ bare)        = 0.05       # Fewer herbivores

If rain (💧) present:
    P(→ sapling)     = 0.5        # Better growth
```

---

## Biome Architecture

### ForestEcosystem_Biome.gd

```gdscript
class_name ForestEcosystem_Biome
extends Node

## Grid of ecosystem patches (like farming grid but ecological)
var patches: Dictionary  # [Vector2i] → EcosystemPatch

## Global weather state (affects all patches)
var weather_qubit: DualEmojiQubit  # (🌬️, 💧) - wind vs water
var sun_qubit: DualEmojiQubit      # (☀️, 🌧️) - sun vs rain

## Methods
func create_patch(position: Vector2i) -> EcosystemPatch
func get_patch(position: Vector2i) -> EcosystemPatch
func update_all_patches(delta: float)
func harvest_water() -> float      # From wolves
func harvest_apples() -> float     # From mature forest
func harvest_eggs() -> float       # From birds

## Markov transitions
func apply_ecological_transitions()
```

### EcosystemPatch.gd

```gdscript
class_name EcosystemPatch
extends Node

## Ecological state
enum State {
    BARE_GROUND,
    SEEDLING,
    SAPLING,
    MATURE_FOREST,
    DEAD_FOREST
}

var state: State = State.BARE_GROUND
var state_qubit: DualEmojiQubit    # Quantum representation of state

## Organisms in patch (quantum superposition)
var organisms: Dictionary           # [icon] → DualEmojiQubit
# Example:
# "🐺" → wolf qubit
# "🦅" → eagle qubit
# "🐰" → rabbit qubit

## Methods
func add_organism(icon: String, qubit: DualEmojiQubit)
func remove_organism(icon: String)
func transition(delta: float)       # Apply Markov transition
func eat_organism(predator: String, prey: String)  # Predation
func get_harvestable_resource() -> String
func harvest_resource() -> DualEmojiQubit
```

---

## Markov Transition Rules

### Bare Ground → Seedling

Requires:
- Wind (🌬️) to carry seeds
- Water (💧) for germination
- No predators eating seeds

```
Transition rate: P = P(wind) * P(water) * 0.7
  = sin²(weather_theta/2) * cos²(weather_theta/2) * 0.7
  = max 0.25 * 0.7 = 0.175
```

### Seedling → Sapling

Requires:
- Survive herbivores (rabbits, caterpillars)
- Get water and sun
- Grow for time period

```
Base: P = 0.3
If wolf present (eats rabbits): P = 0.4
If eagle present (eats caterpillars): P = 0.4
If both: P = 0.5
If rain: P += 0.1
If drought: P -= 0.1
```

### Sapling → Mature Forest

Requires:
- Years of growth
- Sufficient water
- Low predation (or predator balance)

```
Base: P = 0.2
If water abundant: P = 0.3
If forest nearby (seed source): P = 0.25
If rain: P += 0.05
```

### Mature Forest → Dead/Bare

Triggers:
- Wildfire (low probability, high impact)
- Disease (rare)
- Climate change (gradual)

```
Base: P = 0.02 (low background death)
If fire (lightning): P = 0.8
If drought: P += 0.05
```

---

## Predator-Prey Dynamics

### Wolf Cycle

```
High rabbit population
    ↓ (wolves eat rabbits)
Wolves flourish (🐺 energy increases)
    ↓ (wolves produce 💧 water as "waste")
Water becomes abundant
    ↓ (water enables seedling→sapling)
More plants grow
    ↓ (rabbits return)
Cycle repeats

OUTPUT: Wolf presence → Water production
```

### Eagle Cycle

```
High bird population
    ↓ (eagles eat birds)
Eagle flourishes (🦅 energy increases)
    ↓ (eagles produce 🌬️ wind as "movement")
Wind disperses seeds
    ↓ (more plants sprout)
More insects appear (food for birds)
    ↓ (bird population recovers)
Cycle repeats

OUTPUT: Eagle presence → Wind production
```

---

## Harvesting Mechanics

### Water Harvest (from wolves)

```
Wolf produces water as byproduct of existence
Player can harvest from patches with wolves

Harvest amount: wolf_qubit.radius * 0.5
Output: 💧 water qubit

Connects to: Kitchen needs 💧 water
```

### Apple Harvest (from mature forest)

```
Mature forest produces apples as fruit

Harvest amount: forest_state_qubit.radius * 0.3
Output: 🍎 apple qubit

Could use for: Special recipes, guild trade
```

### Egg Harvest (from birds)

```
Bird population produces eggs

Harvest amount: bird_qubit.radius * 0.2
Output: 🥚 egg qubit

Could use for: Animal feed, guild trade
```

---

## Integration Points

### With Farming Biome

```
Forest plot (special plot type)
    ↓ (ecological state)
Can be planted like farming plots
But transitions are ecological, not agricultural
    ↓ (Markov chain rules)
Players harvest resources from forest

Forest plot updates:
- Each tick: Apply Markov transition
- Presence of wolf/eagle → resource production
- Seasons/weather → affects transitions
```

### With Kitchen

```
Kitchen needs 💧 water
    ↓ (input from forest)
Forest plots with wolves → produce water
    ↓ (harvest water qubit)
Player feeds water to kitchen
    ↓ (kitchen produces bread)
Complete chain!
```

### With Guild System

```
Guilds want 💧 water
    ↓ (guild pressure on market)
Player must maintain forest with wolves
    ↓ (ecological management)
Forest management becomes strategic
    ↓ (timing, organism placement)
Player discovers: predators create resources
```

---

## Quantum Mechanics Grounding

### Why Quantum?

1. **Superposition** - Patch in multiple ecological states until "measured" (observed by player)
2. **Entanglement** - Predator presence affects prey behavior
3. **Probability** - Markov chains model stochastic transitions
4. **Measurement collapse** - Harvesting collapses resource state

### Icons as Qubits

Each organism is a **dual-emoji superposition**:

```
Wolf: (🐺, 💧)
    State 1: 🐺 = wolf hunting/alive
    State 2: 💧 = wolf contribution to hydrology
    Theta: position on Bloch sphere
    Radius: population strength

Eagle: (🦅, 🌬️)
    State 1: 🦅 = eagle alive/hunting
    State 2: 🌬️ = eagle wind effect

Rabbit: (🐰, 🌱)
    State 1: 🐰 = rabbit alive
    State 2: 🌱 = food source for ecosystem
```

---

## Test Scenario

### Complete Forest Cycle (test_forest_ecosystem.gd)

```
PHASE 1: Initial State
  - 5x5 grid of bare ground patches
  - Weather: Balanced (wind + water equal)
  - No organisms yet

PHASE 2: Natural Succession (10 cycles)
  - Wind and water trigger seedling growth
  - Seedlings grow to saplings
  - First organisms appear: rabbits, birds
  - Forest begins to form

PHASE 3: Predator Introduction (5 cycles)
  - Player adds wolf to patch
  - Wolf hunts rabbits
  - Water production visible
  - Forest growth accelerates (fewer herbivores)

PHASE 4: Ecosystem Balance (5 cycles)
  - Multiple predators and prey
  - Markov chains create natural cycles
  - Boom and bust in animal populations
  - Resource production steady

PHASE 5: Harvesting (3 cycles)
  - Player harvests water from wolves
  - Output: 💧 water qubits for kitchen
  - Demonstration: Forest → Water → Kitchen → Bread
```

---

## File Structure

```
Core/Environment/
├── ForestEcosystem_Biome.gd         # Main biome
├── EcosystemPatch.gd                # Individual patch with state
├── EcologicalTransition.gd          # Markov transition logic
└── EcosystemOrganism.gd             # Organism qubit wrapper

Tests/
└── test_forest_ecosystem.gd         # Full ecosystem demo
```

---

## Conclusion

The **Forest Ecosystem** is a **pure quantum icon biome** where:

1. Ecological states are quantum superpositions
2. Predator-prey dynamics emerge from Markov chains
3. Resources (water, apples, eggs) are produced by organisms
4. Player manages ecosystem to harvest resources
5. All grounded in **real ecology** (population dynamics, food webs, succession)

Just like everything else in SpaceWheat - **no arbitrary rules, pure physics** (ecological and quantum). ✨
