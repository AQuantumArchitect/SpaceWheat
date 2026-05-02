# Exotic Topology Mechanics — Tier System

> **Tier 0 and Tier 1 are implemented.** Instant quantum farming (no time grinds) is the
> current design. Berry phase is live in `DualEmojiQubit.gd` and drives glow in `QuantumNode.gd`.
> Tiers 2–6 (strange attractors, topological pipes, Majorana bridges, anyonic braiding,
> knot theory) are future work.

A 6-tier progression from basic farming to reality engineering.
Each tier introduces a new topological concept as a *gameplay mechanic.*

## Tier 0 — Instant Quantum Farming (no time grinds)
Plants appear at full size immediately. Harvest requires measurement first.
Measurement freezes theta drift but not azimuthal phi. The player is a
probability engineer from turn one.

**Key principle:** No maturity timers. State manipulation IS the gameplay.

## Tier 1 — Berry Phase Accumulation
Completing a full parameter cycle (θ: 0 → 2π in any qubit) accumulates
a geometric phase bonus. Berry phase is unbounded; experienced qubits
glow more intensely (phase coefficient 0.2 on visual). 

"Quantum history" as a resource: qubits that have been through more
evolutionary cycles carry more phase, produce richer yields.

## Tier 2 — Strange Attractors
Biome dynamics settle into:
- **Fixed point** → predictable, low variance yields
- **Limit cycle** → rhythmic outputs with timing bonuses
- **Strange attractor** → chaotic, occasional jackpot events

Player can push biomes between attractor states by adjusting the Hamiltonian
(Druid frame) or applying Lindblad pumping (Socialite frame).

## Tier 3 — Topological Insulator Pipes (SSH Model)
Alternating coupling strengths (v, w, v, w...) in a qubit chain.
When |v| < |w|: the system enters a topological phase with **edge protection** —
resources at the edge of the chain conduct robustly even under disorder.

Gameplay: Build long qubit chains across biomes with tuned alternating couplings.
The edge modes are protected from decoherence; the middle is vulnerable.

## Tier 4 — Majorana Bridges (Inter-Biome)
Nonlocal quantum information storage between two biomes.
The Majorana bridge uses only a 2×2 density matrix (not full tensor product),
giving ~90% decoherence resistance.

Information stored in the bridge is accessible from either end but
doesn't "live" in either biome. Inter-biome communication without entanglement overhead.

## Tier 5 — Non-Abelian Anyonic Braiding
Operations that don't commute: (Gate A then Gate B) ≠ (Gate B then Gate A).
Fibonacci anyons with golden ratio structure. Order of operations matters in the farm.

Gameplay: Qubit "threads" that must be braided in the correct sequence to
produce a target state. Wrong order → different (potentially useful?) outcome.

## Tier 6 — Knot Theory & Linking Numbers
The emoji topology graph (see EMOJI_TOPOLOGY_LANGUAGE.md) has knot invariants.
Linking number of two faction entanglement loops determines transfer rate.
Reidemeister moves as optimization: unknot the graph to maximize throughput.

---

## Observation Tools (ready to build)

- **Purity meter** — crystal clarity vs fog
- **Coherence thermometer** — "quantum temperature" of a biome
- **Eigenstate compass** — where the system "wants" to go
- **Entanglement web visualization** — glowing links showing coupling strength and type
