# Biome: FreshwaterSpring — Campaign & Tutorial Notes

> **Scope:** open-system Lindblad design reference (DLC-only) — full banner in [docs/biomemissions/README.md](README.md).

**Lore pitch:** Source water wells up from deep stone. Ice melts at the margins.
Bubbles rise and pop in an instant. This is where water begins its journey through
the world — fundamental, flowing, feeding everything downstream.

**Physics pitch:** A 6-atom, 3-qubit open system demonstrating source-biome
dynamics and cross-biome hub topology. The spring feeds four downstream biomes.
🌿 dominates — water feeds plant life, not the other way around. Score 0.003.

---

## The Three Axes (what the player reads)

| Axis | Pole 0 | Pole 1 | Physics role |
|---|---|---|---|
| **Phase** | 🧊 ice | 🔥 fire | Temperature axis. 🧊 is the primary reservoir (22.6%). 🗑→🧊 pump (0.30) — "ice wells up from deep stone." Celestial Archons H: ε☀=1.0, 🔥↔💧 anti-coupled (−0.4). |
| **Scale** | 💧 drop | 🌊 wave | Volume axis. 💧 at 13.3%, 🌊 at 9.0%. Celestial Archons H: 🌙↔💧 (0.5), 🌬↔💧 (0.6). Water scale spans single drops to wave. |
| **Cycle** | 🫧 bubble | 🌿 herb | Ephemeral/growth axis. 🌿 dominant at 31.6% — water feeds plant life. 🫧 at 2.7% — bubbles appear and vanish instantly (fast L decay). |

---

## What the Biome Does (baseline steady state)

From an empty start:

```
🧊 0.226   🔥 0.111   — cold source dominant; fire present but secondary
💧 0.133   🌊 0.090   — water present at both scales
🫧 0.027   🌿 0.316   — bubbles ephemeral; plant life is largest accumulation
```

**🌿 dominates at 31.6%.** The spring isn't a water biome — it's a growth biome
powered by water. The Pollinator Guild H and Terrarium Collective H both push
hard on 🌿 (couplings 0.55–0.6 range), and the spring's abundant 💧 feeds that
channel. Plant life outweighs the water that sustains it.

### The 🔥 anomaly

🔥 at 11.1% in a water biome looks wrong. It's physically coherent:

- Celestial Archons H runs 🔥↔🌬 (0.5), 🔥↔⛰ (0.3) — fire is the element of
  heat, not combustion; it co-exists with water as thermal energy
- 💧→🔥 outgoing cross_biome_flow to Harbor (0.08) models evaporation energy —
  water heating to steam, thermal differential driving coastal dynamics
- Irrigation Jury H: 💧↔⚖ (0.6), with 💧→🔥 anti-coupled (−0.6) — the Jury
  actively routes water away from heat, but the coupling produces a shared steady
  state rather than eliminating 🔥

The spring contains a small persistent fire — geothermal, thermal from sunlight
on the surface pool, or evaporative energy. It's not burning; it's warm.

### Bubbles as a probe qubit

🫧 at 2.7% is intentionally ephemeral. Bubbles have a fast decay term — they
appear briefly from dissolved gases and pop. Because 🫧 decays rapidly, it carries
information about the current state of the water (dissolved oxygen, carbonic acid,
temperature) but doesn't accumulate. A player measuring 🫧 repeatedly sees a
different reading each time — the variance is the signal.

---

## Player Mission: Follow the Water

The spring is a hub. Water from here reaches four downstream biomes.

**Cross-biome map:**

```
FreshwaterSpring ──💧──→ Village        (mill pond, cooking water)
FreshwaterSpring ──💧──→ PastoralCommons (meadow irrigation)
FreshwaterSpring ──💧🌊→ TidalPools     (freshwater input to tidal mix)
FreshwaterSpring ──💧🧊→ Harbor         (cold fresh water meets salt)
```

The player's mission is to trace each path: find the downstream biome, measure
what 💧 becomes when it arrives. In Village it becomes bread; in PastoralCommons
it becomes meadow; in TidalPools it becomes salinity gradients.

**What this teaches:** Cross-biome flows are directional but not absolute. 💧
doesn't disappear from the spring when it flows to Village — probability amplitude
leaks across the boundary at a defined rate. The spring is a source; it
continuously produces what the downstream sinks consume.

### Second mission: Water Rights

Add ⚖ (Irrigation Jury) to the spring's atom_components. ⚖ in the Jury's H
anti-couples to 🔥 (−0.6) and strongly couples to 💧 (0.6). Its presence
creates a governance layer: water rights as a physical force, reducing thermal
waste and increasing directed flow to 🌱 (🪣↔🌾 via 🌱 coupling 0.4).

This introduces a social structure to an abiotic biome. The spring produces water
whether or not there are laws about it. With ⚖ present, who gets the water changes
the steady-state distribution.

---

## Faction Landscape

| Faction | Active atoms | What they contribute |
|---|---|---|
| **Celestial Archons** | ☀, 🌙, 🔥, 💧, 🌬 | Elemental H substrate. Sky-element couplings drive the thermal and water dynamics. Self-energies create energy hierarchy: ε☀=1.0 > ε🌙=0.8 > ε🔥=0.6 > ε💧=0.3. |
| **Irrigation Jury** | 💧, ⚖, 🌱, 🪣 | Water governance. 💧↔⚖ (0.6), 💧→🔥 (−0.6, anti-coupled). Not in-biome by default — player introduces them via ⚖ injection. |
| **Terrarium Collective** | 🌿, 💧, 🫙, ♻️ | Closed-loop ecology. 🌿↔💧 (0.38), 🌿↔🫙 (0.6). Drives the plant-water coupling that makes 🌿 dominant. |
| **The Submersed** | 🌊, 🪸, 🦀, 🐠 | Reef-tenders. Chiral H: 🌊↔🪸 ([0.35, 0.4] complex) — underwater physics with imaginary coupling. Their atoms (🪸, 🦀, 🐠) aren't in-biome yet; 🌊 is the bridge. |

The Submersed's complex H coupling on 🌊↔🪸 is the only chiral term in this biome.
If the player introduces 🪸 (coral), the 🌊 site acquires a persistent current —
a quantum rotation that carries information about the underwater ecosystem into the
surface spring. This is a mechanic for connecting fresh and salt water.

---

## Assay Data

```
🌿 0.316/0.319   (dominant — water feeds growth)
🧊 0.226/0.225   (cold reservoir)
💧 0.133/0.133
🔥 0.111/0.110
🌊 0.090/0.089
🫧 0.027/0.027
Score: 0.003
```

Score 0.003 is correct for a source biome: peaceful, unique, always flowing. The
near-identical empty/loaded columns confirm monostability — the spring reaches the
same state regardless of history.

---

## Cross-Biome Flows

| Direction | Biome | Atoms | Story |
|---|---|---|---|
| outgoing | Village | 💧 | Mill pond and drinking water |
| outgoing | PastoralCommons | 💧 | Meadow irrigation |
| outgoing | TidalPools | 💧, 🌊 | Freshwater input to tidal system |
| outgoing | Harbor | 💧, 🧊 | Cold freshwater meets salt; thermal dynamics |

---

## Implementation Notes

- `Core/Biomes/data/biomes.json` — full L-specs and cross_biome_flows
- 🧊←🗑 pump (0.30) added to fix pump-starvation — prior to this, ice depleted
  and the entire Phase axis collapsed, starving the water chain
- No incoming cross_biome_flows — this is a true source node in the watershed graph
- ⚖ and 🌾 can be added by the player to introduce Irrigation Jury governance
