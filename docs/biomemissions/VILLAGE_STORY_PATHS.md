# Village — Story Paths & Island Wiring

This doc maps all viable "5th qubit" choices for Village, the cross-biome
flows that wire it to circle 1 and circle 2, and the story each path tells.

Village currently has 8 emojis (4 qubits). 6 is the UI maximum. Adding
one pair (2 atoms) fills the 5th qubit and leaves the 6th open for the
player to slot in from their inventory — the customisation slot.

---

## What's already flowing INTO Village (but has no register)

Before choosing a 5th qubit, note three cross-biome flows that are already
wired in the data but currently have no register to land in:

| Source | Atoms | Story |
|---|---|---|
| **FreshwaterSpring** | 💧 | Spring water from upstream; Hearth Keepers H couples it to 🔥, 🍞, 👥 |
| **Woodlot** | 🪵 | Felled timber from the managed forest |
| **Apiary** (circle 2) | 🫙 🌾 | Honey + grain from the beekeepers; Apiary is fed by PastoralCommons |

These flows arrive at Village's Lindblad runtime but go nowhere because
🪵, 🌾, 🫙 aren't in Village's emoji register. **Adding any of them as a
5th qubit closes a real physical circuit, not just a lore one.**

---

## Dormant atom menu (Village's 4 native factions)

Atoms in Village's factions that aren't in the biome yet:

| Atom | Faction | H into Village atoms | Also appears in |
|---|---|---|---|
| 🏭 factory | Millwright's | ⚙↔0.65, 🍞↔0.55, 💨↔0.52, 👥↔**−0.2** | — |
| 🔨 hammer | Millwright's | 🔨↔⚙=0.5 | — |
| ⛓ chains | Void Serfs | 👥↔⛓=**0.7** | — |
| 💸 debt | Void Serfs | 💸↔👥=0.5, 💸↔💀=0.3 | — |
| 💀 death | Void Serfs | 💀↔👥=−0.22, 💀↔💸=0.3 | StarterForest, BioticFlux |
| 💧 water | Hearth Keepers | 💧↔🍞=0.5, 💧↔🔥=0.2, 💧↔👥=0.3 | FreshwaterSpring (flow source) |
| 🏜️ desert | Hearth Keepers | 🏜️↔🔥=0.3, 🏜️↔🍞=**−0.35** | — |
| 🌱 seedling | Granary Guilds | 🌱↔💰=0.32 | StarterForest, Woodlot |

---

## The Story Paths

Each path = one 5th qubit (2 atoms), a dominant physics character, and a
description of what the player's 6th slot does to extend or subvert it.

---

### Path A — The Water Mill `💧 | 🏜️` *Environment: Wet vs Dry*

FreshwaterSpring's outgoing flow gets a register to land in. With 💧,
Hearth Keepers H mediates fire and bread through water (💧↔🍞=0.5,
💧↔🔥=0.2). The spring feeds the mill pond. Flip to 🏜️ and drought hits:
fire runs hotter (🏜️↔🔥=0.3), bread collapses (🏜️↔🍞=−0.35).

**Physics:** water gives fire and ice a shared resource to compete over,
which sharpens the hearth bistability toward what we originally wanted.
The Wet↔Dry axis becomes the environmental dial behind village prosperity.

**Circle wiring:** FreshwaterSpring → Village 💧 (already wired).
Flipping the spring dry has a physical effect on the village now.

**6th slot extensions:**
- 🪣 (Irrigation Jury, circle 2 via FreshwaterSpring): water management
- 🧊 (bring ice from FreshwaterSpring): freeze the mill pond; force fire mode
- ⛓: drought enables exploitation — add bondage when the village is parched

---

### Path B — The Factory `🏭 | ⛓` *Industry: Machine vs Labor*

The darkest structural path. Millwright's H makes 🏭 the production hub
(⚙↔0.65, 🍞↔0.55, 💨↔0.52) — the mill fully industrialises. But
🏭↔👥=−0.2 displaces workers, and ⛓↔👥=0.7 binds the displaced ones.
These two forces are coupled: automation and bondage rise together.

