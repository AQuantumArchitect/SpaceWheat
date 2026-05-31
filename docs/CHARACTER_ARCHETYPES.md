# Character Archetypes — The 8-Vertex Cube

A cosmology of 8 archetypes arranged on a 3-axis cube. This is the current
cube vocabulary used by the live frame stack.

## Axes

Three independent binary axes:

- **Self ↔ World** — manifold orientation. *Looking from within* (immersed,
  embodied) vs. *looking at* (external, observed). A Self-side archetype is
  a state the player occupies; a World-side archetype is a vocation the
  world contains.
- **Classical ↔ Quantum** — math layer. Deterministic / discrete-state vs.
  superposed / entangled. Note: this is a *property*, not a strict gate —
  social interaction is "quantum-flavored" even though Socialite sits on
  the Classical face. Eventually most of the game becomes quantum graphs.
- **Flow ↔ Pulse** — time-stance. Persistent and conforming (continuous
  participation in a pattern) vs. discrete and asserting (firing a
  one-shot event). Absorbs both the eternal/instant axis and the
  conform/disrupt axis from earlier drafts.

## The 8 vertices

| Archetype | Self/World | Classical/Quantum | Flow/Pulse | Read as |
|---|---|---|---|---|
| **Socialite** | Self | Classical | Flow | Player as ongoing relational presence |
| **Ace** | Self | Classical | Pulse | Player as wanderer / insurgent — discrete classical breaks |
| **Icon** | Self | Quantum | Flow | Player as embodied pattern — identifying with a Hamiltonian / qubit-axis |
| **Spark** | Self | Quantum | Pulse | Player as instant event — the moment of casting / collapse |
| **Captain** | World | Classical | Flow | NPC strategist — faction lord, fiefdom-tender, decree-giver |
| **Merchant** | World | Classical | Pulse | NPC empiricist — trader, broker, frontier-market runner |
| **Operator** | World | Quantum | Flow | NPC architect — topology crafter, anyon-bridge engineer |
| **Druid** | World | Quantum | Pulse | NPC caster — quantum priest, gate-firer |

```
                        FLOW face
        Icon ━━━━━━━━━━━━━━━━━━━━━ Operator
       (S,Q,F)                       (W,Q,F)
         /│                              │\
        / │                              │ \
       /  │                              │  \
   Socialite ━━━━━━━━━━━━━━━━━━━━━ Captain  │
   (S,C,F) │                       (W,C,F)  │
       │   │                              │  │
       │  Spark ━━━━━━━━━━━━━━━━━━━━━ Druid
       │ (S,Q,P)                       (W,Q,P)
       │ /                              /
       │/                              /
       Ace ━━━━━━━━━━━━━━━━━━━━━━ Merchant
      (S,C,P)                      (W,C,P)
                        PULSE face
```

## What the cube actually is

**It is a map of NPC space and player-state space, separated by the
Self/World axis.** The 4 World-face vertices are kinds of vocation the
world generates; the 4 Self-face vertices are states the player passes
through.

- **World-face NPCs are derived from world state and game mechanics.**
  Captains come out of faction signatures + biome economy; Merchants
  come out of trade networks and frontier market flows; Operators come
  out of biome topology authorship; Druids come out of gate-casting
  vocations. Each is procedurally instantiable from existing data.
- **Self-face archetypes need hand-crafting.** They describe player
  experience, not procgen content. Their meaning emerges from how the
  UI lets the player inhabit them — what it feels like to *be* an Ace
  or to *become* an Icon for a moment.

## Strictness — the cube is descriptive, not prescriptive

The Self/World split is **not strict**. The player applies gates,
which is acting as a Druid (a World-face vocation). That's fine — the
player can *temporarily inhabit* a World-face archetype by performing
its verbs. What the cube really separates is:

- **Self-face**: the archetypes that describe what the player *is*
  (their default mixture of states)
- **World-face**: the archetypes that describe what the world *offers*
  as roles, which the player can transiently borrow

Eventually everything in the game ends up represented as quantum graphs
anyway, so the Classical/Quantum axis is more of a "current
representation" tag than a hard distinction.

## The 4 deepest tensions (body diagonals — all 3 axes differ)

Each World-face vertex's antipode is exactly one Self-face vertex.
Every NPC vocation has a player-shadow:

