# Biome Construction
## Building Worlds from Icons

---

## The Recipe

A biome is constructed from:

1. **Emoji Set** - Which emojis exist in this biome
2. **Weights** - Initial abundances of each emoji
3. **Icon Contributions** - Automatically pulled from IconRegistry
4. **Environmental Parameters** - Temperature, energy input, etc.

```gdscript
var forest_recipe = {
    "emojis": ["⛰", "☀", "💧", "🌳", "🌲", "🌿", "🐺", "🐇", "🦌", "🍂"],
    "weights": {
        "⛰": 0.2,   # Stable foundation
        "☀": 0.1,   # Driver
        "💧": 0.1,  
        "🌳": 0.15,
        "🌲": 0.1,
        "🌿": 0.15,
        "🐺": 0.02,  # Rare predator
        "🐇": 0.08,  # Common prey
        "🦌": 0.05,
        "🍂": 0.05
    },
    "parameters": {
        "temperature": 300.0,  # Kelvin
        "energy_input": 0.1,   # External driving strength
        "dissipation": 0.02    # Global decay rate
    }
}
```

---

## Biome Initialization

### Step 1: Create Bath

```gdscript
func initialize_biome(recipe: Dictionary):
    var emojis = recipe.emojis
    var weights = recipe.weights
    
    # Create bath with these emojis
    bath = QuantumBath.new()
    bath.initialize_with_emojis(emojis)
    bath.initialize_weighted(weights)
```

### Step 2: Gather Icons

```gdscript
func gather_icons():
    for emoji in bath.emoji_list:
        var icon = IconRegistry.get_icon(emoji)
        if icon:
            active_icons.append(icon)
        else:
            # Blank icon - no dynamics
            print("⚠️ No Icon for %s - will be inert" % emoji)
```

### Step 3: Build Operators

```gdscript
func build_operators():
    bath.build_hamiltonian_from_icons(active_icons)
    bath.build_lindblad_from_icons(active_icons)
```

### Step 4: Configure Environment

```gdscript
func configure_environment(params: Dictionary):
    bath.temperature = params.get("temperature", 300.0)
    bath.external_driving = params.get("energy_input", 0.0)
    bath.global_dissipation = params.get("dissipation", 0.0)
```

---

## Example: Forest Biome Construction

### The Markov-Derived Forest

Starting from your `forest_emoji_simulation_v11`:

```gdscript
# ForestEcosystem_Biome.gd
class_name ForestEcosystem_Biome
extends BiomeBase

const FOREST_MARKOV = {
    "⛰": {"🌳": 0.6, "☔": 0.4},
    "☀": {"🌳": 0.5, "🌱": 0.3, "🌿": 0.2},
    "☔": {"💧": 0.5, "☀": 0.3, "💨": 0.2},
    "🌳": {"⛰": 0.3, "🌲": 0.3, "🏡": 0.2, "🌿": 0.2},
    # ... rest of chain
    "🐺": {"🌳": 0.5, "💧": 0.3, "🌿": 0.2},
    "🐇": {"🏡": 0.5, "🍂": 0.3, "🐺": 0.2, "🦅": 0.1},
    # ... etc
}

func _ready():
    super._ready()
    
    # Derive Icons from Markov chain
    _derive_icons_from_markov(FOREST_MARKOV)
    
    # Build the biome
    var emojis = FOREST_MARKOV.keys()
    bath = QuantumBath.new()
    bath.initialize_with_emojis(emojis)
    
    # Start with Markov stationary distribution
    var stationary = _compute_stationary_distribution(FOREST_MARKOV)
    bath.initialize_weighted(stationary)
    
    # Build operators
    _gather_and_build_operators()
    
    print("🌲 Forest biome initialized with %d emojis" % emojis.size())

func _derive_icons_from_markov(markov: Dictionary):
    for source in markov:
        var icon = Icon.new()
        icon.emoji = source
        
        for target in markov[source]:
            var prob = markov[source][target]
            
            # Check for reverse transition
            var reverse = 0.0
            if markov.has(target) and markov[target].has(source):
                reverse = markov[target][source]
            
            # Symmetric → Hamiltonian
            var symmetric = (prob + reverse) / 2.0
            if symmetric > 0.05:
                icon.hamiltonian_couplings[target] = symmetric * 0.5
            
            # Asymmetric → Lindblad
            var asymmetric = prob - symmetric
            if asymmetric > 0.02:
                icon.lindblad_outgoing[target] = asymmetric * 0.3
        
        IconRegistry.register_icon(icon)
```

