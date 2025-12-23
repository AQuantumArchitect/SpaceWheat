# SpaceWheat Quantum Mills & Markets Architecture Design

**Date:** 2025-12-17
**Context:** Architectural planning for quantum mill and market systems
**Purpose:** Export research and design questions for higher-level consideration

---

## Executive Summary

SpaceWheat is implementing a **computational physics model** where:
1. **Quantum Layer (Local):** Icons' Hamiltonians power entangled wheat-mill systems
2. **Probabilistic Layer (Intermediate):** Repeated measurements generate probability distributions → classical flow rates
3. **Strategic Layer (High Level):** Classical flows are what the strategy game sees and optimizes around

The goal: Create mills as **quantum transducers** that convert wheat superposition into flour probability distributions, powered by icon Hamiltonians. Markets become **quantum network gateways** that couple local farm systems to broader market networks.

---

## User's Vision: Computational Physics Game

### Core Concept

> "The end game puzzle is trying to set up complex systems with the right balance of icons so that the 'physics' of the hamiltonian-ish function powers the system. And then when you measure it 1000 times you get this probabilistic output function that can be expressed into classical flow rates. Eventually, when the system is multiple layers deep, the strategic layer only sees classical flows which are computed from the quantum probability fields."

### Game Flow Progression

**Early Game:**
- Simple quantum systems (single plant + icon influence)
- Direct measurement → discrete outcomes

**Mid Game:**
- Complex multi-layer systems with entangled fields and mills
- Icon Hamiltonians drive mill evolution
- Measurement yields probabilistic distributions

**End Game:**
- Deep system design where you're tuning Hamiltonian-driven quantum systems
- Strategic layer receives classical outputs (computed from quantum probability fields)
- Faction requests reflect useful strategic outcomes

### Key Insight

**The game is about building quantum computers that compute classical resource flows.**

---

## Quantum Mills: User's Specification

### How Quantum Mills Should Work

From user:
> "If the mills are quantum then we entangle a wheat field and then siphon off the wheat energy and into the [wheat-flour]mill qubit and then when the system is measured, or if the mill is measured, it'll collapse into flour."

### Icon-Hamiltonian-Mill Coupling

From user:
> "My idea is to entice icons into the local physics by planting wheat. The agrarian or imperial icons have a hamiltonian that powers the mill, then the mill gets introduced to the system and the whole system should start working in the quantum realm."

**Flow:**
```
1. Plant wheat → Creates quantum state
2. Add mill → Creates mill qubit [wheat→flour]
3. Entangle wheat field with mill
4. Icons apply Hamiltonians → Drive mill evolution
5. Mill theta evolves under icon influence
6. Measure mill → Collapses entangled system into flour
7. Repeated measurements → Probability distribution → Flow rate
```

### Measurement → Flow Rate Computation

From user:
> "When you measure it 1000 times you get this probabilistic output function that can be expressed into classical flow rates."

This means:
- Single measurement: Discrete flour output (sampled from Born rule)
- Repeated measurements: Build probability histogram
- Probability distribution → Classical flow rate calculation
- Strategic layer sees: "Mill produces 12.3 flour/sec"

---

## Quantum Markets: User's Specification

### Market as Quantum Network Gateway

From user:
> "The markets should connect the local space to a quantum network market space. Much like the tomatoes are supposed to activate and connect the system to the tomato conspiracy network, the market should have an ~"internal"~ quantum network that expresses the market prices."

**Key Points:**
- Markets are NOT just local quantum nodes
- Markets are **gateways** to a broader quantum network
- Market prices emerge from this quantum network (not just local superposition)
- Similar to how tomatoes connect to TomatoConspiracyNetwork

### Market Network Structure

Markets should:
1. Create/connect to a quantum network space
2. Have internal quantum network that represents market dynamics
3. Express prices through network state
4. Allow local farm systems to couple with global market network
5. Selling flour = coupling local quantum system to market network

---

## Current System Architecture (Research Findings)

### 1. Hamiltonian System

**Implementation:** IconHamiltonian base class with evolution bias vector

**Structure:**
```gdscript
class IconHamiltonian:
    var evolution_bias: Vector3  # (theta_rate, phi_rate, damping_rate)
    var node_couplings: Dictionary  # node_id -> coupling_strength

    func modulate_node_evolution(node, dt):
        node.theta += evolution_bias.x * coupling * dt
        node.phi += evolution_bias.y * coupling * dt
        node.q, node.p *= (1.0 - evolution_bias.z * coupling * dt)
```