1. **Captain ↔ Spark** — strategist's plans crash against the player's
   spontaneous quantum events. The unscheduled disruption is what
   strategy must absorb.
2. **Merchant ↔ Icon** — the trader prices from outside; the
   player has *become* the pattern being traded. Valuer meets
   embodied subject.
3. **Operator ↔ Ace** — the architect's careful topology vs. the
   player's uncareful path through it. Order vs. entropy along the
   shared cube body diagonal.
4. **Druid ↔ Socialite** — the initiated caster fires in formal rite;
   the player is just *being themselves with people*. Discipline meets
   casual presence.

## The 4 interface edges (Self/World pairs that share both other axes)

These are the cube edges where only the Self/World axis differs.
**Each edge is a kind of player-NPC interaction interface** — the
player's state on one side, the NPC's vocation on the other:

| Edge | Interface |
|---|---|
| Captain ↔ Socialite | **Quest board / faction politics** — strategist meets player-as-relational |
| Druid ↔ Spark | **Casting interface** — NPC priest meets player-as-firing-event |
| Operator ↔ Icon | **Topology / biome editor** — architect meets player-as-pattern |
| Merchant ↔ Ace | **Trade / discovery log** — frontier broker meets player-as-wanderer |

These four edges carve the entire interaction surface of the game into
four interface zones. UI design can use this as an organizing schema.

## Face zones (each face has a coherent flavor)

- **Self face** {Socialite, Ace, Icon, Spark} — what the player *is*
- **World face** {Captain, Merchant, Operator, Druid} — what the world *contains*
- **Classical face** {Socialite, Ace, Captain, Merchant} — deterministic, social, observable
- **Quantum face** {Icon, Spark, Operator, Druid} — superposed, entangled, casting
- **Flow face** {Socialite, Icon, Captain, Operator} — the persistent/conserving archetypes
- **Pulse face** {Ace, Spark, Merchant, Druid} — the eventful/asserting archetypes

The Pulse face is the natural "verb" face — every Pulse archetype is
an act-er. The Flow face is the natural "state" face — every Flow
archetype is a steady condition.

## Engine-side anchoring

Where each World-face archetype currently lives in code:

- **Captain**: Faction system (`Core/Factions/`), `Core/Quests/`, faction
  standing channels. Faction lords and fiefdom-tenders.
- **Merchant**: Frontier trade networks — faction contract brokers,
  import/export terminals, market-rate ledgers. The economic pulse
  actor; fires discrete trades between biome economies.
- **Operator**: `Core/QuantumSubstrate/`, `Core/Environment/Components/
  BiomeQuantumSystemBuilder.gd`, biome topology authorship in
  `Core/Biomes/data/biomes.json`. The architects of the manifold.
- **Druid**: `Core/QuantumSubstrate/QuantumGateLibrary.gd`, the gate
  cast verbs in Tool 1. NPC casters would be faction priests who teach
  or sell gate access.

Self-face archetypes are less directly anchored — they live in the
UI/PlayerShell input layer and the player's moment-to-moment state.

## Composite NPCs

Real factions and NPCs are typically *blends* of multiple World-face
archetypes:

- A faction lord who also brokers trade = Captain + Merchant
- A quest-giving caster priest = Captain + Druid
- An architect who teaches topology = Operator + Druid

The cube gives the design vocabulary; specific NPCs occupy weighted
combinations of vertices.

## Current naming

- **Flow ↔ Pulse** is the current axis name.
- **(W, C, P)** is **Merchant**: the faction-economy vertex on the World face.
- **(S, C, F)** is **Socialite**: the player's relational-presence vertex on the Self face.

## Runtime note

The cube is a design vocabulary. The live hat row is defined in
`Core/GameState/ToolConfig.gd` and uses 7 frames on keys `4 5 6 7 8 9 0`.

## Related

- `UI/Core/KEYBOARD_GRAMMAR.md` — input layer design
- `UI/Core/SURFACE_MANIFEST.md` — surface inventory
- `BIOME_AGENTS.md` — Captain/Operator territory (biomes + factions)
- `🍄/🎛️/` — lab tooling
- `Core/QuantumSubstrate/QuantumGateLibrary.gd` — Druid territory (gates)
