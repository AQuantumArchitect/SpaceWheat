# The Last Machinery — engine frontier plan

> **Status: Part I SHIPPED (2026-07-04, same day) — see `docs/CONNECT_CAMPAIGN.md`
> for the ship record.** C0–C4 landed: loop records + the repaired Berry
> integration seam (the audit's biggest find — `integrate_step` had NO live call
> site; live Berry accumulation never ran until now), `KnotRegister`,
> `BridgeRegister` with derived Γ-product protection, Spark 🌉 verbs, five
> interleaved story flags (owner: interleave, blessed save touch, mechanics only),
> glossary **knot** + **bridge**. **Part II SHIPPED G1–G4:** G1 attract reels
> (`🍄/🎛️/ReelRunner.gd`, `SW_REEL=<path>` / `--reel=path`, any input exits;
> `🍄/🎛️/reels/first_light.reel.json`); G2 postcards (`🍄/🎛️/PostcardCapture.gd`,
> F12 → watermark-in-pixels PNG + sidecar certificate, reel verb `postcard`);
> G3 the atlas (`tools/atlas_plates.py` — all 162 biomes as SVG plates from data
> truth + contact sheet; independently re-derives the What Fades geography;
> samples in `docs/atlas/samples/`); G4 the web door
> (`scripts/smoke-test-web-export.mjs` browser smoke + `docs/release/WEB_DOOR.md`
> lane/policy — harness fixture-validated; first real run needs a Godot machine).
> Remaining: G5 (grammar audit — visual, deferred per "mechanics only") and the
> web door's first real run.
>
> Original plan follows, kept for the audit trail and Part II.

> **Status: PLANNED, 2026-07.** The two campaigns shipped: "What Survives"
> (`TOPOLOGY_CAMPAIGN.md`, acts 1–4) taught the invariants; "What Fades"
> (`OPEN_CAMPAIGN.md`, acts 6–8) opened the door. What remains are the two
> machinery reservations made in both audits — **Tier 4 (Majorana bridges)** and
> **Tier 6 (knots)** from `inspiration/EXOTIC_TOPOLOGY.md` — and the aspiration the
> whole project has carried from the start: that SpaceWheat is an **art piece**
> (`inspiration/DEMON_AT_THE_GATE.md`, "Why this matters for the art piece") and
> must eventually be able to exhibit itself. This document plans both: Part I is
> the physics machinery, Part II is the gallery machinery. Neither is speculative;
> both audits below found the hard parts already standing.

## Why these two, together

The reserved topology tiers are not leftovers — they are both about the same thing,
and it is the thing the game has been quietly pricing all along: **nonlocal
structure**. A Majorana bridge is information that lives *between* two biomes and
in neither. A linking number is an invariant that belongs to *two* loops and to
neither alone. Mutual information — the gold edges the player has been weaving
since act 1 — was the currency; these are its monuments. The campaign they seed
is the trilogy's close:

> **What Survives** taught what one system keeps.
> **What Fades** taught what the world takes.
> **What Connects** teaches what two places share that neither owns.

And the gallery is the same thesis turned outward. The art piece argues that
*observation is an act with a price*; an exhibition surface — a playable link, a
self-running installation, a reproducible postcard — is the piece finally being
observed on its own terms, without its author standing next to it.

---

# Part I — What Connects (the last topology machinery)

## The audit