**Physics:** 🏭 creates a new dominant pole for production output, pulling
population from ⚙/💨/🍞. The −0.2 anti-coupling to 👥 means labor and
factory are in tension. Adding ⛓ (strongest coupling in the biome at 0.7)
then captures the displaced workers.

**Circle wiring:** Woodlot → Village 🪵 flows in; if 🏭 is present, the
mill now has industrial fuel. StarterForest trees → Woodlot lumber →
Village factory is a full three-biome chain.

**6th slot extensions:**
- 💸: add debt (Void Serfs triad complete: factory→chains→debt→death)
- 🔨: resistance — craftspeople pushing back against the factory
- 💀: full Void Serfs arc; factory, bondage, and mortality co-present

---

### Path C — The Artisan Guild `🔨 | 🌱` *Craft: Forge vs Field*

The gentler counter to Path B. The blacksmith (🔨↔⚙=0.5) drives the mill
by skilled hand. The Granary Guilds invest coin in seedlings
(🌱↔💰=0.32) — growth from the ground up. No factory, no chains. The
village functions through craft and careful agriculture.

**Physics:** 🔨 gives a second lever on the mill axis without automation's
negative labor coupling. 🌱 draws Granary H into the agricultural cycle:
money → seeds → the economy is rooted in cultivation rather than industry.

**Circle wiring:** 🌱 appears in both StarterForest and Woodlot. Adding it
to Village makes the seedling the literal connection between forest, managed
land, and village market — the grain pipeline made visible.

**6th slot extensions:**
- 💧: wholesome + water; the spring feeds the gardens. Utopian.
- 🏭: morally loaded upgrade. Player can industrialise from artisan baseline,
  watching what it costs (labor coupling changes).
- 🌾 (from Apiary flow): Apiary grain arrives into an agricultural village
  that has registers to receive it.

---

### Path D — Debt and Ruin `💸 | 💀` *Consequence: Debt vs Death*

The Void Serfs' full economic catastrophe. 💸 drains money from people
(💸↔👥=0.5) and connects toward death (💸↔💀=0.3). 💀 repels labor
(💀↔👥=−0.22). The village is a crisis scenario: baskets pile up
(preservation attractor) while coin hemorrhages outward.

**Physics:** this creates a second negative-coupling axis in the biome.
👥 is simultaneously repelled by 💀 (existing) and attracted to 💸 (at
0.5). The labor pool is caught between two drains. The Commerce bistability
shifts: from empty start, 🧺 + 💀 co-dominate (cold and dying).

