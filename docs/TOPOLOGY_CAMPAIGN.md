# What Survives — the Topology Campaign

> Campaign plan, 2026-07. Descends from `docs/inspiration/EXOTIC_TOPOLOGY.md` (the
> six-tier aspiration), audited here against the shipped engine and reframed for the
> enclave's closed-system canon.
>
> **Status: all four chapters SHIPPED (2026-07-04, owner-approved).** Seven story
> flags (`loop_remembers`, `pond_depths`, `pond_breathes`, `chain_ends`,
> `chain_flipped`, `braid_order`, `braid_word`) across acts 1–4; `gate_order` +
> `dynamics_at_most` / `dynamics_at_least` predicates; the eigenstate compass (🧭)
> on the Graph frame's status card + E-inspect; population motion in the dynamics
> tracker; `docs/glossary/invariant.md`. One plan-to-reality correction below:
> Chapter 3 needed **no new biome** — Lanternfall already existed.

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

*(The ladders below are the design shapes. The shipped arcs compress each chapter to
its sharpest one or two asks — flag ids in the status header — and move the remaining
lessons into the beats, where the words are; the mechanics they describe all exist for
procedural quests to reuse.)*

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
  protected edge modes; population parked there stays. The bulk is on the wrong side
  of every weak-strong wall and disperses everything it's given.
- **The lie it breaks:** "protection lives in things." It lives in the *pattern
  between* things.
- **The plan met reality and reality was ahead of it.** The draft called for
  authoring a new chain biome ("Loomrow"). The implementation audit found the stage
  already built and *better*: **Lanternfall** — five lanterns on the coast
  (🌉 🪔 📯 🗼 🏁), native faction the **Lamplighters** ("topological patience…
  scholars of the order call it chiral symmetry"), alternating icon couplings in
  `icons.json` (Beacon: 🪔→📯 at 1.1 vs 🪔→🌉 at 0.3), a biome description that
  already narrates the protected zero mode at the bridge, and a standing physics
  assay (`tools/ssh_assay.py`, with a beautiful pedagogical header). Per the
  rehabilitation-over-duplication rule, the chapter stages there.
- **Shipped quest ladder** (`chain_ends` → `chain_flipped`, act 3):
  1. *Keep the Bridge Lit* — hold 🌉 above 45% while the chain runs
     (`biome_state_gte`); the zero mode does the holding once you feed the ends.
  2. *The Middle Cannot Hold* — settle 📯 (mid-chain) under 25% while 🌉 still
     holds 35%: the bulk-vs-edge contrast enacted as a single composed ask.
  The beats carry the winding-number lesson: count the pattern, not the lamps.
- **Voice:** the Lamplighters themselves (guild-class), including an authored
  webway whisper override — the chapter's faction speaks in its own words.
- **Validation note for the testing bots:** one headless scene proving edge-mode
  pinning through the real `build_from_icons` path on Lanternfall's realized
  register (flagged; the SSH assay validates the authored data layer, not the
  icon-built runtime H).

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

*(Update, 2026-07: the door is open — "What Fades" shipped — and tiers 4 & 6
SHIPPED as "What Connects" (`docs/CONNECT_CAMPAIGN.md`), interleaved through
acts 5–7. Chaos alone stays sealed.)*

Three tiers stay sealed with reasons, recorded in `docs/inspiration/OPEN_SYSTEM_ACT2.md`:

- **Majorana bridges (tier 4)** — nonlocal inter-biome storage needs bridge machinery
  the engine doesn't have; it is also *better* in Act 2, where decoherence resistance
  means something because decoherence exists.
- **Knot invariants (tier 6)** — linking numbers over entanglement histories need a
  braid-history graph; farthest out, still loved.
- **True chaos** — the "storming" chapter teaches its absence honestly:
  quasi-periodicity is a theorem in the enclave. Strange attractors arrive with
  dissipation, and dissipation arrives with Act 2.

## The implementation ladder — as shipped (2026-07-04)

| Phase | Work | Landed in |
|-------|------|-----------|
| **A — data** | All four chapter arcs: 7 story flags with beats + arc quests, acts 1–4 | `Core/Quests/data/story_flags.json` |
| **B — small code** | `gate_order` (ordered-subsequence braid predicate) + `dynamics_at_most` / `dynamics_at_least`; eigenstate compass 🧭 (status card + E-inspect, with the conservation-law line); population motion in dynamics snapshots (in the enclave purity/entropy are frozen — populations carry the breathing); Druid-frame Hadamard recorded into the gate history; predicate summaries + gate glyphs on the quest board | `QuestStateProjectionService`, `MapMetaOverlay`, `BiomeBase` + `BiomeDynamicsTracker`, `QuantumInstrument`, `QuestBoard` |
| **C — authored content** | *Cancelled as planned, replaced by rehabilitation:* Lanternfall + Lamplighters + alternating icon couplings already existed. Chapter 3 stages on them; a Lamplighters webway whisper override was the only new authored voice | `story_flags.json`, `QuestVoice` |
| **D — weave** | `docs/glossary/invariant.md` (the campaign's one new canon word), INDEX + in-game Guide featured strip, this status pass | `docs/glossary/`, `ControlsOverlay` |

## How it sits in the game

The topology campaign is not a separate board — it is the **upper rungs of the
existing curriculum ladder**. Rungs 1–2 (personality-typed amplitude/coherence/ratio/
multi, then entanglement) teach the player to *steer* states. The campaign's four
chapters teach what steering *cannot change* — and that the things it cannot change
are the things worth keeping. The same factions offer them, in the same voices,
through the same board, gated on the same acts. By the end, the player has met both
of the enclave's irreversibilities: the one they commit (measurement) and the ones
the world was born with (shape).
