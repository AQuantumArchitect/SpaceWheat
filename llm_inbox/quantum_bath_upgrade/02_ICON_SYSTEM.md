# Icon System
## The Gods of Interaction

---

## Philosophy

Icons are the eternal spirits that define how emojis interact. They are:

- **Immutable**: Once defined, an Icon's rules don't change
- **Universal**: The same Icon applies wherever that emoji exists
- **Composable**: Multiple Icons combine naturally via superposition
- **Emergent**: Complex behavior arises from simple Icon rules

Icons are the **design space** of SpaceWheat. A blank emoji is inert. Attaching an Icon breathes life into it.

---

## Icon Structure

```gdscript
class_name Icon
extends Resource

## Identity
@export var emoji: String                    # Which emoji this Icon governs
@export var display_name: String             # Human-readable name
@export var description: String              # Flavor text

## Hamiltonian Terms (Unitary)
@export var self_energy: float = 0.0         # Diagonal term H[i,i]
@export var hamiltonian_couplings: Dictionary = {}  
# {target_emoji: coupling_strength}
# Coupling is real for now; could be Complex for phase effects

## Lindblad Terms (Dissipative)  
@export var lindblad_outgoing: Dictionary = {}
# {target_emoji: transfer_rate}
# Energy flows FROM this emoji TO target

@export var lindblad_incoming: Dictionary = {}
# {source_emoji: transfer_rate}  
# Energy flows TO this emoji FROM source
# (Syntactic sugar - equivalent to source Icon having outgoing)

@export var decay_rate: float = 0.0          # Self-dissipation rate
@export var decay_target: String = "🍂"       # Where decay goes

## Time Dependence
@export var self_energy_driver: String = ""   # Expression or callable name
@export var driver_frequency: float = 0.0     # For oscillatory drivers
@export var driver_phase: float = 0.0         # Phase offset

## Metadata
@export var trophic_level: int = 0           # 0=abiotic, 1=producer, 2=herbivore, 3=carnivore
@export var tags: Array[String] = []          # ["celestial", "flora", "predator", etc.]
```

---

## Hamiltonian Coupling Semantics

### What Coupling Means

A Hamiltonian coupling between emoji A and emoji B creates **coherent oscillation** between them. Amplitude sloshes back and forth.

```
H_AB = J (|A⟩⟨B| + |B⟩⟨A|)

Effect: If bath is in |A⟩, it evolves toward superposition of |A⟩ and |B⟩
        The rate of oscillation is proportional to J
```

**Interpretation**: The two emojis are "aware" of each other. Their fates are linked.

### Coupling Strength Guidelines

| Strength | Meaning | Example |
|----------|---------|---------|
| 0.0 | No coupling | Unrelated emojis |
| 0.1-0.3 | Weak awareness | Distant ecological connection |
| 0.3-0.6 | Moderate coupling | Direct interaction (predator sees prey) |
| 0.6-0.9 | Strong coupling | Tight relationship (symbiosis) |
| 1.0+ | Dominant coupling | Defining relationship |

### Coupling Examples

```gdscript
# Sun couples strongly to moon (they define each other)
Icon_☀.hamiltonian_couplings = {"🌙": 0.8}

# Wolf couples moderately to rabbit (hunting awareness)
Icon_🐺.hamiltonian_couplings = {"🐇": 0.4, "🦌": 0.3}

# Rabbit couples to vegetation (food awareness) and wolf (danger awareness)
Icon_🐇.hamiltonian_couplings = {"🌿": 0.5, "🐺": 0.4}
```

---

## Lindblad Transfer Semantics

### What Transfer Means

A Lindblad term from A to B creates **directed amplitude flow**. This is irreversible.

```
L = √γ |B⟩⟨A|

Effect: Amplitude drains from A to B at rate γ
        This is NOT symmetric - A loses, B gains
```

**Interpretation**: Energy, life force, or resources flow in one direction.

### Transfer Rate Guidelines

| Rate | Meaning | Example |
|------|---------|---------|
| 0.0 | No transfer | No resource relationship |
| 0.01-0.05 | Slow trickle | Background nutrient cycling |
| 0.05-0.15 | Moderate flow | Normal predation/consumption |
| 0.15-0.30 | Fast transfer | Aggressive predation, rapid growth |
| 0.30+ | Dominant transfer | Overwhelming consumption |

