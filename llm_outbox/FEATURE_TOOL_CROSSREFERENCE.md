# Feature-Tool Cross-Reference Matrix

Complete mapping of which tools can access which quantum features and capabilities.

---

## QUICK REFERENCE: TOOLS vs QUANTUM FEATURES

### Tool 1: GROWER 🌱

| Quantum Feature | Q Action (Plant) | E Action (Entangle) | R Action (Measure) |
|-----------------|------------------|---------------------|-------------------|
| **State Initialization** | ✓ Sets initial state for plot | ✓ Merges components | ✓ Collapses state |
| **Density Matrix** | ✓ Read populations | ✓ Read/modify via tensor product | ✓ Modifies via projection |
| **Lindblad Evolution** | ✓ Implicit (growth) | ✓ Disabled (instantaneous entangle) | ✓ Via measurement collapse |
| **Population Transfer** | ✓ Plant → growth transition | - | ✓ Harvest → observable |
| **Measurement** | - | - | ✓ Projective measurement |
| **Entanglement** | - | ✓ Creates Bell φ+ state | ✓ Component entanglement info |
| **Register Tracking** | ✓ Via planted status | ✓ Merges registers into component | ✓ Via measurement outcome |
| **State Properties (Purity, Entropy)** | ✓ Read via inspection | ✓ Modified (increases purity if separated registers) | ✓ Reduced after measurement |
| **Semantic Octant** | ✓ Affects planting variant | - | - |
| **Spark Extraction** | - | - | - |
| **Gate Operations** | - | - | - |

**Usage Flow:**
1. Q: Select plot → Plant (sets up register, initializes state)
2. E: Select 2+ plots → Entangle (applies Bell circuit, merges components)
3. R: Select plot → Measure (collapses single register)

---

### Tool 2: QUANTUM ⚛️

| Quantum Feature | Q Action (Cluster) | E Action (Set Trigger) | R Action (Batch Measure) |
|-----------------|-------------------|------------------------|--------------------------|
| **State Initialization** | - | - | - |
| **Density Matrix** | ✓ Read full state | - | ✓ Read for projection |
| **Lindblad Evolution** | - | - | - |
| **Population Transfer** | - | - | - |
| **Measurement** | - | ✓ Designates trigger | ✓ Batch measures component |
| **Entanglement** | ✓ Creates Bell (2-plot) or Cluster (3+) | ✓ Monitors for measurement event | ✓ Measures all correlated plots |
| **Register Tracking** | ✓ Builds entanglement graph | ✓ Tracks trigger point | ✓ Returns all register outcomes |
| **State Properties** | ✓ Can read purity/entropy after cluster | - | ✓ Can read after measurement |
| **Component Merging** | ✓ Merges if separate components | - | ✓ Required for batch operation |
| **Semantic Octant** | - | - | - |
| **Spark Extraction** | - | - | - |
| **Gate Operations** | - | - | - |

**Usage Flow:**
1. Q: Select 2-3+ plots → Build Cluster (creates entanglement structure)
2. E: Select measurement observer → Set Trigger (watches for collapse)
3. R: Activate → Batch Measure (collapses entire entangled component)

---

### Tool 3: INDUSTRY 🏭

| Quantum Feature | Q (Build Menu) | E (Build Market) | R (Build Kitchen) |
|-----------------|----------------|------------------|-------------------|
| **State Initialization** | - | - | - |
| **Density Matrix** | - | - | - |
| **Lindblad Evolution** | - | - | - |
| **Population Transfer** | - | ✓ Market trades resource <br/> (emoji population exchange) | ✓ Kitchen transforms crops <br/> (emoji state change) |
| **Measurement** | - | - | - |
| **Entanglement** | - | - | - |
| **Register Tracking** | - | - | - |
| **State Properties** | - | - | - |
| **Semantic Octant** | - | - | - |
| **Spark Extraction** | - | - | - |
| **Gate Operations** | - | - | - |

**Note:** Tool 3 is economy-focused, not quantum mechanics. Minimal direct quantum access.

---

### Tool 4: BIOME CONTROL ⚡

