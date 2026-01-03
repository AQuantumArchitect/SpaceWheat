# Quick Reference - Farm Plot Mechanics

## Plot Classes

| Class | Extends | Purpose | Player Interactive |
|-------|---------|---------|-------------------|
| `BasePlot` | Resource | Foundation with quantum state | No (abstract) |
| `FarmPlot` | BasePlot | Player-controlled plots | Yes |
| `BiomePlot` | BasePlot | Biome-managed entities | No |

---

## Plot Types (FarmPlot.PlotType)

| Type | North Emoji | South Emoji | Description |
|------|-------------|-------------|-------------|
| WHEAT | 🌾 | 👥 | Standard crop (labor/wheat) |
| TOMATO | 🍅 | 🍝 | Conspiracy network crop |
| MUSHROOM | 🍄 | 🍂 | Moon-influenced crop |
| MILL | 🏭 | 💨 | Grinds wheat into flour |
| MARKET | 🏪 | 💰 | Sells for credits |
| KITCHEN | 🍳 | 🍞 | Bakes flour into bread |
| ENERGY_TAP | 🚰 | ⚡ | Drains energy from emojis |

---

## Tools & Actions (Q/E/R)

### Tool 1: Grower 🌱
- **Q**: Plant (submenu: wheat/mushroom/tomato)
- **E**: Entangle Batch (Bell φ+)
- **R**: Measure + Harvest

### Tool 2: Quantum ⚛️
- **Q**: Cluster (2=Bell, 3+=Cluster)
- **E**: Measure Trigger
- **R**: Remove Gates

### Tool 3: Industry 🏭
- **Q**: Build (submenu: mill/market/kitchen)
- **E**: Build Market
- **R**: Build Kitchen

### Tool 4: Energy ⚡
- **Q**: Energy Tap (submenu: wheat/mushroom/tomato)
- **E**: Inject Energy
- **R**: Drain Energy

### Tool 5: Gates 🔄
- **Q**: 1-Qubit Gates (submenu: Pauli-X/H/Z)
- **E**: 2-Qubit Gates (submenu: CNOT/CZ/SWAP)
- **R**: Measure Batch

### Tool 6: Future 6️⃣
- Reserved

---

## Core Methods Reference

### FarmGrid

```gdscript
# Plot Management
func get_plot(position: Vector2i) -> FarmPlot
func is_valid_position(position: Vector2i) -> bool

# Planting
func plant(position: Vector2i, plant_type: String) -> bool
func plant_wheat(position: Vector2i) -> bool  # Deprecated
func plant_tomato(position: Vector2i) -> bool  # Deprecated
func plant_mushroom(position: Vector2i) -> bool  # Deprecated
func plant_energy_tap(position: Vector2i, target_emoji: String) -> bool

# Harvesting
func harvest(position: Vector2i) -> Dictionary

# Entanglement
func create_entanglement(pos_a: Vector2i, pos_b: Vector2i, bell_type: String) -> bool
func create_entangled_cluster(positions: Array[Vector2i])
func remove_entanglement(pos_a: Vector2i, pos_b: Vector2i)
func are_plots_entangled(pos_a: Vector2i, pos_b: Vector2i) -> bool

# Biome Management
func register_biome(biome_name: String, biome_instance)
func assign_plot_to_biome(position: Vector2i, biome_name: String)
func get_biome_for_plot(position: Vector2i) -> BiomeBase
```

### BasePlot

```gdscript
# Lifecycle
func plant(quantum_state_or_labor, wheat_cost, biome)
func measure(icon_network) -> String
func harvest() -> Dictionary
func reset()

# State Queries
func get_dominant_emoji() -> String
func get_plot_emojis() -> Dictionary  # {"north": "🌾", "south": "👥"}

# Persistent Gates
func add_persistent_gate(gate_type: String, linked_plots: Array[Vector2i])
func clear_persistent_gates()
func has_active_gate(gate_type: String) -> bool
func get_active_gates() -> Array[Dictionary]

# Entanglement (Legacy)
func remove_entanglement(partner_id: String)
```

### FarmPlot

```gdscript
# Evolution
func grow(delta, biome, territory_manager, icon_network, conspiracy_network) -> float

# Entanglement
func add_entanglement(other_plot_id: String, strength: float)
func clear_entanglement()
func get_entanglement_count() -> int
```