### Transfer Examples

```gdscript
# Vegetation grows from sunlight
Icon_🌿.lindblad_incoming = {"☀": 0.1}

# Rabbit eats vegetation (vegetation → rabbit)
Icon_🐇.lindblad_incoming = {"🌿": 0.08}

# Wolf eats rabbit (rabbit → wolf)
Icon_🐺.lindblad_incoming = {"🐇": 0.12, "🦌": 0.10}

# Everything decays to organic matter
Icon_🐺.decay_rate = 0.02
Icon_🐺.decay_target = "🍂"
```

---

## Self-Energy Semantics

### What Self-Energy Means

The diagonal Hamiltonian term H[i,i] = E_i gives the emoji its "natural frequency."

```
|ψ_i(t)⟩ = e^(-iE_i t) |ψ_i(0)⟩

Effect: The phase of amplitude i rotates at rate E_i
```

**Interpretation**: Higher self-energy = faster phase evolution = more "active" or "energetic" emoji.

### Self-Energy Guidelines

| Value | Meaning | Example |
|-------|---------|---------|
| -0.5 to -0.1 | Negative energy (unstable, tends to decay) | Sick organisms |
| -0.1 to 0.1 | Neutral (stable) | Most things |
| 0.1 to 0.5 | Positive energy (active, vibrant) | Thriving organisms |
| 0.5+ | High energy (driving force) | Sun, celestial bodies |

### Self-Energy Examples

```gdscript
# Sun has high positive energy (drives the system)
Icon_☀.self_energy = 0.5

# Healthy vegetation is slightly positive
Icon_🌿.self_energy = 0.1

# Organic matter is neutral (stable, doesn't drive anything)
Icon_🍂.self_energy = 0.0

# A starving wolf might have negative self-energy
# (But this would be state-dependent, not Icon-level)
```

---

## Time-Dependent Icons

### The Day/Night Cycle

The sun Icon has time-dependent self-energy:

```gdscript
Icon_☀ = Icon.new()
Icon_☀.emoji = "☀"
Icon_☀.self_energy_driver = "cosine"
Icon_☀.driver_frequency = 0.1  # Cycles per second
Icon_☀.driver_phase = 0.0

# In QuantumBath, evaluate:
func get_icon_self_energy(icon: Icon, time: float) -> float:
    if icon.self_energy_driver == "cosine":
        return icon.self_energy * cos(icon.driver_frequency * time * TAU + icon.driver_phase)
    elif icon.self_energy_driver == "sine":
        return icon.self_energy * sin(icon.driver_frequency * time * TAU + icon.driver_phase)
    else:
        return icon.self_energy
```

### Seasonal Variation

Longer cycles for seasonal effects:

```gdscript
Icon_🌸 = Icon.new()  # Cherry blossom
Icon_🌸.emoji = "🌸"
Icon_🌸.self_energy_driver = "cosine"
Icon_🌸.driver_frequency = 0.001  # Very slow cycle
Icon_🌸.driver_phase = PI / 2     # Peaks in "spring"
```

---

## Icon Composition

### How Icons Combine in a Biome

When multiple emojis exist in a biome, their Icons contribute additively:

```gdscript
# In QuantumBath
func build_total_hamiltonian():
    H = zero_matrix(N, N)
    
    for emoji in emoji_list:
        var icon = IconRegistry.get_icon(emoji)
        if not icon:
            continue
        
        var i = emoji_to_index[emoji]
        
        # Add self-energy to diagonal
        H[i][i] += icon.get_self_energy(bath_time)
        
        # Add couplings (symmetrized for Hermiticity)
        for target in icon.hamiltonian_couplings:
            if not emoji_to_index.has(target):
                continue
            var j = emoji_to_index[target]
            var coupling = icon.hamiltonian_couplings[target]
            H[i][j] += coupling / 2.0
            H[j][i] += coupling / 2.0
    
    return H
```

### Emergent Behavior

By defining Icons independently, complex behavior emerges from their combination:

**Example: Forest Ecosystem**

