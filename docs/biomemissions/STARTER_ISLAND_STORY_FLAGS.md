# Starter Island — Story Flags & Narrative Arc

This document defines the narrative arc of the starter island as a sequence of
**story flags**: threshold conditions on faction standings + biome state that
fire once and record a permanent entry in `farm.story_log`. When a flag fires,
it unlocks a Z/Y Story tab entry, optionally gates a new market tier, and
advances the island's arc.

The design principle: **the market tells the story.** The player doesn't read
lore — they complete contracts, standings accumulate, thresholds cross, and
the Story tab reflects what they've already done in physics terms. Narrative is
a projection of their accumulated standing, not a separate track.

---

## How Story Flags Work (architecture sketch)

Each flag is a record with:
- `id` — stable string key (e.g. `"forest_stirs"`)
- `display_name` — shown in Z/Y Story tab
- `predicates` — list of conditions that must ALL be true
- `arc_beat` — one-paragraph player-facing text (past tense, already happened)
- `unlocks` — what becomes available when triggered (arc quests, market tiers,
  dormant atoms, biome discovery)
- `standing_grants` — standing deltas fired once on trigger (to reflect world
  acknowledgment of what the player did)

Predicate types currently needed:

| Type | Example |
|---|---|
| `standing_gte` | `{faction: "Millwright's Union", channel: "access", value: 0.3}` |
| `standing_gte` | `{faction: "Hearth Keepers", channel: "trust", value: 0.25}` |
| `biome_discovered` | `{biome: "Woodlot"}` |
| `biome_state_gte` | `{biome: "Village", atom: "💨", value: 0.1}` |
| `story_flag_set` | `{id: "mill_wakes"}` — flag depends on prior flag |
| `atom_in_biome` | `{biome: "Village", atom: "🪵"}` |

The evaluation loop runs each physics frame inside QuestManager (same as
observable quests). Once all predicates pass, the flag fires once, is added to
`farm.story_log`, and cannot re-fire.

---

## The Five-Act Arc

```
Act 0 — First Contact         BioticFlux: encounter pure unitarity
Act 1 — The Forest Stirs      StarterForest: open the food chain
Act 2 — Upstream Wakes        Woodlot + FreshwaterSpring: close the supply lines
Act 3 — The Mill Runs         Village: commerce bistability; mill toggle
Act 4 — Your Village          Village 5th + 6th qubit; identity chosen
Act 5 — The Ledger Opens      BloodLedger: tribute was flowing all along
```

---

## Flag Definitions

---

### Flag 0 — `first_contact_unitarity`

> **"The biotic flux is pure. Nothing decays here."**

**Predicates:**
```json
[
  { "type": "biome_discovered", "biome": "BioticFlux" }
]
```

**Arc beat:**
The player enters BioticFlux — a biome with no Lindblad terms. Every quantity
oscillates without settling. Nothing decays, nothing stabilises. This is what
the universe looks like before dissipation: pure Hamiltonian rotation. The
tutorial question forms: *why doesn't everything just oscillate forever?*

**Unlocks:**
- Z/Y Story tab section: "Act 0 — First Contact"
- Introductory guide text in Z/O Guide: "What is Lindblad dissipation?"
- Market: Tier 1 contracts from BioticFlux (observable quests only — no
  delivery; BioticFlux has no economy to deliver from)

**Standing grants on trigger:** none — this is the opening beat, no faction
has noticed yet.

---

### Flag 1 — `forest_stirs`

> **"The forest woke. Light reached the canopy and the food chain opened."**

**Predicates:**
```json
[
  { "type": "biome_discovered", "biome": "StarterForest" },
  { "type": "biome_state_gte", "biome": "StarterForest", "atom": "☀", "value": 0.05 }
]
```

The second predicate fires only once the player has injected something into
the sun pump (☀ `lindblad_incoming: {🗑: 0.20}`). The forest exists on
discovery but is cold until the pump runs.

**Arc beat:**
Sunlight reached the canopy. The food chain is now complete: trees absorb
light, rabbits appear at the edges, wolves hunt the clearing. Anderson
transport is running: population is localised at the tree source and
propagating toward the rabbit sink. The forest is not balanced — it is alive.

**Unlocks:**
- Z/Y Story tab section: "Act 1 — The Forest Stirs"
- New StarterForest arc quest: **"Open the Food Chain"** (SHAPE_ACHIEVE: 🌲
  bistability score > 0.08 — the tree/rabbit difference is visible)
- Market: Woodlot contracts become available (Millwright's Union begins
  offering timber delivery quests, gated on StarterForest being active)

**Standing grants on trigger:**
```json
{ "Hearth Keepers": { "trust": 0.05 } }
```
The Hearth Keepers notice life returning to the forest edge.

