# Farm Plot Mechanics - Complete Documentation Package

## Package Overview

**Total Documentation: ~10,000 words across 8 files**

This package provides complete documentation of the SpaceWheat farm plot system, including:
- Plot class hierarchy and architecture
- Complete lifecycle (plant → grow → measure → harvest)
- 6 tools with Q/E/R actions
- Biome integration and multi-biome support
- Quantum gates and persistent infrastructure
- Detailed code examples with .gdtxt format

---

## Quick Navigation

### For New Users
1. **README.md** - Start here for package overview
2. **01_plot_architecture.md** - Understand the class hierarchy
3. **02_plot_lifecycle.md** - Learn the gameplay flow
4. **QUICK_REFERENCE.md** - Fast lookup tables

### For Developers
1. **06_code_examples.md** - Complete code walkthroughs with .gdtxt
2. **04_biome_integration.md** - How to connect custom biomes
3. **05_quantum_gates.md** - Entanglement and gate infrastructure
4. **QUICK_REFERENCE.md** - API reference

### For Game Designers
1. **03_tools_system.md** - All 6 tools and their actions
2. **02_plot_lifecycle.md** - Player experience flow
3. **01_plot_architecture.md** - Game mechanics foundations

---

## File Breakdown

### 01_plot_architecture.md (7.1 KB)
**Topics:**
- Class hierarchy: BasePlot → FarmPlot, BiomePlot
- Plot types and emoji mappings
- Persistent gate infrastructure
- Entanglement tracking (two systems)
- Berry phase accumulation
- Conspiracy network connection

**Key Concepts:**
- Plots STORE quantum state, biomes EVOLVE quantum state
- Infrastructure persists, qubits are temporary
- Multi-level entanglement tracking

### 02_plot_lifecycle.md (9.8 KB)
**Topics:**
- Plant → Grow → Measure → Harvest flow
- Empty plot initial state
- Planting with biome resource injection
- Automatic quantum evolution
- Measurement and Born rule collapse
- Harvesting and cleanup
- Persistent gates across cycles

**Key Concepts:**
- Biome creates quantum state on plant
- Evolution happens automatically every frame
- Gates survive harvest/replant cycles

**Code Examples:**
```gdtxt
# Planting (BasePlot.plant)
func plant(labor, wheat_cost, biome):
    var emojis = get_plot_emojis()
    quantum_state = DualEmojiQubit.new(emojis["north"], emojis["south"], PI/2)
    quantum_state.energy = (wheat_cost * 100.0) + (labor * 50.0)
```

### 03_tools_system.md (12 KB)
**Topics:**
- ToolConfig.gd as single source of truth
- Tool 1: Grower (plant, entangle, harvest)
- Tool 2: Quantum (persistent gates)
- Tool 3: Industry (mills, markets, kitchens)
- Tool 4: Energy (energy taps)
- Tool 5: Gates (1-qubit and 2-qubit operations)
- Submenu system
- Tool action routing

**Key Concepts:**
- 6 tools, each with 3 actions (Q/E/R)
- Submenus for complex actions
- Single source of truth pattern

**Code Examples:**
```gdtxt
# Tool definition
const TOOL_ACTIONS = {
    1: {  # GROWER Tool
        "name": "Grower",
        "emoji": "🌱",
        "Q": {"action": "submenu_plant", "label": "Plant ▸"},
        "E": {"action": "entangle_batch", "label": "Entangle (Bell φ+)"},
        "R": {"action": "measure_and_harvest", "label": "Measure + Harvest"},
    },
```

### 04_biome_integration.md (13 KB)
**Topics:**
- Multi-biome architecture
- FarmGrid biome registry
- Biome assignment and routing
- Biome responsibilities
- BioticFlux example (three-layer evolution)
- Forest biome (current problematic approach)
- Market biome
- Icon scoping (advanced)
- Creating custom biomes

**Key Concepts:**
- Plot-to-biome assignment determines evolution
- Each biome has different physics
- Icon scoping restricts Hamiltonians to specific biomes
- Separation of concerns: plots=storage, biomes=evolution

**Code Examples:**
```gdtxt
# Biome registration
grid.register_biome("BioticFlux", biotic_flux_biome)
grid.assign_plot_to_biome(Vector2i(0, 0), "BioticFlux")

# Routing
var plot_biome = grid.get_biome_for_plot(position)
plot_biome._evolve_quantum_substrate(delta)
```

### 05_quantum_gates.md (12 KB)
**Topics:**
- Persistent gate system
- Auto-entangle from infrastructure
- Bell states (4 types)
- Density matrix representation
- Entangled clusters (N-qubit)
- Single-qubit gates (Pauli-X, H, Z)
- Two-qubit gates (CNOT, CZ, SWAP)
- Gate visualization
- Gate removal

**Key Concepts:**
- Gates persist, qubits don't
- Auto-apply when all participants planted
- Proper density matrix for Bell pairs
- Visual feedback for entanglement

**Code Examples:**
```gdtxt
# Building persistent gate
plot_a.add_persistent_gate("bell_phi_plus", [pos_b])
plot_b.add_persistent_gate("bell_phi_plus", [pos_a])

# Harvest both (gates persist!)
grid.harvest(pos_a)
grid.harvest(pos_b)

# Replant both → auto-entangle
grid.plant(pos_a, "wheat")
grid.plant(pos_b, "wheat")
# → _auto_apply_persistent_gates() creates new EntangledPair
```

### 06_code_examples.md (21 KB) ⭐
**Topics:**
- Complete plant-grow-harvest cycle (detailed)
- Building persistent Bell gate (step-by-step)
- Energy tap system (complete flow)
- Key code patterns

