# What Connects — the Nonlocality Campaign

> Campaign design + ship record, 2026-07-04. The third movement of the trilogy,
> promoted from `docs/ENGINE_FRONTIER.md` (Part I) the way the first two campaigns
> were promoted from their seed banks. Owner directives honored: the save-format
> touch is **blessed** (GameState.bridges), the chapters **interleave** into acts
> 5–7 rather than trailing the door, and this cycle is **mechanics only**.
>
> **Status: SHIPPED (2026-07-04, same day as the plan).** Machinery:
> `BerryPhaseRegister` loop records + the repaired live integration seam,
> `KnotRegister` (mutual winding + experimental Gauss linking on the Berry lift),
> `BridgeRegister` (2×2 nonlocal ρ, Γ-product protection, braid/fusion), Spark 🌉
> mode verbs, rig verbs, five story flags, five flag predicates, three quest
> predicates, knot card + bridge card, BRIDGE_WHISPER register, glossary **knot** +
> **bridge**. Remaining: threshold tuning in live play (testing bots); loop records
> and pending anchors are session-only by design (bridges themselves persist).

## The thesis

**What Survives** taught what one system keeps. **What Fades** taught what the
world takes. **What Connects** teaches the third thing, the one the gold edges
have been whispering since act 1:

> *What two places share, neither owns — and what neither owns, the world
> cannot easily take.*

Mutual information was the currency; the knot and the bridge are its monuments.
Both are nonlocal structure: the knot is an invariant belonging to two loops and
to neither alone; the bridge is a bit living between two biomes and in neither.
And both end in the same lesson the game opened with: when you finally *read*
the nonlocal thing, you localize it, and looking is paying.

## The chapters (interleaved, acts 5–7)

| # | Flag | Act | Where | The teaching |
|---|------|-----|-------|--------------|
| I | `second_loop` | 5 | StarterForest | The record: closed walks now file their *paths*, not just their areas. Two entries make a question. |
| II | `the_knot` | 5 | StarterForest | Two loops on a sphere cannot link — the sphere is a shadow. The link lives one floor up, where the phase turns; Berry was its accountant all along. Arc quest: wind twice (mutual winding 2). |
| III | `the_span` | 6 | home ⇌ GildedRot | The first structure the Bath cannot reach: joint parity has no local handle. Γ_bridge = the *product* of the shores' wet rates — an island anchor makes it immortal. Home matters mechanically, forever. |
| IV | `braid_alphabet` | 7 | the span | The bridge accepts no gates. Braiding is the only writing, and it speaks two letters — S here, √X there — which do not commute. The braid word is the program; the reachable words are Clifford, and that constraint is taught, not hidden. |
| V | `the_fusion` | 7 | the span | Fusion: Born-sample the parity, paid in surprisal across *both shores at once* — then the bridge is gone, because localizing the answer handed the Bath the address. The Throne learns what unreachable storage is worth. |

