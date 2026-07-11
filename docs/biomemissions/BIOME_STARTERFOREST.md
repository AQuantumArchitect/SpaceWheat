# Biome: StarterForest — Campaign & Tutorial Notes

> **Scope banner (2026-07-11):** written before the closed-native migration —
> this doc treats open-system Lindblad physics as the working baseline. The
> base game is closed (zero Lindblad operators; see `docs/CLOSED_SYSTEM.md`).
> Valid as design reference for the open / wet-country DLC content only.

**Lore pitch:** A quiet forest edge where celestial cycles drive life. Sun and moon
wheel overhead while predators and prey orbit each other, and the slow succession
from seedling to canopy plays out beneath the humus.

**Physics pitch:** A 12-atom, 6-qubit open system demonstrating Anderson localization
and transport. The forest starts in a locked state — 🌲 at 71% — with almost no
population reaching the animals. The sun qubit is the transport toggle. When ☀ is
active, the food chain opens; when ☀ goes dark, the forest locks back into dormant
canopy. Bistability score 0.114.

---

## The Six Axes (what the player reads)

| Axis | Pole 0 | Pole 1 | Physics role |
|---|---|---|---|
| **CelestialCycle** | ☀ sun | 🌙 moon | Sky driver. ☀ pumped by 🗑→☀ (0.20); ☀→🌿 (0.05) feeds the food chain. 🌙 nearly dark from empty start — no pump yet. |
| **PackHerd** | 🐺 wolf | 🦌 deer | Predator/prey pair. Pack Lords H: 🐺↔🦌 (0.5). Deer graze 🌿; wolves cull deer. |
| **Raptor** | 🦅 hawk | 🐇 rabbit | Aerial predator / fast prey. 🦅↔🐇 (0.5, Pack Lords). Rabbit is the chain's far end — the Anderson sink. |
| **Succession** | 🌱 seedling | 🌲 tree | Growth axis. 🌲 dominates from empty start (71.5%). Verdant Pulse H drives 🌱↔🌲 succession. |
| **Humus** | 🍂 litter | 🌿 herb | Ground layer. 🌿 pumped by ☀; feeds deer and rabbits. Mycelial Web chiral H: 🍄↔🍂↔💀 rot clock. |
| *(singleton)* | 🍄 mushroom | 💀 death | Not a qubit pair; atom_components include both. Mycelial Web couples 🌙→🍄 (0.65) and runs the decomposition triangle. |

---

## What the Biome Does (baseline steady state)

From an empty start:

```
☀ 0.020   🌙 0.019   — sky nearly dark; sun barely lit, moon dormant
🐺 0.013   🦌 0.013   — tiny, nearly equal predator/prey pair
🦅 0.013   🐇 0.008   — raptors slightly outnumber their prey
🌱 0.063   🌲 0.715   — forest locked: 71.5% canopy, 6.3% seedling
🍂 0.041   🌿 0.045   — ground layer thin
🍄 0.021   💀 0.024   — rot cycle present but subdued
```

The forest is **locked**. Almost all population sits in 🌲. The animals survive
at trace levels (~1–2%) because the food chain can't propagate amplitude through
the dense canopy. This is Anderson localization in an ecological system — the tree
site acts as a probability trap.

### Sun as transport toggle

The ☀ pump (🗑→☀ 0.20) was added in a recent balance pass along with a drain
☀→🌿 (0.05). When ☀ is active:

1. ☀ pumps 🌿 (herbs grow in sunlit clearings)
2. 🌿 feeds into 🐇 and 🦌 via Swift Herd H
3. 🦌 and 🐇 feed 🐺 and 🦅 via Pack Lords H
4. Chain carries population from 🌲 (source) all the way to 🐇 (sink)

Without the sun pump, the chain starves at step 1. The entire food web depends
on this single photon input.

### Bistability (score 0.114)

Two attractors coexist:

- **Locked attractor** (from empty): 🌲 heavy, animals at trace, no food chain flow
- **Flowing attractor** (from loaded): animals bright, 🌲 shares population with
  the full ecological web

This is history-dependent. What the forest "remembers" about how it was seeded
determines which attractor it occupies. This is the player's first encounter with
a biome that can be in one of two qualitatively different states.

