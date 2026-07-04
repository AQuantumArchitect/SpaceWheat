# What Survives — the Topology Campaign

> Campaign plan, 2026-07. Descends from `docs/inspiration/EXOTIC_TOPOLOGY.md` (the
> six-tier aspiration), audited here against the shipped engine and reframed for the
> enclave's closed-system canon. Status: **planning → phased implementation**.

## The thesis

The old aspiration was *teach topology through farming*. The enclave makes that
aspiration sharper, not harder. In a closed world nothing decays, nothing rusts,
nothing leaks — unitary evolution deforms every state smoothly and reversibly. So the
only quantities worth farming are the ones smooth deformation cannot touch:
**invariants**. A solid angle enclosed by a loop. The spectrum of a density matrix.
The dimerization class of a chain. The order of a braid.

Measurement is the enclave's *thermodynamic* irreversibility — the one act that scars.
Topology is its *geometric* irreversibility — the quantities that don't flow, they
jump. The campaign teaches the second kind, one invariant per chapter:

> **The enclave forbids decay. It cannot forbid shape.**

## The audit — six tiers against the shipped game

| Tier | The old doc says | What actually exists | v0 fate |
|------|------------------|----------------------|---------|
| 0 — Instant farming | implemented | The design foundation of the whole game | **shipped** |
| 1 — Berry phase | "implemented, drives glow" | *Deeper than claimed*: `BerryPhaseRegister` integrates true signed solid angle (L'Huilier per slice), ripeness at 2π, harvest counters, story-flag predicates (`berry_consumed_count_gte`, `berry_total_phase_gte`), soul incorporation with faction whispers | **Chapter 1** — machinery done, needs the teaching arc |
| 2 — Strange attractors | future work | *Mostly built and already in use*: `BiomeBase.get_attractor_state()` (dominant eigenstate + eigenvalue gap), `BiomeDynamicsTracker` (evolution rate), lookahead prediction, quest predicates `attractor_emoji_gte` / `eigenvalue_gap_gte` / `predict_population_gte` / `predict_purity_gte` / `biome_purity_trending`, maintain-for-duration trackers with draining elapsed banks. The Village arc already drives the mill's ⚙ attractor | **Chapter 2** — reframe the fiction (closed systems have no attractors), then it's data-only |
| 3 — SSH chains | future work | *Expressible as pure data*: `HamiltonianBuilder` builds H entirely from icons; icons author per-emoji `hamiltonian_couplings` (complex-valued cross terms). A dimerized chain is an icon line with alternating strengths. Per-atom `population:` observables + duration trackers can watch the edges | **Chapter 3** — the crown; needs authored content, no engine change |
| 4 — Majorana bridges | future work | No inter-biome bridge machinery exists | **reserved → Act 2** |
| 5 — Anyonic braiding | future work | Non-commuting gates ship today (Operator + Druid frames); `gate_sequence_contains` counts gate uses but is order-blind | **Chapter 4** — needs one small predicate (`gate_order`) |
| 6 — Knot invariants | future work | No linking-number machinery | **reserved → Act 2+** |

The old doc's **observation tools** footer, same treatment: purity meter ✅ (inspector
+ M-Eigenstate), coherence thermometer ✅ (E-inspect observables), entanglement web ✅
(the loom — gold MI edges in M-Graph), eigenstate compass ❌ — `get_attractor_state()`
computes it but **no UI surface reads it**. Chapter 2 gives it one.

## The four chapters

Each chapter teaches one invariant, through one mechanic, in one faction's voice, by
breaking one lie the player might believe.

### Chapter 1 — The Loop Remembers *(Berry holonomy)*

- **Invariant:** the solid angle a closed loop encloses on the Bloch sphere.
- **The lie it breaks:** "if you end where you started, nothing happened."
- **Physics:** geometric phase. Path-dependent, parameter-independent, quantized
  against nothing — pure memory of *shape*. Ripeness at 2π is a hemisphere enclosed.
- **Machinery:** all live (`BerryPhaseRegister`, ripeness, consume counters, berry
  whispers, `berry.md` glossary).
