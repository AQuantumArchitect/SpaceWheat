# SpaceWheat for Physicists

> The five-minute credibility pass. If you teach quantum mechanics, work in the
> field, or simply refuse to take "it's real physics" on faith, this is the
> document for you: every physics concept the game claims to teach, what the
> player actually does with it, and an **honesty grade** for how the simulation
> earns the claim. Written by the people who built the machinery; the grades
> err conservative.

## The claim

SpaceWheat's engine is a density-matrix simulator. Each biome *is* a ρ evolving
under its authored Hamiltonian — exactly, via the unitary propagator
U = exp(−iH·dt) — with a GKSL (Lindblad) dissipator wherever the world runs
"open." The farming mechanics are not decorated dice: planting, measuring, and
harvesting are state preparation, Born-rule sampling, and information-to-work
accounting performed on that live ρ. The story layer is *computed from* the
quantum state (faction moods from observables, whispers at irreversible
moments), not written beside it.

That claim is checkable, and the last section tells you how.

## The honesty scale

- **exact** — the number on screen *is* the quantity, computed by the true
  equation on the live state; trustworthy to machine precision within the model.
- **faithful** — real equations, real behavior, reduced model (few sites,
  cartoon rates, game-constant exchange rates). The lesson transfers; the scale
  does not.
- **suggestive** — the mechanic gestures at physics the engine does not
  simulate. The game says so in-world; nothing suggestive is presented as exact.

## The ledger

### Foundations — the closed game (acts 0–4)

| Concept | In-game | What the player does | Grade | Where |
|---|---|---|---|---|
| Density matrix ρ | the biome's cloud | Every biome is a ρ; the N overlay shows the raw matrix as a heatmap with per-register probability bars | **exact** | `Core/QuantumSubstrate/` |
| Unitary evolution U = exp(−iH·dt) | the season | Watches states evolve under each biome's authored H; purity conserved to machine precision (eigendecomposition in C++, Padé scaling-and-squaring in the GDScript fallback) | **exact** | `QuantumComputer.evolve()` |
| Quantum gates | Operator (9) / Druid (0) frames | Builds Bell, GHZ, and cluster states by hand; 14 gates with exact unitary matrices, verified against exact density-matrix elements (142 tests) | **exact** | `Core/QuantumSubstrate/`, `tests/` |
| Born rule + projective collapse | measurement (E) — the economy's engine | Samples a qubit; the state collapses; sampling is deterministically seeded so a save-load replays the same universe | **exact** | `Core/Actions/` |
| Weak measurement | the drain (open country) | Partial-strength readout: trace preserved, coherence decays as √(1−η); η = 0 and η = 1 limits tested (18 tests) | **exact** | weak-measurement suite |
| Purity Tr(ρ²) and von Neumann entropy | "resolved / mixed"; kT | Reads purity on every inspect surface; the economy's kT is computed from live entropy | **exact** | inspect overlays |
| Mutual information | the loom — gold edges | Entangles qubits and watches MI edges glow in proportion to bits (native path, physics rate) | **exact** | M-Graph view |
| Surprisal economy E = −kT·log p | the harvest | Gets paid the surprisal of what was learned; improbable outcomes pay more | **faithful** — the bookkeeping is real (Landauer-flavored, kT from live entropy); the credit exchange rate is a game constant | `EnergyPricing` |
| Open-system decay of identity | "You are a quantum system too" | The player's identity is a ρ over 12-qubit faction concept-space, decaying toward the maximally mixed state (τ = 300 s) unless choices renew it | **faithful** — a real density matrix under real decay; the concept basis is fiction | `Core/`, M overlay |
| Maxwell's demon | the whole game | Converts information to work for pay; the Throne subplot asks what an information engine owes the world it farms | **faithful** | `docs/inspiration/DEMON_AT_THE_GATE.md` |

### Geometry and topology — What Survives (acts 1–4)

