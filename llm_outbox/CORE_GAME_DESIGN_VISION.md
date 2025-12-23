# SpaceWheat: Core Game Design Vision

**Date**: 2025-12-14
**Status**: Canonical Design Document
**Purpose**: Define the fundamental gameplay loop and philosophy

---

## Central Concept: The Quantum-Classical Divide

SpaceWheat is fundamentally about **negotiating the boundary between quantum potentiality and classical actuality**.

### The Two Realms

#### **Quantum Realm** (Pre-Measurement)
- **Nature**: Flowing, pulsating, organic "liquid neural net"
- **Visuals**: Glowing energy flows, entanglement lines, superposition states
- **Mechanics**: Energy evolution, Icon modulation, entanglement topology
- **Player Activity**: Cultivation, tuning, shaping potential
- **Time Scale**: Continuous evolution (every frame)

**This is where you PLAY.**

#### **Classical Realm** (Post-Measurement)
- **Nature**: Concrete, discrete, statistical
- **Visuals**: Numbers, currencies, discrete items, stats
- **Mechanics**: Resources, inventory, economy
- **Player Activity**: Spending, building, unlocking
- **Time Scale**: Discrete events (harvests, trades)

**This is where you HARVEST.**

### The Divide

**Measurement** is the bridge - the moment of collapse where quantum potential becomes classical reality.

```
Quantum State         Measurement           Classical Outcome
(Superposition)  ───────────>  (Collapse)  ───────────>  (Definite Value)
  🌾👥                 Harvest                   🌾 or 👥
  Flowing Energy       Observation              Currency/Stats
  Potential            Choice                   Actuality
```

---

## Core Gameplay Loop

### 1. **Quantum Cultivation** (Pre-Measurement Gameplay)

**Goal**: Shape the quantum field to create advantageous states for measurement.

**Mechanics**:
- **Place wheat plots** → Create DualEmojiQubits (🌾/👥 superposition)
- **Create entanglements** → Build topology (max 3 per plot)
- **Bring Icons to farm** → Modulate quantum evolution
  - Wheat items → Activate Biotic Flux Icon (growth, order)
  - Tomato items → Activate Chaos Icon (transformation, mutation)
  - Market items → Activate Imperium Icon (control, extraction)
  - *Void/Nothing* → Activate Cosmic Chaos Icon (decoherence, noise)
- **Watch energy flows** → Quantum states evolve continuously
- **Tune topology** → Discover knot patterns for bonuses
- **Resist decoherence** → Maintain coherence against entropy

**Visuals**:
- Pulsating glow halos around plots
- Energy flowing along entanglement lines
- Color spectrum from topological invariants
- Rhythmic breathing/oscillation of the field
- Particle systems showing quantum flow

**This phase is about POTENTIAL**: You're not producing wheat yet, you're cultivating a quantum field that COULD produce wheat when measured.

---

### 2. **Observation Choice** (The Moment of Measurement)

**Goal**: Decide WHEN and WHAT to measure for optimal harvest.

**Strategic Questions**:
- Is the topology good? (Check Jones polynomial, bonus multiplier)
- Is decoherence low? (Check purity, coherence)
- Which plots should I harvest? (Local topology analysis)
- What's the expected value? (North probability × yield_🌾 + South probability × yield_👥)

**Mechanics**:
- **Hover over plot** → Show measurement probabilities
  - P(🌾) = cos²(θ/2) = "Natural growth probability"
  - P(👥) = sin²(θ/2) = "Labor-enhanced probability"
- **Click to harvest** → Trigger measurement
  - Collapse superposition → Definite outcome
  - Apply local topology bonus
  - Break entanglements (or preserve based on protection)
  - Propagate collapse to entangled partners
- **Collect yield** → Classical resources added to inventory

**Visuals**:
- Dramatic flash/pulse on measurement
- Quantum glow fades → Classical sprite appears
- Numbers float up showing yield
- Entanglement lines break (with particle effects)

---

### 3. **Classical Economy** (Post-Measurement)

**Goal**: Spend harvested resources to improve your quantum farm.

**Mechanics**:
- **Currency**: Wheat (natural), Labor tokens (👥), Quantum coherence
- **Purchases**:
  - More wheat plots → Expand quantum field
  - Icon items → Modulate physics (tomatoes, market goods, void artifacts)
  - Upgrades → Better entanglement, slower decoherence
  - Tools → Measurement aids, topology analyzers