| Quantum Feature | Q (Energy Tap) | E (Pump/Reset) | R (Tune Decoherence) |
|-----------------|----------------|----------------|----------------------|
| **State Initialization** | - | ✓ Reset pure: reinitialize to basis |✓ Reset mixed: maximize entropy | - |
| **Density Matrix** | ✓ Reads energy split (real/imaginary) | ✓ Modifies diagonal elements | ✓ Modifies Lindblad rates |
| **Lindblad Evolution** | - | - | ✓ Changes decoherence rate parameter |
| **Population Transfer** | ✓ Via SparkConverter | ✓ Pump to wheat: direct population boost | - |
| **Measurement** | - | - | - |
| **Entanglement** | - | - | - |
| **Register Tracking** | - | - | - |
| **State Properties** | ✓ Purity (before/after extraction) | ✓ Entropy (after reset) | ✓ Coherence decay rate |
| **Energy Extraction** | ✓ **PRIMARY** - Extract coherence → population | - | - |
| **Spark System** | ✓ Uses SparkConverter.extract_spark() | - | - |
| **Semantic Octant** | - | - | - |
| **Gate Operations** | - | - | - |

**Usage Flow:**
1. Q: Select target emoji → Energy Tap (extracts imaginary → real energy)
2. E: Select option → Pump to wheat / Reset pure / Reset mixed
3. R: Adjust slider → Tune decoherence rate (γ parameter)

**Key Trade-off:** Energy extraction sacrifices flexibility (coherence) for immediate resources (population).

---

### Tool 5: GATES 🔄

| Quantum Feature | Q (1-Q Gate) | E (2-Q Gate) | R (Remove) |
|-----------------|--------------|--------------|-----------|
| **State Initialization** | - | - | - |
| **Density Matrix** | ✓ Apply unitary ρ' = Uρ† | ✓ Apply 2-qubit unitary | ✓ Reverse gate effect |
| **Lindblad Evolution** | - | - | - |
| **Population Transfer** | - | - | - |
| **Measurement** | - | - | - |
| **Entanglement** | ✓ H creates superposition (entangles with environment) | ✓ CNOT/CZ/SWAP manipulates entanglement | ✓ Removes entanglement effects |
| **Register Tracking** | ✓ Modifies state of register at position | ✓ Correlates two registers | ✓ Clears gate history |
| **State Properties** | ✓ Changes purity/entropy | ✓ Can create/reduce entanglement | ✓ Restores previous state |
| **Quantum Gates** | ✓ **PRIMARY** - Applies Pauli-X, Hadamard, Z | ✓ **PRIMARY** - Applies CNOT, CZ, SWAP | ✓ Deletes gates |
| **Gate Operations** | ✓ Single-qubit gates | ✓ Two-qubit gates | ✓ Gate removal |
| **Semantic Octant** | - | - | - |

**Gate Details by Submenu:**

**1-Qubit Gates (Tool 5, Q):**
- Pauli-X (↔): Bit flip |0⟩→|1⟩
- Hadamard (🌀): Superposition (|0⟩+|1⟩)/√2
- Pauli-Z (⚡): Phase flip (|1⟩ gets -1)

**2-Qubit Gates (Tool 5, E):**
- CNOT (⊕): Control-X on target
- CZ (⚡): Control-phase
- SWAP (⇄): Exchange qubits

---

### Tool 6: BIOME 🌍

| Quantum Feature | Q (Assign) | E (Clear) | R (Inspect) |
|-----------------|-----------|-----------|-------------|
| **State Initialization** | ✓ Links plot to biome's quantum computer | ✓ Unlinks from quantum computer | - |
| **Density Matrix** | ✓ Registers plot with register map | ✓ Deregisters from register map | ✓ Displays current state |
| **Lindblad Evolution** | ✓ Plot now evolves with biome | ✓ Stops evolution | ✓ Shows evolution history |
| **Population Transfer** | ✓ Enables biome transitions | ✓ Stops transitions | - |
| **Measurement** | ✓ Can be measured in biome context | ✓ Cannot be measured | ✓ Shows measurement outcomes |
| **Entanglement** | ✓ Can entangle within biome | ✗ **Cannot** entangle with other biomes | ✓ Shows entanglement graph |
| **Register Tracking** | ✓ Adds to biome register map | ✓ Removes from register map | ✓ Lists all registers |
| **State Properties** | ✓ Subject to biome modifiers | - | ✓ Displays full analysis |
| **Semantic Octant** | - | - | ✓ Shows current octant |

