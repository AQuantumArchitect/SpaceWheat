# Biome: Woodlot — Campaign & Tutorial Notes

> **Scope:** open-system Lindblad design reference (DLC-only) — full banner in [docs/biomemissions/README.md](README.md).

**Lore pitch:** Timber country. Axes ring against trunks. Trees become lumber
become firewood become ash. The forest gives and takes, and the cycle turns with
every swing of the blade.

**Physics pitch:** A 6-atom, 3-qubit open system demonstrating a closed production
cycle and sustainable-forestry optimization. The dominant output is ash, not lumber.
The cycle runs — 🌲→🪵→🔥→🍂→🌱→🌲 — and the player's mission is to tune the
axe pump to maximize lumber yield without collapsing tree population. Score 0.003.

---

## The Three Axes (what the player reads)

| Axis | Pole 0 | Pole 1 | Physics role |
|---|---|---|---|
| **Lifestage** | 🌲 tree | 🌱 seedling | Growth axis. Verdant Pulse H: 🌱↔🌲 (0.4). 🌲 pump added (🗑→🌲) to close the full cycle. |
| **Labor** | 🪓 axe | 🪵 lumber | Production axis. Axes are rare (0.002) — the player's lever. 🌲×🪓→🪵 gated channel fires when both are present. |
| **Decompose** | 🔥 fire | 🍂 ash/litter | Combustion output. 🔥→🍂 is the dominant pathway; ash is the cycle's primary product. Wildfire H: 🔥↔🍂 (0.7), 🔥↔🌱 (−0.4). Sacred Flame Keepers: 🔥↔🪵 (0.5). |

---

## What the Biome Does (baseline steady state)

From an empty start:

```
🌲 0.064   🌱 0.286   — seedlings outnumber trees; regrowth phase
🪓 0.002   🪵 0.060   — axes extremely rare; lumber present from direct tree drain
🔥 0.063   🍂 0.506   — ash dominates at 50.6%; fire steady
```

The biome's **largest accumulation is ash**. This is ecologically correct: a managed
forest produces more debris than product. Most timber enters the fire pathway
(🌲→🔥 via Wildfire/Sacred Flame H) rather than the labor pathway (🌲→🪵 via axes).

### Why ash dominates

Three routes lead to 🍂:
1. 🔥→🍂 (primary): fire produces ash continuously (Sacred Flame Keepers: 🔥↔🍂 0.2)
2. 🌿→🍂 (secondary): Verdant Pulse litter pathway
3. 🌱→🌲 cycle leaves litter at each transition

The labor pathway (🌲×🪓→🪵) requires both a tree AND an axe in proximity. From
an empty start, axes are nearly absent (0.002), so the gated channel barely fires.
Almost all 🌲 drains to fire instead.

### The full cycle

```
🗑 → 🌲   (source pump, closes the cycle)
🌲 → 🪵   (via 🪓 gate: Labor)
🌲 → 🔥   (Wildfire/SFK H: fire consumes trees)
🪵 → 🔥   (Sacred Flame Keepers: lumber burns)
🔥 → 🍂   (combustion → ash)
🍂 → 🌱   (Verdant Pulse: litter → seedling, 0.5)
🌱 → 🌲   (Verdant Pulse: succession, 0.4)
```

---

## Player Mission: Balance the Cut

**The problem:** 🪓 (axes) at 0.002 means the labor pathway is starved. Lumber
yield is low; most tree biomass goes to fire.

**The lever:** Pump 🪓 using Tool 1. As axe population rises, the gated 🌲×🪓→🪵
channel fires harder, redirecting tree biomass from fire to lumber.

**The constraint:** Pumping 🪓 too fast harvests 🌲 faster than 🌱→🌲 succession
can replenish it. If 🌲 collapses, the axe pump has nothing to cut — 🪵 output
drops to zero. The fire pathway keeps burning through whatever 🌲 remains until
the forest is gone.

**The optimization:** Find the axe pump rate where lumber output is maximized while
🌲 stays above its regrowth floor (~0.05). This is a real trade-off between
extraction rate and regeneration rate — sustainable forestry as a physics problem.

**What this teaches:** Gated channels are not linear amplifiers. Doubling the
axe population does not double lumber output if trees become scarce. The system
has a carrying capacity, and the player learns to read the steady-state slope.

---

## Faction Landscape

| Faction | Active atoms | What they contribute |
|---|---|---|
| **Sacred Flame Keepers** | 🔥, 🪵, 🍂 | Fire-lumber-ash triangle. Strong 🔥↔🪵 (0.5), 🔥↔🍂 (0.2). The eternal flame consumes timber. |
| **Wildfire** | 🔥, 🌲, 🌿, 🍂, 🌱 | Anti-couples 🔥 to 🌲 (−0.4), 🌱 (−0.4) — fire is the threat to regeneration. 🔥↔🍂 (0.7) — fire makes ash. |
| **Verdant Pulse** | 🌱, 🌲, 🍂 | Succession and litter. 🍂↔🌱 (0.5), 🌱↔🌲 (0.4). The regeneration engine. |

---

## Assay Data

```
🍂 0.506/0.503   (dominant — ash is primary output)
🌱 0.286/0.289
🌲 0.064/0.064
🔥 0.063/0.063
🪵 0.060/0.061
🪓 0.002/0.002
Score: 0.003
```

The near-identical empty/loaded columns (score 0.003) show the Woodlot has almost
no bistability — it reaches the same equilibrium regardless of starting conditions.
The cycle is robust. Only the axe pump rate changes the qualitative outcome.

---

## Cross-Biome Flows

| Direction | Biome | Atoms | Story |
|---|---|---|---|
| incoming | StarterForest | 🌲 | Wild forest supplements the managed stand |
| outgoing | Village | 🪵 | Lumber to the mill and hearth |
| outgoing | Workshop | 🪵 | Lumber to craftspeople |

---

## Implementation Notes

- `Core/Biomes/data/biomes.json` — full L-specs and cross_biome_flows
- 🌲←🗑 pump added to close the regeneration cycle (prior to this, trees depleted
  monotonically and the cycle stalled)
- No empty slots — all 6 atoms active from the start; player extends by importing
  atoms as the 7th+
