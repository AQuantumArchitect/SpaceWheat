# Plot Lifecycle - Plant → Grow → Measure → Harvest

## Overview Flow

```
Empty Plot → Plant → Growing → Measure → Harvest → Empty Plot
     ↑                                                    ↓
     └────────────────────────────────────────────────────┘
                    (replant cycle)
```

---

## Stage 1: Empty Plot

**Initial State:**
```gdscript
plot.is_planted = false
plot.quantum_state = null
plot.has_been_measured = false
plot.persistent_gates = [...]  # Survives from previous cycle
```

**Quantum Visualization:**
- Plot may have quantum_state for visualization (initialized with random phi)
- Not considered "planted" until player explicitly plants

---

## Stage 2: Planting

**Player Action:** Select Grower tool (1), press Q → Plant submenu, select crop type

**Method Call:**
```gdscript
FarmGrid.plant(position: Vector2i, plant_type: String) -> bool
```

**Implementation:**
```gdtxt
func plant(position: Vector2i, plant_type: String, quantum_state: Resource = null) -> bool:
    var plot = get_plot(position)
    if plot == null or plot.is_planted:
        return false

    # Set plot type based on plant_type
    var plot_type_map = {
        "wheat": FarmPlot.PlotType.WHEAT,
        "tomato": FarmPlot.PlotType.TOMATO,
        "mushroom": FarmPlot.PlotType.MUSHROOM
    }
    plot.plot_type = plot_type_map[plant_type]

    # Get biome for this plot's position
    var plot_biome = get_biome_for_plot(position)

    # Option 1: Direct quantum state injection (deprecated)
    if quantum_state != null:
        plot.plant(quantum_state)

    # Option 2: Biome resource injection (NEW SYSTEM)
    else:
        # Default inputs: 0.08 labor + 0.22 wheat
        plot.plant(0.08, 0.22, plot_biome)

    # Emit signals
    plot_planted.emit(position)
    plot_changed.emit(position, "planted", {"plant_type": plant_type})
    visualization_changed.emit()

    # AUTO-ENTANGLE from persistent gates
    _auto_entangle_from_infrastructure(position)
    _auto_apply_persistent_gates(position)

    return true
```

**What Happens in plot.plant():**
```gdtxt
# In BasePlot
func plant(quantum_state_or_labor = null, wheat_cost: float = 0.0, biome = null) -> void:
    # If biome provided, let it create quantum state
    if biome != null:
        var emojis = get_plot_emojis()
        quantum_state = DualEmojiQubit.new(emojis["north"], emojis["south"], PI/2)
        quantum_state.energy = (wheat_cost * 100.0) + (quantum_state_or_labor * 50.0)

    # Mark as planted
    is_planted = true
```

**Key Steps:**
1. Player provides resources (labor + wheat)
2. Biome creates DualEmojiQubit with plot-specific emojis
3. Initial energy calculated from resources
4. Persistent gates automatically re-entangle new qubit
5. Visualization updates

---

## Stage 3: Growing

**Automatic Process:** Runs every frame in `FarmGrid._process(delta)`

**Flow:**
```gdtxt
func _process(delta):
    # Build icon network (Hamiltonians from active icons)
    var icon_network = _build_icon_network()

    # Grow all planted plots
    for position in plots.keys():
        var plot = plots[position]
        if plot.is_planted:
            var plot_biome = get_biome_for_plot(position)
            plot.grow(delta, plot_biome, faction_territory_manager, icon_network, conspiracy_network)
```

**What Happens in plot.grow():**
```gdtxt
# In FarmPlot
func grow(delta, biome, territory_manager, icon_network, conspiracy_network) -> float:
    if not is_planted or not quantum_state:
        return 0.0

    # Let biome handle quantum evolution
    if biome and biome.has_method("_evolve_quantum_substrate"):
        biome._evolve_quantum_substrate(delta)

    # Apply phase constraints (e.g., Imperium field lock)
    if phase_constraint:
        phase_constraint.apply(quantum_state)

    return 0.0
```

**Biome Evolution (BioticFlux Example):**
```gdtxt
# In BioticFluxBiome
func _evolve_quantum_substrate(dt: float):
    # LAYER 1: Hamiltonian (rotation)
    _apply_celestial_oscillation(dt)  # Sun/moon orbit
    _apply_hamiltonian_evolution(dt)   # Icon Hamiltonians
    _apply_spring_attraction(dt)       # Spring forces toward sun

    # LAYER 2: Lindblad (energy)
    _apply_energy_transfer(dt)         # Energy growth from sun alignment

    # LAYER 3: Dissipation
    for position in quantum_states.keys():
        var qubit = quantum_states[position]
        apply_dissipation(qubit, position, dt)  # T1 + T2 decoherence
```

**What Changes:**
- `theta` - Rotates based on Hamiltonian + spring forces
- `phi` - Rotates based on coupling
- `radius` - Grows based on energy transfer
- `berry_phase` - Accumulates from evolution

**Visual Effect:** Bubble size grows, position shifts on skating rink

---

## Stage 4: Measurement

**Player Action:** Grower tool (1), press R (Measure + Harvest) OR Gates tool (5), press R (Measure)

**Two Modes:**

### Auto-Measure (Forgiving)
```gdtxt
# Happens automatically during harvest if not already measured
func harvest() -> Dictionary:
    if not has_been_measured and quantum_state:
        measure()
```

