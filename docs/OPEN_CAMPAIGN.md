# What Fades — the Open-World Campaign

> Campaign design, 2026-07-04, owner-directed: *"an open system campaign that leaves
> the player in the full game to explore — all 150+ biomes with real open and closed
> system dynamics."* Descends from `docs/inspiration/OPEN_SYSTEM_ACT2.md` (the seed
> bank: post-mortem, laws, seam) — this document promotes those seeds to a campaign
> the way `docs/TOPOLOGY_CAMPAIGN.md` promoted `EXOTIC_TOPOLOGY.md`.
>
> **Status: Phases 0–2 and 4–5 SHIPPED (2026-07-04, same day).** The per-biome
> regime seam (`regime_override` on `QuantumComputer`, honored at the Lindblad build
> gate, the evolve kernel, ground-state init, measurement style, and the reap split);
> 10 wet landmarks + 5 inviolable island biomes stamped in `biomes.json`; eight story
> flags across acts 6–8 (`the_crossing` → `the_door_stays_open`); story-driven
> `regime_changes` / `physics_changes` applied on flag fire and re-derived on load;
> the per-biome rite (`_open_reap_rewards`, kT·ΔS was already implemented — it needed
> only the split) with its whisper register; `coherence_fell` + `purity_at_most`
> predicates; wet-country E-inspect passport + literal compass; glossary **bath** +
> **fading**.
>
> **Update 2026-07-05 — the verbs came home by geography, not decree.** The
> interim "all open verbs unseal at the door" simplification is retired: the
> keyboard is never sealed. Every hat is always selectable and the Lindblad
> verbs gate per-plot on `is_open_here()` — live in the wet landmarks from the
> moment the player stands in them, refused on closed ground forever (the
> island cannot be mixed, by construction: Farm's channel tick skips closed
> biomes). Chapter V's verb beats now exist as two act-7 flags
> (`the_verbs_come_home`, `the_first_contract`); Merchant's sub-modes are the
> three canonical channels (thermal / dephase / damp — the pure-dephasing
> kernel `apply_dephase` now exists, paying law #2's debt), F settles a
> standing contract, E reads the real order book, and Ace's Plant is a
> coherent Rabi pulse — legal everywhere, unable to purify (the Spark's jolt
> is the dissipative counterpoint that can). Phase 6 (Majorana) shipped as
> "What Connects" (`docs/CONNECT_CAMPAIGN.md`).
> Remaining: Phase 3 (role-separation data reform — biome bots), the dead
> `gated_lindblad_source` channels (61 authored self-feeding circuits in
> `biomes.json` that `LindbladBuilder` does not yet read — Chapter III's
> hysteresis beats need them), `PREVENT_DECOHERENCE` (tracker exists, no
> generator emits it), and threshold tuning in live play.

## The thesis

**What Survives** taught the invariants — what unitary motion cannot touch. **What
Fades** teaches the arrows — what only dissipation can do: pump, decay, dephase,
forget. The two campaigns are duals, and the game's deepest sentence sits between
them:

> In the enclave, looking is the only way to spend.
> Out here, looking is the only way to keep.

The closed game made measurement the player's *scar* on a perfect world. The open
game makes it their *lantern* against a hungry one. Same verb, learned in minute one,
recast at the hinge of the whole story — no new controls, a new world under them.

## The product shape

The campaign is the **endgame, not a sequel**. Act 5 ends at `edge_of_the_enclave`
("The Bath is patient. One day you will farm it"). What Fades opens that door and
leaves the player in the full 162-biome world — permanently, as the post-story game.

The load-bearing design decision: **openness is a place, not a patch.** The switch
does not flip on the world; the player *walks into* the parts of the world where it
was always on. Two facts make this cheap and honest:

1. **The geography already exists in the data.** Of 162 biomes, **64 author real
   Lindblad structure** (webways, decays, 23 with external pumps) — the Bath's
   territory, *wet* country. The other **98 author no L at all** — even with
   dissipation globally enabled they build zero operators and stay coherent:
   **natural enclaves**, dry country, born from data nobody has to retrofit. The
   world map is already a thermodynamic map.
2. **The seam is three physics sites** (verified in the seed bank §6):
   `LindbladBuilder.build_from_atoms` (the single build gate),
   `QuantumComputer.evolve()` (exact-unitary vs dissipator kernel), and ground-state
   init (pure vs thermal). A per-instance `force_open` on `QuantumComputer`, set from
   biome data, honored at those three sites, gives per-biome regime — while every
   player verb (Spark, pump, drain, Merchant export/import) can stay globally sealed
   until the campaign hands each one back as a story reward.

The island the player grew up on **stays closed forever** — the enclave becomes home,
a place you return to where nothing you built can rot. That is not a technical
limitation; it is the emotional architecture: the whole first game becomes the thing
the second game teaches you to miss.

## The audit — what already exists

| Layer | State |
|-------|-------|
| Master equation | Full GKSL machinery: `LindbladBuilder` (outgoing/incoming/decay/gated nonlinear sources, sink-flagging, wildcard), Lindblad integrator, `lindblad_rate_scale` dial |
| Native path | The C++ lookahead engine already consumes `qc.lindblad_operators` — **no recompile needed** |
| Persistence | `GameStateSerializer` round-trips mixed density matrices (dense + CSR) |
| Measurement backaction | Weak-measurement drain path tested (18 tests: trace, √(1−η) coherence decay, η limits) |
| Visual grammar | Purity→radius and coherence→saturation channels **built and frozen** (r ≡ 1 closed) — dephasing is a reveal of a sense organ the player didn't know the game had |
| Quest types | `PREVENT_DECOHERENCE` (the Zeno quest), `MAINTAIN_COHERENCE`, `INDUCE_BELL_STATE` trackers implemented, dormant |
| Economy | Already thermodynamic: E = −kT·log p, kT from live entropy. The open game says Landauer out loud |
| The circuit shelf | ~15 authored dissipative circuits, all dormant in v0: EIT dark states (NullingChamber), Zeno latch (ZenoLatch, Clinic), chiral clocks (WheelOfHours), laser gain (LaserGlint), bistables (ShrineOfAshes 0.95, TwofacedTide), **tristable Village**, limit cycle (MothGarden), critical slowdown (BrittleDawn), 2-bit memory (MnemonicHive), gradient memory (SporeLibrary), serenity attractor (MeditationGarden), vacuum attractor (FreshwaterSpring), polyculture (PastoralCommons), self-erasing one-shot (OrbitalStrike) |
| Assay toolkit | Six Python assays validate the shelf's physics headlessly (`tools/`) |
| Content engine | The procedural quest curriculum (personality-typed, four flavors + entanglement), resonance, and the ten-archetype voice system already cover **every faction and any biome** — the 150-biome long tail needs no per-biome authoring |
| Graph views | The webway is already *drawn* in every graph view, dark and sealed — lighting it up is the payoff of a decision made months before the door opens |
| World state | 162 biomes; 9 discovered at start; Captain frame owns discovery |

The engineering surface is genuinely small. The **design** surface is where the
months went last time — which is why the laws below are binding.

## The laws (promoted from the seed bank)

1. **Role separation.** H owns everything conservative and phase-carrying: transport,
   oscillation, interference, entanglement. L owns only what H cannot do: pump
   (population from nothing), decay (population to the sink), dephasing (phase
   destruction, populations untouched), steady-state attraction (initial-condition
   forgetting). **No L transfer channel may parallel an existing H coupling edge.**
   The first open system died of role duplication; this law makes duplication
   impossible by construction. Consequence: most webway recirculation edges migrate
   to H couplings (a data reform the biome-crafting bots can execute assay-by-assay);
   L keeps the arrows of time.
2. **Dephasing first.** The star channel: invisible in population space (cannot
   duplicate any H mechanic), *the* concept the art piece exists to teach, and its
   visuals are already built and frozen. The first open moment is: **the world goes
   gray while nothing moves.**
3. **Zeno is the counterplay.** Repeated measurement pins a dying state. The player's
   oldest verb becomes their shield. No new controls, ever, for the core loop.
4. **The rite is designed once.** Reap's true identity — sink flux + entropy-bank
   kT·ΔS — arrives here, with the harvest festival, the whisper register, the
   ceremony v0 deliberately withheld.
5. **Openness is a place** (new, this document). Wet and dry country coexist; the
   player chooses exposure by geography. Every open mechanic is somewhere you *go*,
   not something that happens to you.

## The campaign — five chapters and a capstone

Acts 6–9, staged like What Survives: sharp authored arcs on landmark biomes, beats
carrying the theory, the procedural engine filling the country between landmarks.
Each chapter is the *dual* of a closed-campaign chapter — the same object, met again
in a world that leaks.

### Prologue — The Crossing *(the door itself)*

`edge_of_the_enclave` fires and, for the first time, the horizon is a place. The
player sails/walks/falls out of the enclave (form TBD — cheapest is a discovered
biome that refuses to load closed). **Mechanics:** the first `force_open` biome
boots; global switches stay off; every open verb still sealed. The player brings
only closed-system hands into a world that doesn't play by their rules. The beat
names the antagonist that is not an antagonist: **the Bath** — patient, uniform,
incapable of malice, incapable of stopping.

### Chapter I — The Gray *(dephasing; dual of The Loop)*

The Loop banked phase; the Bath eats phase first. In the Fallow — one authored
visit-only wound-biome (canonize one of the cruft-resistant biomes; **GildedRot**
has the perfect name for it) — the player watches a qubit they prepared go gray:
populations intact, bubbles full-bright in place, color draining, radius shrinking.
Nothing moved, and something is gone. The E-inspect card teaches T₂; the glossary
gains **bath** and **fading**. *Quest shape:* prepare coherence, watch it halve,
bank the observation (predicates: `coherence_at_least` then a new
`coherence_dropped_below` witness — the first quest in the game that asks you to
*lose* something).

### Chapter II — Watching Keeps *(T₁ + Zeno; dual of The Pond)*

The Pond's depths were untouchable; here the spectrum finally moves on its own —
the compass needle *drifts* while you watch. A qubit is dying toward the sink
(T₁), and the player keeps it alive by measuring it, again and again — the Zeno
latch, already on the circuit shelf (ZenoLatch, Clinic). `PREVENT_DECOHERENCE`
wakes from its two-year sleep and becomes the signature quest type of the act.
The beat says the campaign's thesis line (looking is the only way to keep).

### Chapter III — The Basin *(attractors become literal; dual of The Chain — and the Pond's promise paid)*

`pond_breathes` promised: *"that kind of motion needs a world that leaks — someday
you will farm one."* Payday. Steady states, basins, bistability with hysteresis
(ShrineOfAshes, TwofacedTide), the Village's hot/cold/quiet tristability finally
running, MothGarden's limit cycle actually cycling, BrittleDawn's critical
slowdown. The eigenstate compass — which told the truth-but-not-the-whole-truth in
the enclave — becomes literal: the dominant eigenstate now *is* where the biome is
going. And Lanternfall's chain finally earns the original doc's claim: the edge
mode holds *against decoherence* while the bulk fades — topological protection
meaning something because there is finally something to be protected from.
*Quest shapes:* flip a bistable and watch it refuse to flip back (hysteresis =
the world's own memory); park population in the SSH edge mode and let the Bath
prove the theorem.

### Chapter IV — Hiding in the Light *(dark states; dual of The Braid)*

The Bath cannot eat what does not couple to it. NullingChamber's EIT dark state —
a superposition engineered so destructive interference hides it from the drive —
becomes the player's first *shelter they build out of phase itself*: the braid
lesson (order, interference, engineered superposition) weaponized against
dissipation. Chiral clocks (WheelOfHours) keep time by persistent current; laser
gain (LaserGlint) shows the Bath *feeding* a mode for once — dissipation as
cultivation, the first hint that the open world is farmable.

### Chapter V — The Rite *(the reap arrives; the economy opens)*

The verbs come home: Spark, pump, drain, Merchant export/import unseal one at a
time as faction rewards across the chapter, each with its whisper. Then the rite:
**reap stops being a volley of collapses and becomes the Lindbladian extraction**
— open a season's worth of accumulated dissipation and be paid from the entropy
bank, kT·ΔS, in the same units the physics uses. The harvest festival is designed
here, once, for the mechanic it honors. The Maxwell's-demon subtext of the entire
game (`DEMON_AT_THE_GATE.md`) is finally said in the open: the Throne's one use,
and one fear, for an entropy source — and the player decides what an information
engine owes the world it farms.

### Capstone — The Bridge *(Majorana; reserved machinery, scoped separately)*

The first structure the player builds that the Bath cannot reach: nonlocal storage
split between two biomes. **Shipped as "What Connects"** (`docs/CONNECT_CAMPAIGN.md`,
interleaved through acts 5–7 per the owner's call): `BridgeRegister` — a standalone
2×2 ρ anchored to a qubit in each biome, protection *derived* as the product of the
two ends' local noise rates, an island-anchored end immortal. Knot invariants
shipped alongside (Berry-loop records + mutual winding on the Berry lift); the
seed bank is empty of everything but chaos.

## The world between landmarks

- **Wet/dry geography from data:** 64 wet biomes (authored webways) are the Bath's
  country; 98 dry biomes are natural enclaves. The map views already distinguish
  them (webway edges present/absent) — add a single wet/dry glyph to the federation
  view and E-inspect.
- **Regions by tag:** the tag taxonomy already clusters the world (detector/lab —
  the instrument coast; memory/archive — the remembering lands; death/void — the
  fallows; commerce/labor/civic — the living belt; cosmic/space — the far shell).
  Regions are an *authoring vocabulary* for discovery gating and quest flavor, not
  engine structure.
- **Discovery pacing:** 9 biomes discovered at start; the Captain frame owns
  discovery; chapters unlock regional bands. The long tail runs on the existing
  procedural engine: personality-typed quests, resonance moods, archetype voices —
  all of it already reads *any* biome, including wet ones (dissipative observables
  simply start varying: purity, entropy, and the dynamics axis finally live).
- **Resonance pays off double:** entropy-loving factions — restless and alienated
  through the whole closed game *by canon* — are **at home in the wet country**.
  The faction that never liked your island finally has somewhere to invite you.
  Zero new code; the alignment math already does this.

## Implementation ladder

| Phase | Work | Owner |
|-------|------|-------|
| **0 — the seam** | Per-biome regime: `force_open` on `QuantumComputer` honored at the three physics sites; biome-data field (`"regime": "open"`); serializer flag; boot wiring. Global verb seals untouched | core (me) |
| **1 — the wound** | The Crossing beat + arc; the Fallow authored (canonize GildedRot); the gray reveal (unfreeze mixedness visuals — verify, don't rebuild); first fading quest; `coherence_dropped_below` witness predicate; glossary: **bath**, **fading** | core (me) |
| **2 — watching keeps** | Zeno arc on ZenoLatch/Clinic; wake `PREVENT_DECOHERENCE`; compass drift line; T₁/T₂ E-inspect teaching cards | core (me) |
| **3 — the reform** | Role-separation migration: webway recirculation edges → H couplings, L keeps sources/sinks/dephasing; rate retuning; assay regression per biome | biome bots (`BIOME_AGENTS.md`), assay-gated |
| **4 — the basins** | Chapters III–IV arcs on the circuit shelf; hysteresis/dark-state/gain quests; Lanternfall-under-noise beat | core (me) |
| **5 — the rite** | Entropy bank + kT·ΔS reap; verb unseals as faction rewards; harvest festival; whisper register for the rite | core (me) + economy validation by testing bots |
| **6 — the bridge** | Majorana machinery | scoped later |
| *(throughout)* | Drain/Zeno/steady-state runtime validation; save migration tests | testing bots |

Phases 0–2 are deliberately the seed bank's "shape 1 + shape 2" (visit-only wound,
then storms/Zeno) — the tar pit that ate months (`the full open economy`) stays
last, entered only with the laws in force and the feel validated.

## Open questions for the owner

1. **Where does the door ship?** Post-credits in v0 ("the game keeps going"), or
   v0.5 as the expansion beat? The seam work is identical either way.
2. **Is the island enclave inviolable forever** (my recommendation — home as the
   thing the open world teaches you to miss), or can late-game players choose to
   open it?
3. **Wet-country risk to standing farms:** when a webway wakes in a biome where the
   player has crops, do we grandfather a grace season? (Cheap: the Crossing fires
   only wet biomes the player hasn't settled; settled wet biomes wake on next reap.)