Icons defined:
- ☀ → high self-energy, couples to 🌿
- 🌿 → receives from ☀, couples to 🐇, decays to 🍂
- 🐇 → receives from 🌿, couples to 🐺, decays to 🍂
- 🐺 → receives from 🐇, decays to 🍂
- 🍂 → receives from decay, couples to 🌿 (nutrient cycling)

Emergent dynamics:
1. ☀ drives 🌿 growth
2. 🌿 feeds 🐇
3. 🐇 population rises
4. 🐺 feeds on 🐇
5. 🐺 population rises, 🐇 falls
6. 🐺 starves, decays
7. 🍂 accumulates, feeds back to 🌿
8. Cycle continues

**No hand-coded Lotka-Volterra. Just Icons.**

---

## The Icon Registry

### Singleton Pattern

```gdscript
# IconRegistry.gd
extends Node

var icons: Dictionary = {}  # emoji → Icon

func _ready():
    _load_builtin_icons()
    _load_custom_icons()

func register_icon(icon: Icon):
    icons[icon.emoji] = icon

func get_icon(emoji: String) -> Icon:
    return icons.get(emoji, null)

func has_icon(emoji: String) -> bool:
    return icons.has(emoji)

func get_all_emojis() -> Array[String]:
    return icons.keys()
```

### Loading Icons

**Option 1: Programmatic definition**

```gdscript
func _load_builtin_icons():
    # Celestial
    var sun = Icon.new()
    sun.emoji = "☀"
    sun.display_name = "Sol"
    sun.self_energy = 0.5
    sun.self_energy_driver = "cosine"
    sun.driver_frequency = 0.05
    sun.hamiltonian_couplings = {"🌙": 0.8, "🌿": 0.3}
    sun.tags = ["celestial", "light", "driver"]
    register_icon(sun)
    
    # ... more icons
```

**Option 2: Resource files**

```gdscript
func _load_builtin_icons():
    var icon_files = [
        "res://Icons/celestial/sun.tres",
        "res://Icons/celestial/moon.tres",
        "res://Icons/flora/wheat.tres",
        # ...
    ]
    for path in icon_files:
        var icon = load(path) as Icon
        if icon:
            register_icon(icon)
```

**Option 3: JSON/Dictionary definition**

```gdscript
const ICON_DEFINITIONS = {
    "☀": {
        "display_name": "Sol",
        "self_energy": 0.5,
        "hamiltonian_couplings": {"🌙": 0.8, "🌿": 0.3},
        "driver": "cosine",
        "frequency": 0.05
    },
    # ...
}

func _load_from_definitions():
    for emoji in ICON_DEFINITIONS:
        var def = ICON_DEFINITIONS[emoji]
        var icon = Icon.new()
        icon.emoji = emoji
        icon.display_name = def.get("display_name", emoji)
        icon.self_energy = def.get("self_energy", 0.0)
        icon.hamiltonian_couplings = def.get("hamiltonian_couplings", {})
        # ... etc
        register_icon(icon)
```

---

## Deriving Icons from Markov Chain

Your forest Markov chain can bootstrap Icon definitions:

```gdscript
func derive_icons_from_markov(markov: Dictionary):
    for source_emoji in markov:
        var icon = Icon.new()
        icon.emoji = source_emoji
        
        var transitions = markov[source_emoji]
        
        for target_emoji in transitions:
            var prob = transitions[target_emoji]
            
            # Symmetric part → Hamiltonian coupling
            # (If A→B and B→A both exist, average them)
            var reverse_prob = 0.0
            if markov.has(target_emoji) and markov[target_emoji].has(source_emoji):
                reverse_prob = markov[target_emoji][source_emoji]
            
            var symmetric = (prob + reverse_prob) / 2.0
            var asymmetric = prob - symmetric
            
            if symmetric > 0.01:
                icon.hamiltonian_couplings[target_emoji] = symmetric
            
            # Asymmetric part → Lindblad transfer
            if asymmetric > 0.01:
                icon.lindblad_outgoing[target_emoji] = asymmetric * 0.5  # Scale factor
        
        register_icon(icon)
```

**Example with forest_emoji_simulation_v11:**

