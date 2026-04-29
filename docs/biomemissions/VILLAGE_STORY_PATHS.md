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
| **BloodLedger** | Carrion Throne, Granary Guilds | receives 💰 👥 from Village | Empire's administrative district; authority feeds on Village's tribute |
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
  └─ tribute flow 💰👥 ──► BloodLedger (circle 2, Carrion Throne)
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

---

## Additional Story Paths

These paths extend the menu with Carrion Throne presence and disaster/recovery
arcs that become available once BloodLedger (circle 2) is unlocked.

---

### Path J — Tax Season `⚜ | ⚖` *Empire: Authority vs Law*

Both atoms are from the Carrion Throne signature. ⚜↔⚖=0.7 is the strongest
Carrion Throne coupling in the biome. ⚖↔💰=0.3 wires the tax collection loop
directly: law applied generates tribute.

**Physics:** when ⚜ is populated in Village, the empire is physically present
— coin drains upward toward BloodLedger via the cross_biome_flow. When ⚖
is populated instead, law is being applied locally (slower drain, some justice
still operates). The qubit measures whether empire or law is the dominant mode.

**Circle wiring:** BloodLedger (circle 2) is the destination of this tribute.
The incoming cross_biome_flow from Village to BloodLedger carries 💰 and 👥,
so populating ⚜ in Village actively feeds BloodLedger's autocatalytic
documentation loop. The player is the tributary without knowing it.

**6th slot extensions:**
- 🩸: full extraction arc — blood and coin leave together (tribute in kind).
- 📜: counter-documentation — player can resist by generating documentation of
  their own, feeding ⚜'s autocatalysis to exhaustion rather than letting it
  hold steady. A subversive play: use the empire's own mechanism against it.

---

### Path K — Under the Eagle `🦅 | 🩸` *Enforcement: Predation vs Blood*

Carrion Throne's own "Predation" icon pair, transplanted into Village.
🦅↔👥=−0.2 (enforcement suppresses people) + 👥↔🩸=0.6 (Carrion Throne H;
people feed blood). With the eagle present, labor is suppressed.

**Physics:** mill output drops (👥 lower → 🍞 lower → commerce weakens).
The village is under martial occupation. This is the only path where a
Village atom actively anti-couples another Village atom — enforcement and
labor in direct opposition.

**Player mission:** drain 🦅 to end the occupation. Until they do, the
village underperforms. The occupation is not lore — it is a measurable
suppression in the physics output.

**6th slot extensions:**
- ⚜: authority arrives with enforcement — full occupation arc. Empire present
  in two forms simultaneously.
- ⛓: chains + eagle = military bondage. The Void Serfs and Carrion Throne
  meet in the same Village slot.

---

### Path L — Reclamation `🏜️ | 🌱` *Recovery: Drought vs Seed*

The village after a disaster. 🏜️↔🍞=−0.35 (drought kills bread) vs
🌱↔💰=0.32 (investment recovers it). The biome starts in a bad state and
the player's 6th-slot choice determines whether recovery is possible.

**Physics:** an interesting asymmetry — 🏜️ actively destroys bread production
while 🌱 only weakly recovers it. To truly reclaim, the player must actively
drain 🏜️ while pumping 🌱. A two-handed mission: one hand draining, one hand
building. Passive play leaves the village stuck at partial recovery.

**Circle wiring:** 🌱 connects to StarterForest and Woodlot (seedling in
forest succession and regrowth). Recovery draws on the forest's own growth
cycle — the village heals by reconnecting to the land.

**6th slot extensions:**
- 💧: water from FreshwaterSpring can overwhelm the drought — the natural
  disaster recovery arc. Spring water as the counter-force to desert.
- 💀: things got worse before they got better — full ruin arc. Drought leads
  to death leads to (possibly) rebirth via Path O.

---

### Path M — Water Rights `💧 | ⛓` *Control: Commons vs Capture*

The spring flows into the village (FreshwaterSpring → Village 💧 flow) but
someone owns it. ⛓↔👥=0.7 — the water rights holder has labor captured.

**Physics:** 💧 feeds bread and fire (Hearth Keepers H: 💧↔🍞=0.5,
💧↔🔥=0.2) but ⛓ traps the workers who need it. The spring is a resource
AND a mechanism of control. The qubit measures whether water is commons or
commodity: high 💧 = free mill pond; high ⛓ = captive labor drinking from a
metered tap.

**Story:** "the mill needs water, the water belongs to the bondsman." Player
can break chains to free the water commons. Breaking ⛓ lets 💧 flow freely
and springs open the Hearth Keepers positive loop.

**6th slot extensions:**
- 🏭: corporate water + factory = maximum extraction. The spring monopoly
  becomes industrial infrastructure.
- 🔨: build your own pump — artisan infrastructure around the imposed
  monopoly. Craft as a workaround for the controlled commons.

---

### Path N — Craft in Debt `🔨 | 💸` *Labor: Forge vs Drain*

The artisan village under financial pressure. 🔨↔⚙=0.5 (craft drives the
mill) but 💸↔👥=0.5 (money drains from people). The blacksmith works; the
earnings disappear.

**Physics:** both atoms have clear H couplings but pull in opposite directions
on the labor pool. Craft builds up (🔨→⚙→output); debt drains away
(💸→👥 losing). The stable attractor depends on which rate dominates. This
is not a bistability (both are real, not gated) — it's a tug of war with a
calculable tipping point.