| Concept | In-game | What the player does | Grade | Where |
|---|---|---|---|---|
| Geometric phase | ripeness (berry) | A tracked qubit's closed Bloch walk banks the signed solid angle it encloses (L'Huilier per evolution slice); ripe at 2π | **exact** — this is the Aharonov–Anandan geometric phase of the actual pure-state path (not adiabatic transport, and the game never says "adiabatic") | `BerryPhaseRegister.gd` |
| Spectrum conservation | the pond's depths | Evolves a biome wildly, then verifies the eigenvalues of ρ never moved; exactly one act reaches the depths — measurement | **exact** — a theorem, enacted | Chapter 2 arc |
| Dominant eigenstate + gap | the eigenstate compass 🧭 | Reads what the biome most *is*, and how decidedly | **exact** readback — with the honest label: closed systems have **no attractors**, so the compass reads identity, not destiny | `MapMetaOverlay` E-inspect |
| SSH edge protection | Lanternfall's chain | Keeps the bridge lantern lit while the mid-chain disperses; alternating strong/weak couplings are authored icon data (chiral symmetry) | **faithful** — a real dimerized hopping chain with a genuine protected edge mode, at 5 sites; the sharp winding-number phase is a thermodynamic-limit story and the game teaches the pattern, not the limit | `icons.json`, `tools/ssh_assay.py` |
| Non-commutativity | the braid word | H-then-CNOT builds a Bell pair; CNOT-then-H builds something else — both offered as quests, verified by the resulting state; `gate_order` matches ordered subsequences | **exact** | Chapter 4 arc |
| Absence of chaos | "storming, never chaotic" | Learns that wild closed-system motion is quasi-periodic forever — true chaos needs contraction, and contraction needs the open door | **exact absence**, honestly taught | Chapter 2 beats |

### Open systems — What Fades (acts 6–8)

| Concept | In-game | What the player does | Grade | Where |
|---|---|---|---|---|
| GKSL (Lindblad) master equation | the wet country | 64 of 162 biomes author real L (pumps, decays, dephasing, gated channels); the other 98 author none and stay coherent — the world map is a thermodynamic map | **exact** within the model — the dissipator integrates the real GKSL generator | `LindbladBuilder`, `biomes.json` |
| T₂ dephasing | the gray / fading | Prepares coherence and watches it drain: populations intact, color desaturating, radius shrinking — *nothing moved, and something is gone* | **exact** channel; the two visual channels (purity→radius, coherence→saturation) are direct readbacks | Chapter I arc |
| T₁ decay | dying toward the sink | Watches population leak to an authored sink | **exact** channel | webway payloads |
| Quantum Zeno effect | watching keeps | Pins a dying qubit by measuring it, again and again — the player's oldest verb becomes the shield | **exact** mechanism (repeated projective pinning on the live ρ) | Chapter II arc |
| Steady states, bistability, hysteresis | the basins | Flips a bistable and feels it refuse to flip back; the Village runs hot/cold/quiet tristable; MothGarden's limit cycle cycles; BrittleDawn slows critically | **faithful** — engineered few-qubit Lindbladians whose steady-state structure genuinely has these features | the circuit shelf, `tools/` assays |
| EIT dark states | shelter built from phase | Engineers a superposition that destructive interference hides from the drive — the Bath cannot eat what does not couple to it | **faithful** — real dark-state interference in a reduced model | NullingChamber |
| Thermodynamics of erasure | the rite: reap pays kT·ΔS | A season's accumulated dissipation is paid out from the entropy bank, in the same units the physics uses | **faithful** bookkeeping — Landauer said out loud, at game scale | `_open_reap_rewards` |

### Nonlocality — What Connects (acts 5–7)

| Concept | In-game | What the player does | Grade | Where |
|---|---|---|---|---|
| Loop records + mutual winding | the knot | Closes two Bloch walks in one biome; the integer winding of one loop about the other's area axis is the quest currency | **exact** for the recorded polylines | `KnotRegister.gd` |
| Linking and the Hopf fibration | "any two answers of a qubit are linked circles" | Learns that loops on S² cannot link — the sphere is a shadow; linking lives one floor up, on S³, where the Berry phase turns | **faithful** teaching — the Hopf statement is true; the game places it correctly | knot card, `docs/glossary/knot.md` |
| Gauss linking of Berry lifts | the experimental line on the knot card | Sees a Gauss linking number computed on the loops' horizontal lifts to S³ (stereographic projection, midpoint double sum) | **suggestive** — labeled *experimental* in-game; a quadrature over a coordinate choice, shown for wonder, never gated on | `KnotRegister.lift_to_s3` |
| Majorana-style nonlocal storage | the bridge / the span | Splits one parity bit between two biomes; decoherence rate is the **product** of the two shores' local noise rates (Γ = κ·Γ_a·Γ_b, read live from the webways) — an island-anchored end is immortal | **faithful** — the product scaling is the honest core of topological protection (a nonlocal fermion needs correlated noise at both ends); the model is a 2×2 parity ρ, not a Kitaev wire, and the game never claims otherwise | `BridgeRegister.gd` |
| Ising-anyon braiding | the braid alphabet: S here, √X there | Writes the bridge by braiding — two non-commuting letters; the reachable set is Clifford **and the game teaches that limit as a feature** (why the field wants T gates) | **faithful** — S and √X are the genuine braid-group representation for Ising anyons | Spark 🌉 mode |
| Fusion | reading the span | Born-samples the joint parity: the answer localizes, the surprisal is paid across both shores at once, and the bridge is spent — localizing the answer handed the Bath the address | **faithful** | `bridge_fuse` |

