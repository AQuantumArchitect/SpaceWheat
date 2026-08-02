# Biome: BioticFlux — Campaign & Tutorial Notes

> **Scope:** open-system Lindblad design reference (DLC-only) — full banner in [docs/biomemissions/README.md](README.md).

**Lore pitch:** The ecological margin between forest and village — the edge where
neither civilization nor wilderness fully dominates. Sun and moon cycle through
wheat and mushroom growth while matter flows between detritus and death. Nothing
here decays. Nothing here ends. Everything is always in flux.

**Physics pitch:** A 6-atom, 3-qubit open system with **no Lindblad terms** —
intentionally empty atom_components. Pure faction H only. Without dissipation,
the density matrix evolves unitarily forever and never reaches a steady state.
This biome is physically alive but ecologically inert: population is conserved,
not dissipated. Score: skipped (assay requires Lindblad).

---

## The Three Axes (what the player reads)

| Axis | Pole 0 | Pole 1 | Physics role |
|---|---|---|---|
| **CelestialCycle** | ☀ sun | 🌙 moon | Sky driver. Celestial Archons H: ε☀=1.0, ε🌙=0.8. ☀↔🌙 coupling (0.025). Without L, the system oscillates between sun and moon with no damping. |
| **Harvest** | 🌾 grain | 🍄 mushroom | Productive output pair. Pollinator Guild H: 🐝↔🌾 (0.6). Mycelial Web H: 🌙→🍄 (0.65). Both channels run; neither dissipates. |
| **Death** | 🍂 litter | 💀 death | Decomposition pair. Mycelial Web chiral H triangle: 🍄↔🍂↔💀 (imaginary couplings). Population rotates around the triangle — the rot clock runs, but nothing actually rots. |

---

## What the Biome Does (and does not do)

**BioticFlux has no Lindblad terms (atom_components is empty).**

Without L operators:
- The density matrix evolves as ρ(t) = e^{−iHt} ρ₀ e^{+iHt}
- This is fully unitary — probability is preserved, not dissipated
- The system oscillates under H indefinitely
- There is no steady state. Ever.

The assay toolkit skips BioticFlux because transition_assay requires a
steady state to compare. The biome runs; it just never arrives anywhere.

### What the player sees

Atoms flicker. Population oscillates between the sky pair, the harvest pair,
and the death pair in patterns governed by Hamiltonian eigenfrequencies. The
Mycelial Web's chiral triangle creates a persistent current — population rotates
around 🍄↔🍂↔💀 slightly faster in one direction. Measuring any site shows
different values on successive ticks.

This is not a bug. This is **unitarity** — the most fundamental property of
quantum mechanics before the environment intervenes.

### Death arrives but isn't processed

An incoming cross_biome_flow from ShrineOfAshes delivers 💀 atoms. In any other
biome with an L term, those deaths would be processed — pumped into 🍂 or 🌱,
beginning the decay cycle. Here there is no L to absorb them. The 💀 amplitude
enters the biome and joins the Hamiltonian oscillation. Death arrives but isn't
absorbed. The margin between forest and village holds the dead without digesting them.

---

## Player Mission: First Contact with Unitarity

**The experience:** explore a biome where measuring changes state but nothing
decays. The player discovers that without L, the biome never reaches equilibrium.
It's always in flux.

**The mission:** add a single Lindblad term — any decay channel. Candidates
(sorted by ecological fit):

| New L term | Rate | Story |
|---|---|---|
| 🍂 → 🌱 | ~0.10 | Litter decomposes into seedlings; the margin begins to cycle |
| 💀 → 🍂 | ~0.15 | Death breaks down; decomposition begins |
| 🌾 → 🍂 | ~0.08 | Harvested grain returns to earth as stubble |

Once any of these is in place, the biome acquires a steady state. Population that
was previously conserved now flows — from the death/litter pair into whatever
downstream site the L term targets. The oscillation damps. BioticFlux settles.

**What this teaches:** Lindblad terms are not just "noise" or "loss." They are
the mechanism by which a quantum system couples to its environment. They are
the physical act of irreversibility. Adding L to BioticFlux is the player's
first act of introducing time's arrow into a reversible space. Before: the forest
margin is in quantum superposition indefinitely. After: it has a preferred direction,
a steady state, a future.

### Alternative mission: measure the eigenfrequencies

Without adding any L, the player can probe BioticFlux by repeated measurement.
The oscillation frequency of ☀↔🌙 is determined by Celestial Archons' diagonal
self-energies (ε☀=1.0, ε🌙=0.8) and their coupling (0.025). The period is
approximately 2π/(ε☀−ε🌙) ≈ 63 ticks — long enough that the player sees a
slow, peaceful oscillation if they watch the sky axis for several seconds.

This is the quantum Zeno effect: rapid measurement slows the oscillation. Slow
or no measurement lets it run free.

---

## Faction Landscape

| Faction | Active atoms | What they contribute |
|---|---|---|
| **Pollinator Guild** | 🐝, 🌾, 🌿, 🌱 | Bee-grain coupling (0.6). 🐝 is not in-biome (no atom_component) but the H couplings are present — if the player introduces 🐝, the grain harvest channel activates instantly. |
| **Mycelial Web** | 🌙, 🍄, 🍂, 💀, 🌱 | Rot clock (chiral H triangle). Moon-mushroom (0.65). The web is fully present in H but none of it dissipates without L. |
| **Celestial Archons** | ☀, 🌙, 🔥, 💧, 🌬 | Sky energy levels. Their self-energy asymmetry (ε☀=1.0 > ε🌙=0.8) sets the eigenfrequency of the celestial oscillation. |

---

## Assay Data

**No assay data.** The biome has no Lindblad terms. The steady-state solver
does not converge; the assay is skipped.

This is intentional. BioticFlux is the only biome in the starter island that
cannot be profiled — it has no equilibrium to measure.

---

## Cross-Biome Flows

| Direction | Biome | Atoms | Story |
|---|---|---|---|
| incoming | ShrineOfAshes | 💀 | Death arrives from the shrine; enters the unitary oscillation without being absorbed |

---

## Implementation Notes

- `Core/Biomes/data/biomes.json` — atom_components is intentionally empty; icons
  define the 3 axis pairs; no L terms
- All 6 emojis (☀, 🌙, 🌾, 🍄, 🍂, 💀) are dormant H atoms — faction H is
  present, physics runs, but no dissipation channel exists
- Player extends this biome by injecting atoms to add new H couplings, or by
  adding the first L term to introduce irreversibility
- ShrineOfAshes is not in the starter island; 💀 cross_biome_flow is latent