| Piece | Engine state today | Gap |
|-------|--------------------|-----|
| Standalone density matrix outside all biome tensor products | **Exists** — `FactionDensityMatrix` (the player's soul) runs exactly this pattern | None; it's the precedent for the bridge |
| Per-biome open/closed regime with live local noise rates | **Shipped** (What Fades Phase 0) — `QuantumComputer.is_open_here()`, per-biome Lindblad activity | None; the bridge's decoherence rule reads it directly |
| Berry loop tracking | **Shipped** — `BerryPhaseRegister` integrates signed solid angle (L'Huilier) per slice | Scalar only: the *path* is discarded, so no loop-pair invariant can be computed |
| Emoji-keyed relationship graph | **Exists** — `DualEmojiQubit.entanglement_graph` + full query API (`inspiration/EMOJI_TOPOLOGY_GRAPH.md`) | Unused by any quest; no rewiring puzzle shape |
| Gate non-commutativity, braid words | **Shipped** (What Survives ch. 4) — `gate_order` predicate | The bridge gives braiding a *place to live* |
| Quest predicate vocabulary | **Shipped** — 20+ predicates, biome-targeted flag predicates | ~4 new predicates per machine, same pattern as before |

Both machines are **pure GDScript, no C++ work, no recompile**. A bridge is a 2×2
density matrix; a loop record is ≤128 floats. The native engine never needs to
know either exists.

## Machine 1 — The Bridge (`BridgeRegister`)

### The physics, honestly

In a Kitaev chain, one fermion is split into two Majorana end-modes, one at each
end of the wire. The stored bit is their **joint parity** — a property of the
pair, readable at neither end alone. Local noise couples to local operators, and
no local operator can flip a nonlocal parity: decoherence requires *correlated*
disturbance at both ends at once. The protection is not a shield; it is the
absence of any local handle for the Bath to grab.

### The engine translation

- **`BridgeRegister.gd`** (`Core/QuantumSubstrate/`): one standalone 2×2 ρ per
  bridge — the nonlocal fermion's occupation. Anchored to `(biome_a, atom_a)` and
  `(biome_b, atom_b)`. It lives in *no* biome's Hilbert space — that is both the
  physics point and the engineering cheapness (no tensor-product growth).
- **Emergent protection, not a magic constant.** The old doc promised "~90%
  decoherence resistance" as a number. We derive it instead:
  `Γ_bridge = κ · Γ_A(atom_a) · Γ_B(atom_b)` — the *product* of the two ends'
  local wet-noise rates, read live from each host biome's Lindblad activity.
  Consequences that fall out for free, in regime language:
  - anchor one end in **closed country** → that end's Γ = 0 → the bridge is
    immortal. The island becomes perfect anchor ground — home matters
    *mechanically*, forever, exactly as the door promised it would.
  - both ends wet → a slow second-order fade, visibly gentler than either
    biome's own graying. The player *sees* the protection as a rate contrast.
- **Verbs in the existing QERF grammar** (no new controls, per the What Fades law):
  - **R** at an anchored end = **braid**: exchange the end-modes, applying
    exp(θ·γ₁γ₂) phases to the bridge. Braiding alone generates only Clifford
    operations — an honest constraint we *teach* rather than hide: *the bridge
    speaks only the braid alphabet.*
  - **E** = inspect the bridge card: span, parity odds, live Γ_bridge, age.
  - **Q** = **fusion**: measure the joint parity. The bridge collapses and pays
    surprisal, like every other look in this game. Reading the bridge kills it —
    the thesis in one verb.
- **Seams**: tick beside the soul-decay tick in the farm process loop (2×2 needs
  nothing from the batcher); a new small `bridges` array in the save file — the
  **first save-format touch in two campaigns**, flagged for the owner below;
  E-inspect card surfaced from both anchor biomes; whisper register for first
  fusion. Predicates: `bridge_exists` (span), `bridge_age_gte`,
  `bridge_parity_odds_gte`, `fusion_payout_gte`.

## Machine 2 — The Knot (`LoopRecord` + `KnotRegister`)

### The physics, honestly

Two loops on the Bloch sphere **cannot link** — linking needs three dimensions
and S² hasn't the room. The honest statement is better than the naive one: the
qubit's full state lives one floor up, on S³, carrying the global phase the
Bloch projection forgets — and *there*, loops genuinely link. The Berry register
has been metering that floor all along: geometric phase is exactly what the lift
remembers that the shadow doesn't. **Ripeness was always the shadow of a knot.**

The canonical fact to teach costs zero computation, because it is a theorem
(Hopf): the preimages of *any two distinct points* of the Bloch sphere are
circles in S³ that link exactly once. Any two answers a qubit can give are
linked circles — that is the geometric reason you can never hold both.

### The engine translation

- **`LoopRecord`** — extend `BerryPhaseRegister` with opt-in path recording:
  an angularly-decimated polyline of Bloch points (record a vertex only when
  direction turns by more than ε; hard cap ~64–128 points). When a tracked loop
  closes (returns within δ of its seed with |Ω| above the noise floor), the
  polyline freezes into a `LoopRecord {biome, qubit, points, omega, closed_at}`.
  Purely additive; the shipped scalar path is untouched.
- **`KnotRegister`** — pairwise invariants over frozen records:
  - **Mutual winding** (ship first): how many times loop A winds about loop B's
    mean axis. An integer, robust to decimation, one pass to compute.
  - **Gauss linking of the Hopf lifts** (stretch): lift both polylines to S³
    using the accumulated phase and evaluate the Gauss double sum — O(64²) per
    pair, trivial cost, and the number it returns is the real thing.
- **Graph knots as puzzles, not invariants.** Reidemeister moves on the webway /
  entanglement graph ("unknot the ecology to maximize throughput") depend on the
  drawing, not the physics — so they ship as a *puzzle shape* using the existing
  `entanglement_graph` API and SWAP rewiring, honestly framed as housekeeping,
  never as topology.
- **Surfaces**: a knot card on the compass plane (E-inspect, as everything);
  linked loop pairs draw a gold band between their qubits in the graph views.
  Predicates: `loops_linked` (two frozen loops, |link| ≥ 1), `winding_gte`,
  `graph_planarized`.

## The campaign seed (acts 9–10, sketched only)

Full campaign doc comes at implementation time, as with the first two. The
chapter shapes, so the machinery is built with its story in hand: **The Span**
(first bridge, one end anchored home — the island's mechanical vindication),
**The Braid Alphabet** (Clifford constraint as drill, reusing act-4 braid word
muscle), **The Fusion** (reading kills; the payout economy), **The Linked
Harvest** (grow two Berry loops on two qubits until the knot card certifies
|link| ≥ 1 — harvest pays both), **The Unknotting** (graph puzzle, the Weaver's
housekeeping). The Throne, which learned in act 8 what an entropy source is
worth, now learns what *unreachable storage* is worth — the Demon subtext gets
its final rhyme.

**Still reserved:** true chaos. One honest route exists now that the door is
open — state-dependent H (mean-field feedback) in wet country produces real
positive-Lyapunov dynamics, which closed linear evolution never can — but it
stays in the seed bank until What Connects ships.

---

# Part II — The Gallery (the art piece exhibits itself)

## The aspiration, stated

SpaceWheat's deepest pitch is not "a game that teaches quantum mechanics"; it is
a thesis about observation having a price, rendered as a place
(`DEMON_AT_THE_GATE.md`). A thesis needs an exhibition surface: a **playable
link** that requires no install, a **self-running reel** for a screen at a show
or on a portfolio page, **plates** that hang, and **postcards** that certify.
The audit found — as with the rite last cycle — that most of the machinery
already exists and was built for other reasons.

## The found-machinery audit

| Machinery | State | Gallery use |
|-----------|-------|-------------|
| **The rig** (`🍄/🎛️/rig_listener.gd`) | Headless persistent session executing a JSONL action queue — ~40 verbs incl. gates, pumps, time-skip, overlays, quest ops | An attract reel is *data, not code*: a queue file plus timing |
| **Deterministic measurement seeds** | Shipped — save-load replays the same universe | Postcards become **physics certificates**: every image reproducible from its seed |
| **Headless assay pattern** (`tools/ssh_assay.py`) | Shipped (What Survives ch. 3) | The atlas plate generator follows it exactly |
| **Visual grammar** (`QuantumVisualGrammar.gd`, one owner per channel) | Shipped; enforced (`VISUAL_MOTION_SCOUT.md`) | Wet country just made purity→radius and coherence→saturation vary *for the first time* — audit the newly live channels |
| **Web preset** | Exists, experimental; wired for native WASM GDExtension (`EXPORT_HEALTH.md`) | The play link — the portfolio's front door |
| **Desktop lanes** | Linux healthy, Windows mostly (`release/ITCH_STATUS.md`) | itch uploads are close; not engine work |

## The workstreams

### G1 — Attract reels (the piece plays itself)

A **reel** is a JSONL rig script with timing: seed the universe, walk a biome,
inject an icon, weave entanglement, close a Berry loop, collapse something
improbable, let a whisper land. The rig already executes every one of those
verbs headless; what's missing is presentation plumbing — new rig verbs
`focus_biome`, `set_overlay_tab`, `wait_phrames`, `caption` — and a kiosk
runner: boot headed with `--reel <path>`, loop forever, any input exits to live
play. Reels double as living documentation, trailer source, and regression
theater (a reel that desyncs is a determinism bug found for free).

### G2 — Postcards (reproducible witness)

One key: capture the current view at high resolution to `user://postcards/`
with a **physics watermark strip** — biome, act, seed, Tr(ρ²), entanglement
bits, sim time. Because measurement is seeded, the watermark is a *claim*: this
exact universe, replayable. No other game can put "this really happened, and
here is how to make it happen again" on a screenshot. Engine cost: a viewport
capture plus a watermark composer; zero gameplay surface.

### G3 — The atlas plates (the catalog)

A headless generator (assay-pattern script driving the rig) renders each of the
162 biomes as a **plate**: the cluster graph — purple H couplings, the webway in
orange (solid where wet, dark where sealed), palette, name, regime stamp —
composed to PNG/SVG at print resolution. The output is simultaneously the
exhibition catalog, the itch page art, and a data-QA sweep (a malformed biome is
visible as a malformed plate). 162 plates is an art book the repo generates from
truth.

### G4 — The web door (the play link)

The heaviest item, and the portfolio's front door. `ITCH_STATUS.md` already
names the bar; this workstream makes it a lane: (1) one repeatable export
script producing the web bundle from repo state; (2) a browser smoke lane
(Playwright: boot, run N frames, probe responsiveness) run as a gate; (3) an
honest performance statement for the live game; (4) an explicit degradation
policy — **try the WASM native path first** (the preset is already wired for
it); if it can't hold frame, ship the **gallery build**: GDScript fallback with
a reduced live-biome budget, stated plainly as such. A degraded-but-honest link
beats no link.

### G5 — The grammar audit (the reveal must land)

The first fading is the art piece's thesis statement rendered — *the world goes
gray while nothing moves* — and it works only if nothing else is moving either.
Wet country makes the purity and coherence channels vary for the first time in
the project's life: sweep them under the `VISUAL_MOTION_SCOUT.md` working rule
(one owner, one source, one policy per channel), and finish converting the
remaining ambient pulsing (infra lines, plot tiles) that the scout already
indicted. Small, sharp, high leverage.

---

# The ladder

Two independent tracks; within each, dependency order. Cheap, high-certainty
items first — C0 and G1 are days, not weeks.

| Phase | Work | Owner |
|-------|------|-------|
| **C0 — the record** | `LoopRecord`: opt-in decimated path capture + loop-closure freeze in `BerryPhaseRegister`; purely additive | core (me) |
| **C1 — the knot** | `KnotRegister`: mutual winding (+ Gauss lift, stretch); knot card + gold band; `loops_linked` / `winding_gte` predicates | core (me) |
| **C2 — the bridge core** | `BridgeRegister`: 2×2 ρ, anchors, Γ-product decoherence rule, tick, serialization (**save-format touch — owner sign-off**) | core (me) |
| **C3 — the bridge verbs** | Braid / inspect / fusion in QERF; bridge card; predicates; first-fusion whisper | core (me) |
| **C4 — What Connects** | Campaign doc + acts 9–10 arcs + glossary (**bridge**, **knot**); Unknotting puzzle shape | core (me) |
| **G1 — attract reels** | Rig presentation verbs + reel format + kiosk runner (`--reel`) | core (me); owner records reels |
| **G2 — postcards** | Capture key + physics watermark composer | core (me) |
| **G3 — atlas plates** | Headless plate generator, 162 plates to `user://atlas/` | core (me); biome bots triage bad plates |
| **G4 — the web door** | Export script + Playwright smoke lane + perf statement + degradation policy | core (me) + testing bots; **gated last** |
| **G5 — grammar audit** | Newly-live wet channels swept; remaining ambient pulsing converted | core (me); anytime |
| *(throughout)* | Runtime validation: bridge Γ contrast, loop-record determinism, reel desync, web smoke | testing bots |

## Open questions for the owner

1. **The save file.** The bridge is the first machinery in two campaigns that
   wants a new save field (a `bridges` array). Cheap and additive — but it ends
   the "no save-format changes" streak. Bless it, or should bridges be
   session-only until fusion (roguelike bridges: use them or lose them)?
2. **Campaign placement.** Does What Connects run as acts 9–10 after the door,
   or interleave its early chapters (The Span works fine pre-door, island end
   anchored)? Default plan: after, keeping the trilogy's order clean.
3. **The degraded web build.** If WASM native can't hold frame, is a
   GDScript-only gallery build (fewer live biomes, stated plainly) acceptable
   for the portfolio link, or is desktop-only the more honest exhibit?
4. **Plate & postcard identity.** Watermark and plate composition are art
   direction — owner's eye wanted before G2/G3 output styles freeze.
