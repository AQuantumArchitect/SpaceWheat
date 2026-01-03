# Biome Integration - How Plots Connect to Biomes

## Overview

**Core Concept:** Plots store quantum state, biomes evolve quantum state.

```
Plot (storage) ← Biome (evolution) → Quantum State (data)
```

---

## Multi-Biome Architecture

### FarmGrid Biome Registry

```gdtxt
# In FarmGrid.gd
class FarmGrid:
    # OLD (legacy): Single biome for all plots
    var biome = null

    # NEW (Phase 2): Multi-biome support
    var biomes: Dictionary = {}  # String → BiomeBase
    var plot_biome_assignments: Dictionary = {}  # Vector2i → String
```

**Registration Flow:**
```gdtxt
# In Farm._ready()
func _ready():
    # Create biomes
    var biotic_flux = BioticFluxBiome.new()
    var forest = ForestEcosystem_Biome.new()
    var market = MarketBiome.new()

    # Register with FarmGrid
    grid.register_biome("BioticFlux", biotic_flux)
    grid.register_biome("Forest", forest)
    grid.register_biome("Market", market)

    # Assign plots to biomes
    for x in range(5):
        grid.assign_plot_to_biome(Vector2i(x, 0), "BioticFlux")  # Row 0
    for x in range(5):
        grid.assign_plot_to_biome(Vector2i(x, 1), "Forest")       # Row 1
    for x in range(5):
        grid.assign_plot_to_biome(Vector2i(x, 2), "Market")       # Row 2
```

---

## Biome Assignment

### Method: assign_plot_to_biome()

```gdtxt
func assign_plot_to_biome(position: Vector2i, biome_name: String) -> void:
    if not is_valid_position(position):
        push_error("Invalid position")
        return

    if not biomes.has(biome_name):
        push_error("Unregistered biome: %s" % biome_name)
        return

    plot_biome_assignments[position] = biome_name
```

**Result:** Plot at `position` will use quantum evolution from `biome_name`

---

## Biome Routing

### Method: get_biome_for_plot()

```gdtxt
func get_biome_for_plot(position: Vector2i):
    # Check explicit assignment
    if plot_biome_assignments.has(position):
        var biome_name = plot_biome_assignments[position]
        if biomes.has(biome_name):
            return biomes[biome_name]

    # Fallback to BioticFlux (default)
    if biomes.has("BioticFlux"):
        return biomes["BioticFlux"]

    # Final fallback to legacy biome variable
    return biome
```

**Usage in plot.grow():**
```gdtxt
func grow(delta, biome, ...):
    var plot_biome = grid.get_biome_for_plot(position)
    if plot_biome:
        plot_biome._evolve_quantum_substrate(delta)
```

---

## Biome Responsibilities

### What Biomes Must Provide

1. **Quantum State Creation**
```gdtxt
# When plot.plant() is called with biome reference
func create_quantum_state(position: Vector2i, north: String, south: String, theta: float):
    var qubit = DualEmojiQubit.new(north, south, theta)
    quantum_states[position] = qubit
    return qubit
```

2. **Quantum Evolution**
```gdtxt
func _update_quantum_substrate(dt: float):
    # Evolve all qubits in this biome
    for position in quantum_states.keys():
        var qubit = quantum_states[position]
        _evolve_single_qubit(qubit, position, dt)
```

3. **Dissipation Application**
```gdtxt
func apply_dissipation(qubit: DualEmojiQubit, position: Vector2i, dt: float):
    var T1_rate = get_T1_rate(position)  # Biome-specific
    var T2_rate = get_T2_rate(position)  # Biome-specific

    qubit.apply_amplitude_damping(T1_rate * dt)
    qubit.apply_phase_damping(T2_rate * dt)
```

4. **Visual Configuration**
```gdtxt
func get_visual_config() -> Dictionary:
    return {
        "color": visual_color,
        "label": visual_label,
        "center_offset": visual_center_offset,
        "oval_width": visual_oval_width,
        "oval_height": visual_oval_height,
        "enabled": visual_enabled
    }
```

---

## Example: BioticFlux Biome

### Three-Layer Evolution