- **Quest ladder (data-only):**
  1. *Walk a small loop* — track a qubit, let the Hamiltonian carry it around, bank
     any nonzero phase (`berry_total_phase_gte`, small value).
  2. *The hemisphere* — bring one qubit to ripeness and harvest it
     (`berry_consumed_count_gte: 1`).
  3. *Two roads home* — accumulate phase from loops of different shape; the beat
     teaches that the same endpoints paid differently. The invariant is the loop,
     not the destination (`berry_total_phase_gte`, larger value, beat text carries
     the lesson).
- **Voice:** mystic — the archetype already whispering at incorporation.

### Chapter 2 — The Pond Holds Its Depths *(the spectrum)*

- **Invariant:** the eigenvalues of ρ. Every unitary conserves them — the surface of
  the pond moves, the depths do not. Exactly one act reaches the depths: measurement.
- **The lie it breaks:** "if it's churning, it's changing."
- **Physics, honest version:** closed systems have **no attractors** — nothing
  converges, nothing settles; motion is quasi-periodic forever. What the engine calls
  the "attractor" (`get_attractor_state()`) is the *dominant eigenstate of ρ right
  now* — in enclave fiction, the **eigenstate compass**: what the biome most *is*,
  and how decidedly (the eigenvalue gap). The closed-system motion taxonomy:
  - **still** — ρ near-commutes with H; the dynamics tracker reads ~0,
  - **breathing** — one dominant coherence, one frequency: the pond has a pulse,
  - **storming** — many incommensurate frequencies at once; wild but *never chaotic*.
    True chaos needs contraction, and contraction needs the open door — an Act 2
    foreshadow spoken in-beat.
- **Machinery:** attractor state + gap, dynamics tracker, maintain-duration trackers,
  five live predicates — zero campaign users yet.
- **Quest ladder (data-only):**
  1. *Still the pond* — steer toward a decided state and hold it
     (`eigenvalue_gap_gte` + duration bank).
  2. *Make it breathe* — drive coherence, hold the dynamics mid-band (coherence +
     duration).
  3. *The depths don't move* — evolve wildly, then verify purity is exactly what it
     was (`purity_at_least` after storming — the conservation *is* the punchline).
  4. *Reach the depths* — measure, and watch the gap jump. The one hand that touches
     the bottom.
- **Small code (Phase B):** an eigenstate-compass line on the biome's E-inspect card —
  *"the pond wants ⚙ — gap 0.22"* — surfacing `get_attractor_state()` for the first
  time. Optional honesty patch: the dynamics tracker snapshots purity/entropy/
  coherence, but the first two are frozen in the enclave — add population motion to
  the snapshot so "storming" registers fully.
- **Language note:** player-facing text says *compass / deep state / depths*; the
  `attractor_*` predicate names stay (data API, not fiction). The Village arc's
  "second attractor / bistability" lines are dissipative-flavored — flag for a later
  voice pass, not load-bearing now.
- **Voice:** defensive — stillness, water, holding.

### Chapter 3 — The Chain Protects Its Ends *(SSH winding)*

- **Invariant:** the dimerization class of an alternating chain — winding number 0
  or 1. When weak-strong alternation puts the strong bonds *inside*, the ends host
  protected edge modes; population parked there stays. Flip the pattern and the same
  atoms, the same icons, the same total coupling leak everything they're given.
- **The lie it breaks:** "protection lives in things." It lives in the *pattern
  between* things.
- **Physics:** the icon cross-coupling is a two-qubit flip-flip (XX-type) term —
  in the low-excitation sector, hopping. A six-qubit chain with alternating |v| < |w|
  is the SSH model as icon data. Twelve atoms per chain biome sits inside the shipped
  envelope (biomes up to 13 atoms exist today).
- **Machinery:** `HamiltonianBuilder.build_from_icons` (exists), per-atom
  `population:` observables (exist), duration trackers (exist), Icon frame planting
  (exists). **Needed: authored content only** — a dimer icon family (strong-bond and
  weak-bond icon species), one chain biome ("Loomrow"), and the quest arc.