---

## Player Mission: Open the Food Chain

The forest is in its localized state. Population does not flow from 🌲 to 🐇.
To open transport, the player must activate the sun.

**The chain:** 🌲 → (☀ mediates) → 🌿 → 🦌/🐇 → 🐺/🦅 → 💀 → 🍂 → 🌱 → 🌲

**How to open it:** Pump ☀ using Tool 1 (Hamiltonian) or ensure the 🗑→☀ source
is loaded. Once ☀ exceeds threshold, 🌿 lights up, deer and rabbits emerge, and
the predators appear seconds later. The forest transitions from locked to flowing.

**What this teaches:** Transport in a quantum biome isn't automatic — it requires
an active driving field. The sun is that field. A biome can be structurally complete
(all atoms present, all Lindblad terms wired) and still be ecologically dead because
the energy source is off.

### Second mission: Wire the Night

🌙 sits at 0.019 — almost zero. The Mycelial Web faction uses 🌙→🍄 (0.65), but
without a Lindblad pump on 🌙, the moon never brightens. The mission is to add a
single L term: 🗑→🌙 (rate ~0.15). Once the moon is pumped, a night cycle emerges:
fungal bloom grows at night, decomposes litter, returns nutrients to 🌱. Sun and
moon become complementary phases of a day/night driver.

---

## Faction Landscape

| Faction | Active atoms | What they contribute |
|---|---|---|
| **Pack Lords** | 🐺, 🦌, 🦅, 🐇, 💀 | Full predator-prey coupling. Strong 🐺↔🐇 (0.6), 🦅↔🐇 (0.5). Death coupled to all animals (0.3–0.4). |
| **Swift Herd** | 🐇, 🦌, 🌿 | Grazer coupling: 🌿↔🦌 (0.62), 🌿↔🐇 (0.55). Self-energies give 🌿 a slight elevation above deer. |
| **Wildfire** | 🔥, 🌿, 🌲, 🍂, 🌱 | Anti-couples 🔥 to 🌲 (−0.4), 🌿 (−0.35), 🌱 (−0.4) — fire threatens regeneration. No 🔥 pump here so Wildfire is latent; it activates if the player introduces fire. |
| **Celestial Archons** | ☀, 🌙 | Diagonal self-energies (ε☀=1.0, ε🌙=0.8). Weak ☀↔🌙 (0.025) — they coexist rather than compete. |
| **Mycelial Web** | 🌙, 🍄, 🍂, 💀, 🌱 | Rot clock: chiral H triangle 🍄↔🍂↔💀. Moon-mushroom coupling 🌙↔🍄 (0.65). |
| **Verdant Pulse** | 🌱, 🌲, 🌿, 🍂 | Succession chain: 🌱↔🌿 (0.6), 🌱↔🌲 (0.4). Litter returns to seedling via 🍂↔🌱 (0.5). |

---

## Assay Data

From empty start:

```
☀ 0.020/0.029   🌙 0.019/0.026
🐺 0.013/0.018  🦌 0.013/0.017
🦅 0.013/0.020  🐇 0.008/0.012
🌱 0.063/0.084  🌲 0.715/0.601   ← bistable 0.114
🍂 0.041/0.060  🌿 0.045/0.065
🍄 0.021/0.029  💀 0.024/0.034
```

The two columns are empty-start vs. loaded-start steady states. 🌲 drops from
71.5% to 60.1% in the loaded case as population redistributes across the food web.

---

## Cross-Biome Flows

| Direction | Biome | Atoms | Story |
|---|---|---|---|
| incoming | Woodlot | 🌲 | Timber country feeds tree population here |
| outgoing | TrappersCamp | 🐇 | Rabbit population exported to trappers |

---

## Implementation Notes

- `Core/Biomes/data/biomes.json` — L-specs and cross_biome_flows source
- Sun pump (🗑→☀ 0.20) and drain (☀→🌿 0.05) added in balance pass
- 🌙 has no source pump yet — night cycle is a player-buildable extension
- 11 atom_components (🌲 atom_component present, 💀 is in atom_components; no separate 🌙 atom — the icon pair is CelestialCycle ☀|🌙 with both present)