### DualEmojiQubit

```gdscript
# State Access
func get_north_probability() -> float  # cos²(theta/2)
func get_south_probability() -> float  # sin²(theta/2)
func get_semantic_state() -> String

# Quantum Gates
func apply_pauli_x()  # Flip theta
func apply_pauli_z()  # Phase flip
func apply_hadamard()  # Superposition
func measure() -> String  # Born rule collapse

# Evolution
func grow_energy(strength: float, dt: float)
func apply_amplitude_damping(rate: float)  # T1 decoherence
func apply_phase_damping(rate: float)  # T2 decoherence
func apply_rotation(axis: Vector3, angle: float)

# Topology Graph
func add_graph_edge(relationship_emoji: String, target_emoji: String)
func get_graph_targets(relationship_emoji: String) -> Array
func has_graph_edge(relationship_emoji: String, target_emoji: String) -> bool
```

---

## Signals

### FarmGrid

```gdscript
signal plot_planted(position: Vector2i)
signal plot_harvested(position: Vector2i, yield_data: Dictionary)
signal entanglement_created(from: Vector2i, to: Vector2i)
signal entanglement_removed(from: Vector2i, to: Vector2i)
signal plot_changed(position: Vector2i, change_type: String, details: Dictionary)
signal visualization_changed()
```

### BiomeBase

```gdscript
signal qubit_created(position: Vector2i, qubit: Resource)
signal qubit_measured(position: Vector2i, outcome: String)
signal qubit_evolved(position: Vector2i)
signal bell_gate_created(positions: Array)
```

---

## Data Structures

### Harvest Result

```gdscript
{
    "success": bool,
    "outcome": String,  # "🌾" or "👥"
    "energy": float,    # Raw quantum energy (0.0-1.0+)
    "yield": int        # Legacy: energy * 10
}
```

### Persistent Gate

```gdscript
{
    "type": String,            # "bell_phi_plus", "cluster", etc.
    "active": bool,
    "linked_plots": Array[Vector2i]
}
```

### EntangledPair

```gdscript
{
    qubit_a: DualEmojiQubit,
    qubit_b: DualEmojiQubit,
    density_matrix: Array[Array],  # 4x4 complex
    bell_type: String,  # "phi_plus", "phi_minus", etc.
    coherence_time_T1: float
}
```

### EntangledCluster

```gdscript
{
    qubit_ids: Array[String],
    qubits: Array[DualEmojiQubit],
    entanglement_strength: float
}
```

---

## Bell States

