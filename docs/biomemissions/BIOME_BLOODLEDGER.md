# Biome: BloodLedger — Campaign & Tutorial Notes

> **Scope banner (2026-07-11):** written before the closed-native migration —
> this doc treats open-system Lindblad physics as the working baseline. The
> base game is closed (zero Lindblad operators; see `docs/CLOSED_SYSTEM.md`).
> Valid as design reference for the open / wet-country DLC content only.

**Lore pitch:** The district where law becomes land and coin becomes tribute.
Four columns of documentation rise around a central courtyard. No one here chose
to be here. No one leaves without leaving something behind. The Carrion Throne
doesn't know it's a quantum phenomenon — it *is* the quantum phenomenon of order
achieving critical density.

**Physics pitch:** An 8-atom, 4-qubit open system demonstrating autocatalytic
authority and designed monoculture. Score 0.002 — the empire always reaches the
same equilibrium. The unique steady state is the design. You cannot randomly
initialise your way to a free village. Only active intervention collapses it.

---

## The Four Axes (what the player reads)

| Axis | Pole 0 | Pole 1 | Physics role |
|---|---|---|---|
| **Authority** | ⚜ seal | ⚖ scales | Dominance axis. ⚜ sustained by 📜 autocatalytic loop (rate 25.0, power 2). Carrion Throne H: ⚜↔🏰 (0.8), ⚜↔🦅 (0.6), ⚜↔📜 (0.6). |
| **Heritage** | 🏰 fortress | 📜 document | Infrastructure axis. 📜 is the autocatalytic fuel. 📜↔🏰 (0.6). Documentation sustains the fortress which sustains documentation. |
| **Predation** | 🦅 hawk | 🩸 blood | Enforcement axis. 🦅↔⚜ (0.6), 🦅↔🩸 (0.4). Hawks enforce authority; blood is the cost of enforcement — and of its resistance. |
| **Extraction** | 👥 people | 💰 coin | Tribute axis. 💰 dominant (0.170). 💰 flows in from Village; 👥 are present but subordinate (⚜↔👥 anti-coupled −0.28). |

---

## What the Biome Does (baseline steady state)

From an empty start:

```
⚜ 0.111   ⚖ 0.103   — authority present; scales barely balancing against it
🏰 0.114   📜 0.102   — fortress and documentation sustaining each other
🦅 0.093   🩸 0.123   — enforcers; blood slightly outweighs the hawks that draw it
👥 0.117   💰 0.170   — people present; coin is the largest accumulation
Score: 0.002
```

**💰 at 17.0%** is the headline: tax revenue is the biome's largest accumulation.
Tribute flows in from Village (incoming cross_biome_flow: 💰 and 👥) and the
extraction H ensures it stays. People arrive and coin remains.

### The autocatalytic authority loop

The critical L term (ShrineOfAshes pattern): 📜 reservoir → gated ⚜ (rate 25.0,
power 2). This is a nonlinear pump: the more 📜 exists, the faster ⚜ is produced.
Documentation feeds authority; authority produces more documentation. The loop
has a threshold — below a critical 📜 level, the autocatalysis stalls. Above it,
authority accelerates to its steady-state value and holds.

This is a designed bistability that doesn't show up as a high score because the
*other* attractor (low 📜, low ⚜) requires active intervention to reach. The
empire starts above its critical threshold and never falls below it on its own.

### Why score 0.002

The near-zero bistability score confirms the design: from empty and from full,
the system reaches essentially the same state. You cannot seed this biome into
a free configuration. The autocatalytic loop pulls everything back to empire
equilibrium within a few ticks. History doesn't matter here — the structure
enforces its own reproduction.

The Carrion Throne's description says it right: "every form filed, every tax
collected, every law enforced adds to its coherence." The steady state is
self-reinforcing. Score 0.002 is not a failure of physics design; it is the
physics expressing total narrative control.

---

## Player Mission: Starve the Ledger

**The lever:** drain 📜 (documentation) using Tool 2 (Lindblad sink on 📜).