```gdtxt
# In BioticFluxBiome._evolve_quantum_substrate()
func _evolve_quantum_substrate(dt: float):
    # LAYER 1: Hamiltonian (unitary rotations)
    _apply_celestial_oscillation(dt)      # Sun/moon orbit
    _apply_hamiltonian_evolution(dt)      # Icon Hamiltonians
    _apply_spring_attraction(dt)          # Spring forces

    # LAYER 2: Lindblad (open system dynamics)
    _apply_energy_transfer(dt)            # Energy growth
    _apply_energy_taps(dt)                # Energy drain

    # LAYER 3: Per-qubit effects
    for position in quantum_states.keys():
        var qubit = quantum_states[position]

        # Temperature modulation
        temperature_grid[position] = base_temperature

        # Dissipation (T1 + T2)
        apply_dissipation(qubit, position, dt)

        # Icon coherence restoration
        if biotic_flux_icon:
            biotic_flux_icon._apply_coherence_restoration(qubit, dt)

        # Phase constraints (Imperium lock)
        _apply_phase_constraint(qubit, position)

        qubit_evolved.emit(position)
```

### Energy Transfer Mechanism

```gdtxt
func _apply_energy_transfer(dt: float):
    for position in quantum_states.keys():
        var qubit = quantum_states[position]

        # 3D alignment between crop and sun
        var qubit_vector = _bloch_vector(qubit.theta, qubit.phi)
        var sun_vector = _bloch_vector(sun_qubit.theta, sun_qubit.phi)
        var alignment = cos(_bloch_angle_between(qubit_vector, sun_vector))^2

        # Brightness from sun position
        var sun_brightness = cos(sun_qubit.theta / 2.0)^2

        # Energy rate
        var energy_rate = base_energy_rate * alignment * sun_brightness * wheat_influence

        # Exponential growth
        qubit.grow_energy(energy_rate, dt)
        qubit.radius = qubit.energy
```

**Key Physics:**
- **Alignment** - How well crop points toward sun
- **Brightness** - How bright sun currently is (theta-dependent)
- **Influence** - Crop-specific growth multiplier

---

## Example: Forest Biome (Current - Problematic)

### Organism-Based Evolution

```gdtxt
func _update_quantum_substrate(dt: float):
    _update_weather()

    for pos in patches.keys():
        _update_patch(pos, dt)

func _update_patch(position: Vector2i, delta: float):
    var patch = patches[position]

    # Update organisms (PROBLEM: spawns instances)
    _update_quantum_organisms(patch, delta)

func _update_quantum_organisms(patch, delta):
    var organisms_dict = patch.get_meta("organisms")

    for org in organisms_dict.values():
        org.update(delta, nearby_organisms, available_food, predators_nearby)

        # Reproduction creates new instances (BAD!)
        if org.offspring_created > 0:
            var baby = QuantumOrganism.new(org.icon, org.type)
            organisms_dict[unique_key] = baby
```

**Problem:** This spawns individual organisms instead of using conceptual qubits.

---

## Example: Market Biome

### Sentiment Oscillation

```gdtxt
func _update_quantum_substrate(dt: float):
    # Sentiment qubit oscillates
    sentiment_qubit.theta += sentiment_oscillation_rate * dt
    if sentiment_qubit.theta > TAU:
        sentiment_qubit.theta = 0.0

    # Liquidity qubit cycles
    liquidity_qubit.phi += liquidity_rotation_rate * dt

    # Plots assigned to Market biome get influenced by sentiment
    for position in quantum_states.keys():
        var plot_qubit = quantum_states[position]
        _apply_sentiment_coupling(plot_qubit, sentiment_qubit, dt)
```

---

## Icon Scoping (Advanced)

### Restricting Icons to Specific Biomes

```gdtxt
# In FarmGrid
var icon_scopes: Dictionary = {}  # Icon → Array[String] biome names

func add_scoped_icon(icon, allowed_biomes: Array[String]):
    active_icons.append(icon)
    icon_scopes[icon] = allowed_biomes

# In _apply_icon_effects()
for position in plots.keys():
    var plot = plots[position]
    var plot_biome_name = plot_biome_assignments.get(position, "BioticFlux")

    for icon in active_icons:
        # Check scope
        if icon_scopes.has(icon):
            var allowed = icon_scopes[icon]
            if not allowed.has(plot_biome_name):
                continue  # Skip this icon for this plot

        # Apply Hamiltonian
        icon.apply_hamiltonian_evolution(plot.quantum_state, delta)
```

**Example Usage:**
```gdtxt
# Forest icon only affects Forest plots
var forest_icon = ForestEcosystemIcon.new()
grid.add_scoped_icon(forest_icon, ["Forest"])

# Result:
# - Plots in BioticFlux: NOT affected by forest_icon
# - Plots in Forest: Affected by forest_icon
```

---

## Biome Signals

### Standard Signals (in BiomeBase)

```gdtxt
signal qubit_created(position: Vector2i, qubit: Resource)
signal qubit_measured(position: Vector2i, outcome: String)
signal qubit_evolved(position: Vector2i)
signal bell_gate_created(positions: Array)
```