**Cross-Biome Prevention:**
- ✓ Assign allows same-biome only
- ✗ Entanglement blocked across biomes (validated in FarmGrid)

---

## CAPABILITY MATRIX: What Each Tool Can Do

```
                    STATE  EVOLVE  GATES  MEASURE  ENTANGLE  ENERGY  ANALYZE
Tool 1 (Grower)      ✓      ✓       -        ✓         ✓        -        ✓
Tool 2 (Quantum)     -      -       -        ✓         ✓        -        ✓
Tool 3 (Industry)    -      -       -        -         -        -        -
Tool 4 (Control)     ✓      ✓       -        -         -        ✓        ✓
Tool 5 (Gates)       ✓      ✓       ✓        -         ✓        -        -
Tool 6 (Biome)       ✓      ✓       -        -         ✗        -        ✓

Legend:
✓ = Full access
✗ = Blocked/prevented
- = Not applicable
```

---

## FEATURE AVAILABILITY BY TOOL

### Register & Component Operations
| Feature | Tool 1 | Tool 2 | Tool 3 | Tool 4 | Tool 5 | Tool 6 |
|---------|--------|--------|--------|--------|--------|--------|
| Allocate register | ✓ | - | - | - | - | ✓ |
| Merge components | ✓ | ✓ | - | - | - | - |
| Inspect component | ✓ | ✓ | - | - | - | ✓ |
| Register mapping | ✓ | ✓ | - | - | ✓ | ✓ |

### Measurement Operations
| Feature | Tool 1 | Tool 2 | Tool 3 | Tool 4 | Tool 5 | Tool 6 |
|---------|--------|--------|--------|--------|--------|--------|
| Single measurement | ✓ | - | - | - | - | - |
| Batch measurement | - | ✓ | - | - | - | - |
| Measurement trigger | - | ✓ | - | - | - | - |
| Distribution inspection | ✓ | ✓ | - | - | - | ✓ |

### State Evolution
| Feature | Tool 1 | Tool 2 | Tool 3 | Tool 4 | Tool 5 | Tool 6 |
|---------|--------|--------|--------|--------|--------|--------|
| Hamiltonian evolution | ✓ (implicit) | - | - | - | - | ✓ |
| Lindblad evolution | ✓ (implicit) | - | - | - | - | ✓ |
| Population transfer | ✓ | - | ✓ | ✓ | - | - |
| Decoherence control | - | - | - | ✓ | - | - |

### Entanglement Operations
| Feature | Tool 1 | Tool 2 | Tool 3 | Tool 4 | Tool 5 | Tool 6 |
|---------|--------|--------|--------|--------|--------|--------|
| Create Bell state | ✓ | ✓ | - | - | - | - |
| Create cluster | - | ✓ | - | - | - | - |
| Manipulate entanglement | - | - | - | - | ✓ | - |
| Cross-biome prevention | ✓ | ✓ | - | - | - | ✓ |

### Quantum Gates
| Feature | Tool 1 | Tool 2 | Tool 3 | Tool 4 | Tool 5 | Tool 6 |
|---------|--------|--------|--------|--------|--------|--------|
| Pauli gates (X, Y, Z) | - | - | - | - | ✓ | - |
| Hadamard | - | - | - | - | ✓ | - |
| CNOT/CZ/SWAP | - | - | - | - | ✓ | - |
| Gate history | - | - | - | - | ✓ | ✓ |