**The mechanism:**
1. 📜 drops below the autocatalytic threshold
2. Gated ⚜ pump rate collapses (rate 25.0 × 📜² → near zero)
3. ⚜ (authority) declines — sustained only by weaker H couplings from 🏰
4. 🦅 (enforcement) weakens as ⚜↔🦅 (0.6) loses its source
5. 💰 extraction slows — fewer enforcers to collect tribute
6. 👥 (people) temporarily escape ⚜ anti-coupling suppression (−0.28)

**The catch:** the moment the player stops draining 📜, incoming 💰 and 👥
from Village refill the extraction chain. 📜 regenerates (Carrion Throne H:
📜↔🏰 (0.6), ⚜↔📜 (0.6)). The autocatalytic loop restarts. Authority returns.

The collapse is real but not permanent. To make it permanent, the player must
also break the incoming Village flow — cut the tribute pipeline at the source.

**What this teaches:** autocatalytic systems have a critical threshold but they
also have a regeneration pathway. Draining the fuel is necessary but not sufficient.
You also need to cut the supply chain that refills the fuel.

### Second mission: The Audit

Import ⚖ from Village (Path J: Tax Season) and observe the coupling. Irrigation
Jury H: ⚖↔💧 (0.6), ⚖↔🌱 (−0.18). In Village, ⚖ represents commerce. Here, ⚖
is the scales of authority — the same atom, different political context.

When Village's ⚖ is reduced (fewer transactions, weaker commerce), the tribute
flow (💰 from Village to BloodLedger) decreases at distance. The Authority axis
in BloodLedger weakens without the player ever touching BloodLedger directly.
Reducing ⚖ in Village reduces imperial strength here.

**What this teaches:** faction atoms are shared across biomes. ⚖ in Village
and ⚖ in BloodLedger are the same species. They are coupled not by explicit
cross_biome_flow but by the player's manipulation of common resources.

---

## Faction Landscape

| Faction | Active atoms | What they contribute |
|---|---|---|
| **Carrion Throne** | ⚖, ⚜, 🏰, 👥, 📜, 🦅, 🩸, 💰 | Full empire H. 📜 autocatalysis loop. ⚜↔🏰 (0.8) — the fortress-authority bond is the strongest coupling in the biome. 🦅 enforcement. 👥 anti-coupled to ⚜ (−0.28) — people are suppressed by authority. |
| **Granary Guilds** | 💰, 🍞, 🧺, 🌱 | Economic H substrate. 💰↔🍞 (0.58), 💰↔🧺 (0.5). Their commerce atoms (🍞, 🧺) are not in-biome — only 💰 is active here. The Guild's commercial network feeds the tribute stream. |

The Carrion Throne description: "feeds on documentation the way fire feeds on
oxygen." The player never meets it directly. The player always serves it — until
they don't.

---

## Assay Data

```
💰 0.170/0.172   (dominant — tribute accumulates)
🏰 0.114/0.114
🐺→🩸 0.123/0.122   (blood: enforcement cost)
👥 0.117/0.117
⚜ 0.111/0.110
⚖ 0.103/0.104
📜 0.102/0.102
🦅 0.093/0.092
Score: 0.002
```

The columns are nearly identical. From empty or loaded, you get the same empire.

---

## Cross-Biome Flows

| Direction | Biome | Atoms | Story |
|---|---|---|---|
| incoming | Village | 💰, 👥 | Tribute flows upstream; people arrive for processing |

---

## Native Factions

- **Carrion Throne** — the primary architect of this biome's H
- **Granary Guilds** — economic substrate; their 💰 H feeds the tribute chain

---

## Implementation Notes

- `Core/Biomes/data/biomes.json` — full L-specs; autocatalytic L documented as
  ShrineOfAshes pattern (gated, rate 25.0, power 2)
- Redesigned from "VillagePocket" test artifact into Carrion Throne faction showcase
- cross_biome_flows.incoming: Village sends 💰 and 👥; no outgoing flows (nothing
  the empire takes is returned)
- The unique steady state is the design goal — score 0.002 is intentional