**Circle wiring:** 💀 appears in StarterForest (Pack Lords' mortality) and
BioticFlux (receives 💀 from ShrineOfAshes). A death flow from the
forest edges into the village is narratively coherent: the wilderness
mortality that wolves and eagles represent eventually reaches the settlement.

**6th slot extensions:**
- ⛓: complete the Void Serfs triad (debt→chains→death). Darkest possible
  village.
- 💰: redemption arc — inject coin to reverse the debt spiral. With 💰
  flowing in, Granary H drives 💰↔🍞 (0.58) and commerce recovers.
- 💧: spring water as the counter — life force against death.

---

### Path E — The Steam Age `💧 | 🏭` *Production: Water vs Factory*

An optimistic industrial path. 💧 feeds hearth (💧↔🔥=0.2) and bread
(💧↔🍞=0.5) while 🏭 processes everything into output. The mill runs on
steam — water in, production out. The negative 🏭↔👥=−0.2 is softened by
💧↔👥=0.3 (water as commons good).

**Physics:** this is the path most likely to sharpen the hearth bistability.
💧 gives 🔥 and ❄ a shared fluid resource to compete over — the mechanism
that can create a hard fire/ice attractor switch. With 💧 as mediator,
the Hearth Keepers H (🔥↔❄=0.8 Rabi mixing) gets a dampener: water absorbs
some of the mixing energy before it washes out the polarisation.

**Circle wiring:** FreshwaterSpring → Village 💧 (flow active). Woodlot →
Village 🪵 (has a register only if player adds 🪵 separately). The spring
powers the steam mill; the lumber heats the boiler.

**6th slot extensions:**
- 🔨: steam-powered forge; blacksmith + factory coexist.
- ⛓: factory + steam + chains = full industrial dark arc.
- 🧊 (from FreshwaterSpring): freeze the boiler — shuts down production.

---

### Path F — The Forge Town `🔨 | 🏭` *Transition: Craft to Industry*

The industrial revolution as a single qubit. Pole 0 = 🔨 (craft, hand
tools, small-scale mill). Pole 1 = 🏭 (factory, automation, displacement).
The qubit measures where the village economy sits on that transition. The
player can push it either direction, experiencing the coupling changes.

**Physics:** both atoms are in Millwright's H. 🔨↔⚙=0.5 (craft drives
the mill), 🏭↔⚙=0.65 (factory drives the mill harder). The factory's
anti-coupling to 👥 (−0.2) means the two poles have genuinely different
consequences for labor — flipping from craft to factory isn't symmetric.

**6th slot extensions:**
- ⛓: factory pole → bondage arrives naturally.
- 💧: water democratises both (mill pond benefits all). Water mediates.
- 💸 + 💀: full consequence chain for the factory pole.

---

### Path G — Blessed Commons `💧 | 🌱` *Source: Spring vs Seed*

The utopian path. Spring water flows in (FreshwaterSpring → Village 💧)
and seeds are planted (🌱↔💰=0.32 — Granary investment). The village is
fed by both its watershed and its own agriculture. No factory, no chains.

**Physics:** this is the lowest-drama option but the highest
cross-biome connectivity — 💧 brings the spring in, 🌱 connects to
the forest and woodlot. Three islands are wired together through real
flows. Commerce (🧺|💰) runs warmly in the background.

**Circle wiring:** most wired path in the set.
- FreshwaterSpring → Village 💧 (flow active)
- 🌱 appears in StarterForest (seedling in forest succession) + Woodlot
  (seedling grows into 🌲 via the regrowth loop)

**6th slot extensions:**
- 🔨: add craft to the commons (wholesome).
- 🏭: the enclosure — player can industrialise the commons, watching
  whether 🌱 survives (does seed-money coupling hold under factory pressure?).
- 🌾: Apiary's grain arrives into a village that can grow it.

---

### Path H — Liberation `🔨 | ⛓` *Justice: Craft vs Bondage*

The craftsman versus the labor system. ⛓↔👥=0.7 is the strongest
coupling in the biome when chains are present — it dominates the labor
axis. 🔨↔⚙=0.5 is the alternative: skilled work that doesn't require
bondage. The qubit literally measures whether the village runs on free
craft or bound labor.

**Physics:** the H pulling 👥 toward ⛓ is very strong (0.7). To keep
labor free (high 🔨, low ⛓), the player must actively maintain the
🔨 side — pump craft, drain chains. Neglect it and the Void Serfs H
naturally slides everyone toward bondage.

**6th slot extensions:**
- 💀: liberation or ruin — free workers or they die.
- 🏭: factory as the third option (beyond craft or chains).
- 💧: water as a social good that weakens the chain coupling.

---

### Path I — Timber Village `🪵 | 🌾` *Harvest: Lumber vs Grain*

**The most physically wired path.** Both atoms are already flowing into
Village from neighbors — they just have no register. Adding this qubit
activates two pre-existing circuits simultaneously.

| Flow | Source | What it means |
|---|---|---|
| 🪵 | Woodlot (cross_biome_flow already live) | Lumber arrives and burns in the hearth |
| 🌾 | Apiary (cross_biome_flow already live) | Grain arrives and feeds the mill |