**This phase is DISCRETE**: You're working with definite resources, not quantum potential.

---

## Icon System: Modulating Quantum Physics

Icons are **environmental modifiers** that change how the quantum field evolves based on what you bring to the farm.

### Icon Activation

Icons activate **proportionally to abundance** of related items:

```gdscript
# Example: Biotic Flux Icon
var wheat_count = count_items_of_type("wheat")
var activation = wheat_count / max_wheat_count  # 0.0 to 1.0

biotic_flux_icon.set_activation(activation)

# Icon modulates conspiracy network evolution
for node in conspiracy_network.nodes:
    icon.modulate_node_evolution(node, delta)
```

**The more wheat you have, the stronger the "agrarian order" physics becomes.**

### The Four Primary Icons

#### 🌾 **Biotic Flux** (Agrarian Order)
- **Activated by**: Wheat, natural items, sunlight
- **Effect**:
  - Enhances growth rate (positive θ drift)
  - Reduces chaos/decoherence
  - Stabilizes superposition states
- **Physics**: Order, predictability, coherence
- **Visual**: Green-golden glow, smooth flows

#### 🍅 **Chaos Vortex** (Tomato Conspiracy)
- **Activated by**: Tomatoes, mutant crops, strange items
- **Effect**:
  - Increases phase velocity (fast φ rotation)
  - Creates exotic topologies
  - Higher variance in measurement outcomes
- **Physics**: Transformation, unpredictability, mutation
- **Visual**: Red-orange swirl, turbulent flows

#### 🏰 **Carrion Throne** (Imperium)
- **Activated by**: Market goods, currency, authority items
- **Effect**:
  - Extracts energy (negative θ drift)
  - Increases measurement yields but degrades field
  - Market optimization
- **Physics**: Control, extraction, efficiency
- **Visual**: Purple-gold, geometric patterns

#### 🌌 **Cosmic Chaos** (Outer Void) ← **NEW**
- **Activated by**: Void, absence, darkness, entropy
- **Effect**:
  - Introduces decoherence (noise in quantum state)
  - Random phase kicks
  - Degrades entanglement over time
  - Increases uncertainty
- **Physics**: Entropy, noise, the collapse toward classicality
- **Visual**: Black-purple tendrils, static, dissolving patterns

**Gameplay**: The Outer Void is always present (entropy is universal), but you can RESIST it by:
- High protection topologies (decoherence resistance)
- Biotic Flux Icon (order counters chaos)
- Strategic measurement (collapse before decoherence destroys value)

---

## Decoherence Mechanics

### What is Decoherence?

The gradual loss of quantum coherence - superposition states decay toward classical states over time.

```gdscript
# Every frame, quantum states degrade
func apply_decoherence(delta):
    var base_rate = 0.01 * delta

    # Cosmic Chaos Icon increases decoherence
    var chaos_modifier = 1.0 + cosmic_chaos_icon.get_activation() * 2.0

    # Topology protection reduces decoherence
    var topology = analyzer.get_current_topology()
    var protection_modifier = 1.0 - (topology.pattern.protection_level / 20.0)

    var actual_rate = base_rate * chaos_modifier * protection_modifier

    for plot in wheat_plots:
        plot.quantum_state.partial_collapse(actual_rate)
```

### Visual Decoherence

- Superposition glow gradually fades
- Entanglement lines dim and flicker
- Colors desaturate (move toward gray)
- Particle flows slow down
- Visual "static" increases

### Gameplay Implications

**Decoherence creates URGENCY**:
- You can't cultivate quantum states forever
- Must harvest before decoherence destroys value
- High protection topologies last longer
- Strategic choice: Harvest now (low bonus) or wait (higher bonus but more decoherence risk)

---

## Production Mechanics: Local Topology Bonuses

### Option 2 (Selected): Local Topology + Option B (Decoherence Resistance)

Each plot's production is affected by its **local entanglement neighborhood**.