### The Hand-Tuned Forest

After Markov bootstrap, tune Icons by hand:

```gdscript
func _tune_forest_icons():
    # Wolf should be more predatory
    var wolf = IconRegistry.get_icon("🐺")
    wolf.lindblad_incoming = {"🐇": 0.15, "🦌": 0.12}  # Eats prey
    wolf.decay_rate = 0.03  # Dies without food
    wolf.self_energy = -0.05  # Slightly unstable
    
    # Rabbit should reproduce and fear wolf
    var rabbit = IconRegistry.get_icon("🐇")
    rabbit.lindblad_incoming = {"🌿": 0.1}  # Eats vegetation
    rabbit.hamiltonian_couplings["🐺"] = 0.6  # Strong awareness of predator
    rabbit.self_energy = 0.02  # Slightly positive (reproduces)
    
    # Vegetation should grow from sun
    var vegetation = IconRegistry.get_icon("🌿")
    vegetation.lindblad_incoming = {"☀": 0.2}  # Photosynthesis
    vegetation.decay_rate = 0.01  # Slow natural decay
    
    # Sun drives the system
    var sun = IconRegistry.get_icon("☀")
    sun.self_energy = 0.5
    sun.self_energy_driver = "cosine"
    sun.driver_frequency = 0.05  # Day/night cycle
```

---

## Example: BioticFlux Retrofit

### Current BioticFlux Emojis

From your existing implementation:
- ☀ Sun
- 🌙 Moon  
- 🌾 Wheat (mature)
- 💀 Labor/Death
- 🍄 Mushroom
- 🍂 Detritus

### Converting to Bath-First

```gdscript
# BioticFluxBiome.gd (retrofitted)
class_name BioticFluxBiome
extends BiomeBase

func _ready():
    super._ready()
    
    # Define Icons for BioticFlux
    _register_biotic_flux_icons()
    
    # Create bath
    var emojis = ["☀", "🌙", "🌾", "💀", "🍄", "🍂"]
    bath = QuantumBath.new()
    bath.initialize_with_emojis(emojis)
    
    # Initial weights
    bath.initialize_weighted({
        "☀": 0.3,   # Daytime start
        "🌙": 0.1,
        "🌾": 0.2,
        "💀": 0.15,
        "🍄": 0.15,
        "🍂": 0.1
    })
    
    # Build from Icons
    _gather_and_build_operators()

func _register_biotic_flux_icons():
    # Sun Icon - the driver
    var sun = Icon.new()
    sun.emoji = "☀"
    sun.display_name = "Sol"
    sun.self_energy = 1.0
    sun.self_energy_driver = "cosine"
    sun.driver_frequency = 0.05  # Matches original period
    sun.hamiltonian_couplings = {"🌙": 0.8}  # Antipodal coupling
    sun.lindblad_outgoing = {}  # Eternal, doesn't decay
    IconRegistry.register_icon(sun)
    
    # Moon Icon - night driver
    var moon = Icon.new()
    moon.emoji = "🌙"
    moon.display_name = "Luna"
    moon.self_energy = 0.5
    moon.self_energy_driver = "cosine"
    moon.driver_frequency = 0.05
    moon.driver_phase = PI  # Opposite phase to sun
    moon.hamiltonian_couplings = {"☀": 0.8, "🍄": 0.4}
    IconRegistry.register_icon(moon)
    
    # Wheat Icon
    var wheat = Icon.new()
    wheat.emoji = "🌾"
    wheat.display_name = "Golden Grain"
    wheat.self_energy = 0.1
    wheat.hamiltonian_couplings = {"☀": 0.5}  # Follows sun
    wheat.lindblad_incoming = {"☀": 0.15}  # Grows from sun
    wheat.decay_rate = 0.01
    wheat.decay_target = "💀"
    IconRegistry.register_icon(wheat)
    
    # Labor Icon
    var labor = Icon.new()
    labor.emoji = "💀"
    labor.display_name = "Labor"
    labor.self_energy = 0.0  # Neutral
    labor.hamiltonian_couplings = {"🌾": 0.3}
    IconRegistry.register_icon(labor)
    
    # Mushroom Icon - moon-linked
    var mushroom = Icon.new()
    mushroom.emoji = "🍄"
    mushroom.display_name = "Moonshroom"
    mushroom.self_energy = 0.05
    mushroom.hamiltonian_couplings = {"🌙": 0.6, "🍂": 0.3}
    mushroom.lindblad_incoming = {"🌙": 0.1, "🍂": 0.08}
    mushroom.decay_rate = 0.02
    IconRegistry.register_icon(mushroom)
    
    # Detritus Icon
    var detritus = Icon.new()
    detritus.emoji = "🍂"
    detritus.display_name = "Organic Matter"
    detritus.self_energy = 0.0
    detritus.lindblad_incoming = {}  # Receives from decay of others
    IconRegistry.register_icon(detritus)
```

