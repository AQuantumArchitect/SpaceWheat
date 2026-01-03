# SpaceWheat Quantum Biome System - Architecture Overview

## Core Concept
SpaceWheat is a farming game where quantum mechanics drive gameplay. Players plant crops that exist as quantum superpositions and evolve according to Bloch sphere physics.

## Fundamental Building Block: DualEmojiQubit

Every entity in the game is represented by a **DualEmojiQubit** - a quantum state on the Bloch sphere with two emoji poles:

```gdscript
class DualEmojiQubit:
    north_emoji: String    # e.g., "🌾" (wheat)
    south_emoji: String    # e.g., "👥" (labor)

    # Bloch sphere coordinates
    theta: float          # Polar angle (0 to π)
    phi: float            # Azimuthal angle (0 to 2π)
    radius: float         # Distance from origin (0 to 1)

    # Semantic quantum state
    energy: float         # Growth/health
    berry_phase: float    # Accumulated evolution

    # Topology graph (pure emoji relationships)
    entanglement_graph: Dictionary  # {"🍴": ["🐰"], "💧": ["☀️"]}
```

**Born Rule Probabilities:**
- North probability: `cos²(θ/2)`
- South probability: `sin²(θ/2)`

When measured (harvested), the qubit collapses to one pole based on these probabilities.

---

## Visualization System: Skating Rink Bloch Projection

The entire visualization is a 2D projection of 3D Bloch sphere physics:

```
Phi (φ) → Angular position around oval perimeter
Radius (r) → Distance from oval center
Theta (θ) → Visual orientation indicator (arrow on bubble)
```

Each biome is rendered as an oval "skating rink" where quantum bubbles:
1. Are attracted to their `phi` angle position on the perimeter (like skaters on a track)
2. Are pushed outward from center proportional to their `radius`
3. Show their `theta` orientation as a directional indicator

---

## Biome System Architecture

### BiomeBase (Abstract Parent)
All biomes extend this base class:

```gdscript
class BiomeBase:
    quantum_states: Dictionary        # Vector2i → DualEmojiQubit

    # Visual properties for oval rendering
    visual_color: Color
    visual_center_offset: Vector2     # Position in graph
    visual_oval_width: float
    visual_oval_height: float

    # Core methods (override in subclasses)
    func _update_quantum_substrate(dt: float)  # How biome evolves qubits
    func get_biome_type() -> String
```

### Three-Layer Evolution Architecture

All biomes evolve qubits through three layers:

1. **Hamiltonian Layer (Unitary)**
   - Pure rotations on Bloch sphere
   - Changes θ and φ only
   - Reversible quantum evolution

2. **Lindblad Layer (Open System)**
   - Energy transfer (changes radius/energy)
   - Decoherence/dissipation
   - Irreversible environmental coupling

3. **Measurement Layer (Discrete)**
   - Player actions (planting, harvesting, measuring)
   - Collapse to classical outcome

---

## Entanglement Graph: Pure Emoji Topology

Instead of hardcoded class hierarchies, relationships are expressed as emoji edges:

```
Predation:    🐺 → {"🍴": ["🐰", "🐭"]}     # Wolf hunts rabbit and mouse
Escape:       🐰 → {"🏃": ["🐺", "🦅"]}     # Rabbit flees wolf and eagle
Consumption:  🐰 → {"🌱": ["🌿", "🌲"]}     # Rabbit eats seedlings
Production:   🐺 → {"💧": ["☀️"]}           # Wolf produces water
Reproduction: 🐰 → {"👶": ["🐰"]}           # Rabbit reproduces
Transformation: 🏜️ → {"🔄": ["🌱"]}        # Bare ground becomes seedling
```

This allows pure topological reasoning without class hierarchies.

---

## Physics Simulation vs Visual Representation

**Critical distinction:**

- **Physics layer**: Qubits evolve according to biome Hamiltonians
- **Visualization layer**: QuantumForceGraph renders the current state

The visualization is a *display* of the quantum state, not the source of truth. The Bloch sphere coordinates drive the visuals, not vice versa.
