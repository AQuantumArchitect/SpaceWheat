# Biome: Village — Campaign & Tutorial Notes

**Lore pitch:** A farming settlement where fire and ice battle for the hearth,
labor produces bread, and gears grind flour into commerce.

**Physics pitch:** An 8-atom open system demonstrating autocatalytic phase
competition, a two-attractor Commerce bistability, and a player-buildable
industrial arc. The village starts cold and stuck in a preservation economy;
a druid gate flip wakes the mill and switches it to warm commerce mode.

---

## The Four Axes (what the player reads)

| Axis | Pole 0 | Pole 1 | Physics role |
|---|---|---|---|
| **Hearth** | 🔥 fire | ❄ ice | Atmospheric poles. Both have autocatalytic pumps (bread→fire, basket→ice). Hearth Keepers H has a strong 🔥↔❄ Rabi coupling (0.8) that mixes them too fast for a hard bistable flip — fire stays soft-dominant due to self-energy bias (ε🔥=0.8, ε❄=−0.3). An X-gate on Hearth shifts the atmosphere but doesn't latch. |
| **Labor** | 👥 people | 🍞 bread | People produce bread (H coupling 0.6 via Hearth Keepers, 0.45 via Millwright's). The dominant axis by population — bread is what the village makes. |
| **WindMill** | ⚙ gear | 💨 wind | Mill coupling: Millwright's Union drives ⚙↔💨 (H 0.6). Both show strong bistability (diff 0.065 / 0.056) — the mill either runs or doesn't depending on starting conditions. |
| **Commerce** | 🧺 basket | 💰 coin | **The actual bistable axis (score 0.186).** Preservation mode (🧺 dominant, from empty start) vs. commerce mode (balanced 🍞/⚙/💨, from loaded start). Granary Guilds H drives 💰↔🍞 (0.58) and 💰↔🧺 (0.5). |

---

## What the Biome Does (baseline steady state)

From an empty start:
```
🔥 0.025   ❄  0.004   — hearth barely lit; fire soft-dominant
👥 0.246   🍞 0.152   — people active, bread building up
⚙  0.011   💨 0.102   — mill mostly idle (gear low)
💰 0.038   🧺 0.414   — preservation economy: baskets dominate
```

From a full load:
```
🔥 0.003   ❄  0.001   — hearth cold (autocatalysis hasn't kicked in)
👥 0.207   🍞 0.220   — people and bread balanced
⚙  0.077   💨 0.194   — mill running! (wind-gear channel active)
💰 0.070   🧺 0.228   — commerce mode: mill producing, coin circulating
```

The village lives in two qualitatively different modes. The empty-start attractor
is a quiet, subsistence economy — baskets of stored goods, low mill activity.
The loaded-start attractor is a functioning mill town — wind drives gears, gears
process grain, coin circulates.

### Why the hearth doesn't flip hard

The Hearth Keepers faction carries a Hamiltonian coupling 🔥↔❄ = 0.8 — the
second-strongest coupling in the entire faction. This creates rapid Rabi mixing
between fire and ice: any polarization the Lindblad builds up gets coherently
rotated back before it can accumulate. The autocatalytic pumps (bread→fire, power
25.0; basket→ice, power 25.0) ARE large enough to sustain themselves, but they
can't outrun the H-mixing. The hearth is warm or cool, not hot or frozen.

**The design implication:** fire and ice are atmospheric texture, not the hard
switch. The hard switch is on **Commerce**.

---

## Player Mission: Wake the Mill (the light switch)

**The mechanic:** An X gate on the Commerce qubit (🧺|💰) flips 🧺↑ → 💰↑.
With coin circulating, Granary Guilds H drives 💰↔🍞 (0.58) and 💰↔🧺 (0.5),
and Millwright's H drives ⚙↔💨 (0.60) — the whole mill economy activates.
The wind picks up, the gear turns, bread produces.

**Why it latches:** the Commerce bistability (0.186) means this is a stable
attractor. After the X-gate kick, the system settles into the commerce mode
and stays there. This IS the light switch. Kicking back (X again) returns to
the preservation attractor.

**Sequence to teach:**
1. Player observes the cold village (basket full, mill idle).
2. Tutorial hints: "the mill has two modes. Look at what Commerce is doing."
3. Player discovers the X gate on Commerce qubit.
4. Mill activates. Wind/gear visibly brighten. Bread climbs.
5. Player flips back. Village quiets. "Now you control the village economy."

---

## Autocatalysis: how bread feeds fire

The 🍞→🔥 pump uses a `gated_lindblad_source`:

> **extra flux into 🔥 = 25.0 · ρ(🔥)² · ρ(🍞)**

This is autocatalytic: fire feeds itself from bread, proportional to how much
fire already exists. Above a threshold (~ρ(🔥) > 0.03 with ρ(🍞)~0.15), the
gain exceeds the drain and fire self-sustains. Below threshold, fire decays.

The bread reservoir needs population to fuel this (🍞 ← 🗑 at 0.3). A full
bread bin feeds a hot hearth; empty pantry = cold village.

🧺 (baskets) runs the symmetric mechanism → ❄ (ice):
> **extra flux into ❄ = 25.0 · ρ(❄)² · ρ(🧺)**

**Player hook:** if the player drains 🍞 (via Tool 2, Lindblad drain), the fire
autocatalysis collapses. Village goes cold even if the hearth was warm.
Conversely, if they pour 🗑 into 🍞, they can sustain an anomalously warm
hearth. The hearth responds to food supply.

---

## Faction Landscape

| Faction | Active atoms | What they contribute |
|---|---|---|
| **Millwright's Union** | ⚙, 💨, 🍞, 👥 | Mill coupling: ⚙↔💨 (0.6) — the core of the commerce attractor |
| **Hearth Keepers** | 🔥, ❄, 🍞, 💨, 👥 | Strong 🔥↔❄ (0.8) mixes fire/ice; fire bias (ε=0.8); 🍞↔🔥 (0.4) feeds hearth |
| **Granary Guilds** | 🍞, 💰, 🧺 | Commerce coupling: 💰↔🍞 (0.58), 💰↔🧺 (0.5) — the bistability source |
| **Void Serfs** | 👥 (only) | sig includes ⛓💸💀 but none are in the biome — their dark lore is **dormant** |

---

## Dormant Gizmos (atoms wired but not yet in the biome)

Every faction has atoms in its Hamiltonian that are absent from Village's emoji
list. Adding one of these to Village plugs it into existing faction couplings
with no new physics needed — the H is already there.

| Atom | Faction | H into Village | What it does |
|---|---|---|---|
| 🏭 factory | Millwright's Union | ⚙↔🏭=0.65, 🏭↔💨=0.52, 🏭↔🍞=0.55, 🏭↔👥=−0.2 | Industrial output hub. When the mill runs (⚙/💨 high), factory lights up and pushes bread. The −0.2 coupling with 👥 is automation displacing labor. |
| ⛓ chains | Void Serfs | 👥↔⛓=0.7 | Worker bondage. Strong mixing between people and chains. Wires the dark Void Serfs lore. Player mission: drain chains to free labor. |
| 💸 debt | Void Serfs | 💸↔👥=0.5, 💸↔💀=0.3 | Money flying away from people, toward death. Pairs with 💰 as Wealth/Debt axis. Adds a crisis dimension. |
| 💧 water | Hearth Keepers | 💧↔🍞=0.5, 💧↔🔥=0.2, 💧↔👥=0.3 | Mill pond / water supply. Mediates between bread, fire, and people. Adding water helps the hearth dynamics and gives fire/ice a shared resource to compete over. |
| 🔨 hammer | Millwright's Union | 🔨↔⚙=0.5 | Craft coupling. Second lever on the mill. Blacksmith work drives gears. |
| 🌱 seedling | Granary Guilds | 🌱↔💰=0.32 | Farm investment. Coin buys seeds. Connects Village commerce to the StarterForest/Woodlot soil. |

---

## Assay Scores

| Assay | Score | Site | Notes |
|---|---|---|---|
| `transition_assay` bistability | **0.186** | 🧺 | Commerce axis; above 0.10 threshold |
| Secondary bistable sites | 0.065 / 0.056 / 0.052 | ⚙ / 💨 / 👥 | Mill and labor also show strong seed-dependence |

Run `python3 tools/transition_assay.py --biome Village` to reproduce.

---

## Implementation Files

- `Core/Biomes/data/biomes.json` — source of truth
- `tools/mutate_starter_island.py` — autocatalysis rates, kickstart pumps, cross-suppression
- Commits: `430e597` (starter island), `b2716bb` (initial structure)