## What the game refuses to fake

The credibility of the ledger lives as much in the refusals as the claims:

- **No attractors in the enclave.** The engine computes a "dominant eigenstate"
  and the fiction calls it a compass — and the beats say out loud that closed
  systems never settle. The word "attractor" is only allowed to mean attractor
  after the door opens.
- **No chaos anywhere, yet.** Quasi-periodicity is a theorem in the enclave;
  the game teaches the theorem instead of faking sensitivity. True chaos stays
  in the seed bank until an honest mechanism exists.
- **No linking on the sphere.** Ripeness banked solid angles for four acts
  before the game admits the loops those angles came from cannot link where
  they live — and then it shows you where linking actually lives.
- **No magic protection percentages.** The bridge's decoherence rate is
  *derived* from the product of its ends' live noise rates, not decreed. Park
  an end on the sealed island and the product is zero; the immortality is
  arithmetic, not a buff.
- **Clifford-only braiding, admitted.** The braid alphabet cannot reach every
  program, which is the true limitation of Ising anyons — taught, not hidden.

## Assessment is performance, not quizzes

The game never asks the player *about* physics. Quest completion is soft-gated
on observables computed from the live ρ — a progress bar fills as the state
approaches the ask. "Hold coherence above 0.6 for a season" cannot be answered;
it can only be *done*, and doing it requires exactly the understanding the quest
teaches (which basis, which coupling, when to look and when looking costs). In
assessment terms: every quest is a performance task with the density matrix as
the grader. The soft gates (`QuestMath.soft_gate`) mean partial understanding
earns visible partial credit — the progress bar is the teacher.

## A rough course map

| Acts | The game teaches | Course anchor |
|---|---|---|
| 0–1 | states, superposition, Born rule, measurement backaction, entanglement | first weeks of any quantum-information course |
| 1–4 | geometric phase, spectra as invariants, SSH edge modes, non-commutativity | topological-matter interludes |
| 5–7 | mutual information, knot/linking intuition, Majorana nonlocality, braiding | quantum computing / anyons |
| 6–8 | Lindblad channels, T₁/T₂, Zeno, dark states, Landauer | open quantum systems |

## Verifying the claims

Nothing above needs to be taken on faith:

1. **The test suites** — 164 physics tests against exact matrix elements:
   `bash run_quantum_gate_tests.sh` (or per-suite via `bash 🍄/🧪/🔬.sh`).
2. **The rig** — a deterministic headless JSON control surface
   (`Rig/rig_listener.gd`): script a preparation, evolve, measure with a fixed
   roll, and check the numbers yourself. Reels (`Rig/reels/`) are worked
   examples.
3. **The assays** — standalone Python ports validating the authored physics
   (`tools/ssh_assay.py` and friends) with no engine in the loop.
4. **The atlas** — `tools/atlas_plates.py` re-derives the world's thermodynamic
   geography (64 wet / 98 dry) from the same data the engine boots from.
5. **Postcards** — every F12 capture carries a sidecar certificate (purity, MI,
   phrame count, regime) reproducible from the save.

Disagreements with a grade are welcome — the ledger is meant to be attacked.
The campaign documents carry the full designs: `docs/CLOSED_SYSTEM.md`,
`docs/TOPOLOGY_CAMPAIGN.md`, `docs/OPEN_CAMPAIGN.md`, `docs/CONNECT_CAMPAIGN.md`,
and the in-world vocabulary lives in `docs/glossary/INDEX.md`.