---

### Flag 2 — `lumber_flows`

> **"Woodlot is cutting. Timber is moving toward the village."**

**Predicates:**
```json
[
  { "type": "biome_discovered", "biome": "Woodlot" },
  { "type": "story_flag_set", "id": "forest_stirs" },
  { "type": "standing_gte", "faction": "Millwright's Union", "channel": "access", "value": 0.2 }
]
```

Millwright's Union access 0.2 is achievable with ~8–10 completed timber
delivery contracts from Woodlot. It means the guild has noticed the player and
started offering better work.

**Arc beat:**
The managed woodlot is felling trees and sending lumber downstream. The
Millwright's Union — the faction that runs the village mill — is watching what
arrives. Timber is not yet landing anywhere (Village has no 🪵 register yet),
but the flow is live in the cross_biome data. The wood is piling up at the
village gate.

**Unlocks:**
- Z/Y Story tab section: "Act 2 — Upstream Wakes (Woodlot)"
- New arc quest: **"Close the Timber Circuit"** — DELIVER quest: add 🪵 atom
  to Village (this is the player's first atom-placement action; teaches the
  Captain frame). Completing this quest is the gate for Flag 5.
- Dormant atom hint in Z/Y: "🪵 — timber is arriving at the village but has
  nowhere to land"

**Standing grants on trigger:**
```json
{ "Millwright's Union": { "trust": 0.08, "attention": 0.1 } }
```
The guild is paying attention now.

---

### Flag 3 — `spring_connects`

> **"The spring is flowing downstream. Water has reached the village."**

**Predicates:**
```json
[
  { "type": "biome_discovered", "biome": "FreshwaterSpring" },
  { "type": "standing_gte", "faction": "Hearth Keepers", "channel": "trust", "value": 0.25 }
]
```

Hearth Keepers trust 0.25 is reachable through ~10–12 completed FreshwaterSpring
or Village contracts where the Hearth Keepers faction appears as the offering
faction. The trust channel (not access) fires here because water is about
relationship, not transaction.

**Arc beat:**
Ice wells up from deep stone, melts, and flows downstream. The Hearth Keepers
— who govern fire, water, and bread in equal measure — have seen the player
tending the watershed. The spring's outflow is now physically coupling into
Village's Lindblad runtime, even though it has no register yet. The mill pond
could exist. It's waiting.

**Unlocks:**
- Z/Y Story tab section: "Act 2 — Upstream Wakes (FreshwaterSpring)"
- New arc quest: **"Open the Mill Pond"** — hints at adding 💧 to Village or
  choosing Path A/E/G/M (all of which give 💧 a register)
- FreshwaterSpring contracts now weight toward Irrigation Jury (circle 2
  faction) — the water governance theme begins appearing in offers
- Dormant atom hint: "💧 — spring water is arriving but has nowhere to land"

**Standing grants on trigger:**
```json
{ "Hearth Keepers": { "trust": 0.1 } }
```

---

### Flag 4 — `mill_wakes`

> **"The commerce mode switched. The mill is running."**

**Predicates:**
```json
[
  { "type": "biome_discovered", "biome": "Village" },
  { "type": "biome_state_gte", "biome": "Village", "atom": "💨", "value": 0.12 },
  { "type": "biome_state_gte", "biome": "Village", "atom": "⚙", "value": 0.05 }
]
```

Wind and gear thresholds jointly confirm that the mill is actually running —
not just that the Commerce qubit was flipped once, but that the Millwright's
coupling has settled into the commerce attractor. ⚙ > 0.05 is only achievable
from the loaded start (empty start gives ⚙ ≈ 0.011).

**Arc beat:**
The Commerce bistability flipped. Baskets emptied out; coin began circulating;
wind picked up and the gear began turning. This is the light switch: the village
has two stable modes and the player found the second one. Millwright's H
(⚙↔💨 = 0.60) is now the dominant coupling — the mill is the engine of
the local economy.

**Unlocks:**
- Z/Y Story tab section: "Act 3 — The Mill Runs"
- Tutorial note in Z/O Guide updated: "The Village has two attractors. You
  found the second one. This is bistability: two stable states, one flip apart."
- New arc quest: **"Hold Commerce"** (MAINTAIN_COHERENCE: Village ⚙ > 0.05
  for 30 phramesf — teaches the player that attractors can decay if upstream
  supply fails)
- Granary Guilds market offers expand (higher-tier contracts available)

**Standing grants on trigger:**
```json
{
  "Millwright's Union": { "trust": 0.12, "legitimacy": 0.05 },
  "Granary Guilds": { "trust": 0.08 }
}
```

---