```gdscript
func harvest_plot(plot: WheatPlot) -> float:
    # 1. Get local network (this plot + entangled neighbors within radius)
    var local_plots = get_local_network(plot, radius=2)

    # 2. Analyze local topology
    var local_topology = topology_analyzer.analyze_entanglement_network(local_plots)

    # 3. Measure quantum state (collapse)
    var result = plot.quantum_state.measure()

    # 4. Calculate base yield
    var growth_factor = plot.growth_progress  # 0.0 to 1.0 over time
    var base_yield = 10.0 * growth_factor

    # 5. Quantum state modifier
    var state_modifier = 1.5 if result == "👥" else 1.0  # Labor = 1.5x

    # 6. Local topology bonus
    var topology_bonus = local_topology.bonus_multiplier  # 1.0x to 3.0x

    # 7. Final yield
    var final_yield = base_yield * state_modifier * topology_bonus

    # 8. Break entanglements (measurement effect)
    plot.quantum_state.break_all_entanglements()

    return final_yield
```

### Why Local Topologies?

**Pros**:
- Different parts of farm can have different strategies
- Granular optimization ("this cluster is for high yield, that cluster is for stability")
- Harvesting one plot doesn't destroy entire farm
- More interesting spatial gameplay

**Example**:
```
Farm Layout:

  [A]─[B]─[C]           [X]─[Y]
   │   │   │             │   │
  [D]─[E]─[F]           [Z]─[W]

Left cluster: 6-node complex topology (J=8.2, bonus=2.1x)
Right cluster: 4-node ring (J=4.4, bonus=1.6x)

Harvesting plot E:
- Affects local topology [A,B,C,D,E,F]
- Doesn't affect [X,Y,Z,W]
- Player can maintain stable topologies in different zones
```

---

## Energy Flow Focus (Pre-Measurement)

The core gameplay is **NOT** about harvesting wheat. It's about **cultivating quantum fields**.

### What You're Actually Doing

**Before measurement, wheat doesn't exist yet.** You're working with:

1. **Quantum States** (Bloch sphere positions)
   - θ = polar angle (🌾 ↔ 👥 superposition)
   - φ = azimuthal phase (hidden quantum information)
   - Visualized as glow intensity, color, pulsation

2. **Energy Flows** (Hamiltonian evolution)
   - Icons modulate evolution (bias toward certain states)
   - Conspiracy network creates complex dynamics
   - Visualized as flowing particles along lines

3. **Entanglement Networks** (Topology)
   - Creating links between plots
   - Discovering patterns (knots, rings, exotic structures)
   - Visualized as glowing connection lines

4. **Coherence** (Purity vs. Decoherence)
   - Maintaining quantum-ness against entropy
   - High coherence = bright, pure colors
   - Low coherence = dim, noisy, gray
   - Visualized as glow strength, saturation

### The "Liquid Neural Net" Aesthetic

The quantum farm should feel **ALIVE**:

- **Breathing**: Plots pulse in sync (synchronized evolution)
- **Flowing**: Energy streams along entanglement lines
- **Rippling**: Perturbations propagate through network
- **Harmonizing**: Different Icons create different flow patterns
  - Biotic Flux: Smooth, laminar, golden flow
  - Chaos: Turbulent, swirling, red-orange eddies
  - Imperium: Geometric, angular, purple rays
  - Cosmic Chaos: Static, dissolving, dark tendrils
- **Responding**: Player actions cause ripples (placing plot, creating entanglement)

### Pre-Measurement Gameplay Activities

1. **Experimenting with topology** - "What if I connect these three plots?"
2. **Icon balancing** - "Too much chaos, need more wheat for order"
3. **Watching patterns emerge** - "Oh! That's a toric structure forming!"
4. **Timing the harvest** - "The Jones polynomial is rising... wait for it... NOW!"
5. **Fighting decoherence** - "Need to harvest before the void corrupts this"

**It's like tending a garden of POTENTIAL**, not a garden of plants.

---

## Measurement as Harvest: The Strategic Moment

### What Measurement Does

1. **Collapses superposition** → Definite outcome
2. **Breaks entanglement** → Local topology degrades
3. **Extracts classical value** → Quantum → Currency
4. **Affects neighbors** → Collapse propagates

### Strategic Depth

**You must choose WHEN to harvest**:

**Harvest Early**:
- ✅ Low decoherence (pure state)
- ✅ Preserve entanglement network
- ❌ Low growth progress (less yield)
- ❌ Low topology bonus (simple patterns)