### Explicit Measure
```gdtxt
func measure(icon_network = null) -> String:
    if not quantum_state:
        return ""

    # Call DualEmojiQubit.measure() - Born rule collapse
    var outcome = quantum_state.measure()

    # Mark as measured (locks theta)
    has_been_measured = true
    theta_frozen = true

    return outcome
```

**Born Rule Collapse (in DualEmojiQubit):**
```gdtxt
func measure() -> String:
    var prob_north = cos(theta / 2.0)^2
    if randf() < prob_north:
        theta = 0.0
        return north_emoji  # e.g., "🌾"
    else:
        theta = PI
        return south_emoji  # e.g., "👥"
```

**Effect:**
- Qubit collapses to one pole
- `theta_frozen = true` - stops Hamiltonian evolution
- Outcome determines harvest type

---

## Stage 5: Harvesting

**Player Action:** Grower tool (1), press R (Measure + Harvest)

**Method Call:**
```gdtxt
func harvest() -> Dictionary:
    if not is_planted:
        return {"success": false, "yield": 0, "energy": 0.0}

    # Auto-measure if needed
    if not has_been_measured and quantum_state:
        measure()

    # Get outcome emoji
    var outcome = quantum_state.get_semantic_state()

    # Get raw quantum energy
    var energy = quantum_state.energy
    # Add Berry phase bonus (entanglement memory)
    energy += berry_phase * 0.1

    # Clear the plot
    is_planted = false
    quantum_state = null
    has_been_measured = false
    theta_frozen = false
    replant_cycles += 1  # Increment memory counter

    return {
        "success": true,
        "outcome": outcome,  # "🌾" or "👥"
        "energy": energy,    # Used to calculate credits
        "yield": int(energy * 10)  # Legacy
    }
```

**Return Dictionary:**
```gdscript
{
    "success": true,
    "outcome": "🌾",     # Measurement result
    "energy": 0.85,      # Raw quantum energy
    "yield": 8           # Credits = energy * 10
}
```

**What Persists:**
- `persistent_gates` - Gate infrastructure
- `replant_cycles` - Memory counter
- `berry_phase` - Experience accumulator
- Grid position

**What Clears:**
- `quantum_state` - Removed
- `is_planted` - Set to false
- `has_been_measured` - Reset
- `entangled_plots` - Cleared
- `theta_frozen` - Reset

---

## Special Case: Persistent Gates

**Scenario:** Two plots have a Bell gate connecting them

**Before Harvest:**
```gdscript
plot_a.persistent_gates = [{"type": "bell_phi_plus", "active": true, "linked_plots": [pos_b]}]
plot_b.persistent_gates = [{"type": "bell_phi_plus", "active": true, "linked_plots": [pos_a]}]
```

**Harvest Both:**
```gdscript
grid.harvest(pos_a)  # Clears quantum_state, keeps persistent_gates
grid.harvest(pos_b)  # Clears quantum_state, keeps persistent_gates
```

**Replant:**
```gdscript
grid.plant(pos_a, "wheat")
# → Creates new qubit
# → _auto_apply_persistent_gates() called
# → Checks plot_a.has_active_gate("bell_phi_plus")
# → Re-entangles with pos_b (if also planted)

grid.plant(pos_b, "wheat")
# → Creates new qubit
# → _auto_apply_persistent_gates() called
# → Now both plots have qubits
# → Creates Bell pair between them!
```

**Result:** Infrastructure is permanent, qubits are temporary.

---

## Lifecycle Signals

**Emitted by FarmGrid:**

```gdscript
signal plot_planted(position: Vector2i)
signal plot_harvested(position: Vector2i, yield_data: Dictionary)
signal plot_changed(position: Vector2i, change_type: String, details: Dictionary)
signal visualization_changed()
```

**Usage:**
```gdscript
# In Farm.gd
grid.plot_planted.connect(_on_plot_planted)
grid.plot_harvested.connect(_on_plot_harvested)

func _on_plot_planted(pos: Vector2i):
    print("Planted at %s" % pos)

func _on_plot_harvested(pos: Vector2i, yield_data: Dictionary):
    var credits = yield_data["energy"] * 10
    economy.add_credits(credits)
```

---

## Replant Optimization

**Concept:** Reusing the same plot provides Berry phase bonus

**Math:**
```
Harvest 1: energy = 0.8, berry_phase = 0.0  →  0.80 credits
Harvest 2: energy = 0.8, berry_phase = 0.1  →  0.81 credits (0.8 + 0.1*0.1)
Harvest 3: energy = 0.8, berry_phase = 0.2  →  0.82 credits (0.8 + 0.2*0.1)
```

**Strategy:** Players learn to replant the same plots for cumulative bonuses.

---

## Multi-Biome Lifecycle

**With Biome Assignment:**
```gdscript
# Assign plot to Forest biome
grid.assign_plot_to_biome(Vector2i(5, 0), "Forest")

# Plant wheat on that plot
grid.plant(Vector2i(5, 0), "wheat")
# → Calls ForestEcosystem_Biome.plant()
# → ForestEcosystem quantum evolution applies (not BioticFlux!)
```

**Effect:** Different biomes = different evolution rules
- BioticFlux: Sun/moon cycle, day/night growth
- Forest: Ecosystem dynamics, predator-prey
- Market: Sentiment oscillation, trading pressure

**Key Insight:** Same plot type (wheat), different physics based on biome assignment.
