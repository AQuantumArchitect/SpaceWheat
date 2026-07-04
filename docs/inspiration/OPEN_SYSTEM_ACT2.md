# The Open System — Act 2 Design Notes

**Status: seed bank.** v0 ships closed (`docs/CLOSED_SYSTEM.md`). This document holds the
design thinking for the day the dissipative switch (`BalanceConfig.dissipative_enabled`)
comes back on — so that day starts from a diagnosis, not a blank page.

---

## 1. Post-mortem: why the first open system failed

The v0-era attempt at running both generators produced Hamiltonian and Lindblad dynamics
that were *copies of each other*, and it was right to kill it. The diagnosis matters more
than the failure:

**Both generators were authored as transport graphs over the same emoji nodes.** A
Hamiltonian coupling moves amplitude between 🌾 and 👥; a webway Lindblad channel moves
population between 🌾 and 🍂. At the level the player actually reads — populations, bubble
brightness — a coherent coupling and an incoherent transfer channel paint nearly the same
picture: stuff flows along edges. The real differences (oscillation vs. monotone
relaxation, interference, phase) are precisely the things population-space cannot show.
Two systems doing the same job at different rates is not a balance problem. It is a **role
duplication** problem, and no amount of rate tuning fixes it.

## 2. The role-separation law

The fix falls straight out of the GKSL structure. H is the Hermitian generator — it
*conserves*: trace, energy, information, purity. L is the non-Hermitian part — the only
thing in the theory that can do what H cannot. So partition the game roles by what is
mathematically exclusive to each generator:

> **H owns everything conservative and phase-carrying:** transport, oscillation,
> interference, entanglement generation.
>
> **L owns only the non-conservative and phase-destroying channels:** pump (population
> from nothing), decay (population to the sink), dephasing (phase destruction with
> populations untouched), and steady-state attractors (initial-condition forgetting).
>
> **Rule: no L transfer channel may parallel an existing H coupling edge.**

Under this law the two generators *cannot* mimic each other — they are orthogonal by
construction rather than by tuning. Practical consequence: most of the current webway
recirculation edges (`lindblad_outgoing`/`lindblad_incoming` between in-cloud atoms)
should migrate to Hamiltonian couplings in Act 2. L keeps the arrows of time: sources,
sinks, and forgetting. The webway's *ecological reading* survives — it just becomes
coherent food-web transport, with dissipation reserved for what actually dissipates.

## 3. Dephasing first

The star channel of Act 2 is **dephasing**, for three reasons:

1. It is the one Lindblad operator that is *literally invisible in population space* — it
   can never be a copy of any H mechanic. The role-separation law is automatically
   satisfied.
2. It is *the* open-systems concept the art piece exists to teach: decoherence.
3. **The visual language for it is already built and currently frozen.** In the closed
   game r = 1 always, so the purity→radius and coherence→saturation channels
   (`QuantumVisualGrammar.gd`, `QuantumNode.apply_quantum_snapshot`) never vary. The
   first dephasing event is the reveal of a sense organ the player didn't know the game
   had: **the world goes gray while nothing moves.** Populations intact, color gone.
   No population-transport mechanic could ever say that sentence.

## 4. The Zeno mechanic — measurement as preservation

The counterplay to dissipation should be the verb the player already owns. Repeated
measurement pins a state against Lindblad evolution — the quantum Zeno effect, already
demonstrated on the circuit shelf (`ZenoLatch`, see `BIOME_AGENTS.md`). So in an open
zone:

- A qubit is dying (T₁ decay toward the sink).
- The player keeps it alive by *watching it* — spamming the same Measure they learned in
  minute one, now recast as an act of preservation.

> *In the enclave, looking is the only way to spend. Out here, looking is the only way
> to keep.*

One authored quest around that loop teaches irreversibility, decay, and measurement
backaction as a resource — using only Act-0 vocabulary. No new mechanics required.

## 5. The narrative arc — the enclave and the Bath

