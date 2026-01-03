# Plot Architecture - Class Hierarchy and Core Concepts

## Class Hierarchy

```
Resource
  └── BasePlot
       ├── FarmPlot
       │    └── WheatPlot (legacy)
       └── BiomePlot
```

---

## BasePlot - Foundation Class

**Purpose:** Core quantum state management shared by all plots

**Key Properties:**
- `plot_id: String` - Unique identifier
- `grid_position: Vector2i` - Position in farm grid
- `quantum_state: DualEmojiQubit` - The quantum state (injected by biome)
- `is_planted: bool` - Whether crop is planted
- `has_been_measured: bool` - Whether quantum state has collapsed
- `berry_phase: float` - Accumulated "experience" from replanting

**Core Methods:**
```gdscript
func plant(quantum_state_or_labor, wheat_cost, biome)
func measure(icon_network) -> String
func harvest() -> Dictionary
func reset()
```

**Quantum State Accessors:**
```gdscript
# For backward compatibility - delegate to quantum_state
var theta: float
    get: return quantum_state.theta if quantum_state else PI/2.0
    set(value): if quantum_state: quantum_state.theta = value
```

**Key Insight:** BasePlot STORES quantum state but does NOT create or evolve it. The biome is responsible for quantum evolution.

---

## FarmPlot - Player-Interactive Plots

**Purpose:** Plots that respond to player tools

**Extends:** BasePlot

**New Properties:**
- `plot_type: PlotType` - WHEAT, TOMATO, MUSHROOM, MILL, MARKET, KITCHEN, ENERGY_TAP
- `phase_constraint: PhaseConstraint` - Optional Bloch sphere restriction
- `entangled_plots: Dictionary` - Connected plots (plot_id → strength)
- `persistent_gates: Array[Dictionary]` - Gates that survive harvest

**Plot Type Emoji Mapping:**
```gdscript
PlotType.WHEAT     → {"north": "🌾", "south": "👥"}  # Wheat ↔ Labor
PlotType.TOMATO    → {"north": "🍅", "south": "🍝"}  # Tomato ↔ Sauce
PlotType.MUSHROOM  → {"north": "🍄", "south": "🍂"}  # Mushroom ↔ Detritus
PlotType.MILL      → {"north": "🏭", "south": "💨"}  # Mill ↔ Flour
PlotType.MARKET    → {"north": "🏪", "south": "💰"}  # Market ↔ Credits
PlotType.KITCHEN   → {"north": "🍳", "south": "🍞"}  # Kitchen ↔ Bread
PlotType.ENERGY_TAP→ {"north": "🚰", "south": "⚡"}  # Tap ↔ Power
```

**Growth Method:**
```gdscript
func grow(delta, biome, territory_manager, icon_network, conspiracy_network) -> float:
    if not is_planted or not quantum_state:
        return 0.0

    # Let biome handle quantum evolution
    if biome:
        biome._evolve_quantum_substrate(delta)

    # Apply phase constraints (e.g., Imperium lock)
    if phase_constraint:
        phase_constraint.apply(quantum_state)

    return 0.0
```

**Key Insight:** FarmPlot delegates quantum evolution to the biome. It only manages lifecycle and constraints.

---

## BiomePlot - Biome-Managed Entities

**Purpose:** Non-player entities managed by biome systems

**Extends:** BasePlot

**Plot Types:**
- `TRANSFORMATION_NODE` ⚗️ - Alchemy/transformation
- `MARKET_QUBIT` 💰 - Market trading entity
- `GUILD_RESOURCE` 👥 - Guild/faction resource
- `ENVIRONMENT` 🌍 - Environmental entity

**Key Properties:**
- `biome_plot_type: BiomePlotType`
- `parent_biome` - Reference to owning biome

**Player Interaction:** DISABLED
```gdscript
func plant(...):
    print("⚠️ Cannot plant on biome plot")

func harvest() -> Dictionary:
    return {"success": false, "reason": "Cannot harvest biome plot"}
```

**Use Cases:**
- Forest organisms (wolves, rabbits in ForestEcosystem biome)
- Market traders (sentiment qubits in Market biome)
- Transformation nodes (alchemical processes)