**Key Points:**
- NOT traditional Hamiltonian operator equations
- Continuous modulation via parameter evolution
- Applied to both conspiracy nodes AND individual qubits
- Uses Lindblad jump operators for realistic decoherence

### 2. Three Icons (Hamiltonian Sources)

#### Biotic Flux Icon (🌾 - Agrarian)
- **Temperature Effect:** Cooling (20K → 1K at full activation)
- **Evolution Bias:** Coherence restoration (pulls theta toward π/2)
- **Jump Operators:** Optical pumping (σ_+), anti-dephasing
- **Growth Modifier:** 1.0x to 2.0x (farming boost)
- **Entanglement:** Strengthens bonds (1.0x to 1.5x)
- **Activation:** Based on wheat coverage (wheat_count / total_plots)

#### Chaos Icon (🍅 - Entropic)
- **Temperature Effect:** Heating (20K → 100K+ at full activation)
- **Evolution Bias:** (0.15, 0.4, 0.01) = high theta/phi rates
- **Jump Operators:** Dephasing (σ_z), damping (σ_-)
- **Growth Modifier:** Chaotic 0.8x to 1.4x
- **Activation:** Based on active conspiracies (active_count / max)
- **Special:** Applies quantum noise (Wiener process on phi)

#### Imperium Icon (🏰 - Imperial)
- **Temperature Effect:** Neutral or moderate cooling
- **Evolution Bias:** (-0.02, 0.1, 0.02) = slight drain, phase shift
- **Jump Operators:** Measurement-like collapse (Z-basis), extractive damping
- **Growth Modifier:** Inverted-U curve (oppressive at high activation)
- **Entanglement:** Breaks bonds (1.0x to 0.5x)
- **Activation:** Based on quota pressure (shortfall + time pressure)
- **Special:** Quantum Zeno effect (measurement freezes evolution)

### 3. Icon-Plot Integration

**Applied in:** `FarmGrid._apply_icon_effects(delta)`

**Flow:**
```
FarmGrid._process(delta):
  ├─ _apply_icon_effects(delta)
  │  ├─ Calculate effective_temp from all Icons
  │  └─ For each planted plot:
  │     ├─ Set plot.quantum_state.environment_temperature
  │     └─ For each Icon:
  │        └─ icon.apply_to_qubit(plot.quantum_state, delta)
  │
  └─ For each plot:
     └─ plot.grow(delta, ..., icon_network)
```

**Icon Effects Summary:**

| Effect | Biotic 🌾 | Chaos 🍅 | Imperium 🏰 |
|--------|----------|---------|-----------|
| Temperature | Cooling | Heating | Neutral |
| Coherence | Restore | Destroy | Collapse |
| Growth | Accelerate | Chaotic | Inverted-U |
| Entanglement | Strengthen | Weaken | Break |

### 4. Entanglement System

**Three Mechanisms:**

#### A. Two-Qubit Entangled Pairs (EntangledPair.gd)
- 4×4 density matrix (basis: |00⟩, |01⟩, |10⟩, |11⟩)
- Bell states: Φ+, Φ-, Ψ+, Ψ-
- Partial trace for single-qubit measurement
- Entanglement measures: purity, entropy, concurrence

#### B. N-Qubit Entangled Clusters (EntangledCluster.gd)
- 2^N × 2^N density matrix
- States: GHZ, W, Cluster (graph states)
- Used for measurement-based quantum computing

#### C. WheatPlot Entanglement Dictionary
```gdscript
var entangled_plots: Dictionary = {}  # plot_id -> strength (temporary)
var plot_infrastructure_entanglements: Array[Vector2i] = []  # persistent gates
const MAX_ENTANGLEMENTS = 3
```

**Effects:**
- Entangled plots drift theta → π/2 (superposition)
- Isolated plots drift theta → 0 (wheat certain)
- Measurement detangles all connections
- +20% yield bonus per entangled neighbor

### 5. Measurement Effects

**Three Critical Consequences:**

1. **Theta Freezing:** `theta_frozen = true` stops further drift
2. **Detanglement:** `entangled_plots.clear()` removes from quantum network
3. **Conspiracy Bond:** `conspiracy_bond_strength += 1.0` creates classical correlation

**Imperium Measurement Bias (Applied BEFORE measurement):**
```gdscript
apply_collapse_bias(qubit):
  # Push theta toward nearest pole (0 or π)
  if qubit.theta < PI/2:
    qubit.theta *= (1.0 - 0.4 * active_strength)  # → 0
  else:
    qubit.theta += (PI - qubit.theta) * (0.4 * active_strength)  # → π
```