| State | Equation | Density Matrix Indices |
|-------|----------|----------------------|
| Φ+ | (&#124;00⟩ + &#124;11⟩)/√2 | [0,0], [0,3], [3,0], [3,3] |
| Φ− | (&#124;00⟩ − &#124;11⟩)/√2 | [0,0], [0,3], [3,0], [3,3] |
| Ψ+ | (&#124;01⟩ + &#124;10⟩)/√2 | [1,1], [1,2], [2,1], [2,2] |
| Ψ− | (&#124;01⟩ − &#124;10⟩)/√2 | [1,1], [1,2], [2,1], [2,2] |

---

## Quantum Gate Operations

### Single-Qubit

| Gate | Effect | Bloch Sphere | Code |
|------|--------|--------------|------|
| Pauli-X | Bit flip | θ → π − θ | `qubit.apply_pauli_x()` |
| Pauli-Z | Phase flip | φ → φ + π | `qubit.apply_pauli_z()` |
| Hadamard | Superposition | Rotate π around (1,0,1) | `qubit.apply_hadamard()` |

### Two-Qubit

| Gate | Effect | Implementation |
|------|--------|----------------|
| CNOT | If control &#124;1⟩, flip target | `if control.theta > π/2: target.apply_pauli_x()` |
| CZ | If control &#124;1⟩, phase target | `if control.theta > π/2: target.apply_pauli_z()` |
| SWAP | Exchange states | `temp = a; a = b; b = temp` |

---

## Biome Integration

### Registration

```gdscript
# In Farm._ready()
grid.register_biome("BioticFlux", biotic_flux_biome)
grid.register_biome("Forest", forest_biome)
grid.register_biome("Market", market_biome)
```

### Assignment

```gdscript
# Assign specific plot to biome
grid.assign_plot_to_biome(Vector2i(0, 0), "BioticFlux")

# Assign row to biome
for x in range(5):
    grid.assign_plot_to_biome(Vector2i(x, 1), "Forest")
```

### Routing

```gdscript
# Get biome for plot
var biome = grid.get_biome_for_plot(position)

# Evolution routed automatically
plot.grow(delta, biome, ...)
```

---

## Common Patterns

### Plant-Grow-Harvest

```gdscript
# Plant
grid.plant(pos, "wheat")

# Grow (automatic every frame)
# ... quantum evolution happens ...

# Harvest
var result = grid.harvest(pos)
var credits = result["energy"] * 10
economy.add_credits(credits)
```

### Build Persistent Gate

```gdscript
# Build gate
grid.create_entanglement(pos_a, pos_b, "phi_plus")

# Harvest both
grid.harvest(pos_a)
grid.harvest(pos_b)

# Replant both
grid.plant(pos_a, "wheat")
grid.plant(pos_b, "wheat")
# → Auto-entangles!
```

### Energy Tap

```gdscript
# Build tap
grid.plant_energy_tap(pos, "🌾")

# Wait for draining (automatic)
# ... energy accumulates in tap ...

# Harvest tap
var result = grid.harvest(pos)
# → Collected drained wheat energy
```

---

## Key Formulas

### Born Rule Probabilities

```gdscript
P(north) = cos²(theta / 2)
P(south) = sin²(theta / 2)
```

### Energy Growth (BioticFlux)

```gdscript
energy_rate = base_rate * alignment * brightness * icon_influence
qubit.energy *= exp(energy_rate * dt)
```

### Alignment (3D Bloch Sphere)

```gdscript
v1 = (sin(θ1)cos(φ1), sin(θ1)sin(φ1), cos(θ1))
v2 = (sin(θ2)cos(φ2), sin(θ2)sin(φ2), cos(θ2))
alignment = cos²(acos(v1·v2))
```

### Energy Tap Coupling

```gdscript
alignment = cos²((target.theta - tap.theta) / 2)
amplitude = cos²(target.theta / 2)
transfer_rate = base_rate * amplitude * alignment
```

---

## Typical Values

| Property | Typical Range | Example |
|----------|---------------|---------|
| theta | 0 to π | 1.2 (68.7°) |
| phi | 0 to 2π | 3.5 (200.5°) |
| radius | 0.0 to 1.0 | 0.85 |
| energy | 0.0 to 1.0 | 0.73 |
| berry_phase | 0.0 to 10.0 | 0.2 |
| replant_cycles | 0 to ∞ | 3 |

---

## File Locations

| Component | File Path |
|-----------|-----------|
| BasePlot | `Core/GameMechanics/BasePlot.gd` |
| FarmPlot | `Core/GameMechanics/FarmPlot.gd` |
| BiomePlot | `Core/GameMechanics/BiomePlot.gd` |
| FarmGrid | `Core/GameMechanics/FarmGrid.gd` |
| DualEmojiQubit | `Core/QuantumSubstrate/DualEmojiQubit.gd` |
| ToolConfig | `Core/GameState/ToolConfig.gd` |
| BiomeBase | `Core/Environment/BiomeBase.gd` |
| BioticFluxBiome | `Core/Environment/BioticFluxBiome.gd` |

---

## Quick Debugging

### Check Plot State

```gdscript
var plot = grid.get_plot(Vector2i(0, 0))
print("Planted: %s" % plot.is_planted)
print("Measured: %s" % plot.has_been_measured)
print("Theta: %.2f" % plot.theta)
print("Energy: %.2f" % plot.quantum_state.energy)
```

### Check Entanglement

```gdscript
var is_entangled = grid.are_plots_entangled(pos_a, pos_b)
print("Plots entangled: %s" % is_entangled)
print("Entangled pairs count: %d" % grid.entangled_pairs.size())
```

### Check Persistent Gates

```gdscript
var gates = plot.get_active_gates()
print("Active gates: %d" % gates.size())
for gate in gates:
    print("  Gate: %s, Linked: %s" % [gate["type"], gate["linked_plots"]])
```