Interleave logic: chapters I–II extend act-1 berry muscle and slot beside act 5's
lull; chapter III requires the wet country (act 6's `the_crossing`) so protection
*means* something; chapters IV–V ride act 7 beside the basin arcs, and the braid
alphabet explicitly collects the act-4 `braid_word` debt.

## The machinery (docs/ENGINE_FRONTIER.md, as built)

**The repaired seam first.** The audit's biggest find was a wound, not a gap:
`BerryPhaseRegister.integrate_step` had **no call site** — written against a
stride-8 Bloch packet that no longer exists (live packets are stride 9), so live
Berry accumulation never ran; the rig faked it for tests by poking `_state`
directly. Rehabilitated per the standing directive: the integrator is now
stride-agnostic and wired at every evolution seam (batcher cursor advance,
stride-skip fast-forward, both deterministic stepper cycles, manual time-skip),
projective collapse cuts the walk (`reseed_tracked` — no unitary path connects a
jump), and sub-ε decoherence forfeits the partial loop (ripeness must beat the
gray). Chapter 1 of What Survives runs live for the first time.

**The knot** (`KnotRegister`, loop records in `BerryPhaseRegister`): tracked
qubits keep an arc-decimated polyline of their Bloch walk with running Ω per
vertex — the fiber coordinate of the Berry-connection lift. A walk that returns
to its seed having enclosed real solid angle freezes into a record (cap 8/biome)
that survives harvest. Pair invariants: **mutual winding** (integer; the quest
currency) and an experimental **Gauss linking** of the loops' horizontal lifts
to S³ (stereographic projection + midpoint double sum; display only). The knot
card lives on E-inspect beside the compass, with the Hopf line: *any two answers
of a qubit are linked circles.*

**The bridge** (`BridgeRegister`): one nonlocal fermion per span — a standalone
2×2 ρ over the parity basis, anchored to a qubit's atom pair in each of two
biomes, in neither Hilbert space, invisible to the native engine. Decoherence:
`Γ = κ·Γ_a·Γ_b`, ends read live per anchor atom from the host biome's webway
payload, zero wherever `is_open_here()` is false — protection *derived*, story
regime flips repricing every span on the next tick. Braids: S / √X (validated
unitary, non-commuting, trace-preserving against a Python port; the depolarizing
tick matches e^(−Γt) analytically). Fusion pays surprisal at the mean of the
shores' temperatures, split across both anchor atoms. Verbs in Spark 🌉 mode
(QERF: R spans, F braids, Q fuses, E inspects); rig verbs
`bridge_build/braid/fuse/list` (deterministic `roll` supported); save in
`GameState.bridges` (owner-blessed, additive).

## Vocabulary added

- Flag predicates: `bridge_built_gte`, `bridge_braids_gte`, `bridge_fused_gte`
  (farm-wide lifetime counters), `biome_frozen_loops_gte`, `biome_loops_linked`
  (biome-targeted).
- Quest predicates (active-biome projection): `frozen_loops_gte`, `loops_linked`,
  `winding_gte`.
- Whisper register: `bridge` (fusion — ten archetype lines + accessor), toasted
  with the fusion payout.
- Glossary: **knot**, **bridge** (nineteen terms; berry/invariant relate to them).

## For the testing bots

1. **Loop closure rates in live play**: LOOP_CLOSE_EPS 0.25 / LOOP_MIN_POINTS 12 /
   LOOP_OMEGA_FLOOR 0.5 are first guesses — verify the StarterForest day/night
   Hamiltonian actually closes loops at reasonable cadence, and that the act-5
   arc thresholds (2 loops; winding 2) are reachable.
2. **The repaired Berry seam**: berry ripeness must now accumulate WITHOUT the
   rig shim — verify Chapter 1 (What Survives) fires through live evolution, and
   that measurement collapse genuinely reseeds (no spurious solid-angle spikes
   across projective jumps, including the reap's mass measurement).
3. **Bridge Γ contrast**: island-anchored span never decays; GildedRot⇌ZenoLatch
   span decays visibly slower than either biome grays; story regime flip
   (`the_chain_tested` opening Lanternfall) reprices spans that anchor there.
4. **Save/load**: bridges round-trip through GameState.bridges (ρ, age, braid
   counts, lifetime counters); loop records intentionally do NOT persist.
5. **KAPPA = 10.0 / DEFAULT_WET_RATE = 0.05** set bridge lifetimes (both-wet at
   rate 0.1 → τ ≈ 10 s) — tune to taste in live play.

## Addendum (2026-08-10)

The knot thread's two honesty sequels live in the fourth lane, **What Turns**
(`docs/GAUGE_CAMPAIGN.md`): the winding attack ("The Number That Lied" — mutual
winding demoted from invariant to attackable diagnostic) and lift closure
("Close It Upstairs" — `gauss_linking` now refuses open lifts; the player walks
a loop twice to close its S³ lift before the linking question is legal). Also
resolved here: `the_span` now additionally gates on `the_knot`, restoring
What Connects II→III lane continuity (CAMPAIGN_STATE_2026-08-04 anomaly 11).
