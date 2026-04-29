# Biome: PastoralCommons — Campaign & Tutorial Notes

**Lore pitch:** Flocks graze on common land. Bees drift between wildflowers.
Porridge simmers over low fires while gentle hands shape the future. A peaceful
place — but peace is fragile, and predators are always circling.

**Physics pitch:** An 8-atom, 4-qubit open system demonstrating Lotka-Volterra
predation, nonlinear harvest gating, and an emergent commons. Wolf outnumbers
sheep in steady state. The commons atom (🤲) is the rarest — it only exists when
everything else is thriving. Score 0.005.

---

## The Four Axes (what the player reads)

| Axis | Pole 0 | Pole 1 | Physics role |
|---|---|---|---|
| **Predation** | 🐑 sheep | 🐺 wolf | LV predation: wolf presence drains sheep (rate 1.5). Wolf outnumbers sheep in steady state (0.130 vs 0.068). |
| **Pollination** | 🐝 bee | 🌿 herb | Pollination axis. Pollinator Guild H: 🐝↔🌿 (0.55). Meadow is the energy source (🗑→🌿 pump 0.6). |
| **Harvest** | 🥣 porridge | 🫙 honey jar | Output axis. 🫙 dominant (0.189) — stored goods lead. 🥣 fills nonlinearly from abundant meadow. |
| **Commons** | 🤲 hands | 🌾 grain | 🤲 near zero from empty start (0.000/0.005). Commons only exists when the system is well-loaded. |

---

## What the Biome Does (baseline steady state)

From an empty start:

```
🐑 0.068   🐺 0.130   — wolf outnumbers sheep; predators dominate
🐝 0.155   🌿 0.080   — bees active; meadow is consumed by pollinators
🥣 0.140   🫙 0.189   — storage leads; porridge building up
🤲 0.000   🌾 0.166   — commons absent; grain present but not shared
```

The headline result: **wolves outnumber sheep**. In a standard Lotka-Volterra
system you expect prey-heavy steady states. Here the LV drain is asymmetric enough
(rate 1.5 on sheep, 🐺 self-sustains via Pack Lords / Swift Herd H) that wolves
reach near-twice-sheep population. Ecologically accurate for an overgrazed common —
the predators have eaten the grazing buffer.

### Why 🤲 is zero

The commons is a high-order emergent state. It requires:
- Meadow sufficiently loaded (🌿 above threshold)
- Bees actively pollinating (🐝 above threshold)
- Grain accumulation (🌾 present from cross-biome flow or Verdant Pulse H)
- All three together sustaining the gating condition for 🤲

From an empty start, the system bootstraps slowly. By the time 🐺 drain suppresses
🐑, the harvest chain hasn't yet accumulated enough to satisfy the commons gate.
The loaded-start case shows 0.005 — the commons is just barely present.

This is intentional design: the commons cannot be forced. It appears only when the
underlying ecosystem is healthy and balanced.

---

## Player Mission: The Commons

**The problem:** 🤲 is near-zero. It represents shared, collective life — and
it doesn't exist yet.

**The path:** The commons is not built directly. The player creates conditions:
1. Ensure 🌿 stays well-pumped (🗑→🌿 0.6 is already in place)
2. Import 🌾 or let Verdant Pulse H build grain from 🌱
3. Manage the 🐺/🐑 predation balance — if wolves collapse sheep entirely,
   the grazing pressure on 🌿 drops, which starves the pollination chain
4. Let 🫙 accumulate; the storage surplus is the precondition for 🤲

**What this teaches:** Some quantum states are not directly injectable. They are
attractors of a functioning system. The player learns to read indirect indicators
(🌿 bright, 🐝 active, 🫙 full) as proxies for the condition they actually want.

### Second mission: Reduce the wolves

Wolf at 0.130, sheep at 0.068. The pasture is being overhunted. The player can:
- Drain 🐺 via Tool 2 (Lindblad sink on wolves)
- Import 🐑 (from a livestock biome) to boost prey population
- Add a 🐑 pump to close the sheep regeneration loop

With 🐑 population restored, grazing pressure on 🌿 increases (Swift Herd H),
meadow cycles faster, bees flourish, harvest rises — and 🤲 appears with higher
probability.

---

## Faction Landscape

| Faction | Active atoms | What they contribute |
|---|---|---|
| **Pollinator Guild** | 🐝, 🌿, 🌾, 🌱 | Bee-meadow coupling (0.55), bee-grain (0.6). Energy flows from bees to harvest. |
| **Verdant Pulse** | 🌱, 🌿, 🌾, 🍂 | Green growth cycle. 🌿↔🌱 (0.6), grain↔litter. Seedling path is dormant here (no 🌱 pump) but the H is present. |
| **Yeast Prophets** | 🫙, 🥣 | Fermentation physics: 🫙↔🥣 coupling (0.6), storage-to-porridge conversion. Probabilistic harvest reading — the Prophets read futures in the jar. |
| **Swift Herd** | 🐇, 🦌, 🌿 | Grazing pressure. 🌿↔🦌 (0.62), 🌿↔🐇 (0.55). Active even without deer/rabbit present — their H adds green pressure to 🌿. |
| **Scythe Provosts** | 🌱, ⚔, 🛡, 🏇 | Estate guards. Their combat atoms (⚔, 🛡, 🏇) aren't in-biome, but 🌱 H coupling is dormant here. Can be activated if the player introduces conflict. |

---

## Assay Data

```
🫙 0.189/0.187   (dominant — stored goods lead)
🐝 0.155/0.154
🌾 0.166/0.165
🥣 0.140/0.139
🐺 0.130/0.129
🌿 0.080/0.080
🐑 0.068/0.068
🤲 0.000/0.005
Score: 0.005
```

Score 0.005 reflects the 🤲 bistability: the commons flickers in only under the
loaded-start condition. Everything else is monostable — the predation/harvest
balance reaches the same point from either start.

---

## Cross-Biome Flows

| Direction | Biome | Atoms | Story |
|---|---|---|---|
| incoming | FreshwaterSpring | 💧 | Water feeds the meadow |
| outgoing | Apiary | 🐝, 🫙 | Bees and honey to the dedicated hive |
| outgoing | WeaversLoft | 🧵 | Wool pathway (WeaversLoft not in current island) |

---

## Implementation Notes

- `Core/Biomes/data/biomes.json` — full L-specs and cross_biome_flows
- LV predation drain on sheep (rate 1.5) was added in balance pass
- Harvest gating added: 🥣 fills nonlinearly from abundant meadow
- 🌿 pump (🗑→🌿 0.6) is the biome's primary energy input
- WeaversLoft outgoing noted in data but that biome is not in the current starter island