Wire 🪵→🔥 in L (lumber burns: small `lindblad_outgoing: {🔥: 0.05}`)
and 🌾→🍞 (grain grinds: `lindblad_outgoing: {🍞: 0.04}`). Suddenly the
village hearth and bakery are fed by upstream work. The food chain becomes:

```
StarterForest → Woodlot 🪵 → Village 🔥 (hearth)
PastoralCommons bees → Apiary 🌾 → Village 🍞 (bakery)
FreshwaterSpring → Village 💧 (mill pond)
```

Three starter-island biomes physically driving the village's two key outputs.

**Physics:** 🪵 and 🌾 have no Village faction H coupling (no native
faction covers them). They function as pure resource inputs — their
population is entirely controlled by how much upstream biomes produce.
The village becomes economically downstream, not self-sufficient.

**6th slot extensions:**
- 🏭: village industrialises its timber+grain supply (combines with Path I
  naturally: factory processes both inputs faster).
- ⛓: upstream resources + bondage = classic resource extraction economy.
- 💧: closes the spring/timber/grain triangle (FreshwaterSpring, Woodlot,
  Apiary all feeding one place).

---

## Cross-Biome Wiring Map

### Circle 1 (starter island)

| Source | → Village | Mechanism | Register status |
|---|---|---|---|
| FreshwaterSpring | 💧 | cross_biome_flow live | **Path A/E/G activate it** |
| Woodlot | 🪵 | cross_biome_flow live | **Path I activates it** |
| BioticFlux | — | pure H; no flow to Village | — |
| PastoralCommons | — | no direct flow to Village | (indirect via Apiary) |
| StarterForest | — | no direct flow to Village | 🌱/💀 narrative echoes |

### Circle 2 (neighbors of the island)

| Biome | Shared with | → Village | Notes |
|---|---|---|---|
| **Apiary** | PastoralCommons, FreshwaterSpring | 🫙 🌾 (flow live) | Honey + grain; Path I receives 🌾 |
| **VillagePocket** | Granary Guilds, Hearth Keepers | downstream of Village | Commerce output biome; receives 💰/🍞 |
| **TrappersCamp** | StarterForest (Pack Lords) | — | Has 🌱+💀; forest mortality chain |
| **Harbor** | FreshwaterSpring (Irrigation Jury) | 💧 echo | Spring water reaches the sea |
| **ShrineOfAshes** | Woodlot (Sacred Flame Keepers) | 💀 → BioticFlux | Death from ash reaches the pure-H space |

### The full upstream chain (most wired scenario)

```
StarterForest (🌲 source)
  └─ cross_biome_flow ──► Woodlot (🌲→🪵→🔥 cycle)
                            └─ cross_biome_flow ──► Village 🪵 (hearth fuel)

FreshwaterSpring (🧊 source → 💧)
  ├─ cross_biome_flow ──► Village 💧 (mill pond)
  └─ cross_biome_flow ──► PastoralCommons 💧
                            └─ bees ──► Apiary
                                         └─ cross_biome_flow ──► Village 🌾 (grain)

Village (5 qubits + 1 open slot)
  └─ commerce output ──► VillagePocket (circle 2)
```

Path I (🪵|🌾) is the only path that makes all three upstream flows
land simultaneously. It's the "well-connected" default.

---

## Recommendation

For the designed default (pre-player customisation), **Path I** wires the
most cross-biome physics with the least invented fiction — the flows are
already there. Leave the 6th slot for the player's choice from Paths
A–H, which lets them decide: water mill, factory, artisans, dark arc, etc.

The designed story progression could be:
1. Player discovers Village is downstream (lumber arrives, grain arrives,
   water arrives — they see the flows even without understanding them).
2. First mission: add the Timber+Grain qubit so the flows land. Village
   "wakes up" as the regional hub.
3. Second mission: choose the 6th qubit from the path menu above. That
   choice defines their village's character for the rest of circle 1.