**Harvest Outcome:**
```gdscript
measured_state = get_dominant_emoji()

if measured_state == north:
  outcome = "wheat"
  base_yield = 10-15
  quality = 1.0 - 0.10 (observer penalty) + berry_phase * 0.1
else:
  outcome = "labor"
  final_yield = 1
```

### 6. Conspiracy Network (TomatoConspiracyNetwork.gd)

**Architecture:** 12 Nodes + 15 Connections

**The 12 Nodes:**
1. seed (🌱→🍅): Potential to fruit
2. observer (👁️→📊): Measurement collapse
3. underground (🕳️→🌐): Root network
4. genetic (🧬→📝): Information transcription
5. ripening (⏰→🔴): Time-color entanglement
6. **market (💰→📈): Value superposition** ← Already exists!
7. sauce (🍅→🍝): State transformation
8. identity (🤔→❓): Categorical superposition
9. solar (☀️→⚡): Light-energy conversion
10. water (💧→🌊): Fluid information storage
11. meaning (📖→💭): Semantic field generator
12. meta (🔄→☯️): Self-referential loop

**Key Connections:**
- ripening ↔ market (0.75): value_timing
- sauce ↔ market (0.82): economic_transformation
- observer ↔ meaning (0.77): semantic_collapse

**Network Evolution:**
```
evolve_network(dt):
  1. Evolve each node independently (theta, phi, q, p)
  2. Sun/moon oscillation (drives solar node)
  3. Apply Icon modulation (Hamiltonians affect node evolution)
  4. Energy diffusion through entanglement connections
```

**Conspiracy Activation:**
- Based on node energy thresholds
- 24 conspiracies with different energy requirements
- Example: "growth_acceleration" activates when energy > 0.8

### 7. Current Flow Rate System

**Status:** NOT IMPLEMENTED

**Current System:**
- Measurement yields discrete outcomes (sampled from Born rule)
- Harvest returns: `{yield: 10-15, outcome: "wheat"}`
- Goes to wheat_inventory (classical economy)
- No probabilistic field mapping repeated measurements to flows

**What Needs to Be Built:**
- Measurement history tracking
- Probability distribution computation
- Flow rate calculation: `avg_yield_per_measurement * measurement_frequency`
- Strategic layer display: "Mill: 12.3 flour/sec"

---

## Key Physics Concepts Implemented

1. **Bloch Sphere Geometry:** θ (polar) and φ (azimuthal) represent quantum states
2. **Berry Phase:** Geometric phase tracking "institutional memory"
3. **Lindblad Evolution:** Master equation with jump operators (σ_x, σ_y, σ_z, σ_±)
4. **Density Matrix Formalism:** 2×2, 4×4, and 2^N matrices
5. **Partial Trace:** Project entangled states to reduced density matrices
6. **T₁/T₂ Decoherence:** Temperature-dependent relaxation and dephasing
7. **Born Rule:** P = |amplitude|²
8. **Quantum Zeno Effect:** Measurement freezes evolution (Imperium)

---

## Design Questions for Larger Brain

### QUANTUM MILLS

#### 1. Mill Quantum State Creation
- Should mills create their own `DualEmojiQubit` when placed?
- Dual emoji: 🌾→💨 (wheat transforming to flour)?
- Or should mill's quantum_state be a **joint state** of the entangled wheat field?

#### 2. Hamiltonian-Driven Evolution
- Currently icons apply evolution_bias to individual qubits
- For quantum mills, should Hamiltonian **couple** wheat field theta to mill theta?
- Example flow:
  ```
  Agrarian icon → modulates mill node in conspiracy network
  Agrarian Hamiltonian → affects mill theta evolution
  Mill theta ≈ f(wheat_field_avg_theta) → flour probability
  ```

#### 3. Entanglement Linking
- When you place a mill adjacent to wheat:
  - Automatically entangle all adjacent wheat?
  - Or explicitly "activate" mill to link?
- Does each mill create separate cluster, or share one large cluster?

#### 4. Measurement Cascade
- When you measure a mill entangled with 5 wheat plots:
  - Collapse ALL 5 wheat + mill into flour simultaneously?
  - Or mill "processes" wheat field probabilistically?
- Yield formula:
  ```
  flour_yield = sum(wheat_probabilities) * Hamiltonian_efficiency?
  flour_yield = average(wheat_states) * icon_modulation?
  ```