**Key Insight:** BiomePlots exist in the quantum visualization but are controlled entirely by their parent biome.

---

## Persistent Gate Infrastructure

**Concept:** Gates that survive harvest/replant cycles

**Storage:**
```gdscript
# In BasePlot
var persistent_gates: Array[Dictionary] = []
# Each gate: {"type": String, "active": bool, "linked_plots": Array[Vector2i]}
```

**Methods:**
```gdscript
func add_persistent_gate(gate_type: String, linked_plots: Array[Vector2i])
func clear_persistent_gates()
func has_active_gate(gate_type: String) -> bool
func get_active_gates() -> Array[Dictionary]
```

**Example:**
```gdscript
# Build a Bell gate between two plots
plot_a.add_persistent_gate("bell_phi_plus", [pos_b])
plot_b.add_persistent_gate("bell_phi_plus", [pos_a])

# Harvest both plots
plot_a.harvest()
plot_b.harvest()

# Replant both plots
grid.plant(pos_a, "wheat")
grid.plant(pos_b, "wheat")

# Gates automatically re-entangle the new qubits!
# (handled by FarmGrid._auto_apply_persistent_gates)
```

**Key Insight:** Infrastructure persists while crops are temporary. This allows building permanent quantum circuits.

---

## Entanglement Tracking

**Two Systems:**

### 1. Plot-Level (Legacy)
```gdscript
# In BasePlot/FarmPlot
var entangled_plots: Dictionary = {}  # plot_id → strength
const MAX_ENTANGLEMENTS = 3
```

### 2. Grid-Level (New - Proper Quantum States)
```gdscript
# In FarmGrid
var entangled_pairs: Array[EntangledPair]
var entangled_clusters: Array[EntangledCluster]
```

**EntangledPair Structure:**
```gdscript
{
    qubit_a: DualEmojiQubit,
    qubit_b: DualEmojiQubit,
    density_matrix: Array[Array],  # 4x4 complex matrix
    bell_type: "phi_plus" | "phi_minus" | "psi_plus" | "psi_minus",
    coherence_time_T1: float
}
```

**EntangledCluster Structure:**
```gdscript
{
    qubit_ids: Array[String],
    qubits: Array[DualEmojiQubit],
    entanglement_strength: float
}
```

**Key Insight:** Grid-level tracking maintains proper quantum mechanics (density matrices), while plot-level tracking provides backward compatibility.

---

## Berry Phase Accumulation

**Concept:** Plots "remember" how many times they've been replanted

**Mechanism:**
```gdscript
# In BasePlot
var replant_cycles: int = 0
var berry_phase: float = 0.0

func harvest() -> Dictionary:
    var energy = quantum_state.energy
    # Add Berry phase bonus
    energy += berry_phase * 0.1
    replant_cycles += 1  # Increment counter
    return {"energy": energy, ...}
```

**Gameplay Effect:**
- First harvest: 1.0 energy
- Second harvest (same plot): 1.0 + (0.1 * 0.1) = 1.01 energy
- Third harvest: 1.0 + (0.2 * 0.1) = 1.02 energy
- ...

**Key Insight:** Encourages reusing the same plots. Creates spatial memory in the farm.

---

## Conspiracy Network Connection

**For Tomatoes Only:**

```gdscript
# In BasePlot
var conspiracy_node_id: String = ""
var conspiracy_bond_strength: float = 0.0
```

**Assignment Logic (FarmGrid.plant):**
```gdscript
if plant_type == "tomato":
    var node_ids = ["seed", "observer", "underground", "genetic",
                    "ripening", "market", "sauce", "identity",
                    "solar", "water", "meaning", "meta"]
    var node_index = total_plots_planted % node_ids.size()
    plot.conspiracy_node_id = node_ids[node_index]
```

**Effect:** Each tomato connects to one of 12 conspiracy nodes, creating a network topology that affects growth.

**Key Insight:** Different crops have different special mechanics (wheat=normal, mushroom=moon-influenced, tomato=conspiracy network).
