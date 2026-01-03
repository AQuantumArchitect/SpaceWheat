# Quick Start - Forest Biome Design Review

## TL;DR

**Problem:** Forest biome spawns 100+ individual mice instead of representing "mouse-ness" as a single concept.

**Goal:** Design a quantum representation where ONE qubit = ONE organism archetype (not individual instances).

**Constraint:** Must use Bloch sphere (theta, phi, radius) and fit existing architecture.

---

## 5-Minute Read Path

### 1. Understand the System (5 min)
Read sections from **01_system_architecture.md**:
- DualEmojiQubit (what is it?)
- Skating Rink Bloch Projection (how it visualizes)
- Three-Layer Evolution (how qubits evolve)

**Key takeaway:** Everything is a qubit with (theta, phi, radius). Visualization projects this to 2D.

### 2. See What Works (5 min)
Read **02_biotic_flux_example.md** - Focus on:
- "Key Entities" section (sun, wheat icon, wheat crops)
- "Evolution Mechanics" section (how sun drives crops)
- "Why This Works" section (design clarity)

**Key takeaway:** BioticFlux has ONE sun driving MANY crops. Each crop is independent. No spawning.

### 3. See What's Broken (5 min)
Read **03_current_forest_implementation.md** - Focus on:
- "Reproduction Logic (THE PROBLEM)" section
- "The Population Explosion Problem" section
- "Comparison to BioticFlux" table

**Key takeaway:** Current forest treats organisms as agents, leading to exponential spawning.

### 4. Understand the Vision (5 min)
Read **04_observed_problem.md** - Focus on:
- "The Platonic Projection Concept" section
- "Example Desired Behavior" section

**Key takeaway:** We want ONE bubble per concept, with radius = population health.

### 5. Engage with the Question (10 min)
Read **05_design_question.md** - Focus on:
- Question 1: What should theta represent?
- Question 4: How to encode predator-prey coupling?
- Question 5: How to handle multi-species interactions?

**Key takeaway:** Open design space. Many possible interpretations. Need external perspective.

---

## Key Comparisons

### What BioticFlux Does (Works ✅)
```
SunQubit (1)
  ↓ drives
WheatQubit (1), WheatQubit (2), WheatQubit (3), ...
  ↓ player harvests
ClassicalWheat resource
```

**Pattern:** One driver, many followers, no auto-spawning.

### What Forest Does Now (Broken ❌)
```
MouseQubit (1)
  ↓ reproduces
MouseQubit_1234, MouseQubit_5678, MouseQubit_9012, ...
  ↓ all reproduce
100+ MouseQubit instances
```

**Pattern:** Exponential spawning of instances.

### What Forest Should Do (Desired ✨)
```
WolfQubit (radius=0.5)  ←→  RabbitQubit (radius=0.7)
  ↑ hunts                      ↓ eaten
  (wolf grows)                 (rabbit shrinks)
```

**Pattern:** Fixed number of qubits, population encoded in radius, dynamics through coupling.

---

## Core Design Questions

### Representation
1. **Theta (polar angle)** = ?
   - Behavioral state?
   - Age distribution?
   - Health status?

2. **Phi (azimuthal angle)** = ?
   - Seasonal cycle?
   - Resource niche?
   - Population phase?

3. **Radius (magnitude)** = Population health/abundance ✓
   - This is the strongest candidate (visually intuitive)

### Dynamics
1. **Predation** = ?
   - Radius transfer (Lindblad layer)?
   - Theta coupling (Hamiltonian layer)?
   - Hybrid approach?

2. **Multi-species** = ?
   - Pairwise coupling matrix?
   - Shared resource pool?
   - Field theory?

3. **Food web topology** = ?
   - Drive coupling strengths?
   - Just documentation?

---

## What We Need

**Input on:**
- What theta/phi should represent for populations
- How to couple organism qubits (Lotka-Volterra → quantum?)
- Analogies from other systems (quantum chemistry? spin systems?)
- Trade-offs between different approaches

**NOT looking for:**
- Code implementation
- Debugging existing code
- Performance optimization

---

## Quick Reference: Bloch Sphere Basics

```
North Pole (θ=0):     north_emoji (e.g., 🌾)
Equator (θ=π/2):      Superposition (🌾↔👥)
South Pole (θ=π):     south_emoji (e.g., 👥)

Phi (φ):              Rotation around axis (phase)
Radius (r):           Purity/coherence/energy

Born Rule:
  P(north) = cos²(θ/2)
  P(south) = sin²(θ/2)
```

**Visualization:**
- Phi → Angular position on oval perimeter
- Radius → Distance from oval center
- Theta → Orientation arrow on bubble

---

## Example Evolution Code (BioticFlux pattern)

```gdscript
# Step 1: Drive celestial anchor
sun_qubit.theta = PI * sin(phase / 2.0)  # Oscillate 0→π

# Step 2: Crops follow sun with spring force
var sun_target = bloch_vector(sun_qubit.theta, sun_qubit.phi)
apply_bloch_torque(wheat_qubit, sun_target, spring_constant, dt)

# Step 3: Energy transfer (separate from rotation)
var alignment = cos²(angle_between(wheat_vector, sun_vector))
wheat_qubit.energy *= exp(base_rate * alignment * sun_brightness * dt)
```

**Question:** How to adapt this pattern for predator-prey?

---

## Files to Dive Deeper

**Conceptual:**
- `01_system_architecture.md` - Full system details
- `02_biotic_flux_example.md` - Complete working example
- `05_design_question.md` - All design questions

**Evidence:**
- `test_out.log` - Working tri-biome output
- `forest_test2.log` - Organism spawn explosion

**Code (in repository):**
- `BioticFluxBiome.gd` - 1258 lines of working physics
- `ForestEcosystem_Biome.gd` - Current problematic approach
- `DualEmojiQubit.gd` - Core quantum state class

---

## Contact / Next Steps

This package is for **external design review**. The documentation intentionally avoids prescribing solutions to enable fresh perspectives.

**Best approach:**
1. Read this quick start
2. Skim the detailed docs for context
3. Think about the design questions
4. Share insights/analogies/alternative interpretations

Thank you!