- **Quest ladder:**
  1. *Plant the chain* — install the dimer icons in alternation (icon-installed
     predicates).
  2. *The edge holds* — inject population at an end atom; hold it above threshold
     for a season (`population:` + duration bank).
  3. *The middle leaks* — inject at the center; watch it disperse
     (`biome_state_lte` on the center atom).
  4. *Flip the pattern* — replant shifted by one bond. Same icons, other winding
     class. Now the edge leaks too — and the player learns the protection was never
     in the atoms.
- **Validation note for the testing bots:** one headless scene proving edge-mode
  pinning through the real `build_from_icons` path (not this plan's job; flagged).
- **Voice:** guild — infrastructure, pattern, load-bearing bonds.

### Chapter 4 — The Braid Cares About Order *(non-commutativity)*

- **Invariant:** the braid word — the order of operations that don't commute.
  H-then-CNOT builds a Bell pair; CNOT-then-H builds something else entirely.
- **The lie it breaks:** "a list of chores is a set."
- **Machinery:** the Operator and Druid frames ship every gate needed. Outcomes are
  verifiable *by state* today: the right order shows up as
  `mutual_information_at_least` (the Bell pair), the wrong order as mere coherence.
- **Small code (Phase B):** a `gate_order` predicate in
  `QuestStateProjectionService` — ordered-subsequence match over the existing
  `_action_history`, soft-gated like everything else (~25 lines). The current
  `gate_sequence_contains` counts; braiding needs *order*.
- **Quest ladder:** *Two chores* (do A-then-B, verify by outcome state) → *The other
  braid* (same two gates, other order, other outcome — both quests offered together
  by the same faction, which is the joke and the lesson) → *The long braid* (a
  three-gate word via `gate_order`).
- **Voice:** militant — drill order, sequence discipline. Fibonacci anyons remain
  flavor text; the enclave demonstrates non-commutativity with the gates it has.

## Reserved for the open door

Three tiers stay sealed with reasons, recorded in `docs/inspiration/OPEN_SYSTEM_ACT2.md`:

- **Majorana bridges (tier 4)** — nonlocal inter-biome storage needs bridge machinery
  the engine doesn't have; it is also *better* in Act 2, where decoherence resistance
  means something because decoherence exists.
- **Knot invariants (tier 6)** — linking numbers over entanglement histories need a
  braid-history graph; farthest out, still loved.
- **True chaos** — the "storming" chapter teaches its absence honestly:
  quasi-periodicity is a theorem in the enclave. Strange attractors arrive with
  dissipation, and dissipation arrives with Act 2.

## The implementation ladder (cheapest first)

| Phase | Work | Touches |
|-------|------|---------|
| **A — data only** | Chapters 1–2 quest arcs as story-flag beats + quests riding live predicates | `Core/Quests/data/` |
| **B — small code** | Eigenstate-compass E-inspect line; `gate_order` predicate; optional population term in dynamics snapshots | `MapMetaOverlay`/biome status card, `QuestStateProjectionService`, `BiomeBase._track_dynamics` |
| **C — authored content** | Dimer icon family, the Loomrow chain biome, Chapter 3 arc | `icons.json`, `biomes.json`, quest data |
| **D — weave** | Chapter beats into the act structure (chapter *n* gates on act *n*), whisper lines per chapter voice, candidate glossary entry: **invariant** (the campaign's one new canon word) | `story_flags.json`, `QuestVoice`, `docs/glossary/` |

Phases A and B are a normal cultivation cycle each. Phase C is the first time the
campaign asks for new *world* (one biome, ~4 icons) rather than new words about the
existing world.

## How it sits in the game

The topology campaign is not a separate board — it is the **upper rungs of the
existing curriculum ladder**. Rungs 1–2 (personality-typed amplitude/coherence/ratio/
multi, then entanglement) teach the player to *steer* states. The campaign's four
chapters teach what steering *cannot change* — and that the things it cannot change
are the things worth keeping. The same factions offer them, in the same voices,
through the same board, gated on the same acts. By the end, the player has met both
of the enclave's irreversibilities: the one they commit (measurement) and the ones
the world was born with (shape).