#### 5. Flow Rate Generation
- Should system track measurement history of each mill?
- Compute steady-state flow rate:
  ```
  flow_rate = avg_flour_per_measurement * measurement_frequency
  ```
- Display: "Mill flowing 12.3 flour/sec (from 1000 samples)"?

### QUANTUM MARKETS

#### 1. Market-Network Connection
- Should markets create new conspiracy node?
- Or tap into existing "market" node (already exists in TomatoConspiracyNetwork)?
- Current "market" node entangled with: ripening (0.75), sauce (0.82)

#### 2. Price Superposition
How should market prices emerge?

**Option A:** Market has own theta, prices fluctuate as theta evolves
```gdscript
price = lerp(LOW_PRICE, HIGH_PRICE, get_south_probability(market.theta))
```

**Option B:** Price emerges from market conspiracy node energy
```gdscript
price = BASE_PRICE + (market_node.energy * price_sensitivity)
```

**Option C:** Price is collective state of all market nodes in network

#### 3. Selling as Measurement
When player sells flour to market:
- Couple local farm system (wheat + mill + icons) to global market network?
- Sample market price from market node's current state?
- Collapse market theta (affecting future prices)?

#### 4. Classical-Quantum Boundary
- Player sees: "Sold 10 flour for 45 credits"
- Internal process: local quantum system measured → collapsed to flour → coupled to market network → market state sampled → credits calculated?

### SYSTEM ARCHITECTURE

Should we:
1. **Expand conspiracy network** to include Mill nodes (like tomato nodes)?
2. **Create wheat-mill pairs** as entangled clusters within local physics layer?
3. **Extend market nodes** to be gateways coupling local systems to broader network?
4. **Add measurement history tracker** computing flow rates from repeated measurements?

---

## Implementation Considerations

### Integration Points

**Files that will need modification:**

1. **WheatPlot.gd** - Add mill plot type with quantum_state
2. **DualEmojiQubit.gd** - Possibly extend for mill states
3. **FarmGrid.gd** - Handle mill-wheat entanglement creation
4. **TomatoConspiracyNetwork.gd** - Add mill nodes, market gateway logic
5. **IconHamiltonian subclasses** - Define mill-specific Hamiltonian coupling
6. **GameController.gd** - Handle mill measurement and flour production
7. **FarmEconomy.gd** - Track flow rates, not just discrete outputs
8. **QuantumForceGraph.gd** - Visualize mill nodes and market gateways

### Data Structures Needed

**For Mills:**
```gdscript
# In WheatPlot.gd for mill plots
var mill_entangled_wheat: Array[Vector2i] = []  # Which wheat fields power this mill
var measurement_history: Array[float] = []  # Record of past measurements
var flow_rate: float = 0.0  # Computed classical flow rate

# Mill quantum state
var mill_theta: float  # Wheat→flour transformation probability
```

**For Markets:**
```gdscript
# Market gateway to conspiracy network
var market_network_id: String  # Which market network this connects to
var price_state: float  # Current price superposition
var network_coupling_strength: float  # How strongly coupled to network
```

**For Flow Rate System:**
```gdscript
# New class: FlowRateCalculator
class FlowRateCalculator:
    var measurement_window: int = 1000
    var measurement_history: Array[Dictionary] = []

    func record_measurement(outcome: Dictionary)
    func compute_flow_rate() -> float
    func get_probability_distribution() -> Dictionary
```

### Physics Calculations Needed

**Mill Evolution under Icon Hamiltonian:**
```gdscript
# Icon applies evolution bias to mill theta
mill.theta += icon.evolution_bias.x * coupling_strength * dt

# Mill theta also coupled to average wheat field state
wheat_avg_theta = sum([w.theta for w in entangled_wheat]) / len(entangled_wheat)
mill.theta = lerp(mill.theta, wheat_avg_theta, coupling_rate * dt)
```

**Flow Rate Computation:**
```gdscript
# From 1000 measurements, compute expected value
E[flour] = sum([measurement.yield * P(measurement)]) / total_measurements

# Flow rate = expected yield * measurement frequency
flow_rate = E[flour] * measurements_per_second
```

**Market Price from Network:**
```gdscript
# Sample from market conspiracy node
market_node = conspiracy_network.get_node("market")
price_fluctuation = market_node.energy * price_sensitivity

# Or use market theta
price = BASE_PRICE * (1.0 + sin(market.theta) * volatility)
```

---

## Strategic Implications

