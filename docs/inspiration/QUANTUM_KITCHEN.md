# Quantum Kitchen — GHZ Bread Mechanic

> **Status: The core mechanic is implemented.** `BiomeBellGateTracker.gd` detects spatial
> triplet arrangements and `GAMEPLAY_BELL_GATE_ACTION.md` confirms 20/20 tests passing.
> Bread production from triplet GHZ measurement is live. This doc preserves the
> design rationale and the "🍞 as collapsed GHZ state" framing for future UX work.

The quantum kitchen is a biome (or biome sub-system) where three qubits —
flour (🌾), water (💧), and fire (🔥) — are arranged by the player into a
spatial Bell state pattern. The arrangement IS the quantum gate.
Measuring the entangled triplet produces a bread qubit (🍞).

## The Core Idea

Bread (🍞) is a superposition of its ingredients all in the north state.
Not metaphorically — literally. The bread qubit encodes the quantum history
of what created it in its south emoji: (🌾💧🔥) "memory of entanglement."

This sets a precedent: **🍞 can be considered in-game as a superposition of
flour, water, and fire simultaneously measured into their north states.**
A loaf is a collapsed GHZ state.

## Plot Arrangement → Quantum Gate

Different spatial arrangements of the three input qubits produce different
Bell states and thus different bread properties:

| Shape | Bell State | Theta | Bread Character |
|---|---|---|---|
| Row (horizontal) | GHZ_HORIZONTAL | 0° | Pure bread — clean, high energy |
| Column (vertical) | GHZ_VERTICAL | 45° | Lean bread |
| L-shape | W_STATE | 270° | Input-linked bread — lower energy, more stable |
| T-shape | CLUSTER_STATE | 180° | Computation-ready bread — transforms well |

The player physically positions their plots. No menu, no recipe list.
**Spatial geometry IS the quantum gate.**

## Physics

- Efficiency: 80% of input energy converts to bread energy
- Measurement is stochastic: same ingredients, different timing → different bread
- Fire (🔥) boosts radius (energy magnitude) of the output qubit
- The bread qubit's theta angle encodes which Bell state was used

## Why This Is Great

It makes the abstract concrete. A player discovers that diagonal placement
gives a different loaf than horizontal placement — and the game explains WHY
by showing them the density matrix shift. Spatial puzzle design and quantum
mechanics are unified through the plot grid.

## Implementation Path (Future)

Wire as: a specialized BiomeBase subclass that reads a 3-plot cluster,
detects arrangement geometry → selects Bell state type →
synthesizes_and_exercises a GHZ circuit on those three qubits →
outputs bread qubit into a fourth "output" plot.

The kitchen IS the circuit builder, made physical.