### Verifying Behavior Matches

The retrofitted BioticFlux should exhibit:
1. Day/night oscillation (sun/moon self-energy drivers)
2. Wheat grows during day (sun → wheat Lindblad)
3. Mushroom grows at night (moon → mushroom Lindblad)
4. Wheat follows sun position (H coupling → Bloch rotation)
5. Death/decay returns to detritus

Test by comparing visualization to original.

---

## Procedural Biome Generation

### The Vision

Drop a handful of emojis → biome self-constructs:

```gdscript
func create_procedural_biome(emojis: Array[String]) -> BiomeBase:
    var biome = BiomeBase.new()
    
    # Initialize bath with given emojis
    biome.bath = QuantumBath.new()
    biome.bath.initialize_with_emojis(emojis)
    biome.bath.initialize_uniform()  # Equal weights
    
    # Gather whatever Icons exist for these emojis
    for emoji in emojis:
        var icon = IconRegistry.get_icon(emoji)
        if icon:
            biome.active_icons.append(icon)
    
    # Build operators from available Icons
    biome.bath.build_hamiltonian_from_icons(biome.active_icons)
    biome.bath.build_lindblad_from_icons(biome.active_icons)
    
    return biome
```

### Example: Random Ecosystem

```gdscript
# Player throws random emojis into a pot
var my_biome = create_procedural_biome(["🐍", "🐸", "🪲", "🌴", "💧", "☀"])

# If Icons exist for these, behavior emerges:
# - Sun drives palm growth
# - Beetle eats detritus
# - Frog eats beetle
# - Snake eats frog
# - Water sustains all

# If no Icons, emojis are inert (no dynamics)
```

### Icon Completeness

The more Icons you define, the richer procedural biomes become:

```
Phase 1: Core 20 Icons (celestial, basic flora/fauna)
Phase 2: Extended 50 Icons (more creatures, weather, economy)
Phase 3: Full 200+ Icons (complete emoji ecology)
```

Each new Icon adds to the design space without breaking existing biomes.

---

## Biome Composition

### Multi-Biome Worlds

Biomes can share emojis but have different baths:

```gdscript
# Farm biome (player-controlled)
farm_biome.bath.emojis = ["☀", "🌾", "💀", "💧", "⛰"]

# Forest biome (wild)
forest_biome.bath.emojis = ["☀", "🌳", "🐺", "🐇", "💧", "⛰"]

# Shared emojis (☀, 💧, ⛰) could couple biomes
```

### Biome Coupling (Future)

```gdscript
func couple_biomes(biome_a: BiomeBase, biome_b: BiomeBase, shared_emojis: Array):
    # Create coupling Lindblad terms
    for emoji in shared_emojis:
        var idx_a = biome_a.bath.emoji_to_index.get(emoji, -1)
        var idx_b = biome_b.bath.emoji_to_index.get(emoji, -1)
        
        if idx_a >= 0 and idx_b >= 0:
            # Add inter-bath coupling
            var coupling = InterBathCoupling.new()
            coupling.bath_a = biome_a.bath
            coupling.bath_b = biome_b.bath
            coupling.emoji = emoji
            coupling.rate = 0.05
            
            inter_bath_couplings.append(coupling)
```

