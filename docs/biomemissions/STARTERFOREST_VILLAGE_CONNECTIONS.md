# StarterForest ↔ Village — Latent Connections & Story Options

Both biomes are at maximum capacity (6 qubits each). Neither needs new atoms.
This document maps the **faction Hamiltonian bridges** that already exist between
them — couplings that span atoms in both biomes but are currently dormant because
no mechanism activates them across the biome boundary.

These are story options, not implementation tasks. The physics is already wired.
The narrative is waiting for a reason to surface it.

---

## The Situation

StarterForest and Village share **no atoms, no cross_biome_flows, no native
factions**. In the current runtime, they are physically isolated — nothing flows
between them and the market treats them as independent.

But four faction Hamiltonians contain coupling terms that span atoms from both
biomes simultaneously. These are latent bridges: the faction "knows about" atoms
on both sides, even though neither biome has wired the connection.

---

## The Four Bridges

### Bridge 1 — Wildfire: Forest Decay → Village Fire

**Faction:** Wildfire (StarterForest native)
**Connection:** Wildfire H couples every forest decay atom to 🔥:

| Coupling | Strength | Direction |
|---|---|---|
| 🍂 ↔ 🔥 | **0.7** | Leaf litter → fire (strongest bridge in this set) |
| 🌿 ↔ 🔥 | 0.4 | Greenery → damps fire |
| 🌲 ↔ 🔥 | 0.3 | Trees → damps fire |
| 🌱 ↔ 🔥 | −0.2 | Seedlings → suppresses fire |

Wildfire treats the forest as a fuel system and 🔥 as the output. Every atom
in StarterForest's decomposition cycle (🍂→🌱→🌲→🌿→🍂) has a direct H
coupling to the Village hearth.

**What it means physically:** the forest's decay rate is a latent fire intensity
signal. When 🍂 (leaf litter) is high — when the decomposition cycle stalls —
Wildfire's H pushes toward 🔥. When the forest is healthy and green (🌿 high,
🌲 high), it damps fire. The biome is writing a fire risk index that the village
is not reading.

**Story options:**
- *The Dry Season* — PastoralCommons drought spills into the Woodlot; Woodlot
  🍂 accumulates and outflows into StarterForest; StarterForest 🍂 peaks; the
  Wildfire bridge lights the Village hearth hotter than the player expected. A
  chain reaction across three biomes that no single player action caused.
- *Controlled Burns* — player discovers that draining 🍂 in StarterForest
  (normally a mid-game optimisation for the Woodlot cycle) also cools the
  Village hearth. Forest management has urban consequences.
- *Fire Season* — a campaign mission where the Wildfire faction offers a
  contract: keep 🍂 below threshold in StarterForest for N phrames, or the
  village goes cold. The player is managing the forest to protect the hearth.

---

### Bridge 2 — Celestial Archons: Sun Drives Fire

**Faction:** Celestial Archons (StarterForest native)
**Connection:** Celestial Archons H has ☀ ↔ 🔥 = **0.7**

This is the single strongest cross-biome coupling in the starter island. ☀ is
StarterForest's day/night driver; 🔥 is Village's hearth. The Celestial Archons
treat sunlight and fire as the same thing — the celestial fire and the domestic
hearth are one phenomenon at different scales.

**What it means physically:** StarterForest's day/night cycle (☀ ↔ 🌙 toggle)
is running constantly. Its ☀ population fluctuates with that cycle. If that
signal could reach the village, the Village hearth would brighten during the
day and dim at night — not because of the player, but because of the sun.

**Story options:**
- *Solar Calendar* — the player discovers that the Village hearth's natural
  rhythm tracks the StarterForest day cycle. Not magic — physics. The Celestial
  Archons faction (not visible in Village) is the reason. Campaign reveal: there
  is a faction shaping your hearth that you have never contracted with.
- *Eclipse* — a narrative event where the StarterForest night cycle is extended
  (player-driven or scripted); ☀ drops; Village 🔥 cools as a consequence.
  The player experiences the solar-fire link before being told about it.
- *Druid Discovery* — the Druid archetype frame is the natural one to surface
  this. An advanced Druid mission: find the faction whose H term connects ☀ to
  🔥. Answer: Celestial Archons. Reward: a contract tier opens with them.

---

### Bridge 3 — Granary Guilds: Seedlings Buy Investment

**Faction:** Granary Guilds (Village native)
**Connection:** Granary Guilds H has 🌱 ↔ 💰 = 0.32

🌱 (seedling) is in StarterForest — it is the atom in the forest succession
cycle (🍂→🌱→🌲). 💰 (coin) is in Village. The Granary Guilds, the faction
that runs Village's commercial economy, care about seedlings. Their Hamiltonian
says: investment (coin) and seedlings are coupled.

**What it means physically:** this is the ecological investment principle — you
spend coin to plant seeds, and seeds grow into trees, and trees sustain the
forest. The Granary Guilds' H is not just a Village mechanic; it is a statement
that the village economy has a stake in forest regeneration.