### Flag 5 — `island_lives`

> **"Three flows are landing. The village is downstream of the whole island."**

**Predicates:**
```json
[
  { "type": "story_flag_set", "id": "lumber_flows" },
  { "type": "story_flag_set", "id": "spring_connects" },
  { "type": "story_flag_set", "id": "mill_wakes" },
  { "type": "atom_in_biome", "biome": "Village", "atom": "🪵" }
]
```

The last predicate confirms that the player actually placed a 5th-qubit atom
(Path I or any path that accepts 🪵). The timber circuit must be physically
closed, not just flagged as available.

**Arc beat:**
StarterForest feeds Woodlot, Woodlot feeds the Village hearth. FreshwaterSpring
feeds the mill pond. PastoralCommons bees feed Apiary grain, grain feeds the
bakery. Three upstream biomes are now physically driving the village's two key
outputs. The island is not a set of isolated experiments — it is an ecosystem.
The player built this.

**Unlocks:**
- Z/Y Story tab section: "Act 4 — Your Village"
- **The 6th qubit slot appears** as a player-facing affordance: Z/Y shows the
  full path menu (Paths A–Q) and explains the choice. This is the first
  explicit menu-driven narrative decision in the game.
- New hint entries for each path appear in the Story tab under "Paths available"
  — each one with a one-line teaser. Player selects with G/H/J/K/L/; in the Y
  tab (not yet implemented; this is the hook for the Y-tab path picker UI).

**Standing grants on trigger:**
```json
{
  "Millwright's Union": { "legitimacy": 0.1 },
  "Granary Guilds": { "legitimacy": 0.1 },
  "Hearth Keepers": { "trust": 0.12 }
}
```
The whole island is aware of what was built.

---

### Flag 6 — `village_identity`

> **"Your village has a character now."**

**Predicates:**
```json
[
  { "type": "story_flag_set", "id": "island_lives" },
  { "type": "atom_count_gte", "biome": "Village", "value": 12 }
]
```

12 atoms = 6 qubits — Village is at capacity. The player placed their 6th qubit
(any path). `atom_count_gte` is a simple register count, no path discrimination.

**Arc beat:**
This fires differently depending on which atoms are present, expressed in the
`arc_beat` as a template populated at runtime:

- If 💧 present: "The mill runs on spring water. The Blessed Commons path."
- If 🏭 + ⛓ present: "The factory and the chains are both here. The Industrial
  path — the darkest available."
- If 🔨 + 🌱 present: "Craft and seedlings. The Artisan Guild path."
- If 🦅 present: "The eagle is perched on the mill. The empire is watching."
- If 💀 present: "The village has a cemetery. The Void Serfs path."
- Default: "Your village has its sixth qubit. It will behave accordingly."

**Unlocks:**
- Z/Y Story tab entry: path-specific text (see above)
- Path-specific arc quests unlock (e.g., if 🏭 present: "Resist the Enclosure"
  quest becomes available; if 💧 present: "Bless the Commons" quest)
- BloodLedger discovery hint appears in Z/Y: "Something is receiving the coin
  and people your village produces. Follow the tribute upstream."

**Standing grants on trigger:** path-dependent, see Flag 6 Appendix below.

---

### Flag 7 — `ledger_opens`

> **"The empire was always here. You were feeding it."**

**Predicates:**
```json
[
  { "type": "story_flag_set", "id": "village_identity" },
  { "type": "biome_discovered", "biome": "BloodLedger" }
]
```

**Arc beat:**
BloodLedger is discovered. The cross_biome_flow from Village to BloodLedger
(💰 and 👥) has been running since the player first built commerce mode. Every
contract completed, every coin circulated, every worker employed — a fraction
flowed upward into the district where the Carrion Throne anchors its authority.
The 📜 autocatalysis loop has been fed by Village's prosperity without the
player knowing. The empire does not announce itself. It is already present in
the physics.

This is the Act 5 reveal: the market was shaped by an authority that the
player never contracted with. Their standing with Carrion Throne is not zero —
it has been accumulating (via `attention` channel) without their knowledge.

**Unlocks:**
- Z/Y Story tab section: "Act 5 — The Ledger Opens"
- BloodLedger arc quest: **"Starve the Ledger"** — drain 📜 below the
  autocatalysis threshold; requires cutting the Village tribute pipeline
  (player must drain 💰 in Village, severing the cross_biome_flow)
- Z/SELF tab: Carrion Throne faction standing is now visible (was hidden until
  discovery). Player sees they already have `attention: 0.2–0.4` depending
  on how much commerce they built.
- New market tier: Carrion Throne begins offering contracts — but their prices
  are influenced by the player's accumulated `attention` channel (high attention
  = more scrutiny = worse terms)