**Usage:**
```gdtxt
# In BioticFluxBiome
func create_quantum_state(position, north, south, theta):
    var qubit = DualEmojiQubit.new(north, south, theta)
    quantum_states[position] = qubit
    qubit_created.emit(position, qubit)  # Notify listeners
    return qubit
```

**Listeners:**
```gdtxt
# In QuantumForceGraph
biome.qubit_created.connect(_on_qubit_created)

func _on_qubit_created(position, qubit):
    # Create visual node for this qubit
    var node = QuantumNode.new()
    node.qubit = qubit
    quantum_nodes.append(node)
```

---

## Multi-Biome Quantum Evolution

### Execution Order

```gdtxt
# In FarmGrid._process(delta)
func _process(delta):
    # STEP 1: Apply Icon effects (scoped by biome)
    _apply_icon_effects(delta)

    # STEP 2: Grow all planted plots (routes to correct biome)
    for position in plots.keys():
        var plot = plots[position]
        if plot.is_planted:
            var plot_biome = get_biome_for_plot(position)
            plot.grow(delta, plot_biome, ...)

    # STEP 3: Process buildings (mills, markets)
    for position in plots.keys():
        var plot = plots[position]
        if plot.plot_type == MILL:
            plot.process_mill(delta, self, economy)
```

**Key Points:**
1. Icons applied first (Hamiltonian layer)
2. Each plot routed to its assigned biome
3. Buildings process last (economy layer)

---

## Creating a Custom Biome

### Minimum Implementation

```gdtxt
# MyCustomBiome.gd
class_name MyCustomBiome
extends "res://Core/Environment/BiomeBase.gd"

func _ready():
    super._ready()

    # Set visual properties
    visual_color = Color(1.0, 0.5, 0.0, 0.3)  # Orange
    visual_label = "🔥 Fire Biome"
    visual_center_offset = Vector2(0.0, 0.0)
    visual_oval_width = 400.0
    visual_oval_height = 250.0

func get_biome_type() -> String:
    return "Fire"

func _update_quantum_substrate(dt: float):
    # Custom evolution logic
    for position in quantum_states.keys():
        var qubit = quantum_states[position]

        # Example: Rotate all qubits clockwise
        qubit.phi += 0.5 * dt

        # Example: Energy decays in fire
        qubit.energy *= 0.99

        qubit_evolved.emit(position)

func apply_dissipation(qubit, position, dt):
    # Higher T1/T2 rates (harsh environment)
    var T1_rate = 0.05  # 10x higher than normal
    var T2_rate = 0.10
    qubit.apply_amplitude_damping(T1_rate * dt)
    qubit.apply_phase_damping(T2_rate * dt)
```

### Registering and Using

```gdtxt
# In Farm._ready()
var fire_biome = MyCustomBiome.new()
grid.register_biome("Fire", fire_biome)

# Assign row 3 to fire biome
for x in range(5):
    grid.assign_plot_to_biome(Vector2i(x, 3), "Fire")

# Plant wheat in fire biome
grid.plant(Vector2i(0, 3), "wheat")
# → Creates qubit in fire_biome.quantum_states
# → Evolves with fire_biome._update_quantum_substrate()
# → Higher decoherence, phi rotation effect
```

---

## Biome Overlap (Advanced)

### Dual-Biome Assignments

**Currently:** Each plot assigned to ONE biome

**Future Possibility:** Plots in overlap zones receive evolution from MULTIPLE biomes

```gdtxt
# Proposed: plot_biome_assignments becomes Array
var plot_biome_assignments: Dictionary = {}  # Vector2i → Array[String]

# Example
grid.assign_plot_to_biomes(Vector2i(2, 1), ["BioticFlux", "Forest"])

# Evolution
for biome_name in plot_biome_assignments[position]:
    var biome = biomes[biome_name]
    biome._evolve_quantum_substrate(delta)
```

**Effect:** Additive evolution from multiple physics models

---

## Key Takeaways

1. **Separation of Concerns**
   - Plots: Storage + lifecycle
   - Biomes: Quantum evolution
   - Grid: Orchestration

2. **Multi-Biome Routing**
   - Each plot → one biome (currently)
   - `get_biome_for_plot()` handles routing
   - Different physics per biome assignment

3. **Icon Scoping**
   - Icons can be restricted to specific biomes
   - Allows biome-specific Hamiltonians

4. **Custom Biomes**
   - Extend BiomeBase
   - Implement `_update_quantum_substrate()`
   - Register with FarmGrid
   - Assign plots

5. **Signals**
   - Biomes emit events
   - Visualization listens
   - Decoupled architecture