### State Analysis
| Feature | Tool 1 | Tool 2 | Tool 3 | Tool 4 | Tool 5 | Tool 6 |
|---------|--------|--------|--------|--------|--------|--------|
| Purity calculation | ✓ | ✓ | - | ✓ | - | ✓ |
| Entropy calculation | ✓ | ✓ | - | ✓ | - | ✓ |
| Uncertainty metrics | ✓ | - | - | ✓ | - | ✓ |
| Attractor analysis | ✓ | - | - | - | - | ✓ |
| Semantic octant | ✓ | - | - | ✓ | - | ✓ |

### Energy & Spark System
| Feature | Tool 1 | Tool 2 | Tool 3 | Tool 4 | Tool 5 | Tool 6 |
|---------|--------|--------|--------|--------|--------|--------|
| Energy split calculation | - | - | - | ✓ | - | - |
| Spark extraction | - | - | - | ✓ | - | - |
| Coherence monitoring | - | - | - | ✓ | - | - |
| Regime detection | - | - | - | ✓ | - | - |

---

## SEMANTIC TOPOLOGY FEATURES

### Fiber Bundle Integration
| Feature | Tool 1 | Tool 2 | Tool 3 | Tool 4 | Tool 5 | Tool 6 |
|---------|--------|--------|--------|--------|--------|--------|
| Octant detection | ✓ | - | - | ✓ | - | ✓ |
| Context-aware actions | ✓ | - | - | - | - | - |
| Region modifiers | ✓ | - | - | ✓ | - | ✓ |
| Adjacent regions | - | - | - | - | - | ✓ |

### Uncertainty Principle
| Feature | Tool 1 | Tool 2 | Tool 3 | Tool 4 | Tool 5 | Tool 6 |
|---------|--------|--------|--------|--------|--------|--------|
| Precision calculation | ✓ | ✓ | - | ✓ | - | ✓ |
| Flexibility calculation | ✓ | ✓ | - | ✓ | - | ✓ |
| Regime classification | ✓ | - | - | ✓ | - | ✓ |
| Action modifiers | ✓ | - | - | ✓ | - | - |

### Attractor Analysis
| Feature | Tool 1 | Tool 2 | Tool 3 | Tool 4 | Tool 5 | Tool 6 |
|---------|--------|--------|--------|--------|--------|--------|
| Trajectory recording | ✓ | - | - | - | - | ✓ |
| Personality classification | ✓ | - | - | - | - | ✓ |
| Lyapunov exponent | ✓ | - | - | - | - | ✓ |
| Spread calculation | ✓ | - | - | - | - | ✓ |

---

## UI PANELS MAPPED TO TOOLS

| UI Panel | Tool 1 | Tool 2 | Tool 3 | Tool 4 | Tool 5 | Tool 6 |
|----------|--------|--------|--------|--------|--------|--------|
| Quantum Energy Meter | ✓ | - | - | ✓ | - | - |
| Uncertainty Meter | ✓ | - | - | ✓ | - | - |
| Semantic Context | ✓ | - | - | ✓ | - | - |
| Attractor Personality | ✓ | - | - | - | - | ✓ |
| Action Preview | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Entanglement Lines | ✓ | ✓ | - | - | - | - |
| Gate History | - | - | - | - | ✓ | ✓ |

---

## ACCESSING QUANTUM MACHINERY FEATURES

### If you want to... use this tool:

| Goal | Tool(s) | Action | Feature Accessed |
|------|---------|--------|-----------------|
| **Plant crops** | Grower (1) | Q | State init + Lindblad evolution |
| **Entangle plots** | Grower (1) / Quantum (2) | E | Entanglement + Bell states |
| **Harvest/Measure** | Grower (1) | R | Measurement + collapse |
| **Build structure** | Quantum (2) | Q | Entanglement graph |
| **Batch measure** | Quantum (2) | R | Component measurement |
| **Extract energy** | Control (4) | Q | Spark system + coherence |
| **Adjust decoherence** | Control (4) | R | Lindblad parameter tuning |
| **Apply quantum gate** | Gates (5) | Q/E | Unitary transformation |
| **Assign plot to biome** | Biome (6) | Q | Register map + quantum computer |
| **Inspect quantum state** | Biome (6) / Grower (1) | R | State analysis |

