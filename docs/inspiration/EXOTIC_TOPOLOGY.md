# Exotic Topology Mechanics — Tier System

> **Audited, promoted to a campaign, and SHIPPED, 2026-07** — see
> `docs/TOPOLOGY_CAMPAIGN.md` ("What Survives"): four chapters live across acts 1–4,
> staged on StarterForest, FreshwaterSpring, Lanternfall, and the Operator/Druid
> frames. Per-tier fates from the audit:
> - **Tier 0** shipped — it *is* the game's foundation.
> - **Tier 1** shipped deeper than this doc claims: `BerryPhaseRegister` integrates true
>   signed solid angle, with ripeness, harvest counters, story-flag predicates, and
>   faction whispers. Campaign Chapter 1 adds the teaching arc.
> - **Tier 2** was mostly built while nobody was looking: attractor state + eigenvalue
>   gap, dynamics tracker, five quest predicates, duration trackers — the Village arc
>   already uses them. Reframed honestly for the enclave (closed systems have no
>   attractors; the spectrum is conserved) as Chapter 2, *The Pond Holds Its Depths*.
> - **Tier 3** needs **no engine work**: H is built from icons, icons author
>   cross-couplings, so a dimerized SSH chain is pure data. Chapter 3, the crown.
> - **Tier 5** demonstrable today with shipped gates; needs only an order-sensitive
>   `gate_order` predicate. Chapter 4.
> - **Tiers 4 & 6** (Majorana bridges, knots) and **true chaos** were reserved for the
>   open door — noted in `docs/inspiration/OPEN_SYSTEM_ACT2.md`. **Both tiers are now
>   SHIPPED** as "What Connects" (`docs/CONNECT_CAMPAIGN.md`, via the
>   `docs/ENGINE_FRONTIER.md` plan): the bridge as a standalone 2×2 ρ with emergent
>   Γ-product protection (`BridgeRegister`), the knot as Berry-loop path records +
>   mutual-winding invariants on the Berry lift (`KnotRegister`). All six tiers of
>   this document are live. Chaos alone stays in the seed bank.
>
> **Tier 7 — Gauge & Holonomy — added and SHIPPED, 2026-08-10** as the fourth
> campaign lane, "What Turns" (`docs/GAUGE_CAMPAIGN.md`): a Z₂/U(1) lattice
> gauge ledger over each biome's coupling graph (`GaugeField` — gauge
> transforms, Wilson loops, tree gauge fixing, β₁), reference-qubit
> interference revealing the spinor sign flip of a ripe Berry loop, the
> closure-honesty pass on the S³ lift (`gauss_linking` refuses open lifts),
> and the deliberate demotion of mutual winding from "invariant" to
> "attackable diagnostic". The tier this document never dared to write down:
> *which of your numbers are bookkeeping, and which belong to the world.*

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
(Druid frame) or applying Lindblad pumping (Spark frame).

### Quest Framing

Attractor control is already a strong quest shape:

- **Steer to attractor**: help a biome settle into its dominant basin and hold it there long enough to register as intentional play.
- **Heal attractor**: perturb a biome, then restore the same basin after the system has been knocked out of shape.

This works with present-day game tech, not future hardware. The game already has:

- live attractor snapshots from the biome runtime,
- purity / eigenvalue-gap style metrics,
- explicit player actions that act as control inputs,
- and a quest system that can watch threshold crossings over time.

That means the quest can be implemented as a simple controller loop:

1. Read current attractor state.
2. Compare it to the target basin.
3. Let the player apply gates, pumps, drains, or time skips.
4. Award completion when the live metrics hold steady for long enough.

No exotic runtime is required. The “future” part is mostly in the framing: the player is learning to shape the dynamics, not just to click through a checklist.

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
The emoji topology graph (see `archive/docs/architecture/EMOJI_TOPOLOGY_LANGUAGE.md`) has knot invariants.
Linking number of two faction entanglement loops determines transfer rate.
Reidemeister moves as optimization: unknot the graph to maximize throughput.

---

## Observation Tools (ready to build)

- **Purity meter** — crystal clarity vs fog
- **Coherence thermometer** — "quantum temperature" of a biome
- **Eigenstate compass** — where the system "wants" to go
- **Entanglement web visualization** — glowing links showing coupling strength and type