**Harvest Late**:
- ✅ High growth progress (more yield)
- ✅ High topology bonus (complex knots formed)
- ❌ High decoherence (degraded state)
- ❌ Risk losing coherence entirely

**The player must find the OPTIMAL moment** - that's the skill expression.

---

## Summary: The Full Loop

```
┌─────────────────────────────────────────────────────────┐
│ QUANTUM REALM (Continuous Play)                         │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  1. Place plots → Create qubits in superposition        │
│                                                          │
│  2. Create entanglements → Build topology               │
│     └─> Discover knot patterns                          │
│                                                          │
│  3. Bring items to farm → Activate Icons                │
│     └─> Icons modulate quantum evolution                │
│                                                          │
│  4. Watch energy flows → Pulsating neural net           │
│     └─> Grow quantum potential over time                │
│                                                          │
│  5. Fight decoherence → Cosmic Chaos degrades field     │
│     └─> High protection topologies resist               │
│                                                          │
│  6. Choose WHEN to harvest → Strategic timing           │
│                                                          │
└─────────────────────────────────────────────────────────┘
                            │
                            │ MEASUREMENT
                            ▼
┌─────────────────────────────────────────────────────────┐
│ CLASSICAL REALM (Discrete Events)                       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  7. Collapse → Quantum state becomes classical          │
│     └─> 🌾👥 → 🌾 or 👥                                 │
│                                                          │
│  8. Calculate yield → Growth × State × Topology         │
│     └─> Convert to currency/resources                   │
│                                                          │
│  9. Break entanglement → Local topology degrades        │
│                                                          │
│  10. Spend resources → Buy items, upgrades              │
│      └─> Bring items back to farm (Icons)               │
│                                                          │
└─────────────────────────────────────────────────────────┘
                            │
                            │ ITEMS → ICONS
                            ▼
                    (Loop back to step 3)
```

---

## Design Pillars

1. **Quantum is Play, Classical is Harvest**
   - You play in the quantum realm (continuous, flowing)
   - You harvest into the classical realm (discrete, concrete)

2. **The Divide is the Game**
   - Strategic decision: WHEN to collapse potential into actuality
   - Tension: Wait for better topology vs. decoherence risk

3. **Energy Flows, Not Resources**
   - Pre-measurement gameplay is about energy, potential, flows
   - Resources only exist post-measurement

4. **Icons Shape Physics**
   - What you bring to the farm changes HOW physics works
   - Wheat → order, Tomatoes → chaos, Void → entropy

5. **Topology is Emergent Strategy**
   - No prescribed patterns, pure mathematical reward
   - Player discovers optimal configurations through play

6. **Liquid Neural Net Aesthetic**
   - Organic, flowing, pulsating, alive
   - Not mechanical, not discrete, not static

---

## Implementation Priorities

### Core Mechanics (Must Have)
- [x] DualEmojiQubit with Bloch sphere
- [x] Entanglement system (max 3)
- [x] Bell pairs and collapse propagation
- [x] Parametric TopologyAnalyzer
- [x] Icon Hamiltonian modulation
- [ ] **Decoherence mechanics** ← NEW
- [ ] **Cosmic Chaos Icon** ← NEW
- [ ] **Local topology production calculation** ← NEW
- [ ] Measurement/harvest with local bonus
- [ ] Icon activation from item counts

### Visual Systems (High Priority)
- [x] Entanglement lines (basic)
- [ ] Energy flow particles along lines
- [ ] Pulsating glow halos
- [ ] Color from topological invariants
- [ ] Decoherence visual degradation
- [ ] Measurement flash/collapse animation
- [ ] Icon-specific visual effects (flow patterns)

### Polish (Nice to Have)
- [ ] Synchronized breathing/pulsation
- [ ] Ripple effects from player actions
- [ ] Topology diagram overlay
- [ ] Real-time Jones polynomial display
- [ ] Codex of discovered topologies

---

## Philosophical Note

SpaceWheat is a game about **observation**.

In quantum mechanics, observation is not passive - it's an *act of creation*. Before you look, the wheat both exists and doesn't exist. Your observation *makes it real*.

The player is not a farmer growing wheat.
The player is an **observer collapsing quantum potential into classical reality**.

The wheat is Schrödinger's crop. 🌾📦⚛️