```
🐺 Wolf transitions: {🌳: 0.5, 💧: 0.3, 🌿: 0.2}

Derived Icon_🐺:
  hamiltonian_couplings: {🌳: 0.25, 💧: 0.15, 🌿: 0.1}
  lindblad_outgoing: {🌳: 0.125, 💧: 0.075, 🌿: 0.05}
```

This gives a starting point. Then tune Icons by hand for desired behavior.

---

## Icon Categories

### Celestial Icons
```
☀ Sun - Primary driver, day/night cycle
🌙 Moon - Secondary driver, lunar cycle
⭐ Star - Distant influence
🌍 Earth - Grounding, stability
```

### Elemental Icons
```
💧 Water - Flow, life sustainer
⛰ Mountain/Soil - Foundation, nutrients
💨 Wind - Dispersal, movement
🔥 Fire - Transformation, destruction
☔ Weather - Environmental fluctuation
```

### Flora Icons
```
🌱 Seedling - Potential, growth
🌿 Vegetation - Base producer
🌾 Wheat - Cultivated crop
🍄 Mushroom - Decomposer, moon-linked
🌳 Forest - Ecosystem anchor
🌲 Tree - Structure, shelter
🌼 Flower - Pollination node
```

### Fauna Icons
```
🐺 Wolf - Apex predator
🐇 Rabbit - Primary prey, reproducer
🦌 Deer - Large herbivore
🐭 Mouse - Small prey
🐦 Bird - Disperser, small predator
🦅 Eagle - Apex aerial predator
🐝 Bee - Pollinator
🐜 Bug - Decomposer, base prey
```

### Economic Icons
```
💰 Money - Exchange medium
📦 Goods - Tradeable resources
🏪 Market - Exchange node
🏭 Mill - Transformation
```

### Abstract Icons
```
💀 Death - Terminus
🍂 Organic Matter - Recycling node
🏡 Shelter - Protection
👥 Labor - Human input
```

---

## Blank Icons (Your Design Space)

Many emojis have no Icon attached. These are your canvas:

```gdscript
func get_icon(emoji: String) -> Icon:
    if icons.has(emoji):
        return icons[emoji]
    else:
        # Return a "blank" icon - no couplings, no transfers
        var blank = Icon.new()
        blank.emoji = emoji
        blank.display_name = "Unknown: " + emoji
        blank.self_energy = 0.0
        return blank
```

As you develop the game, you fill in Icons:
- New crops → new Flora Icons
- New creatures → new Fauna Icons  
- New mechanics → new Abstract Icons

The system scales because Icons are independent. Adding one doesn't break others.

---

## Tomato: The Chaos Icon

You mentioned tomatoes are "excessively complicated and invasive at a quantum/psychic level."

```gdscript
var tomato_icon = Icon.new()
tomato_icon.emoji = "🍅"
tomato_icon.display_name = "The Infiltrator"
tomato_icon.description = "Learns. Adapts. Entwines."

# Strong coupling to EVERYTHING nearby
tomato_icon.hamiltonian_couplings = {}  # Dynamically populated

# Psychic invasion: reads neighbor states and adds couplings
tomato_icon.tags = ["chaos", "adaptive", "psychic"]

# Special behavior flag
tomato_icon.is_adaptive = true
```

In QuantumBath:
```gdscript
func update_adaptive_icons():
    for emoji in emoji_list:
        var icon = IconRegistry.get_icon(emoji)
        if not icon.is_adaptive:
            continue
        
        # Tomato learns its neighbors
        var neighbors = get_nearby_emojis(emoji)
        for neighbor in neighbors:
            var strength = get_amplitude(neighbor).abs_sq() * 0.3
            icon.hamiltonian_couplings[neighbor] = strength
        
        mark_hamiltonian_dirty()
```

The tomato Icon evolves based on what's around it. It entangles with everything. Chaos.

---

## Summary

| Aspect | Role |
|--------|------|
| **Icon** | Definition of one emoji's quantum behavior |
| **Self-Energy** | Natural frequency / activity level |
| **H Couplings** | Coherent awareness between emojis |
| **L Transfers** | Directed energy/resource flow |
| **Decay** | Return to ground state |
| **Registry** | Singleton holding all Icons |
| **Composition** | Biomes sum Icon contributions |

Icons are your atoms of game design. Combine them to build worlds.

