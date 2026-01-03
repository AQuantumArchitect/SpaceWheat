# Observed Problem: Agentic vs Conceptual Simulation

## The Core Issue

**Quote from developer:**
> "While physically accurate, the current forest is spawning a hundred mice. That concept should be handled in quantum energy to the mouse quantum emoji abstraction. We're not doing agentic simulations, we're doing **conceptual simulation**. Like... the biome is the **platonic projection** of the hypothetical actual forest."

---

## What We See in Tests

### Test Output (test_out.log)
```
🌍 BioticFlux | Temp: 400K | ☀️111.7° | 🌾45.0° | Energy: 0.4 | Qubits: 6
   👶 🐭 reproduces! (created offspring #1)
   👶 🐰 reproduces! (created offspring #1)
      🌱 Spawned 🐰_3761242001 (🐰/🌱)
      🌱 Spawned 🐭_932369244 (🐭/🌾)
   👶 🐰 reproduces! (created offspring #1)
🌍 BioticFlux | Temp: 303K | ☀️26.4° | 🌾45.0° | Energy: 0.9 | Qubits: 6
      🌱 Spawned 🐰_3747983186 (🐰/🌱)
```

**Problem indicators:**
1. Unique instance IDs: `🐰_3761242001`, `🐭_932369244`
2. Repeated spawn messages
3. Population growing every frame
4. Each organism is a separate Node instance

---

## Visualization Problem

### What We Want to See
```
Forest Biome Oval:
  🐺 (single bubble) - represents "wolf-ness" / predator pressure
  🐰 (single bubble) - represents "rabbit-ness" / prey abundance
  🦅 (single bubble) - represents "eagle-ness" / apex predation
  🐭 (single bubble) - represents "mouse-ness" / small prey
```

### What We Actually See
```
Forest Biome Oval:
  🐺 (1 bubble)
  🐰 (1 bubble)
  🐰_3761242001 (1 bubble)
  🐰_3747983186 (1 bubble)
  🐰_8492615037 (1 bubble)
  🐰_1029384756 (1 bubble)
  ... (100+ more bubbles)
```

The visualization becomes cluttered with individual agents instead of showing the archetypal concepts.

---

## The Platonic Projection Concept

### Traditional Agent-Based Model (What We Have)
```
Forest = {
    Wolf_1 {position, health, hunger},
    Wolf_2 {position, health, hunger},
    Rabbit_1 {position, health, fear},
    Rabbit_2 {position, health, fear},
    ...
}

Update: Each agent acts independently
Result: Emergent population dynamics
```

### Platonic Projection Model (What We Want)
```
Forest = {
    WolfQubit {theta, phi, radius},      # radius = wolf population health
    RabbitQubit {theta, phi, radius},    # radius = rabbit abundance
    MouseQubit {theta, phi, radius},     # radius = mouse population
    ...
}

Update: Qubits interact via Hamiltonian coupling
Result: Population dynamics encoded in qubit evolution
```

---

## Conceptual Analogy

Think of it like weather forecasting:

### Agent-Based (Current Forest)
Track every water molecule individually:
- Molecule_1 position, velocity, energy
- Molecule_2 position, velocity, energy
- ... (10^23 molecules)

### Field Theory (Desired Forest)
Model aggregate properties:
- Temperature field T(x,y,z,t)
- Pressure field P(x,y,z,t)
- Humidity field H(x,y,z,t)

**We want field theory, not particle tracking.**

---

## Why This Matters for Gameplay

### Current System (Agentic)
- Player sees: 100 mouse bubbles bouncing around
- Mental model: "There are 100 individual mice"
- Interaction: Click individual mouse to interact?
- Harvest: Kill individual mouse?

### Desired System (Conceptual)
- Player sees: 1 mouse bubble with radius 0.8 (large = abundant)
- Mental model: "The mouse population is thriving"
- Interaction: Affect the mouse concept (introduce predator, reduce food)
- Harvest: Extract some "mouse energy" (reduce radius)

**The conceptual model is:**
1. **Cleaner visually** (fewer bubbles)
2. **More abstract** (matches game's quantum theme)
3. **More meaningful** (radius = population health is intuitive)

---

## The Technical Challenge

How do we encode predator-prey dynamics in qubit evolution without spawning agents?

**Requirements:**
1. One qubit per organism type (🐺, 🐰, 🐭, 🦅)
2. Population dynamics emerge from qubit interactions
3. Predation = energy flow between qubits
4. Reproduction = radius growth (not spawning new instances)
5. Death = radius decay (not removing instances)

**Constraints:**
1. Must use Bloch sphere coordinates (theta, phi, radius)
2. Must fit into existing three-layer architecture (Hamiltonian, Lindblad, Measurement)
3. Must visualize meaningfully in skating rink projection

---

## Example Desired Behavior

### Initial State
```
Wolf:   theta=0,    phi=0,      radius=0.3  (low population)
Rabbit: theta=PI/2, phi=PI,     radius=0.7  (abundant)
Mouse:  theta=PI/2, phi=3*PI/2, radius=0.6  (moderate)
```

### After 10 seconds (Wolves hunt)
```
Wolf:   theta=PI/4, phi=0,      radius=0.5  (↑ ate rabbits, population grows)
Rabbit: theta=PI/2, phi=PI,     radius=0.4  (↓ predation pressure)
Mouse:  theta=PI/2, phi=3*PI/2, radius=0.8  (↑ no predation, thriving)
```

### After 20 seconds (Rabbits recover)
```
Wolf:   theta=0,    phi=0,      radius=0.6  (stable)
Rabbit: theta=0,    phi=PI,     radius=0.7  (↑ recovered, plenty of food)
Mouse:  theta=PI/2, phi=3*PI/2, radius=0.5  (↓ rabbits competing for food)
```

**Visualization:** Three bubbles smoothly changing size and position, not hundreds of bubbles spawning/dying.

---

## Open Questions

1. How to encode predator-prey coupling in Hamiltonian terms?
   - Lotka-Volterra as qubit interactions?
   - Food web edges as coupling coefficients?

2. What does theta represent for a population?
   - Behavioral state (aggressive ↔ passive)?
   - Age distribution (young ↔ old)?
   - Spatial distribution (scattered ↔ clustered)?

3. What does phi represent?
   - Seasonal cycle phase?
   - Resource preference?
   - Migration pattern?

4. How to handle multiple organism types interacting?
   - N qubits, N×N coupling matrix?
   - Multi-qubit entanglement states?

5. How to preserve food web topology?
   - Keep entanglement_graph edges?
   - Translate edges to coupling strengths?

---

## What We Need

**Not prescriptive solutions**, but:
- External perspective on design approaches
- Analogies from other quantum/population systems
- Insights on what theta/phi/radius should represent
- Ideas for encoding dynamics without agents