**Story options:**
- *The Investment Chain* — a Granary Guilds arc quest: the player is asked to
  sustain 🌱 above threshold in StarterForest. The reward is coin and access.
  The framing: "the guild funds reforestation because timber is their supply
  chain." Commerce as ecology.
- *Deforestation Crisis* — if the player has been over-harvesting 🌲 in the
  Woodlot, 🌱 in StarterForest drops. Granary Guilds contracts in Village get
  more expensive (less seedlings → fewer future trees → less timber → commerce
  at risk). The market is reading forest health as economic risk.
- *Seed Bank* — adding 🌱 to Village as the 6th qubit (Path C or G) closes this
  bridge explicitly. The atom that was in the forest is now also in the village
  — the agricultural investment loop is physically complete. Until then, the
  connection is latent.

---

### Bridge 4 — Void Serfs: Forest Death Repels Labor

**Faction:** Void Serfs (Village native)
**Connection:** Void Serfs H has 💀 ↔ 👥 = −0.22

💀 (death) is in StarterForest — the Pack Lords faction uses it as the mortality
axis of the predator/prey cycle (🐇, 🦌, and 🐺 all have death in their decay
chain). 👥 (people) is in Village. The Void Serfs, the faction that governs
bondage and labor, have a coupling that says: death repels workers.

**What it means physically:** the forest's mortality signal is latently
anti-coupled to village labor. When the StarterForest death rate is high —
when wolves are taking deer, when the food chain is losing population — that
signal would push 👥 downward in the village. The wilderness mortality that the
forest demonstrates has an urban shadow.

**Story options:**
- *The Plague Season* — a narrative scenario where StarterForest's 💀 spikes
  (wolf cull, or a player who drained all the prey). Village 👥 drops. The
  connection is invisible to the player until revealed. "Why are people leaving
  the village?" The Scientist frame surfaces it: the death rate in the forest
  edge is high.
- *The Refugees* — inverse of plague season: a Village crisis drives 👥 out;
  the forest absorbs displaced labor. 💀 in StarterForest rises as the refugees
  struggle to survive outside the settlement. The mortality in the wilderness is
  the cost of economic collapse in the village.
- *Void Serfs Revelation* — a Void Serfs arc quest: the faction asks the player
  to maintain low 💀 in StarterForest (keep prey populations stable) as a labor
  stability measure. The framing is oppressive: "stable forests mean workers
  don't have an excuse to leave." Forest conservation as labor control.

---

## Summary: The Four Bridges

| Bridge | SF atom | V atom | Faction | Strength | Story flavour |
|---|---|---|---|---|---|
| **Wildfire** | 🍂🌿🌲🌱 | 🔥 | Wildfire (SF) | 0.7 max | Forest decay → village fire; seasonal chain reaction |
| **Celestial Archons** | ☀ | 🔥 | Celestial Archons (SF) | **0.7** | Day cycle drives hearth; Druid discovery arc |
| **Granary Guilds** | 🌱 | 💰 | Granary Guilds (V) | 0.32 | Seedlings = investment; deforestation as economic risk |
| **Void Serfs** | 💀 | 👥 | Void Serfs (V) | −0.22 | Forest mortality repels labor; refugees; labor control |

---

## What the Market Currently Sees

Nothing. All native factions have empty signatures (`sig: []`), so the market's
biome-axial positioning falls back to neutral for both biomes. The contracts
generated for StarterForest and Village are drawn from faction density overlap
and spectral signal — they are biome-flavored (Pack Lords offering prey delivery,
Millwright's offering grain) but not cross-biome.

The market will not see these bridges until one of two things happens:

1. **Faction signatures are populated** — once native factions have axiom-pattern
   signatures, `ContractMarket._build_biome_axial_from_signature()` can derive
   that StarterForest is a local/emergent/physical biome and Village is a
   classical/consumptive/structured one. The spectral overlap between their
   factional characters becomes a pricing signal.

2. **A shared atom is registered in both biomes** — the 🌱 bridge (Path C/G)
   or adding 🔥 to StarterForest would make the connections visible to the
   runtime. Until then, these bridges live only in the faction Hamiltonians —
   real physics that the biomes haven't opted into.

The absence of signatures is the more impactful gap: the market doesn't know
what kind of place either biome is. That is a future tuning pass, not starter
island work.

---

## Relationship to Story Flags

These bridges are not in the starter island story flags (see
`STARTER_ISLAND_STORY_FLAGS.md`) because they don't require the player to
*do* anything to activate them — they are discoveries, not missions.

The natural integration point is the **Z/Y Story tab** as a "connections"
section: after Flag 5 (`island_lives`) fires, the Story tab could reveal one
latent bridge per arc beat — framed as the player noticing a pattern in the
market or the physics, not as a tutorial pointing at a mechanic.

The Celestial Archons ☀↔🔥 bridge is the best candidate for the first
reveal: it is the strongest coupling (0.7), it involves the most visible atoms
(the day cycle and the hearth are both prominent in their biomes), and it sets
up the Druid frame as the tool for cross-biome investigation.