**Standing grants on trigger:**
```json
{ "Carrion Throne": { "attention": 0.1 } }
```
The empire acknowledges that the player has noticed.

---

## Flag Sequence Summary

```
Flag 0  first_contact_unitarity   — BioticFlux discovered
  └── Flag 1  forest_stirs        — StarterForest sun pump running
       └── Flag 2  lumber_flows   — Woodlot active + Millwright access 0.2
            │
Flag 3  spring_connects           — FreshwaterSpring + Hearth Keepers trust 0.25
            │
Flag 4  mill_wakes                — Village commerce attractor confirmed
            │
            ├── Flag 2 ──► Flag 5  island_lives   — 3 flows landing, 5th qubit placed
                                     └── Flag 6  village_identity   — 6th qubit placed
                                                   └── Flag 7  ledger_opens  — BloodLedger discovered
```

Note: Flags 2 and 3 have independent paths (lumber vs water). Flag 5 requires
both. The player can approach them in either order — the arc is convergent, not
linear.

---

## Standing Thresholds — Calibration Guide

Thresholds are set so that organic market play (no grinding) crosses them
naturally during a normal session:

| Threshold | Contracts needed (approx) | Notes |
|---|---|---|
| Millwright access 0.2 | 8–10 Woodlot deliveries | Early-game reachable |
| Hearth Keepers trust 0.25 | 10–12 Village/FreshwaterSpring completes | Trust builds slower than access |
| Millwright access 0.3 (Path I hint) | 15–18 total | Gating the "close the circuit" arc quest |
| Granary Guilds access 0.3 (Flag 4 expansion) | 12–15 Village completes | Medium-game |
| Carrion Throne attention 0.2–0.4 (passive) | Passive; accumulates from Village commerce | Player never contracted with them |

The Carrion Throne `attention` accumulation is the single most important
passive mechanic: the player builds an empire they did not contract with, at
a rate proportional to their Village commerce output. When they discover
BloodLedger, the `attention` score reveals how long it has been watching.

---

## Appendix — Flag 6 Path-Specific Standing Grants

| 6th qubit choice | Standing grants |
|---|---|
| 💧 (any water path: A/E/G/M/Q) | `Hearth Keepers: {legitimacy: 0.08}` |
| 🏭 (any factory path: B/E/F/P) | `Millwright's Union: {legitimacy: 0.1}`, `Void Serfs: {attention: 0.05}` |
| 🔨 (any craft path: C/F/H/N/Q) | `Millwright's Union: {trust: 0.08}` |
| 🌱 (any seed path: C/G/L/O) | `Granary Guilds: {trust: 0.1}` |
| ⛓ (any bondage path: B/H/M/P) | `Void Serfs: {entanglement: 0.1}`, `Carrion Throne: {attention: 0.08}` |
| 💀 (any death path: D/O) | `Void Serfs: {entanglement: 0.15}` |
| 🦅 or ⚜ (empire paths: J/K) | `Carrion Throne: {legitimacy: 0.1, attention: 0.15}` |
| 💸 (debt paths: D/N/P) | `Void Serfs: {debt: 0.1}` |

These grants are additive with the Flag 7 trigger. A player who chose Path K
(eagle + empire) arrives at BloodLedger with measurably higher Carrion Throne
standing than one who chose Path Q (blessed forge). The market reflects
the history.

---

## Implementation Notes

**Z/Y Story tab wiring** (placeholder → live):
1. Add `story_log: Array[Dictionary]` to Farm.gd (or GameState)
2. Each entry: `{id, fired_at_phrame, display_name, arc_beat, act}`
3. `ControlsOverlay._build_story_body()` reads `farm.story_log`, groups by act,
   renders with G/H/J/K/L; item selection for expanded arc beat text
4. Unfired flags show as greyed hints with "next threshold" progress bar
   (e.g., "Millwright access: 0.14 / 0.20")

**Arc quest injection** (on flag fire):
- QuestManager gets a new method `inject_arc_quest(flag_id)` 
- Arc quests are defined alongside flags in the same data structure
- They appear in C/QuestBoard under a new `ARC` filter (alongside COMFORT/
  STRETCH/MAGNITUDE sort modes)
- Arc quests cannot expire — they persist until completed or the arc advances

**Flag evaluation** (minimal change to existing tick loop):
- Add `_evaluate_story_flags()` call in QuestManager._physics_process()
- Iterate unfired flags; check predicates; fire and log on first all-pass
- Keep flag list small (7 for starter island); O(N×predicates) is trivial

The entire mechanism reuses existing infrastructure: standing channels,
biome state reads, QuestManager lifecycle, Z/Y tab scaffolding. No new physics.