---

## QUICK START GUIDE BY QUANTUM GOAL

### Goal: Create Entanglement
**Tools:** Grower (1) or Quantum (2)
- **Method 1 (Grower):** Select 2+ plots → Tool 1 → E (Entangle)
- **Method 2 (Quantum):** Select 2-3+ plots → Tool 2 → Q (Build Cluster)
- **Features Used:** Register merging, Bell state creation, component management
- **UI Panel:** Entanglement Lines show the connections

### Goal: Measure State
**Tools:** Grower (1) or Quantum (2)
- **Grower:** Select plot → Tool 1 → R (single measurement)
- **Quantum:** Select component → Tool 2 → R (batch measurement)
- **Features Used:** Born rule sampling, state projection, collapse
- **UI Panel:** Action Preview shows outcome

### Goal: Apply Quantum Gates
**Tools:** Gates (5)
- **1-Qubit:** Select plot → Tool 5 → Q → choose gate
- **2-Qubit:** Select 2 plots → Tool 5 → E → choose gate
- **Features Used:** Unitary transformation, embedding, Hilbert space operations
- **UI Panel:** Gate History (via Biome inspector)

### Goal: Control State Evolution
**Tools:** Control (4) or Biome (6)
- **Energy Extraction:** Tool 4 → Q (tap emoji)
- **Pump/Reset:** Tool 4 → E (modify state)
- **Decoherence Control:** Tool 4 → R (adjust γ)
- **Features Used:** Lindblad dynamics, energy split, spark system
- **UI Panel:** Quantum Energy Meter, Uncertainty Meter

### Goal: Analyze Quantum Behavior
**Tools:** Grower (1), Biome (6), or Action Panels
- **Inspect:** Tool 6 → R (view full state)
- **Monitor:** Watch UI panels (Energy, Uncertainty, Attractor)
- **Features Used:** State properties, semantic analysis, trajectory tracking
- **UI Panels:** All analysis panels update in real-time

---

## CONSTRAINTS & RULES

### Cross-Biome
- ✓ Entanglement within biome (Tool 1/2)
- ✗ Entanglement across biomes (blocked by FarmGrid validation)
- ✓ Tools work independently in each biome

### State Collapse
- Measurement (Tool 1 R or Tool 2 R) collapses entire component
- Single measurement affects all correlated registers
- Non-reversible operation

### Entanglement Limits
- Can merge unlimited components
- Increasing Hilbert dimension (2^n grows exponentially)
- Performance degrades with large components

### Energy Extraction Trade-off (Tool 4)
- Gain: Real energy (population boost)
- Cost: Lose coherence (flexibility)
- Evaluates uncertainty principle

### Gate Application (Tool 5)
- Must apply to plots in same component for 2-qubit gates
- Gates preserve trace and Hermiticity
- History tracked for inspection

---

## REFERENCE: FEATURE TO TOOL LOOKUP

Use this to find which tools access each quantum feature:

| Quantum Feature | Tools | UI Panel |
|-----------------|-------|----------|
| Register allocation | 1, 6 | Action Preview |
| State initialization | 1, 4, 6 | Quantum Energy Meter |
| Hamiltonian evolution | 1, 6 | Semantic Context |
| Lindblad evolution | 1, 4, 6 | Uncertainty Meter |
| Population transfer | 1, 3, 4 | Resource Panel |
| Measurement | 1, 2 | Action Preview |
| Single-qubit gates | 5 | Gate History |
| Two-qubit gates | 5 | Gate History |
| Entanglement | 1, 2 | Entanglement Lines |
| Bell states | 1, 2 | Entanglement Lines |
| Component merging | 1, 2 | Network Info |
| Energy extraction | 4 | Quantum Energy Meter |
| Decoherence control | 4 | Uncertainty Meter |
| Semantic octants | 1, 4, 6 | Semantic Context |
| Uncertainty metrics | 1, 4, 6 | Uncertainty Meter |
| Attractor analysis | 1, 6 | Attractor Panel |
| State inspection | 1, 2, 6 | All panels |