### Early Game
- Plant wheat → Basic quantum states
- Single measurements → Discrete outcomes
- Build wheat inventory → Sell for credits

### Mid Game
- Build mills → Create quantum transducers
- Entangle wheat fields with mills
- Icons influence Hamiltonian evolution
- Measure mills → Flour with probabilistic yields
- Start seeing flow rates emerge

### End Game
- Complex multi-layer systems
- Multiple mills entangled with large wheat fields
- Carefully tuned icon activation for optimal Hamiltonians
- Strategic layer sees: "System flowing 45.2 flour/sec"
- Faction requests based on flow rates
- Player optimizes quantum computer configurations

### Victory Condition Possibilities
- Achieve target flow rate: "Produce 100 flour/sec for 60 seconds"
- Faction quota fulfillment: "Deliver 10,000 flour over time"
- Network dominance: "Control 80% of market quantum network"
- Hamiltonian mastery: "Build system with 3+ icons in stable configuration"

---

## Open Questions for Larger Brain

1. **Hamiltonian Coupling Strength:** How should icon Hamiltonians affect mill evolution rate? Linear? Quadratic? Threshold-based?

2. **Measurement Frequency:** Should there be a cooldown/cost to measuring mills, or can player spam measurements?

3. **Flow Rate Convergence:** How many measurements needed before flow rate stabilizes? Should early measurements be more uncertain?

4. **Market Network Topology:** Is there one global market network, or multiple regional networks? How do they interact?

5. **Icon Balance:** If Biotic icon powers mills (agrarian), what does Chaos do to mills? Introduce noise/fluctuation? What about Imperium?

6. **Entanglement Limits:** Can one wheat plot be entangled with multiple mills? Can mills entangle with each other?

7. **Conspiracy Activation Effects:** When "growth_acceleration" conspiracy activates, should it directly affect mill flow rates?

8. **Classical-Quantum Feedback:** Should high flow rates attract more icon activation (positive feedback), or deplete icons (negative feedback)?

9. **Visualization:** How to show quantum mill states in QuantumForceGraph? Should they pulse at measurement frequency?

10. **Strategic Layer UI:** What should faction/contract system see? "We need 50 flour/sec for 120 seconds"?

---

## Files Referenced in Research

### Core Quantum System
- `/Core/QuantumSubstrate/DualEmojiQubit.gd`
- `/Core/QuantumSubstrate/EntangledPair.gd`
- `/Core/QuantumSubstrate/EntangledCluster.gd`
- `/Core/QuantumSubstrate/TomatoConspiracyNetwork.gd`
- `/Core/QuantumSubstrate/TomatoNode.gd`

### Icons & Hamiltonians
- `/Core/Icons/IconHamiltonian.gd`
- `/Core/Icons/LindbladIcon.gd`
- `/Core/Icons/BioticFluxIcon.gd`
- `/Core/Icons/ChaosIcon.gd`
- `/Core/Icons/CosmicChaosIcon.gd`
- `/Core/Icons/ImperiumIcon.gd`
- `/Core/Icons/CarrionThroneIcon.gd`

### Game Mechanics
- `/Core/GameMechanics/WheatPlot.gd`
- `/Core/GameMechanics/FarmGrid.gd`
- `/Core/GameMechanics/FarmEconomy.gd`
- `/Core/GameController.gd`

### Visualization
- `/Core/Visualization/QuantumForceGraph.gd`
- `/Core/Visualization/QuantumNode.gd`

---

## Conclusion

The SpaceWheat quantum mill and market system represents a sophisticated computational physics model where:
- **Quantum mechanics** (superposition, entanglement, measurement) drives local farm systems
- **Icon Hamiltonians** power quantum transducers (mills)
- **Repeated measurements** generate probability distributions
- **Classical flow rates** emerge as strategic-level observables
- **Markets** couple local systems to global quantum networks

This creates a game where building and tuning quantum computers (via wheat fields, mills, icons) is the core strategic challenge, with classical resource flows as the computed output.

The implementation requires careful integration of existing quantum substrate (Hamiltonians, entanglement, conspiracy networks) with new mill and market gateway systems, plus a flow rate computation layer bridging quantum probability to classical strategy.

---

**Next Steps:**
1. Larger brain clarifies design questions
2. Specify exact Hamiltonian coupling mechanisms
3. Define market network architecture
4. Implement measurement history tracking
5. Build flow rate computation system
6. Integrate with strategic layer (factions, contracts)

**Agent ID for Resuming Research:** a9c8b70