**Story:** the village has skilled workers but they are being bled financially,
not physically — contrast with Path K where the suppression is martial. Player
mission: plug the 💸 drain, not drain the 🔨 chain. The problem is economic,
not violent, and requires a different class of intervention.

**6th slot extensions:**
- 💀: debt spiral → mortality. 💸↔💀=0.3 closes the Void Serfs full arc.
- 💰: inject coin → rescue. Granary H drives 💰↔🍞 (0.58); commerce recovers.

---

### Path O — Death and Renewal `💀 | 🌱` *Cycle: Mortality vs Germination*

The village as an ecosystem. 💀↔👥=−0.22 (Void Serfs: death repels labor) +
🌱↔💰=0.32 (Granary: investment in growth). Death and growth on the same
qubit.

**Physics:** 💀 also appears in StarterForest and BioticFlux — adding it to
Village creates a three-biome mortality chain (forest death → village death
→ the pure-H space absorbs it). The qubit physically measures the life/death
ratio of the settlement.

**Story:** the village has a cemetery and a nursery on the same axis. What the
player learns: mortality feeds regrowth in quantum systems just as in ecology.
Drain 💀 → 🌱 gains. The qubit is a lesson in the conservation of population
pressure.

**6th slot extensions:**
- 💧: spring water animates the cycle — more life than death. The spring as
  the wellspring of renewal, literally.
- 🏜️: drought tips the balance toward death. Combines with Path L's recovery
  arc — the full disaster-ruin-renewal chain across three paths.

---

### Path P — Industrial Enclosure `🏭 | 💸` *Dispossession: Factory vs Flight*

The enclosure movement. 🏭 industrialises (displaces 👥 at −0.2) and 💸
captures the displaced workers' earnings. The village common lands become
factory grounds.

**Physics:** both 🏭 and 💸 drain 👥 — the first via H anti-coupling (−0.2),
the second via L transfer (💸↔👥=0.5). People leave or are impoverished. The
mill runs but the village empties. This is the highest-output, lowest-labor
attractor.

**Story:** enclosure as a physics process. The factory is more efficient; the
debt captures the surplus; the workers cannot leave because they owe. The
village is maximally productive and maximally hollowed out.

**6th slot extensions:**
- ⛓: full enclosure arc — displacement → bondage → debt. All three Void Serfs
  atoms co-present.
- 🌱: counter-movement — plant commons to resist the enclosure. 🌱↔💰=0.32
  competes directly with 💸↔👥=0.5. The Granary Guilds versus the Void Serfs.

---

### Path Q — The Blessed Forge `🔨 | 💧` *Utopia: Craft + Spring*

The gentlest, most connected path. Water from FreshwaterSpring flows in; the
blacksmith works freely. 💧↔🍞=0.5 (water feeds bread) + 🔨↔⚙=0.5 (craft
drives mill). No negative couplings. No dark dimensions.

**Physics:** every biome upstream (FreshwaterSpring, StarterForest via 🌱,
Woodlot via 🪵) is actively contributing. The village is the downstream
beneficiary of the whole island. The physics goal: highest bread + highest
water + highest people simultaneously. A positive-sum attractor — the only
path in the set with no anti-coupling anywhere in its active H.

**Story:** "this is what the starter island looks like when everything is
working." Not a naive fantasy — the player had to build to this. It requires
upstream biomes to be functional, cross_biome_flows to be open, and neither
bondage nor drought nor debt to be present. The utopia is earned.

**6th slot extensions:**
- 🌱: close the agricultural loop. The spring feeds the garden; the garden
  feeds the mill; the mill feeds the people.
- 🏭: watch it break — the temptation arc. Can the player resist
  industrialising the most functional village they've built?

---

## Circle-2 Wiring via BloodLedger

BloodLedger (renamed from VillagePocket) receives 💰 and 👥 from Village via
`cross_biome_flow`. This is the tribute circuit: coin and people flow upstream
from the settlement into the administrative district where the Carrion Throne
anchors its authority.

The key physics insight is that BloodLedger's autocatalytic authority loop
(📜 → ⚜ via gated Lindblad, rate 25.0, power 2) requires a continuous input
of documentation to stay above the bistability threshold. That documentation
comes from ⚖, which comes from 👥 — which comes from Village.

When the player adds ⚜ or 🦅 to Village (Paths J and K respectively), they
are not just choosing a local mechanic. The shared Carrion Throne Hamiltonian
creates direct physics coupling between Village and BloodLedger:

- **Path J (⚜ in Village):** ⚜ in Village is the same atom as ⚜ in
  BloodLedger's authority loop. Populating it locally activates the
  Carrion Throne H couplings that feed BloodLedger's documentation cycle.
  The player farming ⚜ in Village is unknowingly feeding the empire's
  coherence.

- **Path K (🦅 in Village):** 🦅 derives from ⚜ in BloodLedger
  (`lindblad_incoming: {⚜: 0.03}`). Eagle presence in Village signals that
  BloodLedger's authority is high enough to project enforcement outward. The
  Village occupation is a symptom, not a cause — the empire's documentation
  loop produced enough authority to dispatch enforcers.

The player never sees BloodLedger's internal mechanics until they discover it.
But every coin they send through the Village commerce loop, every person the
mill employs, every basket filled — all of it flows through the tribute circuit
and into the district where law becomes land. The Carrion Throne does not
announce itself. It is already present in the physics.