**Key Concepts:**
- Biome-driven evolution pattern
- Signal-driven updates
- Persistent infrastructure lifecycle
- Multi-biome routing

**Code Examples:** (Extensive .gdtxt format with full implementations)
- 300+ lines of annotated code
- Example calculations with numbers
- Multi-step workflows
- Real game scenarios

### QUICK_REFERENCE.md (11 KB) 📚
**Contents:**
- Plot classes table
- Plot types table
- Tools & actions (all 6 tools)
- Core methods reference
- Signals reference
- Data structures
- Bell states table
- Quantum gate operations
- Common patterns
- Key formulas
- Typical values
- File locations
- Quick debugging

**Use Case:** Fast API lookup during development

### README.md (2.7 KB)
**Contents:**
- Package overview
- Reading paths for different roles
- System flow diagram
- Quick concept summary

---

## Key Design Patterns Documented

### 1. Separation of Concerns
```
Plot (storage) ← Biome (evolution) → Quantum State (data)
```

### 2. Persistent Infrastructure
```
Gates persist → Harvest destroys qubits → Replant creates qubits → Gates auto-apply
```

### 3. Multi-Biome Routing
```
Grid registry → Plot assignment → Evolution routing → Different physics
```

### 4. Signal-Driven Architecture
```
Grid emits → Farm listens → Economy updates → UI refreshes
```

### 5. Tool-Based Interaction
```
Player selects tool → Presses Q/E/R → ToolConfig maps → FarmGrid executes
```

---

## Code Format: .gdtxt

All code examples use `.gdtxt` format (GDScript text) for clarity:
- Full function signatures with types
- Detailed comments explaining logic
- Example calculations with actual numbers
- Multi-step workflows showing data flow

**Example:**
```gdtxt
func plant(position: Vector2i, plant_type: String) -> bool:
    var plot = get_plot(position)
    if plot.is_planted:
        return false

    # Set plot type based on plant_type
    plot.plot_type = {"wheat": WHEAT, "mushroom": MUSHROOM}[plant_type]

    # Biome creates quantum state
    plot.plant(0.08, 0.22, biome)  # 0.08 labor + 0.22 wheat
    # → quantum_state.energy = (0.22 * 100) + (0.08 * 50) = 26.0

    return true
```

---

## Coverage

### ✅ Fully Documented
- Plot class hierarchy
- Complete lifecycle
- All 6 tools
- Biome integration
- Quantum gates
- Persistent infrastructure
- Multi-biome support
- Energy taps
- Code examples

### 📝 Referenced (Detailed in Forest Biome docs)
- Forest ecosystem (problematic - documented in forest_biome_design_question)
- QuantumOrganism (agent-based approach)

### 🔮 Future Topics (Not Yet Implemented)
- Measure triggers
- Mill/Market/Kitchen processing details
- Conspiracy network mechanics
- Vocabulary evolution integration

---

## Cross-References

### Forest Biome Design Question Package
Location: `llm_outbox/forest_biome_design_question/`

**Overlap:**
- BiomePlot usage in forest
- QuantumOrganism (problematic implementation)
- How biomes should evolve plots

**Difference:**
- Farm Plot Mechanics: How plots work
- Forest Biome Design: How to fix forest organisms

### Reading Order for Complete Understanding
1. This package (farm_plot_mechanics) - Understand plots
2. Forest biome package - Understand biome design challenges
3. Code repository - See actual implementation

---

## Statistics

| Metric | Value |
|--------|-------|
| Total Files | 8 |
| Total Words | ~10,000 |
| Code Examples | 50+ |
| .gdtxt Blocks | 30+ |
| Tables | 15+ |
| Cross-References | 25+ |

---

## Best Practices from Documentation

1. **Always use biome for planting**
   ```gdscript
   plot.plant(labor, wheat, biome)  # NEW
   # NOT: plot.plant(quantum_state)  # OLD (deprecated)
   ```

2. **Let biomes handle evolution**
   ```gdscript
   biome._evolve_quantum_substrate(dt)
   # NOT: plot.quantum_state.theta += 0.1  # Manual mutation
   ```

3. **Use persistent gates for permanent circuits**
   ```gdscript
   grid.create_entanglement(pos_a, pos_b, "phi_plus")
   # Creates EntangledPair AND persistent gate infrastructure
   ```

4. **Route plots to correct biome**
   ```gdscript
   var plot_biome = grid.get_biome_for_plot(position)
   plot.grow(delta, plot_biome, ...)
   ```

5. **Emit signals for UI updates**
   ```gdscript
   plot_changed.emit(position, "planted", {"plant_type": "wheat"})
   visualization_changed.emit()
   ```

---

## Audience

**Primary:** External developers integrating with SpaceWheat

**Secondary:**
- Internal team members
- Game designers planning mechanics
- Technical writers
- AI assistants helping with the project

---

## Maintenance

**To update this documentation:**
1. Modify relevant .md file in this package
2. Update QUICK_REFERENCE.md if API changed
3. Add code examples to 06_code_examples.md
4. Update this summary if structure changed

**When adding new features:**
1. Add to appropriate existing document
2. Update QUICK_REFERENCE.md
3. Add code example if complex
4. Update README.md reading paths if needed

---

## Related Packages

1. **forest_biome_design_question/** - Forest biome conceptual design
2. **quantum_mills_markets_design/** - Economic system design (if exists)
3. Repository code - Actual implementation

---

Thank you for using this documentation package!