The closed world now has an in-fiction name: **the enclave** — a bubble of perfect
coherence where nothing decays, nothing leaks, and only measurement leaves a scar. The
seam is planted in v0's story data:

- `first_breath` (Act 0) names the enclave's law at the very first beat.
- `edge_of_the_enclave` (Act 5, `story_flags.json`) is the door v0 does not open: the old
  texts call this a closed system, *and they say it is not the only kind*. The Bath is
  patient.

Act 2 is the walls coming down — or the player stepping out. Decoherence arrives as a
narrative event, not a patch note. Candidate shapes, cheapest first:

1. **The Fallow** — one authored, visit-only decoherent biome. A diorama with a door: no
   reap, no market, no economy integration. The player walks in, watches a qubit die,
   learns Zeno, walks out changed. (Consider canonizing one of the "crufty" biomes —
   TidalPools, HorizonFracture, GildedRot — as the wound: the biomes that resisted tuning
   become the place where balance is impossible. The cruft becomes canon.)
2. **Decoherence storms** — timed Lindblad injection into otherwise-closed biomes
   (`set_lindblad_operators` is already the API), defended by Zeno play.
3. **The full open economy** — entropy bank, kT·ΔS reap, live webways. This is the tar
   pit that ate months. It comes last, after 1 and 2 have taught the design what open
   play *feels* like, and only under the role-separation law.

## 6. The implementation seam (verified against the tree, 2026-07)

The closed/open switch touches ~25 call sites, but only **three are physics**:

| Site | Role |
|---|---|
| `LindbladBuilder.build_from_atoms` (`LindbladBuilder.gd:41`) | The single build gate — closed → 0 operators |
| `QuantumComputer.evolve()` fast path (`QuantumComputer.gd:~1719`) | Exact-unitary kernel vs. Euler+dissipator |
| `QuantumComputer` ground-state init (`QuantumComputer.gd:~742`) | Pure vs. thermal init |

Everything else is player-tool and UI gating (Spark/Merchant hats, drain/pump verbs,
frame visibility) that can **stay globally closed** for a visit-only open zone — the
*environment* dissipates; the player brings only closed-system verbs. Implementation is a
per-instance flag on `QuantumComputer` (e.g. `force_open`), set from one biome's data,
honored at those three sites. Supporting facts, all verified:

- The C++ engine already consumes `qc.lindblad_operators` (no native recompile —
  `docs/CLOSED_SYSTEM.md` says so explicitly).
- Mixed states already serialize: `GameStateSerializer` round-trips full density matrices,
  dense and CSR sparse.
- The weak-measurement drain path is tested (`tests/test_drain_qubit.gd`: trace
  preservation, √(1−η) coherence decay, η=0/1 limits).
- The mixedness visuals exist and are dormant (see §3).

## 7. Physics footnotes worth keeping

- **The economy is already thermodynamic** (`EnergyPricing.gd`: E = −kT·log p, kT from
  live entropy). In the open system this becomes literal Maxwell's demon / Landauer play:
  the player is an information engine extracting work by measurement, and the reap bank
  kT·ΔS prices it in the same units the physics uses. The closed game whispers this;
  the open game can say it out loud.
- **Entanglement quests before dissipation quests.** The trackers for INDUCE_BELL_STATE,
  MAINTAIN_COHERENCE, PREVENT_DECOHERENCE already exist (`QuestManager.gd`) and are
  dormant — only SHAPE_ACHIEVE coherence quests spawn today. An entanglement teaching arc
  (make a Bell pair → watch the MI edge appear in the force graph → measure one half →
  watch the partner collapse) is pure authoring on existing machinery, and it is the
  natural bridge between the closed curriculum (superposition, measurement, Berry phase)
  and the open one (decoherence).
- **PREVENT_DECOHERENCE is the Zeno quest type.** It was implemented before its physics
  was reachable. In Act 2 it stops being dormant and becomes the signature verb.