Water flows from forest to farm. Sun affects both. Ecosystems interact.

---

## Environmental Parameters

### Temperature

Affects dissipation rates:

```gdscript
func apply_thermal_dissipation(dt: float):
    var T = bath.temperature
    var kT = T / 300.0  # Normalize to room temperature
    
    for i in range(bath.amplitudes.size()):
        # Higher temperature → faster decay toward equilibrium
        var decay = global_dissipation * kT * dt
        bath.amplitudes[i] = bath.amplitudes[i].scale(1.0 - decay)
    
    bath.normalize()
```

### Energy Input

External driving (like sun, but biome-wide):

```gdscript
func apply_energy_input(dt: float):
    # Pump amplitude into "driver" emojis
    for emoji in driver_emojis:
        var idx = bath.emoji_to_index.get(emoji, -1)
        if idx >= 0:
            var pump = external_driving * dt
            bath.amplitudes[idx] = bath.amplitudes[idx].add(Complex.new(pump, 0))
    
    bath.normalize()
```

### Seasonal Modulation

```gdscript
var season_time: float = 0.0
var season_period: float = 1000.0  # Long cycle

func get_seasonal_modifier() -> float:
    return 0.5 + 0.5 * cos(season_time / season_period * TAU)

func _process(delta):
    season_time += delta
    
    # Modulate growth rates by season
    var season = get_seasonal_modifier()
    for icon in active_icons:
        icon.current_lindblad_multiplier = season
```

---

## Biome Lifecycle

### Creation

```gdscript
var biome = ForestEcosystem_Biome.new()
biome.name = "Darkwood Forest"
farm.add_child(biome)
grid.register_biome("Forest", biome)
```

### Assignment

```gdscript
# Assign plot region to biome
for x in range(5, 10):
    for y in range(0, 5):
        grid.assign_plot_to_biome(Vector2i(x, y), "Forest")
```

### Evolution

```gdscript
# Automatic in _process
func _process(delta):
    bath.evolve(delta)
    update_projections()
    emit_signal("biome_evolved")
```

### Destruction

```gdscript
func destroy_biome():
    # Remove all projections
    for pos in active_projections.keys():
        remove_projection(pos)
    
    # Clear bath
    bath.queue_free()
    
    # Unregister
    grid.unregister_biome(biome_name)
```

---

## Biome Visualization

### The Oval/Skating Rink

Each biome renders as an oval containing its projections:

```gdscript
# In BiomeVisualizer
func draw_biome_region():
    # Draw oval boundary
    draw_arc(center, radius, 0, TAU, 64, biome.visual_color, 2.0)
    
    # Draw biome label
    draw_string(font, center - Vector2(40, radius + 20), biome.visual_label)
    
    # Projection bubbles drawn by QuantumNodes
```

### Bath State Visualization (Optional)

Show the full bath as a background:

```gdscript
func draw_bath_state():
    var dist = bath.get_probability_distribution()
    
    # Draw as pie chart or bar graph in corner
    var angle = 0.0
    for emoji in dist:
        var prob = dist[emoji]
        var arc_size = prob * TAU
        draw_arc(pie_center, pie_radius, angle, angle + arc_size, 16, emoji_color[emoji])
        angle += arc_size
```

### Energy Flow Visualization

Show Lindblad transfers as arrows:

```gdscript
func draw_energy_flows():
    for term in bath.lindblad_terms:
        var source_pos = get_emoji_position(term.source_emoji)
        var target_pos = get_emoji_position(term.target_emoji)
        var strength = term.rate * bath.get_probability(term.source_emoji)
        
        draw_arrow(source_pos, target_pos, strength * 2.0, flow_color)
```

---

## Summary

| Step | Action |
|------|--------|
| 1. Define Recipe | List emojis, weights, parameters |
| 2. Create Bath | Initialize with emoji set |
| 3. Gather Icons | Pull from IconRegistry |
| 4. Build Operators | Construct H and L from Icons |
| 5. Configure Environment | Set temperature, driving, etc. |
| 6. Evolve | Bath evolves each frame |
| 7. Project | Plots project from bath as needed |

**Biomes are compositions of Icons. Drop in emojis, behavior emerges.**

